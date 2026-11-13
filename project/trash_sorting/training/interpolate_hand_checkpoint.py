"""Interpolate shared four-bin weights while retaining the joint hand row.

Offline validation experiment, identical inference graph. Never edits either
input checkpoint or active FPGA files. No validation/test pictures are inputs.
"""
import argparse
import copy
import hashlib
import json
import os
from pathlib import Path
import sys
import types


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def blend_tensor(original, adapted, fraction):
    if original.shape != adapted.shape:
        raise ValueError('Tensor shape mismatch')
    if not adapted.is_floating_point():
        return (original if fraction == 0 else adapted).clone()
    return original.float().lerp(adapted.float(), fraction).to(adapted.dtype)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--base', type=Path, required=True)
    p.add_argument('--expected-base-sha256', required=True)
    p.add_argument('--joint', type=Path, required=True)
    p.add_argument('--expected-joint-sha256', required=True)
    p.add_argument('--fraction', type=float, required=True,
                   help='0=original shared weights, 1=adapted shared weights; hand class row always adapted')
    p.add_argument('--bn-statistics-only',action='store_true',
                   help='Blend only running_mean/var, keep every learned tensor exactly adapted')
    p.add_argument('--yolo', type=Path, required=True)
    p.add_argument('--out', type=Path, required=True)
    a = p.parse_args()
    if not 0 <= a.fraction <= 1:
        raise ValueError('Fraction must be in [0,1]')
    if sha(a.base) != a.expected_base_sha256 or sha(a.joint) != a.expected_joint_sha256:
        raise ValueError('Checkpoint identity mismatch')
    a.out.mkdir(parents=True, exist_ok=False)
    os.environ['YOLOV5_CONFIG_DIR'] = str((a.out/'config').resolve())
    os.environ['YOLOv5_AUTOINSTALL'] = 'false'
    sys.path.insert(0, str(a.yolo.resolve()))
    import torch
    import models.common, models.yolo, models.experimental
    package = types.ModuleType('yolov5')
    package.models = types.ModuleType('yolov5.models')
    sys.modules['yolov5'] = package; sys.modules['yolov5.models'] = package.models
    for name in ['common','yolo','experimental']:
        sys.modules['yolov5.models.'+name] = sys.modules['models.'+name]
    torch.set_num_threads(4)
    def load(path):
        cp = torch.load(path, map_location='cpu')
        return (cp.get('ema') or cp['model']).float().eval()
    base, joint = load(a.base), load(a.joint)
    if base.model[-1].nc != 4 or joint.model[-1].nc != 5:
        raise ValueError('Expected original4 and joint5 checkpoints')
    def names(m): return [m.names[i] for i in range(m.model[-1].nc)]
    if names(base) != ['kitchen','recyclable','hazardous','other'] or names(joint) != names(base)+['hand']:
        raise ValueError('Taxonomy mismatch')
    if len(base.model) != 25 or len(joint.model) != 25:
        raise ValueError('Unexpected graph')
    result = copy.deepcopy(joint)
    original, adapted, target = base.state_dict(), joint.state_dict(), result.state_dict()
    head_keys = {f'model.24.m.{i}.{field}' for i in range(3) for field in ('weight','bias')}
    checked = 0
    with torch.no_grad():
        for key, value in adapted.items():
            if key not in original:
                raise ValueError('Joint-only state key: '+key)
            if a.bn_statistics_only and not key.endswith(('.running_mean','.running_var')):
                assert torch.equal(target[key],value)
                checked += 1
                continue
            if key in head_keys:
                if value.shape[0] != 30 or original[key].shape[0] != 27:
                    raise ValueError('Unexpected head width')
                for anchor in range(3):
                    old = original[key][anchor*9:anchor*9+9]
                    new = value[anchor*10:anchor*10+9]
                    target[key][anchor*10:anchor*10+9].copy_(blend_tensor(old,new,a.fraction))
                    # The tenth row is learned hand class, not another bin.
                    assert torch.equal(target[key][anchor*10+9],value[anchor*10+9])
            else:
                if key.endswith('anchors') and not torch.equal(original[key], value):
                    raise ValueError('Anchor geometry differs')
                target[key].copy_(blend_tensor(original[key],value,a.fraction))
            checked += 1
        torch.manual_seed(20261112)
        image = torch.rand(1,3,320,320)
        pred = result(image)[0]
        if not torch.isfinite(pred).all() or list(pred.shape) != [1,6300,10]:
            raise ValueError('Invalid model output')
        endpoint_error = None
        if a.fraction == 0 and not a.bn_statistics_only:
            ref = base(image)[0]
            endpoint_error = float((pred[:,:,:9]-ref).abs().max())
            torch.testing.assert_close(pred[:,:,:9],ref,atol=1e-3,rtol=2e-5)
        elif a.fraction == 1:
            ref = joint(image)[0]
            torch.testing.assert_close(pred,ref,atol=0,rtol=0)
            endpoint_error = 0.
    checkpoint = a.out/'interpolated.pt'
    torch.save(dict(model=result.half(), ema=None, epoch=-1, optimizer=None, best_fitness=0), checkpoint)
    report = dict(status='OFFLINE_PARAMETER_INTERPOLATION_ONLY', fraction=a.fraction,
                  bn_statistics_only=a.bn_statistics_only,
                  base_sha256=sha(a.base), joint_sha256=sha(a.joint), checkpoint_sha256=sha(checkpoint),
                  common_state_tensors_checked=checked, hand_class_rows_retained_exact=True,
                  endpoint_fp32_output_max_error=endpoint_error,
                  training_performed=False, inference_graph_unchanged=True, extra_inference_macs=0,
                  images_used='fixed random tensor only; no photos for parameter construction',
                  script_sha256=sha(Path(__file__)), pds_started=False, board_programmed=False,
                  limitations=['Parameter interpolation is a validation experiment, not proof of retained accuracy',
                               'Hand class scores can compete with waste classes even when common logits restored'])
    (a.out/'provenance.json').write_text(json.dumps(report,indent=2),encoding='utf8')
    print(json.dumps(report))


if __name__ == '__main__':
    main()
