"""Frozen calibration replay must fail closed on train/schema/identity drift."""
import copy
from pathlib import Path
import sys
import unittest

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools/overnight'))
from calibration_identity import frozen_calibration, ordered_identity


class CalibrationIdentityTest(unittest.TestCase):
    def setUp(self):
        self.classes=['kitchen','recyclable','hazardous','other','hand']
        self.metadata={str(Path('image'+str(i)+'.jpg').resolve()):dict(
            path=str(Path('image'+str(i)+'.jpg').resolve()),sha256=str(i)*64,
            label_sha256=str(i+1)*64,source='reviewed_train',primary_calibration_class=i) for i in range(5)}
        self.reference=dict(classes=self.classes,calibration_images=list(copy.deepcopy(self.metadata).values()))

    def test_order_preserved_and_identity_order_sensitive(self):
        paths=frozen_calibration(self.reference,self.metadata,self.classes)
        self.assertEqual(list(map(str,paths)),list(self.metadata))
        self.assertNotEqual(ordered_identity(paths,self.metadata),ordered_identity(paths[::-1],self.metadata))

    def test_old_provenance_without_label_hash_supported(self):
        for row in self.reference['calibration_images']:row.pop('label_sha256')
        self.assertEqual(len(frozen_calibration(self.reference,self.metadata,self.classes)),5)

    def test_missing_train_changed_pixel_label_or_schema_rejected(self):
        for field in ('sha256','label_sha256','source','primary_calibration_class'):
            reference=copy.deepcopy(self.reference);reference['calibration_images'][0][field]='changed'
            with self.subTest(field=field),self.assertRaises(ValueError):
                frozen_calibration(reference,self.metadata,self.classes)
        missing=dict(self.metadata);missing.pop(next(iter(missing)))
        with self.assertRaises(ValueError):frozen_calibration(self.reference,missing,self.classes)
        with self.assertRaises(ValueError):frozen_calibration(self.reference,self.metadata,self.classes[::-1])

    def test_repeated_image_and_missing_class_rejected(self):
        reference=copy.deepcopy(self.reference)
        reference['calibration_images'].append(reference['calibration_images'][0])
        with self.assertRaises(ValueError):frozen_calibration(reference,self.metadata,self.classes)
        reference['calibration_images']=reference['calibration_images'][1:-1]
        with self.assertRaises(ValueError):frozen_calibration(reference,self.metadata,self.classes)


if __name__=='__main__':unittest.main()
