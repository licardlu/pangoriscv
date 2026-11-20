"""Verify native-five-class teacher on actual training photos before joint fitting."""
import argparse
import copy
import hashlib
import json
import os
from pathlib import Path
import sys


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for arg in ('yolo','weights','manifest','out'):
        p.add_argument('--'+arg,type=Path,required=True)
    p.add_argument('--freeze',type=int,default=10)
    p.add_argument('--waste-hand-margin',type=float,default=0.)
    p.add_argument('--teacher-background-strength',type=float,default=0.)
    a=p.parse_args();a.out.mkdir(parents=True,exist_ok=False)
    os.environ['YOLOV5_CONFIG_DIR']=str(a.out/'config')
    os.environ['YOLOv5_AUTOINSTALL']='false'
    sys.path.insert(0,str(a.yolo.resolve()))
    import cv2
    import numpy as np
    import torch
    import types
    import models.common,models.yolo,models.experimental
    package=types.ModuleType('yolov5');package.models=types.ModuleType('yolov5.models')
    sys.modules['yolov5']=package;sys.modules['yolov5.models']=package.models
    for name in ('common','yolo','experimental'):
        sys.modules['yolov5.models.'+name]=sys.modules['models.'+name]
    from PIL import Image,ImageOps
    from utils.augmentations import letterbox
    from utils.loss import ComputeLoss
    from disjoint_hand_loss import disjoint_loss_class
    from hard_negative_objectness import hard_negative_loss_class
    from teacher_preservation import PreservationLoss
    torch.set_num_threads(4);torch.set_num_interop_threads(1);cv2.setNumThreads(0)
    torch.manual_seed(20261111)
    cp=torch.load(a.weights,map_location='cpu')
    teacher=(cp.get('ema') or cp['model']).float().eval()
    assert teacher.model[-1].nc==5
    student=copy.deepcopy(teacher)
    for index,block in enumerate(student.model):
        for param in block.parameters():param.requires_grad_(index>=a.freeze)
    # Keep BN deterministic during the arithmetic preflight; real training
    # freezes only blocks0..9 and records its own actual optimization stats.
    student.eval()
    unique={}
    for row in json.loads(a.manifest.read_text(encoding='utf8')):
        if row['split']=='train':unique[row['image_sha256']]=row
    groups=[[r for r in unique.values() if any(int(b[0])==c for b in r['boxes'])] for c in range(5)]
    selected={}
    for group in groups:
        for row in sorted(group,key=lambda r:r['prepared_image'])[:6]:selected[row['image_sha256']]=row
    images=[];targets=[]
    for index,row in enumerate(selected.values()):
        assert row['split']=='train'
        path=Path(row['prepared_image'])
        assert hashlib.sha256(path.read_bytes()).hexdigest()==row['image_sha256']
        with Image.open(path) as im:rgb=np.array(ImageOps.exif_transpose(im).convert('RGB'))
        h,w=rgb.shape[:2];canvas,ratio,pad=letterbox(rgb,(320,320),auto=False)
        images.append(torch.from_numpy(canvas.transpose(2,0,1).copy()).float()/255.)
        for c,cx,cy,bw,bh in row['boxes']:
            targets.append([index,c,(cx*w*ratio[0]+pad[0])/320,(cy*h*ratio[1]+pad[1])/320,
                            bw*w*ratio[0]/320,bh*h*ratio[1]/320])
    images=torch.stack(images);targets=torch.tensor(targets,dtype=torch.float32).reshape(-1,6)
    # Train() returns raw predictions; keep each BN in eval to match the
    # identical teacher for the initial exact-state/loss check.
    student.train()
    for module in student.modules():
        if isinstance(module,torch.nn.BatchNorm2d):module.eval()
    teacher_before={k:v.clone() for k,v in teacher.state_dict().items()}
    frozen_before={k:v.clone() for k,v in student.state_dict().items() if int(k.split('.')[1])<a.freeze}
    first_conv_before=student.model[0].conv.weight.detach().clone()
    bn_before={k:v.clone() for k,v in student.state_dict().items() if 'running_' in k or 'num_batches_tracked' in k}
    tracked=[];hard=[]
    base=hard_negative_loss_class(ComputeLoss,hard,strength=.02)
    margin_losses=[]
    if a.waste_hand_margin:
        from waste_hand_margin import waste_hand_loss_class
        base=waste_hand_loss_class(base,margin_losses,strength=a.waste_hand_margin)
    base=disjoint_loss_class(base,tracked)
    loss=PreservationLoss(base(student),student,teacher,5.,background_strength=a.teacher_background_strength)
    parameters=[v for v in student.parameters() if v.requires_grad]
    optimizer=torch.optim.AdamW(parameters,lr=3e-5)
    # Use small chunks for CPU efficiency without a persistent feature cache.
    before_stats=[];after_stats=[]
    for step in range(2):
        optimizer.zero_grad();total=0.
        for start in range(0,len(images),8):
            stop=min(start+8,len(images));mask=(targets[:,0]>=start)&(targets[:,0]<stop)
            truth=targets[mask].clone();truth[:,0]-=start
            prediction=student(images[start:stop])
            value,_=loss(prediction,truth,images=images[start:stop])
            assert torch.isfinite(value).all();value.backward();total+=float(value.detach())
        assert any(v.grad is not None and bool(v.grad.abs().sum()>0) for v in parameters)
        assert all(v.grad is None or bool(torch.isfinite(v.grad).all()) for v in parameters)
        assert all(v.grad is None for v in teacher.parameters())
        if a.freeze==0:
            assert student.model[0].conv.weight.grad is not None and bool(student.model[0].conv.weight.grad.abs().sum()>0)
            assert all(v.requires_grad for v in student.parameters())
        stats=loss.take_stats()
        assert stats['matched_anchors_by_class'].get('2',0)>0, 'Battery preservation never exercised'
        if step==0:
            assert stats['mean_preservation_loss']<1e-10,stats
            before_stats=stats
        else:
            assert stats['mean_preservation_loss']>0,stats
            after_stats=stats
        optimizer.step()
    assert all(torch.equal(v,teacher.state_dict()[k]) for k,v in teacher_before.items())
    assert all(torch.equal(v,student.state_dict()[k]) for k,v in frozen_before.items())
    assert all(torch.equal(v,student.state_dict()[k]) for k,v in bn_before.items())
    if a.freeze==0:assert not torch.equal(first_conv_before,student.model[0].conv.weight)
    conflict=tracked[0].take_assignment_stats();assert conflict['training_batches_with_hand']>0
    margin_stats=margin_losses[0].take_margin_stats() if margin_losses else None
    if margin_stats:
        assert margin_stats['training_batches']>0
        assert all(margin_stats['waste_anchors_by_class'].get(str(c),0)>0 for c in range(4))
    result=dict(status='PASS_ACTUAL_TRAIN_ONLY_NATIVE_TEACHER',training_images=len(images),
                initial=before_stats,after_update=after_stats,disjoint_stats=conflict,
                teacher_frozen=True,frozen_blocks_unchanged=True,validation_or_test_read=False,
                weights_saved=False,script_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                freeze=a.freeze,bn_running_statistics_unchanged=True,waste_hand_margin=margin_stats,
                teacher_background_strength=a.teacher_background_strength,
                trainable_parameters=sum(v.numel() for v in student.parameters() if v.requires_grad),
                all_parameters_trainable=all(v.requires_grad for v in student.parameters()),
                selected_train_images=[dict(path=r['prepared_image'],sha256=r['image_sha256'],source=r['source']) for r in selected.values()])
    (a.out/'result.json').write_text(json.dumps(result,indent=2),encoding='utf8')
    print(json.dumps({k:v for k,v in result.items() if k!='selected_train_images'}),flush=True)


if __name__=='__main__':main()
