"""Record explicitly selected, complete battery/hand boxes; folder labels are not GT."""
from collections import Counter
import argparse
import hashlib
import json
from pathlib import Path
from PIL import Image
from collect_public_expansion import sheets


def read(path): return json.loads(Path(path).read_text(encoding='utf8'))
def sha(path): return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def save(path,value): Path(path).write_text(json.dumps(value,indent=2)+'\n',encoding='utf8')


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--decisions',type=Path,required=True)
    p.add_argument('--out',type=Path,required=True)
    a=p.parse_args()
    root=Path('build/new_battery_extensions_review_20261118_001/apadoss')
    source=read(root/'inventory.json'); rows=[]; ledger={}
    for sheet,selected in read(a.decisions).items():
        for cell,rectangles in selected.items():
            sheet,cell=int(sheet),int(cell); index=(sheet-1)*24+cell-1;r=source[index]
            assert r['admission']=='PENDING_COMPLETE_BATTERY_HAND_BOX_REVIEW'
            assert sha(r['path'])==r['image_sha256'] and r['historical_nearest_phash']>6
            with Image.open(r['path']) as im:
                assert im.size==(r['width'],r['height']) and im.getexif().get(274,1) in [0,1]
                thumb=im.copy();thumb.thumbnail((350,270))
            ox=(cell-1)%4*360+(360-thumb.width)//2;oy=(cell-1)//4*320
            boxes=[];annotations=[]
            for c,x1,y1,x2,y2 in rectangles:
                assert c in [2,4] and ox-1<=x1<x2<=ox+thumb.width+1 and oy-1<=y1<y2<=oy+thumb.height+1,(sheet,cell,ox,oy,thumb.size,rectangles)
                x1=max(0,(x1-ox)/thumb.width);x2=min(1,(x2-ox)/thumb.width)
                y1=max(0,(y1-oy)/thumb.height);y2=min(1,(y2-oy)/thumb.height)
                boxes.append([c,(x1+x2)/2,(y1+y2)/2,x2-x1,y2-y1])
                annotations.append(dict(category_id=c,bbox=[x1*r['width'],y1*r['height'],(x2-x1)*r['width'],(y2-y1)*r['height']]))
            sheetpath=root/('unreviewed_%02d.jpg'%sheet)
            rows.append(dict(r,boxes=boxes,annotations=annotations,status='MANUAL_BOXES_PENDING_FINAL_OVERLAY_REVIEW',
                category_names={str(i):n for i,n in enumerate(['kitchen','recyclable','hazardous','other','hand'])}))
            ledger[r['id']]=dict(source_sha256=r['image_sha256'],original_sha256=r['original_sha256'],
                sheet=sheet,cell=cell,display_rectangles=rectangles,source_sheet=str(sheetpath.resolve()),source_sheet_sha256=sha(sheetpath),
                coordinate_space='saved_1440x1920_source_review_sheet',reviewer='assistant_visual',source_inventory_sha256=sha(root/'inventory.json'))
    a.out.mkdir(exist_ok=False);save(a.out/'inventory.json',rows);save(a.out/'ledger.json',ledger)
    sheets(rows,a.out,'overlay')
    print(dict(images=len(rows),boxes=dict(Counter(int(b[0]) for r in rows for b in r['boxes'])),training_admitted=0),flush=True)


if __name__=='__main__': main()
