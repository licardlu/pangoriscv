"""Acquire three already indexed public detection sources for local review only."""
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import zipfile
import requests


def main():
    root = Path('build/joint_battery_resume_20261118_001/research/new_detection_indexes_002')
    def acquire(key):
        directory = root/key
        index = json.loads((directory/'index.json').read_text())
        path = directory/'source.zip'
        if not path.exists():
            temporary = directory/'source.partial'
            with requests.get(index['url'], stream=True, timeout=(12, 45)) as response:
                response.raise_for_status()
                with temporary.open('wb') as stream:
                    for chunk in response.iter_content(1024*1024): stream.write(chunk)
            assert temporary.stat().st_size == index['archive_bytes']
            temporary.replace(path)
        assert path.stat().st_size == index['archive_bytes']
        raw = (directory/'raw').resolve(); raw.mkdir(exist_ok=True)
        with zipfile.ZipFile(path) as archive:
            assert {(i.filename, i.CRC, i.file_size) for i in archive.infolist()} == {(r['name'], r['crc'], r['size']) for r in index['entries']}
            for info in archive.infolist():
                target = (raw/info.filename).resolve()
                assert target == raw or raw in target.parents
                if any(p.lower() in ('test', 'val', 'valid') for p in Path(info.filename).parts): continue
                if info.is_dir(): target.mkdir(parents=True, exist_ok=True); continue
                target.parent.mkdir(parents=True, exist_ok=True)
                data = archive.read(info)
                if target.exists(): assert target.read_bytes() == data
                else: target.write_bytes(data)
        report = dict(status='ACQUIRED_FOR_REVIEW_NOT_TRAINING', source=index['source'], version=index['version'],
            archive_bytes=path.stat().st_size, archive_sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
            raw=str(raw), images_admitted=0, upstream_test_valid_contents_extracted=False)
        (directory/'acquisition.json').write_text(json.dumps(report, indent=2), encoding='utf8')
        print(report, flush=True)
        return report
    with ThreadPoolExecutor(max_workers=3) as pool:
        list(pool.map(acquire, ['plastic', 'cardboard', 'household_clutter']))


if __name__ == '__main__': main()
