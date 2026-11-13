"""Evaluate shared-feature hand branches or a joint five-class candidate.

CPU floating point only. No FPGA execution is implied. New personal held scenes
have reviewed subject boxes and relations; the old80 have image-level truth.
Uses the actual C target policy, separately from hand-only detector metrics.
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

import numpy as np
from PIL import Image, ImageOps, ImageDraw

ROOT = Path(__file__).resolve().parents[3]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


class Box(C.Structure):
    _fields_ = [(n, C.c_float) for n in ('x1', 'y1', 'x2', 'y2', 'score')] + [('category', C.c_uint32)]


class Target(C.Structure):
    _fields_ = [('object_index', C.c_int), ('hand_index', C.c_int), ('hand_seen', C.c_uint),
                *[(n, C.c_float) for n in ('roi_x1', 'roi_y1', 'roi_x2', 'roi_y2')]]


def hand_annotations(row, hand_label_class):
    """Select hand labels by class, never by position in a mixed-class row."""
    return [b for b in row['boxes'] if int(b[0]) == hand_label_class]


def hand_metric_arrays(hands, labels, width, height):
    """Map both nc=1 branch and nc=5 joint hand boxes to metric class zero."""
    gt = np.asarray([[0, (b[1]-b[3]/2)*width, (b[2]-b[4]/2)*height,
                      (b[1]+b[3]/2)*width, (b[2]+b[4]/2)*height]
                     for b in labels], dtype=np.float32).reshape(-1, 5)
    pred = np.asarray(hands, dtype=np.float32).reshape(-1, 6).copy()
    pred[:, 5] = 0
    return pred, gt


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--base', type=Path, required=True)
    p.add_argument('--expected-base-sha256', required=True)
    p.add_argument('--hand', type=Path, required=True)
    p.add_argument('--data', type=Path, required=True)
    p.add_argument('--personal', type=Path, required=True)
    p.add_argument('--cc', type=Path, required=True)
    p.add_argument('--yolo', type=Path, required=True)
    p.add_argument('--out', type=Path, required=True)
    p.add_argument('--hand-confidence', type=float, default=.25,
                   help='Independent hand threshold; waste threshold remains .25')
    p.add_argument('--validation-only', action='store_true')
    p.add_argument('--personal-hand-review', type=Path,
                   help='Explicit visual hand-presence review, matched by photo ID and SHA')
    p.add_argument('--split', choices=('val', 'test'), default='val')
    p.add_argument('--joint-model', action='store_true',
                   help='Evaluate --hand as a jointly trained five-class model; no shared-feature invariance claim')
    p.add_argument('--target-policy', choices=('roi', 'contact'), default='roi',
                   help='Actual C selector; current candidate camera source uses contact')
    a = p.parse_args()
    if sha(a.base) != a.expected_base_sha256:
        raise ValueError('Base checkpoint identity mismatch')
    a.out = a.out.resolve()
    a.out.mkdir(parents=True, exist_ok=False)
    config = a.out/'config'
    config.mkdir()
    os.environ['YOLOV5_CONFIG_DIR'] = str(config)
    os.environ['YOLOv5_AUTOINSTALL'] = 'false'
    os.environ['WANDB_MODE'] = 'disabled'
    sys.path.insert(0, str(a.yolo.resolve()))
    import torch
    from utils.augmentations import letterbox
    from utils.general import non_max_suppression, scale_boxes
    from val import process_batch
    torch.set_num_threads(4)
    torch.set_num_interop_threads(1)

    def load(path):
        cp = torch.load(path, map_location='cpu')
        return (cp.get('ema') or cp['model']).float().eval()

    base, auxiliary = load(a.base), load(a.hand)
    if base.model[-1].nc != 4 or auxiliary.model[-1].nc != (5 if a.joint_model else 1):
        raise ValueError('Unexpected base/candidate class count')
    if a.joint_model and a.hand_confidence != .25:
        raise ValueError('Joint model must use one deployment threshold .25')
    adapters = [] if a.joint_model else list(auxiliary.model[24:-1])
    if len(adapters) not in (0, 3):
        raise ValueError('Expected Detect only or three independent feature adapters')
    feature_layers = [layer.f for layer in adapters] if adapters else [17,20,23]
    if not a.joint_model and feature_layers not in ([17,20,23],[4,6,9]):
        raise ValueError('Unvalidated shared feature routing')
    original, trained = base.state_dict(), auxiliary.state_dict()
    changes = []
    frozen = []
    for key, value in original.items():
        if key.startswith('model.24.'):
            continue
        frozen.append(key)
        if key not in trained or not torch.equal(value, trained[key]):
            changes.append(dict(key=key, max_abs=float((value-trained[key]).abs().max())
                                if key in trained else None))
    identity = dict(base_sha256=sha(a.base), hand_sha256=sha(a.hand),
                    feature_state_tensors_compared=len(frozen), changed_feature_tensors=changes,
                    parameter_and_bn_exact=not changes,
                    original_garbage_features_required_frozen=not a.joint_model)
    (a.out/'identity.json').write_text(json.dumps(identity, indent=2), encoding='utf8')
    if changes and not a.joint_model:
        raise ValueError('Frozen parameters/BN changed; shared-feature head is not validated')

    temp = a.out/'temp'
    temp.mkdir()
    cc = a.cc.resolve()
    env = os.environ.copy()
    env['PATH'] = str(cc.parent)+os.pathsep+env.get('PATH', '')
    env['TMP'] = env['TEMP'] = str(temp)
    sw = ROOT/'project/trash_sorting/source/yolo/software'
    dll = a.out/'policy.dll'
    contact = a.target_policy == 'contact'
    policy_source = 'test_contact_policy.c' if contact else 'test_target_policy.c'
    policy_header = 'yolo_contact_policy.h' if contact else 'yolo_target_policy.h'
    command = [str(cc), '-std=c11', '-O2', '-Wall', '-Wextra', '-Werror', '-shared',
               '-I'+str(sw), str(ROOT/'project/trash_sorting/tools'/policy_source),
               '-lm', '-o', str(dll)]
    result = subprocess.run(command, capture_output=True, text=True, env=env)
    (a.out/'policy_build.log').write_text(result.stdout+result.stderr, encoding='utf8')
    result.check_returncode()
    lib = C.CDLL(str(dll))
    policy_select = lib.policy_select_contact if contact else lib.policy_select_separate
    policy_select.argtypes = [C.POINTER(Box), C.c_uint32, C.POINTER(Box), C.c_uint32,
                                          C.c_float, C.c_float]
    policy_select.restype = Target

    def select(objects, hands, width, height):
        ob = (Box*len(objects))(*[Box(*b[:5], int(b[5])) for b in objects])
        hb = (Box*len(hands))(*[Box(*b[:5], 4) for b in hands])
        t = policy_select(ob, len(ob), hb, len(hb), width, height)
        return dict(selected=int(objects[t.object_index][5]) if t.object_index >= 0 else None,
                    object_index=t.object_index, hand_index=t.hand_index, hand_seen=bool(t.hand_seen),
                    roi=[t.roi_x1, t.roi_y1, t.roi_x2, t.roi_y2])

    import yaml
    data_config = yaml.safe_load((a.data/'data.yaml').read_text(encoding='utf8'))
    names = data_config['names']
    hand_label_class = (names.index('hand') if isinstance(names, list)
                        else next(int(k) for k, v in names.items() if v == 'hand'))
    manifest = json.loads((a.data/'manifest.json').read_text(encoding='utf8'))
    # This tool measures audited hand scenes. Garbage-only AP belongs to the
    # separate fixed-decode validation, since public hand labels are incomplete.
    audited_sources = {'reviewed_hand', 'hagrid_hand_localisation', 'reviewed_hand_negative',
                       'reviewed_hand_context', 'personal_handheld'}
    records = [dict(r, key=Path(r['prepared_image']).stem, path=r['prepared_image'], source_group='hand_val')
               for r in manifest if r['split'] == a.split and
               (r['source'] in audited_sources or r.get('hand_annotation_status') == 'visually reviewed absent')]
    (a.out/'evaluation_config.json').write_text(json.dumps(dict(
        arguments={k: str(v) if isinstance(v, Path) else v for k, v in vars(a).items()},
        manifest_sha256=sha(a.data/'manifest.json'),
        dataset_config_sha256=sha(a.data/'data.yaml'),
        hand_label_class=hand_label_class,
        evaluation_script_sha256=sha(Path(__file__))), indent=2), encoding='utf8')
    truth = {r['id']: r for r in json.loads((a.personal/'truth.json').read_text(encoding='utf8'))['images']}
    inventory = json.loads((a.personal/'inventory.json').read_text(encoding='utf8'))
    hand_truth = {}
    if a.personal_hand_review:
        review = json.loads(a.personal_hand_review.read_text(encoding='utf8'))
        if review['status'] != 'VISUALLY_REVIEWED' or review['source_inventory_sha256'] != sha(a.personal/'inventory.json'):
            raise ValueError('Personal hand review identity mismatch')
        hand_truth = {r['id']: r for r in review['images']}
        if len(hand_truth) != len(inventory) or any(hand_truth[r['id']]['sha256'] != r['sha256'] for r in inventory):
            raise ValueError('Personal hand review does not cover exact inventory')
    if not a.validation_only:
        records += [dict(r, key=str(r['id']), boxes=None, source_group='personal', truth=truth[r['id']])
                    for r in inventory]
    captured = {}

    early_features = {}

    def capture_feature(index):
        def capture(_module, _args, value):
            early_features[index] = value
        return capture

    def run_hand(_module, args):
        # Detect.forward replaces list members. A new list preserves base inputs.
        source = ([early_features[i] for i in feature_layers]
                  if feature_layers != [17,20,23] else list(args[0]))
        captured['features'] = [(x.shape[-2], x.shape[-1], x.shape[1]) for x in source]
        features = [layer(x) for layer, x in zip(adapters, source)] if adapters else source
        captured['hand_channels'] = [x.shape[1] for x in features]
        captured['hand'] = auxiliary.model[-1](features)[0]

    decisions = []
    hand_stats, negative_stats, personal_stats, personal_groups = Counter(), Counter(), Counter(), {}
    context_stats = Counter()
    held_stats = Counter()
    personal_empty_stats = Counter()

    def iou(left, right):
        area = max(0, min(left[2], right[2])-max(left[0], right[0]))*max(0, min(left[3], right[3])-max(left[1], right[1]))
        total = (left[2]-left[0])*(left[3]-left[1])+(right[2]-right[0])*(right[3]-right[1])-area
        return area/total if total > 0 else 0
    extra_macs = None
    with torch.no_grad():
        for index, row in enumerate(records):
            path = Path(row['path'])
            if sha(path) != row['sha256']:
                raise ValueError('Evaluation source changed: '+str(path))
            with Image.open(path) as raw:
                image = ImageOps.exif_transpose(raw).convert('RGB')
            rgb = np.asarray(image)
            width, height = image.size
            network = letterbox(rgb, (320, 320), auto=False, stride=32)[0]
            tensor = torch.from_numpy(np.ascontiguousarray(network.transpose(2, 0, 1))).float()[None]/255
            unhooked = base(tensor)[0]
            if a.joint_model:
                waste = auxiliary(tensor)[0]
                combined = non_max_suppression(waste, .25, .45, multi_label=False, max_det=32)[0]
                objects, hands = combined[combined[:, 5] < 4], combined[combined[:, 5] == 4]
            else:
                early_features.clear()
                feature_hooks = ([base.model[i].register_forward_hook(capture_feature(i)) for i in feature_layers]
                                 if feature_layers != [17,20,23] else [])
                hook = base.model[-1].register_forward_pre_hook(run_hand)
                try:
                    waste = base(tensor)[0]
                finally:
                    hook.remove()
                    for feature_hook in feature_hooks:feature_hook.remove()
                if not torch.equal(unhooked, waste):
                    raise ValueError('Auxiliary hand execution changed waste output')
                standalone_hand = auxiliary(tensor)[0]
                if not torch.equal(standalone_hand, captured['hand']):
                    raise ValueError('Shared-feature hand differs from standalone auxiliary forward: '+
                                     str(float((standalone_hand-captured['hand']).abs().max())))
                if extra_macs is None:
                    extra_macs = sum(h*w*(c*hc*adapters[i].conv.kernel_size[0]**2+hc*18 if adapters else c*18)
                                     for i, ((h, w, c), hc) in enumerate(zip(captured['features'], captured['hand_channels'])))
                objects = non_max_suppression(waste, .25, .45, multi_label=False, max_det=32)[0]
                hands = non_max_suppression(captured['hand'], a.hand_confidence, .45, multi_label=False, max_det=32)[0]
            for boxes in (objects, hands):
                if len(boxes):
                    boxes[:, :4] = scale_boxes(tensor.shape[2:], boxes[:, :4], rgb.shape)
            objects, hands = objects.cpu().tolist(), hands.cpu().tolist()
            chosen = select(objects, hands, width, height)
            largest = select(objects, [], width, height)
            top = int(objects[0][5]) if objects else None
            decision = dict(key=row['key'], source_group=row['source_group'], path=str(path),
                            source_sha256=row['sha256'], width=width, height=height,
                            waste=objects, hands=hands, top=top, largest=largest['selected'], **chosen)
            if row['source_group'] == 'hand_val':
                hand_labels = hand_annotations(row, hand_label_class)
                contextual = row['source'] == 'reviewed_hand_context'
                personal_empty = row['source'] == 'personal_handheld' and row.get('empty_hand', False)
                held = row['source'] == 'personal_handheld' and not personal_empty
                if personal_empty and row.get('held_object') is not None:
                    raise ValueError('Empty-hand scene cannot have held-object truth')
                stats = personal_empty_stats if personal_empty else held_stats if held else context_stats if contextual else hand_stats if hand_labels else negative_stats
                stats['images'] += 1
                stats['hand_seen_images'] += bool(hands)
                stats['selected_images'] += chosen['selected'] is not None
                if hand_labels:
                    pred_array, gt_array = hand_metric_arrays(hands, hand_labels, width, height)
                    gt, hp = torch.from_numpy(gt_array), torch.from_numpy(pred_array)
                    correct = process_batch(hp, gt, torch.tensor([.5])) if len(hands) else []
                    tp = int(correct.sum()) if len(hands) else 0
                    stats['TP'] += tp
                    stats['FP'] += len(hands)-tp
                    stats['GT'] += len(hand_labels)
                else:
                    stats['hand_false_detections'] += len(hands)
                # These hand positives show empty gestures, not held garbage.
                decision['empty_hand'] = bool(hand_labels) and not contextual and not held
                decision['physical_group'] = row.get('group')
                decision['hand_annotation_source'] = row['source']
                if held:
                    target = row['held_object']
                    xyxy = [target['xyxy'][i]*(width if i%2 == 0 else height) for i in range(4)]
                    if len(hand_labels) != 1:
                        raise ValueError('Held relation requires exactly one reviewed hand')
                    hb = hand_labels[0]
                    hand_gt = [(hb[1]-hb[3]/2)*width, (hb[2]-hb[4]/2)*height,
                               (hb[1]+hb[3]/2)*width, (hb[2]+hb[4]/2)*height, 1., 0]
                    oracle = select(objects, [hand_gt], width, height)
                    oracle_box = objects[oracle['object_index']] if oracle['object_index'] >= 0 else None
                    candidate = objects[chosen['object_index']] if chosen['object_index'] >= 0 else None
                    selected_iou = iou(candidate, xyxy) if candidate else 0
                    decision.update(held_truth=target, selected_subject_iou=selected_iou,
                                    selected_subject_correct=selected_iou >= .5,
                                    selected_bucket_correct=chosen['selected'] == target['bin'],
                                    oracle_hand_selection=oracle,
                                    oracle_hand_selected_subject_iou=iou(oracle_box, xyxy) if oracle_box else 0)
                    stats['subject_selected_iou050'] += selected_iou >= .5
                    stats['bucket_correct'] += chosen['selected'] == target['bin']
                    stats['subject_and_bucket_correct'] += selected_iou >= .5 and chosen['selected'] == target['bin']
                    # A correct largest-box fallback must not be reported as
                    # successful hand-guided recognition.
                    outcome = 'hand_present' if hands else 'no_hand_fallback'
                    stats[outcome+'_images'] += 1
                    stats[outcome+'_subject_and_bucket_correct'] += selected_iou >= .5 and chosen['selected'] == target['bin']
                    stats['base_subject_detected_iou050'] += any(iou(b, xyxy) >= .5 for b in objects)
                    stats['base_subject_correct_bucket_iou050'] += any(iou(b, xyxy) >= .5 and int(b[5]) == target['bin'] for b in objects)
                    stats['oracle_hand_subject_and_bucket_correct'] += bool(oracle_box) and iou(oracle_box, xyxy) >= .5 and int(oracle_box[5]) == target['bin']
            else:
                gt = row['truth']
                accepted = gt.get('accepted_bins', [gt['bin']])
                decision['truth'] = gt
                stats_group = personal_groups.setdefault(gt['group'], Counter())
                for stats in (personal_stats, stats_group):
                    stats['images'] += 1
                    stats['hand_seen_images'] += bool(hands)
                    stats['strict_correct'] += chosen['selected'] == gt['bin']
                    stats['accepted_correct'] += chosen['selected'] in accepted
                    stats['largest_accepted_correct'] += largest['selected'] in accepted
                    stats['top_accepted_correct'] += top in accepted
                    stats['no_selection'] += chosen['selected'] is None
                    if row['id'] in hand_truth:
                        stats['hand_presence_reviewed_images'] += 1
                        if not hand_truth[row['id']]['visible_hand']:
                            stats['reviewed_no_hand_images'] += 1
                            stats['false_hand_images'] += bool(hands)
            decisions.append(decision)
            if hands or index < 6 or row.get('source') == 'personal_handheld':
                preview = image.copy()
                preview.thumbnail((800, 600))
                draw = ImageDraw.Draw(preview)
                for boxes, color in ((objects, '#4477ff'), (hands, '#ffcc00')):
                    for b in boxes:
                        draw.rectangle((b[0]*preview.width/width, b[1]*preview.height/height,
                                        b[2]*preview.width/width, b[3]*preview.height/height), outline=color, width=2)
                if row.get('source') == 'personal_handheld' and not row.get('empty_hand', False):
                    truth_box = row['held_object']['xyxy']
                    draw.rectangle(tuple(truth_box[i]*(preview.width if i%2 == 0 else preview.height)
                                         for i in range(4)), outline='#ff33cc', width=3)
                    draw.text((4, 4), 'Magenta: held-subject truth; yellow: predicted hand', fill='white')
                preview.save(a.out/f"preview_{row['source_group']}_{row['key']}.jpg")
            if (index+1) % 10 == 0:
                print('EVALUATED', index+1, '/', len(records), flush=True)
    held_groups = {}
    for decision in decisions:
        if 'held_truth' in decision:
            group_stats = held_groups.setdefault(str(decision['physical_group']), Counter())
            group_stats['images'] += 1
            group_stats['hand_seen_images'] += decision['hand_seen']
            group_stats['subject_and_bucket_correct'] += decision['selected_subject_correct'] and decision['selected_bucket_correct']
    report = dict(status='OFFLINE_FLOAT_EVALUATED', **identity,
                  unchanged_waste_forward_images=0 if a.joint_model else len(decisions),
                  target_policy=a.target_policy, policy_sha256=sha(sw/policy_header),
                  common_geometry_sha256=sha(sw/'yolo_target_policy.h'), conf=.25, nms_iou=.45,
                  hand_confidence=a.hand_confidence,
                  shared_hand_forward_exact=None if a.joint_model else True,
                  joint_model=a.joint_model,
                  annotation_hand_class=hand_label_class,
                  hand_metric_class=0,
                  evaluation_script_sha256=sha(Path(__file__)),
                  personal_hand_review_sha256=sha(a.personal_hand_review) if a.personal_hand_review else None,
                  max_detections_per_list=32, joint_global_detection_capacity=32 if a.joint_model else None,
                  extra_hand_head_macs=extra_macs,
                  adapter_layers=len(adapters),
                  shared_feature_layers=feature_layers if not a.joint_model else None,
                  hand_val=hand_stats, no_hand_val=negative_stats,
                  contextual_hand_val=context_stats,
                  personal_held_split=held_stats, personal_empty_hand_split=personal_empty_stats,
                  personal_held_groups=held_groups, evaluated_split=a.split,
                  held_truth_bins=sorted({d['held_truth']['bin'] for d in decisions if 'held_truth' in d}),
                  personal=personal_stats, personal_groups=personal_groups,
                  limits=['CPU floating point, not Q15 or FPGA timing',
                          'Validation is for model development; test is final held-out evaluation only',
                          'Old80 photos are repeated diagnostics; some physical items now occur in new training photos',
                          'New held scenes use reviewed subject boxes; old80 bucket truth is image-level',
                          'Same hand and rooms across personal splits; no independent-subject accuracy claim',
                          'Largest-box background mistakes remain the waste detector responsibility'])
    (a.out/'decisions.json').write_text(json.dumps(decisions, ensure_ascii=False, indent=2), encoding='utf8')
    (a.out/'result.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf8')
    print(json.dumps(report, ensure_ascii=False), flush=True)


if __name__ == '__main__':
    main()
