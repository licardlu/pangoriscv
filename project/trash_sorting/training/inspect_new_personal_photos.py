"""Inventory newly supplied original photos and make visual-review sheets.

Never creates labels, chooses splits, runs inference or changes source photos.
Old train/val/test image identities are kept distinct from truly new files.
"""
import argparse
from collections import Counter
import hashlib
import json
import math
from pathlib import Path
from PIL import Image, ImageOps, ImageDraw, ImageFont


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--photos',type=Path,required=True)
    p.add_argument('--known',type=Path,action='append',required=True)
    p.add_argument('--out',type=Path,required=True)
    a=p.parse_args();a.out.mkdir(parents=True,exist_ok=False)
    known={};known_paths={}
    for source in a.known:
        content=json.loads(source.read_text(encoding='utf8'))
        rows=content['images'] if isinstance(content,dict) else content
        for r in rows:
            known[r['sha256']]=str(source)
            known_paths[str(Path(r['path']).resolve()).lower()]=r['sha256']
    paths=sorted((p for p in a.photos.rglob('*') if p.is_file() and p.suffix.lower() in ('.jpg','.jpeg','.png')),key=lambda p:str(p).lower())
    font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',14)
    rows=[];seen={};duplicates=[];old=[];cards=[]
    previews=a.out/'previews';previews.mkdir()
    for path in paths:
        before=path.stat();digest=hashlib.sha256(path.read_bytes()).hexdigest()
        if str(path.resolve()).lower() in known_paths and known_paths[str(path.resolve()).lower()]!=digest:
            raise ValueError('Previously recorded source photo changed: '+str(path))
        if digest in known:
            old.append(dict(path=str(path),sha256=digest,known_inventory=known[digest]));continue
        if digest in seen:
            duplicates.append(dict(path=str(path),sha256=digest,first=seen[digest]));continue
        with Image.open(path) as raw:
            raw_size=list(raw.size);orientation=raw.getexif().get(274,1)
            image=ImageOps.exif_transpose(raw).convert('RGB')
        after=path.stat()
        if (before.st_size,before.st_mtime_ns)!=(after.st_size,after.st_mtime_ns):
            raise ValueError('Photo changed during read: '+str(path))
        idx=len(rows)+1;display_size=list(image.size)
        preview=image.copy();preview.thumbnail((768,768));preview.save(previews/f'N{idx:03d}.jpg',quality=95)
        thumb=image.copy();thumb.thumbnail((216,270))
        card=Image.new('RGB',(224,304),'#eeeeee');card.paste(thumb,((224-thumb.width)//2,(270-thumb.height)//2))
        d=ImageDraw.Draw(card);d.text((3,272),f'N{idx:03d}  '+path.stem[-6:],font=font,fill='black')
        d.text((3,288),str(display_size),font=font,fill='black');cards.append(card)
        rows.append(dict(id=idx,path=str(path.resolve()),file=path.name,sha256=digest,
                         bytes=before.st_size,raw_size=raw_size,orientation=orientation,display_size=display_size,
                         preview=str((previews/f'N{idx:03d}.jpg').resolve()),status='UNREVIEWED_NO_LABELS'))
        seen[digest]=str(path)
        if len(rows)%40==0:print('INVENTORIED_NEW',len(rows),flush=True)
    for start in range(0,len(cards),24):
        batch=cards[start:start+24];sheet=Image.new('RGB',(6*224,math.ceil(len(batch)/6)*304),'white')
        for idx,card in enumerate(batch):sheet.paste(card,((idx%6)*224,(idx//6)*304))
        sheet.save(a.out/f'review_{start//24+1:02d}.jpg',quality=95)
    (a.out/'inventory.json').write_text(json.dumps(dict(status='UNREVIEWED_NO_LABELS',images=rows),indent=2),encoding='utf8')
    report=dict(status='INVENTORIED_NOT_LABELLED',total_image_files=len(paths),known_images=len(old),new_unique_images=len(rows),
        duplicate_new_files=len(duplicates),duplicates=duplicates,known_images_seen=old,
        known_inventories=[dict(path=str(p.resolve()),sha256=hashlib.sha256(p.read_bytes()).hexdigest()) for p in a.known],
        inventory_sha256=hashlib.sha256((a.out/'inventory.json').read_bytes()).hexdigest(),
        source_photos_modified=False,model_inference_performed=False,labels_created=False)
    (a.out/'summary.json').write_text(json.dumps(report,indent=2),encoding='utf8')
    print(json.dumps({k:v for k,v in report.items() if k not in ('known_images_seen','duplicates','known_inventories')}),flush=True)


if __name__=='__main__':main()
