"""Generate proposals and enlarged sheets after visual screening, not ground truth."""
import json
from pathlib import Path
import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from collect_public_expansion import sheets

DEFER={522,525,534,537,542,564,570,571,582,589,592,613,620,624,651,668,672,680,684,698,706,711,714}
EXTRA_SINGLE={716,725,726,745,746,753,756,838,848,901,902,909,930}
MULTI=[759,760,767,775,780,788,789,791,797,799,800,802,805,806,818,821,826,839,841,845,853,866,883,889,890,892,894,896,905,907,908,918]


def main():
    root=Path('build/joint_battery_resume_20261118_001/research/mostafa_battery_001')
    rows=[r for r in json.loads((root/'inventory.json').read_text()) if r['admission'].startswith('PENDING_')]
    lookup={int(r['id'].split('battery')[-1]):r for r in rows}
    selected=[r for n,r in lookup.items() if (n<=710 and n not in DEFER) or n in EXTRA_SINGLE]
    out=root/'single_proposals_002';out.mkdir(exist_ok=False)
    result=[]
    for r in selected:
        a=np.array(Image.open(r['path']).convert('RGB'))
        border=np.concatenate([a[0],a[-1],a[:,0],a[:,-1]])
        bg=np.median(border,axis=0)
        mask=(np.max(np.abs(a.astype(float)-bg),axis=2)>45).astype('uint8')
        mask=cv2.morphologyEx(mask,cv2.MORPH_CLOSE,np.ones((3,3),np.uint8))
        _,_,stats,_=cv2.connectedComponentsWithStats(mask)
        x,y,w,h,_=max(stats[1:],key=lambda s:s[4])
        x1,y1=max(0,int(x)-1),max(0,int(y)-1)
        x2,y2=min(r['width'],int(x+w)+1),min(r['height'],int(y+h)+1)
        result.append(dict(r,proposed_xyxy=[x1,y1,x2,y2],
            annotations=[dict(category_id=2,bbox=[x1,y1,x2-x1,y2-y1])],
            category_names={'2':'battery proposal'},status='PENDING_BOX_OVERLAY_REVIEW'))
    (out/'inventory.json').write_text(json.dumps(result,indent=2),encoding='utf8')
    sheets(result,out,'proposals')
    multi=root/'multi_review_002';multi.mkdir(exist_ok=False)
    font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',20)
    layout={}
    for start in range(0,len(MULTI),6):
        canvas=Image.new('RGB',(1200,1320),'#dddddd')
        for j,number in enumerate(MULTI[start:start+6]):
            r=lookup[number];im=Image.open(r['path']).convert('RGB')
            scale=min(560/im.width,360/im.height)
            im=im.resize((round(im.width*scale),round(im.height*scale)))
            x=j%2*600+(600-im.width)//2;y=j//2*440+40
            canvas.paste(im,(x,y));ImageDraw.Draw(canvas).text((j%2*600+8,j//2*440+8),r['id'],font=font,fill='black')
            layout[r['id']]=dict(sheet=start//6+1,xywh=[x,y,im.width,im.height],native_size=[r['width'],r['height']])
        canvas.save(multi/f'review_{start//6+1:02}.jpg',quality=96)
    (multi/'layout.json').write_text(json.dumps(layout,indent=2),encoding='utf8')
    print(dict(single_proposals=len(result),manual_review=len(layout)),flush=True)


if __name__=='__main__':main()
