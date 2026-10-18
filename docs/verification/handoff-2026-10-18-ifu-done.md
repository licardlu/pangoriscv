# pangoriscv 交接报告（2026-10-18 · CoreMark/MHz 2.6757，累计 +105.0%）

> 用途：新会话直接从这里接手。所有结论都有实测数据与证据目录支撑，不依赖对话历史。
> 上一份交接：`handoff-2026-10-17-optimization.md`（其"下一步 IFU"一节已由本文取代）。
> **本文件在 P8/P9/P10/P13/P14/P16 完成后持续更新**：第一节与链条表给的是 P16 的最新数字，
> 细节分别见 `evidence/records/optimization/P8|P9|P10|P13|P14|P16/measurement.md`。

---

## 一、当前交付状态（一句话）

**取指吞吐（P7）+ 访存快发（P8）+ 完成提前报（P9）+ 零延迟命中（P10）
+ 读命中不阻塞（P13）+ store 当拍拿确认（P14）+ 突发气泡清除（P16）七步做完：
CoreMark/MHz 1.3054 → 2.6757（+105.0%），面积只 +7.2%，
27 MHz 与 50 MHz 约束均收敛。**
唯一没做的是上板（没有物理开发板）。

| 评分项 | 交付值 | 来源 |
|---|---|---|
| ① 执行效率 | **2.6757 CoreMark/MHz** | 768 迭代有效跑分，ticks 287,030,751，10.63 s（**RTL 仿真**） |
| ② 时钟频率 | **27 MHz 与 50 MHz 约束均 All Constraints Met** | 27 MHz：setup **+14.578 ns**、hold **+0.115 ns**，0 失败；50 MHz：setup **+1.262 ns**、hold **+0.121 ns**，0 失败（均取 `multiseed_summary.csv`） |
| ③ 资源 | **13,481 LUT（device_map）** / 0.1985 CoreMark/kLUT | synthesis 13,574、后布线更小，引用必须写阶段；触发器 8,507 |

**PDS 收敛经验（务必保留）**：27 MHz 的 hold 必须用
`-fix_hold_violation_threshold 500`（不是 300），否则会留下 1~5 个 −0.001~−0.027 ns 端点，
根因是 D-Cache LUTRAM 写口跨时钟树分支的偏斜。
**50 MHz 是种子敏感的**：本版 seed 11→−0.001、seed 41→−0.155、seed 23 才通过。

**三项数字的链条**（务必按这个口径说，别混）：

| 阶段 | 每迭代 ticks | CoreMark/MHz | LUT | CoreMark/kLUT |
|---|---|---|---|---|
| S0 基线（store 优化前） | 766,039 | 1.3054 | 12,572 | 0.1038 |
| P2' store 后台排空 B | 697,254 | 1.4342 | 12,622 | 0.1136 |
| P7 取指吞吐 | 594,717 | 1.6815 | 13,018 | 0.1292 |
| P8 访存快发 | 536,987 | 1.8622 | 13,059 | 0.1426 |
| P9 完成提前报 | 479,774 | 2.0843 | 13,099 | 0.1591 |
| P10 零延迟命中 | 421,798 | 2.3708 | 13,558 | 0.1749 |
| P13 读命中不阻塞 | 389,504 | 2.5674 | 13,558 | 0.1894 |
| P14 store 当拍确认 | 382,986 | 2.6109 | 13,576 | 0.1923 |
| P16 突发气泡清除 | 373,973 | 2.6740 | 13,574 | 0.1970 |
| **P17 LRU 修复（本版）** | **373,738** | **2.6757** | **13,481** | **0.1985** |

- 相对最初交付（S0）：**+104.84% CoreMark/MHz**、**+89.72% CoreMark/kLUT**，
  面积仅 +7.97%
- 相对上一版（P14）：**+2.42%**，面积 **−2 LUT / −2 FF（中性）**

位流：`bitstream/pangoriscv_i768.sbit`，3,791,112 B，
SHA256 `0878A35D1D1371209C4E6987F43DB535A54300DDAC15E21A9D9F69A77B3E7B0F`。
（`.sbit` 字节不可复现：同一组参数重跑 slack 完全一致但哈希不同，归档必须同时记录时序汇总。）

---

## 二、本轮做成的唯一性能改动（P7）

### 根因（上一轮推断，本轮数据闭环）

`ifu_axi` 假设"同时只有一笔取指在飞"，`icache_axi` 命中后又要停在 `IC_RESP` 一拍，
两者锁步 → **取指供给 0.5 IPC 天花板**。基线 `if_wait` = 3,269,814 拍 = 全周期的 20.6%。

