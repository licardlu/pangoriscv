"""Archive reproducible head-adaptation evidence and write an honest result note."""
import argparse,shutil
from pathlib import Path
from adapt_quant_heads import ROOT,read,save,sha

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--experiment',type=Path,required=True)
    a=p.parse_args();exp=a.experiment.resolve();root=exp.parent
    state=read(exp/'evaluation/state.json');assert state['status'].startswith('COMPLETED_')
    evidence=ROOT/'evidence/records/optimization/quant_head_adapt_20261118_001'
    evidence.mkdir(exist_ok=False,parents=True)
    files=[root/'diagnosis/result.json',root/'coverage_and_diagnosis.json',root/'header_audit.json',root/'context_label_spotcheck.json',
        root/'math_tests_002.log',root/'background_coverage_limit.json',
        root/'baseline_q15_current_policy/result.json',root/'baseline_publicdev_score/result.json',
        exp/'plan.json',exp/'cache_result.json',exp/'cache_resume_001.json',exp/'early_preflight.json',
        exp/'preflight.json',exp/'gradient_smoke.json',exp/'training/result.json',exp/'training/history.json',
        exp/'evaluation/state.json',exp/'evaluation/score_oldval/result.json',exp/'evaluation/score_publicdev/result.json',
        exp/'evaluation/numeric_oldval/result.json',exp/'evaluation/numeric_publicdev/result.json',
        exp/'evaluation/quant/provenance.json']
    for f in files:
        dest=evidence/f.relative_to(root);dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(f,dest)
    scriptdir=evidence/'scripts';scriptdir.mkdir()
    for name in ['diagnose_quant_features.py','adapt_quant_heads.py','resume_feature_cache.py','evaluate_quant_head_adaptation.py','record_quant_adaptation.py','test_quant_head_math.py']:
        shutil.copyfile(Path(__file__).parent/name,scriptdir/name)
    before=state['baseline_q15'];after=state['q15_oldval']
    lines=['# 定点特征检测头适配实验','',
        '本次为离线软件验证，不是摄像头或 FPGA 实测。旧 val 已用于多轮开发；新增公开 dev 也不能证明完全实物级独立，且没有空背景。最终 test 图片和标签未读取。','',
        '## 方法与执行','',
        '训练集50张分层样本的三个检测头输入相对RMSE分别约31.1%、34.0%、38.9%，没有观察到输出端int8饱和，不能据此认定所有误差都由同一层造成。',
        '固定扩大数据浮点权重的骨干、BN、anchors和原160张历史train有序校准，只更新三个1×1检测头。全部7904个训练文件SHA身份，12662个原采样draw/轮，6轮；75%实际Q15特征GT损失、25%FP32特征GT损失；AdamW，学习率1e-4线性至1e-5。只评估最终轮，不以验证集挑轮次或扫阈值。',
        '准备001因部分历史行缺宽高字段停止；002因33张历史文件已经等比缩放、与原始尺寸不同而停止，两次均零梯度更新。全量文件头审计没有宽高比或EXIF变化。003使用实际像素尺寸，已完成前缀后以四进程分区续算，数学仍为未修改的float64精确Q15 oracle。',
        '检测头浮点forward一致性、独立Q16点积、letterbox坐标和保存重载检查均有机器证据；导出后再次逐数组核验骨干量化参数与原始扩大数据模型bit-identical。','',
        '## 旧验证集：实际C选择策略','',
        '| 指标 | 当前部署模型Q15 | 本次Q15 |','|---|---:|---:|']
    for key,label in [('correct_positive','主体类别且IoU≥.5正确 /1793'),('false_background','无物/空手误选 /136（低为好）'),('correct_personal_battery','个人电池 /60'),('correct_public_glass','公开玻璃 /242')]:
        lines.append(f'| {label} | {before[key]} | {after[key]} |')
    lines+=['','## 各类检测与验收','','| 类别 | TP旧→新 | Precision旧→新 | 通过不退化门槛 |','|---|---:|---:|---|']
    for name,v in state['detection_gates'].items():
        lines.append(f"| {name} | {v['TP_before']} → {v['TP_after']} | {v['precision_before']:.3f} → {v['precision_after']:.3f} | {v['passed']} |")
    lines+=['',f"新增712张公开dev主体正确：{state['baseline_publicdev']['correct_positive']} → {state['q15_publicdev']['correct_positive']}。这些图不含有害、其他和手的GT，因此不能评价这些类别的新域召回。",'',
        f"整体门槛：`{state['gates']}`。",'',
        ('全部离线门槛通过，可作为后续上板候选，尚无现场效果结论。' if state['accepted_offline'] else '未全部通过预先固定的无退化门槛，拒绝替换当前部署模型。不能称为所有物品均已识别良好。'),'',
        '额外覆盖审计：7904个train文件身份中287张无垃圾图全部带手框，没有零框纯场景图。旧val的136张无垃圾图由29张HaGRID与107张个人空手组成。故这项误选指标主要反映空手抑制，不能声称已经覆盖无人杂乱背景、远处有物品但无人投放等场景。',
        '本次没有综合、布局布线、串口通信或修改板卡/Flash。原部署blob SHA保持 `7a0765a6f275f3c06d838f924d73542783ca55e131509aa1b546efc98bd65728`。',
        '仍需补充手持电池、透明玻璃、少样本厨房/其他垃圾和真实杂乱背景的完整双框标签。20,000张独立合格训练图目标尚未达到；重复采样、裁剪、增强均不充当新增独立实物。','']
    note=ROOT/'docs/overnight-20261116/QUANT_HEAD_ADAPTATION_20261118.md'
    note.write_text('\n'.join(lines),encoding='utf8');shutil.copyfile(note,evidence/note.name)
    save(evidence/'archive_sha256.json',{str(f.relative_to(evidence)):sha(f) for f in evidence.rglob('*') if f.is_file()})
    print(note,flush=True)

if __name__=='__main__':main()
