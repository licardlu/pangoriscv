"""Explicit complete replacement annotations on11visually inspected photos.

Coordinates are on450x800raw-pixel review views. No pseudo labels and no
automatic change to the frozen training queue.
"""
import hashlib
import json
from pathlib import Path
from PIL import Image,ImageDraw

BOXES={
 1:[[239,72,298,166],[138,181,196,299],[241,223,347,301],[137,336,255,416],[333,381,413,432],[183,441,293,533]],
 2:[[18,110,81,233],[166,189,215,310],[353,205,413,321],[36,279,128,397],[154,367,297,451],[339,374,391,526]],
 3:[[191,57,225,168],[282,126,393,169],[277,184,358,284],[101,251,221,293],[64,316,134,406],[204,296,316,397]],
 6:[[211,154,273,362]],
 7:[[221,250,273,322]],
 8:[[88,127,149,231],[294,65,347,185],[255,203,301,293],[151,310,203,381]],
 9:[[85,30,148,188],[312,25,381,190],[240,131,289,284],[76,209,153,346]],
 10:[[28,107,116,271],[177,174,237,338],[244,29,290,197],[347,192,439,357]],
 11:[[82,92,150,174],[136,122,231,152],[217,29,248,126],[289,183,390,215],[77,390,107,491],[212,346,277,438],[227,425,321,491]],
 13:[[188,151,237,348]],
 14:[[205,128,256,331]],
}


def main():
    root=Path('build/noon_continuation_20261118_001/research/battery_visual_001/Fetan-Love_AI-battery-detection-with-yolo_retry_001/audit_002')
    rows=json.loads((root/'inventory.json').read_text(encoding='utf8'))
    out=root/'replacement_annotations_001';out.mkdir(exist_ok=False);(out/'labels').mkdir()
    manifest=[]
    for n,coords in BOXES.items():
        row=rows[n-1];assert row['review_index']==n and row['admission'].startswith('PENDING_')
        assert row['exif_orientation']==1 and row['source_split']=='train'
        assert hashlib.sha256(Path(row['path']).read_bytes()).hexdigest()==row['image_sha256']
        boxes=[]
        for x1,y1,x2,y2 in coords:
            assert 0<=x1<x2<=450 and 0<=y1<y2<=800
            boxes.append([2,(x1+x2)/900,(y1+y2)/1600,(x2-x1)/450,(y2-y1)/800])
        label=out/'labels'/(row['stem']+'.txt')
        label.write_text(''.join(str(b[0])+' '+' '.join('%.8f'%v for v in b[1:])+'\n' for b in boxes),encoding='ascii')
        manifest.append(dict(row,boxes=boxes,replacement_label=str(label.resolve()),
                             replacement_label_sha256=hashlib.sha256(label.read_bytes()).hexdigest(),
                             annotation_status='PENDING_FINAL_OVERLAY_REVIEW_NOT_TRAINED'))
    for start in range(0,len(manifest),6):
        sheet=Image.new('RGB',(1350,1660),'white');d=ImageDraw.Draw(sheet)
        for j,row in enumerate(manifest[start:start+6]):
            im=Image.open(row['path']).convert('RGB').resize((450,800));v=ImageDraw.Draw(im)
            for _,cx,cy,bw,bh in row['boxes']:
                v.rectangle(((cx-bw/2)*450,(cy-bh/2)*800,(cx+bw/2)*450,(cy+bh/2)*800),outline='lime',width=2)
            x=j%3*450;y=j//3*830;sheet.paste(im,(x,y+30));d.text((x+4,y+4),f'B{row["review_index"]:02} complete battery boxes{len(row["boxes"])}',fill='black')
        sheet.save(out/f'overlay_{start//6+1}.jpg',quality=96)
    (out/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf8')
    print(dict(proposed=len(manifest),boxes=sum(len(r['boxes']) for r in manifest),training_admitted=0),flush=True)


if __name__=='__main__':main()
