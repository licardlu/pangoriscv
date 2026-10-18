# 阶段 1-B：PDS 证据核验（前端优化候选 vs 基线）

日期：2026-10-17
对应指令：m02813 第三节 B（完成 PDS，核实真正生效的配置，不只看命令行）

## 1. 结论

- 候选设计（前端优化后）已完成综合、布局布线、时序报告、位流生成，且全部约束满足（`All Constraints Met.`）。
- 已核实：候选 PDS 实际使用的源码 = 候选实验树（逐文件 sha256 相同），与基线树只差 `rtl/core/icache_axi.v` 与 `rtl/core/ifu_axi.v` 两个文件；`soc_config.vh` 两树逐字节相同（三宏均已启用）。
- 已核实：CACHE/PREDICT/PERF 三宏确实进入网表（不是只写在命令行）；INIT_FILE 从流程 CWD 正确解析并装入两份镜像；载入的镜像与基线 400 迭代 performance 镜像逐字节相同。
- 时序四角（Setup/Hold × Slow/Fast）+ Recovery/Removal/脉冲宽度均满足，0 条未约束路径报告。
- 首次候选布线出现 hold −0.036 ns（3 个端点）；通过只**增加 hold 修复力度**（阈值 0→100 ps、迭代 50→100）收敛，未放宽任何约束、未降频。

## 2. 设计身份与配置证据

### 2.1 源码身份

| 对象 | 证据 |
|---|---|
| 候选实验树 | `$AUDIT\frontend_opt\src`（$AUDIT = `E:\file\pango\project\evidence\records\bottleneck_audit`） |
| PDS 实际源码副本 | 流程目录 `$AUDIT\frontend_opt\src\build\pango_native\sources\rtl` |
| 副本 = 候选树？ | 逐文件 sha256 比较，**差异数 0**（含 `core/icache_axi`、`core/ifu_axi`、`core/soc_config`） |
| 候选 vs 基线树（仅 rtl） | 只差 `rtl\core\icache_axi.v`（cand `3F45A38D450B…` vs base `ADDC7A724DF8…`）和 `rtl\core\ifu_axi.v`（cand `222C35AE56AE…` vs base `C7C2C2DCCFEF…`）；其余 rtl 文件全部相同；另有 `soc_config.vh.gitasis` 备份文件仅在候选树（不参与设计） |
| 开宏后的 `soc_config.vh` | 两树相同，sha256 `BD9A2677B58A093AB5BEE6027193BE34B9174C8464FEFBCF2E6957C22585AE2D`（改前三行宏被注释，见 `results/T4_frontend_results.md` §8） |

> 说明：PDS 会把 `.v` 设计文件复制进流程目录的 `sources/` 时改名为 `.sv`，因此按 `sources/rtl/**.sv → 树内同名 .v` 比较；比较结果 0 差异。

### 2.2 宏确实生效（不是“资源规模接近”的推断）

- 综合网表 `synthesize/pangoriscv_top_syn.vm`（39 个 module）中存在实例：
  - `axi_read_engine read_engine (` 第 87045 行
  - `axi_data_engine inner (` 第 95599 行
  - `dcache_axi data_cache (` 第 134012 行
  - `ifu_axi ifu (` 第 134098 行
  - `icache_axi instruction_cache (` 第 134224 行（源位置注释 `pangoriscv_axi_top.sv:77`）
- `compile/run.log` 显示分析时包含 `rtl/core/soc_config.vh`，并逐个分析了 `ifu_axi.sv`、`icache_axi.sv`。
- 若三宏未开，`pangoriscv_axi_top` 会走无 Cache/无预测的直连分支，上述实例不会出现在网表中。
- 旁证：候选/基线 DRAM 用量均为 4.5 块、Distributed RAM 2,685，APM 6（乘法器）——与启用 I/D-Cache + 预测器 + 性能计数器的配置一致。

### 2.3 CWD 与 INIT_FILE

- `pds_shell -file build.tcl -work_dir <流程目录>`；流程目录 = `$AUDIT\frontend_opt\src\build\pango_native`，`build.pds` 中 `prj_work_dir` = `"."`。
- `flow.log` 第 338–354 行：`INIT_FILE = program.hex` / `INIT_FILE = data.hex`，实际解析为流程目录下的绝对路径：
  - `...\build\pango_native\program.hex`
  - `...\build\pango_native\data.hex`
- 即 `INIT_FILE` 是相对路径、按流程目录（CWD）解析，与 `build.tcl` 中“先拷两份镜像到 run_dir 再 cd”的逻辑一致。
- 编译日志中 `Loading memory data from file` 恰好 2 条（`axi_ram.sv:118`），两条路径分别指向程序/数据镜像。

### 2.4 镜像身份（两侧同一固件）

| 镜像 | sha256 | 说明 |
|---|---|---|
| `program.hex`（流程目录内） | `4AD7DE6B14F6954BA3E04B93574713F4619101B3388DEC3CDE13F7B355E82EC6` | = 基线 400 迭代 performance 镜像 |
| `data.hex`（流程目录内） | `6FFD4571DA129E86EEE388AC737C29191BF745BDEB9BB55B262EFF454CA06298` | = 基线同镜像 |

两侧 UART 输出打印的编译参数也逐字段相同：`-DCPU_FREQ_MHZ=27 -DITERATIONS=400 -DPERFORMANCE_RUN=1`，编译器 `GCC7.1.1 20170509`。

## 3. 工具与流程

