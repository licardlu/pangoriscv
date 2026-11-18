"""Inspect actual public archive directories and configs before downloading."""
from concurrent.futures import ThreadPoolExecutor
import json
from pathlib import Path
import zipfile
from research_20k_sources import RangeZip

SOURCES = {
    'magbridge': ('sakthigsj/magbridge-battery', 1),
    'plastic': ('dataclusterlabs/plastic-object-detection-dataset', 1),
    'cardboard': ('dataclusterlabs/cardboard-object-detection', 1),
    'garbage': ('hammadarshad18/garbage-detection', 1),
    'household_cc0': ('dataclusterlabs/household-trash', 1),
}


def main():
    root = Path('build/joint_battery_resume_20261118_001/research')
    def inspect(pair):
        key, (ref, version) = pair
        out = root/'indexes'/key; out.mkdir(parents=True, exist_ok=False)
        try:
            url = f'https://www.kaggle.com/api/v1/datasets/download/{ref}?datasetVersionNumber={version}'
            remote = RangeZip(url)
            with zipfile.ZipFile(remote) as z:
                entries = [dict(name=i.filename, size=i.file_size, compressed=i.compress_size,
                                offset=i.header_offset, crc=i.CRC) for i in z.infolist()]
                configs = []
                for i in z.infolist():
                    name = Path(i.filename).name.lower()
                    if name in ['data.yaml','dataset.yaml','classes.txt','readme.md','readme.txt','license','license.txt'] and i.file_size < 100000:
                        text = z.read(i).decode('utf8', errors='replace')
                        configs.append([i.filename, text])
                images = [e for e in entries if Path(e['name']).suffix.lower() in ['.jpg','.jpeg','.png','.bmp','.webp']]
                labels = [e for e in entries if Path(e['name']).suffix.lower() in ['.txt','.json','.xml']]
                result = dict(source=ref, version=version, url=url, archive_bytes=remote.length,
                              etag=remote.etag, entries=entries, configs=configs,
                              images=len(images), labels=len(labels), transferred=remote.transferred,
                              image_samples=[e['name'] for e in images[:8]],
                              label_samples=[e['name'] for e in labels[:8]])
                (out/'index.json').write_text(json.dumps(result, indent=2), encoding='utf8')
                return {k:v for k,v in result.items() if k != 'entries'}
        except Exception as e:
            result = dict(source=ref, error=repr(e))
            (out/'error.json').write_text(json.dumps(result), encoding='utf8')
            return result
    with ThreadPoolExecutor(max_workers=3) as pool:
        for result in pool.map(inspect, SOURCES.items()):
            print(json.dumps(result), flush=True)


if __name__ == '__main__':
    main()
