"""Append reviewed held/empty-hand scenes without altering an existing dataset."""
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
    p.add_argument('--out', type=Path, required=True)
    p.add_argument('--train-repeat', type=int, default=3)
    p.add_argument('--batch-id', default='043', help='Provenance label for reviewed personal scenes')
    p.add_argument('--hand-only', action='store_true', help='Explicit reviewed nc=1 hand base, never convert unreviewed waste negatives')
    a = p.parse_args()
    if not 1 <= a.train_repeat <= 3:
        raise ValueError('Train repeat must be 1..3')
    review = json.loads(a.annotations.read_text(encoding='utf8'))
    if review['status'] != 'VISUALLY_REVIEWED_HAND_OBJECT_RELATIONS':
        raise ValueError('Explicit overlay review required')
    config = yaml.safe_load((a.base_data/'data.yaml').read_text(encoding='utf8'))
    expected_names = ['hand'] if a.hand_only else ['kitchen', 'recyclable', 'hazardous', 'other', 'hand']
    if config['nc'] != len(expected_names) or config['names'] != expected_names:
        raise ValueError('Unexpected base taxonomy')
    rows = json.loads((a.base_data/'manifest.json').read_text(encoding='utf8'))
    a.out.mkdir(parents=True, exist_ok=False)
    data = a.out/'dataset'
    base_labels = {}
    for r in rows:
        src = Path(r['prepared_image'])
        if sha(src) != r['sha256']:
            raise ValueError('Base image identity changed')
        label = a.base_data/'labels'/r['split']/(src.stem+'.txt')
        dst = data/'images'/r['split']/src.name
        link(src, dst)
        link(label, data/'labels'/r['split']/label.name)
        base_labels[str(label)] = sha(label)
        r['prepared_image'] = str(dst.resolve())
    unique = Counter()
    for r in review['images']:
        if r['status'] == 'EXCLUDED':
            continue
        if r['status'] != 'VISUALLY_REVIEWED' or r['split'] not in ('train', 'val'):
            raise ValueError('Unreviewed scene or forbidden test addition')
        src = Path(r['path'])
        if sha(src) != r['sha256']:
            raise ValueError('Personal source changed')
        empty = r['object_xyxy'] is None
        if empty != (r['bin'] is None) or empty != (r['group'] == 'empty_hand'):
            raise ValueError('Empty hand must have no subject or bucket')
        boxes = []
        for box, category in ((r['object_xyxy'], r['bin']), (r['hand_xyxy'], 4)):
            if a.hand_only and category != 4:
                continue
            if box is None:
                continue
            x1, y1, x2, y2 = box
            if not (0 <= x1 < x2 <= 1 and 0 <= y1 < y2 <= 1):
                raise ValueError('Invalid normalized box')
            boxes.append([0 if a.hand_only else category, (x1+x2)/2, (y1+y2)/2, x2-x1, y2-y1])
        for rep in range(a.train_repeat if r['split'] == 'train' else 1):
            dst = data/'images'/r['split']/f"personal_N{r['id']:03d}_{rep}.jpg"
            dst.parent.mkdir(parents=True, exist_ok=True)
            if dst.exists():
                raise ValueError('Destination collision')
            with Image.open(src) as raw:
                im = ImageOps.exif_transpose(raw).convert('RGB')
                if list(im.size) != r['display_size']:
                    raise ValueError('Orientation mismatch')
                im.thumbnail((640, 640))
                im.save(dst, quality=95)
            label = data/'labels'/r['split']/(dst.stem+'.txt')
            label.parent.mkdir(parents=True, exist_ok=True)
            label.write_text(''.join(str(b[0])+' '+' '.join(f'{v:.9f}' for v in b[1:])+'\n' for b in boxes), encoding='ascii')
            rows.append(dict(source='personal_handheld', split=r['split'],
                group='personal_'+r['group'], primary_bin=0 if a.hand_only else 4 if empty else r['bin'],
                boxes=boxes, prepared_image=str(dst.resolve()), sha256=sha(dst),
                original_sha256=r['sha256'], original_path=str(src), personal_id=r['id'],
                personal_batch=a.batch_id, repetition=rep, empty_hand=empty,
                held_object=None if empty else dict(bin=r['bin'], xyxy=r['object_xyxy'], relation=r['relation']),
                annotation_scope=r['annotation_scope']))
        unique[r['split']] += 1
    for left, right in (('train', 'val'), ('train', 'test'), ('val', 'test')):
        for key in ('group', 'sha256', 'original_sha256'):
            s = {r[key] for r in rows if r['split'] == left and key in r}
            t = {r[key] for r in rows if r['split'] == right and key in r}
            if s & t:
                raise ValueError(f'Split leakage {key}: {s & t}')
    # Hard-linked originals must remain byte-for-byte identical.
    if any(sha(Path(path)) != digest for path, digest in base_labels.items()):
        raise ValueError('Base labels modified')
    config['path'] = str(data.resolve()).replace('\\', '/')
    (data/'data.yaml').write_text(yaml.safe_dump(config), encoding='utf8')
    (data/'manifest.json').write_text(json.dumps(rows, indent=2), encoding='utf8')
    result = dict(status='PREPARED', counts=dict(Counter(r['split'] for r in rows)),
        added_unique=dict(unique), train_repeat=a.train_repeat, hand_only=a.hand_only, batch_id=a.batch_id,
        empty_hand_unique=sum(r.get('empty_hand', False) and r.get('repetition') == 0 for r in rows),
        base_images_and_labels_unchanged=True, split_group_sha_isolation=True,
        base_manifest_sha256=sha(a.base_data/'manifest.json'), review_sha256=sha(a.annotations),
        preparation_script_sha256=sha(Path(__file__)), battery_test_used=False,
        limitations=['Background waste not exhaustively labelled',
                     'Same person and rooms across personal splits',
                     'New battery group held out; no new hazardous training scenes'])
    (a.out/'preparation.json').write_text(json.dumps(result, indent=2), encoding='utf8')
    print(json.dumps(result), flush=True)


if __name__ == '__main__':
    main()
