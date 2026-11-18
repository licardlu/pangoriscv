"""Predeclare fixed-scale QAT recovery of the one final supervised checkpoint.

This is a deliberate continuation of a rejected candidate to address its
quantization gap, never a deployment acceptance or checkpoint sweep.
"""
import argparse
from pathlib import Path
import shutil
from adapt_quant_heads import read,save,sha
from train_qat_tail import verify


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--reference',type=Path,required=True)
    p.add_argument('--full-experiment',type=Path,required=True)
    p.add_argument('--out',type=Path,required=True)
    a=p.parse_args();ref,full,out=a.reference.resolve(),a.full_experiment.resolve(),a.out.resolve()
    prior=verify(ref);result=read(full/'evaluation/state.json')
    assert read(full/'pipeline_state.json')['status']=='COMPLETED_OFFLINE_FULL_CONTINUATION'
    preflight=read(full.parent/'preflight_tail_001/result.json')
    cp=full/'training/final.pt';profile=full/'evaluation/quant'
    assert preflight['status']=='PASS' and preflight['post_gradient_step_nonhead_export_bit_exact']
    assert sha(cp)==preflight['checkpoint_sha256']==result['checkpoint_sha256']
    assert sha(profile/'bundle/bundle.json')==preflight['bundle_sha256']
    assert result['float_scores']['float_oldval']['correct_personal_battery']==56
    assert result['q15_oldval']['correct_personal_battery']==49
    out.mkdir(parents=True,exist_ok=False)
    for name in ['unique_train.json','targets.json','draw_indices.json']:
        shutil.copyfile(ref/name,out/name)
    plan=dict(prior)
    plan.pop('reuse_feature_cache',None);plan.pop('reference_cache_requirement',None)
    plan.update(hypothesis='The fixed10-epoch feature continuation improved held-scene dev56to66 and glass232to235 but lost battery55to49 inQ15; its float battery56toQ15 49 identifies a quantization gap. Continue this single final checkpoint with its own predeclared160-train calibration scales through exactQ15 tail training, on the identical8508-file reviewed context dataset. Only initialization/matching fixed profile changes relative to the already frozen contextQAT. Keep3epochs, optimizer/loss/trainable layers and unchanged gates. No calibration, threshold or epoch sweep; rejection of the parent remains in effect until every offline gate passes.',
        checkpoint=str(cp),checkpoint_sha256=sha(cp),
        scale_profile=str(profile/'bundle'),bundle_sha256=sha(profile/'bundle/bundle.json'),
        parameters_sha256=sha(profile/'bundle/parameters.npz'),graph_source=str(profile/'graph.json'),
        scale_provenance=str(profile/'provenance.json'),
        initialization='One fixed-final10epoch supervised checkpoint and its one matching predeclared160-current-train calibration; parent rejected and not deployed. Not a best-of-epoch selection.',
        calibration_note='Freeze the already derived full-continuation profile, not the older deployment profile; do not recalibrate or search scales.',
        target_reference=str(out/'targets.json'),target_reference_sha256=sha(out/'targets.json'),
        unique_train_sha256=sha(out/'unique_train.json'),draw_indices_sha256=sha(out/'draw_indices.json'),
        preflight_sha256=sha(full.parent/'preflight_tail_001/result.json'),
        parent_full_plan_sha256=sha(full/'plan.json'),parent_full_result_sha256=sha(full/'evaluation/state.json'),
        feature_cache='Recompute from this new initialization; cross-model cache reuse forbidden.',
        deadline_utc='2026-11-18T04:00:00Z')
    save(out/'plan.json',plan)
    frozen=out/'frozen_scripts';frozen.mkdir()
    for name in ['prepare_full_recovery_qat.py','train_qat_tail.py','qat_tail.py','export_qat_tail.py',
                 'evaluate_quant_head_adaptation.py','run_predeclared_qat_queue.py']:
        shutil.copyfile(Path(__file__).parent/name,frozen/name)
    verify(out);print(dict(experiment=str(out),unique_train=plan['unique_train'],draws=plan['draws_per_epoch']),flush=True)


if __name__=='__main__':main()
