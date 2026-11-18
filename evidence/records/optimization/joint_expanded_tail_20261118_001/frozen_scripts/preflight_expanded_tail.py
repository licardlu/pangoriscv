"""Train-only arithmetic, gradient and frozen-state checks for a broader QAT tail."""
from pathlib import Path
import copy
import time
from adapt_quant_heads import ROOT, read, save, sha, setup


def main():
    out=ROOT/'build/expanded_tail_preflight_20261118_001';out.mkdir(exist_ok=False);setup(out)
    import numpy as np
    import torch
    import yaml
    from train_qat_tail import verify
    from qat_tail import QuantTail,CUT
    from deployment_bundle import Deployment
    from quant_yolov5n import preprocess
    from utils.loss import ComputeLoss
    from fiveclass_distillation import distill
    reference=ROOT/'build/joint_battery_resume_20261118_001/experiment_001'
    plan=verify(reference);rows=read(reference/'unique_train.json');targets=read(reference/'targets.json')
    prefixes=['model.17.cv3.conv.','model.18.conv.','model.20.cv1.conv.','model.20.cv2.conv.',
        'model.20.cv3.conv.','model.20.m.0.cv1.conv.','model.20.m.0.cv2.conv.',
        'model.21.conv.','model.23.cv1.conv.','model.23.cv2.conv.','model.23.cv3.conv.',
        'model.23.m.0.cv1.conv.','model.23.m.0.cv2.conv.','model.24.m.']
    dep=Deployment(Path(plan['scale_profile']),Path(plan['checkpoint']));model=dep.model
    ops=[o['idx'] for o in dep.graph['ops'] if o.get('execution')=='rtl_q15_conv'
         and any((o['module']+'.weight').startswith(p) for p in prefixes)]
    assert ops==[65,66,68,69,70,71,73,74,76,77,78,79,81]
    for name,p in model.named_parameters():p.requires_grad_(any(name.startswith(s) for s in prefixes))
    frozen={k:v.clone() for k,v in model.state_dict().items() if not any(k.startswith(s) for s in prefixes)}
    conv=[p for n,p in model.named_parameters() if p.requires_grad and not n.startswith('model.24.')]
    head=[p for n,p in model.named_parameters() if p.requires_grad and n.startswith('model.24.')]
    assert len(conv)==13 and len(head)==6
    tail=QuantTail(model,dep.graph,dep.arrays)
    teacher_model=copy.deepcopy(model).eval()
    for p in teacher_model.parameters():p.requires_grad_(False)
    teacher=QuantTail(teacher_model,dep.graph,dep.arrays)
    hyp=yaml.safe_load((ROOT/'build/public_20k_20261117_001/runs/expanded_clean_004/hyp.yaml').read_text())
    hyp['cls']*=5/80;hyp['obj']*=.25;hyp['label_smoothing']=0.
    model.hyp=hyp;criterion=ComputeLoss(model)
    ids=[]
    for c in range(5):
        eligible=[i for i,r in enumerate(rows) if any(int(b[0])==c for b in r['boxes'])]
        ids.append(eligible[len(eligible)//2])
    empty=next(i for i,r in enumerate(rows) if not r['boxes']);ids.append(empty)
    q={op:torch.from_numpy(np.array(np.load(reference/f'features/q15_{h}.npy',mmap_mode='r')[ids],dtype=np.float64)) for h,op in enumerate(CUT)}
    f={op:torch.from_numpy(np.array(np.load(reference/f'features/float_{h}.npy',mmap_mode='r')[ids])) for h,op in enumerate(CUT)}
    gt=torch.tensor([[b,*box] for b,i in enumerate(ids) for box in targets[i]],dtype=torch.float32).reshape(-1,6)
    arithmetic=[]
    with torch.no_grad():
        for i in ids:
            x,_,_=preprocess(Path(rows[i]['prepared_image']),320);values={}
            dep.execute(x,lambda op,v:values.update({op['idx']:v.copy()}))
            actual={};tail({op:torch.from_numpy(values[op].astype(np.float64)) for op in CUT},True,
                          lambda op,v:actual.update({op['idx']:v.numpy()}))
            for op in range(65,82):np.testing.assert_array_equal(values[op],actual[op])
            arithmetic.append(rows[i]['image_sha256'])
    opt=torch.optim.AdamW([dict(params=conv,lr=plan['conv_lr0']),dict(params=head,lr=plan['head_lr0'])],weight_decay=plan['weight_decay'])
    start=time.time();qp=tail(q,True);qloss,_=criterion(qp,gt);floss,_=criterion(tail(f,False),gt)
    with torch.no_grad():tp=teacher(q,True)
    auxiliary,counts=distill(criterion,qp,tp,gt)
    loss=.75*qloss+.25*floss+5*len(ids)*auxiliary
    assert bool(torch.isfinite(loss));loss.backward()
    assert all(p.grad is not None and bool(torch.isfinite(p.grad).all()) for p in conv+head)
    assert all(p.grad is None for p in teacher_model.parameters())
    opt.step()
    assert all(torch.equal(v,model.state_dict()[k]) for k,v in frozen.items())
    arrays=tail.export_arrays()
    for name in dep.arrays.files:
        idx=int(name.split('_')[0][2:])
        if idx not in ops+[82,83,84] or name.endswith('_lut'):
            np.testing.assert_array_equal(arrays[name],dep.arrays[name])
    np.savez(out/'parameters.npz',**arrays);save(out/'bundle.json',dep.graph)
    replay=Deployment(out,Path(plan['checkpoint']))
    with torch.no_grad():
        i=ids[2];x,_,_=preprocess(Path(rows[i]['prepared_image']),320);values={}
        replay.execute(x,lambda op,v:values.update({op['idx']:v.copy()}))
        actual={};tail({op:torch.from_numpy(values[op].astype(np.float64)) for op in CUT},True,
                      lambda op,v:actual.update({op['idx']:v.numpy()}))
        for op in range(65,82):np.testing.assert_array_equal(values[op],actual[op])
    result=dict(status='PASS_TRAIN_ONLY_EXPANDED_TAIL_PREFLIGHT',trained_q15_ops=ops,
        trainable_prefixes=prefixes,expected_trainable_conv_tensors=len(conv),
        init_profile_bit_exact_train_checks=arithmetic,post_step_export_bit_exact=True,
        loss=float(loss),finite_gradients_all_trainable=True,frozen_state_exact=True,
        luts_and_scales_unchanged=True,teacher_no_grad=True,teacher_matched_counts=dict(counts),
        step_seconds=time.time()-start,train_batch=len(ids),checkpoint_sha256=plan['checkpoint_sha256'],
        profile_sha256=plan['bundle_sha256'],test_or_dev_files_read=False,
        board_accessed=False,accepted_model=False)
    save(out/'result.json',result);print(result,flush=True)


if __name__=='__main__':main()
