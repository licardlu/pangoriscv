"""Freeze individually reviewed glass/hand labels and merge future train draws.

This leaves all in-flight experiments and all development/held-out rows intact.
Copies are hardlinks with original source bytes, not invented new photographs.
"""
from collections import Counter
import hashlib
import json
import os
from pathlib import Path


def read(path):
    return json.loads(Path(path).read_text(encoding='utf8'))


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def save(path,value):
    Path(path).write_text(json.dumps(value,indent=2)+'\n',encoding='utf8')


def main():
    root = Path('build/wastesense_review_20261118_001').resolve()
    source = root/'glass_annotations_003'
    inventory = {r['id']:r for r in read(root/'inventory.json')}
    candidates = read(source/'candidates.json'); ledger = read(source/'ledger.json')
    assert len(candidates) == 58
    assert Counter(int(b[0]) for r in candidates for b in r['mapped_boxes']) == {1:70,4:8}
    out = root/'dataset_001'; out.mkdir(exist_ok=False)
    images,labels = out/'images/train',out/'labels/train'
    images.mkdir(parents=True); labels.mkdir(parents=True)
    basepath = Path('build/extras_battery_candidates_20261118_001/reviewed_dataset_001/manifest.json')
    base = read(basepath)
    multi_path = Path('build/extras_battery_candidates_20261118_001/reviewed_multi_additions_001/manifest.json')
    multi = read(multi_path)
    seen = {r['image_sha256'] for r in base}
    assert len({r['image_sha256'] for r in multi}) == 21
    assert not seen.intersection(r['image_sha256'] for r in multi)
    seen.update(r['image_sha256'] for r in multi)
    additions = []
    for row in candidates:
        key = row['id']; item = ledger[key]; original = inventory[key]
        assert original['admission'] == 'REQUIRES_VISUAL_COMPLETE_INSTANCE_AND_POLICY_REVIEW'
        assert original['historical_nearest_phash'] > 6
        assert sha(row['path']) == row['image_sha256'] == item['source_sha256']
        assert row['image_sha256'] not in seen
        seen.add(row['image_sha256'])
        image = images/(key+Path(row['path']).suffix)
        os.link(row['path'],image)
        boxes = item['boxes']; label = labels/(image.stem+'.txt')
        for c,cx,cy,w,h in boxes:
            assert c in [1,4] and w>0 and h>0
            assert -1e-9<=cx-w/2<cx+w/2<=1+1e-9 and -1e-9<=cy-h/2<cy+h/2<=1+1e-9
        label.write_text(''.join(str(b[0])+' '+' '.join('%.8f'%v for v in b[1:])+'\n' for b in boxes),encoding='ascii')
        actual = [[float(x) for x in line.split()] for line in label.read_text().splitlines()]
        assert len(actual) == len(boxes)
        assert all(abs(a-b)<1e-7 for aa,bb in zip(actual,boxes) for a,b in zip(aa,bb))
        item.update(status='VISUALLY_REVIEWED_COMPLETE_GLASS_AND_HANDS',
            final_review='Final overlay_01..03 checked after enlarged-object corrections; source shadows/reflections do not create new objects.')
        additions.append(dict(source='wastesense_reviewed_glass',origin='wastesense_manual_20261118',
            split='train',stem=key,prepared_image=str(image),image_sha256=sha(image),
            width=row['width'],height=row['height'],boxes=boxes,primary_bin=1,
            label=str(label),label_sha256=sha(label),source_file=row['source_file'],
            source_url='https://www.kaggle.com/datasets/sumn2u/wastesense',
            group='wastesense_whole_source_train_only',capture_group='wastesense_whole_source_train_only',
            annotation_status=item['status'],phash=row['phash'],sha256_pixels=row['sha256_pixels'],
            new_source_image=True,physical_object_identity_unknown=True,
            independent_camera_station_capture=False))
    # Two replay draws per reviewed addition, declared before any training.
    rows = base + [dict(r,reviewed_shape_draw=n) for n in range(2) for r in multi+additions]
    assert [r for r in rows if r['split']!='train'] == [r for r in base if r['split']!='train']
    save(out/'manifest.json',rows);save(out/'additions.json',multi+additions)
    save(out/'glass_review_ledger.json',ledger)
    for split in ['train','val']:
        (out/(split+'.txt')).write_text(''.join(r['prepared_image']+'\n' for r in rows if r['split']==split),encoding='utf8')
    (out/'data.yaml').write_text('path: '+out.as_posix()+'\ntrain: train.txt\nval: val.txt\nnc: 5\nnames: [kitchen, recyclable, hazardous, other, hand]\n',encoding='utf8')
    save(out/'result.json',dict(status='FROZEN_REVIEWED_FUTURE_TRAINING_NOT_YET_TRAINED',
        base_manifest_sha256=sha(basepath),multi_battery_manifest_sha256=sha(multi_path),
        new_glass_source_files=58,new_multi_battery_source_files=21,
        new_box_instances=dict(Counter(int(b[0]) for r in multi+additions for b in r['boxes'])),
        added_draws_per_source_file=2,training_draws=sum(r['split']=='train' for r in rows),
        unique_file_identities=len({r['image_sha256'] for r in rows if r['split']=='train'}),
        current_experiments_changed=False,dev_rows_unchanged=True,final_test_files_opened=False,
        review_ledger_sha256=sha(out/'glass_review_ledger.json'),
        source_inventory_sha256=sha(root/'inventory.json'),
        final_overlay_sha256={p.name:sha(p) for p in source.glob('overlay_*.jpg')},
        image_count_note='8451 training file identities includes earlier376 rotations and14 background crops. 13940 draws is not 13940 independent photos. Added79 source files include product/rendered images and correlated same-object views; no new station or validation captures.',
        limitations=['Source-wide train-only grouping, no proof of independent physical-object identities.',
                    'Mostly glass containers and utensils; no new kitchen/other examples in this addition.',
                    'Source license CC BY-NC4.0; retain original attribution and upstream metadata.']))
    assert read(out/'result.json')['training_draws'] == 13940
    assert read(out/'result.json')['unique_file_identities'] == 8451
    print(read(out/'result.json'),flush=True)


if __name__ == '__main__':
    main()
