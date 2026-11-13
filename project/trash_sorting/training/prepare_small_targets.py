"""Add train-only scale/pad variants while retaining every original annotation.

These synthetic scale variants are not new independent pictures. Personal
photos and validation/test images are never sources. No object crop is pasted:
the complete labelled source photograph is resized onto a neutral canvas.
"""
import argparse
from collections import Counter
import hashlib
import json
import math
import os
from pathlib import Path
import random
import shutil

from PIL import Image, ImageDraw
import yaml


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def link(source, destination):
    destination.parent.mkdir(parents=True, exist_ok=True)
    try:
        os.link(source, destination)
    except OSError:
        shutil.copy2(source, destination)


def transform(boxes, source_size, resized_size, offset, canvas=320):
    sw, sh = source_size
    rw, rh = resized_size
    ox, oy = offset
    result = []
    for cls, cx, cy, w, h in boxes:
        if not all(math.isfinite(v) for v in (cx, cy, w, h)) or min(w, h) <= 0:
            raise ValueError('Invalid source box')
        if min(cx-w/2, cy-h/2) < -1e-6 or max(cx+w/2, cy+h/2) > 1+1e-6:
            raise ValueError('Source box out of bounds')
        result.append([int(cls), (cx*rw+ox)/canvas, (cy*rh+oy)/canvas,
                       w*rw/canvas, h*rh/canvas])
    return result


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--base-data', type=Path, required=True)
    p.add_argument('--out', type=Path, required=True)
    p.add_argument('--sizes', type=int, nargs='+', default=[12, 24])
    p.add_argument('--seed', type=int, default=20261112)
    a = p.parse_args()
    if not all(8 <= s <= 48 for s in a.sizes):
        p.error('Target short sides must be 8..48 pixels at 320 input')
    a.out.mkdir(parents=True, exist_ok=False)
    dataset = a.out/'dataset'
    rows = json.loads((a.base_data/'manifest.json').read_text(encoding='utf8'))
    rng = random.Random(a.seed)
    train_groups = {r['group'] for r in rows if r['split']=='train'}
    heldout_groups = {r['group'] for r in rows if r['split']!='train'}
    if train_groups & heldout_groups:
        raise ValueError('Source group leakage')
    variants, seen, thumbnails = [], set(), []
    for row in rows:
        old = Path(row['prepared_image'])
        target = dataset/'images'/row['split']/old.name
        label = a.base_data/'labels'/row['split']/(old.stem+'.txt')
        link(old, target)
        link(label, dataset/'labels'/row['split']/label.name)
        if (row['split']!='train' or row['source']=='hagrid_hand_negative'
                or row.get('repetition') is not None):
            continue
        red = [b for b in row['boxes'] if int(b[0])==2]
        if not red:
            continue
        source_sha=digest(old)
        if source_sha in seen:
            continue
        seen.add(source_sha)
        label_boxes=[[float(v) for v in line.split()] for line in label.read_text().splitlines() if line.strip()]
        if len(label_boxes)!=len(row['boxes']) or any(
                abs(x-y)>2e-6 for left,right in zip(label_boxes,row['boxes']) for x,y in zip(left,right)):
            raise ValueError('Label and source manifest disagree: '+str(old))
        with Image.open(old) as raw:
            source = raw.convert('RGB')
        sw, sh = source.size
        largest = max(red, key=lambda b:b[3]*b[4])
        short = min(largest[3]*sw, largest[4]*sh)
        for size in a.sizes:
            scale = min(size/short, 320/sw, 320/sh)
            rw, rh = max(1,round(sw*scale)), max(1,round(sh*scale))
            ox, oy = rng.randrange(321-rw), rng.randrange(321-rh)
            level = rng.randrange(75,221)
            background = tuple(max(0,min(255,level+rng.randrange(-12,13))) for _ in range(3))
            canvas = Image.new('RGB',(320,320), background)
            canvas.paste(source.resize((rw,rh),Image.Resampling.LANCZOS),(ox,oy))
            boxes = transform(row['boxes'],(sw,sh),(rw,rh),(ox,oy))
            name = f'small_{old.stem}_{size}'
            im_path = dataset/'images/train'/(name+'.jpg')
            label_path = dataset/'labels/train'/(name+'.txt')
            canvas.save(im_path, quality=95)
            label_path.write_text(''.join(str(b[0])+' '+' '.join(f'{v:.9f}' for v in b[1:])+'\n' for b in boxes))
            variants.append(dict(source='synthetic_scale_pad', split='train',
                group=row['group'], primary_bin=row['primary_bin'], boxes=boxes,
                prepared_image=str(im_path.resolve()), original_image=str(old.resolve()),
                original_sha256=source_sha, sha256=digest(im_path),
                original_size=[sw,sh], resized_size=[rw,rh], offset=[ox,oy],
                requested_short_side_320=size, background=background,
                limitation='Full source photo scaled onto neutral canvas; not a new real scene'))
            if len(thumbnails)<36:
                draw=ImageDraw.Draw(canvas)
                for cls,cx,cy,w,h in boxes:
                    draw.rectangle([(cx-w/2)*320,(cy-h/2)*320,(cx+w/2)*320,(cy+h/2)*320],outline='red' if cls==2 else 'blue',width=2)
                draw.text((4,4),f'{len(variants)-1} / {size}px',fill='white',stroke_width=1,stroke_fill='black')
                thumbnails.append(canvas.resize((240,240)))
    result=[]
    for row in rows:
        old=Path(row['prepared_image'])
        result.append(dict(row,prepared_image=str((dataset/'images'/row['split']/old.name).resolve())))
    result.extend(variants)
    (dataset/'manifest.json').write_text(json.dumps(result,indent=2),encoding='utf8')
    data=yaml.safe_load((a.base_data/'data.yaml').read_text())
    data['path']=str(dataset.resolve()).replace('\\','/')
    (dataset/'data.yaml').write_text(yaml.safe_dump(data),encoding='utf8')
    summary=dict(seed=a.seed, train_source_images=len(seen), synthetic_variants=len(variants),
        requested_short_sides_320=a.sizes, split_counts=dict(Counter(r['split'] for r in result)),
        train_heldout_groups_disjoint=True, all_source_annotations_retained=True,
        personal_photos_used=False, base_manifest_sha256=digest(a.base_data/'manifest.json'),
        note='Synthetic scale variants are correlated training augmentation, not an accuracy test')
    (a.out/'preparation.json').write_text(json.dumps(summary,indent=2),encoding='utf8')
    if thumbnails:
        sheet=Image.new('RGB',(6*240,math.ceil(len(thumbnails)/6)*240),'white')
        for i,thumb in enumerate(thumbnails):
            sheet.paste(thumb,((i%6)*240,(i//6)*240))
        sheet.save(a.out/'review.jpg',quality=95)
    print(json.dumps(summary),flush=True)


if __name__=='__main__':
    main()
