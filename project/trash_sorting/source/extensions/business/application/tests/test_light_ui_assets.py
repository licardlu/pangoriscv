"""Validate compact header assets and the full-width camera reservation."""
from pathlib import Path
import json
import subprocess
import sys
import unittest
from PIL import Image
ROOT = Path(__file__).resolve().parents[1]
class LightUiAssetsTest(unittest.TestCase):
    def test_compact_header_assets(self):
        subprocess.run([sys.executable, str(ROOT / 'tools/light_ui_assets.py')], check=True)
        asset = ROOT / 'assets'
        bg = (asset / 'ui_light_bg.hex').read_text().splitlines()
        palette = (asset / 'ui_light_palette.hex').read_text().splitlines()
        status = (asset / 'ui_light_status.hex').read_text().splitlines()
        self.assertEqual(len(bg), 4480)
        self.assertEqual(len(palette), 16)
        self.assertEqual(len(status), 4860)
        self.assertTrue(all(len(v) == 8 for v in bg + status))
        layout = json.loads((asset / 'ui_light_layout.json').read_text())
        self.assertEqual(layout['header'], [0, 0, 1280, 112])
        self.assertEqual(layout['camera'], [0, 112, 1280, 608])
        for retired in ('points_card', 'bins', 'auto', 'quiz', 'music_card'):
            self.assertNotIn(retired, layout)
        with Image.open(asset / 'ui_light_preview.png') as preview:
            self.assertEqual(preview.size, (1280, 720))
            self.assertEqual(len(preview.crop((0, 112, 1280, 720)).getcolors()), 1)
            self.assertGreater(len(preview.crop((660, 56, 1216, 80)).getcolors()), 1,
                               'Startup prompt must appear inside the status card')
        with Image.open(asset / 'ui_light_header.png') as header:
            self.assertEqual(header.size, (1280, 112))
if __name__ == '__main__':
    unittest.main()
