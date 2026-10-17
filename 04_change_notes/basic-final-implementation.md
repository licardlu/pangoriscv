# 基本版本落地实现记录（2026-10-10）

> **板级资料核对轮更新（m03415，2026-10-11，最新）—— 本文所有 "50 MHz" 一律作废。**
> 官方板卡资料证明本板系统时钟是 **27 MHz 单端晶振 → D18**（教程1 §2.1.2.2.3.2；教程2 §7.2 与 §7.3；
> 官方 `2_8_uart_test` 的 `uart_top.v BPS_NUM = 234`），板上没有 50 MHz 晶振。
> 本轮据此修改了 `platform/pango_native/pango_native.fdc`（37.037 ns）、`rtl/perips/axi_uart.v`（分频 234）、
> `tests/example/include/utils.h`（`CPU_FREQ_MHZ 27U`）、`tests/example/lib/uart.c`（写 `UART0_BAUD`）、
> `tools/build_native_software.py`（默认 `--cpu-mhz 27`）、三个测试台分频常量、`platform/pango_native/build.tcl`
> （`PANGO_NATIVE_FDC` 覆盖 + 板钟/镜像一致性检查 + 空 ROM 守卫）与 `platform/pango_native/README.md`。
> **本轮改动的逐条记录（旧值/新值/证据/影响/哈希）以
> `09_validation_results/board_material_audit/03_CONSTRAINT_CHANGE_LOG.md` 为准**；
> 复验结论见同目录 `04_PDS_REVALIDATION_REPORT.md`。

> 本文记录"把基本版本做完"这一轮（任务 m01844）对生产文件的**全部**改动。
>
> 阅读边界：`09_validation_results/BASIC_VERSION_VERIFICATION_REPORT.md` 是**验证轮**的报告，
> 该轮的边界是"不改生产文件"，因此它写的"RTL / C / 汇编 / 板级约束未做任何修改"只对该轮成立。
> 本轮（实现轮）的任务就是按验证轮给出的最小修复建议把问题修掉，所以**有**生产文件改动，逐条列在下面。
>
> 全部改动前都有备份，见 §7。

工程根：`E:\file\pango\project\01_code\tinyriscv_axi4`
所有仿真 / 综合命令都必须在该目录下执行（`sim/native_axi_sources.f` 内是相对工程根的路径）。

---

## 1. 改动总表

| # | 文件 | 性质 | 解决验证轮的哪个问题 | 回归证据 |
|---|---|---|---|---|
| 1 | `rtl/bus/axi_interconnect.v` | RTL 修复 | S1（PDS `bmsSMOD` 无法映射，综合直接失败） | `run_interconnect_tests.py --seeds 20` → 20/20 PASS；PDS 综合通过 |
| 2 | `rtl/perips/axi_ram.v` | RTL 修复 | S5（全清单唯一的 SystemVerilog-only 构造，逼着 PDS 开 SV 前端） | 29 源整体编译 0 error；RAM/LSU 40/40 PASS |
| 3 | `platform/pango_native/build.tcl` | 工程脚本修复 | S4（`pds_shell -file` 下相对约束路径不可读，流程 `Flow-0049` 中断） | 完整 PDS 流程 exit 0，产出 `.sbit` |
| 4 | `tb/unit/tb_pipeline.sv` | 测试台修复 | S2（回归台还在连已废弃的 `trap_vector` 端口，跑起来数值就是错的） | `run_pipeline_tests.py` → `PASS N03_PIPELINE` |
| 5 | `rtl/soc/pango_native_top.v` | 可观测性增强 | S6（CPU 内部状态没有引出观测点，板上无法抓 ILA） | 编译 0 error 0 warning；端口未变 |
| 6 | `tests/example/coremark/core_portme.c` | C 修复 | S8（CoreMark 用时只能靠 32 位 `Total ticks` 打印，长跑必然截断） | 1 迭代 CRC 与黄金值一致；200 迭代 `Total ticks 655032761`（13.1007 s ≥ 10 s）、成功行前缀、无 `Errors detected` |
| 7 | `tb/integration/tb_coremark_uart.sv` | 测试台增强 | —（让 CoreMark 回归能自己认出报告结尾，不必烧满周期上限） | CoreMark 回归正常收敛 |
| 8 | `platform/pango_native/README.md` | 文档 | S6 余项（ILA 探针清单与触发配方） | — |
| 9 | `tests/halt_reset/*`、`tb/integration/tb_halt_reset_drain.sv`、`tools/run_halt_reset_tests.py` | **新增**测试覆盖 | 清单第 5 项（halt/reset 事务排空与恢复） | 5/5 PASS |
| 10 | `rtl/soc/pango_native_top.v`（**同一文件再改一次**） | RTL 修复（收尾轮） | **新发现**：第 5 项用的 `(* keep = "true" *)` 被 PDS 拒绝（`PAP_KEEP` 值非法），19 个观测点里 14 个 + 两个计数器**根本没进网表**；`(* ASYNC_REG = "TRUE" *)` 也是非法属性 | 见 §13：新网表中 18 个 `obs_*` 名全部存在；29 源重新精化 0 error 0 warning；完整 PDS 流程重跑 |

