"""Ground-truth-gated four-bin teacher loss for five-class hand training.

Only distill anchors where the teacher agrees with an actual waste label and
has IoU>=.5 and confidence>=.25. False kitchen hands and remote background
predictions are never pseudo-labels. Teacher is training-only, never exported.
"""
from collections import Counter
import torch
import torch.nn.functional as F


def matched_preservation_loss(student, teacher, boxes, anchors, classes):
    if student.shape[-1] != 10 or teacher.shape[-1] != 9:
        raise ValueError('Expected matched joint5 and original4 raw anchor logits')
    if student.shape[0] != teacher.shape[0] or boxes.shape != (len(student),4):
        raise ValueError('Matched anchor/target shapes differ')
    teacher = teacher.detach()
    xy = teacher[:,:2].sigmoid()*2-.5
    wh = (teacher[:,2:4].sigmoid()*2).square()*anchors
    lo = torch.maximum(xy-wh/2, boxes[:,:2]-boxes[:,2:]/2)
    hi = torch.minimum(xy+wh/2, boxes[:,:2]+boxes[:,2:]/2)
    intersection = (hi-lo).clamp(min=0).prod(1)
    union = wh.prod(1)+boxes[:,2:].prod(1)-intersection
    overlap = intersection/union.clamp(min=1e-9)
    score, category = teacher[:,5:9].sigmoid().max(1)
    valid = ((category == classes) & (classes < 4) &
             (score*teacher[:,4].sigmoid() >= .25) & (overlap >= .5))
    losses = []
    counts = Counter()
    for cls in range(4):
        mask = valid & (classes == cls)
        if mask.any():
            prediction, truth = student[mask,:9], teacher[mask]
            losses.append(.5*F.mse_loss(prediction[:,:4].sigmoid(), truth[:,:4].sigmoid()) +
                          F.mse_loss(prediction[:,4:5].sigmoid(), truth[:,4:5].sigmoid()) +
                          F.mse_loss(prediction[:,5:9].sigmoid(), truth[:,5:9].sigmoid()))
            counts[str(cls)] += int(mask.sum())
    return (torch.stack(losses).mean() if losses else student.sum()*0), counts


class PreservationLoss:
    def __init__(self, supervised, student, teacher, strength):
        self.supervised, self.teacher, self.strength = supervised, teacher.eval(), strength
        head, old = student.model[-1], teacher.model[-1]
        if head.nc != 5 or old.nc != 4 or not torch.equal(head.anchors,old.anchors):
            raise ValueError('Teacher/student head taxonomy or anchors differ')
        if not torch.equal(head.stride,old.stride):
            raise ValueError('Teacher/student strides differ')
        for p in self.teacher.parameters(): p.requires_grad_(False)
        self.reset_stats()

    def reset_stats(self):
        self.batches = 0
        self.loss_sum = 0.
        self.counts = Counter()

    def take_stats(self):
        result = dict(batches=self.batches, mean_preservation_loss=self.loss_sum/max(1,self.batches),
                      matched_anchors_by_class=dict(self.counts), strength=self.strength,
                      validation_teacher_used=False)
        self.reset_stats()
        return result

    def __call__(self, prediction, targets, images=None):
        loss, components = self.supervised(prediction, targets)
        # Upstream validation passes no images: its reported loss stays ordinary
        # supervised loss. No hooks, teacher, or helper are attached to student.
        if images is None:
            return loss, components
        waste_targets = targets[targets[:,1] < 4]
        if len(waste_targets) == 0:
            self.batches += 1
            return loss, components
        with torch.no_grad():
            teacher_outputs = self.teacher(images.detach())[1]
        classes, boxes, indices, anchors = self.supervised.build_targets(prediction, waste_targets)
        terms = []
        for i, (batch, anchor, y, x) in enumerate(indices):
            if len(batch):
                term, counts = matched_preservation_loss(prediction[i][batch,anchor,y,x],
                    teacher_outputs[i][batch,anchor,y,x], boxes[i], anchors[i], classes[i])
                terms.append(term)
                self.counts.update(counts)
        auxiliary = torch.stack(terms).mean() if terms else prediction[0].sum()*0
        self.batches += 1
        self.loss_sum += float(auxiliary.detach())
        return loss + auxiliary*self.strength*images.shape[0], components