| 项 | 值 / 证据 |
|---|---|
| 综合实现工具 | Pango Design Suite（Fabric Compiler version 2022.2-SP6.1 build 138931，安装目录 `E:\donwload\PDS_2022.2-SP6.4\PDS_2022.2-SP6.1`） |
| 流程脚本 | `$AUDIT\frontend_opt\src\platform\pango_native\build.tcl`（候选专用副本）；`impl.tcl` 由环境变量生成 |
| 关键环境变量 | `PANGO_NATIVE_REPO`=候选 `src`；`PANGO_NATIVE_BOARD_DIR`=候选 `platform`；`NATIVE_IMAGE_DIR`=基线 400 迭代 performance 镜像目录 |
| 器件 | PG2L100H-6FBG676（`constraint_check.ccr`：`Current device : PG2L100H-6FBG676`；板测读到 ID `0x00602899`） |
| 约束文件 | `platform/pango_native/pango_native.fdc`（时钟）、`pango_native.pcf`（引脚） |
| 时钟约束 | `create_clock -name clk -period 37.037 -waveform {0 18.5185} [get_ports {clk}]`（27 MHz 板载晶振，D18） |
| 完整日志 | `run.log` 614,523 B、`flow.log` 601,851 B；归档 `$AUDIT\frontend_opt\pds\run2_hold100\`（sbit、rtr、multiseed、flow.log、pds_stdout.log） |

## 4. 时序结果（全部角）

| 指标 | 基线（`747C18CA…`） | 候选（`DE0F9074…`） |
|---|---|---|
| Design Summary | All Constraints Met. | All Constraints Met. |
| Setup WNS Slow (ns) | 16.262 | 17.131 |
| Setup WNS Fast (ns) | 24.216 | 23.799 |
| Hold WHS Slow (ns) | 0.024 | 0.103 |
| Hold WHS Fast (ns) | 0.014 | 0.069 |
| Recovery / Removal / Min Pulse Width | 见 rtr，全部满足 | 见 rtr，全部满足 |
| 时序端点总数 | 48,478 | 48,478 |
| 估计最高频率 | 48.15 MHz | 50.2361 MHz |

- 候选 slow 角关键路径（`report_timing` 第一条路径）：`soc/core/cpu/u_id_ex/slot/data_q[371] → … → u_ex` 乘法器 APM 级联 → `u_id_ex/slot/data_q[181]`，Slack (MET) 17.131 ns。**前端改动没有成为关键路径**，缓慢角瓶颈仍是 EX 乘法链。
- 只有极少数路径变化；端点总数两侧相同（48,478）。
- 首次候选布线 hold 违规：WHS slow −0.036 ns、fast −0.020 ns（各 3 个端点），违规点均在 `soc/core/ifu/tail_q[*] → soc/core/cpu/u_if_id/slot/data_q[77]/…/WADDR[*]` 一类 min 路径。修复：候选 `build.tcl` 中 pnr hold 修复阈值 `0 → 100` ps、迭代 `50 → 100`（`-fix_hold_violation_*` 三个参数同步），仅提高修复强度，**未改变时钟、未放宽约束**；重跑后 hold 为正。

## 5. 资源结果

| 资源 | 基线 | 候选 | 变化 |
|---|---|---|---|
| LUT | 12,441 | 12,406 | −35 |
| FF | 7,268 | 7,268 | 0 |
| DRM（块 RAM） | 4.5 | 4.5 | 0 |
| APM（乘法器） | 6 | 6 | 0 |
| Distributed RAM | 2,685 | 2,685 | 0 |
| IO | 13 | 13 | 0 |
| HSSTHP / USCM / HCKB / RCKB | NA / 1 / 0 / 0 | NA / 1 / 0 / 0 | 0 |

## 6. 约束覆盖与未约束路径

- `constraint_check.ccr`（2026-10-17 22:20:12）：`Found 0 error(s), 0 critical warning(s), 6 warning(s), out of 1 constraint(s)`。
- 6 条 warning 均为 `ConstraintEditor-4019: Port … unspecified I/O constraint`（`led`、`clk`、`key`、`rst_n`、`uart_rx`、`uart_tx`）——这些是板级 I/O，由 `pango_native.pcf` 在 device map 阶段约束；不影响内部时序。
- `report_timing` 的 rtr 报告中没有 “Unconstrained paths” 段，四角 summary 均存在，无约束覆盖缺口。
- 无 “未约束路径” 说明缺失项；若后续需要显式证明，可用 PDS `report_timing -unconstrained` 单独导出（本轮 NOT RUN，rtr 已足够）。

## 7. 位流与 ROM 初始化

| 项 | 基线 | 候选 |
|---|---|---|
| 位流文件 | `$AUDIT\baseline_build\artifacts\pangoriscv_i400_baseline_fullfeature.sbit` | `$AUDIT\frontend_opt\pds\run2_hold100\pangoriscv_top.sbit` |
| 大小 | 3,791,112 B | 3,791,112 B |
| sha256 | `747C18CA32DEFD118E2237863FD7BDAC9C6DB1E110EE734F6CC485FAF68E6D77` | `DE0F907466874E7113F4E7FC535FF101B416CB185E2686CC5F508FA0AA47B4F8` |
| ROM 初始化加载 | `Loading memory data from file` ×2 | `Loading memory data from file` ×2 |
| 载入镜像 | 400 迭代 performance（`4AD7DE6B…` / `6FFD4571…`） | 同左（流程目录内实测 sha256） |

## 8. 本轮 NOT RUN / 边界

- 未用 PDS 优化选项重跑基线（基线位流沿用上一轮已归档产物，sha256 与报告一致；基线源码/配置/镜像身份已在 §2、§2.4 核对）。
- 未做 PDS 多 seed 探索（`multiseed_summary.csv` 为单 seed；`Pass Rate/Convergence Rate 100%`）。
- 未改正式交付树、未覆盖基线位流；候选位流归档在 `frontend_opt/pds/run2_hold100/`。