前 8 项都是**最小修复**：只动必须动的那几行，不改架构、不改接口、不降断言。
第 10 项是**收尾轮**（任务 m02843）的追加修复，原因、证据、影响面见 §13。

**改造轮（修复前）综合/实现结果（一句话，证据见 `05_verification/native-basic-final-status.md` §4）**：`pds_shell` 完整流程 exit 0，`Design Summary : All Constraints Met`；Slack Setup `WNS 3.258 ns`（慢角，29238 端点 0 失败）、Hold `WHS 0.139 ns`；关键路径 20 − 3.258 = 16.742 ns（等效 Fmax 约 59.7 MHz，**推算**），50 MHz 板振下有余量；`Total LUTs 7622 / 66600 (11.44%)`、`Total Registers 2984 / 133200 (2.24%)`；比特流 `build/pango_native/generate_bitstream/pango_native_top.sbit`（3791112 B，SHA256 `A8D616B3…`）。**未上板下载。**（**以下数值已被收尾轮取代，见下方引用块与 §13.4**）

> **上表的时序/资源/比特流数值已被收尾轮（任务 m02843）取代**：收尾轮修掉观测点属性后重跑同一套 PDS 流程，
> 最终数值见 §13.3 与 §13.4——`WNS 5.219 ns`（慢角，29018 端点）、`WHS 0.124 ns`、
> `Total LUTs 7761 / 66600 (11.65%)`、`Total Registers 3114 / 133200 (2.34%)`、
> 比特流 SHA256 `5ED76142…`。上方 3.258 ns / 7622 LUT / `A8D616B3…` 是**修复前**那一轮的数值，
> 只作为前后对比保留，**不得**再当作最终交付数值引用。

---

## 2. S1 —— `rtl/bus/axi_interconnect.v`：把取模/除法换成环绕扫描 + 位选择

### 原因
PDS 的 ADS/Synplify 前端把参数化取模当成真的取模器，在 `MASTERS=2`（即 `2*MASTERS=4`，明明是 2 的幂）时也没有常量折叠，留下 `bmsSMOD` 原语无法映射，`synthesize` 直接以 exit code 1 结束且**没有产出网表**。

### 改法
- `rtl/bus/axi_interconnect.v:125-135`：仲裁扫描不再用 `(rr+k)%(2*MASTERS)`

```verilog
choice=-1;
candidate=rr;
// Rotating scan instead of (rr+k)%(2*MASTERS) and /2: modulo and
// division are not folded ...
    if(choice==-1 && (candidate[0]==1'b0 ? m_arvalid[candidate>>1] :
                                             m_awvalid[candidate>>1]))
        choice=candidate;
    candidate=(candidate>=2*MASTERS-1)?0:candidate+1;
```

- `:147-148`：`if(choice[0]==1'b0) m_arready[choice>>1]=1; else m_awready[choice>>1]=1;`
- `:184-185`：`owner<=choice>>1; rr<=(choice+1>=2*MASTERS)?0:(choice+1);`
- 其余 16 处 `(choice/2)` → `(choice>>1)`，`choice%2==0` → `choice[0]==1'b0`。

语义等价（`MASTERS` 为 2 的幂，`choice/2 == choice>>1`，`choice%2 == choice[0]`），但不再要求综合器做代数化简。
全文件已无 `%` 与 `/2`。

### 验证
```
python sim/run_interconnect_tests.py --seeds 20      →  SUMMARY 20 / 20 PASS
```
PDS 全流程随后在**同一份 RTL** 上通过（§6）。

---

## 3. S5 —— `rtl/perips/axi_ram.v`：去掉唯一的 SystemVerilog-only 构造

