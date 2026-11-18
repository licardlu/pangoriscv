"""Audit existing public classification pictures before complete-box review.

No source classification is converted automatically into detection ground truth.
Held-out image contents are not opened; isolation uses stored identity metadata.
"""
from collections import Counter
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import zipfile

import numpy as np
from PIL import Image

from audit_public_expansion import features
from collect_public_expansion import sheets


def read(path):
    return json.loads(Path(path).read_text(encoding='utf8'))


def main():
    source = Path('build/joint_battery_resume_20261118_001/research/mostafa_battery_001')
    out = Path('build/mostafa_waste_review_20261118_001')
    out.mkdir(exist_ok=True)
    assert not (out/'inventory.json').exists(), 'Already audited; do not repeat.'
    raw = out/'raw'
    raw.mkdir(exist_ok=True)
    paths = [
        'build/joint_battery_more_photos_20261118_001/experiment_001/unique_train.json',
        'build/public_20k_20261117_001/public_dev_001/manifest.json',
        'build/overnight_20261116/dataset_stage4/manifest.json',
        'build/held_background_dev_20261118_001/inventory.json',
        'build/public_expansion_20261117_001/dedup_inventory.json',
        'build/public_targeted_20261118_001/identity_audit.json',
    ]
    known = [r for path in paths for r in read(path)]
    cache = 'build/public_20k_20261117_001/historical_feature_cache.json'
    known += list(read(cache).values())
    oldsha = {r.get('image_sha256', r.get('sha256')) for r in known}
    oldsha.update(r.get('original_sha256') for r in known)
    oldpixels = {r['sha256_pixels'] for r in known if r.get('sha256_pixels')}
    phashes = np.asarray(sorted({int(r['phash']) for r in known if 'phash' in r}), dtype=np.uint64)
    lut = np.asarray([bin(i).count('1') for i in range(256)], dtype=np.uint8)
    categories = {'white-glass', 'green-glass', 'brown-glass', 'biological',
                  'trash', 'metal', 'cardboard', 'paper', 'plastic'}
    candidates = []
    with zipfile.ZipFile(source/'source_v1.zip') as archive:
        for info in archive.infolist():
            parts = Path(info.filename).parts
            if len(parts) < 2 or parts[-2] not in categories:
                continue
            if Path(info.filename).suffix.lower() not in {'.jpg', '.jpeg', '.png'}:
                continue
            assert not {'test', 'val', 'valid'}.intersection(p.lower() for p in parts)
            body = archive.read(info)  # ZIP CRC checked by zipfile.
            path = raw/Path(info.filename).name
            if path.exists():
                assert path.read_bytes() == body
            else:
                path.write_bytes(body)
            candidates.append(dict(id='mostafa_waste_'+path.stem, path=str(path.resolve()),
                source_file=info.filename, source_classification=parts[-2],
                image_sha256=hashlib.sha256(body).hexdigest(), source_split='unsplit_train_only'))

    def inspect(row):
        row = dict(row)
        try:
            with Image.open(row['path']) as im:
                assert im.getexif().get(274, 1) == 1
                row.update(width=im.width, height=im.height)
            row.update(features(row['path']))
            distance = int(lut[(phashes ^ np.uint64(row['phash'])).view(np.uint8).reshape(-1, 8)].sum(1).min())
            row['historical_nearest_phash'] = distance
            reason = ('EXCLUDE_HISTORICAL_EXACT_OR_NEAR'
                      if row['image_sha256'] in oldsha or row['sha256_pixels'] in oldpixels or distance <= 6
                      else 'PENDING_COMPLETE_INSTANCE_HAND_AND_POLICY_REVIEW')
            row.update(admission=reason, annotations=[], category_names={})
        except Exception as error:
            row.update(admission='EXCLUDE_DECODE_OR_ORIENTATION', error=repr(error))
        return row

    checkpoint = out/'scanned_inventory.json'
    if checkpoint.exists():
        rows = read(checkpoint)
        assert [(r['id'], r['image_sha256']) for r in rows] == [(r['id'], r['image_sha256']) for r in candidates]
    else:
        with ThreadPoolExecutor(max_workers=2) as pool:
            rows = []
            for i, row in enumerate(pool.map(inspect, candidates), 1):
                rows.append(row)
                if i % 500 == 0:
                    print('scanned', i, '/', len(candidates), flush=True)
        checkpoint.write_text(json.dumps(rows, indent=2), encoding='utf8')
    accepted = []
    for row in rows:
        if not row['admission'].startswith('PENDING_'):
            continue
        duplicate = next((r['id'] for r in accepted if r['sha256_pixels'] == row['sha256_pixels']
                          or bin(r['phash'] ^ row['phash']).count('1') <= 6), None)
        if duplicate:
            row.update(admission='EXCLUDE_INTERNAL_NEAR_DUPLICATE', duplicate=duplicate)
        else:
            accepted.append(row)
    (out/'inventory.json').write_text(json.dumps(rows, indent=2), encoding='utf8')
    for category in sorted(categories):
        selected = [r for r in accepted if r['source_classification'] == category]
        directory = out/category
        directory.mkdir()
        (directory/'inventory.json').write_text(json.dumps(selected, indent=2), encoding='utf8')
        sheets(selected, directory, 'unreviewed')
    result = dict(status='CANDIDATES_ONLY_NOT_TRAINING', source_files=len(rows),
        source='mostafaabla/garbage-classification v1',
        archive_sha256=read(source/'result.json')['archive_sha256'],
        counts=dict(Counter(r['admission'] for r in rows)),
        pending_by_source_class=dict(Counter(r['source_classification'] for r in accepted)),
        identity_metadata_sha256={p: hashlib.sha256(Path(p).read_bytes()).hexdigest() for p in paths+[cache]},
        training_images_added=0, held_out_image_contents_read=False,
        limitations='Classification labels are discovery hints only. Entire related source stays train-only; file hashes do not prove physical-object independence. Mixed web/product images, no new station captures.')
    (out/'result.json').write_text(json.dumps(result, indent=2), encoding='utf8')
    print(result, flush=True)


if __name__ == '__main__':
    main()
