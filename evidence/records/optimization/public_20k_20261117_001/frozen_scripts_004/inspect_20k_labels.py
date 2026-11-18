"""Audit public training detection labels and show deterministic, class-stratified samples.

This does not admit data to training and does not call source labels human-reviewed.
"""
import argparse,collections,hashlib,json,re
from pathlib import Path
from PIL import Image,ImageOps
from collect_public_expansion import sheets

NAMES={
 'arshnoor':['cardboard','miscellaneous','organic','paper','glass','metal','plastic'],
 'plusyaml':['paper','plastic','glass','metal','organic','electronics','miscellaneous'],
 'garbage6':['biodegradable','cardboard','glass','metal','paper','plastic'],
 'household':['banana','apple','orange','tomato','carrot','cucumber','potato','bread','cake','pizza','hamburger','chicken','fish','food','tin can','bottle','facial tissue holder','toilet paper','paper towel','milk','snack','plastic bag','candy','light bulb','toothbrush','soap dispenser','drinking straw','fast food','pasta','pastry'],
 'drinking':['aluminium can','glass bottle','PET bottle','HDPE bottle'],
 'warp':['bottle-blue','bottle-green','bottle-dark','bottle-milk','bottle-transp','bottle-multicolor','bottle-yogurt','bottle-oil','cans','juice-cardboard','milk-cardboard','detergent-color','detergent-transparent','detergent-box','canister','bottle-blue-full','bottle-transp-full','bottle-dark-full','bottle-green-full','bottle-multicolorv-full','bottle-milk-full','bottle-oil-full','detergent-white','bottle-blue5l','bottle-blue5l-full','glass-transp','glass-dark','glass-green'],
 'batteryobjects':['battery','dice','toycar','candle','highlighter','spoon'],
 'wastesense':['glass','metal','paper','plastic'],
 'trashsort':['bottle','brick','battery','can','carrot','china','paperCup','pill','potato','radish','stone','potato_chip'],
 # Verified across every label and its original class folder; metadata lists
 # category names but does not specify the numerical index order.
 'bbox384':['metal','trash','glass','paper','cardboard','plastic','biological']}
def canonical(name):
 s=Path(name).stem.lower();s=re.sub(r'\.rf\.[a-f0-9]+$','',s)
 s=re.sub(r'_(jpg|jpeg|png)$','',s);return s
def main():
 p=argparse.ArgumentParser();p.add_argument('--root',type=Path,required=True);p.add_argument('--source',choices=NAMES,required=True);a=p.parse_args();root=a.root.resolve();key=a.source
 dest=root/'audits'/key;dest.mkdir(parents=True,exist_ok=True);raw=root/'raw'/key
 paths=sorted(p for p in raw.rglob('*') if p.suffix.lower() in ('.jpg','.jpeg','.png'))
 paths=[p for p in paths if 'train' in p.parts or key in ('arshnoor','drinking','wastesense','bbox384')]
 if key=='drinking':paths=[p for p in paths if 'YOLO_imgs' in p.parts]
 if key=='warp':paths=[p for p in paths if 'Warp-D' in p.parts]
 inventory=[];errors=[];counts=collections.Counter();full=collections.Counter();area=[]
 for image in paths:
  lp=Path(str(image).replace('/images/','/labels/').replace('\\images\\','\\labels\\')).with_suffix('.txt')
  if key=='drinking':lp=image.with_suffix('.txt')
  try:
   if not lp.exists():raise ValueError('missing detection label')
   boxes=[]
   for line in lp.read_text(encoding='utf-8-sig').splitlines():
    if not line.strip():continue
    if key=='batteryobjects':
     fields=line.split();cls=NAMES[key].index(fields[0]);x1,y1,x2,y2=map(float,fields[4:8])
     with Image.open(image) as im:iw,ih=im.size
     b=[cls,(x1+x2)/(2*iw),(y1+y2)/(2*ih),(x2-x1)/iw,(y2-y1)/ih]
    else:b=list(map(float,line.split()))
    assert len(b)==5 and int(b[0])==b[0] and 0<=int(b[0])<len(NAMES[key]),'bad class/schema'
    c,x,y,w,h=b;assert w>0 and h>0 and min(x-w/2,y-h/2)>=-.005 and max(x+w/2,y+h/2)<=1.005,'bad coordinates'
    x1,y1,x2,y2=max(0,x-w/2),max(0,y-h/2),min(1,x+w/2),min(1,y+h/2)
    boxes.append([int(c),(x1+x2)/2,(y1+y2)/2,x2-x1,y2-y1]);counts[int(c)]+=1;full[int(c)]+=w*h>.90;area.append(w*h)
   if not boxes:raise ValueError('empty source label requires visual negative confirmation')
   inventory.append(dict(id=key+'_'+hashlib.sha256(str(image.relative_to(raw)).encode()).hexdigest()[:16],path=str(image),label=str(lp),
                         boxes=boxes,source=key,canonical_stem=canonical(image.name),source_relative=image.relative_to(raw).as_posix(),
                         annotation_status='SOURCE_LABELS_NOT_INDIVIDUALLY_REVIEWED'))
  except Exception as e:errors.append(dict(path=str(image),reason=str(e)))
 (dest/'inventory.json').write_text(json.dumps(inventory,indent=2),encoding='utf8')
 (dest/'errors.json').write_text(json.dumps(errors,indent=2),encoding='utf8')
 chosen=[];seen=set()
 for c in range(len(NAMES[key])):
  pool=[r for r in inventory if any(b[0]==c for b in r['boxes'])];pool.sort(key=lambda r:hashlib.sha256(r['id'].encode()).hexdigest())
  for r in pool[:8]:
   if r['id'] in seen:continue
   seen.add(r['id'])
   try:
    with Image.open(r['path']) as im:
     assert im.getexif().get(274,1)==1,'EXIF rotation requires annotation audit';w,h=im.size
    chosen.append({**r,'width':w,'height':h,'annotations':[dict(category_id=b[0],bbox=[(b[1]-b[3]/2)*w,(b[2]-b[4]/2)*h,b[3]*w,b[4]*h]) for b in r['boxes']],
       'category_names':dict(enumerate(NAMES[key]))})
    chosen[-1]['category_names']={str(k):v for k,v in chosen[-1]['category_names'].items()}
   except Exception as e:errors.append(dict(path=r['path'],reason=repr(e)))
 sheets(chosen,dest,'source_labels')
 (dest/'errors.json').write_text(json.dumps(errors,indent=2),encoding='utf8')
 result=dict(source=key,train_paths=len(paths),label_valid_rows=len(inventory),errors=len(errors),sampled_images=len(chosen),
             class_box_counts={NAMES[key][c]:n for c,n in counts.items()},near_full_frame_boxes={NAMES[key][c]:n for c,n in full.items() if n},
             scope='Source TRAIN only; schema validation and stratified visual sample prepared. Not all labels reviewed.')
 (dest/'summary.json').write_text(json.dumps(result,indent=2),encoding='utf8');print(json.dumps(result),flush=True)
if __name__=='__main__':main()
