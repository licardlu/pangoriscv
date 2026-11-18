"""Predeclare the reviewed glass/hand and multi-battery data-only QAT change."""
import argparse
from pathlib import Path
import shutil

from adapt_quant_heads import read, save, sha, targets_letterbox
from train_qat_tail import verify


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--reference',type=Path,required=True)
    p.add_argument('--data',type=Path,required=True)
    p.add_argument('--out',type=Path,required=True)
    a = p.parse_args(); ref,data,out = a.reference.resolve(),a.data.resolve(),a.out.resolve()
    prior = verify(ref); report = read(data/'result.json')
    assert report['status'] == 'FROZEN_REVIEWED_FUTURE_TRAINING_NOT_YET_TRAINED'
    assert report['base_manifest_sha256'] == prior['manifest_sha256']
    assert report['dev_rows_unchanged'] and not report['final_test_files_opened']
    assert not report['current_experiments_changed']
    before = read(ref/'unique_train.json'); targets = read(ref/'targets.json')
    assert sha(ref/'targets.json') == prior['target_reference_sha256']
    assert len(targets) == len(before) == 8372
    rows = read(data/'manifest.json'); unique = {}
    for row in rows:
        if row['split'] != 'train':
            continue
        key = row['image_sha256']
        if key in unique:
            assert unique[key]['boxes'] == row['boxes']
        unique[key] = row
    old_ids = {r['image_sha256'] for r in before}
    assert old_ids.issubset(unique)
    added = sorted((r for k,r in unique.items() if k not in old_ids),key=lambda r:r['image_sha256'])
    assert len(added) == 79
    for row in added:
        assert sha(row['prepared_image']) == row['image_sha256']
        assert sha(row['label']) == row['label_sha256']
    after = before+added; ids = {r['image_sha256']:i for i,r in enumerate(after)}
    draws = [ids[r['image_sha256']] for r in rows if r['split']=='train']
    targets += [targets_letterbox(r['boxes'],r['width'],r['height']) for r in added]
    assert len(after) == report['unique_file_identities'] == 8451
    assert len(draws) == report['training_draws'] == 13940
    out.mkdir(parents=True,exist_ok=False)
    save(out/'unique_train.json',after); save(out/'targets.json',targets); save(out/'draw_indices.json',draws)
    plan = dict(prior)
    plan.update(hypothesis='Product-only single batteries do not add transparent glass contours, handles or multi-instance layouts. Add exactly58 individually reviewed glass source files (70 complete glass boxes and8 hand boxes) and21 multi-battery source files (73 complete battery boxes). Keep deployed initialization, frozen Q15 activation profile, selected tail layers, loss and fixed3-epoch schedule identical. This is a predeclared data change, not a threshold, calibration, epoch or validation-based optimizer search.',
        manifest=str(data/'manifest.json'),manifest_sha256=sha(data/'manifest.json'),
        unique_train=len(after),draws_per_epoch=len(draws),
        unique_train_sha256=sha(out/'unique_train.json'),draw_indices_sha256=sha(out/'draw_indices.json'),
        target_reference=str(out/'targets.json'),target_reference_sha256=sha(out/'targets.json'),
        reuse_feature_cache=str(ref),data_review_result_sha256=sha(data/'result.json'),
        new_source_images=79,new_camera_station_captures=0,derived_empty_crops=0,
        derived_orientation_files=0,added_draws_per_file=2,independent_new_validation_images=0,
        new_data_ledger_sha256=sha(data/'glass_review_ledger.json'),
        count_note=report['image_count_note'],
        reference_cache_requirement='Reference cache must finish with identity and array SHA checks before this cache starts; not available at plan creation time.',
        deadline_utc='2026-11-18T04:00:00Z')
    plan.pop('new_source_photos',None)
    save(out/'plan.json',plan)
    frozen = out/'frozen_scripts'; frozen.mkdir()
    for name in ['prepare_reviewed_shape_qat.py','train_qat_tail.py','qat_tail.py','export_qat_tail.py',
                 'evaluate_quant_head_adaptation.py','run_predeclared_qat_queue.py']:
        src = Path(__file__).parent/name
        shutil.copyfile(src,frozen/name)
    verify(out)
    print(dict(experiment=str(out),unique_train=len(after),draws=len(draws),added_source_images=79),flush=True)


if __name__ == '__main__':
    main()
