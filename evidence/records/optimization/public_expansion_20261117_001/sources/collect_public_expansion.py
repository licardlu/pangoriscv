"""Fetch public expansion candidates, preserving original labels and source identities.

Nothing is admitted to training here. TACO has no hand labels; every selected
image requires an explicit visual decision before conversion to five classes.
"""
import argparse
import collections
from concurrent.futures import ThreadPoolExecutor
import hashlib
import io
import json
from pathlib import Path
import time
import zipfile

from PIL import Image, ImageDraw, ImageFont
import requests


def sha(data):
    return hashlib.sha256(data).hexdigest()


def sheets(rows, directory, prefix):
    font = ImageFont.truetype('C:/Windows/Fonts/arial.ttf', 15)
    for start in range(0, len(rows), 24):
        canvas = Image.new('RGB', (1440, 1920), '#eeeeee')
        for n, row in enumerate(rows[start:start+24]):
            im = Image.open(row['path']).convert('RGB')
            im.thumbnail((350, 270))
            cell = Image.new('RGB', (360, 320), 'white')
            cell.paste(im, ((360-im.width)//2, 0))
            d = ImageDraw.Draw(cell)
            sx, sy = im.width/row['width'], im.height/row['height']
            ox = (360-im.width)//2
            for b in row.get('annotations', []):
                x,y,w,h = b['bbox']
                d.rectangle((ox+x*sx,y*sy,ox+(x+w)*sx,(y+h)*sy), outline='red', width=2)
                d.text((ox+x*sx,y*sy), row['category_names'][str(b['category_id'])], font=font, fill='red')
            d.text((4,275), row['id'], font=font, fill='black')
            d.text((4,296), f"{row['width']}x{row['height']}", font=font, fill='black')
            canvas.paste(cell, ((n%4)*360, (n//4)*320))
        canvas.save(directory/f'{prefix}_{start//24+1:02}.jpg', quality=94)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--root', type=Path, required=True)
    a = p.parse_args(); root = a.root.resolve()
    out = root/'candidates'; out.mkdir(exist_ok=False)
    coco = json.loads((root/'research/taco_annotations.json').read_text())
    categories = {c['id']:c['name'] for c in coco['categories']}
    anns = collections.defaultdict(list)
    for b in coco['annotations']:
        anns[b['image_id']].append(b)
    # Keep every object in a selected image. Exclude uncertain mixed-waste
    # categories instead of silently making them unlabelled background.
    mapping = {0:1,1:2,2:3,3:3,4:1,5:1,6:1,7:1,8:1,9:1,10:1,11:2,12:1,
        13:1,14:1,15:1,16:1,17:1,18:3,19:3,20:3,21:3,22:3,23:1,24:1,
        25:0,26:1,27:1,28:1,30:1,31:3,32:1,33:1,34:1,35:3,42:3,
        43:1,44:1,45:3,46:3,47:1,48:3,49:3,50:1,51:3,52:1,53:3,
        54:3,55:3,56:3,57:3,59:3}
    focus = {1,6,23,26}
    eligible = [r for r in coco['images'] if any(b['category_id'] in focus for b in anns[r['id']])
                and all(b['category_id'] in mapping for b in anns[r['id']])]
    # Supplement diverse ordinary scenes, rather than adding only glass.
    replay = [r for r in coco['images'] if r not in eligible and anns[r['id']]
              and all(b['category_id'] in mapping for b in anns[r['id']])]
    replay.sort(key=lambda r:sha(str(r['id']).encode()))
    selected = eligible+replay[:48]
    def fetch(row):
        url = row.get('flickr_640_url') or row['flickr_url']
        error = None
        for attempt in range(3):
            try:
                r = requests.get(url, timeout=(12,35)); r.raise_for_status()
                im = Image.open(io.BytesIO(r.content)).convert('RGB'); im.load()
                path = out/f"taco_{row['id']:04}.jpg"
                im.save(path, quality=95)
                w,h = im.size
                if abs(w/h-row['width']/row['height'])>.015:
                    raise ValueError('Thumbnail orientation/aspect differs')
                boxes=[]
                for b in anns[row['id']]:
                    b=dict(b);x,y,bw,bh=b['bbox']
                    b['bbox']=[x*w/row['width'],y*h/row['height'],bw*w/row['width'],bh*h/row['height']]
                    boxes.append(b)
                return dict(id=path.stem,source='taco',source_image_id=row['id'],
                    source_file=row['file_name'],url=url,path=str(path),width=w,height=h,
                    sha256=sha(path.read_bytes()),download_sha256=sha(r.content),
                    annotations=boxes,category_names={str(k):v for k,v in categories.items()},
                    proposed_map=mapping,review_status='UNREVIEWED',license='TACO CC BY 4.0; source image metadata retains license=None',
                    source_commit='70479ad9adc3da971a8ae75ac97eb1026910eec7')
            except Exception as e:
                error=repr(e);time.sleep(.5)
        return dict(id=f"taco_{row['id']:04}",error=error,url=url)
    with ThreadPoolExecutor(max_workers=6) as pool:
        rows=list(pool.map(fetch,selected))
    good=[r for r in rows if 'error' not in r]
    (root/'taco_inventory.json').write_text(json.dumps(rows,indent=2),encoding='utf8')
    sheets(good,out,'taco_review')
    battery=[]
    with zipfile.ZipFile(root/'ewaste_v1.zip') as z:
        # Classification folder is only a discovery aid, never a detection box.
        names=sorted(n for n in z.namelist() if '/train/Battery/' in n)
        for name in names:
            data=z.read(name)
            im=Image.open(io.BytesIO(data)).convert('RGB');im.load()
            path=out/('ewaste_'+Path(name).name);path.write_bytes(data)
            battery.append(dict(id=path.stem,source='ewaste',path=str(path),width=im.width,height=im.height,
                sha256=sha(data),archive_member=name,source_split='train',
                url='https://www.kaggle.com/datasets/akshat103/e-waste-image-dataset',
                license='Apache 2.0 as declared by uploader; mixed upstream sources',
                review_status='UNREVIEWED_CLASSIFICATION_ONLY'))
    (root/'battery_inventory.json').write_text(json.dumps(battery,indent=2),encoding='utf8')
    sheets(battery,out,'battery_review')
    print(json.dumps(dict(taco_downloaded=len(good),taco_failed=len(rows)-len(good),battery_candidates=len(battery))),flush=True)


if __name__=='__main__':main()
