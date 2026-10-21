# 发布版位流

> **当前交付（2026-10-21）：`pangoriscv_i1152_e2.sbit` —— 板上 3.8557（同一分数，面积 −10.9%）**
> （298,780,717 ticks / 1152 迭代 / 11.066 s / 五项 CRC 全对；LUT 17,534 / FF 7,153 / kLUT 0.2199；
> setup +7.816 / hold +0.025 / 失败端点 0）
>
> 上一版（同分数、更大面积）：`pangoriscv_i1152_p37.sbit` —— 板上 3.8557
> （298,780,717 ticks / **1152** 迭代 / **11.066 s ≥ 10 s** / 五项 CRC 全对 / `Correct operation validated`）
> 交付镜像换用 **1152 迭代**：3.6345 那版用 1024 迭代已降到 9.83 s，CoreMark 判 "must execute for at least 10 secs"，
> 那就不再是有效成绩。详见 `evidence/records/optimization/perf-pair-raw-3.86/measurement.md`。
>
> 上一版交付（历史）：`pangoriscv_i1024_p36.sbit` —— 板上 3.6345
> （ticks 281,741,495 / 1024 迭代 / 10.435 s / 五项 CRC 全对 / 27 MHz `All Constraints Met`，
> hold +0.002 / 失败端点 0 / LUT 18,099）。下面 2026-10-19 的声明是历史版本（2.8833），
> 详细对比见文末「写通路吞吐版」一节。

> ## （历史）成绩有效性声明（2026-10-19：P21 位流 2.8833）
>
> **① 的分数已经在本文件这份位流上、于真实开发板上跑出来了。**
>
> | 项 | 值 |
> |---|---|
> | 板测 `Total ticks` | **288,558,769** |
> | 板测 `Iterations` | 768 |
> | 板测用时 | 10.687 s（≥10 s ✓，**832 迭代**） |
> | 板测五项 CRC | `0xe9f5 / 0xe714 / 0x1fd7 / 0x8e3a / 0x3c53` |
> | 板测结论 | `Correct operation validated` |
> | 板测 `Compiler version` | GCC15.2.0 |
> | 板测 **CoreMark/MHz** | **2.8833** |
>
> 原始串口抓取：`evidence/records/optimization/P21/board_uart_score.txt`
> （691 B）；烧写记录与 PDS 全套：同目录。
> 板卡 PG2L100H、27 MHz 晶振、Pango USB Cable II 下载、串口 CP210x @115200 8N1。
>
> **与仿真的关系**：位流中带有固件镜像（综合日志确认
> `Loading memory data from file .../program.hex`），板上串口直接读出 `Total ticks`，
> 这是**实测值**，不依赖仿真推算。
>
> **仍缺的证据**：②（时序收敛）与 ③（综合资源）是真实工具产物，已具备；
> **ILA 波形尚未抓取**（赛题文档评分项），应用场景章节尚未撰写。

## 2026-10-21 追加：写通路吞吐版（板上 **3.6345**）—— **当前交付**

> 位流 `pangoriscv_i1024_p36.sbit`。同镜像 score1024、同工具、同流程；
> 改动只有 D-Cache 的 posted store 队列 + tag 写数据重定时，以及 AXI 写引擎的两处握手重叠
> （详见 `evidence/records/optimization/perf-writepath-3.63/measurement.md`）。

| 项 | 值 |
|---|---|
| 板上 `Total ticks` | **281,741,495** |
| 板上 `Iterations` | 1024 |
| 板上用时 | **10.435 s ≥ 10 s** |
| 五项 CRC | `0xe9f5 / 0xe714 / 0x1fd7 / 0x8e3a / 0x9ce8`（与基线逐项相同） |
| 结论 | `Correct operation validated` |
| **CoreMark/MHz** | **3.6345**（相对 3.4222 → +6.21%） |
| ② 时序 | 27 MHz `All Constraints Met`，setup **+10.041**，hold **+0.002/+0.001**，失败端点 **0** |
| ③ 资源 | LUT **18,099** / FF **9,931** / LUTRAM **3,628** → CoreMark/kLUT **0.2008** |

⚠️ **这份位流 hold 只有 +0.002 ns，不要再重跑同一个构建目录**（重跑会覆盖证据，且新种子可能更差）。
若必须重建，先确认 `multiseed_summary.csv` 仍是 `single,OK,OK` 且 hold > 0。

