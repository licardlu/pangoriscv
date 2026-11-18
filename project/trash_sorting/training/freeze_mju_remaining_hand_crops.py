"""Freeze only novel complete manually reviewed derived crops; no queue edits."""
import hashlib
import json
from pathlib import Path
import numpy as np


def read(p):return json.loads(Path(p).read_text(encoding='utf8'))
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()


def main():
    root=Path('build/noon_continuation_20261118_001/research/handheld_mirrors_001/mju_train_001/audit_002')
    review=root/'remaining_review_001/hand_crop_annotations_001';rows=read(review/'manifest.json')
    base=Path('build/public_20k_20261117_001');known=[]
    for p in [base/'dataset_004/manifest.json',base/'public_dev_001/manifest.json',
              Path('build/overnight_20261116/dataset_stage4/manifest.json'),
              Path('build/held_background_dev_20261118_001/inventory.json'),
              root/'frozen_hand_crops_001/manifest.json']:
        known+=read(p)
    known+=list(read(base/'historical_feature_cache.json').values())
    ph=np.asarray(sorted({int(r['phash']) for r in known if 'phash' in r}),dtype=np.uint64)
    pixels={r['sha256_pixels'] for r in known if r.get('sha256_pixels')}
    hashes={r.get('image_sha256',r.get('sha256')) for r in known}
    lut=np.asarray([bin(n).count('1') for n in range(256)],dtype=np.uint8)
    out=root/'remaining_review_001/frozen_hand_crops_001';out.mkdir(exist_ok=False);(out/'labels').mkdir()
    admitted=[];decisions=[]
    for row in rows:
        assert sha(row['path'])==row['image_sha256'] and sha(row['source_path'])==row['parent_image_sha256']
        distance=int(lut[(ph^np.uint64(row['phash'])).view(np.uint8).reshape(-1,8)].sum(1).min())
        reason='historical_exact_or_near' if row['image_sha256'] in hashes or row['sha256_pixels'] in pixels or distance<=6 else None
        if any(bin(row['phash']^r['phash']).count('1')<=6 for r in admitted):reason='internal_near'
        decisions.append(dict(id=row['id'],decision=reason or 'REVIEWED_COMPLETE_DERIVED_TRAIN',nearest_phash=distance))
        if reason:continue
        label=out/'labels'/(row['id']+'.txt')
        label.write_text(''.join(str(b[0])+' '+' '.join('%.8f'%v for v in b[1:])+'\n' for b in row['boxes']),encoding='ascii')
        admitted.append(dict(source='reviewed_mju_hand_crop',origin='mju_upstream_train_only',split='train',
            stem=row['id'],prepared_image=row['path'],image_sha256=row['image_sha256'],
            width=row['width'],height=row['height'],boxes=row['boxes'],primary_bin=1,
            label=str(label.resolve()),label_sha256=sha(label),sha256_pixels=row['sha256_pixels'],phash=row['phash'],
            parent_image=row['source_path'],parent_image_sha256=row['parent_image_sha256'],
            source_file=row['source_file'],source_mask_sha256=row['source_mask_sha256'],crop_xyxy=row['crop_xyxy'],
            group='mju_upstream_train_only',capture_group='mju_upstream_train_only',
            historical_nearest_phash=distance,derived_crop=True,new_station_capture=False,
            annotation_status='VISUALLY_REVIEWED_COMPLETE_OBJECT_AND_ALL_CROPPED_HANDS',
            source_url='https://github.com/realwecan/mju-waste',license='MIT copyright2020TaoWang',
            review='96previously unreviewed contact-sheet images,12detail images and4coordinate grids inspected. Explicit crop excludes unlabelled background waste; all final4crop overlays inspected. No new valid/testimages.',
            final_overlay_sha256=sha(review/'overlay.jpg')))
    for name,value in [('manifest.json',admitted),('decisions.json',decisions)]:
        (out/name).write_text(json.dumps(value,indent=2),encoding='utf8')
    result=dict(status='FROZEN_REVIEWED_ADDITIONS_NOT_YET_TRAINED',derived_crops=len(admitted),
        object_boxes=sum(sum(b[0]!=4 for b in r['boxes']) for r in admitted),hand_boxes=sum(sum(b[0]==4 for b in r['boxes']) for r in admitted),
        source_parents=len(admitted),independent_new_photos=0,manifest_sha256=sha(out/'manifest.json'),
        queued_training_manifests_modified=False,test_files_read=False)
    (out/'result.json').write_text(json.dumps(result,indent=2),encoding='utf8');print(result,flush=True)


if __name__=='__main__':main()