### 原因
对 `sim/native_axi_sources.f` 里 29 个源文件做了一次 SV-only 构造扫描（`always_ff` / `always_comb` / `logic` / `typedef` / `struct` / `enum` / `interface` / `for(integer ...)`），
命中**恰好一处**：`rtl/perips/axi_ram.v:93`（原行号）的 `for(integer lane=0;lane<4;lane=lane+1)`。
它使 PDS 必须在工程设置里打开 SystemVerilog 前端，而 `pds_shell -file` 批处理模式下这个设置项不可靠。

### 改法
- 在已有 `integer delay_left;` 旁加声明 `integer lane;`（现 `:48`，附注释说明为什么不能内联）。
- `:93`（现 `:98`）改为 `for(lane=0;lane<4;lane=lane+1)`。

改完后 29 个源文件全部是 Verilog-2001 合法，**PDS 用默认前端**即可综合。
（`rtl/core/axi_read_engine.v`、`rtl/core/axi_data_engine.v` 里的 `$fatal` 都在 `ifndef SYNTHESIS` 内，安全。）

---

## 4. S4 —— `platform/pango_native/build.tcl`：批处理模式下的路径解析

### 原因
`pds_shell -file <script>` 的批处理解析器下 `[info script]` 取不到可用路径，`./pango_native.fdc` 这类相对路径报：
```
E: Flow-0049: The file {./pango_native.fdc} is not readable
E: Flow-0163: ... build.tcl at line 33/37
```

### 改法
- 布局目录：优先 `$::env(PANGO_NATIVE_BOARD_DIR)`；否则只在 `[file dirname [file normalize [info script]]]` 下确实存在 `native_sources.tcl` 时才采用；都不成立就报错并提示调用方设置环境变量。
- 仓库根：优先 `$::env(PANGO_NATIVE_REPO)`，否则 `$board_dir/../..`。
- 先断言 `native_sources.tcl` / `pango_native.fdc` / `pango_native.pcf` 三个文件都在。
- `add_constraint` 使用**绝对路径** `$fdc_file` / `$pcf_file`。

流程主体未变：逐源 `add_design` 到 `build/pango_native/sources/**`，从 `$repo/build/native_software/coremark/performance`（或 `$::env(NATIVE_IMAGE_DIR)`）拷 `program.hex`/`data.hex`，
`cd $run_dir` → `set_arch -family Logos2 -device PG2L100H -speedgrade -6 -package FBG676` →
`compile -top_module pango_native_top -include_path [list $repo/rtl/core]` →
`synthesize -ads -selected_syn_tool_opt 2` → `dev_map` → `pnr` → `report_timing` → `gen_bit_stream`。

### 实际调用（可复现）
```powershell
$pds='E:\donwload\PDS_2022.2-SP6.4\PDS_2022.2-SP6.1\bin\pds_shell.exe'
$env:PANGO_NATIVE_REPO='E:\file\pango\project\01_code\tinyriscv_axi4'
$env:PANGO_NATIVE_BOARD_DIR='E:\file\pango\project\01_code\tinyriscv_axi4\platform\pango_native'
Set-Location 'E:\file\pango\project\01_code\tinyriscv_axi4\build\pango_native'
& $pds -file 'E:\file\pango\project\01_code\tinyriscv_axi4\platform\pango_native\build.tcl'
```
结果 exit 0，见 §6。

---

## 5. S2 —— `tb/unit/tb_pipeline.sv`：回归台对齐架构 `mtvec`

### 原因
原生 CPU 的陷入重定向走的是架构 `mtvec` CSR，旧顶层端口 `trap_vector` 已经不再使用（`pango_native_top`/原生 SoC 里被接 0）。
回归台还在给 `trap_vector` 喂值，于是"陷入目标正确"这条检查实际上在测一个悬空信号——即使通过也不构成证据。

### 改法
- 新增 `wire ... halt_pending;` 与 `wire [31:0] ... csr_mtvec;`
- 端口连接补 `.halt_pending(halt_pending)`、`.irq_software(1'b0),.irq_timer(1'b0),.irq_external(1'b0),.csr_mtvec(csr_mtvec)`（顺带消掉 5 个 vopt 悬空端口告警）。
- 检查改为
  ```systemverilog
  if(!redirect_valid || redirect_pc!==csr_mtvec) $fatal(1,"trap redirect missing or wrong target");
  ```
- 在第一个陷入用例前插入 CSR 引导（`mtvec` 必须先被程序写进去）：
  ```systemverilog
  insn(236,32'h00001fb7,1,31,32'h1000);   // lui  x31,1
  insn(240,32'h305f9073,0,0,0);           // csrrw x0,mtvec,x31
  drain();
  if(csr_mtvec!==32'h1000) $fatal(1,"mtvec was not programmed");
  ```
  （用 x31 是因为后面 x1 要当除法操作数。）

