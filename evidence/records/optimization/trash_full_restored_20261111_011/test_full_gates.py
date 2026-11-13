import unittest

from build_full import timing_gate


def report(omit_clock=None, bad_hold=False):
    text = "Timing analysis mode : multi corner\nDesign Summary : All Constraints Met.\n"
    clocks = ("sys_clk", "pix_clk", "cfg_clk", "clk_25M",
              "cam1_sccb", "cam2_sccb", "ddrphy_sysclk")
    for corner in ("Slow", "Fast"):
        for kind in ("Setup", "Hold", "Recovery", "Removal", "Minimum Pulse Width"):
            text += f"\n{kind} Summary({corner} Corner):\n"
            for clock in clocks:
                if clock != omit_clock:
                    failing = bad_hold and corner == "Fast" and kind == "Hold"
                    text += f" {clock} {clock} {'-0.001 0.001 1' if failing else '0.1 0 0'} 10\n"
    return text


class TimingGate(unittest.TestCase):
    def test_all_required_clock_domains_and_corners(self):
        self.assertEqual(len(timing_gate(report())), 10)

    def test_pass_banner_does_not_hide_fast_hold_failure(self):
        with self.assertRaisesRegex(ValueError, "Timing violation"):
            timing_gate(report(bad_hold=True))

    def test_unconstrained_camera_domain_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "cam2_sccb"):
            timing_gate(report(omit_clock="cam2_sccb"))


if __name__ == "__main__":
    unittest.main()
