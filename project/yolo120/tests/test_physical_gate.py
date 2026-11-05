"""Reject physical experiments when PDS overwrites or ignores their input."""
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]/'tools'))
from build import check_physical_constraints


class PhysicalGate(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.out = Path(self.temp.name)
        self.command = 'def_region cpu_core_region 50 105 20 100'
        data = (self.command+'\n').encode('ascii')
        (self.out/'region.input.txt').write_bytes(data)
        (self.out/'inputs.json').write_text(json.dumps({'physical_constraints': [
            {'path': 'region.input.txt', 'sha256': hashlib.sha256(data).hexdigest(),
             'active_path': 'region.pcf'}]}))
        (self.out/'region.pcf').write_bytes(data)
        self.log = 'Executing : '+self.command+' successfully\n'

    def test_applied_constraint(self):
        check_physical_constraints(self.out, self.log)

    def test_overwritten_pcf_rejected(self):
        (self.out/'region.pcf').write_text('def_port sys_clk LOC=D18\n')
        with self.assertRaisesRegex(ValueError, 'did not reach PNR'):
            check_physical_constraints(self.out, self.log)

    def test_ignored_or_failed_command_rejected(self):
        for log in ('', self.log.replace('successfully', 'failed')):
            with self.subTest(log=log), self.assertRaisesRegex(ValueError, 'did not reach PNR'):
                check_physical_constraints(self.out, log)

    def test_changed_input_rejected(self):
        (self.out/'region.input.txt').write_text(self.command+'\n# changed\n')
        with self.assertRaisesRegex(ValueError, 'changed after preparation'):
            check_physical_constraints(self.out, self.log)

    def test_success_echo_with_constraint_error_rejected(self):
        # PDS prints "successfully" even after PhysicalConstraintEditor-0023.
        with self.assertRaisesRegex(ValueError, 'reported an error'):
            check_physical_constraints(self.out, 'E: Instance cannot be found.\n'+self.log)


if __name__ == '__main__':
    unittest.main()
