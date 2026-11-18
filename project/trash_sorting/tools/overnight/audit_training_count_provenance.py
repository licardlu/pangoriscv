"""Report file/draw counts separately from known derivations and source-photo evidence."""
import argparse
from collections import Counter
from pathlib import Path
from adapt_quant_heads import read,save,sha


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--experiment',type=Path,required=True);p.add_argument('--out',type=Path,required=True)
    a=p.parse_args();exp=a.experiment.resolve();out=a.out.resolve();assert not out.exists()
    rows=read(exp/'unique_train.json');draws=read(exp/'draw_indices.json');plan=read(exp/'plan.json')
    assert len(rows)==plan['unique_train'] and len(draws)==plan['draws_per_epoch']
    assert len({r['image_sha256'] for r in rows})==len(rows)
    assert all(r['split']=='train' for r in rows) and all(0<=i<len(rows) for i in draws)
    sources={};audit=[]
    for r in rows:
        reasons=[]
        if r.get('augmentation_degrees_ccw') is not None:reasons.append('explicit_rotation')
        if r.get('crop_xyxy') or r.get('derived_crop') or r.get('derived_empty_crop'):reasons.append('explicit_crop')
        if r['source']=='mark_battery_crop':reasons.append('mark_crop_source')
        if r.get('count_as_new_source_photo') is False or r.get('new_source_photograph') is False:reasons.append('explicit_do_not_count_as_source')
        if r['source']=='derived_battery_orientation':reasons.append('rotation_source')
        # Upstream Roboflow filename alone does not reveal whether it is an
        # original, transformed copy, or the only available view; keep separate.
        upstream_rf='.rf.' in str(r.get('source_file',r.get('source_relative','')))
        source=sources.setdefault(r['source'],Counter())
        source['files']+=1;source['known_derived']+=bool(reasons);source['upstream_rf_identity_uncertain']+=upstream_rf
        audit.append(dict(stem=r.get('stem',Path(r['prepared_image']).stem),source=r['source'],
            image_sha256=r['image_sha256'],known_derived=bool(reasons),derived_reasons=reasons,
            parent_image_sha256=r.get('parent_image_sha256',r.get('parent_sha256')),
            original_sha256=r.get('original_sha256'),source_sha256=r.get('source_sha256'),
            upstream_rf_identity_uncertain=upstream_rf))
    parents={r['image_sha256']:r['image_sha256'] for r in rows}
    def find(x):
        if x not in parents:parents[x]=x
        while parents[x]!=x:
            parents[x]=parents[parents[x]];x=parents[x]
        return x
    for r in audit:
        child=r['image_sha256'];parent=r['parent_image_sha256']
        if not parent and r['known_derived']:parent=r['original_sha256']
        if parent:parents[find(child)]=find(parent)
    result=dict(status='COMPLETED_METADATA_ONLY_COUNT_AUDIT',training_file_identities=len(rows),
        draws_per_epoch=len(draws),known_derived_files=sum(r['known_derived'] for r in audit),
        files_without_explicit_derivation_evidence=sum(not r['known_derived'] for r in audit),
        metadata_parent_groups=len({find(r['image_sha256']) for r in audit}),
        upstream_rf_files_with_uncertain_original_identity=sum(r['upstream_rf_identity_uncertain'] for r in audit),
        independent_original_photographs_certified=None,qualified_20000_target_achieved=False,
        sources={s:dict(v) for s,v in sources.items()},
        evidence_sha256={name:sha(exp/name) for name in ['unique_train.json','draw_indices.json','plan.json']},
        limitations=['Files without explicit derivation evidence are NOT certified originals.',
            'Metadata parent groups are not physical objects, sessions, or independent photographs.',
            'Existing public sources may contain upstream augmentations and unknown shared physical identity.',
            'Repeated draws, rotations, crops, orientation-normalized copies do not create new original photos.',
            'Only train metadata was read; no final-test images or labels accessed.'])
    out.mkdir(parents=True);save(out/'result.json',result);save(out/'identity_ledger.json',audit)
    text=['# 训练数量与来源证据核对','',f'训练文件身份：{len(rows)}；每轮采样：{len(draws)}。',
        f'明确含裁剪、旋转等派生证据的文件：{result["known_derived_files"]}。',
        f'未见明确派生证据的文件：{result["files_without_explicit_derivation_evidence"]}，此数不是已认证独立原图数。',
        f'可按父哈希合并的元数据身份组：{result["metadata_parent_groups"]}，仍不代表独立照片或实物。',
        '', '2万张合格原图目标未完成。上游增强与未知实物/拍摄身份未自动计为独立原图。','',
        '| 来源 | 文件 | 明确派生 | 上游RF身份待核 |','|---|---:|---:|---:|']
    text.extend(f'| {s} | {v["files"]} | {v["known_derived"]} | {v["upstream_rf_identity_uncertain"]} |' for s,v in sorted(sources.items()))
    (out/'count_audit.md').write_text('\n'.join(text)+'\n',encoding='utf8')
    print({k:v for k,v in result.items() if k not in ['sources','limitations','evidence_sha256']},flush=True)


if __name__=='__main__':main()
