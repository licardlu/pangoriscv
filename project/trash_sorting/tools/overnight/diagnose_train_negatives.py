"""Measure training-set negative fit, never generalization or camera accuracy.

Only train rows whose annotations contain no waste are opened. Repeated image
bytes are counted once. Weights and the current compiled C selector are frozen;
this diagnostic does not fit parameters, tune thresholds, or access hardware.
"""
import argparse
from collections import Counter, defaultdict
import ctypes as C
import hashlib
import json
import os
from pathlib import Path
import sys
import time

from replay_policy import Box, Target


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--manifest', type=Path, required=True)
    p.add_argument('--yolo', type=Path, required=True)
    p.add_argument('--checkpoint', nargs=3, action='append', required=True,
                   metavar=('NAME', 'PATH', 'SHA256'))
    p.add_argument('--policy-dir', type=Path, required=True)
    p.add_argument('--source-dir', type=Path, required=True)
    p.add_argument('--out', type=Path, required=True)
    a = p.parse_args()
    a.out = a.out.resolve()
    a.out.mkdir(parents=True, exist_ok=False)
    started = time.time()
    names = [v[0] for v in a.checkpoint]
    assert len(set(names)) == len(names)
    for _, path, expected in a.checkpoint:
        assert sha(path) == expected, 'Checkpoint identity mismatch'

    # Inspect split metadata to choose train rows, but never open val/test files.
    manifest = json.loads(a.manifest.read_text(encoding='utf8'))
    selected = {}
    repeated = 0
    for r in manifest:
        if r['split'] != 'train' or any(int(b[0]) < 4 for b in r['boxes']):
            continue
        assert all(int(b[0]) == 4 for b in r['boxes'])
        key = r['image_sha256']
        if key in selected:
            before = selected[key]
            assert before['boxes'] == r['boxes'] and before['source'] == r['source']
            repeated += 1
        else:
            selected[key] = r
    rows = sorted(selected.values(), key=lambda r: (r['source'], r['prepared_image']))
    assert rows, 'No train negatives'
    inventory = []
    for r in rows:
        image = Path(r['prepared_image'])
        label = image.parent.parent.parent / 'labels' / 'train' / (image.stem + '.txt')
        assert sha(image) == r['image_sha256'], str(image)
        assert sha(label) == r['label_sha256'], str(label)
        actual = [[float(x) for x in line.split()] for line in label.read_text().splitlines() if line.strip()]
        assert len(actual) == len(r['boxes'])
        assert all(all(abs(x-y) <= 1e-6 for x,y in zip(b,c)) and len(b)==len(c)
                   for b,c in zip(actual, r['boxes'])), str(label)
        inventory.append(dict(path=str(image), split='train', source=r['source'],
                              image_sha256=r['image_sha256'], label_sha256=r['label_sha256']))
    (a.out/'inventory.json').write_text(json.dumps(inventory, indent=2), encoding='utf8')

    policy_report = json.loads((a.policy_dir/'result.json').read_text(encoding='utf8'))
    sw = a.source_dir/'yolo/software'
    headers = {path.name: sha(path) for path in sw.glob('*policy.h')}
    assert headers == policy_report['headers'], 'Compiled selector headers are stale'
    lib = C.CDLL(str((a.policy_dir/'policy.dll').resolve()))
    lib.policy_select.argtypes = [C.POINTER(Box), C.c_uint32, C.c_uint32,
                                  C.c_uint32, C.c_float, C.c_float]
    lib.policy_select.restype = Target
    os.environ['YOLOv5_AUTOINSTALL'] = 'false'
    os.environ['WANDB_MODE'] = 'disabled'
    os.environ['YOLOV5_CONFIG_DIR'] = str(a.out/'config')
    os.environ['OMP_NUM_THREADS'] = '2'
    os.environ['MKL_NUM_THREADS'] = '2'
    os.environ['MPLBACKEND'] = 'Agg'
    sys.path.insert(0, str(a.yolo.resolve()))
    import cv2
    import numpy as np
    import torch
    from utils.augmentations import letterbox
    from utils.general import non_max_suppression, scale_boxes
    torch.set_num_threads(2)
    torch.set_num_interop_threads(1)
    cv2.setNumThreads(0)

    reports = {}
    all_decisions = {}
    for name, path, expected in a.checkpoint:
        cp = torch.load(path, map_location='cpu')
        model = (cp.get('ema') or cp['model']).float().eval()
        assert model.model[-1].nc == 5
        decisions = []
        stats = defaultdict(Counter)
        with torch.inference_mode():
            for idx, r in enumerate(rows):
                # Match YOLOv5 non-augment, non-rect validation preprocessing:
                # initial resize uses truncated sizes and AREA when downsampling;
                # letterbox then pads to 320 and uses the recorded resize ratio.
                im = cv2.imdecode(np.fromfile(r['prepared_image'], dtype=np.uint8), cv2.IMREAD_COLOR)
                assert im is not None
                h0,w0 = im.shape[:2]
                if 'width' in r and 'height' in r:
                    assert (w0,h0) == (r['width'],r['height'])
                ratio = 320/max(h0,w0)
                if ratio != 1:
                    im = cv2.resize(im, (int(w0*ratio),int(h0*ratio)),
                                    interpolation=cv2.INTER_LINEAR if ratio > 1 else cv2.INTER_AREA)
                h,w = im.shape[:2]
                im, _, pad = letterbox(im, 320, auto=False, scaleup=False)
                x = torch.from_numpy(np.ascontiguousarray(im.transpose(2,0,1)[::-1])).float()[None]/255
                pred = non_max_suppression(model(x)[0], .25, .45, multi_label=False, max_det=32)[0]
                scale_boxes(x.shape[2:], pred[:,:4], (h0,w0), ((h/h0,w/w0),pad))
                boxes = pred.cpu().tolist()
                cb = (Box*len(boxes))(*[Box(*b[:5],int(b[5])) for b in boxes])
                t = lib.policy_select(cb,len(boxes),4,4,w0,h0)
                chosen = boxes[t.object_index] if t.object_index >= 0 else None
                raw_waste = any(int(b[5]) < 4 for b in boxes)
                for cohort in ('all','source/'+r['source']):
                    s = stats[cohort]
                    s['unique_train_images'] += 1
                    s['raw_waste_detection_images'] += raw_waste
                    s['false_selected_images'] += chosen is not None
                    s['hand_seen_images'] += bool(t.hand_seen)
                decisions.append(dict(path=r['prepared_image'],source=r['source'],width=w0,height=h0,
                                      image_sha256=r['image_sha256'],detections=boxes,selected=chosen,
                                      hand_seen=bool(t.hand_seen)))
                if (idx+1)%50 == 0:
                    print(f'{name}: {idx+1}/{len(rows)} train-only negatives', flush=True)
        reports[name] = dict(checkpoint_sha256=expected, cohorts=dict(stats))
        all_decisions[name] = decisions
        print(json.dumps({name:reports[name]['cohorts']},ensure_ascii=False), flush=True)
        del model,cp

    (a.out/'decisions.json').write_text(json.dumps(all_decisions,indent=2), encoding='utf8')
    result = dict(status='TRAIN_NEGATIVE_FIT_DIAGNOSTIC_COMPLETED',
                  scope='CPU float training-fit only; not generalization, Q15, FPGA, or camera accuracy',
                  manifest_sha256=sha(a.manifest), inventory_sha256=sha(a.out/'inventory.json'),
                  script_sha256=sha(__file__), headers=headers, policy_dll_sha256=sha(a.policy_dir/'policy.dll'),
                  split='train', unique_images=len(rows), repeated_sampling_rows_ignored=repeated,
                  thresholds=dict(confidence=.25,nms_iou=.45,max_det=32,single_label=True),
                  sources=dict(Counter(r['source'] for r in rows)),reports=reports,
                  torch=torch.__version__, opencv=cv2.__version__, elapsed_s=time.time()-started,
                  val_images_opened=False,test_images_opened=False,labels_changed=False,
                  training_performed=False,hardware_accessed=False)
    (a.out/'result.json').write_text(json.dumps(result,indent=2),encoding='utf8')
    print('TEST_PASS train-only negative fit diagnostic', flush=True)


if __name__ == '__main__':
    main()
