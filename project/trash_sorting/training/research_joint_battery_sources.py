"""New bounded source search, persisted metadata only, not dataset admission."""
from concurrent.futures import ThreadPoolExecutor
import json
from pathlib import Path
import requests


def main():
    root = Path('build/joint_battery_resume_20261118_001/research/source_round_001')
    root.mkdir(parents=True, exist_ok=False)
    jobs = [('github', q) for q in [
        'battery dataset yolo in:readme -lithium-ion -soc -soh -BMS',
        'batteries detection dataset in:readme',
        'battery object detection dataset in:name,description',
        'handheld battery detection in:readme']]
    jobs += [('kaggle_view', ref) for ref in [
        'sakthigsj/magbridge-battery', 'siddhantmaji/unified-waste-classification-dataset',
        'dataclusterlabs/plastic-object-detection-dataset',
        'dataclusterlabs/cardboard-object-detection', 'hammadarshad18/garbage-detection']]
    jobs += [('hf', 'battery'), ('hf', 'waste detection')]
    def fetch(job):
        kind, query = job
        params = {}
        if kind == 'github':
            url = 'https://api.github.com/search/repositories'
            params = dict(q=query, per_page=30, sort='updated')
        elif kind == 'kaggle_view':
            url = 'https://www.kaggle.com/api/v1/datasets/list'
            params = dict(search=query, pageSize=10)
        else:
            url = 'https://huggingface.co/api/datasets'
            params = dict(search=query, limit=30)
        stem = kind+'_'+''.join(c if c.isalnum() else '_' for c in query)
        try:
            r = requests.get(url, params=params, timeout=(10, 30))
            r.raise_for_status(); value = r.json()
            (root/(stem+'.json')).write_text(json.dumps(value, indent=2), encoding='utf8')
            items = value.get('items', []) if kind == 'github' else value
            if kind == 'github':
                result = [{k:x.get(k) for k in ['full_name','description','size','default_branch']} for x in items]
            elif kind == 'kaggle_view':
                result = [{k:x.get(k) for k in ['ref','licenseName','totalBytes','description']} for x in items]
            else:
                result = [{k:x.get(k) for k in ['id','downloads','tags']} for x in items]
            return dict(kind=kind, query=query, items=result)
        except Exception as e:
            result = dict(kind=kind, query=query, error=repr(e))
            (root/(stem+'_error.json')).write_text(json.dumps(result), encoding='utf8')
            return result
    with ThreadPoolExecutor(max_workers=3) as pool:
        results = list(pool.map(fetch, jobs))
    (root/'summary.json').write_text(json.dumps(results, indent=2), encoding='utf8')
    for r in results:
        print(json.dumps(r), flush=True)


if __name__ == '__main__':
    main()
