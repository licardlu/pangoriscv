"""Train-only class separation at actual waste GT anchors; no pseudo labels.

Preserve ordinary five-class supervision, including actual hand anchors.
The auxiliary term only changes the true-waste and hand class logits at waste
anchors. It does not force an entire hand-containing image to be negative.
"""
from collections import Counter
import torch
import torch.nn.functional as F


def waste_hand_margin(logits, classes, margin=1.):
    if logits.ndim != 2 or logits.shape[1] != 10 or classes.shape != (len(logits),):
        raise ValueError('Expected five-class raw logits and assigned GT classes')
    if not bool(((classes >= 0) & (classes <= 4)).all()):
        raise ValueError('Invalid GT category')
    terms = []
    counts = Counter()
    for category in range(4):
        mask = classes == category
        if bool(mask.any()):
            # A logit gap of1 is fixed before training, not selected on dev.
            terms.append(F.softplus(logits[mask, 9] - logits[mask, 5+category] + margin).mean())
            counts[str(category)] += int(mask.sum())
    return (torch.stack(terms).mean() if terms else logits.sum()*0), counts


def waste_hand_loss_class(parent, instances, strength=.01):
    if strength <= 0:
        raise ValueError('Positive margin strength required')

    class WasteHandMarginLoss(parent):
        def __init__(self, model, *args, **kwargs):
            super().__init__(model, *args, **kwargs)
            if self.nc != 5:
                raise ValueError('Requires native five classes')
            self.margin_stats = Counter()
            self.margin_counts = Counter()
            instances.append(self)

        def take_margin_stats(self):
            result = dict(self.margin_stats)
            result.update(waste_anchors_by_class=dict(self.margin_counts), strength=strength, margin=1.,
                          scope='Only complete GT waste anchors; hand GT untouched; class logits only')
            self.margin_stats.clear()
            self.margin_counts.clear()
            return result

        def __call__(self, prediction, targets):
            loss, items = super().__call__(prediction, targets)
            if not torch.is_grad_enabled() or not any(p.requires_grad for p in prediction):
                return loss, items
            # Avoid counting an auxiliary target build as supervised examples.
            with torch.no_grad():
                classes, _, indices, _ = self.build_targets(prediction, targets)
            terms = []
            for raw, category, index in zip(prediction, classes, indices):
                if len(category):
                    term, counts = waste_hand_margin(raw[index], category)
                    terms.append(term)
                    self.margin_counts.update(counts)
            extra = torch.stack(terms).mean() if terms else prediction[0].sum()*0
            self.margin_stats['training_batches'] += 1
            self.margin_stats['unscaled_batch_mean_sum'] += float(extra.detach())
            return loss + extra*strength*prediction[0].shape[0], items

    return WasteHandMarginLoss
