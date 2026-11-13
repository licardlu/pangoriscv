"""Replay fixed floating detections with an isolated C contact-policy header."""
import argparse
import ctypes as C
from collections import Counter
import hashlib
import json
import os
from pathlib import Path
import subprocess
from evaluate_hand_branch import Box, Target

ROOT = Path(__file__).resolve().parents[3]


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def main():
    p = argparse.ArgumentParser(description=__doc__)
    for arg in ('predictions', 'header', 'cc', 'out'):
        p.add_argument('--'+arg, type=Path, required=True)
    p.add_argument('--ignore-hands', action='store_true',
                   help='Counterfactual largest-object selection from identical waste predictions')
    a = p.parse_args()
    a.out = a.out.resolve()
    a.out.mkdir(parents=True, exist_ok=False)
    (a.out/'temp').mkdir()
    (a.out/'yolo_contact_policy.h').write_bytes(a.header.read_bytes())
    sw = ROOT/'project/trash_sorting/source/yolo/software'
    cc = a.cc.resolve()
    env = os.environ.copy()
    env['PATH'] = str(cc.parent)+os.pathsep+env.get('PATH', '')
    env['TMP'] = env['TEMP'] = str(a.out/'temp')
    command = [str(cc), '-std=c11', '-O2', '-Wall', '-Wextra', '-Werror', '-shared',
        '-I'+str(a.out), '-I'+str(sw), str(ROOT/'project/trash_sorting/tools/test_contact_policy.c'),
        '-lm', '-o', str(a.out/'policy.dll')]
    build = subprocess.run(command, env=env, capture_output=True, text=True)
    (a.out/'build.log').write_text(build.stdout+build.stderr, encoding='utf8')
    build.check_returncode()
    lib = C.CDLL(str(a.out/'policy.dll'))
    select = lib.policy_select_contact
    select.argtypes = [C.POINTER(Box), C.c_uint32, C.POINTER(Box), C.c_uint32, C.c_float, C.c_float]
    select.restype = Target
    rows = json.loads(a.predictions.read_text(encoding='utf8'))
    stats, decisions = {}, []
    for row in rows:
        objects, hands = row['waste'], [] if a.ignore_hands else row['hands']
        ob = (Box*len(objects))(*[Box(*b[:5], int(b[5])) for b in objects])
        hb = (Box*len(hands))(*[Box(*b[:5], 4) for b in hands])
        t = select(ob, len(ob), hb, len(hb), row['width'], row['height'])
        selected = objects[t.object_index] if t.object_index >= 0 else None
        group = str(row.get('physical_group') or row.get('hand_annotation_source') or row['source_group'])
        s = stats.setdefault(group, Counter())
        s['images'] += 1
        s['changed'] += t.object_index != row['object_index']
        s['selected'] += selected is not None
        item = dict(key=row['key'], original_index=row['object_index'], selected_index=t.object_index)
        if row.get('empty_hand'):
            s['empty_false_selection'] += selected is not None
        if row.get('held_truth'):
            truth = row['held_truth']
            xy = [v*(row['width'] if i%2 == 0 else row['height']) for i,v in enumerate(truth['xyxy'])]
            overlap = 0
            if selected:
                b = selected
                inter = max(0, min(b[2], xy[2])-max(b[0], xy[0]))*max(0, min(b[3], xy[3])-max(b[1], xy[1]))
                overlap = inter/((b[2]-b[0])*(b[3]-b[1])+(xy[2]-xy[0])*(xy[3]-xy[1])-inter)
            correct = overlap >= .5 and int(selected[5]) == truth['bin'] if selected else False
            s['subject_and_bucket_correct'] += correct
            item.update(subject_iou=overlap, correct=correct)
        if row.get('truth'):
            s['accepted_bucket'] += selected is not None and int(selected[5]) in row['truth'].get('accepted_bins', [row['truth']['bin']])
        decisions.append(item)
    report = dict(status='OFFLINE_FIXED_PREDICTION_C_REPLAY_NOT_MODEL_RETRAINING', summaries=stats,
        counterfactual_ignore_hands=a.ignore_hands,
        predictions_sha256=sha(a.predictions), policy_sha256=sha(a.header), script_sha256=sha(Path(__file__)),
        confidence_and_detections_unchanged=True, decisions=decisions, board_programmed=False)
    (a.out/'result.json').write_text(json.dumps(report, indent=2), encoding='utf8')
    print(json.dumps(stats), flush=True)


if __name__ == '__main__':
    main()
