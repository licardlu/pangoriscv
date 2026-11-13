"""Add reviewed hand + held-subject pairs to the existing five-internal-class data.

Only foreground held subjects are annotated in new photos. Visible background
garbage is not exhaustively annotated; this is recorded, not detection AP truth.
"""
import argparse
from collections import Counter
import hashlib
import io
import json
from pathlib import Path
from PIL import Image, ImageOps
import yaml
from prepare_hand_context import link
from reviewed_train_exclusions import load_exclusions, validate_exclusion


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--base-data', type=Path, required=True)
    p.add_argument('--annotations', type=Path, required=True)
    p.add_argument('--out', type=Path, required=True)
    p.add_argument('--train-repeat', type=int, default=4)
    p.add_argument('--audited-hand-scenes', type=Path,
                   help='Reviewed nc=1 dataset: add contextual hands; keep original waste labels on negatives')
    p.add_argument('--context-repeat', type=int, default=3)
    p.add_argument('--reviewed-public-hands', type=Path, action='append', default=[],
                   help='Manually reviewed missing hand boxes on original public train images; repeat for separate source audits')
    p.add_argument('--reviewed-train-exclusions', type=Path,
                   help='Explicit visual review of contradictory public train annotations; never changes val/test')
    a = p.parse_args()
    if not 1 <= a.train_repeat <= 4:
        raise ValueError('Repeat must be 1..4')
    if not 1 <= a.context_repeat <= 4:
        raise ValueError('Context repeat must be 1..4')
    annotations = json.loads(a.annotations.read_text(encoding='utf8'))
    if annotations['status'] != 'VISUALLY_REVIEWED_HAND_OBJECT_RELATIONS':
        raise ValueError('Explicit visual hand/subject review required')
    rows = json.loads((a.base_data/'manifest.json').read_text(encoding='utf8'))
    if any(r['source'] == 'personal_handheld' for r in rows):
        raise ValueError('Base already includes personal scenes; use the original hand/waste dataset')
    a.out.mkdir(parents=True, exist_ok=False)
    data = a.out/'dataset'
    public_labels, public_exclusions = {}, set()
    for review_path in a.reviewed_public_hands:
        public_review = json.loads(review_path.read_text(encoding='utf8'))
        if public_review['status'] != 'VISUALLY_REVIEWED_HAND_BOXES':
            raise ValueError('Explicit public hand-box review required')
        inventory_path = review_path.parent/'inventory.json'
        if sha(inventory_path) != public_review['inventory_sha256']:
            raise ValueError('Public review inventory changed')
        inventory = {r['review_id']: r for r in json.loads(inventory_path.read_text(encoding='utf8'))['images']}
        for r in public_review['labels']:
            if r['prepared_sha256'] in public_labels:
                raise ValueError('Duplicate public hand correction across source audits')
            public_labels[r['prepared_sha256']] = r
        for idx in public_review['excluded_ambiguous_train_ids']:
            public_exclusions.add(sha(Path(inventory[idx]['prepared_image'])))
    annotation_exclusions = load_exclusions(a.reviewed_train_exclusions) if a.reviewed_train_exclusions else {}
    if set(annotation_exclusions) & public_exclusions:
        raise ValueError('Image excluded by more than one review')
    public_exclusions.update(annotation_exclusions)
    if set(public_labels) & public_exclusions:
        raise ValueError('Public image both corrected and excluded')
    matched_public, excluded_public = set(), set()
    base_rows, rows = rows, []
    for r in base_rows:
        src = Path(r['prepared_image'])
        if 'sha256' in r:
            if sha(src) != r['sha256']:raise ValueError('Base source changed')
        else:
            # Historical identity describes the ORIGINAL pixels; the prepared
            # file was resized and re-encoded as JPEG95. Check both explicitly.
            with Image.open(r['image']) as raw:
                rgb=raw.convert('RGB')
                pixel_sha=hashlib.sha256(rgb.tobytes()+str(rgb.size).encode()).hexdigest()
                rgb.thumbnail((640,640));encoded=io.BytesIO();rgb.save(encoded,format='JPEG',quality=95)
            if pixel_sha != r['sha256_pixels']:raise ValueError('Base pixels changed')
            if hashlib.sha256(encoded.getvalue()).hexdigest()!=sha(src):
                raise ValueError('Historical prepared JPEG differs from its recorded conversion')
            r['sha256']=sha(src)
        if r['sha256'] in public_exclusions:
            if r['split'] != 'train':
                raise ValueError('Public exclusions must be train only')
            if r['sha256'] in annotation_exclusions:
                validate_exclusion(r, annotation_exclusions[r['sha256']])
            excluded_public.add(r['sha256'])
            continue
        dst = data/'images'/r['split']/src.name
        link(src, dst)
        label = data/'labels'/r['split']/(src.stem+'.txt')
        if r['sha256'] in public_labels:
            correction = public_labels[r['sha256']]
            if r['split'] != 'train' or correction['split'] != 'train' or correction['group'] != r['group']:
                raise ValueError('Public correction identity/split mismatch')
            with Image.open(src) as raw:
                if list(raw.size) != correction['image_size']:
                    raise ValueError('Public hand coordinates use wrong image dimensions')
            if any(int(b[0]) == 4 for b in r['boxes']):
                raise ValueError('Public image already has hand labels')
            for x1, y1, x2, y2 in correction['hand_xyxy']:
                if not (0 <= x1 < x2 <= 1 and 0 <= y1 < y2 <= 1):
                    raise ValueError('Invalid public hand annotation')
                r['boxes'].append([4, (x1+x2)/2, (y1+y2)/2, x2-x1, y2-y1])
            label.parent.mkdir(parents=True, exist_ok=True)
            # Write a new label; never modify the original hard-linked label.
            label.write_text(''.join(str(b[0])+' '+' '.join(f'{v:.9f}' for v in b[1:])+'\n'
                                     for b in r['boxes']), encoding='ascii')
            r['hand_annotation_status'] = 'visible hands manually boxed and reviewed'
            matched_public.add(r['sha256'])
        else:
            link(a.base_data/'labels'/r['split']/(src.stem+'.txt'), label)
        r['prepared_image'] = str(dst.resolve())
        rows.append(r)
    if matched_public != set(public_labels) or excluded_public != public_exclusions:
        raise ValueError('Public hand review does not exactly match this base dataset')
    added_contexts = Counter()
    retained_negative_waste_labels = Counter()
    if a.audited_hand_scenes:
        source_config = yaml.safe_load((a.audited_hand_scenes/'data.yaml').read_text(encoding='utf8'))
        if source_config['nc'] != 1 or source_config['names'] != ['hand']:
            raise ValueError('Expected reviewed hand-only source dataset')
        audited = json.loads((a.audited_hand_scenes/'manifest.json').read_text(encoding='utf8'))
        by_sha = {r['sha256']: r for r in rows}
        seen = set()
        for r in audited:
            if r['source'] not in ('reviewed_hand_context', 'reviewed_hand_negative'):
                continue
            src = Path(r['prepared_image'])
            if sha(src) != r['sha256']:
                raise ValueError('Audited hand scene changed')
            if r['sha256'] in seen:
                continue
            seen.add(r['sha256'])
            if r['source'] == 'reviewed_hand_negative':
                # These are garbage photos with reviewed hand absence. Empty
                # hand-only labels must never erase their actual waste labels.
                if r['sha256'] not in by_sha or by_sha[r['sha256']]['split'] != r['split']:
                    raise ValueError('Hand negative must match original waste image and split')
                by_sha[r['sha256']]['hand_annotation_status'] = 'visually reviewed absent'
                retained_negative_waste_labels[r['split']] += 1
                continue
            if r['sha256'] in by_sha:
                raise ValueError('Context already occurs in base dataset')
            boxes = [[4, *b[1:]] for b in r['boxes']]
            if not boxes or any(int(b[0]) != 0 for b in r['boxes']):
                raise ValueError('Context requires reviewed hand labels')
            for rep in range(a.context_repeat if r['split'] == 'train' else 1):
                dst = data/'images'/r['split']/f"context_{r['sha256'][:20]}_{rep}.jpg"
                link(src, dst)
                label = data/'labels'/r['split']/(dst.stem+'.txt')
                label.parent.mkdir(parents=True, exist_ok=True)
                label.write_text(''.join(str(b[0])+' '+' '.join(f'{v:.9f}' for v in b[1:])+'\n'
                                         for b in boxes), encoding='ascii')
                rows.append(dict(r, boxes=boxes, primary_bin=4, repetition=rep,
                                 prepared_image=str(dst.resolve()),
                                 annotation_scope='official reviewed hands; background waste not exhaustive'))
            added_contexts[r['split']] += 1
    for r in annotations['images']:
        if r['status'] == 'EXCLUDED':
            continue
        if r['status'] != 'VISUALLY_REVIEWED':
            raise ValueError('Unreviewed personal image')
        src = Path(r['path'])
        if sha(src) != r['sha256']:
            raise ValueError('Personal source changed')
        boxes = []
        for field, category in (('object_xyxy', r['bin']), ('hand_xyxy', 4)):
            x1, y1, x2, y2 = r[field]
            if not (0 <= x1 < x2 <= 1 and 0 <= y1 < y2 <= 1):
                raise ValueError('Invalid reviewed box')
            boxes.append([category, (x1+x2)/2, (y1+y2)/2, x2-x1, y2-y1])
        for rep in range(a.train_repeat if r['split'] == 'train' else 1):
            dst = data/'images'/r['split']/f"personal_H{r['id']:03d}_{rep}.jpg"
            dst.parent.mkdir(parents=True, exist_ok=True)
            with Image.open(src) as raw:
                im = ImageOps.exif_transpose(raw).convert('RGB')
                im.thumbnail((640, 640))
                im.save(dst, quality=95)
            label = data/'labels'/r['split']/(dst.stem+'.txt')
            label.parent.mkdir(parents=True, exist_ok=True)
            label.write_text(''.join(str(b[0])+' '+' '.join(f'{v:.9f}' for v in b[1:])+'\n' for b in boxes), encoding='ascii')
            rows.append(dict(source='personal_handheld', split=r['split'], group='personal_'+r['group'],
                             primary_bin=r['bin'], boxes=boxes, prepared_image=str(dst.resolve()),
                             sha256=sha(dst), original_sha256=r['sha256'], original_path=str(src),
                             personal_id=r['id'], repetition=rep,
                             held_object=dict(bin=r['bin'], xyxy=r['object_xyxy'], relation=r['relation']),
                             annotation_scope='visible hand and held subject only; background not exhaustive'))
    for left, right in (('train', 'val'), ('train', 'test'), ('val', 'test')):
        for key in ('group', 'sha256', 'original_sha256'):
            s = {r[key] for r in rows if r['split'] == left and key in r}
            t = {r[key] for r in rows if r['split'] == right and key in r}
            if s & t:
                raise ValueError('Split leakage '+key)
    config = dict(path=str(data.resolve()).replace('\\', '/'), train='images/train',
                  val='images/val', test='images/test', nc=5,
                  names=['kitchen', 'recyclable', 'hazardous', 'other', 'hand'])
    (data/'data.yaml').write_text(yaml.safe_dump(config), encoding='utf8')
    (data/'manifest.json').write_text(json.dumps(rows, indent=2), encoding='utf8')
    report = dict(status='PREPARED', base_manifest_sha256=sha(a.base_data/'manifest.json'),
                  annotations_sha256=sha(a.annotations), counts=dict(Counter(r['split'] for r in rows)),
                  personal_unique=dict(Counter(r['split'] for r in annotations['images'] if r['status'] != 'EXCLUDED')),
                  added_unique_contexts=dict(added_contexts), context_train_repeat=a.context_repeat,
                  retained_negative_waste_labels=dict(retained_negative_waste_labels),
                  audited_hand_manifest_sha256=sha(a.audited_hand_scenes/'manifest.json') if a.audited_hand_scenes else None,
                  public_hand_review_sha256=sha(a.reviewed_public_hands[0]) if len(a.reviewed_public_hands) == 1 else None,
                  public_hand_reviews=[dict(path=str(r.resolve()), sha256=sha(r)) for r in a.reviewed_public_hands],
                  public_train_images_hand_corrected=len(matched_public),
                  public_train_images_excluded_ambiguous=len(excluded_public),
                  contradictory_annotation_exclusions=len(annotation_exclusions),
                  train_exclusion_review_sha256=sha(a.reviewed_train_exclusions) if a.reviewed_train_exclusions else None,
                  preparation_script_sha256=sha(Path(__file__)),
                  hand_class=4, bins=4, battery_personal_test_used=False, old80_training_images=0,
                  limitations=['Old80 physical items partly overlap new personal training images',
                               'Same person and rooms across personal splits',
                               'Original public garbage photos have not been fully audited for hands',
                               'Personal background garbage not exhaustively annotated',
                               'New held images have no kitchen samples; preserve public four-bin replay'])
    (a.out/'preparation.json').write_text(json.dumps(report, indent=2), encoding='utf8')
    print(json.dumps(report), flush=True)


if __name__ == '__main__':
    main()
