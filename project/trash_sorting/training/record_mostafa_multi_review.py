"""Manually outline every visible instance in selected enlarged battery sheets."""
import json
from pathlib import Path
from collect_public_expansion import sheets

# Coordinates on saved1200x1320review sheets, never detector pseudo-labels.
BOXES={
759:[(75,115,178,312),(179,118,254,312),(274,139,331,310),(340,199,392,310),(416,125,532,312)],
760:[(766,91,846,339),(853,228,1074,336)],
767:[(226,526,295,739),(250,613,444,807)],
775:[(823,529,1018,698),(790,599,1006,729),(837,600,1034,764)],
780:[(173,949,302,1191),(207,1061,453,1257)],
788:[(659,959,1012,1255),(786,937,1137,1206)],
797:[(106,580,335,792),(264,550,495,747)],
802:[(780,983,838,1154),(826,981,889,1156),(876,982,936,1158),(927,984,985,1157),
     (705,1101,851,1218),(969,1094,1105,1218)],
805:[(209,142,455,260),(161,191,414,319)],
818:[(65,551,180,765),(185,550,293,765),(293,550,403,764),(408,549,521,765)],
821:[(765,635,947,740),(820,568,961,676),(931,648,1029,733)],
826:[(80,963,227,1224),(229,960,369,1220),(373,961,515,1225)],
839:[(718,982,894,1259),(924,981,1079,1255)],
841:[(142,82,224,358),(220,82,300,359),(299,79,383,362),(379,82,456,364)],
845:[(631,77,819,321),(809,60,970,289),(959,90,1167,335)],
853:[(112,582,373,770),(234,545,489,653)],
866:[(666,501,1103,668),(678,585,1136,801)],
889:[(676,951,1048,1194)],
890:[(126,189,160,308),(196,176,235,310),(277,175,349,315),(387,149,482,320)],
892:[(782,62,881,360),(866,66,953,350),(940,80,1000,343),(993,116,1048,339)],
894:[(135,663,244,779),(249,556,309,769),(324,696,526,774)],
896:[(648,511,734,673),(733,513,819,673),(817,510,903,675),(900,512,982,677),
     (981,510,1067,678),(1067,511,1153,675)],
905:[(142,1007,289,1148),(282,1007,433,1147),(136,1065,291,1225),(284,1071,439,1227)],
907:[(645,970,753,1160),(744,973,846,1160),(837,975,943,1160),(933,976,1041,1162),(1033,968,1148,1162)],
908:[(80,185,357,392),(284,59,451,365)],
918:[(719,49,868,347),(870,82,1098,390)]}


def main():
    root=Path('build/joint_battery_resume_20261118_001/research/mostafa_battery_001')
    lookup={r['id']:r for r in json.loads((root/'inventory.json').read_text())}
    layout=json.loads((root/'multi_review_002/layout.json').read_text())
    out=root/'multi_final_review_001';out.mkdir(exist_ok=False)
    rows=[];ledger={}
    for number,rects in BOXES.items():
        key='mostafa_battery'+str(number);r=lookup[key];x,y,dw,dh=layout[key]['xywh']
        assert r['admission'].startswith('PENDING_')
        boxes=[];annotations=[]
        for a,b,c,d in rects:
            assert x-2<=a<c<=x+dw+2 and y-2<=b<d<=y+dh+2,(key,[a,b,c,d],layout[key])
            aa,bb=max(0,(a-x)/dw),max(0,(b-y)/dh)
            cc,dd=min(1,(c-x)/dw),min(1,(d-y)/dh)
            boxes.append([2,(aa+cc)/2,(bb+dd)/2,cc-aa,dd-bb])
            annotations.append(dict(category_id=2,bbox=[aa*r['width'],bb*r['height'],(cc-aa)*r['width'],(dd-bb)*r['height']]))
        rows.append(dict(r,boxes=boxes,annotations=annotations,category_names={'2':'battery'},status='FINAL_OVERLAY_REVIEW_PENDING'))
        ledger[key]=dict(source_sha256=r['image_sha256'],display_xyxy=rects,sheet=layout[key]['sheet'])
    for number in [789,791,799,800,806,883]:
        ledger['mostafa_battery'+str(number)]=dict(status='DEFERRED_NOT_ADMITTED',
            reason='Dense/occluded instances need more precise review;800includes an edge-truncated extra battery.')
    (out/'inventory.json').write_text(json.dumps(rows,indent=2),encoding='utf8')
    (out/'ledger.json').write_text(json.dumps(ledger,indent=2),encoding='utf8')
    sheets(rows,out,'complete_boxes')
    print(dict(images=len(rows),boxes=sum(len(r['boxes']) for r in rows)),flush=True)


if __name__=='__main__':main()
