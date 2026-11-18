"""Archive the sampling correction honestly, including incomplete deadline results."""
from datetime import datetime,timezone
from pathlib import Path
import shutil
from adapt_quant_heads import ROOT,read,save,sha


def main():
    parent=ROOT/'build/balanced_replay_fix_20261118_001';exp=parent/'experiment_001'
    state=read(exp/'pipeline_state.json');plan=read(exp/'plan.json')
    assert state['status'] in ['COMPLETED_BALANCED_REPLAY_EVALUATION','failed']
    evidence=ROOT/'evidence/records/optimization/balanced_replay_fix_20261118_001';evidence.mkdir(exist_ok=False)
    lines=['# 平衡采样修正：固定整包一轮', '',
        '用户指出电池持续下降后，针对已确认的加载器去重问题落实原有平衡回放。仍从原部署对应权重开始，不从四轮退步候选续训。', '',
        '9,349个已有文件通过19,260条不同硬链接路径联合采样；其中有害类图的回放次数为6,889，个人/手持电池按原冻结draw清单加权。别名和重复采样都不算新增照片，2万独立原图目标未完成。',
        '固定一轮，其他模型/损失/超参沿用前一整包；没有依开发集选择中间轮次或阈值。160张校准图的照片SHA、类别和顺序不变，仅映射到首个别名路径。', '',
        f'最终状态：`{state["status"]}`；原截止：`{plan["deadline_utc"]}`。板卡已经被用户拿走，本次没有任何硬件操作。', '']
    if state.get('error'):lines += ['未完成原因：`'+state['error']+'`。不能将未完成评估当作通过。','']
    result_path=exp/'training/result.json'
    if result_path.exists():
        training=read(result_path);checkpoint=exp/'training/final.pt'
        assert sha(checkpoint)==training['checkpoint_sha256']
        lines += [f'完整训练耗时{training["elapsed_s"]/60:.2f}分钟；权重SHA256：`{sha(checkpoint)}`。','']
        models=ROOT/'project/trash_sorting/training/candidates/balanced_replay_fix_20261118_001';models.mkdir(exist_ok=False)
        shutil.copyfile(checkpoint,models/'final.pt')
        evpath=exp/'evaluation/state.json';evaluation=read(evpath) if evpath.exists() else {}
        accepted=evaluation.get('accepted_offline',False) and state['status']=='COMPLETED_BALANCED_REPLAY_EVALUATION'
        save(models/'identities.json',dict(status='OFFLINE_REVIEW_ONLY' if accepted else 'NOT_ACCEPTED_DO_NOT_DEPLOY',
            checkpoint_sha256=sha(checkpoint),actual_epochs=1,original_deployment_unchanged=True,
            completed_all_checks=state['status']=='COMPLETED_BALANCED_REPLAY_EVALUATION'))
        (models/'README.md').write_text('# 平衡采样修正模型\n\n固定整包一轮，是否通过完整检查以仓库根目录交接和本实验报告为准。未通过或未完成不得部署；此目录不表示已上板。\n',encoding='utf8')
        counts=evaluation.get('q15_oldval')
        floated=evaluation.get('float_scores',{}).get('float_oldval')
        if counts or floated:
            lines += ['| 指标 | 原部署Q15 | 本轮浮点 | 本轮Q15 |','|---|---:|---:|---:|']
            for key,name,base in [('correct_positive','主体 /1793',1455),('correct_personal_battery','电池 /60',55),
                                  ('correct_public_glass','玻璃 /242',232),('false_background','无垃圾误选 /136，低为好',8)]:
                lines.append(f'| {name} | {base} | {floated[key] if floated else "未完成"} | {counts[key] if counts else "未完成"} |')
            lines += ['','浮点同口径基线为1457/54/231/8。所有这些集合都已反复用于开发，不是现场或独立测试。','']
        if evaluation.get('q15_publicdev'):lines += [f'公开dev正确：{evaluation["q15_publicdev"]["correct_positive"]}/712（原271）。','']
        if evaluation.get('gates'):lines += ['门槛：`'+str(evaluation['gates'])+'`。','']
        lines += ['通过完整离线门槛，仅供后续现场复核，未自动部署。' if accepted else '未通过或未完成完整离线门槛，保留原部署，不安装新模型。','']
    else:
        lines += ['未产生确认完整训练成功的交付权重，已有run日志/检查点保留，不能声称完整一轮已结束。','']
    priority=exp/'priority_evaluation/cohort_results.json'
    if priority.exists():
        diagnostic=read(priority)
        lines += ['## 截止前优先完成的固定分组整数检查','','这些分组按既有GT元数据选取，没有按本轮预测挑图。与全量检查严格区分，不能据此声称通过全部验收。','',
                  '| 分组 | 图数 | 原部署 | 本轮 |','|---|---:|---:|---:|']
        for key,title in [('battery','电池正确'),('glass','玻璃正确'),('empty_hand','无垃圾误选，低为好')]:
            r=diagnostic['counts'][key]
            old,new=(r['baseline_false'],r['candidate_false']) if key=='empty_hand' else (r['baseline_correct'],r['candidate_correct'])
            lines.append(f'| {title} | {r["images"]} | {old} | {new} |')
        lines += ['','完整主体、公开dev及逐类无退步门槛若未完成，仍不得替换部署。','']
    continuation=exp/'evaluation/continuation_comparison.json'
    if continuation.exists():
        c=read(continuation);lines += [f'77张手持开发：{c["baseline_correct"]}→{c["candidate_correct"]}，新增正确{len(c["gains"])}、退步{len(c["losses"])}。','']
    relative_files=['plan.json','pipeline_state.json','delivery.json','effective_loader_audit.json','calibration_reference.json',
        'training/result.json','training.log','run/provenance.json','run/progress.json','run/hard_negative_epochs.jsonl','run/results.csv',
        'evaluation/state.json','evaluation/quant/provenance.json','evaluation/numeric_oldval/result.json','evaluation/score_oldval/result.json',
        'evaluation/numeric_publicdev/result.json','evaluation/score_publicdev/result.json','evaluation/continuation_comparison.json',
        'pipeline_state_before_priority_adoption.json','priority_monitor_ready.json',
        'priority_evaluation/cohort_results.json','priority_evaluation/quant/provenance.json',
        'priority_evaluation/numeric/result.json','priority_evaluation/score/result.json','priority_evaluation/score/decisions.json']
    for relative in relative_files:
        src=exp/relative
        if src.exists():
            target=evidence/relative;target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(src,target)
    for relative in ['frozen_scripts','evaluation/targeted_regressions']:
        if (exp/relative).exists():shutil.copytree(exp/relative,evidence/relative)
    bg=ROOT/'build/held_background_dev_20261118_001/balanced_replay_fix_20261118_001/state.json'
    if bg.exists():
        shutil.copyfile(bg,evidence/'background_dev_state.json');b=read(bg)
        if b.get('counts'):lines += [f'额外复杂背景主体{b["counts"]["correct_positive"]}/17、空场误选{b["counts"]["false_background"]}/10；集合仅27相关视图，不代表现场。','']
    lines += ['下一位优先看采样修正前后电池逐图变化、浮点到Q15损失和手部筛选，不再把大量白底可回收图片当作现场泛化证明。纯空背景不足仍需补实际相机数据。', '',
              '运行日志和小体积必要证据已归档，缓存和别名不是Git训练图片。此报告不改变任何验收门槛。', '',
              '生成UTC：'+datetime.now(timezone.utc).isoformat(),'']
    note=ROOT/'docs/overnight-20261116/BALANCED_REPLAY_FIX_20261118_001.md';assert not note.exists()
    note.write_text('\n'.join(lines),encoding='utf8');shutil.copyfile(note,evidence/note.name)
    save(evidence/'archive_sha256.json',{str(p.relative_to(evidence)):sha(p) for p in evidence.rglob('*') if p.is_file()})
    print(note,flush=True)


if __name__=='__main__':
    main()
