"""Bounded metadata search for real hand-held scenes and battery detection.

Does not revisit blocked Drive/Roboflow links or admit any pictures.
"""
from concurrent.futures import ThreadPoolExecutor
import json
from pathlib import Path
import requests


def main():
    out=Path('build/noon_continuation_20261118_001/research/handheld_mirrors_001')
    out.mkdir(exist_ok=False)
    jobs=[('kaggle','mju waste'),('kaggle','handheld waste'),('kaggle','battery detection'),
          ('github','MJU waste dataset'),('github','battery detection dataset in:name,description')]
    def fetch(job):
        provider,query=job;name=provider+'_'+query.replace(' ','_').replace(':','_').replace(',','_')
        try:
            url='https://www.kaggle.com/api/v1/datasets/list' if provider=='kaggle' else 'https://api.github.com/search/repositories'
            params={'search':query,'pageSize':20} if provider=='kaggle' else {'q':query,'per_page':15}
            r=requests.get(url,params=params,timeout=(10,25));r.raise_for_status();value=r.json()
            (out/(name+'.json')).write_text(json.dumps(value,indent=2),encoding='utf8')
            items=value if provider=='kaggle' else value['items']
            return dict(provider=provider,query=query,items=[{k:x.get(k) for k in
                (['ref','licenseName','totalBytes','title'] if provider=='kaggle' else ['full_name','description'])} for x in items])
        except Exception as error:
            result=dict(provider=provider,query=query,error=repr(error))
            (out/(name+'_error.json')).write_text(json.dumps(result),encoding='utf8');return result
    with ThreadPoolExecutor(max_workers=2) as pool:
        for result in pool.map(fetch,jobs):print(json.dumps(result,ensure_ascii=True),flush=True)


if __name__=='__main__':main()
