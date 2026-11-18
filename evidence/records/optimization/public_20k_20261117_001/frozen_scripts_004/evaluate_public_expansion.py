"""Complete this public-data continuation's fixed offline gates, without board access."""
import argparse,hashlib,json,os,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[4]
def read(p):return json.loads(Path(p).read_text(encoding='utf8'))
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def scores(decisions,manifest):
    truth={Path(r['prepared_image']).stem:r for r in read(manifest) if r['split']=='val'}
    assert set(decisions)==set(truth)
    positive={k for k,r in truth.items() if any(int(b[0])<4 for b in r['boxes'])}
    battery={k for k,r in truth.items() if r['source']=='personal_\u7535\u6c60'}
    glass={k for k,r in truth.items() if r['source']=='sumn2u' and '/glass/' in str(r.get('image','')).replace('\\','/').lower()}
    return dict(correct_positive=sum(decisions[k]['correct_class_and_iou050'] for k in positive),
                false_background=sum(decisions[k]['selected'] is not None for k in set(truth)-positive),
                correct_personal_battery=sum(decisions[k]['correct_class_and_iou050'] for k in battery),
                correct_public_glass=sum(decisions[k]['correct_class_and_iou050'] for k in glass),
                denominators=dict(positive=len(positive),background=len(truth)-len(positive),personal_battery=len(battery),public_glass=len(glass)))
def dominates(a,b,strict=True):
    high=('correct_positive','correct_personal_battery','correct_public_glass')
    good=all(a[k]>=b[k] for k in high) and a['false_background']<=b['false_background']
    return good and (not strict or any(a[k]>b[k] for k in high) or a['false_background']<b['false_background'])
