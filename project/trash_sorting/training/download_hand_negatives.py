"""Inspect official HaGRID archives by HTTP Range, without fetching 1.2 GB.

Downloaded hand photos are candidates for human-reviewed negatives, not
automatically empty YOLO labels. Preserve subject IDs for split isolation.
"""
import argparse
import hashlib
import io
import json
from pathlib import Path
import urllib.request
import zipfile

BASE='https://rndml-team-cv.obs.ru-moscow-1.hc.sbercloud.ru/datasets/hagrid_v2/'
ANNOTATION_URL=BASE+'annotations_with_landmarks/annotations.zip'


class RemoteZip(io.RawIOBase):
    def __init__(self,url):
        self.url=url
        self.pos=0
        self.transferred=0
        with urllib.request.urlopen(urllib.request.Request(url,headers={'Range':'bytes=-65536'}),timeout=30) as r:
            if r.status!=206:
                raise ValueError('Server must support byte ranges')
            self.length=int(r.headers['Content-Range'].split('/')[-1])
            self.etag=r.headers['ETag']
            self.buffer=r.read()
            self.start=self.length-len(self.buffer)
            self.transferred+=len(self.buffer)

    def seekable(self):
        return True

    def tell(self):
        return self.pos

    def seek(self,offset,whence=0):
        self.pos=offset+(self.pos if whence==1 else self.length if whence==2 else 0)
        if not 0<=self.pos<=self.length:
            raise ValueError('Invalid remote seek')
        return self.pos

    def read(self,n=-1):
        if n<0:
            n=self.length-self.pos
        n=min(n,self.length-self.pos)
        if not n:
            return b''
        if not(self.start<=self.pos and self.pos+n<=self.start+len(self.buffer)):
            end=min(self.length,self.pos+max(n,65536))
            req=urllib.request.Request(self.url,headers={'Range':f'bytes={self.pos}-{end-1}','If-Match':self.etag})
            with urllib.request.urlopen(req,timeout=45) as r:
                expected=f'bytes {self.pos}-{end-1}/{self.length}'
                if r.status!=206 or r.headers.get('Content-Range')!=expected or r.headers['ETag']!=self.etag:
                    raise ValueError('Remote archive identity/range changed')
                self.buffer=r.read()
            if len(self.buffer)!=end-self.pos:
                raise ValueError('Incomplete range response')
            self.start=self.pos
            self.transferred+=len(self.buffer)
        result=self.buffer[self.pos-self.start:self.pos-self.start+n]
        self.pos+=len(result)
        return result


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--out',type=Path,required=True)
    p.add_argument('--download',type=int,default=0,help='Deterministic maximum images per source split for visual review')
    p.add_argument('--source-split',choices=('train','val','test'),
                   help='Download images from only this original subject split')
    p.add_argument('--gesture',choices=('no_gesture','palm','fist'),default='no_gesture',
                   help='Official archive; all downloads remain unreviewed, never automatic empty labels')
    a=p.parse_args()
    a.out.mkdir(parents=True,exist_ok=False)
    records={}
    annotations={}
    image_url=BASE+'hagrid_v2_zip/'+a.gesture+'.zip'
    for kind,url in [('annotations',ANNOTATION_URL),('images',image_url)]:
        remote=RemoteZip(url)
        with zipfile.ZipFile(remote) as archive:
            infos=archive.infolist()
            selected=[i for i in infos if Path(i.filename).name==a.gesture+'.json'
                      and i.filename.startswith('annotations/')
                      and '/.ipynb_checkpoints/' not in i.filename
                      and (not a.source_split or i.filename.split('/')[1]==a.source_split)]
            if kind=='annotations' and not selected:
                raise ValueError('Requested official gesture/split annotations absent')
            record=dict(url=url,etag=remote.etag,archive_bytes=remote.length,
                        entries=[dict(name=i.filename,bytes=i.file_size,compressed_bytes=i.compress_size,crc32=f'{i.CRC:08x}') for i in infos])
            if kind=='annotations':
                for info in selected:
                    print('ANNOTATION',info.filename,info.file_size,flush=True)
                    payload=archive.read(info)
                    name=info.filename.replace('/','_')
                    (a.out/name).write_bytes(payload)
                    annotations[info.filename]=json.loads(payload)
            elif a.download:
                by_stem={Path(i.filename).stem:i for i in infos if i.filename.lower().endswith(('.jpg','.jpeg','.png'))}
                sampled=[]
                for ann_name,items in annotations.items():
                    if a.source_split and ann_name.split('/')[1]!=a.source_split:
                        continue
                    if not isinstance(items,dict):
                        raise ValueError('Unexpected annotation schema')
                    keys=sorted(items)
                    for index in range(min(a.download,len(keys))):
                        key=keys[index*len(keys)//min(a.download,len(keys))]
                        info=by_stem.get(key)
                        if info is None:
                            raise ValueError('Annotated photo missing '+key)
                        data=archive.read(info)
                        target=a.out/'images'/Path(info.filename).name
                        target.parent.mkdir(exist_ok=True)
                        target.write_bytes(data)
                        sampled.append(dict(file=target.name,archive_member=info.filename,
                                            annotation_source=ann_name,annotation=items[key],
                                            sha256=hashlib.sha256(data).hexdigest(),
                                            review_status='unreviewed; no negative labels created'))
                        if len(sampled)%20==0:print('HAND_CANDIDATES',len(sampled),flush=True)
                (a.out/'candidate_images.json').write_text(json.dumps(sampled,indent=2),encoding='utf8')
            record['bytes_transferred']=remote.transferred
            records[kind]=record
            print(kind,'entries',len(infos),'transferred',remote.transferred,flush=True)
        (a.out/'archives.json').write_text(json.dumps(records,indent=2),encoding='utf8')


if __name__=='__main__':
    main()
