"""Summarize actual FPGA predictions; never runs a PC detector or opens serial.

Default requires the entire precommitted 18-image evaluation to be complete.
Use --allow-partial only for explicitly labelled interim diagnostics.
"""
from pathlib import Path
import argparse
import collections
import contextlib
import csv
import hashlib
import io
import json
import math
import statistics
import struct
import sys

sys.path.insert(0, r'C:\Users\TWINKL~1\AppData\Local\Temp\fpga_validation_deps_20261104')
from pycocotools.coco import COCO
from pycocotools.cocoeval import COCOeval
from PIL import Image, ImageDraw, ImageFont
import numpy as np

BASE = Path(__file__).resolve().parent
NAMES = ['biodegradable', 'cardboard', 'glass', 'metal', 'paper', 'plastic']


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def iou(a, b):
    iw = max(0., min(a[2], b[2]) - max(a[0], b[0]))
    ih = max(0., min(a[3], b[3]) - max(a[1], b[1]))
    inter = iw * ih
    union = max(0., a[2] - a[0]) * max(0., a[3] - a[1]) + max(0., b[2] - b[0]) * max(0., b[3] - b[1]) - inter
    return inter / union if union > 0 else 0.


def ratio(n, d):
    return n / d if d else 0.


def read_raw(path):
    data = path.read_bytes()
    count, = struct.unpack_from('<I', data)
    if len(data) != 4 + 24 * count or count > 32:
        raise ValueError('Invalid raw FPGA packet: ' + str(path))
    rows = []
    for i in range(count):
        x1, y1, x2, y2, score, cid = struct.unpack_from('<5fI', data, 4 + 24 * i)
        rows.append({'category': NAMES[cid], 'score': score, 'box': [x1, y1, x2, y2]})
    return rows


def coco_metrics(images, predictions):
    dataset = {'info': {'description': 'Actual FPGA validation subset'},
               'licenses': [], 'images': [], 'annotations': [],
               'categories': [{'id': i, 'name': name} for i, name in enumerate(NAMES)]}
    ident = 1
    for row in images:
        dataset['images'].append({'id': row['image_id'], 'file_name': row['file_name'],
                                  'width': row['width'], 'height': row['height']})
        for a in row['gt']:
            x1, y1, x2, y2 = a['bbox_xyxy']
            dataset['annotations'].append({'id': ident, 'image_id': row['image_id'],
                  'category_id': a['class_id'], 'bbox': [x1, y1, x2-x1, y2-y1],
                  'area': (x2-x1)*(y2-y1), 'iscrowd': a.get('iscrowd', 0)})
            ident += 1
    gt = COCO()
    gt.dataset = dataset
    gt.createIndex()
    # COCO.loadRes indexes the first element and fails on an empty prediction list.
    if predictions:
        dt = gt.loadRes(predictions)
    else:
        dt = COCO()
        dt.dataset = {**dataset, 'annotations': []}
        dt.createIndex()
    evaluator = COCOeval(gt, dt, 'bbox')
    evaluator.params.imgIds = [row['image_id'] for row in images]
    evaluator.params.catIds = list(range(6))
    evaluator.params.maxDets = [1, 10, 100]
    evaluator.evaluate()
    evaluator.accumulate()
    evaluator.summarize()
    precision = evaluator.eval['precision']  # IoU, recall, category, area, maxDets
    per = {}
    for cid, name in enumerate(NAMES):
        all_iou = precision[:, :, cid, 0, -1]
        p50 = precision[0, :, cid, 0, -1]
        per[name] = {'ap50': float(np.mean(p50[p50 > -1])) if np.any(p50 > -1) else None,
                     'ap50_95': float(np.mean(all_iou[all_iou > -1])) if np.any(all_iou > -1) else None}
    return {'ap50_95': float(evaluator.stats[0]), 'ap50': float(evaluator.stats[1]),
            'ap75': float(evaluator.stats[2]), 'ar100': float(evaluator.stats[8]),
            'per_class': per}, dataset


