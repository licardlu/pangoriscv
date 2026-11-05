import json
import math
import struct
import wave
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]
AUDIO = ROOT / "assets" / "audio"


class VoiceAssetTests(unittest.TestCase):
    def test_manifest_and_wavs_match_requested_offline_prompts(self):
        manifest = json.loads((AUDIO / "VOICE_MANIFEST.json").read_text(encoding="utf-8"))
        self.assertEqual(manifest["sample_rate_hz"], 48000)
        self.assertEqual(manifest["channels"], 1)
        expected = {
            "PROMPT.WAV": "请选择垃圾桶。",
            "CORRECT.WAV": "恭喜你，答对了！",
            "WRONG.WAV": "哎呀，答错了。",
            "TIMEOUT.WAV": "选择超时，请移走垃圾后重试。",
        }
        self.assertEqual(manifest["assets"], expected)
        for name in expected:
            with wave.open(str(AUDIO / name), "rb") as wav:
                self.assertEqual(wav.getframerate(), 48000)
                self.assertEqual(wav.getnchannels(), 1)
                self.assertEqual(wav.getsampwidth(), 2)
                self.assertGreater(wav.getnframes(), 0)
                samples = struct.unpack("<" + "h" * wav.getnframes(), wav.readframes(wav.getnframes()))
            rms = math.sqrt(sum(sample * sample for sample in samples) / len(samples))
            self.assertGreater(rms, 100.0, name)


if __name__ == "__main__":
    unittest.main()
