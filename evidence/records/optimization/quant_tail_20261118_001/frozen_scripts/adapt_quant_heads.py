"""Fit detection heads on frozen exact-Q15 train features and floating features.

Uses a fixed six-epoch schedule and final weights, with no validation selection.
The feature extractor, BN, anchors and calibration remain frozen. Test paths in
the manifest are metadata only; their image/label contents are never read.
"""
import argparse, copy, hashlib, json, time
from pathlib import Path
from diagnose_quant_features import ROOT, setup, sha

PARENT = ROOT / 'build/public_20k_20261117_001'
CP = PARENT / 'runs/expanded_clean_004/weights/best.pt'
DATA = PARENT / 'dataset_004/manifest.json'
DEP = PARENT / 'quant_original160_006/bundle'
SEED = 20261118
SIZES = [(64,40,40),(128,20,20),(256,10,10)]

def read(p):
    return json.loads(Path(p).read_text(encoding='utf8'))

def save(p,v):
    Path(p).write_text(json.dumps(v,indent=2,ensure_ascii=False)+'\n',encoding='utf8')

def training_rows():
    rows=[r for r in read(DATA) if r['split']=='train']
    unique={}
    for r in rows:
        unique.setdefault(r['image_sha256'],r)
    return rows, sorted(unique.values(),key=lambda r:r['image_sha256'])

def targets_letterbox(boxes, width, height):
    # Match quant_yolov5n.preprocess exactly, including integer centering.
    r=min(320/height,320/width)
    nw,nh=int(round(width*r)),int(round(height*r))
    left,top=(320-nw)//2,(320-nh)//2
    # cv2 resize geometry uses the rounded dimensions, not the ideal ratio.
    return [[int(c),(cx*nw+left)/320,(cy*nh+top)/320,bw*nw/320,bh*nh/320]
            for c,cx,cy,bw,bh in boxes]

def freeze_plan(out):
    out.mkdir(parents=True,exist_ok=False)
    rows,unique=training_rows()
    assert len(rows)==12662 and len(unique)==7904
    baseline=read(out.parent/'baseline_q15_current_policy/result.json')
    plan=dict(hypothesis='Frozen Q15 features drift from floating training features. Adapt only the three detection heads with original train GT, mixing 75% Q15 and 25% floating supervision.',
        checkpoint=str(CP),checkpoint_sha256=sha(CP),manifest=str(DATA),manifest_sha256=sha(DATA),
        bundle_sha256=sha(DEP/'bundle.json'),parameters_sha256=sha(DEP/'parameters.npz'),
        unique_train=7904,draws_per_epoch=12662,epochs=6,batch=16,seed=SEED,
        optimizer='AdamW',lr0=.0001,lr_final=.00001,weight_decay=.0005,
        quant_loss_weight=.75,float_loss_weight=.25,
        head_weights='STE round-half-away; per-output-channel Q16 scale halved to fit int16, matching runtime coefficient conversion',
        features='All unique whitelist train identities; exact Q15 oracle and unrounded FP32 backbone features; no augmentation or new labels.',
        checkpoint_selection='Final epoch only. No validation threshold or epoch sweep.',
        calibration='Original ordered historical train-only 160, same identity; never gradient training outside current whitelist.',
        acceptance=dict(subject_correct_min=1455,personal_battery_min=55,public_glass_min=232,background_false_max=8,
            per_waste_class_subject_correct='at least deployed baseline with same selector',
            each_class_detection_TP_min={k:v['TP'] for k,v in baseline['fixed_conf025_iou050'].items()},
            each_class_precision_min={k:v['precision'] for k,v in baseline['fixed_conf025_iou050'].items()},
            strict_improvement_required=True,public_dev='no worse than deployed baseline on identical 712 images',
            float='subject>=1457, battery>=54, glass>=231, background_false<=8'),
        scope='Offline only. No FPGA access, physical implementation, deployment replacement or final-test image/label access.')
    save(out/'plan.json',plan)
    save(out/'unique_train.json',unique)
    ids={r['image_sha256']:i for i,r in enumerate(unique)}
    save(out/'draw_indices.json',[ids[r['image_sha256']] for r in rows])
    print(json.dumps(plan,indent=2),flush=True)

def verify_plan(out):
    p=read(out/'plan.json')
    assert sha(CP)==p['checkpoint_sha256'] and sha(DATA)==p['manifest_sha256']
    assert sha(DEP/'bundle.json')==p['bundle_sha256'] and sha(DEP/'parameters.npz')==p['parameters_sha256']
    return p

