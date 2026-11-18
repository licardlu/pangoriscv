"""Acquire only18upstreamtrain battery pairs with Git blob verification."""
from concurrent.futures import ThreadPoolExecutor
import argparse
import base64
import hashlib
import json
from pathlib import Path
import requests


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--blob-failed', action='store_true', help='One bounded Git-blob recovery of failed raw downloads; preserve original evidence.')
    args = parser.parse_args()
    root = Path('build/noon_continuation_20261118_001/research/battery_visual_001/Fetan-Love_AI-battery-detection-with-yolo_retry_001')
    tree = json.loads((root/'tree.json').read_text(encoding='utf8'))
    assert tree['sha'] == '7679a920e4dc919c50fdcc437a5ec63b82205cbc'
    files = {x['path']: x for x in tree['tree'] if x['type'] == 'blob'}
    images = [x for p, x in files.items() if p.startswith('datasets/images/train/') and p.endswith('.jpg')]
    assert len(images) == 18
    if args.blob_failed:
        previous = json.loads((root/'train_acquisition_001/inventory.json').read_text(encoding='utf8'))
        failed = {r['stem'] for r in previous if r['status']=='FAILED'}
        images = [x for x in images if Path(x['path']).stem in failed]
    out = root/('train_blob_recovery_001' if args.blob_failed else 'train_acquisition_001')
    out.mkdir(exist_ok=False)
    (out/'images').mkdir(); (out/'labels').mkdir()
    def fetch(image):
        stem = Path(image['path']).stem
        row = dict(stem=stem, source_split='train')
        try:
            for kind, blob in [('images', image), ('labels', files['datasets/labels/train/'+stem+'.txt'])]:
                url = (f"https://api.github.com/repos/Fetan-Love/AI-battery-detection-with-yolo/git/blobs/{blob['sha']}" if args.blob_failed else
                       f"https://raw.githubusercontent.com/Fetan-Love/AI-battery-detection-with-yolo/{tree['sha']}/{blob['path']}")
                response = requests.get(url, timeout=(10, 25))
                response.raise_for_status()
                data = base64.b64decode(response.json()['content']) if args.blob_failed else response.content
                assert len(data) == blob['size']
                assert hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest() == blob['sha']
                path = out/kind/Path(blob['path']).name
                path.write_bytes(data)
                row[kind] = str(path.resolve()); row[kind+'_sha256'] = hashlib.sha256(data).hexdigest()
                row[kind+'_source_url'] = url
            row['status'] = 'DOWNLOADED_FOR_REVIEW_NOT_ADMITTED'
        except Exception as error:
            row.update(status='FAILED', error=repr(error))
        print(row['stem'], row['status'], flush=True)
        return row
    with ThreadPoolExecutor(max_workers=2) as pool:
        rows = list(pool.map(fetch, images))
    (out/'inventory.json').write_text(json.dumps(rows, indent=2), encoding='utf8')
    result = dict(complete=sum(r['status'].startswith('DOWNLOADED_') for r in rows),
                  failed=sum(r['status']=='FAILED' for r in rows), training_admitted=0,
                  source_split='train', valid_test_contents_read=False,
                  license_note='RootUnlicense verified; no separate dataset permission statement; provenance must remain visible.')
    (out/'result.json').write_text(json.dumps(result, indent=2), encoding='utf8')
    print(result, flush=True)


if __name__ == '__main__':
    main()
