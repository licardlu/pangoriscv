"""Inspect public project datasets through bounded ZIP ranges before acquisition."""
import argparse,collections,io,json,re,time,zipfile
from pathlib import Path
import requests

SOURCES={
 'arshnoor':('arshnoor7389/garbage-classification-dataset',1),
 'household':('youssefelebiary/household-trash-recycling-dataset',3),
 'plusyaml':('engrbasit62/garbage-dataset-plusyaml',1),
 'drinking':('arkadiyhacks/drinking-waste-classification',2),
 'wastesense':('sumn2u/wastesense',2),
 'garbage6':('viswaprakash1990/garbage-detection',1),
 'warp':('parohod/warp-waste-recycling-plant-dataset',3),
 'batteryobjects':('markcsizmadia/object-detection-batteries-dices-and-toy-cars',1),
 'trashsort':('codingbearhsun/trash-sort',1),
 'bbox384':('sumn2u/garbage-classification-v2-bbox-384',1),
}

class RangeZip(io.RawIOBase):
 def __init__(self,url):
  self.url=url;self.pos=0;self.transferred=0;self.calls=0
  r=self.request('bytes=-131072');m=re.fullmatch(r'bytes (\d+)-(\d+)/(\d+)',r.headers.get('Content-Range',''))
  if r.status_code!=206 or not m:raise ValueError('Range unsupported '+str(r.status_code))
  self.start,self.end,self.length=map(int,m.groups());self.buffer=r.content
  self.etag=r.headers.get('ETag');self.final_url=r.url
  assert len(self.buffer)==self.end-self.start+1
 def request(self,rg):
  for attempt in range(3):
   try:
    r=requests.get(self.url,headers={'Range':rg},timeout=(15,40));r.raise_for_status();self.calls+=1;self.transferred+=len(r.content);return r
   except requests.RequestException:
    if attempt==2:raise
    time.sleep(1)
 def seekable(self):return True
 def tell(self):return self.pos
 def seek(self,offset,whence=0):
  self.pos=offset+(self.pos if whence==1 else self.length if whence==2 else 0)
  if not 0<=self.pos<=self.length:raise ValueError('Bad seek')
  return self.pos
 def read(self,n=-1):
  if n<0:n=self.length-self.pos
  n=min(n,self.length-self.pos)
  if n==0:return b''
  if not self.start<=self.pos or self.pos+n>self.start+len(self.buffer):
   end=min(self.length,self.pos+max(n,131072));r=self.request(f'bytes={self.pos}-{end-1}')
   if r.status_code!=206 or r.headers.get('Content-Range')!=f'bytes {self.pos}-{end-1}/{self.length}':raise ValueError('Wrong range response')
   if self.etag and r.headers.get('ETag')!=self.etag:raise ValueError('Archive identity changed')
   self.start=self.pos;self.buffer=r.content
   assert len(self.buffer)==end-self.pos
  b=self.buffer[self.pos-self.start:self.pos-self.start+n];self.pos+=len(b);return b

def main():
 p=argparse.ArgumentParser();p.add_argument('--out',type=Path,required=True);p.add_argument('--source',choices=SOURCES,action='append');a=p.parse_args();a.out.mkdir(parents=True,exist_ok=True)
 for key in a.source or SOURCES:
  ref,version=SOURCES[key];dest=a.out/key;dest.mkdir(exist_ok=True)
  if (dest/'index.json').exists():print(key,'already indexed',flush=True);continue
  try:
   url=f'https://www.kaggle.com/api/v1/datasets/download/{ref}?datasetVersionNumber={version}';remote=RangeZip(url)
   with zipfile.ZipFile(remote) as z:
    entries=[dict(name=i.filename,size=i.file_size,compressed=i.compress_size,offset=i.header_offset,crc=i.CRC) for i in z.infolist()]
    configs=[i for i in z.infolist() if Path(i.filename).name.lower() in ('data.yaml','dataset.yaml','classes.txt','labels.txt','readme.md','readme.txt')]
    saved=[]
    for i in configs[:20]:
     if i.file_size>100000:continue
     body=z.read(i);name=i.filename.replace('/','__');(dest/name).write_bytes(body);saved.append((i.filename,body.decode('utf8',errors='replace')[:1500]))
    images=[e for e in entries if Path(e['name']).suffix.lower() in ('.jpg','.jpeg','.png','.bmp','.webp')]
    labels=[e for e in entries if Path(e['name']).suffix.lower() in ('.txt','.json','.xml')]
    result=dict(source=ref,version=version,url=url,archive_bytes=remote.length,etag=remote.etag,entries=entries,configs=saved,images=len(images),labels=len(labels),transferred=remote.transferred)
    (dest/'index.json').write_text(json.dumps(result,indent=2),encoding='utf8')
    print(json.dumps({k:v for k,v in result.items() if k not in ('entries',)},ensure_ascii=True),flush=True)
  except Exception as e:
   (dest/'error.json').write_text(json.dumps(dict(source=ref,error=repr(e))),encoding='utf8');print(key,repr(e),flush=True)
if __name__=='__main__':main()