### 改法（只动两个文件）

1. `ifu_axi.v`：2 深 PC FIFO（`pcf0/pcf1`、`pdf0/pdf1`）+ `ocnt_q`（0..2）；
   响应配槽 0 后前移；`count_q + ocnt_q < DEPTH` **预留队列表项**，
   所以 `eng_rsp_ready` 可以无条件为高（否则会出现"要了响应却塞不进队列"丢指令）；
   重定向改用 `stale_cnt_q` 按笔计数吞迟到响应。
2. `icache_axi.v`：`req_ready` 增加 `rsp_leaving` 条件，`IC_IDLE`/`IC_RESP` 合并受理分支
   → 连续命中 1 拍 1 条。

### 实测（同镜像同测试台 A/B，基线 `99e8bdb`）

| 指标 | 基线 | 本轮 | 变化 |
|---|---|---|---|
| ticks（20 迭代） | 13,940,928 | **11,887,687** | **−14.73%** |
| cycles | 15,866,750 | 13,809,115 | −12.97% |
| IPC | 0.4046 | **0.4686** | +15.8% |
| `if_wait` | 3,269,814 | **742,122** | **−77.30%** |
| `lsu_wait` | 1,560,772 | 1,560,816 | +0.00% |
| `d_miss` / `mispred` / `ret_cf` | 4,209 / 154,321 / 1,401,059 | 相同 | 0 |
| 五项 CRC | — | 逐项一致 | 架构等价 |

只有 `if_wait` 掉、其它停顿项不动 → 收益确实来自取指供给。

### 同镜像同迭代数的绝对 A/B（512 迭代，两侧都是有效跑分）

| 指标 | 基线 `99e8bdb` | 本轮 | 变化 |
|---|---|---|---|
| ticks | 356,993,719 | **304,495,134** | **−14.71%** |
| cycles | 358,802,946 | 306,299,998 | −14.63% |
| IPC | 0.4130 | **0.4840** | +17.2% |
| CoreMark/MHz | 1.4342 | **1.6815** | **+17.24%** |
| `Correct operation validated` | 是 | 是 | — |
| `crcfinal`（同迭代数） | 0xdfc8 | **0xdfc8** | 完全一致 |

---

## 三、交付跑分为什么是 512 迭代

性能提上去后 400 迭代会掉到 8.8 s，违反赛题"≥10 s"硬性规则。

```
每迭代 ticks = 594,717
N ≥ ceil(10.5 × 27e6 / 594,717) = 477  → 取 512（11.28 s）
```

**以后任何性能或频率改动都必须重算这个数**，否则成绩作废。

跑分结果：ticks 304,495,134 / 11.28 s / 512 迭代 /
`seedcrc 0xe9f5`、`crclist 0xe714`、`crcmatrix 0x1fd7`、`crcstate 0x8e3a`、`crcfinal 0xdfc8` /
`Correct operation validated` / traps 0 / faults 0。

> `crcfinal` 随迭代数变化（跨迭代累积），官方只比对 list/matrix/state 三项。
> 赛题按整数秒口径读是 512/11/27 MHz ≈ 1.72；按 tick 精确是 **1.6815**，报告一律用后者。

---

## 四、27 MHz 交付实现与 hold 收敛的坑

第一轮全流程：setup WNS +16.521 ns、**0 失败**，但 **hold 4 个端点 −0.020 ns 不过**。
失败路径全是 I-Cache 分布式 RAM 写口，根因是**时钟树分支偏斜**
（launch `HCKBROUTE_2` 3.238 ns / capture `HCKBROUTE_1` 3.832 ns，跨列），
不是数据路径太长——数据侧 0.312 ns 的广播网络延迟反而在吃余量。

修法（**不放松任何约束**：无 false_path、无 multicycle、不降周期）：

```powershell
$env:PANGO_NATIVE_PNR_EXTRA = "-fix_hold_violation -fix_hold_violation_threshold 150 " +
  "-fix_hold_violation_threshold_for_clk_tree 150 " +
  "-fix_hold_violation_threshold_for_clock_path_cross_srb 150 " +
  "-fix_hold_violation_iterations 400 -max_hold_violated_paths_num 4000 " +
  "-groute_seed 23 -gplace_seed 23"
```

即"阈值从 0 提到 150 ps + 换布局/走线种子"，结果 hold **+0.154 / +0.113 ns，0 失败**。
`build.tcl` 为此新增 `PANGO_NATIVE_PNR_EXTRA` 钩子，默认参数不变。

