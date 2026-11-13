"""Prepare frozen original-waste features with a hand-only early-backbone head.

Only explicitly reviewed hand scenes/negatives are used, never unreviewed
garbage as empty hand negatives. All evaluation splits are copied unchanged.
"""
import argparse
import copy
from collections import Counter
import hashlib
import json
import os
from pathlib import Path
import sys
import yaml
from prepare_hand_context import link


def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for name in ('base-data','public-data','initial-adapter','waste','yolo','out'):
        p.add_argument('--'+name,type=Path,required=True)
    p.add_argument('--expected-waste-sha256',required=True)
    p.add_argument('--expected-adapter-sha256',required=True)
    a=p.parse_args()
    if sha(a.waste)!=a.expected_waste_sha256 or sha(a.initial_adapter)!=a.expected_adapter_sha256:
        raise ValueError('Input checkpoint identity mismatch')
    cfg=yaml.safe_load((a.base_data/'data.yaml').read_text(encoding='utf8'))
    if cfg['nc']!=1 or cfg['names']!=['hand']:raise ValueError('Expected reviewed hand dataset')
    original=json.loads((a.base_data/'manifest.json').read_text(encoding='utf8'))
    public=json.loads((a.public_data/'manifest.json').read_text(encoding='utf8'))
    a.out.mkdir(parents=True,exist_ok=False);data=a.out/'dataset';rows=[]
    for row in original:
        src=Path(row['prepared_image'])
        if sha(src)!=row['sha256']:raise ValueError('Base image identity changed')
        dst=data/'images'/row['split']/src.name
        link(src,dst);link(a.base_data/'labels'/row['split']/(src.stem+'.txt'),
                           data/'labels'/row['split']/(src.stem+'.txt'))
        rows.append(dict(row,prepared_image=str(dst.resolve())))
    added=[];seen={r['sha256'] for r in rows}
    for row in public:
        if row.get('hand_annotation_status')!='visible hands manually boxed and reviewed':continue
        if row['split']!='train' or row['source'] not in ('codingbear','sumn2u'):
            raise ValueError('Only reviewed public training hands may be added')
        src=Path(row['prepared_image'])
        if sha(src)!=row['sha256'] or row['sha256'] in seen:
            raise ValueError('Changed or duplicate reviewed hand image')
        boxes=[[0,*b[1:]] for b in row['boxes'] if int(b[0])==4]
        if not boxes:raise ValueError('Reviewed public hand annotations absent')
        for rep in range(3):
            dst=data/'images/train'/f"public_hand_{row['sha256'][:20]}_{rep}.jpg"
            link(src,dst);label=data/'labels/train'/(dst.stem+'.txt');label.parent.mkdir(parents=True,exist_ok=True)
            label.write_text(''.join('0 '+' '.join(f'{v:.9f}' for v in b[1:])+'\n' for b in boxes),encoding='ascii')
            rows.append(dict(source='reviewed_public_hand',split='train',group=row['group'],
                             boxes=boxes,prepared_image=str(dst.resolve()),sha256=row['sha256'],
                             repetition=rep,annotation_scope='Explicitly reviewed hand boxes only; waste excluded from hand-only task'))
        seen.add(row['sha256']);added.append(row['sha256'])
    if len(added)!=50:raise ValueError('Expected exactly50 reviewed public hand images')
    for left,right in [('train','val'),('train','test'),('val','test')]:
        for field in ('group','sha256','original_sha256'):
            if {str(r[field]) for r in rows if r['split']==left and field in r}&{str(r[field]) for r in rows if r['split']==right and field in r}:
                raise ValueError('Split leakage '+field)
    config=dict(cfg,path=str(data.resolve()).replace('\\','/'))
    (data/'data.yaml').write_text(yaml.safe_dump(config),encoding='utf8')
    (data/'manifest.json').write_text(json.dumps(rows,indent=2),encoding='utf8')
    os.environ['YOLOv5_AUTOINSTALL']='false';os.environ['YOLOV5_CONFIG_DIR']=str((a.out/'config').resolve())
    sys.path.insert(0,str(a.yolo.resolve()))
    import torch
    from models.yolo import Model
    torch.set_num_threads(2);torch.manual_seed(20261112)
    cp=torch.load(a.waste,map_location='cpu');waste=(cp.get('ema') or cp['model']).float().eval()
    cp=torch.load(a.initial_adapter,map_location='cpu');old=(cp.get('ema') or cp['model']).float().eval()
    if len(old.model)!=28 or old.model[-1].nc!=1:raise ValueError('Expected three-adapter hand model')
    cfg=copy.deepcopy(old.yaml)
    for entry,feature in zip(cfg['head'][-4:-1],[4,6,9]):entry[0]=feature
    model=Model(cfg,ch=3,nc=1).float().eval()
    expected={k:v for k,v in waste.state_dict().items() if not k.startswith('model.24.')}
    state=model.state_dict()
    for k,v in expected.items():
        if state[k].shape!=v.shape:raise ValueError('Frozen state shape mismatch')
        state[k].copy_(v)
    for k,v in old.state_dict().items():
        if int(k.split('.')[1])>=24:
            if state[k].shape!=v.shape:raise ValueError('Early-feature channels differ from planned neck channels')
            state[k].copy_(v)
    if [model.model[i].f for i in (24,25,26)]!=[4,6,9]:raise ValueError('Unexpected early feature routing')
    if any(not torch.equal(v,model.state_dict()[k]) for k,v in expected.items()):raise ValueError('Frozen state changed')
    with torch.no_grad():
        prediction=model(torch.zeros(1,3,320,320))[0]
        if prediction.shape!=(1,6300,6) or not torch.isfinite(prediction).all():raise ValueError('Invalid hand forward')
    target=a.out/'initial_hand_branch.pt'
    torch.save(dict(model=model,ema=None,epoch=-1,optimizer=None,best_fitness=0),target)
    report=dict(status='PREPARED_NOT_TRAINED',counts=dict(Counter(r['split'] for r in rows)),
        frozen_feature_layers=24,source_feature_layers=[4,6,9],adapter_channels=32,adapter_kernel=1,
        base_checkpoint_sha256=sha(a.waste),initial_checkpoint_sha256=sha(target),adapter_source_sha256=sha(a.initial_adapter),
        base_manifest_sha256=sha(a.base_data/'manifest.json'),public_manifest_sha256=sha(a.public_data/'manifest.json'),
        reviewed_public_hand_images=len(added),public_train_repeat=3,
        prepared_manifest_sha256=sha(data/'manifest.json'),script_sha256=sha(Path(__file__)),
        validation_and_test_images_and_labels_unchanged=True,test_inference_performed=False,
        pds_started=False,board_programmed=False)
    (a.out/'preparation.json').write_text(json.dumps(report,indent=2),encoding='utf8');print(json.dumps(report))


if __name__=='__main__':main()
