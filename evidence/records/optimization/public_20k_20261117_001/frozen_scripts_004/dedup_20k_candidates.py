"""Conservative source admission, historical exclusion, and near-duplicate groups.

No final test file is opened. Existing test hash metadata is exclusion-only.
This stage does not assert that source labels were individually reviewed.
"""
import argparse,collections,hashlib,json,re,time
from pathlib import Path
import numpy as np
from audit_public_expansion import features

MAPS={
 'drinking':{i:1 for i in range(4)},
 'bbox384':{0:1,2:1,3:1,4:1,6:0},
 'trashsort':{0:1,1:3,2:2,3:1,4:0,5:3,6:3,7:2,8:0,9:0,10:3,11:0},
 'batteryobjects':{0:2},
 # WaRP has unlabelled other-bin waste throughout its conveyor scenes.
 # Retain as research/reference, not incomplete four-bin supervision.
}
def main():
 p=argparse.ArgumentParser();p.add_argument('--root',type=Path,required=True);a=p.parse_args();root=a.root.resolve();repo=Path(__file__).resolve().parents[3]
 known=[]
 for folder in ['overnight_20261116/dataset_stage4','continuation_023_dataset_001','public_expansion_20261117_001/dataset_003']:
  known+=json.loads((repo/'build'/folder/'manifest.json').read_text(encoding='utf8'))
 cachepath=root/'historical_feature_cache.json';cache=json.loads(cachepath.read_text()) if cachepath.exists() else {}
 for r in known:
  if 'phash' not in r and r['split']!='test':
   key=r['prepared_image']
   if key not in cache:cache[key]=features(key)
   r.update(cache[key])
 cachepath.write_text(json.dumps(cache),encoding='utf8')
 oldph=np.array(sorted({int(r['phash']) for r in known if 'phash'in r}),dtype=np.uint64)
 oldpix={r['sha256_pixels'] for r in known if r.get('sha256_pixels')}
 oldsha={r.get('image_sha256',r.get('sha256')) for r in known}
 oldnames=collections.defaultdict(set)
 for r in known:
  if r['source'] in ('sumn2u','codingbear'):
   for field in ['image','label']:
    if r.get(field):oldnames[r['source']].add(Path(r[field]).stem.lower())
 lut=np.array([bin(i).count('1') for i in range(256)],dtype=np.uint8)
 rows=[];rejected=[]
 for source,mapping in MAPS.items():
  scanpath=root/'image_scan'/(source+'.jsonl')
  if not scanpath.exists():raise ValueError('Scan not complete: '+source)
  scanned={r['id']:r for r in map(json.loads,scanpath.read_text().splitlines())}
  inv=json.loads((root/'audits'/source/'inventory.json').read_text(encoding='utf8'))
  assert len(scanned)==len(inv),(source,len(scanned),len(inv))
  for r in inv:
   s=scanned[r['id']];reason=None
   if s.get('error'):reason='decode_or_orientation'
   elif s['palm_count']:reason='suspected_unlabelled_palm'
   elif any(int(b[0]) not in mapping for b in r['boxes']):reason='ambiguous_or_out_of_taxonomy_image'
   elif len(r['boxes'])>10:reason='dense_scene_requires_missing_object_review'
   elif min(s['width'],s['height'])<160:reason='insufficient_resolution'
   elif Path(r['path']).stem.lower() in oldnames[{'bbox384':'sumn2u','trashsort':'codingbear'}.get(source,'')]:reason='historical_source_identity_including_exclusions'
   elif s['image_sha256'] in oldsha or s['sha256_pixels'] in oldpix:reason='historical_exact'
   else:
    distance=lut[(oldph^np.uint64(s['phash'])).view(np.uint8).reshape(-1,8)].sum(1)
    if int(distance.min())<=6:reason='historical_near_or_permanent_exclusion'
   if reason:rejected.append(dict(id=r['id'],source=source,reason=reason));continue
   r.update(s);r['mapped_boxes']=[[mapping[int(b[0])],*b[1:]] for b in r['boxes']];rows.append(r)
  print(source,'eligible',sum(r['source']==source for r in rows),flush=True)
 # Greedy representatives avoid repeated images; connected components include
 # *all* near edges, so a rejected duplicate cannot bridge train and dev.
 n=len(rows);parent=list(range(n));size=[1]*n
 def find(i):
  while parent[i]!=i:parent[i]=parent[parent[i]];i=parent[i]
  return i
 def union(i,j):
  i,j=find(i),find(j)
  if i==j:return
  if size[i]<size[j]:i,j=j,i
  parent[j]=i;size[i]+=size[j]
 ph=np.array([r['phash'] for r in rows],dtype=np.uint64);seenpix={};seenname={};keepers=[]
 for i,r in enumerate(rows):
  if i:
   distance=lut[(ph[:i]^ph[i]).view(np.uint8).reshape(-1,8)].sum(1)
   for j in np.where(distance<=6)[0]:union(i,int(j))
  for value,seen in [(r['sha256_pixels'],seenpix),(r['source']+':'+r['canonical_stem'],seenname)]:
   if value in seen:union(i,seen[value])
   else:seen[value]=i
  if (i+1)%1000==0:print('dedup',i+1,'/',n,flush=True)
 representatives={}
 for i,r in enumerate(rows):
  component=find(i);r['near_component']=component
  # One image per connected near-duplicate group is conservative and gives an
  # honest independent image count (may remove useful distinct white-bg views).
  if component not in representatives:representatives[component]=r
  else:rejected.append(dict(id=r['id'],source=r['source'],reason='public_near_duplicate_component',representative=representatives[component]['id']))
 rows=list(representatives.values())
 # No pseudo hand labels. Group chronological filename blocks when original
 # physical identity is unavailable; report that limitation explicitly.
 for r in rows:
  stem=Path(r['path']).stem
  if r['source']=='drinking':
   m=re.match(r'(AluCan|Glass|HDPEM|PET)([\d,]+)',stem,re.I)
   group='drinking_'+m[1].lower()+'_'+str(int(m[2].replace(',',''))//150) if m else 'drinking_unknown'
  elif r['source']=='batteryobjects':group='batteryobjects_sequence_'+str(int(stem)//100)
  elif r['source']=='trashsort':group='trashsort_original_capture' # Few actual physical items; keep entire source together.
  else:group=r['source']+'_image_'+r['sha256_pixels'][:20]
  r['capture_group']=group
  r['split']='public_dev' if int(hashlib.sha256(group.encode()).hexdigest()[:8],16)%10==0 else 'train'
 (root/'eligible_candidates.json').write_text(json.dumps(rows,indent=2),encoding='utf8')
 (root/'exclusions.json').write_text(json.dumps(rejected,indent=2),encoding='utf8')
 report=dict(admitted_unique_images=len(rows),by_source_split={s:dict(collections.Counter(r['split'] for r in rows if r['source']==s)) for s in MAPS},
  exclusions_by_source={s:dict(collections.Counter(r['reason'] for r in rejected if r['source']==s)) for s in MAPS},
  historical_rows=len(known),historical_unique_phashes=len(oldph),phash_threshold=6,test_files_opened=0,
  annotation_status='Source labels with schema validation, stratified visual audit and palm exclusion. Not per-image human gold.',
  limitations=['Palm screen can miss hands.','Chronological blocks and near duplicates do not establish physical-instance identity.','Class balance will be checked before training.'])
 (root/'candidate_report.json').write_text(json.dumps(report,indent=2),encoding='utf8');print(json.dumps(report),flush=True)
if __name__=='__main__':main()
