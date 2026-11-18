"""Export only the 77 reviewed photos reserved before training; no test use."""
import argparse,collections,hashlib,json,os,shutil
from pathlib import Path
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def main():
 p=argparse.ArgumentParser();p.add_argument('--photos',type=Path,required=True);p.add_argument('--training',type=Path,required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args()
 audit=json.loads((a.photos/'audit.json').read_text(encoding='utf8'));ledger=json.loads((a.photos/'review_ledger.json').read_text(encoding='utf8'))
 trained=json.loads((a.training/'manifest.json').read_text(encoding='utf8'));trainsha={r['image_sha256'] for r in trained if r['split']=='train'}
 traingroup={str(r.get('capture_group',r.get('group'))) for r in trained if r['split']=='train'}
 historical=collections.defaultdict(set)
 for r in audit['images']:
  if r.get('group_id') and r.get('historical_splits'):historical[r['group_id']].update(r['historical_splits'])
 selected=[]
 for r in audit['images']:
  review=ledger['images'].get(r.get('id'))
  if r['status']!='NEEDS_VISUAL_REVIEW' or not review or review['status']!='VISUALLY_REVIEWED':continue
  split='train' if historical[r.get('group_id')]=={'train'} else r['split']
  if split!='val':continue
  assert not historical[r.get('group_id')].intersection({'train','val','test'})
  assert r['image_sha256'] not in trainsha and str(r.get('group_id')) not in traingroup
  assert review['image_sha256']==r['image_sha256'] and review['source_sha256']==r['sha256']
  selected.append((r,review))
 assert len(selected)==77,len(selected)
 out=a.out.resolve();out.mkdir(parents=True,exist_ok=False);rows=[]
 for r,review in selected:
  src=Path(r['image_path']);assert sha(src)==r['image_sha256']
  image=out/'images/val'/(r['id']+'.jpg');image.parent.mkdir(parents=True,exist_ok=True)
  try:os.link(src,image)
  except OSError:shutil.copyfile(src,image)
  w,h=r['preview_size'];boxes=[]
  for b in review['boxes']:
   x1,y1,x2,y2=b['xyxy'];boxes.append([b['category'],(x1+x2)/(2*w),(y1+y2)/(2*h),(x2-x1)/w,(y2-y1)/h])
  assert boxes or review.get('empty_confirmed')
  label=out/'labels/val'/(r['id']+'.txt');label.parent.mkdir(parents=True,exist_ok=True)
  label.write_text(''.join(str(b[0])+' '+' '.join(f'{v:.8f}' for v in b[1:])+'\n' for b in boxes),encoding='ascii')
  counts=collections.Counter(int(b[0]) for b in boxes if int(b[0])<4)
  rows.append(dict(source='personal_continuation_'+r['class_name'],origin='reserved_new_validation',split='val',
   prepared_image=image.as_posix(),boxes=boxes,primary_bin=counts.most_common(1)[0][0] if counts else 4,
   capture_group=r.get('group_id'),image_sha256=r['image_sha256'],label_sha256=sha(label),
   source_sha256=r['sha256'],annotation_status='VISUALLY_REVIEWED'))
 (out/'manifest.json').write_text(json.dumps(rows,indent=2,ensure_ascii=False),encoding='utf8')
 (out/'val.txt').write_text(''.join(r['prepared_image']+'\n' for r in rows),encoding='utf8')
 (out/'data.yaml').write_text(f'path: {out.as_posix()}\ntrain: val.txt\nval: val.txt\ntest: val.txt\nnc: 5\nnames: [kitchen, recyclable, hazardous, other, hand]\n',encoding='utf8')
 result=dict(status='PASS',images=len(rows),classes=dict(collections.Counter(int(b[0]) for r in rows for b in r['boxes'])),
  groups=sorted({r['capture_group'] for r in rows}),training_sha_and_capture_groups_disjoint=True,
  review_ledger_sha256=sha(a.photos/'review_ledger.json'),training_manifest_sha256=sha(a.training/'manifest.json'),
  scope='new development validation reserved before continuation; same source collection, not an independent physical-item test; YAML train/test aliases are evaluation-only')
 (out/'audit.json').write_text(json.dumps(result,indent=2),encoding='utf8');print(json.dumps(result),flush=True)
if __name__=='__main__':main()
