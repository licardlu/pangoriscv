# Phase-1 前端优化 · 测试与报告核验（验收证据）

生成：2026-10-17 23:40（Asia/Shanghai）
核验者：phase1-tests（测试核验子代理）
对象：候选树 `$AUDIT\frontend_opt\src`（= 交付版 RTL + I-Cache「同拍收旧发新」+ IFU「同拍发射、单笔在途、接口不变」）
基线树：`$AUDIT\baseline_build\src`（= 交付版 RTL）
审计区：`$AUDIT = E:\file\pango\project\evidence\records\bottleneck_audit`
本文件只写测试/报告核验结论；未改 `firmware\code`、未改既有证据文件、未写 Lead 负责的三份文档、未碰 PDS/位流/串口。

## 0. 结论摘要

| # | 核验项 | 结论 | 一句话 |
|---|---|---|---|
| 1 | A/B 镜像标签（performance vs validation 不混用） | **PASS** | `cand/base_cm1.log` = performance 镜像，`cand/base_cmval_v3b.log` = validation 镜像，命令行 `+PROG/+DATA` 路径可逐字核对；sha256 见 §1 |
| 2 | 计时窗口（CPU 周期、排除串口） | **PASS** | CoreMark `start_time/stop_time` = RV32 `mcycle` 64 位读；`Total ticks = t1-t0`；报告打印在 `stop_time()` 之后，不计入窗口；§2 有源码行号 |
| 3 | 固件/镜像/宏一致性 | **PASS（附 3 条 GAP）** | 候选树与 `work/tree` 的 4 个 hex 逐字节相同、manifest `cpu_hz=27000000/iterations=1` 相同；宏全开有 `+define` 编译命令+probe 证据；但 A/B 旧日志无编译命令、PERF 宏两侧不完全同构，交付树宏仍是注释态（G3/G4/G5） |
| 4 | 正确性辅助证据（五 CRC / retires） | **PASS（附订正）** | 五 CRC 与 EEMBC known 值逐项相同、无 `[0]ERROR!`；仿真日志打印 `Errors detected` 的唯一原因是 1 iter<10 s 规则（`core_main.c:298-301`），**不是** CRC 错。T4 §6 line 111「两侧均打印 Correct operation validated」对 sim 日志不成立（板级日志成立） |
| 5 | 专项 a–h 覆盖 + 补测 | **PASS** | 8 条全部有 TB 检查点、日志与关键输出行；新增 3 个定向 TB（INVALIDATE_BP / PAIR_REDIRECT / DEFINES_PROBE），全部 PASS；映射见 §5 |
| 6 | 旧回归（11 套件 + isa_e2e + halt_reset），对应改动后 RTL | **FAIL（2 项）→ 需 Lead 决策** | 10/11 套件 PASS（合计 154 个用例）；`run_pipeline_tests.py` 在当前宏全开配置下 **COMMAND_FAIL**（套件配置问题，已用全源清单替代 PASS）；`tools/run_isa_e2e.py` **14/15**，`case 7 mcycle/minstret counters` FAIL（真问题，§6.2）；halt/reset **5/5 PASS** |

> 验收建议：测试证据本身完整；**唯一刚性阻塞是 isa_e2e case 7 在候选 PDS 配置（CACHE_ENABLE=ON）下失败**。该失败可复现、可归因（CACHE-only 也失败，PREDICT-only/全关/基线全开均通过，core RTL 逐字节未改），建议 Lead 决定「修 core CSR 读写旁路 / 降级为已知限制（比赛软件不写 mcycle）」。其余为文档订正/环境性缺口，见 §7。

---

## 1. 标签核验：哪份日志 = 哪个镜像 = 多少 cycles

### 1.1 日志 ↔ 镜像（`$AUDIT\frontend_opt\ab\`，共 14 个 log）

| 日志 | 镜像（命令行 `+PROG/+DATA`，可逐字核对） | TB / `+MAX_CYCLES` | 结论数字 |
|---|---|---|---|
| `cand_cm1.log` / `base_cm1.log` | `$AUDIT\frontend_opt\src\build\native_software\coremark\performance\{program,data}.hex` | `tb_coremark_audit_v2` / 4,000,000 | performance A/B |
| `cand_cmval_v3b.log` / `base_cmval_v3b.log` | `$AUDIT\frontend_opt\src\build\native_software\coremark\validation\{program,data}.hex` | `tb_coremark_audit_v3` / 5,000,000 | validation A/B |

证据（`# vsim ...` 行，日志第 1~2 行）：
- `cand_cm1.log`：`# vsim -c -voptargs="+acc" tb_coremark_audit_v2 "+PROG=...\coremark\performance\program.hex" "+DATA=...\coremark\performance\data.hex" "+MAX_CYCLES=4000000"`
- `base_cm1.log`：同上，仅日志名不同。
- `cand_cmval_v3b.log` / `base_cmval_v3b.log`：`+PROG/+DATA=...\coremark\validation\...`，`+MAX_CYCLES=5000000`。

> 注意：`commands.md` §3.7（lines 240-243）写的是 `+PROG=$audit\work\tree\...` 且 `-work ab2_$k`，实际日志记录的是 `frontend_opt\src` 镜像、默认 `work` 库。两处镜像 **逐字节相同**（§3.1），因此不影响数字；但文档与实操不一致，建议 Lead 订正（G4）。

### 1.2 数字（原始行）

