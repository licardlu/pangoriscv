"""One frozen-model final battery test. This is offline Q15+C, not board accuracy.

Preflight never runs inference. Formal run is time-gated and creates an exclusive
output directory before starting the arithmetic checker; failures stay recorded.
"""
import argparse
from collections import Counter
import ctypes as C
from datetime import datetime, timezone
import hashlib
import json
import math
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[3]
SW = ROOT / 'project/trash_sorting/source/yolo/software'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text(encoding='utf8'))


def write(path, value):
    path.write_text(json.dumps(value, indent=2), encoding='utf8')


class Box(C.Structure):
    _fields_ = [(k, C.c_float) for k in ('x1', 'y1', 'x2', 'y2', 'score')] + [('category', C.c_uint32)]


class Target(C.Structure):
    _fields_ = [('object_index', C.c_int), ('hand_index', C.c_int), ('hand_seen', C.c_uint),
                *[(k, C.c_float) for k in ('roi_x1', 'roi_y1', 'roi_x2', 'roi_y2')]]


def iou(a, b):
    overlap = max(0, min(a[2], b[2])-max(a[0], b[0])) * max(0, min(a[3], b[3])-max(a[1], b[1]))
    union = max(0, a[2]-a[0])*max(0, a[3]-a[1]) + (b[2]-b[0])*(b[3]-b[1]) - overlap
    return overlap/union if union > 0 else 0


def compile_policy(cc, out):
    env = os.environ.copy()
    env['PATH'] = str(cc.parent)+os.pathsep+env.get('PATH', '')
    temp = out/'temp'; temp.mkdir()
    env['TMP'] = env['TEMP'] = str(temp.resolve())
    dll = (out/'policy.dll').resolve()
    command = [str(cc), '-O2', '-std=c11', '-Wall', '-Wextra', '-Werror', '-shared',
               '-I'+str(SW), str(ROOT/'project/trash_sorting/tools/test_contact_policy.c'), '-lm', '-o', str(dll)]
    result = subprocess.run(command, capture_output=True, text=True, env=env)
    (out/'build.log').write_text(result.stdout+result.stderr, encoding='utf8')
    result.check_returncode()
    lib = C.CDLL(str(dll))
    lib.policy_select.argtypes = [C.POINTER(Box), C.c_uint32, C.c_uint32, C.c_uint32, C.c_float, C.c_float]
    lib.policy_select.restype = Target
    return lib


def score_row(row, detections, lib):
    width, height = row['display_size']
    ds = []
    if len(detections) > 32:
        raise ValueError('Decoder result overflow')
    for b in detections:
        if b['category'] not in range(4) or len(b['box']) != 4 or not all(math.isfinite(v) for v in b['box']+[b['score']]):
            raise ValueError('Invalid four-bin detection')
        ds.append(Box(*b['box'], b['score'], b['category']))
    boxes = (Box*len(ds))(*ds)
    target = lib.policy_select(boxes, len(ds), 4, 0xffffffff, width, height)
    if target.hand_seen or target.object_index >= len(ds):
        raise ValueError('Four-bin policy schema mismatch')
    chosen = detections[target.object_index] if target.object_index >= 0 else None
    truth = row['held_object']
    truth_box = [v*(width if i%2 == 0 else height) for i, v in enumerate(truth['xyxy'])]
    def clipped(b):
        return [max(0, min(width if i%2 == 0 else height, v)) for i, v in enumerate(b['box'])]
    selected_iou = iou(clipped(chosen), truth_box) if chosen else 0
    stats = dict(images=1, selected_images=int(chosen is not None),
                 base_subject_detected_iou050=int(any(iou(clipped(b), truth_box) >= .5 for b in detections)),
                 base_subject_red_detected_iou050=int(any(b['category'] == 2 and iou(clipped(b), truth_box) >= .5 for b in detections)),
                 selected_subject_iou050=int(selected_iou >= .5),
                 selected_red_bucket=int(chosen is not None and chosen['category'] == 2),
                 subject_and_bucket_correct=int(selected_iou >= .5 and chosen['category'] == 2))
    return dict(id=row['id'], file=row['file'], source=row['source'], primary_score=row['primary_score'],
                quality=row['quality'], truth=truth, detections=detections, selected_index=target.object_index,
                selected=chosen, subject_iou=selected_iou, counts=stats)


def aggregate(decisions):
    result = {}
    for d in decisions:
        split = 'primary' if d['primary_score'] else 'secondary_motion_blur'
        for key in (split, split+'/'+d['source'], 'all_angles'):
            result.setdefault(key, Counter()).update(d['counts'])
    return result


