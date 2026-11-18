"""Synthetic host checks only. No serial, FPGA, calibration or physical claims."""
import copy
import hashlib
import json
from pathlib import Path
import struct
import tempfile
import unittest
import numpy as np
from PIL import Image
from capture_stereo_pairs import capture
from export_stereo_calibration import export, geometry


def fixture():
    k = np.array([[200., 0, 160], [0, 200, 90], [0, 0, 1]])
    p = np.column_stack((k, np.zeros(3)))
    right = p.copy();right[0, 3] = -6000
    arrays = dict(size=np.array([320, 180]), kl=k, kr=k.copy(), dl=np.zeros(5),
        dr=np.zeros(5), rl=np.eye(3), rr=np.eye(3), pl=p, pr=right)
    report = dict(status='OFFLINE_CALIBRATION_ONLY', reasons=[], measured_baseline_mm=30,
        quality=dict(left_rms_px=.2, right_rms_px=.2, stereo_rms_px=.3,
                     epipolar_p95_px=.4, baseline_mm=30))
    return arrays, report


class StereoTools(unittest.TestCase):
    def test_geometry_maps(self):
        arrays, report = fixture()
        cameras, fb = geometry(arrays, report)
        self.assertEqual(fb, 6000*256)
        for camera in cameras:
            raw = camera['inverse_rectified']@np.array([123., 81., 1])
            restored = arrays['kl']@raw
            np.testing.assert_allclose(restored/restored[2], [123, 81, 1])
            np.testing.assert_allclose(camera['forward_rectified'], arrays['kl'])

    def test_rejected_geometry(self):
        for mutation in ('quality', 'size', 'order', 'nan', 'baseline', 'rotation'):
            arrays, report = fixture()
            if mutation == 'quality':report['quality']['epipolar_p95_px'] = 1.01
            if mutation == 'size':arrays['size'] = [640, 360]
            if mutation == 'order':arrays['pr'][0, 3] = 6000
            if mutation == 'nan':arrays['dl'][0] = np.nan
            if mutation == 'baseline':report['quality']['baseline_mm'] = 60
            if mutation == 'rotation':arrays['rr'][0, 0] = 2
            with self.assertRaises(ValueError, msg=mutation):geometry(arrays, report)

    def test_export_disabled_and_sha_bound(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp);arrays, report = fixture()
            cal = root/'calibration.npz';np.savez(cal, **arrays)
            report['calibration_sha256'] = hashlib.sha256(cal.read_bytes()).hexdigest()
            cal.with_suffix('.json').write_text(json.dumps(report))
            result = export(cal, root/'cal.h')
            self.assertFalse(result['physical_distance_verified'])
            self.assertIn('.verified=STEREO_CALIBRATED', (root/'cal.h').read_text())
            with self.assertRaises(FileExistsError):export(cal, root/'cal.h')
            cal.write_bytes(cal.read_bytes()+b'changed')
            with self.assertRaises(ValueError):export(cal, root/'bad.h')

    def test_capture_two_views_and_wrap(self):
        calls = []
        expected = np.arange(57600, dtype=np.uint16)
        def transact(port, command, offset=0):
            self.assertIsNone(port);calls.append((command, offset))
            if command == 21:
                return struct.pack('<9I', 0x53545031, 320, 180, 26, 54000000,
                                   0x34561234, 0xfffffff0, 0x20, 0x53545031)
            values = expected[offset:offset+128]
            pair = np.empty(256, dtype=np.uint8)
            pair[::2] = (values % 256).astype(np.uint8)
            pair[1::2] = (255-values % 256).astype(np.uint8)
            return pair.tobytes()
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)/'capture'
            result = capture(None, transact, root, 1)
            self.assertEqual(len(calls), 451)
            self.assertEqual(result['timestamp_source'], 'frame_start_common_clock')
            self.assertFalse(result['exposure_sync_verified'])
            pair = result['pairs'][0]
            self.assertEqual((pair['left_frame_id'], pair['right_frame_id']), (0x1234, 0x3456))
            self.assertAlmostEqual(pair['right_timestamp_ms']-pair['left_timestamp_ms'], 48/54000)
            np.testing.assert_array_equal(np.asarray(Image.open(root/pair['left'])).ravel(), expected % 256)
            np.testing.assert_array_equal(np.asarray(Image.open(root/pair['right'])).ravel(), 255-expected % 256)

    def test_partial_capture_rejected(self):
        def transact(port, command, offset=0):
            if command == 21:return struct.pack('<9I', 0x53545031,320,180,26,54000000,1,2,3,0x53545031)
            return b'\0'*(255 if offset == 128 else 256)
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)/'capture'
            with self.assertRaises(ValueError):capture(None, transact, root, 1)
            self.assertFalse((root/'pairs.json').exists())
            self.assertFalse(list(root.glob('*.png')))


if __name__ == '__main__':unittest.main()
