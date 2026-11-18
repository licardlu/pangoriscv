"""Audit one variant per original capture before reviewing fruit detection GT.

Only upstream train images/labels are opened. Upstream valid identities come
from ZIP names, not image/label contents. No reviewed labels are manufactured.
"""
from collections import Counter,defaultdict
import argparse
import hashlib
import json
from pathlib import Path
import re
import numpy as np
from PIL import Image
import yaml
from audit_public_expansion import features
from collect_public_expansion import sheets


def read(p):return json.loads(Path(p).read_text(encoding='utf8'))
def canonical(name):return re.sub(r'_(jpg|png|jpeg)$','',re.sub(r'\.rf\.[a-f0-9]+$','',Path(name).stem.lower()))


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out',type=Path)
    args=parser.parse_args()
    root=Path('build/noon_continuation_20261118_001/research/organic_001')
    out=args.out or root/'fruit_audit_001';out.mkdir(exist_ok=False)
    raw=Path(read(root/'fruitquality_acquisition.json')['raw'])/'Fruit Quality Classification'
    names=yaml.safe_load((raw/'data.yaml').read_text(encoding='utf8'))['names'];assert len(names)==14
    index=read(root/'indexes/fruitquality/index.json')
    protected={canonical(x['name']) for x in index['entries'] if '/valid/images/' in x['name'] or '/test/images/' in x['name']}
    groups=defaultdict(list)
    for image in sorted((raw/'train/images').iterdir()):groups[canonical(image.name)].append(image)
    records=list(read('build/public_20k_20261117_001/historical_feature_cache.json').values())
    for path in ['build/wastesense_review_20261118_001/dataset_001/manifest.json',
                 'build/public_20k_20261117_001/public_dev_001/manifest.json',
                 'build/public_expansion_20261117_001/dedup_inventory.json',
                 'build/public_targeted_20261118_001/identity_audit.json',
                 'build/held_background_dev_20261118_001/inventory.json',
                 'build/extras_battery_candidates_20261118_001/inventory.json',
                 'build/wastesense_review_20261118_001/inventory.json']:
        records+=read(path)
    oldsha={r.get('image_sha256',r.get('sha256')) for r in records};oldsha.update(r.get('original_sha256') for r in records)
    oldpixels={r['sha256_pixels'] for r in records if r.get('sha256_pixels')}
    oldph=np.asarray(sorted({int(r['phash']) for r in records if 'phash' in r}),dtype=np.uint64)
    lut=np.asarray([bin(i).count('1') for i in range(256)],dtype=np.uint8)
    rows=[];accepted=[]
    for identity,paths in sorted(groups.items()):
        path=paths[0]
        row=dict(id='fruit_'+hashlib.sha256(identity.encode()).hexdigest()[:16],canonical_capture=identity,
                 path=str(path.resolve()),source='abrars2_fruit_quality',
                 source_file=path.relative_to(raw).as_posix(),source_variants=len(paths),
                 category_names={str(i):n for i,n in enumerate(names)})
        if identity in protected:
            rows.append(dict(row,admission='EXCLUDE_UPSTREAM_HELD_CAPTURE_BY_FILENAME'));continue
        try:
            label=raw/'train/labels'/(path.stem+'.txt')
            boxes=[]
            for line in label.read_text(encoding='utf-8-sig').splitlines():
                if not line.strip():continue
                values=list(map(float,line.split()))
                if len(values)==5:
                    b=values
                else:
                    assert len(values)>=7 and (len(values)-1)%2==0,'Invalid polygon schema'
                    points=np.asarray(values[1:]).reshape(-1,2)
                    assert np.isfinite(points).all() and (points>=0).all() and (points<=1).all()
                    lo,hi=points.min(0),points.max(0)
                    b=[values[0],*(lo+hi)/2,*(hi-lo)]
                c,cx,cy,w,h=b;assert c==int(c) and 0<=c<14 and w>0 and h>0
                assert min(cx-w/2,cy-h/2)>=-1e-6 and max(cx+w/2,cy+h/2)<=1+1e-6
                boxes.append([int(c),cx,cy,w,h])
            assert boxes
            with Image.open(path) as im:
                assert im.getexif().get(274,1)==1
                width,height=im.size
            row.update(width=width,height=height,source_boxes=boxes,
                image_sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
                source_label_sha256=hashlib.sha256(label.read_bytes()).hexdigest(),**features(path))
            distance=int(lut[(oldph^np.uint64(row['phash'])).view(np.uint8).reshape(-1,8)].sum(1).min());row['historical_nearest_phash']=distance
            if row['image_sha256'] in oldsha or row['sha256_pixels'] in oldpixels or distance<=6:
                rows.append(dict(row,admission='EXCLUDE_HISTORICAL_EXACT_OR_NEAR'));continue
            duplicate=next((x['id'] for x in accepted if x['sha256_pixels']==row['sha256_pixels'] or bin(x['phash']^row['phash']).count('1')<=6),None)
            if duplicate:
                rows.append(dict(row,admission='EXCLUDE_INTERNAL_NEAR',duplicate_of=duplicate));continue
            row['annotations']=[dict(category_id=b[0],bbox=[(b[1]-b[3]/2)*width,(b[2]-b[4]/2)*height,b[3]*width,b[4]*height]) for b in boxes]
            row['admission']='PENDING_VISUAL_COMPLETE_FRUIT_HAND_REVIEW';rows.append(row);accepted.append(row)
        except Exception as error:rows.append(dict(row,admission='EXCLUDE_SCHEMA_OR_IMAGE',error=repr(error)))
    selected=[];seen=set()
    for c in range(14):
        pool=[r for r in accepted if any(b[0]==c for b in r['source_boxes'])]
        pool.sort(key=lambda r:hashlib.sha256(r['id'].encode()).hexdigest())
        for row in pool[:10]:
            if row['id'] not in seen:selected.append(row);seen.add(row['id'])
    (out/'inventory.json').write_text(json.dumps(rows,indent=2),encoding='utf8')
    (out/'review_order.json').write_text(json.dumps(selected,indent=2),encoding='utf8')
    sheets(selected,out,'review')
    report=dict(status='REVIEW_ONLY_NOT_TRAINING_ADMITTED',upstream_train_variants=sum(map(len,groups.values())),
        canonical_train_captures=len(groups),selected_for_review=len(selected),
        counts=dict(Counter(r['admission'] for r in rows)),
        held_capture_ids_checked_from_names=len(protected),test_and_valid_files_opened=False,
                annotation_formats='YOLO boxes or polygon extents; polygon extents still require full visual completeness review.',
                note='One lexicographically first upstream augmentation per capture. Same fruit and consecutive captures remain correlated; source-wide train-only if admitted. Existing deployed model unchanged. Initial fruit_audit_001 only supported boxes and its temporary format failures are preserved; this audit explicitly adds source polygon support, without changing any historical exclusion.')
    (out/'result.json').write_text(json.dumps(report,indent=2),encoding='utf8');print(json.dumps(report),flush=True)


if __name__=='__main__':main()
