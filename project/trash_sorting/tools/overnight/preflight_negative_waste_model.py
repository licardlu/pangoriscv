"""Exercise one real train-only mixed-GT forward/backward before queuing the experiment."""
import argparse
from pathlib import Path
import numpy as np
from adapt_quant_heads import ROOT,PARENT,read,save,sha,setup
from train_qat_tail import verify


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--experiment',type=Path,required=True);a=p.parse_args()
    exp=a.experiment.resolve();plan=verify(exp);setup(exp)
    import torch,yaml
    from utils.loss import ComputeLoss
    from deployment_bundle import Deployment
    from qat_tail import QuantTail,CUT
    from negative_waste_supervision import negative_waste_loss
    torch.set_num_threads(4);torch.manual_seed(plan['seed'])
    rows=read(exp/'unique_train.json');positive=next(i for i,r in enumerate(rows) if any(int(b[0])<4 for b in r['boxes']))
    negative=next(i for i,r in enumerate(rows) if not any(int(b[0])<4 for b in r['boxes']))
    ids=[positive,negative];assert all(rows[i]['split']=='train' for i in ids)
    prior=Path(plan['reuse_feature_cache']);assert read(prior/'cache_result.json')['status']=='PASS'
    dep=Deployment(Path(plan['scale_profile']),Path(plan['checkpoint']));model=dep.model
    for name,param in model.named_parameters():param.requires_grad_(any(name.startswith(s) for s in plan['trainable_prefixes']))
    frozen={n:v.clone() for n,v in model.state_dict().items() if not any(n.startswith(s) for s in plan['trainable_prefixes'])}
    hyp=yaml.safe_load((PARENT/'runs/expanded_clean_004/hyp.yaml').read_text());hyp['cls']*=5/80;hyp['obj']*=.25;hyp['label_smoothing']=0.
    model.hyp=hyp;supervised=ComputeLoss(model);tail=QuantTail(model,dep.graph,dep.arrays)
    q={op:torch.from_numpy(np.array(np.load(prior/f'features/q15_{h}.npy',mmap_mode='r')[ids],dtype=np.float64)) for h,op in enumerate(CUT)}
    f={op:torch.from_numpy(np.array(np.load(prior/f'features/float_{h}.npy',mmap_mode='r')[ids])) for h,op in enumerate(CUT)}
    targets=read(exp/'targets.json');gt=torch.tensor([[b,*box] for b,i in enumerate(ids) for box in targets[i]],dtype=torch.float32).reshape(-1,6)
    qp,fp=tail(q,True),tail(f,False);qloss,_=supervised(qp,gt);floss,_=supervised(fp,gt)
    qnegative,n=negative_waste_loss(qp,gt,plan['negative_waste_topk']);fnegative,nf=negative_waste_loss(fp,gt,plan['negative_waste_topk'])
    assert n==nf==1 and qnegative>0 and fnegative>0
    loss=plan['quant_loss_weight']*qloss+plan['float_loss_weight']*floss+len(ids)*plan['negative_waste_strength']*(plan['quant_loss_weight']*qnegative+plan['float_loss_weight']*fnegative)
    loss.backward();trainable=[p for p in model.parameters() if p.requires_grad]
    assert len(trainable)==19 and all(p.grad is not None and bool(torch.isfinite(p.grad).all()) for p in trainable)
    assert all(torch.equal(v,model.state_dict()[n]) for n,v in frozen.items())
    save(exp/'preflight_model.json',dict(status='PASS',plan_sha256=sha(exp/'plan.json'),negative_images=1,
        train_only_input_image_sha256=[rows[i]['image_sha256'] for i in ids],trainable_tensors=len(trainable),
        all_gradients_present_finite=True,frozen_state_exact=True,q15_auxiliary=float(qnegative.detach()),
        float_auxiliary=float(fnegative.detach()),checkpoint_updated=False,model_accuracy_measured=False,final_test_read=False))
    print('NEGATIVE_WASTE_MODEL_PREFLIGHT_PASS',flush=True)


if __name__=='__main__':main()
