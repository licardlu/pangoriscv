"""Compare actual C contact/ROI selectors on saved validation detections.

Oracle hand boxes diagnose geometry separately from model hand misses.
This is offline validation; no policy or board model is enabled automatically.
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

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT/'project/trash_sorting/training'))
from evaluate_hand_branch import Box, Target
from evaluate_quantized_hand_policy import match_hands


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--detections', type=Path, required=True)
    p.add_argument('--manifest', type=Path, required=True)
    p.add_argument('--cc', type=Path, required=True)
    p.add_argument('--out', type=Path, required=True)
    p.add_argument('--hand-confidence',type=float,
                   help='Filter saved independent hand predictions; cannot go below their recorded inference threshold')
    a = p.parse_args()
    source_report=json.loads((a.detections.parent/'result.json').read_text(encoding='utf8'))
    if a.hand_confidence is not None:
        if (source_report.get('joint_model') or not 0<=a.hand_confidence<=1 or
                a.hand_confidence<source_report['hand_confidence']):
            raise ValueError('Threshold replay requires independent hands and a threshold >= saved inference floor')
    a.out = a.out.resolve()
    a.out.mkdir(parents=True, exist_ok=False)
    (a.out/'temp').mkdir()
    env = os.environ.copy()
    cc = a.cc.resolve()
    env['PATH'] = str(cc.parent)+os.pathsep+env.get('PATH', '')
    env['TMP'] = env['TEMP'] = str(a.out/'temp')
    sw = ROOT/'project/trash_sorting/source/yolo/software'
    source = ROOT/'project/trash_sorting/tools/test_contact_policy.c'
    base = [str(cc), '-std=c11', '-O2', '-Wall', '-Wextra', '-Werror', '-I'+str(sw), str(source), '-lm']
    logs = []
    for command in (base+['-o', str(a.out/'test.exe')], [str(a.out/'test.exe')],
                    base+['-shared', '-o', str(a.out/'policy.dll')]):
        r = subprocess.run(command, capture_output=True, text=True, env=env)
        logs.append(r.stdout+r.stderr)
        (a.out/'test.log').write_text('\n'.join(logs), encoding='utf8')
        r.check_returncode()
    if 'TEST_PASS contact_policy' not in logs[1]:
        raise ValueError('C directed tests did not pass')
    lib = C.CDLL(str(a.out/'policy.dll'))
    lib.policy_select_contact.argtypes = [C.POINTER(Box), C.c_uint32, C.POINTER(Box), C.c_uint32, C.c_float, C.c_float]
    lib.policy_select_contact.restype = Target
    data = json.loads(a.detections.read_text(encoding='utf8'))
    manifest = {Path(r['prepared_image']).stem: r for r in json.loads(a.manifest.read_text(encoding='utf8'))}
    import yaml
    names = yaml.safe_load((a.manifest.parent/'data.yaml').read_text(encoding='utf8'))['names']
    hand_class = names.index('hand') if isinstance(names, list) else next(int(k) for k, v in names.items() if v == 'hand')

    def select(objects, hands, w, h):
        ob = (Box*len(objects))(*[Box(*b[:5], int(b[5])) for b in objects])
        hb = (Box*len(hands))(*[Box(*b[:5], 4) for b in hands])
        t = lib.policy_select_contact(ob, len(objects), hb, len(hands), w, h)
        return t.object_index

    def iou(b, xyxy):
        if b is None:
            return 0
        area = max(0, min(b[2], xyxy[2])-max(b[0], xyxy[0]))*max(0, min(b[3], xyxy[3])-max(b[1], xyxy[1]))
        union = (b[2]-b[0])*(b[3]-b[1])+(xyxy[2]-xyxy[0])*(xyxy[3]-xyxy[1])-area
        return area/union if union > 0 else 0

    summaries, details = {}, []
    for d in data:
        objects, hands = d['waste'], d['hands']
        if a.hand_confidence is not None:
            hands=[b for b in hands if b[4]>=a.hand_confidence]
        idx = select(objects, hands, d['width'], d['height'])
        picked = objects[idx] if idx >= 0 else None
        decision = dict(key=d['key'], index=idx, selected=int(picked[5]) if picked else None)
        row = manifest.get(d['key'])
        if row is None:
            group = d['source_group']
        else:
            group = row['source']
        stats = summaries.setdefault(group, Counter())
        stats['images'] += 1
        stats['selected'] += picked is not None
        stats['hand_seen_images'] += bool(hands)
        if row:
            w,h=d['width'],d['height']
            hand_truth=[[(b[1]-b[3]/2)*w,(b[2]-b[4]/2)*h,
                         (b[1]+b[3]/2)*w,(b[2]+b[4]/2)*h]
                        for b in row['boxes'] if int(b[0])==hand_class]
            tp=match_hands(hands,hand_truth)
            stats['hand_TP']+=tp;stats['hand_FP']+=len(hands)-tp;stats['hand_GT']+=len(hand_truth)
        if 'truth' in d:
            accepted = d['truth'].get('accepted_bins', [d['truth']['bin']])
            stats['accepted_bucket_correct'] += picked is not None and int(picked[5]) in accepted
            if d['truth']['group']=='cylindrical_batteries':
                stats['battery_images']+=1
                stats['battery_hand_seen_images']+=bool(hands)
                stats['battery_bucket_correct']+=picked is not None and int(picked[5]) in accepted
        if row and row['source'] in ('reviewed_hand', 'hagrid_hand_localisation'):
            stats['empty_hand_false_selection'] += picked is not None
        if row and row['source'] == 'personal_handheld':
            w, h = d['width'], d['height']
            target = row['held_object']
            xyxy = [target['xyxy'][i]*(w if i%2 == 0 else h) for i in range(4)]
            correct = picked is not None and int(picked[5]) == target['bin'] and iou(picked, xyxy) >= .5
            stats['subject_and_bucket_correct'] += correct
            outcome = 'hand_present' if hands else 'no_hand_fallback'
            stats[outcome+'_images'] += 1
            stats[outcome+'_subject_and_bucket_correct'] += correct
            hand_labels = [b for b in row['boxes'] if int(b[0]) == hand_class]
            if len(hand_labels) != 1:
                raise ValueError('Held relation requires exactly one reviewed hand')
            hb = hand_labels[0]
            oracle = [(hb[1]-hb[3]/2)*w, (hb[2]-hb[4]/2)*h, (hb[1]+hb[3]/2)*w, (hb[2]+hb[4]/2)*h, 1, 0]
            oi = select(objects, [oracle], w, h)
            op = objects[oi] if oi >= 0 else None
            stats['oracle_hand_subject_and_bucket_correct'] += op is not None and int(op[5]) == target['bin'] and iou(op, xyxy) >= .5
            stats['reference_subject_and_bucket_correct'] += bool(d['selected_subject_correct'] and d['selected_bucket_correct'])
            stats['reference_oracle_subject_and_bucket_correct'] += bool(
                d['oracle_hand_selected_subject_iou'] >= .5 and d['oracle_hand_selection']['selected'] == target['bin'])
            decision.update(correct=correct, subject_iou=iou(picked, xyxy), oracle_index=oi,
                            oracle_subject_iou=iou(op, xyxy))
        details.append(decision)
    report = dict(status='OFFLINE_COMPARISON_ONLY', summaries=summaries, decisions=details,
                  policy_revision='hand_size_adaptive_contact_v2',
                  hand_confidence=a.hand_confidence if a.hand_confidence is not None else source_report['hand_confidence'],
                  saved_inference_hand_floor=source_report['hand_confidence'],
                  waste_confidence=source_report['conf'],model_sha256=source_report['hand_sha256'],
                  source_sha256=hashlib.sha256(a.detections.read_bytes()).hexdigest(),
                  policy_sha256=hashlib.sha256((sw/'yolo_contact_policy.h').read_bytes()).hexdigest(),
                  limits=['Validation-driven geometry experiment; not independent test',
                          'Box contact does not prove holding, cannot recover undetected waste',
                          'This replay does not compile FPGA logic or deploy to a board'])
    (a.out/'result.json').write_text(json.dumps(report, indent=2), encoding='utf8')
    print(json.dumps(summaries), flush=True)


if __name__ == '__main__':
    main()
