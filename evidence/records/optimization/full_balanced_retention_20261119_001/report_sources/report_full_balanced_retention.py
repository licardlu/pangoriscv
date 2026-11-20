"""Publish verified model/result assets after one complete fixed training run."""
import argparse
from datetime import datetime,timezone
from pathlib import Path
import shutil
from adapt_quant_heads import ROOT,read,save,sha


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--experiment',type=Path,required=True)
    exp=parser.parse_args().experiment.resolve();name=exp.parent.name
    plan=read(exp/'plan.json');training=read(exp/'training/result.json');ev=read(exp/'evaluation/state.json')
    assert ev['status'].startswith('COMPLETED_') and read(exp/'run/progress.json')['epoch']==8
    checkpoint=exp/'training/final.pt';assert sha(checkpoint)==training['checkpoint_sha256']==ev['checkpoint_sha256']
    evidence=ROOT/'evidence/records/optimization'/name;evidence.mkdir(exist_ok=False)
    models=ROOT/'project/trash_sorting/training/candidates'/name;models.mkdir(exist_ok=False)
    blob=exp/'evaluation/quant/packed/model.bin'
    for filename,source in [('final.pt',checkpoint),('model.bin',blob)]:shutil.copyfile(source,models/filename)
    save(models/'identities.json',dict(status='OFFLINE_ACCEPTED_FOR_REVIEW' if ev['accepted_offline'] else 'OFFLINE_REJECTED_DO_NOT_DEPLOY',
        checkpoint_sha256=sha(checkpoint),blob_sha256=sha(blob),board_programmed=False,epochs=8,
        actual_primary_samples_total=154080,unique_train_files=9349,new_original_photos=0))
    (models/'README.md').write_text('# 固定八轮全数据训练模型\n\n是否通过离线门槛见`identities.json`及仓库docs/overnight-20261116中的同名报告。未自动部署，不能把文件存在当作已通过板测。原图标签在本机build中的共享数据集，未复制进该模型目录。\n',encoding='utf8')
    continuation=read(exp/'evaluation/continuation_comparison.json')
    background=read(ROOT/'build/held_background_dev_20261118_001'/name/'state.json')
    counts=ev['q15_oldval'];base=ev['baseline_q15'];floating=ev['float_scores']['float_oldval']
    lines=['# '+name+' 整包联合训练', '',
        '通过固定离线门槛，可供后续现场审阅。' if ev['accepted_offline'] else '未通过全部离线替换门槛，保留原部署模型。', '',
        f'固定八轮已完成，batch64、8CPU线程、冻结前10块及其BN、学习率3e-5。训练阶段耗时{training["elapsed_s"]/60:.1f}分钟。',
        '共享已审核数据，实际每轮19,260条不同回放路径、301批，共154,080次主样本加载。来自9,349个文件，含至少995个已知派生视图；未新增原图，不等于15万张照片。2万合格独立原图目标仍未完成。',
        '所有四类垃圾和手部联合训练，有害类回放6,889次/轮。原部署权重初始化，冻结更多早层并降低学习率，避免直接延续已经退步的权重。固定末轮，不用验证集选择中间权重或阈值。', '',
        '| 指标 | 原部署Q15 | 本轮浮点 | 本轮Q15/C |','|---|---:|---:|---:|']
    for key,title in [('correct_positive','主体正确 /1793'),('correct_personal_battery','电池 /60'),('correct_public_glass','玻璃 /242'),('false_background','无垃圾误选 /136，低为好')]:
        lines.append(f'| {title} | {base[key]} | {floating[key]} | {counts[key]} |')
    lines += ['', '浮点同口径基线为主体1457、电池54、玻璃231、误选8，不能用Q15第一列替代浮点基线。',
        f'公开dev：{ev["baseline_publicdev"]["correct_positive"]}/712→{ev["q15_publicdev"]["correct_positive"]}/712。',
        f'77张手持开发：{continuation["baseline_correct"]}→{continuation["candidate_correct"]}；增益{len(continuation["gains"])}、退步{len(continuation["losses"])}。',
        f'额外复杂背景：主体{background["counts"]["correct_positive"]}/17，空场误选{background["counts"]["false_background"]}/10；27张相关视图不代表现场。', '',
        '| 验收项 | 通过 |','|---|---|']
    lines += [f'| {k} | {v} |' for k,v in ev['gates'].items()]
    lines += ['', '| 检测类别 | TP：原部署→本轮 | Precision：原部署→本轮 | 通过 |', '|---|---:|---:|---|']
    for label,row in ev['detection_gates'].items():
        lines.append(f'| {label} | {row["TP_before"]}→{row["TP_after"]} | {row["precision_before"]:.3f}→{row["precision_after"]:.3f} | {row["passed"]} |')
    lines += ['', '| 垃圾类别主体正确 | 原部署Q15 | 本轮Q15/C | 图片数 |', '|---|---:|---:|---:|']
    for c,title in enumerate(['厨余','可回收','有害','其他']):
        before=ev['subject_by_class']['baseline'][str(c)]
        after=ev['subject_by_class']['candidate'][str(c)]
        lines.append(f'| {title} | {before["correct"]} | {after["correct"]} | {after["images"]} |')
    targeted=read(exp/'evaluation/targeted_regressions/result.json')['cohorts']
    lines += ['', '| 重点开发分组 | 新增正确 | 新增错误 | 浮点正确但整数错误 |', '|---|---:|---:|---:|']
    for key,title in [('personal_battery','电池'),('public_glass','玻璃')]:
        row=targeted[key]
        lines.append(f'| {title} | {row.get("gains",0)} | {row.get("regressions",0)} | {row.get("float_correct_q15_wrong",0)} |')
    if not ev['accepted_offline']:
        lines += ['', '后续改进依据：', '',
            '1. 本轮降低学习率、冻结更多前层并延长到8轮，仍未通过固定验收；不将同配置继续加轮数当作已验证的改进。',
            '2. 先分开电池的错类、漏选与定位问题，再核对训练侧同来源、同实物/场次的标注及采样。开发错误图用于诊断，不能直接混入训练。',
            '3. 后续可验证原部署教师对训练图的输出约束与完整GT联合监督，防止新增公开数据覆盖原有能力；新增有效训练图优先补手持小电池、透明玻璃与真实空场，而不是继续堆叠已有图片别名。',
            '4. 浮点先通过保留能力检查，再核查固定校准下的Q15损失。当前val/dev已反复开发使用，真正泛化仍需另设未参与调参的分场次测试。']
    lines += ['', '完整逐类TP、precision及主体统计在evaluation/state.json。电池、玻璃和空手逐图新增错误在targeted_regressions/，不以一种增益掩盖另一类退步。',
        '现有val/dev已经反复用于开发，不是独立最终测试。最终test图片和标签未读取；无硬件、布局布线、串口或TF/Flash操作。',
        '本次不生成多轮巨大NPY特征缓存，复用现有数据硬链接和标签缓存；RAM缓存随训练进程结束释放。保留有效源码、权重、曲线、日志与诊断，临时文件不进入Git。', '',
        f'权重：`project/trash_sorting/training/candidates/{name}/final.pt`，SHA256 `{sha(checkpoint)}`。',
        f'量化模型SHA256 `{sha(blob)}`。',f'报告生成UTC：{datetime.now(timezone.utc).isoformat()}。','']
    note=ROOT/'docs/overnight-20261116'/(name.upper()+'.md');assert not note.exists();note.write_text('\n'.join(lines),encoding='utf8')
    for relative in ['plan.json','effective_loader_audit.json','pipeline_state.json','delivery.json','training/result.json',
        'training.log','run/provenance.json','run/progress.json','run/hard_negative_epochs.jsonl','run/results.csv',
        'evaluation/state.json','evaluation/continuation_comparison.json','evaluation/quant/provenance.json',
        'evaluation/numeric_oldval/result.json','evaluation/numeric_publicdev/result.json',
        'evaluation/score_oldval/result.json','evaluation/score_publicdev/result.json']:
        source=exp/relative
        if source.exists():
            dest=evidence/relative;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(source,dest)
    for relative in ['frozen_scripts','evaluation/error_gallery','evaluation/targeted_regressions','evaluation/recognition_coverage']:
        shutil.copytree(exp/relative,evidence/relative)
    for relative in ['state.json','numeric/result.json','score/result.json','score/decisions.json']:
        source=ROOT/'build/held_background_dev_20261118_001'/name/relative
        dest=evidence/'evaluation/background_dev'/relative
        dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(source,dest)
    report_sources=evidence/'report_sources';report_sources.mkdir()
    for filename in ['report_full_balanced_retention.py','summarize_recognition_coverage.py',
                     'diagnose_targeted_regressions.py','render_quant_comparison.py',
                     'evaluate_held_background_dev.py','evaluate_qat_continuation.py']:
        shutil.copyfile(Path(__file__).with_name(filename),report_sources/filename)
    shutil.copyfile(note,evidence/note.name)
    save(evidence/'archive_sha256.json',{str(p.relative_to(evidence)):sha(p) for p in evidence.rglob('*') if p.is_file()})
    save(exp/'final_delivery.json',dict(status='COMPLETED_REPORTED_TRAINING',accepted_offline=ev['accepted_offline'],
        report=str(note),checkpoint_sha256=sha(checkpoint),model_sha256=sha(blob),board_programmed=False))
    print(note,flush=True)


if __name__=='__main__':main()
