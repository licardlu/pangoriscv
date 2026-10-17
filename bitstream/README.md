# 发布版位流

| 文件 | 大小 | SHA256 |
|---|---|---|
| `pangoriscv_i512.sbit` | 3,791,112 B | `CCE6CD7215E797C5E46AC745744D69EC08900198DE5079DD1E97B0996984855B` |

**板卡**：Pango PG2L100H，27 MHz 晶振。

**配置**：`CACHE_ENABLE` / `PREDICT_ENABLE` / `PERF_ENABLE` 三开关全开（全功能配置），BTB 32 项。

**固件**：CoreMark v1.0 性能跑（`PERFORMANCE_RUN=1`），**512 次迭代**，`-DCPU_FREQ_MHZ=27`。

> 迭代数为什么是 512：赛题要求单次运行 ≥10 s。本轮把取指通路提速后，400 迭代会掉到
> 8.8 s（不合格），按 `N ≥ ceil(10.5 × 27e6 / 594,717) = 477` 重算后取 512，实际 11.28 s。
> 性能再变时必须重算，否则成绩作废。

**串口输出（RTL 仿真，同一镜像 `score512`）**：

```
Total ticks      : 304495134
Total time (secs): 11
Iterations/Sec   : 46
Iterations       : 512
seedcrc          : 0xe9f5
[0]crclist       : 0xe714
[0]crcmatrix     : 0x1fd7
[0]crcstate      : 0x8e3a
[0]crcfinal      : 0xdfc8
Correct operation validated. See readme.txt for run and reporting rules.
```

`crcfinal` 随迭代数变化（最终 CRC 是跨迭代累积的）；官方只与已知表比对
`crclist / crcmatrix / crcstate`，三项全对，`total_errors` 为 0，故
`Correct operation validated` 已打印。

**评分口径**

| 项 | 值 | 口径 |
|---|---|---|
| ① 执行效率 | **1.6815 CoreMark/MHz** | `iterations / ticks`，迭代数无关的归一化指标 |
| ② 时钟频率 | **27 MHz 约束下 All Constraints Met** | setup WNS **+14.127 ns**、hold WHS **+0.154 ns**，0 / 52,349 失败端点；板载晶振 27 MHz，**不是**板上实测最高频率 |
| ③ 资源效率 | **0.1292 CoreMark/kLUT** | `Total LUTs 13,018`（as logic 10,333 + as DRAM 2,685），取自 `device_map` |

**提升幅度（同镜像、同 512 迭代、两侧都是有效跑分）**

| 阶段 | ticks | CoreMark/MHz | LUT | CoreMark/kLUT |
|---|---|---|---|---|
| S0 基线（store 优化前） | 306,415,752（400 迭代） | 1.3054 | 12,572 | 0.1038 |
| store 后台排空 B 响应 | 356,993,719 | 1.4342 | 12,622 | 0.1136 |
| **取指吞吐（本版位流）** | **304,495,134** | **1.6815** | **13,018** | **0.1292** |

即累计 **+28.8% CoreMark/MHz**、**+24.4% CoreMark/kLUT**；本版相对上一版是
**性能 +17.24%、面积 +3.14%**。两侧 512 迭代的 `crcfinal` 同为 `0xdfc8`。

**三项数据同源**：本目录位流、`13,018 LUT`、上表时序，全部来自同一份源码树
（`ifu_axi` 两笔未完成请求 + `icache_axi` 背靠背命中）配同一份 `score512` 镜像。

**证据等级（重要）**：CoreMark 的 ticks / CRC / 运行时间均来自**周期精确的 RTL 仿真**，
不是板上实测——本轮没有物理开发板。仿真里"总时间"由固件按 `CPU_FREQ_MHZ=27` 从 ticks 换算，
因此在 27 MHz 板卡上就是表中的 11.28 s；但**串口实物输出仍需上板复现**。
频率一栏是约束收敛结果，按赛题诚信边界不得写成"实测最高频率"。

上板后必须补的三件事：实板串口抓完整报告、ILA 抓 CoreMark 关键算法波形、
以及用实测数据重算迭代数。详见 `docs/verification/handoff-2026-10-18-ifu-done.md` 与
`evidence/records/optimization/P7/measurement.md`。

**已取代**：`pangoriscv_i400.sbit`（400 迭代、取指改造前的实现）已从本目录移除，
其数据保留在 git 历史与 `evidence/records/` 中。

自行重新构建位流的流程见 `firmware/code/platform/pango_native/README.md`。
**注意**：必须在 `build/pango_native` 目录里直接启动 `pds_shell`，否则 `$readmemh`
找不到 `program.hex`/`data.hex`，会得到存储器全空的位流。
