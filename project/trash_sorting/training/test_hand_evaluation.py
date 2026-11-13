"""Regress metric class translation and mixed hand/waste annotation ordering."""
import unittest
import numpy as np
from evaluate_hand_branch import hand_annotations, hand_metric_arrays
from evaluate_quantized_hand_policy import match_hands


class HandEvaluation(unittest.TestCase):
    def test_branch_and_joint_have_identical_hand_metric_inputs(self):
        labels = [[0, .5, .5, .4, .6]]
        legacy = [[30, 20, 70, 80, .9, 0]]
        joint = [[30, 20, 70, 80, .9, 4]]
        p0, g0 = hand_metric_arrays(legacy, labels, 100, 100)
        p4, g4 = hand_metric_arrays(joint, [[4, *labels[0][1:]]], 100, 100)
        np.testing.assert_array_equal(p0, p4)
        np.testing.assert_array_equal(g0, g4)
        self.assertEqual(joint[0][5], 4)  # metric copy must not alter policy IDs

    def test_mixed_row_does_not_use_object_as_oracle_hand(self):
        hand = [4, .7, .6, .4, .5]
        row = {'boxes': [[1, .2, .3, .1, .2], hand]}
        self.assertEqual(hand_annotations(row, 4), [hand])
        self.assertEqual(hand_annotations({'boxes': []}, 4), [])

    def test_empty_hand_predictions_have_stable_shapes(self):
        p, g = hand_metric_arrays([], [], 1280, 720)
        self.assertEqual(p.shape, (0, 6))
        self.assertEqual(g.shape, (0, 5))

    def test_quantized_duplicate_predictions_cannot_count_as_two_hands(self):
        truth = [[10, 10, 40, 50]]
        self.assertEqual(match_hands([[10, 10, 40, 50], [11, 10, 41, 50]], truth), 1)
        self.assertEqual(match_hands([[0, 0, 100, 100]], truth), 0)
        self.assertEqual(match_hands([], truth), 0)

    def test_quantized_multiple_hands_require_distinct_matches(self):
        truth = [[10, 10, 40, 50], [70, 10, 100, 50]]
        self.assertEqual(match_hands([[10, 10, 40, 50], [70, 10, 100, 50]], truth), 2)


if __name__ == '__main__':
    unittest.main()
