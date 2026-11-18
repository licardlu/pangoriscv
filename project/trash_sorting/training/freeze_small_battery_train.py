"""Freeze11complete manually reviewed replacement labels, not a training run."""
import hashlib
import json
from pathlib import Path


def sha(path): return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def read(path): return json.loads(path.read_text(encoding='utf8'))


def main():
    root=Path('build/noon_continuation_20261118_001/research/battery_visual_001/Fetan-Love_AI-battery-detection-with-yolo_retry_001/audit_002')
    review=root/'replacement_annotations_001';rows=read(review/'manifest.json')
    assert len(rows)==11 and sum(len(r['boxes']) for r in rows)==41
    out=root/'frozen_additions_001';out.mkdir(exist_ok=False)
    manifest=[]
    for r in rows:
        assert r['source_split']=='train' and r['admission'].startswith('PENDING_')
        assert sha(r['path'])==r['image_sha256'] and sha(r['replacement_label'])==r['replacement_label_sha256']
        manifest.append(dict(source='reviewed_fetan_battery',origin='fetan_upstream_train_only',split='train',
            stem='fetan_'+r['stem'],prepared_image=r['path'],image_sha256=r['image_sha256'],
            width=r['width'],height=r['height'],boxes=r['boxes'],primary_bin=2,
            label=r['replacement_label'],label_sha256=r['replacement_label_sha256'],
            source_label=r['labels'],source_label_sha256=r['labels_sha256'],source_label_empty=r['source_label_empty'],
            sha256_pixels=r['sha256_pixels'],phash=r['phash'],historical_nearest_phash=r['historical_nearest_phash'],
            group='fetan_20251118_single_session',capture_group='fetan_20251118_single_session',
            source_url='https://github.com/Fetan-Love/AI-battery-detection-with-yolo',
            source_tree_sha='7679a920e4dc919c50fdcc437a5ec63b82205cbc',
            license='Repository rootUnlicense; no separate photo-specific declaration found; retain provenance.',
            annotation_status='VISUALLY_REVIEWED_ALL_VISIBLE_BATTERIES_NO_HANDS',
            annotation_note='All18source-train photos reviewed. Source10emptylabels and partial multiobjectlabels are never accepted as background.11selected photos fully reboxed with41battery boxes. Exclude touching pile cases, one edge-cropped image, and one internally near duplicate. Both final overlays inspected.',
            new_station_capture=False,derived_crop=False))
    result=dict(status='FROZEN_REVIEWED_ADDITIONS_NOT_YET_TRAINED',source_images=11,battery_boxes=41,hand_boxes=0,
                source_capture_groups=1,independent_physical_object_count='unknown, same batteries repeatedly photographed',
                root_license='Unlicense',photo_specific_permission_statement_found=False,
                queued_training_manifests_modified=False,test_valid_contents_read=False,
                review_overlays_sha256={p.name:sha(p) for p in review.glob('overlay_*.jpg')},
                exclusion_ledger={'4':'touching pile ambiguous individual extents','5':'touching pile ambiguous individual extents',
                    '12':'right-edge clipped battery','15':'internal near duplicate of14',
                    '16':'touching row deferred','17':'touching row deferred','18':'touching stack deferred'})
    (out/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf8')
    result['manifest_sha256']=sha(out/'manifest.json')
    (out/'result.json').write_text(json.dumps(result,indent=2),encoding='utf8')
    print(result,flush=True)


if __name__=='__main__':main()
