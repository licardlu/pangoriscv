"""Train-only equality and gradient preflight before a QAT experiment."""
import argparse,time
from pathlib import Path
from adapt_quant_heads import ROOT,CP,DEP,PARENT,read,save,setup,sha

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--out',type=Path,required=True)
    a=p.parse_args();a.out.mkdir(parents=True,exist_ok=False);setup(a.out)
    import numpy as np,torch,yaml
    from deployment_bundle import Deployment
    from quant_yolov5n import preprocess
    from qat_tail import QuantTail,CUT
    from utils.loss import ComputeLoss
    dep=Deployment(DEP,CP);tail=QuantTail(dep.model,dep.graph,dep.arrays)
    # At initialization all exported integer coefficients must equal the
    # independent original deployment calibration, including frozen convs.
    generated=tail.export_arrays()
    for k in dep.arrays.files:np.testing.assert_array_equal(generated[k],dep.arrays[k],err_msg=k)
    rows=read(ROOT/'build/quant_head_adapt_20261118_001/diagnosis/sample.json')[::10]
    checks=[]
    with torch.no_grad():
        for r in rows:
            image,_,_=preprocess(Path(r['prepared_image']),320)
            expected={}
            dep.execute(image,lambda op,v:expected.update({op['idx']:v.copy()}))
            features={i:torch.from_numpy(expected[i].astype(np.float64)) for i in CUT}
            actual={}
            start=time.time();tail(features,True,lambda op,v:actual.update({op['idx']:v.numpy()}))
            for op in dep.graph['ops'][65:]:
                i=op['idx']
                if i<82:np.testing.assert_array_equal(actual[i],expected[i],err_msg=f'op{i}')
                else:np.testing.assert_allclose(actual[i],expected[i],atol=.001,rtol=0,err_msg=f'Q16 head{i}')
            checks.append(dict(image_sha256=r['image_sha256'],elapsed_s=time.time()-start,nonhead_bit_exact=True))
    # Check actual gradient propagation across quantized concat and later
    # frozen convolutions, with BN and earlier extractor held unchanged.
    model=dep.model
    names=['model.17.cv3.conv','model.20.cv3.conv','model.23.cv3.conv','model.24.m.']
    for n,v in model.named_parameters():v.requires_grad_(any(n.startswith(s) for s in names))
    hyp=yaml.safe_load((PARENT/'runs/expanded_clean_004/hyp.yaml').read_text())
    hyp['cls']*=5/80;hyp['obj']*=.25;hyp['label_smoothing']=0.;model.hyp=hyp
    lossfn=ComputeLoss(model)
    target=torch.tensor([[0,0,.5,.5,.3,.3]],dtype=torch.float32)
    started=time.time();prediction=tail(features,True);loss,_=lossfn(prediction,target);loss.backward()
    grads={n:dict(finite=bool(torch.isfinite(v.grad).all()),nonzero=int(torch.count_nonzero(v.grad))) for n,v in model.named_parameters() if v.requires_grad}
    assert all(r['finite'] and r['nonzero']>0 for r in grads.values())
    elapsed=time.time()-started
    torch.optim.AdamW([p for p in model.parameters() if p.requires_grad],lr=1e-5).step()
    # Recheck exported coefficients after a real parameter update; the
    # original deployment executor is independent of the STE graph.
    testbundle=a.out/'post_step_export';testbundle.mkdir()
    np.savez(testbundle/'parameters.npz',**tail.export_arrays())
    save(testbundle/'bundle.json',dep.graph)
    reference=Deployment(testbundle,CP)
    expected={}
    with torch.no_grad():
        reference.execute(image,lambda op,v:expected.update({op['idx']:v.copy()}))
        actual={}
        tail(features,True,lambda op,v:actual.update({op['idx']:v.numpy()}))
    for i in range(65,82):np.testing.assert_array_equal(actual[i],expected[i],err_msg=f'post-update op{i}')
    save(a.out/'result.json',dict(status='PASS',checkpoint_sha256=sha(CP),bundle_sha256=sha(DEP/'bundle.json'),
        exact_export_parameter_arrays=len(generated),forward_checks=checks,train_only=True,
        selected_parameter_gradients=grads,one_image_forward_backward_s=elapsed,
        post_gradient_step_nonhead_export_bit_exact=True,
        gradient_target='Synthetic geometry only for arithmetic gradient connectivity; no checkpoint saved.',
        frozen_scale_profile=True,training_started=False))
    print(read(a.out/'result.json'),flush=True)

if __name__=='__main__':main()
