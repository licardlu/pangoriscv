"""Freeze a reviewed continuation dataset without changing original splits/files."""
import argparse,collections,hashlib,json,os,shutil
from pathlib import Path
def main():
 p=argparse.ArgumentParser();p.add_argument('--base',type=Path,required=True);p.add_argument('--photos',type=Path,required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args()
 base=a.base.resolve();photos=a.photos.resolve();out=a.out.resolve();out.mkdir(parents=True,exist_ok=False)
 originals=json.loads((base/'manifest.json').read_text(encoding='utf8'))
 rows=[]
 for r in originals:
  r=dict(r);r['prepared_image']=(base/r['prepared_image']).as_posix();rows.append(r)
 audit=json.loads((photos/'audit.json').read_text(encoding='utf8'));ledger=json.loads((photos/'review_ledger.json').read_text(encoding='utf8'))
 assert ledger['reviewer']=='assistant_visual' and ledger['coordinate_space']=='preview_xyxy'
 added=[];skip=collections.Counter();base_hashes={r['image_sha256'] for r in rows};groups=collections.defaultdict(set)
 for r in audit['images']:
  if r.get('group_id') and r.get('historical_splits'):groups[r['group_id']].update(r['historical_splits'])
 for r in audit['images']:
  if r['status']!='NEEDS_VISUAL_REVIEW':skip[r['status']]+=1;continue
  review=ledger['images'].get(r['id'])
  if not review or review['status']!='VISUALLY_REVIEWED':skip['unreviewed_or_excluded']+=1;continue
  assert review['source_sha256']==r['sha256'] and review['image_sha256']==r['image_sha256']
  assert hashlib.sha256(Path(r['image_path']).read_bytes()).hexdigest()==r['image_sha256']
  # An old training object cannot become a supposedly new independent val.
  historical=groups[r.get('group_id')]
  assert not historical.intersection({'val','test'})
  split='train' if historical=={'train'} else r['split']
  if split!='train':skip['reserved_new_validation']+=1;continue
  if r['image_sha256'] in base_hashes:skip['duplicate_prepared_image']+=1;continue
  w,h=r['preview_size'];boxes=[]
  for b in review['boxes']:
   c=b['category'];x1,y1,x2,y2=b['xyxy'];assert c in range(5) and 0<=x1<x2<=w and 0<=y1<y2<=h
   boxes.append([c,(x1+x2)/(2*w),(y1+y2)/(2*h),(x2-x1)/w,(y2-y1)/h])
  assert boxes or review.get('empty_confirmed') is True
  target=out/'images/train'/(r['id']+'.jpg');target.parent.mkdir(parents=True,exist_ok=True)
  try:os.link(r['image_path'],target)
  except OSError:shutil.copyfile(r['image_path'],target)
  label=out/'labels/train'/(r['id']+'.txt');label.parent.mkdir(parents=True,exist_ok=True)
  label.write_text(''.join(str(b[0])+' '+' '.join(f'{v:.8f}' for v in b[1:])+'\n' for b in boxes),encoding='ascii')
  q={'source':'continuation_'+r['class_name'],'origin':'personal_continuation','split':'train','prepared_image':target.as_posix(),'boxes':boxes,
     'primary_bin':int(boxes[0][0]) if boxes else 4,'group':r.get('group_id'),'capture_group':r.get('group_id'),
     'image_sha256':r['image_sha256'],'source_sha256':r['sha256'],'label_sha256':hashlib.sha256(label.read_bytes()).hexdigest(),
     'annotation_status':'VISUALLY_REVIEWED','stem':r['id']}
  added.append(q);base_hashes.add(r['image_sha256'])
 rows+=added
 assert added,'No reviewed additions; refuse data-free retraining'
 for split in ['train','val','test']:
  (out/(split+'.txt')).write_text(''.join(r['prepared_image']+'\n' for r in rows if r['split']==split),encoding='utf8')
 (out/'data.yaml').write_text(f'path: {out.as_posix()}\ntrain: train.txt\nval: val.txt\ntest: test.txt\nnc: 5\nnames: [kitchen, recyclable, hazardous, other, hand]\n',encoding='utf8')
 (out/'manifest.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2),encoding='utf8')
 (out/'review_ledger.snapshot.json').write_text(json.dumps(ledger,ensure_ascii=False,indent=2),encoding='utf8')
 report={'base_images':len(originals),'reviewed_additions':len(added),'split_images':dict(collections.Counter(r['split'] for r in rows)),
         'added_classes':dict(collections.Counter(int(b[0]) for r in added for b in r['boxes'])),'skipped':dict(skip),
         'base_val_test_unchanged':all(r['split']=='train' for r in added),'reviewed_ledger_images':len(ledger['images']),
         'ledger_sha256':hashlib.sha256((out/'review_ledger.snapshot.json').read_bytes()).hexdigest(),
         'note':'Only explicitly reviewed train candidates added; original 1929 val/1634 test remain unchanged. No claim of new independent physical-object testing.'}
 (out/'dataset_audit.json').write_text(json.dumps(report,indent=2),encoding='utf8');print(json.dumps(report),flush=True)
if __name__=='__main__':main()
