import importlib.util
from pathlib import Path
import unittest

spec=importlib.util.spec_from_file_location('measurement',Path(__file__).parents[1]/'scripts/measurement.py')
m=importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)

VALID='''CPU_HZ=120461538
Iterations       : 7000
seedcrc          : 0xe9f5
[0]crclist       : 0xe714
[0]crcmatrix     : 0x1fd7
[0]crcstate      : 0x8e3a
[0]crcfinal      : 0x1234
Correct operation validated. See README.md for run and reporting rules.
TICKS_HI=0
TICKS_LO=1300000000
BENCH_DONE
'''

class UartResults(unittest.TestCase):
    def parse(self,s):
        self.assertTrue(hasattr(m,'parse_uart'),'Missing complete-report validator')
        return m.parse_uart(s)

    def test_complete_report_uses_cycles(self):
        r=self.parse(VALID)
        self.assertTrue(r['meets_target'])
        self.assertAlmostEqual(r['coremark_per_mhz'],7000e6/1300000000)

    def test_crc_mismatch_rejects_success_text(self):
        self.assertFalse(self.parse(VALID.replace('0xe714','0xffff'))['crc_valid'])

    def test_short_report_cannot_pass(self):
        r=self.parse(VALID.replace('1300000000','1000000'))
        self.assertFalse(r['meets_target'])

    def test_error_report_rejects_success_text(self):
        self.assertFalse(self.parse(VALID+'Errors detected\n')['crc_valid'])

    def test_missing_ticks_or_completion_rejected(self):
        for line in ['TICKS_HI=0\n','BENCH_DONE\n']:
            with self.subTest(line=line),self.assertRaises(ValueError):
                self.parse(VALID.replace(line,''))

    def test_second_run_not_silently_combined(self):
        with self.assertRaises(ValueError): self.parse(VALID+VALID)

if __name__=='__main__': unittest.main()
