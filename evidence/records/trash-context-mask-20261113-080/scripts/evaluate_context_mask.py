"""Separate removal of distant context from ROI zoom, with fixed subject scale."""
import argparse
from collections import Counter, defaultdict
import ctypes as C
import json
import os
from pathlib import Path
import sys
import types

import numpy as np
from PIL import Image, ImageDraw, ImageOps
from evaluate_crop_diagnostic import ROOT, Box, Target, COLORS, sha, save, iou


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--source', type=Path, required=True)
    p.add_argument('--out', type=Path, required=True)
    a = p.parse_args()
    a.out = a.out.resolve()
    a.out.mkdir(parents=True, exist_ok=False)
    (a.out/'config').mkdir()
    os.environ['YOLOV5_CONFIG_DIR'] = str(a.out/'config')
    os.environ['YOLOv5_AUTOINSTALL'] = 'false'
    sys.path.insert(0,str(ROOT/'build/trash_retrain_research_20261111_001/yolov5-7.0'))
    import torch
    import models.common, models.yolo, models.experimental
    pkg = types.ModuleType('yolov5'); pkg.models = types.ModuleType('yolov5.models')
    sys.modules['yolov5'],sys.modules['yolov5.models'] = pkg,pkg.models
    for n in ('common','yolo','experimental'):
        sys.modules['yolov5.models.'+n] = sys.modules['models.'+n]
    from utils.augmentations import letterbox
    from utils.general import non_max_suppression, scale_boxes
    torch.set_num_threads(4); torch.set_num_interop_threads(1)
    model_path = ROOT/'project/trash_sorting/training/candidates/four_bins_20261111/four_bins_yolov5n_320.pt'
    contract = json.loads((a.source/'contract.json').read_text(encoding='utf8'))
    assert sha(model_path) == contract['checkpoint_sha256']
    cp = torch.load(model_path,map_location='cpu'); model=(cp.get('ema') or cp['model']).float().eval()
    lib = C.CDLL(str(a.source.resolve()/'policy.dll'))
    lib.policy_select.argtypes = [C.POINTER(Box), C.c_uint32, C.c_uint32, C.c_uint32, C.c_float, C.c_float]
    lib.policy_select.restype = Target
    rows = [r for r in json.loads((a.source/'predictions.json').read_text(encoding='utf8')) if r['subject']]
    results = []
    counters, paired = defaultdict(Counter), defaultdict(Counter)
    for idx,row in enumerate(rows):
        assert sha(row['path']) == row['sha256']
        with Image.open(row['path']) as im: original=np.asarray(ImageOps.exif_transpose(im).convert('RGB'))
        roi = row['modes']['object_1p5_oracle']['roi']; x1,y1,x2,y2 = roi
        masked=np.full_like(original,114); masked[y1:y2,x1:x2]=original[y1:y2,x1:x2]
        assert masked.shape == original.shape and np.array_equal(masked[y1:y2,x1:x2],original[y1:y2,x1:x2])
        w,h = row['size']; subject=row['subject']; expected=row['expected_model_class']
        assert x1<=subject[0] and y1<=subject[1] and x2>=subject[2] and y2>=subject[3]
        network=letterbox(masked,(320,320),auto=False,stride=32)[0]
        tensor=torch.from_numpy(np.ascontiguousarray(network.transpose(2,0,1))).float()[None]/255
        with torch.no_grad():pred=non_max_suppression(model(tensor)[0],.25,.45,multi_label=False,max_det=32)[0]
        if len(pred):pred[:,:4]=scale_boxes(tensor.shape[2:],pred[:,:4],masked.shape).round()
        boxes=pred.cpu().numpy().tolist()
        ob=(Box*len(boxes))(*[Box(*b[:5],int(b[5])) for b in boxes])
        chosen=lib.policy_select(ob,len(boxes),4,0xffffffff,w,h).object_index
        selected=boxes[chosen] if chosen>=0 else None
        siou=iou(selected[:4],subject) if selected else 0
        both=bool(selected and int(selected[5])==expected and siou>=.5)
        base=row['modes']['whole']; zoom=row['modes']['object_1p5_oracle']
        detail=dict(key=row['key'],cohort=row['cohort'],group=row['group'],path=row['path'],subject=subject,
                    expected_model_class=expected,kept_roi=roi,kept_area_fraction=(x2-x1)*(y2-y1)/(w*h),
                    dimensions_and_inner_pixels_exact=True,detections=boxes,selected=selected,subject_iou=siou,
                    selected_both_correct=both,whole=base,zoom=zoom)
        results.append(detail)
        c=counters[row['cohort']];c['n']+=1;c['subject_and_bucket_correct']+=both
        c['selected_subject_correct']+=siou>=.5
        c['selected_class_correct']+=bool(selected and int(selected[5])==expected)
        c['selected_class_changed_vs_whole']+=(None if not selected else selected[5])!=(None if not base['selected'] else base['selected'][5])
        b=base['selected_both_correct']; paired[row['cohort']]['gain' if both and not b else 'loss' if b and not both else 'both_correct' if b else 'both_wrong']+=1
        if (idx+1)%20==0:print('CONTEXT_MASK '+str(idx+1)+'/'+str(len(rows)),flush=True)
    save(a.out/'predictions.json',results)
    save(a.out/'result.json',dict(status='PASS_FLOAT_CONTEXT_DIAGNOSTIC',summaries=dict(counters),paired=dict(paired),
         checkpoint_sha256=sha(model_path),source_sha256=sha(a.source/'predictions.json'),script_sha256=sha(__file__),
         truth_assisted=True,held_out_test_used=False,board_changed=False,
         caveat='Constant gray masking is itself a distribution change; not proof of background-only causality.'))
    # Every public case that changes its bucket, ordered by fixed inventory.
    changes=[r for r in results if r['cohort']=='public_hazard_val' and r['whole']['selected_both_correct'] and not r['selected_both_correct']]
    for start in range(0,len(changes),4):
        sheet=Image.new('RGB',(840,1000),'#202020')
        keys=[]
        for j,row in enumerate(changes[start:start+4]):
            with Image.open(row['path']) as im: original=ImageOps.exif_transpose(im).convert('RGB')
            roi=row['kept_roi'];mask=Image.new('RGB',original.size,(114,114,114));mask.paste(original.crop(roi),(roi[0],roi[1]))
            for col,(title,im,sel,offset) in enumerate([('whole',original,row['whole']['selected'],[0,0]),('mask_same_scale',mask,row['selected'],[0,0]),('zoom',original.crop(roi),row['zoom']['selected'],roi[:2])]):
                w,h=im.size;im.thumbnail((280,210));draw=ImageDraw.Draw(im)
                if sel:
                    b=[(sel[0]-offset[0])*im.width/w,(sel[1]-offset[1])*im.height/h,(sel[2]-offset[0])*im.width/w,(sel[3]-offset[1])*im.height/h]
                    draw.rectangle(b,outline=COLORS[int(sel[5])],width=3)
                x,y=col*280,j*250;sheet.paste(im,(x,y+35));d=ImageDraw.Draw(sheet)
                d.text((x+3,y+2),row['key'][:30],fill='white');d.text((x+3,y+17),title,fill='white')
            keys.append(row['key'])
        name='mask_changes_%02d'%(start//4+1);sheet.save(a.out/(name+'.jpg'),quality=90);save(a.out/(name+'.json'),keys)
    print('CONTEXT_MASK_COMPLETE',flush=True)


if __name__ == '__main__':main()
