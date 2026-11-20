"""Audit hand/waste errors on a fixed, train-only stratified sample.

No validation/test images, label edits, optimizer steps or threshold search.
This audit identifies whether extra training should target false hands,
missing hands, or missed waste before budgeting the next CPU run.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import sys
import types
from collections import Counter


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    for key in ['manifest', 'baseline', 'candidate', 'yolo', 'out']:
        ap.add_argument('--' + key, type=Path, required=True)
    a = ap.parse_args()
    a.out.mkdir(parents=True, exist_ok=False)
    os.environ['YOLOV5_CONFIG_DIR'] = str(a.out / 'config')
    os.environ['YOLOv5_AUTOINSTALL'] = 'false'
    sys.path.insert(0, str(a.yolo.resolve()))
    import cv2
    import numpy as np
    import torch
    import models.common, models.yolo, models.experimental
    pkg = types.ModuleType('yolov5')
    pkg.models = types.ModuleType('yolov5.models')
    sys.modules['yolov5'] = pkg
    sys.modules['yolov5.models'] = pkg.models
    for key in ['common', 'yolo', 'experimental']:
        sys.modules['yolov5.models.' + key] = sys.modules['models.' + key]
    from PIL import Image, ImageOps
    from utils.augmentations import letterbox
    from utils.general import non_max_suppression
    from utils.metrics import box_iou
    torch.set_num_threads(4)
    torch.set_num_interop_threads(1)
    cv2.setNumThreads(0)
    rows = json.loads(a.manifest.read_text(encoding='utf8'))
    unique = {r['image_sha256']: r for r in rows if r['split'] == 'train'}
    held = {r['image_sha256'] for r in rows if r['split'] != 'train'}
    assert not set(unique) & held
    groups = {f'class{c}': [r for r in unique.values() if any(int(b[0]) == c for b in r['boxes'])]
              for c in range(5)}
    groups.update(battery=[r for r in unique.values() if 'battery' in r['source'].lower()],
                  glass=[r for r in unique.values() if 'glass' in r['source'].lower()],
                  empty=[r for r in unique.values() if not r['boxes']],
                  mixed=[r for r in unique.values() if any(int(b[0]) == 4 for b in r['boxes'])
                         and any(int(b[0]) < 4 for b in r['boxes'])])
    selected = {}
    for group in groups.values():
        for row in sorted(group, key=lambda r: r['image_sha256'])[:24]:
            selected[row['image_sha256']] = row
    models = {}
    for name in ['baseline', 'candidate']:
        cp = torch.load(getattr(a, name), map_location='cpu')
        models[name] = (cp.get('ema') or cp['model']).float().eval()
        assert models[name].model[-1].nc == 5
    summary = {k: Counter() for k in models}
    evidence = []
    with torch.no_grad():
        for index, row in enumerate(selected.values()):
            assert row['split'] == 'train'
            image_path, label_path = Path(row['prepared_image']), Path(row['label'])
            assert hashlib.sha256(image_path.read_bytes()).hexdigest() == row['image_sha256']
            assert hashlib.sha256(label_path.read_bytes()).hexdigest() == row['label_sha256']
            with Image.open(image_path) as im:
                rgb = np.array(ImageOps.exif_transpose(im).convert('RGB'))
            h, w = rgb.shape[:2]
            canvas, ratio, pad = letterbox(rgb, (320, 320), auto=False)
            image = torch.from_numpy(canvas.transpose(2, 0, 1).copy()).float().unsqueeze(0) / 255.
            gt = []
            for c, cx, cy, bw, bh in row['boxes']:
                gt.append([(cx-bw/2)*w*ratio[0]+pad[0], (cy-bh/2)*h*ratio[1]+pad[1],
                           (cx+bw/2)*w*ratio[0]+pad[0], (cy+bh/2)*h*ratio[1]+pad[1], c])
            gt = torch.tensor(gt, dtype=torch.float32).reshape(-1, 5)
            hands, waste = gt[gt[:, 4] == 4, :4], gt[gt[:, 4] < 4]
            record = dict(image_sha256=row['image_sha256'], path=str(image_path), source=row['source'],
                          split='train', gt_boxes_320=gt.tolist(), outputs={})
            for name, model in models.items():
                prediction = non_max_suppression(model(image)[0], conf_thres=.25, iou_thres=.45,
                                                 multi_label=False, max_det=100)[0]
                predicted_hands = prediction[prediction[:, 5] == 4]
                pair = box_iou(predicted_hands[:, :4], hands)
                best = pair.max(1).values if len(hands) else torch.zeros(len(predicted_hands))
                false_hands = predicted_hands[best < .3]
                missing_hands = int(((pair.max(0).values if len(predicted_hands) else torch.zeros(len(hands))) < .5).sum())
                missed_waste = 0
                for box in waste:
                    same_class = prediction[prediction[:, 5] == box[4], :4]
                    correct = len(same_class) and bool((box_iou(box[:4].reshape(1, 4), same_class) >= .5).any())
                    missed_waste += int(not correct)
                stats = dict(images=1, gt_hands=len(hands), gt_waste=len(waste),
                             unmatched_hand_detections=len(false_hands),
                             images_with_unmatched_hand=int(len(false_hands)>0),
                             missed_gt_hands=missing_hands, missed_gt_waste=missed_waste)
                summary[name].update(stats)
                record['outputs'][name] = dict(stats=stats, predictions_320=prediction.tolist(),
                                               unmatched_hands_320=false_hands.tolist())
            evidence.append(record)
            if (index+1) % 24 == 0:
                print('TRAIN_ONLY_AUDIT', index+1, len(selected), flush=True)
    result = dict(status='COMPLETED_TRAIN_ONLY_DIAGNOSTIC', selected_images=len(selected),
                  selection='First24 SHA-sorted training identities in each of5classes,battery,glass,empty,mixed; deduplicated',
                  summary={k: dict(v) for k, v in summary.items()}, validation_or_test_images_read=False,
                  labels_modified=False, weights_saved=False, no_new_photos=True,
                  interpretation='Unmatched hand detections require visual label review; incomplete GT can cause unmatched predictions.',
                  baseline_sha256=hashlib.sha256(a.baseline.read_bytes()).hexdigest(),
                  candidate_sha256=hashlib.sha256(a.candidate.read_bytes()).hexdigest(),
                  records=evidence)
    (a.out / 'result.json').write_text(json.dumps(result, indent=2), encoding='utf8')
    print(json.dumps({k: v for k, v in result.items() if k != 'records'}), flush=True)


if __name__ == '__main__':
    main()