def font(size, bold=False):
    path = Path('C:/Windows/Fonts') / ('segoeuib.ttf' if bold else 'segoeui.ttf')
    return ImageFont.truetype(str(path), size)


def centered(draw, xy, txt, f, fill=(20, 25, 35)):
    box = draw.textbbox((0, 0), txt, font=f)
    draw.text((xy[0]-(box[2]-box[0])/2, xy[1]-(box[3]-box[1])/2), txt, font=f, fill=fill)


def matrix_png(matrix, path, partial):
    canvas = Image.new('RGB', (1500, 1250), 'white')
    draw = ImageDraw.Draw(canvas)
    title = ('PARTIAL ' if partial else '') + 'FPGA validation confusion matrix'
    draw.text((50, 26), title, font=font(39, True), fill='black')
    draw.text((50, 84), 'Rows = ground truth; columns = predicted class. IoU >= 0.50; score >= 0.25.', font=font(24), fill='black')
    draw.text((50, 124), 'Class-agnostic geometric one-to-one matching; unmatched objects enter background.', font=font(24), fill='black')
    labels = ['biodeg.', 'cardboard', 'glass', 'metal', 'paper', 'plastic', 'background']
    x0, y0, cell = 245, 330, 145
    maxval = max(1, int(np.max(matrix)))
    for j, name in enumerate(labels):
        centered(draw, (x0+j*cell+cell/2, y0-48), name, font(23, True))
    for i, name in enumerate(labels):
        centered(draw, (125, y0+i*cell+cell/2), name, font(24, True))
        for j in range(7):
            value = int(matrix[i, j])
            strength = math.sqrt(value/maxval)
            fill = (int(247-190*strength), int(249-135*strength), int(253-70*strength))
            box = [x0+j*cell, y0+i*cell, x0+(j+1)*cell, y0+(i+1)*cell]
            draw.rectangle(box, fill=fill, outline=(210, 215, 222), width=2)
            centered(draw, (box[0]+cell/2, box[1]+cell/2), str(value), font(33, True), 'white' if strength > .65 else 'black')
    # Height is calculated from the actual grid, preventing a clipped background row.
    if y0+7*cell+40 > canvas.height:
        expanded = Image.new('RGB', (1500, y0+7*cell+55), 'white')
        expanded.paste(canvas, (0, 0))
        canvas = expanded
        draw = ImageDraw.Draw(canvas)
        # Redraw the clipped last row.
        i = 6
        centered(draw, (125, y0+i*cell+cell/2), labels[i], font(24, True))
        for j in range(7):
            value = int(matrix[i, j]); strength = math.sqrt(value/maxval)
            box = [x0+j*cell, y0+i*cell, x0+(j+1)*cell, y0+(i+1)*cell]
            draw.rectangle(box, fill=(int(247-190*strength), int(249-135*strength), int(253-70*strength)), outline=(210, 215, 222), width=2)
            centered(draw, (box[0]+cell/2, box[1]+cell/2), str(value), font(33, True), 'white' if strength > .65 else 'black')
    canvas.save(path)


