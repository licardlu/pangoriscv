"""Ground-truth-gated original teacher loss for four/five-class students.

Only distill anchors where the teacher agrees with an actual waste label and
has IoU>=.5 and confidence>=.25. False kitchen hands and remote background
predictions are never pseudo-labels. Teacher is training-only, never exported.
"""
from collections import Counter
import torch
import torch.nn.functional as F


def matched_preservation_loss(student, teacher, boxes, anchors, classes):
    if (student.shape[-1] not in (9, 10) or teacher.shape[-1] not in (9, 10)
            or teacher.shape[-1] > student.shape[-1]):
        raise ValueError('Expected four/five-class teacher compatible with student raw anchor logits')
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
    nc = teacher.shape[-1]-5
    score, category = teacher[:,5:5+nc].sigmoid().max(1)
    valid = ((category == classes) & (classes < nc) &
             (score*teacher[:,4].sigmoid() >= .25) & (overlap >= .5))
    losses = []
    counts = Counter()
    for cls in range(nc):
        mask = valid & (classes == cls)
        if mask.any():
            prediction, truth = student[mask,:5+nc], teacher[mask]
            losses.append(.5*F.mse_loss(prediction[:,:4].sigmoid(), truth[:,:4].sigmoid()) +
                          F.mse_loss(prediction[:,4:5].sigmoid(), truth[:,4:5].sigmoid()) +
                          F.mse_loss(prediction[:,5:5+nc].sigmoid(), truth[:,5:5+nc].sigmoid()))
            counts[str(cls)] += int(mask.sum())
    return (torch.stack(losses).mean() if losses else student.sum()*0), counts


class PreservationLoss:
    def __init__(self, supervised, student, teacher, strength, background_strength=0.):
        self.supervised, self.teacher, self.strength = supervised, teacher.eval(), strength
        head, old = student.model[-1], teacher.model[-1]
        if head.nc not in (4,5) or old.nc not in (4,5) or old.nc>head.nc or not torch.equal(head.anchors,old.anchors):
            raise ValueError('Teacher/student head taxonomy or anchors differ')
        if not torch.equal(head.stride,old.stride):
            raise ValueError('Teacher/student strides differ')
        for p in self.teacher.parameters(): p.requires_grad_(False)
        self.teacher_classes = old.nc
        if background_strength < 0 or (background_strength and old.nc != 5):
            raise ValueError('Background retention requires nonnegative strength and native5teacher')
        self.background_strength = background_strength
        self.reset_stats()

    def reset_stats(self):
        self.batches = 0
        self.loss_sum = 0.
        self.counts = Counter()
        self.background_counts = Counter()
        self.background_loss_sum = 0.

    def take_stats(self):
        result = dict(batches=self.batches, mean_preservation_loss=self.loss_sum/max(1,self.batches),
                      matched_anchors_by_class=dict(self.counts), strength=self.strength,
                      validation_teacher_used=False)
        if self.background_strength:
            result['background_preservation'] = dict(self.background_counts,
                strength=self.background_strength,mean_loss=self.background_loss_sum/max(1,self.batches),
                scope='Teacher obj<=.1, exclude every GT assignment and GT rectangles expanded1cell; top32/image; suppress objectness increases only')
        self.reset_stats()
        return result

    def __call__(self, prediction, targets, images=None):
        loss, components = self.supervised(prediction, targets)
        # Upstream validation passes no images: its reported loss stays ordinary
        # supervised loss. No hooks, teacher, or helper are attached to student.
        if images is None:
            return loss, components
        eligible_targets = targets[targets[:,1] < self.teacher_classes]
        if len(eligible_targets) == 0 and not self.background_strength:
            self.batches += 1
            return loss, components
        with torch.no_grad():
            teacher_outputs = self.teacher(images.detach())[1]
            # Target construction has no differentiable work. Exclude this
            # helper from mixed hand/waste supervision counters.
            classes, boxes, indices, anchors = self.supervised.build_targets(prediction, eligible_targets)
        terms = []
        for i, (batch, anchor, y, x) in enumerate(indices):
            if len(batch):
                term, counts = matched_preservation_loss(prediction[i][batch,anchor,y,x],
                    teacher_outputs[i][batch,anchor,y,x], boxes[i], anchors[i], classes[i])
                terms.append(term)
                self.counts.update(counts)
        auxiliary = torch.stack(terms).mean() if terms else prediction[0].sum()*0
        background = prediction[0].sum()*0
        if self.background_strength:
            from teacher_background import background_preservation_loss
            with torch.no_grad():
                _, _, all_indices, _ = self.supervised.build_targets(prediction, targets)
            background, stats = background_preservation_loss(prediction, teacher_outputs, targets, all_indices)
            self.background_counts.update(stats)
            self.background_loss_sum += float(background.detach())
        self.batches += 1
        self.loss_sum += float(auxiliary.detach())
        return loss + (auxiliary*self.strength + background*self.background_strength)*images.shape[0], components
