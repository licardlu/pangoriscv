"""Fetch only the1485 upstream train RGB/masks at one pinned public Git SHA.

Byte length and Git blobSHA1 bind mirror payloads to its saved tree. This is
acquisition for review, never automatic five-class admission. Test/valid image
and mask contents are never requested.
"""
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import time
import requests


def main():
    root=Path('build/noon_continuation_20261118_001/research/handheld_mirrors_001')
    tree=json.loads((root/'mirror_tree.json').read_text(encoding='utf8'))
    assert not tree['truncated'] and tree['sha']=='b2c5ae89cc4f5f5ba6c5b61e47df873799ffc6fd'
    ids=(root/'mirror_ImageSets__Segmentation__train.txt').read_text(encoding='utf8').splitlines()
    assert len(ids)==len(set(ids))==1485
    entries={r['path']:r for r in tree['tree'] if r['type']=='blob'}
    out=root/'mju_train_001';out.mkdir(exist_ok=False)
    (out/'images').mkdir();(out/'masks').mkdir()
    base='https://raw.githubusercontent.com/thanhlongqax/mju-waste-dataset/'+tree['sha']+'/'
    def fetch(stem):
        row=dict(id=stem,source='MJU_Waste',source_split='train',git_commit=tree['sha'])
        try:
            for directory,key in [('JPEGImages','images'),('SegmentationClass','masks')]:
                name=directory+'/'+stem+'.png';entry=entries[name]
                assert 0<entry['size']<2_000_000
                response=requests.get(base+name,timeout=(10,30));response.raise_for_status();body=response.content
                assert len(body)==entry['size']
                assert hashlib.sha1(b'blob '+str(len(body)).encode()+b'\0'+body).hexdigest()==entry['sha']
                path=out/key/(stem+'.png');path.write_bytes(body)
                row[key]=str(path.resolve());row[key+'_sha256']=hashlib.sha256(body).hexdigest()
            row['status']='DOWNLOADED_FOR_REVIEW_NOT_ADMITTED'
        except Exception as error:row.update(status='ACQUISITION_FAILED',error=repr(error))
        return row
    rows=[];start=time.time()
    with ThreadPoolExecutor(max_workers=4) as pool:
        for n,row in enumerate(pool.map(fetch,ids),1):
            rows.append(row)
            if n%32==0:
                (out/'inventory.json').write_text(json.dumps(rows,indent=2),encoding='utf8')
                print(dict(fetched=n,total=len(ids),elapsed_s=round(time.time()-start)),flush=True)
    (out/'inventory.json').write_text(json.dumps(rows,indent=2),encoding='utf8')
    result=dict(status='ACQUIRED_FOR_VISUAL_FIVECLASS_AND_HAND_REVIEW',train_entries=len(ids),
        complete=sum(r['status']=='DOWNLOADED_FOR_REVIEW_NOT_ADMITTED' for r in rows),
        failed=[r['id'] for r in rows if r['status']=='ACQUISITION_FAILED'],
        git_commit=tree['sha'],train_split_sha256=hashlib.sha256((root/'mirror_ImageSets__Segmentation__train.txt').read_bytes()).hexdigest(),
        source_url='https://github.com/realwecan/mju-waste',mirror_url='https://github.com/thanhlongqax/mju-waste-dataset',
        licence_url='https://github.com/realwecan/mju-waste/blob/master/LICENSE',
        licence='MIT, original2020TaoWang copyright notice retained in licence_check_LICENSE.json',
        training_admission=0,test_valid_images_masks_requested=False,elapsed_s=time.time()-start,
        limitations=['Upstream random split has correlated same-object views; only upstreamtrain fetched, no own random image split.',
                    'Source segmentation has one waste category, no four-bin semantic identity or hand boxes; must add by visual review.',
                    '1485sourcefiles does not mean1485physicalobjects; no new camera-station captures.'])
    (out/'result.json').write_text(json.dumps(result,indent=2),encoding='utf8');print(result,flush=True)


if __name__=='__main__':main()
