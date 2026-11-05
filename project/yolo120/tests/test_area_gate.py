"""The documented implementation schema must enforce the area gate."""
import importlib.util
from pathlib import Path
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[3]
spec = importlib.util.spec_from_file_location('area_gate', REPO/'tools/check_area_budget.py')
gate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)


class AreaGate(unittest.TestCase):
    def run_summary(self, lut, ff, ram, mode='strict', tolerance=0):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)/'summary.csv'
            path.write_text(f'Logic Utilization,LUT,FF,Distributed RAM\nUsed,{lut},{ff},{ram}\n')
            return gate.check(path, 'yolo120_application', mode, tolerance)

    def test_documented_application_baseline(self):
        self.assertEqual(self.run_summary(25680,21653,290)['status'], 'PASS')

    def test_extra_area_fails(self):
        self.assertEqual(self.run_summary(25681,21653,290)['status'], 'FAIL')

    def test_explicit_tolerance_is_not_neutrality(self):
        result = self.run_summary(25681,21653,290,'baseline',1)
        self.assertEqual(result['status'], 'PASS')
        self.assertFalse(result['exact_area_neutral'])

    def test_nonfinite_tolerance_rejected(self):
        with self.assertRaises(ValueError):
            self.run_summary(25680,21653,290,'baseline',float('nan'))

    def test_original_default_alias(self):
        self.assertEqual(gate.read_budget('reference_exact')[0]['LUT'],8875)


if __name__ == '__main__':
    unittest.main()
