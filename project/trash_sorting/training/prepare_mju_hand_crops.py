"""Propose five explicitly inspected hand-held recyclable training crops.

Derived crops are not independent photos. Full originals remain train-only;
cropping excludes unannotated background waste rather than relabelling it.
"""
import hashlib
import json
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw
from audit_public_expansion import features

CHOICES={
    63:dict(crop=[245,110,378,355],hands=[[264,129,346,183]],item='clear PET bottle'),
    65:dict(crop=[327,155,453,324],hands=[[403,207,446,270]],item='paper notebook'),
    70:dict(crop=[205,164,431,326],hands=[[219,181,302,258],[331,234,418,320]],item='paper leaflet'),
    84:dict(crop=[151,172,374,325],hands=[[185,186,271,269]],object_box=[210,214,363,292],item='clear PET bottle with yellow cap'),
}


def main():
    root=Path('build/noon_continuation_20261118_001/research/handheld_mirrors_001/mju_train_001/audit_002')
    rows=json.loads((root/'review_order.json').read_text(encoding='utf8'))
    out=root/'reviewed_hand_crops_003';out.mkdir(exist_ok=False);(out/'images').mkdir()
    selected=[];canvas=Image.new('RGB',(1200,1000),'white');draw=ImageDraw.Draw(canvas)
    for cell,(index,decision) in enumerate(CHOICES.items()):
        row=rows[index-1];assert row['review_index']==index and row['source_split']=='train'
        assert hashlib.sha256(Path(row['path']).read_bytes()).hexdigest()==row['image_sha256']
        x1,y1,x2,y2=decision['crop'];source=Image.open(row['path']).convert('RGB');im=source.crop((x1,y1,x2,y2));w,h=im.size
        obj=decision.get('object_box',row['mask_bbox']);assert x1<=obj[0]<obj[2]<=x2 and y1<=obj[1]<obj[3]<=y2,(index,obj)
        xyxy=[[1,*obj]]+[[4,*b] for b in decision['hands']]
        boxes=[]
        for c,bx1,by1,bx2,by2 in xyxy:
            assert x1<=bx1<bx2<=x2 and y1<=by1<by2<=y2
            boxes.append([c,((bx1+bx2)/2-x1)/w,((by1+by2)/2-y1)/h,(bx2-bx1)/w,(by2-by1)/h])
        key='mju_handcrop_'+row['source_id'];path=out/'images'/(key+'.png');im.save(path)
        r=dict(id=key,path=str(path.resolve()),width=w,height=h,boxes=boxes,item=decision['item'],
            source_path=row['path'],source_image_sha256=row['image_sha256'],source_mask_sha256=row['masks_sha256'],
            source_file=row['source_id'],crop_xyxy=decision['crop'],review_index=index,
            image_sha256=hashlib.sha256(path.read_bytes()).hexdigest(),**features(path),
            status='PENDING_FINAL_OVERLAY_REVIEW_NOT_ADMITTED')
        selected.append(r)
        view=im.resize((400,400));d=ImageDraw.Draw(view)
        for c,cx,cy,bw,bh in boxes:d.rectangle(((cx-bw/2)*400,(cy-bh/2)*400,(cx+bw/2)*400,(cy+bh/2)*400),outline='lime' if c==4 else 'orange',width=3)
        ox=(cell%3)*400;oy=(cell//3)*500;canvas.paste(view,(ox,oy+40));draw.text((ox+3,oy+5),str(index)+' '+decision['item'],fill='black')
    (out/'candidates.json').write_text(json.dumps(selected,indent=2),encoding='utf8');canvas.save(out/'overlay.jpg',quality=96)
    print(dict(proposed=len(selected),admitted=0),flush=True)


if __name__=='__main__':main()
