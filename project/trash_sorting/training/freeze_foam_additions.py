"""Freeze 70 inspected foam scenes without changing held-out data or old labels."""
from collections import Counter
import hashlib
import json
import os
from pathlib import Path


def read(path): return json.loads(Path(path).read_text(encoding='utf8'))
def sha(path): return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def save(path,value): Path(path).write_text(json.dumps(value,indent=2)+'\n',encoding='utf8')


def main():
    root=Path('build/noon_continuation_20261118_001/research/organic_001').resolve()
    review=root/'foam_review_001/object_review_001'
    candidates=read(review/'candidates.json'); ledger=read(review/'ledger.json')
    assert len(candidates)==70
    basepath=root/'reviewed_dataset_001/manifest.json'; base=read(basepath)
    out=root/'reviewed_foam_dataset_001';out.mkdir(exist_ok=False)
    images=out/'images/train';labels=out/'labels/train'
    images.mkdir(parents=True);labels.mkdir(parents=True)
    old={r['image_sha256'] for r in base};additions=[]
    for row in candidates:
        key=row['source_id'];item=ledger[key]; boxes=item['boxes']
        assert item['status']=='PENDING_FINAL_OVERLAY_REVIEW'
        assert sha(row['path'])==row['image_sha256']==item['source_sha256']
        assert row['image_sha256'] not in old;old.add(row['image_sha256'])
        assert row['historical_nearest_phash']>6
        for c,cx,cy,w,h in boxes:
            assert c==3 and w>0 and h>0
            assert min(cx-w/2,cy-h/2)>=-1e-9 and max(cx+w/2,cy+h/2)<=1+1e-9
        path=images/(key+Path(row['path']).suffix);os.link(row['path'],path)
        label=labels/(key+'.txt')
        label.write_text(''.join(str(b[0])+' '+' '.join('%.8f'%v for v in b[1:])+'\n' for b in boxes),encoding='ascii')
        item.update(status='VISUALLY_REVIEWED_COMPLETE_FOAM_OBJECTS',
            final_review='All four initial and three selected overlay sheets inspected. Duplicate source bbox/polygon proposals merged to one extent per visible physical instance. Ambiguous plate/bowl material, unlabelled secondary waste and severe truncation excluded.')
        additions.append(dict(source='reviewed_foam_objects',origin='organic_review_20261118',
            split='train',stem=key,prepared_image=str(path),image_sha256=sha(path),width=row['width'],height=row['height'],
            boxes=boxes,primary_bin=3,label=str(label),label_sha256=sha(label),
            group='caodatan_foam_source_train_only',capture_group='caodatan_foam_source_train_only',
            source_file=row['source_file'],sha256_pixels=row['sha256_pixels'],phash=row['phash'],
            annotation_status=item['status'],source_label_sha256=row['source_label_sha256'],
            source_url='https://www.kaggle.com/datasets/caodatan/waste-organic-inorganic-reclycable-yolov8',
            license='CC0 declared by uploader v1; mixed upstream provenance is not independently established.',
            independent_physical_object=False,new_station_capture=False))
    rows=base+[dict(r,foam_review_draw=n) for n in range(2) for r in additions]
    assert [r for r in rows if r['split']!='train']==[r for r in base if r['split']!='train']
    save(out/'manifest.json',rows);save(out/'additions.json',additions);save(out/'foam_review_ledger.json',ledger)
    for split in ['train','val']:
        (out/(split+'.txt')).write_text(''.join(r['prepared_image']+'\n' for r in rows if r['split']==split),encoding='utf8')
    (out/'data.yaml').write_text('path: '+out.as_posix()+'\ntrain: train.txt\nval: val.txt\nnc: 5\nnames: [kitchen, recyclable, hazardous, other, hand]\n',encoding='utf8')
    report=dict(status='FROZEN_REVIEWED_FUTURE_TRAINING_NOT_YET_TRAINED',base_manifest_sha256=sha(basepath),
        new_source_images=70,new_station_captures=0,derived_background_crops=0,
        unique_file_identities=len({r['image_sha256'] for r in rows if r['split']=='train'}),
        training_draws=sum(r['split']=='train' for r in rows),added_draws_per_file=2,
        new_box_instances=dict(Counter(int(b[0]) for r in additions for b in r['boxes'])),
        dev_rows_unchanged=True,final_test_files_opened=False,review_ledger_sha256=sha(out/'foam_review_ledger.json'),
        final_overlays_sha256={p.name:sha(p) for p in review.glob('overlay_*.jpg')},
        image_count_note='8578 train file identities includes376 rotations,24 background crops and47 upstream augmented fruit views.14194 draws are not independent photos. Added70 foam source files include correlated same-object/background captures. No new station validation and not20000 independently qualified photos.',
        limitations=['Cannot infer all white containers are foam; ambiguous round/printed plates/bowls excluded.',
                    '24 reviewed plastic-bag proposals look synthetically pasted into backgrounds and were not admitted.',
                    'No additional hazardous/hand-held battery or new empty station scenes in this increment.'])
    assert report['unique_file_identities']==8578 and report['training_draws']==14194
    save(out/'result.json',report);print(report,flush=True)


if __name__=='__main__':main()
