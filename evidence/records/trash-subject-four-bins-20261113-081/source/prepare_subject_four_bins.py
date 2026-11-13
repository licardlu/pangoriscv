"""Four-class development candidate: real hand negatives plus train-only ROI variants."""
import argparse
from collections import Counter
import hashlib
import json
import os
from pathlib import Path
import shutil

import numpy as np
from PIL import Image, ImageOps
import yaml

from evaluate_crop_diagnostic import ROOT, expanded, pixel_roi, sha, save


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--out',type=Path,required=True)
    a=p.parse_args();a.out=a.out.resolve();a.out.mkdir(parents=True,exist_ok=False)
    base_path=ROOT/'build/trash_retrain_research_20261111_001/four_bins_001/manifest.json'
    hand_path=ROOT/'build/trash_additional_hands_20261113_052/prepared/dataset/manifest.json'
    base=json.loads(base_path.read_text(encoding='utf8'));hands=json.loads(hand_path.read_text(encoding='utf8'))
    rows=[]
    for r in base:
        if r['split'] in ('train','val'):
            rows.append(dict(r,key=Path(r['prepared_image']).stem,sha256=sha(r['prepared_image'])))
    seen=set()
    for r in hands:
        if r['source'] not in ('personal_handheld','hagrid_hand_localisation') or r['split'] not in ('train','val'):
            continue
        if r.get('repetition',0)!=0:
            continue
        identity=(r['split'],r.get('original_sha256',r['sha256']))
        if identity in seen:
            continue
        seen.add(identity)
        if r['source']=='personal_handheld' and r['split']=='val' and not r.get('held_object'):
            continue
        assert 'battery' not in str(r.get('group','')).lower()
        boxes=[b for b in r['boxes'] if int(b[0])<4]
        assert len(boxes)<=1
        rows.append(dict(r,key=Path(r['prepared_image']).stem,boxes=boxes))
    train=[r for r in rows if r['split']=='train'];val=[r for r in rows if r['split']=='val']
    train_groups={str(r['group']) for r in train};val_groups={str(r['group']) for r in val}
    assert not train_groups.intersection(val_groups), 'Physical-group split leak'
    def identities(rs):
        return {r.get('original_sha256',r.get('sha256_pixels',r['sha256'])) for r in rs}
    assert not identities(train).intersection(identities(val)), 'Original-source split leak'
    assert not {r['sha256'] for r in train}.intersection(r['sha256'] for r in val), 'Prepared-byte split leak'
    data=a.out/'dataset'
    for split in ('train','val'):
        (data/'images'/split).mkdir(parents=True)
        (data/'labels'/split).mkdir(parents=True)
    manifest=[]
    def put(row,path,boxes,mode):
        key=row['key']+'_'+mode;split=row['split']
        target=data/'images'/split/(key+path.suffix.lower())
        if target.exists():raise ValueError('Duplicate key '+key)
        try:os.link(path,target)
        except OSError:shutil.copyfile(path,target)
        label=data/'labels'/split/(key+'.txt')
        label.write_text(''.join(' '.join(format(float(v),'.10g') for v in b)+'\n' for b in boxes),encoding='utf8')
        manifest.append(dict(key=key,split=split,group=row['group'],source=row['source'],variant=mode,
                             prepared_image=str(target),sha256=sha(target),boxes=boxes,
                             original_path=row['prepared_image'],original_sha256=row.get('original_sha256',row.get('sha256_pixels',row['sha256']))))
    variants=a.out/'variants';variants.mkdir()
    for row in rows:
        path=Path(row['prepared_image'])
        assert sha(path)==row['sha256']
        boxes=row['boxes']
        put(row,path,boxes,'original')
        if row['split']!='train' or len(boxes)!=1 or not (int(boxes[0][0])==2 or row['source']=='personal_handheld'):
            continue
        with Image.open(path) as im:image=ImageOps.exif_transpose(im).convert('RGB')
        w,h=image.size;c,cx,cy,bw,bh=boxes[0]
        subject=[(cx-bw/2)*w,(cy-bh/2)*h,(cx+bw/2)*w,(cy+bh/2)*h]
        roi=pixel_roi(expanded(subject,1.5),w,h);x1,y1,x2,y2=roi
        assert x1<=subject[0]+1e-5 and y1<=subject[1]+1e-5 and x2>=subject[2]-1e-5 and y2>=subject[3]-1e-5
        cropped=image.crop(roi);crop_path=variants/(row['key']+'_crop.png');cropped.save(crop_path)
        translated=[[int(c),((subject[0]+subject[2])/2-x1)/(x2-x1),((subject[1]+subject[3])/2-y1)/(y2-y1),
                     (subject[2]-subject[0])/(x2-x1),(subject[3]-subject[1])/(y2-y1)]]
        assert all(0<=v<=1.00001 for v in translated[0][1:])
        put(row,crop_path,translated,'crop_1p5')
        mask=Image.new('RGB',image.size,(114,114,114));mask.paste(cropped,(x1,y1))
        assert np.array_equal(np.asarray(mask)[y1:y2,x1:x2],np.asarray(image)[y1:y2,x1:x2])
        mask_path=variants/(row['key']+'_mask.png');mask.save(mask_path)
        put(row,mask_path,boxes,'context_gray')
    save(data/'manifest.json',manifest)
    config=dict(path=str(data),train='images/train',val='images/val',nc=4,
                names={0:'kitchen',1:'recyclable',2:'hazardous',3:'other'})
    (data/'data.yaml').write_text(yaml.safe_dump(config,sort_keys=False),encoding='utf8')
    report=dict(status='PASS_TRAIN_ONLY_FOUR_CLASS_PREPARATION',base_manifest_sha256=sha(base_path),
                hand_manifest_sha256=sha(hand_path),manifest_sha256=sha(data/'manifest.json'),
                script_sha256=sha(__file__),original_counts=dict(Counter(r['split']+'/'+r['source'] for r in rows)),
                prepared_counts=dict(Counter(r['split']+'/'+r['variant'] for r in manifest)),
                train_val_physical_groups_disjoint=True,train_val_source_sha_disjoint=True,
                train_val_prepared_sha_disjoint=True,hand_class_removed=True,context_without_exhaustive_labels_excluded=True,
                held_out_test_used=False,battery_personal_excluded=True)
    save(a.out/'preparation.json',report);print(json.dumps(report),flush=True)


if __name__=='__main__':main()
