"""Freeze a controlled increase in trainable Q15 tail layers on identical data."""
from pathlib import Path
import shutil
from adapt_quant_heads import ROOT,read,save,sha
from train_qat_tail import verify


def main():
    reference=ROOT/'build/joint_balanced_sources_20261118_001/experiment_001'
    prior=verify(reference)
    check=ROOT/'build/expanded_tail_preflight_20261118_001/result.json';preflight=read(check)
    assert preflight['status']=='PASS_TRAIN_ONLY_EXPANDED_TAIL_PREFLIGHT'
    assert preflight['checkpoint_sha256']==prior['checkpoint_sha256'] and preflight['profile_sha256']==prior['bundle_sha256']
    out=ROOT/'build/joint_expanded_tail_20261118_001/experiment_001';out.mkdir(parents=True,exist_ok=False)
    for name in ['unique_train.json','draw_indices.json','targets.json']:shutil.copyfile(reference/name,out/name)
    plan=dict(prior)
    plan.update(hypothesis='Original three-output-convolution QAT repeatedly leaves handheld battery and glass errors; fixed early feature cuts and only three trainable output convolutions restrict adaptation. On exactly the same8975-file reviewed fiveclass data and17274draws as joint_balanced_sources, unfreeze13 existing Q15 tail convolutions instead of3 while preserving original deployment initialization, all BN, all earlier graphops0..64, scales/LUTs, losses, GT-gated deployedteacherstrength5, optimizer, fixed3epochs and gates. This isolates trainable capacity, not morephotos or an epoch/threshold sweep. Preflight verifies all new gradients, frozen state, and bitexact integer export on train-only inputs.',
        trainable_prefixes=preflight['trainable_prefixes'],expected_trainable_conv_tensors=preflight['expected_trainable_conv_tensors'],
        trained_q15_ops=preflight['trained_q15_ops'],expanded_tail_preflight=str(check),expanded_tail_preflight_sha256=sha(check),
        reuse_feature_cache=str(reference),unique_train_sha256=sha(out/'unique_train.json'),
        draw_indices_sha256=sha(out/'draw_indices.json'),target_reference=str(out/'targets.json'),
        target_reference_sha256=sha(out/'targets.json'),
        frozen='All graph operations0..64, all BN parameters/stats, anchors, all preactivation/activation scales and LUTs, and all nonselected parameters.',
        count_note='Same8975 training file identities and17274samplingdraws as preceding frozen dataset; includes existing derived views. Zero added photos and no new field validation in this experiment.')
    save(out/'plan.json',plan)
    frozen=out/'frozen_scripts';frozen.mkdir()
    for name in ['prepare_expanded_tail.py','preflight_expanded_tail.py','train_qat_tail.py','qat_tail.py',
                 'fiveclass_distillation.py','export_qat_tail.py','evaluate_quant_head_adaptation.py','run_predeclared_qat_queue.py']:
        shutil.copyfile(Path(__file__).parent/name,frozen/name)
    verify(out);print(dict(experiment=str(out),trainable_q15_ops=plan['trained_q15_ops'],data_unchanged=True),flush=True)


if __name__=='__main__':main()
