"""Assess the frozen small outdoor development set under the current C selector."""
import argparse
import os
from pathlib import Path
import subprocess
import time

from adapt_quant_heads import ROOT, read, save, sha
from evaluate_public_expansion import scores


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--deployment',type=Path,required=True);p.add_argument('--checkpoint',type=Path,required=True)
    p.add_argument('--name',required=True);a=p.parse_args()
    assert all(c.isalnum() or c=='_' for c in a.name)
    root=ROOT/'build/held_background_dev_20261118_001'
    out=root/a.name;out.mkdir(exist_ok=False)
    data=root/'dataset_001';manifest=data/'manifest.json';report=read(data/'result.json')
    assert report['status']=='FROZEN_DEVELOPMENT_ONLY_NEVER_TRAIN' and sha(manifest)==report['manifest_sha256']
    cp=a.checkpoint.resolve();digest=sha(cp);deployment=a.deployment.resolve()
    source=ROOT/'project/trash_sorting/candidates/continuation_023/source'
    blob=source/'yolo/model/model.bin';oldsha=sha(blob)
    assert oldsha=='7a0765a6f275f3c06d838f924d73542783ca55e131509aa1b546efc98bd65728'
    tools=Path(__file__).parent;py=ROOT/'build/trash_train_env/Scripts/python.exe'
    env=dict(os.environ,PYTHONUTF8='1');photos=root/'numeric_inventory_001'
    steps=[('numeric',[tools/'check_deployment.py','--deployment',deployment,'--yolo',ROOT/'build/overnight_20261116/upstream/yolov5-7.0',
        '--cc',ROOT/'build/overnight_20261116/cc_adapter.exe','--clang-host','--exact-q16-head',
        '--out',out/'numeric','--checkpoint',cp,'--expected-checkpoint-sha256',digest,
        '--source-dir',source,'--photos',photos,'--linear-o2','--compact-scratch']),
        ('score',[tools/'score_numeric_validation.py','--numeric',out/'numeric','--photos',photos,
        '--manifest',manifest,'--policy-replay',ROOT/'build/public_20k_20261117_001/replay_oldval_004',
        '--source-dir',source,'--out',out/'score'])]
    state=dict(status='running',checkpoint_sha256=digest,manifest_sha256=sha(manifest),steps=[])
    try:
        for name,args in steps:
            print('START',name,flush=True);step=dict(name=name,started_unix=time.time(),status='running')
            state['steps'].append(step);save(out/'state.json',state)
            with (out/(name+'.log')).open('x',encoding='utf8') as log:
                subprocess.run([str(py),*map(str,args)],cwd=ROOT,env=env,stdout=log,stderr=subprocess.STDOUT,check=True)
            step.update(status='completed',elapsed_s=time.time()-step['started_unix'])
        decisions=read(out/'score/decisions.json');counts=scores(decisions,manifest)
        state.update(status='COMPLETED_DEVELOPMENT_DIAGNOSTIC',counts=counts,
            fixed_conf025_iou050=read(out/'score/result.json')['fixed_conf025_iou050'],
            empty_misselections=sorted(k for k,d in decisions.items() if '_empty_' in k and d['selected']),
            gates_modified=False,board_accessed=False,test_files_read=False,
            limitations=report['limitations'])
        print(counts,flush=True)
    except BaseException as error:
        state.update(status='failed',error=repr(error));raise
    finally:
        assert sha(blob)==oldsha and sha(cp)==digest
        save(out/'state.json',state)


if __name__=='__main__':main()
