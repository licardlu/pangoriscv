"""Export checked offline geometry for the 320x180 candidate; no board access.

Only CALIBRATED is set. Physical distance and exposure synchronization require
later measured evidence; an offline fit never enables the automatic gate.
"""
import argparse
import hashlib
import json
from pathlib import Path
import numpy as np


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def geometry(arrays, report):
    if report.get('status') != 'OFFLINE_CALIBRATION_ONLY' or report.get('reasons'):
        raise ValueError('Only an accepted offline calibration can be exported')
    quality = report['quality']
    for key in ('left_rms_px', 'right_rms_px', 'stereo_rms_px', 'epipolar_p95_px'):
        if not np.isfinite(quality[key]) or not 0 <= quality[key] <= 1:
            raise ValueError('Calibration quality exceeds one pixel')
    baseline = float(quality['baseline_mm'])
    measured = float(report['measured_baseline_mm'])
    if not np.isfinite([baseline, measured]).all() or min(baseline, measured) <= 0 or abs(baseline/measured-1) > .2:
        raise ValueError('Calibration differs from measured camera spacing')
    if tuple(arrays['size']) != (320, 180):
        raise ValueError('Board snapshot requires native 320x180 calibration')
    cameras = []
    for side in ('l', 'r'):
        k = np.asarray(arrays['k'+side], dtype=float)
        d = np.asarray(arrays['d'+side], dtype=float).reshape(-1)
        r = np.asarray(arrays['r'+side], dtype=float)
        p = np.asarray(arrays['p'+side], dtype=float)
        if k.shape != (3, 3) or r.shape != (3, 3) or p.shape != (3, 4) or d.shape != (5,):
            raise ValueError('Unsupported intrinsic/distortion/rectification format')
        if not all(np.isfinite(a).all() for a in (k, d, r, p)):
            raise ValueError('Nonfinite calibration')
        if min(k[0, 0], k[1, 1], p[0, 0], p[1, 1]) <= 0 or not np.allclose(k[2], (0, 0, 1)) or abs(k[0, 1])+abs(k[1, 0]) > 1e-6:
            raise ValueError('Unsupported skew or invalid intrinsic')
        if not np.allclose(r@r.T, np.eye(3), atol=1e-5) or abs(np.linalg.det(r)-1) > 1e-5:
            raise ValueError('Rectification is not a rotation')
        if not np.allclose(p[2], (0, 0, 1, 0), atol=1e-6) or abs(p[1, 3]) > 1e-3:
            raise ValueError('Only horizontal rectified stereo is supported')
        cameras.append(dict(fx=k[0, 0], fy=k[1, 1], cx=k[0, 2], cy=k[1, 2],
            dist=d, inverse_rectified=r.T@np.linalg.inv(p[:, :3]),
            forward_rectified=p[:, :3]@r))
    pl, pr = arrays['pl'], arrays['pr']
    if abs(pl[0, 3]) > 1e-3 or pr[0, 3] >= 0 or not np.allclose(pl[:, :3], pr[:, :3], atol=1e-4):
        raise ValueError('Need zero-disparity left/right projections in the correct order')
    if abs(abs(pr[0, 3])/pr[0, 0]/baseline-1) > .01:
        raise ValueError('Projection baseline and quality report disagree')
    fb = int(round(abs(pr[0, 3])*256))
    if not 0 < fb <= 0xffffffff:
        raise ValueError('Focal-baseline value outside firmware range')
    return cameras, fb


def number(value):
    text = format(float(value), '.9g')
    return text+('f' if '.' in text or 'e' in text.lower() else '.0f')


def export(calibration, output):
    report_path = calibration.with_suffix('.json')
    report = json.loads(report_path.read_text(encoding='utf8'))
    if report.get('calibration_sha256') != sha(calibration):
        raise ValueError('Array SHA differs from quality report')
    with np.load(calibration, allow_pickle=False) as arrays:
        cameras, fb = geometry(arrays, report)
    lines = ['#ifndef STEREO_CALIBRATION_H', '#define STEREO_CALIBRATION_H',
        '#include "stereo_depth.h"',
        '/* Offline geometry only. Distance and exposure sync are NOT verified.',
        ' * Calibration SHA256: '+sha(calibration)+' */',
        'static const stereo_calibration_t stereo_calibration={',
        ' .width=320,.height=180,.max_disparity=96,.max_skew_ms=5,',
        ' .limit_mm=200,.error_mm=5,.verified=STEREO_CALIBRATED,',
        f' .focal_baseline_q8={fb}u,.camera={{']
    for camera in cameras:
        fields = ['.'+name+'='+number(camera[name]) for name in ('fx', 'fy', 'cx', 'cy')]
        fields += ['.'+name+'={'+','.join(number(x) for x in camera[name].flat)+'}'
                   for name in ('dist', 'inverse_rectified', 'forward_rectified')]
        lines.append(' {'+','.join(fields)+'},')
    lines += [' }};', '#endif', '']
    # Never overwrite a candidate calibration implicitly.
    with output.open('x', encoding='utf8') as handle:
        handle.write('\n'.join(lines))
    return dict(status='OFFLINE_GEOMETRY_EXPORTED_GATE_DISABLED',
        calibration_sha256=sha(calibration), report_sha256=sha(report_path),
        header_sha256=sha(output), physical_distance_verified=False,
        exposure_sync_verified=False, board_modified=False)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--calibration', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    a = p.parse_args()
    print(json.dumps(export(a.calibration, a.output), indent=2))


if __name__ == '__main__':
    main()
