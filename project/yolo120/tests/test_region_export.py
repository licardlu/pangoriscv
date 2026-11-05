"""Verify actual PDS text-export fields used to attest logical placement."""
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]/'tools'))
from region_constraints import placed_cpu_cells


class RegionExport(unittest.TestCase):
    def parse(self, text):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder)/'placed.adif'
            path.write_text(text, encoding='utf-8')
            return list(placed_cpu_cells(path))

    def test_logical_site_is_distinct_from_resource_site(self):
        # Syntax from PDS region-probe-005's real placement export. The instance
        # prefix is changed to the CPU prefix under test. Its logical site is
        # (50,71); its CLMA resource name instead contains (171,432).
        text = r'''
          (INSTANCE \ai/cpu/system_cpu_logic_core/count[1]/opit_0_L6QL5Q  (VIEWREF OPER (CELLREF gopLUT6QL5Q (OPERAREF gopLUT6QL5Q (LIBRARYREF pango_lib))))
            (FILEID 2 )
            (LINENUM 1 )
              (ATTRIBUTE .REGION_CONSTRAINT (STRING "cpu_core_region"))
            (SITEREF 50 71)
          )
          (NET clk (CONNECT))
        (INSTANNOTATE (INSTREF \ai/cpu/system_cpu_logic_core/count[1]/opit_0_L6QL5Q )
          (PLACE impl_devAL6QL5Q (DEVINSTREF CLMA (SITEREF 171 432)))
        )
'''
        cells = self.parse(text)
        self.assertEqual(len(cells), 1)
        self.assertEqual(cells[0]['site'], [50, 71])
        self.assertEqual(cells[0]['region'], 'cpu_core_region')

    def test_missing_properties_stay_missing(self):
        text = r'''
          (INSTANCE \ai/cpu/system_cpu_logic_core/a  (VIEWREF OPER (CELLREF q)))
          )
          (INSTANCE \unrelated/b (VIEWREF OPER (CELLREF q)))
            (ATTRIBUTE .REGION_CONSTRAINT (STRING "cpu_core_region"))
            (SITEREF 50 71)
          )
'''
        self.assertEqual(self.parse(text), [dict(
            name='ai/cpu/system_cpu_logic_core/a', site=None, region=None)])


if __name__ == '__main__':
    unittest.main()
