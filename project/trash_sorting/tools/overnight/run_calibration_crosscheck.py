"""Finish the two missing cells of the frozen weight/calibration comparison."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[4]

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--out',type=Path,required=True)
    p.add_argument('--resume',action='store_true')
    p.add_argument('--policy-replay',type=Path,default=ROOT/'build/continuation_023_replay_threshold_007')
    a=p.parse_args();a.out=a.out.resolve();a.out.mkdir(parents=True,exist_ok=a.resume)
    source=ROOT/'project/trash_sorting/candidates/continuation_023/source'
    base=ROOT/'build/overnight_20261116';night=ROOT/'build/tonight_20261117'
    tools=ROOT/'project/trash_sorting/tools/overnight'
    env=os.environ.copy();env['PYTHONUTF8']='1'
    state=dict(status='running',pid=os.getpid(),test_used=False,board_touched=False,steps=[])
    if a.resume:
        state=json.loads((a.out/'state.json').read_text(encoding='utf8'))
        state.update(status='running',pid=os.getpid())
    def save():
        state['utc']=datetime.now(timezone.utc).isoformat()
        (a.out/'state.json').write_text(json.dumps(state,indent=2),encoding='utf8')
    def run(name,args):
        if a.resume and any(s['name']==name and s['status']=='completed' for s in state['steps']):return
        row=dict(name=name,command=[sys.executable,*map(str,args)],status='running')
        state['steps'].append(row);save()
        with (a.out/(name+'.log')).open('a' if a.resume else 'x',encoding='utf8') as log:
            r=subprocess.run(row['command'],cwd=ROOT,env=env,stdout=log,stderr=subprocess.STDOUT)
        row.update(status='completed' if r.returncode==0 else 'failed',returncode=r.returncode);save()
        if r.returncode:raise RuntimeError(name+' failed; see log')
    try:
        run('stage4_focused_calibration_numeric',[tools/'check_deployment.py',
            '--deployment',night/'quant_stage4_focused_calibration_001',
            '--yolo',base/'upstream/yolov5-7.0','--cc',base/'cc_adapter.exe',
            '--clang-host','--exact-q16-head','--out',night/'numeric_stage4_focused_calibration_001',
            '--checkpoint',base/'runs/continuation_stage4_002/weights/best.pt',
            '--expected-checkpoint-sha256','a4a0b1b04f83af1d114813e0512dd2c2fa5e7306fae16759824f136b3133021a',
            '--source-dir',source,'--photos',base/'numeric_allval_001','--linear-o2','--compact-scratch','--skip-fixtures'])
        for label,numeric in [('stage4_original',base/'numeric_stage4_allval_exact_001'),
                              ('stage4_focused',night/'numeric_stage4_focused_calibration_001'),
                              ('conservative_original',night/'numeric_conservative_original_calibration_001'),
                              ('conservative_focused',ROOT/'build/continuation_023_numeric_conservative_original_001')]:
            assert (numeric/'result.json').is_file(),'Required concurrent numeric run not complete: '+str(numeric)
            run(label+'_score',[tools/'score_numeric_validation.py','--numeric',numeric,
                '--photos',base/'numeric_allval_001','--manifest',base/'dataset_stage4/manifest.json',
                '--policy-replay',a.policy_replay,
                '--source-dir',source,'--out',a.out/(label+'_score')])
        scores={label:json.loads((a.out/(label+'_score/result.json')).read_text(encoding='utf8'))
                for label in ('stage4_original','stage4_focused','conservative_original','conservative_focused')}
        (a.out/'comparison.json').write_text(json.dumps({k:dict(model_sha256=v['model_sha256'],cohorts={c:r for c,r in v['cohorts'].items() if c in ('all','no_waste','material/public_glass') or c.startswith('source/personal_')}) for k,v in scores.items()},ensure_ascii=False,indent=2),encoding='utf8')
        state['status']='completed';state.pop('error',None);save()
    except BaseException as e:
        state.update(status='failed',error=repr(e));save();raise

if __name__=='__main__':main()