### 验证
```
python sim/run_pipeline_tests.py    →  PASS N03_PIPELINE   (运行目录 .sim_runs/pipeline-ydi0l7pu)
```

---

## 6. S6 —— `rtl/soc/pango_native_top.v`：板级可观测性（ILA 观测点）

### 原因
赛题要求提交"CPU 流水线在 CoreMark 关键算法上的 ILA 波形"。原顶层把 CPU 状态输出接成匿名表达式后就没再用，综合器会全部优化掉，板上根本抓不到。

### 改法
**端口完全不变**（`clk, rst_n, key, uart_rx, uart_tx, led[7:0]`）——不臆造引脚。
所有 CPU 状态改接到带 `(* keep = "true" *)` 的**命名内部网线**：

`obs_retire_fire`、`obs_retire_order[63:0]`、`obs_retire_pc`、`obs_retire_inst`、`obs_rd_valid`、`obs_rd[4:0]`、`obs_wdata`、
`obs_trap_fire`、`obs_trap_cause`、`obs_trap_pc`、`obs_trap_tval`、`obs_halted`、`obs_arch_next_pc`、`obs_protocol_fault`、
`obs_csr_mtvec`、`obs_uart_tx`，外加两个自由运行计数器 `obs_retire_count` / `obs_trap_count`（用来做 ILA 触发条件）。

探针清单与触发配方写在 `platform/pango_native/README.md`。
**本次没有做任何 ILA 采集**（无物理板），该项仍为 `NOT RUN`。

---

## 7. S8 —— `tests/example/coremark/core_portme.c`：64 位 tick 打印

### 原因
比赛判据是 `CoreMark_Iterations / (Total_Time × Frequency)`，且要求 CoreMark v1.0 **运行 ≥ 10 秒**才算有效。
但：
- `tests/example/coremark/core_main.c:288` 打印 `Total ticks` 时显式做了 `(ee_u32)total_time` 截断；
- `tests/example/lib/xprintf.c` 只实现了 32 位 `long` 转换（第 76/97/127 行）。

于是长跑（几十秒）时 tick 数必然被截断，无法从串口证明"确实跑够了 10 秒"。

### 改法
`stop_time()` 里增加一行：

```c
t1 = get_cycle_value();
ee_printf("CPM_TICKS hi=%lu lo=%lu\n", (unsigned long)(t1 >> 32), (unsigned long)(t1 & 0xffffffffUL));
```

注释里写明：**比赛用时证据只能取这一行或 ILA，不能取被截断的 `Total ticks`**。
计分路径不受影响——`core_main.c` 用 `time_in_secs(get_time())` 算时间，本来就是 64 位。

---

## 8. 清单第 5 项 —— 新增 halt/reset 事务排空与恢复回归

| 文件 | 作用 |
|---|---|
| `tests/halt_reset/link.ld` | 极简链接脚本（text 落 0x0） |
| `tests/halt_reset/halt_reset.S` | 持续 lw/sw 到数据 RAM 的循环，保证 halt/reset 一定打在**真实 AXI 事务**中间 |
| `tb/integration/tb_halt_reset_drain.sv` | 在完整原生 SoC 上跑 5 个场景，含逐周期 AXI VALID/载荷稳定性监视器 |
| `tools/run_halt_reset_tests.py` | 汇编 → 转 4096 字 hex → 编译清单+TB → 逐场景跑 |

5 个场景：
1. 事务进行中 halt（等 `lsu.state==3` LSU_READ_WAIT）
2. 事务进行中 halt（等 `lsu.state==4` LSU_WRITE_WAIT）
3. 事务进行中 reset
4. 事务进行中 reset
5. 空闲时 reset

检查项：已接受的读必须仍返回 R、已接受的写必须仍返回 B（HR_DRAIN）；halt 后 `halted` 必须拉高且 `arch_next_pc` 不再前进；halt 期间 400 周期内任何主设备不得再拉 ARVALID/AWVALID/WVALID（HR_HALTED_QUIET）；释放后第一个 AR 地址必须等于之前捕获的 `arch_next_pc`（HR_RESUME）且退休恢复；reset 场景中所有主设备 valid/ready 必须为低 100 周期（HR_RESET_QUIET）且没有从设备驱动 VALID；释放后首个取指必须是 PC 0（HR_RESTART）且退休恢复；全程 `protocol_fault` 保持低。

