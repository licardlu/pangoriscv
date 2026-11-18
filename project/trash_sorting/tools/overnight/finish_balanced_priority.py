"""Adopt the unchanged active training worker; prioritize battery before hard cutoff."""
import argparse
from datetime import datetime
import os
from pathlib import Path
import shutil
import subprocess
import time
import psutil
from adapt_quant_heads import ROOT,read,save,sha


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--training-pid',type=int,required=True)
    a=p.parse_args();parent=ROOT/'build/balanced_replay_fix_20261118_001';exp=parent/'experiment_001'
    state=read(exp/'pipeline_state.json');assert state['status']=='training'
    assert state['steps'][0]['pid']==a.training_pid
    worker=psutil.Process(a.training_pid)
    assert 'train_four_bins.py' in ' '.join(worker.cmdline())
    shutil.copyfile(exp/'pipeline_state.json',exp/'pipeline_state_before_priority_adoption.json')
    state.update(monitor='finish_balanced_priority',status='training',
        reserve_revision='Keep original hard deadline; avoid preempting almost-completed fixed epoch at an internal12min reserve. Prioritize fixed battery/glass/empty-hand diagnostics before any incomplete full-set checks.',
        training_restarted=False,acceptance_gates_modified=False)
    plan=read(exp/'plan.json');deadline=datetime.fromisoformat(plan['deadline_utc']).timestamp()
    tools=Path(__file__).resolve().parent;py=ROOT/'build/trash_train_env/Scripts/python.exe';env=dict(os.environ,PYTHONUTF8='1')
    blob=ROOT/'project/trash_sorting/candidates/continuation_023/source/yolo/model/model.bin'
    def persist():
        assert sha(blob)=='7a0765a6f275f3c06d838f924d73542783ca55e131509aa1b546efc98bd65728'
        save(exp/'pipeline_state.json',state)
    def command(name,args):
        remaining=deadline-time.time();assert remaining>0
        step=dict(name=name,status='running',started_unix=time.time());state['steps'].append(step);state['status']=name;persist()
        print('START',name,flush=True)
        with (exp/(name+'.log')).open('x',encoding='utf8') as log:
            process=subprocess.Popen([str(py),*map(str,args)],cwd=ROOT,env=env,stdout=log,stderr=subprocess.STDOUT)
            step['pid']=process.pid;persist()
            try:rc=process.wait(timeout=remaining)
            except subprocess.TimeoutExpired:
                subprocess.run(['taskkill','/PID',str(process.pid),'/T','/F'],capture_output=True)
                raise RuntimeError('Original two-hour hard deadline reached during '+name)
        step.update(status='completed' if rc==0 else 'failed',returncode=rc,elapsed_s=time.time()-step['started_unix']);persist()
        if rc:raise RuntimeError(name+' failed')
    persist()
    save(exp/'priority_monitor_ready.json',dict(pid=os.getpid(),training_pid=a.training_pid,training_not_stopped=True))
    try:
        try:worker.wait(timeout=max(0,deadline-time.time()))
        except psutil.TimeoutExpired:
            subprocess.run(['taskkill','/PID',str(a.training_pid),'/T','/F'],capture_output=True)
            raise RuntimeError('Training reached original hard deadline')
        provenance=read(exp/'run/provenance.json');progress=read(exp/'run/progress.json')
        assert provenance['status']=='completed' and progress['epoch']==1
        state['steps'][0].update(status='completed',returncode=0,elapsed_s=time.time()-state['steps'][0]['started_unix'])
        import numpy as np
        cache=np.load(parent/'dataset_001/train.cache',allow_pickle=True).item()
        effective=[k for k in cache if k not in ['hash','version','msgs','results']];assert len(effective)==19260
        assert progress['hard_negative_objectness']['training_batches']==301
        save(exp/'effective_loader_audit.json',dict(status='PASS',effective_samples=19260,unique_photo_files=9349,
            batches=301,last_batch=60,epochs_completed=1,aliases_not_new_photos=True))
        target=exp/'training';target.mkdir();cp=target/'final.pt';shutil.copyfile(exp/'run/weights/last.pt',cp)
        digest=sha(cp);save(target/'result.json',dict(status='PASS',epochs=1,elapsed_s=provenance['finished_unix']-provenance['started_unix'],
                                                  checkpoint_sha256=digest,final_epoch_only=True))
        out=exp/'priority_evaluation';out.mkdir();quant=out/'quant'
        command('priority_quantize',[tools/'prepare_deployment.py','--out',quant,'--yolo',ROOT/'build/overnight_20261116/upstream/yolov5-7.0',
            '--data',parent/'dataset_001','--checkpoint',cp,'--expected-checkpoint-sha256',digest,'--include-hand',
            '--calibration-from',exp/'calibration_reference.json','--expected-calibration-sha256',sha(exp/'calibration_reference.json')])
        # Fixed cohorts from the unchanged original val metadata, never predictions.
        manifest=read(plan['manifest']);truth={Path(r['prepared_image']).stem:r for r in manifest if r['split']=='val'}
        allphotos=ROOT/'build/overnight_20261116/numeric_allval_001';all_inventory=read(allphotos/'inventory.json')
        all_truth=read(allphotos/'truth.json');photos=out/'fixed_cohorts';photos.mkdir()
        cohorts={}
        for stem,row in truth.items():
            if row['source']=='personal_电池':cohorts[stem]='battery'
            elif '/glass/' in str(row.get('image','')).replace('\\','/').lower():cohorts[stem]='glass'
            elif not any(int(b[0])<4 for b in row['boxes']):cohorts[stem]='empty_hand'
        inventory=sorted([r for r in all_inventory if Path(r['path']).stem in cohorts],
                         key=lambda r:({'battery':0,'glass':1,'empty_hand':2}[cohorts[Path(r['path']).stem]],r['id']))
        assert len(inventory)==60+242+136
        save(photos/'inventory.json',inventory);save(photos/'truth.json',{str(r['id']):all_truth[str(r['id'])] for r in inventory})
        command('priority_numeric',[tools/'check_deployment.py','--deployment',quant,'--yolo',ROOT/'build/overnight_20261116/upstream/yolov5-7.0',
            '--cc',ROOT/'build/overnight_20261116/cc_adapter.exe','--clang-host','--exact-q16-head','--out',out/'numeric',
            '--checkpoint',cp,'--expected-checkpoint-sha256',digest,'--source-dir',ROOT/'project/trash_sorting/candidates/continuation_023/source',
            '--photos',photos,'--linear-o2','--compact-scratch'])
        command('priority_score',[tools/'score_numeric_validation.py','--numeric',out/'numeric','--photos',photos,
            '--manifest',plan['manifest'],'--policy-replay',ROOT/'build/public_20k_20261117_001/replay_oldval_004',
            '--source-dir',ROOT/'project/trash_sorting/candidates/continuation_023/source','--out',out/'score'])
        decisions=read(out/'score/decisions.json');baseline=read(ROOT/'build/quant_head_adapt_20261118_001/baseline_q15_current_policy/decisions.json')
        counts={}
        for group in ['battery','glass','empty_hand']:
            ids=[stem for stem,g in cohorts.items() if g==group]
            counts[group]=dict(images=len(ids),baseline_correct=sum(baseline[s]['correct_class_and_iou050'] for s in ids),
                candidate_correct=sum(decisions[s]['correct_class_and_iou050'] for s in ids),
                baseline_false=sum(bool(baseline[s]['selected']) for s in ids) if group=='empty_hand' else None,
                candidate_false=sum(bool(decisions[s]['selected']) for s in ids) if group=='empty_hand' else None,
                gains=[s for s in ids if decisions[s]['correct_class_and_iou050'] and not baseline[s]['correct_class_and_iou050']],
                regressions=[s for s in ids if baseline[s]['correct_class_and_iou050'] and not decisions[s]['correct_class_and_iou050']])
        save(out/'cohort_results.json',dict(status='COMPLETED_FIXED_COHORT_DIAGNOSTIC',counts=counts,
            checkpoint_sha256=digest,all_acceptance_checks_completed=False,accepted_offline=False,
            final_test_read=False,photos_selected_by_frozen_gt_not_predictions=True,subset_not_full_accuracy=True))
        # Full checks remain useful if time permits. Fixed-cohort result is retained
        # even if the original hard cutoff interrupts the full evaluation.
        command('evaluation',[tools/'evaluate_quant_head_adaptation.py','--experiment',exp,'--full-finetune'])
        ev=read(exp/'evaluation/state.json')
        state.update(status='COMPLETED_BALANCED_REPLAY_EVALUATION',accepted_offline=ev['accepted_offline'],
                     q15=ev['q15_oldval'],public_dev=ev['q15_publicdev'],gates=ev['gates'],finished_unix=time.time())
    except BaseException as error:state.update(status='failed',error=repr(error));raise
    finally:persist()


if __name__=='__main__':
    main()
