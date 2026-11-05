"""Keep the faster AI clock separate from the camera and DDR clock domains."""
from pathlib import Path
import tempfile
import unittest

from generate_vexii_camera import generate


class PerformanceClockTest(unittest.TestCase):
    def test_fast_clock_and_reset_follow_the_same_domain(self):
        with tempfile.TemporaryDirectory() as folder:
            out = generate(cpu_hz=37125000, out=Path(folder))
            top = (out / "yolo_camera_top.v").read_text(encoding="utf-8")
            fdc = (out / "camera.fdc").read_text(encoding="utf-8")
        self.assertIn("GTP_CLKBUFG ai_clock_global", top)
        self.assertIn("always @(posedge ai_clk or negedge ai_ready)", top)
        self.assertIn(".clk_sys(ai_clk)", top)
        self.assertIn(".cpu_clk(ai_clk)", top)
        self.assertIn(".core_clk(core_clk)", top)
        self.assertIn("create_generated_clock -name {ai_clk}", fdc)
        self.assertIn("{ai_clock_global/CLKOUT}", fdc)
        self.assertIn("-divide_by 2", fdc)
        self.assertIn("ai_to_ddr_async", fdc)

    def test_legacy_clock_stays_available_for_recovery(self):
        with tempfile.TemporaryDirectory() as folder:
            out = generate(cpu_hz=27000000, out=Path(folder))
            top = (out / "yolo_camera_top.v").read_text(encoding="utf-8")
        self.assertNotIn("ai_clock_global", top)
        self.assertIn(".clk_sys(sys_clk)", top)

    def test_120mhz_uses_the_final_cpu_pll_and_waits_for_lock(self):
        with tempfile.TemporaryDirectory() as folder:
            out = generate(cpu_hz=120461538, out=Path(folder))
            top = (out / "yolo_camera_top.v").read_text(encoding="utf-8")
            pll = (out / "ai_perf_pll.v").read_text(encoding="utf-8")
            fdc = (out / "camera.fdc").read_text(encoding="utf-8")
        self.assertIn("ai_perf_pll ai_clock_pll", top)
        self.assertIn("ai_pll_locked && ddr_init_done", top)
        self.assertIn(".STATIC_RATIOF(58)", pll)
        self.assertIn(".STATIC_RATIO0(13)", pll)
        self.assertIn(".clk_sys(ai_clk)", top)
        self.assertIn(".cpu_clk(ai_clk)", top)
        self.assertIn("create_clock -name {ai_clk}", fdc)
        self.assertIn("[get_pins {ai_clock_pll/u_ppll:CLKOUT0}]", fdc)
        self.assertNotIn("ppll_inst/CLKOUT0", fdc)
        self.assertIn("ai_to_video_async", fdc)
        self.assertIn("ai_to_ddr_async", fdc)
        self.assertIn("-period {8.2931}", fdc)
        self.assertNotIn(
            "get_clocks {sys_clk|ai_clock_pll/u_ppll/CLKOUT0_Inferred}", fdc)

    def test_81mhz_uses_integer_ppll_ratios(self):
        with tempfile.TemporaryDirectory() as folder:
            out = generate(cpu_hz=81000000, out=Path(folder))
            pll = (out / "ai_perf_pll.v").read_text(encoding="utf-8")
            fdc = (out / "camera.fdc").read_text(encoding="utf-8")
        self.assertIn(".STATIC_RATIOF(45)", pll)
        self.assertIn(".STATIC_RATIO0(15)", pll)
        self.assertIn("create_clock -name {ai_clk}", fdc)
        self.assertIn("[get_pins {ai_clock_pll/u_ppll:CLKOUT0}]", fdc)
        self.assertNotIn("ppll_inst/CLKOUT0", fdc)
        self.assertIn("ai_to_video_async", fdc)
        self.assertIn("-period {12.3333}", fdc)
        self.assertNotIn(
            "get_clocks {sys_clk|ai_clock_pll/u_ppll/CLKOUT0_Inferred}", fdc)

    def test_93mhz_uses_ppll_and_separate_async_clock_groups(self):
        with tempfile.TemporaryDirectory() as folder:
            out = generate(cpu_hz=93461538, out=Path(folder))
            pll = (out / "ai_perf_pll.v").read_text(encoding="utf-8")
            fdc = (out / "camera.fdc").read_text(encoding="utf-8")
        self.assertIn(".STATIC_RATIOF(45)", pll)
        self.assertIn(".STATIC_RATIO0(13)", pll)
        self.assertIn("[get_pins {ai_clock_pll/u_ppll:CLKOUT0}]", fdc)
        self.assertIn("-period {10.6889}", fdc)
        self.assertIn("ai_to_video_async", fdc)
        self.assertIn("ai_to_ddr_async", fdc)

    def test_unsupported_frequency_is_rejected(self):
        with self.assertRaises(ValueError):
            generate(cpu_hz=50000000)


if __name__ == "__main__":
    unittest.main()
