"""Archive fixed-final supervised feature adaptation with correct provenance.

Unlike tail QAT, this experiment adapts features above module4 and recalibrates
once with the predeclared training-only reference. No deployment is performed.
"""
import argparse
from pathlib import Path
import shutil
from adapt_quant_heads import ROOT,read,save,sha


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--experiment',type=Path,required=True)
    p.add_argument('--name',required=True)
    a=p.parse_args();exp=a.experiment.resolve()
    assert a.name and all(c.isalnum() or c=='_' for c in a.name)
    pipeline=read(exp/'pipeline_state.json')
    assert pipeline['status']=='COMPLETED_OFFLINE_FULL_CONTINUATION'
    state=read(exp/'evaluation/state.json');plan=read(exp/'plan.json')
    training=read(exp/'training/result.json');provenance=read(exp/'run/provenance.json')
    assert state['status'].startswith('COMPLETED_')
    assert training['checkpoint_sha256']==state['checkpoint_sha256']==sha(exp/'training/final.pt')
    assert training['final_epoch_only'] and provenance['fixed_final']
    assert training['epochs']==plan['epochs']==10
    assert sha(exp/'calibration_reference.json')==plan['calibration_reference_sha256']
    blob=ROOT/'project/trash_sorting/candidates/continuation_023/source/yolo/model/model.bin'
    assert sha(blob)=='7a0765a6f275f3c06d838f924d73542783ca55e131509aa1b546efc98bd65728'
    evidence=ROOT/'evidence/records/optimization'/a.name
    evidence.mkdir(parents=True,exist_ok=False)
    for relative in ['plan.json','pipeline_state.json','calibration_reference.json',
                     'training/result.json','run/provenance.json','run/progress.json','run/results.csv',
                     'evaluation/state.json','evaluation/numeric_oldval/result.json',
                     'evaluation/numeric_publicdev/result.json','evaluation/score_oldval/result.json',
                     'evaluation/score_publicdev/result.json','evaluation/quant/provenance.json',
                     'evaluation/continuation_comparison.json','evaluation/numeric_continuation/result.json',
                     'evaluation/score_continuation/result.json']:
        src=exp/relative
        if src.is_file():
            dst=evidence/relative;dst.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(src,dst)
    for relative in ['frozen_scripts','evaluation/error_gallery','evaluation/float_q15_errors','evaluation/recognition_coverage']:
        if (exp/relative).exists():shutil.copytree(exp/relative,evidence/relative)
    background=ROOT/'build/held_background_dev_20261118_001'/a.name/'state.json'
    if background.exists():shutil.copyfile(background,evidence/'background_development_state.json')
    lines=['# '+a.name+' 固定最终轮监督微调结果','',
           '仅离线训练、导出和开发评估；未综合、布局布线、串口访问或上板，最终test图片和标签未读取。','',
           '## 事前冻结方案','',plan['hypothesis'],'',
           f"初始化SHA `{plan['checkpoint_sha256']}`；冻结前{plan['freeze']}个模块与其BN，其余特征层进行监督微调。AdamW、初始学习率{plan['lr0']}，固定{plan['epochs']}轮最终last.pt，没有中途验证选轮次或早停。",
           plan['photograph_count_note'],'',
           '训练后只用事前冻结的160张当前train图片校准一次。此实验改变特征和量化参数，不能表述为骨干或激活尺度全冻结的尾部QAT。','',
           '## 同一C选择器与相同阈值的Q15结果','',
           '| 指标 | 原部署 | 本次Q15 |','|---|---:|---:|']
    for key,label in [('correct_positive','主体类别与IoU正确 /1793'),('false_background','无垃圾/空手误选 /136，越低越好'),
                      ('correct_personal_battery','个人电池 /60'),('correct_public_glass','公开玻璃 /242')]:
        lines.append(f"| {label} | {state['baseline_q15'][key]} | {state['q15_oldval'][key]} |")
    lines += ['', '| 类别 | TP原→本次 | Precision原→本次 | 无退化通过 |','|---|---:|---:|---|']
    for name,row in state['detection_gates'].items():
        lines.append(f"| {name} | {row['TP_before']}→{row['TP_after']} | {row['precision_before']:.3f}→{row['precision_after']:.3f} | {row['passed']} |")
    cont=read(exp/'evaluation/continuation_comparison.json')
    lines += ['',f"712张公开dev主体正确：{state['baseline_publicdev']['correct_positive']}→{state['q15_publicdev']['correct_positive']}。",
              f"77张手持开发图主体正确：{cont['baseline_correct']}→{cont['candidate_correct']}；新增正确{len(cont['gains'])}，新增错误{len(cont['losses'])}。",'',
              '## 结论与适用范围','',
              '全部预定离线门槛通过，保留为现场复核候选；未自动部署。' if state['accepted_offline'] else '未通过全部预定无退化门槛，拒绝替换现用模型。',
              f"固定门槛：`{state['gates']}`。",
              f"浮点分项：`{state['float_scores']['float_oldval']}`。",
              f"训练{training['elapsed_s']:.1f}秒，最终权重SHA `{training['checkpoint_sha256']}`。",'',
              '旧val和公开dev已用于开发，均不代表独立最终测试或现场效果。公开dev缺有害/其他/手和空场GT；77图缺厨余。空手指标不能证明无人复杂背景无误报。旋转图和重复draw不能计作独立新照片。','']
    note=ROOT/'docs/overnight-20261116'/(a.name.upper()+'.md')
    assert not note.exists()
    note.write_text('\n'.join(lines),encoding='utf8');shutil.copyfile(note,evidence/note.name)
    shutil.copyfile(Path(__file__),evidence/Path(__file__).name)
    save(evidence/'archive_sha256.json',{str(f.relative_to(evidence)):sha(f) for f in evidence.rglob('*') if f.is_file()})
    print(note,flush=True)


if __name__=='__main__':
    main()
