"""Explicit hand boxes from the individually inspected 760x780 focus images."""
import json
from pathlib import Path


def main():
    root=Path('build/datacluster_review_20261118_002')
    focus=json.loads((root/'hand_focus_001/inventory.json').read_text())
    path=Path('project/trash_sorting/training/datacluster_decisions_001.json')
    decisions=json.loads(path.read_text())
    rectangles={
        0:[[110,158,560,720]],
        1:[[110,128,498,720]],
        2:[[110,203,437,622]],
        3:[[135,330,518,679]],
        4:[[424,0,650,299]],
        5:[[110,295,519,720]],
        6:[[211,280,533,699]],
        7:[[438,88,653,244]],
        8:[[218,0,542,720]],
        9:[[110,259,494,720]],
        11:[[249,0,439,83]],
        12:[[110,383,344,720]],
        13:[[254,414,555,720]],
        14:[[110,305,477,720]],
        15:[[165,335,373,604],[142,145,213,199],[111,166,155,218]],
        16:[[241,375,481,720]],
        19:[[110,407,412,720]],
        20:[[110,391,418,720]],
    }
    excluded={10:'Unannotated edible produce fills the shop background; cannot establish full instance GT from this image.',
              17:'Black opaque vessel material uncertain (possibly ceramic); no visible hand.'}
    for i,r in enumerate(focus):
        if i in excluded:continue
        entry={k:r[k] for k in ['sheet','cell','source_classes']}
        if i==11:entry['source_classes']=0
        entry.update(visible_hand=i in rectangles,focus_image=r['focus'],
            note='Individually inspected original-resolution display; all visible hands separately outlined. '+
                ('Carrot stick is kitchen, not a toothbrush.' if i==11 else
                 'Visible lower limbs are feet, not hands.' if i in [18,21] else ''))
        entry['extra_normalized_boxes']=[]
        w,h=r['display_size'];ox=r['offset_x']
        for x1,y1,x2,y2 in rectangles.get(i,[]):
            assert ox<=x1<x2<=ox+w and 0<=y1<y2<=h
            entry['extra_normalized_boxes'].append([4,(x1-ox)/w,y1/h,(x2-ox)/w,y2/h])
        assert not any(x['sheet']==r['sheet'] and x['cell']==r['cell'] for x in decisions[r['source']])
        decisions[r['source']].append(entry)
    path.write_text(json.dumps(decisions,indent=2),encoding='utf8')
    (root/'hand_focus_001/review_exclusions.json').write_text(json.dumps(excluded,indent=2),encoding='utf8')
    print(dict(images=sum(map(len,decisions.values())),hand_images=len(rectangles),hand_boxes=sum(map(len,rectangles.values()))),flush=True)


if __name__=='__main__':main()
