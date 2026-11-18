"""Record manual corrections from inspected full-source contact sheets."""
import json
from pathlib import Path
from PIL import Image
from collect_public_expansion import sheets

# Rectangles in the saved proposal sheets (1440x1920), converted to source pixels.
FIX={508:(84,25,278,157),519:(110,674,236,856),531:(95,1019,260,1136),
538:(57,1303,309,1442),550:(74,29,276,190),559:(1152,370,1368,498),
533:(428,993,650,1154),565:(831,650,980,813),578:(799,1306,1004,1437),593:(792,29,1012,196),
596:(1143,16,1376,201),601:(79,292,280,540),611:(431,668,649,825),
621:(803,985,1000,1140),626:(121,1350,219,1498),628:(816,1293,968,1509),
634:(1147,1608,1373,1798),636:(450,35,645,181),
641:(1165,14,1371,175),645:(479,328,604,509),648:(1212,382,1304,463),
656:(62,994,299,1132),659:(1147,969,1372,1168),664:(820,1281,976,1506),
679:(119,321,227,517),685:(1149,321,1366,548),695:(1150,962,1356,1142),
696:(110,1290,258,1495),703:(70,1606,291,1815),707:(454,1640,626,1789),
716:(56,37,300,165),726:(785,0,1020,212),753:(458,348,631,513),
838:(1189,359,1328,496)}


def main():
    root=Path('build/joint_battery_resume_20261118_001/research/mostafa_battery_001')
    source=json.loads((root/'single_proposals_002/inventory.json').read_text())
    out=root/'single_final_review_004';out.mkdir(exist_ok=False)
    rows=[];ledger={}
    for i,r in enumerate(source):
        number=int(r['id'].split('battery')[-1])
        x1,y1,x2,y2=r['proposed_xyxy']
        if number in FIX:
            im=Image.open(r['path']);im.thumbnail((350,270))
            ox=i%4*360+(360-im.width)//2;oy=(i%24)//4*320
            a,b,c,d=FIX[number]
            x1,y1=max(0,(a-ox)*r['width']/im.width),max(0,(b-oy)*r['height']/im.height)
            x2,y2=min(r['width'],(c-ox)*r['width']/im.width),min(r['height'],(d-oy)*r['height']/im.height)
        assert 0<=x1<x2<=r['width'] and 0<=y1<y2<=r['height'],r['id']
        boxes=[[2,(x1+x2)/2/r['width'],(y1+y2)/2/r['height'],(x2-x1)/r['width'],(y2-y1)/r['height']]]
        rows.append(dict(r,boxes=boxes,annotations=[dict(category_id=2,bbox=[x1,y1,x2-x1,y2-y1])],
                         category_names={'2':'battery'},status='FINAL_OVERLAY_REVIEW_PENDING'))
        ledger[r['id']]=dict(source_sha256=r['image_sha256'],final_xyxy=[x1,y1,x2,y2],
            manual_correction=number in FIX,source_proposal_sheet=i//24+1)
    (out/'inventory.json').write_text(json.dumps(rows,indent=2),encoding='utf8')
    (out/'ledger.json').write_text(json.dumps(ledger,indent=2),encoding='utf8')
    sheets(rows,out,'complete_boxes')
    print(dict(single_images=len(rows),manual_corrections=len(FIX)),flush=True)


if __name__=='__main__':main()
