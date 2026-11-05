"""Detection metrics on an independent, annotated dataset.

The 12-image smoke set in `eval_yolov5n.py` only says "a box appears".  This
script uses the validation split of data/garbage_datasets, which has YOLO box
labels, and restricts it to classes that map unambiguously onto the six classes
the selected checkpoint was trained on.

The 40 -> 6 mapping is deliberately conservative.  Anything not listed is
excluded from the scored images, so an unlabelled "battery" is never counted as
a false positive of "metal".

Output: AP@0.5 per class, TP/FP/FN at a fixed confidence, and how many scored
images have more than one ground-truth box (multi-object).
"""
import argparse
import json
import sys
from collections import defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from eval_yolov5n import detect, load_model, NAMES  # noqa: E402

def build_qfeat(size, calib_n=256):
    """Return (quantised feature extractor, Detect head) for --quant."""
    import torch
    from torch.ao.quantization import get_default_qconfig
    from torch.ao.quantization.quantize_fx import prepare_fx, convert_fx
    from quant_yolov5n import FeatureExtractor, preprocess, CKPT
    sd = torch.load(CKPT, map_location="cpu", weights_only=False)
    model = sd["model"].float().eval()
    feat = FeatureExtractor(model.model[:-1]).eval()
    paths = sorted((ROOT / "data/images/indomain_test").glob("*.jpg"))
    man = ROOT / "data/g4/train.json"
    if man.exists():
        import json as _j
        for e in list(_j.loads(man.read_text(encoding="utf-8")).values()):
            p = ROOT / e["img"].replace("\\", "/")
            if p.exists():
                paths.append(p)
            if len(paths) >= calib_n:
                break
    paths = paths[:calib_n]
    prep = prepare_fx(feat, {"": get_default_qconfig("fbgemm")},
                      (preprocess(paths[0], size)[0],))
    with torch.no_grad():
        for p in paths:
            prep(preprocess(p, size)[0])
    return convert_fx(prep).eval(), model.model[-1]

import yaml

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data/garbage_datasets"

# 40-class names -> model class.  Cardboard/GlassCup/Cans/PaperBags/bottles and
# kitchen waste have a one-to-one meaning; mixed-material "recyclable" classes
# (Toys, OldClothes, Powerbank ...) are left out instead of being guessed.
MAP40 = {
    "Cardboard": "cardboard",
    "GlassCup": "glass",
    "Can": "metal",
    "MetalFoodCans": "metal",
    "Pot": "metal",
    "PaperBags": "paper",
    "Bottle": "plastic",
    "DrinkBottle": "plastic",
    "ShampooBottle": "plastic",
    "CosmeticBottles": "plastic",
    "Meal": "biodegradable",
    "Bone": "biodegradable",
    "FruitPeel": "biodegradable",
    "Pulp": "biodegradable",
    "Tea": "biodegradable",
    "Vegetable": "biodegradable",
    "Eggshell": "biodegradable",
    "FishBone": "biodegradable",
}


def iou(a, b):
    x1, y1 = max(a[0], b[0]), max(a[1], b[1])
    x2, y2 = min(a[2], b[2]), min(a[3], b[3])
    iw, ih = max(0.0, x2 - x1), max(0.0, y2 - y1)
    inter = iw * ih
    area = max(0.0, a[2] - a[0]) * max(0.0, a[3] - a[1]) + \
        max(0.0, b[2] - b[0]) * max(0.0, b[3] - b[1]) - inter
    return inter / area if area > 0 else 0.0


