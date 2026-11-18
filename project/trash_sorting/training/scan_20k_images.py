"""Decode/hash public source TRAIN images and flag palms for exclusion, not labeling.

Source annotations remain source annotations. A negative palm screen is not proof
that all hands were annotated. Test photos and labels are never opened here.
"""
import argparse, concurrent.futures, hashlib, json, sys, threading, time
from pathlib import Path
import numpy as np
from PIL import Image
from scipy.fft import dctn
import cv2

local=threading.local()
def main():
 p=argparse.ArgumentParser();p.add_argument('--root',type=Path,required=True);p.add_argument('--source',action='append',required=True);a=p.parse_args()
 root=a.root.resolve();dest=root/'image_scan';dest.mkdir(exist_ok=True)
 models=root/'screening_models';sys.path.insert(0,str(models));from mp_palmdet import MPPalmDet
 cv2.setNumThreads(1)
 for source in a.source:
  rows=json.loads((root/'audits'/source/'inventory.json').read_text(encoding='utf8'))
  out=dest/(source+'.jsonl');done={}
  if out.exists():
   for line in out.read_text(encoding='utf8').splitlines():
    r=json.loads(line);done[r['id']]=r
  todo=[r for r in rows if r['id'] not in done];start=time.time()
  def scan(row):
   try:
    path=Path(row['path']);body=path.read_bytes()
    with Image.open(path) as im:
     if im.getexif().get(274,1)!=1:raise ValueError('EXIF orientation requires explicit box transform')
     rgb=im.convert('RGB');w,h=rgb.size;arr=np.array(rgb)
     pix=hashlib.sha256(arr.tobytes()+str((w,h)).encode()).hexdigest()
     freq=dctn(np.array(rgb.resize((32,32)).convert('L'),dtype=float),norm='ortho')[:8,:8].flatten()
     ph=int(''.join('1' if v>np.median(freq[1:]) else '0' for v in freq),2)
    if not hasattr(local,'palm'):local.palm=MPPalmDet(str(models/'palm_detection_mediapipe_2023feb.onnx'),scoreThreshold=.35)
    # Full-frame and optional tiles catch smaller hands without generating labels.
    detections=local.palm.infer(cv2.cvtColor(arr,cv2.COLOR_RGB2BGR))
    return dict(id=row['id'],width=w,height=h,image_sha256=hashlib.sha256(body).hexdigest(),sha256_pixels=pix,phash=ph,
                palm_count=len(detections),palm_max_score=float(detections[:,-1].max()) if len(detections) else 0.,
                screen='PUBLIC_TRAIN_ONLY_NO_PSEUDO_LABELS')
   except Exception as e:return dict(id=row['id'],error=repr(e))
  with concurrent.futures.ThreadPoolExecutor(4) as pool,out.open('a',encoding='utf8') as f:
   for i,r in enumerate(pool.map(scan,todo)):
    f.write(json.dumps(r)+'\n');f.flush()
    if (i+1)%200==0:print(source,i+1,'/',len(todo),'seconds',round(time.time()-start),flush=True)
  print(source,'COMPLETE',len(rows),flush=True)
 (dest/'screen_model_identity.json').write_text(json.dumps({p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in models.iterdir() if p.is_file()},indent=2))
if __name__=='__main__':main()
