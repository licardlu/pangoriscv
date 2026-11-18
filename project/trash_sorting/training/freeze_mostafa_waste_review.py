"""Freeze only explicitly reviewed source and box overlays for future training."""
from collections import Counter
import argparse
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
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--reviewed',default='annotations_002')
    parser.add_argument('--out',default='frozen_additions_001')
    parser.add_argument('--exclusion-json',type=Path)
    parser.add_argument('--additional-identity-inventory',type=Path,action='append',default=[])
    args=parser.parse_args()
    root = Path('build/mostafa_waste_review_20261118_001').resolve()
    reviewed = root/args.reviewed
    out = root/args.out
    assert not out.exists()
    # Deliberately omit uncertain material and incomplete borders found in overlay review.
    excluded = {'mostafa_waste_white-glass584': 'Opaque decorative pitcher material uncertain.',
                'mostafa_waste_white-glass597': 'Stacked/rimmed vessel material or instance count uncertain.',
                'mostafa_waste_trash11': 'Diaper edge extends beyond drawn box; defer rather than admit incomplete annotation.'}
    if args.exclusion_json:excluded=read(args.exclusion_json)
    paths = ['build/joint_battery_more_photos_20261118_001/experiment_001/unique_train.json',
             'build/public_20k_20261117_001/public_dev_001/manifest.json',
             'build/overnight_20261116/dataset_stage4/manifest.json',
             'build/held_background_dev_20261118_001/inventory.json',
             'build/public_expansion_20261117_001/dedup_inventory.json',
             'build/public_targeted_20261118_001/identity_audit.json']
    known = [r for p in paths for r in read(p)]
    for path in args.additional_identity_inventory:known+=read(path)
    cache = 'build/public_20k_20261117_001/historical_feature_cache.json'
    known += list(read(cache).values())
    oldsha = {r.get('image_sha256', r.get('sha256')) for r in known}
    oldsha.update(r.get('original_sha256') for r in known)
    oldpix = {r['sha256_pixels'] for r in known if r.get('sha256_pixels')}
    ph = np.asarray(sorted({int(r['phash']) for r in known if 'phash' in r}), dtype=np.uint64)
    lut = np.asarray([bin(i).count('1') for i in range(256)], dtype=np.uint8)
    source_ledger = read(reviewed/'ledger.json')
    rows, ledger = [], {}
    for r in read(reviewed/'inventory.json'):
        key = r['id']
        if key in excluded:
            ledger[key] = dict(status='EXCLUDED_FINAL_OVERLAY', reason=excluded[key])
            continue
        assert r['admission'].startswith('PENDING_') and r['source_split'] == 'unsplit_train_only'
        assert source_ledger[key]['source_sha256'] == r['image_sha256'] == sha(r['path'])
        with Image.open(r['path']) as im:
            assert im.size == (r['width'], r['height']) and im.getexif().get(274, 1) == 1
        f = features(r['path'])
        assert all(r[k] == v for k, v in f.items())
        distance = int(lut[(ph ^ np.uint64(r['phash'])).view(np.uint8).reshape(-1,8)].sum(1).min())
        assert r['image_sha256'] not in oldsha and r['sha256_pixels'] not in oldpix and distance > 6
        assert not any(x['sha256_pixels'] == r['sha256_pixels'] or bin(x['phash'] ^ r['phash']).count('1') <= 6 for x in rows)
        for c, cx, cy, w, h in r['boxes']:
            assert c in range(5) and w > 0 and h > 0 and np.isfinite([cx,cy,w,h]).all()
            assert -1e-9 <= cx-w/2 < cx+w/2 <= 1+1e-9 and -1e-9 <= cy-h/2 < cy+h/2 <= 1+1e-9
        assert r['boxes']
        rows.append(r)
        ledger[key] = dict(source_ledger[key], status='SOURCE_AND_FINAL_OVERLAY_VISUALLY_REVIEWED',
            boxes=r['boxes'], visible_hand=False, nearest_recorded_historical_phash=distance)
    images, labels = out/'images/train', out/'labels/train'
    images.mkdir(parents=True); labels.mkdir(parents=True)
    additions = []
    for r in rows:
        image = images/(r['id']+Path(r['path']).suffix)
        os.link(r['path'], image)
        label = labels/(image.stem+'.txt')
        label.write_text(''.join(str(int(b[0]))+' '+' '.join('%.8f' % x for x in b[1:])+'\n' for b in r['boxes']), encoding='ascii')
        actual = [[float(v) for v in line.split()] for line in label.read_text().splitlines()]
        assert np.allclose(actual, r['boxes'], rtol=0, atol=1e-7)
        additions.append(dict(source='mostafa_reviewed_'+r['source_classification'],
            origin='mostafa_waste_complete_boxes_20261118', split='train', stem=image.stem,
            prepared_image=str(image), image_sha256=sha(image), width=r['width'], height=r['height'],
            boxes=r['boxes'], primary_bin=int(r['boxes'][0][0]), label=str(label), label_sha256=sha(label),
            group='mostafa_web_collection_train_only', capture_group='mostafa_web_collection_train_only',
            source_url='https://www.kaggle.com/datasets/mostafaabla/garbage-classification',
            source_file=r['source_file'], annotation_status=ledger[r['id']]['status'],
            phash=r['phash'], sha256_pixels=r['sha256_pixels'], historical_nearest_phash=r['historical_nearest_phash'],
            new_source_image=True, independent_camera_capture=False, physical_object_identity_unknown=True))
    save(out/'manifest.json', additions); save(out/'review_ledger.json', ledger)
    save(out/'result.json', dict(status='FROZEN_REVIEWED_SOURCE_ADDITIONS_NOT_YET_TRAINED',
        source_files=len(additions), box_instances=dict(Counter(int(b[0]) for r in additions for b in r['boxes'])),
        source_counts=dict(Counter(r['source'] for r in additions)), derived_images=0, new_camera_captures=0,
        manifest_sha256=sha(out/'manifest.json'), review_inventory_sha256=sha(reviewed/'inventory.json'),
        source_review_ledger_sha256=sha(reviewed/'ledger.json'),
        final_overlay_sha256={p.name:sha(p) for p in reviewed.glob('overlay_*.jpg')},
        identity_metadata_sha256={str(p):sha(p) for p in paths+[cache]+args.additional_identity_inventory},
        current_experiments_changed=False, final_test_files_read=False,
        limitations=['Mostly product/web photographs; no new camera station captures.',
                    'Distinct file identity does not prove distinct physical objects or independent validation.',
                    'No source-wide random new dev split; retain original photo provenance, no redistribution.']))
    print(read(out/'result.json'), flush=True)


if __name__ == '__main__': main()
