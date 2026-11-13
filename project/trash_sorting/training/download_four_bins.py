"""Download the pinned public archives; verify hashes before safe extraction."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
from pathlib import Path
import shutil
import zipfile
import requests

SOURCES = [
    ('codingbearhsun-trash-sort-v1.zip', 'codingbear',
     'https://www.kaggle.com/api/v1/datasets/download/codingbearhsun/trash-sort?datasetVersionNumber=1',
     130139535, '517db4508ec12dfca9a2141e1e537bdd6419ceff7622d353bb83e26d57c9062d'),
    ('sumn2u-bbox384-v1.zip', 'sumn2u',
     'https://www.kaggle.com/api/v1/datasets/download/sumn2u/garbage-classification-v2-bbox-384?datasetVersionNumber=1',
     264249231, 'a2e92666290ae41477c70f40558ab654c24a1263449a2e56a2288ca15cf2cbbf'),
    ('yolov5-v7.0.zip', '', 'https://codeload.github.com/ultralytics/yolov5/zip/refs/tags/v7.0',
     1042849, 'a40568a7979c4b27195d198987e49610de86b038b044f2521f5515455571f852')]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', type=Path, required=True)
    a = ap.parse_args()
    a.out.mkdir(parents=True, exist_ok=True)
    for filename, directory, url, size, sha in SOURCES:
        target = a.out/filename
        if not target.exists():
            # Bounded connections avoid a single long, stalled download.
            step = 4*1024*1024
            partial = a.out/(filename+'.parts')
            partial.mkdir(exist_ok=True)
            def chunk(i):
                lo, hi = i*step, min(size,(i+1)*step)-1
                dest = partial/str(i)
                if dest.exists() and dest.stat().st_size==hi-lo+1:
                    return dest
                for attempt in range(3):
                    try:
                        r = requests.get(url, headers={'Range':f'bytes={lo}-{hi}'}, timeout=(20,45))
                        r.raise_for_status()
                        if lo==0 and hi==size-1 and len(r.content)==size:
                            pass
                        elif r.status_code!=206 or r.headers.get('Content-Range')!=f'bytes {lo}-{hi}/{size}':
                            raise ValueError('Server did not return the requested byte range')
                        if len(r.content)!=hi-lo+1:
                            raise ValueError('Incomplete range')
                        dest.write_bytes(r.content)
                        print(filename, i, 'downloaded', flush=True)
                        return dest
                    except Exception:
                        if attempt==2:
                            raise
            with ThreadPoolExecutor(max_workers=4) as ex:
                parts = list(ex.map(chunk, range((size+step-1)//step)))
            with target.open('wb') as f:
                for part in parts:
                    f.write(part.read_bytes())
        if target.stat().st_size!=size or hashlib.sha256(target.read_bytes()).hexdigest()!=sha:
            raise ValueError('Archive hash mismatch: '+str(target))
        destination = (a.out/directory).resolve()
        with zipfile.ZipFile(target) as z:
            for info in z.infolist():
                if not (destination/info.filename).resolve().is_relative_to(destination):
                    raise ValueError('Archive path escapes destination')
            if z.testzip() is not None:
                raise ValueError('Bad ZIP CRC')
            z.extractall(destination)
        partial = a.out/(filename+'.parts')
        if partial.exists():
            # This exact task-owned directory is inside the requested output.
            assert partial.resolve().parent==a.out.resolve()
            shutil.rmtree(partial)
        print(filename, 'SHA256 and ZIP CRC passed', flush=True)


if __name__=='__main__':
    main()
