# 原始测量结果（bottleneck audit）

所有数字均来自 `tb_coremark_audit_v2.sv` / `tb_uart_run.sv` 的仿真日志，日志文件在
`logs/`，脚本在 `scripts/`。仿真使用工作副本 `work/tree`（发布树的副本，发布树本身未被改动）。

> **v2 修订（重要）**：第一版测量（`tb_coremark_audit.sv`，日志 `sim_audit_*.log`）有三个口径缺陷，
> 已在 v2 中修正，本文件以 v2 为准：
> 1. 直方图（取指队列占用、延迟、间隔）统计了**整段仿真**（含启动载入与 UART 打印），与 CoreMark
>    算法区间混用；v2 全部改为**只统计区间内**。
> 2. LSU 停顿只给了总数，load/store 未拆分；v2 按周期按 `is_store` 直接计数，并进一步按
>    `lsu_axi` 状态归因。
> 3. “取指饿死（STARVE）”是**剩余分类**，不能当作取指原因的证明；v2 改名为 `frontend_idle` 并
>    拆成 5 项（队列空等响应 / 队列空空闲 / 队列有货但 EX 空 / 重定向期间 / 其它气泡）。

## 0. 采样窗口与计数器定义

| 项 | 定义 |
|---|---|
| 采样窗口 | CoreMark 计时区间：`core_portme.c` 的 `start_time()` 第一次 `csrr cycle` 到 `stop_time()` 第二次 `csrr cycle`；TB 在 `retire_inst==32'hc0002573`（`csrr cycle`）的退休点采样，START＝第一次、STOP＝第二次 |
| 计数器位宽 | 所有计数器 32 bit 无符号；cycle CSR 32 bit，27 MHz 下 159.07 s 回绕；本区间 11.87 s，不回绕 |
| 区间差值 | TB 在 START/STOP 各拍一次快照；`AUDIT_INT*` 为差值，`AUDIT_SUMMARY` 为整段仿真（含启动与 UART 打印），两者不混用 |
| 互斥分类（v2 按周期直接计） | 优先级 `RETIRE > LSU_load/LSU_store > DIV > EX > frontend_idle`；每个周期只归一类，TB 用 **三处 `$fatal` 硬断言**校验（分类和、LSU 相位和、前端拆分和），不等即终止仿真并打印 `AUDIT_CHECK … MISMATCH`；通过时打印 `AUDIT_CHECK class_sum=NNN interval_cycles=NNN`（四组运行全部通过） |
| LSU 相位归因 | 在 `cls_lsu*` 周期上，按 `soc.core.lsu.axi_inst`/LSU 状态细分：`EMPTY / REQUEST / WRITE_DATA / READ_WAIT / WRITE_WAIT / COMPLETE` |
| frontend_idle 拆分 | `empty`（取指队列空）再分 `empty_wait_rsp`（有请求在途等 I-Cache 响应）/ `empty_idle`（无请求在途）；`bubble`（队列有货但 EX 空）；`redirect_cycles`（重定向期间） |
| 原始事件 | `ifwait`（`fetch_enable && fetch_ready && !fetch_valid`）、`lsuwait`（`op_valid && !done_valid`）为独立计数，**可以重叠**，不可相加当总周期 |
| 访存计数 | load＝`lw/lb/lh/lbu/lhu` 完成数，store＝`sw/sb/sh` 完成数，mdiv＝乘除发射数 |
| AXI 计数 | 在 `soc.core` 的 AXI 线上采样：`i_ar/i_r`、`d_ar/d_r`、`d_aw/d_w/d_b` |

## 1. 全功能构建（CACHE_ENABLE + PREDICT_ENABLE + PERF_ENABLE）

### 1.1 performance 镜像，1 次迭代（与板上 400 次迭代同参数）
日志：`logs/sim_audit_v2_perf1.log`（v2）／`logs/sim_audit_perf1.log`（v1，仅作对照）

