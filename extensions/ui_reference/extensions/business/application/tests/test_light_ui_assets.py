"""Checks the fixed ROM layout and half-screen boundary of the bright UI."""
from pathlib import Path
import subprocess
import sys
import unittest
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]

class LightUiAssetsTest(unittest.TestCase):
    def test_half_screen_rom_assets(self):
        script = ROOT / 'tools/light_ui_assets.py'
        self.assertTrue(script.exists(), 'Bright half-screen asset generator is missing')
        subprocess.run([sys.executable, str(script)], cwd=ROOT, check=True)
        asset = ROOT / 'assets'
        bg = (asset / 'ui_light_bg.hex').read_text().splitlines()
        palette = (asset / 'ui_light_palette.hex').read_text().splitlines()
        status = (asset / 'ui_light_status.hex').read_text().splitlines()
        self.assertEqual(len(bg), 28800)
        self.assertEqual(len(palette), 16)
        self.assertEqual(len(status), 9720)
        self.assertTrue(all(len(v) == 8 for v in bg + status))
        preview = Image.open(asset / 'ui_light_preview.png').convert('RGB')
        self.assertEqual(preview.size, (1280, 720))
        with Image.open(asset / 'ui_light_left.png') as left:
            self.assertEqual(left.size, (640, 720))
        self.assertLessEqual(len(preview.getcolors(16)), 16)
        self.assertEqual(len(preview.crop((640, 0, 1280, 720)).getcolors()), 1,
                         'Camera half must remain blank rather than contain UI')
        self.assertEqual(preview.getpixel((48, 256)), (255, 255, 255))
        self.assertEqual(preview.getpixel((320, 112)), (255, 255, 255),
                         'Dynamic point digits must have a clean white background')
        self.assertEqual(preview.getpixel((420, 630)), (255, 255, 255),
                         'Dynamic playback state must have a clean background')

if __name__ == '__main__':
    unittest.main()
