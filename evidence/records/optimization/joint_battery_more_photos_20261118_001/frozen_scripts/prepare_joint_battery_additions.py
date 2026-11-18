"""Freeze a data-only extension of joint supervised/Q15 preservation training."""
from pathlib import Path
import argparse
import shutil
from adapt_quant_heads import ROOT, read, save, sha, targets_letterbox
from train_qat_tail import verify


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--reference',type=Path,default=ROOT/'build/joint_battery_resume_20261118_001/experiment_001')
    parser.add_argument('--packs',type=Path,nargs='+',default=[ROOT/'build/joint_battery_resume_20261118_001/research/extras_remaining_001/frozen_additions_001'])
    parser.add_argument('--out',type=Path,default=ROOT/'build/joint_battery_additions_20261118_001')
    args=parser.parse_args()
    reference = args.reference.resolve()
    prior = verify(reference)
    packs = [p.resolve() for p in args.packs]
    additions = [r for pack in packs for r in read(pack/'manifest.json')]
    assert additions
    before = read(reference/'unique_train.json')
    known = {r['image_sha256'] for r in before}
    assert len({r['image_sha256'] for r in additions}) == len(additions)
    for r in additions:
        assert r['split'] == 'train' and r['image_sha256'] not in known
        assert r['historical_nearest_phash'] > 6
        assert sha(r['prepared_image']) == r['image_sha256'] and sha(r['label']) == r['label_sha256']
    root = args.out.resolve()
    data, exp = root/'dataset_001', root/'experiment_001'
    data.mkdir(parents=True, exist_ok=False); exp.mkdir()
    added = sorted(additions, key=lambda r:r['image_sha256'])
    unique = before+added
    draws = read(reference/'draw_indices.json')+list(range(len(before), len(unique)))*2
    targets = read(reference/'targets.json')+[targets_letterbox(r['boxes'],r['width'],r['height']) for r in added]
    base = read(prior['manifest'])
    held = [r for r in base if r['split'] != 'train']
    rows = [dict(unique[i], joint_additions_draw=j) for j,i in enumerate(draws)]+held
    save(data/'manifest.json', rows)
    for split in ['train', 'val']:
        (data/(split+'.txt')).write_text(''.join(r['prepared_image']+'\n' for r in rows if r['split']==split), encoding='utf8')
    (data/'data.yaml').write_text('path: '+data.as_posix()+'\ntrain: train.txt\nval: val.txt\nnc: 5\nnames: [kitchen, recyclable, hazardous, other, hand]\n', encoding='utf8')
    save(exp/'unique_train.json', unique); save(exp/'draw_indices.json', draws); save(exp/'targets.json', targets)
    plan = dict(prior)
    plan.update(hypothesis=f'Extend the predeclared joint battery replay and frozen original Q15 teacher experiment with{len(additions)} newly reviewed product battery pictures/{sum(len(r["boxes"]) for r in additions)}completeboxes. Keep original deployment initialization, same five-class supervision, exact scales, optimizer, fixed3epochs, teacherstrength5 and existingdraws. Add2draws per newfile. This is a new data experiment, not continuation from a failedcandidate. More productpictures do not establish better realhandheld generalization.',
        manifest=str(data/'manifest.json'),manifest_sha256=sha(data/'manifest.json'),
        unique_train=len(unique),draws_per_epoch=len(draws),
        unique_train_sha256=sha(exp/'unique_train.json'),draw_indices_sha256=sha(exp/'draw_indices.json'),
        target_reference=str(exp/'targets.json'),target_reference_sha256=sha(exp/'targets.json'),
        reuse_feature_cache=str(reference),new_data_manifests_sha256={str(pack):sha(pack/'manifest.json') for pack in packs},
        new_data_review_results_sha256={str(pack):sha(pack/'result.json') for pack in packs},new_source_image_files=len(additions),
        count_note=f'{len(unique)}trainingfileidentities include existing derivatives;{len(draws)}draws are repeated sampling, not newphotos.{len(additions)}newfiles are mainly productpictures/renderings; physicalidentity and cameraindependence unknown. Not20000qualifiedindependentphotos.',
        checkpoint_selection='Fixed final third epoch; no checkpoint/threshold/scale search.')
    save(exp/'plan.json',plan)
    save(data/'result.json',dict(status='FROZEN_REVIEWED_FUTURE_TRAINING_NOT_YET_TRAINED',
        new_source_image_files=len(additions),new_battery_boxes=sum(len(r['boxes']) for r in additions),
        unique_train_files=len(unique),draws_per_epoch=len(draws),derived_images_added=0,
        dev_rows_unchanged=True,final_test_files_read=False,review_packs=list(map(str,packs))))
    frozen=exp/'frozen_scripts';frozen.mkdir()
    for name in ['prepare_joint_battery_additions.py','train_qat_tail.py','qat_tail.py',
                 'fiveclass_distillation.py','run_predeclared_qat_queue.py','export_qat_tail.py']:
        shutil.copyfile(Path(__file__).parent/name,frozen/name)
    verify(exp)
    print(dict(experiment=str(exp),unique_train=len(unique),draws_per_epoch=len(draws),new_files=len(additions)),flush=True)


if __name__=='__main__':main()