def cache(out,start_index=0,stop_index=None,resume=False):
    plan=verify_plan(out)
    setup(out)
    import numpy as np,torch,cv2
    from deployment_bundle import Deployment,float_graph
    from quant_yolov5n import preprocess
    from test_graph_torch import submodule
    rows=read(out/'unique_train.json');n=len(rows)
    stop_index=n if stop_index is None else stop_index
    directory=out/'features';directory.mkdir(exist_ok=resume)
    fp=[np.lib.format.open_memmap(directory/f'float_{h}.npy',mode='r+' if resume else 'w+',dtype='float32',shape=(n,*s)) for h,s in enumerate(SIZES)]
    qp=[np.lib.format.open_memmap(directory/f'q15_{h}.npy',mode='r+' if resume else 'w+',dtype='int8',shape=(n,*s)) for h,s in enumerate(SIZES)]
    if resume:torch.set_num_threads(2)
    dep=Deployment(DEP,CP)
    indices=[dep.graph['ops'][i]['inputs'][0] for i in dep.graph['outputs']]
    assert indices==[65,73,81]
    gt=[];start=time.time();max_head_diff=0.
    with torch.no_grad():
        for i in range(start_index,stop_index):
            row=rows[i]
            assert row['split']=='train'
            path=Path(row['prepared_image'])
            assert sha(path)==row['image_sha256']
            # Read the deployed five-class prepared label, never the original
            # public-source taxonomy or any held-out label.
            label=Path(path.as_posix().replace('/images/','/labels/')).with_suffix('.txt')
            actual=np.asarray([[float(x) for x in line.split()] for line in label.read_text().splitlines() if line.strip()],dtype=np.float32).reshape(-1,5)
            expected=np.asarray(row['boxes'],dtype=np.float32).reshape(-1,5)
            np.testing.assert_allclose(actual,expected,rtol=0,atol=1e-5)
            im,_,_=preprocess(path,320)
            decoded=cv2.imread(str(path));height,width=decoded.shape[:2]
            if 'width' in row and 'height' in row:
                # Some historical prepared files were uniformly resized;
                # their normalized labels remain valid. Reject aspect changes.
                assert abs(width/height-row['width']/row['height'])<.005
            gt.append(targets_letterbox(row['boxes'],width,height))
            floats={};quants={}
            def fcb(op,v,pre):
                if op['idx'] in indices:floats[op['idx']]=v
            def qcb(op,v):
                if op['idx'] in indices:quants[op['idx']]=v.copy()
            outputs=float_graph(dep.model,dep.graph,im,fcb)
            dep.execute(im,qcb)
            for h,idx in enumerate(indices):
                fp[h][i]=floats[idx].numpy()[0];qp[h][i]=quants[idx][0]
                if i==start_index:
                    raw=submodule(dep.model,dep.graph['ops'][82+h]['module'])(torch.from_numpy(fp[h][i:i+1]))
                    error=float((raw-outputs[82+h]).abs().max())
                    assert error<1e-5
                    max_head_diff=max(max_head_diff,error)
            if (i+1)%32==0 or i+1==stop_index:
                for array in fp+qp:array.flush()
                progress=out/(f'worker_{start_index}_{stop_index}_progress.json' if resume else 'cache_progress.json')
                save(progress,dict(completed=i+1,total=stop_index,start_index=start_index,elapsed_s=time.time()-start))
                print(f'cache {i+1}/{stop_index} elapsed={time.time()-start:.1f}s',flush=True)
    for array in fp+qp:array.flush()
    if resume:
        save(out/f'worker_{start_index}_{stop_index}_result.json',dict(status='PASS',start_index=start_index,stop_index=stop_index,
            elapsed_s=time.time()-start,float_head_max_error=max_head_diff,train_only=True,targets=gt))
        return
    save(directory/'targets.json',gt)
    files={p.name:sha(p) for p in directory.iterdir() if p.is_file()}
    save(out/'cache_result.json',dict(status='PASS',images=n,elapsed_s=time.time()-start,
        plan_sha256=sha(out/'plan.json'),float_head_max_error=max_head_diff,
        files=files,feature_ops=indices,scales=[dep.graph['ops'][82+h]['input_scales'][0] for h in range(3)],
        target_counts={str(c):sum(int(b[0])==c for items in gt for b in items) for c in range(5)}))

