"""Synthetic reports test the parser; they are never performance evidence."""
import unittest
from test_uart_result import VALID, m


class ReportIntegrity(unittest.TestCase):
    def test_explicit_error_invalidates_success(self):
        self.assertFalse(m.parse_uart(VALID + 'ERROR! corrupted benchmark\n')['crc_valid'])

    def test_counter_words_must_be_32_bit(self):
        with self.assertRaises(ValueError):
            m.parse_uart(VALID.replace('TICKS_HI=0', 'TICKS_HI=4294967296'))

    def test_crc_must_be_16_bit(self):
        with self.assertRaises(ValueError):
            m.parse_uart(VALID.replace('0x1234', '0x11234'))

    def test_firmware_iteration_banner_must_match(self):
        with self.assertRaises(ValueError):
            m.parse_uart('ITERATIONS=10\n' + VALID)

    def test_duration_and_frequency_do_not_prove_hardware(self):
        self.assertFalse(m.parse_uart(VALID).get('board_verified', True))


if __name__ == '__main__':
    unittest.main()
