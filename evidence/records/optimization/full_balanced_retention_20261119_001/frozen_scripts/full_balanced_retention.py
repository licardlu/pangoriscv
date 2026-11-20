"""Fixed eight-epoch balanced full-data continuation with automatic integer checks."""
import argparse
from collections import Counter
import ctypes
from datetime import datetime,timezone
import os
from pathlib import Path
import shutil
import subprocess
import time
from adapt_quant_heads import ROOT,read,save,sha
from train_full_orientation import verify_full_plan


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--name',required=True)
    a=parser.parse_args();assert all(c.isalnum() or c=='_' for c in a.name)
    parent=ROOT/'build'/a.name;parent.mkdir(exist_ok=False)
    exp=parent/'experiment_001';exp.mkdir()
    prior=ROOT/'build/balanced_replay_fix_20261118_001/experiment_001'
    plan=verify_full_plan(prior);data=Path(plan['manifest']).parent
    rows=read(plan['manifest']);train=[r for r in rows if r['split']=='train']
    assert len(train)==19260 and len({r['prepared_image'] for r in train})==19260
    unique={r['image_sha256']:r for r in train};assert len(unique)==9349
    import numpy as np
    cache=np.load(data/'train.cache',allow_pickle=True).item()
    keys=[k for k in cache if k not in ['hash','results','version','msgs']]
    assert len(keys)==19260 and set(keys)=={r['prepared_image'] for r in train}
    held={r['image_sha256'] for r in rows if r['split']!='train'}
    assert not set(unique)&held and all(r['split'] in ['train','val'] for r in rows)
    # Check actual bytes once per photo identity, not once per replay alias.
    for i,row in enumerate(unique.values()):
        assert sha(row['prepared_image'])==row['image_sha256'],row['prepared_image']
        assert sha(row['label'])==row['label_sha256']
        if (i+1)%2000==0:print('PREFLIGHT_IDENTITIES',i+1,flush=True)
    shutil.copyfile(prior/'calibration_reference.json',exp/'calibration_reference.json')
    runner=ROOT/'project/trash_sorting/training/train_four_bins.py'
    tools=Path(__file__).resolve().parent
    plan.update(hypothesis='One fixed eight-epoch joint continuation on all9349 reviewed file identities,19260 distinct replay paths/epoch. Retain original feature blocks0..9 and their BN, train remaining features and heads with3e-5 instead of1e-4 to reduce deployed-source/battery forgetting. Same complete five-class GT and GT-waste-free hard-negative objectness0.02; no failed-candidate initialization, no intermediate validation selection, no threshold adjustment. Longer lower-rate optimization addresses undertraining/source drift, and final acceptance still requires actual Q15/C checks.',
        epochs=8,freeze=10,freeze_bn=True,lr0=.00003,warmup_bias_lr=.00003,batch=64,threads=8,
        checkpoint_selection='Fixed final eighth epoch last.pt; no validation checkpoint search',
        runner_sha256=sha(runner),calibration_reference_sha256=sha(exp/'calibration_reference.json'),
        authorized_start_utc=datetime.now(timezone.utc).isoformat(),deadline_utc=None,
        predecessor_finding='One balanced epoch had53float/48integer battery; source/quant drift unresolved. Protect more early features and use lower learning rate, do not claim sampling alone fixes quantization.',
        estimated_training_hours='1.5-2.5 on current CPU; estimate only; actual log determines progress',
        data_reused_without_new_image_copies=True)
    save(exp/'plan.json',plan);verify_full_plan(exp)
    frozen=exp/'frozen_scripts';frozen.mkdir()
    for source in [Path(__file__),runner,runner.with_name('hard_negative_objectness.py'),tools/'evaluate_quant_head_adaptation.py',tools/'prepare_deployment.py']:
        shutil.copyfile(source,frozen/source.name)
    save(exp/'effective_loader_audit.json',dict(status='PASS_BEFORE_TRAINING',effective_paths=len(keys),
        unique_train_files=len(unique),samples_per_epoch=19260,planned_epochs=8,planned_primary_loads=154080,
        expected_batches_per_epoch=301,cache_sha256=sha(data/'train.cache'),new_original_photos=0,
        class_image_draws=dict(Counter(int(c) for r in train for c in {b[0] for b in r['boxes']})),
        original20000_photo_target_achieved=False,train_test_sha_disjoint=True))
    shutil.copytree(prior.parent/'baseline_continuation_current_policy',parent/'baseline_continuation_current_policy')
    py=ROOT/'build/trash_train_env/Scripts/python.exe';env=dict(os.environ,PYTHONUTF8='1')
    blob=ROOT/'project/trash_sorting/candidates/continuation_023/source/yolo/model/model.bin'
    state=dict(status='prepared',steps=[],board_accessed=False,scope='Offline only; no board or synthesis, routing, UART, TF/Flash; no final test reads',
               started_utc=datetime.now(timezone.utc).isoformat())
    def persist():
        assert sha(blob)=='7a0765a6f275f3c06d838f924d73542783ca55e131509aa1b546efc98bd65728'
        save(exp/'pipeline_state.json',state)
    def run(name,args):
        step=dict(name=name,status='running',started_unix=time.time());state['steps'].append(step);state['status']=name;persist()
        print('START',name,flush=True)
        with (exp/(name+'.log')).open('x',encoding='utf8') as log:
            proc=subprocess.Popen([str(py),*map(str,args)],cwd=ROOT,env=env,stdout=log,stderr=subprocess.STDOUT)
            step['pid']=proc.pid;persist();rc=proc.wait()
        step.update(status='completed' if rc==0 else 'failed',returncode=rc,elapsed_s=time.time()-step['started_unix']);persist()
        if rc:raise RuntimeError(name+' failed; inspect log instead of restarting')
    awake=ctypes.windll.kernel32.SetThreadExecutionState
    awake.argtypes=[ctypes.c_uint32];awake.restype=ctypes.c_uint32
    assert awake(0x80000001)
    try:
        run('training',[runner,'--yolo',ROOT/'build/overnight_20261116/upstream/yolov5-7.0','--data',data/'data.yaml',
            '--weights',plan['checkpoint'],'--project',exp,'--name','run','--epochs',8,'--fixed-final',
            '--freeze',10,'--freeze-bn','--batch',64,'--threads',8,'--lr0',.00003,'--warmup-bias-lr',.00003,
            '--cache','ram','--hard-negative-objectness',.02])
        provenance=read(exp/'run/provenance.json');progress=read(exp/'run/progress.json')
        assert provenance['status']=='completed' and progress['epoch']==8
        assert progress['hard_negative_objectness']['training_batches']==301
        target=exp/'training';target.mkdir();shutil.copyfile(exp/'run/weights/last.pt',target/'final.pt')
        save(target/'result.json',dict(status='PASS',epochs=8,elapsed_s=provenance['finished_unix']-provenance['started_unix'],
            checkpoint_sha256=sha(target/'final.pt'),final_epoch_only=True))
        run('evaluation',[tools/'evaluate_quant_head_adaptation.py','--experiment',exp,'--full-finetune','--frozen-calibration-only'])
        run('continuation',[tools/'evaluate_qat_continuation.py','--experiment',exp])
        run('background_dev',[tools/'evaluate_held_background_dev.py','--deployment',exp/'evaluation/quant',
            '--checkpoint',target/'final.pt','--name',a.name])
        run('targeted',[tools/'diagnose_targeted_regressions.py','--experiment',exp])
        run('gallery',[tools/'render_quant_comparison.py','--experiment',exp,'--baseline-root',ROOT/'build/quant_head_adapt_20261118_001'])
        run('coverage',[tools/'summarize_recognition_coverage.py','--experiment',exp,'--out',exp/'evaluation/recognition_coverage'])
        ev=read(exp/'evaluation/state.json')
        state.update(status='COMPLETED_FULL_BALANCED_RETENTION',accepted_offline=ev['accepted_offline'],
            q15=ev['q15_oldval'],public_dev=ev['q15_publicdev'],gates=ev['gates'],finished_utc=datetime.now(timezone.utc).isoformat())
        save(exp/'delivery.json',dict(state,training=read(target/'result.json'),actual_epochs=8,
            actual_samples_per_epoch=19260,actual_primary_samples_total=154080,unique_train_files=9349,new_original_photos=0))
        run('report',[tools/'report_full_balanced_retention.py','--experiment',exp])
        state['status']='COMPLETED_FULL_BALANCED_RETENTION'
    except BaseException as error:state.update(status='failed',error=repr(error));raise
    finally:
        state['awake_request_released']=bool(awake(0x80000000));persist()


if __name__=='__main__':
    main()
