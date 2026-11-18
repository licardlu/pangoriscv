"""Inspect three discovered repositories without fetching held-out contents."""
from concurrent.futures import ThreadPoolExecutor
import json
from pathlib import Path
import requests

REPOS = ['B11200044/YOLO-Battery-Detection', 'Fetan-Love/AI-battery-detection-with-yolo',
         'Wissem-Sahli-Engineer/Recycling_Sorting_Computer_Vision_YOLO']


def main():
    out = Path('build/noon_continuation_20261118_001/research/battery_visual_001')
    def inspect(repo):
        folder = out/repo.replace('/', '_')
        folder.mkdir(exist_ok=False)
        try:
            r = requests.get(f'https://api.github.com/repos/{repo}/git/trees/main',
                             params=dict(recursive=1), timeout=(10, 35))
            r.raise_for_status()
            tree = r.json()
            (folder/'tree.json').write_text(json.dumps(tree, indent=2), encoding='utf8')
            assert not tree.get('truncated')
            blobs = [x for x in tree['tree'] if x['type'] == 'blob']
            images = [x for x in blobs if Path(x['path']).suffix.lower() in ['.jpg', '.jpeg', '.png']]
            labels = [x for x in blobs if Path(x['path']).suffix.lower() in ['.txt', '.xml', '.json']]
            references = [x for x in blobs if x['path'].lower().endswith(('readme.md', 'license', 'license.md', 'license.txt', 'data.yaml', 'dataset.yaml'))
                          and x.get('size', 0) < 100000 and not any(p in ['test', 'valid', 'val'] for p in Path(x['path']).parts)]
            for i, b in enumerate(references[:12]):
                url = f"https://raw.githubusercontent.com/{repo}/{tree['sha']}/{b['path']}"
                response = requests.get(url, timeout=(10, 25))
                (folder/f'reference_{i}.json').write_text(json.dumps(dict(path=b['path'], url=url,
                    status_code=response.status_code, text=response.text), indent=2), encoding='utf8')
            result = dict(repo=repo, tree_sha=tree['sha'], images=len(images), label_paths=len(labels),
                          image_samples=[x['path'] for x in images[:8]], label_samples=[x['path'] for x in labels[:8]],
                          references=[x['path'] for x in references], contents_not_downloaded=True)
        except Exception as error:
            result = dict(repo=repo, error=repr(error))
        (folder/'result.json').write_text(json.dumps(result, indent=2), encoding='utf8')
        return result
    with ThreadPoolExecutor(max_workers=2) as pool:
        for result in pool.map(inspect, REPOS):
            print(json.dumps(result), flush=True)


if __name__ == '__main__':
    main()
