"""Inspect candidate ZIP inventories/configs without admitting training data."""
import json
from pathlib import Path
import zipfile
import requests
from research_20k_sources import RangeZip


def main():
    root = Path('build/noon_continuation_20261118_001/research/organic_001/indexes')
    root.mkdir(exist_ok=False)
    for key,ref in [('fruitquality','abrars2/fruit-quality-classificaltion-and-detection'),
                    ('organic3','caodatan/waste-organic-inorganic-reclycable-yolov8')]:
        out = root/key; out.mkdir()
        try:
            r = requests.get('https://www.kaggle.com/api/v1/datasets/view/'+ref, timeout=(10,25))
            r.raise_for_status(); metadata = r.json()
            (out/'metadata.json').write_text(json.dumps(metadata,indent=2),encoding='utf8')
            version = int(metadata['currentVersionNumber'])
            url = 'https://www.kaggle.com/api/v1/datasets/download/'+ref+'?datasetVersionNumber='+str(version)
            remote = RangeZip(url)
            with zipfile.ZipFile(remote) as archive:
                entries = [dict(name=x.filename,size=x.file_size,compressed=x.compress_size,
                                offset=x.header_offset,crc=x.CRC) for x in archive.infolist()]
                configs=[]
                for item in archive.infolist():
                    if Path(item.filename).name.lower() in ['data.yaml','dataset.yaml','classes.txt','readme.md','readme.txt'] and item.file_size<100000:
                        body=archive.read(item); (out/item.filename.replace('/','__')).write_bytes(body)
                        configs.append([item.filename,body.decode('utf8',errors='replace')[:3000]])
                result=dict(source=ref,version=version,url=url,archive_bytes=remote.length,
                            etag=remote.etag,entries=entries,configs=configs,
                            no_images_admitted=True)
                (out/'index.json').write_text(json.dumps(result,indent=2),encoding='utf8')
                print(json.dumps({k:v for k,v in result.items() if k!='entries'}),flush=True)
        except Exception as error:
            (out/'error.json').write_text(json.dumps(dict(error=repr(error))),encoding='utf8')
            print(key,repr(error),flush=True)


if __name__=='__main__':
    main()
