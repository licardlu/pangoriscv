"""Propose four additional explicitly reviewed source-train hand/object crops."""
import hashlib
import json
from pathlib import Path
from PIL import Image,ImageDraw
from audit_public_expansion import features

CHOICES={
 6:dict(crop=[255,112,430,352],object=[315,151,404,335],hands=[[272,127,350,195]],item='clearPETcoke bottle'),
 13:dict(crop=[195,140,420,315],object=[263,160,358,298],hands=[[217,176,281,238],[337,194,405,260]],item='paper notebook'),
 32:dict(crop=[225,120,432,315],object=[297,155,414,299],hands=[[244,143,326,199]],item='clearPETorange label bottle'),
 71:dict(crop=[210,124,380,308],object=[266,164,364,293],hands=[[228,145,298,203]],item='clearPETgreen label bottle'),
}


def main():
    root=Path('build/noon_continuation_20261118_001/research/handheld_mirrors_001/mju_train_001/audit_002/remaining_review_001')
    rows=json.loads((root/'review_order.json').read_text(encoding='utf8'))
    out=root/'hand_crop_annotations_001';out.mkdir(exist_ok=False);(out/'images').mkdir()
    selected=[];sheet=Image.new('RGB',(1200,1000),'white');d=ImageDraw.Draw(sheet)
    for cell,(n,choice) in enumerate(CHOICES.items()):
        row=rows[n-1];assert row['review_index']==n and row['source_split']=='train'
        assert hashlib.sha256(Path(row['path']).read_bytes()).hexdigest()==row['image_sha256']
        x1,y1,x2,y2=choice['crop'];im=Image.open(row['path']).convert('RGB').crop(choice['crop']);w,h=im.size
        boxes=[]
        for c,(bx1,by1,bx2,by2) in [(1,choice['object'])]+[(4,b) for b in choice['hands']]:
            assert x1<=bx1<bx2<=x2 and y1<=by1<by2<=y2
            boxes.append([c,((bx1+bx2)/2-x1)/w,((by1+by2)/2-y1)/h,(bx2-bx1)/w,(by2-by1)/h])
        key='mju_remaining_handcrop_'+row['source_id'];p=out/'images'/(key+'.png');im.save(p)
        selected.append(dict(id=key,path=str(p.resolve()),width=w,height=h,boxes=boxes,
            source_path=row['path'],parent_image_sha256=row['image_sha256'],source_mask_sha256=row['masks_sha256'],
            source_file=row['source_id'],crop_xyxy=choice['crop'],review_index=n,item=choice['item'],
            image_sha256=hashlib.sha256(p.read_bytes()).hexdigest(),**features(p),
            status='PENDING_FINAL_OVERLAY_REVIEW_NOT_TRAINED'))
        view=im.resize((400,400));v=ImageDraw.Draw(view)
        for c,cx,cy,bw,bh in boxes:v.rectangle(((cx-bw/2)*400,(cy-bh/2)*400,(cx+bw/2)*400,(cy+bh/2)*400),outline='lime' if c==4 else 'orange',width=3)
        x=cell%3*400;y=cell//3*500;sheet.paste(view,(x,y+40));d.text((x+4,y+4),f'R{n:03} '+choice['item'],fill='black')
    sheet.save(out/'overlay.jpg',quality=96)
    (out/'manifest.json').write_text(json.dumps(selected,indent=2),encoding='utf8')
    print(dict(proposed=len(selected),object_boxes=4,hand_boxes=5,training_admitted=0),flush=True)


if __name__=='__main__':main()
