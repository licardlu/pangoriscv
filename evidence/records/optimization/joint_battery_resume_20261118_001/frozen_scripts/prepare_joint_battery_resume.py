"""Freeze battery replay plus original-Q15 preservation on all reviewed classes."""
from collections import Counter
from datetime import datetime, timedelta, timezone
from pathlib import Path
import shutil
from adapt_quant_heads import ROOT, read, save, sha
from train_qat_tail import verify


def main():
    reference = ROOT/'build/quant_final_reviewed_increment_20261118_001/experiment_001'
    prior = verify(reference)
    parent = ROOT/'build/joint_battery_resume_20261118_001'
    out = parent/'experiment_001'
    out.mkdir(parents=True, exist_ok=False)
    unique = read(reference/'unique_train.json')
    draws = read(reference/'draw_indices.json')
    # Replay real battery-containing pictures, preserving all their hand/other GT.
    # Rotated derivatives are already represented and receive no extra weight.
    extra = [i for i, row in enumerate(unique)
             if 'battery' in row['source'].lower()
             and row['source'] != 'derived_battery_orientation'
             and any(int(b[0]) == 2 for b in row['boxes'])]
    assert extra and all(unique[i]['split'] == 'train' for i in extra)
    draws += extra * 2
    for name in ['unique_train.json', 'targets.json']:
        shutil.copyfile(reference/name, out/name)
    save(out/'draw_indices.json', draws)
    now = datetime.now(timezone.utc)
    deadline = now + timedelta(hours=12)
    plan = dict(prior)
    for key in ['deadline_utc', 'latest_start_utc', 'resource_limit']:
        plan.pop(key, None)
    plan.update(
        hypothesis='Joint supervised exact-Q15 training on every reviewed class, including latest 11 AA photos and 8 hand-held crops. Add two draws per real battery-containing file, excluding extra replay for rotated derivatives; retain original complete hand/object labels. Add the previously tested GT-gated frozen original deployed teacher (strength5) to preserve reliable predictions. Fixed3epochs and final checkpoint, not validation selection. This tests replay plus preservation jointly; gains cannot be attributed solely to more unique data.',
        epochs=3, draws_per_epoch=len(draws),
        manifest=str(prior['manifest']),
        reuse_feature_cache=str(reference),
        unique_train_sha256=sha(out/'unique_train.json'),
        draw_indices_sha256=sha(out/'draw_indices.json'),
        target_reference=str(out/'targets.json'),
        target_reference_sha256=sha(out/'targets.json'),
        deployed_q15_distillation_strength=5.,
        teacher_checkpoint_sha256=prior['checkpoint_sha256'],
        teacher_rule='Frozen original deployed Q15; GT class match, confidence>=.25, bbox IoU>=.5, class-balanced across five classes. No pseudo labels.',
        checkpoint_selection='Fixed final third epoch only; no early stopping or validation checkpoint selection.',
        extra_battery_file_identities=len(extra), extra_draws_per_battery=2,
        extra_battery_source_counts=dict(Counter(unique[i]['source'] for i in extra)),
        reference_cache_requirement='Exact verified identical initialization/profile and all8597 file identities in identical order.',
        count_note='8597 files includes existing derivatives; battery replay adds sampling draws, not new photos. Additional reviewed new sources will be frozen in a later distinct experiment.',
        authorized_resume_utc=now.isoformat(), user_training_window_end_utc=deadline.isoformat())
    save(out/'plan.json', plan)
    save(parent/'window.json', dict(start_utc=now.isoformat(), end_utc=deadline.isoformat(),
        target_usable_train_files=20000, count_policy='Do not count repeated sampling or derivatives as independent new photographs.',
        status='ACTIVE', hardware_authorized=False))
    frozen = out/'frozen_scripts'; frozen.mkdir()
    for name in ['prepare_joint_battery_resume.py','train_qat_tail.py','qat_tail.py',
                 'fiveclass_distillation.py','run_predeclared_qat_queue.py','export_qat_tail.py']:
        shutil.copyfile(Path(__file__).parent/name, frozen/name)
    verify(out)
    print(dict(experiment=str(out), unique_train=len(unique), draws=len(draws),
               extra_battery_files=len(extra), epochs=3, window_end_utc=deadline.isoformat()), flush=True)


if __name__ == '__main__':
    main()