| 指标 | 基线 `base_cm1.log` | 候选 `cand_cm1.log` | 基线 `base_cmval_v3b.log` | 候选 `cand_cmval_v3b.log` |
|---|---|---|---|---|
| `AUDIT_START cycle=` | 57479 | 54810 | 58212 | 55483 |
| `AUDIT_STOP cycle=` / `delta=` | 860709 / **803230** | 756310 / **701500** | 862845 / **804633** | 757714 / **702231** |
| `CPM_TICKS hi/lo` | —（v2 无） | — | `hi=0 lo=862844` | `hi=0 lo=757713` |
| 固件 `Total ticks` | —（v2 窗口短未解到） | — | **804633** | **702231** |
| `AUDIT_INT cycles/retires/ipc` | 803230 / 305069 / 0.379803 | 701500 / 305069 / 0.434881 | 804633 / 305505 / 0.379682 | 702231 / 305505 / 0.435049 |
| TB 结束行 | `TEST_FAIL T_COREMARK_AUDIT_V2 retires=331551 cycles=891709` | `TEST_FAIL ... retires=331553 cycles=787310` | `TEST_PASS T_COREMARK_AUDIT_V3 retires=857437 cycles=2471714` | `TEST_PASS ... retires=860219 cycles=2361845` |
| 五 CRC | — | — | `seedcrc 0x18f2 / crclist 0xe3c1 / crcmatrix 0x0747 / crcstate 0x8d84 / crcfinal 0xe3c1` + `Errors detected` | 同上五值 + `Errors detected` |

- `cand_cm1/base_cm1` 的 `TEST_FAIL` **不是正确性失败**：v2 TB 的终止 fork 在 `have_stop` 后只 `repeat(30000)` 拍（`tb/integration/tb_coremark_audit_v2.sv:409-420`），而 UART 报告约需 235k 拍，故 `report_seen=0`、`chars=12`。v2 是**性能专用窗口**，正确性证据看 v3b 与板级日志。
- T4 §6 表中 performance 803,230→701,500、retires 305,069 两侧相同，数据源为 `AUDIT_STOP delta` / `AUDIT_INT`；validation 804,633→702,231、retires 305,505 两侧相同，数据源为固件 `Total ticks` / `AUDIT_INT`。**数字与日志一致。**
- 交叉校验：`CPM_TICKS.lo − Total ticks` = 862844−804633=58211（base，TB `AUDIT_START=58212`）、757713−702231=55482（cand，TB=55483）——差 1 拍来自 TB 在 CSR 读指令 retire 沿采样 vs 固件计数器读数，**证明 `Total ticks` 就是 mcycle 差值**（见 §2）。

### 1.3 未混用结论

performance 与 validation 两组日志的 `+PROG/+DATA` 路径不同且与各自 TB 的用途一致（T4 §6 表行对应 v2/v3 两套 TB），**未发现 performance 日志引用 validation 镜像或反之**。旧命名 `cand_cm3.log`（`commands.md:258`）**不存在**，实际为 `cand_cm1.log`（全盘 `*cm3*` 无结果）。

---

## 2. 计时窗口核验（源码行号）

镜像源码在 `$AUDIT\frontend_opt\src\tests\example`（与两棵树逐字节相同，§3.3）：

| 位置 | 内容 | 结论 |
|---|---|---|
| `coremark\core_portme.c:29` | `static CORE_TICKS t0, t1;` | 全局 64 位 tick |
| `coremark\core_portme.c:31-34` | `void start_time(void){ t0 = get_cycle_value(); }` | 窗口起点=CPU 周期读 |
| `coremark\core_portme.c:36-46` | `void stop_time(void){ t1 = get_cycle_value(); ee_printf("CPM_TICKS hi=%lu lo=%lu\n", t1>>32, t1&0xffffffff); }` | 窗口终点=CPU 周期读；全 64 位原始值入日志 |
| `coremark\core_portme.c:48-51` | `CORE_TICKS get_time(void){ return t1 - t0; }` | **Total ticks = stop−start** |
| `lib\utils.c:7-16` | `uint64_t get_cycle_value(void){ do{ high=read_csr(cycleh); low=read_csr(cycle); high_after=read_csr(cycleh);}while(high!=high_after); return ((uint64_t)high<<32)\|low; }` | RV32 `mcycle/mcycleh`（`cycle/cycleh` 为 0xC00/0xC80 只读别名） |
| `include\utils.h:21-23` | `read_csr` = `asm volatile("csrr %0, " #reg ...)` | CSR 读宏 |
| `coremark\core_main.c:215,231,232` | `start_time(); ... iterate(...); stop_time(); total_time=get_time();` | 计时窗口只包 `iterate()`（CoreMark 负载） |
| `coremark\core_main.c:288` | `ee_printf("Total ticks      : %lu\n",(ee_u32)total_time);` | 打印发生在 `stop_time()` 之后；**注意 (ee_u32) 截断**，>2^32 拍必须读 `CPM_TICKS` 行或硬件 ILA |
| `coremark\core_main.c:287-344` | 全部报告（Size/Total time/Iterations/CRC/结尾判断） | 均在 `stop_time()` 之后打印 → 串口打印**不计入**计时 |

补充：首次 `start_time/stop_time`（`core_main.c:203,205`）只用于 1 秒自动标定，不进入报告数字。
单位校验：`time_in_secs = ticks / CPU_FREQ_HZ`，`CPU_FREQ_HZ=27000000`（`core_portme.h` / `utils.h`，与 manifest `cpu_hz` 一致）→ tick 即 **CPU 周期**（mcycle，且只读别名不可写）。
**结论：PASS。** 计时窗口 = 纯 CoreMark 负载，单位 CPU 周期，不含串口打印。

---

## 3. 固件一致核验

### 3.1 镜像 sha256（`Get-FileHash -Algorithm SHA256`，已复核）

