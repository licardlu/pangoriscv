"""Additional frozen 77-image development diagnostic, without changing gates."""
import argparse
import os
import subprocess
from pathlib import Path

from adapt_quant_heads import ROOT, PARENT, read, save, sha


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--experiment', type=Path, required=True)
    a = p.parse_args()
    exp = a.experiment.resolve()
    evaluation = exp / 'evaluation'
    state = read(evaluation / 'state.json')
    assert state['status'].startswith('COMPLETED_')
    cp = exp / 'training/final.pt'
    assert sha(cp) == state['checkpoint_sha256']
    tools = ROOT / 'project/trash_sorting/tools/overnight'
    source = ROOT / 'project/trash_sorting/candidates/continuation_023/source'
    blob = source / 'yolo/model/model.bin'
    before = sha(blob)
    assert before == '7a0765a6f275f3c06d838f924d73542783ca55e131509aa1b546efc98bd65728'
    photos = ROOT / 'build/overnight_20261116/numeric_newval_inventory_001'
    manifest = ROOT / 'build/overnight_20261116/reserved_newval_001/manifest.json'
    numeric = evaluation / 'numeric_continuation'
    scored = evaluation / 'score_continuation'
    env = os.environ.copy()
    env['PYTHONUTF8'] = '1'
    commands = [
        ('numeric_continuation', [tools/'check_deployment.py', '--deployment', evaluation/'quant',
            '--yolo', ROOT/'build/overnight_20261116/upstream/yolov5-7.0',
            '--cc', ROOT/'build/overnight_20261116/cc_adapter.exe', '--clang-host', '--exact-q16-head',
            '--out', numeric, '--checkpoint', cp, '--expected-checkpoint-sha256', sha(cp),
            '--source-dir', source, '--photos', photos, '--linear-o2', '--compact-scratch']),
        ('score_continuation', [tools/'score_numeric_validation.py', '--numeric', numeric,
            '--photos', photos, '--manifest', manifest, '--policy-replay', PARENT/'replay_oldval_004',
            '--source-dir', source, '--out', scored]),
    ]
    for name, args in commands:
        print('START ' + name, flush=True)
        with (evaluation / (name + '.log')).open('x', encoding='utf8') as log:
            subprocess.run([str(ROOT/'build/trash_train_env/Scripts/python.exe'), *map(str, args)],
                cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT, check=True)
    baseline = read(exp.parent / 'baseline_continuation_current_policy/decisions.json')
    candidate = read(scored / 'decisions.json')
    assert set(baseline) == set(candidate) and len(candidate) == 77
    gains = sorted(k for k in candidate if candidate[k]['correct_class_and_iou050'] and not baseline[k]['correct_class_and_iou050'])
    losses = sorted(k for k in candidate if baseline[k]['correct_class_and_iou050'] and not candidate[k]['correct_class_and_iou050'])
    assert sha(blob) == before
    save(evaluation/'continuation_comparison.json', dict(status='COMPLETED_DEVELOPMENT_DIAGNOSTIC',
        images=77, baseline_correct=sum(d['correct_class_and_iou050'] for d in baseline.values()),
        candidate_correct=sum(d['correct_class_and_iou050'] for d in candidate.values()),
        gains=gains, losses=losses, checkpoint_sha256=sha(cp), original_deployment_unchanged=True,
        acceptance_gates_modified=False, test_images_or_labels_read=False,
        manifest_sha256=sha(manifest), numeric_result_sha256=sha(numeric/'result.json'),
        baseline_decisions_sha256=sha(exp.parent/'baseline_continuation_current_policy/decisions.json'),
        candidate_decisions_sha256=sha(scored/'decisions.json')))
    print('CONTINUATION_DIAGNOSTIC_COMPLETE', flush=True)


if __name__ == '__main__':
    main()
