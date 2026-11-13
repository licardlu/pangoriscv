"""Propose missing hand boxes on garbage TRAIN images for visual review.

Never creates training labels automatically. Existing waste annotations are
shown in blue, proposed hands in magenta; every proposal needs visual review.
"""
import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import sys
from PIL import Image,ImageDraw,ImageFont


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--data',type=Path,required=True)
    p.add_argument('--weights',type=Path,required=True)
    p.add_argument('--yolo',type=Path,required=True)
    p.add_argument('--out',type=Path,required=True)
    a=p.parse_args();a.out.mkdir(parents=True,exist_ok=False)
    os.environ['YOLOv5_AUTOINSTALL']='false';os.environ['WANDB_MODE']='disabled'
    os.environ['YOLOV5_CONFIG_DIR']=str((a.out/'config').resolve())
    sys.path.insert(0,str(a.yolo.resolve()))
    import cv2
    import numpy as np
    import torch
    from utils.augmentations import letterbox
    from utils.general import non_max_suppression,scale_boxes
    torch.set_num_threads(1);torch.set_num_interop_threads(1);cv2.setNumThreads(0)
    cp=torch.load(a.weights,map_location='cpu')
    model=(cp.get('ema') or cp['model']).float().eval()
    if model.model[-1].nc!=5:raise ValueError('Expected four bins + internal hand')
    source=json.loads((a.data/'manifest.json').read_text(encoding='utf8'))
    rows=[r for r in source if r['split']=='train' and r['source']!='hagrid_hand_localisation']
    font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',16)
    candidates=[];thumbs=[]
    with torch.inference_mode():
        for i,row in enumerate(rows):
            path=Path(row['prepared_image'])
            with Image.open(path) as im:rgb=np.array(im.convert('RGB'))
            h,w=rgb.shape[:2]
            canvas=letterbox(rgb,320,auto=False)[0]
            x=torch.from_numpy(np.ascontiguousarray(canvas.transpose(2,0,1))).float()[None]/255
            pred=non_max_suppression(model(x)[0],.25,.45,multi_label=False,max_det=32)[0]
            hands=pred[pred[:,5]==4].clone()
            if len(hands):
                hands[:,:4]=scale_boxes(x.shape[2:],hands[:,:4],rgb.shape)
                proposals=hands.cpu().tolist()
                idx=len(candidates)+1
                candidates.append(dict(review_id=idx,path=str(path.resolve()),split='train',
                    source=row['source'],source_group=row['group'],width=w,height=h,
                    sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
                    proposed_hands_xyxy_conf=proposals,waste_boxes=row['boxes'],review_status='unreviewed'))
                im=Image.fromarray(rgb);im.thumbnail((300,260));d=ImageDraw.Draw(im)
                sx,sy=im.width/w,im.height/h
                for _,bx,by,bw,bh in row['boxes']:
                    d.rectangle(((bx-bw/2)*im.width,(by-bh/2)*im.height,
                        (bx+bw/2)*im.width,(by+bh/2)*im.height),outline='blue',width=2)
                for j,b in enumerate(proposals):
                    d.rectangle((b[0]*sx,b[1]*sy,b[2]*sx,b[3]*sy),outline='magenta',width=3)
                    d.text((b[0]*sx,b[1]*sy),f'H{j} {b[4]:.2f}',font=font,fill='magenta',stroke_width=1,stroke_fill='black')
                card=Image.new('RGB',(320,300),'#eeeeee');card.paste(im,((320-im.width)//2,0))
                ImageDraw.Draw(card).text((5,265),f'REVIEW {idx}  {w}x{h}',font=font,fill='black');thumbs.append(card)
            if (i+1)%100==0:print('PROPOSE_TRAIN_HAND',i+1,len(candidates),flush=True)
    for start in range(0,len(thumbs),16):
        batch=thumbs[start:start+16];sheet=Image.new('RGB',(1280,math.ceil(len(batch)/4)*300),'white')
        for i,im in enumerate(batch):sheet.paste(im,((i%4)*320,(i//4)*300))
        sheet.save(a.out/f'review_{start//16+1:02d}.jpg',quality=95)
    report=dict(status='UNREVIEWED_NO_TRAINING_LABELS',checkpoint_sha256=hashlib.sha256(a.weights.read_bytes()).hexdigest(),
        manifest_sha256=hashlib.sha256((a.data/'manifest.json').read_bytes()).hexdigest(),
        scope='train only; no val/test/personal images',images_scanned=len(rows),candidates=candidates)
    (a.out/'proposals.json').write_text(json.dumps(report,indent=2),encoding='utf8')
    print('TRAIN_HAND_PROPOSALS',len(candidates),flush=True)


if __name__=='__main__':main()