| 文件 | work/tree | frontend_opt/src | baseline_build/src |
|---|---|---|---|
| perf/`program.hex` | `65923D5D…D707225` | 同左 | `4AD7DE6B…E82EC6`（400 iter） |
| perf/`data.hex` | `1BA057B3…A2383A5` | 同左 | `6FFD4571…CA06298`（400 iter） |
| val/`program.hex` | `28EB87E4…33E2090` | 同左 | **目录不存在** |
| val/`data.hex` | `BC474B72…9B3509` | 同左 | **目录不存在** |

- **候选树 = `work/tree` 逐字节相同（4/4）**；`baseline_build/src` 只有 400 iter performance 镜像，**没有 validation 目录**。T4 §6 标题「两棵树逐字节相同的 program.hex/data.hex」措辞不准（G2）：逐字节相同的是 `work/tree` 与候选树；基线树是 400 iter 的另一份镜像（T4 §8 PDS 用的正是这份，见 §3.4）。
- manifest（UTF-8 BOM JSON）：`work/tree` 与候选树 performance/validation 均 `"mode": "performance"/"validation"`、`"iterations": 1`、`"cpu_hz": 27000000`；基线 perf `iterations: 400`（`-DPERFORMANCE_RUN=1`）、`cpu_hz: 27000000`。

### 3.2 manifest ↔ hex 对应

各 manifest 的 `artifact_sha256.program.hex/data.hex` 与上表实测 sha 逐项相同；候选树与 work/tree 的 `source_sha256`（19~29 个固件源文件）逐项相同 → 同源、同参数、同镜像。

### 3.3 固件源码一致性

`tests/example/coremark/core_main.c`、`core_portme.c`、`lib/utils.c` 实测 sha 在 baseline/candidate 两树完全相同（如 core_main.c `BAFCC71C…6091F`）；`source_sha256` 表亦相同。**固件源码无差异。**

### 3.4 三宏 +define 证据（CACHE_ENABLE / PREDICT_ENABLE / PERF_ENABLE）

- 候选树 `rtl/core/soc_config.vh:34-36` 三行均已取消注释 = ON，文件 sha256 `BD9A2677…85AE2D`；基线树同文件同 sha（也 ON）。
- **`work/tree` 与交付树 `firmware\code\rtl\core\soc_config.vh` 同 sha `5EAB5871…F44547`（三行仍为注释 = 默认 OFF）** → 交付树与 T4 验证/PDS 配置的宏状态不同（G5）。
- 本次核验编译命令（`phase1_logs\02_vlog_contract_tbs.log` 第 3 行，逐字）：
  `vlog -sv -work phase1_wl "+define+CACHE_ENABLE" "+define+PREDICT_ENABLE" "+define+PERF_ENABLE" "+incdir+rtl/core" "+incdir+rtl/perips" -f sim/native_axi_sources.f tb/unit/tb_icache_contract.sv tb/unit/tb_ifu_contract.sv tb/unit/tb_ifu_axi.sv`
  追加 TB 命令（`phase1_logs\03_vlog_phase1_ext_cmd.txt`）：
  `vlog -sv -work phase1_wl +define+CACHE_ENABLE +define+PREDICT_ENABLE +define+PERF_ENABLE +incdir+rtl/core +incdir+rtl/perips tb/unit/tb_icache_invalidate_bp.sv tb/unit/tb_ifu_pair_redirect.sv tb/unit/tb_defines_probe.sv`
- 宏生效实证（`phase1_logs\13_cand_phase1_wl_tb_defines_probe.log:20-23`）：
  `DEFINE CACHE_ENABLE=ON` / `DEFINE PREDICT_ENABLE=ON` / `DEFINE PERF_ENABLE=ON` / `TEST_PASS DEFINES_PROBE`
- 宏在 RTL 中确有分支：`rtl/core/pangoriscv.v:91-92`（PREDICT_ENABLE→`branch_predictor`）、候选 `rtl/core/pangoriscv_axi_top.v:17,169` 与 `rtl/soc/pangoriscv_axi_soc.v:108-127`（PERF_ENABLE→`perf_regs`）。

**GAP（G3，A/B 旧日志宏一致性）**：A/B 的 vsim 日志**不记录 vlog 命令/define**，只能间接推断：
- 两侧均 `Loading work.branch_predictor` + `Loading work.icache_axi`（`base/cand_cmval_v3b.log:24,38-41`）→ CACHE/PREDICT 均 ON；
- **只有 base_* 日志加载 `work.perf_regs`**（`base_cm1.log:56`、`base_cmval_v3b.log:58`），cand_* 系列全部没有 → 候选侧 A/B 库应在 PERF_ENABLE=OFF 下编译。
- 影响评估：`PERF_ENABLE` 仅把只读计数器 `perf_regs` 挂到互联（从设备，无主设备/无背压，`pangoriscv_axi_soc.v:108-127`、`pangoriscv_axi_top.v:169-177` 仅 assign 观测 tap），不改变流水线控制/数据通路 → **对 cycles 无实质影响**；但严格意义上 A/B 宏配置不完全同构，需在 T4/commands 中如实注记。

**结论：3 PASS（附 G3/G4/G5 三条缺口）。**

---

## 4. 正确性辅助检查

### 4.1 五 CRC / retires / 结尾判定（v3b 日志原文）

