"""Separate hand localization from waste accuracy and real C target selection."""
import argparse
from collections import Counter, defaultdict
import ctypes as C
import json
import os
from pathlib import Path
import sys
import types
import numpy as np
from PIL import Image,ImageOps
from evaluate_crop_diagnostic import ROOT,Box,Target,sha,save,iou
from evaluate_quantized_hand_policy import match_hands


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--checkpoint',type=Path,required=True);p.add_argument('--expected-sha256',required=True)
    p.add_argument('--out',type=Path,required=True);p.add_argument('--occupancy',action='store_true')
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
    base_path=ROOT/'project/trash_sorting/training/candidates/four_bins_20261111/four_bins_yolov5n_320.pt'
    assert sha(base_path)=='8014832f2bc87081c9a7adad363d5590c13ffc6b4c8ff6700f289553b1f575e0'
    def load(path):
        cp=torch.load(path,map_location='cpu');return (cp.get('ema') or cp['model']).float().eval()
    base,hand=load(base_path),load(a.checkpoint)
    assert base.model[-1].nc==4 and hand.model[-1].nc==(2 if a.occupancy else 1)
    production=ROOT/'build/trash_crop_diagnostic_20261113_079'
    contract=json.loads((production/'contract.json').read_text(encoding='utf8'))
    for n,v in contract['c_headers'].items():assert sha(ROOT/'project/trash_sorting/source/yolo/software'/n)==v
    lib=C.CDLL(str(production/'policy.dll'))
    lib.policy_select_contact.argtypes=[C.POINTER(Box),C.c_uint32,C.POINTER(Box),C.c_uint32,C.c_float,C.c_float]
    lib.policy_select_contact.restype=Target
    lib.policy_select.argtypes=[C.POINTER(Box),C.c_uint32,C.c_uint32,C.c_uint32,C.c_float,C.c_float];lib.policy_select.restype=Target
    fixture=ROOT/'build/trash_hand_numeric_fixture_20261113_048/inventory.json'
    rows=json.loads(fixture.read_text(encoding='utf8'))
    counters=defaultdict(Counter);groups=defaultdict(Counter);decisions=[];macs=Counter()
    def hook_for(name):
        def hook(module,args,value):
            macs[name]+=value.shape[-1]*value.shape[-2]*module.out_channels*(module.in_channels//module.groups)*module.kernel_size[0]*module.kernel_size[1]
        return hook
    def infer(model,image,size):
        rgb=np.asarray(image);network=letterbox(rgb,(size,size),auto=False,stride=32)[0]
        tensor=torch.from_numpy(np.ascontiguousarray(network.transpose(2,0,1))).float()[None]/255
        raw=model(tensor)[0]
        pred=non_max_suppression(raw.clone(),.25,.45,multi_label=False,max_det=32)[0]
        if len(pred):pred[:,:4]=scale_boxes(tensor.shape[2:],pred[:,:4],rgb.shape).round()
        return pred.cpu().numpy().tolist(),tensor,raw
    with torch.no_grad():
        for idx,row in enumerate(rows):
            assert sha(row['path'])==row['sha256']
            with Image.open(row['path']) as im:image=ImageOps.exif_transpose(im).convert('RGB')
            handles=[]
            if idx==0:
                for name,model in [('waste320',base),('hand128',hand)]:
                    handles.extend(m.register_forward_hook(hook_for(name)) for m in model.modules() if isinstance(m,torch.nn.Conv2d))
            objects,base_tensor,original_raw=infer(base,image,320)
            hands,_,_=infer(hand,image,128)
            for handle in handles:handle.remove()
            assert torch.equal(original_raw,base(base_tensor)[0]),'Independent hand model altered original waste output'
            visible=hands
            occupied=[h for h in hands if not a.occupancy or int(h[5])==0]
            empty=[h for h in hands if a.occupancy and int(h[5])==1]
            ob=(Box*len(objects))(*[Box(*b[:5],int(b[5])) for b in objects]);hb=(Box*len(occupied))(*[Box(*b[:5],4) for b in occupied])
            t=lib.policy_select_contact(ob,len(ob),hb,len(hb),*image.size)
            # Empty hand is still a detected hand: it cannot trigger no-hand fallback.
            chosen=t.object_index if occupied or not empty else -1
            original=lib.policy_select(ob,len(ob),4,0xffffffff,*image.size).object_index
            selected=objects[chosen] if chosen>=0 else None;baseline=objects[original] if original>=0 else None
            tp=match_hands(visible,row['reviewed_hand_boxes'])
            held=row.get('held_object');subject=[v*d for v,d in zip(held['xyxy'],[*image.size,*image.size])] if held else None
            both=bool(selected and iou(selected,subject)>=.5 and int(selected[5])==held['bin']) if held else None
            oldboth=bool(baseline and iou(baseline,subject)>=.5 and int(baseline[5])==held['bin']) if held else None
            detail=dict(key=row['key'],source=row['source'],group=row['group'],hands=hands,occupied=occupied,empty=empty,
                        objects=objects,selected=selected,baseline=baseline,hand_tp=tp,hand_gt=len(row['reviewed_hand_boxes']),
                        selected_both_correct=both,baseline_both_correct=oldboth)
            decisions.append(detail)
            for c in (counters[row['source']],groups[str(row['group'])]):
                c['n']+=1;c['hand_TP']+=tp;c['hand_FP']+=len(visible)-tp;c['hand_GT']+=len(row['reviewed_hand_boxes'])
                c['hand_seen']+=bool(visible);c['hand_correctly_localized_image']+=tp>0
                c['selected_any']+=chosen>=0;c['baseline_selected_any']+=original>=0
                if held:c['selected_both_correct']+=both;c['baseline_both_correct']+=oldboth
                if row['source']=='hagrid_hand_localisation':c['empty_hand_false_selection']+=chosen>=0
            if (idx+1)%20==0:print('INDEPENDENT_HAND '+str(idx+1)+'/'+str(len(rows)),flush=True)
    held=counters['personal_handheld'];nohand=[d for d in decisions if d['source'] in ('sumn2u','codingbear')]
    false_hand=sum(bool(d['hands']) for d in nohand);empty=counters['hagrid_hand_localisation']
    gates=dict(held_hand_localized_at_least_40_of_50=held['hand_correctly_localized_image']>=40,
               nohand_false_hand_at_most_1_of_31=false_hand<=1,
               empty_false_selection_at_most_10_of_29=empty['empty_hand_false_selection']<=10,
               subject_and_bucket_no_worse_than_baseline=held['selected_both_correct']>=held['baseline_both_correct'])
    save(a.out/'predictions.json',decisions)
    save(a.out/'result.json',dict(status='PASS_OFFLINE_GATES' if all(gates.values()) else 'REJECT_OFFLINE_GATES',gates=gates,
         checkpoint_sha256=sha(a.checkpoint),base_checkpoint_sha256=sha(base_path),fixtures_sha256=sha(fixture),
         summaries=dict(counters),physical_groups=dict(groups),nohand_false_hand_images=false_hand,
         nohand_images=len(nohand),conv_macs=dict(macs),extra_conv_mac_ratio=macs['hand128']/macs['waste320'],
         original_waste_output_exact_checks=len(rows),hand_input=128,waste_input=320,occupancy_model=a.occupancy,
         threshold=.25,nms=.45,truth_assisted_selection=False,test_used=False,board_changed=False,
         caveat='CPU float + actual C selection; extra MAC is not measured FPGA latency; no small-battery final-test reuse.'))
    print('INDEPENDENT_HAND_EVALUATION_COMPLETE',flush=True)


if __name__=='__main__':main()
