"""Resume only evaluation after an audited upstream JPEG identity repair."""
from datetime import datetime
import os
from pathlib import Path
import shutil
import subprocess
import time
from adapt_quant_heads import ROOT, read, save, sha
from recover_bulk_image_identity import verify_recovery


def main():
    parent=ROOT/'build/bulk_twohour_20261118_001'
    exp=(parent/'experiment_001').resolve()
    tools=Path(__file__).resolve().parent
    verify_recovery(exp)
    old=read(exp/'pipeline_state.json')
    assert old['status']=='failed' and old['steps'][0]['status']=='completed'
    assert read(exp/'run/progress.json')['epoch']==4
    original=(exp/'evaluation').resolve()
    preserved=(exp/'evaluation_failed_jpeg_001').resolve()
    assert original.parent==preserved.parent==exp and not preserved.exists()
    shutil.copyfile(exp/'pipeline_state.json',exp/'pipeline_state_failed_jpeg_001.json')
    original.rename(preserved)
    state=dict(status='resuming_evaluation',steps=[old['steps'][0]],deadline_utc=old['deadline_utc'],
               board_accessed=False,training_repeated=False,
               preserved_failed_evaluation=str(preserved),image_identity_recovery_sha256=sha(exp/'image_identity_recovery.json'))
    deadline=datetime.fromisoformat(state['deadline_utc']).timestamp()
    py=ROOT/'build/trash_train_env/Scripts/python.exe'
    env=dict(os.environ,PYTHONUTF8='1')
    blob=ROOT/'project/trash_sorting/candidates/continuation_023/source/yolo/model/model.bin'
    def persist():
        assert sha(blob)=='7a0765a6f275f3c06d838f924d73542783ca55e131509aa1b546efc98bd65728'
        save(exp/'pipeline_state.json',state)
    def run(name,args):
        remaining=deadline-time.time()
        assert remaining>0
        step=dict(name=name,status='running',started_unix=time.time())
        state['steps'].append(step);state['status']=name;persist()
        print('START',name,flush=True)
        with (exp/('recovery_'+name+'.log')).open('x',encoding='utf8') as log:
            proc=subprocess.Popen([str(py),*map(str,args)],cwd=ROOT,env=env,stdout=log,stderr=subprocess.STDOUT)
            step['pid']=proc.pid;persist()
            try:rc=proc.wait(timeout=remaining)
            except subprocess.TimeoutExpired:
                subprocess.run(['taskkill','/PID',str(proc.pid),'/T','/F'],capture_output=True)
                raise RuntimeError('Deadline reached during '+name)
        step.update(status='completed' if rc==0 else 'failed',returncode=rc,elapsed_s=time.time()-step['started_unix']);persist()
        if rc:raise RuntimeError(name+' failed; inspect saved recovery log')
    try:
        run('evaluation',[tools/'evaluate_quant_head_adaptation.py','--experiment',exp,'--full-finetune','--image-identity-recovery'])
        run('continuation',[tools/'evaluate_qat_continuation.py','--experiment',exp])
        run('gallery',[tools/'render_quant_comparison.py','--experiment',exp,'--baseline-root',ROOT/'build/quant_head_adapt_20261118_001'])
        run('coverage',[tools/'summarize_recognition_coverage.py','--experiment',exp,'--out',exp/'evaluation/recognition_coverage'])
        run('background_dev',[tools/'evaluate_held_background_dev.py','--deployment',exp/'evaluation/quant',
                              '--checkpoint',exp/'training/final.pt','--name',parent.name])
        run('targeted_regressions',[tools/'diagnose_targeted_regressions.py','--experiment',exp])
        evaluation=read(exp/'evaluation/state.json')
        state.update(status='COMPLETED_BULK_OFFLINE_EVALUATION',accepted_offline=evaluation['accepted_offline'],
                     q15=evaluation['q15_oldval'],public_dev=evaluation['q15_publicdev'],gates=evaluation['gates'],finished_unix=time.time())
        save(exp/'delivery.json',dict(state,training=read(exp/'training/result.json'),
             actual_loader_audit=read(parent/'loader_audit_001/result.json'),
             unchanged_deployment_sha256=sha(blob),new_images=0))
    except BaseException as error:
        state.update(status='failed',error=repr(error));raise
    finally:persist()


if __name__=='__main__':
    main()
