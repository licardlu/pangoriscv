"""Freeze one all-class old-source replay hypothesis; no validation-example selection."""
import argparse
from collections import Counter
from pathlib import Path
import shutil
from adapt_quant_heads import read,save,sha
from train_qat_tail import verify


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--reference',type=Path,required=True);p.add_argument('--out',type=Path,required=True)
    a=p.parse_args();reference=a.reference.resolve();prior=verify(reference);root=a.out.resolve()
    assert not root.exists() and read(reference/'pipeline_state.json')['status']=='COMPLETED_OFFLINE_REVIEWED_SHAPE_QAT'
    exp=root/'experiment_001';data=root/'dataset_001';exp.mkdir(parents=True);data.mkdir()
    rows=read(reference/'unique_train.json');draws=read(reference/'draw_indices.json')
    # A source-wide rule, not hand-picked errors or material-specific examples.
    replay=[i for i,r in enumerate(rows) if r['source'] in ['sumn2u','codingbear']]
    assert len(replay)==619 and all(rows[i]['split']=='train' for i in replay)
    draws=draws+replay*2;held=[r for r in read(prior['manifest']) if r['split']!='train']
    manifest=[dict(rows[i],source_retention_draw=j) for j,i in enumerate(draws)]+held
    save(data/'manifest.json',manifest)
    for split in ['train','val']:(data/(split+'.txt')).write_text(''.join(r['prepared_image']+'\n' for r in manifest if r['split']==split),encoding='utf8')
    (data/'data.yaml').write_text('path: '+data.as_posix()+'\ntrain: train.txt\nval: val.txt\nnc: 5\nnames: [kitchen, recyclable, hazardous, other, hand]\n',encoding='utf8')
    for name in ['unique_train.json','targets.json']:shutil.copyfile(reference/name,exp/name)
    save(exp/'draw_indices.json',draws);plan=dict(prior)
    plan.update(hypothesis='Public data additions and thirteen-tail adaptation improve public development recognition, but old source kitchen/glass/paper localization and recall are not retained. Increase replay of every existing train image from both original diverse public sources sumn2u and codingbear by exactly two extra draws, without choosing validation errors or changing source boxes. Keep all9349 file identities, original deployment initialization, thirteen tail convolutions, no-waste auxiliary strength0.5/top32, teacher5, frozen BN/scales, optimizer and fixed three epochs. Original validation/test boundary and all gates remain unchanged. One fixed source-retention hypothesis, no threshold/epoch sweep or failed-weight continuation.',
        manifest=str(data/'manifest.json'),manifest_sha256=sha(data/'manifest.json'),
        draws_per_epoch=len(draws),draw_indices_sha256=sha(exp/'draw_indices.json'),
        unique_train_sha256=sha(exp/'unique_train.json'),target_reference=str(exp/'targets.json'),target_reference_sha256=sha(exp/'targets.json'),
        reuse_feature_cache=str(reference),replay_source_rule={'sumn2u':2,'codingbear':2},
        replay_extra_draws=len(replay)*2,replay_sources=dict(Counter(rows[i]['source'] for i in replay)),
        negative_waste_training_draws=sum(not any(int(b[0])<4 for b in rows[i]['boxes']) for i in draws),
        unchanged_reference_plan=str(reference/'plan.json'),unchanged_reference_plan_sha256=sha(reference/'plan.json'),
        count_note=f'Same9349 file identities, zero new images; {len(draws)} repeated draws per epoch includes1238 additional old-source replays. Not20000qualified originals.')
    save(exp/'plan.json',plan)
    frozen=exp/'frozen_scripts';frozen.mkdir()
    for name in ['prepare_source_retention_qat.py','negative_waste_supervision.py','train_qat_tail.py','qat_tail.py',
        'fiveclass_distillation.py','run_predeclared_qat_queue.py','export_qat_tail.py']:
        shutil.copyfile(Path(__file__).with_name(name),frozen/name)
    verify(exp);save(data/'result.json',dict(status='FROZEN_SOURCE_RETENTION_REPLAY',unique_files=len(rows),draws=len(draws),
        extra_draws=len(replay)*2,new_images=0,source_rule={'sumn2u':2,'codingbear':2},
        original_initialization=True,heldout_rows_unchanged=True,final_test_read=False))
    print(dict(experiment=str(exp),files=len(rows),draws=len(draws)),flush=True)


if __name__=='__main__':main()