`base_cmval_v3b.log` 与 `cand_cmval_v3b.log` 均含：
```
# Total ticks      : 804633   / 702231
# seedcrc          : 0x18f2
# [0]crclist       : 0xe3c1
# [0]crcmatrix     : 0x0747
# [0]crcstate      : 0x8d84
# [0]crcfinal      : 0xe3c1
# Errors detected
```
- 对照 `core_main.c:35-37` 官方 known 表：`crclist[4]=0xe3c1`、`crcmatrix[4]=0x0747`、`crcstate[4]=0x8d84`；seedcrc=0x18f2 即 2K validation 参数组合（`core_main.c:256` 附近注释/已知表选择逻辑）→ **五值逐项与 EEMBC known 值相同**，日志中**没有任何 `[0]ERROR! ... crc` 行**（若有 CRC 错 `core_main.c:268-280` 必打印）。
- **`Errors detected` 的唯一原因是 `core_main.c:298-301`：1 次迭代仿真总时间 0.03 s < 10 s**（`ERROR! Must execute for at least 10 secs for a valid result!` 会先打印——v3b 日志中该行确实存在，`report_seen` 的匹配串为 `Errors detected`）。因此 **T4 §6 line 111「两侧均打印 Correct operation validated」对仿真日志不成立**；正确表述应为「五 CRC 与 EEMBC known 值相同、无 CRC error；因 1 iter<10 s 规则固件打印 Errors detected；**`Correct operation validated` 由 400 iter 板级日志提供**」（见 §4.3）。
- retires：`AUDIT_INT retires` 两侧相同（perf 305,069/305,069；validation 305,505/305,505），**仅作辅助**：retires 相同说明「没有少算/多算工作」，但相同 retire 数不排除「换了错误指令流仍凑出相同条数」（理论上）。真正的功能 oracle 是 §4.1 的 CRC 三元组 + `check_data_types()`（`core_main.c:285`）+ 结尾校验，因此不把 retires 当唯一证明。

### 4.2 还能用的辅助证据（已确认可用）

1. **2K performance 参数指纹**：`CoreMark Size : 666`（=`core_main.c:36-37` 的 2K 参数集大小，B/C 日志相同）、`Iterations : 1`、`Compiler version : GCC7.1.1 20170509`、`Memory location : STATIC`、`seedcrc 0x18f2`（`base/cand_cmval_v3b.log`）。这四个字段 + seedcrc 构成「同一 2K 参数集 + 同一编译产物」的可复核指纹。
2. **`AUDIT_INT` 分项守恒断言**（tb v3 :448-466）：`AUDIT_INT_CLASS` 的 `sum=701500 vs cycles=701500`（cand）/ `sum=803230 vs cycles=803230`（base），以及 `AUDIT_INT_LSU_PHASE`/`FE_IDLE` 分项和断言；任何流水线计数不自洽会 `$fatal`。两侧均无 `$fatal`，说明「周期分解」与总窗口自洽。
3. **访存/总线计数互证**：`AUDIT_INT_MEM load/store` 两侧相同（55823/15687 perf；56227/15560 validation），`AUDIT_INT_CACHE` i-cache miss 421→423、d-cache miss 92→97（±5，来自 redirect/时序微差），与 `AUDIT_INT_AXI` 的 ar/r 计数一致（如 ar=421, r=3368 = 421×8 beat）。
4. **板级 400 iter 日志（最强正确性证据，真机）**：`$AUDIT\results\board_uart_baseline.txt` / `board_uart_candidate.txt` / `board_uart_delivered_bitstream.txt` 均为
   `seedcrc 0xe9f5 / crclist 0xe714 / crcmatrix 0x1fd7 / crcstate 0x8e3a / crcfinal 0x25b5` + **`Correct operation validated. See readme.txt for run and reporting rules.`**
   对照 `core_main.c:35-37` 的 known_id=3（400 iter performance 组合）：`0xe714/0x1fd7/0x8e3a` 逐项相同；candidate 与 baseline/delivered **同一 CRC 五元组** → 真机功能等价。
5. **seedcrc 本身**：seedcrc 是 CoreMark 校验数据生成的种子指纹，相同 seedcrc + 相同五 CRC 才能排除「跑错数据集」。

### 4.3 结论

正确性证据链完整：仿真（1 iter validation：五 CRC 对 known 值 + 无 CRC error 行 + `check_data_types` + 无 trap/fault）→ 板级（400 iter performance：五 CRC 对 known_id=3 + `Correct operation validated`）→ 两侧（baseline/candidate/delivered）CRC 五元组一致。**retires 相同只作为「工作量未减少」的辅证，不作为唯一正确性证明。**
**结论：4 PASS（需订正 T4 §6 line 111 措辞）。**

---

## 5. 专项测试映射与补测（a–h）

### 5.1 运行环境

