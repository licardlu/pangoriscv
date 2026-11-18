"""Record explicit visual screening decisions and draw battery box proposals for review.

The selected IDs below were screened in the source contact sheets. Generated
battery boxes remain proposals until their overlays are separately reviewed.
"""
import json,hashlib,sys
from pathlib import Path
import cv2,numpy as np
from PIL import Image,ImageDraw,ImageFont
from collect_public_expansion import sheets

root=Path(sys.argv[1]).resolve()
rows=json.loads((root/'dedup_inventory.json').read_text(encoding='utf8'))
taco={12,39,40,43,67,80,82,456,468,651,685,793,797,839,1000,1103,1160,1336,1337,1338,1339,1497,
      55,51,152,1110,471,1154,211,290,975,791,520,1085,1309,748,1415,559,1498,49,780,722,437,1068,399,771}
battery={104,132,17,184,195,2,181,204,208,232,233,255,50,78,80,274,
         0,100,109,111,112,119,121,124,126,13,144,145,15,158,16,170,172,173,176,197,210,218,227}
ledger={};proposals=[]
for r in rows:
    chosen=(r['source']=='taco' and r['source_image_id'] in taco) or (r['source']=='ewaste' and int(r['id'].split('_')[-1]) in battery)
    decision='SELECTED_FOR_BOX_REVIEW' if chosen else 'EXCLUDED_SCREENING'
    reason='clear target; no visible unlabelled hand in contact-sheet review' if chosen else 'outside focused shortlist: tiny/ambiguous clutter, visible unlabelled people/hands, product pile or redundant product type'
    if r['dedup_status']=='REJECT':decision='EXCLUDED_DUPLICATE';reason=r['dedup_reason']
    boxes=[]
    if decision=='SELECTED_FOR_BOX_REVIEW' and r['source']=='taco':
        boxes=[[int(r['proposed_map'][str(b['category_id'])]),*b['bbox']] for b in r['annotations']]
    if decision=='SELECTED_FOR_BOX_REVIEW' and r['source']=='ewaste':
        im=np.array(Image.open(r['path']).convert('RGB'))
        mask=(im.min(axis=2)<225).astype('uint8')
        n,labels,stats,c=cv2.connectedComponentsWithStats(mask)
        # Only a proposal: white-background shadows/text may distort this box.
        x,y,w,h,area=max(stats[1:],key=lambda s:s[4])
        x1,y1=max(0,int(x)-2),max(0,int(y)-2);x2,y2=min(r['width'],int(x+w)+2),min(r['height'],int(y+h)+2)
        boxes=[[2,x1,y1,x2-x1,y2-y1]]
        proposals.append({**r,'annotations':[dict(category_id=2,bbox=boxes[0][1:])],'category_names':{'2':'battery proposal'}})
    ledger[r['id']]=dict(status=decision,reason=reason,sha256=r['sha256'],boxes_xywh=boxes)
(root/'review_screening.json').write_text(json.dumps(dict(reviewer='assistant_visual',coordinate_space='source_pixels_xywh',images=ledger),indent=2),encoding='utf8')
sheets(proposals,root/'candidates','battery_box_proposal')
print('proposals',len(proposals),'TACO',sum(v['status']=='SELECTED_FOR_BOX_REVIEW' and k.startswith('taco') for k,v in ledger.items()),flush=True)
