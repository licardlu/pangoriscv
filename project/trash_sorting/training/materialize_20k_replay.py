"""Give intentional replay draws distinct paths because YOLO cache keys collapse duplicates.

Aliases are hard links, not new independent images. Preserve the frozen source
dataset and create a new manifest listing each draw and its original identity.
"""
from pathlib import Path
import argparse,collections,hashlib,json,os,shutil

ap=argparse.ArgumentParser();ap.add_argument('root',type=Path);ap.add_argument('--out-name',required=True)
a=ap.parse_args();root=a.root.resolve()
assert Path(a.out_name).name==a.out_name
src=root/'dataset_001';out=root/a.out_name;out.mkdir(exist_ok=False)
rows=json.loads((src/'manifest.json').read_text(encoding='utf8'))
lookup={r['prepared_image']:r for r in rows}
paths=(src/'train.txt').read_text(encoding='utf8').splitlines()
seen=collections.Counter();draws=[];alias_count=0
for path in paths:
    r=lookup[path];seen[path]+=1
    if seen[path]==1:
        draws.append(dict(r,replay_draw=1));continue
    original=Path(path);stem=original.stem+'_replay_'+str(seen[path])
    target=out/'images/train'/(stem+original.suffix)
    label=out/'labels/train'/(stem+'.txt')
    oldlabel=Path(original.as_posix().replace('/images/','/labels/')).with_suffix('.txt')
    assert oldlabel.is_file(),oldlabel
    for a,b in [(original,target),(oldlabel,label)]:
        b.parent.mkdir(parents=True,exist_ok=True)
        try:os.link(a,b)
        except OSError:shutil.copyfile(a,b)
    draws.append(dict(r,prepared_image=target.as_posix(),stem=stem,
                      replay_draw=seen[path],replay_of=path))
    alias_count+=1
assert len({r['prepared_image'] for r in draws})==len(paths)
assert len({r['image_sha256'] for r in draws})==7906
allrows=draws+[r for r in rows if r['split']!='train']
(out/'manifest.json').write_text(json.dumps(allrows,indent=2),encoding='utf8')
(out/'train.txt').write_text(''.join(r['prepared_image']+'\n' for r in draws),encoding='utf8')
shutil.copyfile(src/'val.txt',out/'val.txt')
(out/'data.yaml').write_text(f'path: {out.as_posix()}\ntrain: train.txt\nval: val.txt\nnc: 5\nnames: [kitchen, recyclable, hazardous, other, hand]\n',encoding='utf8')
report=dict(status='FROZEN_REPLAY_ALIASES_NOT_NEW_IMAGES',training_draws=len(draws),
 unique_train_file_identities=len({r['image_sha256'] for r in draws}),alias_count=alias_count,
 primary_bin_draws=dict(collections.Counter(r['primary_bin'] for r in draws)),
 reason='Upstream YOLO label cache is keyed by path and collapses repeated lines. Distinct hardlinked aliases implement the intended replay without inventing new data.',
 original_validation_unchanged=(out/'val.txt').read_bytes()==(src/'val.txt').read_bytes())
(root/'replay_materialization.json').write_text(json.dumps(report,indent=2),encoding='utf8')
(root/(out.name+'_sha256.json')).write_text(json.dumps({p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in out.iterdir() if p.is_file()},indent=2),encoding='utf8')
print(json.dumps(report),flush=True)
