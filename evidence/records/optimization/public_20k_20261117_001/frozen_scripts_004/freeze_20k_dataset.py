"""Freeze screened public additions and replay the latest clean training whitelist.

Counts distinguish independent image identities from repeated training samples.
No amount of repeat sampling is reported as new data.
"""
import collections,hashlib,json,os,shutil,sys
from pathlib import Path
root=Path(sys.argv[1]).resolve();repo=Path(__file__).resolve().parents[3]
out=root/'dataset_001';out.mkdir(exist_ok=False)
base=json.loads((repo/'build/continuation_023_dataset_001/manifest.json').read_text(encoding='utf8'))
candidates=json.loads((root/'eligible_candidates.json').read_text(encoding='utf8'))
screen={r['id']:r for r in map(json.loads,(root/'teacher_hand_screen.jsonl').read_text().splitlines())}
rejected=[];added=[]
for r in candidates:
 assert r['id'] in screen,'Incomplete hand screening'
 reason=None
 if screen[r['id']]['hand_count']:reason='existing_model_flags_unlabelled_hand'
 if r['source']=='bbox384':
  if any(int(b[0]) not in (0,2,6) for b in r['boxes']):reason='paper_cardboard_weak_boxes_or_policy_conflicts'
  if any(s in Path(r['path']).stem.lower() for s in ('fluorescent','nailpolish','lightbulb','lamp')):reason='hazardous_material_inside_glass_category'
  if r['id'] in {'bbox384_bf8fbcc3af3f751e','bbox384_3ff951165d0d8442','bbox384_9a0318453ea3c349'}:reason='visual_sample_incomplete_object_or_missing_hand'
 if reason:rejected.append(dict(id=r['id'],source=r['source'],reason=reason));continue
 src=Path(r['path']);assert hashlib.sha256(src.read_bytes()).hexdigest()==r['image_sha256']
 target=out/'images'/r['split']/(r['id']+src.suffix.lower());target.parent.mkdir(parents=True,exist_ok=True)
 try:os.link(src,target)
 except OSError:shutil.copyfile(src,target)
 label=out/'labels'/r['split']/(r['id']+'.txt');label.parent.mkdir(parents=True,exist_ok=True)
 boxes=r['mapped_boxes'];label.write_text(''.join(str(int(b[0]))+' '+' '.join(f'{v:.8f}' for v in b[1:])+'\n' for b in boxes),encoding='ascii')
 added.append(dict(source='large_public_'+r['source'],origin='public_20k_20261117',split=r['split'],stem=r['id'],
  group=r['capture_group'],capture_group=r['capture_group'],prepared_image=target.as_posix(),boxes=boxes,
  primary_bin=int(max(boxes,key=lambda b:b[3]*b[4])[0]),width=r['width'],height=r['height'],
  image_sha256=r['image_sha256'],sha256_pixels=r['sha256_pixels'],phash=r['phash'],label_sha256=hashlib.sha256(label.read_bytes()).hexdigest(),
  annotation_status='SOURCE_LABELS_SCHEMA_AND_STRATIFIED_VISUAL_AUDIT_PALM_AND_TEACHER_EXCLUSION',source_relative=r['source_relative']))
rows=base+added
# Replay each clean legacy entry twice, and kitchen/other an additional two
# times. Repeated samples are explicit references, never counted as new photos.
train=[r['prepared_image'] for r in rows if r['split']=='train']
replay=[r['prepared_image'] for r in base if r['split']=='train']
minor=[r['prepared_image'] for r in base if r['split']=='train' and int(r['primary_bin']) in (0,3)]
train+=replay+minor*2
(out/'train.txt').write_text(''.join(p+'\n' for p in train),encoding='utf8')
(out/'val.txt').write_text(''.join(r['prepared_image']+'\n' for r in base if r['split']=='val'),encoding='utf8')
names='nc: 5\nnames: [kitchen, recyclable, hazardous, other, hand]\n'
(out/'data.yaml').write_text(f'path: {out.as_posix()}\ntrain: train.txt\nval: val.txt\n'+names,encoding='utf8')
(out/'manifest.json').write_text(json.dumps(rows,indent=2),encoding='utf8')
devdir=root/'public_dev_001';devdir.mkdir(exist_ok=False);dev=[{**r,'split':'val'} for r in added if r['split']=='public_dev']
assert not {r['group'] for r in added if r['split']=='train'}.intersection(r['group'] for r in dev)
assert [r for r in rows if r['split']=='val']==[r for r in base if r['split']=='val']
(devdir/'manifest.json').write_text(json.dumps(dev,indent=2),encoding='utf8')
(devdir/'val.txt').write_text(''.join(r['prepared_image']+'\n' for r in dev),encoding='utf8')
(devdir/'data.yaml').write_text(f'path: {devdir.as_posix()}\ntrain: val.txt\nval: val.txt\n'+names,encoding='utf8')
lookup={r['prepared_image']:r for r in rows}
report=dict(status='FROZEN_FOR_OFFLINE_TRAINING_NOT_DEPLOYMENT',target_images=20000,
 base_train_rows=sum(r['split']=='train' for r in base),base_train_file_identities=len({r['image_sha256'] for r in base if r['split']=='train'}),
 new_unique_images=len(added),new_train_images=sum(r['split']=='train' for r in added),new_dev_images=len(dev),
 total_train_file_identities=len({r['image_sha256'] for r in rows if r['split']=='train'}),
 sampled_training_rows=len(train),sampled_primary_bins=dict(collections.Counter(lookup[p]['primary_bin'] for p in train)),
 new_source_split={s:dict(collections.Counter(r['split'] for r in added if r['source']==s)) for s in sorted({r['source'] for r in added})},
 clean_whitelist_preserved=True,original_val_unchanged=True,test_photos_opened=0,
 limitations=['20k unique accepted images NOT reached; no repeats or augmentation counted as new pictures.',
 'Public source boxes are sampled/audited, not individually human gold. Palm and teacher exclusion may miss hands.',
 'Drinking serial blocks and content hashes isolate views but do not prove physical object independence.',
 '21 historical test rows lack phash; only stored SHA/source identity exclusions are available for those rows.'])
(root/'freeze_report.json').write_text(json.dumps(report,indent=2),encoding='utf8');(root/'final_exclusions.json').write_text(json.dumps(rejected,indent=2),encoding='utf8')
(root/'frozen_inputs_sha256.json').write_text(json.dumps({str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in [out/'manifest.json',out/'train.txt',out/'val.txt',out/'data.yaml',devdir/'manifest.json']},indent=2),encoding='utf8')
print(json.dumps(report),flush=True)
