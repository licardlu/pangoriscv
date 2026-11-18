"""Freeze one explicit no-waste supervision hypothesis, preserving original initialization."""
from collections import Counter
from pathlib import Path
import argparse
import shutil
from adapt_quant_heads import ROOT,read,save,sha
from train_qat_tail import verify


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--reference',type=Path,required=True);p.add_argument('--out',type=Path,required=True)
    a=p.parse_args();reference=a.reference.resolve();prior=verify(reference);out=a.out.resolve()
    assert not out.exists();out.mkdir(parents=True)
    cached=read(reference/'cache_result.json');assert cached['status']=='PASS'
    for name in ['unique_train.json','draw_indices.json','targets.json']:shutil.copyfile(reference/name,out/name)
    rows=read(out/'unique_train.json');negative=[i for i,r in enumerate(rows) if not any(int(b[0])<4 for b in r['boxes'])]
    sources=Counter(rows[i]['source'] for i in negative)
    assert set(sources).issubset({'hagrid_hand_localisation','personal_empty_hand','continuation_empty_hand',
        'targeted_reviewed_background_crop','reviewed_hagrid_background_crop'})
    preflight=ROOT/'build/negative_waste_preflight_20261118_001/result.json'
    helper=Path(__file__).with_name('negative_waste_supervision.py')
    assert read(preflight)['status']=='PASS' and read(preflight)['source_sha256']==sha(helper)
    plan=dict(prior)
    plan.update(hypothesis='The 13-tail model still produces large waste boxes on labelled empty hands and background. Ordinary YOLO classification supervision is applied at positive anchors, whereas existing positive-only teacher does not constrain no-waste false classes. On the exact same9349 files/18022 draws and original deployment initialization, add fixed-strength0.5 auxiliary suppression of top32 objectness-times-waste-class scores per class per explicitly labelled no-waste image, pooled across three heads. Preserve hand supervision, all positive-image GT, teacher5, frozen scales/BN, 13 convolutions, three epochs and original evaluation gates. No new photos, threshold tuning or rejected-weight continuation. Shared objectness may reduce hand recall, which the unchanged gates must detect.',
        reuse_feature_cache=str(reference),target_reference=str(out/'targets.json'),target_reference_sha256=sha(out/'targets.json'),
        unique_train_sha256=sha(out/'unique_train.json'),draw_indices_sha256=sha(out/'draw_indices.json'),
        negative_waste_strength=.5,negative_waste_topk=32,negative_waste_source_sha256=sha(helper),
        negative_waste_preflight=str(preflight),negative_waste_preflight_sha256=sha(preflight),
        negative_waste_eligible_files=len(negative),negative_waste_source_counts=dict(sources),
        negative_waste_training_draws=sum(Counter(read(out/'draw_indices.json'))[i] for i in negative),
        count_note='Same9349 training file identities and18022 repeated draws; zero new photos. Existing derivatives remain, not20000qualified originals.',
        new_source_image_files=0,new_box_instances={},new_data_manifests_sha256={},new_data_review_results_sha256={},
        unchanged_reference_plan=str(reference/'plan.json'),unchanged_reference_plan_sha256=sha(reference/'plan.json'))
    save(out/'plan.json',plan);frozen=out/'frozen_scripts';frozen.mkdir()
    for name in ['prepare_negative_waste_qat.py','negative_waste_supervision.py','preflight_negative_waste.py',
        'train_qat_tail.py','qat_tail.py','fiveclass_distillation.py','run_predeclared_qat_queue.py','export_qat_tail.py']:
        shutil.copyfile(Path(__file__).with_name(name),frozen/name)
    verify(out)
    save(out/'preparation.json',dict(status='FROZEN_FUTURE_FIXED_HYPOTHESIS',negative_sources=dict(sources),
        negative_files=len(negative),new_images=0,original_initialization_preserved=True,
        acceptance_gates_changed=False,final_test_read=False))
    print(dict(experiment=str(out),negative_files=len(negative),negative_sources=dict(sources)),flush=True)


if __name__=='__main__':main()
