"""Compare snapshot sampling on identical simulated 720p scenes, offline.

Scenes are validation images fitted into 1280x720 with known GT transforms.
This diagnoses preprocessing only; it is not field accuracy on people/hands.
"""
import argparse
import json
from pathlib import Path

import cv2
import numpy as np
import torch

from deployment_bundle import Deployment
from eval_yolov5n_labeled import ap50
from gen_vexii_yolo_sim import CLASSES, decode

ROOT = Path(__file__).resolve().parents[1]


def sensor_channels(rgb):
    return rgb.astype(np.uint16) >> np.array([3, 2, 3], dtype=np.uint16)


def expand(channels):
    shifts = np.array([3, 2, 3], dtype=np.uint16)
    return (channels << shifts) | (channels >> (8 - 2 * shifts))


def sample(rgb, mode):
    if mode == "bilinear_rgb888":
        return cv2.resize(rgb, (320, 180), interpolation=cv2.INTER_LINEAR)
    channels = sensor_channels(rgb)
    if mode == "nearest_rgb565":
        channels = channels[::4, ::4]
    elif mode == "center_rgb565":
        channels = channels[2::4, 2::4]
    elif mode == "bilinear_rgb565":
        # The four center pixels at (1,1),(1,2),(2,1),(2,2) per 4x4 cell.
        channels = (channels[1::4, 1::4] + channels[1::4, 2::4] +
                    channels[2::4, 1::4] + channels[2::4, 2::4] + 2) // 4
    else:
        raise ValueError(mode)
    return expand(channels).astype(np.uint8)


def self_check():
    rgb = np.full((720, 1280, 3), [255, 128, 0], dtype=np.uint8)
    for mode in ("nearest_rgb565", "center_rgb565", "bilinear_rgb565"):
        out = sample(rgb, mode)
        assert out.shape == (180, 320, 3)
        assert np.all(out == [255, 130, 0])
    rgb[:] = 0
    rgb[1::4, 1::4] = 255
    rgb[1::4, 2::4] = 255
    assert np.all(sample(rgb, "nearest_rgb565") == 0)
    assert np.all(sample(rgb, "center_rgb565") == 0)
    assert np.all(sample(rgb, "bilinear_rgb565") == [132, 130, 132])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--limit", type=int, default=222)
    parser.add_argument("--out", type=Path, default=ROOT / "sim/camera_sampling")
    parser.add_argument("--self-check", action="store_true")
    args = parser.parse_args()
    self_check()
    if args.self_check:
        print("CAMERA_SAMPLING_ARITHMETIC_PASS")
        return
    if args.limit < 1:
        parser.error("--limit must be positive")
    records = json.loads((ROOT / "results/yolov5n_deployment_q15/predictions.json")
                         .read_text())[:args.limit]
    modes = ("bilinear_rgb888", "nearest_rgb565", "center_rgb565", "bilinear_rgb565")
    results = {mode: [] for mode in modes}
    deployment = Deployment(ROOT / "gen/integration/deployment")
    torch.set_num_threads(4)
    for index, record in enumerate(records):
        path = ROOT / "data/garbage_datasets/datasets/images/val" / record["image"]
        bgr = cv2.imread(str(path))
        if bgr is None:
            raise ValueError(f"Cannot read {path}")
        h, w = bgr.shape[:2]
        scale = min(1280 / w, 720 / h)
        nh, nw = round(h * scale), round(w * scale)
        top, left = (720 - nh) // 2, (1280 - nw) // 2
        scene = np.full((720, 1280, 3), 114, np.uint8)
        scene[top:top + nh, left:left + nw] = cv2.resize(bgr[:, :, ::-1], (nw, nh))
        gt = [dict(g, box=[g["box"][0] * nw / w + left,
                           g["box"][1] * nh / h + top,
                           g["box"][2] * nw / w + left,
                           g["box"][3] * nh / h + top]) for g in record["gt"]]
        for mode in modes:
            canvas = np.full((320, 320, 3), 114, dtype=np.uint16)
            canvas[70:250] = sample(scene, mode)
            q = ((canvas * 127 + 127) // 255).astype(np.int8)
            image = torch.from_numpy(np.ascontiguousarray(
                q.transpose(2, 0, 1)[None].astype(np.float32) / 127))
            with torch.no_grad():
                raw = deployment.execute(image)
            boxes = decode(raw, 1280, 720, .25, 0, 70)
            results[mode].append(dict(image=record["image"], gt=gt, dets=[
                {"class": CLASSES[int(b[5])], "score": b[4], "box": b[:4]}
                for b in boxes]))
        if (index + 1) % 20 == 0:
            print(f"CAMERA_SAMPLING {index + 1}/{len(records)}", flush=True)
    metrics = {}
    for mode, items in results.items():
        per = {name: dict(zip(("ap50", "tp", "fp", "gt"), ap50(items, name)))
               for name in CLASSES}
        aps = [v["ap50"] for v in per.values() if v["ap50"] is not None]
        metrics[mode] = dict(map50=sum(aps) / len(aps), per_class=per)
    report = dict(images=len(records), metrics=metrics, board_verified=False,
                  camera_negative_set_tested=False,
                  note="Simulated letterboxed scenes; fixed confidence .25, IoU .45. "
                       "Not field accuracy, not an automatic deployment decision.")
    args.out.mkdir(parents=True, exist_ok=True)
    (args.out / "result.json").write_text(json.dumps(report, indent=2))
    print("CAMERA_SAMPLING_COMPLETE " + json.dumps(report), flush=True)


if __name__ == "__main__":
    main()
