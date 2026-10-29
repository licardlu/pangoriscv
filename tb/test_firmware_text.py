"""Iteration count changes data, so short and release runs keep identical code layout."""
from pathlib import Path
import struct
import unittest


def text_section(path):
    data = path.read_bytes()
    shoff = struct.unpack_from('<I', data, 32)[0]
    entsize, count, names_index = struct.unpack_from('<HHH', data, 46)
    headers = [struct.unpack_from('<10I', data, shoff+i*entsize) for i in range(count)]
    names = headers[names_index]
    strings = data[names[4]:names[4]+names[5]]
    for h in headers:
        if strings[h[0]:].split(b'\0',1)[0] == b'.text':
            return data[h[4]:h[4]+h[5]]
    raise ValueError('missing .text')


class FirmwareText(unittest.TestCase):
    def test_short_and_release_instruction_bytes_identical(self):
        root = Path(__file__).parents[1]
        self.assertEqual(text_section(root/'build/firmware_100/coremark.elf'),
                         text_section(root/'build/firmware_7000/coremark.elf'))
