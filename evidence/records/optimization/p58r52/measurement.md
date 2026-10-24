# p58r52 —— 52 MHz 第一次：布线成功，时序差 0.195 ns（本家族 52 MHz 最好的一次）

**日期**：2026-10-24 13:15–13:32
**RTL**：主干 `main`（cut-2 树，无 P57），PLL `27*52/27`（VCO 1404）
**镜像**：`hw_i2900_52b`（2900 迭代；2900×190,535÷52e6 = 10.63 s ≥ 10 s）
**约束**：`--freq 52` → 19.230769 ns
**pnr 选项**：`-dc_duplication TRUE -slack_prior_in_global_router TRUE -refineplacement_cluster TRUE -optimize_routing_recovery TRUE`

## 结果

| 项 | 值 | 判定 |
|---|---|---|
| `Unrouted nets` | **0（第 186 轮）** | ✅ 布线收敛 |
| `Design Summary` | `Fail` | ✗ |
| setup WNS | **−0.195 ns**（`report_timing` 收尾值；`after_hold_fix` 快照报 −0.079 / 4 端点） | ✗ |
| 失败端点 | 12（`after_hold_fix` 快照 4） | ✗ |
| hold | +0.025，0 失败 | ✅ |
| LUT / FF / LUTRAM / DRM / APM | **17,027** / 8,597 / 2,274 / 12 / 10 | ✅ ≤18,000 |
| 位流 | `generate_bitstream/pangoriscv_top.sbit`，sha256 `c6ed4e272cba1f03f2c443977e3bf0c83e7ceb75598502c7c27599f9ae48cf09` | 镜像已加载（program.hex + data.hex 各一条 `Loading memory data from file`） |
| 全流程耗时 | 17m15s | — |

## 关键对比（这是本轮最重要的信息）

| 尝试 | 树 | pnr 选项 | 布线结果 | 判定 |
|---|---|---|---|---|
| `p48r50b`/`p48r50` | pair45 | 默认 | 21.120 / 21.600 | ✗ |
| `p50r52` | cut2+ | 默认 | 20.222 | ✗ |
| `p52qual2` | pair45+ | 只有 `-enable_route_constraint_iterate` | 第 680 轮仍有 **1,259 根未布通**（发散） | ✗ |
| **`p58r52`** | **cut-2** | **四个质量选项** | **19.426（186 轮收敛）** | ✗ 差 0.195 |

⇒ **`-dc_duplication` + `-slack_prior_in_global_router` + `-refineplacement_cluster` 把 52 MHz 从
"布不通/20.2 ns" 拉到 19.426 ns**，方向是对的；`-enable_route_constraint_iterate` 单独用会让布线发散，
加了这四个选项之后是否还发散，由 `p58r52b` 验证。

## 路径分解（为什么还差 0.195）

```
Data arrival 21.533 ns（含时钟插入 ~2.5 ns）  Logic 7.938 ns (42.0%) / Route 10.960 ns (58.0%)，13 级
```

与交付 `p48r50e`（50 MHz）对比：

| 树 | Logic | Route | 13 级？ |
|---|---:|---:|---|
| 交付 `p48r50e` | 3.685 ns (18%) | 16.470 ns (82%) | — |
| **cut-2（本建）** | **7.938 ns (42%)** | 10.960 ns (58%) | 13 级 |

**这正是 lesson 97 的另一面**：切掉 CSR 那条路径之后，综合把
`rr_pred → 操作数选择 → ALU → ex_value_h` 的锥合并得更深，逻辑从 3.7 ns 涨到 7.9 ns。
布线反而更干净（10.96 vs 16.47），净效果是总路径几乎打平（19.43 vs 19.36）。

⇒ 想再要 0.2 ns，靠"布线质量选项"已经接近极限，得动逻辑锥（或换回逻辑更短的树）。

## P59：把那条 DSP 路径删掉（重新应用 P57）——**更差**

最差路径的 13 级里有 8.75 ns 是 `u_mul_h` 的四段 APM 级联，前面还串着 lane 0 的整条组合 ALU
（`alu_a → u_alu 4 级 → fwd1_h`，5.3 ns）。这正是 P57 当初要删的东西，而 P57 那一轮因为
"50 MHz 用不上"被回退。于是重新应用（`docs/patches/cut2-and-p57.patch` 的 `rv32_top` 部分）：

* `packet_alu_mul_use` 进 `pair_ok`（拒绝"lane1 乘除读 lane0 本拍结果"这一种包）
* `fwd1_hn` / `fwd2_hn`（= `fwd1_h`/`fwd2_h` 去掉 `lane0_raw ? alu_y :` 项）驱动 `u_mul_h`

**仿真**：`Total ticks 3,810,540`（比交付**少 160 拍**），五项 CRC 全对 ⇒ 分数 5.24862（略好），
LUT 17,021 → **17,152**（+131）。

**实现（`p59r52`，52 MHz，同一套四个质量选项）**：

| | 不含 P57（`p58r52`） | 含 P57（`p59r52`） |
|---|---|---|
| LUT | 17,027 | 17,152 |
| 摆放 slack | +1,894 ps | +1,906 ps（**与旧的默认选项构建 `p50r52` 逐位相同**） |
| 最差路径级别 | **13 级** | **24 级** |
| Logic / Route | 7.938 / 10.960 | **3.685 / 16.470** |
| 布线后路径 | **19.426 ns** | **20.252 ns** |
| WNS | −0.195（12 端点） | **−0.991（1,024 端点）** |

**结论：P57 把最差路径让给了一条 24 级的"布线主导"路径（Route 16.47 ns），净效果差 0.83 ns。**
这是 lesson 97 的第三次复现——「砍掉第一名，第二名可能更糟」，而且**与逻辑量无关**。

补充证据：`p50r52`（同一棵 P57 网表、**默认** pnr 选项）与本建（四个质量选项）
在摆放与布线上**逐位相同**（`Worst Slack Before RP` 都是 396338、after DP 都是 1903/1906、
WNS 都是 −0.991/1024 端点）⇒ **这四个选项对这棵网表完全无效**，
它们的作用在 `p58r52`（不含 P57 的网表）上才显现（20.222 → 19.426）。

⇒ 交付候选回到**不含 P57** 的 `p58r52` 树（17,027 LUT）。

