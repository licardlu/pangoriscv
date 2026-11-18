"""Audit18verifiedtrain photos against stored historical identity metadata."""
from collections import Counter
import argparse
import hashlib
import json
from pathlib import Path
import numpy as np
from PIL import Image
from audit_public_expansion import features
from collect_public_expansion import sheets


def read(path): return json.loads(path.read_text(encoding='utf8'))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    root = Path('build/noon_continuation_20261118_001/research/battery_visual_001/Fetan-Love_AI-battery-detection-with-yolo_retry_001')
    rows = [r for name in ['train_acquisition_001', 'train_blob_recovery_001']
            for r in read(root/name/'inventory.json') if r['status']=='DOWNLOADED_FOR_REVIEW_NOT_ADMITTED']
    assert len(rows)==18 and len({r['stem'] for r in rows})==18
    base = Path('build/public_20k_20261117_001')
    known = []
    for p in [base/'dataset_004/manifest.json', base/'public_dev_001/manifest.json',
              Path('build/overnight_20261116/dataset_stage4/manifest.json'),
              Path('build/held_background_dev_20261118_001/inventory.json'),
              Path('build/noon_continuation_20261118_001/research/organic_001/reviewed_foam_dataset_001/manifest.json')]:
        known += read(p)
    known += list(read(base/'historical_feature_cache.json').values())
    oldsha = {r.get('image_sha256', r.get('sha256')) for r in known}
    pixels = {r['sha256_pixels'] for r in known if r.get('sha256_pixels')}
    ph = np.asarray(sorted({int(r['phash']) for r in known if 'phash' in r}), dtype=np.uint64)
    lut = np.asarray([bin(n).count('1') for n in range(256)], dtype=np.uint8)
    out = args.out; out.mkdir(exist_ok=False)
    audited = []; novel = []
    for i, source in enumerate(sorted(rows, key=lambda r:r['stem']), 1):
        r = dict(source, path=source['images'], id=f'B{i:02}_'+source['stem'],
                 image_sha256=source['images_sha256'], review_index=i)
        assert r['source_split']=='train'
        assert hashlib.sha256(Path(r['path']).read_bytes()).hexdigest()==r['image_sha256']
        assert hashlib.sha256(Path(r['labels']).read_bytes()).hexdigest()==r['labels_sha256']
        with Image.open(r['path']) as im:
            # Inspect raw-pixel orientation rather than assuming mobile JPEGs
            # need rotation. Any future transform must rotate boxes too.
            w,h=im.size; orientation=im.getexif().get(274,1)
        boxes=[]
        for line in Path(r['labels']).read_text().splitlines():
            values=list(map(float,line.split())); assert len(values)==5 and values[0]==0
            _,cx,cy,bw,bh=values
            assert bw>0 and bh>0 and 0<=cx-bw/2<=cx+bw/2<=1.00001 and 0<=cy-bh/2<=cy+bh/2<=1.00001
            boxes.append([2,cx,cy,bw,bh])
        r.update(width=w,height=h,exif_orientation=orientation,boxes=boxes,**features(Path(r['path'])))
        distance=int(lut[(ph^np.uint64(r['phash'])).view(np.uint8).reshape(-1,8)].sum(1).min())
        dup=next((x['id'] for x in novel if x['sha256_pixels']==r['sha256_pixels'] or bin(x['phash']^r['phash']).count('1')<=6),None)
        reason=('historical_exact' if r['image_sha256'] in oldsha or r['sha256_pixels'] in pixels else
                'historical_near' if distance<=6 else 'internal_near' if dup else None)
        r.update(historical_nearest_phash=distance,duplicate_of=dup,
                 admission='EXCLUDE_'+reason if reason else 'PENDING_COMPLETE_OBJECT_HAND_REVIEW',
                 source_label_empty=not boxes,
                 annotations=[dict(category_id=2,bbox=[(cx-bw/2)*w,(cy-bh/2)*h,bw*w,bh*h]) for _,cx,cy,bw,bh in boxes],
                 category_names={'2':'battery_NEEDS_REVIEW'})
        audited.append(r)
        if reason is None: novel.append(r)
    (out/'inventory.json').write_text(json.dumps(audited,indent=2),encoding='utf8')
    sheets(audited,out,'battery')
    report=dict(downloaded_pairs=18,counts=dict(Counter(r['admission'] for r in audited)),
                training_admitted=0,empty_source_labels=sum(r['source_label_empty'] for r in audited),source_split='train',source_valid_test_contents_read=False,
                historical_metadata_only=True,orientation_counts=dict(Counter(r['exif_orientation'] for r in audited)),
                dataset_license='RootUnlicense; source-photo-specific grant not separately documented',
                capture_group='All18one-session adjacent captures; not18independent objects')
    (out/'result.json').write_text(json.dumps(report,indent=2),encoding='utf8')
    print(report,flush=True)


if __name__=='__main__':main()
