"""Truth-assisted crop diagnostic, never a deployable hand locator evaluation.

Uses development validation only. All predictions use the same original four-bin
checkpoint and the production C maximum-clipped-area selector. Cropping truth is
explicitly recorded, including when the crop loses part of a large subject.
"""
import argparse
from collections import Counter, defaultdict
import ctypes as C
import hashlib
import json
import math
import os
from pathlib import Path
import subprocess
import sys
import types

import numpy as np
from PIL import Image, ImageOps, ImageDraw

ROOT = Path(__file__).resolve().parents[3]
MODES = ('whole', 'hand_2x', 'adaptive_oracle', 'object_1p5_oracle')
COLORS = ('lime', 'deepskyblue', 'red', 'gray')


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def area(b):
    return max(0, b[2]-b[0])*max(0, b[3]-b[1])


def intersection(a, b):
    return area([max(a[0], b[0]), max(a[1], b[1]), min(a[2], b[2]), min(a[3], b[3])])


def iou(a, b):
    v = intersection(a, b)
    return v/max(1e-12, area(a)+area(b)-v)


def union(boxes):
    return [min(b[0] for b in boxes), min(b[1] for b in boxes),
            max(b[2] for b in boxes), max(b[3] for b in boxes)]


def expanded(b, factor):
    cx, cy = (b[0]+b[2])/2, (b[1]+b[3])/2
    w, h = (b[2]-b[0])*factor, (b[3]-b[1])*factor
    return [cx-w/2, cy-h/2, cx+w/2, cy+h/2]


def pixel_roi(b, w, h):
    x1, y1 = max(0, min(w-1, math.floor(b[0]))), max(0, min(h-1, math.floor(b[1])))
    x2, y2 = max(x1+1, min(w, math.ceil(b[2]))), max(y1+1, min(h, math.ceil(b[3])))
    return [x1, y1, x2, y2]


def roi_for(mode, hands, subject, w, h):
    if mode == 'whole' or (not hands and mode in ('hand_2x', 'adaptive_oracle')):
        return [0, 0, w, h]
    if mode == 'object_1p5_oracle':
        return pixel_roi(expanded(subject, 1.5), w, h) if subject else [0, 0, w, h]
    if mode == 'adaptive_oracle' and subject and area(subject) > sum(map(area, hands))/len(hands):
        return pixel_roi(expanded(union(hands+[subject]), 1.1), w, h)
    return pixel_roi(union([expanded(b, 2) for b in hands]), w, h)


def remap(boxes, roi):
    a = np.asarray(boxes, dtype=np.float32).reshape(-1, 6).copy()
    a[:, [0, 2]] += roi[0]
    a[:, [1, 3]] += roi[1]
    return a


def geometry_checks():
    assert pixel_roi([-10, -5, 105, 82], 100, 80) == [0, 0, 100, 80]
    assert pixel_roi([99.8, 79.8, 100.1, 80.1], 100, 80) == [99, 79, 100, 80]
    assert roi_for('adaptive_oracle', [], [10, 20, 30, 40], 100, 80) == [0, 0, 100, 80]
    h, s = [[40, 40, 50, 50]], [5, 5, 90, 75]
    assert intersection(s, roi_for('adaptive_oracle', h, s, 100, 80)) == area(s)
    assert intersection(s, roi_for('hand_2x', h, s, 100, 80)) < area(s)
    assert np.allclose(remap([[1, 2, 3, 4, .8, 2]], [10, 20, 60, 70])[0, :4], [11, 22, 13, 24])
    return dict(status='PASS', checks=['clamp', 'edge_rounding', 'no_hand_fallback',
                                      'large_subject_retained', 'hand_crop_truncation', 'coordinate_translation'])


class Box(C.Structure):
    _fields_ = [(n, C.c_float) for n in ('x1', 'y1', 'x2', 'y2', 'score')]+[('category', C.c_uint32)]


