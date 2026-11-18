"""Verify actual upstream loss gradients and hard-negative protection boundaries."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import sys


def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for k in ('yolo','weights','out'):p.add_argument('--'+k,type=Path,required=True)
    a=p.parse_args();a.out=a.out.resolve();a.out.mkdir(parents=True,exist_ok=False)
    os.environ['YOLOV5_CONFIG_DIR']=str(a.out/'config')
    os.environ['YOLOv5_AUTOINSTALL']='false'
    sys.path.insert(0,str(a.yolo.resolve()))
    import torch
    from utils.loss import ComputeLoss
    from hard_negative_objectness import hard_negative_loss_class
    torch.set_num_threads(2);torch.set_num_interop_threads(1)
    model=torch.load(a.weights,map_location='cpu')['model'].float().eval()
    base=ComputeLoss(model);instances=[]
    hard=hard_negative_loss_class(ComputeLoss,instances)(model)
    targets=torch.tensor([[0,4,.5,.5,.3,.3],[1,2,.5,.5,.1,.1]],dtype=torch.float32)
    seed=[torch.full((2,3,n,n,10),-12.) for n in (40,20,10)]
    _,_,positive_indices,_=base.build_targets(seed,targets)
    # The false anchor at image0's far upper corner is not a GT-positive.
    assert not any(b==0 and aa==0 and yy==0 and xx==0 for b,aa,yy,xx in zip(*(v.tolist() for v in positive_indices[0])))
    for level,(raw,index) in enumerate(zip(seed,positive_indices)):
        raw[index[0],index[1],index[2],index[3],4]=3.
        raw[index[0],index[1],index[2],index[3],7]=3.
    # Identical false-looking predictions: protect the image that has true waste.
    seed[0][:,0,0,0,4]=1.
    seed[0][:,0,0,0,7]=4.
    x=[r.clone().requires_grad_() for r in seed]
    y=[r.clone().requires_grad_() for r in seed]
    old,_=base(x,targets);new,_=hard(y,targets)
    old.backward();new.backward()
    assert float(new)>float(old)
    delta=[r.grad-q.grad for r,q in zip(y,x)]
    assert float(delta[0][0,0,0,0,4])>0 # Gradient descent lowers false objectness.
    assert torch.count_nonzero(delta[0])==1 and all(torch.count_nonzero(v)==0 for v in delta[1:])
    assert all(torch.count_nonzero(v[1])==0 for v in delta) # All real-waste image gradients unchanged.
    stats=hard.take_hard_negative_stats()
    assert stats['eligible_images']==1 and stats['mined_anchors']==1
    # Validation remains exactly the original loss, with no diagnostic counters.
    with torch.no_grad():
        before=base(seed,targets);after=hard(seed,targets)
        torch.testing.assert_close(before[0],after[0],rtol=0,atol=0)
        torch.testing.assert_close(before[1],after[1],rtol=0,atol=0)
    assert hard.take_hard_negative_stats()=={}
    # Entirely empty reviewed frames are valid negatives; top-k bounds mining.
    z=[torch.zeros(2,3,n,n,10,requires_grad=True) for n in (40,20,10)]
    # Make a waste class strictly larger than hand, while preserving leaf grads.
    with torch.no_grad():
        for r in z:r[...,5]=1.
    empty=torch.empty(0,6)
    v,_=hard(z,empty);v.backward()
    assert torch.isfinite(v) and all(torch.isfinite(r.grad).all() for r in z)
    assert hard.take_hard_negative_stats()['mined_anchors']==16
    report=dict(status='PASS_ACTUAL_UPSTREAM_GRADIENTS',weights_sha256=sha(a.weights),
                loss_sha256=sha(Path(__file__).with_name('hard_negative_objectness.py')),
                test_sha256=sha(__file__),mixed_batch_stats=stats,
                guarantees=['only selected false objectness gradient increases','all GT-positive anchors protected',
                            'all real-waste images unchanged','no extra class/box gradient',
                            'validation bit-exact to original','empty images finite','top-k per-image bound'],
                training_performed=False,hardware_accessed=False)
    (a.out/'result.json').write_text(json.dumps(report,indent=2),encoding='utf8')
    print('TEST_PASS actual upstream hard-negative gradients and boundaries',flush=True)


if __name__=='__main__':main()
