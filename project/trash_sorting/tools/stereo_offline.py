"""PC-only stereo calibration and depth diagnostics. Does not access the board.

Input manifest: {"pairs": [{"left": "L.png", "right": "R.png", ...}]}.
Paths are relative to the manifest. Depth additionally requires exposure-center
left_timestamp_ms/right_timestamp_ms in a common clock, not file/USB timestamps.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path

import cv2
import numpy as np


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_pairs(path):
    data = json.loads(path.read_text(encoding="utf8"))
    result, seen = [], set()
    for pair in data["pairs"]:
        files = [(path.parent / pair[k]).resolve() for k in ("left", "right")]
        images = [cv2.imread(str(p), cv2.IMREAD_GRAYSCALE) for p in files]
        if any(im is None for im in images) or images[0].shape != images[1].shape:
            raise ValueError("Unreadable images or unequal pair resolution")
        hashes = tuple(digest(p) for p in files)
        if hashes[0] == hashes[1] or any(h in seen for h in hashes):
            raise ValueError("Repeated image: calibration requires distinct stereo views")
        seen.update(hashes)
        result.append((pair, images, hashes))
    if not result:
        raise ValueError("Empty pair manifest")
    if any(p[1][0].shape != result[0][1][0].shape for p in result):
        raise ValueError("All images must use the same resolution")
    return data, result


def fit_calibration(objects, left, right, size):
    flags = cv2.CALIB_FIX_K3
    l_rms, kl, dl, _, _ = cv2.calibrateCamera(objects, left, size, None, None, flags=flags)
    r_rms, kr, dr, _, _ = cv2.calibrateCamera(objects, right, size, None, None, flags=flags)
    rms, kl, dl, kr, dr, rot, trans, _, _ = cv2.stereoCalibrate(
        objects, left, right, kl, dl, kr, dr, size,
        flags=cv2.CALIB_FIX_INTRINSIC,
        criteria=(cv2.TERM_CRITERIA_EPS + cv2.TERM_CRITERIA_COUNT, 100, 1e-7))
    rl, rr, pl, pr, q, roi_l, roi_r = cv2.stereoRectify(
        kl, dl, kr, dr, size, rot, trans, flags=cv2.CALIB_ZERO_DISPARITY, alpha=0)
    errors = []
    for a, b in zip(left, right):
        al = cv2.undistortPoints(a, kl, dl, R=rl, P=pl)
        br = cv2.undistortPoints(b, kr, dr, R=rr, P=pr)
        errors.extend(np.abs(al[:, 0, 1] - br[:, 0, 1]).tolist())
    return dict(kl=kl, dl=dl, kr=kr, dr=dr, rl=rl, rr=rr, pl=pl, pr=pr,
                q=q, size=np.array(size), roi_l=np.array(roi_l), roi_r=np.array(roi_r)), dict(
        left_rms_px=float(l_rms), right_rms_px=float(r_rms), stereo_rms_px=float(rms),
        epipolar_p95_px=float(np.percentile(errors, 95)),
        baseline_mm=float(np.linalg.norm(trans)))


def calibrate(args):
    _, pairs = load_pairs(args.manifest)
    pattern = tuple(args.board)
    grid = np.zeros((pattern[0] * pattern[1], 3), np.float32)
    grid[:, :2] = np.mgrid[0:pattern[0], 0:pattern[1]].T.reshape(-1, 2) * args.square_mm
    objects, left, right, inventory = [], [], [], []
    for item, images, hashes in pairs:
        corners = [cv2.findChessboardCornersSB(im, pattern, cv2.CALIB_CB_NORMALIZE_IMAGE)
                   for im in images]
        accepted = all(c[0] for c in corners)
        inventory.append(dict(left=item["left"], right=item["right"], sha256=hashes,
                              corners_found=accepted))
        if accepted:
            objects.append(grid.copy())
            left.append(corners[0][1])
            right.append(corners[1][1])
    if len(objects) < 12:
        raise ValueError(f"Only {len(objects)} usable pairs; need at least 12 diverse poses")
    size = pairs[0][1][0].shape[::-1]
    arrays, quality = fit_calibration(objects, left, right, size)
    reasons = []
    if not all(np.isfinite(v) for v in quality.values()) or not all(
            np.isfinite(v).all() for v in arrays.values()):
        reasons.append("nonfinite calibration result")
    if abs(quality["baseline_mm"] / args.baseline_mm - 1) > .20:
        reasons.append("baseline differs by more than 20% from measured spacing")
    if max(quality[k] for k in ("left_rms_px", "right_rms_px", "stereo_rms_px")) > 1:
        reasons.append("reprojection RMS exceeds 1 pixel")
    if quality["epipolar_p95_px"] > 1:
        reasons.append("rectified vertical mismatch p95 exceeds 1 pixel")
    if arrays["pr"][0, 3] >= 0 or abs(arrays["pr"][1, 3]) > 1e-3:
        reasons.append("expected horizontal stereo: check left/right assignment")
    report = dict(status="REJECTED" if reasons else "OFFLINE_CALIBRATION_ONLY",
                  reasons=reasons, quality=quality, pairs=inventory,
                  manifest_sha256=digest(args.manifest), square_mm=args.square_mm,
                  board_inner_corners=pattern, measured_baseline_mm=args.baseline_mm,
                  physical_distance_verified=False, board_modified=False)
    (args.output / "calibration.json").write_text(json.dumps(report, indent=2), encoding="utf8")
    if reasons:
        raise ValueError("Calibration rejected: " + "; ".join(reasons))
    np.savez_compressed(args.output / "calibration.npz", **arrays)
    report["calibration_sha256"] = digest(args.output / "calibration.npz")
    (args.output / "calibration.json").write_text(json.dumps(report, indent=2), encoding="utf8")
    print(json.dumps(report["quality"], indent=2))


def depth_roi(left, right, q, roi, max_disparity=128, valid_rois=None):
    """Dense diagnostic with reverse consistency. Invalid pixels never become far/near."""
    if max_disparity < 16 or max_disparity % 16 or max_disparity >= left.shape[1]:
        raise ValueError("Disparity range must be a multiple of 16 below image width")
    x, y, w, h = roi
    if min(x, y) < 0 or min(w, h) <= 0 or x + w > left.shape[1] or y + h > left.shape[0]:
        raise ValueError("ROI outside rectified left image")
    def matcher(minimum):
        return cv2.StereoSGBM_create(minDisparity=minimum, numDisparities=max_disparity,
            blockSize=5, P1=8*25, P2=32*25, uniquenessRatio=12,
            speckleWindowSize=50, speckleRange=2, disp12MaxDiff=1)
    dl = matcher(0).compute(left, right).astype(np.float32) / 16
    dr = matcher(-max_disparity).compute(right, left).astype(np.float32) / 16
    yy, xx = np.indices(dl.shape)
    rx = np.rint(xx - dl).astype(int)
    inside = (rx >= 0) & (rx < dl.shape[1])
    reverse = dr[yy, np.clip(rx, 0, dl.shape[1]-1)]
    xyz = cv2.reprojectImageTo3D(dl, q)
    texture = cv2.boxFilter(left.astype(np.float32)**2, -1, (5, 5)) - cv2.boxFilter(
        left.astype(np.float32), -1, (5, 5))**2
    mask = (inside & (dl > 0) & (dl < max_disparity-1) & (reverse < 0) &
            (np.abs(dl + reverse) <= 1) & (texture > 25) &
            np.isfinite(xyz).all(axis=2) & (xyz[:, :, 2] > 0))
    if valid_rois is not None:
        lx, ly, lw, lh = valid_rois[0]
        rx0, ry0, rw, rh = valid_rois[1]
        mask &= ((xx >= lx) & (xx < lx+lw) & (yy >= ly) & (yy < ly+lh) &
                 (rx >= rx0) & (rx < rx0+rw) & (yy >= ry0) & (yy < ry0+rh))
    selected = mask[y:y+h, x:x+w]
    depths = xyz[y:y+h, x:x+w, 2][selected]
    fraction = float(selected.mean())
    if len(depths) < 100 or fraction < .25:
        return dict(status="UNKNOWN", valid_fraction=fraction, valid_pixels=len(depths))
    low, median, high = np.percentile(depths, [10, 50, 90])
    # A broad/mixed ROI is not a reliable object distance.
    stable = high - low <= max(20, .15 * median)
    return dict(status="DEPTH_DIAGNOSTIC" if stable else "UNKNOWN",
                valid_fraction=fraction, valid_pixels=len(depths),
                depth_p10_mm=float(low), depth_median_mm=float(median), depth_p90_mm=float(high),
                diagnostic_within_200mm=bool(high <= 200) if stable else None,
                physical_distance_verified=False)


def measure(args):
    data, pairs = load_pairs(args.manifest)
    if data.get("timestamp_source") != "exposure_common_clock":
        raise ValueError("Need exposure timestamps in a common clock, not file/USB timestamps")
    report_path = args.calibration.with_suffix(".json")
    report = json.loads(report_path.read_text(encoding="utf8"))
    if report["status"] != "OFFLINE_CALIBRATION_ONLY":
        raise ValueError("Calibration was rejected")
    if report["calibration_sha256"] != digest(args.calibration):
        raise ValueError("Calibration arrays differ from quality report")
    with np.load(args.calibration, allow_pickle=False) as cal:
        size = tuple(int(v) for v in cal["size"])
        maps = [cv2.initUndistortRectifyMap(cal["k"+side], cal["d"+side], cal["r"+side],
                cal["p"+side], size, cv2.CV_32FC1) for side in ("l", "r")]
        results = []
        for pair, images, hashes in pairs:
            if images[0].shape[::-1] != size:
                raise ValueError("Calibration resolution mismatch; do not silently resize")
            timestamps = np.array([pair["left_timestamp_ms"], pair["right_timestamp_ms"]], float)
            if not np.isfinite(timestamps).all():
                raise ValueError("Nonfinite exposure timestamps")
            skew = float(abs(timestamps[0] - timestamps[1]))
            if skew > 5:
                outcome = dict(status="UNKNOWN", reason="exposure skew exceeds 5 ms")
            else:
                rectified = [cv2.remap(im, *m, cv2.INTER_LINEAR) for im, m in zip(images, maps)]
                outcome = depth_roi(*rectified, cal["q"], args.roi, args.max_disparity,
                                    (cal["roi_l"], cal["roi_r"]))
            results.append(dict(left=pair["left"], right=pair["right"], sha256=hashes,
                                exposure_skew_ms=skew, **outcome))
    payload = dict(calibration_sha256=digest(args.calibration),
                   manifest_sha256=digest(args.manifest), rectified_left_roi=args.roi,
                   board_modified=False, results=results)
    (args.output / "depth.json").write_text(json.dumps(payload, indent=2), encoding="utf8")
    print(json.dumps(payload, indent=2))


def main():
    p = argparse.ArgumentParser(description=__doc__)
    sub = p.add_subparsers(dest="mode", required=True)
    for mode in ("calibrate", "measure"):
        s = sub.add_parser(mode)
        s.add_argument("--manifest", type=Path, required=True)
        s.add_argument("--output", type=Path, required=True, help="New, unused output directory")
        if mode == "calibrate":
            s.add_argument("--board", type=int, nargs=2, required=True, help="Inner corners columns rows")
            s.add_argument("--square-mm", type=float, required=True)
            s.add_argument("--baseline-mm", type=float, default=30)
        else:
            s.add_argument("--calibration", type=Path, required=True)
            s.add_argument("--roi", type=int, nargs=4, required=True, help="Rectified left x y width height")
            s.add_argument("--max-disparity", type=int, default=128)
    args = p.parse_args()
    if args.mode == "calibrate" and (min(args.board) < 3 or
            not math.isfinite(args.square_mm) or not math.isfinite(args.baseline_mm) or
            args.square_mm <= 0 or args.baseline_mm <= 0):
        p.error("Need positive measured dimensions and at least 3 inner corners each way")
    args.output.mkdir(parents=True, exist_ok=False)
    (calibrate if args.mode == "calibrate" else measure)(args)


if __name__ == "__main__":
    main()
