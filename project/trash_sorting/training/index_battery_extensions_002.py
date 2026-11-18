"""Inspect source metadata and archive entries before choosing new imagery."""
from concurrent.futures import ThreadPoolExecutor
import json
from pathlib import Path
import zipfile
import requests
from research_20k_sources import RangeZip


def main():
    root=Path('build/joint_battery_resume_20261118_001/research/real_battery_scenes_002')
    refs=['apadoss/recycle-waste','akshat103/e-waste-image-dataset','lluckymun/android-phone-battery-dataset']
    def inspect(ref):
        out=root/ref.split('/')[0];out.mkdir(exist_ok=False)
        try:
            response=requests.get('https://www.kaggle.com/api/v1/datasets/list',params=dict(search=ref,pageSize=10),timeout=(12,30));response.raise_for_status()
            meta=[x for x in response.json() if x.get('ref')==ref];assert len(meta)==1
            (out/'metadata.json').write_text(json.dumps(meta[0],indent=2))
            version=meta[0]['currentVersionNumber']
            url=f'https://www.kaggle.com/api/v1/datasets/download/{ref}?datasetVersionNumber={version}'
            remote=RangeZip(url)
            with zipfile.ZipFile(remote) as z:
                entries=[dict(name=i.filename,size=i.file_size,crc=i.CRC,compressed=i.compress_size,offset=i.header_offset) for i in z.infolist()]
                configs=[]
                for i in z.infolist():
                    if Path(i.filename).name.lower() in ['data.yaml','dataset.yaml','classes.txt','readme.md','readme.txt','license','license.txt'] and i.file_size<100000:
                        configs.append([i.filename,z.read(i).decode('utf8',errors='replace')])
            images=[r for r in entries if Path(r['name']).suffix.lower() in ['.jpg','.jpeg','.png','.bmp','.webp']]
            labels=[r for r in entries if Path(r['name']).suffix.lower() in ['.txt','.xml','.json']]
            result=dict(source=ref,version=version,url=url,archive_bytes=remote.length,etag=remote.etag,
                entries=entries,configs=configs,images=len(images),labels=len(labels),transferred=remote.transferred,
                image_samples=[r['name'] for r in images[:12]],label_samples=[r['name'] for r in labels[:12]])
            (out/'index.json').write_text(json.dumps(result,indent=2))
            return {k:v for k,v in result.items() if k!='entries'}
        except Exception as e:
            result=dict(source=ref,error=repr(e));(out/'error.json').write_text(json.dumps(result));return result
    with ThreadPoolExecutor(max_workers=2) as pool:
        for result in pool.map(inspect,refs):print(json.dumps(result),flush=True)


if __name__=='__main__':main()
