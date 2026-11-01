"""The netlist comparison must use the exact RTL frozen for that build."""
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent))
import run_gate_smoke


class GateSnapshotTests(unittest.TestCase):
    def test_frozen_sources_are_verified_and_pll_is_replaced(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            files = {}
            for name in ('top.sv', 'pango_pll.sv', 'sections/predictor.vh'):
                path = root/'sources'/name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text('// frozen input\n')
                files[path.relative_to(root).as_posix()] = hashlib.sha256(path.read_bytes()).hexdigest()
            listing = root/'source_list.tcl'
            listing.write_text('set exact_sources {\n'+''.join(
                '  {'+(root/'sources'/name).as_posix()+'}\n'
                for name in ('top.sv', 'pango_pll.sv'))+'}\n')
            files['source_list.tcl'] = hashlib.sha256(listing.read_bytes()).hexdigest()
            (root/'input_snapshot.json').write_text(json.dumps({'files':[
                {'path': path, 'sha256': digest} for path, digest in files.items()]}))
            select = getattr(run_gate_smoke, 'reference_sources', None)
            self.assertTrue(callable(select), 'Gate comparison needs verified frozen RTL, not the old predictor')
            self.assertEqual(select(root), [root/'sources/top.sv'])
            (root/'sources/sections/predictor.vh').write_text('// changed after synthesis\n')
            with self.assertRaisesRegex(ValueError, 'changed'):
                select(root)


if __name__ == '__main__':
    unittest.main()
