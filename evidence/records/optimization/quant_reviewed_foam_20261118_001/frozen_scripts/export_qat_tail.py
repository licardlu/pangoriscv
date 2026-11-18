"""Export trained coefficients under a predeclared frozen Q15 scale profile."""
import argparse,copy,time
from pathlib import Path
from adapt_quant_heads import ROOT,CP,DEP,PARENT,read,save,sha,setup

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--experiment',type=Path,required=True)
    p.add_argument('--out',type=Path,required=True);a=p.parse_args()
    exp=a.experiment.resolve();out=a.out.resolve();out.mkdir(parents=True,exist_ok=False);setup(out)
    from train_qat_tail import verify
    import numpy as np,torch
    from qat_tail import QuantTail,CUT
    from deployment_bundle import Deployment,float_graph
    from quant_yolov5n import preprocess
    from test_graph_torch import submodule
    from pack_deployment import pack
    plan=verify(exp);training=read(exp/'training/result.json');cp=exp/'training/final.pt';digest=sha(cp)
    assert training['checkpoint_sha256']==digest and training['status']=='PASS'
    model=torch.load(cp,map_location='cpu')['model'].float().eval()
    initialization=Path(plan['checkpoint']);profile=Path(plan['scale_profile'])
    original=torch.load(initialization,map_location='cpu')['model'].float().eval()
    for key,v in original.state_dict().items():
        if not any(key.startswith(s) for s in plan['trainable_prefixes']):assert torch.equal(v,model.state_dict()[key]),key
    graph=read(Path(plan.get('graph_source',PARENT/'quant_original160_006/graph.json')));graph['checkpoint_sha256']=digest
    expected={};handles=[]
    for op in graph['ops']:
        if op['name']=='CONV':
            module=submodule(model,op['module'][:-5] if op['module'].endswith('.conv') else op['module'])
            handles.append(module.register_forward_hook(lambda m,x,v,idx=op['idx']:expected.update({idx:v.detach().clone()})))
    torch.manual_seed(20261112)
    with torch.no_grad():
        x=torch.rand((1,3,320,320));model(x)
        for h in handles:h.remove()
        outputs=float_graph(model,graph,x)
        for idx,v in expected.items():assert torch.equal(v,outputs[idx]),idx
    save(out/'graph.json',graph)
    bundle=read(profile/'bundle.json');bundle['checkpoint_sha256']=digest
    bundle['note']='Frozen-scale exact-Q15 tail QAT, offline candidate only; not accepted FPGA release'
    bundle['frozen_scale_profile_sha256']=plan['bundle_sha256']
    arrays=np.load(profile/'parameters.npz');tail=QuantTail(model,bundle,arrays);generated=tail.export_arrays()
    directory=out/'bundle';directory.mkdir()
    for op in bundle['ops']:
        if op.get('execution')=='rtl_q15_conv':op['zero_multipliers']=int((generated[f"op{op['idx']}_multiplier"]==0).sum())
    np.savez(directory/'parameters.npz',**generated);save(directory/'bundle.json',bundle)
    for name in arrays.files:
        idx=int(name.split('_')[0][2:])
        if idx not in (65,73,81,82,83,84):np.testing.assert_array_equal(arrays[name],generated[name],err_msg=name)
    replay=Deployment(directory,cp);rows=read(ROOT/'build/quant_head_adapt_20261118_001/diagnosis/sample.json')[::10]
    checks=[]
    with torch.no_grad():
        for row in rows:
            image,_,_=preprocess(Path(row['prepared_image']),320);values={}
            replay.execute(image,lambda op,v:values.update({op['idx']:v.copy()}))
            actual={};tail({i:torch.from_numpy(values[i].astype(np.float64)) for i in CUT},True,
                lambda op,v:actual.update({op['idx']:v.numpy()}))
            for i in range(65,82):np.testing.assert_array_equal(values[i],actual[i],err_msg=f'export op{i}')
            checks.append(dict(image_sha256=row['image_sha256'],primary_bin=row['primary_bin'],nonhead_bit_exact=True))
    packed=pack(directory,out/'packed')
    classes=['kitchen','recyclable','hazardous','other','hand']
    assert graph['classes']==classes
    packed.update(classes=classes,raw_model_classes=5,anchors=graph['anchors'],strides=graph['strides'],
        checkpoint_sha256=digest,hand_locator_class=4)
    assert all(packed['tensors'][i]['c']==30 and packed['tensors'][i]['padded_c']==32 for i in packed['outputs'])
    save(out/'packed/memory_map.json',packed)
    reference=read(Path(plan.get('scale_provenance',PARENT/'quant_original160_006/provenance.json')))
    calibration_reference_note=None
    if 'ordered_calibration_identity_sha256' not in reference:
        companion=ROOT/'build/tonight_20261117/quant_frozen_replay_001'
        assert sha(companion/'provenance.json')=='61eb1673c25d79748b680612f5a7ca4fad40d7c7afb5c8de95c0eb377491649c'
        verified=read(companion/'provenance.json')
        assert verified['checkpoint_sha256']==plan['checkpoint_sha256']
        assert [r['sha256'] for r in reference['calibration_images']]==[r['sha256'] for r in verified['calibration_images']]
        companion_arrays=np.load(companion/'bundle/parameters.npz')
        assert set(companion_arrays.files)==set(arrays.files)
        for name in arrays.files:np.testing.assert_array_equal(arrays[name],companion_arrays[name],err_msg=name)
        calibration_reference_note='Historical provenance predates ordered identity; used existing verified replay with identical ordered image SHA list and every profile array bit-exact. No calibration rerun.'
        reference=verified
    provenance=dict(checkpoint=str(cp),checkpoint_sha256=digest,graph_check='All float convolutions/heads bit-exact to actual saved checkpoint',
        quantization='Fixed-profile QAT, no new max calibration or validation-based scale adjustment',
        scale_profile_source=str(profile),scale_profile_sha256=plan['bundle_sha256'],
        ordered_calibration_identity_sha256=reference['ordered_calibration_identity_sha256'],
        calibration_images=reference['calibration_images'],calibration_scope='Historical 160 train images used to derive initial frozen scales; not reintroduced to gradient training',
        calibration_reference_compatibility=calibration_reference_note,
        train_only_export_checks=checks,training_plan_sha256=sha(exp/'plan.json'),
        trained_q15_ops=[65,73,81],trained_heads=[82,83,84],created_unix=time.time(),scope='Offline only, not FPGA release')
    save(out/'provenance.json',provenance);print('FROZEN_SCALE_QAT_EXPORT_PASS',flush=True)

if __name__=='__main__':main()
