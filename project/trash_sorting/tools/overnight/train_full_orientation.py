"""Predeclare and execute one longer final-epoch supervised continuation."""
import argparse
from collections import Counter
import os
from pathlib import Path
import shutil
import subprocess
import time

from adapt_quant_heads import ROOT, read, save, sha

BASE_SHA='a4a0b1b04f83af1d114813e0512dd2c2fa5e7306fae16759824f136b3133021a'
BLOB_SHA='7a0765a6f275f3c06d838f924d73542783ca55e131509aa1b546efc98bd65728'
TOOLS=Path(__file__).resolve().parent
RUNNER=ROOT/'project/trash_sorting/training/train_four_bins.py'
PY=ROOT/'build/trash_train_env/Scripts/python.exe'


def freeze(exp):
    exp.mkdir(parents=True,exist_ok=False)
    data=exp.parent/'dataset_001'
    report=read(data/'result.json');rows=read(data/'manifest.json')
    assert report['training_draws']==13630 and report['unique_file_identities']==8334
    groups=[[] for _ in range(5)];seen=set()
    for row in sorted((r for r in rows if r['split']=='train'),key=lambda r:r['prepared_image']):
        if not row['boxes'] or row['image_sha256'] in seen:continue
        seen.add(row['image_sha256'])
        c=int(max(row['boxes'],key=lambda b:b[3]*b[4])[0])
        groups[c].append(row)
    selected=[]
    for c,group in enumerate(groups):
        assert len(group)>=32
        for i in range(32):
            row=group[i*len(group)//32]
            selected.append(dict(path=str(Path(row['prepared_image']).resolve()),
                                 sha256=row['image_sha256'],label_sha256=row['label_sha256'],
                                 source=row['source'],primary_calibration_class=c))
    save(exp/'calibration_reference.json',dict(classes=['kitchen','recyclable','hazardous','other','hand'],
        calibration_images=selected,selection='32 per primary class evenly spaced by path, frozen before training; current cleaned train only',
        validation_or_test_used=False))
    cp=ROOT/'build/overnight_20261116/runs/continuation_stage4_002/weights/best.pt'
    assert sha(cp)==BASE_SHA
    plan=dict(hypothesis='Tail-only QAT improves some public/negative examples but loses hand-held battery and glass. Allow the supervised feature hierarchy above block4 to adapt to the already reviewed orientation/background training data, instead of relying on static cached features. This is one fixed final-epoch continuation, not a learning-rate/threshold/epoch search.',
        checkpoint=str(cp),checkpoint_sha256=BASE_SHA,
        manifest=str(data/'manifest.json'),manifest_sha256=sha(data/'manifest.json'),
        data_yaml_sha256=sha(data/'data.yaml'),data_report_sha256=sha(data/'result.json'),
        runner_sha256=sha(RUNNER),epochs=10,batch=16,threads=4,freeze=4,freeze_bn=True,
        lr0=.0001,warmup_bias_lr=.0001,optimizer='AdamW',seed=20261111,
        checkpoint_selection='Fixed final epoch last.pt; no intermediate validation or early stopping',
        unique_train=8334,draws_per_epoch=13630,
        photograph_count_note='7904 previous train identities +40 new source photos +14 derived empty crops +376 derived rotations. 8334 includes derived views; 13630 includes replay draws. Neither is a count of independent objects.',
        calibration_reference_sha256=sha(exp/'calibration_reference.json'),
        calibration='Exactly the 160 predeclared current-whitelist training images; no validation-based scale choice or calibration sweep.',
        acceptance=read(ROOT/'build/quant_battery_orientation_20261118_001/experiment_001/plan.json')['acceptance'],
        deadline_utc='2026-11-18T04:00:00Z',latest_start_unix=1794956400,
        scope='Offline training, export and development evaluation; no board, UART, synthesis, routing, TF or Flash; no final-test files.')
    save(exp/'plan.json',plan)
    frozen=exp/'frozen_scripts';frozen.mkdir()
    for src in (RUNNER,Path(__file__),TOOLS/'evaluate_quant_head_adaptation.py'):
        shutil.copyfile(src,frozen/src.name)
    print(plan,flush=True)


def verify_full_plan(exp):
    plan=read(exp/'plan.json');data=Path(plan['manifest']).parent
    for file,field in [(Path(plan['checkpoint']),'checkpoint_sha256'),(Path(plan['manifest']),'manifest_sha256'),
                       (data/'data.yaml','data_yaml_sha256'),(data/'result.json','data_report_sha256'),
                       (exp/'calibration_reference.json','calibration_reference_sha256')]:
        assert sha(file)==plan[field],(str(file),field)
    return plan


def run(exp):
    plan=verify_full_plan(exp);state=dict(status='waiting_preceding_experiments',steps=[])
    assert sha(RUNNER)==plan['runner_sha256'],'Frozen training runner changed before launch'
    blob=ROOT/'project/trash_sorting/candidates/continuation_023/source/yolo/model/model.bin'
    env=dict(os.environ,PYTHONUTF8='1')
    def persist():
        assert sha(blob)==BLOB_SHA
        save(exp/'pipeline_state.json',state)
    def command(name,args):
        step=dict(name=name,status='running',started_unix=time.time())
        state['steps'].append(step);state['status']=name;persist();print('START',name,flush=True)
        with (exp/(name+'.log')).open('x',encoding='utf8') as log:
            p=subprocess.run([str(PY),*map(str,args)],cwd=ROOT,env=env,stdout=log,stderr=subprocess.STDOUT)
        step.update(returncode=p.returncode,elapsed_s=time.time()-step['started_unix'],status='completed' if p.returncode==0 else 'failed')
        persist()
        if p.returncode:raise RuntimeError(name+' failed')
        print('DONE',name,flush=True)
    try:
        persist();prior=ROOT/'build/noon_continuation_20261118_001/state.json'
        while True:
            status=read(prior)['status']
            if status=='COMPLETED_TWO_FROZEN_OFFLINE_EXPERIMENTS':break
            assert status!='failed','Finish/fix preceding evidence first'
            assert time.time()<plan['latest_start_unix'],'Too late to start this fixed training before noon'
            time.sleep(10)
        data=Path(plan['manifest']).parent
        command('training',[RUNNER,'--yolo',ROOT/'build/overnight_20261116/upstream/yolov5-7.0',
            '--data',data/'data.yaml','--weights',plan['checkpoint'],'--project',exp,'--name','run',
            '--epochs',10,'--fixed-final','--freeze',4,'--freeze-bn','--batch',16,'--threads',4,
            '--lr0',.0001,'--warmup-bias-lr',.0001,'--cache','ram'])
        provenance=read(exp/'run/provenance.json')
        assert provenance['status']=='completed' and provenance['fixed_final']
        assert read(exp/'run/progress.json')['epoch']==10
        training=exp/'training';training.mkdir(exist_ok=False)
        shutil.copyfile(exp/'run/weights/last.pt',training/'final.pt')
        save(training/'result.json',dict(status='PASS',epochs=10,checkpoint_sha256=sha(training/'final.pt'),
            elapsed_s=provenance['finished_unix']-provenance['started_unix'],final_epoch_only=True))
        baseline=ROOT/'build/quant_tail_20261118_001/baseline_continuation_current_policy'
        shutil.copytree(baseline,exp.parent/'baseline_continuation_current_policy')
        command('evaluation',[TOOLS/'evaluate_quant_head_adaptation.py','--experiment',exp,'--full-finetune'])
        command('continuation',[TOOLS/'evaluate_qat_continuation.py','--experiment',exp])
        command('gallery',[TOOLS/'render_quant_comparison.py','--experiment',exp,'--baseline-root',ROOT/'build/quant_head_adapt_20261118_001'])
        command('coverage',[TOOLS/'summarize_recognition_coverage.py','--experiment',exp,'--out',exp/'evaluation/recognition_coverage'])
        state['status']='COMPLETED_OFFLINE_FULL_CONTINUATION'
    except BaseException as error:
        state.update(status='failed',error=repr(error));raise
    finally:persist()


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('mode',choices=['freeze','run'])
    p.add_argument('--experiment',type=Path,required=True);a=p.parse_args()
    {'freeze':freeze,'run':run}[a.mode](a.experiment.resolve())
