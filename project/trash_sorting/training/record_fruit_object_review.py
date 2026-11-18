"""Record selected full-object fruit and visible-hand annotation decisions.

All six 128-frame contact sheets and six enlarged hand details were inspected.
Only explicitly selected complete single fruits are proposed for final overlay.
"""
import argparse
import hashlib
import json
from pathlib import Path
from collect_public_expansion import sheets


SINGLE=[9,21,27,33,34,35,37,38,39,42,44,46,48,51,53,54,55,56,57,58,60,
        61,62,63,65,70,72,76,78,92,93,95,97,99,104,107,109,112,118,119,120,128]
DETAIL={
    22:[(0,24,156,934,960),(4,714,134,960,690)],
    28:[(0,60,88,856,904),(4,0,0,558,663)],
    32:[(0,104,258,676,877),(4,217,294,960,960)],
    98:[(0,85,55,668,858),(4,0,0,608,875)],
    110:[(0,131,144,957,957),(4,17,0,938,960)],
    62:[(0,208,181,958,923)],
    119:[(0,0,191,803,797)],
}


def read(p):return json.loads(Path(p).read_text(encoding='utf8'))
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def normal(boxes,size):
    return [[c,(x1+x2)/2/size,(y1+y2)/2/size,(x2-x1)/size,(y2-y1)/size] for c,x1,y1,x2,y2 in boxes]


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out',type=Path)
    args=parser.parse_args()
    root=Path('build/noon_continuation_20261118_001/research/organic_001/fruit_audit_002')
    out=args.out or root/'object_review_001';out.mkdir(exist_ok=False)
    rows=read(root/'review_order.json');ledger={};selected=[]
    for n,row in enumerate(rows,1):
        key=row['id'];item=dict(review_index=n,reviewer='assistant_visual',source_sha256=row['image_sha256'])
        ledger[key]=item
        if n not in SINGLE and n not in DETAIL:
            item.update(status='EXCLUDED_NOT_ADMITTED',reason='Uncertain object/hand extent, severe truncation/augmentation or incompletely annotated multiple fruit; no automatic negative label.');continue
        assert row['admission']=='PENDING_VISUAL_COMPLETE_FRUIT_HAND_REVIEW' and sha(row['path'])==row['image_sha256']
        if n in DETAIL:
            boxes=normal(DETAIL[n],960)
            method='Complete manual whole-fruit and visible-hand replacement from enlarged full image; fruit stem/calyx and thumb/fingers included to frame boundary.'
        else:
            assert len(row['source_boxes'])==1
            boxes=[[0,*row['source_boxes'][0][1:]]]
            method='Full image and source extent visually checked for one complete visible fruit and no hand; four-bin mapping is kitchen regardless ripeness.'
        if n==63:
            boxes=normal([(0,43,34,270,270)],270)
            method='Manual whole apple extent includes the projecting stem omitted by the source contour box.'
        assert len([b for b in boxes if int(b[0])==0])==1
        item.update(status='PENDING_FINAL_OVERLAY_REVIEW',boxes=boxes,method=method)
        w,h=row['width'],row['height']
        selected.append(dict(row,review_index=n,mapped_boxes=boxes,category_names={'0':'kitchen','4':'hand'},
            annotations=[dict(category_id=b[0],bbox=[(b[1]-b[3]/2)*w,(b[2]-b[4]/2)*h,b[3]*w,b[4]*h]) for b in boxes]))
    assert len(selected)==47
    (out/'ledger.json').write_text(json.dumps(ledger,indent=2),encoding='utf8')
    (out/'candidates.json').write_text(json.dumps(selected,indent=2),encoding='utf8')
    sheets(selected,out,'overlay')
    print(dict(source_views=47,kitchen_boxes=47,hand_boxes=5,training_admission=0),flush=True)


if __name__=='__main__':main()
