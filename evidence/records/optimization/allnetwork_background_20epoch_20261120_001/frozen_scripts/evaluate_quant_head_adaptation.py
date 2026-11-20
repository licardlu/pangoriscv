"""Evaluate a final head-adapted checkpoint with unchanged decode and calibration."""
import argparse,os,subprocess,time,shutil
from pathlib import Path
from adapt_quant_heads import ROOT,PARENT,DEP,read,save,sha,verify_plan
from evaluate_public_expansion import scores,dominates

def primary_counts(decisions,manifest):
    from replay_policy import overlap
    rows={Path(r['prepared_image']).stem:r for r in read(manifest) if r['split']=='val'}
    counts={str(c):dict(correct=0,images=0) for c in range(4)}
    # Only normalized geometry and selected boxes; no reading images here.
    # Numeric decisions are in original display pixels. Inventory supplies size.
    return rows,counts,overlap

def subject_by_class(decisions,manifest,inventory):
    rows,counts,overlap=primary_counts(decisions,manifest)
    sizes={Path(r['path']).stem:r['display_size'] for r in read(inventory)}
    for stem,gt in rows.items():
        w,h=sizes[stem];sel=decisions[stem]['selected']
        for c in range(4):
            boxes=[b for b in gt['boxes'] if int(b[0])==c]
            if not boxes:continue
            counts[str(c)]['images']+=1
            right=bool(sel and int(sel[5])==c and any(overlap(sel[:4],[(cx-bw/2)*w,(cy-bh/2)*h,(cx+bw/2)*w,(cy+bh/2)*h])>=.5 for _,cx,cy,bw,bh in boxes))
            counts[str(c)]['correct']+=right
    return counts

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--experiment',type=Path,required=True)
    p.add_argument('--qat-tail',action='store_true',help='Export predeclared frozen-scale tail QAT instead of recalibrating')
    p.add_argument('--full-finetune',action='store_true',help='Evaluate a predeclared final full-network continuation with its train-only calibration list')
    p.add_argument('--reuse-float-from',type=Path,help='Reuse completed identity-checked float checks from a failed export evaluation')
    p.add_argument('--image-identity-recovery',action='store_true',help='Verify and use an explicitly recorded upstream JPEG-repair manifest; keep frozen plan/calibration unchanged')
    p.add_argument('--frozen-calibration-only',action='store_true',help='Open only the exact identity-pinned train calibration paths during full export')
    a=p.parse_args();exp=a.experiment.resolve();root=exp.parent
    assert not (a.qat_tail and a.full_finetune)
    if a.full_finetune:
        from train_full_orientation import verify_full_plan
        plan=verify_full_plan(exp)
    elif a.qat_tail:
        from train_qat_tail import verify
        plan=verify(exp)
    else:plan=verify_plan(exp)
    recovered_data=None
    if a.image_identity_recovery:
        assert a.full_finetune
        from recover_bulk_image_identity import verify_recovery
        recovered_data=verify_recovery(exp)
    qat_ops=plan.get('trained_q15_ops',[65,73,81])
    training=read(exp/'training/result.json');assert training['status']=='PASS'
    cp=exp/'training/final.pt';digest=sha(cp);assert digest==training['checkpoint_sha256']
    output=exp/'evaluation';output.mkdir(exist_ok=False)
    src=ROOT/'project/trash_sorting/candidates/continuation_023/source'
    blob=src/'yolo/model/model.bin';oldblob=sha(blob)
    assert oldblob=='7a0765a6f275f3c06d838f924d73542783ca55e131509aa1b546efc98bd65728'
    env=os.environ.copy();env['PYTHONUTF8']='1'
    py=ROOT/'build/trash_train_env/Scripts/python.exe'
    tools=ROOT/'project/trash_sorting/tools/overnight'
    yolo=ROOT/'build/overnight_20261116/upstream/yolov5-7.0'
    cc=ROOT/'build/overnight_20261116/cc_adapter.exe'
    state=dict(status='running',steps=[],checkpoint_sha256=digest,board_accessed=False,test_images_accessed=False)
    def persist():save(output/'state.json',state)
    def run(name,args):
        assert sha(cp)==digest and sha(blob)==oldblob
        command=[str(py),*map(str,args)]
        step=dict(name=name,command=command,started_unix=time.time(),status='running')
        state['steps'].append(step);state['status']=name;persist()
        print('START '+name,flush=True)
        with (output/(name+'.log')).open('x',encoding='utf8') as log:
            proc=subprocess.run(command,cwd=ROOT,env=env,stdout=log,stderr=subprocess.STDOUT)
        step.update(returncode=proc.returncode,elapsed_s=time.time()-step['started_unix'],status='completed' if not proc.returncode else 'failed');persist()
        if proc.returncode:raise RuntimeError(name+' failed, see saved log')
        print('DONE '+name,flush=True)
    persist()
    try:
        data=recovered_data or (Path(plan['manifest']).parent if plan.get('manifest') else PARENT/'dataset_004');manifest=data/'manifest.json'
        if recovered_data:
            state['image_identity_recovery_sha256']=sha(exp/'image_identity_recovery.json');persist()
        runner=ROOT/'project/trash_sorting/training/train_four_bins.py'
        if a.reuse_float_from:
            previous=a.reuse_float_from.resolve();prior=read(previous/'state.json')
            assert prior['checkpoint_sha256']==digest and prior['original_deployment_unchanged']
            assert read(previous/'float_oldval/provenance.json')['weights_sha256']==digest
            replay=read(previous/'replay_float/result.json')
            assert replay['manifest_sha256']==sha(manifest)
            for name,value in replay['headers'].items():assert sha(src/'yolo/software'/name)==value
            for folder in ['float_oldval','replay_float']:shutil.copytree(previous/folder,output/folder)
            state['reused_float_from']=str(previous)
            state['reused_float_checkpoint_sha256']=digest;persist()
        else:
            run('float_oldval',[runner,'--yolo',yolo,'--data',data/'data.yaml','--weights',cp,
                '--project',output,'--name','float_oldval','--evaluate','val','--batch',16,'--threads',4])
            run('replay_float',[tools/'replay_policy.py','--manifest',manifest,'--source-dir',src,
                '--evaluation',ROOT/'build/overnight_20261116/evaluation/stage4_original_val',
                '--evaluation',output/'float_oldval','--cc',cc,'--out',output/'replay_float'])
        decisions=read(output/'replay_float/decisions.json')
        state['float_scores']={k:scores(v,manifest) for k,v in decisions.items()}
        state['float_gate']=dominates(state['float_scores']['float_oldval'],state['float_scores']['stage4_original_val'],False);persist()
        # Quantize even on float rejection: this experiment diagnoses the Q15
        # failure, but either gate failure still forbids accepting a replacement.
        calibration=exp/'calibration_reference.json' if a.full_finetune else ROOT/'build/tonight_20261117/quant_frozen_replay_001/provenance.json'
        quant=output/'quant'
        if a.qat_tail:
            run('quantize',[tools/'export_qat_tail.py','--experiment',exp,'--out',quant])
        else:
            run('quantize',[tools/'prepare_deployment.py','--out',quant,'--yolo',yolo,
                '--data',data if a.full_finetune else PARENT/'calibration_reference_001','--checkpoint',cp,
                '--expected-checkpoint-sha256',digest,'--include-hand','--calibration-from',calibration,
                '--expected-calibration-sha256',sha(calibration)]+(['--frozen-calibration-only'] if a.frozen_calibration_only else []))
        import numpy as np
        comparison_profile=Path(plan['scale_profile']) if a.qat_tail else DEP
        old=np.load(comparison_profile/'parameters.npz');new=np.load(quant/'bundle/parameters.npz')
        assert set(old.files)==set(new.files)
        nonhead=[]
        for name in old.files:
            idx=int(name.split('_')[0][2:])
            if not a.full_finetune and idx not in (qat_ops+[82,83,84] if a.qat_tail else (82,83,84)):
                np.testing.assert_array_equal(old[name],new[name],err_msg=name);nonhead.append(name)
        oldgraph=read(comparison_profile/'bundle.json');newgraph=read(quant/'bundle/bundle.json')
        if not a.full_finetune:
            assert oldgraph['ops'][:65 if a.qat_tail else 82]==newgraph['ops'][:65 if a.qat_tail else 82]
        state['frozen_quantized_backbone_bit_exact']=not a.full_finetune
        if a.full_finetune:
            state['full_finetune_quantization']='Updated checkpoint, exact graph-forward verification and predeclared 160 current-whitelist train calibration identities; not frozen-profile tail QAT.'
        if a.qat_tail:
            state['frozen_quantized_backbone_bit_exact_scope']='Nontrainable arrays and graph prefix 0..64; updated Q15 convs are explicitly listed.'
            state['trained_q15_ops']=qat_ops
        state['unchanged_nonhead_parameter_arrays']=len(nonhead);persist()
        for label,photos,mani,policy in [
            ('oldval',ROOT/'build/overnight_20261116/numeric_allval_001',manifest,PARENT/'replay_oldval_004'),
            ('publicdev',PARENT/'numeric_publicdev_inventory_001',PARENT/'public_dev_001/manifest.json',PARENT/'replay_publicdev_004')]:
            numeric=output/('numeric_'+label);scored=output/('score_'+label)
            run('numeric_'+label,[tools/'check_deployment.py','--deployment',quant,'--yolo',yolo,'--cc',cc,
                '--clang-host','--exact-q16-head','--out',numeric,'--checkpoint',cp,'--expected-checkpoint-sha256',digest,
                '--source-dir',src,'--photos',photos,'--linear-o2','--compact-scratch'])
            run('score_'+label,[tools/'score_numeric_validation.py','--numeric',numeric,'--photos',photos,
                '--manifest',mani,'--policy-replay',policy,'--source-dir',src,'--out',scored])
            state['q15_'+label]=scores(read(scored/'decisions.json'),mani);persist()
        baseline_root=ROOT/'build/quant_head_adapt_20261118_001' if a.qat_tail or a.full_finetune else root
        baseline_dir=baseline_root/'baseline_q15_current_policy'
        baseline=read(baseline_dir/'result.json');candidate=read(output/'score_oldval/result.json')
        base_scores=scores(read(baseline_dir/'decisions.json'),manifest)
        before=subject_by_class(read(baseline_dir/'decisions.json'),manifest,ROOT/'build/overnight_20261116/numeric_allval_001/inventory.json')
        after=subject_by_class(read(output/'score_oldval/decisions.json'),manifest,ROOT/'build/overnight_20261116/numeric_allval_001/inventory.json')
        detection_gates={}
        for name,b in baseline['fixed_conf025_iou050'].items():
            c=candidate['fixed_conf025_iou050'][name]
            detection_gates[name]=dict(TP_before=b['TP'],TP_after=c['TP'],precision_before=b['precision'],precision_after=c['precision'],
                passed=c['TP']>=b['TP'] and c['precision']>=b['precision'])
        devbase=scores(read(baseline_root/'baseline_publicdev_score/decisions.json'),PARENT/'public_dev_001/manifest.json')
        gates=dict(float=state['float_gate'],q15_primary=dominates(state['q15_oldval'],base_scores),
            q15_all_waste_classes=all(after[c]['correct']>=before[c]['correct'] for c in before),
            q15_all_detection_classes=all(v['passed'] for v in detection_gates.values()),
            q15_publicdev=dominates(state['q15_publicdev'],devbase,False))
        state.update(gates=gates,subject_by_class=dict(baseline=before,candidate=after),detection_gates=detection_gates,
            baseline_q15=base_scores,baseline_publicdev=devbase,accepted_offline=all(gates.values()),
            status='COMPLETED_OFFLINE_ACCEPTED_FOR_REVIEW' if all(gates.values()) else 'COMPLETED_OFFLINE_REJECTED',
            decision='NO_AUTOMATIC_DEPLOYMENT',finished_unix=time.time())
        persist();print(str(state['gates']),flush=True)
    except BaseException as error:
        state.update(status='failed',error=repr(error));persist();raise
    finally:
        state['original_deployment_unchanged']=sha(blob)==oldblob;persist()

if __name__=='__main__':main()
