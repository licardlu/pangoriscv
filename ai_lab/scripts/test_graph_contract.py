"""Check the actual graph, not just its convolution subsequence."""
import csv
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


def validate(graph, rows):
    ops = graph["ops"]
    convs = [op for op in ops if op["name"] == "CONV"]
    assert len(convs) == len(rows), "convolution count"
    for op in ops:
        refs = op["inputs"]
        assert refs and all(isinstance(r, int) for r in refs), (
            f"{op['module']}: missing tensor inputs")
        assert all(-1 <= r < op["idx"] for r in refs), "non-topological input"
        if op["name"] == "ADD":
            assert len(refs) == 2, "ADD input count"
            assert ops[refs[0]]["out_shape"] == ops[refs[1]]["out_shape"]
        if op["name"] == "CONCAT":
            shapes = [ops[r]["out_shape"] for r in refs]
            assert all(s[1:] == shapes[0][1:] for s in shapes), "concat geometry"
            assert op["out_shape"][0] == sum(s[0] for s in shapes)
    for op, row in zip(convs, rows):
        assert op["module"] == row["module"], "convolution order"
        actual = [op["cin"], op["cout"], op["in_w"], op["in_h"],
                  op["out_w"], op["out_h"]]
        expected = [int(row[k]) for k in
                    ("cin", "cout", "in_w", "in_h", "out_w", "out_h")]
        assert actual == expected, f"{op['module']}: geometry {actual} != {expected}"
        ref = op["inputs"][0]
        shape = [3, graph["size"], graph["size"]] if ref == -1 else ops[ref]["out_shape"]
        assert shape == [op["cin"], op["in_h"], op["in_w"]], (
            f"{op['module']}: producer geometry {shape}")
    assert graph["outputs"] == [op["idx"] for op in convs[-3:]], "detector outputs"


class GraphContract(unittest.TestCase):
    def test_exported_graph(self):
        graph = json.loads((ROOT / "gen/integration/graph.json").read_text())
        with (ROOT / "data/layer_table/layers.csv").open() as handle:
            validate(graph, list(csv.DictReader(handle)))


if __name__ == "__main__":
    unittest.main()
