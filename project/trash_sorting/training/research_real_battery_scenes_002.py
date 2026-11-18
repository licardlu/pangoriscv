"""Save targeted public source metadata, without admitting image labels."""
from concurrent.futures import ThreadPoolExecutor
import json
from pathlib import Path
import requests


def main():
    out=Path('build/joint_battery_resume_20261118_001/research/real_battery_scenes_002')
    out.mkdir(exist_ok=False)
    jobs=[('kaggle','battery detection'),('kaggle','battery photos'),
          ('kaggle','AA battery'),('kaggle','battery waste'),
          ('github','"battery" "dataset" "object detection" in:readme -awesome -papers'),
          ('github','"battery" "Roboflow" in:readme -awesome -papers'),
          ('github','"waste" "dataset" "handheld" in:readme -awesome -papers'),
          ('github','"battery" "images" "recycling" in:readme -awesome -papers')]
    def get(pair):
        i,(provider,q)=pair
        url='https://www.kaggle.com/api/v1/datasets/list' if provider=='kaggle' else 'https://api.github.com/search/repositories'
        params=dict(search=q,pageSize=40) if provider=='kaggle' else dict(q=q,per_page=30,sort='stars')
        try:
            response=requests.get(url,params=params,timeout=(12,35));response.raise_for_status()
            value=response.json();(out/f'{i:02d}.json').write_text(json.dumps(value,indent=2))
            items=value if provider=='kaggle' else value['items']
            fields=['ref','title','licenseName','totalBytes'] if provider=='kaggle' else ['full_name','description','size']
            return dict(provider=provider,query=q,items=[{k:x.get(k) for k in fields} for x in items])
        except Exception as error:return dict(provider=provider,query=q,error=repr(error))
    with ThreadPoolExecutor(max_workers=2) as pool:
        results=list(pool.map(get,enumerate(jobs)))
    (out/'summary.json').write_text(json.dumps(results,indent=2))
    for result in results:print(json.dumps(result),flush=True)


if __name__=='__main__':main()
