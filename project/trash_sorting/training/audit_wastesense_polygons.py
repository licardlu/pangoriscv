"""Audit an already acquired polygon source; produce review candidates only.

Historical held-out files are never opened: stored hashes/names exclude them.
All four upstream material names need individual policy/completeness review.
No segmentation proposal is automatically admitted as a detection annotation.
"""
from collections import Counter
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
import re
from pathlib import Path

import numpy as np
from PIL import Image

from audit_public_expansion import features
from collect_public_expansion import sheets


def read(path):
    return json.loads(Path(path).read_text(encoding='utf8'))


def main():
    base = Path('build/public_20k_20261117_001')
    out = Path('build/wastesense_review_20261118_001')
    out.mkdir(exist_ok=False)
    raw = Path(read(base/'wastesense_acquisition.json')['raw'])
    known = []
    for path in [base/'dataset_004/manifest.json', base/'public_dev_001/manifest.json',
                 Path('build/overnight_20261116/dataset_stage4/manifest.json'),
                 Path('build/public_expansion_20261117_001/dedup_inventory.json'),
                 Path('build/public_targeted_20261118_001/identity_audit.json'),
                 Path('build/held_background_dev_20261118_001/inventory.json'),
                 Path('build/extras_battery_candidates_20261118_001/inventory.json')]:
        known += read(path)
    known += list(read(base/'historical_feature_cache.json').values())
    oldsha = {r.get('image_sha256', r.get('sha256')) for r in known}
    oldsha.update(r.get('original_sha256') for r in known)
    oldpixels = {r.get('sha256_pixels') for r in known if r.get('sha256_pixels')}
    oldph = np.asarray(sorted({int(r['phash']) for r in known if 'phash' in r}), dtype=np.uint64)
    oldnames = set()
    for row in known:
        if row.get('source') == 'sumn2u':
            for key in ['image', 'label']:
                if row.get(key):
                    oldnames.add(Path(row[key]).stem.lower())
    lut = np.asarray([bin(i).count('1') for i in range(256)], dtype=np.uint8)

    def inspect(path):
        key = path.stem
        canonical = re.sub(r'^[0-9a-f]{8}-', '', key.lower())
        row = dict(id='ws_'+key, path=str(path.resolve()), source='wastesense_polygon_review',
                   source_file='images/'+path.name, canonical_source_stem=canonical,
                   annotation_status='UNREVIEWED_POLYGON_SOURCE_NOT_TRAINABLE',
                   category_names={str(i): 'source_material_'+str(i) for i in range(4)})
        if canonical in oldnames:
            return dict(row, admission='EXCLUDE_HISTORICAL_SOURCE_IDENTITY')
        try:
            with Image.open(path) as im:
                assert im.getexif().get(274,1) == 1, 'Unresolved orientation'
                w,h = im.size
            row.update(width=w, height=h, image_sha256=hashlib.sha256(path.read_bytes()).hexdigest(), **features(path))
            distance = int(lut[(oldph ^ np.uint64(row['phash'])).view(np.uint8).reshape(-1,8)].sum(1).min())
            row['historical_nearest_phash'] = distance
            if row['image_sha256'] in oldsha or row['sha256_pixels'] in oldpixels or distance <= 6:
                return dict(row, admission='EXCLUDE_HISTORICAL_EXACT_OR_NEAR')
            label = raw/'labels'/(key+'.txt')
            annotations = []
            for line in label.read_text().splitlines():
                if not line.strip():
                    continue
                values = list(map(float,line.split()))
                c = int(values[0]); assert c == values[0] and c in range(4)
                points = np.asarray(values[1:]).reshape(-1,2)
                assert len(points) >= 3 and np.isfinite(points).all()
                assert (points >= 0).all() and (points <= 1).all()
                lo,hi = points.min(0),points.max(0)
                assert (hi > lo).all()
                annotations.append(dict(category_id=c, bbox=[lo[0]*w,lo[1]*h,(hi[0]-lo[0])*w,(hi[1]-lo[1])*h],
                                        polygon=points.tolist()))
            assert annotations, 'No complete polygons'
            return dict(row, annotations=annotations, label_sha256=hashlib.sha256(label.read_bytes()).hexdigest(),
                        admission='REQUIRES_VISUAL_COMPLETE_INSTANCE_AND_POLICY_REVIEW')
        except Exception as error:
            return dict(row, admission='EXCLUDE_SCHEMA_OR_DECODE', error=repr(error))

    paths = sorted((raw/'images').iterdir())
    with ThreadPoolExecutor(max_workers=2) as pool:
        rows = list(pool.map(inspect, paths))
    eligible = []
    for row in rows:
        if row['admission'] != 'REQUIRES_VISUAL_COMPLETE_INSTANCE_AND_POLICY_REVIEW':
            continue
        if any(row['sha256_pixels'] == r['sha256_pixels'] or
               bin(row['phash'] ^ r['phash']).count('1') <= 6 for r in eligible):
            row['admission'] = 'EXCLUDE_INTERNAL_NEAR_DUPLICATE'
        else:
            eligible.append(row)
    (out/'inventory.json').write_text(json.dumps(rows,indent=2),encoding='utf8')
    report = dict(status='REVIEW_CANDIDATES_ONLY_NO_TRAINING_ADMISSION',
        total=len(rows), counts=dict(Counter(r['admission'] for r in rows)),
        historical_metadata_rows=len(known), historical_phashes=len(oldph),
        final_test_files_opened=False, new_training_images=0,
        source='https://www.kaggle.com/datasets/sumn2u/wastesense',
        license='CC BY-NC 4.0 according to version 2 uploader metadata; retain upstream attribution',
        mapping='No class conversion admitted; material names/IDs, four-bin policy and complete hands/objects require visual review.',
        group='Any future admitted images from this unsplit source stay entirely train; no fabricated validation split.')
    (out/'result.json').write_text(json.dumps(report,indent=2),encoding='utf8')
    sheets(eligible,out,'review')
    print(report,flush=True)


if __name__ == '__main__':
    main()