- 干净库：候选树根 `vlib phase1_wl`（相对名；cwd=候选树根，避免 `vopt-2253`），编译命令见 §3.4；环境 `$env:PATH='E:\donwload\win64;'+$env:PATH`（ModelSim SE-64 10.6e）。
- 新日志目录：`$AUDIT\frontend_opt\phase1_logs\`；本报告所有 TB 结论均来自该目录日志。
- 原有契约 TB 首次在候选树重跑（T4 轮次 `ab/` 目录**没有**契约 TB 日志，属证据缺口，本次补齐）。

### 5.2 映射表（a–h → TB 检查点 → 日志/关键行）

| 需求 | 覆盖 TB / 检查点（文件:行） | 关键输出（日志） |
|---|---|---|
| a) 响应背压与稳定（valid/data 背压下保持） | 新增 `tb/unit/tb_icache_invalidate_bp.sv:7-10` A1（LFSR 随机 rsp_ready，held 时 `A1_DATA_MOVED_WHILE_HELD`/`A1_VALID_DROPPED` 检查 + C3 配对 monitor 全程开）；`tb_icache_contract.sv:16` C5（rsp_ready=0 保持 4 拍）；`tb_ifu_contract.sv:12` C5（fetch_ready=0 时 head/result 稳定） | `14_…tb_icache_invalidate_bp.log:21` `TEST_PASS ICACHE_INVALIDATE_BP accepts=290 rsp=290 bursts=4 bp_cycles=122`（`INFO A1 accepts=278 rsp=279 bursts=1 bp_cycles=122`）；`10_…tb_icache_contract.log:20` `TEST_PASS ICACHE_CONTRACT accepts=20 rsp=27 bursts=5`；`11_…tb_ifu_contract.log:22` `TEST_PASS IFU_CONTRACT delivered=187 same_cycle=192 max_count=8` |
| b) 同拍收旧发新时 PC/预测信息配对 | `tb_icache_contract.sv:12` C1（上一笔 rsp 在走、同拍 accept 命中）+ C3（accept 沿捕获期望字，响应配对，`:127-129`）；`tb_ifu_contract.sv:9,10` C2/C3（queue 项携带请求 PC/pred；`encode(a)={16'h0,a[15:2],2'b00}` 回显）+ same_cycle 计数；新增 `tb_ifu_pair_redirect.sv:7-11` T1 + C3 配对 monitor（inst=pc+0x00100093、pred=pred(pc)） | `10_…log:20`（C1/C3 同拍 accept 20 次、27 响应无错配对）；`11_…log:22` `same_cycle=192`（同拍收旧发新 192 次）；`15_…tb_ifu_pair_redirect.log:27` `TEST_PASS IFU_PAIR_REDIRECT delivered=488 same_cycle=39 reqs=41 faults=0` |
| c) hit→miss→hit | `tb_icache_contract.sv:15,244-258` C4（预热 0x1000/0x1020；0x2000 miss 必须 `bursts+1`；随后 0x2004 hit 数据正确）；新增 `tb_icache_invalidate_bp.sv:11-13` A2（invalidate 后重读必须重新 burst） | `10_…log:20` bursts=5（4 次预期 miss+1 次 invalidate 后重取）；`14_…log:21` bursts=4 |
| d) 队列满/空与槽位预留 | `tb_ifu_contract.sv:13` C6（A1：fill 到 DEPTH=8 且 `max_count=8`、不超 8）；`tb_ifu_axi.sv:66-80,139-142`（T1：恰好填满 8 项后停发、drain 8 项、`count_q<=DEPTH` 断言、reqs==answered）；新增 `tb_ifu_pair_redirect.sv:22-24` T5 | `11_…log:22` `max_count=8`；`12_…tb_ifu_axi.log:20` `TEST_PASS IFU_QUEUE reqs=22 answered=22 delivered=13`；`15_…log:27` faults=0 |
| e) redirect 与旧响应同拍 | `tb_ifu_contract.sv:14,207-214` C7（stall 下 fill queue→redirect→旧流不得再交付，resume 新 PC）；新增 `tb_ifu_pair_redirect.sv:12-18` T2a（redirect 同拍旧 rsp handshake）/T2b（in-flight stale redirect）；`tb_ifu_axi.sv` T4（redirect 丢弃队列）；`tb_ifu_contract` 的 redirect 检查 | `15_…log:27` `delivered=488 same_cycle=39 faults=0`（T2a/T2b/T3b 全过）；`11_…log:22` same_cycle=192；`12_…log:20` answered=reqs |
| f) 错误路径取指异常抑制 | `tb_ifu_contract.sv:14,235-243` C7（fault 指令交付后 `reqs==0`，年轻请求不得发出）；`tb_ifu_axi.sv` T5（non-executable 0x20000000 → fault cause 1 且不发起越界请求；misaligned 0x2 → cause 0）；新增 `tb_ifu_pair_redirect.sv:16-19` T3a/T3b（redirect 后旧路径 SLVERR 不得污染新流） | `11_…log:22`（fault 后无年轻请求）；`12_…log:20` answered=reqs、无 `IFU_PREFETCH_DEPTH`/越界 fatal；`15_…log:27` faults=0 |
| g) invalidate 与命中替换/补行交互 | `tb_icache_contract.sv:17,259-288` C7（fill 途中 invalidate → 行不得变 valid → 重读必须重新 burst）；新增 `tb_icache_invalidate_bp.sv:11-16` A2（同拍 hit/replace 流中 invalidate，行失效后重读重新 burst）+ A3（held response 期间 invalidate：已接受的响应仍按序完成，新请求走 miss） | `10_…log:20` bursts=5；`14_…log:21` accepts=290 rsp=290 bursts=4 |
| h) halt/reset 及在途事务排空 | `tb/integration/tb_halt_reset_drain.sv` 5 场景（halt during in-flight read/write、reset during in-flight read/write、reset idle；检查 AXI VALID/payload 稳定、被接受事务必须收到 R/B、halted 后 400 拍无新 VALID、resume PC=arch_next_pc、无 orphan）；`tools/run_halt_reset_tests.py` | `31_reg_halt_reset.log`：5 个 `scenario n: PASS …` + `SUMMARY 5 / 5 PASS` |

### 5.3 新增 TB（候选副本 `$AUDIT\frontend_opt\src\tb\unit\`，未删/未改旧检查）

1. `tb_icache_invalidate_bp.sv` — 需求 a（随机背压）/c/g 补测。A1 LFSR 随机 `rsp_ready`（`bp_cycles=122`），A2 invalidate 与同拍 hit/replace 流，A3 held response + invalidate；全程 C3 配对 + held 稳定性 monitor。**PASS**（`14_…log`）。
2. `tb_ifu_pair_redirect.sv` — 需求 b/e/f/d 补测。T1 持续流 + C3 指令/预测配对；T2a 同拍 redirect+旧响应对齐、T2b in-flight stale redirect；T3a/T3b redirect 后 wrong-path SLVERR 抑制；T4 disable 排空/恢复；T5 队列满/空 + 头部背压。**PASS**（`15_…log`，`delivered=488 same_cycle=39 reqs=41 faults=0`）。
3. `tb_defines_probe.sv` — 三宏 `+define` 生效证明（`13_…log`，`TEST_PASS DEFINES_PROBE`）。

> 修复过程记录（供内审）：新增 TB 首版曾因非 `-sv` 编译时 `output wire [31:0]` 端口成隐式 1 位线（`vopt-2241`）导致 C3 pred 配对失败；改为显式声明后通过。属 TB 工程问题，非 RTL 问题。

**结论：5 PASS。** 8 条需求均有 TB 检查点 + 日志 + 关键输出行；T4 轮次缺失的契约 TB 日志已补齐。

---

## 6. 旧单元测试回归（候选树改动后 RTL）

### 6.1 结果总表

运行方式：cwd=候选树根，`python sim\run_<suite>_tests.py`（PATH 前置 `E:\donwload\win64`），日志 `phase1_logs\20_reg_*.log`；isa_e2e/halt_reset 用 `tools\run_isa_e2e.py` / `tools\run_halt_reset_tests.py`（日志 30/31）。RTL 与基线差异**仅** `rtl/core/icache_axi.v`、`rtl/core/ifu_axi.v` 两个文件（其余 rtl/core 逐字节相同；固件源逐字节相同）。

| 套件 | 结果 | 日志/关键行 |
|---|---|---|
| `run_unit_tests.py` | **5/5 PASS** | `20_reg_unit.log`：pipe_slot/div_adapter/ifu_axi/lsu_axi/icache_axi 各 PASS + `SUMMARY 5 / 5 PASS` |
| `run_engine_tests.py` | **64/64 PASS** | `SUMMARY 64/64 PASS`（read/data × seed/fault，含 hardware 变体） |
| `run_interconnect_tests.py` | **20/20 PASS** | `SUMMARY 20 / 20 PASS` |
| `run_ram_tests.py` | **40/40 PASS** | `SUMMARY 40/40 PASS`（ram 20 + lsu 20） |
| `run_ifu_engine_tests.py` | **20/20 PASS** | `PASS IFU_REAL_ENGINE seed=1..20` + `SUMMARY 20/20 PASS` |
| `run_pipeline_tests.py` | **FAIL（环境/配置性，见 6.2）** | `20_reg_pipeline.log`：`RuntimeError: COMMAND_FAIL: …\.sim_runs\pipeline-_ggmquef\simulation.log` |
| `run_icache_tests.py` | 1/1 PASS | `PASS icache_axi` + `SUMMARY 1/1 PASS` |
| `run_dcache_tests.py` | 1/1 PASS | `PASS dcache_axi` + `SUMMARY 1/1 PASS` |
| `run_predictor_tests.py` | 1/1 PASS | `PASS branch_predictor` + `SUMMARY 1/1 PASS` |
| `run_perf_tests.py` | 1/1 PASS | `PASS perf_regs` + `SUMMARY 1/1 PASS` |
| `run_gpio_trace_tests.py` | 1/1 PASS | `PASS gpio_trace` + `SUMMARY 1/1 PASS` |
| `tools/run_isa_e2e.py` | **14/15 PASS（case 7 FAIL，见 6.3）** | `30_reg_isa_e2e.log`：`case 7 FAIL mcycle/minstret counters / - x2=0 want 1 (mcycleh after wrap)`；`SUMMARY 14 / 15 PASS`；`failing cases: 7` |
| `tools/run_halt_reset_tests.py` | **5/5 PASS** | `31_reg_halt_reset.log`：5 个 `scenario n: PASS …` + `SUMMARY 5 / 5 PASS` |

### 6.2 pipeline 套件失败：环境/配置性（非 RTL 功能 FAIL）

- 根因（`…\.sim_runs\pipeline-_ggmquef\simulation.log` 原文）：
  `# ** Error: …/rtl/core/pangoriscv.v(92): Module 'branch_predictor' is not defined.` → `Error loading design`
