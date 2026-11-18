"""Predeclare a data-only change to deployed-initialized fixed-profile tail QAT."""
import argparse
from pathlib import Path

from adapt_quant_heads import read, save, sha, targets_letterbox
from train_qat_tail import verify


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--reference', type=Path, required=True)
    p.add_argument('--data', type=Path, required=True)
    p.add_argument('--out', type=Path, required=True)
    a = p.parse_args()
    ref, data, out = a.reference.resolve(), a.data.resolve(), a.out.resolve()
    prior = verify(ref)
    report = read(data/'result.json')
    assert report['status'] == 'FROZEN_REVIEWED_NOT_YET_TRAINED'
    assert report['base_manifest_sha256'] == prior['manifest_sha256']
    assert report['val_test_metadata_unchanged'] and not report['final_test_images_or_labels_read']
    out.mkdir(parents=True, exist_ok=False)
    manifest = read(data/'manifest.json')
    before = read(ref/'unique_train.json')
    old_ids = {r['image_sha256'] for r in before}
    unique = {}
    for r in manifest:
        if r['split'] != 'train':
            continue
        key = r['image_sha256']
        if key in unique:
            assert unique[key]['boxes'] == r['boxes']
        unique[key] = r
    assert old_ids.issubset(unique)
    added = sorted((r for k,r in unique.items() if k not in old_ids), key=lambda r:r['image_sha256'])
    assert len(added) == 54
    rows = before + added
    ids = {r['image_sha256']: i for i,r in enumerate(rows)}
    draws = [ids[r['image_sha256']] for r in manifest if r['split']=='train']
    assert len(rows) == report['total_train_file_identities'] == 7958
    assert len(draws) == report['draws_per_epoch'] == 12878
    cached = read(ref/'cache_result.json')
    assert cached['status'] == 'PASS' and sha(cached['target_reference']) == cached['target_sha256']
    targets = read(cached['target_reference'])
    assert len(targets) == len(before)
    targets += [targets_letterbox(r['boxes'],r['width'],r['height']) for r in added]
    save(out/'unique_train.json', rows)
    save(out/'draw_indices.json', draws)
    save(out/'targets.json', targets)
    plan = dict(prior)
    plan.update(hypothesis='The current whitelist has no pure empty background. Add 40 newly reviewed TACO source images (mostly foam, paper/tissue and two food instances) plus 14 explicitly reviewed empty train-scene crops, with complete mapped boxes and two added hand boxes. Keep deployed initialization, frozen scale profile and identical fixed 3-epoch optimizer/loss/layer schedule; test the data change only.',
        manifest=str(data/'manifest.json'),manifest_sha256=sha(data/'manifest.json'),
        unique_train=len(rows),draws_per_epoch=len(draws),
        unique_train_sha256=sha(out/'unique_train.json'),draw_indices_sha256=sha(out/'draw_indices.json'),
        target_reference=str(out/'targets.json'),target_reference_sha256=sha(out/'targets.json'),
        reuse_feature_cache=str(ref),data_review_result_sha256=sha(data/'result.json'),
        new_source_photos=40,derived_empty_crops=14,added_draws_per_file=4,
        independent_new_validation_images=0,
        count_note='7958 cached train files includes 14 derived background crops; those crops are not new source photos or physical objects.')
    save(out/'plan.json', plan)
    print(plan, flush=True)


if __name__ == '__main__':
    main()
