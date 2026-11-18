"""Record explicit source-sheet decisions; never infer complete GT from a folder."""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
from PIL import Image
from collect_public_expansion import sheets


def read(path): return json.loads(Path(path).read_text(encoding='utf8'))
def sha(path): return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--decisions', type=Path, required=True)
    p.add_argument('--out', type=Path, required=True)
    p.add_argument('--root', type=Path, default=Path('build/datacluster_review_20261118_002'))
    a=p.parse_args(); root=a.root
    decisions=read(a.decisions); rows=[]; ledger={}
    for source, selected in decisions.items():
        inventory=read(root/source/'inventory.json')
        for entry in selected:
            sheet,cell=entry['sheet'],entry['cell']
            assert sheet>=1 and 1<=cell<=24
            index=(sheet-1)*24+cell-1; r=inventory[index]
            assert r['admission']=='PENDING_FOURBIN_HAND_FULLINSTANCE_REVIEW'
            assert sha(r['path'])==r['image_sha256'] and r['historical_nearest_phash']>6
            assert r['id'] not in ledger
            with Image.open(r['path']) as full:
                assert full.size==(r['width'],r['height']) and full.getexif().get(274,1)==1
                thumbnail=full.copy(); thumbnail.thumbnail((350,270))
            ox=(cell-1)%4*360+(360-thumbnail.width)//2; oy=(cell-1)//4*320
            boxes=[]; annotations=[]
            def add(c,x1,y1,x2,y2):
                assert c in range(5) and 0<=x1<x2<=r['width'] and 0<=y1<y2<=r['height'],(r['id'],c,x1,y1,x2,y2)
                boxes.append([c,(x1+x2)/2/r['width'],(y1+y2)/2/r['height'],(x2-x1)/r['width'],(y2-y1)/r['height']])
                annotations.append(dict(category_id=c,bbox=[x1,y1,x2-x1,y2-y1]))
            classes=entry.get('source_classes',[])
            if isinstance(classes,int):classes=[classes]*len(r['annotations'])
            if classes:
                assert len(classes)==len(r['annotations'])
                for c,b in zip(classes,r['annotations']):
                    x,y,w,h=b['bbox'];add(c,x,y,x+w,y+h)
            for c,x1,y1,x2,y2 in entry.get('extra_sheet_boxes',[]):
                assert ox-1<=x1<x2<=ox+thumbnail.width+1 and oy-1<=y1<y2<=oy+thumbnail.height+1,(r['id'],ox,oy,thumbnail.size)
                add(c,max(0,(x1-ox)/thumbnail.width)*r['width'],max(0,(y1-oy)/thumbnail.height)*r['height'],
                    min(1,(x2-ox)/thumbnail.width)*r['width'],min(1,(y2-oy)/thumbnail.height)*r['height'])
            for c,x1,y1,x2,y2 in entry.get('extra_normalized_boxes',[]):
                add(c,x1*r['width'],y1*r['height'],x2*r['width'],y2*r['height'])
            assert boxes and entry['visible_hand']==any(int(b[0])==4 for b in boxes)
            sheetpath=root/source/('source_review_%02d.jpg'%sheet)
            rows.append(dict(r,boxes=boxes,annotations=annotations,
                category_names={str(i):n for i,n in enumerate(['kitchen','recyclable','hazardous','other','hand'])},
                status='EXPLICIT_MANUAL_DECISION_PENDING_FINAL_OVERLAY'))
            ledger[r['id']]=dict(entry,source_sheet=str(sheetpath),source_sheet_sha256=sha(sheetpath),
                normalized_source_sha256=r['image_sha256'],original_source_sha256=r.get('original_sha256',r['image_sha256']),
                source_label_sha256=r['source_label_sha256'],source_inventory_index=index,
                reviewer='assistant_visual',coordinate_space='saved_1440x1920_source_review_sheet',
                source_inventory_sha256=sha(root/source/'inventory.json'))
    a.out.mkdir(exist_ok=False)
    (a.out/'inventory.json').write_text(json.dumps(rows,indent=2),encoding='utf8')
    (a.out/'ledger.json').write_text(json.dumps(ledger,indent=2),encoding='utf8')
    sheets(rows,a.out,'overlay')
    print(dict(manually_decided_images=len(rows),boxes=dict(Counter(int(b[0]) for r in rows for b in r['boxes'])),training_added=0),flush=True)


if __name__=='__main__':main()
