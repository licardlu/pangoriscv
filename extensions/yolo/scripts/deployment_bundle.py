"""Graph-aware deployment calibration and exact integer datapath emulation.

This is distinct from the fbgemm feasibility result. Detection heads deliberately
remain software FP32; all other convolutions emulate the RTL's fixed Q15 tail.
"""
import argparse
import hashlib
import json
from pathlib import Path

import export_graph  # checkpoint import compatibility setup
import numpy as np
import torch
import torch.nn.functional as F

from quant_yolov5n import preprocess
from test_graph_contract import validate
from test_graph_torch import submodule

ROOT = Path(__file__).resolve().parents[1]


def round_away(x):
    return np.copysign(np.floor(np.abs(x) + 0.5), x).astype(np.int64)


def requant(acc, multiplier, shift=15):
    product = np.asarray(acc, dtype=np.int64) * np.asarray(multiplier, dtype=np.int64)
    magnitude = (np.abs(product) + (1 << (shift - 1))) >> shift
    return np.where(product < 0, -magnitude, magnitude)


def padded_channels(n):
    return (n + 7) // 8 * 8


def float_graph(model, graph, image, callback=None):
    outputs = []
    for op in graph["ops"]:
        values = [image if i == -1 else outputs[i] for i in op["inputs"]]
        pre = None
        if op["name"] == "CONV":
            module = submodule(model, op["module"])
            pre = module(values[0])
            if op["module"].endswith(".conv"):
                wrapper = submodule(model, op["module"][:-5])
                pre = wrapper.bn(pre) if hasattr(wrapper, "bn") else pre
                value = wrapper.act(pre)
            else:
                value = pre
        elif op["name"] == "ADD":
            value = values[0] + values[1]
        elif op["name"] == "CONCAT":
            value = torch.cat(values, 1)
        elif op["name"] == "MAXPOOL":
            value = F.max_pool2d(values[0], op["k"], op["stride"], op["k"] // 2)
        elif op["name"] == "UPSAMPLE":
            value = F.interpolate(values[0], scale_factor=2, mode="nearest")
        else:
            raise ValueError(op["name"])
        outputs.append(value)
        if callback:
            callback(op, value, pre)
    return outputs


def calibrate(output, count):
    graph = json.loads((ROOT / "gen/integration/graph.json").read_text())
    import csv
    with (ROOT / "data/layer_table/layers.csv").open() as handle:
        validate(graph, list(csv.DictReader(handle)))
    model = torch.load(export_graph.CKPT, map_location="cpu",
                       weights_only=False)["model"].float().eval()
    manifest = json.loads((ROOT / "data/g4/train.json").read_text(encoding="utf-8"))
    paths = []
    for entry in manifest.values():
        path = ROOT / entry["img"].replace("\\", "/")
        if path.is_file() and path not in paths:
            paths.append(path)
        if len(paths) == count:
            break
    if not paths:
        raise ValueError("No training calibration images")
    maxima = np.zeros(len(graph["ops"]), np.float64)
    premax = np.zeros_like(maxima)
    def observe(op, value, pre):
        idx = op["idx"]
        maxima[idx] = max(maxima[idx], float(value.abs().max()))
        if pre is not None:
            premax[idx] = max(premax[idx], float(pre.abs().max()))
    with torch.no_grad():
        for index, path in enumerate(paths):
            image, _, _ = preprocess(path, graph["size"])
            float_graph(model, graph, image, observe)
            if (index + 1) % 8 == 0:
                print(f"calibration {index + 1}/{len(paths)}", flush=True)

    output.mkdir(parents=True, exist_ok=True)
    arrays, ops = {}, []
    scales = {-1: 1.0 / 127}
    for original in graph["ops"]:
        op = dict(original)
        idx = op["idx"]
        prefix = f"op{idx}_"
        sx = scales[op["inputs"][0]]
        sy = max(maxima[idx], 1e-6) / 127
        if op["name"] in ("MAXPOOL", "UPSAMPLE"):
            sy = sx
        elif op["name"] == "CONCAT":
            sy = max(scales[i] for i in op["inputs"])
        scales[idx] = sy
        op.update(scale=sy, input_scales=[scales[i] for i in op["inputs"]],
                  execution="cpu")
        if op["name"] == "CONV":
            module = submodule(model, op["module"])
            is_head = idx in graph["outputs"]
            if is_head:
                arrays[prefix + "weight"] = module.weight.detach().numpy()
                arrays[prefix + "bias"] = module.bias.detach().numpy()
                op["execution"] = "cpu_fp32_head"
            else:
                if op["module"].endswith(".conv"):
                    wrapper = submodule(model, op["module"][:-5])
                    if hasattr(wrapper, "bn"):
                        module = torch.nn.utils.fusion.fuse_conv_bn_eval(module, wrapper.bn)
                    activation = type(wrapper.act).__name__
                else:
                    activation = "Identity"
                if activation not in ("SiLU", "Identity"):
                    raise ValueError(f"Unsupported activation {activation}")
                wf = module.weight.detach().numpy().astype(np.float64)
                bf = module.bias.detach().numpy().astype(np.float64)
                sw = np.maximum(np.abs(wf).reshape(op["cout"], -1).max(1), 1e-9) / 127
                wq = np.clip(round_away(wf / sw[:, None, None, None]), -127, 127)
                bias = round_away(bf / (sx * sw))
                spre = max(premax[idx], 1e-6) / 127
                mul = round_away(sx * sw / spre * (1 << 15))
                if np.any(np.abs(bias) >= 2**31) or np.any(np.abs(mul) >= 2**31):
                    raise ValueError(f"int32 overflow {op['module']}")
                q = np.arange(-128, 128, dtype=np.float64)
                raw = q * spre
                activated = raw / (1 + np.exp(-np.clip(raw, -700, 700))) if activation == "SiLU" else raw
                lut = np.clip(round_away(activated / sy), -128, 127)
                arrays[prefix + "weight"] = wq.astype(np.int8)
                arrays[prefix + "bias"] = bias.astype(np.int32)
                arrays[prefix + "multiplier"] = mul.astype(np.int32)
                arrays[prefix + "lut"] = lut.astype(np.int8)
                op.update(pre_scale=spre, execution="rtl_q15_conv",
                          zero_multipliers=int(np.sum(mul == 0)))
        ops.append(op)
    bundle = dict(graph, ops=ops, input_scale=scales[-1],
                  checkpoint_sha256=hashlib.sha256(export_graph.CKPT.read_bytes()).hexdigest(),
                  calibration_images=[str(p.relative_to(ROOT)) for p in paths],
                  note="Exact Q15 simulation; NOT an accepted FPGA release")
    np.savez(output / "parameters.npz", **arrays)
    (output / "bundle.json").write_text(json.dumps(bundle, indent=1), encoding="utf-8")
    zero = sum(o.get("zero_multipliers", 0) for o in ops)
    print(f"BUNDLE_CREATED ops={len(ops)} calibration={len(paths)} zero_multipliers={zero}")
    return bundle


class Deployment:
    def __init__(self, path):
        self.graph = json.loads((path / "bundle.json").read_text())
        self.arrays = np.load(path / "parameters.npz")
        self.model = torch.load(export_graph.CKPT, map_location="cpu",
                                weights_only=False)["model"].float().eval()

    def execute(self, image, callback=None):
        graph = self.graph
        x = np.clip(round_away(image.numpy() / graph["input_scale"]), -128, 127).astype(np.int8)
        values = []
        for op in graph["ops"]:
            idx = op["idx"]
            args = [x if r == -1 else values[r] for r in op["inputs"]]
            sy = op["scale"]
            prefix = f"op{idx}_"
            if op["name"] == "CONV":
                weight = self.arrays[prefix + "weight"]
                if op["execution"] == "cpu_fp32_head":
                    inp = torch.from_numpy(args[0].astype(np.float32) * op["input_scales"][0])
                    value = F.conv2d(inp, torch.from_numpy(weight),
                                     torch.from_numpy(self.arrays[prefix + "bias"])).numpy()
                else:
                    # Integer products and sums are exactly representable in
                    # float64 at these bounds. This is an arithmetic oracle,
                    # not a speed or hardware-utilization measurement.
                    acc = F.conv2d(torch.from_numpy(args[0].astype(np.float64)),
                                   torch.from_numpy(weight.astype(np.float64)),
                                   stride=op["stride"], padding=op["pad"]).numpy().astype(np.int64)
                    acc += self.arrays[prefix + "bias"][None, :, None, None]
                    if np.any(acc > 2**31 - 1) or np.any(acc < -(2**31)):
                        raise OverflowError(f"accumulator {op['module']}")
                    q = np.clip(requant(acc, self.arrays[prefix + "multiplier"][None, :, None, None]),
                                -128, 127).astype(np.int16)
                    value = self.arrays[prefix + "lut"][q + 128]
            elif op["name"] in ("ADD", "CONCAT"):
                ratios = [round_away(s / sy * (1 << 24)).item() for s in op["input_scales"]]
                scaled = [a.astype(np.int64) * m for a, m in zip(args, ratios)]
                total = scaled[0] + scaled[1] if op["name"] == "ADD" else np.concatenate(scaled, 1)
                value = np.clip(requant(total, 1, 24), -128, 127).astype(np.int8)
            elif op["name"] == "MAXPOOL":
                value = F.max_pool2d(torch.from_numpy(args[0].astype(np.float32)),
                                     op["k"], op["stride"], op["k"] // 2).numpy().astype(np.int8)
            elif op["name"] == "UPSAMPLE":
                value = np.repeat(np.repeat(args[0], 2, axis=2), 2, axis=3)
            else:
                raise ValueError(op["name"])
            values.append(value)
            if callback:
                callback(op, value)
        return [values[i] for i in graph["outputs"]]

    def decode(self, image_path, confidence=0.25, iou_threshold=0.45, float_reference=False):
        image, ratio, (pad_x, pad_y) = preprocess(image_path, self.graph["size"])
        if float_reference:
            raw = [v.detach().numpy().transpose(0, 1, 4, 2, 3).reshape(
                1, -1, v.shape[2], v.shape[3]) for v in self.model(image)[1]]
        else:
            raw = self.execute(image)
        # Reuse only the trained head's anchors/stride and standard decode,
        # not its convolutions; raw is produced by the deployment executor.
        detect = self.model.model[-1]
        boxes, scores = [], []
        nc = 6
        for h, output in enumerate(raw):
            _, _, height, width = output.shape
            y = torch.sigmoid(torch.from_numpy(output).view(1, 3, nc + 5, height, width)
                              .permute(0, 1, 3, 4, 2))
            gy, gx = torch.meshgrid(torch.arange(height), torch.arange(width), indexing="ij")
            grid = torch.stack((gx, gy), 2)[None, None]
            stride = detect.stride[h]
            xy = (y[..., :2] * 2 - 0.5 + grid) * stride
            wh = (y[..., 2:4] * 2).square() * (detect.anchors[h] * stride)[None, :, None, None]
            boxes.append(torch.cat((xy - wh / 2, xy + wh / 2), -1).reshape(-1, 4))
            scores.append((y[..., 4:5] * y[..., 5:]).reshape(-1, nc))
        from torchvision.ops import nms
        all_boxes, all_scores = torch.cat(boxes), torch.cat(scores)
        names = ["biodegradable", "cardboard", "glass", "metal", "paper", "plastic"]
        results = []
        for cls, name in enumerate(names):
            selected = (all_scores[:, cls] >= confidence).nonzero().flatten()
            keep = nms(all_boxes[selected], all_scores[selected, cls], iou_threshold)
            for k in selected[keep[:100]].tolist():
                b = all_boxes[k].tolist()
                results.append(dict(
                    **{"class": name}, score=float(all_scores[k, cls]),
                    box=[(b[0] - pad_x) / ratio, (b[1] - pad_y) / ratio,
                         (b[2] - pad_x) / ratio, (b[3] - pad_y) / ratio]))
        return sorted(results, key=lambda x: -x["score"])[:100]


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", type=Path, default=ROOT / "gen/integration/deployment")
    parser.add_argument("--calibrate", type=int, default=0)
    parser.add_argument("--image", type=Path)
    args = parser.parse_args()
    torch.set_num_threads(4)
    with torch.no_grad():
        if args.calibrate:
            calibrate(args.out, args.calibrate)
        if args.image:
            print(json.dumps(Deployment(args.out).decode(args.image), indent=1))
