import unittest

from package_release import validate_cpu_clock


class ReleaseClockTest(unittest.TestCase):
    def report(self, period="8.3016", loads="12000"):
        return (
            " Clock Summary:\n"
            " sys_clk 37.0000 {0.0000 18.5000} Declared 100 5 {sys_clk}\n"
            " ai_clk "
            f"{period} {{0.0000 4.1466}} Declared {loads} 22 "
            "{ai_clock_pll/u_ppll:CLKOUT0}\n"
            " Clock Groups:\n"
        )

    def test_routed_120mhz_clock_is_required(self):
        result = validate_cpu_clock(self.report(), 120461538)
        self.assertEqual(result["clock_loads"], 12000)
        with self.assertRaises(RuntimeError):
            validate_cpu_clock("Design Summary : All Constraints Met.", 120461538)

    def test_81mhz_clock_period_is_verified_from_sta(self):
        period = 1e9 / 81000000
        result = validate_cpu_clock(self.report(period=f"{period:.4f}"), 81000000)
        self.assertAlmostEqual(result["period_ns"], period, delta=.01)

    def test_93mhz_clock_period_is_verified_from_sta(self):
        period = 37 * 13 / 45
        result = validate_cpu_clock(
            self.report(period=f"{period:.4f}"), 93461538)
        self.assertAlmostEqual(result["period_ns"], period, delta=.01)

    def test_slow_or_unloaded_clock_is_not_a_120mhz_pass(self):
        for report in (self.report(period="37.0000"), self.report(loads="0")):
            with self.assertRaises(RuntimeError):
                validate_cpu_clock(report, 120461538)

    def test_legacy_oscillator_constraint_is_supported(self):
        report = self.report().replace("Declared 100 5", "Declared 12000 5")
        self.assertEqual(validate_cpu_clock(report, 27000000)["period_ns"], 37.0)


if __name__ == "__main__":
    unittest.main()
