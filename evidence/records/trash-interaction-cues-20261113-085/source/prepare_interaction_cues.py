"""Train-only audited held-subject/empty-hand labels and a geometry-preserving seed."""
import argparse
from collections import Counter
from copy import deepcopy
import json
import os
from pathlib import Path
import shutil
import sys
import numpy as np
import yaml
from evaluate_crop_diagnostic import ROOT,sha,save


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--out',type=Path,required=True)
    p.add_argument('--seed',type=Path,required=True);p.add_argument('--expected-seed-sha256',required=True);a=p.parse_args()
    a.out=a.out.resolve();a.out.mkdir(parents=True,exist_ok=False);assert sha(a.seed)==a.expected_seed_sha256
    data=a.out/'dataset'
    source=ROOT/'build/trash_independent_hand_20261113_082/dataset/manifest.json'
    review_dir=ROOT/'build/trash_independent_hand_20261113_083/occupancy_review'
    review=json.loads((review_dir/'review.json').read_text(encoding='utf8'))
    assert review['status']=='VISUALLY_REVIEWED_TRAIN_ONLY' and review['inventory_sha256']==sha(review_dir/'inventory.json')
    reviewed={r['key']:r for r in review['images']}
    rows=json.loads(source.read_text(encoding='utf8'));manifest=[]
    for split in ('train','val'):
        (data/'images'/split).mkdir(parents=True);(data/'labels'/split).mkdir(parents=True)
    for r in rows:
        boxes=[];relation=None
        if r.get('held_object'):
            target=r['held_object'];x1,y1,x2,y2=target['xyxy'];assert x2>x1 and y2>y1
            boxes=[[0,(x1+x2)/2,(y1+y2)/2,x2-x1,y2-y1]];relation='reviewed held subject'
        elif r['split']=='train' and r['key'] in reviewed:
            mark=reviewed[r['key']];assert mark['sha256']==r['sha256']
            if mark['decision']!='visible_empty_hand':continue
            boxes=[[1,*b[1:]] for b in r['boxes']];relation='visually reviewed empty hand'
        elif r['split']=='val' and r['source']=='hagrid_hand_localisation':
            boxes=[[1,*b[1:]] for b in r['boxes']];relation='existing audited empty-hand validation crop'
        elif not r['boxes']:
            relation='audited absent hand'
        else:continue  # Visible hand does not establish empty/holding status.
        path=Path(r['prepared_image']);assert sha(path)==r['sha256']
        target=data/'images'/r['split']/path.name
        try:os.link(path,target)
        except OSError:shutil.copyfile(path,target)
        (data/'labels'/r['split']/(path.stem+'.txt')).write_text(''.join(' '.join(format(float(v),'.10g') for v in b)+'\n' for b in boxes),encoding='utf8')
        manifest.append(dict(r,boxes=boxes,prepared_image=str(target),cue_annotation=relation))
    for field in ('group','sha256','original_sha256'):
        assert not {str(r[field]) for r in manifest if r['split']=='train'}.intersection(str(r[field]) for r in manifest if r['split']=='val')
    save(data/'manifest.json',manifest)
    (data/'data.yaml').write_text(yaml.safe_dump(dict(path=str(data),train='images/train',val='images/val',nc=2,names={0:'held_item',1:'empty_hand'}),sort_keys=False),encoding='utf8')
    (a.out/'config').mkdir();os.environ['YOLOV5_CONFIG_DIR']=str(a.out/'config');os.environ['YOLOv5_AUTOINSTALL']='false'
    sys.path.insert(0,str(ROOT/'build/trash_retrain_research_20261111_001/yolov5-7.0'))
    import torch
    from models.yolo import Model
    torch.set_num_threads(4);torch.set_num_interop_threads(1)
    cp=torch.load(a.seed,map_location='cpu');old=(cp.get('ema') or cp['model']).float().eval();assert old.model[-1].nc==1
    student=Model(deepcopy(old.yaml),ch=3,nc=2).float().eval()
    prior=old.state_dict();current=student.state_dict()
    shared={k:v for k,v in prior.items() if k in current and v.shape==current[k].shape}
    student.load_state_dict(shared,strict=False)
    with torch.no_grad():
        for src,dst in zip(old.model[-1].m,student.model[-1].m):
            sw=src.weight.reshape(3,6,*src.weight.shape[1:]);dw=dst.weight.reshape(3,7,*dst.weight.shape[1:])
            sb=src.bias.reshape(3,6);db=dst.bias.reshape(3,7)
            dw.zero_();db.zero_();dw[:,:5].copy_(sw[:,:5]);db[:,:5].copy_(sb[:,:5])
        torch.manual_seed(20261113);image=torch.rand(1,3,128,128);left=old(image)[1];right=student(image)[1]
        max_error=max(float((s[...,:5]-t[...,:5]).abs().max()) for s,t in zip(left,right))
        for s,t in zip(left,right):torch.testing.assert_close(s[...,:5],t[...,:5],rtol=1e-6,atol=1e-6)
    seed=a.out/'interaction_seed.pt';torch.save(dict(model=student.half(),ema=None,epoch=-1,optimizer=None),seed)
    result=dict(status='PASS_AUDITED_CUE_DATA_AND_SEED',counts=dict(Counter(r['split']+'/'+r['cue_annotation'] for r in manifest)),
                manifest_sha256=sha(data/'manifest.json'),source_manifest_sha256=sha(source),review_sha256=sha(review_dir/'review.json'),
                seed_source_sha256=sha(a.seed),seed_sha256=sha(seed),shared_state_tensors=len(shared),
                geometry_objectness_max_absolute_error=max_error,split_group_sha_source_disjoint=True,
                classes=['held_item','empty_hand'],test_used=False,unknown_occupancy_not_assumed=True,script_sha256=sha(__file__))
    save(a.out/'preparation.json',result);print(json.dumps(result),flush=True)


if __name__=='__main__':main()
