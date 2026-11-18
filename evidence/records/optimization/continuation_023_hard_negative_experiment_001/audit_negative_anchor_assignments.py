"""Attribute saved train-only false selections to actual YOLO anchor targets.

No fitting or validation access. This explains whether each selected false
anchor receives hand classification/box supervision or only negative objectness.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import sys


def sha(p):
    return hashlib.sha256(Path(p).read_bytes()).hexdigest()


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for k in ('manifest','weights','yolo','diagnostic','out'):
        p.add_argument('--'+k,type=Path,required=True)
    a=p.parse_args(); a.out=a.out.resolve(); a.out.mkdir(parents=True,exist_ok=False)
    previous=json.loads((a.diagnostic/'result.json').read_text(encoding='utf8'))
    assert previous['split']=='train' and not previous['test_images_opened']
    assert sha(a.weights)==previous['reports']['stage4']['checkpoint_sha256']
    assert sha(a.manifest)==previous['manifest_sha256']
    saved=json.loads((a.diagnostic/'decisions.json').read_text(encoding='utf8'))['stage4']
    cases=[r for r in saved if r['selected']]
    train={r['image_sha256']:r for r in json.loads(a.manifest.read_text(encoding='utf8')) if r['split']=='train'}
    os.environ['YOLOv5_AUTOINSTALL']='false'
    os.environ['YOLOV5_CONFIG_DIR']=str(a.out/'config')
    os.environ['OMP_NUM_THREADS']='2'
    os.environ['MKL_NUM_THREADS']='2'
    sys.path.insert(0,str(a.yolo.resolve()))
    import cv2
    import numpy as np
    import torch
    from utils.augmentations import letterbox
    from utils.general import scale_boxes,xywh2xyxy
    from utils.loss import ComputeLoss
    torch.set_num_threads(2);torch.set_num_interop_threads(1);cv2.setNumThreads(0)
    cp=torch.load(a.weights,map_location='cpu')
    model=(cp.get('ema') or cp['model']).float().eval()
    loss=ComputeLoss(model)
    result=[]
    with torch.inference_mode():
        for case in cases:
            r=train[case['image_sha256']]
            assert not any(int(b[0])<4 for b in r['boxes'])
            path=Path(r['prepared_image']);assert sha(path)==case['image_sha256']
            im=cv2.imdecode(np.fromfile(path,dtype=np.uint8),cv2.IMREAD_COLOR)
            h0,w0=im.shape[:2];ratio=320/max(h0,w0)
            if ratio!=1:
                im=cv2.resize(im,(int(w0*ratio),int(h0*ratio)),interpolation=cv2.INTER_LINEAR if ratio>1 else cv2.INTER_AREA)
            h,w=im.shape[:2];im,_,pad=letterbox(im,320,auto=False,scaleup=False)
            x=torch.from_numpy(np.ascontiguousarray(im.transpose(2,0,1)[::-1])).float()[None]/255
            decoded,raw=model(x)
            boxes=xywh2xyxy(decoded[0,:,:4].clone())
            scale_boxes(x.shape[2:],boxes,(h0,w0),((h/h0,w/w0),pad))
            value,category=decoded[0,:,5:].max(-1)
            scores=decoded[0,:,4]*value
            chosen=case['selected']
            distance=(boxes-torch.tensor(chosen[:4])).abs().amax(-1)+(scores-chosen[4]).abs()*1000
            distance[category!=int(chosen[5])]=float('inf')
            index=int(distance.argmin());assert float(distance[index])<.002
            local=index
            for level,pred in enumerate(raw):
                _,na,ny,nx,_=pred.shape
                if local<na*ny*nx:break
                local-=na*ny*nx
            else:raise ValueError('No decoded anchor')
            anchor=local//(ny*nx);gy=(local//nx)%ny;gx=local%nx
            targets=torch.tensor([[0,int(c),(cx*w+pad[0])/320,(cy*h+pad[1])/320,bw*w/320,bh*h/320]
                                  for c,cx,cy,bw,bh in r['boxes']],dtype=torch.float32).reshape(-1,6)
            classes,_,indices,_=loss.build_targets(raw,targets)
            batch,aa,yy,xx=indices[level]
            assigned=classes[level][(batch==0)&(aa==anchor)&(yy==gy)&(xx==gx)].tolist()
            result.append(dict(path=str(path),image_sha256=case['image_sha256'],source=r['source'],
                               level=level,stride=float(model.stride[level]),anchor=anchor,grid_xy=[gx,gy],
                               decoded_index=index,selected_class=int(category[index]),score=float(scores[index]),
                               objectness=float(decoded[0,index,4]),class_probabilities=decoded[0,index,5:].tolist(),
                               target_classes=assigned,
                               supervision='positive hand objectness/box/class' if assigned else 'negative objectness only'))
    report=dict(status='TRAIN_FALSE_ANCHOR_ATTRIBUTION_COMPLETED',split='train',
                scope='Original non-augmented train images only; does not measure actual augmented training history',
                weights_sha256=sha(a.weights),manifest_sha256=sha(a.manifest),
                input_decisions_sha256=sha(a.diagnostic/'decisions.json'),script_sha256=sha(__file__),
                upstream_loss_sha256=sha(a.yolo/'utils/loss.py'),cases=result,
                training_performed=False,val_images_opened=False,test_images_opened=False,hardware_accessed=False)
    (a.out/'result.json').write_text(json.dumps(report,indent=2),encoding='utf8')
    print(json.dumps(result,indent=2),flush=True)
    print('TEST_PASS train-only actual anchor attribution',flush=True)


if __name__=='__main__':main()
