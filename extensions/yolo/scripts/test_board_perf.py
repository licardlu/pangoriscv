import struct
import unittest

from board_perf import compare_detections,parse_profile


class PerformanceProtocol(unittest.TestCase):
    def test_operator_cycles_are_grouped_without_including_upload(self):
        graph={"ops":[{"kind":"YOLO_CONV"},{"kind":"YOLO_HEAD"},{"kind":"YOLO_CONV"}]}
        raw=struct.pack("<11I",1,100,7,3,10,65,4,2,20,30,10)
        profile=parse_profile(raw,graph)
        self.assertAlmostEqual(profile["seconds_by_kind"]["YOLO_CONV"],.3)
        self.assertAlmostEqual(profile["seconds_by_kind"]["YOLO_HEAD"],.3)
        self.assertEqual(profile["stages"]["forward"],.65)
        with self.assertRaises(ValueError):
            parse_profile(raw[:-4],graph)

    def test_detection_pairing_and_tolerance(self):
        expected=[dict(category="plastic",score=.5,box=[1,2,10,20])]
        self.assertEqual(compare_detections(expected,expected)["max_score_error"],0)
        with self.assertRaises(ValueError):
            compare_detections(expected,[])
        changed=[dict(category="plastic",score=.6,box=[1,2,10,20])]
        with self.assertRaises(ValueError):
            compare_detections(expected,changed)


if __name__=="__main__":
    unittest.main()
