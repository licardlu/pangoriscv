"""Fixed source-stratified visual supervision audit of the current train set.

Does not edit any in-flight manifest or use model/validation confidence.
"""
from collections import Counter
import argparse
import hashlib
import json
from pathlib import Path
from PIL import Image
from collect_public_expansion import sheets


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--out',type=Path,required=True);args=parser.parse_args()
    exp=Path('build/quant_reviewed_foam_20261118_001/experiment_001')
    rows=json.loads((exp/'unique_train.json').read_text(encoding='utf8'))
    out=args.out;out.mkdir(exist_ok=False)
    groups={
        'battery':[r for r in rows if any(int(b[0])==2 for b in r['boxes'])],
        'kitchen':[r for r in rows if any(int(b[0])==0 for b in r['boxes'])],
        'other':[r for r in rows if any(int(b[0])==3 for b in r['boxes'])],
        'recyclable_hand':[r for r in rows if any(int(b[0])==1 for b in r['boxes']) and any(int(b[0])==4 for b in r['boxes'])],
    }
    selected=[]
    for group,pool in groups.items():
        source_groups={s:sorted([r for r in pool if r['source']==s],key=lambda r:hashlib.sha256(r['image_sha256'].encode()).hexdigest()) for s in sorted({r['source'] for r in pool})}
        batch=[];i=0
        while len(batch)<24 and any(i<len(v) for v in source_groups.values()):
            for source,values in source_groups.items():
                if i<len(values) and len(batch)<24:batch.append(values[i])
            i+=1
        for r in batch:
            assert r['split']=='train'
            assert hashlib.sha256(Path(r['prepared_image']).read_bytes()).hexdigest()==r['image_sha256']
            with Image.open(r['prepared_image']) as im:
                assert im.getexif().get(274,1)==1
                w,h=im.size
            n=len(selected)+1
            selected.append(dict(r,width=w,height=h,path=r['prepared_image'],id=f'S{n:03} '+group+' '+Path(r['prepared_image']).stem,
                review_index=n,audit_group=group,category_names={str(c):name for c,name in enumerate(['kitchen','recycle','hazard','other','hand'])},
                annotations=[dict(category_id=int(c),bbox=[(cx-bw/2)*w,(cy-bh/2)*h,bw*w,bh*h]) for c,cx,cy,bw,bh in r['boxes']]))
    (out/'review_order.json').write_text(json.dumps(selected,indent=2),encoding='utf8')
    sheets(selected,out,'current_train')
    result=dict(status='REVIEW_ONLY_FROZEN_QUEUE_UNCHANGED',images=len(selected),
        source_counts=dict(Counter(r['source'] for r in selected)),selection='Round-robin sources within fourGTcohorts, each source fixedSHAorder,24percohort',
        final_test_files_read=False,training_manifests_changed=False)
    (out/'result.json').write_text(json.dumps(result,indent=2),encoding='utf8');print(result,flush=True)


if __name__=='__main__':main()
