# 新一轮固定八轮整包联合训练

更新：2026-11-19已完成全部8轮与后续诊断，未通过离线替换门槛。见 [最终报告](FULL_BALANCED_RETENTION_20261119_001.md)。本文件保留启动方案，不能据此重复运行。

用户在上一阶段Git交接后明确要求继续大批量高效训练，此轮为新的授权训练，不沿用已经结束的两小时截止。只做离线模型训练及评估，板卡已被拿走，无需连接。

实验目录：`build/full_balanced_retention_20261119_001/experiment_001`。

已经实际启动。9,349个已核验图像/标签文件身份，19,260条不同硬链接回放路径，每轮301批，batch64、8CPU线程；固定8轮，共计划154,080次主样本加载。不是新增15万张原图，2万合格原图目标仍未达。

从原部署对应权重初始化；冻结前10块和其BN，余下特征与检测头训练。学习率由旧1e-4降低至3e-5，保持完整五类GT和无垃圾图难负样本objectness0.02。原因：上一轮虽然电池采样修复生效，但电池浮点53、Q15为48，玻璃225/242仍退步；需要减少特征遗忘并给足固定训练轮数，不能直接继续失败权重或承诺重复采样必然改善。

`project/trash_sorting/tools/overnight/full_balanced_retention.py`单一流程接续训练→预定160张train校准→完整旧val/公开dev整数评估→77手持→27复杂背景→逐图电池/玻璃/空手诊断→画廊/覆盖→权重与报告归档。固定末轮，不按val选择中间权重、不改阈值或放宽门槛；未全部通过不替换部署。

复用已经准备好的数据集、硬链接和标签缓存，不重新下载、不生成旧式巨大NPY尾部特征缓存。RAM图像缓存在训练进程结束后释放；保留权重、来源/标注、训练曲线和诊断。系统防休眠请求由单一流程持有并在结束/失败时释放，不要求屏幕常亮。

查看当前进度：

```powershell
Get-Content build/full_balanced_retention_20261119_001/experiment_001/pipeline_state.json
Get-Content build/full_balanced_retention_20261119_001/experiment_001/training.log -Tail 4
Get-Content build/full_balanced_retention_20261119_001/experiment_001/run/progress.json
```

此文件只记录启动方案，不表示训练完成或识别率提升。最终以同目录pipeline状态和最终同名报告为准。严禁因为本文件还叫RUNNING就重复启动。