- 机理：当前候选树 `rtl/core/soc_config.vh:34-36` 宏全开（PDS 配置），`pangoriscv.v:91-92` 在 `PREDICT_ENABLE` 下例化 `branch_predictor`；但 `sim/run_pipeline_tests.py:12-16` 的源清单是固定 13 个 core 文件（不含 `branch_predictor.v`），编译 `compile.log` 0 error，vsim 加载时才报缺模块。**即该套件按「默认宏关」的交付树配置设计**，与 T4 §5「改动后 RTL 两轮 11 套件 0 fail」的结论口径不一致（那两轮应是在宏注释态跑的）。
- 替代证据（同 RTL、宏全开、全源清单）：`phase1_wl` 用 `-f sim/native_axi_sources.f` + 三 `+define` 编译同一 `tb/unit/tb_pipeline.sv`，日志 `16_cand_phase1_wl_tb_pipeline.log:64`：`TEST_PASS N03_PIPELINE retires=29 traps=9 operations=5`。→ **pipeline 功能本身在宏全开配置下 PASS；失败仅为 runner 编译清单未适配合法宏配置。**
- 建议：修 `sim/run_pipeline_tests.py` 源清单（按 `soc_config.vh`/define 条件加入 `branch_predictor.v` 等）或在宏全开时改用 `-f native_axi_sources.f`；Lead 可将其记为 GAP（G1），不计入 RTL FAIL。

### 6.3 isa_e2e case 7 FAIL：真问题（候选 PDS 配置下 CSR 读写时序）

现象（`30_reg_isa_e2e.log`）：`case 7 FAIL mcycle/minstret counters - x2=0 want 1 (mcycleh after wrap)`。

