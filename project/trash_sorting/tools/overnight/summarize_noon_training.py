"""Produce a factual offline progress report from completed frozen experiments."""
import argparse
from datetime import datetime,timezone
import hashlib
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[4]
EXPERIMENTS=[
    ('原固定Q15尾部','quant_tail_20261118_001'),
    ('补40图及背景','quant_targeted_tail_20261118_001'),
    ('电池朝向','quant_battery_orientation_20261118_001'),
    ('全特征10轮','full_orientation_20261118_001'),
    ('补38单电池','quant_extras_battery_20261118_001'),
    ('补玻璃及多电池','quant_reviewed_shape_20261118_001'),
    ('补水果及背景','quant_reviewed_context_20261118_001'),
    ('全特征定点恢复','quant_full_recovery_20261118_001'),
    ('补70泡沫场景','quant_reviewed_foam_20261118_001'),
    ('原部署Q15教师保留','quant_deployed_teacher_20261118_001'),
    ('补完整电池与手持框1轮','quant_final_reviewed_increment_20261118_001')]


def read(path):
    if not path.exists():return {}
    return json.loads(path.read_text(encoding='utf8'))


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out',type=Path,required=True)
    args=parser.parse_args();args.out.mkdir(parents=True,exist_ok=False)
    rows=[]
    for label,name in EXPERIMENTS:
        exp=ROOT/'build'/name/'experiment_001'
        plan=read(exp/'plan.json');state=read(exp/'evaluation/state.json')
        training=read(exp/'training/result.json');extra=read(exp/'evaluation/continuation_comparison.json')
        pipeline=read(exp/'pipeline_state.json')
        checkpoint=exp/'training/final.pt'
        if training and checkpoint.exists():
            assert hashlib.sha256(checkpoint.read_bytes()).hexdigest()==training['checkpoint_sha256']
        rows.append(dict(label=label,name=name,path=str(exp),pipeline=pipeline.get('status','not_recorded'),
            trained=bool(training),training_seconds=training.get('elapsed_s',0),epochs=training.get('epochs'),
            accepted_offline=state.get('accepted_offline'),evaluation_status=state.get('status'),
            q15=state.get('q15_oldval'),publicdev=state.get('q15_publicdev'),
            continuation=extra.get('candidate_correct'),detection_gates=state.get('detection_gates'),
            checkpoint_sha256=training.get('checkpoint_sha256'),hypothesis=plan.get('hypothesis'),
            data_note=plan.get('count_note'),unique_train=plan.get('unique_train')))
    data=read(ROOT/'build/noon_continuation_20261118_001/research/organic_001/reviewed_foam_dataset_001/result.json')
    increment=read(ROOT/'build/final_reviewed_increment_20261118_001/dataset_001/result.json')
    stamp=datetime.now(timezone.utc).isoformat()
    blob=ROOT/'project/trash_sorting/candidates/continuation_023/source/yolo/model/model.bin'
    blobsha=hashlib.sha256(blob.read_bytes()).hexdigest()
    assert blobsha=='7a0765a6f275f3c06d838f924d73542783ca55e131509aa1b546efc98bd65728'
    report=dict(generated_utc=stamp,scope='Offline development evaluation, not on-board or final-test accuracy',
        deployed_blob_sha256=blobsha,experiments=rows,latest_reviewed_dataset=increment or data,
        reviewed_foam_dataset=data,final_reviewed_increment=increment,
        completed_training_runs=sum(r['trained'] for r in rows),
        measured_training_seconds=sum(r['training_seconds'] for r in rows),board_accessed=False)
    (args.out/'result.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf8')
    lines=['# 2026-11-18持续训练实测记录','',f'生成UTC：{stamp}。只统计已有证据；未完成项保留状态。',
        '', '全部是离线开发验证，不能冒称真实摄像头识别率；最终test未用于本轮训练或评估。', '',
        '| 固定实验 | 完成轮数 | 主体/1793 | 电池/60 | 玻璃/242 | 空手误选/136↓ | 手持dev/77 | 公开dev/712 | 全门槛 |',
        '|---|---:|---:|---:|---:|---:|---:|---:|---|',
        '| 原部署基线 | — | 1455 | 55 | 232 | 8 | 56 | 271 | 基线 |']
    for r in rows:
        q=r['q15'] or {};p=r['publicdev'] or {}
        val=lambda value: '待完成' if value is None else str(value)
        verdict='待完成' if r['accepted_offline'] is None else ('通过，仍待现场' if r['accepted_offline'] else '拒绝替换')
        lines.append('| '+' | '.join([r['label'],val(r['epochs']),val(q.get('correct_positive')),
            val(q.get('correct_personal_battery')),val(q.get('correct_public_glass')),
            val(q.get('false_background')),val(r['continuation']),val(p.get('correct_positive')),verdict])+' |')
    lines += ['',f"已实际完成训练{report['completed_training_runs']}项，以上运行净训练时间合计{report['measured_training_seconds']/3600:.2f}小时（另有缓存、导出和评估时间）。",'',
        '## 新数据与数量口径','',data.get('image_count_note',''),'',
        '70张新泡沫场景已逐图审查，共80框；材质不明确的纸盘/碗、漏标共现物和截断物排除。塑料袋抽样呈抠图合成背景，未导入。',
        '8578是训练文件身份，不是8578个独立实物；14194是每轮采样次数，不是新增照片。2万张独立合格图的目标尚未达到。','',
        '## 各类检测不可由总分掩盖','']
    if increment:
        position=lines.index('## 各类检测不可由总分掩盖')
        lines[position:position]=['最后另冻结11张电池照片/41完整框和8张MJU派生手持crop/8物体10手框，合计8597训练文件身份、14232draw；其实际训练/评估状态见上表。新电池照片属于同一拍摄批次，8crop不是独立新照片。','']
    for r in rows:
        if not r['detection_gates']:continue
        lines += ['### '+r['label'],'','| 类别 | TP原→新 | Precision原→新 | 无退化 |','|---|---:|---:|---|']
        for name,g in r['detection_gates'].items():
            lines.append(f"| {name} | {g['TP_before']}→{g['TP_after']} | {g['precision_before']:.3f}→{g['precision_after']:.3f} | {g['passed']} |")
        lines.append('')
    lines += ['## 仍需解决','',
        '- 原部署电池和新公开域存在权衡；不能把更高的公开dev总分当电池也改善。',
        '- 136无垃圾图主要为空手；另有27张小规模背景开发视图，仍不能代替实际工位无人背景测试。',
        '- 现有手持77图缺厨余，公开712图缺有害/其他/手GT；尚无全品类现场覆盖。',
        '- 开发val已反复使用，不能当独立最终测试结论。',
        '- 后续优先补同摄像头工位的新实物、不同遮挡/光照/方向与真正无人背景，按实物及拍摄分组隔离。','',
        f'当前部署blob SHA `{blobsha}`；本流程未综合、布线、串口或上板。','',
        '## 证据目录','']
    for r in rows:lines.append(f"- {r['label']}：`{r['path']}`，pipeline=`{r['pipeline']}`，SHA=`{r['checkpoint_sha256']}`。")
    (args.out/'report.md').write_text('\n'.join(lines)+'\n',encoding='utf8')
    print(dict(output=str(args.out),completed_training_runs=report['completed_training_runs'],
               trained_hours=round(report['measured_training_seconds']/3600,2)),flush=True)


if __name__=='__main__':main()
