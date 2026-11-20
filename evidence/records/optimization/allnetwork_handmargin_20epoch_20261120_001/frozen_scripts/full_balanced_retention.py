"""Fixed balanced all-class continuation with automatic integer checks."""
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
    parser.add_argument('--epochs',type=int,default=8)
    parser.add_argument('--native-teacher',action='store_true',
                        help='Joint native-five-class GT-gated preservation plus nonconflicting hand targets')
    parser.add_argument('--full-network',action='store_true',
                        help='Train every parameter while holding pretrained BN running statistics')
    parser.add_argument('--waste-hand-margin',type=float,default=0.,
                        help='GT-waste-only class separation; fixed strength, no decoder changes')
    parser.add_argument('--after',type=Path,help='Finish an already-running experiment before acquiring training CPU')
    a=parser.parse_args();assert all(c.isalnum() or c=='_' for c in a.name)
    assert a.epochs>0
    assert a.waste_hand_margin>=0
    if a.waste_hand_margin:assert a.full_network
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
    plan.update(epochs=a.epochs,checkpoint_selection=f'Fixed final epoch{a.epochs} last.pt; no validation checkpoint search')
    if a.full_network:
        a.native_teacher=True
        assert a.epochs>=20,'Full-network batch run requires explicitly budgeted >=20epochs'
    if a.native_teacher:
        preflight=ROOT/('build/allnetwork_margin_preflight_20261120_001/result.json' if a.waste_hand_margin else
                        ('build/allnetwork_teacher_preflight_20261119_001/result.json' if a.full_network else 'build/native_teacher_preflight_20261119_001/result.json'))
        checked=read(preflight);assert checked['status']=='PASS_ACTUAL_TRAIN_ONLY_NATIVE_TEACHER'
        assert checked['after_update']['matched_anchors_by_class']['2']>0
        plan.update(hypothesis=f'Fixed{a.epochs}-epoch all9349-file joint continuation, including battery, glass, all waste classes and hands on exactly19260 effective replay paths/epoch. The prior full-data8epoch float model forgot original batteries before quantization. Add GT-matched native-five-class original deployed float teacher strength5 and remove only hand target assignments that collide with actual waste anchors; keep every GT waste and nonconflicting hand assignment. Teacher must agree with GT class/conf>=.25/IoU>=.5; no pseudo labels. Initialize original deployment, never rejected weights. '+('Train every network parameter while holding pretrained BN running statistics.' if a.full_network else 'Keep freeze10/BN.')+' Keep3e-5,batch64,hardnegative.02 and fixed train160 calibration. Teacher and conflict handling change together; no isolated attribution, epoch/threshold sweep, validation training or acceptance relaxation.',
            preserve_teacher=plan['checkpoint'],teacher_sha256=plan['checkpoint_sha256'],
            preservation_strength=5.,disjoint_hand_targets=True,teacher_classes=5,full_network=a.full_network,
            native_teacher_preflight=str(preflight),native_teacher_preflight_sha256=sha(preflight),
            teacher_preservation_sha256=sha(runner.with_name('teacher_preservation.py')),
            disjoint_hand_loss_sha256=sha(runner.with_name('disjoint_hand_loss.py')),
            predecessor_finding='Full8epoch float1387/battery47/glass224/false2; Q15 1375/45/223/2. Wrong battery classes and misses precede quantization; add correct-GT original-native teacher and conflict-safe hand supervision, not more unchanged epochs.',
            estimated_training_hours='CPU live-teacher training: measure first epoch; approximately1-1.5hours for4epochs, then evaluation; estimate only')
    if a.full_network:
        assert checked['all_parameters_trainable'] and checked['trainable_parameters']==1770682
        plan.update(freeze=0,freeze_bn=False,hold_bn_statistics=True,all_parameters_trainable=True,
            planned_trainable_parameters=1770682,epochs=a.epochs,
            checkpoint_selection=f'Fixed final epoch{a.epochs}; no validation checkpoint search',save_period=-1,
            estimated_training_hours='All-parameter CPU training with live teacher; first actual epoch sets ETA. Budget20epochs, not a short3/4epoch trial.',
            predecessor_finding='User explicitly requested large-scale joint full-network training after a4epoch frozen-backbone run. Native4epoch float1474/battery53/glass231/false7. Keep original checkpoint initialization, GT-gated teacher and conflict handling; unfreeze all1,770,682 parameters for20fixedepochs. No from-scratch claim, no new-photo claim.')
    if a.after:plan.update(wait_after=str(a.after.resolve()))
    if a.waste_hand_margin:
        assert checked['waste_hand_margin']['strength']==a.waste_hand_margin
        train_audit=ROOT/'build/train_hand_interference_20261120_001/result.json'
        audited=read(train_audit)
        assert audited['status']=='COMPLETED_TRAIN_ONLY_DIAGNOSTIC' and not audited['validation_or_test_images_read']
        plan.update(waste_hand_margin=a.waste_hand_margin,waste_hand_margin_logit_gap=1.,
            waste_hand_margin_sha256=sha(runner.with_name('waste_hand_margin.py')),
            train_hand_audit=str(train_audit),train_hand_audit_sha256=sha(train_audit),
            hypothesis=plan['hypothesis']+' Add one fixed class-separation term at actual waste GT anchors, strength0.01 and logit margin1. Only hand and GT-waste class logits receive auxiliary gradients; actual hand targets, objectness and box supervision remain unchanged. Training-only155-image audit found extra hand boxes over batteries/pear; visually reviewed examples include genuine partial-hand boxes, which are NOT auto-relabeled or mined as negatives. No decoder/threshold changes. This is one new objective, not restarting the completed20epoch run.',
            predecessor_finding='Previous20epoch Q15 overall1461,battery52,glass232,false6; public656/712 and handheld57/77. Battery8errors include3missed detections and5selector failures. Preserve original initialization; train-side audit shows duplicate hand predictions at GT waste boxes. Extra relative class margin addresses that competition without suppressing all real hands.')
    save(exp/'plan.json',plan);verify_full_plan(exp)
    frozen=exp/'frozen_scripts';frozen.mkdir()
    for source in [Path(__file__),runner,runner.with_name('hard_negative_objectness.py'),tools/'evaluate_quant_head_adaptation.py',tools/'prepare_deployment.py']:
        shutil.copyfile(source,frozen/source.name)
    if a.native_teacher:
        for filename in ['teacher_preservation.py','disjoint_hand_loss.py','preflight_native_preservation.py','test_teacher_preservation.py']:
            shutil.copyfile(runner.with_name(filename),frozen/filename)
        shutil.copyfile(preflight,exp/'native_teacher_preflight.json')
    if a.waste_hand_margin:
        for filename in ['waste_hand_margin.py','test_waste_hand_margin.py']:
            shutil.copyfile(runner.with_name(filename),frozen/filename)
        shutil.copyfile(train_audit,exp/'train_hand_audit.json')
        shutil.copyfile(train_audit.with_name('unmatched_hands.png'),exp/'train_hand_audit.png')
    battery_sources=sorted({r['source'] for r in train if 'battery' in r['source'] and any(int(b[0])==2 for b in r['boxes'])})
    save(exp/'effective_loader_audit.json',dict(status='PASS_BEFORE_TRAINING',effective_paths=len(keys),
        unique_train_files=len(unique),samples_per_epoch=19260,planned_epochs=a.epochs,planned_primary_loads=19260*a.epochs,
        battery_named_source_rule=battery_sources,
        battery_named_source_unique_files=sum(r['source'] in battery_sources for r in unique.values()),
        battery_named_source_draws=sum(r['source'] in battery_sources for r in train),
        battery_count_note='Source names explicitly containing battery; hazardous totals also contain other materials. Neither counts new photos.',
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
        if a.after:
            state['status']='waiting_preceding_archive';persist()
            while True:
                preceding=read(a.after.resolve()/'pipeline_state.json')
                if preceding['status']=='COMPLETED_FULL_BALANCED_RETENTION' and preceding.get('awake_request_released'):
                    assert (a.after.resolve()/'final_delivery.json').is_file()
                    break
                assert preceding['status']!='failed','Preceding run failed; preserve it and fix before training'
                time.sleep(10)
        run('training',[runner,'--yolo',ROOT/'build/overnight_20261116/upstream/yolov5-7.0','--data',data/'data.yaml',
            '--weights',plan['checkpoint'],'--project',exp,'--name','run','--epochs',a.epochs,'--fixed-final',
            '--freeze',0 if a.full_network else 10]+(['--hold-bn-statistics'] if a.full_network else ['--freeze-bn'])+['--batch',64,'--threads',8,'--lr0',.00003,'--warmup-bias-lr',.00003,
            '--cache','ram','--hard-negative-objectness',.02]+(['--save-period',-1] if a.full_network else [])+
            (['--waste-hand-margin',a.waste_hand_margin] if a.waste_hand_margin else [])+
            (['--preserve-teacher',plan['checkpoint'],'--expected-teacher-sha256',plan['checkpoint_sha256'],
              '--preservation-strength',5.,'--disjoint-hand-targets'] if a.native_teacher else []))
        provenance=read(exp/'run/provenance.json');progress=read(exp/'run/progress.json')
        assert provenance['status']=='completed' and progress['epoch']==a.epochs
        if a.full_network:
            assert provenance['parameter_audit']['all_parameters_trainable']
            assert provenance['parameter_audit']['trainable_parameters']==1770682
        assert progress['hard_negative_objectness']['training_batches']==301
        if a.waste_hand_margin:
            assert progress['waste_hand_margin']['training_batches']==301
            assert all(progress['waste_hand_margin']['waste_anchors_by_class'].get(str(c),0)>0 for c in range(4))
        if a.native_teacher:
            assert progress['teacher_preservation']['batches']==301
            assert all(progress['teacher_preservation']['matched_anchors_by_class'].get(str(c),0)>0 for c in range(5))
            assert progress['disjoint_hand_targets']['training_batches_with_hand']>0
        target=exp/'training';target.mkdir();shutil.copyfile(exp/'run/weights/last.pt',target/'final.pt')
        save(target/'result.json',dict(status='PASS',epochs=a.epochs,elapsed_s=provenance['finished_unix']-provenance['started_unix'],
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
        save(exp/'delivery.json',dict(state,training=read(target/'result.json'),actual_epochs=a.epochs,
            actual_samples_per_epoch=19260,actual_primary_samples_total=19260*a.epochs,unique_train_files=9349,new_original_photos=0))
        run('report',[tools/'report_full_balanced_retention.py','--experiment',exp])
        state['status']='COMPLETED_FULL_BALANCED_RETENTION'
    except BaseException as error:state.update(status='failed',error=repr(error));raise
    finally:
        state['awake_request_released']=bool(awake(0x80000000));persist()


if __name__=='__main__':
    main()
