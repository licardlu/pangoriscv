"""Freeze this session's visually reviewed shortlist and original replay split."""
import collections,hashlib,json,os,shutil,sys
from pathlib import Path
from collect_public_expansion import sheets

root=Path(sys.argv[1]).resolve();repo=Path(__file__).resolve().parents[3]
out=root/'dataset_003';out.mkdir(exist_ok=False)
inventory=json.loads((root/'dedup_inventory.json').read_text(encoding='utf8'))
ledger=json.loads((root/'review_screening.json').read_text(encoding='utf8'))
hands={'03663f48','098e104d','0f940cf0','16313395','2a3892ac','2f7c54e3','36846bf0','4f007af9',
       '56174054','654908b7','6b3046f7','858a2b04','98926cbd','9f7608b2','a8f92cfc','aec721c1',
       'bc25d6f1','c2030d8c','c671c519','ccb240aa','d990dbbd','dfa2031d','e773b68c','fbdbb08f'}
# Corrections after inspecting both battery proposal overlay sheets.
corrections={112:[3,10,144,137],17:[30,10,100,112],172:[5,16,143,128],78:[27,17,103,121]}
base=json.loads((repo/'build/continuation_023_dataset_001/manifest.json').read_text(encoding='utf8'))
historical=json.loads((repo/'build/overnight_20261116/dataset_stage4/manifest.json').read_text(encoding='utf8'))
old_groups={str(r.get('capture_group',r.get('group'))) for r in historical}
added=[];overlays=[]
for r in inventory:
    review=ledger['images'].get(r['id'],{})
    if r['source']=='taco' and r['source_image_id'] in (82,685,1497):
        review.update(status='EXCLUDED_FINAL_REVIEW',reason='Ambiguous mixed packaging policy or visible additional unlabelled bottle/edge litter in full overlay review')
    if r['source']=='hagrid':
        selected=r['id'].split('_')[1].split('-')[0] in hands and r['dedup_status']=='NOVEL_CANDIDATE'
        review=dict(status='SELECTED_FOR_BOX_REVIEW' if selected else 'EXCLUDED_SCREENING',sha256=r['sha256'],
            reason='Empty visible hands/person, no visible cup or waste; reviewed source hand boxes' if selected else 'Duplicate source, cup held, or uncertain missing hand annotation',
            boxes_xywh=[[4,*b['bbox']] for b in r['annotations']] if selected else [])
        ledger['images'][r['id']]=review
    if review['status']!='SELECTED_FOR_BOX_REVIEW':continue
    assert r['dedup_status']=='NOVEL_CANDIDATE'
    if r['source']=='ewaste' and int(r['id'].split('_')[-1]) in corrections:
        review['boxes_xywh']=[[2,*corrections[int(r['id'].split('_')[-1])]]]
        review['manual_correction']='Corrected incomplete light battery edge or background-contaminated component'
    review.update(status='VISUALLY_REVIEWED',review_evidence='source contact sheets and battery proposal overlays; four battery boxes corrected manually',
                  annotation_origin='reviewed official COCO' if r['source']=='taco' else 'reviewed official HaGRID' if r['source']=='hagrid' else 'visually reviewed component proposal, manual correction where needed')
    assert hashlib.sha256(Path(r['path']).read_bytes()).hexdigest()==review['sha256']
    w,h=r['width'],r['height'];boxes=[]
    for c,x,y,bw,bh in review['boxes_xywh']:
        x1,y1,x2,y2=max(0,x),max(0,y),min(w,x+bw),min(h,y+bh)
        assert 0<=x1<x2<=w and 0<=y1<y2<=h
        boxes.append([c,(x1+x2)/(2*w),(y1+y2)/(2*h),(x2-x1)/w,(y2-y1)/h])
    if r['source']=='taco':
        group='taco_'+r['source_file'].split('/')[0]
        dev=r['source_file'].split('/')[0] in ('batch_5','batch_13')
    elif r['source']=='hagrid':
        group='hagrid_subject_'+r['subject_id']
        dev=group not in old_groups and int(hashlib.sha256(group.encode()).hexdigest()[:8],16)%4==0
    else:
        group='ewaste_photo_'+r['sha256'][:20]
        dev=int(hashlib.sha256(group.encode()).hexdigest()[:8],16)%5==0
    split='public_dev' if dev else 'train'
    target=out/'images'/split/(r['id']+'.jpg');target.parent.mkdir(parents=True,exist_ok=True)
    try:os.link(r['path'],target)
    except OSError:shutil.copyfile(r['path'],target)
    label=out/'labels'/split/(r['id']+'.txt');label.parent.mkdir(parents=True,exist_ok=True)
    label.write_text(''.join(str(b[0])+' '+' '.join(f'{v:.8f}' for v in b[1:])+'\n' for b in boxes),encoding='ascii')
    row=dict(source='public_expansion_'+r['source'],origin='public_expansion_20261117',split=split,group=group,capture_group=group,
             prepared_image=target.as_posix(),stem=r['id'],boxes=boxes,primary_bin=int(max(boxes,key=lambda b:b[3]*b[4])[0]),
             width=w,height=h,image_sha256=r['sha256'],label_sha256=hashlib.sha256(label.read_bytes()).hexdigest(),
             sha256_pixels=r['sha256_pixels'],phash=r['phash'],source_url=r['url'],license=r['license'],annotation_status='VISUALLY_REVIEWED')
    added.append(row)
    overlays.append({**r,'annotations':[dict(category_id=b[0],bbox=b[1:]) for b in review['boxes_xywh']],
                     'category_names':{str(k):n for k,n in enumerate(['kitchen','recyclable','hazardous','other','hand'])}})
