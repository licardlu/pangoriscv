"""Freeze one deadline-limited epoch on newly reviewed battery/hand views.

Predeclare before the teacher's validation result; never alter in-flight data.
Uses original deployment initialization, not any rejected candidate.
"""
from pathlib import Path
import shutil
from adapt_quant_heads import ROOT,read,save,sha,targets_letterbox
from train_qat_tail import verify


def main():
    ref=ROOT/'build/quant_reviewed_foam_20261118_001/experiment_001';prior=verify(ref)
    mju=ROOT/'build/noon_continuation_20261118_001/research/handheld_mirrors_001/mju_train_001/audit_002'
    packs=[mju/'frozen_hand_crops_001',mju/'remaining_review_001/frozen_hand_crops_001',
        ROOT/'build/noon_continuation_20261118_001/research/battery_visual_001/Fetan-Love_AI-battery-detection-with-yolo_retry_001/audit_002/frozen_additions_001']
    additions=[r for p in packs for r in read(p/'manifest.json')]
    assert len(additions)==19
    before=read(ref/'unique_train.json');old={r['image_sha256'] for r in before}
    assert len({r['image_sha256'] for r in additions})==19
    for r in additions:
        assert r['split']=='train' and r['image_sha256'] not in old and r['historical_nearest_phash']>6
        assert sha(r['prepared_image'])==r['image_sha256'] and sha(r['label'])==r['label_sha256']
    base=read(prior['manifest']);data=ROOT/'build/final_reviewed_increment_20261118_001/dataset_001'
    data.mkdir(parents=True,exist_ok=False)
    rows=base+[dict(r,reviewed_increment_draw=n) for n in range(2) for r in additions]
    assert [r for r in rows if r['split']!='train']==[r for r in base if r['split']!='train']
    save(data/'manifest.json',rows)
    for split in ['train','val']:
        (data/(split+'.txt')).write_text(''.join(r['prepared_image']+'\n' for r in rows if r['split']==split),encoding='utf8')
    (data/'data.yaml').write_text('path: '+data.as_posix()+'\ntrain: train.txt\nval: val.txt\nnc: 5\nnames: [kitchen, recyclable, hazardous, other, hand]\n',encoding='utf8')
    note='8597train file identities includes376rotations,24backgroundcrops,47upstream augmentedfruitviews and8MJUhandcrops;14232drawsare not independentphotos.11newbatteryphotosshareonecaptureandfewphysicalbatteries;8handcropsarederived. Not20000qualifiedindependentphotos.'
    save(data/'result.json',dict(status='FROZEN_REVIEWED_FUTURE_TRAINING_NOT_YET_TRAINED',
        base_manifest_sha256=sha(prior['manifest']),new_source_images=11,new_derived_hand_crops=8,
        reviewed_battery_boxes=41,reviewed_recyclable_boxes=8,reviewed_hand_boxes=10,
        source_manifests={str(p):sha(p/'manifest.json') for p in packs},
        unique_file_identities=8597,training_draws=14232,dev_rows_unchanged=True,
        image_count_note=note,final_test_files_opened=False))
    exp=ROOT/'build/quant_final_reviewed_increment_20261118_001/experiment_001';exp.mkdir(parents=True,exist_ok=False)
    added=sorted(additions,key=lambda r:r['image_sha256']);after=before+added
    ids={r['image_sha256']:i for i,r in enumerate(after)};targets=read(ref/'targets.json')
    targets += [targets_letterbox(r['boxes'],r['width'],r['height']) for r in added]
    draws=[ids[r['image_sha256']] for r in rows if r['split']=='train']
    assert len(after)==8597 and len(draws)==14232 and len(targets)==8597
    save(exp/'unique_train.json',after);save(exp/'targets.json',targets);save(exp/'draw_indices.json',draws)
    plan=dict(prior)
    plan.update(hypothesis='Evaluate a single predeclared deadline-limited supervisedQAT epoch on19new reviewed views:11AA batteryphotos with41completeboxes and8derived realhand/objectcrops with8objects10hands. Initialize original deployedcheckpoint/scales, append to same8578trainingfiles and reuse only verifiedsame-initializationcache. Oneepoch chosen beforeteacher validation solely to fitnoon, not by searching validation. No teacherterm, threshold/calibration/epoch sweep, failedcandidateinheritance or gatechange. Newdataandshorterdurationbothchange; cannot attribute gains solelyto newdata.',
        manifest=str(data/'manifest.json'),manifest_sha256=sha(data/'manifest.json'),epochs=1,
        unique_train=8597,draws_per_epoch=14232,unique_train_sha256=sha(exp/'unique_train.json'),
        draw_indices_sha256=sha(exp/'draw_indices.json'),target_reference=str(exp/'targets.json'),
        target_reference_sha256=sha(exp/'targets.json'),reuse_feature_cache=str(ref),
        checkpoint_selection='Only final firstepoch; predeclaredbeforepriorvalidation solely fordeadline. Noearlystoporvalchoice.',
        data_review_result_sha256=sha(data/'result.json'),new_source_images=11,new_derived_hand_crops=8,
        count_note=note,new_data_ledger_sha256=sha(data/'result.json'),
        deadline_utc='2026-11-18T04:00:00Z',latest_start_utc='2026-11-18T03:35:00Z',
        resource_limit='Oneepoch~10min pluscache/fullofflineevaluation~14min; deferif predecessor endsafter11:35CST.')
    save(exp/'plan.json',plan)
    frozen=exp/'frozen_scripts';frozen.mkdir()
    for name in ['prepare_final_reviewed_increment.py','train_qat_tail.py','qat_tail.py','export_qat_tail.py',
                 'evaluate_quant_head_adaptation.py','run_predeclared_qat_queue.py']:
        shutil.copyfile(Path(__file__).parent/name,frozen/name)
    verify(exp);print(dict(experiment=str(exp),unique_train=8597,draws=14232,epochs=1),flush=True)


if __name__=='__main__':main()
