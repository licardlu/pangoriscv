"""Evaluate learned held-item/empty-hand cues with unchanged original four-bin outputs."""
import argparse
from collections import Counter,defaultdict
import ctypes as C
import json
import os
from pathlib import Path
import sys
import numpy as np
from PIL import Image,ImageOps,ImageDraw
from evaluate_crop_diagnostic import ROOT,Box,Target,COLORS,sha,save,iou


class CueTarget(C.Structure):
    _fields_=[('object_index',C.c_int),('cue_index',C.c_int),('cue_seen',C.c_uint32),('empty_hand',C.c_uint32)]


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--checkpoint',type=Path,required=True)
    p.add_argument('--expected-sha256',required=True);p.add_argument('--prepared',type=Path,required=True)
    p.add_argument('--out',type=Path,required=True);a=p.parse_args();a.out=a.out.resolve();a.out.mkdir(parents=True,exist_ok=False)
    assert sha(a.checkpoint)==a.expected_sha256
    (a.out/'config').mkdir();os.environ['YOLOV5_CONFIG_DIR']=str(a.out/'config');os.environ['YOLOv5_AUTOINSTALL']='false'
    sys.path.insert(0,str(ROOT/'build/trash_retrain_research_20261111_001/yolov5-7.0'))
    import torch
    from utils.augmentations import letterbox
    from utils.general import non_max_suppression,scale_boxes
    torch.set_num_threads(4);torch.set_num_interop_threads(1)
    base_path=ROOT/'project/trash_sorting/training/candidates/four_bins_20261111/four_bins_yolov5n_320.pt'
    assert sha(base_path)=='8014832f2bc87081c9a7adad363d5590c13ffc6b4c8ff6700f289553b1f575e0'
    # Original checkpoint uses a historical pickle namespace.
    import types,models.common,models.yolo,models.experimental
    pkg=types.ModuleType('yolov5');pkg.models=types.ModuleType('yolov5.models');sys.modules['yolov5']=pkg;sys.modules['yolov5.models']=pkg.models
    for n in ('common','yolo','experimental'):sys.modules['yolov5.models.'+n]=sys.modules['models.'+n]
    def load(path):
        cp=torch.load(path,map_location='cpu');return (cp.get('ema') or cp['model']).float().eval()
    base,cue_model=load(base_path),load(a.checkpoint);assert base.model[-1].nc==4 and cue_model.model[-1].nc==2
    assert [cue_model.names[i] for i in range(2)]==['held_item','empty_hand']
    policy=C.CDLL(str(a.prepared.resolve()/'native/policy.dll'))
    policy.policy_select_cues.argtypes=[C.POINTER(Box),C.c_uint32,C.POINTER(Box),C.c_uint32,C.c_float,C.c_float];policy.policy_select_cues.restype=CueTarget
    original=C.CDLL(str(ROOT/'build/trash_crop_diagnostic_20261113_079/policy.dll'))
    original.policy_select.argtypes=[C.POINTER(Box),C.c_uint32,C.c_uint32,C.c_uint32,C.c_float,C.c_float];original.policy_select.restype=Target
    fixture=ROOT/'build/trash_hand_numeric_fixture_20261113_048/inventory.json';rows=json.loads(fixture.read_text(encoding='utf8'))
    counters=defaultdict(Counter);groups=defaultdict(Counter);records=[];macs=Counter()
    def hook_for(name):
        def hook(m,args,value):macs[name]+=value.shape[-1]*value.shape[-2]*m.out_channels*(m.in_channels//m.groups)*m.kernel_size[0]*m.kernel_size[1]
        return hook
    def infer(model,image,size):
        rgb=np.asarray(image);network=letterbox(rgb,(size,size),auto=False,stride=32)[0]
        tensor=torch.from_numpy(np.ascontiguousarray(network.transpose(2,0,1))).float()[None]/255
        raw=model(tensor)[0];pred=non_max_suppression(raw.clone(),.25,.45,multi_label=False,max_det=32)[0]
        if len(pred):pred[:,:4]=scale_boxes(tensor.shape[2:],pred[:,:4],rgb.shape).round()
        return pred.cpu().numpy().tolist(),tensor,raw
    with torch.no_grad():
        for idx,row in enumerate(rows):
            assert sha(row['path'])==row['sha256']
            with Image.open(row['path']) as im:image=ImageOps.exif_transpose(im).convert('RGB')
            hooks=[]
            if idx==0:
                for name,model in [('waste320',base),('cue128',cue_model)]:hooks.extend(m.register_forward_hook(hook_for(name)) for m in model.modules() if isinstance(m,torch.nn.Conv2d))
            objects,tensor,raw=infer(base,image,320);cues,_,_=infer(cue_model,image,128)
            for hook in hooks:hook.remove()
            assert torch.equal(raw,base(tensor)[0]),'Original waste outputs changed'
            ob=(Box*len(objects))(*[Box(*b[:5],int(b[5])) for b in objects]);cb=(Box*len(cues))(*[Box(*b[:5],int(b[5])) for b in cues])
            t=policy.policy_select_cues(ob,len(ob),cb,len(cb),*image.size);b=original.policy_select(ob,len(ob),4,0xffffffff,*image.size)
            selected=objects[t.object_index] if t.object_index>=0 else None;baseline=objects[b.object_index] if b.object_index>=0 else None
            held=row.get('held_object');subject=[v*d for v,d in zip(held['xyxy'],[*image.size,*image.size])] if held else None
            cohort='held' if held else 'nohand' if row['source'] in ('sumn2u','codingbear') else 'empty' if row['source']=='hagrid_hand_localisation' else 'context_unscored'
            both=bool(selected and iou(selected,subject)>=.5 and int(selected[5])==held['bin']) if held else None
            oldboth=bool(baseline and iou(baseline,subject)>=.5 and int(baseline[5])==held['bin']) if held else None
            localized=any(int(c[5])==0 and iou(c,subject)>=.5 for c in cues) if held else None
            correct_empty=any(int(c[5])==1 and any(iou(c,g)>=.5 for g in row['reviewed_hand_boxes']) for c in cues) if cohort=='empty' else None
            for counter in (counters[cohort],groups[str(row['group'])]):
                counter['n']+=1;counter['cue_seen']+=bool(cues);counter['selected_any']+=selected is not None;counter['baseline_selected_any']+=baseline is not None
                if held:
                    counter['subject_cue_localized']+=localized;counter['selected_both_correct']+=both;counter['baseline_both_correct']+=oldboth
                    counter['wrong_empty_veto']+=bool(t.empty_hand)
                if cohort=='empty':counter['correct_empty_cue']+=correct_empty;counter['false_selection']+=selected is not None
            records.append(dict(key=row['key'],path=row['path'],sha256=row['sha256'],cohort=cohort,group=row['group'],subject=subject,
                                cues=cues,objects=objects,selected=selected,baseline=baseline,selected_both_correct=both,
                                baseline_both_correct=oldboth,subject_cue_localized=localized,empty_veto=bool(t.empty_hand),cue_index=t.cue_index))
            if (idx+1)%20==0:print('INTERACTION_CUES '+str(idx+1)+'/'+str(len(rows)),flush=True)
    gates=dict(nohand_false_cue_at_most_1_of_31=counters['nohand']['cue_seen']<=1,
               empty_false_selection_at_most_10_of_29=counters['empty']['false_selection']<=10,
               subject_and_bucket_no_worse_than_baseline=counters['held']['selected_both_correct']>=counters['held']['baseline_both_correct'])
    save(a.out/'predictions.json',records)
    save(a.out/'result.json',dict(status='PASS_OFFLINE_GATES' if all(gates.values()) else 'REJECT_OFFLINE_GATES',gates=gates,
         checkpoint_sha256=sha(a.checkpoint),base_checkpoint_sha256=sha(base_path),fixture_sha256=sha(fixture),
         cue_policy_sha256=sha(ROOT/'project/trash_sorting/source/yolo/software/yolo_interaction_policy.h'),
         cue_policy_dll_sha256=sha(a.prepared/'native/policy.dll'),summaries=dict(counters),physical_groups=dict(groups),
         conv_macs=dict(macs),extra_conv_mac_ratio=macs['cue128']/macs['waste320'],original_raw_output_exact_checks=len(rows),
         test_used=False,truth_assisted_selection=False,board_changed=False,threshold=.25,nms=.45,match_iou=.25,
         caveat='Development float inference + actual candidate C selection. No quantization, board latency or held-out battery claim.'))
    for start in range(0,len(records),12):
        sheet=Image.new('RGB',(1200,960),'#202020')
        for j,row in enumerate(records[start:start+12]):
            with Image.open(row['path']) as im:image=ImageOps.exif_transpose(im).convert('RGB')
            w,h=image.size;image.thumbnail((300,275));draw=ImageDraw.Draw(image)
            def rectangle(b,color,width):draw.rectangle([b[0]*image.width/w,b[1]*image.height/h,b[2]*image.width/w,b[3]*image.height/h],outline=color,width=width)
            if row['subject']:rectangle(row['subject'],'white',1)
            for c in row['cues']:rectangle(c,'orange',2)
            if row['selected']:rectangle(row['selected'],COLORS[int(row['selected'][5])],3)
            x,y=j%4*300,j//4*320;sheet.paste(image,(x,y+40));sd=ImageDraw.Draw(sheet)
            sd.text((x+2,y+2),row['key'][:35],fill='white');sd.text((x+2,y+17),row['cohort']+' empty='+str(row['empty_veto']),fill='white')
            sd.text((x+2,y+29),'both='+str(row['selected_both_correct'])+' base='+str(row['baseline_both_correct']),fill='white')
        sheet.save(a.out/('visual_%02d.jpg'%(start//12+1)),quality=90)
    print('INTERACTION_CUES_COMPLETE',flush=True)


if __name__=='__main__':main()
