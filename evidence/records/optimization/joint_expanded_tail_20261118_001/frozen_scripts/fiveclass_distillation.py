"""GT-gated matched-anchor distillation for five-class frozen-feature models.

Only a teacher's correct class, confidence >=.25, IoU>=.5 positive anchors
contribute. Teacher predictions never become new boxes or background labels.
"""
from collections import Counter
import torch
import torch.nn.functional as F

def matched_loss(student,teacher,boxes,anchors,classes):
    assert student.shape==teacher.shape and student.shape[-1]==10
    teacher=teacher.detach()
    xy=teacher[:,:2].sigmoid()*2-.5
    wh=(teacher[:,2:4].sigmoid()*2).square()*anchors
    lo=torch.maximum(xy-wh/2,boxes[:,:2]-boxes[:,2:]/2)
    hi=torch.minimum(xy+wh/2,boxes[:,:2]+boxes[:,2:]/2)
    inter=(hi-lo).clamp(min=0).prod(1)
    iou=inter/(wh.prod(1)+boxes[:,2:].prod(1)-inter).clamp(min=1e-9)
    score,category=teacher[:,5:].sigmoid().max(1)
    valid=(category==classes)&(score*teacher[:,4].sigmoid()>=.25)&(iou>=.5)
    terms=[];counts=Counter()
    for c in range(5):
        mask=valid&(classes==c)
        if bool(mask.any()):
            p=student[mask].sigmoid();t=teacher[mask].sigmoid()
            terms.append(.5*F.mse_loss(p[:,:4],t[:,:4])+F.mse_loss(p[:,4:5],t[:,4:5])+F.mse_loss(p[:,5:],t[:,5:]))
            counts[str(c)]+=int(mask.sum())
    return (torch.stack(terms).mean() if terms else student.sum()*0),counts

def distill(supervised,student,teacher,targets):
    classes,boxes,indices,anchors=supervised.build_targets(student,targets)
    terms=[];counts=Counter()
    for i,(batch,anchor,y,x) in enumerate(indices):
        if len(batch):
            term,c=matched_loss(student[i][batch,anchor,y,x],teacher[i][batch,anchor,y,x],boxes[i],anchors[i],classes[i])
            terms.append(term);counts.update(c)
    return (torch.stack(terms).mean() if terms else student[0].sum()*0),counts