---

## 五、资源口径（别再用旧的 12,572 直接比）

本轮新增 `platform/pango_native/resource_check.tcl`：与 `build.tcl` 相同前端
（同源清单、同 include 路径、同约束、同镜像、同"两幅存储器已载入"守卫），
**停在 device_map**，三分钟出与正式位流一致的 LUT/FF/DRAM。

| 项 | 基线 `99e8bdb` | 本轮 | 变化 |
|---|---|---|---|
| Total LUTs | 12,622 | **13,018** | **+396（+3.14%）** |
| ├ as logic | 9,937 | 10,333 | +396 |
| └ as DRAM | 2,685 | 2,685 | 0 |
| Total Registers | 7,402 | 8,639 | +1,237 |

基线侧与归档的 12,572 / 7,398 差 0.4% / 0.05%，口径一致。
**触发器增幅大于手写改动**（2 深 FIFO 实测约 +70，网表里也没有被复制），
属综合在共享/编码策略上的整体选择差异；它不进评分项③（按 LUT），也不影响时序
（27 MHz 下 setup 仍余 +14.127 ns）。

CoreMark/LUTs：`0.1034 → 0.1292 每 kLUT`（**+24.9%**）——性能涨 28.8%，面积只涨 3.14%。

---

## 六、还剩什么（只有上板）

1. 下载 `pangoriscv_i512.sbit`，串口抓完整 CoreMark 报告（**板上 ≥10 s 必须重新验证**）；
2. ILA 抓 CoreMark 关键算法波形（赛题文档评分项，目前 NOT RUN）；
3. 板上实测频率（约束值 vs 收敛实测值，两个口径分开写）；
4. 用板上数据替换仿真分数并重算迭代数；
5. `SCBV` 未设置（`C: Bitstream-2001`），需按板卡 PCB 确定，现有资料无权威来源，**不猜值**。

---

## 七、环境与工具链（现在共 9 条，前 7 条照旧）

| 坑 | 应对 |
|---|---|
| 工具链前缀是 `riscv-none-elf-`，赛题写的是 `riscv32-unknown-elf-` | 构建用 `--prefix riscv-none-elf-` |
| GCC 15 不再隐含 Zicsr | 必须 `--extra-flag=-march=rv32im_zicsr` |
| `soc_config.vh` 三个开关仓库默认**全关** | 只跑单元/回归时保持全关（`run_pipeline_tests.py` 固定源清单，开关一开就因缺 `branch_predictor` 精化失败）；CoreMark/PDS 才全开，结束无条件还原 |
| ModelSim 复用陈旧 `_opt` 缓存 | 每次编译前删 `work\@_opt*` |
| **PDS 的 `$readmemh` 用进程工作目录** | 从别处启动会得到**存储器全空**的位流且守卫放行；必须 `cd build/pango_native` 后启动，并确认日志有 `Board check: 2 memory images loaded` |
| 用脚本 `-replace` 批量改源码 | 禁止，一律精确编辑 |
| 测试台探针名与 RTL 信号不一致 | 会 vopt 精化失败（vopt-7063）；改 tb 不改 RTL |
| **不能在要删的目录里删自己** | 删目录的进程 `cwd` 放父目录，再另起作业进目标目录；否则 PDS 打开残留旧工程（`report_timing` 是旧网表） |
| `run_halt_reset_tests.py` 硬编码 `riscv32-unknown-elf-` | 已在工具链 bin 内补三个同目录副本（gcc 按自身路径找 libexec，改名可用） |

---

## 八、已经用数据否决的方向（别再做）

| 方向 | 实测 | 结论 |
|---|---|---|
| D-Cache 扩容 | 2→4→8 KB 只快 0.39% / 0.53%，面积 ×4 | 否决 |
| BTB 扩容 | 64/128 项只快 1.68% / 1.84%，LUT +15% / +32% | 否决，恢复 32 项 |
| 取指改造前的"只改 IFU"或"只改 I-Cache" | 单独改任一个与基线**逐位相同**，两个一起改才死锁 | 必须成对改，且要 2 深请求登记 |

---

## 九、纪律（继续守）

- 任何提速改动必须同时记 LUT/寄存器；只看 ticks 会做出亏本决策（BTB 那次就是）。
- 每条结论都要有 **A/B 数字 + 单元测试 + ISA 15/15 + CRC 一致** 四项证据。
- 性能变了就重算迭代数（§3 公式）。
- 不把仿真数据写成板上实测；不把工具按 slack 推算的频率写成实测最高频率。
