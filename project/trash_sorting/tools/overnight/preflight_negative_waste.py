"""Check the auxiliary objective's sample gating, gradients and stable score algebra."""
import argparse
from pathlib import Path
import torch
from adapt_quant_heads import save,sha
from negative_waste_supervision import negative_waste_loss


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--out',type=Path,required=True);a=p.parse_args()
    assert not a.out.exists();a.out.mkdir(parents=True)
    shapes=[(2,3,2,2,10),(2,3,3,3,10),(2,3,4,4,10)]
    preds=[torch.zeros(s,requires_grad=True) for s in shapes]
    # Image0 has a battery; image1 has only a hand. Background image1 is the
    # only admitted auxiliary sample. No gradient on any hand class logit.
    targets=torch.tensor([[0,2,.5,.5,.2,.2],[1,4,.5,.5,.4,.4]])
    loss,n=negative_waste_loss(preds,targets);assert n==1
    assert abs(float(loss)-(-torch.log(torch.tensor(.75))/2).item())<1e-7
    loss.backward()
    for prediction in preds:
        assert prediction.grad is not None and bool(torch.isfinite(prediction.grad).all())
        assert not bool(prediction.grad[0].any())
        assert not bool(prediction.grad[...,0:4].any()) and not bool(prediction.grad[...,9].any())
    assert sum(float(p.grad[1,...,4:9].abs().sum()) for p in preds)>0
    positive=[torch.zeros(s,requires_grad=True) for s in shapes]
    value,n=negative_waste_loss(positive,torch.tensor([[0,0,.5,.5,.2,.2],[1,3,.5,.5,.2,.2]]));assert n==0 and value==0
    empty=[torch.full(s,60.,requires_grad=True) for s in shapes]
    value,n=negative_waste_loss(empty,torch.empty((0,6)));assert n==2 and bool(torch.isfinite(value))
    value.backward();assert all(bool(torch.isfinite(p.grad).all()) for p in empty)
    helper=Path(__file__).with_name('negative_waste_supervision.py')
    save(a.out/'result.json',dict(status='PASS',source_sha256=sha(helper),
        checks=['Only complete-GT no-waste samples admitted','Positive waste image has zero auxiliary gradient',
                'Hand-class and bbox logits have zero direct auxiliary gradient',
                'Joint objectness/class score and full-batch normalization checked',
                'Extreme logits have finite loss and gradients'],
        actual_model_accuracy_measured=False,validation_used=False,final_test_read=False))
    print('NEGATIVE_WASTE_PREFLIGHT_PASS',flush=True)


if __name__=='__main__':main()
