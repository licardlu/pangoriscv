"""Freeze only explicitly inspected full-instance scene annotations for train."""
from collections import Counter
import argparse
import hashlib
import json
import os
from pathlib import Path
import numpy as np
from PIL import Image
from audit_public_expansion import features


def read(path):return json.loads(Path(path).read_text(encoding='utf8'))
def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def save(path,data):Path(path).write_text(json.dumps(data,indent=2)+'\n',encoding='utf8')


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root',type=Path,default=Path('build/datacluster_review_20261118_002'))
    parser.add_argument('--reviewed',default='annotations_001')
    parser.add_argument('--out',default='frozen_additions_001')
    parser.add_argument('--exclusion-json',type=Path)
    parser.add_argument('--additional-identity-inventory',type=Path,action='append',default=[])
    parser.add_argument('--acquisition-root',type=Path,default=Path('build/joint_battery_resume_20261118_001/research/new_detection_indexes_002'))
    parser.add_argument('--source',action='append')
    args=parser.parse_args()
    root=args.root.resolve()
    reviewed=root/args.reviewed;out=root/args.out;assert not out.exists()
    exclusions=[
        ('plastic',3,6,'Shop background contains many unlabelled product instances.'),
        ('cardboard',1,1,'Source box misses raised top flaps.'),
        ('cardboard',1,17,'Additional packaging at image edge is unlabelled.'),
        ('cardboard',2,10,'Multiple separate boxes grouped into one source instance.'),
        ('cardboard',3,7,'Stacked separate cartons grouped into one source instance.'),
        ('household_clutter',3,3,'Circular underside material/instance is uncertain.'),
        ('household_clutter',4,18,'Opaque handled mug may be ceramic; material uncertain.'),
        ('household_clutter',5,8,'Torn paper food wrapper cleanliness/policy uncertain.'),
        ('household_clutter',5,12,'Large neighbouring paper package is unlabelled.'),
        ('household_clutter',5,24,'Source stemmed-glass box misses lower foot.'),
        ('household_clutter',6,15,'Opaque flower vessel material uncertain.'),
        ('household_clutter',6,16,'Full-resolution inspection establishes decorative vase, not food; material uncertain.'),
        ('household_clutter',6,23,'Small opaque cup material uncertain.'),
        ('household_clutter',6,24,'Opaque patterned vessel may be ceramic.'),
        ('household_clutter',7,23,'Dark patterned vase material uncertain; newspaper below also unlabelled.'),
    ]
    excluded={}
    if args.exclusion_json:exclusions=read(args.exclusion_json)
    for source,sheet,cell,reason in exclusions:
        r=read(root/source/'inventory.json')[(sheet-1)*24+cell-1]
        excluded[r['id']]=reason
    paths=['build/joint_balanced_sources_20261118_001/experiment_001/unique_train.json',
        'build/public_20k_20261117_001/public_dev_001/manifest.json',
        'build/overnight_20261116/dataset_stage4/manifest.json',
        'build/held_background_dev_20261118_001/inventory.json',
        'build/public_expansion_20261117_001/dedup_inventory.json',
        'build/public_targeted_20261118_001/identity_audit.json']+list(map(str,args.additional_identity_inventory))
    cache='build/public_20k_20261117_001/historical_feature_cache.json'
    known=[r for p in paths for r in read(p)]+list(read(cache).values())
    oldsha={r.get('image_sha256',r.get('sha256')) for r in known}
    oldsha.update(r.get('original_sha256') for r in known)
    oldpix={r['sha256_pixels'] for r in known if r.get('sha256_pixels')}
    ph=np.asarray(sorted({int(r['phash']) for r in known if 'phash' in r}),dtype=np.uint64)
    lut=np.asarray([bin(i).count('1') for i in range(256)],dtype=np.uint8)
    source_ledger=read(reviewed/'ledger.json');rows=[];ledger={}
    assert set(excluded).issubset({r['id'] for r in read(reviewed/'inventory.json')})
    for r in read(reviewed/'inventory.json'):
        key=r['id']
        if key in excluded:
            ledger[key]=dict(status='EXCLUDED_AFTER_FINAL_OVERLAY_OR_FOCUS_REVIEW',reason=excluded[key]);continue
        entry=source_ledger[key]
        assert r['source_split']=='unsplit_train_only' and r['admission'].startswith('PENDING_')
        assert entry['normalized_source_sha256']==r['image_sha256']==sha(r['path'])
        assert sha(r['label'])==r['source_label_sha256']
        assert sha(entry['source_sheet'])==entry['source_sheet_sha256']
        if r.get('original_path'):assert sha(r['original_path'])==r['original_sha256']
        with Image.open(r['path']) as im:assert im.size==(r['width'],r['height']) and im.getexif().get(274,1)==1
        f=features(r['path']);assert all(r[k]==v for k,v in f.items())
        distance=int(lut[(ph^np.uint64(r['phash'])).view(np.uint8).reshape(-1,8)].sum(1).min())
        assert r['image_sha256'] not in oldsha and r.get('original_sha256',r['image_sha256']) not in oldsha
        assert r['sha256_pixels'] not in oldpix and distance>6
        assert not any(x['sha256_pixels']==r['sha256_pixels'] or bin(x['phash']^r['phash']).count('1')<=6 for x in rows)
        for c,cx,cy,w,h in r['boxes']:
            assert c in range(5) and w>0 and h>0 and np.isfinite([cx,cy,w,h]).all()
            assert -1e-9<=cx-w/2<cx+w/2<=1+1e-9 and -1e-9<=cy-h/2<cy+h/2<=1+1e-9
        assert entry['visible_hand']==any(int(b[0])==4 for b in r['boxes'])
        ledger[key]=dict(entry,status='SOURCE_AND_FINAL_OVERLAY_VISUALLY_REVIEWED',
            boxes=r['boxes'],nearest_recorded_historical_phash=distance)
        rows.append(r)
    images=out/'images/train';labels=out/'labels/train';images.mkdir(parents=True);labels.mkdir(parents=True)
    additions=[]
    for r in rows:
        image=images/(r['id']+Path(r['path']).suffix);os.link(r['path'],image)
        label=labels/(image.stem+'.txt')
        label.write_text(''.join(str(int(b[0]))+' '+' '.join('%.8f'%v for v in b[1:])+'\n' for b in r['boxes']),encoding='ascii')
        assert np.allclose([[float(v) for v in line.split()] for line in label.read_text().splitlines()],r['boxes'],rtol=0,atol=1e-7)
        additions.append(dict(source='datacluster_reviewed_'+r['source'],origin='datacluster_real_scene_complete_boxes_20261118',
            split='train',stem=image.stem,prepared_image=str(image),image_sha256=sha(image),
            original_path=r.get('original_path',r['path']),original_sha256=r.get('original_sha256',r['image_sha256']),
            source_file=r['source_file'],source_label_sha256=r['source_label_sha256'],
            width=r['width'],height=r['height'],boxes=r['boxes'],primary_bin=int(r['boxes'][0][0]),
            label=str(label),label_sha256=sha(label),group='datacluster_all_sources_train_only',
            capture_group='datacluster_all_sources_train_only',annotation_status=ledger[r['id']]['status'],
            phash=r['phash'],sha256_pixels=r['sha256_pixels'],historical_nearest_phash=ledger[r['id']]['nearest_recorded_historical_phash'],
            license='CC0 declared by upstream dataset metadata; retain acquisition provenance.',
            new_source_image=True,real_scene_photo_visually_reviewed=True,independent_camera_capture=False,
            physical_object_identity_unknown=True))
    save(out/'manifest.json',additions);save(out/'review_ledger.json',ledger)
    save(out/'result.json',dict(status='FROZEN_REVIEWED_SOURCE_ADDITIONS_NOT_YET_TRAINED',
        source_files=len(rows),excluded_after_review=len(excluded),
        box_instances=dict(Counter(int(b[0]) for r in rows for b in r['boxes'])),
        hand_images=sum(any(int(b[0])==4 for b in r['boxes']) for r in rows),
        source_counts=dict(Counter(r['source'] for r in rows)),derived_images_added=0,new_camera_station_captures=0,
        orientation_normalizations_are_same_source_photo=True,manifest_sha256=sha(out/'manifest.json'),
        review_inventory_sha256=sha(reviewed/'inventory.json'),review_ledger_sha256=sha(reviewed/'ledger.json'),
        final_overlay_sha256={p.name:sha(p) for p in reviewed.glob('overlay_*.jpg')},
        identity_metadata_sha256={p:sha(p) for p in paths+[cache]},
        acquisition_sha256={s:sha(args.acquisition_root/s/'acquisition.json') for s in (args.source or ['plastic','cardboard','household_clutter'])},
        current_experiments_changed=False,final_test_files_read=False,
        limitations=['Public indoor/outdoor scenes; no new station captures.',
            'Unknown physical object/session identity; all sources train-only, no new independent validation.',
            'Manually reviewed selected scenes; source counts and class boxes reported above. Not enough to establish universal recognition.']))
    print(read(out/'result.json'),flush=True)


if __name__=='__main__':main()
