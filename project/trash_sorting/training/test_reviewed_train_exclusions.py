import json
from pathlib import Path
import tempfile
import unittest
from reviewed_train_exclusions import load_exclusions, validate_exclusion


class ReviewedExclusions(unittest.TestCase):
    def setUp(self):
        self.review = dict(prepared_sha256='a'*64, split='train', source='codingbear',
                           group=5, reason='Contradictory classes on same visible object')

    def load(self, images, status='VISUALLY_REVIEWED_TRAIN_EXCLUSIONS'):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder)/'review.json'
            path.write_text(json.dumps(dict(status=status, images=images)), encoding='utf8')
            return load_exclusions(path)

    def test_exact_reviewed_train_identity_is_accepted(self):
        got = self.load([self.review])
        row = dict(self.review, sha256='a'*64)
        validate_exclusion(row, got['a'*64])

    def test_validation_test_and_missing_reason_are_rejected(self):
        for change in [dict(split='val'), dict(split='test'), dict(reason=''), dict(source='personal_handheld')]:
            with self.assertRaises(ValueError):
                self.load([dict(self.review, **change)])

    def test_duplicate_or_unreviewed_exclusions_are_rejected(self):
        with self.assertRaises(ValueError):self.load([self.review, self.review])
        with self.assertRaises(ValueError):self.load([self.review], 'PROPOSED')

    def test_wrong_group_or_digest_cannot_remove_another_image(self):
        row = dict(self.review, sha256='a'*64)
        for change in [dict(group=6), dict(sha256='b'*64), dict(split='val')]:
            with self.assertRaises(ValueError):
                validate_exclusion(dict(row, **change), self.review)


if __name__ == '__main__':unittest.main()
