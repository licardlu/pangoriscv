"""Evaluate the local YOLOv5n garbage detector on the fixed image sets.

No ultralytics install: the `yolov5` wheel only needs one symbol from that
package at import time, so a two-line stub keeps the environment small and
avoids pulling a second copy of torch.

The model card for keremberke/yolov5n-garbage reports mAP@0.5 = 0.3199, which is
*not* evidence for our board or our categories.  This script measures what the
weights actually do on the images in data/images, at the resolutions a small
accelerator could afford, and writes both counts and annotated images so the
result can be checked by eye.
"""
import argparse
import json
import sys
import time
import types
from pathlib import Path

# --- stub the single ultralytics symbol yolov5 imports -----------------------
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
from torchvision.ops import nms

ROOT = Path(__file__).resolve().parents[1]
CKPT = ROOT / "data/models/yolov5n-garbage.pt"
# The checkpoint carries nc=6 and names=None, but the pickle still holds the
# ordered list the model was trained with: biodegradable, cardboard, glass,
# metal, paper, plastic.  Using the wrong order silently mislabels every box.
NAMES = ["biodegradable", "cardboard", "glass", "metal", "paper", "plastic"]
# Competition bins.  There is no hazardous class in these weights, which is
# recorded rather than papered over; biodegradable is the kitchen-waste bin.
BIN = {"biodegradable": "kitchen", "cardboard": "recyclable", "glass": "recyclable",
       "metal": "recyclable", "paper": "recyclable", "plastic": "recyclable"}


def letterbox(im, new):
    h, w = im.shape[:2]
    r = min(new / h, new / w)
    nh, nw = int(round(h * r)), int(round(w * r))
    canvas = np.full((new, new, 3), 114, np.uint8)
    top, left = (new - nh) // 2, (new - nw) // 2
    canvas[top:top + nh, left:left + nw] = cv2.resize(im, (nw, nh))
    return canvas, r, (left, top)


def load_model():
    torch_load = torch.load
    sd = torch_load(CKPT, map_location="cpu", weights_only=False)
    model = sd["model"].float().eval()
    return model


@torch.no_grad()
def detect(model, im, size, conf, iou):
    lb, r, (px, py) = letterbox(im, size)
    x = lb[:, :, ::-1].transpose(2, 0, 1)[None].astype(np.float32) / 255.0
    out = model(torch.from_numpy(np.ascontiguousarray(x)))[0][0]  # [N, 5+nc]
    # YOLO confidence is objectness multiplied by the class probability.
    # Using objectness alone over-reports background and disagrees with the
    # deployed decoder, which applies the same final-confidence threshold.
    # Checkpoint variants differ: Detect.eval normally returns probabilities,
    # while an exported raw head returns logits.  Normalize either form.
    def probability(v):
        return v.sigmoid() if bool((v.min() < 0) | (v.max() > 1)) else v
    objectness = probability(out[:, 4])
    class_scores = probability(out[:, 5:])
    class_prob, cls = class_scores.max(1)
    score = objectness * class_prob
    keep = score > conf
    if not bool(keep.any()):
        return []
    det = out[keep]
    # The eval Detect head already returns decoded xywh pixels.
    boxes = torch.stack([det[:, 0] - det[:, 2] / 2, det[:, 1] - det[:, 3] / 2,
                         det[:, 0] + det[:, 2] / 2, det[:, 1] + det[:, 3] / 2], 1)
    cls = cls[keep]
    picked = []
    for c in cls.unique():
        idx = (cls == c).nonzero(as_tuple=True)[0]
        for k in nms(boxes[idx], score[keep][idx], iou).tolist():
            picked.append((int(c), float(score[keep][idx][k]),
                           boxes[idx][k].tolist()))
    picked.sort(key=lambda t: -t[1])
    out_list = []
    for c, s, b in picked:
        b = [(b[0] - px) / r, (b[1] - py) / r, (b[2] - px) / r, (b[3] - py) / r]
        out_list.append({"class": NAMES[c], "bin": BIN[NAMES[c]], "score": round(s, 4),
                         "box": [round(float(v), 1) for v in b]})
    return out_list


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--size", type=int, default=320)
    ap.add_argument("--conf", type=float, default=0.25)
    ap.add_argument("--iou", type=float, default=0.45)
    ap.add_argument("--sets", default="testset,indomain_test")
    ap.add_argument("--tag", default="")
    a = ap.parse_args()

    model = load_model()
    outdir = ROOT / "results" / ("yolov5n_" + (a.tag or str(a.size)))
    outdir.mkdir(parents=True, exist_ok=True)
    report = {"ckpt_sha256": __import__("hashlib").sha256(CKPT.read_bytes()).hexdigest(),
              "size": a.size, "conf": a.conf, "iou": a.iou,
              "names": NAMES, "bin_map": BIN, "sets": {}}

    for subset in a.sets.split(","):
        d = ROOT / "data/images" / subset
        rows = []
        t0 = time.time()
        for fn in sorted(p.name for p in d.iterdir()
                         if p.suffix.lower() in (".jpg", ".jpeg", ".png")):
            im = cv2.imread(str(d / fn))
            if im is None:
                continue
            dets = detect(model, im, a.size, a.conf, a.iou)
            rows.append({"image": fn, "n": len(dets), "dets": dets[:8]})
            canvas = im.copy()
            for t in dets:
                x1, y1, x2, y2 = [int(v) for v in t["box"]]
                cv2.rectangle(canvas, (x1, y1), (x2, y2), (0, 220, 0), 2)
                cv2.putText(canvas, "%s %.2f" % (t["class"], t["score"]),
                            (max(0, x1), max(12, y1 - 4)),
                            cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 220, 0), 1)
            cv2.imwrite(str(outdir / (subset + "__" + fn)), canvas)
        hits = sum(1 for r in rows if r["n"] > 0)
        elapsed = (time.time() - t0) / max(1, len(rows))
        report["sets"][subset] = {"images": len(rows), "with_detection": hits,
                                  "cpu_ms_per_image": round(elapsed * 1000, 1),
                                  "rows": rows}
        print("%-14s images=%2d with_det=%2d  %.1f ms/image (CPU FP32)"
              % (subset, len(rows), hits, elapsed * 1000), flush=True)

    (outdir / "detections.json").write_text(json.dumps(report, indent=1), encoding="utf-8")
    print("saved", outdir / "detections.json")


if __name__ == "__main__":
    main()
