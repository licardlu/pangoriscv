"""Run the predeclared new-battery QAT after the current longer experiment."""
import os
from pathlib import Path
import shutil
import subprocess
import time

from adapt_quant_heads import ROOT, read, save, sha


def main():
    exp=ROOT/'build/quant_extras_battery_20261118_001/experiment_001'
    path=exp/'pipeline_state.json';assert not path.exists()
    tools=Path(__file__).parent;py=ROOT/'build/trash_train_env/Scripts/python.exe'
    env=dict(os.environ,PYTHONUTF8='1');state=dict(status='waiting_full_continuation',steps=[])
    blob=ROOT/'project/trash_sorting/candidates/continuation_023/source/yolo/model/model.bin'
    def persist():
        assert sha(blob)=='7a0765a6f275f3c06d838f924d73542783ca55e131509aa1b546efc98bd65728'
        save(path,state)
    def run(name,args):
        state['status']=name;step=dict(name=name,started_unix=time.time(),status='running')
        state['steps'].append(step);persist();print('START',name,flush=True)
        with (exp/(name+'.log')).open('x',encoding='utf8') as log:
            p=subprocess.run([str(py),*map(str,args)],cwd=ROOT,env=env,stdout=log,stderr=subprocess.STDOUT)
        step.update(returncode=p.returncode,elapsed_s=time.time()-step['started_unix'],status='completed' if p.returncode==0 else 'failed');persist()
        if p.returncode:raise RuntimeError(name+' failed')
        print('DONE',name,flush=True)
    try:
        persist()
        prior=ROOT/'build/full_orientation_20261118_001/experiment_001/pipeline_state.json'
        while read(prior)['status']!='COMPLETED_OFFLINE_FULL_CONTINUATION':
            assert read(prior)['status']!='failed','Inspect full-training failure before starting new experiment'
            # Latest start 10:00 Beijing, leaving two hours for cache/train/review.
            if time.time()>1794967200:
                state['status']='DEFERRED_TOO_LATE_BEFORE_NOON';persist();return
            time.sleep(10)
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
            '--checkpoint',exp/'training/final.pt','--name','extras_qat_001'])
        run('archive',[tools/'record_qat_comparison.py','--experiment',exp,'--name','quant_extras_battery_20261118_001'])
        state['status']='COMPLETED_OFFLINE_NEW_BATTERY_QAT'
    except BaseException as error:
        state.update(status='failed',error=repr(error));raise
    finally:persist()


if __name__=='__main__':main()
