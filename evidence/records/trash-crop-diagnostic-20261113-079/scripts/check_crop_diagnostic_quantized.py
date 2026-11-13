"""Prepare lossless crops, then score fixed Q15+C results in original coordinates."""
import argparse
from collections import Counter, defaultdict
import ctypes as C
import json
from pathlib import Path

from PIL import Image, ImageOps
from evaluate_crop_diagnostic import Box, Target, MODES, sha, iou, save


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('action', choices=('prepare','score'))
    p.add_argument('--float-run', type=Path, required=True)
    p.add_argument('--fixtures', type=Path, required=True)
    p.add_argument('--numeric', type=Path)
    p.add_argument('--out', type=Path)
    a = p.parse_args()
    source = a.float_run.resolve()
    fixture = a.fixtures.resolve()
    records = json.loads((source/'predictions.json').read_text(encoding='utf8'))
    if a.action == 'prepare':
        fixture.mkdir(parents=True, exist_ok=False)
        (fixture/'images').mkdir()
        inventory, truth, mapping = [], [], []
        for row in records:
            if sha(row['path']) != row['sha256']:
                raise ValueError('Source image identity changed')
            with Image.open(row['path']) as raw:
                image = ImageOps.exif_transpose(raw).convert('RGB')
            used = {}
            for mode in MODES:
                roi = row['modes'][mode]['roi']
                key = tuple(roi)
                if key not in used:
                    idx = len(inventory)+1
                    path = fixture/'images'/('%04d.png' % idx)
                    crop = image.crop(roi)
                    crop.save(path)
                    inventory.append(dict(id=idx, file=path.name, path=str(path),
                                          sha256=sha(path), display_size=list(crop.size)))
                    truth.append(dict(id=idx, scope='truth-assisted fixed development ROI, not deployment locator'))
                    used[key] = idx
                mapping.append(dict(key=row['key'], mode=mode, fixture_id=used[key], roi=roi))
        save(fixture/'inventory.json', inventory)
        save(fixture/'truth.json', dict(images=truth))
        save(fixture/'mapping.json', mapping)
        save(fixture/'preparation.json', dict(status='FROZEN_CROP_FIXTURES', source_sha256=sha(source/'predictions.json'),
             source_contract_sha256=sha(source/'contract.json'), mapping_sha256=sha(fixture/'mapping.json'),
             inventory_sha256=sha(fixture/'inventory.json'), n_unique_crops=len(inventory), n_modes=len(mapping),
             test_used=False, lossless_png=True, script_sha256=sha(__file__)))
        print('CROP_FIXTURES_PASS '+str(len(inventory)), flush=True)
        return
    prep = json.loads((fixture/'preparation.json').read_text(encoding='utf8'))
    for filename, expected in [('inventory.json',prep['inventory_sha256']), ('mapping.json',prep['mapping_sha256'])]:
        if sha(fixture/filename) != expected:
            raise ValueError('Frozen fixture identity changed')
    if sha(source/'predictions.json') != prep['source_sha256'] or sha(source/'contract.json') != prep['source_contract_sha256']:
        raise ValueError('Frozen diagnostic identity changed')
    numeric = json.loads((a.numeric/'result.json').read_text(encoding='utf8'))
    if numeric['status'] != 'PASS' or numeric['images'] != prep['n_unique_crops']:
        raise ValueError('Complete passing numeric run required')
    if numeric['truth_sha256'] != sha(fixture/'truth.json'):
        raise ValueError('Numeric result uses different crop fixtures')
    if numeric['model_sha256'] != 'ea70896cec65e802cd063525ba8a09814b10c52b65a36822abbc0d7854ac447e':
        raise ValueError('Numeric model changed')
    command = numeric['compiler_command']
    assert '-DYOLO_CLASSES=4' in command and '-DYOLO_LINEAR_O2' in command and '-DYOLO_PACKED_ADD' not in command
    predictions = {p['id']:p for p in json.loads((a.numeric/'predictions.json').read_text(encoding='utf8'))}
    inventory = json.loads((fixture/'inventory.json').read_text(encoding='utf8'))
    assert set(predictions) == {r['id'] for r in inventory}
    for row in inventory:
        if sha(row['path']) != row['sha256'] or predictions[row['id']]['file'] != row['file']:
            raise ValueError('Numeric image changed')
    mapping = {(r['key'],r['mode']):r for r in json.loads((fixture/'mapping.json').read_text(encoding='utf8'))}
    contract = json.loads((source/'contract.json').read_text(encoding='utf8'))
    root = Path(__file__).resolve().parents[3]
    for name, expected in contract['c_headers'].items():
        if sha(root/'project/trash_sorting/source/yolo/software'/name) != expected:
            raise ValueError('Policy header changed')
    lib = C.CDLL(str(source/'policy.dll'))
    lib.policy_select.argtypes = [C.POINTER(Box), C.c_uint32, C.c_uint32, C.c_uint32, C.c_float, C.c_float]
    lib.policy_select.restype = Target
    summaries, groups, paired = defaultdict(Counter), defaultdict(Counter), defaultdict(Counter)
    for row in records:
        for mode in MODES:
            detail = row['modes'][mode]
            item = mapping[(row['key'],mode)]
            assert item['roi'] == detail['roi']
            x, y = item['roi'][:2]
            boxes = [[d['box'][0]+x,d['box'][1]+y,d['box'][2]+x,d['box'][3]+y,d['score'],d['category']]
                     for d in predictions[item['fixture_id']]['detections']]
            assert all(b[5] in range(4) for b in boxes)
            ob = (Box*len(boxes))(*[Box(*b[:5],int(b[5])) for b in boxes])
            chosen = lib.policy_select(ob,len(boxes),4,0xffffffff,*row['size']).object_index
            selected = boxes[chosen] if chosen >= 0 else None
            subject = row['subject']
            best = max((iou(b[:4],subject) for b in boxes),default=0) if subject else None
            siou = iou(selected[:4],subject) if subject and selected else 0 if subject else None
            correct_class = bool(selected and selected[5] == row['expected_model_class']) if subject else None
            detail.update(detections=boxes, selected_index=chosen, selected=selected,
                          best_subject_iou=best, selected_subject_iou=siou,
                          raw_subject_detected=bool(best>=.5) if subject else None,
                          selected_subject_correct=bool(siou>=.5) if subject else None,
                          selected_class_correct=correct_class,
                          selected_both_correct=bool(siou>=.5 and correct_class) if subject else None)
            for counter in (summaries[row['cohort']+'/'+mode],groups[str(row['group'])+'/'+mode]):
                counter['n'] += 1
                counter['selected_any'] += chosen >= 0
                if subject:
                    for k in ('raw_subject_detected','selected_subject_correct','selected_class_correct','selected_both_correct'):
                        counter[k] += detail[k]
                    counter['truncated_subject'] += detail['subject_retained'] < .999
        if row['subject']:
            base = row['modes']['whole']['selected_both_correct']
            for mode in MODES[1:]:
                current = row['modes'][mode]['selected_both_correct']
                paired[row['cohort']+'/'+mode]['gain' if current and not base else 'loss' if base and not current else 'both_correct' if base else 'both_wrong'] += 1
    a.out.mkdir(parents=True,exist_ok=False)
    save(a.out/'predictions.json', records)
    save(a.out/'result.json', dict(status='PASS_Q15_C_DIAGNOSTIC', numerical_result_sha256=sha(a.numeric/'result.json'),
         source_preparation_sha256=sha(fixture/'preparation.json'), numeric_model_sha256=numeric['model_sha256'],
         summaries=dict(summaries), physical_groups=dict(groups), paired_vs_whole=dict(paired),
         truth_assisted=True, held_out_test_used=False, board_changed=False))
    print('CROP_Q15_SCORE_PASS',flush=True)


if __name__ == '__main__':
    main()
