"""Train-only schema/identity audit and stratified visual-review preparation.

No images are admitted. Test and upstream valid files are not opened. The
uploader's category ordering comes from data.yaml, not its conflicting prose.
"""
from collections import Counter
from concurrent.futures import ThreadPoolExecutor
import argparse
import hashlib
import json
from pathlib import Path
import numpy as np
from PIL import Image
import yaml
from audit_public_expansion import features
from collect_public_expansion import sheets


def read(p):
    return json.loads(Path(p).read_text(encoding='utf8'))


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--classes',type=int,nargs='+',default=[c for c in range(34) if c!=19])
    parser.add_argument('--out',type=Path)
    parser.add_argument('--review-count',type=int,default=6)
    parser.add_argument('--polygons',action='store_true',help='Explicitly support polygon source labels as extent proposals; no auto-admission.')
    args=parser.parse_args();allowed=set(args.classes)
    assert allowed and allowed.issubset(range(39)) and 1<=args.review_count<=24
    root=Path('build/noon_continuation_20261118_001/research/organic_001')
    out=args.out or root/'audit_001';out.mkdir(exist_ok=False)
    raw=Path(read(root/'organic3_acquisition.json')['raw'])/'Final_dataset'
    names=yaml.safe_load((raw/'data.yaml').read_text(encoding='utf8'))['names']
    assert len(names)==39 and names[7]=='Egg-hard' and names[19]=='Other-waste'
    base=Path('build/public_20k_20261117_001')
    records=[]
    for p in [base/'dataset_004/manifest.json',base/'public_dev_001/manifest.json',
              Path('build/overnight_20261116/dataset_stage4/manifest.json'),
              Path('build/public_expansion_20261117_001/dedup_inventory.json'),
              Path('build/public_targeted_20261118_001/identity_audit.json'),
              Path('build/held_background_dev_20261118_001/inventory.json'),
              Path('build/extras_battery_candidates_20261118_001/inventory.json'),
              Path('build/wastesense_review_20261118_001/inventory.json')]:
        records+=read(p)
    records+=list(read(base/'historical_feature_cache.json').values())
    oldsha={r.get('image_sha256',r.get('sha256')) for r in records}
    oldsha.update(r.get('original_sha256') for r in records)
    oldpixels={r['sha256_pixels'] for r in records if r.get('sha256_pixels')}
    oldph=np.asarray(sorted({int(r['phash']) for r in records if 'phash' in r}),dtype=np.uint64)
    lut=np.asarray([bin(i).count('1') for i in range(256)],dtype=np.uint8)
    def inspect(path):
        row=dict(id='organic39_'+path.stem,path=str(path.resolve()),source='caodatan_organic39',
                 source_file=path.relative_to(raw).as_posix(),category_names={str(i):n for i,n in enumerate(names)})
        try:
            label=raw/'train/labels'/(path.stem+'.txt')
            boxes=[]
            for line in label.read_text(encoding='utf-8-sig').splitlines():
                if not line.strip():continue
                values=list(map(float,line.split()))
                if len(values)==5:
                    b=values
                else:
                    assert args.polygons and len(values)>=7 and (len(values)-1)%2==0,'Polygon requires explicit format support or invalid schema'
                    points=np.asarray(values[1:]).reshape(-1,2)
                    assert np.isfinite(points).all() and (points>=-1e-9).all() and (points<=1+1e-9).all()
                    lo,hi=points.min(0),points.max(0)
                    b=[values[0],*(lo+hi)/2,*(hi-lo)]
                c,cx,cy,w,h=b;assert c==int(c) and 0<=c<39 and w>0 and h>0
                assert min(cx-w/2,cy-h/2)>=-1e-6 and max(cx+w/2,cy+h/2)<=1+1e-6
                boxes.append([int(c),cx,cy,w,h])
            assert boxes
            # Review the underrepresented food and ordinary-waste classes first.
            if not all(b[0] in allowed for b in boxes):
                return dict(row,admission='DEFER_OUTSIDE_FOCUSED_TAXONOMY')
            with Image.open(path) as im:
                assert im.getexif().get(274,1)==1
                width,height=im.size
            row.update(width=width,height=height,source_boxes=boxes,
                       image_sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
                       source_label_sha256=hashlib.sha256(label.read_bytes()).hexdigest(),**features(path))
            distance=int(lut[(oldph^np.uint64(row['phash'])).view(np.uint8).reshape(-1,8)].sum(1).min())
            row['historical_nearest_phash']=distance
            if row['image_sha256'] in oldsha or row['sha256_pixels'] in oldpixels or distance<=6:
                return dict(row,admission='EXCLUDE_HISTORICAL_EXACT_OR_NEAR')
            row['annotations']=[dict(category_id=b[0],bbox=[(b[1]-b[3]/2)*width,(b[2]-b[4]/2)*height,b[3]*width,b[4]*height]) for b in boxes]
            return dict(row,admission='PENDING_VISUAL_FULL_INSTANCE_HAND_AND_POLICY_REVIEW')
        except Exception as error:
            return dict(row,admission='EXCLUDE_SCHEMA_OR_IMAGE',error=repr(error))
    paths=sorted((raw/'train/images').glob('*'))
    assert paths and all('train' in p.parts for p in paths)
    rows=[]
    with ThreadPoolExecutor(max_workers=2) as pool:
        for i,row in enumerate(pool.map(inspect,paths),1):
            rows.append(row)
            if i%512==0:print('audited',i,'/',len(paths),flush=True)
    accepted=[]
    for row in rows:
        if not row['admission'].startswith('PENDING_'):continue
        duplicate=next((x['id'] for x in accepted if x['sha256_pixels']==row['sha256_pixels'] or bin(x['phash']^row['phash']).count('1')<=6),None)
        if duplicate:row.update(admission='EXCLUDE_INTERNAL_EXACT_OR_NEAR',duplicate_of=duplicate)
        else:accepted.append(row)
    selected=[];seen=set()
    for c in sorted(allowed):
        pool=[r for r in accepted if any(b[0]==c for b in r['source_boxes'])]
        pool.sort(key=lambda r:hashlib.sha256(r['id'].encode()).hexdigest())
        for row in pool[:args.review_count]:
            if row['id'] not in seen:selected.append(row);seen.add(row['id'])
    (out/'inventory.json').write_text(json.dumps(rows,indent=2),encoding='utf8')
    (out/'review_order.json').write_text(json.dumps(selected,indent=2),encoding='utf8')
    sheets(selected,out,'review')
    report=dict(status='REVIEW_ONLY_NOT_TRAINING_ADMITTED',counts=dict(Counter(r['admission'] for r in rows)),
                source_train_images=len(paths),selected_for_visual_review=len(selected),
                source_class_counts=dict(Counter(b[0] for r in accepted for b in r['source_boxes'])),
                historical_metadata_rows=len(records),historical_phashes=len(oldph),
                focused_classes=sorted(allowed),
                polygon_extent_proposals_supported=args.polygons,
                final_test_files_opened=False,upstream_validation_files_opened=False,
                note='No pseudo boxes; full visual review must confirm taxonomy and every visible hand/object before any admission. Source-wide train only; file identities do not prove different physical objects.')
    (out/'result.json').write_text(json.dumps(report,indent=2),encoding='utf8')
    print(json.dumps(report),flush=True)


if __name__=='__main__':
    main()
