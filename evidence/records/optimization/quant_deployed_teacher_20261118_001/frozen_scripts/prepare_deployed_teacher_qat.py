"""Predeclare GT-gated original-Q15 preservation, not expanded-float teaching."""
import argparse
from pathlib import Path
import shutil
from adapt_quant_heads import read,save,sha
from train_qat_tail import verify


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--reference',type=Path,required=True)
    parser.add_argument('--out',type=Path,required=True)
    args=parser.parse_args();ref=args.reference.resolve();out=args.out.resolve()
    prior=verify(ref)
    assert prior['checkpoint_sha256']=='a4a0b1b04f83af1d114813e0512dd2c2fa5e7306fae16759824f136b3133021a'
    assert prior['unique_train']==8578 and prior['epochs']==3
    out.mkdir(parents=True,exist_ok=False)
    for name in ['unique_train.json','targets.json','draw_indices.json']:
        shutil.copyfile(ref/name,out/name)
    plan=dict(prior)
    plan.update(hypothesis='Supervised tailQAT on new data forgets previously reliable hand-held batteries. Preserve only correct GT-matched anchors of the frozen original deployed Q15 teacher while learning the identical8578-file reviewed dataset. Earlier distillation used expanded floating head-only teaching and failed; this distinct test uses deployed integer features and trains the three tail convolutions too. Keep same fixed3epochs, optimizer/loss/scales/sampler and all gates; add one class-balanced distillation term of strength5, chosen once to match the existing distillation convention, without coefficient sweep or pseudo labels.',
        reuse_feature_cache=str(ref),
        unique_train_sha256=sha(out/'unique_train.json'),draw_indices_sha256=sha(out/'draw_indices.json'),
        target_reference=str(out/'targets.json'),target_reference_sha256=sha(out/'targets.json'),
        deployed_q15_distillation_strength=5.,teacher_checkpoint_sha256=prior['checkpoint_sha256'],
        teacher_rule='Only GT class match, objectness*class>=0.25 and bboxIoU>=0.5; class-balanced across all five classes. Teacher frozen/no-grad; no generated boxes, no background pseudo labels. Teacher not exported.',
        reference_cache_requirement='Identical model/profile and unique-file order; cache arrays/identities verified before reuse.',
        latest_start_utc='2026-11-18T02:45:00Z')
    save(out/'plan.json',plan)
    frozen=out/'frozen_scripts';frozen.mkdir()
    for name in ['prepare_deployed_teacher_qat.py','train_qat_tail.py','fiveclass_distillation.py',
                 'test_fiveclass_distillation.py','qat_tail.py','export_qat_tail.py',
                 'evaluate_quant_head_adaptation.py','run_predeclared_qat_queue.py']:
        shutil.copyfile(Path(__file__).parent/name,frozen/name)
    verify(out);print(dict(experiment=str(out),train_files=8578,strength=5.,epochs=3),flush=True)


if __name__=='__main__':main()
