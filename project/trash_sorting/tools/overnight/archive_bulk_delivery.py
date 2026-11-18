"""Publish small useful model/evidence assets, never feature caches or raw archives."""
from pathlib import Path
import shutil
from adapt_quant_heads import ROOT, read, save, sha


def main():
    exp=ROOT/'build/bulk_twohour_20261118_001/experiment_001'
    delivery=read(exp/'verified_delivery.json')
    assert delivery['status']=='VERIFIED_BULK_DELIVERY'
    evidence=ROOT/'evidence/records/optimization/bulk_twohour_20261118_001'
    models=ROOT/'project/trash_sorting/training/candidates/bulk_twohour_20261118_001'
    evidence.mkdir(exist_ok=False)
    models.mkdir(parents=True,exist_ok=False)
    files=['plan.json','calibration_reference.json','image_identity_recovery.json','unique_train.json','draw_indices.json',
           'training/result.json','run/provenance.json','run/progress.json','run/hard_negative_epochs.jsonl',
           'run/results.csv','training.log','pipeline_state.json','pipeline_state_failed_jpeg_001.json',
           'delivery.json','verified_delivery.json','evaluation/state.json','evaluation/continuation_comparison.json',
           'evaluation/quant/provenance.json','evaluation/numeric_oldval/result.json',
           'evaluation/numeric_publicdev/result.json','evaluation/score_oldval/result.json',
           'evaluation/score_publicdev/result.json','evaluation_failed_jpeg_001/state.json',
           'evaluation_failed_jpeg_001/quantize.log']
    for relative in files:
        source=exp/relative
        if source.exists():
            destination=evidence/relative;destination.parent.mkdir(parents=True,exist_ok=True)
            shutil.copyfile(source,destination)
    for relative in ['frozen_scripts','evaluation/error_gallery','evaluation/targeted_regressions','evaluation/recognition_coverage']:
        shutil.copytree(exp/relative,evidence/relative)
    for name in ['loader_audit_001/result.json','loader_audit_001/loader_audit.md',
                 'cleanup_feature_manifest_001.json','cleanup_feature_result_001.json']:
        destination=evidence/name;destination.parent.mkdir(parents=True,exist_ok=True)
        shutil.copyfile(exp.parent/name,destination)
    shutil.copyfile(ROOT/'build/held_background_dev_20261118_001/bulk_twohour_20261118_001/state.json',evidence/'background_dev_state.json')
    model_records={}
    plan=read(exp/'plan.json')
    for name,source in [('final_rejected.pt',exp/'training/final.pt'),('baseline_stage4.pt',Path(plan['checkpoint']))]:
        shutil.copyfile(source,models/name)
        model_records[name]=dict(sha256=sha(source),bytes=source.stat().st_size,original_path=str(source))
    blob=exp/'evaluation/quant/packed/model.bin'
    assert blob.exists()
    shutil.copyfile(blob,models/'model_rejected.bin')
    model_records['model_rejected.bin']=dict(sha256=sha(blob),bytes=blob.stat().st_size,original_path=str(blob))
    save(models/'identities.json',dict(status='OFFLINE_REJECTED_DO_NOT_DEPLOY',models=model_records,
        final_checkpoint_matches_evaluation=model_records['final_rejected.pt']['sha256']==delivery['checkpoint_sha256'],
        active_deployment_unchanged=True,training_images_not_in_this_folder=True))
    (models/'README.md').write_text('# 本次整包离线模型\n\n`final_rejected.pt`和`model_rejected.bin`未通过电池及逐类无退步门槛，只用于复现与诊断，禁止直接替换当前部署。\n\n`baseline_stage4.pt`是本次初始化的原部署对应浮点权重；继续训练应先看仓库根目录`00_接手先读_20261119.md`。权重身份见`identities.json`。图片和标签没有放在此目录，移机必须另行转移。\n',encoding='utf8')
    save(evidence/'archive_sha256.json',{str(p.relative_to(evidence)):sha(p) for p in evidence.rglob('*') if p.is_file()})
    print(dict(evidence=str(evidence),models=str(models),model_records=model_records),flush=True)


if __name__=='__main__':
    main()
