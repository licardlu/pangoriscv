"""Execute one frozen offline QAT after a specified predecessor completes.

This is a same-task work queue, not a scheduler or an automatic model deployment.
Failures stop the queue with saved evidence; no blind retries or extra experiments.
"""
import argparse
from datetime import datetime,timezone
import os
from pathlib import Path
import shutil
import subprocess
import time

from adapt_quant_heads import ROOT,read,save,sha
from train_qat_tail import verify


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--experiment',type=Path,required=True)
    p.add_argument('--wait-state',type=Path,required=True)
    p.add_argument('--wait-status',required=True)
    p.add_argument('--name',required=True)
    p.add_argument('--latest-start',required=True,help='Explicit timezone-aware ISO timestamp')
    a = p.parse_args(); exp=a.experiment.resolve(); verify(exp)
    assert a.name and all(c.isalnum() or c=='_' for c in a.name)
    latest = datetime.fromisoformat(a.latest_start.replace('Z','+00:00'))
    assert latest.tzinfo is not None
    path = exp/'pipeline_state.json'; assert not path.exists()
    tools = Path(__file__).parent; py=ROOT/'build/trash_train_env/Scripts/python.exe'
    env=dict(os.environ,PYTHONUTF8='1'); state=dict(status='waiting_predecessor',steps=[],
        predecessor=str(a.wait_state.resolve()),predecessor_required_status=a.wait_status,
        latest_start_utc=latest.astimezone(timezone.utc).isoformat(),board_accessed=False)
    blob=ROOT/'project/trash_sorting/candidates/continuation_023/source/yolo/model/model.bin'
    def persist():
        assert sha(blob)=='7a0765a6f275f3c06d838f924d73542783ca55e131509aa1b546efc98bd65728'
        save(path,state)
    def run(name,args):
        state['status']=name;step=dict(name=name,started_unix=time.time(),status='running')
        state['steps'].append(step);persist();print('START',name,flush=True)
        with (exp/(name+'.log')).open('x',encoding='utf8') as log:
            proc=subprocess.run([str(py),*map(str,args)],cwd=ROOT,env=env,stdout=log,stderr=subprocess.STDOUT)
        step.update(returncode=proc.returncode,elapsed_s=time.time()-step['started_unix'],
                    status='completed' if proc.returncode==0 else 'failed');persist()
        if proc.returncode:
            raise RuntimeError(name+' failed; inspect saved log before recovery')
        print('DONE',name,flush=True)
    try:
        persist()
        while True:
            previous=read(a.wait_state)['status']
            if previous==a.wait_status:
                break
            if previous=='failed' or previous.startswith('DEFERRED_'):
                raise RuntimeError('Predecessor did not complete: '+previous)
            if datetime.now(timezone.utc)>latest:
                state['status']='DEFERRED_TOO_LATE_BEFORE_NOON';persist();return
            time.sleep(10)
        if datetime.now(timezone.utc)>latest:
            state['status']='DEFERRED_TOO_LATE_BEFORE_NOON';persist();return
        baseline=ROOT/'build/quant_tail_20261118_001/baseline_continuation_current_policy'
        shutil.copytree(baseline,exp.parent/'baseline_continuation_current_policy')
        run('cache',[tools/'train_qat_tail.py','cache','--out',exp])
        run('train',[tools/'train_qat_tail.py','train','--out',exp])
        run('evaluation',[tools/'evaluate_quant_head_adaptation.py','--experiment',exp,'--qat-tail'])
        run('continuation',[tools/'evaluate_qat_continuation.py','--experiment',exp])
        run('gallery',[tools/'render_quant_comparison.py','--experiment',exp,
            '--baseline-root',ROOT/'build/quant_head_adapt_20261118_001'])
        run('coverage',[tools/'summarize_recognition_coverage.py','--experiment',exp,
            '--out',exp/'evaluation/recognition_coverage'])
        run('background_dev',[tools/'evaluate_held_background_dev.py','--deployment',exp/'evaluation/quant',
            '--checkpoint',exp/'training/final.pt','--name',a.name])
        run('archive',[tools/'record_qat_comparison.py','--experiment',exp,'--name',a.name])
        state['status']='COMPLETED_OFFLINE_REVIEWED_SHAPE_QAT'
    except BaseException as error:
        state.update(status='failed',error=repr(error));raise
    finally:
        persist()


if __name__ == '__main__':
    main()