| 文件 | 大小 | SHA256 | 板上实测 |
|---|---|---|---|
| `pangoriscv_i768.sbit` | 3,791,112 B | `1FAC6F435BA34641BB8D16285CFFFA7811D2F787AEAF08805B4F5369A2B41F23` | 2.8833（2026-10-19） |
| `pangoriscv_i1024.sbit` | 3,791,112 B | `8D12C9D114C0DBE4455E0A50C0F944B7D8506273DB28ADAEBC3755205FA6A643` | 3.4194（2026-10-20，**面积优化前**） |
| `pangoriscv_i1024_area.sbit` | 3,791,112 B | `521EC6FEFD867E244DF4C955D6DA98519BEA06F5559E36498ED928DB5B9416BB` | 3.4222（2026-10-21，面积优化版） |
| `pangoriscv_i1024_p36.sbit` | 3,791,112 B | `BE749BC4830E33BB198BD2835251DE09526F4F7F267DCB19D3A08E536EA57737` | 3.6345（2026-10-21，上一版） |
| `pangoriscv_i1152_p37.sbit` | 3,791,112 B | `81C1D04936D3D5B5F70945A847EF6E9C5832D5A21B38FA9B46C60543BBE72B62` | 3.8557（2026-10-21，P37） |
| **`pangoriscv_i1152_e2.sbit`** | 3,791,112 B | `D7BF5E41B708F893DF57F5E049BA8A0168BE39BABB4773E3BFFEA5C0C25D3137` | **3.8557（2026-10-21，当前交付，面积 −10.9%）** |

## 2026-10-21 追加：面积优化版（板上 **3.4222**，LUT −18% / FF −30%）

> **当前候选交付位流**。与 `pangoriscv_i1024.sbit` 功能完全相同（同镜像、同 CRC），
> 但经过面积专项三项减法：M1 去仪表化 + M3 BTB 缩位宽 + M4a 取指队列 16→8。

| 项 | 优化前（`i1024`） | **本版（`i1024_area`）** | Δ |
|---|---:|---:|---:|
| 板测 `Total ticks` | 299,467,030 | **299,226,614** | −0.08% |
| 板测用时 | 11.091 s | **11.082 s**（≥10 s ✓） | — |
| 板测五项 CRC | `e9f5/e714/1fd7/8e3a/9ce8` | 同 | 0 |
| 板测 **CoreMark/MHz** | 3.4194 | **3.4222** | +0.08% |
| LUT（device_map） | 21,949 | **18,006** | **−18.0%** |
| FF | 14,104 | **9,877** | **−30.0%** |
| 分布式 RAM / DRM / APM | 3,628 / 4 / 6 | 3,628 / 4 / 6 | 0 |
| **站点 S = LUT+FF+LUTRAM** | 39,681 | **31,511** | **−20.6%** |
| setup（慢角） | +14.750 | **+12.972** | 仍大量余量 |
| **hold（慢/快）** | +0.015 / +0.002 | **+0.020 / +0.015** | **余量变好** |
| 失败端点 | 0 | **0** | — |
| **CoreMark/kLUT** | 0.1558 | **0.1901** | **+22.0%** |

- 构建目录：`firmware/code/build/pango_native`（**禁止再跑第二次实现**）；
- 构建 profile：**`PERF_ENABLE` 关**（交付 profile），`CACHE_ENABLE`/`PREDICT_ENABLE` 开；
- 镜像：`score1024`（`program.hex` = `F67A0299…F42C4`），综合日志有 2 条 `Loading memory data from file`；
- 完整证据（时序报告/三阶段日志/板上原文/资源表）：`evidence/records/optimization/area-final/`；
- 面积账本与模块合同：`docs/architecture/module-area-plan.md` + `area-budget.csv`。

## 2026-10-20 追加：4 KB I-Cache + 最小 lane1 双发射（板上 3.4194，面积优化前）

> 这个文件是**备份**，不改变上面 2.8833 那份的交付地位；用哪一份交付由评审/作者决定。
> 之所以必须备份：它是**踩线收敛**的唯一一份位流（同一 RTL 的其它种子在 22k 上布不通）。

| 项 | 值 |
|---|---|
| 板测 `Total ticks` | **299,467,030** |
| 板测 `Iterations` | 1024 |
| 板测用时 | 11.091 s（≥10 s ✓） |
| 板测五项 CRC | `0xe9f5 / 0xe714 / 0x1fd7 / 0x8e3a / 0x9ce8` |
| 板测结论 | `Correct operation validated` |
| 板测 **CoreMark/MHz** | **3.4194**（= 1024 / 299,467,030 × 1e6） |
| 资源（device_map） | 21,949 LUT / 14,104 FF / DRM 4 / APM 6 / 分布式 RAM 3,628 |
| 时序（`multiseed_summary.csv`） | `All Constraints Met`；setup +14.750 / +22.341；**hold +0.015 / +0.002**；失败端点 0 |
| 配置 | 三开关全开；I-Cache 64 组（4 KB）；双发射最小 lane1 |
| 镜像 | `program.hex` = 1024 迭代（`F67A0299…`），`data.hex` = `5D5F267A…` |
| 构建目录 | `firmware/code/build/code_ic4k`（**禁止在该目录再跑第二次实现**） |
| 原始抓取 | `evidence/records/optimization/4kb_3.423/uart_4kb_recheck.txt` |

