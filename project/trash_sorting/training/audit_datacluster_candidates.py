"""Check acquired VOC labels and identities; all pictures remain review-only."""
from collections import Counter
import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import xml.etree.ElementTree as ET
import numpy as np
from PIL import Image, ImageOps
from audit_public_expansion import features
from collect_public_expansion import sheets


def read(p): return json.loads(Path(p).read_text(encoding='utf8'))


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--normalize-display-orientation',action='store_true')
    parser.add_argument('--base',type=Path,default=Path('build/joint_battery_resume_20261118_001/research/new_detection_indexes_002'))
    parser.add_argument('--out',type=Path)
    parser.add_argument('--source',action='append')
    parser.add_argument('--additional-identity-inventory',type=Path,action='append',default=[])
    args=parser.parse_args()
    base = args.base
    sources=args.source or ['plastic','cardboard','household_clutter']
    out = args.out or Path('build/datacluster_review_20261118_002' if args.normalize_display_orientation else 'build/datacluster_review_20261118_001'); out.mkdir(exist_ok=False)
    if args.normalize_display_orientation:(out/'oriented').mkdir()
    known = list(read('build/public_20k_20261117_001/historical_feature_cache.json').values())
    paths = ['build/joint_balanced_sources_20261118_001/experiment_001/unique_train.json',
             'build/public_20k_20261117_001/public_dev_001/manifest.json',
             'build/overnight_20261116/dataset_stage4/manifest.json',
             'build/held_background_dev_20261118_001/inventory.json',
             'build/public_targeted_20261118_001/identity_audit.json']
    for p in paths: known += read(p)
    for p in args.additional_identity_inventory:known += read(p)
    oldsha = {r.get('image_sha256', r.get('sha256')) for r in known}
    oldsha.update(r.get('original_sha256') for r in known)
    oldpix = {r['sha256_pixels'] for r in known if r.get('sha256_pixels')}
    ph = np.asarray(sorted({int(r['phash']) for r in known if 'phash' in r}), dtype=np.uint64)
    lut = np.asarray([bin(i).count('1') for i in range(256)], dtype=np.uint8)
    candidates = []
    for key in sources:
        raw = Path(read(base/key/'acquisition.json')['raw'])
        labels = {p.stem:p for p in raw.rglob('*.xml')}
        for path in sorted(raw.rglob('*')):
            if path.suffix.lower() in {'.jpg','.jpeg','.png'}:
                candidates.append((key, path, labels[path.stem]))
    def inspect(candidate):
        key, path, label = candidate
        row = dict(id='dc_'+path.stem, path=str(path.resolve()), source=key,
            source_file=path.name, label=str(label.resolve()), source_label_sha256=hashlib.sha256(label.read_bytes()).hexdigest(),
            image_sha256=hashlib.sha256(path.read_bytes()).hexdigest(), source_split='unsplit_train_only')
        try:
            source = ET.parse(label).getroot()
            with Image.open(path) as im:
                orientation=im.getexif().get(274,1)
                original_size=im.size
                if args.normalize_display_orientation:
                    assert orientation in (0,1,3,6,8), 'Unimplemented mirrored orientation'
                    oriented=ImageOps.exif_transpose(im).convert('RGB')
                    w,h=oriented.size
                    if orientation!=1:
                        row['original_path']=str(path.resolve());row['original_sha256']=row['image_sha256']
                        path=(out/'oriented'/(key+'_'+path.stem+'.png')).resolve()
                        oriented.save(path)
                        row.update(path=str(path),image_sha256=hashlib.sha256(path.read_bytes()).hexdigest())
                else:
                    assert orientation == 1
                    w,h = im.size
            label_size=(int(source.findtext('size/width')),int(source.findtext('size/height')))
            assert label_size==(w,h), 'VOC boxes are not in normalized displayed coordinate space; defer explicit geometric review'
            row.update(width=w,height=h,source_orientation=orientation,source_raw_size=original_size,
                annotation_coordinate_space='displayed_VOC_dimensions_verified',**features(path))
            annotations = [];names = {}
            for obj in source.findall('object'):
                name = obj.findtext('name');names[name]=name
                x1,y1,x2,y2 = [float(obj.findtext('bndbox/'+s)) for s in ['xmin','ymin','xmax','ymax']]
                assert -1 <= x1 < x2 <= w+1 and -1 <= y1 < y2 <= h+1
                x1,y1,x2,y2=max(0,x1),max(0,y1),min(w,x2),min(h,y2)
                annotations.append(dict(category_id=name,bbox=[x1,y1,x2-x1,y2-y1]))
            assert annotations
            distance=int(lut[(ph^np.uint64(row['phash'])).view(np.uint8).reshape(-1,8)].sum(1).min())
            row.update(annotations=annotations,category_names=names,historical_nearest_phash=distance,
                admission='EXCLUDE_HISTORICAL_EXACT_OR_NEAR' if row['image_sha256'] in oldsha or row['sha256_pixels'] in oldpix or distance<=6
                else 'PENDING_FOURBIN_HAND_FULLINSTANCE_REVIEW')
        except Exception as error:row.update(admission='EXCLUDE_SCHEMA_OR_ORIENTATION',error=repr(error))
        return row
    with ThreadPoolExecutor(max_workers=2) as pool: rows=list(pool.map(inspect,candidates))
    accepted=[]
    for r in rows:
        if not r['admission'].startswith('PENDING_'):continue
        duplicate=next((x['id'] for x in accepted if x['sha256_pixels']==r['sha256_pixels'] or bin(x['phash']^r['phash']).count('1')<=6),None)
        if duplicate:r.update(admission='EXCLUDE_INTERNAL_NEAR',duplicate_of=duplicate)
        else:accepted.append(r)
    (out/'inventory.json').write_text(json.dumps(rows,indent=2),encoding='utf8')
    for key in sources:
        selected=[r for r in accepted if r['source']==key];directory=out/key;directory.mkdir()
        (directory/'inventory.json').write_text(json.dumps(selected,indent=2),encoding='utf8');sheets(selected,directory,'source_review')
    result=dict(status='SOURCE_LABELS_AND_IDENTITIES_CHECKED_REVIEW_REQUIRED',source_files=len(rows),
        counts=dict(Counter(r['admission'] for r in rows)),pending_by_source=dict(Counter(r['source'] for r in accepted)),
        training_added=0,final_test_files_read=False,source_mapping='None yet; household_trash cannot be mapped to one four-bin category.',
        limitations='Source-wide train-only; mixed objects and unannotated hands require complete visual review.')
    (out/'result.json').write_text(json.dumps(result,indent=2),encoding='utf8');print(result,flush=True)


if __name__ == '__main__': main()
