"""A stale or incomplete timing report must never qualify a bitstream."""
import sys
from pathlib import Path
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]/'tools'))
from build import final_timing


def report():
    text = 'Timing analysis mode : multi corner\nDesign Summary : All Constraints Met.\n'
    for corner in ('Slow', 'Fast'):
        for kind in ('Setup', 'Hold', 'Recovery', 'Removal', 'Minimum Pulse Width'):
            text += f'\n{kind} Summary({corner} Corner):\n'
            for clock in ('ai_clk', 'cam1_sccb', 'cam2_sccb'):
                text += f'{clock} {clock} 0.012 0.000 0 123\n'
    return text+'\nSlow Corner\n'


class TimingGate(unittest.TestCase):
    def test_complete_report(self):
        self.assertEqual(len(final_timing(report())), 10)

    def test_stale_success_banner_cannot_hide_violation(self):
        with self.assertRaises(ValueError):
            final_timing(report().replace('0.012 0.000 0 123', '-0.012 -0.012 1 123', 1))

    def test_missing_corner_fails(self):
        with self.assertRaises(ValueError):
            final_timing(report().replace('Hold Summary(Fast Corner):', 'Missing:'))

    def test_unconstrained_ai_clock_fails(self):
        with self.assertRaises(ValueError):
            final_timing(report().replace('ai_clk ai_clk', 'other_clk other_clk'))

    def test_intermediate_summary_is_insufficient(self):
        with self.assertRaises(ValueError):
            final_timing('Design Summary : All Constraints Met.')


if __name__ == '__main__':
    unittest.main()
