"""Training-only retention of original teacher's confident background.

The original teacher never creates positive labels here. Only low-objectness
anchors outside every annotated GT rectangle (expanded by one grid cell) are
eligible. All supervised GT assignments are also explicitly excluded.
"""
import torch


def background_preservation_loss(student, teacher, targets, indices, topk=32):
    if len(student) != len(teacher) or len(student) != len(indices) or topk < 1:
        raise ValueError('Incompatible raw heads, GT indices or topk')
    bs = student[0].shape[0]
    candidate_scores, differences, masks = [], [], []
    for raw, old, index in zip(student, teacher, indices):
        if raw.shape != old.shape or raw.shape[-1] != 10 or raw.shape[0] != bs:
            raise ValueError('Background preservation requires matching native five-class heads')
        old = old.detach()
        with torch.no_grad():
            eligible = old[..., 4].sigmoid() <= .1
            eligible[index] = False
            h, w = raw.shape[2:4]
            # Conservative protected support includes hands and all waste.
            for truth in targets:
                batch = int(truth[0])
                cx, cy, width, height = truth[2:6]
                x1 = max(0, int(torch.floor((cx-width/2)*w))-1)
                x2 = min(w, int(torch.ceil((cx+width/2)*w))+2)
                y1 = max(0, int(torch.floor((cy-height/2)*h))-1)
                y2 = min(h, int(torch.ceil((cy+height/2)*h))+2)
                eligible[batch, :, y1:y2, x1:x2] = False
        # Penalize increases only: never raise objectness to copy the teacher.
        increase = (raw[..., 4].sigmoid()-old[..., 4].sigmoid()).clamp_min(0).square()
        with torch.no_grad():
            rank = increase.detach()*raw[..., 5:].sigmoid().amax(-1)
            rank = rank.masked_fill(~eligible, -1)
        candidate_scores.append(rank.reshape(bs, -1))
        differences.append(increase.reshape(bs, -1))
        masks.append(eligible.reshape(bs, -1))
    ranking = torch.cat(candidate_scores, 1)
    values = torch.cat(differences, 1)
    eligibility = torch.cat(masks, 1)
    ranks, chosen = ranking.topk(min(topk, ranking.shape[1]), dim=1)
    used = ranks >= 0
    errors = values.gather(1, chosen)
    mean = ((errors*used).sum(1)/used.sum(1).clamp_min(1)).mean()
    stats = dict(eligible_anchors=int(eligibility.sum()), selected_anchors=int(used.sum()),
                 images_with_selected=int(used.any(1).sum()), positive_drift_anchors=int(((errors > 0)&used).sum()))
    return mean, stats
