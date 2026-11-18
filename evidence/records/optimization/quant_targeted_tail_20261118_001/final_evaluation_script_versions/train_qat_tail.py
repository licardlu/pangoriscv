"""Predeclared exact-Q15 tail experiment; offline only, train-only feature cache."""
import argparse,copy,os,subprocess,time
from pathlib import Path
from adapt_quant_heads import ROOT,CP,DEP,PARENT,read,save,sha,setup,training_rows

HEAD_ROOT=ROOT/'build/quant_head_adapt_20261118_001'
SHAPES=[(128,10,10),(64,20,20),(64,40,40)]

def plan(out,deployed_init=False):
    out.mkdir(parents=True,exist_ok=False)
    assert read(out.parent/'preflight_002/result.json')['status']=='PASS'
    p=dict(hypothesis='Head-only adaptation failed to recover battery. Train three feature-producing tail convolutions through exact Q15 forward with STE and fixed initial calibration scales, retaining float supervision.',
        checkpoint=str(CP),checkpoint_sha256=sha(CP),manifest_sha256=sha(PARENT/'dataset_004/manifest.json'),
        scale_profile=str(DEP),bundle_sha256=sha(DEP/'bundle.json'),parameters_sha256=sha(DEP/'parameters.npz'),
        initialization='Same expanded float best; not previous failed adapted checkpoints',
        feature_ops=[48,57,64],unique_train=7904,draws_per_epoch=12662,epochs=3,batch=16,seed=20261118,
        conv_lr0=.00002,conv_lr_final=.000002,head_lr0=.0001,head_lr_final=.00001,
        optimizer='AdamW',weight_decay=.0005,quant_loss_weight=.75,float_loss_weight=.25,
        trainable_prefixes=['model.17.cv3.conv.','model.20.cv3.conv.','model.23.cv3.conv.','model.24.m.'],
        frozen='All other parameters, all BN stats/affine, anchors, all activation/preactivation scales and LUTs.',
        integer_coefficients='Per-output weight scale and Q15 multiplier recomputed from current weights; export uses the same frozen scale profile, no posthoc calibration.',
        gradient='STE for round-half-away, clamp gradients for saturation; analytic activation for LUT gradient; float64 integer forward accumulations bounded below 2**53.',
        checkpoint_selection='Final third epoch only, no threshold/calibration/epoch sweep.',
        acceptance=read(HEAD_ROOT/'experiment_003/plan.json')['acceptance'],
        scope='Offline training/software arithmetic only, no FPGA, synthesis, routing, UART, TF, Flash, deployment replacement or final-test image/label access.')
    if deployed_init:
        checkpoint=ROOT/'build/overnight_20261116/runs/continuation_stage4_002/weights/best.pt'
        profile=ROOT/'build/overnight_20261116/quant_stage4_001'
        assert sha(checkpoint)=='a4a0b1b04f83af1d114813e0512dd2c2fa5e7306fae16759824f136b3133021a'
        assert sha(profile/'packed/model.bin')=='7a0765a6f275f3c06d838f924d73542783ca55e131509aa1b546efc98bd65728'
        p.update(hypothesis='Expanded-initialized QAT loses battery and paper despite glass/hand improvement. Initialize exact same fixed 3-epoch tail QAT from deployed model and its matching scales to avoid importing expanded-model feature drift; all other training draws, optimizer, selected layers and GT mixture unchanged.',
            checkpoint=str(checkpoint),checkpoint_sha256=sha(checkpoint),scale_profile=str(profile/'bundle'),
            bundle_sha256=sha(profile/'bundle/bundle.json'),parameters_sha256=sha(profile/'bundle/parameters.npz'),
            graph_source=str(profile/'graph.json'),scale_provenance=str(profile/'provenance.json'),
            initialization='Current deployed stage4 checkpoint and its exact existing frozen Q15 scale profile; no failed candidate initialization.',
            original_deployment_blob_sha256=sha(profile/'packed/model.bin'))
    save(out/'plan.json',p)
    _,unique=training_rows();save(out/'unique_train.json',unique)
    save(out/'draw_indices.json',read(HEAD_ROOT/'experiment_003/draw_indices.json'))
    print(p,flush=True)

def verify(out):
    p=read(out/'plan.json')
    checkpoint=Path(p['checkpoint']);profile=Path(p['scale_profile'])
    assert sha(checkpoint)==p['checkpoint_sha256'] and sha(profile/'bundle.json')==p['bundle_sha256']
    assert sha(profile/'parameters.npz')==p['parameters_sha256']
    assert sha(Path(p.get('manifest',PARENT/'dataset_004/manifest.json')))==p['manifest_sha256']
    if 'unique_train_sha256' in p:assert sha(out/'unique_train.json')==p['unique_train_sha256']
    if 'draw_indices_sha256' in p:assert sha(out/'draw_indices.json')==p['draw_indices_sha256']
    if 'target_reference_sha256' in p:assert sha(p['target_reference'])==p['target_reference_sha256']
    return p

