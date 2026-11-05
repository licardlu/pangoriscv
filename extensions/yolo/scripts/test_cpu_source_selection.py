"""Verify the AI build consumes a complete CPU source package.

The upstream project pinned a checkout that only existed on the import machine.
The expected directory is now taken from CPU_RTL; when it is unset only the
completeness checks run.
"""
import os
from pathlib import Path
import unittest

from generate_vexii_soc import CPU


def _expected():
    value = os.environ.get("CPU_RTL")
    return Path(value).resolve() if value else None


EXPECTED = _expected()


class CpuSourceSelectionTest(unittest.TestCase):
    def test_final_cpu_package_is_selected_and_complete(self):
        if EXPECTED is not None:
            self.assertEqual(CPU.resolve(), EXPECTED)
        source_list = [
            line.strip()
            for line in (CPU / "sources.f").read_text(encoding="utf-8").splitlines()
            if line.strip()
        ]
        self.assertIn("rtl/core/execute/branch_eq_pipeline.v", source_list)
        self.assertIn("rtl/core/pango_replica_core.v", source_list)
        self.assertIn("rtl/soc/MicroSoc.v", source_list)
        missing = [entry for entry in source_list if not (CPU / entry).is_file()]
        self.assertEqual(missing, [])


if __name__ == "__main__":
    unittest.main()
