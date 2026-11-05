"""Export the *executed* YOLOv5n layer table, including C3/SPPF inner convolutions.

The top-level module list only shows "Conv"/"C3"/"SPPF"; writing the accelerator
against that would miss every inner convolution and mis-state the first layer.
This script hooks every Conv2d, records the order they actually run at a fixed
input size, and attaches the owning Conv wrapper's activation.

Outputs (data/layer_table/):
    layers.csv     one row per Conv2d, execution order
    layers.json    same plus hashes and model metadata
"""
import argparse
import csv
import hashlib
import json
import sys
import types
from pathlib import Path

if "ultralytics" not in sys.modules:
    _u = types.ModuleType("ultralytics")
    _cu = types.ModuleType("ultralytics.utils")
    _ch = types.ModuleType("ultralytics.utils.checks")
    _ch.check_requirements = lambda *a, **k: None
    _u.utils = _cu
    _cu.checks = _ch
    sys.modules.update({"ultralytics": _u, "ultralytics.utils": _cu,
                        "ultralytics.utils.checks": _ch})

import torch

ROOT = Path(__file__).resolve().parents[1]
CKPT = ROOT / "data/models/yolov5n-garbage.pt"


def owner_activation(model):
    """id(Conv2d) -> activation class name of the Conv wrapper that owns it."""
    out = {}
    for m in model.modules():
        if hasattr(m, "conv") and isinstance(m.conv, torch.nn.Conv2d):
            out[id(m.conv)] = type(getattr(m, "act", None)).__name__
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--size", type=int, default=320)
    ap.add_argument("--out", default="data/layer_table")
    a = ap.parse_args()

    model = torch.load(CKPT, map_location="cpu", weights_only=False)["model"].float().eval()
    acts = owner_activation(model)
    rows = []

    def hook(mod, inp, out):
        c = mod
        rows.append({
            "order": len(rows),
            "module": mod._m_name,
            "k": c.kernel_size[0],
            "stride": c.stride[0],
            "pad": c.padding[0],
            "groups": c.groups,
            "cin": c.in_channels,
            "cout": c.out_channels,
            "in_h": inp[0].shape[-2], "in_w": inp[0].shape[-1],
            "out_h": out.shape[-2], "out_w": out.shape[-1],
            "params": sum(p.numel() for p in c.parameters()),
            "macs": out.shape[-2] * out.shape[-1] * c.out_channels
                    * c.in_channels * c.kernel_size[0] * c.kernel_size[1] // c.groups,
            "act": acts.get(id(c), "None"),
        })

    handles = []
    for name, m in model.named_modules():
        if isinstance(m, torch.nn.Conv2d):
            m._m_name = name
            handles.append(m.register_forward_hook(hook))
    with torch.no_grad():
        model(torch.zeros(1, 3, a.size, a.size))
    for h in handles:
        h.remove()

    outdir = ROOT / a.out
    outdir.mkdir(parents=True, exist_ok=True)
    cols = ["order", "module", "k", "stride", "pad", "groups", "cin", "cout",
            "in_h", "in_w", "out_h", "out_w", "params", "macs", "act"]
    with (outdir / "layers.csv").open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=cols)
        w.writeheader()
        w.writerows(rows)
    meta = {
        "ckpt": CKPT.relative_to(ROOT).as_posix(),
        "ckpt_sha256": hashlib.sha256(CKPT.read_bytes()).hexdigest(),
        "input_size": a.size,
        "conv_count": len(rows),
        "total_macs": sum(r["macs"] for r in rows),
        "total_conv_params": sum(r["params"] for r in rows),
        "first_layer": rows[0],
        "layers": rows,
    }
    (outdir / "layers.json").write_text(json.dumps(meta, indent=1), encoding="utf-8")
    print("convs=%d  MACs=%.3fM  params=%d" %
          (len(rows), meta["total_macs"] / 1e6, meta["total_conv_params"]))
    print("first:", {k: rows[0][k] for k in ("module", "k", "stride", "pad", "cin", "cout", "act")})


if __name__ == "__main__":
    main()
