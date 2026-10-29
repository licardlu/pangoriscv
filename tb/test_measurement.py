import importlib.util
from pathlib import Path
import unittest

SCRIPT = Path(__file__).parents[1] / 'scripts' / 'measurement.py'
spec = importlib.util.spec_from_file_location('measurement', SCRIPT) if SCRIPT.exists() else None
measurement = importlib.util.module_from_spec(spec) if spec else None
if spec:
    spec.loader.exec_module(measurement)


class MeasurementTests(unittest.TestCase):
    def check(self, ticks, iterations, frequency, crc=True):
        self.assertIsNotNone(measurement, '缺少按CPU周期和PLL实频验证成绩的模块')
        return measurement.assess(ticks, iterations, frequency, crc)

    def test_exact_ticks_not_rounded_seconds(self):
        r = self.check(1210000000, 6300, 120461538.46153846)
        self.assertAlmostEqual(r['coremark_per_mhz'], 6300e6 / 1210000000)
        self.assertTrue(r['meets_target'])

    def test_short_but_fast_run_is_not_qualified(self):
        r = self.check(1900000, 10, 120461538.46153846)
        self.assertGreater(r['coremark_per_mhz'], 5.2)
        self.assertFalse(r['meets_target'])

    def test_memory_clock_cannot_replace_low_cpu_clock(self):
        self.assertFalse(self.check(1900000000, 10000, 25000000)['meets_target'])

    def test_crc_failure_invalidates_score(self):
        self.assertFalse(self.check(1210000000, 6300, 120461538.46153846, False)['meets_target'])

    def test_divide_by_zero_is_rejected(self):
        self.assertIsNotNone(measurement, '缺少验证模块')
        with self.assertRaises(ValueError):
            measurement.assess(0, 10, 120000000, True)


if __name__ == '__main__':
    unittest.main()
