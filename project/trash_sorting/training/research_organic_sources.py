"""Bounded source research for missing organic/ordinary-waste detection scenes.

Metadata only: classification categories do not supply detection labels.
"""
from concurrent.futures import ThreadPoolExecutor
import json
from pathlib import Path
import requests


def main():
    out = Path('build/noon_continuation_20261118_001/research/organic_001')
    out.mkdir(exist_ok=False)
    jobs = [('kaggle', 'food waste detection'), ('kaggle', 'organic garbage'),
            ('github', 'food waste object detection dataset in:readme')]
    def fetch(job):
        provider, query = job
        name = provider+'_'+query.replace(' ', '_').replace(':', '_')
        try:
            url = 'https://www.kaggle.com/api/v1/datasets/list' if provider == 'kaggle' else 'https://api.github.com/search/repositories'
            params = {'search': query, 'pageSize': 15} if provider == 'kaggle' else {'q': query, 'per_page': 10}
            r = requests.get(url, params=params, timeout=(10, 25)); r.raise_for_status()
            value = r.json()
            (out/(name+'.json')).write_text(json.dumps(value, indent=2), encoding='utf8')
            items = value if provider == 'kaggle' else value['items']
            return {'provider':provider, 'query':query, 'items':[
                {k:x.get(k) for k in (['ref','licenseName','totalBytes','title'] if provider == 'kaggle' else ['full_name','description'])}
                for x in items]}
        except Exception as error:
            result = {'provider':provider, 'query':query, 'error':repr(error)}
            (out/(name+'_error.json')).write_text(json.dumps(result, indent=2), encoding='utf8')
            return result
    with ThreadPoolExecutor(max_workers=2) as pool:
        for result in pool.map(fetch, jobs):
            print(json.dumps(result, ensure_ascii=True), flush=True)


if __name__ == '__main__':
    main()
