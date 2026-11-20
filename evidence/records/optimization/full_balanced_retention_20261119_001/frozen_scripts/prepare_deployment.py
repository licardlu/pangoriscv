"""Calibrate the selected four-bin checkpoint against the existing FPGA graph.

The template is accepted only after every convolution and head is compared
with the actual checkpoint forward pass. Calibration uses training images only.
"""
import argparse
from copy import deepcopy
import hashlib
import json
import os
from pathlib import Path
import sys
from calibration_identity import frozen_calibration, ordered_identity

ROOT = Path(__file__).resolve().parents[4]
PROJECT = ROOT / 'project/trash_sorting'


def save(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2)+'\n', encoding='utf8')


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--out', type=Path, required=True)
    p.add_argument('--yolo', type=Path, required=True)
    p.add_argument('--data', type=Path, required=True)
    p.add_argument('--per-class', type=int, default=32)
    p.add_argument('--calibration-from', type=Path,
                   help='Replay ordered calibration_images from a frozen provenance JSON; every image must remain in --data train')
    p.add_argument('--expected-calibration-sha256',
                   help='Required SHA256 identity of --calibration-from')
    p.add_argument('--frozen-calibration-only', action='store_true',
                   help='Verify/open only the exact predeclared calibration paths, retaining full split-hash exclusion; avoid reading thousands of unused replay aliases')
    p.add_argument('--checkpoint', type=Path,
                   default=PROJECT/'training/candidates/four_bins_20261111/four_bins_yolov5n_320.pt')
    p.add_argument('--expected-checkpoint-sha256', default=None)
    p.add_argument('--include-hand', action='store_true', help='Internal class 4 locates hands; four waste bins remain unchanged')
    p.add_argument('--include-all-personal-train-calibration', action='store_true',
                   help='Calibration A/B only: add every unique reviewed personal TRAIN image, never val/test')
    a = p.parse_args()
    if a.frozen_calibration_only and not a.calibration_from:
        p.error('--frozen-calibration-only requires an identity-pinned --calibration-from')
    if a.calibration_from:
        if a.include_all_personal_train_calibration:
            p.error('Frozen calibration cannot add personal images')
        if not a.expected_calibration_sha256 or hashlib.sha256(a.calibration_from.read_bytes()).hexdigest()!=a.expected_calibration_sha256:
            p.error('Frozen calibration provenance SHA256 is missing or differs')
    elif a.expected_calibration_sha256:
        p.error('--expected-calibration-sha256 requires --calibration-from')
    if a.per_class<=0:p.error('--per-class must be positive')
    out = a.out.resolve()
    out.mkdir(parents=True, exist_ok=False)
    config = out / 'config'
    config.mkdir()
    os.environ['YOLOV5_CONFIG_DIR'] = str(config)
    os.environ['YOLOv5_AUTOINSTALL'] = 'false'
    os.environ['WANDB_MODE'] = 'disabled'
    sys.path.insert(0, str(a.yolo.resolve()))
    sys.path.insert(0, str(ROOT/'extensions/yolo/scripts'))
    import torch
    from deployment_bundle import calibrate, float_graph
    from test_graph_torch import submodule
    from pack_deployment import pack
    torch.set_num_threads(4)
    torch.set_num_interop_threads(1)
    checkpoint = a.checkpoint.resolve()
    cp_sha = hashlib.sha256(checkpoint.read_bytes()).hexdigest()
    expected_sha = a.expected_checkpoint_sha256
    if expected_sha is None:
        if checkpoint != (PROJECT/'training/candidates/four_bins_20261111/four_bins_yolov5n_320.pt').resolve():
            raise ValueError('Non-default checkpoint requires --expected-checkpoint-sha256')
        expected_sha = '8014832f2bc87081c9a7adad363d5590c13ffc6b4c8ff6700f289553b1f575e0'
    if cp_sha != expected_sha:
        raise ValueError('Selected checkpoint identity changed')
    model = torch.load(checkpoint, map_location='cpu')['model'].float().eval()
    detect = model.model[-1]
    names = [model.names[i] for i in range(detect.nc)]
    classes = ['kitchen','recyclable','hazardous','other'] + (['hand'] if a.include_hand else [])
    nc = len(classes)
    head_channels = 3*(5+nc)
    if detect.nc != nc or names != classes:
        raise ValueError('Four-bin class order mismatch')
    template = PROJECT/'source/yolo/model/graph.json'
    graph = deepcopy(json.loads(template.read_text(encoding='utf8')))
    for idx in graph['outputs']:
        op = graph['ops'][idx]
        op['cout'] = head_channels
        op['out_shape'][0] = head_channels
    expected = {}
    handles = []
    for op in graph['ops']:
        if op['name'] == 'CONV':
            module = submodule(model, op['module'])
            if module.in_channels != op['cin'] or module.out_channels != op['cout']:
                raise ValueError('Channel mismatch: '+op['module'])
            wrapper = submodule(model, op['module'][:-5]) if op['module'].endswith('.conv') else module
            def hook(_m, _i, value, idx=op['idx']):
                expected[idx] = value.detach().clone()
            handles.append(wrapper.register_forward_hook(hook))
    torch.manual_seed(20261112)
    with torch.no_grad():
        image = torch.rand(1,3,320,320)
        model(image)
        for handle in handles:
            handle.remove()
        values = float_graph(model, graph, image)
        for op, value in zip(graph['ops'], values):
            if list(value.shape) != [1,*op['out_shape']]:
                raise ValueError('Geometry mismatch: '+op['module'])
            if op['idx'] in expected and not torch.equal(value, expected[op['idx']]):
                raise ValueError('Arithmetic mismatch: '+op['module'])
    graph.update(classes=classes,
                 anchors=(detect.anchors*detect.stride[:,None,None]).tolist(),
                 strides=detect.stride.tolist(), checkpoint_sha256=cp_sha)
    save(out/'graph.json',graph)
    print('CHECKPOINT_GRAPH_EXACT_PASS ops='+str(len(values)),flush=True)
    # Sample each major class from the actual training split, deterministically.
    groups = [[] for _ in range(nc)]
    training_manifest = a.data/'manifest.json'
    training_rows = json.loads(training_manifest.read_text(encoding='utf8'))
    train_hashes={r['image_sha256'] for r in training_rows if r['split']=='train'}
    if train_hashes.intersection(r['image_sha256'] for r in training_rows if r['split']!='train'):
        raise ValueError('Training/held-out image SHA overlap in calibration manifest')
    calibration_rows = training_rows
    if a.frozen_calibration_only:
        reference = json.loads(a.calibration_from.read_text(encoding='utf8'))
        declared = {r['path'] for r in reference['calibration_images']}
        # Exact raw-path membership is deliberate: fail rather than silently
        # broaden through aliases, symlinks or a changed calibration identity.
        calibration_rows = [r for r in training_rows if r['split']=='train' and r['prepared_image'] in declared]
        if {r['prepared_image'] for r in calibration_rows} != declared:
            raise ValueError('Frozen calibration raw paths are absent from the recorded train manifest')
    training_by_path = {str(Path(r['prepared_image']).resolve()): r
                        for r in calibration_rows if r['split'] == 'train'}
    training_by_stem = {}
    for image_path in training_by_path:
        stem = Path(image_path).stem
        if stem in training_by_stem:
            raise ValueError('Ambiguous training image stem: '+stem)
        training_by_stem[stem] = Path(image_path)
    image_metadata = {}
    seen_images = {}
    # Continuation snapshots reference the original files in place, so scanning
    # only the snapshot label directory would silently omit the 3759 base train.
    for image_path, row in sorted(training_by_path.items()):
        rows = row['boxes']
        if not rows:
            continue
        category = int(max(rows,key=lambda r:float(r[3])*float(r[4]))[0])
        if category < 0 or category >= nc:
            raise ValueError('Unexpected calibration label class')
        image = Path(image_path)
        if image is None:
            raise ValueError('Calibration label has no recorded train image: '+str(image_path))
        if not image.is_file():
            raise ValueError('Missing training image: '+str(image))
        image = image.resolve()
        row = training_by_path.get(str(image))
        if row is None:
            raise ValueError('Calibration image is absent from recorded train split: '+str(image))
        digest = hashlib.sha256(image.read_bytes()).hexdigest()
        if row.get('image_sha256',row.get('sha256')) != digest:
            raise ValueError('Calibration image identity changed')
        label=Path(str(image).replace('/images/','/labels/').replace('\\images\\','\\labels\\')).with_suffix('.txt')
        label_digest=hashlib.sha256(label.read_bytes()).hexdigest()
        if label_digest!=row['label_sha256']:
            raise ValueError('Calibration training label identity changed')
        if digest in seen_images:
            if seen_images[digest] != category:
                raise ValueError('Duplicate calibration image has conflicting class labels')
            continue
        seen_images[digest] = category
        image_metadata[str(image)] = dict(path=str(image), sha256=digest,
                                         label_sha256=label_digest,
                                         source=row['source'], group=row.get('group',row.get('capture_group')),
                                         primary_calibration_class=category)
        groups[category].append(image.resolve())
    paths = []
    if a.calibration_from:
        paths=frozen_calibration(json.loads(a.calibration_from.read_text(encoding='utf8')),image_metadata,classes)
    else:
        for category, candidates in enumerate(groups):
            if len(candidates)<a.per_class:
                raise ValueError('Insufficient calibration class '+str(category))
            # Spread through sorted names, rather than taking adjacent frames.
            paths.extend(candidates[i*len(candidates)//a.per_class] for i in range(a.per_class))
    paths = list(dict.fromkeys(paths))
    if a.include_all_personal_train_calibration:
        # All entries below already passed manifest train-membership, byte
        # identity and duplicate checks above. No directory glob outside train.
        paths = list(dict.fromkeys(paths + [Path(p) for p, meta in image_metadata.items()
                                            if meta['source'] == 'personal_handheld']))
    provenance = dict(checkpoint=str(checkpoint), checkpoint_sha256=cp_sha, template_sha256=hashlib.sha256(template.read_bytes()).hexdigest(),
                      graph_check='All convolution/head outputs bit-exact to actual checkpoint on fixed random input',
                      calibration_split='recorded train only; no val/test',
                      include_all_personal_train_calibration=a.include_all_personal_train_calibration,
                      frozen_calibration_paths_only=a.frozen_calibration_only,
                      calibration_manifest_sha256=hashlib.sha256(training_manifest.read_bytes()).hexdigest(),
                      calibration_reference=str(a.calibration_from.resolve()) if a.calibration_from else None,
                      calibration_reference_sha256=a.expected_calibration_sha256,
                      ordered_calibration_identity_sha256=ordered_identity(paths,image_metadata),
                      calibration_images=[image_metadata[str(p)] for p in paths],
                      personal_training_calibration_images=sum(image_metadata[str(p)]['source'] == 'personal_handheld' for p in paths),
                      repeated_pixel_files_deduplicated=True,
                      torch=torch.__version__, classes=graph['classes'], anchors=graph['anchors'],strides=graph['strides'])
    save(out/'provenance.json',provenance)
    with torch.no_grad():
        bundle = calibrate(out/'bundle',len(paths),graph=graph,checkpoint=checkpoint,paths=paths)
    packed = pack(out/'bundle',out/'packed')
    packed.update(classes=classes,raw_model_classes=nc,anchors=graph['anchors'],strides=graph['strides'],
                  checkpoint_sha256=cp_sha,hand_locator_class=4 if a.include_hand else None)
    save(out/'packed/memory_map.json',packed)
    if any(packed['tensors'][i]['c']!=head_channels or packed['tensors'][i]['padded_c']!=32 for i in packed['outputs']):
        raise ValueError('Invalid deployed detection head allocation')
    print('FOUR_BIN_MODEL_PACKED '+packed['blob_sha256'],flush=True)


if __name__ == '__main__':
    main()
