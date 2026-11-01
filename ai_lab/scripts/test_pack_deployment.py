"""Check packed bytes, graph references, and the real engine buffer bounds."""
import json
from pathlib import Path
import tempfile
import unittest

import numpy as np
from pack_deployment import pack

ROOT = Path(__file__).resolve().parents[1]


class PackingTest(unittest.TestCase):
    def test_real_model(self):
        source = ROOT / "gen/integration/deployment"
        arrays = np.load(source / "parameters.npz")
        graph = json.loads((source / "bundle.json").read_text())
        with tempfile.TemporaryDirectory() as folder:
            result = pack(source, Path(folder))
            blob = (Path(folder) / "model.bin").read_bytes()
            self.assertEqual(len(result["ops"]), 85)
            self.assertEqual(len(result["tensors"]), 86)
            intervals = sorted((r["address"], r["address"] + r["length"])
                               for r in result["regions"])
            for left, right in zip(intervals, intervals[1:]):
                self.assertLessEqual(left[1], right[0])
            for original, op in zip(graph["ops"], result["ops"]):
                self.assertEqual(op["inputs"], [i + 1 for i in original["inputs"]])
                self.assertEqual(op["output"], original["idx"] + 1)
                if op["kind"] != "YOLO_CONV":
                    continue
                cfg = op["conv"]
                self.assertEqual(cfg["a_base"],
                                 result["tensors"][op["inputs"][0]]["address"])
                self.assertLessEqual(((cfg["tr"]-1)*cfg["stride"]+cfg["k"]) *
                                     (cfg["in_w"]+2*cfg["pad"])*(cfg["cin"]//8), 7168)
                self.assertLessEqual(cfg["k"]**2*(cfg["cin"]//8), 576)
                expected = arrays[f'op{original["idx"]}_weight'].transpose(0, 2, 3, 1)
                length = cfg["cout"] * cfg["k"]**2 * cfg["cin"]
                offset = cfg["w_base"] - result["blob_base"]
                actual = np.frombuffer(blob[offset:offset+length], np.int8).reshape(
                    cfg["cout"], cfg["k"], cfg["k"], cfg["cin"])
                np.testing.assert_array_equal(actual[..., :original["cin"]], expected)
                self.assertTrue(np.all(actual[..., original["cin"]:] == 0))
            self.assertEqual(sum(o["kind"] == "YOLO_HEAD" for o in result["ops"]), 3)
            self.assertIn("yolo_ops", (Path(folder) / "deployment_model.h").read_text())

    def test_unsafe_address_map_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            with self.assertRaises(ValueError):
                pack(ROOT / "gen/integration/deployment", Path(folder),
                     base=0x01000000, tensor_base=0x01000100)


if __name__ == "__main__":
    unittest.main()
