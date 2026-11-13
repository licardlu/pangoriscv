"""Run pinned upstream YOLOv5 v7 training without changing the active FPGA model.

Requires the official v7.0 source archive (commit recorded with each run).
The historical checkpoint's yolov5.models namespace is aliased to the matching
upstream model classes before unpickling. Only use trusted local checkpoints.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import sys
import time
import types
from functools import partial
import shutil


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--yolo', type=Path, required=True)
    ap.add_argument('--data', type=Path, required=True)
    ap.add_argument('--weights', type=Path, required=True)
    ap.add_argument('--project', type=Path, required=True)
    ap.add_argument('--name', required=True)
    ap.add_argument('--epochs', type=int, default=20)
    ap.add_argument('--freeze', type=int, default=0)
    ap.add_argument('--freeze-bn',action='store_true',
                    help='Keep frozen blocks in eval mode, including BatchNorm statistics')
    ap.add_argument('--batch', type=int, default=16)
    ap.add_argument('--threads', type=int, default=4)
    ap.add_argument('--lr0', type=float, default=.001)
    ap.add_argument('--evaluate', choices=['val', 'test'])
    ap.add_argument('--baseline-legacy', action='store_true', help='Map old six raw classes to the four bins for comparison')
    ap.add_argument('--deployment-decode', action='store_true',
                    help='Evaluate four classes with the same single-label/.45 NMS/max32 policy as five classes')
    ap.add_argument('--preserve-teacher',type=Path,
                    help='Training only: original4 teacher, constrained to correct labeled waste anchors')
    ap.add_argument('--expected-teacher-sha256')
    ap.add_argument('--preservation-strength',type=float,default=5.)
    ap.add_argument('--disjoint-hand-targets', action='store_true',
                    help='Training only: remove hand anchor assignments that conflict with true waste')
    a = ap.parse_args()
    if a.baseline_legacy and not a.evaluate:
        ap.error('--baseline-legacy is only valid with --evaluate')
    if a.disjoint_hand_targets and a.evaluate:
        ap.error('--disjoint-hand-targets changes training supervision only')
    if a.preserve_teacher and (a.evaluate or not a.expected_teacher_sha256 or a.preservation_strength<=0):
        ap.error('Teacher preservation is training-only and requires identity and positive strength')
    if a.preserve_teacher and hashlib.sha256(a.preserve_teacher.read_bytes()).hexdigest()!=a.expected_teacher_sha256:
        ap.error('Teacher checkpoint identity mismatch')
    a.yolo, a.data, a.weights, a.project = [p.resolve() for p in [a.yolo, a.data, a.weights, a.project]]
    out = a.project/a.name
    if out.exists():
        raise SystemExit('Run exists; use a fresh name')
    out.mkdir(parents=True)
    os.environ['YOLOV5_CONFIG_DIR'] = str(out/'config')
    os.environ['YOLOv5_AUTOINSTALL'] = 'false'
    os.environ['WANDB_MODE'] = 'disabled'
    os.environ['OMP_NUM_THREADS'] = str(a.threads)
    os.environ['MKL_NUM_THREADS'] = str(a.threads)
    os.environ['NUMEXPR_MAX_THREADS'] = str(a.threads)
    os.environ['MPLBACKEND'] = 'Agg'
    config_dir = out/'config'
    config_dir.mkdir()
    shutil.copyfile('C:/Windows/Fonts/arial.ttf', config_dir/'Arial.ttf')
    # Upstream v7 imports TensorBoard unconditionally. CSV is sufficient here;
    # disable that optional import explicitly, without fabricating a log writer.
    logger_file = a.yolo/'utils/loggers/__init__.py'
    logger_source = logger_file.read_text(encoding='utf-8')
    logger_source = logger_source.replace('from torch.utils.tensorboard import SummaryWriter',
                                        'SummaryWriter = None  # local CSV-only training')
    logger_file.write_text(logger_source, encoding='utf-8')
    sys.path.insert(0, str(a.yolo))
    import torch
    import cv2
    import yaml
    import torchvision
    import scipy
    from PIL import ImageFont
    if not hasattr(ImageFont.FreeTypeFont, 'getsize'):
        # v7 plotting compatibility with Pillow >=10; no training math changes.
        def getsize(font, text, *args, **kwargs):
            box = font.getbbox(text, *args, **kwargs)
            return box[2]-box[0], box[3]-box[1]
        ImageFont.FreeTypeFont.getsize = getsize
    import models.common
    import models.yolo
    import models.experimental
    torch.set_num_threads(a.threads)
    torch.set_num_interop_threads(1)
    cv2.setNumThreads(0)
    package = types.ModuleType('yolov5')
    package.models = types.ModuleType('yolov5.models')
    sys.modules['yolov5'] = package
    sys.modules['yolov5.models'] = package.models
    for n in ['common', 'yolo', 'experimental']:
        sys.modules['yolov5.models.'+n] = sys.modules['models.'+n]
    provenance = {k:str(v) if isinstance(v, Path) else v for k,v in vars(a).items()}
    provenance.update(torch=torch.__version__, torchvision=torchvision.__version__,
                      cpu_threads=torch.get_num_threads(),
                      weights_sha256=hashlib.sha256(a.weights.read_bytes()).hexdigest(),
                      data_sha256=hashlib.sha256(a.data.read_bytes()).hexdigest(),
                      upstream_commit='915bbf294bb74c859f0b41f1c23bc395014ea679',
                      logger_patch_sha256=hashlib.sha256(logger_file.read_bytes()).hexdigest(),
                      logging='local CSV only; optional TensorBoard and remote loggers disabled',
                      started_unix=time.time(), status='running')
    (out/'provenance.json').write_text(json.dumps(provenance,indent=2))
    if a.evaluate:
        import val
        from utils.callbacks import Callbacks
        from utils.dataloaders import create_dataloader
        from utils.general import check_dataset
        import numpy as np
        from PIL import Image
        data = check_dataset(str(a.data))
        nc = data['nc']
        deployment_decode = nc == 5 or a.deployment_decode
        class_names = ['kitchen','recyclable','hazardous','other'] + (['hand'] if nc==5 else [])
        if nc not in (4,5) or list(data['names'].values()) != class_names:
            raise ValueError('Unexpected four-bin/internal-hand dataset taxonomy')
        if a.baseline_legacy and nc != 4:
            raise ValueError('Legacy comparison requires the four-bin dataset')
        checkpoint = torch.load(a.weights, map_location='cpu')
        base_model = (checkpoint.get('ema') or checkpoint['model']).float().eval()
        expected_nc = 6 if a.baseline_legacy else nc
        if base_model.model[-1].nc != expected_nc:
            raise ValueError(f'Expected {expected_nc} raw classes for this evaluation mode')
        class BinModel(torch.nn.Module):
            def __init__(self, net, legacy):
                super().__init__()
                self.net = net
                self.names = dict(enumerate(class_names))
                self.legacy = legacy
            def forward(self, x, augment=False):
                p = self.net(x, augment=augment)[0]
                if not self.legacy:
                    # Match the board decoder: one class per anchor. Upstream
                    # val NMS enables multi_label, so suppress other classes.
                    if deployment_decode:
                        q = p.clone()
                        q[...,5:] = 0
                        c = p[...,5:].argmax(-1,keepdim=True)
                        q[...,5:].scatter_(-1,c,p[...,5:].gather(-1,c))
                        return q
                    return p
                q = p.new_zeros((*p.shape[:-1], 9))
                q[..., :5] = p[..., :5]
                q[..., 5] = p[..., 5]
                q[..., 6] = p[..., 6:11].amax(-1)
                return q
        model = BinModel(base_model, a.baseline_legacy)
        loader = create_dataloader(data[a.evaluate], 320, a.batch, 32,
                                   single_cls=False, pad=0., rect=False, workers=0)[0]
        callbacks = Callbacks()
        detail = {}
        def per_class(nt, tp, fp, p, r, f1, ap, ap50, ap_class, confusion_matrix):
            detail['per_class'] = {data['names'][int(c)]: {'targets':int(nt[int(c)]), 'AP50':float(ap50[i]),
                                   'AP50_95':float(ap[i].mean())} for i,c in enumerate(ap_class)}
            detail['confusion_matrix_conf025_iou045'] = confusion_matrix.matrix.tolist()
        callbacks.register_action('on_val_end', callback=per_class)
        manifest = json.loads((a.data.parent/'manifest.json').read_text(encoding='utf8'))
        ground_truth = {Path(r['prepared_image']).stem:r for r in manifest if r['split']==a.evaluate}
        fixed_tp, fixed_fp, fixed_gt = np.zeros(nc), np.zeros(nc), np.zeros(nc)
        by_source = {}
        for r in ground_truth.values():
            for b in r['boxes']:
                fixed_gt[int(b[0])] += 1
        image_decisions = {}
        def image_end(pred, predn, path, names, im):
            r = ground_truth[Path(path).stem]
            picked = predn[predn[:,4]>=.25].detach().cpu()
            image_decisions[Path(path).stem] = {'source':r['source'], 'bins_present':sorted({int(b[0]) for b in r['boxes']}),
                                               'primary_bin':int(r['primary_bin']),
                                               'top_bin':int(picked[picked[:,4].argmax(),5]) if len(picked) else None}
            with Image.open(path) as image:
                w,h = image.size
            if nc == 5:
                image_decisions[Path(path).stem].update(width=w,height=h,
                    detections=picked.tolist(),path=str(path))
            gt = torch.tensor([[b[0],(b[1]-b[3]/2)*w,(b[2]-b[4]/2)*h,(b[1]+b[3]/2)*w,(b[2]+b[4]/2)*h] for b in r['boxes']])
            correct = val.process_batch(picked, gt, torch.tensor([.5])).numpy()[:,0] if len(picked) else np.zeros(0,dtype=bool)
            for i,p in enumerate(picked):
                cls = int(p[5])
                fixed_tp[cls] += bool(correct[i])
                fixed_fp[cls] += not bool(correct[i])
        callbacks.register_action('on_val_image_end', callback=image_end)
        (out/'labels').mkdir()
        result = val.run(data=data, model=model, dataloader=loader, batch_size=a.batch,
                         imgsz=320, device='cpu', task=a.evaluate, workers=0,
                         iou_thres=.45 if deployment_decode else .6,max_det=32 if deployment_decode else 300,
                         save_dir=out, save_json=False, save_txt=True, save_conf=True,
                         verbose=True, plots=True, half=False, callbacks=callbacks)
        metrics = {'precision':float(result[0][0]), 'recall':float(result[0][1]),
                   'mAP50':float(result[0][2]), 'mAP50_95':float(result[0][3]),
                   'per_class_AP50_95':result[1].tolist(), 'timing_ms':list(result[2]),
                   'input': 'fixed square 320x320, no rectangular padding',
                   'summary_PR_note':'Upstream P/R use maximum mean F1 on this split; fixed-threshold P/R are below.',
                   **detail}
        metrics['fixed_conf025_iou050'] = {data['names'][c]: {'TP':int(fixed_tp[c]), 'FP':int(fixed_fp[c]), 'GT':int(fixed_gt[c]),
                                               'precision':float(fixed_tp[c]/max(1,fixed_tp[c]+fixed_fp[c])),
                                               'recall':float(fixed_tp[c]/max(1,fixed_gt[c]))} for c in range(nc)}
        if deployment_decode:
            metrics['deployment_decode_policy']='single-label per anchor, conf .25 for decisions, NMS IoU .45, max 32'
            metrics['waste_only_mean_AP50']=float(np.mean([detail['per_class'][n]['AP50'] for n in class_names[:4]]))
        for stem,r in ground_truth.items():
            d = image_decisions.get(stem, {'top_bin':None,'bins_present':sorted({int(b[0]) for b in r['boxes']})})
            source = by_source.setdefault(r['source'], {'images':0,'no_detection':0,'correct_top_bin':0,'wrong_top_bin':0})
            source['images'] += 1
            source['no_detection'] += d['top_bin'] is None
            source['correct_top_bin'] += d['top_bin'] in d['bins_present']
            source['wrong_top_bin'] += d['top_bin'] is not None and d['top_bin'] not in d['bins_present']
        metrics['image_top_bin_conf025'] = by_source
        image_matrix = np.zeros((nc,nc+1),dtype=int)  # includes internal hand class when present
        source_matrices = {}
        for stem,r in ground_truth.items():
            d = image_decisions.get(stem, {'top_bin':None})
            primary = int(r['primary_bin'])
            predicted = nc if d['top_bin'] is None else int(d['top_bin'])
            image_matrix[primary,predicted] += 1
            sm = source_matrices.setdefault(r['source'],np.zeros((nc,nc+1),dtype=int))
            sm[primary,predicted] += 1
        metrics['image_primary_bin_conf025'] = {
            'row_bins':class_names,
            'columns':class_names+['no_detection'],
            'matrix':image_matrix.tolist(),
            'source_matrices':{k:v.tolist() for k,v in source_matrices.items()},
            'images':int(image_matrix.sum()),
            'coverage':float(image_matrix[:,:nc].sum()/max(1,image_matrix.sum())),
            'primary_bin_accuracy_including_missed':float(sum(image_matrix[i,i] for i in range(nc))/max(1,image_matrix.sum())),
            'primary_bin_accuracy_when_detected':float(sum(image_matrix[i,i] for i in range(nc))/max(1,image_matrix[:,:nc].sum())),
            'primary_bin_note':'One image prediction (highest-confidence box) is compared with its most frequent ground-truth bin; this complements object-level AP and is not a physical-item benchmark.'}
        (out/'image_decisions.json').write_text(json.dumps(image_decisions,indent=2))
        (out/'metrics.json').write_text(json.dumps(metrics,indent=2))
    else:
        if a.freeze_bn:
            if a.freeze<=0:
                raise ValueError('freeze-bn requires freeze > 0')
            train_file=a.yolo/'train.py'
            source=train_file.read_text(encoding='utf8')
            marker='        # LOCAL_FREEZE_BN: preserve frozen feature statistics\n'
            if marker not in source:
                needle='        model.train()\n'
                if source.count(needle)!=1:
                    raise ValueError('Unexpected upstream model.train location')
                source=source.replace(needle,needle+marker+
                    "        if getattr(opt, 'freeze_bn', False):\n"
                    '            for frozen_block in model.model[:opt.freeze[0]]:\n'
                    '                frozen_block.eval()\n')
                train_file.write_text(source,encoding='utf8')
            provenance['training_patch_sha256']=hashlib.sha256(train_file.read_bytes()).hexdigest()
            provenance['freeze_bn_note']='Local explicit opt-in eval() on frozen blocks after each model.train(); prevents BatchNorm running-stat drift'
            (out/'provenance.json').write_text(json.dumps(provenance,indent=2))
        # Patch before import: rewriting train.py after import leaves its
        # already-compiled train() function executing the previous source.
        if a.preserve_teacher:
            train_file=a.yolo/'train.py'
            source=train_file.read_text(encoding='utf8')
            marker='                # LOCAL_PRESERVATION: training images only; ordinary validation loss\n'
            if marker not in source:
                needle='                loss, loss_items = compute_loss(pred, targets.to(device))  # loss scaled by batch_size\n'
                if source.count(needle)!=1:
                    raise ValueError('Unexpected upstream training loss location')
                source=source.replace(needle,marker+
                    "                if getattr(opt, 'preserve_teacher', False):\n"
                    '                    loss, loss_items = compute_loss(pred, targets.to(device), images=imgs)\n'
                    '                else:\n'+needle.replace('                loss','                    loss'))
                train_file.write_text(source,encoding='utf8')
        import train
        train.Loggers = partial(train.Loggers, include=('csv',))
        preservation_losses=[]
        disjoint_losses=[]
        if a.disjoint_hand_targets:
            from disjoint_hand_loss import disjoint_loss_class
            train.ComputeLoss = disjoint_loss_class(train.ComputeLoss, disjoint_losses)
            provenance['disjoint_hand_loss_sha256'] = hashlib.sha256(
                (Path(__file__).parent/'disjoint_hand_loss.py').read_bytes()).hexdigest()
            (out/'provenance.json').write_text(json.dumps(provenance,indent=2))
        if a.preserve_teacher:
            from teacher_preservation import PreservationLoss
            teacher_cp=torch.load(a.preserve_teacher,map_location='cpu')
            teacher=(teacher_cp.get('ema') or teacher_cp['model']).float().eval()
            if [teacher.names[i] for i in range(teacher.model[-1].nc)]!=['kitchen','recyclable','hazardous','other']:
                raise ValueError('Expected original four-bin teacher')
            original_loss_class=train.ComputeLoss
            def make_preserved_loss(model,*args,**kwargs):
                loss=PreservationLoss(original_loss_class(model,*args,**kwargs),model,
                                      teacher.to(next(model.parameters()).device),a.preservation_strength)
                preservation_losses.append(loss)
                return loss
            train.ComputeLoss=make_preserved_loss
            provenance.update(training_patch_sha256=hashlib.sha256(train_file.read_bytes()).hexdigest(),
                              preservation_script_sha256=hashlib.sha256((Path(__file__).parent/'teacher_preservation.py').read_bytes()).hexdigest(),
                              teacher_sha256=a.expected_teacher_sha256,
                              preservation_scope='Only teacher-correct actual waste GT anchors: IoU>=.5/conf>=.25; no pseudo labels, no validation teacher; equal present-class weighting')
            (out/'provenance.json').write_text(json.dumps(provenance,indent=2))
        from utils.callbacks import Callbacks
        # Avoid the upstream network git/version probe and automatic pip changes.
        # Actual dependencies are imported above, and their versions are recorded.
        train.check_git_status = lambda *args, **kwargs: None
        train.check_requirements = lambda *args, **kwargs: None
        hyp = yaml.safe_load((a.yolo/'data/hyps/hyp.scratch-low.yaml').read_text())
        hyp.update(lr0=a.lr0, lrf=.1, warmup_epochs=1., warmup_bias_lr=.01,
                   degrees=8., translate=.1, scale=.35, mosaic=.5,
                   mixup=0., hsv_h=.015, hsv_s=.4, hsv_v=.3)
        hp = out/'training_hyp.yaml'
        hp.write_text(yaml.safe_dump(hyp))
        callbacks = Callbacks()
        def progress(log_vals, epoch, best_fitness, fi):
            status = {'epoch':int(epoch)+1, 'epochs':a.epochs, 'elapsed_s':time.time()-provenance['started_unix'],
                      'precision':float(log_vals[3]), 'recall':float(log_vals[4]),
                      'mAP50':float(log_vals[5]), 'mAP50_95':float(log_vals[6]),
                      'best_fitness':float(best_fitness), 'fitness':float(fi)}
            if preservation_losses:
                if len(preservation_losses)!=1:raise ValueError('Unexpected loss instances')
                status['teacher_preservation']=preservation_losses[0].take_stats()
                if status['teacher_preservation']['batches']==0:
                    raise ValueError('Teacher preservation enabled but no training batches used it')
                with (out/'preservation_epochs.jsonl').open('a',encoding='utf8') as handle:
                    handle.write(json.dumps(dict(epoch=int(epoch)+1,**status['teacher_preservation']))+'\n')
            if disjoint_losses:
                if len(disjoint_losses)!=1:raise ValueError('Unexpected disjoint loss instances')
                status['disjoint_hand_targets'] = disjoint_losses[0].take_assignment_stats()
                if status['disjoint_hand_targets'].get('training_batches_with_hand', 0)==0:
                    raise ValueError('Disjoint hand targets enabled but never used in training')
            (out/'progress.json').write_text(json.dumps(status,indent=2))
            print('EPOCH_RESULT '+json.dumps(status),flush=True)
        callbacks.register_action('on_fit_epoch_end', callback=progress)
        opt = train.parse_opt(known=True)
        settings = dict(data=str(a.data), weights=str(a.weights), imgsz=320,
                        epochs=a.epochs, batch_size=a.batch, device='cpu', workers=0,
                        project=str(a.project), name=a.name, exist_ok=True,
                        hyp=str(hp), optimizer='AdamW', freeze=[a.freeze],freeze_bn=a.freeze_bn,
                        preserve_teacher=bool(a.preserve_teacher),
                        noautoanchor=bool(a.preserve_teacher),
                        patience=8, save_period=5, cache='ram', seed=20261111,
                        noplots=False, cos_lr=True)
        for k, v in settings.items():
            setattr(opt, k, v)
        try:
            train.main(opt, callbacks=callbacks)
        except BaseException as e:
            provenance.update(status='failed', reason=repr(e), finished_unix=time.time())
            (out/'provenance.json').write_text(json.dumps(provenance,indent=2))
            raise
    provenance.update(status='completed', finished_unix=time.time())
    (out/'provenance.json').write_text(json.dumps(provenance,indent=2))


if __name__ == '__main__':
    main()
