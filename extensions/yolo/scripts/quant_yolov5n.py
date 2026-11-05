"""INT8 post-training quantisation check for the selected YOLOv5n detector.

Scope
-----
Only the feature extractor (`model.model[:-1]`, layers 0-23) is quantised.  The
three 1x1 detection heads stay FP32 here because the CPU does the final decode
anyway and their cost is small; the accelerator contract only needs int8 feature
maps.  This is stated explicitly so the number is not over-claimed as a fully
integer network.

Scheme: torch.ao FX `fbgemm` -- per-channel symmetric int8 weights, per-tensor
int8 activations -- which is the same family of rules the RTL epilogue already
implements (`(acc*M)>>S`, round-half-away-from-zero).  It is a *feasibility*
check of the numeric loss, not a cycle-accurate model of our datapath.

Calibration uses the indomain test images plus a fixed sample from the training
manifest, never the validation set used for scoring.
"""
import argparse
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

import cv2
import numpy as np
import torch
from torch.ao.quantization.quantize_fx import convert_fx, prepare_fx
from torch.ao.quantization import get_default_qconfig
from torchvision.ops import nms

ROOT = Path(__file__).resolve().parents[1]
CKPT = ROOT / "data/models/yolov5n-garbage.pt"
NAMES = ["biodegradable", "cardboard", "glass", "metal", "paper", "plastic"]


def preprocess(path, size):
    im = cv2.imread(str(path))
    h, w = im.shape[:2]
    r = min(size / h, size / w)
    nh, nw = int(round(h * r)), int(round(w * r))
    canvas = np.full((size, size, 3), 114, np.uint8)
    top, left = (size - nh) // 2, (size - nw) // 2
    canvas[top:top + nh, left:left + nw] = cv2.resize(im, (nw, nh))
    x = canvas[:, :, ::-1].transpose(2, 0, 1)[None].astype(np.float32) / 255.0
    return torch.from_numpy(np.ascontiguousarray(x)), r, (left, top)


class FeatureExtractor(torch.nn.Module):
    """Layers 0..23 with the three Detect inputs returned instead of decoded."""

    def __init__(self, seq):
        super().__init__()
        self.seq = seq

    def forward(self, x):
        saved = []
        for i, m in enumerate(self.seq):
            if m.f != -1:
                if isinstance(m.f, int):
                    x = saved[m.f] if m.f != -1 else x
                else:
                    x = [x if j == -1 else saved[j] for j in m.f]
            x = m(x)
            saved.append(x)
        return saved[17], saved[20], saved[23]


def decode(feats, detect, anchor, size, conf, iou):
    with torch.no_grad():
        out = detect(list(feats))[0][0]
    keep = out[:, 4] > conf
    if not bool(keep.any()):
        return []
    d = out[keep]
    xywh, score, cls = d[:, :4], d[:, 4], d[:, 5:].argmax(1)
    boxes = torch.stack([xywh[:, 0] - xywh[:, 2] / 2, xywh[:, 1] - xywh[:, 3] / 2,
                         xywh[:, 0] + xywh[:, 2] / 2, xywh[:, 1] + xywh[:, 3] / 2], 1)
    kept = []
    for c in cls.unique():
        idx = (cls == c).nonzero(as_tuple=True)[0]
        for k in nms(boxes[idx], score[idx], iou).tolist():
            kept.append((NAMES[int(c)], float(score[idx][k]), boxes[idx][k].tolist()))
    kept.sort(key=lambda t: -t[1])
    return [{"class": c, "score": round(s, 4), "box": [round(v, 1) for v in b]}
            for c, s, b in kept[:20]]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--size", type=int, default=320)
    ap.add_argument("--conf", type=float, default=0.25)
    ap.add_argument("--iou", type=float, default=0.45)
    ap.add_argument("--calib", type=int, default=40)
    ap.add_argument("--tag", default="320")
    a = ap.parse_args()

    sd = torch.load(CKPT, map_location="cpu", weights_only=False)
    model = sd["model"].float().eval()
    detect = model.model[-1]
    anchor = detect.anchors.detach().clone() / detect.stride.view(-1, 1, 1)
    feat = FeatureExtractor(model.model[:-1]).eval()

    calib_paths = sorted((ROOT / "data/images/indomain_test").glob("*.jpg"))
    manifest = ROOT / "data/g4/train.json"
    if manifest.exists():
        import json as _json
        entries = list(_json.loads(manifest.read_text(encoding="utf-8")).values())
        for e in entries:
            p = ROOT / e["img"].replace("\\", "/")
            if p.exists() and p not in calib_paths:
                calib_paths.append(p)
            if len(calib_paths) >= a.calib:
                break
    calib_paths = calib_paths[:a.calib]

    qconfig = get_default_qconfig("fbgemm")
    ex = (preprocess(calib_paths[0], a.size)[0],)
    prepared = prepare_fx(feat, {"": qconfig}, ex)
    with torch.no_grad():
        for p in calib_paths[:a.calib]:
            prepared(preprocess(p, a.size)[0])
    qfeat = convert_fx(prepared).eval()
    print("calibrated on", min(len(calib_paths), a.calib), "images")

    out = {"size": a.size, "conf": a.conf, "iou": a.iou, "calib_images": min(len(calib_paths), a.calib),
           "note": "feature extractor layers 0-23 INT8; Detect heads remain FP32",
           "sets": {}}
    for subset in ("testset", "indomain_test"):
        rows = []
        agree = 0
        for p in sorted((ROOT / "data/images" / subset).glob("*.jpg")):
            x, r, pad = preprocess(p, a.size)
            with torch.no_grad():
                f32 = feat(x)
                fq = qfeat(x)
            d32 = decode(f32, detect, anchor, a.size, a.conf, a.iou)
            dq = decode(fq, detect, anchor, a.size, a.conf, a.iou)
            exp = p.name.split("__")[0]
            agree += (exp in [d["class"] for d in d32]) == (exp in [d["class"] for d in dq])
            rows.append({"image": p.name, "gt": exp,
                         "float": d32[:5], "int8": dq[:5]})
        hits32 = sum(1 for r in rows if r["gt"] in [d["class"] for d in r["float"]])
        hits8 = sum(1 for r in rows if r["gt"] in [d["class"] for d in r["int8"]])
        out["sets"][subset] = {"images": len(rows), "float_hits": hits32,
                               "int8_hits": hits8, "classification_agreement": agree,
                               "rows": rows}
        print("%-14s n=%2d float_hits=%2d int8_hits=%2d class_agree=%2d"
              % (subset, len(rows), hits32, hits8, agree), flush=True)

    d = ROOT / "results" / ("yolov5n_int8_" + a.tag)
    d.mkdir(parents=True, exist_ok=True)
    (d / "compare.json").write_text(json.dumps(out, indent=1), encoding="utf-8")
    torch.save({"state": qfeat.state_dict()}, d / "feature_int8.pt")
    print("saved", d / "compare.json")


if __name__ == "__main__":
    main()