def validate(a):
    selection = read(a.selection)
    rows = read(a.fixtures/'inventory.json')
    packed = read(a.deployment/'packed/memory_map.json')
    if (selection['status'] != 'MODEL_FROZEN_BEFORE_FINAL_TEST' or selection['classes'] != 4
            or selection['hand_locator_present'] or selection['new_test_predictions_used_for_selection']):
        raise ValueError('Frozen four-bin model selection required')
    if sha(a.fixtures/'inventory.json') != selection['fixture_inventory_sha256'] or sha(a.annotations) != selection['annotations_sha256']:
        raise ValueError('Frozen truth or inventory changed')
    if (sha(a.deployment/'packed/model.bin') != selection['selected_model_sha256']
            or packed['blob_sha256'] != selection['selected_model_sha256']
            or sha(a.checkpoint) != selection['checkpoint_sha256']
            or packed.get('raw_model_classes', 4) != 4):
        raise ValueError('Frozen model identity changed')
    ids = [r['id'] for r in rows]
    if len(set(ids)) != len(rows) or len(rows) != 16 or sum(r['primary_score'] for r in rows) != 15:
        raise ValueError('Expected fixed 15 primary + 1 secondary angles')
    if {r['id'] for r in read(a.fixtures/'truth.json')['images']} != set(ids):
        raise ValueError('Truth image identity mismatch')
    for row in rows:
        w, h = row['display_size']; t = row['held_object']
        if sha(Path(row['path'])) != row['sha256'] or t['bin'] != 2:
            raise ValueError('Source identity or red-bin truth changed')
        x1, y1, x2, y2 = t['xyxy']
        if not (w > 0 and h > 0 and 0 <= x1 < x2 <= 1 and 0 <= y1 < y2 <= 1):
            raise ValueError('Invalid subject truth')
    return selection, rows


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    for k in ('selection', 'fixtures', 'annotations', 'deployment', 'checkpoint', 'yolo', 'cc'):
        ap.add_argument('--'+k, type=Path, required=True)
    ap.add_argument('--out', type=Path)
    ap.add_argument('--preflight', action='store_true')
    ap.add_argument('--linear-o2', action='store_true')
    ap.add_argument('--packed-add', action='store_true')
    a = ap.parse_args()
    selection, rows = validate(a)
    if a.preflight:
        print('FINAL_TEST_PREFLIGHT_PASS: no inference performed; 16 frozen angles, one physical battery')
        return
    if datetime.now(timezone.utc) < datetime.fromisoformat(selection['not_before_utc']):
        raise ValueError('Final inference is not allowed before the frozen UTC start time')
    if a.out is None:
        raise ValueError('--out required for formal run')
    out = a.out.resolve(); out.mkdir(parents=True, exist_ok=False)
    state = dict(status='FINAL_TEST_STARTED', started_utc=datetime.now(timezone.utc).isoformat(),
                 test_used=True, model_sha256=selection['selected_model_sha256'],
                 selection_sha256=sha(a.selection), fixture_inventory_sha256=sha(a.fixtures/'inventory.json'),
                 truth_sha256=sha(a.fixtures/'truth.json'), annotations_sha256=sha(a.annotations),
                 policy_sha256=sha(SW/'yolo_contact_policy.h'), geometry_sha256=sha(SW/'yolo_target_policy.h'),
                 script_sha256=sha(Path(__file__)), one_physical_object=True, board_accuracy=False)
    write(out/'state.json', state)
    try:
        lib = compile_policy(a.cc.resolve(), out)
        cmd = [sys.executable, str(ROOT/'project/trash_sorting/tools/check_four_bin_deployment.py'),
               '--deployment', str(a.deployment), '--checkpoint', str(a.checkpoint),
               '--expected-checkpoint-sha256', selection['checkpoint_sha256'], '--photos', str(a.fixtures),
               '--yolo', str(a.yolo), '--cc', str(a.cc), '--out', str(out/'numeric'), '--skip-fixtures']
        if a.linear_o2: cmd.append('--linear-o2')
        if a.packed_add: cmd.append('--packed-add')
        write(out/'command.json', cmd)
        with (out/'numeric.log').open('w', encoding='utf8') as log:
            subprocess.run(cmd, stdout=log, stderr=subprocess.STDOUT, check=True)
        numeric = read(out/'numeric/result.json'); preds = read(out/'numeric/predictions.json')
        if (numeric['status'] != 'PASS' or numeric['images'] != len(rows)
                or numeric['model_sha256'] != state['model_sha256'] or numeric['truth_sha256'] != state['truth_sha256']
                or len(preds) != len(rows) or {p['id'] for p in preds} != {r['id'] for r in rows}):
            raise ValueError('Incomplete or mismatched final numeric predictions')
        # Revalidate all frozen identities after inference as well.
        validate(a)
        if state['policy_sha256'] != sha(SW/'yolo_contact_policy.h') or state['geometry_sha256'] != sha(SW/'yolo_target_policy.h'):
            raise ValueError('Production policy changed during evaluation')
        by_id = {p['id']: p for p in preds}
        decisions = []
        for row in rows:
            p = by_id[row['id']]
            if p['file'] != row['file']: raise ValueError('Prediction image mismatch')
            decisions.append(score_row(row, p['detections'], lib))
        result = dict(**state, summaries=aggregate(decisions), decisions=decisions,
                      numeric_result_sha256=sha(out/'numeric/result.json'), predictions_sha256=sha(out/'numeric/predictions.json'),
                      limits=['Same single held-out battery, 16 angles, not 16 independent objects',
                              'Primary15 excludes one motion-blurred secondary image by prior review',
                              'Offline Q15 convolution oracle + actual C head/decode/selection; not FPGA accuracy',
                              'Four-class model has no hand locator; production maximum clipped area fallback',
                              'Background not exhaustively labelled; this is subject/bucket scoring, not AP',
                              'Results are final test, never used for training, threshold or model selection'])
        result['status'] = 'FINAL_TEST_EVALUATED'
        write(out/'result.json', result)
        state['status'] = 'FINAL_TEST_EVALUATED'
        print(json.dumps(result['summaries']))
    except Exception as exc:
        state.update(status='FINAL_TEST_FAILED', error=str(exc))
        raise
    finally:
        write(out/'state.json', state)


if __name__ == '__main__':
    main()
