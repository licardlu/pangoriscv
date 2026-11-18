"""Build a focused replay subset from reviewed TRAIN rows only; never relabel val/test."""
import argparse, collections, hashlib, json
from pathlib import Path

def main():
 p=argparse.ArgumentParser(description=__doc__)
 p.add_argument('--manifest',type=Path,required=True);p.add_argument('--out',type=Path,required=True)
 a=p.parse_args();rows=json.loads(a.manifest.read_text(encoding='utf8'))
 # Preserve the physical-item/group split established by the reviewed dataset.
 # Keep all battery/hand/glass/empty-scene rows, plus deterministic public replay.
 selected=[]
 for r in rows:
  if r['split']!='train':continue
  source=r['source'];stem=Path(r['prepared_image']).stem
  retain=source not in ('sumn2u','codingbear') or int(hashlib.sha256(stem.encode()).hexdigest()[:8],16)%3==0
  if retain:selected.append(r)
 assert selected and all(r['split']=='train' for r in selected)
 train_hashes={r['image_sha256'] for r in selected}
 assert not train_hashes.intersection(r['image_sha256'] for r in rows if r['split']!='train')
 # Exact image/annotation identity, not just file presence.
 for r in selected:
  image=Path(r['prepared_image']);label=Path(image.as_posix().replace('/images/','/labels/')).with_suffix('.txt')
  assert image.is_file() and label.is_file(),str(image)
  assert hashlib.sha256(image.read_bytes()).hexdigest()==r['image_sha256']
  assert hashlib.sha256(label.read_bytes()).hexdigest()==r['label_sha256']
 a.out=a.out.resolve();a.out.mkdir(parents=True,exist_ok=False)
 (a.out/'train.txt').write_text(''.join(str(Path(r['prepared_image']).resolve()).replace('\\','/')+'\n' for r in selected),encoding='utf8')
 (a.out/'val.txt').write_text(''.join(str(Path(r['prepared_image']).resolve()).replace('\\','/')+'\n' for r in rows if r['split']=='val'),encoding='utf8')
 # A val-only manifest allows the existing evaluation entry to verify truth.
 (a.out/'manifest.json').write_text(json.dumps([*selected,*(r for r in rows if r['split']=='val')],ensure_ascii=False,indent=2),encoding='utf8')
 (a.out/'data.yaml').write_text(f'path: {a.out.as_posix()}\ntrain: train.txt\nval: val.txt\nnc: 5\nnames: [kitchen, recyclable, hazardous, other, hand]\n',encoding='utf8')
 report=dict(train=len(selected),val=sum(r['split']=='val' for r in rows),sources=dict(collections.Counter(r['source'] for r in selected)),
  reviewed_labels_only=True,validation_added_to_training=False,test_read=False,model_changed=False,
  source_manifest_sha256=hashlib.sha256(a.manifest.read_bytes()).hexdigest())
 (a.out/'audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf8');print(json.dumps(report,ensure_ascii=False))
if __name__=='__main__':main()
