"""Synthetic geometry checks; these are not physical camera acceptance."""
import unittest
import argparse
import hashlib
import json
from pathlib import Path
import tempfile

import cv2
import numpy as np

from stereo_offline import depth_roi, fit_calibration, load_pairs, measure


class StereoGeometry(unittest.TestCase):
    def test_recovers_known_30mm_geometry(self):
        k = np.array([[400., 0, 320], [0, 400, 180], [0, 0, 1]])
        grid = np.zeros((54, 3), np.float32)
        grid[:, :2] = np.mgrid[0:9, 0:6].T.reshape(-1, 2) * 7
        rng = np.random.default_rng(8421)
        objects, left, right = [], [], []
        for _ in range(24):
            rotation = rng.uniform(-.35, .35, 3)
            position = np.array([rng.uniform(-55, 10), rng.uniform(-35, 0), rng.uniform(180, 350)])
            objects.append(grid.copy())
            left.append(cv2.projectPoints(grid, rotation, position, k, None)[0])
            right.append(cv2.projectPoints(grid, rotation, position + [-30, 0, 0], k, None)[0])
        _, quality = fit_calibration(objects, left, right, (640, 360))
        self.assertAlmostEqual(quality["baseline_mm"], 30, delta=.02)
        self.assertLess(quality["epipolar_p95_px"], .01)
        self.assertLess(quality["stereo_rms_px"], .01)

    def fixture(self, disparity):
        k = np.array([[200., 0, 160], [0, 200, 90], [0, 0, 1]])
        q = cv2.stereoRectify(k, np.zeros(5), k, np.zeros(5), (320, 180),
                              np.eye(3), np.array([-30., 0, 0]),
                              flags=cv2.CALIB_ZERO_DISPARITY)[4]
        left = np.random.default_rng(129).integers(0, 256, (180, 320), np.uint8)
        right = np.zeros_like(left)
        right[:, :-disparity] = left[:, disparity:]
        return left, right, q

    def test_known_near_and_far_planes(self):
        for disparity, depth, near in ((40, 150, True), (20, 300, False)):
            result = depth_roi(*self.fixture(disparity), (140, 25, 90, 120), 64)
            self.assertEqual(result["status"], "DEPTH_DIAGNOSTIC")
            self.assertAlmostEqual(result["depth_median_mm"], depth, delta=1)
            self.assertIs(result["diagnostic_within_200mm"], near)

    def test_textureless_unknown(self):
        left, _, q = self.fixture(40)
        left.fill(127)
        result = depth_roi(left, left, q, (140, 25, 90, 120), 64)
        self.assertEqual(result["status"], "UNKNOWN")
        self.assertNotIn("diagnostic_within_200mm", result)

    def test_invalid_roi_and_search_range(self):
        for roi, search in (((300, 0, 50, 50), 64), ((0, 0, 50, 50), 63)):
            with self.assertRaises(ValueError):
                depth_roi(*self.fixture(40), roi, search)

    def test_reversed_views_not_near(self):
        left, right, q = self.fixture(40)
        result = depth_roi(right, left, q, (140, 25, 90, 120), 64)
        self.assertEqual(result["status"], "UNKNOWN")

    def test_calibration_roi_is_enforced(self):
        result = depth_roi(*self.fixture(40), (140, 25, 90, 120), 64,
                           ((0, 0, 10, 10), (0, 0, 10, 10)))
        self.assertEqual(result["status"], "UNKNOWN")
        self.assertEqual(result["valid_pixels"], 0)

    def test_manifest_repetition_and_depth_identity_gates(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            left, right, q = self.fixture(40)
            cv2.imwrite(str(root / "l.png"), left)
            cv2.imwrite(str(root / "r.png"), right)
            pair = dict(left="l.png", right="r.png", left_timestamp_ms=1000,
                        right_timestamp_ms=1000)
            manifest = root / "pairs.json"
            manifest.write_text(json.dumps(dict(pairs=[pair, pair])))
            with self.assertRaisesRegex(ValueError, "Repeated"):
                load_pairs(manifest)
            manifest.write_text(json.dumps(dict(pairs=[pair])))
            args = argparse.Namespace(manifest=manifest, calibration=root/"calibration.npz",
                                      output=root, roi=[140, 25, 90, 120], max_disparity=64)
            with self.assertRaisesRegex(ValueError, "exposure timestamps"):
                measure(args)
            manifest.write_text(json.dumps(dict(pairs=[pair], timestamp_source="exposure_common_clock")))
            report = dict(status="OFFLINE_CALIBRATION_ONLY", calibration_sha256="incorrect")
            args.calibration.write_bytes(b"not accepted arrays")
            (root/"calibration.json").write_text(json.dumps(report))
            with self.assertRaisesRegex(ValueError, "differ"):
                measure(args)
            # Timestamp skew must reject a pair before any stereo matching.
            k = np.array([[200., 0, 160], [0, 200, 90], [0, 0, 1]])
            np.savez(args.calibration, kl=k, kr=k, dl=np.zeros(5), dr=np.zeros(5),
                     rl=np.eye(3), rr=np.eye(3), pl=k, pr=k, q=q, size=[320, 180],
                     roi_l=[0, 0, 320, 180], roi_r=[0, 0, 320, 180])
            report["calibration_sha256"] = hashlib.sha256(args.calibration.read_bytes()).hexdigest()
            (root/"calibration.json").write_text(json.dumps(report))
            pair["right_timestamp_ms"] = 1010
            manifest.write_text(json.dumps(dict(pairs=[pair], timestamp_source="exposure_common_clock")))
            measure(args)
            result = json.loads((root/"depth.json").read_text())["results"][0]
            self.assertEqual(result["status"], "UNKNOWN")
            self.assertIn("skew", result["reason"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
