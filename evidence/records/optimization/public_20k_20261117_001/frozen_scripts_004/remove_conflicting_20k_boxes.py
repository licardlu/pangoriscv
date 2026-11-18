"""Reject overlapping conflicting public labels, preserving frozen inputs."""
from pathlib import Path
import collections,hashlib,json,shutil,sys
root=Path(sys.argv[1]).resolve();src=root/'dataset_003';out=root/'dataset_004'
rows=json.loads((src/'manifest.json').read_text(encoding='utf8'))
bad=json.loads((root/'contradictory_box_audit.json').read_text(encoding='utf8'))
ids={x['stem'] for x in bad}
def original_stem(r):return Path(r.get('replay_of',r['prepared_image'])).stem
kept=[r for r in rows if original_stem(r) not in ids]
assert len(rows)-len(kept)==2
out.mkdir(exist_ok=False)
lookup={r['prepared_image']:r for r in kept}
paths=(src/'train.txt').read_text(encoding='utf8').splitlines()
paths=[p for p in paths if p in lookup]
assert len(set(paths))==len(paths)==12662
assert len({r['image_sha256'] for r in kept if r['split']=='train'})==7904
(out/'manifest.json').write_text(json.dumps(kept,indent=2),encoding='utf8')
(out/'train.txt').write_text(''.join(p+'\n' for p in paths),encoding='utf8')
shutil.copyfile(src/'val.txt',out/'val.txt')
(out/'data.yaml').write_text((src/'data.yaml').read_text(encoding='utf8').replace('dataset_003','dataset_004'),encoding='utf8')
report=dict(training_draws=len(paths),unique_train_file_identities=7904,rejected=bad,
            primary_bin_draws=dict(collections.Counter(lookup[p]['primary_bin'] for p in paths)),
            original_val_unchanged=(out/'val.txt').read_bytes()==(src/'val.txt').read_bytes())
(root/'dataset_004_audit.json').write_text(json.dumps(report,indent=2),encoding='utf8')
(root/'dataset_004_sha256.json').write_text(json.dumps({p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in out.iterdir() if p.is_file()},indent=2),encoding='utf8')
print(json.dumps(report),flush=True)
