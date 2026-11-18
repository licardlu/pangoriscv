"""Freeze a small reviewed source-held development set, never training data."""
import argparse
from collections import Counter
import hashlib
import json
import os
from pathlib import Path

from audit_public_expansion import features


def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def read(path):return json.loads(Path(path).read_text(encoding='utf8'))
def save(path,v):Path(path).write_text(json.dumps(v,indent=2),encoding='utf8')


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--root',type=Path,required=True)
    a=p.parse_args();root=a.root.resolve();out=root/'dataset_001';out.mkdir(exist_ok=False)
    inventory=read(root/'inventory.json');ledger=read(root/'source_review_ledger.json')
    ledger['held_taco_0981'].update(status='EXCLUDED_AFTER_CROP_DETAIL_REVIEW',
        reason='Detail crop contains a long straight wooden object of uncertain waste semantics; defer complete-source judgement.')
    save(root/'source_review_ledger_final.json',ledger)
    crop_rejections={'held_taco_0981_empty_0':'Parent source deferred after detail review',
                     'held_taco_0981_empty_1':'Straight wooden object, uncertain natural stick/utensil',
                     'held_taco_0490_empty_0':'Dark strip near drain, uncertain waste/background',
                     'held_taco_1042_empty_1':'Small pale fragment in grass, uncertainty at available resolution'}
    image_dir=out/'images/val';label_dir=out/'labels/val'
    image_dir.mkdir(parents=True);label_dir.mkdir(parents=True)
    rows=[];crop_ledger={}
    def add(path,stem,width,height,boxes,source,parent):
        dest=image_dir/(stem+Path(path).suffix);os.link(path,dest)
        label=label_dir/(stem+'.txt')
        label.write_text(''.join(str(int(b[0]))+' '+' '.join('%.8f'%x for x in b[1:])+'\n' for b in boxes),encoding='ascii')
        rows.append(dict(split='val',stem=stem,source=source,prepared_image=str(dest),
            image_sha256=sha(dest),width=width,height=height,boxes=boxes,
            label=str(label),label_sha256=sha(label),group='taco_'+parent['source_file'].split('/')[0],
            source_file=parent['source_file'],source_image_id=parent['source_image_id'],
            source_url=parent['source_url'],parent_image_sha256=parent.get('parent_sha256',parent.get('image_sha256')),
            annotation_status='ASSISTANT_VISUALLY_REVIEWED_DEVELOPMENT_ONLY',**features(dest)))
    for r in inventory:
        review=ledger[r['id']]
        if review['status']!='VISUALLY_REVIEWED_ACCEPT':continue
        assert r['admission']=='REQUIRES_VISUAL_REVIEW' and sha(r['path'])==review['source_sha256']
        w,h=r['width'],r['height'];boxes=[]
        for c,x1,y1,x2,y2 in review['boxes_xyxy']:
            assert min(x1,y1)>=0 and x2<=w+.5 and y2<=h+.5
            x2,y2=min(x2,w),min(y2,h)
            boxes.append([c,(x1+x2)/2/w,(y1+y2)/2/h,(x2-x1)/w,(y2-y1)/h])
        add(r['path'],r['id'],w,h,boxes,'held_taco_reviewed_positive',r)
    for r in read(root/'background_proposals.json'):
        reason=crop_rejections.get(r['id'])
        accepted=reason is None
        crop_ledger[r['id']]=dict(status='VISUALLY_CONFIRMED_EMPTY' if accepted else 'EXCLUDED_AMBIGUOUS',
            reason=reason or 'Inspected crop: sand, pavement, planting or vegetation; no visible refuse or hand.',
            source_sha256=r['image_sha256'],reviewer='assistant_visual')
        if accepted:
            assert sha(r['path'])==r['image_sha256']
            add(r['path'],r['id'],r['width'],r['height'],[],'held_taco_reviewed_empty_crop',r)
    assert len(rows)==27 and sum(not r['boxes'] for r in rows)==10
    save(root/'background_review_ledger_final.json',crop_ledger)
    save(out/'manifest.json',rows)
    (out/'val.txt').write_text(''.join(r['prepared_image']+'\n' for r in rows),encoding='utf8')
    (out/'data.yaml').write_text('path: '+out.as_posix()+'\ntrain: val.txt\nval: val.txt\nnc: 5\nnames: [kitchen, recyclable, hazardous, other, hand]\n',encoding='utf8')
    save(out/'result.json',dict(status='FROZEN_DEVELOPMENT_ONLY_NEVER_TRAIN',positive_source_photos=17,
        derived_empty_views=10,source_batches=['batch_5','batch_13'],new_train_photos=0,
        manifest_sha256=sha(out/'manifest.json'),class_instances=dict(Counter(int(b[0]) for r in rows for b in r['boxes'])),
        limitations=['Only 27 development views; empty crops correlated within source photos.',
            'No hazardous/kitchen/hand GT; outdoor scenes do not validate the actual camera station.',
            'Existing identities and available stored pHash used for exclusion; no proof of global physical-object independence.'],
        final_test_files_read=False))
    print(read(out/'result.json'),flush=True)


if __name__=='__main__':main()
