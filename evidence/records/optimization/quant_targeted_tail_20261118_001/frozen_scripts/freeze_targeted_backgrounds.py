"""Freeze visually reviewed new originals and explicitly derived empty crops.

Preserves the current cleaned whitelist and every validation/test metadata row.
Does not read validation/test image or label contents.
"""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path

from PIL import Image


def read(path):
    return json.loads(Path(path).read_text(encoding='utf8'))


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def save(path, value):
    Path(path).write_text(json.dumps(value, indent=2) + '\n', encoding='utf8')


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--root', type=Path, required=True)
    p.add_argument('--base', type=Path, required=True)
    p.add_argument('--out', type=Path, required=True)
    a = p.parse_args()
    root = a.root.resolve()
    out = a.out.resolve()
    out.mkdir(parents=True, exist_ok=False)
    base = read(a.base)
    inventory = read(root/'identity_audit.json')
    ledger = read(root/'review_ledger.json')
    background = read(root/'background_review_ledger.json')
    additions = []
    labels = out/'labels/train'
    labels.mkdir(parents=True)
    corrections = []
    for row in inventory:
        review = ledger['images'].get(row['id'], {})
        if review.get('status') != 'VISUALLY_REVIEWED_ACCEPT':
            continue
        assert row['admission'] == 'REQUIRES_VISUAL_REVIEW'
        assert sha(row['path']) == review['source_sha256'] == row['image_sha256']
        assert row['source_file'].split('/')[0] not in {'batch_5', 'batch_13'}
        w, h = row['width'], row['height']
        boxes = []
        for c, x1, y1, x2, y2 in review['boxes']:
            clipped = [max(0, x1), max(0, y1), min(w, x2), min(h, y2)]
            if clipped != [x1, y1, x2, y2]:
                assert max(abs(u-v) for u, v in zip(clipped, [x1,y1,x2,y2])) < .5
                corrections.append(dict(id=row['id'], before=[x1,y1,x2,y2], after=clipped,
                    reason='Subpixel source box outside image edge; clip to actual image boundary.'))
            x1, y1, x2, y2 = clipped
            assert 0 <= x1 < x2 <= w and 0 <= y1 < y2 <= h
            boxes.append([c, (x1+x2)/2/w, (y1+y2)/2/h, (x2-x1)/w, (y2-y1)/h])
        label = labels/(row['id']+'.txt')
        label.write_text(''.join(str(b[0])+' '+' '.join('%.8f'%v for v in b[1:])+'\n' for b in boxes), encoding='ascii')
        additions.append(dict(source='targeted_taco_reviewed', origin='targeted_review_20261118',
            split='train', stem=row['id'], prepared_image=row['path'], image_sha256=row['image_sha256'],
            sha256_pixels=row['sha256_pixels'], phash=row['phash'], width=w, height=h, boxes=boxes,
            primary_bin=int(max(boxes,key=lambda b:b[3]*b[4])[0]),
            group='taco_'+row['source_file'].split('/')[0], capture_group='taco_'+row['source_file'].split('/')[0],
            source_file=row['source_file'], source_image_id=row['source_image_id'], source_url=row['url'],
            annotation_status='SOURCE_BOXES_AND_MANUAL_HANDS_VISUALLY_REVIEWED',
            label=str(label), label_sha256=sha(label), count_as_new_source_photo=True))
    by_id = {row['stem']: row for row in additions}
    assert len(additions) == 40
    for crop in background:
        assert crop['status'] == 'VISUALLY_CONFIRMED_EMPTY' and crop['reviewer'] == 'assistant_visual'
        assert crop['boxes'] == [] and crop['source_object_intersection'] == 0
        source = by_id[crop['source_id']]
        assert crop['source_sha256'] == source['image_sha256']
        path = Path(crop['path'])
        assert sha(path) == crop['image_sha256']
        with Image.open(path) as im:
            w, h = im.size
        label = labels/(path.stem+'.txt')
        label.write_text('', encoding='ascii')
        additions.append(dict(source='targeted_reviewed_background_crop', origin='targeted_review_20261118',
            split='train', stem=path.stem, prepared_image=str(path), image_sha256=sha(path),
            width=w, height=h, boxes=[], primary_bin=4, group=source['group'],
            capture_group=source['capture_group'], source_image_id=source['source_image_id'],
            source_file=source['source_file'], source_url=source['source_url'],
            parent_image_sha256=source['image_sha256'], crop_xyxy=crop['crop_xyxy'],
            annotation_status='ASSISTANT_VISUALLY_CONFIRMED_EMPTY_DERIVED_TRAIN_ONLY',
            label=str(label), label_sha256=sha(label), count_as_new_source_photo=False))
    assert len(additions) == 54
    old = {r['image_sha256'] for r in base}
    assert not old.intersection(r['image_sha256'] for r in additions)
    assert len({r['image_sha256'] for r in additions}) == len(additions)
    # Four explicit draws per added training view, fixed before training.
    rows = base + [dict(r, targeted_draw=n) for n in range(4) for r in additions]
    assert [r for r in rows if r['split'] in ('val', 'test')] == [r for r in base if r['split'] in ('val', 'test')]
    save(out/'manifest.json', rows)
    save(out/'additions.json', additions)
    for split in ('train', 'val', 'test'):
        (out/(split+'.txt')).write_text(''.join(r['prepared_image']+'\n' for r in rows if r['split']==split), encoding='utf8')
    (out/'data.yaml').write_text('path: '+out.as_posix()+'\ntrain: train.txt\nval: val.txt\ntest: test.txt\nnc: 5\nnames: [kitchen, recyclable, hazardous, other, hand]\n', encoding='utf8')
    save(out/'result.json', dict(status='FROZEN_REVIEWED_NOT_YET_TRAINED',
        base_manifest_sha256=sha(a.base), base_clean_whitelist_rows_preserved=len(base),
        base_train_file_identities=len({r['image_sha256'] for r in base if r['split']=='train'}),
        new_original_source_photos=40, derived_empty_crops=14, new_training_files=54,
        total_train_file_identities=len({r['image_sha256'] for r in rows if r['split']=='train'}),
        draws_per_epoch=sum(r['split']=='train' for r in rows), added_draws_per_file=4,
        new_class_instances=dict(Counter(int(b[0]) for r in additions for b in r['boxes'])),
        new_hand_boxes_added=2, subpixel_boundary_corrections=corrections,
        val_test_metadata_unchanged=True, final_test_images_or_labels_read=False,
        review_ledger_sha256=sha(root/'review_ledger.json'),
        background_review_sha256=sha(root/'background_review_ledger.json'),
        limitations=['Derived crops are not new source photographs or independent physical objects.',
            'No accepted new battery or glass image in this subset.',
            'No new independent validation set; training additions must not be reported as accuracy evidence.']))
    print(read(out/'result.json'), flush=True)


if __name__ == '__main__':
    main()
