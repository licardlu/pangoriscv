"""Archive the complete fixed-profile QAT experiment and comparison results."""
import argparse,shutil
from pathlib import Path
from adapt_quant_heads import ROOT,read,save,sha

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--experiment',type=Path,required=True)
    a=p.parse_args();exp=a.experiment.resolve();root=exp.parent
    s=read(exp/'evaluation/state.json');assert s['status'].startswith('COMPLETED_')
    previous=ROOT/'build/quant_head_adapt_20261118_001'
    plain=read(previous/'experiment_003/evaluation/state.json');distilled=read(previous/'experiment_004/evaluation/state.json')
    evidence=ROOT/'evidence/records/optimization/quant_tail_20261118_001';evidence.mkdir(parents=True,exist_ok=False)
    files=[exp/'plan.json',exp/'cache_result.json',exp/'gradient_smoke.json',exp/'training/result.json',exp/'training/history.json',
        exp/'evaluation/state.json',exp/'evaluation/score_oldval/result.json',exp/'evaluation/score_publicdev/result.json',
        exp/'evaluation/numeric_oldval/result.json',exp/'evaluation/numeric_publicdev/result.json',exp/'evaluation/quant/provenance.json',
        root/'preflight_003/result.json',root/'preflight_004/result.json',root/'export_contract_result.json',root/'integer_conv_tests.log']
    for f in [root/'baseline_continuation_current_policy/result.json',
        exp/'evaluation/continuation_comparison.json', exp/'evaluation/score_continuation/result.json',
        exp/'evaluation/numeric_continuation/result.json']:
        if f.exists():files.append(f)
    for f in files:
        dst=evidence/f.relative_to(root);dst.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(f,dst)
    shutil.copytree(exp/'frozen_scripts',evidence/'frozen_scripts')
    for folder in ['error_gallery','float_q15_errors','recognition_coverage']:
        src=exp/'evaluation'/folder
        if src.exists():shutil.copytree(src,evidence/folder)
    if (root/'research').exists():shutil.copytree(root/'research',evidence/'research')
    train=read(exp/'training/result.json')
    lines=['# 冻结尺度的Q15网络尾部量化感知训练','',
        '本次从同一个扩大数据浮点模型重新初始化，训练三个骨干输出卷积（op65、73、81）及三个检测头。前两项检测头实验失败记录完整保留，不混作成功结果。','',
        '## 事前冻结与数学检查','',
        '全部7904个现有train文件身份，每轮12662次显式draw，固定3轮最终轮权重。AdamW，骨干卷积学习率2e-5线性至2e-6，检测头1e-4至1e-5；75%实际Q15特征GT损失、25%浮点特征GT损失，无教师项、无新伪标签或增强计数。其余参数、BN统计及affine、anchors均冻结。',
        '固定扩大数据模型原160张历史train校准得出的激活/预激活尺度和LUT，当前卷积权重的per-channel尺度、bias和Q15 multiplier在训练及导出中按同一公式更新。这是固定尺度QAT，**不是训练后重新统计max的PTQ**；没有用验证集调尺度，也没有把57张已清洗排除的旧校准图加入梯度训练。',
        'FP64承载整数卷积，逐次检查int32累加器和binary64整数精确范围；round-half-away使用STE，clamp保留饱和梯度，LUT使用解析激活的代理梯度。所有现有硬件算子和C runtime保持原样。',
        '训练前234组参数导出一致；五类train样本逐op前向一致；一次梯度更新后重新导出也逐op一致；batch16真实GT检查9组参数梯度有限且非零；未更新参考权重通过新导出器后，整份model.bin SHA与旧扩大数据PTQ完全一致。较慢的有界unfold/GEMM探针没有用于正式训练，保留FP64实现。','',
        '## 实际C选择策略下的软件定点结果','',
        '| 指标 | 原部署 | 检测头GT | 检测头教师约束 | Q15尾部QAT |','|---|---:|---:|---:|---:|']
    for k,label in [('correct_positive','主体类别且IoU≥.5 /1793'),('false_background','空手误选 /136（低为好）'),('correct_personal_battery','个人电池 /60'),('correct_public_glass','公开玻璃 /242')]:
        lines.append(f"| {label} | {s['baseline_q15'][k]} | {plain['q15_oldval'][k]} | {distilled['q15_oldval'][k]} | {s['q15_oldval'][k]} |")
    lines+=['',f"新增公开dev主体正确 /712：原部署{s['baseline_publicdev']['correct_positive']}；检测头GT {plain['q15_publicdev']['correct_positive']}；教师约束 {distilled['q15_publicdev']['correct_positive']}；本次 {s['q15_publicdev']['correct_positive']}。",'',
        '| 类别 | TP原→QAT | Precision原→QAT | 无退化通过 |','|---|---:|---:|---|']
    for name,v in s['detection_gates'].items():
        lines.append(f"| {name} | {v['TP_before']} → {v['TP_after']} | {v['precision_before']:.3f} → {v['precision_after']:.3f} | {v['passed']} |")
    supplemental=exp/'evaluation/continuation_comparison.json'
    if supplemental.exists():
        comparison=read(supplemental)
        lines+=['',f"额外77张预留开发场景：原部署{comparison['baseline_correct']}/77 → QAT {comparison['candidate_correct']}/77；同图新增正确{len(comparison['gains'])}、新增错误{len(comparison['losses'])}。这项额外诊断不改原验收门槛；不是最终test或现场摄像头测试。",'']
    lines+=['','## 执行与结论','',
        f"3轮训练耗时 {train['elapsed_s']:.1f} 秒；checkpoint SHA `{train['checkpoint_sha256']}`。",'',
        f"浮点复测：`{s['float_scores']['float_oldval']}`。",'',
        f"门槛：`{s['gates']}`。",'',
        ('通过事前全部离线门槛，仅作为下一步现场复核候选。' if s['accepted_offline'] else '未通过事前全部门槛，拒绝替换当前部署。不能称为所有物品均识别很好。'),'',
        '本次无综合、布局布线、串口、板卡或Flash操作；原部署SHA保持不变。',
        '旧验证集已反复用于开发；新增公开dev缺空场景和有害/其他/手GT，且不证明完全实物级独立。现有287个无垃圾train身份全有手框，没有纯空场景。尚未达到2万张独立合格train图片；7904个文件身份也不等于7904个物理实物。',
        '数据补强应优先覆盖手持横竖电池、遮挡与运动模糊、透明玻璃定位、纸张与纸巾、无人杂乱背景和远处有物品但未投放的场景，并按完整实物与拍摄批次隔离。新的公开候选中玻璃源存在网页/实际配置矛盾，手机电池源许可未知，两者均未入训。','']
    note=ROOT/'docs/overnight-20261116/QUANT_TAIL_QAT_20261118.md';note.write_text('\n'.join(lines),encoding='utf8')
    shutil.copyfile(note,evidence/note.name)
    save(evidence/'archive_sha256.json',{str(f.relative_to(evidence)):sha(f) for f in evidence.rglob('*') if f.is_file()})
    print(note,flush=True)

if __name__=='__main__':main()
