"""Save public battery/held-waste source metadata; no images enter training."""
import concurrent.futures
import json
from pathlib import Path

import requests


def main():
    out=Path('build/noon_continuation_20261118_001/research')
    out.mkdir(exist_ok=True)
    jobs=[('kaggle','battery images'),('kaggle','battery object'),
          ('github','battery detection dataset in:readme'),
          ('github','handheld waste dataset in:readme')]
    def get(job):
        provider,q=job
        if provider=='kaggle':
            url='https://www.kaggle.com/api/v1/datasets/list';params={'search':q,'pageSize':30}
        else:
            url='https://api.github.com/search/repositories';params={'q':q,'per_page':15}
        name=provider+'_'+q.replace(' ','_').replace(':','_')
        try:
            r=requests.get(url,params=params,timeout=(12,30));r.raise_for_status();v=r.json()
            (out/(name+'.json')).write_text(json.dumps(v,indent=2),encoding='utf8')
            items=v if provider=='kaggle' else v['items']
            return provider,q,[(x['ref'],x.get('licenseName'),x.get('totalBytes')) for x in items] if provider=='kaggle' else [(x['full_name'],x.get('description')) for x in items]
        except Exception as e:
            return provider,q,repr(e)
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        for value in pool.map(get,jobs):print(json.dumps(value,ensure_ascii=True),flush=True)


if __name__=='__main__':main()
