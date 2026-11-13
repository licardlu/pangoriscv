"""Make a five-internal-class prototype from reviewed hand crops and four bins.

Hand is localisation metadata, not a fifth bin. Existing public garbage images
have no hand annotations: this is recorded as a dataset limitation, not treated
as evidence of hand absence. No personal photo or synthetic held-item label.
"""
import argparse
from collections import Counter
import hashlib
import json
import math
import os
from pathlib import Path
import shutil
from PIL import Image, ImageDraw
import yaml


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def link(src,dst):
    dst.parent.mkdir(parents=True,exist_ok=True)
    try:
        os.link(src,dst)
    except OSError:
        shutil.copy2(src,dst)


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--base-data',type=Path,required=True)
    p.add_argument('--reviewed-hands',type=Path,required=True)
    p.add_argument('--candidates',type=Path,required=True)
    p.add_argument('--out',type=Path,required=True)
    p.add_argument('--hand-repeat',type=int,default=4)
    a=p.parse_args()
    if not 1<=a.hand_repeat<=8:
        p.error('hand-repeat must be 1..8')
    a.out.mkdir(parents=True,exist_ok=False)
    dataset=a.out/'dataset'
    base=json.loads((a.base_data/'manifest.json').read_text(encoding='utf8'))
    hand=json.loads((a.reviewed_hands/'hand_manifest.json').read_text(encoding='utf8'))
    candidates=json.loads((a.candidates/'candidate_images.json').read_text(encoding='utf8'))
    bysha={r['sha256']:r for r in candidates}
    rows=[];subjects={s:set() for s in ('train','val','test')};previews=[]
    for row in base:
        if row['source']=='hagrid_hand_negative':
            raise ValueError('Use original four-bin data, not empty-label hand augmentation')
        old=Path(row['prepared_image']);split=row['split']
        new=dataset/'images'/split/old.name
        link(old,new)
        link(a.base_data/'labels'/split/(old.stem+'.txt'),dataset/'labels'/split/(old.stem+'.txt'))
        rows.append(dict(row,prepared_image=str(new.resolve()),hand_annotation_status='not audited'))
    for r in hand:
        image=Path(r['prepared_image'])
        if sha(image)!=r['sha256']:
            raise ValueError('Reviewed crop changed')
        original=bysha[r['original_sha256']]
        original_path=a.candidates/'images'/original['file']
        if sha(original_path)!=r['original_sha256']:
            raise ValueError('Original image changed')
        with Image.open(original_path) as im:
            sw,sh=im.size
        with Image.open(image) as im:
            crop=im.convert('RGB')
        x1,y1,x2,y2=r['crop_xyxy'];cw,ch=x2-x1,y2-y1
        boxes=[]
        for x,y,w,h in original['annotation']['bboxes']:
            left=max(x1,x*sw);top=max(y1,y*sh)
            right=min(x2,(x+w)*sw);bottom=min(y2,(y+h)*sh)
            if right<=left or bottom<=top:
                continue
            boxes.append([4,((left+right)/2-x1)/cw,((top+bottom)/2-y1)/ch,
                          (right-left)/cw,(bottom-top)/ch])
        if not boxes:
            raise ValueError('Reviewed crop has no annotated hand')
        subjects[r['split']].add(r['user_id'])
        repeats=a.hand_repeat if r['split']=='train' else 1
        for rep in range(repeats):
            stem=f'hand_{image.stem}_{rep}'
            target=dataset/'images'/r['split']/(stem+'.jpg')
            label=dataset/'labels'/r['split']/(stem+'.txt')
            link(image,target);label.parent.mkdir(parents=True,exist_ok=True)
            label.write_text(''.join(str(b[0])+' '+' '.join(f'{v:.9f}' for v in b[1:])+'\n' for b in boxes))
            rows.append(dict(source='hagrid_hand_localisation',split=r['split'],
                group='hagrid_subject_'+r['user_id'],primary_bin=4,boxes=boxes,
                prepared_image=str(target.resolve()),sha256=r['sha256'],repetition=rep,
                original_sha256=r['original_sha256'],crop_xyxy=r['crop_xyxy']))
        if len(previews)<24:
            d=ImageDraw.Draw(crop);w,h=crop.size
            for _,x,y,bw,bh in boxes:
                d.rectangle([(x-bw/2)*w,(y-bh/2)*h,(x+bw/2)*w,(y+bh/2)*h],outline='cyan',width=3)
            crop.thumbnail((240,240));previews.append(crop)
    for s,t in (('train','val'),('train','test'),('val','test')):
        if subjects[s]&subjects[t]:
            raise ValueError('Hand subject split leakage')
        if {r['group'] for r in rows if r['split']==s}&{r['group'] for r in rows if r['split']==t}:
            raise ValueError('Source group leakage')
    config=dict(path=str(dataset.resolve()).replace('\\','/'),train='images/train',
        val='images/val',test='images/test',nc=5,
        names=['kitchen','recyclable','hazardous','other','hand'])
    (dataset/'data.yaml').write_text(yaml.safe_dump(config),encoding='utf8')
    (dataset/'manifest.json').write_text(json.dumps(rows,indent=2),encoding='utf8')
    summary=dict(internal_classes=config['names'],bins=4,hand_class=4,
        split_images=dict(Counter(r['split'] for r in rows)),
        hand_unique_images=dict(Counter(r['split'] for r in hand)),train_hand_repeat=a.hand_repeat,
        hand_subject_splits_disjoint=True,personal_photos_used=False,
        limitations=['Reviewed hand crops mostly cover faces/natural gestures, not held batteries',
                    'Public garbage images have not been relabelled for hands',
                    'No held-item association ground truth; geometry needs new scene validation'],
        base_manifest_sha256=sha(a.base_data/'manifest.json'),hand_manifest_sha256=sha(a.reviewed_hands/'hand_manifest.json'))
    (a.out/'preparation.json').write_text(json.dumps(summary,indent=2),encoding='utf8')
    sheet=Image.new('RGB',(1440,math.ceil(len(previews)/6)*240),'#ddddee')
    for i,im in enumerate(previews):
        sheet.paste(im,((i%6)*240,(i//6)*240))
    sheet.save(a.out/'hand_labels_review.jpg',quality=95)
    print(json.dumps(summary),flush=True)


if __name__=='__main__':
    main()
