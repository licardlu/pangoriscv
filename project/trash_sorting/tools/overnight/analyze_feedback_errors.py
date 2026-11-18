"""Bind saved validation errors to photos and compare float/Q15 selection.

Development diagnostics only. Does not train, relabel, open test, or use UART.
"""
import argparse
from collections import Counter, defaultdict
import ctypes as C
import hashlib
import json
from pathlib import Path

from replay_policy import Box, Target, overlap, sha


def load(path):
    return json.loads(Path(path).read_text(encoding='utf8'))


def cohort(row):
    source = row['source'].lower()
    original = str(row.get('image', '')).replace('\\', '/').lower()
    result = ['all']
    if 'battery' in source or '\u7535\u6c60' in source:
        result.append('battery')
    if 'glass' in source or '/glass/' in original:
        result.append('glass')
    if not any(int(b[0]) < 4 for b in row['boxes']):
        result.append('no_waste')
    if any(int(b[0]) == 4 for b in row['boxes']):
        result.append('has_hand')
    return result


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--manifest', type=Path, required=True)
    p.add_argument('--numeric', type=Path, required=True)
    p.add_argument('--photos', type=Path, required=True)
    p.add_argument('--float-evaluation', type=Path, required=True)
    p.add_argument('--policy', type=Path, required=True)
    p.add_argument('--source-dir', type=Path, required=True)
    p.add_argument('--calibration', type=Path, action='append', default=[])
    p.add_argument('--out', type=Path, required=True)
    a = p.parse_args()
    a.out.mkdir(parents=True, exist_ok=False)
    manifest = load(a.manifest)
    truth = {Path(r['prepared_image']).stem: r for r in manifest if r['split'] == 'val'}
    inventory = load(a.photos/'inventory.json')
    images = {r['id']: r for r in inventory}
    fixed = load(a.numeric/'predictions.json')
    floats = load(a.float_evaluation/'image_decisions.json')
    assert len(images) == len(fixed) == len(truth) == len(floats)
    assert len({r['path'] for r in inventory}) == len(inventory)
    assert {r['id'] for r in fixed} == set(images)
    assert {Path(r['path']).stem for r in inventory} == set(truth) == set(floats)
    assert load(a.numeric/'result.json')['truth_sha256'] == sha(a.photos/'truth.json')
    policy = load(a.policy/'result.json')
    for name, digest in policy['headers'].items():
        assert sha(a.source_dir/'yolo/software'/name) == digest
    lib = C.CDLL(str((a.policy/'policy.dll').resolve()))
    lib.policy_select.argtypes = [C.POINTER(Box), C.c_uint32, C.c_uint32,
                                  C.c_uint32, C.c_float, C.c_float]
    lib.policy_select.restype = Target
    stats = defaultdict(Counter)
    rows = []
    for prediction in fixed:
        image = images[prediction['id']]
        stem = Path(image['path']).stem
        row = truth[stem]
        assert row['image_sha256'] == image['sha256']
        w, h = image['display_size']
        gt = [[int(c), (x-bw/2)*w, (y-bh/2)*h, (x+bw/2)*w, (y+bh/2)*h]
              for c, x, y, bw, bh in row['boxes']]
        waste = [b for b in gt if b[0] < 4]
        outcomes = {}
        for label, boxes in [('float', floats[stem]['detections']),
                             ('q15', [[*d['box'], d['score'], d['category']]
                                      for d in prediction['detections']])]:
            cb = (Box*len(boxes))(*[Box(*b[:5], int(b[5])) for b in boxes])
            target = lib.policy_select(cb, len(boxes), 4, 4, w, h)
            selected = boxes[target.object_index] if target.object_index >= 0 else None
            matching = lambda b: any(int(b[5]) == g[0] and overlap(b[:4], g[1:]) >= .5
                                     for g in waste)
            correct = bool(selected and matching(selected))
            if not waste:
                reason = 'false_activation' if selected else 'correct_rejection'
            elif correct:
                reason = 'correct'
            elif not selected:
                reason = 'association_reject' if any(matching(b) for b in boxes) else 'detection_miss'
            elif any(int(selected[5]) == g[0] for g in waste):
                reason = 'localization_or_wrong_subject'
            else:
                reason = 'classification_or_wrong_subject'
            outcomes[label] = dict(selected=selected, hand_seen=bool(target.hand_seen),
                reason=reason, correct=correct, detections=boxes)
            for group in cohort(row):
                stats[group][label+'/'+reason] += 1
        for group in cohort(row):
            stats[group]['images'] += 1
            if outcomes['float']['correct'] and not outcomes['q15']['correct']:
                stats[group]['float_correct_q15_wrong'] += 1
            if not outcomes['float']['correct'] and outcomes['q15']['correct']:
                stats[group]['float_wrong_q15_correct'] += 1
        rows.append(dict(stem=stem, source=row['source'], cohorts=cohort(row),
                         capture_group=row.get('capture_group', row.get('group')),
                         image=image, truth=gt, outcomes=outcomes))

    calibrations = {}
    for directory in a.calibration:
        r = load(directory/'provenance.json')
        calibrations[directory.name] = dict(checkpoint_sha256=r['checkpoint_sha256'],
            count=len(r['calibration_images']),
            image_sha256=[i['sha256'] for i in r['calibration_images']],
            source_counts=dict(Counter(i['source'] for i in r['calibration_images'])),
            provenance_sha256=sha(directory/'provenance.json'))
    comparisons = []
    for i, (name, first) in enumerate(calibrations.items()):
        for other, second in list(calibrations.items())[i+1:]:
            comparisons.append(dict(first=name, second=other,
                common_images=len(set(first['image_sha256']) & set(second['image_sha256'])),
                identical_ordered_images=first['image_sha256'] == second['image_sha256']))
    report = dict(status='DEVELOPMENT_DIAGNOSTICS',test_used=False,
        board_accuracy_measured=False, cohorts=dict(stats),calibrations=calibrations,
        calibration_comparisons=comparisons, model_sha256=load(a.numeric/'result.json')['model_sha256'],
        manifest_sha256=sha(a.manifest), float_predictions_sha256=sha(a.float_evaluation/'image_decisions.json'),
        numeric_predictions_sha256=sha(a.numeric/'predictions.json'),policy_headers=policy['headers'])
    (a.out/'result.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf8')
    (a.out/'errors.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2),encoding='utf8')

    from PIL import Image, ImageDraw, ImageOps
    for group in ('battery','glass','no_waste'):
        selected = [r for r in rows if group in r['cohorts'] and
            (r['outcomes']['q15']['reason'] not in ('correct','correct_rejection'))][:24]
        for offset in range(0,len(selected),12):
            sheet = Image.new('RGB',(1440,1140),'white')
            draw = ImageDraw.Draw(sheet)
            for j,r in enumerate(selected[offset:offset+12]):
                path=Path(r['image']['path']);assert sha(path)==r['image']['sha256']
                with Image.open(path) as raw: im=ImageOps.exif_transpose(raw).convert('RGB')
                assert list(im.size)==r['image']['display_size']
                w,h=im.size;im.thumbnail((348,302));dw,dh=im.size
                x=(j%4)*360+(360-dw)//2;y=(j//4)*380+48
                sheet.paste(im,(x,y))
                draw.text(((j%4)*360+6,(j//4)*380+4),r['stem']+' '+r['outcomes']['q15']['reason'],fill='black')
                for b in r['truth']:
                    rect=[x+b[1]*dw/w,y+b[2]*dh/h,x+b[3]*dw/w,y+b[4]*dh/h]
                    draw.rectangle(rect,outline='green' if b[0]<4 else 'cyan',width=2)
                b=r['outcomes']['q15']['selected']
                if b:
                    draw.rectangle([x+b[0]*dw/w,y+b[1]*dh/h,x+b[2]*dw/w,y+b[3]*dh/h],outline='red',width=3)
                    draw.text(((j%4)*360+6,(j//4)*380+354),f'Q15 selected {int(b[5])} confidence {b[4]:.3f}',fill='red')
            sheet.save(a.out/f'{group}_{offset//12+1:02d}.png')
    print(json.dumps(dict(cohorts=dict(stats),calibration_comparisons=comparisons)),flush=True)


if __name__=='__main__':
    main()
