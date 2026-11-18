"""Explicit boxes from individually inspected 760x780 large hand views."""
import hashlib
import json
from pathlib import Path


def main():
    root=Path('build/datacluster_glass_review_20261118_001')
    decisions=json.loads((root/'glass_decisions_001.json').read_text())
    focus=json.loads((root/'hand_focus_001/inventory.json').read_text())
    # Visible hand and wrist bounds. Feet and extended forearms are not new hand instances.
    hands={
        (1,1):[(162,259,456,479)],(1,2):[(110,352,502,720)],
        (1,3):[(147,224,550,547)],(1,5):[(164,310,485,651)],
        (1,7):[(140,283,508,635)],(1,11):[(303,125,408,245)],
        (1,13):[(177,125,501,488)],(1,16):[(110,222,500,710)],
        (1,22):[(156,104,524,477)],
        (2,1):[(110,238,499,720)],(2,5):[(132,345,519,622)],
        (2,11):[(230,16,550,396)],(2,12):[(184,206,606,651)],
        (2,15):[(215,241,534,570)],(2,23):[(110,51,481,501)],
        (3,1):[(110,129,438,509)],(3,2):[(192,405,454,720)],
        (3,14):[(110,237,437,704)],(3,16):[(152,223,517,593)],
        (3,17):[(161,254,479,628)],(3,18):[(175,312,469,653)],
        (3,20):[(176,267,497,634)],(3,21):[(203,225,535,590)],
        (4,2):[(177,0,416,79)],
        (4,9):[(178,310,403,510),(349,278,528,474)],
        (4,13):[(110,13,452,339)],(4,15):[(155,209,272,720)],
        (4,17):[(286,96,426,248)],(4,18):[(140,0,555,369)],
        (4,19):[(148,276,637,720)],
        (5,3):[(171,117,650,720)],(5,4):[(120,61,650,720)],
        (5,6):[(110,0,411,451)],(5,7):[(280,306,585,507)],
        (5,8):[(241,255,558,551)],(5,9):[(267,562,478,720)],
        (5,11):[(265,402,650,720)],(5,24):[(214,52,454,385)],
        (6,3):[(176,188,650,720)],(6,6):[(110,289,550,720),(110,62,163,184)],
    }
    excluded={(2,2):'Additional partly visible food/plate; defer full-instance review.',
        (2,19):'Foreground jug and packaging instances require additional policy review.',
        (3,22):'Additional large containers in background need full-instance review.',
        (4,10):'Multiple neighbouring partly occluded containers; defer rather than omit.',
        (4,16):'Glass cup and partially visible package omitted by source labels; defer.',
        (5,10):'Additional partly visible floor container requires review.'}
    def normalize(row,coords):
        x1,y1,x2,y2=coords;w,h=row['display_size'];ox=row['offset_x']
        assert ox<=x1<x2<=ox+w and 0<=y1<y2<=h,(row,coords)
        return [(x1-ox)/w,y1/h,(x2-ox)/w,y2/h]
    for r in focus:
        key=(r['sheet'],r['cell'])
        if key not in hands:
            assert key in excluded;continue
        extras=[[4]+normalize(r,box) for box in hands[key]]
        entry=dict(sheet=r['sheet'],cell=r['cell'],source_classes=1,visible_hand=True,
            extra_normalized_boxes=extras,focus_path=r['focus'],
            focus_sha256=hashlib.sha256(Path(r['focus']).read_bytes()).hexdigest(),
            note='Source and saved larger view inspected; all visible hands explicitly boxed. Pending final overlay review.')
        if key==(2,5):
            # Source top bound missed bottle cap and shoulder.
            entry['source_classes']=[]
            entry['extra_normalized_boxes'].insert(0,[1]+normalize(r,(251,0,509,693)))
        if key==(5,8):
            # Separate small glass bottle at bottom of outdoor scene.
            entry['extra_normalized_boxes'].insert(1,[1]+normalize(r,(487,635,537,712)))
        decisions['glass'].append(entry)
    (root/'glass_decisions_002.json').write_text(json.dumps(decisions,indent=2))
    (root/'focus_exclusions_001.json').write_text(json.dumps([
        dict(sheet=s,cell=c,reason=reason) for (s,c),reason in excluded.items()],indent=2))
    print(dict(selected=len(decisions['glass']),hand_images=len(hands),focus_excluded=len(excluded)))


if __name__=='__main__':main()