| 指标 | v2 数值 |
|---|---|
| 区间周期 | **803,230** |
| 区间退休指令 | **305,069** |
| IPC / CPI | **0.37980 / 2.633** |
| 互斥分类（按周期） | RETIRE **305,069（38.0%）** \| LSU_load **170,169（21.2%）** \| LSU_store **174,995（21.8%）** \| DIV 0 \| EX 0 \| frontend_idle **152,997（19.0%）** |
| LSU 相位（sum=345,164） | EMPTY 71,510 \| REQUEST 71,510 \| WRITE_DATA 31,374 \| READ_WAIT 58,523 \| **WRITE_WAIT 112,247** \| COMPLETE 0 |
| 每笔访存代价 | load ≈ 3.05 拍（=1 empty+1 req+1.05 read_wait）；store ≈ 11.16 拍（=1 empty+1 req+2 write_data+**7.16 write_wait**） |
| frontend_idle 拆分（sum=152,997） | empty 141,936（92.8%，其中 **empty_wait_rsp 131,022**、empty_idle 10,914）\| bubble 11,061 \| redirect_cycles 10,914 |
| 原始事件 | ifwait 153,442 \| lsuwait 71,510 \| predmiss 10,914 \| redirect 10,914 \| trap 0 \| mdiv 0 |
| 访存 | load 55,823 \| store 15,687 |
| I-Cache | 请求 334,459，miss 397（0.12%），AR 397 次、R 3,176 拍（ARLEN=7，8 拍/行） |
| D-Cache | 请求 71,510，miss 92（0.13%），AR 92 次、R 736 拍，single-beat 0 |
| 写通道 | d_aw = d_b = 15,687（每次 store 一笔） |
| 取指队列占用（区间） | 0:**170,808（21.3%）** 1:**202,692（25.2%）** 2:40,350 3:26,791 4:27,617 5:46,220 6:77,695 7:97,357 8:113,700（14.2%） |
| IFU 发请求间隔（区间） | **gap=2: 294,346 / 334,458 = 88.0%**；gap=3: 21,384；gap=11: 6,141 |
| I-Cache 响应延迟（区间） | hit lat=1: 334,062（99.9%）；miss lat=30/31: 397 |
| LSU op→done 延迟（区间） | lat=3 **55,731**（load 命中）\| lat=11 **15,579**（store 写穿等 B）\| lat 26–57 约 200（D-Cache miss） |
| redirect→下一次 retire（区间） | lat=5 **8,084（74.1%）** \| lat=8 1,549 \| lat=16 **1,592** \| 长尾至 90 |
| **store 连跑长度**（区间） | stores 15,687、max_run **27**；len=1 **12,965（82.6%）**、len=2 342、len=3 121、len=4 222、len=5 110、len=6 1、len=11 2、len=13 1、len=14 4、len=15+ 6 |

`TEST_FAIL` 只表示 performance 镜像不打印 `Correct operation`（`report_seen=0`），不是功能失败
（该轮 `traps=0 faults=0`，且同一镜像 validation 版由 TB 判 PASS）。

### 1.2 validation 镜像，1 次迭代（v1 数据，仅作一致性对照）
`logs/sim_audit_full_iter1.log` — 区间 804,633 拍 / 退休 305,505 / IPC 0.3797；
与 1.1 的 803,230 相差 0.17%，说明 validation 与 performance 数据集每迭代代价几乎相同。

## 2. 默认构建（三个宏全关，与 `soc_config.vh:34-36` 的出厂状态一致）

日志：`logs/sim_audit_v2_base.log`（v2，validation 镜像，1 次迭代）

| 指标 | 数值 |
|---|---|
| 区间周期 | **3,045,748** |
| 退休指令 | 305,505（与全功能同镜像**完全相同**，架构等价） |
| IPC / CPI | 0.10031 / 9.97 |
| 互斥分类 | RETIRE **305,505（10.0%）** \| LSU_load **655,453（21.5%）** \| LSU_store **163,721（5.4%）** \| frontend_idle **1,921,069（63.1%）** |
| LSU 相位 | EMPTY 71,787 \| REQUEST 71,787 \| WRITE_DATA 15,560 \| **READ_WAIT 542,999** \| WRITE_WAIT 117,041 |
| 每笔访存代价 | load ≈ **11.66 拍**（未命中 Cache，每次单独 AXI 读）；store ≈ **10.52 拍** |
| frontend_idle 拆分 | empty 1,687,351（其中 **empty_wait_rsp 1,646,086**、empty_idle 41,265）\| bubble 233,718 \| redirect 41,265 |
| 访存 | load 56,227 \| store 15,560 |
| AXI | **i_ar = i_r = 346,770**（每次取指一次单拍读，取指与响应不可重叠）；d_ar = d_r = 56,227；d_aw = d_b = 15,560 |
| 错预测 | 41,265（全功能时 10,914，多 3.78×：无 BTB） |

**同镜像 A/B（v3 修正：此前 3.79× 是“默认 validation ÷ 全功能 performance”的混镜像错误）**：
- performance 镜像：全功能 **803,230** vs 默认 **3,041,345** = **3.786×**（`logs/sim_audit_v2_base_perf.log`；
  默认侧 retire 305,069 / lsu_load 650,698 / lsu_store 165,123 / frontend_idle 1,920,455，和 = 3,041,345）
- validation 镜像：全功能 **804,633** vs 默认 **3,045,748** = **3.785×**
两侧结论一致（≈3.79×），退休数完全对应。历史材料里的 1.86× / 2.05× 出自旧 RTL，不能与当前源码混用。

