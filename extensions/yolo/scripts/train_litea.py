"""Train Lite-A on the cleaned 4-class set.

Deliberately compact: one anchor per ground-truth (best IoU), BCE for objectness
and class, smooth-L1 for the box offsets, class weights for the hazardous bin
which is only ~2.4% of the boxes. This is not the full YOLO loss, and the report
must say so, but it trains the exact Lite-A topology that the hardware executes.

Usage:
  python scripts/train_litea.py --epochs 3 --limit 400 --batch 8     # smoke test
  python scripts/train_litea.py --epochs 30                          # real run
"""

from __future__ import annotations

import argparse
import json
import math
import os
import sys
import time

import numpy as np
import torch
import torch.nn as nn
import torch.nn.functional as F
from PIL import Image, ImageFile

ImageFile.LOAD_TRUNCATED_IMAGES = True

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from litea_model import A1, A2, INPUT, NA, NC, LiteA  # noqa: E402

MEAN = np.array([0.485, 0.456, 0.406], dtype=np.float32)
STD = np.array([0.229, 0.224, 0.225], dtype=np.float32)


def iou_wh(a, b):
    aw, ah = a
    bw, bh = b
    inter = min(aw, bw) * min(ah, bh)
    return inter / (aw * ah + bw * bh - inter + 1e-9)


def load_manifest(path):
    with open(path) as f:
        return json.load(f)


def filter_valid(manifest, tag):
    """Drop images PIL cannot open. The source set contains at least one
    truncated jpeg (img_15267.jpg) that killed a run at step 380; failing fast on
    a bad sample mid-epoch is far worse than skipping it up front."""
    good, bad = {}, []
    for k, v in manifest.items():
        try:
            with Image.open(v["img"]) as im:
                im.verify()
            good[k] = v
        except Exception:
            bad.append(k)
    if bad:
        print(f"{tag}: dropped {len(bad)} unreadable images, e.g. {bad[:5]}", flush=True)
    return good


class G4(torch.utils.data.Dataset):
    def __init__(self, manifest):
        self.items = list(manifest.values())

    def __len__(self):
        return len(self.items)

    def __getitem__(self, i):
        # One truncated jpeg should not kill an epoch. Walk forward until a
        # sample loads; the set has a handful of these.
        last = None
        for off in range(8):
            it = self.items[(i + off) % len(self.items)]
            try:
                img = Image.open(it["img"]).convert("RGB").resize((INPUT, INPUT))
                break
            except Exception as e:      # noqa: BLE001
                last = e
                continue
        else:
            raise RuntimeError(f"could not load any image near index {i}: {last}")
        x = np.asarray(img, dtype=np.float32) / 255.0
        x = (x - MEAN) / STD
        boxes = []
        for line in open(it["labels"]):
            p = line.split()
            if len(p) < 5:
                continue
            c = int(float(p[0]))
            cx, cy, w, h = (float(v) for v in p[1:5])
            boxes.append((c, cx, cy, w, h))
        return torch.from_numpy(x).permute(2, 0, 1), boxes


def collate(batch):
    xs = torch.stack([b[0] for b in batch])
    return xs, [b[1] for b in batch]


def build_target(boxes, g, anchors, device):
    """obj[g,g,3], cls[g,g,3,nc], tbox[g,g,3,4] for one image."""
    # layout matches the model output [A, g, g, ...]
    obj = torch.zeros(NA, g, g, device=device)
    cls = torch.zeros(NA, g, g, NC, device=device)
    tbox = torch.zeros(NA, g, g, 4, device=device)
    # A cell holds up to NA objects, one per anchor.  Taking the global best
    # anchor for every GT silently drops every ground truth after the first that
    # lands in the same cell+anchor, which is why dense scenes (kitchen, ~5 boxes
    # per image on a 4x4 grid) never learned.
    used = {}
    for (c, cx, cy, w, h) in boxes:
        gi0 = min(g - 1, max(0, int(cx * g)))
        gj0 = min(g - 1, max(0, int(cy * g)))
        taken = used.setdefault((gj0, gi0), set())
        best, bi = -1.0, -1
        for ai, (aw, ah) in enumerate(anchors):
            if ai in taken:
                continue
            i = iou_wh((w, h), (aw / INPUT, ah / INPUT))
            if i > best:
                best, bi = i, ai
        if bi < 0:
            continue                      # cell already holds NA objects
        gi = min(g - 1, max(0, int(cx * g)))
        gj = min(g - 1, max(0, int(cy * g)))
        tx = cx * g - gi
        ty = cy * g - gj
        aw, ah = anchors[bi][0] / INPUT, anchors[bi][1] / INPUT
        tw = math.log(max(w, 1e-6) / aw + 1e-9)
        th = math.log(max(h, 1e-6) / ah + 1e-9)
        taken.add(bi)
        obj[bi, gj, gi] = 1.0
        cls[bi, gj, gi, c] = 1.0
        tbox[bi, gj, gi] = torch.tensor([tx, ty, tw, th], device=device)
    return obj, cls, tbox


def decode(pred, g, anchors):
    """pred[1,C,g,g] -> boxes in xyxy (normalised), scores, classes."""
    p = pred.view(1, NA, 5 + NC, g, g).permute(0, 1, 3, 4, 2)[0]  # [A,g,g,5+nc]
    ys, xs = torch.meshgrid(torch.arange(g, device=pred.device),
                            torch.arange(g, device=pred.device), indexing="ij")
    obj = torch.sigmoid(p[..., 4])
    cx = (torch.sigmoid(p[..., 0]) + xs) / g
    cy = (torch.sigmoid(p[..., 1]) + ys) / g
    # p is [A, g, g, 5+nc] after the permute, so the anchor axis comes first
    aw = torch.tensor([a[0] / INPUT for a in anchors], device=pred.device).view(NA, 1, 1)
    ah = torch.tensor([a[1] / INPUT for a in anchors], device=pred.device).view(NA, 1, 1)
    w = torch.exp(p[..., 2].clamp(-4, 4)) * aw
    h = torch.exp(p[..., 3].clamp(-4, 4)) * ah
    cls_logits = p[..., 5:]
    return cx, cy, w, h, obj, cls_logits


