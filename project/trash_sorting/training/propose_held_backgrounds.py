"""Propose source-box-free crops; these remain unlabelled until visual review."""
import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image
from collect_public_expansion import sheets

ACCEPTED_SOURCE_IDS={494,980,468,487,489,492,1066,1055,450,981,434,984,490,987,1042,1068,1053,449}
EXCLUDED_SOURCE_REASONS={991:'Small fragments and source completeness unresolved at available resolution',
    1004:'Defer clutter completeness review',446:'Possible unlabelled white paper/tissue; not complete five-class GT',
    478:'Historical near duplicate; excluded with all derivative views',448:'Possible unlabelled packaging in clutter',
    431:'Rope/net extent and plastic coverage ambiguous'}


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--root',type=Path,required=True)
    a=p.parse_args();root=a.root.resolve();rows=json.loads((root/'inventory.json').read_text(encoding='utf8'))
    out=root/'background_proposals';out.mkdir(exist_ok=False)
    proposals=[];ledger={}
    for row in rows:
        key=row['source_image_id']
        accepted=key in ACCEPTED_SOURCE_IDS
        assert accepted or key in EXCLUDED_SOURCE_REASONS
        ledger[row['id']]=dict(status='VISUALLY_REVIEWED_ACCEPT' if accepted else 'EXCLUDED',
            reason='Full source overlay inspected: mapped garbage boxes, no visible hand or extra salient refuse' if accepted else EXCLUDED_SOURCE_REASONS[key],
            source_sha256=row['image_sha256'],reviewer='assistant_visual',
            boxes_xyxy=[[int(row['mapping'][str(b['category_id'])]),b['bbox'][0],b['bbox'][1],b['bbox'][0]+b['bbox'][2],b['bbox'][1]+b['bbox'][3]] for b in row['annotations']] if accepted else [])
        if not accepted:continue
        assert row['admission']=='REQUIRES_VISUAL_REVIEW'
        im=Image.open(row['path']).convert('RGB');w,h=im.size
        assert hashlib.sha256(Path(row['path']).read_bytes()).hexdigest()==row['image_sha256']
        cw,ch=w//2,h//2;options=[]
        for fx in [0,.25,.5]:
            for fy in [0,.25,.5]:
                x1,y1=int(w*fx),int(h*fy);x2,y2=x1+cw,y1+ch
                # Add 2% margin around every annotated source object.
                intersects=False
                for b in row['annotations']:
                    x,y,bw,bh=b['bbox'];m=.02*max(w,h)
                    if min(x2,x+bw+m)>max(x1,x-m) and min(y2,y+bh+m)>max(y1,y-m):intersects=True
                if not intersects:options.append((x1,y1,x2,y2))
        chosen=[]
        for rect in options:
            def intersection(other):
                return max(0,min(rect[2],other[2])-max(rect[0],other[0]))*max(0,min(rect[3],other[3])-max(rect[1],other[1]))
            if any(intersection(prior)>cw*ch*.25 for prior in chosen):continue
            chosen.append(rect)
            if len(chosen)==2:break
        for i,rect in enumerate(chosen):
            crop=im.crop(rect);crop.thumbnail((640,640))
            path=out/(row['id']+'_empty_%d.png'%i);crop.save(path)
            proposals.append(dict(id=path.stem,path=str(path),width=crop.width,height=crop.height,
                parent_id=row['id'],parent_sha256=row['image_sha256'],crop_xyxy=rect,
                source_image_id=key,source_file=row['source_file'],source_url=row['source_url'],
                image_sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
                annotations=[],category_names={},status='BOX_FREE_PROPOSAL_REQUIRES_VISUAL_REVIEW',
                new_source_photograph=False))
    (root/'source_review_ledger.json').write_text(json.dumps(ledger,indent=2),encoding='utf8')
    (root/'background_proposals.json').write_text(json.dumps(proposals,indent=2),encoding='utf8')
    sheets(proposals,root/'review','empty_review')
    print(dict(reviewed_source_photos=len(ACCEPTED_SOURCE_IDS),excluded=len(EXCLUDED_SOURCE_REASONS),empty_proposals=len(proposals),
               crops_are_not_new_photos=True,training_admission=False),flush=True)


if __name__=='__main__':main()
