"""Freeze the final inspected fruit/hand labels plus ten reviewed empty crops."""
from collections import Counter
import hashlib
import json
import os
from pathlib import Path


def read(p):return json.loads(Path(p).read_text(encoding='utf8'))
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def save(p,x):Path(p).write_text(json.dumps(x,indent=2)+'\n',encoding='utf8')


def main():
    root=Path('build/noon_continuation_20261118_001/research/organic_001').resolve()
    review=root/'fruit_audit_002/object_review_002'
    candidates=read(review/'candidates.json');ledger=read(review/'ledger.json')
    assert len(candidates)==47
    basepath=Path('build/wastesense_review_20261118_001/dataset_001/manifest.json')
    base=read(basepath)
    out=root/'reviewed_dataset_001';out.mkdir(exist_ok=False)
    images=out/'images/train';labels=out/'labels/train'
    images.mkdir(parents=True);labels.mkdir(parents=True)
    old={r['image_sha256'] for r in base};additions=[]
    for row in candidates:
        key=row['id'];item=ledger[key]
        assert item['status']=='PENDING_FINAL_OVERLAY_REVIEW'
        assert sha(row['path'])==row['image_sha256']==item['source_sha256']
        assert row['image_sha256'] not in old;old.add(row['image_sha256'])
        assert row['historical_nearest_phash']>6
        boxes=item['boxes']
        for c,cx,cy,w,h in boxes:
            assert c in [0,4] and w>0 and h>0
            assert min(cx-w/2,cy-h/2)>=-1e-9 and max(cx+w/2,cy+h/2)<=1+1e-9
        path=images/(key+Path(row['path']).suffix);os.link(row['path'],path)
        label=labels/(key+'.txt')
        label.write_text(''.join(str(b[0])+' '+' '.join('%.8f'%v for v in b[1:])+'\n' for b in boxes),encoding='ascii')
        item.update(status='VISUALLY_REVIEWED_COMPLETE_FRUIT_AND_HANDS',
            final_review='Both final overlays inspected after removing severe truncated banana/lime views and correcting fruit stems/calyx. Five hand-held detail frames include manually drawn visible hand boxes.')
        additions.append(dict(source='reviewed_fruit_complete_objects',origin='organic_review_20261118',
            split='train',stem=key,prepared_image=str(path),image_sha256=sha(path),width=row['width'],height=row['height'],
            boxes=boxes,primary_bin=0,label=str(label),label_sha256=sha(label),
            group='abrars2_fruit_source_train_only',capture_group='abrars2_fruit_source_train_only',
            source_file=row['source_file'],canonical_capture=row['canonical_capture'],
            sha256_pixels=row['sha256_pixels'],phash=row['phash'],annotation_status=item['status'],
            source_url='https://www.kaggle.com/datasets/abrars2/fruit-quality-classificaltion-and-detection',
            license='Apache2.0 according to uploader v1; retain upstream attribution.',
            independent_physical_object=False,upstream_augmented_view=True,new_station_capture=False))
    background=Path('build/empty_hand_background_20261118_002/reviewed_additions_001')
    bg=read(background/'manifest.json');assert len(bg)==10
    for row in bg:
        assert row['boxes']==[] and sha(row['prepared_image'])==row['image_sha256']
        assert sha(row['label'])==row['label_sha256'] and row['image_sha256'] not in old
        old.add(row['image_sha256']);additions.append(row)
    assert Counter(int(b[0]) for r in additions for b in r['boxes'])=={0:47,4:5}
    rows=base+[dict(r,organic_review_draw=n) for n in range(2) for r in additions]
    assert [r for r in rows if r['split']!='train']==[r for r in base if r['split']!='train']
    save(out/'manifest.json',rows);save(out/'additions.json',additions);save(out/'fruit_review_ledger.json',ledger)
    for split in ['train','val']:
        (out/(split+'.txt')).write_text(''.join(r['prepared_image']+'\n' for r in rows if r['split']==split),encoding='utf8')
    (out/'data.yaml').write_text('path: '+out.as_posix()+'\ntrain: train.txt\nval: val.txt\nnc: 5\nnames: [kitchen, recyclable, hazardous, other, hand]\n',encoding='utf8')
    report=dict(status='FROZEN_REVIEWED_FUTURE_TRAINING_NOT_YET_TRAINED',base_manifest_sha256=sha(basepath),
        new_fruit_source_views=47,derived_background_crops=10,new_station_captures=0,
        unique_file_identities=len({r['image_sha256'] for r in rows if r['split']=='train'}),
        training_draws=sum(r['split']=='train' for r in rows),added_draws_per_file=2,
        new_box_instances={0:47,4:5},dev_rows_unchanged=True,final_test_files_opened=False,
        fruit_ledger_sha256=sha(out/'fruit_review_ledger.json'),background_review_sha256=sha(background/'review_ledger.json'),
        final_overlays_sha256={p.name:sha(p) for p in review.glob('overlay_*.jpg')},
        image_count_note='8508 train file identities includes earlier376 rotations,24 background crops and47 new upstream augmented fruit views. 14054draws is not independent photos. Fruits include correlated same-object captures, injected noise and grayscale source augmentation. New physical objects and unaugmented-original count are unknown; not a20000-independent-photo dataset.',
        limitations=['No new other/hazardous glass annotations in this increment; broad class/source gaps persist.',
                    'Added source views contain upstream noise/rotation, with one variant per filename capture; independent object IDs unknown.',
                    'Derived empty room/clothing crops are not independent field background validation.'])
    assert report['unique_file_identities']==8508 and report['training_draws']==14054
    save(out/'result.json',report);print(report,flush=True)


if __name__=='__main__':main()
