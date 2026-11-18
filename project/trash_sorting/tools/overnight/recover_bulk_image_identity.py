"""Record upstream JPEG repairs without changing the frozen plan or any images."""
import argparse
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import shutil
from adapt_quant_heads import ROOT, read, save, sha
from train_full_orientation import verify_full_plan


def verify_recovery(exp):
    plan = verify_full_plan(exp)
    record = read(exp/'image_identity_recovery.json')
    assert record['original_manifest_sha256'] == plan['manifest_sha256']
    data = Path(record['recovered_data'])
    for name, digest in record['files'].items():
        assert sha(data/name) == digest
    original = read(plan['manifest'])
    recovered = read(data/'manifest.json')
    assert len(original) == len(recovered)
    changes = {r['path']: r for r in record['changes']}
    assert changes
    log = (exp/'training.log').read_text(encoding='utf8', errors='replace')
    for old, new in zip(original, recovered):
        expected = dict(old)
        if old['prepared_image'] in changes:
            change = changes[old['prepared_image']]
            assert old['split'] == 'train'
            assert old['image_sha256'] == change['before_sha256']
            assert sha(old['prepared_image']) == change['after_sha256']
            assert change['path']+': corrupt JPEG restored and saved' in log
            assert sha(old['label']) == old['label_sha256']
            expected['image_sha256'] = change['after_sha256']
        assert new == expected
    for row in read(exp/'calibration_reference.json')['calibration_images']:
        assert sha(row['path']) == row['sha256']
    return data


def prepare(exp):
    plan = verify_full_plan(exp)
    rows = read(exp/'unique_train.json')
    def check(row):
        assert sha(row['label']) == row['label_sha256']
        actual = sha(row['prepared_image'])
        if actual != row['image_sha256']:
            return dict(path=row['prepared_image'], before_sha256=row['image_sha256'], after_sha256=actual,
                        source=row['source'], label_sha256=row['label_sha256'],
                        original_hardlink_path=row['original_prepared_image'])
    with ThreadPoolExecutor(max_workers=4) as pool:
        changes = [r for r in pool.map(check, rows) if r]
    assert len(changes) == 1, changes
    assert changes[0]['before_sha256'] == 'fa94720efdadcc75507a42ff7b73ce5f59909a7c0f7269ee1677bc36c08a5138'
    selected = {r['path'] for r in read(exp/'calibration_reference.json')['calibration_images']}
    assert not selected.intersection(c['path'] for c in changes)
    original_data = Path(plan['manifest']).parent
    data = exp.parent/'dataset_identity_recovery_001'
    data.mkdir(exist_ok=False)
    for name in ['train.txt', 'val.txt', 'result.json']:
        shutil.copyfile(original_data/name, data/name)
    recovered = read(plan['manifest'])
    by_path = {r['path']: r for r in changes}
    for row in recovered:
        if row['prepared_image'] in by_path:
            assert row['split'] == 'train'
            row['image_sha256'] = by_path[row['prepared_image']]['after_sha256']
    save(data/'manifest.json', recovered)
    (data/'data.yaml').write_text('path: '+data.as_posix()+'\ntrain: train.txt\nval: val.txt\nnc: 5\nnames: [kitchen, recyclable, hazardous, other, hand]\n', encoding='utf8')
    save(exp/'image_identity_recovery.json', dict(status='RECORDED_UPSTREAM_JPEG_REPAIR',
        original_manifest_sha256=plan['manifest_sha256'], recovered_data=str(data), changes=changes,
        files={n:sha(data/n) for n in ['manifest.json','train.txt','val.txt','result.json','data.yaml']},
        original_plan_unchanged=True, labels_splits_paths_unchanged=True, training_not_repeated=True,
        frozen_160_calibration_identities_unchanged=True,
        reason='YOLO verify_image_label repaired one corrupt JPEG in place during dataset initialization; hardlink shared its bytes with source. Record actual trained bytes for evaluation, never silently alter original manifest.'))
    verify_recovery(exp)
    print(changes, flush=True)


if __name__ == '__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--experiment',type=Path,required=True)
    prepare(p.parse_args().experiment.resolve())
