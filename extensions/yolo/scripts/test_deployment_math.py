import unittest
import numpy as np
from deployment_bundle import requant, round_away


class IntegerMath(unittest.TestCase):
    def test_half_away_both_signs(self):
        values = np.array([-49152, -32768, -16384, -1, 0, 1, 16384, 32768, 49152])
        np.testing.assert_array_equal(requant(values, 1),
                                      [-2, -1, -1, 0, 0, 0, 1, 1, 2])

    def test_negative_near_boundary(self):
        values = np.array([-32769, -32767, -16385, -16383, 16383, 16385, 32767, 32769])
        np.testing.assert_array_equal(requant(values, 1),
                                      round_away(values / 32768.0))


if __name__ == "__main__":
    unittest.main()