## 3. 基线身份核对

| 项 | 数值 | 来源 |
|---|---|---|
| 板测成绩（当时抄录） | 320,541,251 ticks / 400 次迭代 / 27 MHz | `firmware/code/README.md:43`（原始 UART 行）；**原始日志文件已在开发机误删，需重新上板采集** |
| 板测每迭代 | 320,541,251 / 400 = **801,353 拍** | 计算 |
| 仿真每迭代（同参数 performance 镜像） | **803,230 拍** | `logs/sim_audit_v2_perf1.log` |
| 差异 | **+0.23%**（仿真慢 1,877 拍） | 计算 |
| 精确成绩 | 400 / (320,541,251/27e6) / 27 = **1.2481 CoreMark/MHz**，绝对分 33.69 | 计算 |
| 历史 1.35 的口径 | 把 11.8719 s 截断成 11 s 后算得，虚高 8.1% | `firmware/code/README.md:44` |

**同源关系（降级表述）**：0.23% 的差异只能支持“**行为接近**”，不构成“源码/配置/位流同源”的
证明——它是 1 次迭代 vs 400 次迭代的对比，冷启动、Cache 预热、外设初始化比例都不同。
可支持的一点是：**默认构建同镜像为 3,041,345 拍/迭代（3.786×）**，与板测 801,353 相差 3.8 倍，
故交付位流**不可能是默认（三宏全关）构建**；是否恰好等于本仓库源码 + 三个宏，仍属**间接推断**。

## 4. 微程序（机制测量，`tb_uart_run.sv`）

固件 `work/tree/tests/example/microbench/main.c`，256 次迭代/相位（div 相位 32 次），
每相位前后各读一次 cycle CSR，指令数按手写汇编序列精确计数。

日志：`logs/sim_microbench_full.log`、`logs/sim_microbench_base.log`

| 相位（每迭代指令数） | 全功能 cycles/条 | 默认 cycles/条 | 全功能每迭代拍数 |
|---|---|---|---|
| alu_independent（10，8 条独立 addi） | **2.03** | 8.80 | 5,192 / 256 |
| alu_dependent（10，8 条依赖 addi） | **2.02** | 8.80 | 5,161 / 256 |
| load_independent（11，8 条独立 lw） | **3.20** | 11.64 | 9,020 / 256 |
| load_dependent（9，8 条地址自依赖 lw） | **3.79** | 13.34 | 8,733 / 256 |
| store（11，8 条 sw） | **9.02** | 10.91 | 25,400 / 256 |
| branch_taken（3，循环分支必跳） | **2.05** | 10.68 | 1,576 / 256 |
| branch_alternating（5，交替分支） | **2.43** | 9.61 | 3,113 / 256 |
| mul_dependent（10，8 条依赖 mul） | **2.02** | 8.80 | 5,159 / 256 |
| div_dependent（6，4 条依赖 div） | **24.38** | 26.92 | 4,682 / 32 |

从微程序读出的机制：

1. **直线 ALU 代码只有 0.49 IPC**（2.03 拍/条），且**依赖链与独立链完全一样**（2.02 vs 2.03）
   ⇒ 瓶颈不在执行单元，而在取指供给：I-Cache 命中稳态 2 拍/条，与区间内
   `IGAP gap=2 占 88.0%`、`ILAT hit=1` 互相印证。
2. **不开 I-Cache 时直线代码 8.80 拍/条**（每次取指一次 AXI 读，无重叠），
   Cache 把取指代价降到 1/4.3。
3. **store 9.02 拍/条**（CoreMark 里实测 11.16 拍/笔，因为多了 D-Cache 状态机开销）：
   每个 store 都阻塞等写响应（`WRITE_WAIT` 占 7.16 拍/笔），是本轮最大的单笔可优化项。
4. **load 命中 3 拍/条**（LLAT lat=3），依赖链 3.79 拍/条（load-use 再加 1 拍）。
5. **mul 1 拍流水**（依赖链仍是 2.02 拍/条 = 取指受限）；**div 约 35 拍/次**
   （24.38 拍/条 ÷ 6 条/迭代 ≈ 146 拍/迭代 ÷ 4 次 ≈ 36.5 拍/次），但在本次 performance 镜像
   的区间内 `mdiv=0`，对总分无影响。
6. **分支**：可预测循环分支 2.05 拍/条（与直线同）；交替分支 2.43 拍/条，
   256 次迭代里约 128 次错预测、多花 489 拍 ⇒ **错预测重定向代价约 3.8 拍**
   （目标在 I-Cache 命中时），与 `REC lat=5 占 74.1%` 一致。

## 5. 复现命令（完整命令见 `results/commands.md`）
