import unittest

from prepare_priority_smoke import select_records


class PrioritySmokeTest(unittest.TestCase):
    def test_selection_does_not_cherry_pick_predictions(self):
        records = [
            dict(image=f"{category}_{index}.jpg",
                 gt=[{"class": category}], dets=[] if index == 0 else [1])
            for category in ("biodegradable", "cardboard", "glass")
            for index in range(2)
        ]
        chosen = select_records(records, 1)
        self.assertEqual([r["image"] for r in chosen],
                         ["biodegradable_0.jpg", "cardboard_0.jpg"])
        self.assertTrue(all(r["dets"] == [] for r in chosen))

    def test_missing_category_is_an_error(self):
        with self.assertRaises(ValueError):
            select_records([], 1)

    def test_mixed_and_empty_annotations_are_not_selected(self):
        records = [
            dict(image="empty.jpg", gt=[], dets=[]),
            dict(image="mixed.jpg", gt=[{"class": c} for c in
                                       ("biodegradable", "cardboard")], dets=[]),
        ]
        with self.assertRaises(ValueError):
            select_records(records, 1)


if __name__ == "__main__":
    unittest.main()
