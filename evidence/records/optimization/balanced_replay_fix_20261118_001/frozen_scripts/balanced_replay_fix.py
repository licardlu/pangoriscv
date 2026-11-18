"""One fixed full-data replay pass after auditing YOLO's duplicate-path collapse."""
from datetime import datetime
import os
from pathlib import Path
import shutil
import subprocess
import time
from adapt_quant_heads import ROOT,read,save,sha
from train_full_orientation import verify_full_plan


def main():
    tools=Path(__file__).resolve().parent
    py=ROOT/'build/trash_train_env/Scripts/python.exe'
    runner=ROOT/'project/trash_sorting/training/train_four_bins.py'
    prior=ROOT/'build/bulk_twohour_20261118_001/experiment_001'
    parent=ROOT/'build/balanced_replay_fix_20261118_001';parent.mkdir(exist_ok=False)
    exp=parent/'experiment_001';exp.mkdir()
    data=parent/'dataset_001'
    deadline=datetime.fromisoformat('2026-11-18T18:19:51+00:00').timestamp()
    env=dict(os.environ,PYTHONUTF8='1')
    subprocess.run([str(py),str(ROOT/'project/trash_sorting/training/materialize_reviewed_draws.py'),
        '--manifest',str(prior.parent/'dataset_identity_recovery_001/manifest.json'),'--out',str(data)],cwd=ROOT,env=env,check=True)
    rows=read(data/'manifest.json');training=[r for r in rows if r['split']=='train']
    assert len(training)==19260 and len({r['prepared_image'] for r in training})==19260
    assert len({r['image_sha256'] for r in training})==9349
    first={}
    for r in training:first.setdefault(r['image_sha256'],r)
    calibration=read(prior/'calibration_reference.json')
    old_calibration_sha=sha(prior/'calibration_reference.json')
    for record in calibration['calibration_images']:
        row=first[record['sha256']]
        assert record['label_sha256']==row['label_sha256'] and sha(row['prepared_image'])==record['sha256']
        record['path']=row['prepared_image']
    calibration['selection']='Same160 predeclared bulk-run train photo hashes/classes/order; only paths remapped to first replay alias. No validation selection.'
    calibration['source_reference_sha256']=old_calibration_sha
    save(exp/'calibration_reference.json',calibration)
    plan=read(prior/'plan.json')
    plan.update(hypothesis='Correct observed loader path deduplication: one fixed complete replay pass from original deployed checkpoint, all9349 photo-file identities jointly sampled as19260 distinct hardlink aliases. No new photos. Previously frozen draw order/multiplicity now effective, emphasizing battery and personal/hand sources. Same architecture/freezing/loss/LR/batch, one fixed final epoch within original two-hour deadline; no validation checkpoint/threshold selection. Training initialization is original stage4, never the regressed bulk final.',
        manifest=str(data/'manifest.json'),manifest_sha256=sha(data/'manifest.json'),data_yaml_sha256=sha(data/'data.yaml'),
        data_report_sha256=sha(data/'result.json'),runner_sha256=sha(runner),epochs=1,
        checkpoint_selection='Fixed final first epoch last.pt; no checkpoint search',
        calibration_reference_sha256=sha(exp/'calibration_reference.json'),effective_loader_paths=19260,
        requested_draws_now_materialized=True,predecessor=str(prior),
        predecessor_finding='Bulk4epoch loader collapsed replay; battery49 float/44 Q15 vs54 float/55 Q15 baseline. Correct sampling rather than repeat unchanged training.',
        original_calibration_photo_identities_unchanged=True)
    save(exp/'plan.json',plan);verify_full_plan(exp)
    frozen=exp/'frozen_scripts';frozen.mkdir()
    for source in [Path(__file__),runner,ROOT/'project/trash_sorting/training/materialize_reviewed_draws.py',tools/'evaluate_quant_head_adaptation.py']:
        shutil.copyfile(source,frozen/source.name)
    shutil.copytree(prior.parent/'baseline_continuation_current_policy',parent/'baseline_continuation_current_policy')
    state=dict(status='prepared',steps=[],deadline_utc=plan['deadline_utc'],board_accessed=False,
               user_board_removed=True,actual_replay_paths=19260,unique_train_files=9349)
    blob=ROOT/'project/trash_sorting/candidates/continuation_023/source/yolo/model/model.bin'
    def persist():
        assert sha(blob)=='7a0765a6f275f3c06d838f924d73542783ca55e131509aa1b546efc98bd65728'
        save(exp/'pipeline_state.json',state)
    def command(name,args,reserve=0):
        remaining=deadline-time.time()-reserve;assert remaining>0
        step=dict(name=name,status='running',started_unix=time.time())
        state['steps'].append(step);state['status']=name;persist();print('START',name,flush=True)
        with (exp/(name+'.log')).open('x',encoding='utf8') as log:
            proc=subprocess.Popen([str(py),*map(str,args)],cwd=ROOT,env=env,stdout=log,stderr=subprocess.STDOUT)
            step['pid']=proc.pid;persist()
            try:rc=proc.wait(timeout=remaining)
            except subprocess.TimeoutExpired:
                subprocess.run(['taskkill','/PID',str(proc.pid),'/T','/F'],capture_output=True)
                raise RuntimeError('Original two-hour deadline/reserve reached: '+name)
        step.update(status='completed' if rc==0 else 'failed',returncode=rc,elapsed_s=time.time()-step['started_unix']);persist()
        if rc:raise RuntimeError(name+' failed; inspect log')
    try:
        command('training',[runner,'--yolo',ROOT/'build/overnight_20261116/upstream/yolov5-7.0','--data',data/'data.yaml',
            '--weights',plan['checkpoint'],'--project',exp,'--name','run','--epochs',1,'--fixed-final',
            '--freeze',4,'--freeze-bn','--batch',64,'--threads',8,'--lr0',.0001,'--warmup-bias-lr',.0001,
            '--cache','ram','--hard-negative-objectness',.02],reserve=720)
        assert read(exp/'run/provenance.json')['status']=='completed' and read(exp/'run/progress.json')['epoch']==1
        import numpy as np
        cache=np.load(data/'train.cache',allow_pickle=True).item()
        effective=[k for k in cache if k not in ['hash','version','msgs','results']]
        assert len(effective)==19260
        save(exp/'effective_loader_audit.json',dict(status='PASS',effective_samples=19260,unique_photo_files=9349,
            batches=301,last_batch=60,epochs_completed=1,aliases_not_new_photos=True,cache_sha256=sha(data/'train.cache')))
        target=exp/'training';target.mkdir();shutil.copyfile(exp/'run/weights/last.pt',target/'final.pt')
        provenance=read(exp/'run/provenance.json')
        save(target/'result.json',dict(status='PASS',epochs=1,elapsed_s=provenance['finished_unix']-provenance['started_unix'],
                                     checkpoint_sha256=sha(target/'final.pt'),final_epoch_only=True))
        command('evaluation',[tools/'evaluate_quant_head_adaptation.py','--experiment',exp,'--full-finetune'])
        command('continuation',[tools/'evaluate_qat_continuation.py','--experiment',exp])
        command('background_dev',[tools/'evaluate_held_background_dev.py','--deployment',exp/'evaluation/quant',
                                 '--checkpoint',target/'final.pt','--name',parent.name])
        command('targeted',[tools/'diagnose_targeted_regressions.py','--experiment',exp])
        ev=read(exp/'evaluation/state.json')
        state.update(status='COMPLETED_BALANCED_REPLAY_EVALUATION',accepted_offline=ev['accepted_offline'],
                     q15=ev['q15_oldval'],public_dev=ev['q15_publicdev'],gates=ev['gates'],finished_unix=time.time())
        save(exp/'delivery.json',dict(state,training=read(target/'result.json'),new_original_photos=0))
    except BaseException as error:state.update(status='failed',error=repr(error));raise
    finally:persist()


if __name__=='__main__':
    main()