def ap50(records, cls):
    """All-point interpolated AP for one class."""
    npos = sum(1 for r in records for g in r["gt"] if g["class"] == cls)
    if npos == 0:
        return None, 0, 0, 0
    dets = []
    for r in records:
        for d in r["dets"]:
            dets.append((d["score"], d["class"] == cls, d["class"], d["box"], r))
    dets.sort(key=lambda t: -t[0])
    used = defaultdict(set)
    tp = fp = 0
    points = []
    for score, is_cls, dcls, box, r in dets:
        if not is_cls:
            continue
        best, bi = 0.0, -1
        for i, g in enumerate(r["gt"]):
            if g["class"] != cls:
                continue
            v = iou(box, g["box"])
            if v > best:
                best, bi = v, i
        if best >= 0.5 and bi not in used[r["image"]]:
            used[r["image"]].add(bi)
            tp += 1
        else:
            fp += 1
        points.append((tp / max(1, npos), tp / max(1, tp + fp)))
    if not points:
        return 0.0, 0, fp, npos
    # precision envelope from the right
    best_p = 0.0
    env = []
    for rec, prec in reversed(points):
        best_p = max(best_p, prec)
        env.append((rec, best_p))
    env.reverse()
    ap = 0.0
    prev_r = 0.0
    for rec, prec in env:
        ap += (rec - prev_r) * prec
        prev_r = rec
    return ap, tp, fp, npos


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--size", type=int, default=320)
    ap.add_argument("--conf", type=float, default=0.25)
    ap.add_argument("--limit", type=int, default=300)
    ap.add_argument("--per-class", type=int, default=40)
    ap.add_argument("--tag", default="val320")
    ap.add_argument("--quant", action="store_true")
    ap.add_argument("--deployment", type=Path)
    ap.add_argument("--deployment-float", action="store_true")
    a = ap.parse_args()

    names = yaml.safe_load((DATA / "data.yaml").read_text(encoding="utf-8"))["names"]
    img_dir = DATA / "datasets/images/val"
    lbl_dir = DATA / "datasets/labels/val"
    model = load_model()
    deployment = None
    if a.deployment:
        from deployment_bundle import Deployment
        import torch
        torch.set_num_threads(4)
        deployment = Deployment(a.deployment)
    qfeat = qdet = None
    if a.quant:
        from quant_yolov5n import preprocess as qpre, decode as qdecode
        qfeat, qdet = build_qfeat(a.size)

    # Preselect a class-balanced subset: taking the first N files in name order
    # left cardboard/glass with zero scored images.
    want = defaultdict(int)
    chosen = []
    for img in sorted(img_dir.glob("*.jpg")):
        lbl = lbl_dir / (img.stem + ".txt")
        if not lbl.exists():
            continue
        present = set()
        good = True
        for line in lbl.read_text().splitlines():
            p = line.split()
            if len(p) != 5:
                continue
            cname = names[int(p[0])]
            if cname not in MAP40:
                good = False
                break
            present.add(MAP40[cname])
        if not good or not present:
            continue
        if all(want[c] >= a.per_class for c in present):
            continue
        for c in present:
            want[c] += 1
        chosen.append(img)
        if len(chosen) >= a.limit:
            break
    print("preselected", len(chosen), dict(want), flush=True)

    records = []
    skipped = 0
    multi = 0
    for img in chosen:
        lbl = lbl_dir / (img.stem + ".txt")
        if not lbl.exists():
            skipped += 1
            continue
        gts = []
        ok = True
        for line in lbl.read_text().splitlines():
            p = line.split()
            if len(p) != 5:
                continue
            cname = names[int(p[0])]
            if cname not in MAP40:
                ok = False
                break
            cx, cy, w, h = map(float, p[1:])
            W, H = 1.0, 1.0
            gts.append({"class": MAP40[cname],
                        "box": [(cx - w / 2) * W, (cy - h / 2) * H,
                                (cx + w / 2) * W, (cy + h / 2) * H]})
        if not ok or not gts:
            skipped += 1
            continue
        import cv2
        im = cv2.imread(str(img))
        if im is None:
            skipped += 1
            continue
        h, w = im.shape[:2]
        for g in gts:
            g["box"] = [g["box"][0] * w, g["box"][1] * h,
                        g["box"][2] * w, g["box"][3] * h]
        if deployment is not None:
            import torch
            with torch.no_grad():
                dets = deployment.decode(img, a.conf, 0.45,
                                         float_reference=a.deployment_float)
        elif a.quant:
            from quant_yolov5n import decode as qdecode
            import torch as _t
            qx, qr, qpad = qpre(img, a.size)
            with _t.no_grad():
                qf = qfeat(qx)
            dets = qdecode(qf, qdet, None, a.size, a.conf, 0.45)
            # quant_yolov5n.decode returns boxes in the *letterboxed* frame.
            # Ground truth here is in original-image pixels, so an un-rescaled
            # box is compared against a differently scaled GT and every IoU
            # collapses to ~0.  Earlier runs reported mAP 0.0523 for exactly
            # this reason; it was a measurement bug, not a quantisation loss.
            _px, _py = qpad
            for _d in dets:
                _b = _d["box"]
                _d["box"] = [(_b[0] - _px) / qr, (_b[1] - _py) / qr,
                             (_b[2] - _px) / qr, (_b[3] - _py) / qr]
        else:
            dets = detect(model, im, a.size, a.conf, 0.45)
        records.append({"image": img.name, "gt": gts, "dets": dets})
        if deployment is not None and len(records) % 20 == 0:
            print("evaluated", len(records), "/", len(chosen), flush=True)
        if len(gts) > 1:
            multi += 1


    per = {}
    for cls in NAMES:
        apv, tp, fp, npos = ap50(records, cls)
        if apv is not None:
            per[cls] = {"ap50": round(apv, 4), "tp": tp, "fp": fp, "gt": npos}
    valid = [v["ap50"] for v in per.values()]
    backend = ("deployment-fp32" if a.deployment_float else "deployment-q15") if deployment else (
        "int8-fbgemm" if a.quant else "fp32")
    result = {"size": a.size, "conf": a.conf, "backend": backend,
              "images": len(records),
              "multi_object_images": multi, "skipped": skipped,
              "map50": round(sum(valid) / len(valid), 4) if valid else None,
              "per_class": per, "mapping_40_to_6": MAP40}
    out = ROOT / "results" / ("yolov5n_" + a.tag)
    out.mkdir(parents=True, exist_ok=True)
    (out / "metrics.json").write_text(json.dumps(result, indent=1), encoding="utf-8")
    if deployment is not None:
        (out / "predictions.json").write_text(json.dumps(records), encoding="utf-8")
    print(json.dumps({k: result[k] for k in
                      ("images", "multi_object_images", "map50", "per_class")}, indent=1))


if __name__ == "__main__":
    main()
