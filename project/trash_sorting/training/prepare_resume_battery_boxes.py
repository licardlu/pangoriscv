"""Propose boxes only for screened single detached battery pictures, for review."""
import json
from pathlib import Path
import cv2
import numpy as np
from PIL import Image
from collect_public_expansion import sheets

SINGLE=[10,25,28,39,109,140,244,246,247,249,250,251,252,253,254,256,257,258,260,
    263,264,265,267,268,269,271,273,275,276,277,278,279,280,281,282,284,286,287,
    289,291,294,295,297,300,301,302,304,307,308,311,316,320,324,328,329,333,334,
    335,336,340,341,342,344,345,346,347,348,350,352,353,355,358,359,360,361,362,
    363,364,365,366,367,370,371,376,377,378,379,380,383,387,389,390,391,393,394,
    396,397,398,400,402,403,404,406,410,412,413,414,419,420,421,424,427,428,429,
    430,431,433,435,436,439,440,442,444,445,446,447,449,451,452,453,454,455,456,
    458,459,463,466,468,470,471,472,473,474,478,479,482,483,485,486,487,488,489,
    490,491,492,493,494,495,505,506]
MULTI=[19,22,34,37,42,48,50,52,53,54,56,57,58,59,65,70,82,163,196,198,209,212,
       214,227,235,236,241,242,243]


def main():
    root=Path('build/joint_battery_resume_20261118_001/research/extras_remaining_001')
    lookup={r['id']:r for r in json.loads((root/'inventory.json').read_text())}
    out=root/'single_proposals_001';out.mkdir(exist_ok=False)
    rows=[]
    for number in SINGLE:
        r=lookup['battery'+str(number)]
        a=np.array(Image.open(r['path']).convert('RGB'))
        border=np.concatenate([a[0],a[-1],a[:,0],a[:,-1]])
        bg=np.median(border,axis=0)
        mask=(np.max(np.abs(a.astype(float)-bg),axis=2)>45).astype('uint8')
        mask=cv2.morphologyEx(mask,cv2.MORPH_CLOSE,np.ones((3,3),np.uint8))
        _,_,stats,_=cv2.connectedComponentsWithStats(mask)
        x,y,w,h,_=max(stats[1:],key=lambda s:s[4])
        x1,y1=max(0,int(x)-1),max(0,int(y)-1)
        x2,y2=min(r['width'],int(x+w)+1),min(r['height'],int(y+h)+1)
        rows.append(dict(r,proposed_xyxy=[x1,y1,x2,y2],
            annotations=[dict(category_id=2,bbox=[x1,y1,x2-x1,y2-y1])],
            category_names={'2':'battery proposal'},status='NOT_ADMITTED_OVERLAY_REVIEW_PENDING'))
    (out/'inventory.json').write_text(json.dumps(rows,indent=2),encoding='utf8')
    sheets(rows,out,'proposals')
    multi=root/'multi_review_002';multi.mkdir(exist_ok=False)
    from PIL import ImageDraw,ImageFont
    font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',20)
    layout={}
    for start in range(0,len(MULTI),6):
        canvas=Image.new('RGB',(1200,1320),'#dddddd')
        for j,number in enumerate(MULTI[start:start+6]):
            r=lookup['battery'+str(number)];im=Image.open(r['path']).convert('RGB')
            scale=min(560/im.width,360/im.height)
            im=im.resize((round(im.width*scale),round(im.height*scale)))
            x=(j%2)*600+(600-im.width)//2;y=(j//2)*440+40
            canvas.paste(im,(x,y));d=ImageDraw.Draw(canvas)
            d.text(((j%2)*600+8,(j//2)*440+8),r['id'],font=font,fill='black')
            layout[r['id']]=dict(sheet=start//6+1,xywh=[x,y,im.width,im.height],native_size=[r['width'],r['height']])
        canvas.save(multi/f'review_{start//6+1:02}.jpg',quality=96)
    (multi/'layout.json').write_text(json.dumps(layout,indent=2))
    print(dict(single_proposals=len(rows),multi_for_manual_boxes=len(layout)),flush=True)


if __name__=='__main__':main()