assert added
rows=base+added
for split in ['train','val']:
    (out/(split+'.txt')).write_text(''.join(r['prepared_image']+'\n' for r in rows if r['split']==split),encoding='utf8')
names='nc: 5\nnames: [kitchen, recyclable, hazardous, other, hand]\n'
(out/'data.yaml').write_text(f'path: {out.as_posix()}\ntrain: train.txt\nval: val.txt\n'+names,encoding='utf8')
(out/'manifest.json').write_text(json.dumps(rows,indent=2),encoding='utf8')
(root/'review_ledger.json').write_text(json.dumps(ledger,indent=2),encoding='utf8')
devdir=root/'public_dev_003';devdir.mkdir()
dev=[{**r,'split':'val'} for r in added if r['split']=='public_dev']
(devdir/'manifest.json').write_text(json.dumps(dev,indent=2),encoding='utf8')
(devdir/'val.txt').write_text(''.join(r['prepared_image']+'\n' for r in dev),encoding='utf8')
(devdir/'data.yaml').write_text(f'path: {devdir.as_posix()}\ntrain: val.txt\nval: val.txt\n'+names,encoding='utf8')
train_groups={r.get('capture_group',r.get('group')) for r in rows if r['split']=='train'}
assert not train_groups.intersection(r['group'] for r in dev)
assert [r for r in rows if r['split']=='val']==[r for r in base if r['split']=='val']
assert len({r['image_sha256'] for r in added})==len(added)
sheets(overlays,root/'candidates','final_reviewed')
report=dict(base_train_rows=sum(r['split']=='train' for r in base),old_val_images=sum(r['split']=='val' for r in base),
            total_train_rows=sum(r['split']=='train' for r in rows),new_unique_images=len(added),new_train_images=sum(r['split']=='train' for r in added),
            new_public_dev_images=len(dev),new_by_source_split={s:dict(collections.Counter(r['split'] for r in added if r['source']==s)) for s in sorted({r['source'] for r in added})},
            old_val_unchanged=True,held_out_test_images_opened=0,
            limitation='Public development split uses conservative TACO batches and HaGRID subjects; e-waste source physical identities unknown. Not independent camera or physical-instance accuracy.')
(root/'dataset_report.json').write_text(json.dumps(report,indent=2),encoding='utf8');print(json.dumps(report),flush=True)
