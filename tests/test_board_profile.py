"""Board integration checks must reject wrong pins or unsupported PLL values."""
import copy
import importlib.util
from pathlib import Path
import sys
import unittest

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))


class BoardProfileTests(unittest.TestCase):
    def test_documented_board_parameters_match_actual_design(self):
        self.assertTrue((ROOT/'tools/board_profile.py').is_file(), 'Board documents need executable integration checks')
        import board_profile
        result=board_profile.check(ROOT)
        self.assertEqual(result['pins_checked'],13)
        self.assertAlmostEqual(result['vco_mhz'],1566.0)
        self.assertGreater(result['cpu_mhz'],120.0)

    def test_wrong_clock_pin_is_rejected(self):
        self.assertTrue((ROOT/'tools/board_profile.py').is_file())
        import board_profile
        text=(ROOT/'constraints/pango_vexii.pcf').read_text()
        with self.assertRaisesRegex(ValueError,'Wrong board pin'):
            board_profile.check(ROOT,pcf=text.replace('LOC=D18','LOC=N3'))

    def test_invalid_ppll_vco_is_rejected(self):
        self.assertTrue((ROOT/'tools/board_profile.py').is_file())
        import board_profile
        pll=(ROOT/'rtl/board/pango_pll.sv').read_text()
        with self.assertRaisesRegex(ValueError,'Out-of-spec PPLL vco_mhz'):
            board_profile.check(ROOT,pll=pll.replace('STATIC_RATIOF(58)','STATIC_RATIOF(40)'))


if __name__=='__main__':unittest.main()
