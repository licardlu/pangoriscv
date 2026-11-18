"""Freeze explicit visual decisions for source-whitelisted background crops.

This produces additions only; no in-flight training manifest is modified.
"""
import hashlib
import json
from pathlib import Path


def read(p):return json.loads(Path(p).read_text(encoding='utf8'))
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def save(p,x):Path(p).write_text(json.dumps(x,indent=2)+'\n',encoding='utf8')


def main():
    root=Path('build/empty_hand_background_20261118_002').resolve()
    out=root/'reviewed_additions_001';out.mkdir(exist_ok=False)
    labels=out/'labels';labels.mkdir()
    candidates=read(root/'inventory.json')
    basepath=Path('build/wastesense_review_20261118_001/dataset_001/manifest.json')
    base=read(basepath);train={r['image_sha256']:r for r in base if r['split']=='train'}
    heldgroups={str(r.get('capture_group',r.get('group'))) for r in base if r['split'] in ['val','test']}
    history=list(read('build/public_20k_20261117_001/historical_feature_cache.json').values())
    history+=read('build/public_20k_20261117_001/public_dev_001/manifest.json')
    heldph={int(r['phash']) for r in history if r.get('split') in ['val','test','dev'] and 'phash' in r}
    accepted={2,3,4,6,7,8,9,11,12,15};ledger={};additions=[]
    for row in candidates:
        index=int(row['id'].rsplit('_',1)[1]);key=row['id']
        item=dict(source_sha256=row['image_sha256'],reviewer='assistant_visual',
            review_sheet_sha256=sha(root/'review_01.jpg'),
            reason='Clutter/edge content or cropped skin/utensil ambiguous; not admitted as empty.')
        ledger[key]=item
        if index not in accepted:
            item['status']='EXCLUDED_VISUAL_AMBIGUITY';continue
        assert row['whitelist_prepared_sha256'] in train
        original=train[row['whitelist_prepared_sha256']]
        assert original['original_sha256']==row['parent_image_sha256']
        assert row['parent_group']==original['group'] and str(row['parent_group']) not in heldgroups
        assert sha(row['path'])==row['image_sha256'] and sha(row['parent_image'])==row['parent_image_sha256']
        distance=min((bin(int(row['phash'])^ph).count('1') for ph in heldph),default=64)
        item['nearest_recorded_held_phash']=distance
        if distance<=6:
            item.update(status='EXCLUDED_HELD_BACKGROUND_NEAR',reason='Background crop resembles recorded held-out identity.');continue
        item.update(status='VISUALLY_CONFIRMED_EMPTY_NO_HAND_NO_FOREGROUND_WASTE',
            reason='Full crop inspected: fixed room furnishing, wall/ceiling or worn clothing/body; no visible hand, loose waste or unlabelled foreground container. Feet and faces are not hand labels.')
        label=labels/(key+'.txt');label.write_text('',encoding='ascii')
        additions.append(dict(source='reviewed_hagrid_background_crop',origin='empty_context_20261118',
            split='train',stem=key,prepared_image=row['path'],image_sha256=row['image_sha256'],
            sha256_pixels=row['sha256_pixels'],phash=row['phash'],width=row['width'],height=row['height'],
            boxes=[],primary_bin=4,label=str(label),label_sha256=sha(label),
            group=row['parent_group'],capture_group=row['parent_group'],
            parent_image_sha256=row['parent_image_sha256'],parent_whitelist_sha256=row['whitelist_prepared_sha256'],
            crop_xyxy=row['crop_xyxy'],annotation_status=item['status'],
            new_source_photograph=False,derived_empty_crop=True,
            source_url='https://github.com/hukenovs/hagrid',
            license='HaGRID custom dataset agreement; derived from already present source, retain attribution.'))
    save(out/'manifest.json',additions);save(out/'review_ledger.json',ledger)
    save(out/'result.json',dict(status='FROZEN_REVIEWED_ADDITIONS_NOT_YET_TRAINED',
        background_crop_files=len(additions),new_source_photographs=0,
        source_whitelist_manifest_sha256=sha(basepath),review_ledger_sha256=sha(out/'review_ledger.json'),
        test_images_or_labels_opened=False,inflight_experiments_changed=False,
        note='Derived views of existing training source captures. No independent validation or real camera-station captures. Empty worn-clothing/room backgrounds do not establish all clutter is handled.'))
    print(read(out/'result.json'),flush=True)


if __name__=='__main__':main()
