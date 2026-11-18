"""Collect explicitly untrained source batches for reviewed background diagnosis."""
import argparse
from collections import defaultdict
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path

from PIL import Image
import requests

from audit_public_expansion import features
from collect_public_expansion import sheets


def read(path):return json.loads(Path(path).read_text(encoding='utf8'))
def save(path,value):Path(path).write_text(json.dumps(value,indent=2),encoding='utf8')
def digest(data):return hashlib.sha256(data).hexdigest()


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--out',type=Path,required=True)
    a=p.parse_args();out=a.out.resolve();out.mkdir(parents=True,exist_ok=True)
    source=Path('build/quant_tail_20261118_001/research/taco_metadata_001/annotations.json')
    coco=read(source);mapping=read('build/public_targeted_20261118_001/plan.json')['source_to_five_class_map']
    cats={str(c['id']):c['name'] for c in coco['categories']}
    anns=defaultdict(list)
    for annotation in coco['annotations']:anns[annotation['image_id']].append(annotation)
    pool=[im for im in coco['images'] if im['file_name'].split('/')[0] in ('batch_5','batch_13')
          and 1<=len(anns[im['id']])<=4 and all(str(b['category_id']) in mapping for b in anns[im['id']])]
    pool.sort(key=lambda im:digest(im['file_name'].encode()))
    selected=pool[:24]
    plan=dict(purpose='Development diagnostic only: source-disjoint ordinary street waste and empty crops, no new tuning or training admission.',
        held_source_batches=['batch_5','batch_13'],selected_image_ids=[im['id'] for im in selected],
        selection='First24 by SHA256(source filename), 1..4 mapped source boxes. Not chosen by model predictions.',
        metadata_sha256=digest(source.read_bytes()),new_training_images=0,
        final_test_images_or_labels_read=False,all_require_visual_review=True)
    if (out/'plan.json').exists():assert read(out/'plan.json')==plan
    else:save(out/'plan.json',plan)
    images=out/'source';images.mkdir(exist_ok=True);review=out/'review';review.mkdir(exist_ok=True)
    def download(im):
        url=im.get('flickr_640_url') or im['flickr_url']
        path=images/('held_taco_%04d.jpg'%im['id'])
        if not path.exists():
            response=requests.get(url,timeout=(12,35));response.raise_for_status();path.write_bytes(response.content)
        with Image.open(path) as picture:
            assert picture.getexif().get(274,1)==1
            w,h=picture.size
        boxes=[]
        for box in anns[im['id']]:
            x,y,bw,bh=box['bbox']
            boxes.append(dict(category_id=box['category_id'],bbox=[x*w/im['width'],y*h/im['height'],bw*w/im['width'],bh*h/im['height']]))
        return dict(id=path.stem,path=str(path),source_image_id=im['id'],source_file=im['file_name'],source_url=url,
                    width=w,height=h,annotations=boxes,category_names=cats,mapping=mapping,
                    image_sha256=digest(path.read_bytes()),**features(path))
    def attempt(im):
        try:return download(im)
        except Exception as error:return dict(id=im['id'],source_file=im['file_name'],error=repr(error))
    with ThreadPoolExecutor(max_workers=3) as pool:results=list(pool.map(attempt,selected))
    rows=[r for r in results if 'error' not in r]
    save(out/'download_failures.json',[r for r in results if 'error' in r])
    known=[]
    for path in [Path('build/battery_orientation_20261118_001/dataset_001/manifest.json'),
                 Path('build/overnight_20261116/dataset_stage4/manifest.json'),
                 Path('build/public_20k_20261117_001/public_dev_001/manifest.json')]:
        known+=read(path)
    cache=read('build/public_20k_20261117_001/historical_feature_cache.json')
    known+=list(cache.values())
    oldsha={r.get('image_sha256',r.get('sha256')) for r in known}
    oldpixels={r.get('sha256_pixels') for r in known if r.get('sha256_pixels')}
    oldph={int(r['phash']) for r in known if 'phash' in r}
    for row in rows:
        row['historical_exact']=row['image_sha256'] in oldsha or row['sha256_pixels'] in oldpixels
        row['nearest_recorded_historical_phash']=min(bin(int(row['phash'])^p).count('1') for p in oldph)
        row['admission']='REQUIRES_VISUAL_REVIEW' if not row['historical_exact'] and row['nearest_recorded_historical_phash']>6 else 'EXCLUDE_HISTORICAL_NEAR_DUPLICATE'
    save(out/'inventory.json',rows)
    sheets(rows,review,'source_review')
    print(dict(downloaded=len(rows),identity_eligible=sum(r['admission']=='REQUIRES_VISUAL_REVIEW' for r in rows),
               new_train_photos=0,test_files_read=False),flush=True)


if __name__=='__main__':main()
