"""Create deterministic TRAIN/VAL garbage-image sheets for a hand-only audit.

No labels are created. A later preparation step needs explicit reviewed IDs.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--data',type=Path,required=True)
    p.add_argument('--split',choices=('train','val'),required=True)
    p.add_argument('--count',type=int,required=True)
    p.add_argument('--out',type=Path,required=True)
    a=p.parse_args();a.out.mkdir(parents=True,exist_ok=False)
    manifest=a.data/'manifest.json'
    rows=[r for r in json.loads(manifest.read_text(encoding='utf8'))
          if r['split']==a.split and r['source']!='hagrid_hand_localisation']
    rows.sort(key=lambda r:hashlib.sha256((str(r['group'])+r['prepared_image']).encode()).hexdigest())
    rows=rows[:a.count]
    font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',16)
    records=[];cards=[]
    for i,r in enumerate(rows,1):
        path=Path(r['prepared_image']);im=Image.open(path).convert('RGB')
        records.append(dict(review_id=i,path=str(path.resolve()),split=a.split,
            source=r['source'],group=r['group'],sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
        im.thumbnail((250,250));card=Image.new('RGB',(256,284),'#eeeeee')
        card.paste(im,((256-im.width)//2,0))
        ImageDraw.Draw(card).text((5,255),f'{a.split.upper()} REVIEW {i}',font=font,fill='black')
        cards.append(card)
    for start in range(0,len(cards),16):
        batch=cards[start:start+16];sheet=Image.new('RGB',(1024,math.ceil(len(batch)/4)*284),'white')
        for i,card in enumerate(batch):sheet.paste(card,((i%4)*256,(i//4)*284))
        sheet.save(a.out/f'review_{start//16+1:02d}.jpg',quality=95)
    (a.out/'inventory.json').write_text(json.dumps(dict(status='UNREVIEWED_NO_LABELS',
        manifest_sha256=hashlib.sha256(manifest.read_bytes()).hexdigest(),records=records),indent=2),encoding='utf8')
    print('HAND_BACKGROUND_REVIEW_READY',a.split,len(records),flush=True)


if __name__=='__main__':main()