def nms(boxes, scores, iou_thr=0.45):
    order = scores.argsort(descending=True)
    keep = []
    while order.numel() > 0:
        i = order[0]
        keep.append(i.item())
        if order.numel() == 1:
            break
        b = boxes[i]
        rest = boxes[order[1:]]
        xx1 = torch.clamp(b[0] - b[2] / 2, min=0)
        yy1 = torch.clamp(b[1] - b[3] / 2, min=0)
        xx2 = b[0] + b[2] / 2
        yy2 = b[1] + b[3] / 2
        rx1 = torch.clamp(rest[:, 0] - rest[:, 2] / 2, min=0)
        ry1 = torch.clamp(rest[:, 1] - rest[:, 3] / 2, min=0)
        rx2 = rest[:, 0] + rest[:, 2] / 2
        ry2 = rest[:, 1] + rest[:, 3] / 2
        iw = torch.clamp(torch.min(xx2, rx2) - torch.max(xx1, rx1), min=0)
        ih = torch.clamp(torch.min(yy2, ry2) - torch.max(yy1, ry1), min=0)
        inter = iw * ih
        uni = b[2] * b[3] + rest[:, 2] * rest[:, 3] - inter
        iou = inter / (uni + 1e-9)
        order = order[1:][iou < iou_thr]
    return keep


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--epochs", type=int, default=3)
    ap.add_argument("--batch", type=int, default=8)
    ap.add_argument("--lr", type=float, default=1e-3)
    ap.add_argument("--limit", type=int, default=0)
    ap.add_argument("--out", default="results/litea.pt")
    ap.add_argument("--threads", type=int, default=8)
    a = ap.parse_args()
    torch.set_num_threads(a.threads)

    tr = filter_valid(load_manifest("data/g4/train.json"), "train")
    va = filter_valid(load_manifest("data/g4/val.json"), "val")
    if a.limit:
        tr = dict(list(tr.items())[:a.limit])
        va = dict(list(va.items())[:max(32, a.limit // 8)])
    ds_tr = G4(tr)
    ds_va = G4(va)
    os.makedirs(os.path.dirname(a.out), exist_ok=True)

    model = LiteA()
    n_par = sum(p.numel() for p in model.parameters())
    print(f"Lite-A params: {n_par:,} ({n_par/1048576:.3f} M)   "
          f"train {len(ds_tr)}  val {len(ds_va)}")

    # hazardous is a small slice of the boxes; weight it up
    w_cls = torch.tensor([1.0, 1.0, 6.0, 1.5])
    opt = torch.optim.AdamW(model.parameters(), lr=a.lr, weight_decay=1e-4)
    dl = torch.utils.data.DataLoader(ds_tr, batch_size=a.batch, shuffle=True,
                                     collate_fn=collate, num_workers=0)

    g1 = INPUT // 32
    g2 = INPUT // 16

    for ep in range(a.epochs):
        model.train()
        t0 = time.time()
        tot = 0.0
        for bi, (x, boxes) in enumerate(dl):
            o1, c1, b1 = zip(*[build_target(b, g1, A1, x.device) for b in boxes])
            o2, c2, b2 = zip(*[build_target(b, g2, A2, x.device) for b in boxes])
            O1 = torch.stack(o1); C1 = torch.stack(c1); B1 = torch.stack(b1)
            O2 = torch.stack(o2); C2 = torch.stack(c2); B2 = torch.stack(b2)

            p1, p2 = model(x)
            p1 = p1.view(-1, NA, 5 + NC, g1, g1).permute(0, 1, 3, 4, 2)
            p2 = p2.view(-1, NA, 5 + NC, g2, g2).permute(0, 1, 3, 4, 2)

            loss = 0.0
            for p, O, C, B in ((p1, O1, C1, B1), (p2, O2, C2, B2)):
                obj = torch.sigmoid(p[..., 4])
                # background cells outnumber objects ~20:1; without pos_weight the
                # cheapest way to lower the loss is to predict "nothing" everywhere
                l_obj = F.binary_cross_entropy_with_logits(
                    p[..., 4], O, pos_weight=torch.tensor(15.0, device=p.device))
                mask = O > 0.5
                if mask.any():
                    l_cls = F.binary_cross_entropy_with_logits(
                        p[..., 5:][mask], C[mask], weight=w_cls.to(p.device))
                    l_box = F.smooth_l1_loss(p[..., :4][mask], B[mask])
                else:
                    l_cls = torch.zeros((), device=p.device)
                    l_box = torch.zeros((), device=p.device)
                loss = loss + l_obj + 2.0 * l_cls + 5.0 * l_box

            opt.zero_grad()
            loss.backward()
            opt.step()
            tot += loss.item()
            if bi % 20 == 0:
                print(f"  ep{ep} it{bi}/{len(dl)} loss={loss.item():.4f} "
                      f"({(time.time()-t0)/(bi+1):.2f}s/it)", flush=True)
        print(f"epoch {ep} done: mean loss {tot/max(1,len(dl)):.4f} "
              f"in {time.time()-t0:.1f}s", flush=True)
        torch.save({"model": model.state_dict(), "epoch": ep}, a.out)
        print(f"  saved {a.out}", flush=True)


if __name__ == "__main__":
    main()
