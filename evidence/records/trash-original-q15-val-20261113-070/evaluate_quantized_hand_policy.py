"""Prepare audited val fixtures or score Q15+C detections with camera C policy.

Never opens the held-out battery test. Numeric convolution/head checking stays
in check_four_bin_deployment.py; this script scores its saved detections.
"""
import argparse
from collections import Counter
import ctypes as C
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
from PIL import Image
import yaml

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(Path(__file__).resolve().parent))
from evaluate_hand_branch import Box, Target, hand_annotations


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def iou(a, b):
    intersection = max(0, min(a[2], b[2])-max(a[0], b[0])) * max(0, min(a[3], b[3])-max(a[1], b[1]))
    union = (a[2]-a[0])*(a[3]-a[1])+(b[2]-b[0])*(b[3]-b[1])-intersection
    return intersection/union if union > 0 else 0


def label_xyxy(b, w, h):
    return [(b[1]-b[3]/2)*w, (b[2]-b[4]/2)*h,
            (b[1]+b[3]/2)*w, (b[2]+b[4]/2)*h]


def match_hands(pred, truth):
    """Greedy descending-IoU one-to-one matching, class already filtered."""
    pairs = sorted([(iou(p, t), i, j) for i, p in enumerate(pred)
                    for j, t in enumerate(truth) if iou(p, t) >= .5], reverse=True)
    used_p, used_t = set(), set()
    for overlap, i, j in pairs:
        if i not in used_p and j not in used_t:
            used_p.add(i); used_t.add(j)
    return len(used_p)


def prepare(a):
    manifest = json.loads((a.data/'manifest.json').read_text(encoding='utf8'))
    sources = {'reviewed_hand', 'hagrid_hand_localisation', 'reviewed_hand_negative',
               'reviewed_hand_context', 'personal_handheld'}
    rows = [r for r in manifest if r['split'] == 'val' and
            (r['source'] in sources or r.get('hand_annotation_status') == 'visually reviewed absent')]
    names = yaml.safe_load((a.data/'data.yaml').read_text(encoding='utf8'))['names']
    hand_class = names.index('hand') if isinstance(names, list) else next(int(k) for k,v in names.items() if v == 'hand')
    a.out.mkdir(parents=True, exist_ok=False)
    inventory, truths = [], []
    for idx, r in enumerate(rows, 1):
        p = Path(r['prepared_image']).resolve()
        if sha(p) != r['sha256']:
            raise ValueError('Reviewed validation image identity changed')
        with Image.open(p) as im:
            w, h = im.size
        inventory.append(dict(id=idx, file=p.name, path=str(p), sha256=sha(p),
                              display_size=[w, h], key=p.stem, source=r['source'],
                              reviewed_hand_boxes=[label_xyxy(b, w, h) for b in hand_annotations(r, hand_class)],
                              held_object=r.get('held_object'), group=r.get('group'),
                              empty_hand=r.get('empty_hand', False)))
        # Numerical checker only hashes truth; this is not an image-level bin
        # label for empty hands, so keep its meaning explicit.
        truths.append(dict(id=idx, annotation_scope='audited hand/held relation, not image-level bucket truth'))
    (a.out/'inventory.json').write_text(json.dumps(inventory, indent=2), encoding='utf8')
    (a.out/'truth.json').write_text(json.dumps(dict(images=truths), indent=2), encoding='utf8')
    report = dict(status='AUDITED_VAL_NUMERIC_FIXTURE', split='val', test_used=False,
                  manifest_sha256=sha(a.data/'manifest.json'), images=len(rows), hand_label_class=hand_class,
                  sources=dict(Counter(r['source'] for r in rows)), script_sha256=sha(Path(__file__)))
    (a.out/'preparation.json').write_text(json.dumps(report, indent=2), encoding='utf8')
    print(json.dumps(report))


