"""Archive completed public-data experiment evidence without source photographs."""
import hashlib,json,shutil,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[4]
root=Path(sys.argv[1]).resolve();out=ROOT/'evidence/records/optimization/public_expansion_20261117_001'
out.mkdir(parents=True,exist_ok=False)
def read(p):return json.loads(Path(p).read_text(encoding='utf8'))
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
state=read(root/'evaluation_state_retry_002.json')
assert state['status']=='completed_rejected_float' and not state['float_gate_pass']
assert not state['board_accessed'] and not state['held_out_test_used']
cp=root/'runs/train_001/weights/best.pt'
assert sha(cp)==state['checkpoint_sha256']
files=['dedup_report.json','dataset_report.json','preflight_integrity.json','review_ledger.json',
       'evaluation_state.json','evaluation_state_retry_002.json',
       'runs/train_001/provenance.json','runs/train_001/progress.json','runs/train_001/results.csv',
       'runs/train_001/hyp.yaml','runs/train_001/opt.yaml',
       'runs/candidate_oldval_float_001/metrics.json','runs/candidate_oldval_float_001/provenance.json',
       'runs/baseline_publicdev_float_002/metrics.json','runs/candidate_publicdev_float_002/metrics.json',
       'replay_oldval_001/result.json','replay_oldval_001/decisions.json',
       'replay_publicdev_001/result.json','replay_publicdev_001/decisions.json',
       'baseline_publicdev_float_001.log']
for name in files:
    p=root/name
    if not p.exists():continue
    target=out/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(p,target)
sources=['project/trash_sorting/training/collect_public_expansion.py',
         'project/trash_sorting/training/audit_public_expansion.py',
         'project/trash_sorting/training/review_public_expansion.py',
         'project/trash_sorting/training/inventory_public_hands.py',
         'project/trash_sorting/training/freeze_public_expansion.py',
         'project/trash_sorting/training/train_four_bins.py',
         'project/trash_sorting/tools/overnight/evaluate_public_expansion.py',
         'project/trash_sorting/tools/overnight/record_public_expansion.py',
         'docs/overnight-20261116/PUBLIC_EXPANSION_20261117.md']
for name in sources:
    p=ROOT/name;target=out/'sources'/p.name;target.parent.mkdir(exist_ok=True);shutil.copyfile(p,target)
inputs={str(p.relative_to(ROOT)):sha(p) for p in [root/'dataset_003/manifest.json',root/'public_dev_003/manifest.json',
        root/'dedup_inventory.json',cp,ROOT/'build/overnight_20261116/runs/continuation_stage4_002/weights/best.pt',
        ROOT/'project/trash_sorting/candidates/continuation_023/source/yolo/model/model.bin']}
result=dict(status='COMPLETED_REJECTED_CANDIDATE',reason='Float gate: fewer correct positive/glass despite improved background/battery counts',
    dataset=read(root/'dataset_report.json'),oldval_float=state['oldval_float'],publicdev_float=state['publicdev_float'],
    checkpoint=str(cp),checkpoint_sha256=sha(cp),input_identities=inputs,
    no_quantization_after_failed_float_gate=True,board_accessed=False,held_out_test_used=False,
    deployment_changed=False,training_epochs=3,training_seconds=1049.0180640220642,
    limitation='Repeated development validation; not independent physical instances, Q15 or camera accuracy. Public-dev only17 images.',
    artifact_hashes={str(p.relative_to(out)):sha(p) for p in out.rglob('*') if p.is_file()})
(out/'result.json').write_text(json.dumps(result,indent=2),encoding='utf8')
print(json.dumps(dict(status=result['status'],evidence=str(out),checkpoint_sha256=sha(cp)),indent=2),flush=True)
