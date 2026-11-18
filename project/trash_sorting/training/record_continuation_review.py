"""Record explicit per-image visual decisions, bound to prepared image identity."""
import json,sys,hashlib
from pathlib import Path
def record_sheet(root,decisions,sheet_number):
 """Convert explicitly inspected contact-sheet rectangles to preview pixels."""
 from PIL import Image
 root=Path(root);rows=json.loads((root/'proposals.json').read_text(encoding='utf8'))['images']
 mapped={}
 for key,decision in decisions.items():
  index=int(key[1:])-1
  assert index//12+1==sheet_number,(key,sheet_number)
  if isinstance(decision,dict):mapped[key]=decision;continue
  w,h=rows[index]['preview_size'];probe=Image.new('1',(w,h));probe.thumbnail((348,464))
  dw,dh=probe.size;local=index%12;ox=(local%4)*360+(360-dw)//2;oy=(local//4)*510+28
  boxes=[]
  for c,x1,y1,x2,y2 in decision:
   assert ox<=x1<x2<=ox+dw and oy<=y1<y2<=oy+dh,(key,(ox,oy,dw,dh),decision)
   boxes.append([c,round((x1-ox)*w/dw,2),round((y1-oy)*h/dh,2),round((x2-ox)*w/dw,2),round((y2-oy)*h/dh,2)])
  mapped[key]=boxes
 return record(root,mapped,f'sheet_{sheet_number:03d}')

def record(root,decisions,sheet):
 root=Path(root);source=json.loads((root/'proposals.json').read_text(encoding='utf8'));images={r['id']:r for r in source['images']}
 dest=root/'review_ledger.json';ledger=json.loads(dest.read_text(encoding='utf8')) if dest.exists() else {'reviewer':'assistant_visual','coordinate_space':'preview_xyxy','images':{},'sheets':[]}
 for key,decision in decisions.items():
  r=images[key];w,h=r['preview_size'];boxes=[]
  if isinstance(decision,dict) and 'exclude' in decision:
   entry={'id':key,'status':'VISUALLY_REVIEWED_EXCLUDED','reason':decision['exclude'],'boxes':[]}
  else:
   for item in decision:
    if isinstance(item,int):b=dict(r['proposed_boxes'][item]);b={k:v for k,v in b.items() if k in ['category','xyxy']}
    else:b={'category':item[0],'xyxy':item[1:]}
    c=b['category'];x1,y1,x2,y2=b['xyxy']
    assert type(c)==int and c in range(5) and 0<=x1<x2<=w and 0<=y1<y2<=h,(key,b,(w,h))
    boxes.append(b)
   entry={'id':key,'status':'VISUALLY_REVIEWED','boxes':boxes,'empty_confirmed':not boxes}
  assert hashlib.sha256(Path(r['image_path']).read_bytes()).hexdigest()==r['image_sha256']
  entry.update(image_sha256=r['image_sha256'],source_sha256=r['sha256'],sheet=sheet)
  if key in ledger['images'] and ledger['images'][key]!=entry:raise ValueError('Existing review differs; explicit revision needed: '+key)
  ledger['images'][key]=entry
 if sheet not in ledger['sheets']:ledger['sheets'].append(sheet)
 dest.write_text(json.dumps(ledger,ensure_ascii=False,indent=2),encoding='utf8');print('REVIEWED',len(ledger['images']),'/TOTAL',len(images),'SHEETS',len(ledger['sheets']),flush=True)
if __name__=='__main__':record(Path(sys.argv[1]),json.load(sys.stdin),sys.argv[2])
