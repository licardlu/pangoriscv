"""Add reviewed full scenes with official hand boxes to a hand-only dataset.

These are contextual views of existing source images, not independent samples.
No garbage or hand-object relation labels are manufactured. Test stays intact.
"""
import argparse
from collections import Counter
import hashlib
import json
import os
from pathlib import Path
import shutil
from PIL import Image
import yaml


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def link(src, dst):
    dst.parent.mkdir(parents=True, exist_ok=True)
    try:
        os.link(src, dst)
    except OSError:
        shutil.copy2(src, dst)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--base-data', type=Path, required=True)
    p.add_argument('--review', type=Path, required=True)
    p.add_argument('--out', type=Path, required=True)
    a = p.parse_args()
    review = json.loads(a.review.read_text(encoding='utf8'))
    if review['status'] != 'VISUALLY_REVIEWED_OFFICIAL_HAND_BOXES':
        raise ValueError('Explicit full-scene visual review required')
    inventory_path = Path(review['inventory'])
    if sha(inventory_path) != review['inventory_sha256']:
        raise ValueError('Context review inventory changed')
    records = json.loads(inventory_path.read_text(encoding='utf8'))
    allow = review['accepted_ids']
    if len(allow) != len(set(allow)):
        raise ValueError('Duplicate reviewed ID')
    a.out.mkdir(parents=True, exist_ok=False)
    data = a.out/'dataset'
    rows = json.loads((a.base_data/'manifest.json').read_text(encoding='utf8'))
    for row in rows:
        src = Path(row['prepared_image'])
        if sha(src) != row['sha256']:
            raise ValueError('Base image changed')
        dst = data/'images'/row['split']/src.name
        link(src, dst)
        link(a.base_data/'labels'/row['split']/(src.stem+'.txt'),
             data/'labels'/row['split']/(src.stem+'.txt'))
        row['prepared_image'] = str(dst.resolve())
    for row in records:
        if row['review_id'] not in allow:
            continue
        if row['split'] not in ('train', 'val'):
            raise ValueError('Contextual test images are not permitted here')
        src = Path(row['path'])
        if sha(src) != row['sha256']:
            raise ValueError('Reviewed context image changed')
        dst = data/'images'/row['split']/('context_'+row['sha256'][:20]+'.jpg')
        dst.parent.mkdir(parents=True, exist_ok=True)
        with Image.open(src) as raw:
            image = raw.convert('RGB')
            image.thumbnail((640, 640))
            image.save(dst, quality=95)
        boxes = []
        for x, y, w, h in row['boxes']:
            if not (0 <= x < x+w <= 1.000001 and 0 <= y < y+h <= 1.000001):
                raise ValueError('Official hand box outside image')
            boxes.append([0, x+w/2, y+h/2, w, h])
        label = data/'labels'/row['split']/(dst.stem+'.txt')
        label.parent.mkdir(parents=True, exist_ok=True)
        label.write_text(''.join('0 '+' '.join(f'{v:.9f}' for v in b[1:])+'\n' for b in boxes), encoding='ascii')
        rows.append(dict(source='reviewed_hand_context', split=row['split'], group=row['group'],
                         boxes=boxes, prepared_image=str(dst.resolve()), sha256=sha(dst),
                         original_sha256=row['sha256'], review_id=row['review_id'],
                         held_object_relation='not annotated; scene may contain objects'))
    for left, right in (('train', 'val'), ('train', 'test'), ('val', 'test')):
        for key in ('group', 'sha256', 'original_sha256'):
            x = {r[key] for r in rows if r['split'] == left and key in r}
            y = {r[key] for r in rows if r['split'] == right and key in r}
            if x & y:
                raise ValueError('Split leakage: '+key)
    config = dict(path=str(data.resolve()).replace('\\', '/'), train='images/train',
                  val='images/val', test='images/test', nc=1, names=['hand'])
    (data/'data.yaml').write_text(yaml.safe_dump(config), encoding='utf8')
    (data/'manifest.json').write_text(json.dumps(rows, indent=2), encoding='utf8')
    report = dict(status='PREPARED', review_sha256=sha(a.review),
                  base_manifest_sha256=sha(a.base_data/'manifest.json'),
                  counts=dict(Counter(r['split'] for r in rows)),
                  sources=dict(Counter(r['split']+'/'+r['source'] for r in rows)),
                  personal_training_images=0, test_used_for_selection=False,
                  limitations=['Full views and crops share physical source images within each split',
                               'Subjects still mostly cover faces or hold cups, not real board hand-held batteries',
                               'Contextual selection is diagnostic; no held-object truth is available'])
    (a.out/'preparation.json').write_text(json.dumps(report, indent=2), encoding='utf8')
    print(json.dumps(report), flush=True)


if __name__ == '__main__':
    main()
