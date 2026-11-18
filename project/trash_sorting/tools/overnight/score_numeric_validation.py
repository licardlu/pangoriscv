"""Score saved Q15-oracle/C-decoder validation outputs using the candidate C selector.

Reports fixed-confidence counts, not AP: the numerical runner only saves >=.25.
This is software arithmetic validation, never a board-camera accuracy result.
"""
import argparse,collections,ctypes as C,json
from pathlib import Path
import numpy as np
from replay_policy import Box,Target,overlap,sha

def main():
 p=argparse.ArgumentParser(description=__doc__)
 p.add_argument('--numeric',type=Path,required=True);p.add_argument('--photos',type=Path,required=True)
 p.add_argument('--manifest',type=Path,required=True);p.add_argument('--policy-replay',type=Path,required=True)
 p.add_argument('--source-dir',type=Path,required=True);p.add_argument('--out',type=Path,required=True)
 a=p.parse_args();result=json.loads((a.numeric/'result.json').read_text(encoding='utf8'))
 assert result['status']=='PASS' and result['truth_sha256']==sha(a.photos/'truth.json')
 inventory=json.loads((a.photos/'inventory.json').read_text(encoding='utf8'))
 predictions=json.loads((a.numeric/'predictions.json').read_text(encoding='utf8'))
 assert len(inventory)==len(predictions)==result['images']
 assert len(inventory)==len({r['path'] for r in inventory}),'Repeated images are not an accuracy sample'
 assert {r['id'] for r in inventory}=={r['id'] for r in predictions}
 photos={r['id']:r for r in inventory};manifest=json.loads(a.manifest.read_text(encoding='utf8'))
 truth={Path(r['prepared_image']).stem:r for r in manifest if r['split']=='val'}
 policy=json.loads((a.policy_replay/'result.json').read_text(encoding='utf8'))
 sw=a.source_dir/'yolo/software'
 for name,digest in policy['headers'].items():assert sha(sw/name)==digest,'Policy header identity changed'
 lib=C.CDLL(str((a.policy_replay/'policy.dll').resolve()))
 lib.policy_select.argtypes=[C.POINTER(Box),C.c_uint32,C.c_uint32,C.c_uint32,C.c_float,C.c_float];lib.policy_select.restype=Target
 stats=collections.defaultdict(collections.Counter);classes=[collections.Counter() for _ in range(5)];decisions={}
 for row in predictions:
  photo=photos[row['id']];stem=Path(photo['path']).stem;gt=truth[stem]
  assert gt['image_sha256']==photo['sha256']
  w,h=photo['display_size'];detections=row['detections'];boxes=[]
  for d in detections:
   assert 0<=d['category']<5 and d['score']>=.25
   boxes.append([*d['box'],d['score'],d['category']]);classes[d['category']]['predictions']+=1
  targets=[]
  for c,cx,cy,bw,bh in gt['boxes']:
   targets.append([int(c),(cx-bw/2)*w,(cy-bh/2)*h,(cx+bw/2)*w,(cy+bh/2)*h]);classes[int(c)]['GT']+=1
  # Same IoU-first, unique-detection then unique-label assignment as YOLOv5.
  matches=[]
  for gi,g in enumerate(targets):
   for pi,b in enumerate(boxes):
    iou=overlap(g[1:],b[:4])
    if int(b[5])==g[0] and iou>=.5:matches.append([gi,pi,iou])
  if matches:
   m=np.asarray(matches);m=m[m[:,2].argsort()[::-1]];m=m[np.unique(m[:,1],return_index=True)[1]]
   m=m[m[:,2].argsort()[::-1]];m=m[np.unique(m[:,0],return_index=True)[1]]
   for pi in m[:,1].astype(int):classes[int(boxes[pi][5])]['TP']+=1
  cb=(Box*len(boxes))(*[Box(*b[:5],int(b[5])) for b in boxes])
  target=lib.policy_select(cb,len(boxes),4,4,w,h)
  selected=boxes[target.object_index] if target.object_index>=0 else None
  waste=[g for g in targets if g[0]<4]
  right=bool(selected and any(int(selected[5])==g[0] and overlap(selected[:4],g[1:])>=.5 for g in waste))
  class_right=bool(selected and any(int(selected[5])==g[0] for g in waste))
  group=str(gt.get('capture_group',gt.get('group_id',gt.get('group','unspecified'))))
  cohorts=['all','source/'+gt['source'],'has_waste' if waste else 'no_waste','group/'+group]
  if '/glass/' in str(gt.get('image','')).replace('\\','/').lower():cohorts.append('material/public_glass')
  for cohort in cohorts:
   s=stats[cohort];s['images']+=1;s['selected']+=selected is not None;s['hand_seen']+=bool(target.hand_seen)
   if waste:s['correct_class_and_iou050']+=right;s['correct_class']+=class_right
   else:s['false_selected']+=selected is not None
  decisions[stem]=dict(selected=selected,correct_class_and_iou050=right,hand_seen=bool(target.hand_seen),group=group)
 names=('kitchen','recyclable','hazardous','other','hand');fixed={}
 for name,counts in zip(names,classes):
  tp,gt,n=counts['TP'],counts['GT'],counts['predictions']
  fixed[name]=dict(TP=tp,FP=n-tp,GT=gt,precision=tp/n if n else 0,recall=tp/gt if gt else None)
 report=dict(status='PASS',scope='software Q15 convolution oracle + actual C head/decoder and candidate C selector; not FPGA or camera accuracy',
  images=len(predictions),model_sha256=result['model_sha256'],held_out_test_used=False,
  confidence=.25,iou_match=.5,nms_iou=.45,max_det=32,AP_not_computed='outputs below confidence .25 were not retained',
  fixed_conf025_iou050=fixed,cohorts=dict(stats),numeric_result_sha256=sha(a.numeric/'result.json'),
  predictions_sha256=sha(a.numeric/'predictions.json'),manifest_sha256=sha(a.manifest),policy_headers=policy['headers'])
 a.out.mkdir(parents=True,exist_ok=False)
 (a.out/'result.json').write_text(json.dumps(report,indent=2,ensure_ascii=False),encoding='utf8')
 (a.out/'decisions.json').write_text(json.dumps(decisions,indent=2),encoding='utf8')
 print(json.dumps(dict(status='PASS',images=len(predictions),fixed=fixed,all=report['cohorts']['all'],no_waste=report['cohorts'].get('no_waste'))),flush=True)
if __name__=='__main__':main()
