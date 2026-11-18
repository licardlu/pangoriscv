"""Freeze four reviewed derived hand/garbage crops; do not alter queued data."""
import hashlib
import json
from pathlib import Path
import numpy as np


def read(path):return json.loads(Path(path).read_text(encoding='utf8'))
def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def save(path,value):Path(path).write_text(json.dumps(value,indent=2)+'\n',encoding='utf8')


def main():
    root=Path('build/noon_continuation_20261118_001/research/handheld_mirrors_001/mju_train_001/audit_002')
    review=root/'reviewed_hand_crops_003';rows=read(review/'candidates.json');assert len(rows)==4
    out=root/'frozen_hand_crops_001';out.mkdir(exist_ok=False);(out/'labels').mkdir()
    base=Path('build/public_20k_20261117_001');known=[]
    for p in [base/'dataset_004/manifest.json',base/'public_dev_001/manifest.json',
              Path('build/overnight_20261116/dataset_stage4/manifest.json'),
              Path('build/held_background_dev_20261118_001/inventory.json')]:known+=read(p)
    known+=list(read(base/'historical_feature_cache.json').values())
    oldsha={r.get('image_sha256',r.get('sha256')) for r in known}
    pixels={r['sha256_pixels'] for r in known if r.get('sha256_pixels')}
    ph=np.asarray(sorted({int(r['phash']) for r in known if 'phash' in r}),dtype=np.uint64)
    lut=np.asarray([bin(n).count('1') for n in range(256)],dtype=np.uint8)
    manifest=[]
    for row in rows:
        assert sha(row['path'])==row['image_sha256'] and sha(row['source_path'])==row['source_image_sha256']
        distance=int(lut[(ph^np.uint64(row['phash'])).view(np.uint8).reshape(-1,8)].sum(1).min())
        assert row['image_sha256'] not in oldsha and row['sha256_pixels'] not in pixels and distance>6
        label=out/'labels'/(row['id']+'.txt')
        label.write_text(''.join(str(b[0])+' '+' '.join('%.8f'%v for v in b[1:])+'\n' for b in row['boxes']),encoding='ascii')
        manifest.append(dict(source='reviewed_mju_hand_crop',origin='mju_train_only',split='train',
            stem=row['id'],prepared_image=row['path'],image_sha256=row['image_sha256'],
            width=row['width'],height=row['height'],boxes=row['boxes'],primary_bin=1,
            label=str(label.resolve()),label_sha256=sha(label),group='mju_upstream_train_only',
            capture_group='mju_upstream_train_only',parent_image_sha256=row['source_image_sha256'],
            parent_image=row['source_path'],source_file=row['source_file'],source_mask_sha256=row['source_mask_sha256'],
            crop_xyxy=row['crop_xyxy'],sha256_pixels=row['sha256_pixels'],phash=row['phash'],
            historical_nearest_phash=distance,derived_crop=True,new_station_capture=False,
            source_url='https://github.com/realwecan/mju-waste',license='MIT copyright2020TaoWang; original licence saved alongside acquisition metadata.',
            annotation_status='VISUALLY_REVIEWED_COMPLETE_CROPPED_OBJECT_AND_HANDS',
            review='Full120-image contact sheets and12enlarged originals inspected. Three crop versions retained; final overlay inspected after fixing notebook fingertip extent and bottle boundary. Only four unambiguous recyclables retained; uncertain dirty container excluded. Nearby background waste excluded by explicit crop; no empty label.',
            final_overlay_sha256=sha(review/'overlay.jpg')))
    save(out/'manifest.json',manifest)
    save(out/'result.json',dict(status='FROZEN_REVIEWED_ADDITIONS_NOT_YET_TRAINED',source_parents=4,
        derived_crops=4,independent_new_photos=0,recyclable_boxes=4,hand_boxes=5,
        queued_training_manifests_modified=False,final_test_files_read=False,metadata_identity_checks=True,
        limitation='Four small correlated source-train crops, no battery/kitchen/other augmentation; not proof of field improvement.',
        manifest_sha256=sha(out/'manifest.json')))
    print(read(out/'result.json'),flush=True)


if __name__=='__main__':main()