def worker(out,lo,hi):
    plan=verify(out);setup(out)
    import numpy as np,torch,cv2
    from deployment_bundle import Deployment,float_graph
    from quant_yolov5n import preprocess
    from qat_tail import CUT
    torch.set_num_threads(2)
    rows=read(out/'unique_train.json');directory=out/'features'
    q=[np.load(directory/f'q15_{h}.npy',mmap_mode='r+') for h in range(3)]
    f=[np.load(directory/f'float_{h}.npy',mmap_mode='r+') for h in range(3)]
    dep=Deployment(Path(plan['scale_profile']),Path(plan['checkpoint']));start=time.time()
    with torch.no_grad():
        for i in range(lo,hi):
            row=rows[i];assert row['split']=='train'
            image=Path(row['prepared_image']);assert sha(image)==row['image_sha256']
            inp,_,_=preprocess(image,320)
            def qcb(op,v):
                if op['idx'] in CUT:q[CUT.index(op['idx'])][i]=v[0]
            def fcb(op,v,pre):
                if op['idx'] in CUT:f[CUT.index(op['idx'])][i]=v.numpy()[0]
            dep.execute(inp,qcb);float_graph(dep.model,dep.graph,inp,fcb)
            if (i+1)%64==0 or i+1==hi:
                for a in q+f:a.flush()
                save(out/f'cache_{lo}_{hi}_progress.json',dict(start=lo,completed=i+1,total=hi,elapsed_s=time.time()-start))
                print(f'cache {i+1}/{hi} elapsed={time.time()-start:.1f}',flush=True)
    save(out/f'cache_{lo}_{hi}_result.json',dict(status='PASS',start=lo,stop=hi,elapsed_s=time.time()-start))

def cache(out):
    plan=verify(out)
    import numpy as np
    n=plan['unique_train'];directory=out/'features';directory.mkdir(exist_ok=False)
    for h,shape in enumerate(SHAPES):
        for kind,dtype in [('q15','int8'),('float','float32')]:
            a=np.lib.format.open_memmap(directory/f'{kind}_{h}.npy',mode='w+',dtype=dtype,shape=(n,*shape));a.flush();del a
    start=time.time();env=os.environ.copy();env['PYTHONUTF8']='1';workers=[];prefix=0
    if plan.get('reuse_feature_cache'):
        previous=Path(plan['reuse_feature_cache']);prior=verify(previous);cached=read(previous/'cache_result.json')
        assert cached['status']=='PASS'
        assert all(prior[k]==plan[k] for k in ['checkpoint_sha256','bundle_sha256','parameters_sha256','feature_ops'])
        before=read(previous/'unique_train.json');after=read(out/'unique_train.json');prefix=len(before)
        assert [r['image_sha256'] for r in before]==[r['image_sha256'] for r in after[:prefix]]
        for name,digest in cached['files'].items():
            assert sha(previous/'features'/name)==digest
            original=np.load(previous/'features'/name,mmap_mode='r')
            target=np.load(directory/name,mmap_mode='r+')
            for lo in range(0,prefix,256):target[lo:min(prefix,lo+256)]=original[lo:min(prefix,lo+256)]
            target.flush();del original,target
        print(f'IDENTITY_VERIFIED_CACHE_PREFIX_REUSED {prefix}',flush=True)
    for i in range(4):
        lo=prefix+(n-prefix)*i//4;hi=prefix+(n-prefix)*(i+1)//4
        log=(out/f'cache_worker_{i}.log').open('x',encoding='utf8')
        command=[str(ROOT/'build/trash_train_env/Scripts/python.exe'),str(Path(__file__).resolve()),'worker','--out',str(out),'--lo',str(lo),'--hi',str(hi)]
        workers.append((subprocess.Popen(command,cwd=ROOT,env=env,stdout=log,stderr=subprocess.STDOUT),log,lo,hi))
    for proc,log,lo,hi in workers:
        rc=proc.wait();log.close();assert rc==0,f'worker {lo}:{hi} failed'
        assert read(out/f'cache_{lo}_{hi}_result.json')['status']=='PASS'
    target=Path(plan.get('target_reference',HEAD_ROOT/'experiment_003/features/targets.json'))
    save(out/'cache_result.json',dict(status='PASS',unique_images=n,elapsed_s=time.time()-start,
        feature_ops=[48,57,64],files={p.name:sha(p) for p in directory.iterdir() if p.is_file()},
        target_reference=str(target),target_sha256=sha(target),draws_sha256=sha(out/'draw_indices.json'),
        reused_prefix_images=prefix,plan_sha256=sha(out/'plan.json')))
    print('QAT_CUT_CACHE_COMPLETE',flush=True)

