import sys
from pathlib import Path
import unittest

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from benchmark import HZ, assess_runs, validate_profile


class Acceptance(unittest.TestCase):
    def run_data(self, seconds):
        return [dict(camera_fast=1,warmup=False,wall_seconds=s,device_seconds=s-.01) for s in seconds]

    def test_slow_outlier_fails_even_when_median_passes(self):
        self.assertFalse(assess_runs(self.run_data([.8,.8,1.01]),3,1)['passed'])

    def test_missing_frame_and_warmup_are_not_success(self):
        runs=self.run_data([.8,.8,.8]);runs[0]['warmup']=True
        self.assertFalse(assess_runs(runs,3,1)['passed'])
        self.assertFalse(assess_runs([],3,1)['passed'])

    def test_device_cycles_cannot_be_hidden_by_host_clock(self):
        runs=self.run_data([.8,.8,.8]);runs[1]['device_seconds']=1.1
        self.assertFalse(assess_runs(runs,3,1)['passed'])
        self.assertTrue(assess_runs(self.run_data([.8,.9,1]),3,1)['passed'])

    def test_partial_graph_cannot_pass_as_full_inference(self):
        profile=dict(cpu_hz=HZ,flags=63,
            stages=dict(capture=.1,forward=.7,decode=.1,display=.01),
            operators=[dict(cycles=100,seconds=100/HZ) for _ in range(85)])
        self.assertAlmostEqual(validate_profile(profile,.92,85),.91)
        profile['operators'][42]['cycles']=0
        with self.assertRaisesRegex(ValueError,'Incomplete'):
            validate_profile(profile,.92,85)

    def test_inconsistent_operator_timing_is_rejected(self):
        profile=dict(cpu_hz=HZ,flags=63,
            stages=dict(capture=.1,forward=.7,decode=.1,display=.01),
            operators=[dict(cycles=HZ,seconds=1)])
        with self.assertRaisesRegex(ValueError,'exceeds'):
            validate_profile(profile,.92,1)


if __name__=='__main__':
    unittest.main()
