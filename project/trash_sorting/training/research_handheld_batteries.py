"""Save bounded public metadata for real battery detection/hand context gaps."""
from concurrent.futures import ThreadPoolExecutor
import json
from pathlib import Path
import requests


def main():
    out=Path('build/noon_continuation_20261118_001/research/handheld_battery_001');out.mkdir(exist_ok=False)
    jobs=[('github','battery dataset object detection in:readme'),
          ('github','battery dataset hand in:readme'),
          ('huggingface','battery'),('huggingface','MJU')]
    def fetch(job):
        provider,query=job;name=provider+'_'+query.replace(' ','_').replace(':','_')
        try:
            url='https://api.github.com/search/repositories' if provider=='github' else 'https://huggingface.co/api/datasets'
            params={'q':query,'per_page':15} if provider=='github' else {'search':query,'limit':20}
            r=requests.get(url,params=params,timeout=(10,25));r.raise_for_status();value=r.json()
            (out/(name+'.json')).write_text(json.dumps(value,indent=2),encoding='utf8')
            items=value['items'] if provider=='github' else value
            return dict(provider=provider,query=query,items=[{k:x.get(k) for k in (['full_name','description'] if provider=='github' else ['id','tags'])} for x in items])
        except Exception as error:
            result=dict(provider=provider,query=query,error=repr(error));(out/(name+'_error.json')).write_text(json.dumps(result),encoding='utf8');return result
    with ThreadPoolExecutor(max_workers=2) as pool:
        for result in pool.map(fetch,jobs):print(json.dumps(result,ensure_ascii=True),flush=True)


if __name__=='__main__':main()
