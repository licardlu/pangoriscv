"""Explicit visually selected source cells, not a source-wide category mapping.

All rows still require final overlay QA before any training admission.
"""
import json
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont


def main():
    root=Path('build/datacluster_review_20261118_002')
    decisions={}; focus=[]
    selected={
        'plastic':{
            1:{1:[6,8,9,10,16,19,20]},
            2:{1:[42,43,44,45]},
            3:{1:[51,52,54,55],3:[61,62,63,64,65,66,69]},
        },
        'cardboard':{
            1:{1:[1,12,14,16,17,19,20,22,23]},
            2:{1:[27,32,34,37,40,41,42,43,47]},
            3:{1:[51,52,53,54,55,56,57,58,60]},
        },
        'household_clutter':{
            1:{1:[9,19,23],2:[10,11],3:[18]},
            2:{1:[6,7,14],3:[2,24]},
            3:{1:[1,3,11,12,15,18,19]},
            4:{1:[10,15,17,18,20],2:[11],3:[3,19,21]},
            5:{1:[8,10,12,15,16,17,21,24],2:[23],3:[3,9,14,22]},
            6:{0:[16],1:[15,17,20,21,22,23,24],3:[12,18]},
            7:{1:[1,4,5,12,17,18,23,24]},
        },
    }
    # Plastic indices are source file numbers. Cardboard sheet2/3 numbers
    # are cumulative source inventory indices; household cells are local.
    for source,spec in selected.items():
        rows=json.loads((root/source/'inventory.json').read_text())
        decisions[source]=[]
        for sheet,classes in spec.items():
            for c,positions in classes.items():
                for n in positions:
                    cell=n if source=='household_clutter' else n-(sheet-1)*24
                    assert 1<=cell<=24
                    decisions[source].append(dict(sheet=sheet,cell=cell,source_classes=c,visible_hand=False,
                        note='Source scene and full visible instances inspected; retain source boxes for explicit selected policy class. Final overlay review required.'))
    hand_cells={'plastic':[(1,1,1),(1,3,1),(1,17,1),(1,18,1),(2,17,1),(3,5,1),(3,22,3)],
                'cardboard':[(3,1,1)],
                'household_clutter':[(1,8,2),(1,24,1),(3,5,1),(3,7,3),(3,10,1),
                    (4,4,1),(4,12,1),(5,1,1),(5,5,1),(6,5,1),(6,9,3),(7,6,1),(7,19,3),(7,22,1)]}
    font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',16)
    focusdir=root/'hand_focus_001';focusdir.mkdir(exist_ok=False)
    for source,entries in hand_cells.items():
        rows=json.loads((root/source/'inventory.json').read_text())
        for sheet,cell,c in entries:
            r=rows[(sheet-1)*24+cell-1]
            im=Image.open(r['path']).convert('RGB');im.thumbnail((720,720))
            canvas=Image.new('RGB',(760,780),'white');canvas.paste(im,((760-im.width)//2,0))
            draw=ImageDraw.Draw(canvas);draw.text((4,725),r['id'],fill='black',font=font)
            draw.text((4,750),'%s sheet%d cell%d class%d; display%d,%d offset%d'%(source,sheet,cell,c,im.width,im.height,(760-im.width)//2),fill='black',font=font)
            path=focusdir/(r['id']+'.jpg');canvas.save(path,quality=95)
            focus.append(dict(source=source,sheet=sheet,cell=cell,source_classes=c,id=r['id'],focus=str(path),display_size=list(im.size),offset_x=(760-im.width)//2))
    (root/'hand_focus_001/inventory.json').write_text(json.dumps(focus,indent=2),encoding='utf8')
    path=Path('project/trash_sorting/training/datacluster_decisions_001.json')
    assert not path.exists();path.write_text(json.dumps(decisions,indent=2),encoding='utf8')
    print(dict(selected_nohand=sum(map(len,decisions.values())),hand_pending=len(focus)),flush=True)


if __name__=='__main__':main()
