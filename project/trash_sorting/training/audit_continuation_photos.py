"""Identify repacked photos by source SHA and protect historical holdout groups.

Produces resized candidates and review media, never unreviewed training labels.
"""
from pathlib import Path
import argparse,collections,hashlib,io,json,zipfile

def main():
 p=argparse.ArgumentParser();p.add_argument('--workspace',type=Path,required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args()
 from PIL import Image,ImageOps,ImageDraw,ImageFont
 root=a.workspace.resolve();out=a.out.resolve();out.mkdir(parents=True,exist_ok=False)
 rows=json.loads((root/'tmp/dataset_recovery_20261115/combined_inventory.json').read_text(encoding='utf8'))
 assert len({r['sha256'] for r in rows})==len(rows)
 ann=json.loads((root/'tmp/training_continue_20261116/annotations844/manifest.json').read_text(encoding='utf8'))['images']
 known={r['source_sha256']:r for r in ann}
 hist=json.loads((root/'pangoriscv/project/trash_sorting/training/handoff_metadata/selected_045_dataset/manifest.original.json').read_text(encoding='utf8'))
 history=collections.defaultdict(list)
 for r in hist:
  if r.get('original_sha256'):history[r['original_sha256']].append(r)
 protected={r.get('group_id') for r in rows if any(h['split']!='train' for h in history[r['sha256']])}
 protected.discard(None)
 protected_names={r['source'] for r in rows if r.get('group_id') in protected}
 # Validation/test object sequences remain excluded from training in full.
 history_status={}
 for r in rows:
  matches=history[r['sha256']]
  if matches:history_status[r['sha256']]=sorted(set(h['split'] for h in matches))
 (out/'images').mkdir();(out/'previews').mkdir();zips={};result=[]
 try:
  for r in sorted(rows,key=lambda r:(r['source'],r['sha256'])):
   q=dict(r);sha=r['sha256'];q['historical_splits']=history_status.get(sha,[])
   if sha in known:
    q.update(status='ALREADY_IN_006',existing_id=known[sha]['id'],existing_split=known[sha]['split']);result.append(q);continue
   q['status']='PROTECTED_HISTORICAL_GROUP' if r['source'] in protected_names else 'NEEDS_VISUAL_REVIEW'
   q['id']=f'C{len([x for x in result if x.get("id")])+1:04d}'
   archive=r['output_archive'];z=zips.setdefault(archive,None)
   if z is None:z=zips[archive]=zipfile.ZipFile(root/'训练数据集_20261115'/archive)
   data=z.read(r['output_member']);assert hashlib.sha256(data).hexdigest()==sha
   with Image.open(io.BytesIO(data)) as raw:im=ImageOps.exif_transpose(raw).convert('RGB')
   q['original_size']=list(im.size);im.thumbnail((1600,1600))
   path=out/'images'/(q['id']+'.jpg');im.save(path,quality=96,subsampling=0)
   q['image_path']=path.as_posix();q['image_size']=list(im.size);q['image_sha256']=hashlib.sha256(path.read_bytes()).hexdigest()
   im.thumbnail((480,640));preview=out/'previews'/(q['id']+'.jpg');im.save(preview,quality=94)
   q['preview']=preview.as_posix();q['preview_size']=list(im.size)
   matches=[h for h in history[sha] if h.get('repetition',0)==0]
   q['historical_box_candidates']=matches[0]['boxes'] if matches else []
   result.append(q)
   if sum('id' in x for x in result)%100==0:print('PREPARED',sum('id' in x for x in result),flush=True)
 finally:
  for z in zips.values():z.close()
 report={'total_source_images':len(rows),'status_counts':dict(collections.Counter(r['status'] for r in result)),
         'protected_groups':sorted(protected),'historical_exact_matches':dict(collections.Counter(','.join(r['historical_splits']) for r in result if r['historical_splits'])),
         'source_inventory_sha256':hashlib.sha256((root/'tmp/dataset_recovery_20261115/combined_inventory.json').read_bytes()).hexdigest(),
         'training_labels_created':0,'images':result}
 (out/'audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf8')
 print(json.dumps({k:v for k,v in report.items() if k!='images'},ensure_ascii=True),flush=True)
if __name__=='__main__':main()