def sample_png(row, item, outpath, partial):
    photo = Image.open(item['path']).convert('RGB')
    photo = photo.resize((720, 720))
    canvas = Image.new('RGB', (1600, 1260), 'white')
    canvas.paste(photo, (50, 170))
    canvas.paste(photo, (830, 170))
    draw = ImageDraw.Draw(canvas)
    draw.text((50, 24), ('PARTIAL ' if partial else '') + f"FPGA sample {row['index']:02d}  {item['target_class_name']}", font=font(40, True), fill='black')
    draw.text((50, 86), f"Ground truth: {len(row['gt'])} objects", font=font(30, True), fill=(0, 145, 60))
    draw.text((830, 86), f"FPGA: {len(row['detections'])} returned detections", font=font(30, True), fill=(190, 0, 130))
    sx, sy = 720 / item['width'], 720 / item['height']
    def drawbox(box, colour, left):
        x1, y1, x2, y2 = box
        coords = [left+x1*sx, 170+y1*sy, left+x2*sx, 170+y2*sy]
        draw.rectangle(coords, outline=colour, width=4)
    for a in row['gt']:
        drawbox(a['bbox_xyxy'], (0, 150, 70), 50)
    for a in row['detections']:
        drawbox(a['box'], (205, 0, 145), 830)
    draw.text((50, 922), 'Class counts (all original annotations retained)', font=font(29, True), fill='black')
    line = 970
    for cid, name in enumerate(NAMES):
        gt_n = sum(a['class_id'] == cid for a in row['gt'])
        selected = [a for a in row['detections'] if a['category'] == name]
        if not gt_n and not selected:
            continue
        draw.text((50, line), f"{name}: {gt_n}", font=font(27), fill=(0, 145, 60))
        scores = ', '.join(f"{a['score']:.3f}" for a in selected)
        if len(scores) > 40:
            scores = f"min {min(a['score'] for a in selected):.3f}, max {max(a['score'] for a in selected):.3f}"
        draw.text((830, line), f"{name}: {len(selected)}" + (f"  (score {scores})" if selected else ''), font=font(25), fill=(190, 0, 130))
        line += 35
    draw.text((50, 1195), f"Inference: {row['inference_seconds']:.3f} s. Fixed example selected before observing predictions.", font=font(25), fill='black')
    canvas.save(outpath)


