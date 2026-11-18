"""Train-only diagnosis of frozen FPGA quantization; never reads held-out images."""
import argparse, hashlib, json, os, sys, time, types
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]

def sha(p):
    return hashlib.sha256(Path(p).read_bytes()).hexdigest()

def setup(out):
    out.mkdir(parents=True,exist_ok=True)
    os.environ['YOLOv5_AUTOINSTALL'] = 'false'
    os.environ['YOLOV5_CONFIG_DIR'] = str(out / 'config')
    sys.path.insert(0, str(ROOT / 'build/overnight_20261116/upstream/yolov5-7.0'))
    sys.path.insert(0, str(ROOT / 'extensions/yolo/scripts'))
    import export_graph
    import models.common, models.yolo, models.experimental
    pkg = types.ModuleType('yolov5')
    pkg.models = types.ModuleType('yolov5.models')
    sys.modules.update({'yolov5': pkg, 'yolov5.models': pkg.models})
    for n in ('common', 'yolo', 'experimental'):
        sys.modules['yolov5.models.' + n] = sys.modules['models.' + n]
    import torch, cv2
    torch.set_num_threads(4)
    cv2.setNumThreads(0)

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--out', type=Path, required=True)
    p.add_argument('--checkpoint', type=Path, required=True)
    p.add_argument('--deployment', type=Path, required=True)
    p.add_argument('--manifest', type=Path, required=True)
    a = p.parse_args()
    a.out.mkdir(parents=True, exist_ok=False)
    setup(a.out)
    import numpy as np, torch
    from deployment_bundle import Deployment, float_graph
    from quant_yolov5n import preprocess
    rows = json.loads(a.manifest.read_text(encoding='utf8'))
    unique = {}
    for r in rows:
        if r['split'] == 'train':
            # Later reviewed manifests retain complete boxes but may omit the
            # optional source primary_bin field. This affects sampling only;
            # the manifest and every GT box remain unchanged.
            primary = r.get('primary_bin', next((int(b[0]) for b in r['boxes'] if int(b[0]) < 4), 4))
            unique.setdefault(r['image_sha256'], dict(r, primary_bin=primary))
    sample = []
    for c in range(5):
        candidates = sorted((r for r in unique.values() if r['primary_bin'] == c),
                            key=lambda r: hashlib.sha256(('diag20261117'+r['image_sha256']).encode()).hexdigest())
        sample.extend(candidates[:10])
    (a.out/'sample.json').write_text(json.dumps(sample, indent=2), encoding='utf8')
    dep = Deployment(a.deployment, a.checkpoint)
    assert dep.graph['checkpoint_sha256'] == sha(a.checkpoint)
    cp = torch.load(a.checkpoint, map_location='cpu')
    ema_diff = None
    if cp.get('ema') is not None:
        ema_diff = max(float((v.float()-cp['ema'].state_dict()[k].float()).abs().max())
                       for k,v in dep.model.state_dict().items())
    selected = [0, 8, 20, 35, 50, 65, 73, 81, 82, 83, 84]
    metrics = {str(i): [] for i in selected}
    started = time.time()
    with torch.no_grad():
        for n,r in enumerate(sample):
            path = Path(r['prepared_image'])
            assert sha(path) == r['image_sha256']
            im,_,_ = preprocess(path, 320)
            floating, quant = {}, {}
            def fcb(op,v,pre):
                if op['idx'] in selected:
                    floating[op['idx']] = v.numpy().copy()
            def qcb(op,v):
                if op['idx'] in selected:
                    quant[op['idx']] = v.copy()
            float_graph(dep.model,dep.graph,im,fcb)
            dep.execute(im,qcb)
            for i in selected:
                f=floating[i].astype(np.float64); raw=quant[i]
                q=raw.astype(np.float64)
                if i not in dep.graph['outputs']:
                    q*=dep.graph['ops'][i]['scale']
                err=q-f
                metrics[str(i)].append(dict(primary_bin=r['primary_bin'],
                    relative_rmse=float(np.sqrt((err**2).mean())/(np.sqrt((f**2).mean())+1e-12)),
                    mean_error=float(err.mean()),max_error=float(np.abs(err).max()),
                    cosine=float((f*q).sum()/(np.sqrt((f*f).sum()*(q*q).sum())+1e-12)),
                    output_clip_fraction=float(((raw==-128)|(raw==127)).mean()) if raw.dtype==np.int8 else None))
            print(f'diagnosis {n+1}/{len(sample)} elapsed={time.time()-started:.1f}',flush=True)
    result=dict(checkpoint_sha256=sha(a.checkpoint),manifest_sha256=sha(a.manifest),
        sample_sha256=sha(a.out/'sample.json'),train_only=True,ema_model_max_diff=ema_diff,
        elapsed_s=time.time()-started,images=len(sample),layers={},
        sampling_note='Up to10per source primary_bin; if absent, first waste GT class or4for no-waste rows. Fixed hash order. Sampling metadata only, GT unmodified.')
    for i,records in metrics.items():
        result['layers'][i]=dict(module=dep.graph['ops'][int(i)].get('module'),
            mean_relative_rmse=float(np.mean([r['relative_rmse'] for r in records])),
            mean_cosine=float(np.mean([r['cosine'] for r in records])),
            per_class={str(c):float(np.mean([r['relative_rmse'] for r in records if r['primary_bin']==c])) for c in range(5)},
            samples=records)
    (a.out/'result.json').write_text(json.dumps(result,indent=2),encoding='utf8')
    print(json.dumps({k:{x:y for x,y in v.items() if x!='samples'} for k,v in result['layers'].items()},indent=2))

if __name__=='__main__':
    main()