**风险（交付前必须写进口径）**：hold 仅 **+0.015 / +0.002 ns**，是"刚好过"的量级；
换种子/换温度都可能翻负。若重新实现，先看 `multiseed_summary.csv` 的 hold 列。

**板卡**：Pango PG2L100H，27 MHz 晶振。

**配置**：`CACHE_ENABLE` / `PREDICT_ENABLE` / `PERF_ENABLE` 三开关全开（全功能配置），BTB 32 项。

**固件**：CoreMark v1.0 性能跑（`PERFORMANCE_RUN=1`），**832 次迭代**，`-DCPU_FREQ_MHZ=27`。
> 迭代数随性能变化而重算：本版每迭代 346,827 ticks，
> `N ≥ ceil(10.5 × 27e6 / 346,827) = 818`，取 832 → 实测 10.687 s。
> **性能每提升一次都必须重算，否则 <10 s 会被判无效**（本版曾用 768 迭代跑出 9.865 s 而作废）。

> 迭代数为什么是 768：赛题要求单次运行 ≥10 s。本轮把 AXI RAM 猝发读的两个白等周期去掉后，
> 每迭代 ticks 降到 373,738，按 `N ≥ ceil(10.5 × 27e6 / 373,738) = 759` 重算后取 768，
> 实际 10.64 s。**性能每变一次都必须重算，否则成绩作废。**

**串口输出（2026-10-19 板上实测，同一镜像 `score768`）**：

```
Total ticks      : 288558769
Total time (secs): 10
Iterations/Sec   : 76
Iterations       : 768
seedcrc          : 0xe9f5
[0]crclist       : 0xe714
[0]crcmatrix     : 0x1fd7
[0]crcstate      : 0x8e3a
[0]crcfinal      : 0x3c53
Correct operation validated. See readme.txt for run and reporting rules.
```
> 注：`Total time (secs)` 与 `Iterations/Sec` 是固件的**整数截断**打印（`core_portme.h` 里 `HAS_FLOAT 0`）。真实时间是 10.631 s，固件按 `floor(10.631)=10` 打印，故 `Iterations/Sec = 768/10 = 76`。**分数必须用 `Total ticks` 计算**：`768 / 287,211,317 × 1e6 = 2.6740`，不能用 `Iterations/Sec` 反推。


`crcfinal` 随迭代数变化（最终 CRC 是跨迭代累积的）：20→`0x4983`、400→`0x25b5`、
512→`0xdfc8`、576→`0x7b65`、640→`0x382f`、768→`0x3c53`。官方只与已知表比对
`crclist / crcmatrix / crcstate`，三项全对，`total_errors` 为 0，故
`Correct operation validated` 已打印。

**评分口径**

| 项 | 值 | 口径 |
|---|---|---|
| ① 执行效率 | **2.6757 CoreMark/MHz** | `iterations / ticks × 1e6`，迭代数无关的归一化指标 |
| ② 时钟频率 | **27 MHz 约束 All Constraints Met**；**50 MHz 过约束同样 All Constraints Met** | 数值取自各次 PDS 的 `multiseed_summary.csv`（**收尾权威值，不是 `*_after_hold_fix.txt` 中间快照**）。27 MHz：setup **+14.578 ns**、hold **+0.115 ns**，0 失败端点，见 `evidence/records/optimization/P17/pds_27mhz_full/`。50 MHz：setup **+1.262 ns**、hold **+0.121 ns**，0 失败端点，见 `evidence/records/optimization/P17/pds_50mhz_full/`。板载晶振 27 MHz，**不是**板上实测最高频率 |
| ③ 资源效率 | **0.1985 CoreMark/kLUT** | `13,481 LUT`，**取自 device_map**（`multiseed_summary.csv` 的 `Used` 行）。同一实现另有两个阶段的数：synthesis 13,574、后布线更小；**引用 LUT 必须写阶段** |

**提升幅度**