def class_metrics_png(per_class, path, partial):
    canvas = Image.new('RGB', (1600, 1110), 'white')
    draw = ImageDraw.Draw(canvas)
    draw.text((50, 25), ('PARTIAL ' if partial else '') + 'FPGA per-class detection metrics', font=font(40, True), fill='black')
    colours = {'precision': (30, 102, 178), 'recall': (0, 145, 100), 'ap50': (190, 90, 5)}
    for k, (label, colour) in enumerate(colours.items()):
        xx = 390 + 320*k
        draw.rectangle((xx, 100, xx+35, 125), fill=colour)
        draw.text((xx+50, 95), label.upper() if label == 'ap50' else label.title(), font=font(27, True), fill='black')
    x0, y0, width, pitch = 390, 200, 960, 130
    for tick in range(0, 101, 25):
        xx = x0+width*tick/100
        draw.line((xx, y0-20, xx, y0+6*pitch-25), fill=(220, 225, 232), width=2)
        centered(draw, (xx, y0-45), f'{tick}%', font(24))
    for i, name in enumerate(NAMES):
        c = per_class[name]
        yy = y0+i*pitch
        draw.text((50, yy+12), name, font=font(29, True), fill='black')
        draw.text((50, yy+55), f"GT {c['gt']} | TP {c['tp']}", font=font(25), fill=(70, 75, 85))
        for j, (metric, colour) in enumerate(colours.items()):
            value = c[metric]
            if value is None:
                continue
            by = yy+j*29
            end = x0+width*value
            if value > 0:
                draw.rectangle((x0, by, end, by+20), fill=colour)
            draw.text((end+12, by-5), f'{100*value:.1f}%', font=font(23), fill=colour)
    draw.text((50, 1010), 'P/R: score >= 0.25, IoU >= 0.50. AP50: COCO evaluation of firmware-returned boxes.', font=font(25), fill='black')
    draw.text((50, 1050), 'Fixed 18-image upstream validation subset; unequal GT counts. Not full-dataset accuracy.', font=font(25), fill='black')
    canvas.save(path)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--allow-partial', action='store_true')
    args = p.parse_args()
    source = BASE/'dataset_board_results.json'
    manifest = BASE/'dataset/validation18_seed20261104.json'
    data = json.loads(source.read_text(encoding='utf-8-sig'))
    subset = json.loads(manifest.read_text(encoding='utf-8-sig'))
    if sha(manifest) != data['subset_sha256']:
        raise ValueError('Subset changed after board evaluation began')
    rows = data['runs']
    complete = data.get('completed') is True and not data.get('failed') and len(rows) == subset['count']
    if not complete and not args.allow_partial:
        raise RuntimeError(f"Evaluation incomplete ({len(rows)}/{subset['count']}); refusing final summary")
    if not rows:
        raise RuntimeError('No completed FPGA predictions')
    out = BASE/('dataset_metrics' if complete else 'dataset_metrics_partial')
    out.mkdir(exist_ok=True)
    byindex = {im['index']: im for im in subset['images']}
    seen = set()
    predictions = []
    object_counts = collections.Counter()
    for row in rows:
        item = byindex[row['index']]
        if row['index'] in seen:
            raise ValueError('Duplicate evaluated index')
        seen.add(row['index'])
        for key in ['image_id', 'width', 'height', 'file_name', 'gt']:
            if row[key] != item[key]:
                raise ValueError('Mismatch vs precommitted manifest: '+key)
        if row['image_sha256'] != item['sha256']:
            raise ValueError('Evaluated image differs from manifest')
        if row['detections'] != read_raw(BASE/f"dataset_{row['index']:02}.bin"):
            raise ValueError('JSON detections differ from raw FPGA response')
        for gt in row['gt']:
            if gt.get('iscrowd', 0):
                raise ValueError('Crowd GT requires separate operational matching policy')
            object_counts[gt['class_id']] += 1
        for det in row['detections']:
            if det['category'] not in NAMES:
                raise ValueError('Unknown returned class')
            x1, y1, x2, y2 = det['box']
            if not all(math.isfinite(x) for x in det['box']+[det['score']]):
                raise ValueError('Nonfinite prediction')
            if not (0 <= x1 <= x2 <= row['width'] and 0 <= y1 <= y2 <= row['height']):
                raise ValueError('Prediction is not clipped absolute original-image xyxy')
            predictions.append({'image_id': row['image_id'], 'category_id': NAMES.index(det['category']),
                                'bbox': [x1, y1, x2-x1, y2-y1], 'score': det['score']})
    log = io.StringIO()
    with contextlib.redirect_stdout(log):
        coco, coco_gt = coco_metrics(rows, predictions)
    (out/'coco_eval.txt').write_text(log.getvalue(), encoding='utf-8')
    # Class-aware score-descending greedy matching, exactly once per GT.
    counts = {c: dict(tp=0, fp=0, fn=0, gt=object_counts[c]) for c in range(6)}
    confusion = np.zeros((7, 7), dtype=int)
    per_image = []
    for row in rows:
        dets = [d for d in row['detections'] if d['score'] >= .25]
        gt = row['gt']
        matched = set()
        img_tp = 0
        for det in sorted(dets, key=lambda d: -d['score']):
            cid = NAMES.index(det['category'])
            candidates = [(iou(det['box'], a['bbox_xyxy']), j) for j, a in enumerate(gt)
                          if j not in matched and a['class_id'] == cid]
            overlap, j = max(candidates, default=(0., -1))
            if overlap >= .5:
                matched.add(j); counts[cid]['tp'] += 1; img_tp += 1
            else:
                counts[cid]['fp'] += 1
        for j, a in enumerate(gt):
            if j not in matched:
                counts[a['class_id']]['fn'] += 1
        # Geometric, class-agnostic matching for a diagnostic confusion matrix.
        pairs = sorted(((iou(a['bbox_xyxy'], det['box']), gi, di)
                         for gi, a in enumerate(gt) for di, det in enumerate(dets)), reverse=True)
        mg, md = set(), set()
        for overlap, gi, di in pairs:
            if overlap < .5:
                break
            if gi in mg or di in md:
                continue
            mg.add(gi); md.add(di)
            confusion[gt[gi]['class_id'], NAMES.index(dets[di]['category'])] += 1
        for gi, a in enumerate(gt):
            if gi not in mg:
                confusion[a['class_id'], 6] += 1
        for di, det in enumerate(dets):
            if di not in md:
                confusion[6, NAMES.index(det['category'])] += 1
        per_image.append({'index': row['index'], 'image_id': row['image_id'], 'gt': len(gt),
                          'detections': len(dets), 'tp': img_tp, 'fp': len(dets)-img_tp,
                          'fn': len(gt)-img_tp, 'inference_seconds': row['inference_seconds'],
                          'upload_seconds': row['upload_seconds']})
    per_class = {}
    for cid, name in enumerate(NAMES):
        c = counts[cid]
        precision = ratio(c['tp'], c['tp']+c['fp'])
        recall = ratio(c['tp'], c['tp']+c['fn'])
        per_class[name] = {**c, 'precision': precision, 'recall': recall,
                           'f1': ratio(2*precision*recall, precision+recall),
                           **coco['per_class'][name]}
    total = {k: sum(c[k] for c in counts.values()) for k in ['tp', 'fp', 'fn', 'gt']}
    prec = ratio(total['tp'], total['tp']+total['fp'])
    rec = ratio(total['tp'], total['tp']+total['fn'])
    scores = [row['inference_seconds'] for row in rows]
    summary = {'complete': complete, 'partial': not complete,
        'scope': 'Actual 27 MHz v3 FPGA inference on precommitted stratified upstream validation subset; no PC detections.',
        'images': len(rows), 'planned_images': subset['count'], 'gt_objects': sum(object_counts.values()),
        'returned_predictions': len(predictions),
        'model_sha256': data['model_sha256'], 'bitstream_sha256': data['bitstream_sha256'],
        'subset_sha256': sha(manifest), 'raw_results_sha256': sha(source),
        'coordinate_format': 'Original-image absolute pixels xyxy verified against board_loader.parse_detections, yolo_decode.c:127-130, metadata original width/height, and raw <5fI packets.',
        'operating_point': {'confidence_min': .25, 'nms_iou': .45, 'evaluation_iou': .5,
            'matching': 'Class-aware, score-descending, greedy one-to-one IoU >= 0.50.',
            'zero_denominator': 'Precision/recall/F1 = 0 when denominator is zero.'},
        'micro': {**total, 'precision': prec, 'recall': rec, 'f1': ratio(2*prec*rec, prec+rec)},
        'macro': {k: statistics.mean(c[k] for c in per_class.values()) for k in ['precision', 'recall', 'f1']},
        'coco': coco, 'per_class': per_class,
        'confusion_matrix': {'labels': NAMES+['background'], 'rows': 'ground truth',
            'columns': 'prediction', 'matrix': confusion.tolist(),
            'matching': 'Class-agnostic descending-IoU greedy one-to-one matching; unmatched GT -> background column, unmatched prediction -> background row. Off-diagonal class confusions may yield counts different from class-aware P/R matching.'},
        'latency': {'inference_mean_s': statistics.mean(scores), 'inference_min_s': min(scores),
             'inference_max_s': max(scores), 'inference_median_s': statistics.median(scores),
             'mean_image_upload_s': statistics.mean(row['upload_seconds'] for row in rows),
             'static_image_scope': 'Excludes camera capture and one-time model upload; inference_seconds includes command/reply and actual model forward, decode, display submission.'},
        'limitations': [
            '18-image stratified validation re-test, not the complete 1042-image held-out test or deployment-population accuracy.',
            'Checkpoint was tuned/evaluated on the same upstream validation split; train/validation duplication independence is unverified.',
            'Returned predictions are truncated at firmware confidence >=0.25, NMS IoU 0.45 and at most 32 returned boxes. Reported COCO AP describes this operating pipeline; it is not unrestricted low-confidence model AP.',
            'COCO AP averages IoU 0.50:0.05:0.95 and 101 recall points over six classes with GT. No confidence intervals are inferred from 18 images.',
            'Per-target-class image allocation is three, but all GT are retained: GT distribution is strongly imbalanced.',
            'Six material/object classes cover only kitchen and recyclable business bins; hazardous/other coverage is not established.'
        ]}
    (out/'metrics.json').write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding='utf-8')
    (out/'coco_ground_truth.json').write_text(json.dumps(coco_gt, indent=2), encoding='utf-8')
    (out/'coco_predictions.json').write_text(json.dumps(predictions, indent=2), encoding='utf-8')
    with (out/'per_class.csv').open('w', encoding='utf-8-sig', newline='') as f:
        w = csv.DictWriter(f, fieldnames=['class','gt','tp','fp','fn','precision','recall','f1','ap50','ap50_95'])
        w.writeheader()
        for name, c in per_class.items():
            w.writerow({'class': name, **c})
    with (out/'per_image.csv').open('w', encoding='utf-8-sig', newline='') as f:
        w = csv.DictWriter(f, fieldnames=list(per_image[0])); w.writeheader(); w.writerows(per_image)
    with (out/'confusion_matrix.csv').open('w', encoding='utf-8-sig', newline='') as f:
        w = csv.writer(f); w.writerow(['GT / prediction']+NAMES+['background'])
        for name, values in zip(NAMES+['background'], confusion.tolist()):
            w.writerow([name]+values)
    matrix_png(confusion, out/'confusion_matrix.png', not complete)
    class_metrics_png(per_class, out/'per_class_metrics.png', not complete)
    rows_by_index = {row['index']: row for row in rows}
    for index in [1, 7, 16]:
        if index in rows_by_index:
            sample_png(rows_by_index[index], byindex[index], out/f'sample_{index:02}.png', not complete)
    methods = f'''# FPGA 数据集实测定义与结果

状态：{'完整18图已结束' if complete else 'PARTIAL 部分结果 不可作最终数据'}。本轮已测 {len(rows)} 张，GT {sum(object_counts.values())} 个，返回框 {len(predictions)} 个。原始结果 SHA256 `{sha(source)}`，预先固定选样清单 SHA256 `{sha(manifest)}`。

预测全部来自当前27 MHz v3 FPGA串口原始响应，未使用PC模型预测替代。框格式通过协议及固件源码核实为原图绝对像素xyxy；COCO评估时转换为xywh。每帧JSON预测与保存的原始二进制 `<5fI` 回复逐项比对。

固定工作点为conf≥0.25，NMS IoU=0.45。P/R/F1采用同类别、按置信度降序、IoU≥0.5一对一匹配。微平均按所有对象汇总TP/FP/FN；宏平均为六类逐类指标算术平均，不可把对象微平均称为图片分类准确率。分母为0时该项记0。

COCO AP50及AP50:95由pycocotools官方COCOeval计算，IoU从0.50到0.95步进0.05、101个召回点、maxDets100；但固件只返回conf≥0.25且最多32框，低分候选已不可恢复，AP应写成“当前部署工作点输出的AP”，不能与上游低阈值完整模型AP直接等同。

混淆矩阵行是真值、列是预测，最后一行/列为background。矩阵先按几何IoU降序忽略类别进行一对一匹配，再统计预测标签，漏检进入background列，误检进入background行。它用于展示类间混淆；与分类别P/R的匹配顺序不同，可能产生不同配对，不能用非对角项直接重算前述P/R。

18张是上游validation的固定seed20261104分层小样本，每个目标类抽3图，但保留多类图全部GT使对象数不均衡：{dict((NAMES[k],v) for k,v in sorted(object_counts.items()))}。特别是厨余类对象占多数，应同时看宏/微平均，不把小样本结果外推为全数据集识别率。该validation也是原checkpoint的调参/评测来源，训练重叠未审计。

静态图推理平均 {statistics.mean(scores):.6f} s，不含约 {statistics.mean(row['upload_seconds'] for row in rows):.3f} s/图的串口输入传输，不含摄像头实际取图。不能当作实时摄像头整机刷新延迟。

图示样例固定为清单第1、7、16项，在查看预测质量前选定。绿色为GT，洋红为实际返回预测；稠密目标图中的漏检均保留。
'''
    (out/'评测定义与文档说明.md').write_text(methods, encoding='utf-8')
    print(json.dumps({'complete': complete,'images':len(rows),'micro':summary['micro'],'coco':coco,
                      'latency':summary['latency'],'out':str(out)}, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