def train(out):
    plan=verify(out);setup(out)
    import numpy as np,torch,yaml
    from utils.loss import ComputeLoss
    from qat_tail import QuantTail,CUT
    from deployment_bundle import Deployment
    torch.manual_seed(plan['seed']);np.random.seed(plan['seed'])
    cached=read(out/'cache_result.json');assert cached['status']=='PASS' and cached['plan_sha256']==sha(out/'plan.json')
    for name,digest in cached['files'].items():assert sha(out/'features'/name)==digest
    assert sha(cached['target_reference'])==cached['target_sha256']
    assert sha(out/'draw_indices.json')==cached['draws_sha256']
    gt=read(cached['target_reference']);draws=np.asarray(read(out/'draw_indices.json'))
    q=[np.load(out/f'features/q15_{h}.npy',mmap_mode='r') for h in range(3)]
    f=[np.load(out/f'features/float_{h}.npy',mmap_mode='r') for h in range(3)]
    dep=Deployment(Path(plan['scale_profile']),Path(plan['checkpoint']));model=dep.model
    for name,p in model.named_parameters():p.requires_grad_(any(name.startswith(s) for s in plan['trainable_prefixes']))
    frozen={k:v.clone() for k,v in model.state_dict().items() if not any(k.startswith(s) for s in plan['trainable_prefixes'])}
    conv=[p for n,p in model.named_parameters() if p.requires_grad and not n.startswith('model.24.')]
    head=[p for n,p in model.named_parameters() if p.requires_grad and n.startswith('model.24.')]
    assert len(conv)==3 and len(head)==6
    optimizer=torch.optim.AdamW([dict(params=conv,lr=plan['conv_lr0']),dict(params=head,lr=plan['head_lr0'])],weight_decay=plan['weight_decay'])
    hyp=yaml.safe_load((PARENT/'runs/expanded_clean_004/hyp.yaml').read_text());hyp['cls']*=5/80;hyp['obj']*=.25;hyp['label_smoothing']=0.
    model.hyp=hyp;lossfn=ComputeLoss(model);tail=QuantTail(model,dep.graph,dep.arrays)
    resultdir=out/'training';resultdir.mkdir(exist_ok=False);history=[];start=time.time()
    for epoch in range(plan['epochs']):
        for group,kind in zip(optimizer.param_groups,['conv','head']):
            group['lr']=plan[kind+'_lr0']+(plan[kind+'_lr_final']-plan[kind+'_lr0'])*epoch/(plan['epochs']-1)
        order=np.random.RandomState(plan['seed']+epoch).permutation(draws);sums=np.zeros(6);batches=0
        for offset in range(0,len(order),plan['batch']):
            ids=order[offset:offset+plan['batch']]
            target=[]
            for b,i in enumerate(ids):target.extend([[b,*box] for box in gt[i]])
            target=torch.tensor(target,dtype=torch.float32).reshape(-1,6)
            quant={i:torch.from_numpy(np.array(a[ids],dtype=np.float64)) for i,a in zip(CUT,q)}
            floating={i:torch.from_numpy(np.array(a[ids])) for i,a in zip(CUT,f)}
            optimizer.zero_grad(set_to_none=True)
            qloss,qparts=lossfn(tail(quant,True),target)
            floss,fparts=lossfn(tail(floating,False),target)
            loss=plan['quant_loss_weight']*qloss+plan['float_loss_weight']*floss
            assert bool(torch.isfinite(loss));loss.backward()
            assert all(p.grad is not None and bool(torch.isfinite(p.grad).all()) for p in conv+head)
            optimizer.step();sums+=np.r_[qparts.numpy(),fparts.numpy()];batches+=1
            if batches%32==0:
                progress=dict(epoch=epoch+1,epochs=plan['epochs'],batch=batches,batches_total=(len(order)+plan['batch']-1)//plan['batch'],loss=float(loss),elapsed_s=time.time()-start)
                save(resultdir/'progress.json',progress);print(progress,flush=True)
        assert all(torch.equal(v,model.state_dict()[k]) for k,v in frozen.items())
        row=dict(epoch=epoch+1,batches=batches,draws=len(order),q15_loss=(sums[:3]/batches).tolist(),float_loss=(sums[3:]/batches).tolist(),elapsed_s=time.time()-start)
        history.append(row);save(resultdir/'history.json',history)
        print('EPOCH_COMPLETE '+str(row),flush=True)
    exported=copy.deepcopy(model).cpu().eval()
    for p in exported.parameters():p.requires_grad_(True)
    torch.save(dict(model=exported,ema=None,epoch=plan['epochs']-1,optimizer=None,
        frozen_scale_profile_sha256=plan['bundle_sha256'],qat_plan_sha256=sha(out/'plan.json')),resultdir/'final.pt')
    save(resultdir/'result.json',dict(status='PASS',epochs=plan['epochs'],elapsed_s=time.time()-start,
        checkpoint_sha256=sha(resultdir/'final.pt'),frozen_nonselected_state_exact=True,trainable_tensors=9,history=history))

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('mode',choices=['plan','cache','worker','train'])
    p.add_argument('--out',type=Path,required=True);p.add_argument('--lo',type=int);p.add_argument('--hi',type=int)
    p.add_argument('--deployed-init',action='store_true',help='Change only initialization and matching frozen profile to current deployed stage4')
    a=p.parse_args()
    if a.mode=='worker':worker(a.out,a.lo,a.hi)
    elif a.mode=='plan':plan(a.out,a.deployed_init)
    else:{'cache':cache,'train':train}[a.mode](a.out)

if __name__=='__main__':main()