归因实验（全部为干净 work 库复跑，日志在 `phase1_logs\`）：

| 配置 | case 7 结果 | 日志 |
|---|---|---|
| 基线树 + 宏全开（ON） | **PASS** | `40_base_on_isa_e2e_case7.log` |
| 候选树 + 宏全关（OFF） | **PASS（且全部 15/15 PASS）** | `41_cand_off_isa_e2e_all.log` |
| 候选树 + 宏全开（ON） | **FAIL** | `30_reg_isa_e2e.log` |
| 候选树 + 只开 CACHE_ENABLE | **FAIL** | `42_cand_on_cache_only_case7.log` |
| 候选树 + 只开 PREDICT_ENABLE | **PASS** | `43_cand_on_predict_only_case7.log` |

- 两树 `rtl/core` 其余文件（含 `id.v`、`csr_native.v`、`pangoriscv.v`、`retire_ctrl.v`）**逐字节相同**，仅 `icache_axi.v`/`ifu_axi.v` 改动 → 失败由「更快的取指时序」暴露 core 既有 CSR 时序问题，而非新增逻辑算错。
- 机理（RTL 行号）：CSR 读在 **ID 级组合**完成（`id.v:319 csr_rdata_o = csr_rdata_i;`，`id.v:343-346 csr_raddr_o` 来自 ID 级），`csr_rdata_i` 接 `csr_native.read_data`（`pangoriscv.v:141-147`，`read_data` 为组合输出，`csr_native.v:45-46` 直接输出 `mcycle` 当前值）；而 CSR **写**只在 retire 的时钟沿提交（`pangoriscv.v:142 .commit(retire_fire && csr_intent)`；`csr_native.v:57-58,67-68` 计算 `ncy/ni`；`:82` 在 posedge 写入）。当「写高半 `csrw mcycleh`」与「紧随的读 `csrr x2, mcycleh` 处于 ID 级」落在同一拍时，读拿到提交前的旧值（0）。基线/候选 OFF 的取指气泡恰好错开一拍，故通过；候选 I-Cache 命中把两条指令压到背靠背 → 失败。
- 风险与建议：CoreMark 固件只读 `mcycle`（`utils.c:11-13`），不写，**竞赛软件路径不受影响**；但「候选 PDS 配置 = 全宏开」的比特流若作为最终交付，则 `tools/run_isa_e2e.py` 不能宣称 15/15。建议二选一：(i) core 增加 CSR 读/写旁路（ID 读到同拍 retire 的 CSR 写时用 `write_data` 前递，涉及 `csr_native.v`/`pangoriscv.v`，**改动超出前端优化范围，需 Lead 决策**）；(ii) 明确记录为已知限制 + 说明比赛软件不触发，并在 T4/验收文档中把回归口径改为「宏全开：14/15（case7 已知限制）；宏全关：15/15」。

**结论：6 FAIL（pipeline 套件配置性失败 → 有等价替代 PASS；isa_e2e case7 真失败）。**

---

## 7. 缺口清单 / 对 Lead 文档的订正建议

| ID | 类型 | 内容与证据 | 建议 |
|---|---|---|---|
| G1 | 真失败 | `tools/run_isa_e2e.py` 在候选 PDS 配置（CACHE_ENABLE=ON）下 case7 FAIL（§6.3 归因矩阵） | Lead 决策：修 core CSR 前递，或降级为已知限制并在验收文档写明 |
| G2 | 文档口径 | T4 §6 标题「两棵树逐字节相同的 program.hex/data.hex」→ 实际仅 `work/tree` 与 `frontend_opt/src` 相同；`baseline_build/src` 是不含 validation 的 400 iter 镜像（§3.1） | 改写为「work/tree 与候选树逐字节相同；baseline 为 400 iter PDS 镜像」 |
| G3 | 文档订正 | T4 §6 line 111「两侧均打印 Correct operation validated」→ sim v3b 两份日志实际打印 `Errors detected`（原因 `core_main.c:298-301` <10 s 规则；五 CRC 均对）；`Correct operation validated` 见于板级日志（§4.1/4.2） | 改为「五 CRC 与 known 值相同、无 CRC error；sim 因 <10 s 规则打印 Errors detected；板级 400 iter 打印 Correct operation validated」 |
| G4 | 文档/证据 | `commands.md:257` 引用的 `cand_cm3.log` 不存在（实际 `cand_cm1.log`）；§3.7 lines 240-243 命令写 `+PROG=work/tree…`、`-work ab2_$k`，实际日志为 `frontend_opt/src` 镜像 + 默认 work 库；A/B 日志未保存 vlog/define 行 | 更正文件名/路径；补存 A/B 编译命令或在日志头部记录 define |
| G5 | 配置一致性 | A/B 宏不完全同构：base_* 日志加载 `work.perf_regs`（`base_cm1.log:56`、`base_cmval_v3b.log:58`），cand_* 全部未加载 → 候选侧 PERF_ENABLE=OFF（§3.4）；perf_regs 仅只读计数从设备，不影响周期 | 在 T4 注明「PERF_ENABLE 差异，对 cycles 无影响」或重跑一侧对齐 |
| G6 | 交付树差异 | `firmware\code\rtl\core\soc_config.vh` = 注释态（sha `5EAB…`），候选/PDS 树 = 全开（sha `BD9A…`）→ 正式交付树源与「验证/综合用的宏配置」不一致 | 交付时明确 bitstream 的宏配置来源（T4 §3.8 已描述 PDS 前手动开宏，建议写入交付说明） |
| G7 | 证据缺口（已补） | T4 轮次 `frontend_opt/ab/` 无契约 TB 日志（只有 CoreMark A/B） | 本次已在 `phase1_logs` 补齐；建议 T4 §5 引用本报告 §5 |
| G8 | 文档口径 | T4 §5「两轮 11 套件 0 fail / isa_e2e 15/15」只在宏关配置可复现；宏全开时 pipeline 套件配置性失败、isa_e2e 14/15 | 按配置分别列结果（见 G1/G2 的表述） |
| G9 | 证据缺口 | v2 性能 TB 的 `TEST_FAIL`（`report_seen=0`）若被误读为正确性失败 | T4/commands 已注明 v2 是性能窗口；建议验收文档再次强调 |

---

## 8. 本次产出与改动文件

**新增（本报告）**
- `$AUDIT\results\phase1_test_acceptance.md`（本文件）

**新增日志（`$AUDIT\frontend_opt\phase1_logs\`，共 40 个文件，均为本次重跑）**
- 编译/探针：`00_steps_summary.txt`、`01_vlib_phase1_wl.log`、`02_vlog_contract_tbs.log`、`03_vlog_phase1_ext(.log/_cmd.txt)`、`03_rc.txt`、`04~09` 修复编译日志
- 契约/专项 TB：`10_cand_phase1_wl_tb_icache_contract.log`、`11_…tb_ifu_contract.log`、`12_…tb_ifu_axi.log`、`13_…tb_defines_probe.log`、`14_…tb_icache_invalidate_bp.log`、`15_…tb_ifu_pair_redirect.log`、`16_…tb_pipeline.log`（均含 `.stdout.log`）
- 旧回归：`20_reg_{unit,engine,interconnect,ram,ifu_engine,pipeline,icache,dcache,predictor,perf,gpio_trace}.log`、`30_reg_isa_e2e.log`、`31_reg_halt_reset.log`
- case7 归因：`40_base_on_isa_e2e_case7.log`、`41_cand_off_isa_e2e_all.log`、`42_cand_on_cache_only_case7.log`、`43_cand_on_predict_only_case7.log`

**新增 TB（候选副本 `$AUDIT\frontend_opt\src\tb\unit\`）**
- `tb_icache_invalidate_bp.sv`、`tb_ifu_pair_redirect.sv`、`tb_defines_probe.sv`

**工作区产物（非交付文件）**
- 候选树根 `phase1_wl\`（相对名 ModelSim 库）与 `src\.sim_runs\*`（runner 临时目录）；临时树 `C:\Users\lenovo\AppData\Local\Temp\phase1\{base_on,cand_off}` 及 `run_regression.ps1`（回归驱动脚本）
- **未修改**：`firmware\code`、既有 `results\*.md`、`T4_frontend_results.md`、`commands.md`、`frontend_contract.md`、旧 TB；未运行 PDS/位流/串口。

---

## 9. 复现命令（关键）

```powershell
$env:PATH='E:\donwload\win64;'+$env:PATH
Set-Location 'E:\file\pango\project\evidence\records\bottleneck_audit\frontend_opt\src'
# 1) 干净库 + 全源清单 + 三宏
vlib phase1_wl
vlog -sv -work phase1_wl "+define+CACHE_ENABLE" "+define+PREDICT_ENABLE" "+define+PERF_ENABLE" `
     "+incdir+rtl/core" "+incdir+rtl/perips" -f sim/native_axi_sources.f `
     tb/unit/tb_icache_contract.sv tb/unit/tb_ifu_contract.sv tb/unit/tb_ifu_axi.sv
