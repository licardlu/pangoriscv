"""Create hand-only crops from an explicit visual-review allowlist.

No_gesture is a hand-pose label, not proof of an empty scene. Candidates with
cups or uncertain objects must be excluded before running this script. Only
the reviewed 1.5x largest-hand crop is used; no whole-photo empty labels.
"""
import argparse
from collections import Counter
import hashlib
import json
import math
import os
from pathlib import Path
import shutil

from PIL import Image
import yaml


def save(path, value):
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False), encoding='utf8')


def link(source, target):
    target.parent.mkdir(parents=True, exist_ok=True)
    try:
        os.link(source, target)
    except OSError:
        shutil.copy2(source, target)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--candidates', type=Path, required=True)
    p.add_argument('--review', type=Path, required=True)
    p.add_argument('--base-data', type=Path, required=True)
    p.add_argument('--out', type=Path, required=True)
    p.add_argument('--train-repeat', type=int, default=4)
    a = p.parse_args()
    if not 1 <= a.train_repeat <= 8:
        p.error('train-repeat must be 1..8')
    items = json.loads((a.candidates/'candidate_images.json').read_text())
    allow = json.loads(a.review.read_text())
    if len(set(allow)) != len(allow):
        raise ValueError('Duplicate review indices')
    a.out.mkdir(parents=True, exist_ok=False)
    negative = []
    subjects = {s: set() for s in ('train','val','test')}
    for index in allow:
        r = items[index]
        split = r['annotation_source'].split('/')[1]
        if split not in subjects:
            raise ValueError('Unexpected source split')
        subjects[split].add(r['annotation']['user_id'])
        source = a.candidates/'images'/r['file']
        if hashlib.sha256(source.read_bytes()).hexdigest() != r['sha256']:
            raise ValueError('Reviewed candidate changed')
        with Image.open(source) as raw:
            im = raw.convert('RGB')
            w,h = im.size
            x,y,bw,bh = max(r['annotation']['bboxes'], key=lambda b:b[2]*b[3])
            if not all(math.isfinite(v) for v in (x,y,bw,bh)) or min(bw,bh)<=0:
                raise ValueError('Invalid hand box')
            cx,cy = (x+bw/2)*w, (y+bh/2)*h
            half = max(bw*w,bh*h)*.75
            box = (max(0,int(cx-half)),max(0,int(cy-half)),
                   min(w,int(cx+half)),min(h,int(cy+half)))
            crop = im.crop(box)
            crop.thumbnail((640,640))
            target = a.out/'hand_images'/split/r['file']
            target.parent.mkdir(parents=True, exist_ok=True)
            crop.save(target, quality=95)
        negative.append(dict(review_index=index, split=split,
            user_id=r['annotation']['user_id'], original_sha256=r['sha256'],
            crop_xyxy=box, prepared_image=str(target.resolve()),
            sha256=hashlib.sha256(target.read_bytes()).hexdigest(),
            boxes=[], decision='visually reviewed hand crop; no target garbage'))
    for s,t in [('train','val'),('train','test'),('val','test')]:
        if subjects[s] & subjects[t]:
            raise ValueError('Subject leaks between hand splits')
    dataset = a.out/'dataset'
    base = json.loads((a.base_data/'manifest.json').read_text())
    for r in base:
        old = Path(r['prepared_image'])
        image = dataset/'images'/r['split']/old.name
        label = dataset/'labels'/r['split']/(old.stem+'.txt')
        link(old,image)
        link(a.base_data/'labels'/r['split']/(old.stem+'.txt'),label)
        r['prepared_image'] = str(image.resolve())
    for r in negative:
        if r['split'] != 'train':
            continue
        old = Path(r['prepared_image'])
        for repeat in range(a.train_repeat):
            name=f'hand_{old.stem}_{repeat}'
            image=dataset/'images/train'/(name+'.jpg')
            label=dataset/'labels/train'/(name+'.txt')
            link(old,image)
            label.parent.mkdir(parents=True,exist_ok=True)
            label.write_text('')
            base.append(dict(source='hagrid_hand_negative', split='train',
                group='hagrid_subject_'+r['user_id'], primary_bin=None,
                boxes=[], prepared_image=str(image.resolve()),
                repetition=repeat, sha256=r['sha256']))
    data=yaml.safe_load((a.base_data/'data.yaml').read_text())
    data['path']=str(dataset.resolve()).replace('\\','/')
    (dataset/'data.yaml').write_text(yaml.safe_dump(data),encoding='utf8')
    save(dataset/'manifest.json',base)
    save(a.out/'hand_manifest.json',negative)
    save(a.out/'preparation.json',dict(
        reviewed_crops=dict(Counter(r['split'] for r in negative)),
        train_repetitions=a.train_repeat, subjects_disjoint=True,
        public_validation_and_test_unchanged=True,
        selection='Public val fitness selects checkpoint; hand val diagnoses false positives; hand test held out',
        review_sha256=hashlib.sha256(a.review.read_bytes()).hexdigest(),
        attribution='HaGRIDv2: hukenovs/hagrid, https://github.com/hukenovs/hagrid',
        license='Custom Public License, based on BY-SA; not a Creative Commons license',
        license_url='https://github.com/hukenovs/hagrid/blob/master/license/en_us.pdf',
        changes='Largest-hand square crop 1.5x; resized max640; JPEG95; empty labels after visual review',
        limitations='Reviewed hand-crop subset, mostly face-covering poses; does not establish board-camera hand-held accuracy'))
    print((a.out/'preparation.json').read_text(), flush=True)


if __name__=='__main__':
    main()