def evaluate(a):
    inventory_path = a.fixtures/'inventory.json'
    rows = {r['id']: r for r in json.loads(inventory_path.read_text(encoding='utf8'))}
    numeric_path = a.predictions.parent/'result.json'
    numeric = json.loads(numeric_path.read_text(encoding='utf8'))
    if numeric['status'] != 'PASS' or numeric['images'] != len(rows):
        raise ValueError('Complete Q15+C numeric check required')
    if numeric['truth_sha256'] != sha(a.fixtures/'truth.json'):
        raise ValueError('Numeric result does not match these validation fixtures')
    if f'-DYOLO_CLASSES={a.classes}' not in numeric.get('compiler_command', []):
        raise ValueError('Requested policy schema differs from numeric decoder')
    predictions = json.loads(a.predictions.read_text(encoding='utf8'))
    if len(predictions) != len(rows) or {r['id'] for r in predictions} != set(rows):
        raise ValueError('Missing or duplicated numeric image results')
    if any(b['category'] not in range(a.classes) for p in predictions for b in p['detections']):
        raise ValueError('Detection outside declared model classes')
    a.out.mkdir(parents=True, exist_ok=False)
    temp = a.out/'temp'; temp.mkdir()
    env = os.environ.copy(); cc = a.cc.resolve()
    env['PATH'] = str(cc.parent)+os.pathsep+env.get('PATH', '')
    env['TMP'] = env['TEMP'] = str(temp.resolve())
    sw = ROOT/'project/trash_sorting/source/yolo/software'
    dll = (a.out/'policy.dll').resolve()
    command = [str(cc), '-O2', '-std=c11', '-Wall', '-Wextra', '-Werror', '-shared',
               '-I'+str(sw), str(ROOT/'project/trash_sorting/tools/test_contact_policy.c'), '-lm', '-o', str(dll)]
    r = subprocess.run(command, capture_output=True, text=True, env=env)
    (a.out/'build.log').write_text(r.stdout+r.stderr, encoding='utf8'); r.check_returncode()
    lib = C.CDLL(str(dll))
    lib.policy_select.argtypes = [C.POINTER(Box), C.c_uint32, C.c_uint32, C.c_uint32, C.c_float, C.c_float]
    lib.policy_select.restype = Target
    summaries, decisions = {}, []
    for p in predictions:
        row = rows[p['id']]; w, h = row['display_size']
        if p['file'] != row['file'] or sha(Path(row['path'])) != row['sha256']:
            raise ValueError('Validation source image changed')
        ds = [[*b['box'], b['score'], b['category']] for b in p['detections']]
        boxes = (Box*len(ds))(*[Box(*b[:5], int(b[5])) for b in ds])
        t = lib.policy_select(boxes, len(boxes), 4, 4 if a.classes == 5 else 0xffffffff, w, h)
        chosen = ds[t.object_index] if t.object_index >= 0 else None
        hands = [b for b in ds if b[5] == 4]
        stats = summaries.setdefault(row['source'], Counter())
        stats['images'] += 1; stats['hand_seen_images'] += bool(hands)
        stats['selected_images'] += chosen is not None
        tp = match_hands(hands, row['reviewed_hand_boxes'])
        stats['TP'] += tp; stats['FP'] += len(hands)-tp
        stats['GT'] += len(row['reviewed_hand_boxes'])
        d = dict(key=row['key'], source=row['source'], hand_seen=bool(hands),
                 selected_index=t.object_index, selected=int(chosen[5]) if chosen else None,
                 width=w, height=h, waste=[b for b in ds if b[5] < 4], hands=hands,
                 detections=ds)
        if row['source'] in ('reviewed_hand', 'hagrid_hand_localisation') or row.get('empty_hand', False):
            stats['empty_hand_false_selection'] += chosen is not None
        target = row.get('held_object')
        if target:
            xyxy = [v*(w if i%2 == 0 else h) for i,v in enumerate(target['xyxy'])]
            subject_iou = iou(chosen, xyxy) if chosen else 0
            correct = chosen is not None and int(chosen[5]) == target['bin'] and subject_iou >= .5
            stats['subject_and_bucket_correct'] += correct
            outcome = 'hand_present' if hands else 'no_hand_fallback'
            stats[outcome+'_images'] += 1
            stats[outcome+'_subject_and_bucket_correct'] += correct
            stats['base_subject_detected_iou050'] += any(b[5] < 4 and iou(b, xyxy) >= .5 for b in ds)
            d.update(held_truth=target, subject_iou=subject_iou, correct=correct)
        decisions.append(d)
    report = dict(status='OFFLINE_Q15_C_POLICY_EVALUATED', model_sha256=numeric['model_sha256'],
                  raw_model_classes=a.classes, hand_locator_present=a.classes == 5,
                  target_policy='contact', summaries=summaries, decisions=decisions,
                  numeric_result_sha256=sha(numeric_path), predictions_sha256=sha(a.predictions),
                  fixture_inventory_sha256=sha(inventory_path),
                  policy_sha256=sha(sw/'yolo_contact_policy.h'), common_geometry_sha256=sha(sw/'yolo_target_policy.h'),
                  script_sha256=sha(Path(__file__)), test_used=False, pds_started=False, board_programmed=False,
                  limits=['CPU Q15 software convolution and actual C head/decode/policy; not FPGA timing',
                          'Personal object groups follow fixture inventory; background labels are not exhaustive',
                          'Contact boxes do not prove grasping; no independent environment accuracy'])
    (a.out/'result.json').write_text(json.dumps(report, indent=2), encoding='utf8')
    print(json.dumps(summaries))


def main():
    p = argparse.ArgumentParser(description=__doc__)
    sub = p.add_subparsers(dest='mode', required=True)
    prep = sub.add_parser('prepare'); prep.add_argument('--data', type=Path, required=True)
    score = sub.add_parser('evaluate')
    score.add_argument('--fixtures', type=Path, required=True)
    score.add_argument('--predictions', type=Path, required=True)
    score.add_argument('--cc', type=Path, required=True)
    score.add_argument('--classes', type=int, choices=(4, 5), default=5,
                       help='Explicit model schema; nc4 has no hand locator')
    for cmd in (prep, score): cmd.add_argument('--out', type=Path, required=True)
    a = p.parse_args()
    (prepare if a.mode == 'prepare' else evaluate)(a)


if __name__ == '__main__':
    main()
