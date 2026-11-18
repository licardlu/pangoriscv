"""One train-only gradient check; its updated weights are never saved or used."""
import copy
from pathlib import Path
import numpy as np
import torch
import yaml
from adapt_quant_heads import ROOT,PARENT,read,save,sha,setup
from train_qat_tail import verify


def main():
    exp=ROOT/'build/quant_deployed_teacher_20261118_001/experiment_001'
    plan=verify(exp);setup(exp)
    from deployment_bundle import Deployment
    from qat_tail import QuantTail,CUT
    from utils.loss import ComputeLoss
    from fiveclass_distillation import distill
    reference=ROOT/'build/quant_extras_battery_20261118_001/experiment_001'
    prior=verify(reference);cached=read(reference/'cache_result.json')
    assert cached['status']=='PASS'
    assert all(prior[k]==plan[k] for k in ['checkpoint_sha256','bundle_sha256','parameters_sha256'])
    gt=read(cached['target_reference']);ids=[]
    for c in range(5):
        ids.extend([n for n,boxes in enumerate(gt) if any(int(b[0])==c for b in boxes)][:4])
    ids=sorted(set(ids));torch.set_num_threads(2);torch.manual_seed(plan['seed'])
    inputs={i:torch.from_numpy(np.array(np.load(reference/f'features/q15_{h}.npy',mmap_mode='r')[ids],dtype=np.float64)) for h,i in enumerate(CUT)}
    target=torch.tensor([[batch,*box] for batch,n in enumerate(ids) for box in gt[n]],dtype=torch.float32).reshape(-1,6)
    dep=Deployment(Path(plan['scale_profile']),Path(plan['checkpoint']));model=dep.model
    for name,p in model.named_parameters():p.requires_grad_(any(name.startswith(s) for s in plan['trainable_prefixes']))
    frozen={k:v.clone() for k,v in model.state_dict().items() if not any(k.startswith(s) for s in plan['trainable_prefixes'])}
    teacher_model=copy.deepcopy(model).eval()
    for p in teacher_model.parameters():p.requires_grad_(False)
    initial_teacher={k:v.clone() for k,v in teacher_model.state_dict().items()}
    student=QuantTail(model,dep.graph,dep.arrays);teacher=QuantTail(teacher_model,dep.graph,dep.arrays)
    hyp=yaml.safe_load((PARENT/'runs/expanded_clean_004/hyp.yaml').read_text());hyp['cls']*=5/80;hyp['obj']*=.25;hyp['label_smoothing']=0.
    model.hyp=hyp;supervised=ComputeLoss(model)
    prediction=student(inputs,True)
    with torch.no_grad():expected=teacher(inputs,True)
    assert all(torch.equal(a,b) for a,b in zip(prediction,expected))
    initial,counts=distill(supervised,prediction,expected,target)
    assert float(initial)==0 and sum(counts.values())>0
    optimizer=torch.optim.SGD([p for p in model.parameters() if p.requires_grad],lr=1e-4)
    loss,_=supervised(prediction,target);loss.backward();optimizer.step();optimizer.zero_grad(set_to_none=True)
    after=student(inputs,True);auxiliary,after_counts=distill(supervised,after,expected,target)
    assert torch.isfinite(auxiliary) and float(auxiliary)>0
    (auxiliary*plan['deployed_q15_distillation_strength']*len(ids)).backward()
    assert all(p.grad is not None and torch.isfinite(p.grad).all() for p in model.parameters() if p.requires_grad)
    assert sum(float(p.grad.abs().sum()) for p in model.parameters() if p.requires_grad)>0
    assert all(p.grad is None for p in teacher_model.parameters())
    assert all(torch.equal(v,teacher_model.state_dict()[k]) for k,v in initial_teacher.items())
    assert all(torch.equal(v,model.state_dict()[k]) for k,v in frozen.items())
    out=exp/'preflight_deployed_teacher.json';assert not out.exists()
    save(out,dict(status='PASS',train_only_source=str(reference),selected_train_indices=ids,
        initial_student_teacher_bit_exact=True,initial_auxiliary=float(initial),
        post_supervised_update_auxiliary=float(auxiliary.detach()),matched_anchors_by_class=dict(after_counts),
        student_gradient_finite_nonzero=True,teacher_gradient_absent=True,teacher_state_exact=True,
        frozen_nonselected_state_exact=True,updated_weights_saved=False,test_files_read=False,
        plan_sha256=sha(exp/'plan.json')))
    print(read(out),flush=True)


if __name__=='__main__':main()
