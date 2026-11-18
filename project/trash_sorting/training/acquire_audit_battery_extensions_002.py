"""Acquire only upstream training battery images, audit identity, and prepare review sheets."""
from collections import Counter
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import zipfile
import requests
import numpy as np
from PIL import Image,ImageOps
from audit_public_expansion import features
from collect_public_expansion import sheets


def read(path):return json.loads(Path(path).read_text(encoding='utf8'))
def save(path,data):Path(path).write_text(json.dumps(data,indent=2))
def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def main():
    base=Path('build/joint_battery_resume_20261118_001/research/real_battery_scenes_002')
    out=Path('build/new_battery_extensions_review_20261118_001');out.mkdir(exist_ok=False)
    paths=['build/joint_glass_hand_food_20261118_001/experiment_001/unique_train.json',
        'build/public_20k_20261117_001/public_dev_001/manifest.json',
        'build/overnight_20261116/dataset_stage4/manifest.json',
        'build/held_background_dev_20261118_001/inventory.json',
        'build/public_expansion_20261117_001/dedup_inventory.json',
        'build/public_targeted_20261118_001/identity_audit.json',
        'build/joint_battery_resume_20261118_001/research/mostafa_battery_001/inventory.json',
        'build/extras_battery_candidates_20261118_001/inventory.json']
    known=[r for p in paths for r in read(p)]+list(read('build/public_20k_20261117_001/historical_feature_cache.json').values())
    oldsha={r.get('image_sha256',r.get('sha256')) for r in known};oldsha.update(r.get('original_sha256') for r in known)
    oldpix={r['sha256_pixels'] for r in known if r.get('sha256_pixels')}
    ph=np.array(sorted({int(r['phash']) for r in known if 'phash' in r}),dtype=np.uint64)
    lut=np.array([bin(i).count('1') for i in range(256)],dtype=np.uint8)
    def acquire(key):
        directory=base/key;index=read(directory/'index.json');meta=read(directory/'metadata.json')
        archive=directory/'source.zip'
        if not archive.exists():
            temp=directory/'source.partial'
            with requests.get(index['url'],stream=True,timeout=(12,45)) as response:
                response.raise_for_status()
                with temp.open('xb') as f:
                    for chunk in response.iter_content(1024*1024):f.write(chunk)
            assert temp.stat().st_size==index['archive_bytes'];temp.replace(archive)
        assert archive.stat().st_size==index['archive_bytes']
        raw=directory/'raw_train_battery';raw.mkdir(exist_ok=False)
        originals=[]
        with zipfile.ZipFile(archive) as z:
            assert {(i.filename,i.CRC,i.file_size) for i in z.infolist()}=={(r['name'],r['crc'],r['size']) for r in index['entries']}
            for i in z.infolist():
                parts=Path(i.filename).parts
                if not ('train' in parts and any(s.lower() in ['battery','batteries'] for s in parts)):continue
                if any(s.lower() in ['test','val','valid','validation'] for s in parts):continue
                if Path(i.filename).suffix.lower() not in ['.jpg','.jpeg','.png','.webp']:continue
                path=raw/Path(i.filename).name;assert not path.exists();path.write_bytes(z.read(i))
                originals.append((path,i.filename))
        save(directory/'acquisition.json',dict(source=index['source'],version=index['version'],
            archive_sha256=sha(archive),archive_bytes=archive.stat().st_size,
            extracted_train_battery_images=len(originals),upstream_valid_test_contents_extracted=False,
            images_admitted=0,license=meta['licenseName']))
        oriented=out/(key+'_oriented');oriented.mkdir()
        rows=[]
        for j,(path,name) in enumerate(originals):
            r=dict(id=key+'_'+hashlib.sha256(name.encode()).hexdigest()[:16],source=key,
                source_file=name,source_split='upstream_train_only',original_path=str(path.resolve()),original_sha256=sha(path),
                license=meta['licenseName'],annotations=[],category_names={})
            try:
                with Image.open(path) as im:
                    orientation=im.getexif().get(274,1);r['source_orientation']=orientation
                    if orientation not in [1,0]:
                        normalized=ImageOps.exif_transpose(im).convert('RGB');prepared=oriented/(r['id']+'.png');normalized.save(prepared)
                    else:prepared=path
                with Image.open(prepared) as im:
                    assert im.getexif().get(274,1) in [0,1];w,h=im.size
                r.update(path=str(prepared.resolve()),width=w,height=h,image_sha256=sha(prepared),**features(prepared))
                distance=int(lut[(ph^np.uint64(r['phash'])).view(np.uint8).reshape(-1,8)].sum(1).min())
                r['historical_nearest_phash']=distance
                r['admission']='EXCLUDE_HISTORICAL_EXACT_OR_NEAR' if r['original_sha256'] in oldsha or r['image_sha256'] in oldsha or r['sha256_pixels'] in oldpix or distance<=6 else 'PENDING_COMPLETE_BATTERY_HAND_BOX_REVIEW'
            except Exception as error:r.update(admission='EXCLUDE_DECODE_ORIENTATION',error=repr(error))
            rows.append(r)
            if j%100==0:print(key,j,len(originals),flush=True)
        return rows
    with ThreadPoolExecutor(max_workers=2) as pool:
        rows=[r for chunk in pool.map(acquire,['apadoss','akshat103']) for r in chunk]
    accepted=[]
    for r in rows:
        if not r['admission'].startswith('PENDING_'):continue
        if any(r['sha256_pixels']==x['sha256_pixels'] or bin(r['phash']^x['phash']).count('1')<=6 for x in accepted):r['admission']='EXCLUDE_INTERNAL_NEAR_DUPLICATE'
        else:accepted.append(r)
    save(out/'scanned_inventory.json',rows)
    for key in ['apadoss','akshat103']:
        target=out/key;target.mkdir();selected=[r for r in accepted if r['source']==key]
        save(target/'inventory.json',selected);sheets(selected,target,'unreviewed')
    result=dict(status='CANDIDATES_NOT_TRAINING',source_files=len(rows),counts=dict(Counter(r['admission'] for r in rows)),
        pending_by_source=dict(Counter(r['source'] for r in accepted)),images_admitted=0,
        identity_metadata_sha256={p:sha(p) for p in paths},final_test_files_read=False,
        upstream_valid_test_contents_extracted=False,orientation_normalizations_count_as_same_source_photo=True)
    save(out/'result.json',result);print(result,flush=True)


if __name__=='__main__':main()
