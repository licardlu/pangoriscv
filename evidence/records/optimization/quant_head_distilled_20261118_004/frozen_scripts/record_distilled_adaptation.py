"""Record a second predeclared hypothesis without hiding the first rejection."""
import argparse,shutil
from pathlib import Path
from adapt_quant_heads import ROOT,read,save,sha

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--experiment',type=Path,required=True)
    a=p.parse_args();exp=a.experiment.resolve();root=exp.parent
    s=read(exp/'evaluation/state.json');assert s['status'].startswith('COMPLETED_')
    prior=read(root/'experiment_003/evaluation/state.json')
    evidence=ROOT/'evidence/records/optimization/quant_head_distilled_20261118_004'
    evidence.mkdir(parents=True,exist_ok=False)
    files=[exp/'plan.json',exp/'preflight.json',exp/'training/result.json',exp/'training/history.json',
        exp/'evaluation/state.json',exp/'evaluation/score_oldval/result.json',exp/'evaluation/score_publicdev/result.json',
        exp/'evaluation/numeric_oldval/result.json',exp/'evaluation/numeric_publicdev/result.json',exp/'evaluation/quant/provenance.json',
        root/'distillation_tests.log',root/'duplicate_label_audit.json',root/'background_coverage_limit.json',root/'continuation_comparison.json']
    for f in files:
        dst=evidence/f.relative_to(root);dst.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(f,dst)
    shutil.copytree(exp/'frozen_scripts',evidence/'frozen_scripts')
    for folder in ['error_gallery','float_q15_errors']:
        src=exp/'evaluation'/folder
        if src.exists():shutil.copytree(src,evidence/folder)
    lines=['# 五类教师约束定点检测头适配','',
        '本实验在普通GT检测头适配未恢复电池定点效果后另立假设；从同一个扩大数据浮点best重新初始化，没有挑前一实验的中间轮次。第一实验结果保持原样。','',
        '## 冻结方法','',
        '训练图、重复采样分布、骨干、BN、anchors、原160张校准、阈值和6轮最终轮规则均保持。检测头以75%定点特征GT损失和25%浮点特征GT损失训练；额外加入与真实GT同类、conf≥.25、IoU≥.5的浮点教师约束。系数预先固定5，按类别平衡目标项，教师包含内部hand第5类。没有伪造新框、用验证错误图训练或扫描系数。',
        '错误类别、低置信度、错位框、手类索引和教师无梯度均有测试。每轮记录实际执行的有效匹配数；所有类别必须非零，否则训练失败。导出的模型不含教师。','',
        '## 固定验证结果','',
        '| 定点指标 | 原部署 | 普通GT适配 | 五类教师适配 |','|---|---:|---:|---:|']
    for k,label in [('correct_positive','主体类别与IoU正确 /1793'),('false_background','无物/空手误选 /136（低为好）'),('correct_personal_battery','个人电池 /60'),('correct_public_glass','公开玻璃 /242')]:
        lines.append(f"| {label} | {s['baseline_q15'][k]} | {prior['q15_oldval'][k]} | {s['q15_oldval'][k]} |")
    lines+=['',f"新增公开dev /712：原部署 {s['baseline_publicdev']['correct_positive']}，普通GT {prior['q15_publicdev']['correct_positive']}，本实验 {s['q15_publicdev']['correct_positive']}。无空场景图，且不证明完全实物级独立。",'',
        '| 类别 | TP旧→新 | Precision旧→新 | 无退化门槛 |','|---|---:|---:|---|']
    for name,v in s['detection_gates'].items():
        lines.append(f"| {name} | {v['TP_before']} → {v['TP_after']} | {v['precision_before']:.3f} → {v['precision_after']:.3f} | {v['passed']} |")
    train=read(exp/'training/result.json')
    lines+=['','## 执行和决策','',
        f"训练耗时 {train['elapsed_s']:.1f} 秒，6轮；最终checkpoint SHA `{train['checkpoint_sha256']}`。",'',
        f"门槛：`{s['gates']}`。",'',
        ('通过全部离线门槛，仅作为后续实物复核候选。' if s['accepted_offline'] else '仍未通过所有预先固定门槛，拒绝替换部署。不得表述为所有类别都已识别很好。'),'',
        '本次没有访问板卡、串口、TF或Flash，没有综合或布局布线。原部署模型哈希保持不变。两次实验都保留完整失败/成功计数和错误图。',
        '覆盖限制：旧val已反复用于开发；136张无垃圾图主要为空手，训练集没有零框纯空场景；公开源标签只有分层抽检，不能称全部人工gold。7904个文件身份不等同于7904个独立物理实物；尚未达到2万张合格独立训练图片。','',
        '下一步优先处理骨干量化适配和真实场景补标：手持电池横竖方向/遮挡、透明玻璃、纸张与纸巾区分、复杂无人背景及远处有垃圾但未投放。检测头单独适配的两项结果应作为是否值得扩大此路线的证据。','']
    note=ROOT/'docs/overnight-20261116/QUANT_HEAD_DISTILLATION_20261118.md';note.write_text('\n'.join(lines),encoding='utf8')
    shutil.copyfile(note,evidence/note.name)
    save(evidence/'archive_sha256.json',{str(f.relative_to(evidence)):sha(f) for f in evidence.rglob('*') if f.is_file()})
    print(note,flush=True)

if __name__=='__main__':main()
