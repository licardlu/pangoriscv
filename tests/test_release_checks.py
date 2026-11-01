"""Regression checks for review findings; exercise real logs and budgets."""
import importlib.util
import json
import pathlib
import sys
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
sys.path.insert(0, str(ROOT / 'tests'))


class AreaReviewTests(unittest.TestCase):
    def test_real_candidate_is_reported_over_budget_without_schema_crash(self):
        path = ROOT / 'tools/check_area_budget.py'
        self.assertTrue(path.is_file(), 'Standalone release needs a working area gate')
        spec = importlib.util.spec_from_file_location('area_gate', path)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        summary = ROOT / 'evidence/records/optimization/positive120/positive020_route20/multiseed_summary.csv'
        result = module.check(summary, 'baseline-implementation-standalone-001', 'strict', 0)
        self.assertEqual(result['status'], 'FAIL')
        self.assertEqual(result['delta'], 611)
        self.assertEqual(result['actual']['LUT'] - result['budget']['LUT'], 32)


class IdentityReviewTests(unittest.TestCase):
    def test_selected_bitstream_and_sources_are_bound_to_report(self):
        path = ROOT/'tools/release_gate.py'
        self.assertTrue(path.is_file(), 'Release must check the actual packaged bitstream identity')
        spec = importlib.util.spec_from_file_location('release_gate', path)
        gate = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(gate)
        selected = json.loads((ROOT/'provenance/SELECTED_IMPLEMENTATION.json').read_text())
        self.assertTrue(gate.check(ROOT, selected)['binding_valid'])
        selected['bitstream_sha256'] = '0'*64
        with self.assertRaises(ValueError):
            gate.check(ROOT, selected)



class BenchmarkReviewTests(unittest.TestCase):
    def test_diagnostic_image_can_be_staged_without_overwriting_coremark(self):
        import build
        select = getattr(build, 'select_image', None)
        self.assertTrue(callable(select), 'PDS build needs an explicit alternate-image path')
        directory, elf, record = select(ROOT/'firmware/diagnostics/image', 'diagnostics.elf')
        self.assertEqual(elf.name, 'diagnostics.elf')
        self.assertNotEqual(directory, ROOT/'firmware/image')
        self.assertGreater(record['checked_bytes'], 0)

    def test_profile_requires_a_closed_timed_window(self):
        import run_rtl
        text = (ROOT / 'evidence/improved1/improved1_bench_upstream20_fast/simulate.log').read_text()
        with self.assertRaises(ValueError):
            run_rtl.validate_result('profile', text)

    def test_profile_exports_both_branch_lanes_and_rejects_wrong_window(self):
        import run_rtl
        text = (ROOT/'evidence/records/review_20261101/review_profile_002/simulate.log').read_text()
        result = run_rtl.validate_result('profile', text)
        self.assertIn('profile', result, 'Timed counters must be exported alongside CRC/ticks')
        self.assertEqual(result['profile']['branch_count'], 932793)
        self.assertEqual(result['profile']['branch_miss'], 61776)
        with self.assertRaises(ValueError):
            run_rtl.validate_result('profile', text.replace('cycles=3799461', 'cycles=9999999'))

    def test_runner_rejects_completed_run_with_bad_crc(self):
        import run_rtl
        validate = getattr(run_rtl, 'validate_result', None)
        self.assertTrue(callable(validate), 'Runner needs CRC validation after TEST_PASS')
        text = (ROOT / 'evidence/improved1/improved1_bench_upstream20_fast/simulate.log').read_text()
        self.assertTrue(validate('benchmark', text)['crc_valid'])
        with self.assertRaises(ValueError):
            validate('benchmark', text.replace('0x4983', '0x4982'))

    def test_profile_addresses_come_from_elf_not_hardcoded_pcs(self):
        import run_rtl
        locate = getattr(run_rtl, 'profile_addresses', None)
        self.assertTrue(callable(locate), 'Profile must follow the firmware ELF')
        start, stop = locate(ROOT / 'firmware/image/coremark.elf',
            'D:/pangowork/xpack-riscv-none-elf-gcc-15.2.0-1/bin/riscv-none-elf-objdump.exe')
        self.assertEqual((start, stop), (0x80005d90, 0x80005e1c))


if __name__ == '__main__':
    unittest.main()
