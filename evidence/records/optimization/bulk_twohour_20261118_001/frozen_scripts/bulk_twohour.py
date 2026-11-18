"""One consolidated supervised feature-training run and complete offline evaluation."""
import argparse
from collections import Counter
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime,timezone
import os
from pathlib import Path
import shutil
import subprocess
import time
import numpy as np
from adapt_quant_heads import ROOT,read,save,sha
from train_full_orientation import verify_full_plan

TOOLS=Path(__file__).resolve().parent
PY=ROOT/'build/trash_train_env/Scripts/python.exe'
RUNNER=ROOT/'project/trash_sorting/training/train_four_bins.py'
NAME='bulk_twohour_20261118_001'
PARENT=ROOT/'build'/NAME
BLOB=ROOT/'project/trash_sorting/candidates/continuation_023/source/yolo/model/model.bin'
BLOB_SHA='7a0765a6f275f3c06d838f924d73542783ca55e131509aa1b546efc98bd65728'
END='2026-11-18T18:19:51+00:00'


def prepare():
    reference=ROOT/'build/joint_source_retention_20261118_001/experiment_001'
    prior=read(reference/'plan.json');exp=PARENT/'experiment_001';exp.mkdir(exist_ok=False)
    data=PARENT/'dataset_001';data.mkdir()
    rows=read(reference/'unique_train.json');draws=read(reference/'draw_indices.json')
    assert len(rows)==9349 and len(draws)==19260 and len({r['image_sha256'] for r in rows})==9349
    for folder in ['images/train','labels/train']:(data/folder).mkdir(parents=True)
    def materialize(row):
        assert row['split']=='train' and sha(row['prepared_image'])==row['image_sha256']
        image=data/'images/train'/(row['image_sha256']+Path(row['prepared_image']).suffix.lower())
        os.link(row['prepared_image'],image)
        label=data/'labels/train'/(image.stem+'.txt')
        for c,cx,cy,w,h in row['boxes']:
            assert c in range(5) and w>0 and h>0 and np.isfinite([cx,cy,w,h]).all()
            assert -1e-6<=cx-w/2<cx+w/2<=1+1e-6 and -1e-6<=cy-h/2<cy+h/2<=1+1e-6
        label.write_text(''.join(str(int(b[0]))+' '+' '.join('%.8f'%v for v in b[1:])+'\n' for b in row['boxes']),encoding='ascii')
        return dict(row,prepared_image=str(image),stem=image.stem,label=str(label),label_sha256=sha(label),original_prepared_image=row['prepared_image'])
    with ThreadPoolExecutor(max_workers=8) as pool:unique=list(pool.map(materialize,rows))
    held=[r for r in read(prior['manifest']) if r['split']=='val']
    assert all(r['split']=='val' for r in held)
    manifest=[dict(unique[i],bulk_draw=j) for j,i in enumerate(draws)]+held
    save(data/'manifest.json',manifest);save(exp/'unique_train.json',unique);save(exp/'draw_indices.json',draws)
    for split in ['train','val']:(data/(split+'.txt')).write_text(''.join(r['prepared_image']+'\n' for r in manifest if r['split']==split),encoding='utf8')
    (data/'data.yaml').write_text('path: '+data.as_posix()+'\ntrain: train.txt\nval: val.txt\nnc: 5\nnames: [kitchen, recyclable, hazardous, other, hand]\n',encoding='utf8')
    save(data/'result.json',dict(status='FROZEN_BULK_SUPERVISED_DATASET',training_draws=len(draws),unique_file_identities=len(unique),
        source_counts=dict(Counter(r['source'] for r in unique)),new_images=0,all_existing_complete_gt_preserved=True,
        original_val_rows_unchanged=True,final_test_read=False,original_reference_sha256=sha(reference/'unique_train.json')))
    groups=[[] for _ in range(5)]
    for r in sorted(unique,key=lambda r:r['image_sha256']):
        if r['boxes']:groups[int(max(r['boxes'],key=lambda b:b[3]*b[4])[0])].append(r)
    selected=[]
    for c,group in enumerate(groups):
        assert len(group)>=32
        for i in range(32):
            r=group[i*len(group)//32];selected.append(dict(path=r['prepared_image'],sha256=r['image_sha256'],
                label_sha256=r['label_sha256'],source=r['source'],primary_calibration_class=c))
    save(exp/'calibration_reference.json',dict(classes=['kitchen','recyclable','hazardous','other','hand'],
        calibration_images=selected,selection='Fixed before training:32 per largest GT class evenly spaced by SHA; train only',validation_or_test_used=False))
    cp=Path(prior['checkpoint']);assert sha(cp)==prior['checkpoint_sha256'] and sha(BLOB)==BLOB_SHA
    plan=dict(hypothesis='One consolidated batch run on all9349 existing qualified train file identities and19260 balanced replay draws. Reopen feature blocks4..24 instead of cached13-tail-only updates; jointly train battery, glass, all waste classes and hands with ordinary complete GT plus opt-in GT-gated hard-negative objectness0.02. Freeze only first4 feature blocks/BN there, retain topology and320input. Use augmentation and larger64image minibatches with8CPU threads selected from a train-only synthetic throughput benchmark. Fixed4epochs from original deployed checkpoint, no validation checkpoint search; final last.pt only. Recalibrate once on160 predeclared train identities and verify actual integer/C selector. No new images, pseudo labels, final-test data or automatic board deployment.',
        checkpoint=str(cp),checkpoint_sha256=sha(cp),manifest=str(data/'manifest.json'),manifest_sha256=sha(data/'manifest.json'),
        data_yaml_sha256=sha(data/'data.yaml'),data_report_sha256=sha(data/'result.json'),runner_sha256=sha(RUNNER),
        epochs=4,batch=64,threads=8,freeze=4,freeze_bn=True,lr0=.0001,warmup_bias_lr=.0001,
        optimizer='AdamW',seed=20261111,hard_negative_objectness=.02,
        checkpoint_selection='Fixed final fourth epoch last.pt; no intermediate validation or early stopping',
        unique_train=len(unique),draws_per_epoch=len(draws),calibration_reference_sha256=sha(exp/'calibration_reference.json'),
        acceptance=prior['acceptance'],deadline_utc=END,authorized_start_utc='2026-11-18T16:19:51+00:00',
        photograph_count_note='9349 files include at least995 known derived files;19260 draws are replay, not new photos;20000original goal not achieved.',
        scope='Offline only; no synthesis/routing/UART/board/TF/Flash/test image or label access.')
    save(exp/'plan.json',plan);frozen=exp/'frozen_scripts';frozen.mkdir()
    for src in [RUNNER,Path(__file__),TOOLS/'evaluate_quant_head_adaptation.py',RUNNER.with_name('hard_negative_objectness.py')]:shutil.copyfile(src,frozen/src.name)
    verify_full_plan(exp);print(dict(experiment=str(exp),files=len(unique),draws=len(draws),epochs=4,batch=64,threads=8),flush=True)


