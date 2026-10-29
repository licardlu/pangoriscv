import importlib.util
from pathlib import Path
import unittest

MODULE = Path(__file__).parents[1] / 'scripts/verify_image.py'


class FirmwareImage(unittest.TestCase):
    def test_ram_lane_bytes_match_elf(self):
        self.assertTrue(MODULE.exists(), 'missing ELF-to-RAM image verifier')
        spec = importlib.util.spec_from_file_location('verify_image', MODULE)
        m = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(m)
        elf = Path(__file__).parents[1] / 'build/firmware_100/coremark.elf'
        image = Path(__file__).parents[1] / 'build/gen_final100'
        self.assertGreater(m.verify(elf, image)['checked_bytes'], 32000)

    def test_corrupted_memory_is_rejected(self):
        self.assertTrue(MODULE.exists(), 'missing ELF-to-RAM image verifier')
        spec = importlib.util.spec_from_file_location('verify_image', MODULE)
        m = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(m)
        with self.assertRaises(ValueError):
            m.compare_bytes(b'\x13\x00\x00\x00', b'\x00\x00\x00\x00', 0x80000000)
