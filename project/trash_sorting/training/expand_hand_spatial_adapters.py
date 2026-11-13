"""Expand frozen-feature hand adapters 1x1 -> 3x3 with identical initial function."""
import argparse
import copy
import hashlib
import json
import os
from pathlib import Path
import sys


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def main():
    p = argparse.ArgumentParser(description=__doc__)
    for name in ('weights', 'yolo', 'out'):
        p.add_argument('--'+name, type=Path, required=True)
    p.add_argument('--expected-sha256', required=True)
    a = p.parse_args()
    if sha(a.weights) != a.expected_sha256:
        raise ValueError('Checkpoint identity mismatch')
    a.out.mkdir(parents=True, exist_ok=False)
    os.environ['YOLOv5_AUTOINSTALL'] = 'false'
    os.environ['YOLOV5_CONFIG_DIR'] = str((a.out/'config').resolve())
    sys.path.insert(0, str(a.yolo.resolve()))
    import torch
    from torch import nn
    torch.set_num_threads(2)
    torch.manual_seed(20261113)
    cp = torch.load(a.weights, map_location='cpu')
    old = (cp.get('ema') or cp['model']).float().eval()
    if len(old.model) != 28 or old.model[-1].nc != 1:
        raise ValueError('Expected three-adapter hand branch')
    model = copy.deepcopy(old)
    adapters = []
    for i in range(24, 27):
        block = model.model[i]
        conv = block.conv
        if conv.kernel_size != (1, 1) or conv.out_channels != 32 or conv.bias is not None:
            raise ValueError('Expected 32-channel 1x1 Conv/BN/SiLU adapters')
        new = nn.Conv2d(conv.in_channels, 32, 3, padding=1, bias=False)
        with torch.no_grad():
            new.weight.zero_()
            new.weight[:, :, 1:2, 1:2].copy_(conv.weight)
        block.conv = new
        entry = model.yaml['head'][-4+(i-24)]
        if entry[3][1] != 1:
            raise ValueError('Unexpected model YAML adapter kernel')
        entry[3][1] = 3
        adapters.append(dict(layer=i, input_channels=conv.in_channels, channels=32, kernel=3))
    common = {k: v for k, v in old.state_dict().items() if int(k.split('.')[1]) < 24}
    if any(not torch.equal(v, model.state_dict()[k]) for k,v in common.items()):
        raise ValueError('Original waste features changed')
    model.eval()
    with torch.no_grad():
        x = torch.rand(1, 3, 320, 320)
        before, after = old(x)[0], model(x)[0]
        torch.testing.assert_close(after, before, rtol=1e-5, atol=1e-4)
    target = a.out/'initial_spatial_hand.pt'
    torch.save(dict(model=model, ema=None, epoch=-1, optimizer=None, best_fitness=0), target)
    result = dict(status='INITIAL_FUNCTION_VERIFIED_ONLY', source_sha256=sha(a.weights),
        checkpoint_sha256=sha(target), adapters=adapters, common_tensors_exact=len(common),
        initial_output_max_abs=float((after-before).abs().max()),
        script_sha256=sha(Path(__file__)), board_programmed=False)
    (a.out/'result.json').write_text(json.dumps(result, indent=2), encoding='utf8')
    print(json.dumps(result), flush=True)


if __name__ == '__main__':
    main()
