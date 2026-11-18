"""Archive a completed QAT experiment with explicit per-class rejection gates."""
import argparse
import shutil
from pathlib import Path

from adapt_quant_heads import ROOT, read, save, sha


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--experiment',type=Path,required=True)
    p.add_argument('--name',required=True)
    a=p.parse_args()
    assert a.name and all(c.isalnum() or c=='_' for c in a.name)
    exp=a.experiment.resolve();state=read(exp/'evaluation/state.json');plan=read(exp/'plan.json')
    assert state['status'].startswith('COMPLETED_')
    training=read(exp/'training/result.json')
    assert training['checkpoint_sha256']==state['checkpoint_sha256']==sha(exp/'training/final.pt')
    evidence=ROOT/'evidence/records/optimization'/a.name;evidence.mkdir(parents=True,exist_ok=False)
    files=['plan.json','cache_result.json','training/result.json','training/history.json',
        'evaluation/state.json','evaluation/numeric_oldval/result.json','evaluation/numeric_publicdev/result.json',
        'evaluation/score_oldval/result.json','evaluation/score_publicdev/result.json','evaluation/quant/provenance.json',
        'evaluation/continuation_comparison.json','evaluation/numeric_continuation/result.json','evaluation/score_continuation/result.json']
    for relative in files:
        src=exp/relative
        if src.exists():
            dst=evidence/relative;dst.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(src,dst)
    for relative in ['frozen_scripts','evaluation/error_gallery','evaluation/float_q15_errors','evaluation/recognition_coverage']:
        src=exp/relative
        if src.exists():shutil.copytree(src,evidence/relative)
    metadata_repairs=[]
    for failed in sorted(exp.glob('evaluation_failed_*')):
        dest=evidence/failed.name;dest.mkdir()
        for src in [failed/'state.json',*failed.glob('*.log')]:
            if src.is_file():shutil.copyfile(src,dest/src.name)
        metadata_repairs.append(failed.name)
    scripts=evidence/'final_evaluation_script_versions';scripts.mkdir()
    for name in ['train_qat_tail.py','qat_tail.py','export_qat_tail.py','evaluate_quant_head_adaptation.py',
        'evaluate_qat_continuation.py','summarize_recognition_coverage.py','record_qat_comparison.py']:
        shutil.copyfile(Path(__file__).parent/name,scripts/name)
    lines=['# '+a.name+' 固定方案QAT结果','',
        '仅离线软件训练/数学核对/开发验证，未综合、布局布线、访问串口或更新板卡；不是现场摄像头识别率。最终测试图片与标签文件未读取。','',
        '## 事前方案','',plan['hypothesis'],'',
        f"初始化权重SHA `{plan['checkpoint_sha256']}`；量化profile SHA `{plan['bundle_sha256']}`。",
        f"固定{plan['epochs']}轮最终权重、batch{plan['batch']}；{plan['unique_train']}个缓存训练文件，每轮{plan['draws_per_epoch']}次draw。文件数不能当独立实物数，重复draw不计新图片。",
        plan.get('count_note','全部使用现有清洗白名单，没有新增训练图片。'),'',
        '激活/预激活尺度和LUT冻结；仅三个尾部骨干输出卷积和三个检测头训练，BN、anchors及其他参数保持不变。没有用验证集选阈值、校准或轮次。','',
        '## 同一C选择器的定点结果','',
        '| 指标 | 原部署 | 本次Q15 |','|---|---:|---:|']
    for key,label in [('correct_positive','主体类别与IoU正确 /1793'),('false_background','无垃圾/空手误选 /136，低为好'),
        ('correct_personal_battery','个人电池 /60'),('correct_public_glass','公开玻璃 /242')]:
        lines.append(f"| {label} | {state['baseline_q15'][key]} | {state['q15_oldval'][key]} |")
    lines += ['', '| 类别 | TP原→本次 | Precision原→本次 | 无退化通过 |','|---|---:|---:|---|']
    for name,row in state['detection_gates'].items():
        lines.append(f"| {name} | {row['TP_before']}→{row['TP_after']} | {row['precision_before']:.3f}→{row['precision_after']:.3f} | {row['passed']} |")
    lines += ['',f"712张公开dev主体正确：{state['baseline_publicdev']['correct_positive']}→{state['q15_publicdev']['correct_positive']}。该集合缺有害/其他/手及无物GT，不能证明这些场景改善。",'']
    if (exp/'evaluation/continuation_comparison.json').exists():
        r=read(exp/'evaluation/continuation_comparison.json')
        lines += [f"额外77张预留手持开发场景：{r['baseline_correct']}→{r['candidate_correct']}；同图新增正确{len(r['gains'])}、新增错误{len(r['losses'])}。该额外诊断不修改门槛。",'']
    lines += ['## 验收与边界','',f"浮点主体分项：`{state['float_scores']['float_oldval']}`。",'',
        f"固定门槛：`{state['gates']}`。",'',
        '所有离线门槛通过，保留为现场复核候选；没有自动部署。' if state['accepted_offline'] else '未通过全部无退化门槛，拒绝替换当前部署。不能用玻璃、手部或公开dev的增益掩盖电池/其他类退步。','',
        f"训练用时{training['elapsed_s']:.1f}秒；最终checkpoint SHA `{training['checkpoint_sha256']}`。",'',
        f"评估中保留的元数据兼容失败记录：{metadata_repairs}。复用已完成浮点预测须核对权重、manifest和策略哈希；没有因元数据修复重训或改权重。",'',
        '旧val与公开dev都属于已用于开发的集合；文件去重不证明实物独立。空手误选指标不代表无人复杂背景。训练新增图、背景裁剪或旋转图不能作为验证准确率证据。','']
    note=ROOT/'docs/overnight-20261116'/(a.name.upper()+'.md');note.write_text('\n'.join(lines),encoding='utf8');shutil.copyfile(note,evidence/note.name)
    save(evidence/'archive_sha256.json',{str(f.relative_to(evidence)):sha(f) for f in evidence.rglob('*') if f.is_file()})
    print(note,flush=True)


if __name__=='__main__':main()
