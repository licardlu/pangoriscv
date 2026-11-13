"""Append manually reviewed real hand-held scenes to an auxiliary hand dataset.

Hand labels train the independent branch only. Held-item boxes and relations
remain separate evaluation truth; original four-bin weights are not changed.
"""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
from PIL import Image, ImageOps
import yaml
from prepare_hand_context import link


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--base-data', type=Path, required=True)
    p.add_argument('--annotations', type=Path, required=True)
    p.add_argument('--repeat', type=int, default=3)
    p.add_argument('--out', type=Path, required=True)
    a = p.parse_args()
    if not 1 <= a.repeat <= 4:
        raise ValueError('Training repetitions must be 1..4')
    annotations = json.loads(a.annotations.read_text(encoding='utf8'))
    if annotations['status'] != 'VISUALLY_REVIEWED_HAND_OBJECT_RELATIONS':
        raise ValueError('Reviewed hand and object boxes required')
    a.out.mkdir(parents=True, exist_ok=False)
    data = a.out/'dataset'
    rows = json.loads((a.base_data/'manifest.json').read_text(encoding='utf8'))
    for r in rows:
        src = Path(r['prepared_image'])
        if sha(src) != r['sha256']:
            raise ValueError('Base image identity changed')
        dst = data/'images'/r['split']/src.name
        link(src, dst)
        link(a.base_data/'labels'/r['split']/(src.stem+'.txt'),
             data/'labels'/r['split']/(src.stem+'.txt'))
        r['prepared_image'] = str(dst.resolve())
    for r in annotations['images']:
        if r['status'] == 'EXCLUDED':
            continue
        if r['status'] != 'VISUALLY_REVIEWED':
            raise ValueError('Unreviewed image')
        src = Path(r['path'])
        if sha(src) != r['sha256']:
            raise ValueError('Reviewed personal image changed')
        for key in ('hand_xyxy', 'object_xyxy'):
            x1, y1, x2, y2 = r[key]
            if not (0 <= x1 < x2 <= 1 and 0 <= y1 < y2 <= 1):
                raise ValueError('Bad normalized box')
        for rep in range(a.repeat if r['split'] == 'train' else 1):
            dst = data/'images'/r['split']/f"personal_H{r['id']:03d}_{rep}.jpg"
            dst.parent.mkdir(parents=True, exist_ok=True)
            with Image.open(src) as raw:
                image = ImageOps.exif_transpose(raw).convert('RGB')
                image.thumbnail((640, 640))
                image.save(dst, quality=95)
            x1, y1, x2, y2 = r['hand_xyxy']
            box = [0, (x1+x2)/2, (y1+y2)/2, x2-x1, y2-y1]
            label = data/'labels'/r['split']/(dst.stem+'.txt')
            label.parent.mkdir(parents=True, exist_ok=True)
            label.write_text('0 '+' '.join(f'{v:.9f}' for v in box[1:])+'\n', encoding='ascii')
            rows.append(dict(source='personal_handheld', split=r['split'], group='personal_'+r['group'],
                             boxes=[box], prepared_image=str(dst.resolve()), sha256=sha(dst),
                             original_sha256=r['sha256'], original_path=str(src),
                             personal_id=r['id'], repetition=rep,
                             held_object=dict(bin=r['bin'], xyxy=r['object_xyxy'], relation=r['relation'])))
    for left, right in (('train', 'val'), ('train', 'test'), ('val', 'test')):
        for key in ('group', 'sha256', 'original_sha256'):
            s = {r[key] for r in rows if r['split'] == left and key in r}
            t = {r[key] for r in rows if r['split'] == right and key in r}
            if s & t:
                raise ValueError('Split leakage: '+key)
    config = dict(path=str(data.resolve()).replace('\\', '/'), train='images/train',
                  val='images/val', test='images/test', nc=1, names=['hand'])
    (data/'data.yaml').write_text(yaml.safe_dump(config), encoding='utf8')
    (data/'manifest.json').write_text(json.dumps(rows, indent=2), encoding='utf8')
    report = dict(status='PREPARED', annotations_sha256=sha(a.annotations),
                  base_manifest_sha256=sha(a.base_data/'manifest.json'),
                  images=dict(Counter(r['split'] for r in rows)),
                  sources=dict(Counter(r['split']+'/'+r['source'] for r in rows)),
                  classes=['hand'], waste_weights_frozen_required=True,
                  split_policy=annotations['split_policy'],
                  limits=['Same photographer, hand and rooms across personal splits',
                          'Old80 diagnostic photos share some items with new training data',
                          'New battery test views not used for checkpoint selection',
                          'No real kitchen object in new held-item photos'])
    (a.out/'preparation.json').write_text(json.dumps(report, indent=2), encoding='utf8')
    print(json.dumps(report), flush=True)


if __name__ == '__main__':
    main()
