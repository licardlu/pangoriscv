"""Predeclare a reviewed foam-data increment, keeping the deployed QAT setup."""
import argparse
from pathlib import Path
import shutil
from adapt_quant_heads import read,save,sha,targets_letterbox
from train_qat_tail import verify


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--reference',type=Path,required=True)
    p.add_argument('--data',type=Path,required=True)
    p.add_argument('--out',type=Path,required=True)
    a=p.parse_args();ref,data,out=a.reference.resolve(),a.data.resolve(),a.out.resolve()
    prior=verify(ref);report=read(data/'result.json')
    assert report['status']=='FROZEN_REVIEWED_FUTURE_TRAINING_NOT_YET_TRAINED'
    assert report['base_manifest_sha256']==prior['manifest_sha256'] and report['dev_rows_unchanged']
    before=read(ref/'unique_train.json');targets=read(ref/'targets.json')
    assert len(before)==len(targets)==8508 and sha(ref/'targets.json')==prior['target_reference_sha256']
    rows=read(data/'manifest.json');unique={}
    for row in rows:
        if row['split']!='train':continue
        if row['image_sha256'] in unique:assert unique[row['image_sha256']]['boxes']==row['boxes']
        unique[row['image_sha256']]=row
    old={r['image_sha256'] for r in before};assert old.issubset(unique)
    added=sorted((r for k,r in unique.items() if k not in old),key=lambda r:r['image_sha256'])
    assert len(added)==70
    for row in added:
        assert sha(row['prepared_image'])==row['image_sha256'] and sha(row['label'])==row['label_sha256']
    after=before+added;ids={r['image_sha256']:i for i,r in enumerate(after)}
    draws=[ids[r['image_sha256']] for r in rows if r['split']=='train']
    targets += [targets_letterbox(r['boxes'],r['width'],r['height']) for r in added]
    assert len(after)==8578 and len(draws)==14194
    out.mkdir(parents=True,exist_ok=False)
    save(out/'unique_train.json',after);save(out/'targets.json',targets);save(out/'draw_indices.json',draws)
    plan=dict(prior)
    plan.update(hypothesis='Foam containers remain underrepresented in the reviewed kitchen/background increment. Add70 explicitly reviewed foam source scenes with duplicated source polygon/bbox labels merged per physical instance. Exclude ambiguous plate/bowl material and secondary unlabelled waste. Keep deployed initialization, matching frozenQ15 profile, same selected tail layers/loss/optimizer and fixed3final epochs as contextQAT. No threshold, calibration or epoch sweep; no prior candidate weights inherited.',
        manifest=str(data/'manifest.json'),manifest_sha256=sha(data/'manifest.json'),
        unique_train=8578,draws_per_epoch=14194,
        unique_train_sha256=sha(out/'unique_train.json'),draw_indices_sha256=sha(out/'draw_indices.json'),
        target_reference=str(out/'targets.json'),target_reference_sha256=sha(out/'targets.json'),
        reuse_feature_cache=str(ref),data_review_result_sha256=sha(data/'result.json'),
        new_source_images=70,new_upstream_augmented_views=0,new_camera_station_captures=0,
        derived_empty_crops=0,derived_orientation_files=0,added_draws_per_file=2,
        independent_new_validation_images=0,count_note=report['image_count_note'],
        new_data_ledger_sha256=sha(data/'foam_review_ledger.json'),
        reference_cache_requirement='Reuse only identity- and parameter-verified8508-file prefix from deployed-initialized context experiment.',
        deadline_utc='2026-11-18T04:00:00Z')
    save(out/'plan.json',plan)
    frozen=out/'frozen_scripts';frozen.mkdir()
    for name in ['prepare_reviewed_foam_qat.py','train_qat_tail.py','qat_tail.py','export_qat_tail.py',
                 'evaluate_quant_head_adaptation.py','run_predeclared_qat_queue.py']:
        shutil.copyfile(Path(__file__).parent/name,frozen/name)
    verify(out);print(dict(experiment=str(out),unique_train=8578,draws=14194),flush=True)


if __name__=='__main__':main()