def run():
    exp=PARENT/'experiment_001';plan=verify_full_plan(exp);assert sha(RUNNER)==plan['runner_sha256']
    state=dict(status='starting',steps=[],board_accessed=False,deadline_utc=END)
    deadline=datetime.fromisoformat(END).timestamp();env=dict(os.environ,PYTHONUTF8='1')
    def persist():
        assert sha(BLOB)==BLOB_SHA
        save(exp/'pipeline_state.json',state)
    def command(name,args,reserve=0):
        remaining=deadline-time.time()-reserve
        assert remaining>0,'Deadline reached'
        step=dict(name=name,status='running',started_unix=time.time());state['steps'].append(step);state['status']=name;persist()
        print('START',name,flush=True)
        with (exp/(name+'.log')).open('x',encoding='utf8') as log:
            proc=subprocess.Popen([str(PY),*map(str,args)],cwd=ROOT,env=env,stdout=log,stderr=subprocess.STDOUT)
            step['pid']=proc.pid;persist()
            try:rc=proc.wait(timeout=remaining)
            except subprocess.TimeoutExpired:
                subprocess.run(['taskkill','/PID',str(proc.pid),'/T','/F'],capture_output=True)
                step.update(status='deadline_stopped',elapsed_s=time.time()-step['started_unix']);persist()
                raise RuntimeError(name+' stopped at reserved evaluation/deadline boundary; existing epoch checkpoints preserved')
        step.update(status='completed' if rc==0 else 'failed',returncode=rc,elapsed_s=time.time()-step['started_unix']);persist()
        if rc:raise RuntimeError(name+' failed; inspect log, do not blindly repeat')
    try:
        assert not (exp/'pipeline_state.json').exists();persist()
        data=Path(plan['manifest']).parent
        command('training',[RUNNER,'--yolo',ROOT/'build/overnight_20261116/upstream/yolov5-7.0','--data',data/'data.yaml',
            '--weights',plan['checkpoint'],'--project',exp,'--name','run','--epochs',4,'--fixed-final',
            '--freeze',4,'--freeze-bn','--batch',64,'--threads',8,'--lr0',.0001,'--warmup-bias-lr',.0001,
            '--cache','ram','--hard-negative-objectness',.02],reserve=1200)
        provenance=read(exp/'run/provenance.json');assert provenance['status']=='completed' and read(exp/'run/progress.json')['epoch']==4
        training=exp/'training';training.mkdir();shutil.copyfile(exp/'run/weights/last.pt',training/'final.pt')
        save(training/'result.json',dict(status='PASS',epochs=4,elapsed_s=provenance['finished_unix']-provenance['started_unix'],
            checkpoint_sha256=sha(training/'final.pt'),final_epoch_only=True))
        shutil.copytree(ROOT/'build/quant_tail_20261118_001/baseline_continuation_current_policy',PARENT/'baseline_continuation_current_policy')
        command('evaluation',[TOOLS/'evaluate_quant_head_adaptation.py','--experiment',exp,'--full-finetune'])
        command('continuation',[TOOLS/'evaluate_qat_continuation.py','--experiment',exp])
        command('gallery',[TOOLS/'render_quant_comparison.py','--experiment',exp,'--baseline-root',ROOT/'build/quant_head_adapt_20261118_001'])
        command('coverage',[TOOLS/'summarize_recognition_coverage.py','--experiment',exp,'--out',exp/'evaluation/recognition_coverage'])
        command('background_dev',[TOOLS/'evaluate_held_background_dev.py','--deployment',exp/'evaluation/quant',
            '--checkpoint',training/'final.pt','--name',NAME])
        ev=read(exp/'evaluation/state.json');state.update(status='COMPLETED_BULK_OFFLINE_EVALUATION',accepted_offline=ev['accepted_offline'],
            q15=ev['q15_oldval'],public_dev=ev['q15_publicdev'],gates=ev['gates'],finished_unix=time.time())
        save(exp/'delivery.json',dict(state,training=read(training/'result.json'),count_note=plan['photograph_count_note'],
            unchanged_deployment_sha256=sha(BLOB),new_images=0,scope=plan['scope']))
    except BaseException as error:state.update(status='failed',error=repr(error));raise
    finally:persist()


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('mode',choices=['prepare','run']);a=p.parse_args();{'prepare':prepare,'run':run}[a.mode]()
