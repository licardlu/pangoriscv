# 下一步清单（2026-10-24 收口时写）

> 按"能不能今天就做完"排序。每条都标了判据与依据。

## A. 插上下载线（唯一阻塞项，5 分钟）

```powershell
powershell -ExecutionPolicy Bypass -File firmware\code\tools\board_verify.ps1 `
    -Sbit bitstream\pangoriscv_board50_i2800_5p248.sbit -FreqMhz 50 -Iterations 2800
```

预检 → 先开串口 → 烧写 → 校验五项 CRC → 输出 `coremark_mhz` 与是否 ≥10 s。

| 退出码 | 含义 |
|---|---|
| 0 | 实测通过，五项 CRC 全对 |
| 3 | 下载线未枚举（插线/驱动） |
| 4 | 报告不全或 CRC 不符 |
| 5 | 串口打不开（COM34 被占用） |

**只有这一步能把"仿真 5.2484"变成"实测 5.2484"。** 在此之前，任何"已达标"的说法都不算数。

## B. `cut 6`：D\$ 写地址打一拍（半天，收益上限 4.77 ns ≈ 68 MHz）

依据：`docs/plan-v23-area-and-freq.md` §10——交付版最关键路径的第 9–11 段合计 **4.77 ns（22%）**，
只服务于"把 store 数据合并进 D\$ 阵列"，读路径完全不需要。

**不要**照 lesson 90 的老写法（那是"再加一条写路径"，PDS 综合会卡 40 分钟）。正确做法三点：

1. `ST_IDLE` 里那条即时合并（`dcache_axi.v` line 604）改成锁存 `{idx, data, strb, valid}`，
   写动作挪到 always 块顶部（`if (dwr_valid) ...`）。
2. 已有的三条 `ST_WR_*` 合并（711/731/747）写的是同一份数据、同一地址，**保留即可**（幂等），
   但要确认综合没有为此生成额外的 1,024 位宽写地址 mux。
3. 唯一的正确性缺口：**store 被接受的下一拍、若有一条 load 命中同一 index，会读到旧数据。**
   优先做法是"{set,word} 相等 + 屏蔽一拍 `req_ready`"；
   **不要**在读路径上加字节合并 mux（读路径本身已有 4.89 ns）。
   先用 20 迭代仿真量互锁代价：**若 +>1,500 拍说明屏蔽太粗**，改精细比较。

判据：`Total ticks ≤ 192,307`（守住 5.2）+ 五项 CRC + ISA 全过 + 满流程 `report_timing` 通过。
风险：缓存正确性没有板上验证就**不能进交付**，只能作为候选。

## C. 3 发射 + 6R3W + 一级访存流水（数周，唯一能同时满足 5.2 与高频的路线）

ILP 定标：186,811 拍 ⇒ **5.353 分**。设计在 `docs/plan-v18-m1-wide4.md` / v20，
S1+S2 的代码在 `docs/patches/wide4-s1s2-fetch16b.patch`。
这是"换一台机器"，不是调参——而且完成后仍然要重跑全部验证。

## D. 不要再做的（每条都有实测依据，重复=浪费）

| 方向 | 依据 |
|---|---|
| 换 `pnr -seed` | 静默 no-op（lesson 81） |
| 重跑同一棵网表 | 摆放/布线确定性，逐位相同（本轮 3 次验证） |
| `-place_worst_slack` / 两步流程 | 摆放变拥塞（v13 §9） |
| floorplan / 区域约束三种形状 | 全负优化（v10 §7） |
| `-enable_route_constraint_iterate` | 选项本身坏了：生成的 `.rcf` 实例名截断（lesson 99） |
| `-retiming` | 综合好 1.5 ns、布线坏 4.3 ns（lesson 100） |
| `-fanout_guide` / 复制驱动器 | 阵列引脚无效，面积 +6% 且拥塞（lesson 101） |
| P57 | 52 MHz 上 20.252 vs 19.426（更差） |
| cut-2 | 50 MHz 上 21.5 vs 19.355（更差），省 153 LUT 不抵 |
| BTB 64→32 | +1.68% 拍数 ⇒ 5.16，破 5.2（`branch_predictor.v` 里的实测表） |
| 降频换通过（51 MHz） | 19.778 比 52 MHz 的 19.426 更差，非单调 |

## 附：本轮真正新增的可用资产

| 资产 | 用途 |
|---|---|
| `firmware/code/tools/check_delivery.py` | 九门交付判定，双向验证过（交付 PASS / 失败构建 FAIL） |
| `firmware/code/tools/board_verify.ps1` | 上板一键（含下载线预检），已演练 |
| `firmware/code/tools/run_pds_flow.py --syn-extra` | 综合选项直通（注意用 `--syn-extra=-retiming` 等号形式） |
| `docs/plan-v23-area-and-freq.md` | 5.2/120 MHz 的完整边界证明 + 逐级路径账 + 结果表 |
| `docs/lessons/mistakes-log.md` §98–101 | ISA 覆盖率假象、坏选项、retiming、高扇出复制 |
| `docs/patches/{cut2-csr-read-split,cut2-and-p57,wide4-s1s2-fetch16b}.patch` | 三条已测过的 RTL 变体，需要时直接贴回 |
