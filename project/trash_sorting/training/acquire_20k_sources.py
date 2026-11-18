"""Resume bounded, identity-checked public ZIP acquisition and safely extract."""
import argparse,concurrent.futures,hashlib,json,os,time,zipfile
from pathlib import Path
import requests
from research_20k_sources import SOURCES

def main():
 p=argparse.ArgumentParser();p.add_argument('--root',type=Path,required=True);p.add_argument('--source',choices=SOURCES,required=True);a=p.parse_args();root=a.root.resolve();key=a.source
 index=json.loads((root/'indexes'/key/'index.json').read_text(encoding='utf8'));size=index['archive_bytes'];url=index['url'];etag=index['etag']
 # Reuse one verified redirect rather than requesting a signed storage URL per
 # chunk. Repeated redirect handshakes are rate limited by the hosting service.
 direct=root/'indexes'/key/'download_url.json'
 if direct.exists():url=json.loads(direct.read_text())['url']
 dest=root/'archives';dest.mkdir(exist_ok=True);target=dest/(key+'.zip');parts=dest/(key+'_parts');parts.mkdir(exist_ok=True);step=8*1024*1024
 if not target.exists():
  def get(i):
   lo=i*step;hi=min(size,lo+step)-1;p=parts/(str(i)+'.part')
   if p.exists() and p.stat().st_size==hi-lo+1:return p
   for attempt in range(4):
    try:
     r=requests.get(url,headers={'Range':f'bytes={lo}-{hi}'},timeout=(15,50));r.raise_for_status()
     if r.status_code!=206 or r.headers.get('Content-Range')!=f'bytes {lo}-{hi}/{size}' or r.headers.get('ETag')!=etag or len(r.content)!=hi-lo+1:raise ValueError('Range or identity mismatch')
     tmp=p.with_suffix('.partial');tmp.write_bytes(r.content);tmp.replace(p)
     print(key,'part',i,'/',(size+step-1)//step,flush=True);return p
    except Exception:
     if attempt==3:raise
     time.sleep(attempt+1)
  with concurrent.futures.ThreadPoolExecutor(2) as pool:ordered=list(pool.map(get,range((size+step-1)//step)))
  tmp=target.with_suffix('.partial')
  with tmp.open('wb') as f:
   for p in ordered:
    with p.open('rb') as src:
     while True:
      b=src.read(1024*1024)
      if not b:break
      f.write(b)
  tmp.replace(target)
 assert target.stat().st_size==size
 digest=hashlib.sha256()
 with target.open('rb') as f:
  for b in iter(lambda:f.read(8*1024*1024),b''):digest.update(b)
 unpack=root/'raw'/key;unpack.mkdir(parents=True,exist_ok=True)
 with zipfile.ZipFile(target) as z:
  infos=z.infolist();assert {(i.filename,i.CRC,i.file_size) for i in infos}=={(e['name'],e['crc'],e['size']) for e in index['entries']}
  for i in infos:
   path=(unpack/i.filename).resolve()
   if unpack not in path.parents and path!=unpack:raise ValueError('Unsafe archive path')
   if i.is_dir():path.mkdir(parents=True,exist_ok=True);continue
   # Do not extract an upstream held-out test set for training or visual tuning.
   if any(s.lower() in ('test','test_crops') for s in Path(i.filename).parts):continue
   path.parent.mkdir(parents=True,exist_ok=True)
   body=z.read(i) # validates CRC even when resuming
   if not path.exists() or path.read_bytes()!=body:path.write_bytes(body)
 record=dict(status='ACQUIRED_ZIP_IDENTITY_CRC_VERIFIED',source=index['source'],version=index['version'],archive_sha256=digest.hexdigest(),archive_bytes=size,etag=etag,
             raw=str(unpack),upstream_test_files_extracted=False)
 (root/(key+'_acquisition.json')).write_text(json.dumps(record,indent=2),encoding='utf8')
 # Task-owned verified parts no longer needed; paths checked within root.
 assert parts.parent==dest and dest.parent==root
 for p in parts.glob('*.part'):p.unlink()
 print(json.dumps(record),flush=True)
if __name__=='__main__':main()
