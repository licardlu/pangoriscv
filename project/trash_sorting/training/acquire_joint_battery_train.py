"""Fetch only public upstream train pairs, preserve blob identities for review."""
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import requests


def main():
    source = Path('build/noon_continuation_20261118_001/research/battery_visual_001/B11200044_YOLO-Battery-Detection')
    tree = json.loads((source/'tree.json').read_text())
    assert tree['sha'] == '2f3e291772dbcf6a8c69a09e22a2c11dbf10d945'
    files = {r['path']:r for r in tree['tree'] if r['type']=='blob'}
    images = [r for p,r in files.items() if p.startswith('data/train/images/') and p.endswith('.png')]
    assert len(images) == 80
    root = Path('build/joint_battery_resume_20261118_001/research/b112_train_001')
    root.mkdir(exist_ok=False); (root/'images').mkdir(); (root/'labels').mkdir()
    repo = 'B11200044/YOLO-Battery-Detection'
    base = f'https://raw.githubusercontent.com/{repo}/{tree["sha"]}/'
    for name in ['data.yaml','split.py','xml2txt.py']:
        response = requests.get(base+name, timeout=(10,25))
        (root/(name+'.response.json')).write_text(json.dumps(dict(url=base+name,
            status_code=response.status_code, text=response.text), indent=2), encoding='utf8')
    def fetch(image):
        stem = Path(image['path']).stem
        row = dict(id='b112_'+stem, source_split='train', source_commit=tree['sha'],
                   repo=repo, source_image=image['path'])
        try:
            with requests.Session() as session:
                for kind, item in [('images',image), ('labels',files['data/train/labels/'+stem+'.txt'])]:
                    url = base+item['path']
                    response = session.get(url, timeout=(10,25))
                    response.raise_for_status(); body=response.content
                    assert len(body)==item['size']
                    assert hashlib.sha1(b'blob '+str(len(body)).encode()+b'\0'+body).hexdigest()==item['sha']
                    path = root/kind/Path(item['path']).name; path.write_bytes(body)
                    row[kind]=str(path.resolve()); row[kind+'_sha256']=hashlib.sha256(body).hexdigest()
                    row[kind+'_url']=url
            row['status']='DOWNLOADED_FOR_REVIEW_NOT_TRAINING'
        except Exception as e:
            row.update(status='FAILED', error=repr(e))
        print(row['id'], row['status'], flush=True)
        return row
    with ThreadPoolExecutor(max_workers=3) as pool:
        rows=list(pool.map(fetch, images))
    (root/'inventory.json').write_text(json.dumps(rows,indent=2),encoding='utf8')
    report=dict(complete=sum(r['status']=='DOWNLOADED_FOR_REVIEW_NOT_TRAINING' for r in rows),
        failed=sum(r['status']=='FAILED' for r in rows), images_admitted=0,
        source_valid_test_contents_read=False,
        provenance_note='Public GitHub upstream training files; no root LICENSE found in pinned tree, no separate photo grant verified. Retain provenance; images not redistributed. Acquisition for local review is not training admission.')
    (root/'result.json').write_text(json.dumps(report,indent=2),encoding='utf8')
    print(report,flush=True)


if __name__=='__main__':
    main()