验证：`python tools/run_halt_reset_tests.py` → **5 / 5 PASS**。

---

## 9. 其它（测试台/文档，不改设计行为）

- `tb/integration/tb_coremark_uart.sv`：加滚动匹配器 `match_reg`/`report_seen`/`report_cycle`，主 `initial` 改为
  `fork begin wait(cycles>=max_cycles); end begin wait(report_seen); repeat(12000) @(posedge clk); end join_any`
  ——CoreMark 打印完报告就收尾，不烧满周期上限；删掉失效的 PC_HIST 打印。
  触发串同时匹配 `"CoreMark 1.0"`、`"Correct operation"`、`"Errors detected"`（第三条永远不会出现，见 §12；第二条是本固件唯一的成功终点）。
- `platform/pango_native/README.md`：状态小节更新为本次真实综合结果；SystemVerilog 选项一节改为"**不再需要**"；补 PDS 环境变量说明、200 迭代 CoreMark 构建命令与 13.1007 s 仿真实测、`Timing-4087/-4086` 属预期、以及完整 ILA 探针清单 + 触发配方。

---

## 10. 备份

| 备份 | 位置 |
|---|---|
| 本轮改动前的整棵源码树 | `E:\file\pango\project\02_original_backups\tinyriscv_source_before_resume_20261010_171938` |
| 本轮改动前的备份脚本与清单 | `E:\file\pango\project\09_validation_results\basic_final\backup_before_basic_final.ps1` |
| 10000 迭代 CoreMark 镜像（被本轮重建替换前） | `E:\file\pango\project\09_validation_results\basic_final\coremark\performance_10000_iter`（含 `SHA256.csv`） |

改动后全部源文件的 SHA256 清单：`E:\file\pango\project\09_validation_results\basic_final\FINAL_SOURCE_SHA256.csv`。

---

## 11. 明确未做的事

- 没有改 `rtl/core/**`（CPU 数据通路、CSR、IFU/LSU 引擎）——验证轮定的冻结契约不动。
- 没有改 `platform/pango_native/pango_native.fdc` / `.pcf`（时钟 20 ns、引脚定义保持原样；FDC 故意不加 blanket false path）。
- 没有实现 Cache / 动态分支预测 / DDR / DMA（属高级任务，本轮范围外）。
- 没有改 `FENCE.I` 译码（保持非法指令，不声称 Zifencei）。
- 没有更快的取指改造（IPC 提升属后续优化项）。
- 没有上板下载、没有 ILA 采集。

**收尾轮（任务 m02843）额外"没有做"的**：

- 没有为了修观测点去改 `syn_probe`（会把探针变成顶层端口，本设计引脚已固定）。
- 没有猜 SCBV 值：本地 Pango 文档只写"按实际板卡电压选择"，`07_board_references` 里没有任何板卡原理图/用户手册，**缺少资料就如实标 BLOCKED**。
- 没有动 `platform/pango_native/pango_native.fdc` 去加 blanket false path 来"消掉"未约束路径告警。
- 没有改动 9 组功能回归所依赖的任何 RTL（收尾轮唯一的 RTL 改动是 `rtl/soc/pango_native_top.v` 的属性写法）。
- 没有把仿真的 13.1007 s / 0.3053 CoreMark/MHz 写成板上成绩；板级项全部 `NOT RUN`。

---

## 12. CoreMark 用时取证结论（V11 / V12），以及一处**软件侧**能力限制

本节不记录"改动"，只记录跑完之后的取证边界，因为签名/交付时一定会被问到。

### 12.1 已取得的

| 项 | 结果 |
|---|---|
| 1 迭代性能镜像（V11） | 串口报告 5 项 CRC 与 `core_main.c` 黄金表 index 3 一致；`Total ticks 3274904`；打印 `Total time (secs): 0` 与 `ERROR! Must execute for at least 10 secs…` —— **该镜像本身不满足 ≥10 s** |
| 200 迭代性能镜像（V12） | `Total ticks 655032761`、`Total time (secs): 13`、`Iterations/Sec : 15`、`Iterations : 200`、CRC 全对（`crcfinal 0x382f`）、成功行**前缀** `Correct operation v`、**无** `Errors detected` |
| 64 位原始 tick | `CPM_TICKS hi=0 lo=655213650` → `t1=655213650`，`t0=180889`，**无 32 位回绕** |
| 仿真规模 | `cycles=658177948 retires=61293205 traps=0 faults=0 uart_chars=652 txd_writes=652`；vsim 墙钟 38 分 01 秒；0 error 0 warning |
| ≥10 s 判据 | `655032761 / 50000000 = 13.1007 s ≥ 10 s` —— 在**仿真内实测**成立 |
| 推算自校验 | 线性推算 654,980,800 与实测 655,032,761 差 0.008% |
| 分数（算术推导） | `200 / 13.10065522 = 15.2665 iter/s` → CoreMark/MHz `0.3053` |
| 证据路径 | `09_validation_results/basic_final/coremark/coremark_perf_200iter_50MHz.log`、`coremark_perf_200iter_compile.log`、`performance_200_iter/`（`coremark.elf` `5EDB52BA…`、`program.bin` `B0A03D96…`，与 `manifest.json` 的 `artifact_sha256` 逐项一致） |

