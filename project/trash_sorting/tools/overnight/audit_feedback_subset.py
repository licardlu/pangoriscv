"""Audit a continuation subset against its reviewed parent; flag visual neighbours.

No held-out test image is opened. pHash neighbours require human review and
are not silently classified as duplicate objects or moved between splits.
"""
import argparse
from collections import Counter, defaultdict
import hashlib
import json
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageOps


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def load(path):
    return json.loads(Path(path).read_text(encoding='utf8'))


def group(row):
    return row.get('capture_group') or row.get('group')


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--parent', type=Path, required=True)
    p.add_argument('--subset', type=Path, required=True)
    p.add_argument('--reserved', type=Path, required=True)
    p.add_argument('--calibration', type=Path, required=True)
    p.add_argument('--out', type=Path, required=True)
    a=p.parse_args(); a.out.mkdir(parents=True,exist_ok=False)
    parent=load(a.parent); subset=load(a.subset); reserved=load(a.reserved)
    by_path={str(Path(r['prepared_image']).resolve()):r for r in parent}
    assert len(by_path)==len(parent), 'Repeated parent path'
    assert all(r['split'] in ('train','val') for r in subset)
    subset_paths=set()
    for row in subset:
        path=str(Path(row['prepared_image']).resolve())
        assert path not in subset_paths, 'Repeated subset row'
        subset_paths.add(path)
        assert row==by_path[path], 'Subset changed reviewed parent row: '+path
    assert {r['image_sha256'] for r in subset if r['split']=='val'}=={
        r['image_sha256'] for r in parent if r['split']=='val'}, 'Validation split changed'
    # Check test identities/groups from metadata only. No test pixels/labels.
    identities=defaultdict(set); groups=defaultdict(set)
    for row in parent+reserved:
        identities[row['image_sha256']].add(row['split'])
        if group(row) is not None:groups[str(group(row))].add(row['split'])
    assert all(len(s)==1 for s in identities.values()), 'Byte SHA split leakage'
    assert all(len(s)==1 for s in groups.values()), 'Declared group split leakage'
    rows=[];inspected={};repeated_rows=0
    for row in parent:
        if row['split']=='test':continue
        before=inspected.get(row['image_sha256'])
        assert before is None or (row['split']==before['split'] and row['boxes']==before['boxes']
            and row['label_sha256']==before['label_sha256'] and group(row)==group(before)), 'Conflicting repeated parent image'
        if before is None:rows.append(row);inspected[row['image_sha256']]=row
        else:repeated_rows+=1
    for row in reserved:
        before=inspected.get(row['image_sha256'])
        assert before is None or row==before, 'Conflicting repeated reserved row'
        if before is None:rows.append(row);inspected[row['image_sha256']]=row
    pixels=defaultdict(set); features=[]
    for i,row in enumerate(rows):
        image=Path(row['prepared_image'])
        label=Path(str(image).replace('/images/','/labels/').replace('\\images\\','\\labels\\')).with_suffix('.txt')
        assert sha(image)==row['image_sha256'], str(image)
        assert sha(label)==row['label_sha256'], str(label)
        actual=[[float(v) for v in line.split()] for line in label.read_text(encoding='ascii').splitlines() if line.strip()]
        assert len(actual)==len(row['boxes'])
        for box,expected in zip(actual,row['boxes']):
            assert len(box)==5 and box[0] in range(5)
            assert all(abs(x-y)<=1e-7 for x,y in zip(box,expected))
            _,cx,cy,w,h=box
            assert w>0 and h>0 and -1e-7<=cx-w/2<=cx+w/2<=1.0000001
            assert -1e-7<=cy-h/2<=cy+h/2<=1.0000001
        with Image.open(image) as raw:
            rgb=ImageOps.exif_transpose(raw).convert('RGB')
            pixel_hash=hashlib.sha256(str(rgb.size).encode()+rgb.tobytes()).hexdigest()
            small=np.asarray(rgb.convert('L').resize((32,32),Image.Resampling.LANCZOS),dtype=np.float32)
        pixels[pixel_hash].add(row['split'])
        dct=cv2.dct(small)[:8,:8].copy().reshape(-1)
        bits=dct>np.median(dct[1:]); bits[0]=False
        phash=int.from_bytes(np.packbits(bits).tobytes(),'little')
        features.append(dict(path=str(image.resolve()),split=row['split'],source=row['source'],
            group=group(row),image_sha256=row['image_sha256'],pixel_sha256=pixel_hash,phash=phash,
            reserved=row in reserved))
        if (i+1)%500==0:print(f'SUBSET_AUDIT {i+1}/{len(rows)}',flush=True)
    pixel_leaks=[k for k,s in pixels.items() if len(s)>1]
    assert not pixel_leaks, 'Exact decoded pixel split leakage'
    train_by_path={str(Path(r['prepared_image']).resolve()):r for r in parent if r['split']=='train'}
    calibration=load(a.calibration)['calibration_images']; calibration_hashes=set()
    for row in calibration:
        original=train_by_path[str(Path(row['path']).resolve())]
        assert row['sha256']==original['image_sha256'] and row['sha256'] not in calibration_hashes
        calibration_hashes.add(row['sha256'])
    trains=[r for r in features if r['split']=='train']; vals=[r for r in features if r['split']=='val']
    hashes=np.array([r['phash'] for r in trains],dtype=np.uint64)
    bitcounts=np.array([bin(i).count('1') for i in range(256)],dtype=np.uint8)
    neighbours=[]
    for val in vals:
        xor=np.bitwise_xor(hashes,np.uint64(val['phash']))
        distances=bitcounts[xor.view(np.uint8).reshape(-1,8)].sum(axis=1)
        for j in np.flatnonzero(distances<=6):
            neighbours.append(dict(distance=int(distances[j]),train=trains[int(j)],val=val))
    neighbours.sort(key=lambda r:(r['distance'],r['val']['path'],r['train']['path']))
    # Bounded sheets for review, preserving ALL flagged pair identities in JSON.
    font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',15)
    for start in range(0,min(len(neighbours),96),12):
        sheet=Image.new('RGB',(1440,1032),'#f4f8fc'); draw=ImageDraw.Draw(sheet)
        for j,pair in enumerate(neighbours[start:start+12]):
            x=(j%3)*480; y=(j//3)*258
            draw.text((x+6,y+2),f"pHash distance {pair['distance']} / REVIEW REQUIRED",font=font,fill='#173952')
            for k,key in enumerate(('train','val')):
                row=pair[key]
                with Image.open(row['path']) as raw:
                    im=ImageOps.exif_transpose(raw).convert('RGB'); im.thumbnail((230,210))
                sheet.paste(im,(x+k*240+(240-im.width)//2,y+24))
                draw.text((x+k*240+4,y+235),key+' '+Path(row['path']).stem[:20],font=font,fill='#173952')
        sheet.save(a.out/f'neighbours_{start//12+1:02d}.jpg',quality=94)
    report=dict(status='IDENTITY_PASS_VISUAL_NEIGHBOURS_REQUIRE_REVIEW' if neighbours else 'PASS',
        subset_splits=dict(Counter(r['split'] for r in subset)),parent_inspected_splits=dict(Counter(r['split'] for r in rows)),
        same_split_identical_repeated_parent_rows=repeated_rows,
        subset_rows_identical_to_parent=True,validation_unchanged=True,all_inspected_image_label_sha_verified=True,
        exact_byte_split_leaks=0,exact_decoded_pixel_split_leaks=0,declared_group_split_leaks=0,
        calibration_images=len(calibration),calibration_all_parent_train=True,
        held_out_test_images_opened=0,phash_distance_threshold=6,flagged_pairs=len(neighbours),
        flagged_val_images=len({r['val']['path'] for r in neighbours}),
        automatic_split_or_label_changes=False,
        limitations=['pHash flags similar images; review must establish whether they share a physical object/capture',
            'Declared groups cannot prove physical object identity across days',
            'Metadata test isolation checked without reading test images or labels'],
        inputs={str(p):sha(p) for p in (a.parent,a.subset,a.reserved,a.calibration)})
    for name,value in [('result',report),('features',features),('neighbours',neighbours)]:
        (a.out/(name+'.json')).write_text(json.dumps(value,ensure_ascii=False,indent=2),encoding='utf8')
    print(json.dumps(report,ensure_ascii=False),flush=True)


if __name__=='__main__':main()