def main():
    p=argparse.ArgumentParser();p.add_argument('--root',type=Path,required=True);a=p.parse_args();root=a.root.resolve()
    state=root/'evaluation_state_retry_002.json';assert not state.exists(),'Evaluation already exists'
    record=dict(status='waiting_for_training',steps=[],board_accessed=False,held_out_test_used=False)
    def save():state.write_text(json.dumps(record,indent=2),encoding='utf8')
    save();train=root/'runs/train_001';deadline=time.time()+3600
    try:
        while True:
            f=train/'provenance.json'
            v=read(f) if f.exists() else {}
            if v.get('status')=='completed':break
            if v.get('status')=='failed':raise RuntimeError('Training failed')
            if time.time()>deadline:raise TimeoutError('Training did not finish within one hour')
            time.sleep(10)
        assert v['weights_sha256']=='a4a0b1b04f83af1d114813e0512dd2c2fa5e7306fae16759824f136b3133021a'
        assert v['epochs']==3 and v['hard_negative_objectness']==0 and v['freeze']==10 and v['freeze_bn']
        cp=train/'weights/best.pt';digest=sha(cp);record['checkpoint_sha256']=digest
        python=ROOT/'build/trash_train_env/Scripts/python.exe';yolo=ROOT/'build/overnight_20261116/upstream/yolov5-7.0'
        source=ROOT/'project/trash_sorting/candidates/continuation_023/source';tools=ROOT/'project/trash_sorting/tools/overnight'
        runner=ROOT/'project/trash_sorting/training/train_four_bins.py';cc=ROOT/'build/overnight_20261116/cc_adapter.exe'
        env=os.environ.copy();env['PYTHONUTF8']='1'
        def run(name,args):
            assert sha(cp)==digest
            if name=='candidate_oldval_float_001':
                prior=read(root/'runs'/name/'provenance.json')
                assert prior['status']=='completed' and prior['weights_sha256']==digest
                record['steps'].append(dict(name=name,status='reused_completed',weights_sha256=digest));save();return
            cmd=[str(python),*map(str,args)];step=dict(name=name,command=cmd,status='running');record['steps'].append(step);record['status']=name;save()
            with (root/(name+'.log')).open('x',encoding='utf8') as log:
                r=subprocess.run(cmd,cwd=ROOT,env=env,stdout=log,stderr=subprocess.STDOUT)
            step.update(status='completed' if r.returncode==0 else 'failed',returncode=r.returncode);save()
            if r.returncode:raise RuntimeError('Failed '+name+'; see saved log')
        data=root/'dataset_003';dev=root/'public_dev_003';runs=root/'runs'
        run('candidate_oldval_float_001',[runner,'--yolo',yolo,'--data',data/'data.yaml','--weights',cp,
             '--project',runs,'--name','candidate_oldval_float_001','--evaluate','val','--batch',16,'--threads',4])
        base=ROOT/'build/overnight_20261116/evaluation/stage4_original_val'
        original=ROOT/'build/overnight_20261116/runs/continuation_stage4_002/weights/best.pt'
        assert read(base/'provenance.json')['weights_sha256']==sha(original)==v['weights_sha256']
        for name,weights in [('baseline_publicdev_float_002',original),('candidate_publicdev_float_002',cp)]:
            run(name,[runner,'--yolo',yolo,'--data',dev/'data.yaml','--weights',weights,
                      '--project',runs,'--name',name,'--evaluate','val','--batch',16,'--threads',4])
        for label,manifest,first,second in [('oldval',data/'manifest.json',base,runs/'candidate_oldval_float_001'),
                ('publicdev',dev/'manifest.json',runs/'baseline_publicdev_float_002',runs/'candidate_publicdev_float_002')]:
            run('replay_'+label+'_001',[tools/'replay_policy.py','--manifest',manifest,'--source-dir',source,
                '--evaluation',first,'--evaluation',second,'--cc',cc,'--out',root/('replay_'+label+'_001')])
            d=read(root/('replay_'+label+'_001/decisions.json'))
            record[label+'_float']={k:scores(z,manifest) for k,z in d.items()};save()
        old=record['oldval_float'];new=record['publicdev_float']
        float_pass=dominates(old['candidate_oldval_float_001'],old['stage4_original_val'])
        dev_pass=dominates(new['candidate_publicdev_float_002'],new['baseline_publicdev_float_002'],False)
        record.update(float_gate_pass=float_pass,publicdev_no_regression=dev_pass)
        if not float_pass or not dev_pass:
            record.update(status='completed_rejected_float',decision='KEEP_ORIGINAL_STAGE4');save();return
        calibration=ROOT/'build/tonight_20261117/quant_frozen_replay_001/provenance.json'
        reference=read(calibration);assert len(reference['calibration_images'])==160
        run('quant_original160_001',[tools/'prepare_deployment.py','--out',root/'quant_original160_001',
            '--yolo',yolo,'--data',data,'--checkpoint',cp,'--expected-checkpoint-sha256',digest,'--include-hand',
            '--calibration-from',calibration,'--expected-calibration-sha256',sha(calibration)])
        quant=read(root/'quant_original160_001/provenance.json')
        assert quant['ordered_calibration_identity_sha256']==reference['ordered_calibration_identity_sha256']
        record['fixed_calibration_identity_sha256']=quant['ordered_calibration_identity_sha256'];save()
        for label,photos,manifest in [('oldval',ROOT/'build/overnight_20261116/numeric_allval_001',data/'manifest.json'),
                ('new77',ROOT/'build/overnight_20261116/numeric_newval_inventory_001',ROOT/'build/overnight_20261116/reserved_newval_001/manifest.json')]:
            run('numeric_'+label+'_001',[tools/'check_deployment.py','--deployment',root/'quant_original160_001','--yolo',yolo,
                '--cc',cc,'--clang-host','--exact-q16-head','--out',root/('numeric_'+label+'_001'),
                '--checkpoint',cp,'--expected-checkpoint-sha256',digest,'--source-dir',source,'--photos',photos,'--linear-o2','--compact-scratch'])
            run('score_'+label+'_001',[tools/'score_numeric_validation.py','--numeric',root/('numeric_'+label+'_001'),
                '--photos',photos,'--manifest',manifest,'--policy-replay',root/'replay_oldval_001','--source-dir',source,'--out',root/('score_'+label+'_001')])
            s=scores(read(root/('score_'+label+'_001/decisions.json')),manifest);record[label+'_q15']=s;save()
            if label=='oldval':
                baseline=dict(correct_positive=1455,false_background=8,correct_personal_battery=55,correct_public_glass=232)
                passed=dominates(s,baseline);record['q15_gate_pass']=passed;save()
                if not passed:
                    record.update(status='completed_rejected_q15',decision='KEEP_ORIGINAL_STAGE4');save();return
            else:
                report=read(root/'score_new77_001/result.json');cohorts=report['cohorts']
                held=sum(v['correct_class_and_iou050'] for k,v in cohorts.items() if k.startswith('source/') and 'battery' in k and 'hand' in k)
                # The source naming is checked separately in the final evidence review.
                record['new77_source_cohorts']={k:v for k,v in cohorts.items() if k.startswith('source/')}
                record['new77_primary_gate_pass']=s['correct_positive']>=56
        record.update(status='completed_candidate_for_review',decision='OFFLINE_GATES_FINISHED_REQUIRES_EVIDENCE_REVIEW_NO_DEPLOYMENT');save()
    except BaseException as e:
        record.update(status='failed',error=repr(e));save();raise
if __name__=='__main__':main()
