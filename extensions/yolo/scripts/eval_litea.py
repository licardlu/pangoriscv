"""Evaluate Lite-A on the cleaned val split: per-class AP@0.5 and a confusion count.

Reports per class rather than a single mAP, because HazardousWaste is 2.4% of the
boxes and a pooled number hides whether it works at all.
"""

from __future__ import annotations

import argparse
import json
import os
import sys

import numpy as np
import torch

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from litea_model import A1, A2, INPUT, NA, NC, LiteA  # noqa: E402
from train_litea import MEAN, STD, decode, nms  # noqa: E402

NAMES = ["recyclable", "kitchen", "hazardous", "other"]


def to_xyxy(cx, cy, w, h):
    return torch.stack([cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2], dim=-1)


def iou_mat(a, b):
    """a[N,4], b[M,4] in xyxy normalised."""
    if a.numel() == 0 or b.numel() == 0:
        return torch.zeros(len(a), len(b))
    xx1 = torch.clamp(torch.max(a[:, None, 0], b[None, :, 0]), min=0)
    yy1 = torch.clamp(torch.max(a[:, None, 1], b[None, :, 1]), min=0)
    xx2 = torch.min(a[:, None, 2], b[None, :, 2])
    yy2 = torch.min(a[:, None, 3], b[None, :, 3])
    iw = torch.clamp(xx2 - xx1, min=0)
    ih = torch.clamp(yy2 - yy1, min=0)
    inter = iw * ih
    ua = (a[:, 2] - a[:, 0]) * (a[:, 3] - a[:, 1])
    ub = (b[:, 2] - b[:, 0]) * (b[:, 3] - b[:, 1])
    return inter / (ua[:, None] + ub[None, :] - inter + 1e-9)


def predict(model, x, conf_thr=0.25):
    with torch.no_grad():
        p1, p2 = model(x)
    out = []
    for p, g, anchors in ((p1, INPUT // 32, A1), (p2, INPUT // 16, A2)):
        cx, cy, w, h, obj, cls_logits = decode(p, g, anchors)
        cx = cx.reshape(-1); cy = cy.reshape(-1); w = w.reshape(-1); h = h.reshape(-1)
        obj = obj.reshape(-1)
        cls = torch.sigmoid(cls_logits.reshape(-1, NC))
        score, cid = cls.max(dim=1)
        keep = (obj * score) > conf_thr
        if keep.any():
            boxes = to_xyxy(cx[keep], cy[keep], w[keep], h[keep])
            out.append(torch.cat([boxes, (obj * score)[keep, None],
                                  cid[keep].float()[:, None]], dim=1))
    if not out:
        return torch.zeros(0, 6)
    pred = torch.cat(out, 0)
    # class-aware NMS
    final = []
    for c in range(NC):
        m = pred[:, 5] == c
        if not m.any():
            continue
        p = pred[m]
        keep = nms(p[:, :4], p[:, 4])
        final.append(p[keep])
    return torch.cat(final, 0) if final else torch.zeros(0, 6)


def ap_at_iou(recs, n_gt, thr=0.5):
    """recs: list of (score, tp) for one class; returns AP via all-point interp."""
    if n_gt == 0:
        return float("nan")
    recs.sort(key=lambda r: -r[0])
    tp = np.cumsum([r[1] for r in recs])
    fp = np.cumsum([1 - r[1] for r in recs])
    recall = tp / (n_gt + 1e-9)
    prec = tp / (tp + fp + 1e-9)
    mrec = np.concatenate([[0], recall, [1]])
    mpre = np.concatenate([[1], prec, [0]])
    for i in range(len(mpre) - 2, -1, -1):
        mpre[i] = max(mpre[i], mpre[i + 1])
    idx = np.where(mrec[1:] != mrec[:-1])[0]
    return float(np.sum((mrec[idx + 1] - mrec[idx]) * mpre[idx + 1]))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ckpt", default="results/litea_e20.pt")
    ap.add_argument("--limit", type=int, default=0)
    ap.add_argument("--conf", type=float, default=0.25)
    ap.add_argument("--manifest", default="data/g4/val.json")
    a = ap.parse_args()

    model = LiteA()
    ck = torch.load(a.ckpt, map_location="cpu")
    model.load_state_dict(ck["model"])
    model.eval()
    print(f"loaded {a.ckpt} (epoch {ck.get('epoch')})")

    va = json.load(open(a.manifest))
    items = list(va.values())[: a.limit or None]

    per_cls = {c: [] for c in range(NC)}
    n_gt = {c: 0 for c in range(NC)}
    stats = {c: {"tp": 0, "fp": 0, "fn": 0} for c in range(NC)}

    for n, it in enumerate(items):
        from PIL import Image
        img = Image.open(it["img"]).convert("RGB").resize((INPUT, INPUT))
        arr = np.asarray(img, dtype=np.float32) / 255.0
        arr = (arr - MEAN) / STD
        x = torch.from_numpy(arr).permute(2, 0, 1)[None]

        gt = []
        for line in open(it["labels"]):
            p = line.split()
            if len(p) < 5:
                continue
            c = int(float(p[0]))
            cx, cy, w, h = (float(v) for v in p[1:5])
            gt.append((c, cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2))
        for c, *_ in gt:
            n_gt[c] += 1

        pred = predict(model, x, a.conf)
        used = set()
        if len(gt):
            g = torch.tensor([[b[1], b[2], b[3], b[4]] for b in gt])
            gc = [b[0] for b in gt]
        if n % 100 == 0:
            print(f"  {n}/{len(items)}", flush=True)

        matched_gt = set()
        for row in pred:
            c = int(row[5].item())
            box = row[:4][None]
            best, bj = 0.0, -1
            if len(gt):
                ious = iou_mat(box, g)[0]
                for j in range(len(gt)):
                    if gc[j] != c or j in matched_gt:
                        continue
                    if ious[j] > best:
                        best, bj = float(ious[j]), j
            if bj >= 0 and best >= 0.5:
                matched_gt.add(bj)
                per_cls[c].append((float(row[4]), 1))
                stats[c]["tp"] += 1
            else:
                per_cls[c].append((float(row[4]), 0))
                stats[c]["fp"] += 1
        for j, cc in enumerate(gc):
            if j not in matched_gt:
                stats[cc]["fn"] += 1

    print("\nper-class AP@0.5 on", len(items), "val images")
    aps = []
    for c in range(NC):
        v = ap_at_iou(per_cls[c], n_gt[c])
        aps.append(v)
        s = stats[c]
        print(f"  {NAMES[c]:<11} AP={v:.4f}  gt={n_gt[c]:<5} "
              f"tp={s['tp']:<5} fp={s['fp']:<5} fn={s['fn']}")
    valid = [v for v in aps if not np.isnan(v)]
    print(f"  mAP@0.5 = {np.mean(valid):.4f} over {len(valid)} classes with gt")

    os.makedirs("results", exist_ok=True)
    json.dump({"ckpt": a.ckpt, "n_img": len(items),
               "ap": {NAMES[c]: (None if np.isnan(aps[c]) else aps[c]) for c in range(NC)},
               "map": float(np.mean(valid)) if valid else None,
               "stats": {NAMES[c]: stats[c] for c in range(NC)}},
              open("results/eval_litea.json", "w"), indent=2)
    print("saved results/eval_litea.json")


if __name__ == "__main__":
    main()