def q16_weight(weight):
    import torch
    flat=weight.detach().flatten(1)
    scale=torch.full((flat.shape[0],1),65536.,dtype=flat.dtype,device=flat.device)
    while True:
        invalid=((flat*scale).min(1).values < -32768)|((flat*scale).max(1).values>32767)
        if not bool(invalid.any()):break
        scale[invalid]*=.5
    q=torch.sign(flat)*torch.floor(torch.abs(flat*scale)+.5)
    dequant=(q/scale).reshape_as(weight)
    return weight+(dequant-weight).detach()

def forward_heads(head,features,quant):
    import torch.nn.functional as F
    predictions=[]
    for layer,x in zip(head.m,features):
        w=q16_weight(layer.weight) if quant else layer.weight
        y=F.conv2d(x,w,layer.bias)
        b,_,ny,nx=y.shape
        predictions.append(y.view(b,head.na,head.no,ny,nx).permute(0,1,3,4,2).contiguous())
    return predictions

def test_q16(head,feature,scale):
    import numpy as np,torch
    x=feature.astype(np.int64);conv=head.m[0]
    w=conv.weight.detach().numpy().reshape(30,-1)
    scales=np.full((len(w),1),65536,dtype=np.float32)
    while True:
        mask=((w*scales).min(1)<-32768)|((w*scales).max(1)>32767)
        if not mask.any():break
        scales[mask]*=.5
    scaled=w*scales
    q=np.trunc(scaled+np.where(scaled>=0,np.float32(.5),np.float32(-.5))).astype(np.int64)
    exact=np.einsum('bchw,oc->bohw',x,q).astype(np.float32)*(np.float32(scale)/scales[:,0])[None,:,None,None]+conv.bias.detach().numpy()[None,:,None,None]
    with torch.no_grad():
        actual=torch.nn.functional.conv2d(torch.from_numpy(feature.astype(np.float32)*scale),q16_weight(conv.weight),conv.bias).numpy()
    diff=float(np.abs(exact-actual).max());assert diff<1e-4,diff
    return diff

