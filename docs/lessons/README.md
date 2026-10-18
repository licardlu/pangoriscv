# 错误与教训（本目录的用途）

> 这个目录只干一件事：**把踩过的坑写成下次能查的规则**。
>
> - 逐条错误记录：[`mistakes-log.md`](mistakes-log.md)
> - 证据口径（最容易出错的地方）：[`evidence-rules.md`](evidence-rules.md)
> - 开工/收工清单：[`preflight-checklist.md`](preflight-checklist.md)
>
> 项目层面的问题总表（含 RTL/合规/文档全部编号项）在
> [`../verification/issue-register-2026-10-18.md`](../verification/issue-register-2026-10-18.md)，
> 那个是**唯一问题登记处**；本目录是"方法论层面的防再犯清单"，两者不重复。

## 三条铁律

### 1. 只贴工具原文，不填自己算的数

**踩过**：我在标注为"串口原始输出"的代码块里，把 `Iterations/Sec` 写成了自己按浮点
算的 72/70/64/56，固件实际打印的是整数截断值 76/76/69/58 —— 5 份文档 4 份错。

**规则**：
- 代码块标了"原始输出"，里面每一行都必须是工具/固件一次性产出的原文。
- 自己推导的数放正文表格，并注明"由 X 计算"。
- 百分比必须写清是**哪个量的比值**（是 ticks 降幅还是 CoreMark/MHz 增幅？两者差 3%）。

### 2. 一个实现 = 一个目录，证据全套同源

**踩过**：我把同一个 `build/pango_native` 先后用于 27 MHz 和 50 MHz 两次 PDS，
第二次覆盖了第一次。结果**交付位流 `F7B135AE…` 在本机没有对应的实现目录**，
独立复核无法验证三项指标同源（问题 C05）。

**规则**：每次"要报数"的实现，产出一个自包含证据目录：

```
evidence/records/optimization/<阶段>/pds_<频率>/
    pangoriscv_top.sbit          位流（附 SHA256）
    flow.log 或 run.log          整条流程日志
    multiseed_summary.csv        ★ 收尾权威值（setup/hold/LUT 都取这里）
    report_timing.rtr            report_timing 原始报告
    device_map_run.log           资源表
    compile_run.log              编译日志
```

**并且**：`*_after_hold_fix.txt` 是**中间快照**，它的 slack 与最终值不同
（实测：27 MHz 中间 15.404 / 最终 15.267；50 MHz 中间 0.862 / 最终 0.703）。
引 slack 只用 `multiseed_summary.csv`。

### 3. 先量后改；改不动就退回，不留看不懂的改动

**踩过两次**：
- P12（写确认提前一拍）净赚仅 0.64% 且破坏 halt-reset 注入点 → 回退；P13 打通读路径后重做才值 1.67%。
- R 拍预取（+2.15%）改变了 `READ_DELAY>0` 路径的取指行为，**我没解释清楚** → 回退，只留注释。

**规则**：
- 改之前先用探针把账算准（本项目已有 `SCORE_WINDOW`/`EX_SPLIT`/`DCACHE_PATH`/`ICACHE_PATH`/
  `ADDR_REGION`/`MISPRED_MIX`/`LSU_REQ_SPLIT` 七个探针）。
- 一次只改一个变量，A/B 用同一镜像、基线取**改动前**的提交。
- 收益 < 1% 而风险不低 → 不做。
- 解释不清的行为差异 → 不上线，写进代码注释说明重启条件。

## 本目录与其他文档的关系

| 想知道 | 去哪 |
|---|---|
| 某个具体问题修了没有、编号多少 | `docs/verification/issue-register-2026-10-18.md` |
| 我怎么又犯了同一个错、怎么避免 | 本目录 `mistakes-log.md` |
| 引数时该引哪个文件 | 本目录 `evidence-rules.md` |
| 动手前/提交前该查什么 | 本目录 `preflight-checklist.md` |
| 某一轮优化怎么做的、数据多少 | `evidence/records/optimization/P*/measurement.md` |