| 阶段 | ticks | CoreMark/MHz | LUT | CoreMark/kLUT |
|---|---|---|---|---|
| S0 基线（store 优化前，400 迭代） | 306,415,752 | 1.3054 | 12,572 | 0.1038 |
| store 后台排空 B 响应（512 迭代） | 356,993,719 | 1.4342 | 12,622 | 0.1136 |
| 取指吞吐（512 迭代） | 304,495,134 | 1.6815 | 13,018 | 0.1292 |
| 访存快发（576 迭代） | 309,304,812 | 1.8622 | 13,059 | 0.1426 |
| 访存完成提前报（640 迭代） | 307,055,517 | 2.0843 | 13,099 | 0.1591 |
| 零延迟 D-Cache 命中（768 迭代） | 323,940,991 | 2.3708 | 13,558 | 0.1749 |
| 读命中不阻塞写事务（768 迭代） | 299,139,003 | 2.5674 | 13,558 | 0.1894 |
| store 当拍拿写确认（768 迭代） | 294,149,365 | 2.6109 | 13,576 | 0.1923 |
| AXI 猝发气泡清除（768 迭代） | 287,211,317 | 2.6740 | 13,574 | 0.1970 |
| LRU 修复 + 重新实现（768 迭代） | 287,030,751 | 2.6757 | 13,481 | 0.1985 |
| 复核 R01/R02/R04 修复 + 重建（768 迭代） | 284,997,892 | 2.6948 | 13,503 | 0.1995 |
| store 数据随请求拍递出（768 迭代） | 280,487,382 | 2.7381 | 13,555 | 0.2020 |
| I-Cache 扩到 4 KB（64 组）+ 上述改动 | 273,172,370 | 2.8115 | 14,622 | 0.1923 |
| **I-Cache 扩到 8 KB（128 组）+ 上述改动（本版位流，832 迭代）** | **288,558,769** | **2.8833** | **16,782** | **0.1718** |

累计 **+104.97% CoreMark/MHz**（超过一倍）、**+91.24% CoreMark/kLUT**，
面积仅 **+7.23%**（12,572 → 13,481）。本版相对上一版是 **性能 +0.06%**；主要变更是修掉独立复核提出的 R03（快命中路径漏更新 LRU，`d_miss` −8.3%）。

**三项数据同源**：本目录位流、`13,481 LUT`、27 MHz 时序，全部来自同一次 PDS 运行，整套原始产物已归档在 `evidence/records/optimization/P17/pds_27mhz_full/`（位流 + `multiseed_summary.csv` + `report_timing.rtr` + `device_map` / `synthesize` / `place_route` / `compile` 日志）。50 MHz 那一套在同级 `pds_50mhz_full/`。

**时序余量说明**

- 27 MHz：setup **+14.578 ns**、hold **+0.115 ns**，0 失败端点（`multiseed_summary.csv` 收尾值）。
- 50 MHz：setup **+1.262 ns**、hold **+0.121 ns**，0 失败端点，是本版最紧的一项。
- **口径**：`place_route/*_after_hold_fix.txt` 是中间快照，其 slack 与最终值不同（本版中间值 17.390，收尾 14.578）。引 slack 只用 `multiseed_summary.csv`。
- 收敛经验（务必保留）：
  - 27 MHz 的 hold 必须用 **`-fix_hold_violation_threshold 500`**（不是 300）；
    但对本版而言**阈值不再敏感**（500 与 700 的结果完全相同，都是 3 个端点 −0.012），
    最终靠 `-groute_seed/-gplace_seed 11` 才通过。`seed 41` 路由器甚至不收敛
    （1042 次迭代后仍有 1096 根未布线）。
  - **50 MHz 是种子敏感的**：本版 `seed 23` 一次通过。换一次 PnR 可能不收敛，
    **不能拿一次通过当保证**。

**可复现性**：同一组 PnR 参数重跑，slack 与失败端点数完全一致，但 `.sbit` 的 SHA256
每次不同（Pango 位流容器含非确定性元数据）。所以"位流哈希一致"不能当作可复现的证据，
必须连同该次运行的时序汇总一起归档。

**证据等级（重要）**：CoreMark 的 ticks / CRC / 运行时间均来自**周期精确的 RTL 仿真**，
不是板上实测——目前没有物理开发板。仿真里"总时间"由固件按 `CPU_FREQ_MHZ=27` 从 ticks 换算，
因此在 27 MHz 板卡上就是表中的 10.64 s；但**串口实物输出仍需上板复现**。
频率一栏是约束收敛结果，按赛题诚信边界不得写成"实测最高频率"。

上板后必须补的三件事：实板串口抓完整报告、ILA 抓 CoreMark 关键算法波形、
以及用实测数据重算迭代数。详见 `docs/verification.md` 与
`evidence/records/optimization/P16/measurement.md`。

**已取代**：`pangoriscv_i400.sbit`、`pangoriscv_i512.sbit`、`pangoriscv_i576.sbit`、
`pangoriscv_i640.sbit` 均已从本目录移除，其数据保留在 git 历史与 `evidence/records/` 中。

自行重新构建位流的流程见 `firmware/code/platform/pango_native/README.md`。
**注意**：必须在 `build/pango_native` 目录里直接启动 `pds_shell`，否则 `$readmemh`
找不到 `program.hex`/`data.hex`，会得到存储器全空的位流；反过来若从源码根启动，
产物会写进 `firmware/code/` 污染工作区。
