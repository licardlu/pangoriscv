"""Check that the board integration actually enables the existing OSD font."""
from pathlib import Path
import tempfile
import unittest

from generate_camera_top import generate


class CameraLabelsTest(unittest.TestCase):
    def test_board_enables_class_labels(self):
        with tempfile.TemporaryDirectory() as folder:
            generate(folder)
            source = (Path(folder) / "yolo_camera_top.v").read_text(encoding="utf-8")
        self.assertIn("video_ai_frontend #(.OSD_TEXT(1),.OSD_BORDER(4)) frontend(", source)
        self.assertNotIn(".OSD_TEXT(0)", source)
        rtl = (Path(__file__).resolve().parents[1] / "rtl/video_ai_frontend.v").read_text(
            encoding="utf-8"
        )
        self.assertIn("box_class[0][31]", rtl)
        self.assertIn("letter(box_class[0][2:0],character)", rtl)
        self.assertIn("bin_letter(box_class[0][2:0],character)", rtl)
        self.assertIn('"Y":glyph=', rtl)

    def test_empty_camera_result_keeps_last_displayed_boxes(self):
        source = (Path(__file__).resolve().parents[1] / "sw/platform_main.c").read_text(
            encoding="utf-8"
        )
        start = source.index("static int display_results(uint32_t count)")
        end = source.index("\nstatic int infer_reply", start)
        self.assertRegex(source[start:end], r"if\s*\(\s*count\s*==\s*0\s*\)\s*return\s+0\s*;")


if __name__ == "__main__":
    unittest.main()
