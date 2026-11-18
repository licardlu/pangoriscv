"""Create exact quarter-turn train augmentations; count no new source photos."""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path

from PIL import Image


def read(path):
    return json.loads(Path(path).read_text(encoding='utf8'))


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def rotate_boxes(boxes, turn):
    assert turn in (1, 3)
    # PIL ROTATE_90 is counter-clockwise: (x,y) -> (y,1-x).
    result = []
    for c,x,y,w,h in boxes:
        result.append([c,y,1-x,h,w] if turn==1 else [c,1-y,x,h,w])
    return result


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--base', type=Path, required=True)
    p.add_argument('--out', type=Path, required=True)
    a = p.parse_args()
    out = a.out.resolve()
    out.mkdir(parents=True, exist_ok=False)
    base = read(a.base)
    eligible = {}
    for r in base:
        if r['split']=='train' and r['source'] in ('personal_held_battery','continuation_held_battery'):
            eligible.setdefault(r['image_sha256'],r)
    assert len(eligible)==188
    plan = dict(hypothesis='Battery errors include vertical/horizontal orientation changes. Add exact +/-90-degree versions of all 188 already-whitelisted hand-held battery train photos, transforming every object/hand box. No selection by validation prediction, no new physical objects.',
        base_manifest_sha256=sha(a.base), source_files=188, angles_degrees=[90,270],
        planned_derived_files=376, new_source_photographs=0, draws_per_derived_file=2,
        all_source_groups_stay_train=True, final_test_images_or_labels_read=False)
    (out/'plan.json').write_text(json.dumps(plan,indent=2),encoding='utf8')
    images=out/'images/train';labels=out/'labels/train'
    images.mkdir(parents=True);labels.mkdir(parents=True)
    added=[]
    for parent in sorted(eligible.values(),key=lambda r:r['image_sha256']):
        path=Path(parent['prepared_image'])
        assert sha(path)==parent['image_sha256']
        with Image.open(path) as im:
            assert im.getexif().get(274,1)==1
            rgb=im.convert('RGB')
        for turn,method in [(1,Image.ROTATE_90),(3,Image.ROTATE_270)]:
            rotated=rgb.transpose(method)
            # Independent pixel contract: inverse transpose restores original.
            restored=rotated.transpose(Image.ROTATE_270 if turn==1 else Image.ROTATE_90)
            assert restored.size==rgb.size and restored.tobytes()==rgb.tobytes()
            boxes=rotate_boxes(parent['boxes'],turn)
            assert Counter(int(b[0]) for b in boxes)==Counter(int(b[0]) for b in parent['boxes'])
            inverse=rotate_boxes(boxes,3 if turn==1 else 1)
            assert all(abs(a-b)<1e-12 for row,original in zip(inverse,parent['boxes']) for a,b in zip(row,original))
            for c,x,y,w,h in boxes:
                assert c in range(5) and w>0 and h>0
                assert min(x-w/2,y-h/2)>-1e-6 and max(x+w/2,y+h/2)<1+1e-6
            stem='batteryrot_'+parent['image_sha256'][:20]+'_'+str(turn*90)
            destination=images/(stem+'.png');rotated.save(destination)
            label=labels/(stem+'.txt')
            label.write_text(''.join(str(int(b[0]))+' '+' '.join('%.8f'%v for v in b[1:])+'\n' for b in boxes),encoding='ascii')
            row=dict(parent)
            row.update(source='derived_battery_orientation',origin='battery_orientation_20261118',
                split='train',prepared_image=str(destination),stem=stem,image_sha256=sha(destination),
                width=rotated.width,height=rotated.height,boxes=boxes,label=str(label),label_sha256=sha(label),
                parent_image_sha256=parent['image_sha256'],augmentation_degrees_ccw=turn*90,
                count_as_new_source_photo=False,annotation_status='EXACT_PIXEL_ROTATION_OF_EXISTING_TRAIN_GT')
            for key in ('phash','sha256_pixels','sha256','original_prepared_image'):
                row.pop(key,None)
            added.append(row)
    assert len(added)==376 and len({r['image_sha256'] for r in added})==376
    rows=base+[dict(r,orientation_draw=n) for n in range(2) for r in added]
    assert [r for r in rows if r['split']!='train']==[r for r in base if r['split']!='train']
    (out/'manifest.json').write_text(json.dumps(rows,indent=2),encoding='utf8')
    (out/'additions.json').write_text(json.dumps(added,indent=2),encoding='utf8')
    for split in ('train','val','test'):
        (out/(split+'.txt')).write_text(''.join(r['prepared_image']+'\n' for r in rows if r['split']==split),encoding='utf8')
    (out/'data.yaml').write_text('path: '+out.as_posix()+'\ntrain: train.txt\nval: val.txt\ntest: test.txt\nnc: 5\nnames: [kitchen, recyclable, hazardous, other, hand]\n',encoding='utf8')
    result=dict(plan,status='FROZEN_DERIVED_AUGMENTATIONS_NOT_YET_TRAINED',
        base_train_file_identities=len({r['image_sha256'] for r in base if r['split']=='train'}),
        total_train_file_identities=len({r['image_sha256'] for r in rows if r['split']=='train'}),
        draws_per_epoch=sum(r['split']=='train' for r in rows),val_test_metadata_unchanged=True,
        pixel_inverse_and_all_box_roundtrip_pass=True,
        limitations=['376 augmentations are not new photographs or independent battery objects.',
            'No validation/test image or annotation files read; stored metadata copied unchanged.'])
    (out/'result.json').write_text(json.dumps(result,indent=2),encoding='utf8')
    print(result,flush=True)


if __name__=='__main__':
    main()