### 12.2 **没有**取得的

- **板上实测**：无物理板，V14/V15/V16 全部 `NOT RUN`；仿真的 13.1007 s **不能**当作板上用时证据。
- 板上真实 CoreMark 分数、板上最高实际频率：**均未实测**。

### 12.3 本固件**永远打印不出**标准 `CoreMark 1.0 : <分数>` 行（新发现，未修）

| 位置 | 内容 | 后果 |
|---|---|---|
| `tests/example/coremark/core_portme.h:16` | `#define HAS_FLOAT 0` | 关掉全部浮点打印分支 |
| `tests/example/lib/xprintf.c:122-123` | `default: xputc(c); continue;`（`%f` 走 default，回显一个 `f` 且**不消耗** va_arg 的 double） | 该 port 的 `ee_printf` 无浮点能力；`xprintf.c:66` 自带注释就是 `<xprintf lacks floating point support>` |
| `tests/example/coremark/core_main.c:294,296` | `#else` 分支用 `%d` 打印 `Total time (secs)` / `Iterations/Sec` | 小数被截断，故打印 `13` / `15` |
| `tests/example/coremark/core_main.c:325-339` | `#if HAS_FLOAT` 包住 `if (known_id==3) ee_printf("CoreMark 1.0 : %f …")` | `HAS_FLOAT 0` 时**整段被预处理剔除**，该行在本镜像里不可能出现 |

结论：本镜像唯一的成功终点是 `Correct operation validated.`（`core_main.c:324`），这也是 `total_errors==0` 能给出的最强证据；分数只能由 `Total ticks` + 已知 `CPU_FREQ_MHZ=50` 算出。

> **日志截断（必须如实说明）**：200 迭代日志里只捕获到该行的**前缀** `# Correct operation v`（log 第 2827 行），其后 TB 就 `$finish` 了（`tb/integration/tb_coremark_uart.sv(319)`，`stop_cycle=658177948`），`alidated. See readme.txt …` 没有传完——TB 匹配到 `"Correct operation"` 后只等 12000 周期。
> **结论不受影响**：`ee_printf("Correct operation validated. …")` 只在 `total_errors==0` 分支执行，`Errors detected` 只在 `total_errors>0` 分支，两者互斥，**收到任意前缀即等价于 `total_errors==0`**；且 5 个 CRC 检查点全部等于黄金值。引用时不要写成完整原文。

**要不要修**：属**软件/port** 改动，不在本轮 RTL+平台交付范围；不改也能满足"≥10 s 有效结果"（判据是 `Total ticks`，不是分数行）。若评审坚持要看到原文，最小改法是让 `ee_printf` 支持 `%f` 后重建镜像，**不要**改 `core_main.c` 的判据逻辑。

**读日志注意**：`tb_coremark_uart.sv` 的 `PROGRESS`/`LIVE` 行会**插进被解码的固件输出中间**，把一行拆成多段（如 `Iterations/Sec : 1` 之后隔两行才是续下来的 `5`；`CPM_TICKS` 前缀被吃掉只剩 `hi=0 lo=655213650`）。引用固件输出时必须容忍这种交错。

---

## 13. 收尾轮（任务 m02843）追加修复：上表第 5 项的观测点原本**没有进网表**

### 13.1 发现

上表第 5 项给 `rtl/soc/pango_native_top.v` 的 19 个观测信号加了 `(* keep = "true" *)`，当时的判据只是"编译 0 error 0 warning、端口未变"，**没有检查综合网表**。收尾轮核对 PDS 日志时发现该属性被工具**拒绝并忽略**：

