"""Check real upstream target assignments and gradients for hand conflict removal."""
import argparse
import json
import os
from pathlib import Path
import sys


def main():
    p = argparse.ArgumentParser(description=__doc__)
    for name in ('yolo', 'weights', 'out'):
        p.add_argument('--'+name, type=Path, required=True)
    a = p.parse_args()
    a.out.mkdir(parents=True, exist_ok=False)
    (a.out/'config').mkdir()
    os.environ['YOLOV5_CONFIG_DIR'] = str((a.out/'config').resolve())
    os.environ['YOLOv5_AUTOINSTALL'] = 'false'
    sys.path.insert(0, str(a.yolo.resolve()))
    import torch
    from utils.loss import ComputeLoss
    from disjoint_hand_loss import disjoint_loss_class
    torch.set_num_threads(2)
    model = torch.load(a.weights, map_location='cpu')['model'].float().eval()
    original = ComputeLoss(model)
    tracked = []
    modified = disjoint_loss_class(ComputeLoss, tracked)(model)
    examples = [
        [[0, 0, .5, .5, .3, .3], [0, 4, .5, .5, .3, .3]],
        [[0, 1, .2, .2, .15, .15], [0, 4, .8, .8, .25, .25]],
        [[0, 3, .5, .5, .3, .3], [0, 4, .5, .5, .3, .3], [1, 4, .5, .5, .3, .3]],
        [[0, 2, .5, .5, .3, .3]],
        [[0, 4, .5, .5, .3, .3]],
        []]
    removed = 0
    for rows in examples:
        raw = [torch.zeros(2, 3, n, n, 10, requires_grad=True) for n in (40, 20, 10)]
        target = torch.tensor(rows, dtype=torch.float32).reshape(-1, 6)
        before = original.build_targets(raw, target)
        after = modified.build_targets(raw, target)
        for level in range(3):
            old_c, new_c = before[0][level], after[0][level]
            old_indices = list(zip(*(v.tolist() for v in before[2][level])))
            new_indices = list(zip(*(v.tolist() for v in after[2][level])))
            waste_positions = {pos for c, pos in zip(old_c.tolist(), old_indices) if c < 4}
            expected_keep = torch.tensor([not (c == 4 and pos in waste_positions)
                                          for c, pos in zip(old_c.tolist(), old_indices)], dtype=torch.bool)
            torch.testing.assert_close(new_c, old_c[expected_keep], rtol=0, atol=0)
            for component in (1, 3):
                torch.testing.assert_close(after[component][level], before[component][level][expected_keep], rtol=0, atol=0)
            for left, right in zip(after[2][level], before[2][level]):
                torch.testing.assert_close(left, right[expected_keep], rtol=0, atol=0)
            assert not any(c == 4 and pos in waste_positions for c, pos in zip(new_c.tolist(), new_indices))
            removed += int((~expected_keep).sum())
        loss, _ = modified(raw, target)
        assert torch.isfinite(loss).all()
        loss.sum().backward()
        assert all(x.grad is not None and torch.isfinite(x.grad).all() for x in raw)
    stats = modified.take_assignment_stats()
    assert removed > 0 and stats['removed_hand_assignments'] > 0
    with torch.no_grad():
        modified.build_targets(raw, torch.tensor(examples[0], dtype=torch.float32))
    assert modified.take_assignment_stats() == {}
    report = dict(status='PASS_ACTUAL_TARGETS_AND_GRADIENTS', cases=len(examples), removed=removed,
                  guarantees=['all waste rows/boxes/anchors/indices preserved', 'all nonconflicting hands preserved',
                              'batch identity included', 'empty targets finite', 'validation excluded from counters'])
    (a.out/'result.json').write_text(json.dumps(report, indent=2), encoding='utf8')
    print('TEST_PASS disjoint targets 6 actual upstream cases and finite gradients', flush=True)


if __name__ == '__main__':
    main()
