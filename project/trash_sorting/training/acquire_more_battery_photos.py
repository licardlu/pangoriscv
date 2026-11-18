"""Download public battery classification pictures for complete-box review."""
from concurrent.futures import ThreadPoolExecutor
from collections import Counter
import hashlib
import json
from pathlib import Path
import zipfile
import numpy as np
import requests
from PIL import Image
from audit_public_expansion import features
from collect_public_expansion import sheets


def read(path):
    return json.loads(Path(path).read_text(encoding='utf8'))


def main():
    root=Path('build/joint_battery_resume_20261118_001/research/mostafa_battery_001')
    root.mkdir(exist_ok=False)
    url='https://www.kaggle.com/api/v1/datasets/download/mostafaabla/garbage-classification?datasetVersionNumber=1'
    archive=root/'source_v1.zip'
    with requests.get(url,stream=True,timeout=(10,45)) as response:
        response.raise_for_status()
        with archive.open('xb') as stream:
            for chunk in response.iter_content(1024*1024):
                stream.write(chunk)
    assert archive.stat().st_size==250641573
    digest=hashlib.sha256(archive.read_bytes()).hexdigest()
    raw=root/'raw';raw.mkdir()
    with zipfile.ZipFile(archive) as z:
        entries=[i for i in z.infolist() if 'battery' in Path(i.filename).parts and Path(i.filename).suffix.lower() in ['.jpg','.jpeg','.png']]
        assert entries
        assert not any(any(s.lower() in ['test','valid','val'] for s in Path(i.filename).parts) for i in entries)
        for info in entries:
            data=z.read(info)
            (raw/Path(info.filename).name).write_bytes(data)
        (root/'archive_index.json').write_text(json.dumps([dict(name=i.filename,size=i.file_size,crc=i.CRC) for i in z.infolist()],indent=2),encoding='utf8')
    known=[]
    for path in ['build/final_reviewed_increment_20261118_001/dataset_001/manifest.json',
        'build/public_20k_20261117_001/public_dev_001/manifest.json',
        'build/overnight_20261116/dataset_stage4/manifest.json',
        'build/held_background_dev_20261118_001/inventory.json',
        'build/public_expansion_20261117_001/dedup_inventory.json',
        'build/public_targeted_20261118_001/identity_audit.json',
        'build/extras_battery_candidates_20261118_001/inventory.json']:
        known+=read(path)
    known+=list(read('build/public_20k_20261117_001/historical_feature_cache.json').values())
    oldsha={r.get('image_sha256',r.get('sha256')) for r in known}
    oldpix={r['sha256_pixels'] for r in known if r.get('sha256_pixels')}
    ph=np.asarray(sorted({int(r['phash']) for r in known if 'phash' in r}),dtype=np.uint64)
    lut=np.asarray([bin(i).count('1') for i in range(256)],dtype=np.uint8)
    def scan(path):
        row=dict(id='mostafa_'+path.stem,path=str(path.resolve()),source_split='unsplit_train_only')
        try:
            with Image.open(path) as im:
                assert im.getexif().get(274,1)==1
                width,height=im.size
            row.update(width=width,height=height,image_sha256=hashlib.sha256(path.read_bytes()).hexdigest(),**features(path))
            distance=int(lut[(ph^np.uint64(row['phash'])).view(np.uint8).reshape(-1,8)].sum(1).min())
            row.update(historical_nearest_phash=distance,annotations=[],category_names={})
            reason='EXCLUDE_HISTORICAL_EXACT_OR_NEAR' if row['image_sha256'] in oldsha or row['sha256_pixels'] in oldpix or distance<=6 else None
            row['admission']=reason or 'PENDING_COMPLETE_BATTERY_HAND_BOX_REVIEW'
        except Exception as error:
            row.update(admission='EXCLUDE_DECODE_OR_ORIENTATION',error=repr(error))
        return row
    with ThreadPoolExecutor(max_workers=2) as pool:
        rows=list(pool.map(scan,sorted(raw.iterdir())))
    kept=[]
    for row in rows:
        if not row['admission'].startswith('PENDING_'):continue
        if any(row['sha256_pixels']==r['sha256_pixels'] or bin(row['phash']^r['phash']).count('1')<=6 for r in kept):
            row['admission']='EXCLUDE_INTERNAL_NEAR_DUPLICATE'
        else:kept.append(row)
    (root/'inventory.json').write_text(json.dumps(rows,indent=2),encoding='utf8')
    review=root/'review';review.mkdir();sheets(kept,review,'battery')
    report=dict(status='ACQUIRED_FOR_REVIEW_NOT_TRAINED',source_url=url,
        archive_sha256=digest,archive_bytes=archive.stat().st_size,
        source_images=len(rows),counts=dict(Counter(r['admission'] for r in rows)),
        images_admitted=0,source='mostafaabla/garbage-classification v1',
        license='Kaggle metadata: Database Open Database; Contents Copyright Original Authors. Public local review only; preserve photo provenance, no redistribution.',
        limitations='Classification-only; may overlap other public collections; entire source stays train-only, no independent dev claim.',
        final_test_files_read=False)
    (root/'result.json').write_text(json.dumps(report,indent=2),encoding='utf8');print(report,flush=True)


if __name__=='__main__':main()