| 日志位置 | 原文 |
|---|---|
| `build/pango_native/compile/run.log:188-205` | `I: [... pango_native_top.sv(line number: 36..54)] Convert attribute name from keep to PAP_KEEP` |
| `build/pango_native/compile/run.log:214+` | `W: [... pango_native_top.sv(line number: 36..54)] The value of attribute PAP_KEEP is invalid, ignore it.` |
| `build/pango_native/compile/run.log:213` | `W: Sdm-2008: The attribute named ASYNC_REG is not legal, then it has no effect, ignore its value.` |

后果（旧综合网表 `build/pango_native/synthesize/pango_native_top_syn.vm`，2026-10-10 23:14:57 生成）：19 个观测名里**只剩 4 个**（`obs_rd`/`obs_retire_fire`/`obs_retire_inst`/`obs_trap_fire`），`obs_retire_order`、`obs_retire_pc`、`obs_wdata`、`obs_trap_cause/pc/tval`、`obs_halted`、`obs_arch_next_pc`、`obs_protocol_fault`、`obs_csr_mtvec`、`obs_uart_tx` 全部消失，两个计数器 `retire_count`/`trap_count` 在 `build/pango_native` 下**0 次命中**。同一网表里 `uart_tx`/`led`/`gpio_data`/`gpio_ctrl` 都在，说明这是死端网络被真实优化掉，不是命名问题。**即：按原样交付，`platform/pango_native/README.md` 里那张 ILA 探针表在实现后的网表上根本抓不到点。**

### 13.2 改动（只动属性写法，不动逻辑、不动端口）

依据本机 Pango 文档 `E:\donwload\PDS_2022.2-SP6.4\PDS_2022.2-SP6.1\syn\doc\fpga_attribute_reference.pdf`（Synplify Pro for Pango Attribute Reference，202 页）：

| 指令 | 页 | 用法与原文要点 |
|---|---|---|
| `syn_keep` | 85/87 | `object /* synthesis syn_keep = 1 */;`，保留指定连线不被优化；"object is a wire or reg declaration for combinational logic"，且对象名与注释斜杠之间**必须有空格** |
| `syn_preserve` | 123 | "Prevents sequential optimizations such as constant propagation, inverter push-through, and FSM extraction"，用于保留寄存器 |
| `syn_probe` | 127 | 会**把探针变成顶层端口**——本设计引脚已固定，**不能用** |

改动内容（`rtl/soc/pango_native_top.v`，85 行 3603 B → 101 行 5027 B）：

1. `(* ASYNC_REG = "TRUE" *) reg [1:0] reset_sync;` → `reg [1:0] reset_sync /* synthesis syn_preserve = 1 */;`（本 wrapper 单时钟域，复位同步器只需保持结构）。
2. 16 个组合观测信号 → `wire obs_x /* synthesis syn_keep = 1 */;`。
3. 2 个死端计数器 → `reg [31:0] obs_retire_count /* synthesis syn_keep = 1, syn_preserve = 1 */;`（`obs_trap_count` 同）。
4. 删掉全部 `(* keep = "true" *)`（否则每次编译仍有 19 条 `PAP_KEEP` 警告）。

### 13.3 复验

- **重新精化**：`vlib .sim_runs/closure_elab/work` + `vlog -sv -work .sim_runs/closure_elab/work +incdir+rtl/core -f sim/native_axi_sources.f`（CWD = 工程根）→ 29 个模块全部编译，`Top level modules: pango_native_top`，**Errors: 0, Warnings: 0**（日志 `.sim_runs/closure_elab/elab.log`，收尾轮证据里另存一份 `pds_rerun/elab.log`）。
- **属性已被工具接受**：新编译日志 `build/pango_native/compile/run.log:188-207` 只有
  `I: [... pango_native_top.sv(line number: 20)] Convert attribute name from syn_preserve to PAP_PRESERVE`
  与 17 条 `I: [... (line number: 51..70)] Convert attribute name from syn_keep to PAP_KEEP`，
  **不再有** `The value of attribute PAP_KEEP is invalid, ignore it.`，也**不再有** `W: Sdm-2008` 的 `ASYNC_REG` 警告。
