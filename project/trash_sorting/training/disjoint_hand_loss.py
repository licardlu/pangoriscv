"""Training-only hand targets may not displace actual waste targets.

Keep every waste assignment and all non-conflicting hand assignments. This
changes supervision only; the deployed five-class model schema is unchanged.
"""
from collections import Counter
import torch


def disjoint_loss_class(parent, instances):
    class DisjointHandLoss(parent):
        def __init__(self, model, *args, **kwargs):
            super().__init__(model, *args, **kwargs)
            if self.nc != 5:
                raise ValueError('Disjoint hand assignments require joint five classes')
            self.assignment_stats = Counter()
            instances.append(self)

        def take_assignment_stats(self):
            result = dict(self.assignment_stats)
            self.assignment_stats.clear()
            return result

        def build_targets(self, prediction, targets):
            classes, boxes, indices, anchors = super().build_targets(prediction, targets)
            # Teacher preservation separately requests waste-only targets;
            # count the supervised mixed/hand call once, not that helper call.
            record = (torch.is_grad_enabled() and prediction[0].requires_grad and
                      bool((targets[:, 1] == 4).any()))
            if record:
                self.assignment_stats['training_batches_with_hand'] += 1
            for i, category in enumerate(classes):
                if not len(category):
                    continue
                batch, anchor, y, x = indices[i]
                h, w = prediction[i].shape[2:4]
                key = ((batch*3+anchor)*h+y)*w+x
                hand, waste = category == 4, category < 4
                conflict = hand & torch.isin(key, key[waste])
                if record:
                    self.assignment_stats['hand_assignments'] += int(hand.sum())
                    self.assignment_stats['waste_assignments'] += int(waste.sum())
                    self.assignment_stats['removed_hand_assignments'] += int(conflict.sum())
                keep = ~conflict
                classes[i], boxes[i], anchors[i] = category[keep], boxes[i][keep], anchors[i][keep]
                indices[i] = tuple(value[keep] for value in indices[i])
            return classes, boxes, indices, anchors

    return DisjointHandLoss
