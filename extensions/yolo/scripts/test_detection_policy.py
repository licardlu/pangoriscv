import unittest

from eval_detection_policy import evaluate, keep


class DetectionPolicyTest(unittest.TestCase):
    def test_area_uses_original_image_not_network_size(self):
        detection = dict(box=[0, 0, 640, 360], score=0.6, **{"class": "paper"})
        self.assertTrue(keep(detection, 1280, 720, 0.25, max_area=0.5))
        self.assertFalse(keep(detection, 640, 360, 0.25, max_area=0.5))

    def test_padding_rejected_but_partial_edge_target_retained(self):
        self.assertFalse(keep(dict(box=[10, -50, 50, -1], score=0.7),
                              1280, 720, 0.25))
        self.assertTrue(keep(dict(box=[-5, 10, 50, 60], score=0.7),
                             1280, 720, 0.25))

    def test_duplicate_or_wrong_class_is_false_positive(self):
        records = [dict(width=320, height=320,
                        gt=[dict(box=[10, 10, 50, 50], **{"class": "paper"})],
                        dets=[dict(box=[10, 10, 50, 50], score=0.8,
                                   **{"class": cls})
                              for cls in ("paper", "paper", "glass")])]
        result = evaluate(records, confidence=0.25)
        self.assertEqual((result["tp"], result["fp"], result["fn"]), (1, 2, 0))

    def test_empty_detections_are_not_false_success(self):
        result = evaluate([dict(width=320, height=320, dets=[],
                                gt=[dict(box=[1, 1, 5, 5], **{"class": "paper"})])],
                          confidence=0.25)
        self.assertEqual((result["tp"], result["fp"], result["fn"]), (0, 0, 1))
        self.assertIsNone(result["precision"])


class DecoderPaddingTest(unittest.TestCase):
    @staticmethod
    def logits():
        import numpy as np
        heads = [np.full((1, 33, 1, 1), -20, dtype=np.float32) for _ in range(3)]
        heads[0][0, :4, 0, 0] = 0
        heads[0][0, 4:6, 0, 0] = 4
        return heads

    def test_reference_rejects_padding_only_anchor(self):
        from gen_vexii_yolo_sim import decode
        self.assertEqual(decode(self.logits(), 1280, 720, .25, 0, 70), [])

    def test_reference_retains_partial_object_at_image_edge(self):
        from gen_vexii_yolo_sim import decode
        boxes = decode(self.logits(), 320, 320, 1, 0, 4)
        self.assertEqual(len(boxes), 1)
        self.assertEqual(boxes[0][:4], [0, 0, 9, 6.5])


if __name__ == "__main__":
    unittest.main()