class Target(C.Structure):
    _fields_ = [('object_index', C.c_int), ('hand_index', C.c_int), ('hand_seen', C.c_uint)]+[
        (n, C.c_float) for n in ('roi_x1', 'roi_y1', 'roi_x2', 'roi_y2')]


def save(path, value):
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False), encoding='utf8')


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--out', type=Path, required=True)
    p.add_argument('--cc', type=Path, required=True)
    a = p.parse_args()
    a.out = a.out.resolve()
    a.out.mkdir(parents=True, exist_ok=False)
    save(a.out/'geometry_checks.json', geometry_checks())
    model_path = ROOT/'project/trash_sorting/training/candidates/four_bins_20261111/four_bins_yolov5n_320.pt'
    if sha(model_path) != '8014832f2bc87081c9a7adad363d5590c13ffc6b4c8ff6700f289553b1f575e0':
        raise ValueError('Original checkpoint identity changed')
    fixture = ROOT/'build/trash_hand_numeric_fixture_20261113_048/inventory.json'
    public = ROOT/'build/trash_retrain_research_20261111_001/four_bins_001/manifest.json'
    inventory = []
    for r in json.loads(fixture.read_text(encoding='utf8')):
        if r['source'] not in ('personal_handheld', 'hagrid_hand_localisation', 'reviewed_hand_context'):
            continue
        inventory.append(dict(key=r['key'], path=r['path'], sha256=r['sha256'], group=r['group'],
                              cohort=('held_val' if r.get('held_object') else
                                      'empty_crop' if r['source']=='hagrid_hand_localisation' else 'context_unscored'),
                              hands=r['reviewed_hand_boxes'], held=r['held_object']))
    for r in json.loads(public.read_text(encoding='utf8')):
        if r['split'] != 'val' or len(r['boxes']) != 1 or int(r['boxes'][0][0]) != 2:
            continue
        _, cx, cy, w, h = r['boxes'][0]
        inventory.append(dict(key=Path(r['prepared_image']).stem, path=r['prepared_image'],
                              sha256=sha(r['prepared_image']), group=str(r['group']), cohort='public_hazard_val',
                              hands=[], held=dict(bin=2, xyxy=[cx-w/2, cy-h/2, cx+w/2, cy+h/2]),
                              original_source=r['image'], annotation_scope='hazardous single box; subtype not assumed'))
    save(a.out/'inventory.json', inventory)
    config = a.out/'config'
    config.mkdir()
    os.environ['YOLOV5_CONFIG_DIR'] = str(config)
    os.environ['YOLOv5_AUTOINSTALL'] = 'false'
    yolo = ROOT/'build/trash_retrain_research_20261111_001/yolov5-7.0'
    sys.path.insert(0, str(yolo))
    import torch
    import models.common, models.yolo, models.experimental
    pkg = types.ModuleType('yolov5')
    pkg.models = types.ModuleType('yolov5.models')
    sys.modules['yolov5'], sys.modules['yolov5.models'] = pkg, pkg.models
    for n in ('common', 'yolo', 'experimental'):
        sys.modules['yolov5.models.'+n] = sys.modules['models.'+n]
    from utils.augmentations import letterbox
    from utils.general import non_max_suppression, scale_boxes
    torch.set_num_threads(4)
    torch.set_num_interop_threads(1)
    cp = torch.load(model_path, map_location='cpu')
    model = (cp.get('ema') or cp['model']).float().eval()
    assert model.model[-1].nc == 4
    temp = a.out/'temp'
    temp.mkdir()
    cc = a.cc.resolve()
    env = os.environ.copy()
    env['PATH'] = str(cc.parent)+os.pathsep+env.get('PATH', '')
    env['TMP'] = env['TEMP'] = str(temp)
    sw = ROOT/'project/trash_sorting/source/yolo/software'
    source = ROOT/'project/trash_sorting/tools/test_contact_policy.c'
    dll = a.out/'policy.dll'
    command = [str(cc), '-std=c11', '-O2', '-Wall', '-Wextra', '-Werror', '-shared',
               '-I'+str(sw), str(source), '-lm', '-o', str(dll)]
    process = subprocess.run(command, capture_output=True, text=True, env=env)
    (a.out/'policy_build.log').write_text(process.stdout+process.stderr, encoding='utf8')
    process.check_returncode()
    lib = C.CDLL(str(dll))
    lib.policy_select.argtypes = [C.POINTER(Box), C.c_uint32, C.c_uint32, C.c_uint32, C.c_float, C.c_float]
    lib.policy_select.restype = Target
    save(a.out/'contract.json', dict(checkpoint_sha256=sha(model_path), script_sha256=sha(__file__),
         source_inventory_sha256=sha(fixture), public_manifest_sha256=sha(public),
         c_source_sha256=sha(source), c_headers={n: sha(sw/n) for n in ('yolo_contact_policy.h', 'yolo_target_policy.h')},
         input_size=320, confidence=.25, nms=.45, max_det=32, modes=list(MODES),
         truth_assisted=True, held_out_test_used=False, board_changed=False, model_classes_to_bin_key=[1,4,2,3]))

    records = []
    summaries = defaultdict(Counter)
    groups = defaultdict(Counter)
    with torch.no_grad():
        for idx, row in enumerate(inventory):
            if sha(row['path']) != row['sha256']:
                raise ValueError('Image changed: '+row['key'])
            with Image.open(row['path']) as im:
                image = ImageOps.exif_transpose(im).convert('RGB')
            w, h = image.size
            subject = ([v*d for v, d in zip(row['held']['xyxy'], [w,h,w,h])] if row['held'] else None)
            expected = row['held']['bin'] if subject else None
            result = dict(key=row['key'], cohort=row['cohort'], group=row['group'], path=row['path'],
                          sha256=row['sha256'], size=[w,h], hands=row['hands'], subject=subject,
                          expected_model_class=expected, modes={})
            cache = {}
            for mode in MODES:
                roi = roi_for(mode, row['hands'], subject, w, h)
                tag = tuple(roi)
                if tag not in cache:
                    crop = np.asarray(image.crop(roi))
                    network = letterbox(crop, (320,320), auto=False, stride=32)[0]
                    tensor = torch.from_numpy(np.ascontiguousarray(network.transpose(2,0,1))).float()[None]/255
                    pred = non_max_suppression(model(tensor)[0], .25, .45, multi_label=False, max_det=32)[0]
                    if len(pred):
                        pred[:, :4] = scale_boxes(tensor.shape[2:], pred[:, :4], crop.shape).round()
                    boxes = remap(pred.cpu().numpy(), roi)
                    ob = (Box*len(boxes))(*[Box(*b[:5], int(b[5])) for b in boxes])
                    chosen = lib.policy_select(ob, len(boxes), 4, 0xffffffff, w, h).object_index
                    cache[tag] = (boxes, chosen)
                boxes, chosen = cache[tag]
                best_iou = max((iou(b[:4], subject) for b in boxes), default=0) if subject else None
                selected = boxes[chosen].tolist() if chosen >= 0 else None
                siou = iou(selected[:4], subject) if subject and selected else 0 if subject else None
                correct_class = bool(selected and expected == int(selected[5])) if subject else None
                retained = intersection(subject, roi)/area(subject) if subject else None
                projected = min(subject[2]-subject[0], subject[3]-subject[1])*320/max(roi[2]-roi[0], roi[3]-roi[1]) if subject else None
                detail = dict(roi=roi, subject_retained=retained, projected_subject_short_side=projected,
                              detections=boxes.tolist(), selected_index=chosen, selected=selected,
                              best_subject_iou=best_iou, selected_subject_iou=siou,
                              raw_subject_detected=bool(best_iou>=.5) if subject else None,
                              selected_subject_correct=bool(siou>=.5) if subject else None,
                              selected_class_correct=correct_class,
                              selected_both_correct=bool(siou>=.5 and correct_class) if subject else None)
                result['modes'][mode] = detail
                for counter in (summaries[row['cohort']+'/'+mode], groups[str(row['group'])+'/'+mode]):
                    counter['n'] += 1
                    counter['selected_any'] += chosen >= 0
                    if subject:
                        for k in ('raw_subject_detected','selected_subject_correct','selected_class_correct','selected_both_correct'):
                            counter[k] += detail[k]
                        counter['truncated_subject'] += retained < .999
                        counter['projected_short_side_sum'] += projected
            records.append(result)
            if (idx+1)%20 == 0:
                print(json.dumps(dict(processed=idx+1, total=len(inventory))), flush=True)
    paired = defaultdict(Counter)
    for r in records:
        if not r['subject']:
            continue
        base = r['modes']['whole']['selected_both_correct']
        for mode in MODES[1:]:
            current = r['modes'][mode]['selected_both_correct']
            paired[r['cohort']+'/'+mode]['gain' if current and not base else 'loss' if base and not current else 'both_correct' if base else 'both_wrong'] += 1
    save(a.out/'predictions.json', records)
    save(a.out/'result.json', dict(status='COMPLETE_OFFLINE_FLOAT_DIAGNOSTIC', n=len(records),
         summaries=dict(summaries), physical_groups=dict(groups), paired_vs_whole=dict(paired),
         caveats=['All hand ROIs use manually reviewed truth, not a trained hand detector.',
                  'Adaptive/object modes additionally use true subject geometry, not deployable.',
                  'Context is not scored as image-negative; background waste labels are incomplete.',
                  'Public hazardous includes unreviewed subtypes; no battery-only claim.',
                  'Development validation only; no held-out battery test or board operations.']))

    # Fixed order, all handheld/empty cases; first twelve public examples, no cherry-picking.
    visuals = [r for r in records if r['cohort'] != 'context_unscored']
    public_count = 0
    chosen_visuals = []
    for r in visuals:
        if r['cohort'] == 'public_hazard_val':
            public_count += 1
            if public_count > 12:
                continue
        chosen_visuals.append(r)
    panel_w, panel_h = 280, 250
    for page in range(0, len(chosen_visuals), 4):
        sheet = Image.new('RGB', (panel_w*4, panel_h*4), '#202020')
        annotations = []
        for row_idx, r in enumerate(chosen_visuals[page:page+4]):
            with Image.open(r['path']) as im:
                image = ImageOps.exif_transpose(im).convert('RGB')
            for col, mode in enumerate(MODES):
                detail = r['modes'][mode]
                roi = detail['roi']
                crop = image.crop(roi)
                crop.thumbnail((panel_w, panel_h-44))
                draw = ImageDraw.Draw(crop)
                sx, sy = crop.width/(roi[2]-roi[0]), crop.height/(roi[3]-roi[1])
                def rectangle(box, color, width):
                    b = [(box[0]-roi[0])*sx, (box[1]-roi[1])*sy,
                         (box[2]-roi[0])*sx, (box[3]-roi[1])*sy]
                    draw.rectangle(b, outline=color, width=width)
                if r['subject']:
                    rectangle(r['subject'], 'white', 1)
                if detail['selected']:
                    rectangle(detail['selected'], COLORS[int(detail['selected'][5])], 3)
                x, y = col*panel_w, row_idx*panel_h
                sheet.paste(crop, (x,y+44))
                sd = ImageDraw.Draw(sheet)
                sd.text((x+3,y+2), r['key'][:32], fill='white')
                sd.text((x+3,y+16), mode, fill='white')
                sd.text((x+3,y+30), 'both='+str(detail['selected_both_correct'])+' keep='+str(round(detail['subject_retained'],2) if r['subject'] else '-'), fill='white')
            annotations.append(r['key'])
        name = 'paired_%02d' % (page//4+1)
        sheet.save(a.out/(name+'.jpg'), quality=90)
        save(a.out/(name+'.json'), annotations)
    print(json.dumps(dict(status='COMPLETE', output=str(a.out), cohorts=Counter(r['cohort'] for r in records))), flush=True)


if __name__ == '__main__':
    main()
