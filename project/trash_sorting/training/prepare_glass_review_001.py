"""Create explicit review selections and large hand-inspection views."""
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont


def main():
    root=Path('build/datacluster_glass_review_20261118_001')
    inventory=json.loads((root/'glass/inventory.json').read_text())
    nohand={1:[12,23],2:[4,14,16,17,18,22,24],3:[6,7,8,9,10,12,15,24],
            4:[1,14,20,21,23],5:[1,5,12,13,14,16,17,21],
            6:[2,5,7,9,10,12,14,15,16,17,18]}
    hand={1:[1,2,3,5,7,11,13,16,22],2:[1,2,5,11,12,15,19,23],
          3:[1,2,14,16,17,18,20,21,22],4:[2,9,10,13,15,16,17,18,19],
          5:[3,4,6,7,8,9,10,11,24],6:[3,6]}
    decisions={'glass':[]};focus=[]
    out=root/'hand_focus_001';out.mkdir(exist_ok=False)
    font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',17)
    for sheet,cells in nohand.items():
        for cell in cells:
            r=inventory[(sheet-1)*24+cell-1]
            assert r['admission'].startswith('PENDING_'),(sheet,cell,r['admission'])
            decisions['glass'].append(dict(sheet=sheet,cell=cell,source_classes=1,visible_hand=False,
                note='Individually inspected source scene. Bottle/can/carton instances recyclable; no visible hands. Pending final-overlay review.'))
    for sheet,cells in hand.items():
        for cell in cells:
            r=inventory[(sheet-1)*24+cell-1]
            if not r['admission'].startswith('PENDING_'):continue
            im=Image.open(r['path']).convert('RGB');im.thumbnail((720,720))
            canvas=Image.new('RGB',(760,780),'white');ox=(760-im.width)//2;canvas.paste(im,(ox,0))
            draw=ImageDraw.Draw(canvas);draw.text((4,725),r['id'],font=font,fill='black')
            draw.text((4,750),f'sheet{sheet} cell{cell} display{im.width},{im.height} offset{ox}',font=font,fill='black')
            path=out/(f's{sheet:02d}_c{cell:02d}.jpg');canvas.save(path,quality=95)
            focus.append(dict(sheet=sheet,cell=cell,id=r['id'],focus=str(path),display_size=list(im.size),offset_x=ox))
    # Coordinates and explicit visible-hand decisions are added after larger-view inspection.
    (out/'inventory.json').write_text(json.dumps(focus,indent=2))
    (root/'glass_decisions_001.json').write_text(json.dumps(decisions,indent=2))
    print(dict(nohand_selected=len(decisions['glass']),hand_pending=len(focus)))


if __name__=='__main__':main()
