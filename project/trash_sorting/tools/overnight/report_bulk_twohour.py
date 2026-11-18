"""Write a truthful final report for the consolidated run, after all checks finish."""
import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
from adapt_quant_heads import ROOT, read, save, sha


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--experiment', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    exp = args.experiment.resolve()
    pipeline = read(exp/'pipeline_state.json')
    assert pipeline['status'] == 'COMPLETED_BULK_OFFLINE_EVALUATION', pipeline
    assert all(s['status'] == 'completed' for s in pipeline['steps'])
    plan = read(exp/'plan.json')
    training = read(exp/'training/result.json')
    progress = read(exp/'run/progress.json')
    evaluation = read(exp/'evaluation/state.json')
    audit = read(exp.parent/'loader_audit_001/result.json')
    hard = [json.loads(line) for line in (exp/'run/hard_negative_epochs.jsonl').read_text(encoding='utf8').splitlines()]
    assert progress['epoch'] == training['epochs'] == plan['epochs'] == 4
    assert [r['epoch'] for r in hard] == [1, 2, 3, 4]
    assert all(r['training_batches'] == audit['expected_batches_per_epoch'] for r in hard)
    checkpoint = exp/'training/final.pt'
    assert sha(checkpoint) == training['checkpoint_sha256'] == evaluation['checkpoint_sha256']
    assert (exp/'evaluation/targeted_regressions/result.json').exists()
    primary_samples_total = progress['epoch'] * audit['effective_primary_samples_per_epoch']
    blob = ROOT/'project/trash_sorting/candidates/continuation_023/source/yolo/model/model.bin'
    assert sha(blob) == '7a0765a6f275f3c06d838f924d73542783ca55e131509aa1b546efc98bd65728'
    background_root = ROOT/'build/held_background_dev_20261118_001'
    background = read(background_root/exp.parent.name/'state.json')
    bgbase = read(background_root/'baseline_deployed_001/state.json')
    continuation = read(exp/'evaluation/continuation_comparison.json')
    base, new = evaluation['baseline_q15'], evaluation['q15_oldval']
    floating = evaluation['float_scores']['float_oldval']
    def metric(counts, key, denominator):
        n, d = counts[key], counts['denominators'][denominator]
        return f'{n}/{d} ({100*n/d:.2f}%)' if d else str(n)
    def link(path, label=None):
        return f'[{label or path.name}](<{path.as_posix()}>)'
    accepted = evaluation['accepted_offline']
    status = '通过既定离线替换门槛，待用户审阅与上板实测' if accepted else '未通过全部替换门槛，保留为研究候选'
    lines = ['# 两小时整包训练交付', '', status+'。', '',
             f'授权窗口：{plan["authorized_start_utc"]} 至 {plan["deadline_utc"]}。报告生成：{datetime.now(timezone.utc).isoformat()}。',
             f'固定四轮已完成。训练阶段耗时 {training["elapsed_s"]/60:.1f} 分钟（含初始化、加载及末轮验证）；batch 64，8 个 CPU 线程，320 输入，冻结前 4 块及其 BN，其余特征层和检测头联合训练。', '',
             '## 实际数据与训练量', '',
             f'本轮使用已有 {audit["effective_primary_samples_per_epoch"]} 个唯一训练文件，没有增加新的原始照片。每轮 147 批，四轮 588 批、37,396 次主样本加载。Mosaic 等增强的额外图源读取不算新增原图。',
             '原请求清单的 19,260 行被 YOLO 标签缓存按相同路径合并，平衡回放未生效。原冻结计划保留作为请求证据，实际数量以独立加载器审计和运行日志为准。',
             '文件中至少 995 张已有明确裁剪或旋转派生证据；其余文件也未经独立原图认证。2 万张合格独立原图目标未完成。', '',
             '| 场景 | 实际每轮文件数 |', '|---|---:|']
    for name, count in audit['effective']['contexts'].items():
        lines.append(f'| {name} | {count} |')
    lines += ['', '完整五类 GT 保留；难负样本只在 GT 无垃圾图中挖掘，并排除已有正锚点。', '',
              '| 轮次 | 批数 | 可挖掘图次数 | 实际难负锚点 |', '|---|---:|---:|---:|']
    lines.extend(f'| {r["epoch"]} | {r["training_batches"]} | {r["eligible_images"]} | {r["mined_anchors"]} |' for r in hard)
    lines += ['', '## 固定策略识别结果', '',
              '旧开发验证集共 1,929 张：1,793 张含垃圾、136 张无垃圾。主体正确要求类别和定位 IoU≥0.5；电池/玻璃是其中子集。无垃圾误选越少越好。', '',
              '| 指标 | 原部署 Q15 | 本轮浮点 | 本轮真实 C 整数 Q15 |', '|---|---:|---:|---:|']
    for title, key, denom in [('主体正确', 'correct_positive', 'positive'), ('电池正确', 'correct_personal_battery', 'personal_battery'), ('玻璃正确', 'correct_public_glass', 'public_glass'), ('无垃圾误选', 'false_background', 'background')]:
        lines.append(f'| {title} | {metric(base,key,denom)} | {metric(floating,key,denom)} | {metric(new,key,denom)} |')
    lines += ['', f'公开开发集主体正确：{metric(evaluation["baseline_publicdev"],"correct_positive","positive")} → {metric(evaluation["q15_publicdev"],"correct_positive","positive")}。',
              '浮点同口径基线为主体1457、电池54、玻璃231、无垃圾误选8；表格第一列是原部署Q15，不能用它替代浮点基线。',
              f'手持开发集（77 张）：{continuation["baseline_correct"]} → {continuation["candidate_correct"]}；新增正确 {len(continuation["gains"])} 张，新增错误 {len(continuation["losses"])} 张。',
              f'额外复杂背景开发集：含垃圾主体正确 {metric(bgbase["counts"],"correct_positive","positive")} → {metric(background["counts"],"correct_positive","positive")}；空背景误选 {metric(bgbase["counts"],"false_background","background")} → {metric(background["counts"],"false_background","background")}。该集合只有 27 张视图且存在同源裁剪相关性，不能代表现场表现。', '',
              '| 主体类别 | 图片数 | 原部署正确 | 本轮正确 |', '|---|---:|---:|---:|']
    names = ['厨余', '可回收', '有害', '其他']
    for c, name in enumerate(names):
        b, n = evaluation['subject_by_class']['baseline'][str(c)], evaluation['subject_by_class']['candidate'][str(c)]
        lines.append(f'| {name} | {b["images"]} | {b["correct"]} | {n["correct"]} |')
    lines += ['', '## 门槛与限制', '', '| 检查 | 结果 |', '|---|---|']
    lines.extend(f'| {name} | {"通过" if passed else "未通过"} |' for name, passed in evaluation['gates'].items())
    lines += ['', '| 检测类别 | TP 原/新 | Precision 原/新 | 该类检查 |', '|---|---:|---:|---|']
    for name, r in evaluation['detection_gates'].items():
        lines.append(f'| {name} | {r["TP_before"]}/{r["TP_after"]} | {r["precision_before"]:.4f}/{r["precision_after"]:.4f} | {"通过" if r["passed"] else "未通过"} |')
    lines += ['', '以上集合已反复用于开发，不是独立最终测试；本轮没有读取最终测试图片或标签。没有按验证结果挑选中间轮次、调阈值或放宽门槛。',
              '训练文件中纯空背景仅 24 张，这是背景抑制的数据短板。后续优先补充实际摄像头空场、杂乱背景、手伸入/移出和手持小电池等完整标注场景；增加独立物体和拍摄场景比重复现有图片更有价值。',
              '部署必须检查整数结果；浮点提升不能代替板端量化结果。此次未自动替换正在使用的模型，未操作布局布线、UART、上板或存储启动。', '',
              '## 交付文件', '',
              '- '+link(checkpoint,'最终浮点权重 final.pt'),
              '- '+link(exp/'evaluation/quant','校准量化导出目录'),
              '- '+link(exp.parent/'loader_audit_001/loader_audit.md','实际加载数量审计'),
              '- '+link(exp/'evaluation/state.json','完整评估结果与门槛'),
              '- '+link(exp/'evaluation/targeted_regressions','电池、玻璃、空手错误诊断'),
              '- '+link(exp/'evaluation/error_gallery','各类增益、退步和持续错误画廊'),
              '- '+link(exp/'training.log','完整训练日志'), '',
              f'最终权重 SHA256：`{sha(checkpoint)}`。',
              f'原部署模型 SHA256：`{sha(blob)}`。', '']
    args.out.parent.mkdir(parents=True, exist_ok=True)
    assert not args.out.exists()
    args.out.write_text('\n'.join(lines), encoding='utf8')
    save(exp/'verified_delivery.json', dict(status='VERIFIED_BULK_DELIVERY', accepted_offline=accepted,
        actual_primary_samples_per_epoch=audit['effective_primary_samples_per_epoch'],
        actual_epochs=progress['epoch'], actual_primary_samples_total=primary_samples_total,
        requested_draws_per_epoch_effective=False, new_original_photographs=0,
        qualified_20000_original_target_achieved=False, report=str(args.out.resolve()),
        checkpoint_sha256=sha(checkpoint), original_deployment_sha256=sha(blob),
        finished_utc=datetime.now(timezone.utc).isoformat()))
    print(args.out, flush=True)


if __name__ == '__main__':
    main()
