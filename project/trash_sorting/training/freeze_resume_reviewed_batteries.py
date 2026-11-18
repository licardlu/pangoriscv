"""Freeze visually reviewed complete battery boxes, after fresh metadata isolation.

Reads held-out identity metadata only. Does not edit active experiments or data.
"""
import argparse
from collections import Counter
import hashlib
import json
import os
from pathlib import Path
import numpy as np
from PIL import Image
from audit_public_expansion import features


def read(path): return json.loads(Path(path).read_text(encoding='utf8'))
def sha(path): return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def save(path, value): Path(path).write_text(json.dumps(value, indent=2)+'\n', encoding='utf8')


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--review-root', type=Path, required=True)
    p.add_argument('--out', type=Path, required=True)
    p.add_argument('--source-name', required=True)
    p.add_argument('--source-url', required=True)
    p.add_argument('--group', required=True)
    p.add_argument('--exclude', nargs='*', default=[])
    p.add_argument('--known', nargs='*', default=[])
    a = p.parse_args()
    root, out = a.review_root.resolve(), a.out.resolve()
    assert not out.exists()
    candidates = read(root/'inventory.json')
    known_paths = [
        'build/final_reviewed_increment_20261118_001/dataset_001/manifest.json',
        'build/public_20k_20261117_001/public_dev_001/manifest.json',
        'build/overnight_20261116/dataset_stage4/manifest.json',
        'build/held_background_dev_20261118_001/inventory.json',
        'build/public_expansion_20261117_001/dedup_inventory.json',
        'build/public_targeted_20261118_001/identity_audit.json']+a.known
    known = [r for path in known_paths for r in read(path)]
    cache = 'build/public_20k_20261117_001/historical_feature_cache.json'
    known += list(read(cache).values())
    oldsha = {r.get('image_sha256', r.get('sha256')) for r in known}
    oldpix = {r['sha256_pixels'] for r in known if r.get('sha256_pixels')}
    ph = np.asarray(sorted({int(r['phash']) for r in known if 'phash' in r}), dtype=np.uint64)
    lut = np.asarray([bin(i).count('1') for i in range(256)], dtype=np.uint8)
    rows, ledger = [], {}
    for r in candidates:
        key = r['id']
        if key in a.exclude:
            ledger[key] = dict(status='EXCLUDED_FINAL_VISUAL_REVIEW', reason='Source body/packaging requires further annotation review; excluded explicitly.')
            continue
        image = Path(r['path'])
        assert sha(image) == r['image_sha256']
        with Image.open(image) as im:
            assert im.size == (r['width'], r['height']) and im.getexif().get(274, 1) == 1
        f = features(image)
        assert all(f[k] == r[k] for k in f)
        distance = int(lut[(ph ^ np.uint64(f['phash'])).view(np.uint8).reshape(-1, 8)].sum(1).min())
        duplicate = next((x['id'] for x in rows if x['sha256_pixels'] == f['sha256_pixels']
                          or bin(x['phash'] ^ f['phash']).count('1') <= 6), None)
        reason = ('historical_exact_or_near' if r['image_sha256'] in oldsha
                  or f['sha256_pixels'] in oldpix or distance <= 6 else
                  'within_addition_near_duplicate' if duplicate else None)
        if reason:
            ledger[key] = dict(status='EXCLUDED_IDENTITY_AUDIT', reason=reason,
                               historical_nearest_phash=distance, duplicate=duplicate)
            continue
        assert r['boxes']
        for c, cx, cy, w, h in r['boxes']:
            assert c == 2 and np.isfinite([cx, cy, w, h]).all() and w > 0 and h > 0
            assert -1e-9 <= cx-w/2 < cx+w/2 <= 1+1e-9
            assert -1e-9 <= cy-h/2 < cy+h/2 <= 1+1e-9
        rows.append(dict(r, historical_nearest_phash=distance))
        ledger[key] = dict(status='COMPLETE_BATTERY_BOXES_VISUALLY_REVIEWED',
            source_sha256=r['image_sha256'], boxes=r['boxes'], visible_hand=False)
    images, labels = out/'images/train', out/'labels/train'
    images.mkdir(parents=True); labels.mkdir(parents=True)
    additions = []
    for r in rows:
        image = images/(a.source_name+'_'+r['id']+Path(r['path']).suffix)
        os.link(r['path'], image)
        label = labels/(image.stem+'.txt')
        label.write_text(''.join('2 '+' '.join('%.8f' % v for v in b[1:])+'\n' for b in r['boxes']), encoding='ascii')
        actual = [[float(v) for v in line.split()] for line in label.read_text().splitlines()]
        assert len(actual) == len(r['boxes'])
        assert np.allclose(actual, r['boxes'], rtol=0, atol=1e-7)
        additions.append(dict(source=a.source_name, origin='resume_battery_review_20261118',
            split='train', stem=image.stem, prepared_image=str(image), image_sha256=sha(image),
            width=r['width'], height=r['height'], boxes=r['boxes'], primary_bin=2,
            label=str(label), label_sha256=sha(label), source_url=a.source_url,
            source_file=r.get('source_file', Path(r['path']).name), group=a.group, capture_group=a.group,
            annotation_status=ledger[r['id']]['status'], phash=r['phash'], sha256_pixels=r['sha256_pixels'],
            historical_nearest_phash=r['historical_nearest_phash'], new_source_image=True,
            physical_object_identity_unknown=True, independent_camera_capture=False))
    save(out/'manifest.json', additions); save(out/'review_ledger.json', ledger)
    save(out/'result.json', dict(status='FROZEN_REVIEWED_ANNOTATIONS_NOT_YET_TRAINED',
        source_files=len(additions), battery_boxes=sum(len(r['boxes']) for r in additions),
        decision_counts=dict(Counter(r['status'] for r in ledger.values())),
        review_inventory_sha256=sha(root/'inventory.json'),
        review_evidence={p.name:sha(p) for p in root.glob('*.jpg')},
        identity_metadata_sha256={path:sha(path) for path in known_paths+[cache]},
        manifest_sha256=sha(out/'manifest.json'), derived_images=0, new_camera_captures=0,
        current_experiments_changed=False, final_test_files_read=False,
        limitations=['Product photographs/renderings; not new station or hand-held captures.',
                    'Distinct file identities do not prove distinct physical objects.',
                    'Whole related source stays train only; no independent validation claim.']))
    print(read(out/'result.json'), flush=True)


if __name__ == '__main__': main()
