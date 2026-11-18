"""Generate foreground box proposals for visually selected single-battery images."""
import json
from pathlib import Path

import cv2
import numpy as np
from PIL import Image
from collect_public_expansion import sheets

SELECTED=[108,119,120,125,129,130,132,135,156,158,161,172,173,174,180,182,185,192,
          200,203,204,206,207,210,226,228,229,237,239,240,29,3,31,38,46,61,79,81]


def main():
    root=Path('build/extras_battery_candidates_20261118_001').resolve()
    allrows=json.loads((root/'inventory.json').read_text(encoding='utf8'))
    lookup={r['id']:r for r in allrows};proposals=[]
    for number in SELECTED:
        r=lookup['battery'+str(number)]
        assert r['admission']=='REQUIRES_VISUAL_AND_COMPLETE_BOX_REVIEW'
        im=np.array(Image.open(r['path']).convert('RGB'))
        border=np.concatenate([im[0],im[-1],im[:,0],im[:,-1]],axis=0)
        bg=np.median(border,axis=0)
        mask=(np.max(abs(im.astype(float)-bg),axis=2)>45).astype('uint8')
        mask=cv2.morphologyEx(mask,cv2.MORPH_CLOSE,np.ones((3,3),dtype='uint8'))
        n,labels,stats,centers=cv2.connectedComponentsWithStats(mask)
        x,y,w,h,area=max(stats[1:],key=lambda s:s[4])
        x1,y1=max(0,int(x)-2),max(0,int(y)-2);x2,y2=min(r['width'],int(x+w)+2),min(r['height'],int(y+h)+2)
        proposals.append(dict(r,annotations=[dict(category_id=2,bbox=[x1,y1,x2-x1,y2-y1])],
                             category_names={'2':'hazardous proposal'},status='FOREGROUND_PROPOSAL_NOT_APPROVED'))
    (root/'single_battery_box_proposals.json').write_text(json.dumps(proposals,indent=2),encoding='utf8')
    review=root/'single_battery_review';review.mkdir(exist_ok=False)
    sheets(proposals,review,'box_proposal')
    (root/'single_battery_screening.json').write_text(json.dumps(dict(
        selected_ids=['battery'+str(n) for n in SELECTED],reviewer='assistant_visual',
        selection='Contact-sheet visual screening: one clearly visible cylindrical or 9V battery, no hand, no extra object; not based on model prediction.',
        rest='NOT_SELECTED: packs/laptops/large car batteries/piles/duplicates deferred; not assigned negative labels',
        actual_complete_box_review_pending=True,new_train_photos=0),indent=2),encoding='utf8')
    print('PROPOSALS',len(proposals),flush=True)


if __name__=='__main__':main()
