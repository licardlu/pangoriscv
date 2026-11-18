"""Summarize paired train-only feature diagnostics without acceptance claims."""
from pathlib import Path
import shutil
from adapt_quant_heads import ROOT,read,save,sha


def main():
    root=ROOT/'build/train_quant_gap_20261118_001'
    a=read(root/'baseline_002/result.json');b=read(root/'full_final_002/result.json')
    assert a['sample_sha256']==b['sample_sha256'] and a['train_only'] and b['train_only']
    sample=read(root/'baseline_002/sample.json')
    assert len(sample)==50 and all(r['split']=='train' for r in sample)
    lines=['# 2026-11-18 同一50张train的量化特征诊断','',
           '这不是独立验证或准确率。固定按主类各取10张train，比较各模型自己的浮点与Q15特征；两版使用同一图片顺序，没有打开最终test、调整校准列表或改变任何训练数据。','',
           '| 图节点 | 模块 | 原部署有害类相对RMSE | 全特征候选有害类相对RMSE |','|---|---|---:|---:|']
    metrics={}
    for key,layer in a['layers'].items():
        candidate=b['layers'][key]
        lines.append(f"| {key} | {layer['module']} | {layer['per_class']['2']:.3f} | {candidate['per_class']['2']:.3f} |")
        metrics[key]=dict(baseline=layer['per_class']['2'],candidate=candidate['per_class']['2'])
    lines += ['',
        '相对误差从前层到深层累计；两版都有该现象。候选81节点有害类误差0.450，原版0.426；三个head中的前两个候选平均误差反而较小。因此不能只凭单个RMSE数字断言电池退步来自某一层，不能据此扫校准尺度。',
        '本样本各抽取层的int8输出极值占比很低，未支持“大规模输出截断”解释。该统计只测输出端点，不能排除preactivation截断、乘数离散误差或少数关键位置受损。',
        '下一项已冻结的恢复QAT保留该候选现有校准profile，通过训练使检测适应定点特征；按原逐类验收判断，不能把算术一致或特征RMSE降低当识别通过。','',
        '初版直接使用包含可选primary_bin缺项的新manifest导致两次KeyError，未计算指标；失败目录保留。第二版仅在单独train诊断元数据副本按最大框/空图补主类字段，原manifest、图片、标签和在途实验未变。','',
        f"样本SHA `{a['sample_sha256']}`；原部署checkpoint `{a['checkpoint_sha256']}`；候选checkpoint `{b['checkpoint_sha256']}`。",'']
    note=ROOT/'docs/overnight-20261116/TRAIN_QUANT_GAP_20261118_001.md'
    note.write_text('\n'.join(lines),encoding='utf8')
    evidence=ROOT/'evidence/records/optimization/train_quant_gap_20261118_001';evidence.mkdir(exist_ok=False)
    for key in ['baseline_002','full_final_002','metadata_001']:
        dest=evidence/key;dest.mkdir()
        for name in ['result.json','sample.json','provenance.json']:
            if (root/key/name).exists():shutil.copyfile(root/key/name,dest/name)
    shutil.copyfile(note,evidence/note.name)
    save(evidence/'summary.json',dict(train_only=True,images=50,held_test_opened=False,acceptance_modified=False,
        sample_sha256=a['sample_sha256'],battery_bucket_metrics=metrics,board_accessed=False))
    save(evidence/'archive_sha256.json',{str(p.relative_to(evidence)):sha(p) for p in evidence.rglob('*') if p.is_file()})
    print(note,flush=True)


if __name__=='__main__':main()
