"""Measure threshold/geometry tradeoffs on cached predictions, without a board.

This is an experiment, not a firmware policy selector. Garbage-only validation
images cannot establish rejection of people, hands, or other unknown objects.
"""
import argparse
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def overlap(a, b):
    intersection = max(0, min(a[2], b[2]) - max(a[0], b[0])) * max(
        0, min(a[3], b[3]) - max(a[1], b[1]))
    total = max(0, a[2] - a[0]) * max(0, a[3] - a[1]) + max(
        0, b[2] - b[0]) * max(0, b[3] - b[1]) - intersection
    return intersection / total if total > 0 else 0.0


def keep(detection, width, height, confidence, max_area=1.0,
         reject_edge=False):
    x1, y1, x2, y2 = detection["box"]
    score = detection["score"]
    if not all(math.isfinite(v) for v in (x1, y1, x2, y2, score)):
        return False
    clipped_w = max(0, min(width, x2) - max(0, x1))
    clipped_h = max(0, min(height, y2) - max(0, y1))
    if score < confidence or not clipped_w or not clipped_h:
        return False
    if clipped_w * clipped_h > width * height * max_area:
        return False
    if reject_edge and (x1 <= 1 or y1 <= 1 or
                        x2 >= width - 1 or y2 >= height - 1):
        return False
    return True


def evaluate(records, **policy):
    tp = fp = gt = 0
    for record in records:
        gt += len(record["gt"])
        matched = set()
        for detection in sorted(record["dets"], key=lambda d: -d["score"]):
            if not keep(detection, record["width"], record["height"], **policy):
                continue
            options = [(overlap(detection["box"], label["box"]), i)
                       for i, label in enumerate(record["gt"])
                       if i not in matched and
                       label["class"] == detection["class"]]
            best, index = max(options, default=(0, -1))
            if best >= 0.5:
                matched.add(index)
                tp += 1
            else:
                fp += 1
    return dict(tp=tp, fp=fp, fn=gt-tp, gt=gt,
                recall=tp/gt if gt else None,
                precision=tp/(tp+fp) if tp+fp else None)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--predictions", type=Path, default=ROOT /
                        "results/yolov5n_deployment_q15_conf005/predictions.json")
    parser.add_argument("--images", type=Path, default=ROOT /
                        "data/garbage_datasets/datasets/images/val")
    parser.add_argument("--out", type=Path, default=ROOT /
                        "sim/camera_feedback_20261102/policy_scan.json")
    args = parser.parse_args()
    import cv2
    records = json.loads(args.predictions.read_text(encoding="utf-8"))
    if not records:
        raise ValueError("No predictions to evaluate")
    for record in records:
        path = args.images / Path(record["image"]).name
        image = cv2.imread(str(path))
        if image is None:
            raise ValueError(f"Cannot establish original image dimensions: {path}")
        record["height"], record["width"] = image.shape[:2]
    policies = [(f"confidence_{value:.2f}", dict(confidence=value))
                for value in (0.20, 0.25, 0.30, 0.35, 0.40, 0.50)]
    policies += [(f"max_area_{area:.2f}", dict(confidence=0.25, max_area=area))
                 for area in (0.98, 0.95, 0.90, 0.85)]
    policies.append(("reject_any_edge",
                     dict(confidence=0.25, reject_edge=True)))
    results = [dict(name=name, policy=policy, **evaluate(records, **policy))
               for name, policy in policies]
    report = dict(images=len(records), source=str(args.predictions.resolve()),
                  board_tested=False, camera_negative_set_tested=False,
                  note="Fixed-threshold TP/FP/FN, IoU>=0.5; not AP or board accuracy. "
                       "No automatic deployment of a scanned policy.",
                  results=results)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(report, indent=2), encoding="utf-8")
    for item in results:
        print(f'{item["name"]}: TP={item["tp"]} FP={item["fp"]} FN={item["fn"]} '
              f'recall={item["recall"]:.4f} precision={item["precision"]:.4f}')
    print(f"POLICY_SCAN_COMPLETE {args.out}; no firmware thresholds changed")


if __name__ == "__main__":
    main()