def train(out):
    plan=verify_plan(out)
    setup(out)
    import numpy as np,torch,yaml
    from utils.loss import ComputeLoss
    torch.manual_seed(SEED);np.random.seed(SEED)
    cache_out=Path(plan.get('feature_cache_reference',out))
    result=read(cache_out/'cache_result.json');assert result['status']=='PASS'
    if cache_out==out:assert result['plan_sha256']==sha(out/'plan.json')
    else:assert sha(cache_out/'cache_result.json')==plan['feature_cache_result_sha256']
    directory=cache_out/'features'
    for name,digest in result['files'].items():assert sha(directory/name)==digest,name
    floating=[np.load(directory/f'float_{h}.npy',mmap_mode='r') for h in range(3)]
    quant=[np.load(directory/f'q15_{h}.npy',mmap_mode='r') for h in range(3)]
    gt=read(directory/'targets.json');draws=np.asarray(read(cache_out/'draw_indices.json'))
    model=torch.load(CP,map_location='cpu')['model'].float().eval()
    frozen={k:v.detach().clone() for k,v in model.state_dict().items() if not k.startswith('model.24.m.')}
    for name,p in model.named_parameters():p.requires_grad_(name.startswith('model.24.m.'))
    head=model.model[-1]
    assert head.nc==5 and head.no==10
    hyp=yaml.safe_load((PARENT/'runs/expanded_clean_004/hyp.yaml').read_text())
    hyp['cls']*=head.nc/80*3/head.nl
    hyp['box']*=3/head.nl
    hyp['obj']*=(320/640)**2*3/head.nl
    hyp['label_smoothing']=0.
    model.hyp=hyp
    compute=ComputeLoss(model)
    strength=plan.get('distillation_strength',0.)
    teacher=None
    if strength:
        from fiveclass_distillation import distill
        teacher=copy.deepcopy(head).eval()
        for p in teacher.parameters():p.requires_grad_(False)
    # Meaningful independent arithmetic/geometry checks before any update.
    assert targets_letterbox([[2,.5,.5,.2,.4]],640,480)==[[2,.5,.5,.2,.3]]
    checks=dict(q16_head_error=test_q16(head,quant[0][0:1],result['scales'][0]))
    float_err=0.
    with torch.no_grad():
        features=[torch.from_numpy(np.array(f[0:1])) for f in floating]
        custom=forward_heads(head,features,False)
        head.training=True
        original=head([x.clone() for x in features])
        head.training=False
        for a,b in zip(custom,original):float_err=max(float_err,float((a-b).abs().max()))
    assert float_err==0.
    checks['float_head_forward_error']=float_err
    save(out/'preflight.json',dict(status='PASS',**checks))
    params=[p for p in model.parameters() if p.requires_grad]
    assert len(params)==6
    optimizer=torch.optim.AdamW(params,lr=plan['lr0'],weight_decay=plan['weight_decay'])
    output=out/'training';output.mkdir(exist_ok=False)
    start=time.time();history=[]
    for epoch in range(plan['epochs']):
        from collections import Counter
        matched=Counter();aux_sum=0.
        lr=plan['lr0']+(plan['lr_final']-plan['lr0'])*epoch/(plan['epochs']-1)
        for g in optimizer.param_groups:g['lr']=lr
        order=np.random.RandomState(SEED+epoch).permutation(draws)
        sums=np.zeros(6);batches=0
        for offset in range(0,len(order),plan['batch']):
            ids=order[offset:offset+plan['batch']]
            target=[]
            for b,i in enumerate(ids):target.extend([[b,*box] for box in gt[i]])
            targets=torch.tensor(target,dtype=torch.float32).reshape(-1,6)
            qfeatures=[torch.from_numpy(np.array(f[ids],dtype=np.float32))*s for f,s in zip(quant,result['scales'])]
            ffeatures=[torch.from_numpy(np.array(f[ids])) for f in floating]
            optimizer.zero_grad(set_to_none=True)
            qpred=forward_heads(head,qfeatures,True)
            qloss,qparts=compute(qpred,targets)
            floss,fparts=compute(forward_heads(head,ffeatures,False),targets)
            loss=plan['quant_loss_weight']*qloss+plan['float_loss_weight']*floss
            if teacher is not None:
                with torch.no_grad():tpred=forward_heads(teacher,ffeatures,False)
                auxiliary,counts=distill(compute,qpred,tpred,targets)
                matched.update(counts);aux_sum+=float(auxiliary.detach())
                loss=loss+auxiliary*strength*len(ids)
            assert bool(torch.isfinite(loss))
            loss.backward()
            assert all(p.grad is not None and bool(torch.isfinite(p.grad).all()) for p in params)
            optimizer.step()
            sums+=np.r_[qparts.numpy(),fparts.numpy()];batches+=1
            if batches%100==0:print(f'epoch {epoch+1}/6 batch {batches}/792 loss={float(loss):.5f}',flush=True)
        assert all(torch.equal(v,model.state_dict()[k]) for k,v in frozen.items()),'Frozen extractor or anchors changed'
        row=dict(epoch=epoch+1,lr=lr,batches=batches,draws=len(order),q15_loss=(sums[:3]/batches).tolist(),float_loss=(sums[3:]/batches).tolist(),elapsed_s=time.time()-start)
        if teacher is not None:
            assert all(matched[str(c)]>0 for c in range(5)),'Missing GT-gated teacher supervision'
            row.update(distillation_loss=aux_sum/batches,matched_anchors_by_class=dict(matched),strength=strength)
        history.append(row);save(output/'history.json',history)
        print(json.dumps(row),flush=True)
    saved=copy.deepcopy(model).cpu().eval()
    for p in saved.parameters():p.requires_grad_(True)
    torch.save(dict(model=saved,ema=None,epoch=plan['epochs']-1,optimizer=None,
                    adaptation_plan_sha256=sha(out/'plan.json')),output/'final.pt')
    reloaded=torch.load(output/'final.pt',map_location='cpu')['model'].float().eval()
    assert all(torch.equal(v,reloaded.state_dict()[k]) for k,v in model.state_dict().items())
    save(output/'result.json',dict(status='PASS',epochs=6,checkpoint_sha256=sha(output/'final.pt'),
        frozen_nonhead_state_exact=True,trainable_tensors=6,checkpoint_roundtrip_exact=True,
        elapsed_s=time.time()-start,history=history,final_epoch_only=True,teacher_exported=False))

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('mode',choices=['plan','cache','train'])
    p.add_argument('--out',type=Path,required=True)
    p.add_argument('--start-index',type=int,default=0)
    p.add_argument('--stop-index',type=int)
    p.add_argument('--resume-cache',action='store_true')
    a=p.parse_args()
    if a.mode=='cache':cache(a.out,a.start_index,a.stop_index,a.resume_cache)
    else:{'plan':freeze_plan,'train':train}[a.mode](a.out)

if __name__=='__main__':main()
