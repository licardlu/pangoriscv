"""Score a four-bin candidate on the frozen 079 ROI and 080 context diagnostics."""
import argparse
from collections import Counter, defaultdict
import ctypes as C
import json
import os
from pathlib import Path
import sys
import types

import numpy as np
from PIL import Image, ImageOps
from evaluate_crop_diagnostic import ROOT, Box, Target, MODES, remap, iou, sha, save


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--checkpoint',type=Path,required=True)
    p.add_argument('--expected-sha256',required=True)
    p.add_argument('--source',type=Path,required=True)
    p.add_argument('--out',type=Path,required=True)
    a=p.parse_args();a.out=a.out.resolve();a.out.mkdir(parents=True,exist_ok=False)
    assert sha(a.checkpoint)==a.expected_sha256
    (a.out/'config').mkdir();os.environ['YOLOV5_CONFIG_DIR']=str(a.out/'config');os.environ['YOLOv5_AUTOINSTALL']='false'
    sys.path.insert(0,str(ROOT/'build/trash_retrain_research_20261111_001/yolov5-7.0'))
    import torch
    import models.common,models.yolo,models.experimental
    pkg=types.ModuleType('yolov5');pkg.models=types.ModuleType('yolov5.models')
    sys.modules['yolov5'],sys.modules['yolov5.models']=pkg,pkg.models
    for n in ('common','yolo','experimental'):sys.modules['yolov5.models.'+n]=sys.modules['models.'+n]
    from utils.augmentations import letterbox
    from utils.general import non_max_suppression,scale_boxes
    torch.set_num_threads(4);torch.set_num_interop_threads(1)
    cp=torch.load(a.checkpoint,map_location='cpu');model=(cp.get('ema') or cp['model']).float().eval()
    assert model.model[-1].nc==4
    lib=C.CDLL(str(a.source.resolve()/'policy.dll'))
    lib.policy_select.argtypes=[C.POINTER(Box),C.c_uint32,C.c_uint32,C.c_uint32,C.c_float,C.c_float];lib.policy_select.restype=Target
    baseline=json.loads((a.source/'predictions.json').read_text(encoding='utf8'))
    contract=json.loads((a.source/'contract.json').read_text(encoding='utf8'))
    for n,v in contract['c_headers'].items():assert sha(ROOT/'project/trash_sorting/source/yolo/software'/n)==v
    records=[];summaries=defaultdict(Counter);groups=defaultdict(Counter);paired=defaultdict(Counter)
    with torch.no_grad():
        for idx,row in enumerate(baseline):
            assert sha(row['path'])==row['sha256']
            with Image.open(row['path']) as im:image=ImageOps.exif_transpose(im).convert('RGB')
            w,h=image.size;subject=row['subject'];expected=row['expected_model_class'];modes={};cache={}
            for mode in MODES+(('mask_same_scale',) if subject else ()):
                roi=row['modes'][mode]['roi'] if mode in MODES else [0,0,w,h]
                tag=(tuple(roi),mode=='mask_same_scale')
                if tag not in cache:
                    if mode=='mask_same_scale':
                        keep=row['modes']['object_1p5_oracle']['roi'];crop_image=Image.new('RGB',image.size,(114,114,114));crop_image.paste(image.crop(keep),(keep[0],keep[1]))
                    else:crop_image=image.crop(roi)
                    crop=np.asarray(crop_image);network=letterbox(crop,(320,320),auto=False,stride=32)[0]
                    tensor=torch.from_numpy(np.ascontiguousarray(network.transpose(2,0,1))).float()[None]/255
                    pred=non_max_suppression(model(tensor)[0],.25,.45,multi_label=False,max_det=32)[0]
                    if len(pred):pred[:,:4]=scale_boxes(tensor.shape[2:],pred[:,:4],crop.shape).round()
                    boxes=remap(pred.cpu().numpy(),roi).tolist()
                    ob=(Box*len(boxes))(*[Box(*b[:5],int(b[5])) for b in boxes])
                    chosen=lib.policy_select(ob,len(boxes),4,0xffffffff,w,h).object_index
                    selected=boxes[chosen] if chosen>=0 else None
                    siou=iou(selected[:4],subject) if subject and selected else 0 if subject else None
                    both=bool(selected and siou>=.5 and int(selected[5])==expected) if subject else None
                    cache[tag]=dict(roi=roi,detections=boxes,selected=selected,selected_index=chosen,
                                    selected_subject_iou=siou,selected_both_correct=both,
                                    selected_class_correct=bool(selected and int(selected[5])==expected) if subject else None,
                                    raw_subject_detected=any(iou(b[:4],subject)>=.5 for b in boxes) if subject else None)
                detail=cache[tag];modes[mode]=detail
                for counter in (summaries[row['cohort']+'/'+mode],groups[str(row['group'])+'/'+mode]):
                    counter['n']+=1;counter['selected_any']+=detail['selected'] is not None
                    if subject:
                        for k in ('selected_both_correct','selected_class_correct','raw_subject_detected'):counter[k]+=detail[k]
                        counter['selected_subject_correct']+=detail['selected_subject_iou']>=.5
                if mode in MODES and subject:
                    old=row['modes'][mode]['selected_both_correct'];new=detail['selected_both_correct']
                    paired[row['cohort']+'/'+mode]['gain' if new and not old else 'loss' if old and not new else 'both_correct' if old else 'both_wrong']+=1
            records.append(dict(key=row['key'],cohort=row['cohort'],group=row['group'],modes=modes))
            if (idx+1)%20==0:print('SUBJECT_CANDIDATE '+str(idx+1)+'/'+str(len(baseline)),flush=True)
    save(a.out/'predictions.json',records)
    save(a.out/'result.json',dict(status='COMPLETE_FLOAT_DEVELOPMENT_DIAGNOSTIC',checkpoint_sha256=sha(a.checkpoint),
         source_predictions_sha256=sha(a.source/'predictions.json'),script_sha256=sha(__file__),
         summaries=dict(summaries),physical_groups=dict(groups),paired_vs_original=dict(paired),
         truth_assisted_crop_modes=True,whole_mode_truth_assisted=False,held_out_test_used=False,board_changed=False))
    print('SUBJECT_CANDIDATE_COMPLETE',flush=True)


if __name__=='__main__':main()
