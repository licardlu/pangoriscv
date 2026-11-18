"""Audit pinned upstreamtrain only; propose mask extents, no semantic labels."""
from concurrent.futures import ThreadPoolExecutor
from collections import Counter
import argparse
import hashlib
import json
from pathlib import Path
import numpy as np
from PIL import Image
from audit_public_expansion import features
from collect_public_expansion import sheets


def read(path):return json.loads(Path(path).read_text(encoding='utf8'))


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--snapshot',action='store_true',help='Freeze complete verified rows currently available; never assume a partial acquisition completed.')
    parser.add_argument('--out',type=Path)
    args=parser.parse_args()
    root=Path('build/noon_continuation_20261118_001/research/handheld_mirrors_001/mju_train_001')
    if args.snapshot:
        inventory=read(root/'inventory.json')
        source_rows=[r for r in inventory if r['status']=='DOWNLOADED_FOR_REVIEW_NOT_ADMITTED']
        assert len(source_rows)>100
    else:
        result=read(root/'result.json');assert result['complete']==1485 and not result['failed']
        source_rows=read(root/'inventory.json')
    out=args.out or root/'audit_001';out.mkdir(exist_ok=False)
    (out/'acquisition_snapshot.json').write_text(json.dumps(source_rows,indent=2),encoding='utf8')
    base=Path('build/public_20k_20261117_001')
    known=[]
    for p in [base/'dataset_004/manifest.json',base/'public_dev_001/manifest.json',
        Path('build/overnight_20261116/dataset_stage4/manifest.json'),
        Path('build/public_expansion_20261117_001/dedup_inventory.json'),
        Path('build/public_targeted_20261118_001/identity_audit.json'),
        Path('build/held_background_dev_20261118_001/inventory.json'),
        Path('build/noon_continuation_20261118_001/research/organic_001/reviewed_foam_dataset_001/manifest.json')]:known+=read(p)
    known+=list(read(base/'historical_feature_cache.json').values())
    oldsha={r.get('image_sha256',r.get('sha256')) for r in known}
    oldsha.update(r.get('original_sha256') for r in known)
    oldpixels={r['sha256_pixels'] for r in known if r.get('sha256_pixels')}
    oldph=np.asarray(sorted({int(r['phash']) for r in known if 'phash' in r}),dtype=np.uint64)
    lut=np.asarray([bin(i).count('1') for i in range(256)],dtype=np.uint8)
    def inspect(row):
        row=dict(row,path=row['images'],image_sha256=row['images_sha256'])
        try:
            assert row['source_split']=='train' and hashlib.sha256(Path(row['images']).read_bytes()).hexdigest()==row['images_sha256']
            assert hashlib.sha256(Path(row['masks']).read_bytes()).hexdigest()==row['masks_sha256']
            with Image.open(row['images']) as im:
                width,height=im.size;assert im.getexif().get(274,1)==1
            with Image.open(row['masks']) as mask:
                assert mask.size==(width,height)
                colors=np.asarray(mask.convert('RGB'))
                assert set(map(tuple,colors.reshape(-1,3))).issubset({(0,0,0),(128,0,0)})
            # Indexed PNG palettes differ; semantic dark-red foreground is
            # authoritative. On this mirror index0isforeground, index1background.
            y,x=np.where(np.all(colors==[128,0,0],axis=2));assert len(y)>64
            x1,y1,x2,y2=int(x.min()),int(y.min()),int(x.max())+1,int(y.max())+1
            row.update(width=width,height=height,mask_bbox=[x1,y1,x2,y2],**features(Path(row['images'])))
            distance=int(lut[(oldph^np.uint64(row['phash'])).view(np.uint8).reshape(-1,8)].sum(1).min())
            row['historical_nearest_phash']=distance
            row.update(annotations=[dict(category_id=0,bbox=[x1,y1,x2-x1,y2-y1])],category_names={'0':'source_waste_NEEDS_BIN_AND_HANDS'})
            row['admission']='EXCLUDE_HISTORICAL_EXACT_OR_NEAR' if row['image_sha256'] in oldsha or row['sha256_pixels'] in oldpixels or distance<=6 else 'PENDING_FOURBIN_HAND_FULLINSTANCE_REVIEW'
        except Exception as error:row.update(admission='EXCLUDE_SCHEMA_OR_IMAGE',error=repr(error))
        return row
    rows=[]
    with ThreadPoolExecutor(max_workers=2) as pool:
        for n,row in enumerate(pool.map(inspect,source_rows),1):
            rows.append(row)
            if n%128==0:print('audited',n,flush=True)
    accepted=[]
    for row in rows:
        if not row['admission'].startswith('PENDING_'):continue
        match=next((r['id'] for r in accepted if r['sha256_pixels']==row['sha256_pixels'] or bin(r['phash']^row['phash']).count('1')<=6),None)
        if match:row.update(admission='EXCLUDE_INTERNAL_EXACT_OR_NEAR',duplicate_of=match)
        else:accepted.append(row)
    # Uniform chronological coverage includes each part of the acquisition, not
    # a model-confidence or validation-error selection.
    selected=[]
    for i in np.linspace(0,len(accepted)-1,min(120,len(accepted)),dtype=int):
        r=dict(accepted[i]);n=len(selected)+1;r.update(source_id=r['id'],review_index=n,id=f'{n:03}_'+r['id']);selected.append(r)
    (out/'inventory.json').write_text(json.dumps(rows,indent=2),encoding='utf8')
    (out/'review_order.json').write_text(json.dumps(selected,indent=2),encoding='utf8')
    sheets(selected,out,'mju')
    report=dict(status='REVIEW_ONLY_NO_ADMISSION',counts=dict(Counter(r['admission'] for r in rows)),
        selected=len(selected),historical_metadata_only=True,final_test_files_read=False,
        source_test_valid_contents_read=False,training_admitted=0,acquisition_partial_snapshot=args.snapshot,
        foreground_rule='RGB128,0,0 waste; RGB0,0,0 background. Never assume indexed palette label1iswaste.',
        acquisition_snapshot_rows=len(source_rows),
        acquisition_snapshot_sha256=hashlib.sha256((out/'acquisition_snapshot.json').read_bytes()).hexdigest())
    (out/'result.json').write_text(json.dumps(report,indent=2),encoding='utf8');print(report,flush=True)


if __name__=='__main__':main()
