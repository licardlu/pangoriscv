"""Measure false-positive frames on a fixed reviewed hand-only split.

This is CPU floating-point inference, not a board-camera accuracy measurement.
Confidence/NMS are fixed in advance to match the four-bin deployment policy.
"""
import argparse
from collections import Counter
import hashlib
import json
import os
from pathlib import Path
import sys


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--data',type=Path,required=True)
    p.add_argument('--weights',type=Path,required=True)
    p.add_argument('--yolo',type=Path,required=True)
    p.add_argument('--split',choices=('val','test'),default='val')
    p.add_argument('--out',type=Path,required=True)
    a=p.parse_args()
    a.out.mkdir(parents=True,exist_ok=False)
    os.environ['YOLOv5_AUTOINSTALL']='false'
    os.environ['WANDB_MODE']='disabled'
    os.environ['YOLOV5_CONFIG_DIR']=str(a.out/'config')
    sys.path.insert(0,str(a.yolo.resolve()))
    import cv2
    import numpy as np
    import torch
    from utils.augmentations import letterbox
    from utils.general import non_max_suppression
    torch.set_num_threads(2)
    torch.set_num_interop_threads(1)
    cv2.setNumThreads(0)
    checkpoint=torch.load(a.weights,map_location='cpu')
    model=(checkpoint.get('ema') or checkpoint['model']).float().eval()
    if model.model[-1].nc!=4:
        raise ValueError('Expected four-bin model')
    records=json.loads((a.data/'hand_manifest.json').read_text())
    records=[r for r in records if r['split']==a.split]
    if not records:
        raise ValueError('Empty reviewed evaluation split')
    decisions=[]
    with torch.inference_mode():
        for r in records:
            path=Path(r['prepared_image'])
            if hashlib.sha256(path.read_bytes()).hexdigest()!=r['sha256']:
                raise ValueError('Reviewed crop changed')
            im=cv2.imdecode(np.fromfile(path,dtype=np.uint8),cv2.IMREAD_COLOR)
            im=letterbox(im,320,auto=False)[0][:,:,::-1].transpose(2,0,1)
            x=torch.from_numpy(np.ascontiguousarray(im)).float().unsqueeze(0)/255.
            pred=non_max_suppression(model(x)[0],.25,.45,multi_label=False,max_det=32)[0]
            decisions.append(dict(review_index=r['review_index'],user_id=r['user_id'],
                image_sha256=r['sha256'],detections=pred.cpu().tolist()))
    false=sum(bool(r['detections']) for r in decisions)
    counts=Counter(int(d[5]) for r in decisions for d in r['detections'])
    report=dict(split=a.split,images=len(decisions),false_positive_frames=false,
        false_positive_frame_rate=false/len(decisions),detections_by_class=dict(counts),
        confidence=.25,nms_iou=.45,multi_label=False,input_size=320,
        model_sha256=hashlib.sha256(a.weights.read_bytes()).hexdigest(),
        hand_manifest_sha256=hashlib.sha256((a.data/'hand_manifest.json').read_bytes()).hexdigest(),
        runtime='CPU float; not INT8 or FPGA; face-covering hand-crop subset',
        decisions=decisions)
    (a.out/'result.json').write_text(json.dumps(report,indent=2),encoding='utf8')
    print(json.dumps({k:v for k,v in report.items() if k!='decisions'}),flush=True)


if __name__=='__main__':
    main()
