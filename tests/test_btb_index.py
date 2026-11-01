"""BTB candidate index model and the actual GShare initialization contract.

The folded function below is an offline candidate, not the selected RTL.
"""
import pathlib
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]
DISPATCH = ROOT / "rtl" / "core" / "sections" / "020_DispatchPlugin.vh"
BTB = ROOT / "rtl" / "core" / "sections" / "036_BtbPlugin.vh"


class BtbIndexTests(unittest.TestCase):
    def test_candidate_fold_separates_one_known_alias(self):
        # These two hot branches share the old 256-entry index and bank.
        pc_a = 0x800010A6
        pc_b = 0x800028A4
        old_a = (pc_a >> 3) & 0xFF
        old_b = (pc_b >> 3) & 0xFF
        self.assertEqual(old_a, old_b)

        # Fold a higher PC slice into the line index without changing the
        # BTB storage size or the tag comparison.
        folded_a = ((pc_a >> 3) ^ (pc_a >> 12)) & 0xFF
        folded_b = ((pc_b >> 3) ^ (pc_b >> 12)) & 0xFF
        self.assertNotEqual(folded_a, folded_b)

    def test_gshare_reset_state_matches_reference(self):
        text = BTB.read_text(encoding="utf-8")
        self.assertIn("assign _zz_GSharePlugin_logic_mem_write_payload_data_0 = 8'h0;", text)

if __name__ == "__main__":
    unittest.main()
