"""Run predeclared offline comparison after the screened public-data training.

No FPGA access or automatic replacement; test images and labels are not read.
"""
import argparse,hashlib,json,os,subprocess,time
from pathlib import Path
from evaluate_public_expansion import scores,dominates

REPO=Path(__file__).resolve().parents[4]
BASE_SHA='a4a0b1b04f83af1d114813e0512dd2c2fa5e7306fae16759824f136b3133021a'
def read(p):return json.loads(Path(p).read_text(encoding='utf-8-sig'))
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--root',type=Path,required=True)
    a=ap.parse_args();root=a.root.resolve();state=root/'evaluation_004_state.json'
    assert not state.exists(),'Existing evaluation record; preserve and use a new evaluation version'
    plan=read(root/'training_plan_final.json');assert plan['data']=='dataset_004' and plan['active_run']=='expanded_clean_004'
    record=dict(status='waiting_for_training',steps=[],plan_sha256=sha(root/'training_plan_final.json'),
                test_images_accessed=False,board_accessed=False,deployment_replaced=False)
    def save():state.write_text(json.dumps(record,indent=2),encoding='utf8')
    save()
    train=root/'runs/expanded_clean_004';runs=root/'runs'
    python=REPO/'build/trash_train_env/Scripts/python.exe'
    tools=REPO/'project/trash_sorting/tools/overnight'
    runner=REPO/'project/trash_sorting/training/train_four_bins.py'
    yolo=REPO/'build/overnight_20261116/upstream/yolov5-7.0'
    source=REPO/'project/trash_sorting/candidates/continuation_023/source'
    blob=source/'yolo/model/model.bin';blobsha=sha(blob);record['original_blob_sha256']=blobsha;save()
    cc=REPO/'build/overnight_20261116/cc_adapter.exe'
    env=os.environ.copy();env['PYTHONUTF8']='1'
    try:
        while True:
            v=read(train/'provenance.json') if (train/'provenance.json').exists() else {}
            if v.get('status')=='completed':break
            if v.get('status') and v['status']!='running':raise RuntimeError('Training status '+v['status'])
            time.sleep(10)
        assert v['weights_sha256']==BASE_SHA and v['epochs']==10 and v['freeze']==4 and v['freeze_bn']
        assert v['lr0']==0.0001 and v['hard_negative_objectness']==0
        cp=train/'weights/best.pt';digest=sha(cp);record['candidate_checkpoint_sha256']=digest;save()
        def run(name,args):
            assert sha(cp)==digest and sha(blob)==blobsha
            command=[str(python),*map(str,args)]
            step=dict(name=name,command=command,status='running',started_unix=time.time())
            record['steps'].append(step);record['status']=name;save()
            with (root/(name+'.log')).open('x',encoding='utf8') as log:
                result=subprocess.run(command,cwd=REPO,env=env,stdout=log,stderr=subprocess.STDOUT)
            step.update(status='completed' if result.returncode==0 else 'failed',returncode=result.returncode,finished_unix=time.time());save()
            if result.returncode:raise RuntimeError('Failed '+name+'; see saved log')
        data=root/'dataset_004';dev=root/'public_dev_001'
        original=REPO/'build/overnight_20261116/runs/continuation_stage4_002/weights/best.pt'
        base=REPO/'build/overnight_20261116/evaluation/stage4_original_val'
        assert sha(original)==BASE_SHA==read(base/'provenance.json')['weights_sha256']
        # Compare validation truth rows, not training aliases, before reusing predictions.
        base_rows=[r for r in read(REPO/'build/continuation_023_dataset_001/manifest.json') if r['split']=='val']
        assert [r for r in read(data/'manifest.json') if r['split']=='val']==base_rows
        for name,weights,config in [('candidate_oldval_float_004',cp,data),
                                    ('baseline_publicdev_float_004',original,dev),
                                    ('candidate_publicdev_float_004',cp,dev)]:
            run(name,[runner,'--yolo',yolo,'--data',config/'data.yaml','--weights',weights,
                      '--project',runs,'--name',name,'--evaluate','val','--batch',16,'--threads',4])
        for label,manifest,first,second in [('oldval',data/'manifest.json',base,runs/'candidate_oldval_float_004'),
                ('publicdev',dev/'manifest.json',runs/'baseline_publicdev_float_004',runs/'candidate_publicdev_float_004')]:
            replay=root/('replay_'+label+'_004')
            run('replay_'+label+'_004',[tools/'replay_policy.py','--manifest',manifest,'--source-dir',source,
                '--evaluation',first,'--evaluation',second,'--cc',cc,'--out',replay])
            record[label+'_float']={k:scores(z,manifest) for k,z in read(replay/'decisions.json').items()};save()
        old=record['oldval_float'];devscores=record['publicdev_float']
        passed=dominates(old['candidate_oldval_float_004'],old['stage4_original_val'])
        devpass=dominates(devscores['candidate_publicdev_float_004'],devscores['baseline_publicdev_float_004'],False)
        record.update(float_gate_pass=passed,publicdev_no_regression=devpass);save()
        if not (passed and devpass):
            record.update(status='completed_rejected_float',decision='KEEP_ORIGINAL_STAGE4',finished_unix=time.time());save();return
        calibration=REPO/'build/tonight_20261117/quant_frozen_replay_001/provenance.json'
        reference=read(calibration);assert len(reference['calibration_images'])==160
        assert reference['ordered_calibration_identity_sha256']=='f9e83b5deb2db0100958165d646f2d30156a60ab97cff91a53947f60c95d9532'
        deployment=root/'quant_original160_004'
        run('quant_original160_004',[tools/'prepare_deployment.py','--out',deployment,'--yolo',yolo,'--data',data,
            '--checkpoint',cp,'--expected-checkpoint-sha256',digest,'--include-hand','--calibration-from',calibration,
            '--expected-calibration-sha256',sha(calibration)])
        assert read(deployment/'provenance.json')['ordered_calibration_identity_sha256']==reference['ordered_calibration_identity_sha256']
        photos=REPO/'build/overnight_20261116/numeric_allval_001';numeric=root/'numeric_oldval_004';scored=root/'score_oldval_004'
        run('numeric_oldval_004',[tools/'check_deployment.py','--deployment',deployment,'--yolo',yolo,'--cc',cc,
            '--clang-host','--exact-q16-head','--out',numeric,'--checkpoint',cp,'--expected-checkpoint-sha256',digest,
            '--source-dir',source,'--photos',photos,'--linear-o2','--compact-scratch'])
        run('score_oldval_004',[tools/'score_numeric_validation.py','--numeric',numeric,'--photos',photos,
            '--manifest',data/'manifest.json','--policy-replay',root/'replay_oldval_004','--source-dir',source,'--out',scored])
        s=scores(read(scored/'decisions.json'),data/'manifest.json');record['oldval_q15']=s
        qpass=dominates(s,dict(correct_positive=1455,false_background=8,correct_personal_battery=55,correct_public_glass=232))
        record.update(q15_gate_pass=qpass,status='completed_offline_candidate_for_review' if qpass else 'completed_rejected_q15',
            decision='REQUIRES_FURTHER_NEWDOMAIN_QUANTIZED_REVIEW_NO_DEPLOYMENT' if qpass else 'KEEP_ORIGINAL_STAGE4',finished_unix=time.time());save()
    except BaseException as e:
        record.update(status='failed',error=repr(e),finished_unix=time.time());save();raise
    finally:
        record['original_blob_unchanged']=sha(blob)==blobsha;save()
if __name__=='__main__':main()
