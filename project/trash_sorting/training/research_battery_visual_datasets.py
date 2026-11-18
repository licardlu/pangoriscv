"""Bounded visual battery-detection reference search; metadata only."""
from concurrent.futures import ThreadPoolExecutor
import json
from pathlib import Path
import requests


def main():
    out = Path('build/noon_continuation_20261118_001/research/battery_visual_001')
    out.mkdir(exist_ok=False)
    queries = ['battery detection yolo in:name,description',
               'battery dataset object detection in:name,description',
               'batteries dataset in:name,description',
               'battery detection -fault -anomaly -defect -charge -sleep in:name']
    def fetch(pair):
        i, q = pair
        try:
            r = requests.get('https://api.github.com/search/repositories',
                             params=dict(q=q, per_page=30, sort='stars'), timeout=(10, 25))
            r.raise_for_status()
            value = r.json()
            (out/f'search_{i}.json').write_text(json.dumps(value, indent=2), encoding='utf8')
            return dict(query=q, items=[{k: x.get(k) for k in ['full_name', 'description', 'size', 'default_branch']}
                                        for x in value['items']])
        except Exception as e:
            result = dict(query=q, error=repr(e))
            (out/f'search_{i}_error.json').write_text(json.dumps(result), encoding='utf8')
            return result
    with ThreadPoolExecutor(max_workers=2) as pool:
        for result in pool.map(fetch, enumerate(queries)):
            print(json.dumps(result, ensure_ascii=True), flush=True)


if __name__ == '__main__':
    main()
