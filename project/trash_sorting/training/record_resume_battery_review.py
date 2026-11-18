"""Record inspected single boxes and manually outlined visible battery instances."""
import hashlib
import json
from pathlib import Path
from PIL import Image
from collect_public_expansion import sheets

# Coordinates refer to the saved 1200x1320 review sheets, not model predictions.
BOXES={
19:[(202,91,282,358),(303,91,383,357)],
22:[(729,137,802,276),(819,164,876,274),(889,168,922,276),(939,182,965,276),(979,189,998,276),(1011,170,1071,276)],
34:[(254,538,305,724),(304,537,356,725)],
37:[(734,485,830,825),(770,721,1077,834)],
42:[(210,945,286,1258),(311,944,386,1257)],
48:[(630,965,900,1224),(899,971,1174,1237)],
50:[(169,103,237,339),(235,103,302,339),(300,103,367,339),(365,103,431,339)],
52:[(729,81,793,290),(810,69,884,257),(849,224,1019,331),(954,278,1084,363)],
53:[(211,559,257,754),(243,567,284,763),(271,575,313,772),(304,578,360,781)],
54:[(708,540,817,760),(786,532,880,757),(868,538,948,757),(939,528,1025,754)],
56:[(214,1003,265,1213),(259,1003,302,1215),(308,1002,357,1214),(349,1003,395,1214)],
57:[(744,935,834,1209),(823,935,909,1213),(890,1074,974,1267),(974,1075,1064,1268)],
58:[(145,87,222,351),(218,87,296,351),(289,87,365,351),(359,87,440,351)],
59:[(844,49,916,269),(908,51,969,269)],
65:[(145,509,270,774),(191,637,460,808)],
70:[(818,586,868,761),(868,585,921,741),(916,586,967,732),(850,713,1020,788)],
82:[(127,938,315,1155),(268,949,489,1223)],
163:[(681,922,784,1276),(790,922,895,1276),(902,921,1008,1276),(1016,921,1119,1276)],
198:[(731,85,1042,301),(815,54,1133,258)],
209:[(168,565,365,702),(220,622,421,763)],
212:[(626,541,735,740),(754,561,795,738),(819,535,879,740),(907,531,1011,740),(1044,485,1177,739)],
214:[(129,1013,222,1193),(253,1037,301,1193),(341,1059,379,1192),(411,1084,468,1192)],
227:[(701,941,800,1265),(801,941,902,1266),(904,941,1006,1266),(1008,941,1105,1266)],
236:[(767,95,908,367),(901,97,1039,362)],
241:[(98,583,191,760),(197,603,235,760),(241,582,293,762),(300,582,386,766),(393,543,507,768)],
242:[(678,486,777,831),(792,487,891,831),(906,486,1007,831),(1020,487,1120,831)],
243:[(74,950,501,1073),(101,1047,528,1170)]}


def main():
    root=Path('build/joint_battery_resume_20261118_001/research/extras_remaining_001')
    source=json.loads((root/'single_proposals_001/inventory.json').read_text())
    lookup={r['id']:r for r in json.loads((root/'inventory.json').read_text())}
    layout=json.loads((root/'multi_review_002/layout.json').read_text())
    out=root/'final_review_001';out.mkdir(exist_ok=False)
    # These pictures have cropped bodies/leads or a source frame that prevents
    # an unambiguous complete battery box. Keep exclusions as explicit evidence.
    excluded={284:'cropped attached lead',286:'cropped battery body',295:'cropped battery body',
              300:'edge-truncated tip',364:'cropped right body',387:'cropped far end',
              445:'cropped ends',470:'edge-truncated pack'}
    rows=[];ledger={}
    for r in source:
        number=int(r['id'].replace('battery',''))
        if number in excluded:
            ledger[r['id']]=dict(status='EXCLUDED_AFTER_OVERLAY_REVIEW',reason=excluded[number]);continue
        x1,y1,x2,y2=r['proposed_xyxy']
        if number==276:x1,y1,x2,y2=17,42,289,116
        row=dict(r,boxes=[[2,(x1+x2)/2/r['width'],(y1+y2)/2/r['height'],(x2-x1)/r['width'],(y2-y1)/r['height']]],
            annotations=[dict(category_id=2,bbox=[x1,y1,x2-x1,y2-y1])],
            category_names={'2':'battery'},status='FINAL_OVERLAY_READY')
        rows.append(row)
        ledger[r['id']]=dict(status='SINGLE_BOX_INSPECTED',source_sha256=r['image_sha256'],
            final_xyxy=[x1,y1,x2,y2],correction='tighten watermark border' if number==276 else None)
    for number,rectangles in BOXES.items():
        key='battery'+str(number);r=lookup[key];x,y,dw,dh=layout[key]['xywh']
        boxes=[];annotations=[]
        for a,b,c,d in rectangles:
            assert x-2<=a<c<=x+dw+2 and y-2<=b<d<=y+dh+2,(key,[a,b,c,d],layout[key])
            aa,bb=max(0,(a-x)/dw),max(0,(b-y)/dh)
            cc,dd=min(1,(c-x)/dw),min(1,(d-y)/dh)
            assert aa<cc and bb<dd
            boxes.append([2,(aa+cc)/2,(bb+dd)/2,cc-aa,dd-bb])
            annotations.append(dict(category_id=2,bbox=[aa*r['width'],bb*r['height'],(cc-aa)*r['width'],(dd-bb)*r['height']]))
        rows.append(dict(r,boxes=boxes,annotations=annotations,category_names={'2':'battery'},status='FINAL_OVERLAY_READY'))
        ledger[key]=dict(status='MANUAL_INSTANCE_BOXES_RECORDED',source_sha256=r['image_sha256'],display_xyxy=rectangles,
                        sheet=layout[key]['sheet'],boxes=boxes)
    for number in [196,235]:
        ledger['battery'+str(number)]=dict(status='DEFERRED_DENSE_INSTANCES',reason='Need enlarged instance boundaries; not silently left partially annotated.')
    (out/'inventory.json').write_text(json.dumps(rows,indent=2),encoding='utf8')
    (out/'ledger.json').write_text(json.dumps(ledger,indent=2),encoding='utf8')
    sheets(rows,out,'complete_boxes')
    print(dict(ready_for_final_overlay_check=len(rows),boxes=sum(len(r['boxes']) for r in rows)),flush=True)


if __name__=='__main__':main()
