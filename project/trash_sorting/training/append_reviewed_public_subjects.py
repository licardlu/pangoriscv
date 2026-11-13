"""Append manually reviewed public detection boxes to train; preserve all splits."""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageOps
import yaml
from prepare_hand_context import link


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--base-data', type=Path, required=True)
    p.add_argument('--annotations', type=Path, required=True)
    p.add_argument('--out', type=Path, required=True)
    p.add_argument('--train-repeat', type=int, default=3)
    a = p.parse_args()
    if not 1 <= a.train_repeat <= 3:
        raise ValueError('Repeat must be 1..3')
    review = json.loads(a.annotations.read_text(encoding='utf8'))
    if review['status'] != 'VISUALLY_REVIEWED_PUBLIC_SUBJECTS' or not review.get('license'):
        raise ValueError('Explicit visual review and license evidence required')
    config = yaml.safe_load((a.base_data/'data.yaml').read_text(encoding='utf8'))
    if config['names'] != ['kitchen', 'recyclable', 'hazardous', 'other', 'hand'] or config['nc'] != 5:
        raise ValueError('Expected four bins and internal hand class')
    rows = json.loads((a.base_data/'manifest.json').read_text(encoding='utf8'))
    known = {r[k] for r in rows for k in ('sha256', 'original_sha256') if k in r}
    names = set()
    # Validate every source before creating a partially prepared dataset.
    for r in review['images']:
        if r['status'] != 'VISUALLY_REVIEWED' or r['split'] != 'train':
            raise ValueError('Only reviewed train additions are allowed')
        if not r.get('source_url') or not r.get('source_license') or not r.get('group'):
            raise ValueError('Missing public provenance')
        src = Path(r['path'])
        if sha(src) != r['sha256'] or r['sha256'] in known:
            raise ValueError('Source identity mismatch or existing duplicate')
        known.add(r['sha256'])
        if r['id'] in names or not str(r['id']).isdigit():
            raise ValueError('Invalid or duplicate public ID')
        names.add(r['id'])
        with Image.open(src) as raw:
            if list(ImageOps.exif_transpose(raw).size) != r['display_size']:
                raise ValueError('Source orientation/size mismatch')
        if not r['boxes']:
            raise ValueError('Expected an explicitly reviewed subject')
        for box in r['boxes']:
            x1, y1, x2, y2 = box['xyxy']
            if box['bin'] not in range(4) or not (0 <= x1 < x2 <= 1 and 0 <= y1 < y2 <= 1):
                raise ValueError('Invalid box or public bucket')
        if any(x['group'] == r['group'] and x['split'] != 'train' for x in rows):
            raise ValueError('Public physical group crosses splits')
    a.out.mkdir(parents=True, exist_ok=False)
    data = a.out/'dataset'
    base_files = {}
    for r in rows:
        src = Path(r['prepared_image'])
        label = a.base_data/'labels'/r['split']/(src.stem+'.txt')
        if sha(src) != r['sha256']:
            raise ValueError('Base image changed')
        dst = data/'images'/r['split']/src.name
        link(src, dst)
        link(label, data/'labels'/r['split']/label.name)
        base_files[str(src)] = r['sha256']
        base_files[str(label)] = sha(label)
        r['prepared_image'] = str(dst.resolve())
    for r in review['images']:
        boxes = [[b['bin'], (b['xyxy'][0]+b['xyxy'][2])/2,
                  (b['xyxy'][1]+b['xyxy'][3])/2,
                  b['xyxy'][2]-b['xyxy'][0], b['xyxy'][3]-b['xyxy'][1]] for b in r['boxes']]
        for rep in range(a.train_repeat):
            dst = data/'images/train'/f"public_063_{r['id']}_{rep}.jpg"
            if dst.exists():
                raise ValueError('Destination collision')
            with Image.open(r['path']) as raw:
                im = ImageOps.exif_transpose(raw).convert('RGB')
                im.save(dst, quality=95)
            label = data/'labels/train'/(dst.stem+'.txt')
            label.write_text(''.join(str(b[0])+' '+' '.join(f'{v:.9f}' for v in b[1:])+'\n' for b in boxes), encoding='ascii')
            rows.append(dict(source='realwaste_reviewed_063', split='train', group=r['group'],
                primary_bin=boxes[0][0], boxes=boxes, prepared_image=str(dst.resolve()),
                sha256=sha(dst), original_sha256=r['sha256'], original_path=r['path'],
                source_url=r['source_url'], source_license=r['source_license'],
                repetition=rep, annotation_scope=r['annotation_scope']))
    for left, right in (('train', 'val'), ('train', 'test'), ('val', 'test')):
        for key in ('group', 'sha256', 'original_sha256'):
            if {r[key] for r in rows if r['split'] == left and key in r} & {r[key] for r in rows if r['split'] == right and key in r}:
                raise ValueError('Split leakage: '+key)
    if any(sha(Path(path)) != digest for path, digest in base_files.items()):
        raise ValueError('Base data changed')
    config['path'] = str(data.resolve()).replace('\\', '/')
    (data/'data.yaml').write_text(yaml.safe_dump(config), encoding='utf8')
    (data/'manifest.json').write_text(json.dumps(rows, indent=2), encoding='utf8')
    result = dict(status='PREPARED_NOT_TRAINED', counts=dict(Counter(r['split'] for r in rows)),
        added_unique=len(review['images']), train_repeat=a.train_repeat,
        base_manifest_sha256=sha(a.base_data/'manifest.json'), review_sha256=sha(a.annotations),
        script_sha256=sha(Path(__file__)), base_images_and_labels_unchanged=True,
        val_test_unchanged=True, split_group_sha_isolation=True,
        limitations=['Approximate duplicate screening cannot prove independent physical objects',
                     'Public isolated objects have different backgrounds from held objects'])
    (a.out/'preparation.json').write_text(json.dumps(result, indent=2), encoding='utf8')
    print(json.dumps(result), flush=True)


if __name__ == '__main__':
    main()
