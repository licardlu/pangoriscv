"""Verify frozen training identities, labels and splits; render exported-label samples."""
import argparse,collections,hashlib,json,random
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def main():
 p=argparse.ArgumentParser();p.add_argument('--data',type=Path,required=True);p.add_argument('--base',type=Path,required=True);p.add_argument('--photos',type=Path,required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args()
 a.out.mkdir(parents=True,exist_ok=False)
 rows=json.loads((a.data/'manifest.json').read_text(encoding='utf8'));original=json.loads((a.base/'manifest.json').read_text(encoding='utf8'))
 photo_audit=json.loads((a.photos/'audit.json').read_text(encoding='utf8'));protected=set(photo_audit['protected_groups'])
 base={r['image_sha256']:r for r in original};seen=collections.defaultdict(set);groups=collections.defaultdict(set);added=[]
 for i,r in enumerate(rows):
  image=Path(r['prepared_image']);label=Path(str(image).replace('/images/','/labels/').replace('\\images\\','\\labels\\')).with_suffix('.txt')
  assert sha(image)==r['image_sha256'],image
  assert sha(label)==r['label_sha256'],label
  boxes=[[float(n) for n in line.split()] for line in label.read_text(encoding='ascii').splitlines() if line.strip()]
  assert len(boxes)==len(r['boxes']),label
  for actual,wanted in zip(boxes,r['boxes']):
   assert len(actual)==5 and actual[0] in range(5) and actual[0]==wanted[0]
   assert all(abs(x-y)<=1e-7 for x,y in zip(actual,wanted)),label
   _,cx,cy,w,h=actual
   # The original labels are rounded to seven decimals: an edge at zero
   # can reconstruct as -5e-8. Allow only this serialization rounding.
   assert -1e-7<=cx-w/2<=cx+w/2<=1.0000001 and -1e-7<=cy-h/2<=cy+h/2<=1.0000001,label
  seen[r['image_sha256']].add(r['split'])
  group=r.get('capture_group',r.get('group'))
  if group is not None:groups[str(group)].add(r['split'])
  if r.get('origin')=='personal_continuation':
   assert r['split']=='train' and r['annotation_status']=='VISUALLY_REVIEWED'
   assert r['image_sha256'] not in base and group not in protected
   added.append(r)
  else:
   before=base[r['image_sha256']]
   assert r['split']==before['split'] and r['boxes']==before['boxes'] and r['label_sha256']==before['label_sha256']
  if (i+1)%1000==0:print(f'DATASET_AUDIT {i+1}/{len(rows)}',flush=True)
 assert len(rows)==len(original)+len(added)
 leaked={h:list(s) for h,s in seen.items() if len(s)>1}
 group_leaked={g:list(s) for g,s in groups.items() if len(s)>1}
 assert not leaked,leaked
 # Existing group contracts are reported without silently reassigning old splits.
 rng=random.Random(1611);sample=[]
 for c in range(5):
  pool=[r for r in added if any(int(b[0])==c for b in r['boxes'])]
  for r in rng.sample(pool,min(4,len(pool))):
   if r not in sample:sample.append(r)
 font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',15)
 colors=['#008547','#2075ff','#e02020','#888888','#ff8c00'];names=['厨余','回收','有害','其他','手']
 for start in range(0,len(sample),12):
  sheet=Image.new('RGB',(1440,1530),'#f4f8fc');d=ImageDraw.Draw(sheet)
  for j,r in enumerate(sample[start:start+12]):
   im=Image.open(r['prepared_image']).convert('RGB');im.thumbnail((348,464));w,h=im.size
   ox=(j%4)*360+(360-w)//2;oy=(j//4)*510+28;sheet.paste(im,(ox,oy))
   d.text(((j%4)*360+8,(j//4)*510+4),Path(r['prepared_image']).stem,font=font,fill='#173952')
   for c,cx,cy,bw,bh in r['boxes']:
    box=[ox+(cx-bw/2)*w,oy+(cy-bh/2)*h,ox+(cx+bw/2)*w,oy+(cy+bh/2)*h]
    d.rectangle(box,outline=colors[int(c)],width=2);d.text((box[0]+2,box[1]+2),names[int(c)],font=font,fill=colors[int(c)])
   d.text(((j%4)*360+8,(j//4)*510+492),str(r.get('group')),font=font,fill='#52756b')
  sheet.save(a.out/f'exported_labels_{start//12+1:02d}.jpg',quality=94)
 result=dict(status='PASS',images=len(rows),new_train=len(added),splits=dict(collections.Counter(r['split'] for r in rows)),
  original_images_labels_splits_unchanged=True,all_image_and_label_sha_verified=True,exact_sha_split_leaks=leaked,
  group_split_leaks=group_leaked,protected_new_groups_in_train=0,rendered_samples=len(sample),
  manifest_sha256=sha(a.data/'manifest.json'),review_snapshot_sha256=sha(a.data/'review_ledger.snapshot.json'))
 (a.out/'result.json').write_text(json.dumps(result,indent=2),encoding='utf8');print(json.dumps(result),flush=True)
if __name__=='__main__':main()
