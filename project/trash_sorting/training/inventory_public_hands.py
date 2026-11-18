"""Index official full-frame hand annotations; still requires visual waste-free review."""
import json,sys
from pathlib import Path
from PIL import Image
from collect_public_expansion import sheets
root=Path(sys.argv[1]).resolve();source=root/'hagrid_no_gesture'
items=json.loads((source/'candidate_images.json').read_text(encoding='utf8'));rows=[]
for r in items:
    path=source/'images'/r['file'];ann=r['annotation'];w,h=Image.open(path).size
    boxes=[]
    for b in ann['bboxes']:
        x,y,bw,bh=b
        boxes.append(dict(category_id=4,bbox=[x*w,y*h,bw*w,bh*h]))
    rows.append(dict(id='hagrid_'+path.stem,source='hagrid',path=str(path),width=w,height=h,
        sha256=r['sha256'],annotations=boxes,category_names={'4':'hand'},subject_id=ann['user_id'],
        source_split='train',annotation_source=r['annotation_source'],archive_member=r['archive_member'],
        url='https://github.com/hukenovs/hagrid',
        license='HaGRID dataset custom agreement; verify upstream before redistribution',review_status='UNREVIEWED'))
(root/'hand_inventory.json').write_text(json.dumps(rows,indent=2),encoding='utf8')
sheets(rows,root/'candidates','hand_review')
print('hand candidates',len(rows),'subjects',len({r['subject_id'] for r in rows}),flush=True)