vlog -sv -work phase1_wl +define+CACHE_ENABLE +define+PREDICT_ENABLE +define+PERF_ENABLE `
     +incdir+rtl/core +incdir+rtl/perips `
     tb/unit/tb_icache_invalidate_bp.sv tb/unit/tb_ifu_pair_redirect.sv tb/unit/tb_defines_probe.sv
# 2) 契约/专项 TB
vsim -c -work phase1_wl tb_icache_contract -do "run -all; quit -f" -l ..\phase1_logs\10_cand_phase1_wl_tb_icache_contract.log
vsim -c -work phase1_wl tb_ifu_contract    -do "run -all; quit -f" -l ..\phase1_logs\11_cand_phase1_wl_tb_ifu_contract.log
vsim -c -work phase1_wl tb_ifu_axi         -do "run -all; quit -f" -l ..\phase1_logs\12_cand_phase1_wl_tb_ifu_axi.log
vsim -c -work phase1_wl tb_defines_probe   -do "run -all; quit -f" -l ..\phase1_logs\13_cand_phase1_wl_tb_defines_probe.log
vsim -c -work phase1_wl tb_icache_invalidate_bp -do "run -all; quit -f" -l ..\phase1_logs\14_cand_phase1_wl_tb_icache_invalidate_bp.log
vsim -c -work phase1_wl tb_ifu_pair_redirect    -do "run -all; quit -f" -l ..\phase1_logs\15_cand_phase1_wl_tb_ifu_pair_redirect.log
# 3) 旧回归
foreach($s in 'unit','engine','interconnect','ram','ifu_engine','pipeline','icache','dcache','predictor','perf','gpio_trace'){ python "sim\run_${s}_tests.py" *> "..\phase1_logs\20_reg_$s.log" }
python tools\run_isa_e2e.py          *> ..\phase1_logs\30_reg_isa_e2e.log
python tools\run_halt_reset_tests.py *> ..\phase1_logs\31_reg_halt_reset.log
```

## 10. NOT RUN（明确未做）

1. **PDS/综合/布局布线/上板重跑**：按任务约束不碰硬件（不跑 PDS、不下载位流、不占串口）；T4 §8 的后端/板级数据按既有证据引用，未复跑。
2. **A/B CoreMark 长仿真重跑**：A/B 原始日志（`frontend_opt/ab/*.log`）已存在且命令行/镜像/数字可核验，本次只做只读核对，未重跑（重跑 236 万拍≈数分钟/次，非必需）。
3. **第二轮独立干净库全套回归**：T4 §5 声称跑过两轮；本次只跑一轮（§6.1）。因 case7 是确定性可复现失败，复跑第二轮不改变结论，未重复。
4. **`firmware\code` 交付树仿真**：交付树无 `build/native_software` 镜像、且宏为注释态；核验在候选/基线审计树完成。
