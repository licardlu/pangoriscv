"""Build a hand-only head experiment; never alter the original four-bin model.

Only explicitly reviewed garbage negatives and reviewed positive hand crops
are used. The original backbone/neck will be frozen by the training command.
"""
import argparse
import copy
from collections import Counter
import hashlib
import json
import os
from pathlib import Path
import shutil
import sys
from PIL import Image
import yaml


def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()


def link(src,dst):
    dst.parent.mkdir(parents=True,exist_ok=True)
    try:os.link(src,dst)
    except OSError:shutil.copy2(src,dst)


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--hand-data',type=Path,required=True)
    p.add_argument('--review',type=Path,required=True)
    p.add_argument('--weights',type=Path,required=True)
    p.add_argument('--expected-sha256',required=True)
    p.add_argument('--yolo',type=Path,required=True)
    p.add_argument('--out',type=Path,required=True)
    p.add_argument('--adapter-channels',type=int,default=0,
                   help='Offline experiment: nonlinear 1x1 feature adapters before hand Detect')
    p.add_argument('--adapter-kernel',type=int,choices=(1,3),default=1)
    p.add_argument('--initialize-auxiliary',type=Path,
                   help='Copy compatible trained adapters, center-padding 1x1 kernels if needed')
    a=p.parse_args()
    if sha(a.weights)!=a.expected_sha256:raise ValueError('Original checkpoint identity changed')
    review=json.loads(a.review.read_text(encoding='utf8'))
    if review['status']!='VISUALLY_REVIEWED':raise ValueError('Explicit visual review required')
    a.out.mkdir(parents=True,exist_ok=False);data=a.out/'dataset'
    rows=[];negative_seen=set();groups={s:set() for s in ('train','val','test')}
    original=json.loads((a.hand_data/'manifest.json').read_text(encoding='utf8'))
    for r in original:
        if r['source']!='hagrid_hand_localisation' or r['repetition']!=0:continue
        split=r['split'];src=Path(r['prepared_image'])
        if sha(src)!=r['sha256']:raise ValueError('Reviewed hand crop changed')
        groups[split].add(('hagrid',r['group']))
        boxes=[[0,*b[1:]] for b in r['boxes']]
        for rep in range(2 if split=='train' else 1):
            stem=f'positive_{src.stem}_{rep}'
            target=data/'images'/split/(stem+'.jpg');label=data/'labels'/split/(stem+'.txt')
            link(src,target);label.parent.mkdir(parents=True,exist_ok=True)
            label.write_text(''.join('0 '+' '.join(f'{v:.9f}' for v in b[1:])+'\n' for b in boxes),encoding='ascii')
            rows.append(dict(source='reviewed_hand',split=split,group=r['group'],boxes=boxes,
                prepared_image=str(target.resolve()),sha256=sha(src)))
    for source in review['sources']:
        inventory=json.loads(Path(source['inventory']).read_text(encoding='utf8'))
        items=inventory.get('records',inventory.get('candidates',[]))
        for r in items:
            idx=r['review_id']
            if idx not in source['negative_ids']:continue
            src=Path(r.get('path',r.get('prepared_image','')));digest=sha(src)
            if digest!=r['sha256']:raise ValueError('Reviewed negative changed')
            split=r['split']
            if digest in negative_seen:continue
            negative_seen.add(digest);groups[split].add((r['source'],str(r.get('group',r.get('source_group')))))
            for rep in range(2 if split=='train' else 1):
                stem=f'negative_{digest[:20]}_{rep}'
                target=data/'images'/split/(stem+'.jpg');label=data/'labels'/split/(stem+'.txt')
                link(src,target);label.parent.mkdir(parents=True,exist_ok=True);label.write_text('',encoding='ascii')
                rows.append(dict(source='reviewed_hand_negative',split=split,group=str(r.get('group',r.get('source_group'))),
                    boxes=[],prepared_image=str(target.resolve()),sha256=digest,review_id=idx))
    for s,t in (('train','val'),('train','test'),('val','test')):
        if groups[s]&groups[t]:raise ValueError('Hand experiment group split leakage')
        if {r['sha256'] for r in rows if r['split']==s}&{r['sha256'] for r in rows if r['split']==t}:
            raise ValueError('Image split leakage')
    config=dict(path=str(data.resolve()).replace('\\','/'),train='images/train',val='images/val',
        test='images/test',nc=1,names=['hand'])
    (data/'data.yaml').write_text(yaml.safe_dump(config),encoding='utf8')
    (data/'manifest.json').write_text(json.dumps(rows,indent=2),encoding='utf8')
    os.environ['YOLOv5_AUTOINSTALL']='false';os.environ['WANDB_MODE']='disabled'
    os.environ['YOLOV5_CONFIG_DIR']=str((a.out/'config').resolve())
    sys.path.insert(0,str(a.yolo.resolve()))
    import torch
    from torch import nn
    torch.set_num_threads(2);torch.manual_seed(20261112)
    cp=torch.load(a.weights,map_location='cpu')
    model=(cp.get('ema') or cp['model']).float().eval()
    detect=model.model[-1]
    if detect.nc!=4 or detect.na!=3:raise ValueError('Expected original four-bin model')
    if a.adapter_channels:
        from models.yolo import Model
        if a.adapter_channels%8 or a.adapter_channels<8:
            raise ValueError('Adapter channels must be a positive multiple of eight')
        cfg=copy.deepcopy(model.yaml)
        if len(cfg['backbone'])+len(cfg['head'])!=25 or detect.f!=[17,20,23]:
            raise ValueError('Unexpected feature graph')
        cfg['nc']=1
        argument=int(a.adapter_channels/cfg['width_multiple'])
        cfg['head']=cfg['head'][:-1]+[[i,1,'Conv',[argument,a.adapter_kernel,1]] for i in detect.f]+[
            [[24,25,26],1,'Detect',[1,cfg['anchors']]]]
        adapted=Model(cfg,ch=3,nc=1)
        frozen={k:v for k,v in model.state_dict().items() if not k.startswith('model.24.')}
        incompatible=adapted.load_state_dict(frozen,strict=False)
        if incompatible.unexpected_keys:raise ValueError('Unexpected frozen state keys')
        for k,v in frozen.items():
            if not torch.equal(v,adapted.state_dict()[k]):raise ValueError('Frozen copy changed')
        model=adapted.float().eval();detect=model.model[-1]
        if a.initialize_auxiliary:
            auxiliary_cp=torch.load(a.initialize_auxiliary,map_location='cpu')
            old=(auxiliary_cp.get('ema') or auxiliary_cp['model']).float().eval()
            if len(old.model)!=len(model.model):raise ValueError('Auxiliary structure mismatch')
            state=model.state_dict()
            with torch.no_grad():
                for key,value in old.state_dict().items():
                    if int(key.split('.')[1])<24:continue
                    if key not in state:raise ValueError('Unknown auxiliary parameter '+key)
                    target_value=state[key]
                    if value.shape==target_value.shape:target_value.copy_(value)
                    elif value.ndim==4 and value.shape[-2:]==(1,1) and target_value.shape[-2:]==(3,3):
                        target_value.zero_();target_value[:,:,1:2,1:2].copy_(value)
                    else:raise ValueError('Incompatible auxiliary shape '+key)
    else:
        for i,old in enumerate(detect.m):
            new=nn.Conv2d(old.in_channels,18,1)
            with torch.no_grad():
                new.weight.zero_();new.bias.zero_()
                for anchor in range(3):
                    new.weight[anchor*6:anchor*6+5].copy_(old.weight[anchor*9:anchor*9+5])
                    new.bias[anchor*6:anchor*6+5].copy_(old.bias[anchor*9:anchor*9+5])
                    new.bias[anchor*6+5]=4.59511985
            detect.m[i]=new
    detect.nc=1;detect.no=6;model.yaml['nc']=1;model.names=['hand']
    target=a.out/'initial_hand_branch.pt'
    torch.save(dict(model=model,ema=None,epoch=-1,optimizer=None,best_fitness=0),target)
    report=dict(status='PREPARED_NOT_TRAINED',base_checkpoint_sha256=sha(a.weights),
        initial_checkpoint_sha256=sha(target),review_sha256=sha(a.review),
        counts=dict(Counter(r['split'] for r in rows)),sources=dict(Counter((r['split']+'/'+r['source']) for r in rows)),
        freeze_required=24,freeze_bn_required=True,personal_images_used=False,hand_test_used=False,
        adapter_channels=a.adapter_channels,
        adapter_kernel=a.adapter_kernel,
        initialized_auxiliary_sha256=sha(a.initialize_auxiliary) if a.initialize_auxiliary else None,
        active_fpga_modified=False,limitations=['Frozen garbage backbone has seen original garbage train images',
            'Positive hand crops mostly cover faces/natural gestures; no held-item relation labels',
            'Negative-only validation subset is small and not a camera-background benchmark'])
    (a.out/'preparation.json').write_text(json.dumps(report,indent=2),encoding='utf8');print(report,flush=True)


if __name__=='__main__':main()
