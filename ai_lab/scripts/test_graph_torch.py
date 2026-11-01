"""Execute the exported op graph and compare it with YOLO module outputs."""
import argparse
import csv
import json
from pathlib import Path
import sys
import types

if "ultralytics" not in sys.modules:
    u = types.ModuleType("ultralytics")
    utils = types.ModuleType("ultralytics.utils")
    checks = types.ModuleType("ultralytics.utils.checks")
    checks.check_requirements = lambda *a, **k: None
    u.utils = utils
    utils.checks = checks
    sys.modules.update({"ultralytics": u, "ultralytics.utils": utils,
                        "ultralytics.utils.checks": checks})

import torch

ROOT = Path(__file__).resolve().parents[1]


def submodule(root, path):
    value = root
    for part in path.split("."):
        value = value[int(part)] if part.isdigit() else getattr(value, part)
    return value


def run(graph_path):
    graph = json.loads(Path(graph_path).read_text(encoding="utf-8"))
    ckpt = torch.load(ROOT / "data/models/yolov5n-garbage.pt",
                      map_location="cpu", weights_only=False)
    model = ckpt["model"].float().eval()
    model_root = model
    reference = {}
    handles = []
    with (ROOT / "data/layer_table/layers.csv").open(newline="", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))
    for row in rows:
        path = row["module"]
        ref_module = submodule(model_root, path.rsplit(".conv", 1)[0] if path.endswith(".conv") else path)
        def hook(_module, _inputs, output, key=path):
            reference[key] = output.detach().clone()
        handles.append(ref_module.register_forward_hook(hook))

    torch.manual_seed(91)
    image = torch.rand(1, 3, graph["size"], graph["size"])
    with torch.no_grad():
        model(image)
        outputs = []
        for op in graph["ops"]:
            args = [image if ref == -1 else outputs[ref] for ref in op["inputs"]]
            if op["name"] == "CONV":
                module = submodule(model_root, op["module"])
                if op["module"].endswith(".conv"):
                    module = submodule(model_root, op["module"].rsplit(".conv", 1)[0])
                value = module(args[0])
            elif op["name"] == "MAXPOOL":
                if op["module"].rsplit(".", 1)[-1].startswith("m") and op["module"].rsplit(".", 1)[-1][1:].isdigit():
                    value = submodule(model_root, op["module"].rsplit(".", 1)[0]).m(args[0])
                else:
                    value = submodule(model_root, op["module"])(args[0])
            elif op["name"] == "UPSAMPLE":
                value = submodule(model_root, op["module"])(args[0])
            elif op["name"] == "CONCAT":
                value = torch.cat(args, dim=1)
            elif op["name"] == "ADD":
                value = args[0] + args[1]
            else:
                raise AssertionError(op["name"])
            outputs.append(value)
            expected_shape = tuple([1, *op["out_shape"]])
            assert tuple(value.shape) == expected_shape, (
                f"{op['module']} shape {tuple(value.shape)} != {expected_shape}")

    for handle in handles:
        handle.remove()
    max_abs = 0.0
    for op in graph["ops"]:
        if op["name"] != "CONV":
            continue
        actual = outputs[op["idx"]]
        expected = reference[op["module"]]
        assert actual.shape == expected.shape, op["module"]
        err = float((actual - expected).abs().max())
        max_abs = max(max_abs, err)
        assert torch.equal(actual, expected), (
            f"{op['module']} graph differs from model, max_abs={err}")
    print(f"GRAPH_TORCH_PASS ops={len(outputs)} convs={len(rows)} max_abs={max_abs}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--graph", default=str(ROOT / "gen/integration/graph.json"))
    run(parser.parse_args().graph)
