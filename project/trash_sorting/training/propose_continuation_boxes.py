"""Generate review-only detections and numbered sheets; never export labels."""
import argparse,hashlib,json,os,sys,math
from pathlib import Path

def render(root,rows,start=0):
 from PIL import Image,ImageDraw,ImageFont
 font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',15)
 colors={0:'#18a566',1:'#0779ff',2:'#ef3434',3:'#f5a000',4:'#d52bb8'}
 folder=root/'sheets';folder.mkdir(exist_ok=True)
 for offset in range(start,len(rows),12):
  batch=rows[offset:offset+12];sheet=Image.new('RGB',(1440,1530),'#e9eef3')
  for i,r in enumerate(batch):
   cell=Image.new('RGB',(360,510),'white');im=Image.open(r['preview']).convert('RGB');w,h=im.size;im.thumbnail((348,464));sx,sy=im.width/w,im.height/h;draw=ImageDraw.Draw(im)
   for j,b in enumerate(r['proposed_boxes']):
    c=b['category'];x1,y1,x2,y2=b['xyxy'];draw.rectangle((x1*sx,y1*sy,x2*sx,y2*sy),outline=colors[c],width=2)
    draw.text((max(0,x1*sx),max(0,y1*sy-16)),f'{j}:{c}'+(f" {b['score']:.2f}" if 'score' in b else ' GT'),font=font,fill=colors[c],stroke_width=1,stroke_fill='white')
   cell.paste(im,((360-im.width)//2,28));d=ImageDraw.Draw(cell);d.text((5,3),f"{r['id']} {r['class_name']} {r['split']}",font=font,fill='black');d.text((5,492),r['source'][-33:],font=font,fill='#344054')
   sheet.paste(cell,((i%4)*360,(i//4)*510))
  sheet.save(folder/f'sheet_{offset//12+1:03d}.jpg',quality=96)

def main():
 p=argparse.ArgumentParser();p.add_argument('--root',type=Path,required=True);p.add_argument('--yolo',type=Path,required=True);p.add_argument('--weights',type=Path,required=True);p.add_argument('--render-only',action='store_true');a=p.parse_args()
 root=a.root.resolve();draft=root/'proposals.json'
 if a.render_only:
  data=json.loads(draft.read_text(encoding='utf8'));render(root,data['images']);return
 os.environ['YOLOV5_CONFIG_DIR']=str(root/'config');os.environ['YOLOv5_AUTOINSTALL']='false';os.environ['WANDB_MODE']='disabled';(root/'config').mkdir(exist_ok=True)
 sys.path.insert(0,str(a.yolo.resolve()))
 import torch,cv2,numpy as np
 from PIL import Image
 from utils.augmentations import letterbox
 from utils.general import non_max_suppression,scale_boxes
 torch.set_num_threads(4);torch.set_num_interop_threads(1);cv2.setNumThreads(0)
 cp=torch.load(a.weights,map_location='cpu');model=(cp.get('ema') or cp['model']).float().eval();assert model.model[-1].nc==5
 audit=json.loads((root/'audit.json').read_text(encoding='utf8'));rows=[r for r in audit['images'] if r.get('id')]
 rows.sort(key=lambda r:r['id']);result=[]
 with torch.inference_mode():
  for i,r in enumerate(rows):
   im=Image.open(r['image_path']).convert('RGB');rgb=np.array(im);h,w=rgb.shape[:2]
   canvas=letterbox(rgb,640,auto=False)[0];x=torch.from_numpy(np.ascontiguousarray(canvas.transpose(2,0,1))).float()[None]/255
   pred=non_max_suppression(model(x)[0],.12,.45,multi_label=False,max_det=32)[0]
   if len(pred):pred[:,:4]=scale_boxes(x.shape[2:],pred[:,:4],rgb.shape)
   pw,ph=r['preview_size'];boxes=[]
   for b in r['historical_box_candidates']:
    c,cx,cy,bw,bh=b;boxes.append({'category':int(c),'xyxy':[(cx-bw/2)*pw,(cy-bh/2)*ph,(cx+bw/2)*pw,(cy+bh/2)*ph],'origin':'historical_reviewed_box'})
   for x1,y1,x2,y2,score,c in pred.tolist():
    boxes.append({'category':int(c),'xyxy':[x1/w*pw,y1/h*ph,x2/w*pw,y2/h*ph],'score':score,'origin':'006_prediction_640_REVIEW_ONLY'})
   r['proposed_boxes']=boxes;r['review_status']='UNREVIEWED';result.append(r)
   if (i+1)%25==0:print('PROPOSALS',i+1,len(rows),flush=True)
 data={'status':'UNREVIEWED_NO_LABELS','checkpoint_sha256':hashlib.sha256(a.weights.read_bytes()).hexdigest(),'coordinate_space':'preview_xyxy','images':result}
 draft.write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf8');render(root,result)
 print('READY_FOR_REVIEW',len(result),math.ceil(len(result)/12),flush=True)
if __name__=='__main__':main()
