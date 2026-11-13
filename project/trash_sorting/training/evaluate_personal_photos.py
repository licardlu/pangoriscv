"""Read-only personal-photo inventory and offline four-bin inference.

Source photos stay in place. Image-level truth is reviewed independently of
predictions; this tool does not create training labels or claim detection AP.
"""
import argparse
from collections import Counter, defaultdict
import csv
import hashlib
import json
import os
from pathlib import Path
import sys
import time

from PIL import Image, ImageDraw, ImageFont, ImageOps

ROOT = Path(__file__).resolve().parents[3]
NAMES = ['kitchen', 'recyclable', 'hazardous', 'other']
ZH = ['厨余/绿', '可回收/蓝', '有害/红', '其他/灰']
COLORS = ['#00a050', '#0060ff', '#e02020', '#848484']
FONT = 'C:/Windows/Fonts/msyh.ttc'


def save_json(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2)+'\n', encoding='utf8')


def load_photo(path):
    with Image.open(path) as im:
        return ImageOps.exif_transpose(im).convert('RGB')


def inventory(source, out):
    out.mkdir(parents=True, exist_ok=False)
    paths = sorted(p for p in source.rglob('*') if p.is_file() and p.suffix.lower() in
                   {'.jpg', '.jpeg', '.png', '.webp', '.bmp', '.tif', '.tiff'})
    rows = []
    thumb_font = ImageFont.truetype(FONT, 16)
    for start in range(0, len(paths), 20):
        sheet = Image.new('RGB', (1500, 1200), '#f2f2f2')
        d = ImageDraw.Draw(sheet)
        for pos, path in enumerate(paths[start:start+20]):
            number = start+pos+1
            with Image.open(path) as raw:
                w, h = raw.size
                orientation = raw.getexif().get(274, 1)
            im = load_photo(path)
            rows.append({'id': number, 'path': str(path.resolve()), 'file': path.name,
                         'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
                         'raw_size': [w, h], 'orientation': orientation,
                         'display_size': list(im.size)})
            im.thumbnail((290, 250))
            x, y = (pos%5)*300, (pos//5)*300
            sheet.paste(im, (x+(300-im.width)//2, y+(250-im.height)//2))
            d.text((x+6, y+252), f'{number:02d}  {path.stem[-13:]}', font=thumb_font, fill='black')
            d.text((x+6, y+276), f'{w} x {h}', font=thumb_font, fill='#555555')
        sheet.save(out/f'contact_{start//20+1:02d}.jpg', quality=93)
    save_json(out/'inventory.json', rows)
    print(json.dumps({'images': len(rows), 'sizes': dict(Counter(str(r['display_size']) for r in rows)),
                      'unique_sha256': len({r['sha256'] for r in rows}), 'out':str(out)}, ensure_ascii=False))


def evaluate(out, yolo, weights):
    # Both files are fixed before model inference; truth never comes from output.
    rows = json.loads((out/'inventory.json').read_text(encoding='utf8'))
    truth = json.loads((out/'truth.json').read_text(encoding='utf8'))
    if {r['id'] for r in rows} != {r['id'] for r in truth['images']}:
        raise ValueError('Every photo needs an independently reviewed truth entry')
    os.environ['YOLOv5_AUTOINSTALL'] = 'false'
    os.environ['WANDB_MODE'] = 'disabled'
    os.environ['YOLOV5_CONFIG_DIR'] = str(out/'config')
    (out/'config').mkdir(exist_ok=True)
    sys.path.insert(0, str(yolo.resolve()))
    import cv2
    import numpy as np
    import torch
    from utils.augmentations import letterbox
    from utils.general import non_max_suppression, scale_boxes
    torch.set_num_threads(4)
    torch.set_num_interop_threads(1)
    cv2.setNumThreads(0)
    cp = torch.load(weights, map_location='cpu')
    model = (cp.get('ema') or cp['model']).float().eval()
    if model.model[-1].nc != 4:
        raise ValueError('Expected four-bin checkpoint')
    provenance = {'model': str(weights.resolve()), 'model_sha256': hashlib.sha256(weights.read_bytes()).hexdigest(),
                  'inventory_sha256': hashlib.sha256((out/'inventory.json').read_bytes()).hexdigest(),
                  'truth_sha256_before_inference': hashlib.sha256((out/'truth.json').read_bytes()).hexdigest(),
                  'upstream': str(yolo.resolve()), 'torch': torch.__version__,
                  'input': 'EXIF transpose RGB; aspect-ratio letterbox to fixed 320x320, auto=False, scaleup=True',
                  'confidence': .25, 'nms_iou': .45, 'multi_label': False,
                  'decision': 'highest confidence box; no detection counted as incorrect',
                  'runtime': 'CPU floating point; not FPGA', 'no_training': True,
                  'script_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest()}
    save_json(out/'provenance.json', provenance)
    predictions = []
    with torch.inference_mode():
        model(torch.zeros(1, 3, 320, 320))
        for row in rows:
            path = Path(row['path'])
            if hashlib.sha256(path.read_bytes()).hexdigest() != row['sha256']:
                raise ValueError('Source photo changed since review: '+str(path))
            rgb = np.array(load_photo(path))
            image = letterbox(rgb, (320, 320), auto=False, stride=32)[0]
            tensor = torch.from_numpy(np.ascontiguousarray(image.transpose(2, 0, 1))).float().unsqueeze(0)/255.
            begin = time.perf_counter()
            raw = model(tensor)[0]
            pred = non_max_suppression(raw, conf_thres=.25, iou_thres=.45,
                                       multi_label=False, max_det=100)[0]
            ms = (time.perf_counter()-begin)*1000
            if len(pred):
                pred[:, :4] = scale_boxes(tensor.shape[2:], pred[:, :4], rgb.shape).round()
                pred = pred[pred[:,4].argsort(descending=True)]
            boxes = [{'class': int(p[5]), 'confidence': float(p[4]), 'xyxy':p[:4].tolist()}
                     for p in pred.cpu()]
            predictions.append({'id':row['id'], 'file':row['file'], 'top_bin':boxes[0]['class'] if boxes else None,
                                'top_confidence': boxes[0]['confidence'] if boxes else None,
                                'boxes':boxes, 'inference_nms_cpu_ms':ms})
            if row['id']%10==0:
                print(f'EVALUATED {row["id"]}/{len(rows)}', flush=True)
    save_json(out/'predictions.json', predictions)
    print('PERSONAL_PHOTO_INFERENCE_COMPLETE', len(predictions), flush=True)


def report(out):
    rows = json.loads((out/'inventory.json').read_text(encoding='utf8'))
    truth = {r['id']: r for r in json.loads((out/'truth.json').read_text(encoding='utf8'))['images']}
    predictions = {r['id']: r for r in json.loads((out/'predictions.json').read_text(encoding='utf8'))}
    if len(rows)!=len(predictions) or len(truth)!=len(rows):
        raise ValueError('Incomplete evaluation')
    object_stats = defaultdict(lambda: {'images':0,'strict_correct':0,'accepted_correct':0,'predictions':Counter()})
    bin_stats = defaultdict(lambda: {'images':0,'strict_correct':0,'accepted_correct':0})
    matrix = [[0]*5 for _ in range(4)]
    details = []
    for row in rows:
        t,p = truth[row['id']], predictions[row['id']]
        predicted = p['top_bin']
        strict = predicted == t['bin']
        accepted = predicted in t.get('accepted_bins',[t['bin']])
        matrix[t['bin']][predicted if predicted is not None else 4] += 1
        for stat in [object_stats[t['object']], bin_stats[NAMES[t['bin']]]]:
            stat['images']+=1;stat['strict_correct']+=strict;stat['accepted_correct']+=accepted
        object_stats[t['object']]['predictions'][NAMES[predicted] if predicted is not None else 'no_detection']+=1
        details.append({'id':row['id'],'file':row['file'],'object':t['object'], 'group':t['group'],
                        'target':NAMES[t['bin']],'predicted':NAMES[predicted] if predicted is not None else 'no_detection',
                        'confidence':p['top_confidence'],'strict_correct':strict,'user_accepted':accepted,
                        'boxes':len(p['boxes'])})
    # Gallery shows every image in filename order, never only successful cases.
    f = ImageFont.truetype(FONT, 16)
    for start in range(0,len(rows),20):
        sheet = Image.new('RGB',(1500,1280),'#f4f4f4');d=ImageDraw.Draw(sheet)
        for pos,row in enumerate(rows[start:start+20]):
            t,p=truth[row['id']],predictions[row['id']]
            im=load_photo(Path(row['path']));ow,oh=im.size;im.thumbnail((290,240))
            painter=ImageDraw.Draw(im)
            for k,b in reversed(list(enumerate(p['boxes']))):
                x1,y1,x2,y2=b['xyxy']
                painter.rectangle((x1*im.width/ow,y1*im.height/oh,x2*im.width/ow,y2*im.height/oh),
                                  outline=COLORS[b['class']],width=3 if k==0 else 1)
            x,y=(pos%5)*300,(pos//5)*320
            sheet.paste(im,(x+(300-im.width)//2,y+(240-im.height)//2))
            pred=p['top_bin'];strict=pred==t['bin'];accepted=pred in t.get('accepted_bins',[t['bin']])
            d.text((x+5,y+242),f'{row["id"]:02d} {t["object"]} → {ZH[t["bin"]]}',font=f,fill='black')
            label=ZH[pred] if pred is not None else '未检测'
            confidence=f'{p["top_confidence"]:.2f}' if pred is not None else '—'
            d.text((x+5,y+266),f'预测：{label} 分数{confidence}',font=f,fill=COLORS[pred] if pred is not None else 'black')
            status='正确' if strict else '按用户放宽口径可接受' if accepted else '错误'
            d.text((x+5,y+290),status,font=f,fill='#087a40' if strict else '#906000' if accepted else '#c02020')
        sheet.save(out/f'predictions_{start//20+1:02d}.jpg',quality=94)
    strict_count=sum(d['strict_correct'] for d in details)
    accepted_count=sum(d['user_accepted'] for d in details)
    without_medicine=[d for d in details if d['object']!='药瓶']
    result={'images':len(rows),'strict_correct':strict_count,'strict_accuracy':strict_count/len(rows),
            'user_accepted_correct':accepted_count,'user_accepted_accuracy':accepted_count/len(rows),
            'excluding_medicine_bottles':{'images':len(without_medicine),'correct':sum(d['strict_correct'] for d in without_medicine)},
            'no_detection':sum(p['top_bin'] is None for p in predictions.values()),
            'objects':dict(object_stats),'bins':dict(bin_stats), 'confusion_matrix':matrix,
            'matrix_rows':NAMES,'matrix_columns':NAMES+['no_detection'],
            'wrong_ids':[d['id'] for d in details if not d['strict_correct']],
            'wrong_ids_after_user_relaxation':[d['id'] for d in details if not d['user_accepted']],
            'limits':'Image-level top-score bucket only; boxes were not manually annotated, no mAP is measured. Repeated real objects and backgrounds, no independent-object population inference. Confidence is not accuracy. All 80 photos are evaluation only, not used for training.'}
    save_json(out/'metrics.json',result)
    save_json(out/'image_decisions.json',details)
    with (out/'image_decisions.csv').open('w',newline='',encoding='utf-8-sig') as handle:
        writer=csv.DictWriter(handle,fieldnames=list(details[0]));writer.writeheader();writer.writerows(details)
    print(json.dumps(result,ensure_ascii=False,indent=2))


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('action', choices=['inventory', 'evaluate', 'report'])
    p.add_argument('--source', type=Path, default=Path('D:/Huawei Share/Huawei Share'))
    p.add_argument('--out', type=Path, required=True)
    p.add_argument('--yolo', type=Path, default=ROOT/'build/trash_retrain_research_20261111_001/yolov5-7.0')
    p.add_argument('--weights', type=Path, default=ROOT/'project/trash_sorting/training/candidates/four_bins_20261111/four_bins_yolov5n_320.pt')
    a = p.parse_args()
    if a.action=='inventory':
        inventory(a.source, a.out)
    elif a.action=='evaluate':
        evaluate(a.out, a.yolo, a.weights)
    else:
        report(a.out)


if __name__=='__main__':
    main()
