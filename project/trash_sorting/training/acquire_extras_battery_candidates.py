"""Acquire a public classification source for manual box review, never auto-label."""
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import zipfile

import requests
from PIL import Image
from audit_public_expansion import features
from collect_public_expansion import sheets


def read(path):return json.loads(Path(path).read_text(encoding='utf8'))
def save(path,v):Path(path).write_text(json.dumps(v,indent=2),encoding='utf8')


def main():
    out=Path('build/extras_battery_candidates_20261118_001').resolve();out.mkdir(exist_ok=True)
    index=read('build/noon_continuation_20261118_001/research/extras_index_001/index.json')
    archive=out/'extras_v1.zip'
    if not archive.exists():
        r=requests.get('https://www.kaggle.com/api/v1/datasets/download/shettysharanyaa/extras?datasetVersionNumber=1',timeout=(15,60))
        r.raise_for_status();assert len(r.content)==index['archive_bytes']
        archive.write_bytes(r.content)
    save(out/'acquisition.json',dict(source='shettysharanyaa/extras',version=1,
        archive_sha256=hashlib.sha256(archive.read_bytes()).hexdigest(),archive_bytes=archive.stat().st_size,
        license_metadata='MIT per Kaggle metadata; preserve attribution; upstream photographic origin not independently established',
        source_metadata='build/noon_continuation_20261118_001/research/shettysharanyaa_extras_metadata.json',
        purpose='Classification images require complete manual detection boxes and identity review; no training admission',
        test_files_read=False))
    raw=out/'raw';raw.mkdir(exist_ok=True)
    with zipfile.ZipFile(archive) as z:
        assert {(i.filename,i.file_size,i.CRC) for i in z.infolist()}=={(e['name'],e['size'],e['crc']) for e in index['entries']}
        entries=[i for i in z.infolist() if i.filename.startswith('battery/') and Path(i.filename).suffix.lower() in ('.jpg','.png','.jpeg')]
        for entry in entries:
            target=raw/Path(entry.filename).name
            if not target.exists():target.write_bytes(z.read(entry))
    known=[]
    for folder in ['overnight_20261116/dataset_stage4','continuation_023_dataset_001',
                   'public_expansion_20261117_001/dataset_003','battery_orientation_20261118_001/dataset_001',
                   'public_20k_20261117_001/public_dev_001']:
        known+=read(Path('build')/folder/'manifest.json')
    known+=list(read('build/public_20k_20261117_001/historical_feature_cache.json').values())
    # Include the entire earlier reviewed candidate pool, not only admitted GT.
    # Rejected blurry/piled/ambiguous examples must not re-enter via a new source.
    known+=read('build/public_expansion_20261117_001/dedup_inventory.json')
    known+=read('build/public_targeted_20261118_001/identity_audit.json')
    oldsha={r.get('image_sha256',r.get('sha256')) for r in known}
    oldpixels={r.get('sha256_pixels') for r in known if r.get('sha256_pixels')}
    oldph={int(r['phash']) for r in known if 'phash' in r}
    def scan(path):
        with Image.open(path) as im:
            assert im.getexif().get(274,1)==1
            w,h=im.size
        f=features(path);digest=hashlib.sha256(path.read_bytes()).hexdigest()
        distance=min(bin(int(f['phash'])^p).count('1') for p in oldph)
        return dict(id=path.stem,path=str(path),width=w,height=h,image_sha256=digest,**f,
            nearest_recorded_historical_phash=distance,
            historical_duplicate=digest in oldsha or f['sha256_pixels'] in oldpixels or distance<=6,
            annotations=[],category_names={},annotation_status='NO_DETECTION_BOXES_NOT_TRAINABLE',
            source_file='battery/'+path.name)
    with ThreadPoolExecutor(max_workers=2) as pool:rows=list(pool.map(scan,sorted(raw.iterdir())))
    kept=[]
    for r in rows:
        if r['historical_duplicate']:
            r['admission']='EXCLUDE_HISTORICAL_OR_PERMANENT_EXCLUSION';continue
        if any(bin(int(r['phash'])^int(k['phash'])).count('1')<=6 or r['sha256_pixels']==k['sha256_pixels'] for k in kept):
            r['admission']='EXCLUDE_CANDIDATE_NEAR_DUPLICATE';continue
        r['admission']='REQUIRES_VISUAL_AND_COMPLETE_BOX_REVIEW';kept.append(r)
    save(out/'inventory.json',rows)
    review=out/'review';review.mkdir(exist_ok=True)
    sheets(kept,review,'classification_candidate')
    save(out/'result.json',dict(raw_battery_files=len(rows),identity_eligible=len(kept),new_training_images=0,
        proposal_label_count=0,all_require_complete_box_review=True,
        no_source_train_test_split=True,test_files_read=False,
        limitations=['224x224 classification pictures; photographs may derive from older waste collections.',
            'No physical-instance identifiers. pHash exclusion is conservative but incomplete.',
            'Do not count these as training images until full objects/hands are manually reviewed and groups frozen.']))
    print(read(out/'result.json'),flush=True)


if __name__=='__main__':main()