- **重新综合/实现**：删除 `build/pango_native/{compile,constraint_check,synthesize,device_map,place_route,generate_bitstream}` 后重跑 `platform/pango_native/build.tcl`。
  新网表 `build/pango_native/synthesize/pango_native_top_syn.vm`（5,477,576 B，SHA256 `CED470656CC29D2C4F0A2CC80585863EBA32A5C2B16FD2876208BF2F4DD5A2B5`）中 18 个观测名**全部存在**，
  出现次数：`obs_retire_fire` 34、`obs_retire_order` 2、`obs_retire_pc` 33、`obs_retire_inst` 103、`obs_rd_valid` 2、`obs_rd` 4、`obs_wdata` 2、`obs_trap_fire` 34、`obs_trap_cause` 6、`obs_trap_pc` 2、`obs_trap_tval` 2、`obs_halted` 1、`obs_arch_next_pc` 2、`obs_protocol_fault` 2、`obs_csr_mtvec` 31、`obs_uart_tx` 3、`obs_retire_count` 137、`obs_trap_count` 137。修复**已生效**。
  （上面提到的"旧网表只剩 4 个名、两个计数器 0 次命中"指修复前那一版 `pango_native_top_syn.vm`；此处数字以**收尾轮重跑后的最终网表**为准。）
- **影响面判断（必须如实写明）**：`pango_native_top` 不被任何仿真 testbench 例化（SoC 级 testbench 例化的是 `tinyriscv_axi_soc`），所以本轮**没有重跑功能回归**，理由是 9 组回归所依赖的 RTL 一行未改；但该文件是 `sim/native_axi_sources.f` 的 29 个源之一，**必须**重新精化——已做。

### 13.4 收尾轮重跑后的最终实现数值（取代 §1 上方的旧数值）

| 项 | 修复前（2026-10-10 那一轮） | **收尾轮重跑（最终）** | 证据 |
|---|---|---|---|
| 流程结果 | `Design Summary : All Constraints Met.` | **同上，exit 0** | `09_validation_results/basic_closure/pds_rerun/pds_rerun_closure.log` |
| 时序端点 | 29238 | **29018** | `pds_rerun/place_route/pango_native_top_timing_summary_after_hold_fix.txt` |
| 慢角 Setup WNS | 3.258 ns | **5.219 ns**（TNS 0.000，0 失败） | 同上 |
| 慢角 Hold WHS | 0.139 ns | **0.124 ns**（THS 0.000，0 失败） | 同上 |
| 快角 Setup / Hold | 8.368 ns / 0.101 ns | **10.156 ns / 0.088 ns** | 同上 |
| Recovery / Removal / 最小脉宽 | 空（无违例） | **空（无违例）** | 同上 |
| 关键路径 / 等效 Fmax | 16.742 ns / 约 59.7 MHz | **20 − 5.219 = 14.781 ns / 约 67.6 MHz** | 算术推导 |
| Total LUTs | 7622 / 66600 (11.44%) | **7761 / 66600 (11.65%)**（其中 `LUTs as dram` 2080、`LUTs as logic` 5681） | `pds_rerun/place_route/run.log` |
| Total Registers | 2984 / 133200 (2.24%) | **3114 / 133200 (2.34%)** | 同上 |
| Latches / APM / I/O | 0 / 6.00 of 240 / 13 of 300 | **0 / 6.00 of 240 (2.50%) / 13 of 300 (4.33%)** | 同上 |
| 比特流 | `A8D616B31B2E53B91A668F5883E82A423FBC8F3B6874EA32181B80454DC693B1` | **`5ED76142DF321F752F01E9637F8616B54AB7083DCE85C040E21B44BC1CE529F4`**（3,791,112 B） | `pds_rerun/generate_bitstream/pango_native_top.sbit` |
| 流程耗时 | — | compile→gen_bit_stream CPU 0h:4m:43s，进程总 CPU 0h:5m:20s | `pds_rerun_closure.log` |

**代价与收益（如实记录）**：把观测点真正留在网表里，代价是 **+139 个 LUT、+130 个寄存器**（`+0.21%` LUT、`+0.10%` 寄存器），
收益是 `platform/pango_native/README.md` 的 ILA 探针表在**实现后的网表上确实抓得到**——这是"能上板"和"只能上板但抓不到"的区别。
时序数值的变化（3.258 → 5.219 ns）来自修复后网表布线结果不同，**不是**"改属性提升了主频"，不要把两者写成因果关系。

> **仍未做**：比特流**没有下载、没有上板、没有 ILA 采集**；`C: Bitstream-2001: SCBV has not been set.` 警告依旧存在（原因见 `09_validation_results/basic_closure/01_PLAN_RECONCILIATION.md` §5 B2），**未猜值**。
> `Timing-4086/4087`（`led[0..7]`、`uart_tx`、`key`、`rst_n`、`uart_rx` 未约束）依旧存在，属 FDC 故意不加 blanket false path 的预期结果。
