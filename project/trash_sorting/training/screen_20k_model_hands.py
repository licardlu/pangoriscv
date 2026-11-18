"""Flag unlabelled hands in public TRAIN candidates; no labels are produced."""
import argparse,hashlib,json,os,sys,time,types
from pathlib import Path
import numpy as np
from PIL import Image
def main():
 p=argparse.ArgumentParser();p.add_argument('--root',type=Path,required=True);p.add_argument('--weights',type=Path,required=True);p.add_argument('--yolo',type=Path,required=True);a=p.parse_args();root=a.root.resolve()
 config=root/'screen_yolo_config';config.mkdir(exist_ok=True)
 os.environ['YOLOV5_CONFIG_DIR']=str(config)
 os.environ['YOLOv5_AUTOINSTALL']='false';os.environ['WANDB_MODE']='disabled';sys.path.insert(0,str(a.yolo.resolve()))
 import torch,cv2
 import models.common,models.yolo,models.experimental
 from utils.general import non_max_suppression
 from utils.augmentations import letterbox
 pkg=types.ModuleType('yolov5');pkg.models=types.ModuleType('yolov5.models');sys.modules['yolov5']=pkg;sys.modules['yolov5.models']=pkg.models
 for n in ['common','yolo','experimental']:sys.modules['yolov5.models.'+n]=sys.modules['models.'+n]
 torch.set_num_threads(4);torch.set_num_interop_threads(1);cv2.setNumThreads(0)
 cp=torch.load(a.weights,map_location='cpu');model=(cp.get('ema') or cp['model']).float().eval();assert model.model[-1].nc==5
 rows=json.loads((root/'eligible_candidates.json').read_text());out=root/'teacher_hand_screen.jsonl';done={}
 if out.exists():done={r['id']:r for r in map(json.loads,out.read_text().splitlines())}
 rows=[r for r in rows if r['id'] not in done];start=time.time()
 with torch.inference_mode(),out.open('a',encoding='utf8') as f:
  for i in range(0,len(rows),32):
   batch=rows[i:i+32];images=[]
   for r in batch:
    with Image.open(r['path']) as im:arr=np.array(im.convert('RGB'))
    images.append(letterbox(arr,320,auto=False)[0])
   x=torch.from_numpy(np.ascontiguousarray(np.stack(images).transpose(0,3,1,2))).float()/255
   pred=non_max_suppression(model(x)[0],.15,.45,multi_label=False,max_det=32)
   for r,prediction in zip(batch,pred):
    hands=prediction[prediction[:,5]==4]
    f.write(json.dumps(dict(id=r['id'],hand_count=len(hands),max_conf=float(hands[:,4].max()) if len(hands) else 0.))+'\n')
   f.flush()
   if i%320==0:print('hand screen',i+len(batch),'/',len(rows),'seconds',round(time.time()-start),flush=True)
 (root/'teacher_hand_screen_identity.json').write_text(json.dumps(dict(checkpoint_sha256=hashlib.sha256(a.weights.read_bytes()).hexdigest(),confidence=.15,scope='Exclusion proposals only. No pseudo labels or validation/test use.'),indent=2))
if __name__=='__main__':main()
