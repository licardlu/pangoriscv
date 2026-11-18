"""Freeze the explicitly reviewed battery subset, preserving source and identity evidence."""
from collections import Counter
import argparse
import hashlib
import json
import os
from pathlib import Path
import numpy as np
from PIL import Image
from audit_public_expansion import features


def read(path): return json.loads(Path(path).read_text(encoding='utf8'))
def sha(path): return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def save(path,value): Path(path).write_text(json.dumps(value,indent=2)+'\n',encoding='utf8')


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--reviewed',default='annotations_003')
    p.add_argument('--out',default='frozen_additions_001')
    a=p.parse_args();root=Path('build/new_battery_extensions_review_20261118_001').resolve()
    reviewed=root/a.reviewed;out=root/a.out;assert not out.exists()
    paths=['build/joint_glass_hand_food_20261118_001/experiment_001/unique_train.json',
        'build/mostafa_waste_review_20261118_001/frozen_balanced_003/manifest.json',
        'build/public_20k_20261117_001/public_dev_001/manifest.json',
        'build/overnight_20261116/dataset_stage4/manifest.json',
        'build/held_background_dev_20261118_001/inventory.json',
        'build/public_expansion_20261117_001/dedup_inventory.json',
        'build/public_targeted_20261118_001/identity_audit.json']
    cache='build/public_20k_20261117_001/historical_feature_cache.json'
    known=[r for path in paths for r in read(path)]+list(read(cache).values())
    oldsha={r.get('image_sha256',r.get('sha256')) for r in known};oldsha.update(r.get('original_sha256') for r in known)
    oldpix={r['sha256_pixels'] for r in known if r.get('sha256_pixels')}
    ph=np.asarray(sorted({int(r['phash']) for r in known if 'phash' in r}),dtype=np.uint64)
    lut=np.asarray([bin(i).count('1') for i in range(256)],dtype=np.uint8)
    rows=read(reviewed/'inventory.json');ledger=read(reviewed/'ledger.json');admitted=[]
    for r in rows:
        key=r['id'];entry=ledger[key]
        assert r['admission']=='PENDING_COMPLETE_BATTERY_HAND_BOX_REVIEW' and r['source_split']=='upstream_train_only'
        assert r['image_sha256']==entry['source_sha256']==sha(r['path'])
        assert r['original_sha256']==sha(r['original_path']) and sha(entry['source_sheet'])==entry['source_sheet_sha256']
        with Image.open(r['path']) as im:assert im.size==(r['width'],r['height']) and im.getexif().get(274,1) in [0,1]
        assert all(r[k]==v for k,v in features(r['path']).items())
        distance=int(lut[(ph^np.uint64(r['phash'])).view(np.uint8).reshape(-1,8)].sum(1).min())
        assert r['image_sha256'] not in oldsha and r['original_sha256'] not in oldsha and r['sha256_pixels'] not in oldpix and distance>6,key
        assert not any(x['sha256_pixels']==r['sha256_pixels'] or bin(x['phash']^r['phash']).count('1')<=6 for x in admitted)
        for c,cx,cy,w,h in r['boxes']:
            assert c in [2,4] and w>0 and h>0 and np.isfinite([cx,cy,w,h]).all()
            assert -1e-9<=cx-w/2<cx+w/2<=1+1e-9 and -1e-9<=cy-h/2<cy+h/2<=1+1e-9
        ledger[key]=dict(entry,status='SOURCE_AND_FINAL_OVERLAY_VISUALLY_REVIEWED',boxes=r['boxes'],
            visible_hand=any(int(b[0])==4 for b in r['boxes']),nearest_recorded_historical_phash=distance)
        admitted.append(r)
    images=out/'images/train';labels=out/'labels/train';images.mkdir(parents=True);labels.mkdir(parents=True)
    additions=[]
    for r in admitted:
        image=images/(r['id']+Path(r['path']).suffix);os.link(r['path'],image)
        label=labels/(image.stem+'.txt');label.write_text(''.join(str(int(b[0]))+' '+' '.join('%.8f'%v for v in b[1:])+'\n' for b in r['boxes']),encoding='ascii')
        assert np.allclose([[float(v) for v in line.split()] for line in label.read_text().splitlines()],r['boxes'],rtol=0,atol=1e-7)
        additions.append(dict(source='apadoss_reviewed_battery',origin='battery_extensions_complete_boxes_20261118',split='train',
            stem=image.stem,prepared_image=str(image),image_sha256=sha(image),original_path=r['original_path'],original_sha256=r['original_sha256'],
            source_file=r['source_file'],source_split=r['source_split'],source_url='https://www.kaggle.com/datasets/apadoss/recycle-waste',
            width=r['width'],height=r['height'],boxes=r['boxes'],primary_bin=2,label=str(label),label_sha256=sha(label),
            group='apadoss_upstream_train_only',capture_group='apadoss_upstream_train_only',license=r['license'],
            phash=r['phash'],sha256_pixels=r['sha256_pixels'],historical_nearest_phash=ledger[r['id']]['nearest_recorded_historical_phash'],
            annotation_status=ledger[r['id']]['status'],new_source_image=True,independent_camera_capture=False,physical_object_identity_unknown=True))
    save(out/'manifest.json',additions);save(out/'review_ledger.json',ledger)
    save(out/'result.json',dict(status='FROZEN_REVIEWED_SOURCE_ADDITIONS_NOT_YET_TRAINED',source_files=len(admitted),
        box_instances=dict(Counter(int(b[0]) for r in admitted for b in r['boxes'])),
        hand_images=sum(any(int(b[0])==4 for b in r['boxes']) for r in admitted),
        manifest_sha256=sha(out/'manifest.json'),review_inventory_sha256=sha(reviewed/'inventory.json'),
        final_overlay_sha256={p.name:sha(p) for p in reviewed.glob('overlay_*.jpg')},
        focus_sha256=sha(root/'focus_001.jpg'),identity_metadata_sha256={p:sha(p) for p in paths+[cache]},
        acquisition_sha256=sha('build/joint_battery_resume_20261118_001/research/real_battery_scenes_002/apadoss/acquisition.json'),
        derived_images_added=0,new_camera_station_captures=0,final_test_files_read=False,
        exclusions='Unselected dense piles, chargers, decorative graphics, and ambiguous battery pack in sheet7cell4 are not GT and not empty negatives.',
        limitations=['Public web/product images; unknown capture/object identity.',
            'No new independent evaluation data; actual station handheld generalization remains to be measured.']))
    print(read(out/'result.json'),flush=True)


if __name__=='__main__': main()
