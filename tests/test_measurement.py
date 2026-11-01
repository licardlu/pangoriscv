import pathlib
import sys
import unittest

ROOT=pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))


class MeasurementTests(unittest.TestCase):
    def test_original_board_capture_is_valid_but_below_target(self):
        from measure import assess
        text=(ROOT/'evidence/baseline/board-run-001/uart.log').read_text()
        result=assess(text)
        self.assertTrue(result['official_valid'])
        self.assertFalse(result['score_target_met'])
        self.assertAlmostEqual(result['coremark_per_mhz'],7000000000/1309328358)

    def test_short_run_is_diagnostic_even_if_crc_matches(self):
        from measure import assess
        text=(ROOT/'evidence/improved1/improved1_bench_upstream20_fast/simulate.log').read_text()
        result=assess(text)
        self.assertTrue(result['crc_valid'])
        self.assertFalse(result['official_valid'])
        self.assertFalse(result['target_achieved'])
        self.assertAlmostEqual(result['coremark_per_mhz'],20000000/3799461)

    def test_incorrect_final_crc_fails(self):
        from measure import assess
        text=(ROOT/'evidence/improved1/improved1_bench_upstream20_fast/simulate.log').read_text()
        self.assertFalse(assess(text.replace('0x4983','0x4982'))['crc_valid'])

    def test_unfinished_benchmark_is_not_accepted(self):
        from measure import assess
        with self.assertRaises(ValueError):
            assess('UART: VEXII_PANGO_BOOT')


if __name__=='__main__':unittest.main()
