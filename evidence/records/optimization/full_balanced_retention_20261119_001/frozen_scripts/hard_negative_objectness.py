"""Training-only objectness emphasis for reviewed waste-free images.

Do not use predicted labels as truth: eligibility comes from existing GT.
Keep all GT-positive hand anchors and every image containing real waste intact.
The deployed model, decoder, class schema, and ordinary validation are unchanged.
"""
from collections import Counter
import torch
import torch.nn.functional as F


def hard_negative_loss_class(parent, instances, strength=.02, topk=8, min_score=.10):
    if strength <= 0 or topk < 1 or not 0 <= min_score < 1:
        raise ValueError('Invalid hard-negative settings')

    class HardNegativeObjectnessLoss(parent):
        def __init__(self, model, *args, **kwargs):
            super().__init__(model, *args, **kwargs)
            if self.nc != 5:
                raise ValueError('Requires the joint four-bin/hand model')
            self.hard_negative_stats = Counter()
            instances.append(self)

        def take_hard_negative_stats(self):
            result = dict(self.hard_negative_stats)
            self.hard_negative_stats.clear()
            return result

        def __call__(self, prediction, targets):
            loss, items = super().__call__(prediction, targets)
            if not torch.is_grad_enabled() or not any(p.requires_grad for p in prediction):
                return loss, items
            bs = prediction[0].shape[0]
            # Targets describe all reviewed waste, including background objects.
            # Such images are never treated as waste-free on the basis of name.
            has_waste = torch.zeros(bs, dtype=torch.bool, device=prediction[0].device)
            if len(targets):
                has_waste[targets[targets[:, 1] < 4, 0].long()] = True
            _, _, indices, _ = self.build_targets(prediction, targets)
            candidates, logits = [], []
            for p, index in zip(prediction, indices):
                with torch.no_grad():
                    prob = p.detach().sigmoid()
                    waste = prob[..., 5:9].amax(-1)
                    score = prob[..., 4] * waste
                    eligible = (~has_waste)[:, None, None, None].expand_as(score).clone()
                    # Exclude every ground-truth-positive anchor, including hand.
                    eligible[index] = False
                    eligible &= (waste > prob[..., 9]) & (score >= min_score)
                    score = score.masked_fill(~eligible, -1)
                candidates.append(score.reshape(bs, -1))
                logits.append(p[..., 4].reshape(bs, -1))
            scores = torch.cat(candidates, dim=1)
            obj_logits = torch.cat(logits, dim=1)
            selected_scores, selected_indices = scores.topk(min(topk, scores.shape[1]), dim=1)
            mask = selected_scores >= min_score
            chosen = obj_logits.gather(1, selected_indices)
            # Mean per image, then sum as upstream returns a batch-scaled loss.
            # Images without a mined anchor add zero; no extra class/box gradient.
            terms = F.binary_cross_entropy_with_logits(chosen, torch.zeros_like(chosen), reduction='none')
            added = ((terms * mask).sum(1) / mask.sum(1).clamp_min(1)).sum() * strength
            self.hard_negative_stats['training_batches'] += 1
            self.hard_negative_stats['eligible_images'] += int((~has_waste).sum())
            self.hard_negative_stats['images_with_hard_negatives'] += int(mask.any(1).sum())
            self.hard_negative_stats['mined_anchors'] += int(mask.sum())
            self.hard_negative_stats['added_batch_loss_sum'] += float(added.detach())
            return loss + added, items

    return HardNegativeObjectnessLoss
