"""Use actual PDS reports to prevent publishing an unconverged implementation."""
import pathlib
import sys
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'tools'))


class TimingGateTests(unittest.TestCase):
    @staticmethod
    def synthetic_closed_report(setup_slack):
        # A unit fixture, never a report from an implementation.
        text = 'core_clk 8.3010 {0.0000 4.1500} Declared\n'
        for corner in ['Slow', 'Fast']:
            for kind in ['Setup', 'Hold', 'Recovery', 'Removal', 'Minimum Pulse Width']:
                slack = setup_slack if kind == 'Setup' else 0.01
                text += f'{kind} Summary({corner} Corner):\ncore_clk {slack} 0.000 0 10\n=====\n'
        return text + 'Design Summary : All Constraints Met.'

    def test_zero_slack_does_not_meet_positive_margin_requirement(self):
        import timing_gate
        self.assertFalse(timing_gate.assess(self.synthetic_closed_report(0.0))['sta_closed'])

    def test_strictly_positive_complete_report_passes(self):
        import timing_gate
        self.assertTrue(timing_gate.assess(self.synthetic_closed_report(0.001))['sta_closed'])

    def test_original_negative_slack_is_rejected(self):
        import timing_gate
        result = timing_gate.assess((ROOT/'evidence/baseline/final-timing.rtr').read_text())
        self.assertFalse(result['sta_closed'])
        self.assertLess(result['setup_wns_ns'], 0)
        self.assertGreater(result['setup_failing_endpoints'], 0)

    def test_missing_corner_cannot_pass(self):
        import timing_gate
        with self.assertRaises(ValueError):
            timing_gate.assess('Design Summary : All Constraints Met.')

    def test_modified_summary_cannot_hide_a_failing_path(self):
        import timing_gate
        text = (ROOT/'evidence/baseline/final-timing.rtr').read_text()
        text = text.replace('Some Constraints Violated.', 'All Constraints Met.')
        self.assertFalse(timing_gate.assess(text)['sta_closed'])

    def test_all_corners_and_checks_are_required(self):
        import timing_gate
        text = (ROOT/'evidence/baseline/final-timing.rtr').read_text()
        result = timing_gate.assess(text)
        self.assertEqual(set(result['checks']), {f'{check}({corner} Corner)' for corner in ['Slow', 'Fast']
            for check in ['Setup', 'Hold', 'Recovery', 'Removal', 'Minimum Pulse Width']})


if __name__ == '__main__':
    unittest.main()
