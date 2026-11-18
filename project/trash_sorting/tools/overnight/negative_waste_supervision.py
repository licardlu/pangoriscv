"""Train-only hard negative waste scores on explicitly labelled no-waste images.

Hand remains a positive detection class in the ordinary supervised YOLO loss.
Only images whose complete GT has no class0..3 enter this auxiliary objective.
It uses no teacher pseudo labels, confidence threshold, validation or policy edits.
"""
import torch


def negative_waste_loss(predictions,targets,topk=32):
    assert len(predictions)==3 and topk>0
    batch=predictions[0].shape[0]
    assert all(p.shape[0]==batch and p.shape[-1]==10 for p in predictions)
    assert targets.ndim==2 and targets.shape[1]==6
    has_waste=torch.zeros(batch,dtype=torch.bool,device=predictions[0].device)
    if len(targets):
        assert bool(((targets[:,1]>=0)&(targets[:,1]<=4)).all())
        indices=targets[targets[:,1]<4,0].long()
        assert not len(indices) or bool(((indices>=0)&(indices<batch)).all())
        has_waste[indices]=True
    negative=(~has_waste).nonzero(as_tuple=True)[0]
    if not len(negative):return predictions[0].sum()*0,0
    # Actual decoder score is objectness * class probability. Pool over all
    # three heads, taking the 32 strongest scores per waste class and image.
    scores=torch.cat([p[negative].reshape(len(negative),-1,10) for p in predictions],dim=1)
    joint=scores[:,:,4:5].sigmoid()*scores[:,:,5:9].sigmoid()
    hardest=joint.topk(min(topk,joint.shape[1]),dim=1).values
    terms=-torch.log1p(-hardest.clamp(max=1-1e-6))
    # Sum negative image means / full batch: a lone negative does not receive
    # sixteen times the gradient simply because the other images contain waste.
    return terms.mean(dim=(1,2)).sum()/batch,int(len(negative))
