# tinyriscv native-AXI 基本版本 —— 落地状态与验证台账（2026-10-10，收尾轮 m02843 更新于 2026-10-11）

> **板级资料核对轮更新（m03415，2026-10-11，最新）—— 本文所有 "50 MHz" 一律作废。**
> 官方板卡资料证明本板（盘古100Pro+ / MES2L676-100HP / PG2L100H-6IFBG676）的**系统时钟是 27 MHz 单端晶振 → D18**，
> 板上没有 50 MHz 晶振（教程1 §2.1.2.2.3.2；教程2 §7.2「27MHZ…周期约为 37.037ns」；官方 `2_8_uart_test`
> 的 `uart_top.v BPS_NUM = 234`）。本轮据此改了 4 个频率相关常量（`create_clock` 37.037 ns、UART 分频 234、
> `CPU_FREQ_MHZ` 27、构建脚本默认 `--cpu-mhz 27`）并重跑了 PDS 与回归。
> **最新权威证据根**：`E:\file\pango\project\09_validation_results\board_material_audit`
> （`01_BOARD_MATERIAL_AUDIT.md` 资料核对、`02_PIN_AND_SCBV_COMPARISON.md` 引脚/SCBV、`03_CONSTRAINT_CHANGE_LOG.md` 改动记录、
> `04_PDS_REVALIDATION_REPORT.md` 修改后复验、`05_NEXT_BOARD_BRINGUP_STEPS.md` 上板步骤、`BOARD_MATERIAL_AUDIT_FINAL.md` 结论）。
> 本文下面 §3/§4 里的 20 ns / 50 MHz / WNS +5.219 / 比特流 `5ED76142…` 等数值，都属于**修改前（50 MHz 假设）**的历史版本；
> 修改后的最终数值以 `board_material_audit/04_PDS_REVALIDATION_REPORT.md` 为准。

> 本文是**实现轮**（任务 m01844）的台账，并由**收尾轮**（任务 m02843）更新：把基本版本做到"可交付"之后，逐项列清哪些真的跑过、哪些没跑。
> 收尾轮新增/更新的条目一律标 `V18` 或"收尾轮"字样；**最终交付数值以收尾轮为准**（时序/资源/比特流见 §4，源码清单见 `09_validation_results/basic_closure/03_SOURCE_SHA256.csv`）。
>
> **证据分级是硬要求**：编译 ≠ 仿真 ≠ 综合 ≠ 上板 ≠ 计分。本文任何一处结论都不跨级外推。
>
> - 工程根：`E:\file\pango\project\01_code\tinyriscv_axi4`（**所有** vlog/vsim/python 命令都在此目录下执行）
> - 证据根：`E:\file\pango\project\09_validation_results\basic_final`
> - **收尾轮证据根**：`E:\file\pango\project\09_validation_results\basic_closure`
> - 改动记录：`04_change_notes/basic-final-implementation.md`
> - 验证轮报告（历史，边界是"不改生产文件"）：`09_validation_results/BASIC_VERSION_VERIFICATION_REPORT.md`
>
> **路径简写**：表里的 `.../xxx` 一律指 `E:\file\pango\project\09_validation_results\basic_final\xxx`；`build/...` 指工程根下的 `build/...`。

---

## 1. 一句话状态

| 证据类别 | 状态 |
|---|---|
| 代码可综合 / 可精化 | **PASS**（29 源 Verilog-2001 + SV 混合，ModelSim 0 error 0 warning） |
| 功能验证（仿真） | **PASS**（9 组回归全绿：15/15、5/5、PASS、20/20、64/64、20/20、40/40、4/4） |
| 综合 / 布局布线 / 时序 / 比特流 | **PASS**（`All Constraints Met`，已产出 `.sbit`；**最终数值**：慢角 Setup WNS +5.219 ns / Hold WHS +0.124 ns，LUT 7761/66600 = 11.65%，比特流 SHA256 `5ED76142…`，见 §4） |
| 上板下载 | **NOT RUN**（无物理板） |
| CoreMark 实测 | **仿真 PASS / 板上 NOT RUN**（200 迭代 `Total ticks 655032761` → 仿真实测 **13.1007 s ≥ 10 s**，CRC 全对、无 `Errors detected`；**板上**与计分未取得） |
| ILA 波形 | **NOT RUN**（无板，未采集） |

**没有任何一项上板结论被写成本文的仿真或综合结果。**

---

## 2. 运行环境

| 项 | 值 |
|---|---|
| 工具链 | `E:\file\pango\toolchains\openisa-1.0.0\gcc\riscv32-unknown-elf-gcc\bin`，`riscv32-unknown-elf-gcc.exe (GCC) 7.1.1 20170509`，`-march=rv32im -mabi=ilp32` |
| 仿真器 | ModelSim SE-64 10.6e（`E:\donwload\win64`） |
| 综合/实现 | `E:\donwload\PDS_2022.2-SP6.4\PDS_2022.2-SP6.1\bin\pds_shell.exe`（2022.2-SP6.1 build 138931） |
| 目标器件 | Logos2 `PG2L100H-6FBG676`（50 MHz 晶振）。器件型号有独立来源：板厂参考工程的 PDS 日志 `07_board_references/.../run_2026-09-22-15-31-49.log:728` 报 `Current device : PG2L100H-6FBG676`。**板卡商品名 `MES2L676-100HP` 在 `07_board_references` 里找不到任何独立来源**（`07_board_references` 无 `.md`、无原理图、无用户手册），只能算待确认信息，**不得**当作已核实事实引用。 |
| Python | 3.11.9 |
| 缺失工具 | iverilog / vvp / yosys **不存在**；物理板 **不存在** |

> PDS license：`E:\donwload\PDS_2022.2-SP6.4\new_pds_F4A80DA47D72.lic`，运行时提示 `license will invalid in 24 days`。

---

## 3. 工程验证表

| # | 验证项 | 结果 | 精确命令（CWD = 工程根） | 日志 |
|---|---|---|---|---|
| V1 | 29 源整体编译 + 精化 | **PASS** | `vlog -sv -work sim/verify_work/compile_check/work "+incdir+rtl/core" "+incdir+rtl/soc" -f sim/native_axi_sources.f` | `sim/verify_work/compile_check/compile.log`（`Errors: 0, Warnings: 0`，exit 0） |
| V2 | 指令级端到端（真实工具链程序 × 完整原生 SoC × 参考模型） | **PASS 15/15** | `python tools/run_isa_e2e.py --cases all` | `09_validation_results/basic_final/regressions/isa_e2e.txt` |
| V3 | halt / reset 事务排空与恢复（5 场景） | **PASS 5/5** | `python tools/run_halt_reset_tests.py` | `.../regressions/halt_reset.txt`、`.../halt_reset/halt_reset_run.txt` |
| V4 | 流水线 N03（含架构 `mtvec` 陷入目标校验） | **PASS** | `python sim/run_pipeline_tests.py` | `.../regressions/pipeline.txt`（`RUN_DIR .sim_runs/pipeline-ydi0l7pu`） |
| V5 | AXI 互联随机回归（20 seed） | **PASS 20/20** | `python sim/run_interconnect_tests.py --seeds 20` | `.../regressions/interconnect.txt` |
| V6 | 读/写引擎 | **PASS 64/64** | `python sim/run_engine_tests.py` | `.../regressions/engine.txt` |
| V7 | IFU↔AXI 引擎 | **PASS 20/20** | `python sim/run_ifu_engine_tests.py` | `.../regressions/ifu_engine.txt` |
| V8 | RAM + LSU | **PASS 40/40** | `python sim/run_ram_tests.py` | `.../regressions/ram.txt` |
| V9 | 单元级（pipe_slot / div_adapter / ifu_axi / lsu_axi） | **PASS 4/4** | `python sim/run_unit_tests.py` | `.../regressions/unit.txt` |
| V10 | 综合 → 布局布线 → 时序 → 比特流 | **PASS** | 见 §4 | `09_validation_results/basic_final/pds/{flow.log,run.log,timing_summary_after_pnr.txt,clock_utilization.txt,pango_native_top.sbit}`（**修复前那一轮**；最终数值见 V18） |
| V11 | CoreMark 1 迭代性能镜像仿真（50 MHz） | **PASS（CRC 全对）** | `vsim -c ... tb_coremark_uart +PROG=... +MAX_CYCLES=40000000` | `.../coremark/coremark_perf_1iter_50MHz.log` |
| V12 | CoreMark 200 迭代仿真（≥10 s 用时取证） | **PASS** | 同上，`+MAX_CYCLES=800000000`，镜像 `--iterations 200` | `09_validation_results/basic_final/coremark/coremark_perf_200iter_50MHz.log`（原始：`sim/verify_work/cm200/coremark_200iter.log`） |
| V13 | 软件镜像构建（CoreMark 性能/校验） | **PASS** | `python tools/build_native_software.py coremark --mode performance --iterations 200 --cpu-mhz 50 --toolchain-bin <bin>` | `build/native_software/coremark/performance/manifest.json`（含全部编译命令与 flags） |
| V14 | 上板下载 / 串口实测 | **NOT RUN** | — | 无物理板 |
| V15 | ILA 波形采集 | **NOT RUN** | — | 无物理板 |
| V16 | 板上真实 CoreMark 计分 | **NOT RUN** | — | 无物理板 |
| V17 | riscv-compliance 官方套件全量跑 | **NOT RUN** | 套件源码/ELF 在树内，但本轮以自建 E2E + 定向用例覆盖 | — |
| V18 | **收尾轮**：观测点属性修复后 29 源重新精化 + 完整 PDS 重跑 | **PASS** | 见 §4.1 | `09_validation_results/basic_closure/pds_rerun/{pds_rerun_closure.log,elab.log,compile/run.log,synthesize/pango_native_top_syn.vm,place_route/...,generate_bitstream/pango_native_top.sbit}` |

---

## 4. 综合 / 时序 / 比特流（V10 详情）

**命令**（可复现）：
```powershell
$pds='E:\donwload\PDS_2022.2-SP6.4\PDS_2022.2-SP6.1\bin\pds_shell.exe'
$env:PANGO_NATIVE_REPO='E:\file\pango\project\01_code\tinyriscv_axi4'
$env:PANGO_NATIVE_BOARD_DIR='E:\file\pango\project\01_code\tinyriscv_axi4\platform\pango_native'
Set-Location 'E:\file\pango\project\01_code\tinyriscv_axi4\build\pango_native'
& $pds -file 'E:\file\pango\project\01_code\tinyriscv_axi4\platform\pango_native\build.tcl'
```

**结果（收尾轮最终重跑，V18）**：exit 0，六个阶段全部 `successfully`，
compile→gen_bit_stream 总 CPU `0h:4m:43s`，进程总 CPU `0h:5m:20s`（`pnr` 实测 `0h:2m:53s`，峰值内存 1,641 MB）。
日志：`09_validation_results/basic_closure/pds_rerun/pds_rerun_closure.log`。

> 上一轮（修复观测点属性之前，V10）同流程为 `0h:4m:28s`、`pnr 0h:2m:21s`，日志在 `09_validation_results/basic_final/pds/`。
> **两轮的时序/资源/比特流数值不同**，下表给出最终值并保留旧值作对比；引用时只能用最终值。

**时序（`pnr` 之后，最终）**：`Design Summary : All Constraints Met.`

| 角 | 项 | 最终值（V18） | 失败端点 | 修复前（V10，仅对比） |
|---|---|---|---|---|
| Slow | Setup WNS | **+5.219 ns** | 0 / 29018 | +3.258 ns / 29238 |
| Slow | Hold WHS | **+0.124 ns** | 0 / 29018 | +0.139 ns / 29238 |
| Fast | Setup WNS | **+10.156 ns** | 0 / 29018 | +8.368 ns / 29238 |
| Fast | Hold WHS | **+0.088 ns** | 0 / 29018 | +0.101 ns / 29238 |

Recovery / Removal / Minimum Pulse Width 三个汇总在**两个角上都是空的**（无违例）。

时钟周期 20 ns（`pango_native.fdc`：`create_clock -name clk -period 20 -waveform {0 10} [get_ports {clk}]`）。
关键路径 = 20 − 5.219 = **14.781 ns** → **等效 Fmax ≈ 67.6 MHz**。
即：50 MHz 目标下余量 5.219 ns。
**口径（必须照此写）**：目标频率仍是 **50 MHz**，"约 59.7 MHz / 约 67.6 MHz"只是由 PnR 余量**推算**的时序余量估计，
**不是**实测最高频率、**不是**已把主频改成 67 MHz；板卡晶振是 50 MHz，本轮**没有**为了好看去降频或改频。

**资源（`pnr` 之后，最终）**：

| 项 | 用量（V18） | 可用 | 占比 | 修复前（V10） |
|---|---|---|---|---|
| Total LUTs | **7761** | 66600 | **11.65%** | 7622 / 11.44% |
| — 其中 LUTs as Logic | 5681 | — | — | 5542 |
| — 其中 LUTs as DRAM(distributed) | 2080 | 19900 | 10.45% | 2080 / 11% |
| Total Registers | **3114** | 133200 | **2.34%** | 2984 / 2.24% |
| DRM (36K block RAM) | 4 | 155 | 3% | 4 / 3% |
| APM | 6 | 240 | 2.50% | 6 / 3% |
| I/O | 13 | 300 | 4.33% | 13 / 5% |
| Latches | 0 | — | — | 0 |

**观测点属性修复的代价**：`+139 LUT`、`+130 寄存器`（LUT 11.44% → 11.65%，寄存器 2.24% → 2.34%），
换来的是 `platform/pango_native/README.md` 的 ILA 探针表在**实现后网表里确实存在**（详见 `04_change_notes/basic-final-implementation.md` §13）。

**比特流（最终）**：`build/pango_native/generate_bitstream/pango_native_top.sbit`（3,791,112 B，SHA256 **`5ED76142DF321F752F01E9637F8616B54AB7083DCE85C040E21B44BC1CE529F4`**），
已归档到 `09_validation_results/basic_closure/pds_rerun/generate_bitstream/pango_native_top.sbit`。
（修复前那一轮为 `A8D616B31B2E53B91A668F5883E82A423FBC8F3B6874EA32181B80454DC693B1`，同尺寸，归档在 `09_validation_results/basic_final/pds/pango_native_top.sbit`，**只作历史对比**。）

**必须一起叙述的告警/限制**：
1. `C: Bitstream-2001: SCBV has not been set. Please set SCBV value based on PCB board...`
   → 未设置 SCBV，**该比特流是否可直接烧录未经上板验证**（无板，无法确认）。
2. `Timing-4087/-4086` 报 `led[0..7]`、`uart_tx`、`key`、`rst_n`、`uart_rx` 为未约束组合路径 —— **预期行为**：FDC 只建时钟、故意不加 blanket false path（加了会把真实路径一并掩盖）。
3. `W: syn_maxfan of lutcarry ... is more than 10000`，未自动复制 —— 未做进一步处理。

**资源效率发现（记录，本轮不改，S3/优化项同属后置 OPEN）**：16 KiB 数据 RAM 因为 `axi_ram.v` 是**异步读**，被推成分布式 LUTRAM（`GTP_RAM64X1DP ×2048` + 寄存器堆 `GTP_RAM32X2DP ×32`），吃掉了 2080 个 LUT；只有只读的程序 RAM 正确推断成 `GTP_DRM36K_E1 ×4`。
若把数据 RAM 改成同步读、改推 block RAM，LUT 总数约可从 7761 降到 ~5681（11.65% → ~8.5%），直接改善赛题 `CoreMark/LUTs` 指标。
**本轮不动**：更激进的性能/资源优化按用户意图属于后续步骤，本轮只做基本版本落地。

---

## 5. 功能验证覆盖（V2 明细）

`run_isa_e2e.py` 在**完整原生 SoC**（CPU + IFU/LSU AXI 引擎 + 互联 + 程序 RAM + 数据 RAM + UART/GPIO/Timer/SPI/IRQ）上跑真实工具链汇编出的程序，并与独立参考模型逐寄存器比对。镜像检查：16,200 / 16,384 B，无压缩指令，编译 0 error。

| 用例 | 覆盖内容 |
|---|---|
| 1 | ALU 依赖链与立即数形式 |
| 2 | load-use 冒险与载入符号/零扩展 |
| 3 | M 扩展乘/除/余 |
| 4 | 分支 / jal / jalr 与错误路径抑制 |
| 5 | 字节/半字 lane 与 store→load |
| 6 | CSR 读改写规则（CSRRW 在 rd=x0 时仍写；CSRRS/CSRRC 写意图来自编码 rs1 索引） |
| 7 | `mcycle` / `minstret` 计数器 |
| 8 | ECALL 陷入与 MRET 返回 |
| 9 | 非法指令陷入 |
| 10 | 取数访问故障陷入 |
| 11 | 存数访问故障陷入 |
| 12 | UART TXDATA 发送 |
| 13 | GPIO 输出模式 |
| 14 | Timer 单次触发与 W1C |
| 15 | 机器定时器中断与 MRET |

陷阱处理链已被真实固件覆盖：`init.c` 写 `mtvec/mie/mstatus` → `start.S` 先调 `_init` 再进 `main` → `trap_entry.S` 保存 x1,x3..x31（x2 存到 sp+128 槽位，保留被中断的 sp）→ `trap_handler.c` 按 cause 3/7/11 分派，其余 cause **关闭 mie/MIE、记录 `trap_last_fault{cause,epc,tval,valid}` 并死循环**，绝不静默 `mepc+4`（仅 `TRAP_TEST_ALLOW_ECALL` 下 cause 11 例外）。

`get_cycle_value()` 已是 64 位安全（high-low-high 重读 + 回绕安全减法）；本轮未改软件。

---

## 6. CoreMark 状态（V11 / V12）—— 证据边界

### 6.1 已取得的（V11，1 迭代性能镜像，50 MHz 仿真）

串口解出的报告：
```
2K performance run parameters for coremark.
CoreMark Size    : 666
Total ticks      : 3274904          <- core_main.c:288 的 (ee_u32) 截断打印
Total time (secs): 0
ERROR! Must execute for at least 10 secs for a valid result!
Iterations       : 1
Compiler version : GCC7.1.1 20170509
Compiler flags   : -march=rv32im -mabi=ilp32 ... -DITERATIONS=1 -DPERFORMANCE_RUN=1
Memory location  : STATIC
seedcrc          : 0xe9f5
[0]crclist       : 0xe714
[0]crcmatrix     : 0x1fd7
[0]crcstate      : 0x8e3a
[0]crcfinal      : 0xe714
Errors detected
```

四个 CRC 与 `core_main.c` 内建黄金表 index 3（PERFORMANCE_RUN）**逐项一致** → 功能正确性成立。

仿真侧计数：`cycles=40000000 retires=2554658 traps=0 faults=0 uart_chars=679`，程序最终停在 `loop: j loop`（pc 0x68）。

由此推算（**仅为推算，不是实测**）：
- ticks = 3,274,904；50 MHz → 0.0654990 s
- CoreMark/MHz = 1 / 3,274,904 × 1e6 = **0.305**
- 200 迭代 → 200 × 3,274,904 = 654,980,800 ticks → 50 MHz 下 **13.10 s**（实测为 655,032,761 ticks = 13.1007 s，偏差 0.008%）
- **口径提醒**：`CPU_FREQ_HZ` 与板振都是 **50 MHz**，所以 13.10 s 就是板上应得的时间量级（仿真实测值）；
  若按收尾轮推算的等效 Fmax 约 67.6 MHz 去算，同一份 200 迭代镜像只需约 **9.69 s**，
  即**一旦板上实际主频高于 50 MHz，必须按实际主频提高迭代数**才能满足赛题 ≥10 s 的要求；本条是提醒，不是要改频率。

### 6.2 已取得的（V12，200 迭代性能镜像，50 MHz 仿真）—— **≥10 s 已在仿真内实测成立**

镜像：`--iterations 200 --cpu-mhz 50`（`coremark.elf` `5EDB52BA…`、`program.bin` `B0A03D96…`，与 `manifest.json` 的 `artifact_sha256` 逐项一致），归档于 `09_validation_results/basic_final/coremark/performance_200_iter/`。

串口解出的报告（**日志中 `PROGRESS`/`LIVE` 行会插进固件输出中间，下面是去掉交错后的重建**）：
```
2K performance run parameters for coremark.
CoreMark Size    : 666
Total ticks      : 655032761
Total time (secs): 13          <- HAS_FLOAT=0，用 %d 打印，小数被截断
Iterations/Sec   : 15          <- 同上，整数截断
Iterations       : 200
Compiler version : GCC7.1.1 20170509
Compiler flags   : -march=rv32im -mabi=ilp32 -mcmodel=medlow -O2 -ffreestanding -fno-builtin -fno-common
                   -ffunction-sections -fdata-sections -falign-functions=4 -falign-jumps=4 -falign-loops=4
                   -DCPU_FREQ_MHZ=50 -DITERATIONS=200 -DPERFORMANCE_RUN=1
Memory location  : STATIC
seedcrc          : 0xe9f5
[0]crclist       : 0xe714
[0]crcmatrix     : 0x1fd7
[0]crcstate      : 0x8e3a
[0]crcfinal      : 0x382f
Correct operation validated. See readme.txt for run and reporting rules.
```
**没有 `Errors detected`** —— `total_errors == 0`。

> **必须如实说明的截断**：上面这块是"去掉交错后的**重建**"，日志本身**没有**收到完整的 `Correct operation validated.` 那一行。
> 日志里最后解到的字符是 `# Correct operation v`（第 2827 行），其后 12000 个周期 TB 就 `$finish` 了（`stop_cycle=658177948`，
> `$finish` 在 `tb/integration/tb_coremark_uart.sv(319)`），所以 `alidated. See readme.txt …` 这段没有传完。
> **这不影响结论**：`core_main.c:324` 的 `ee_printf("Correct operation validated. …")` **只在 `total_errors==0` 分支里**执行
>（`core_main.c:323` 是 `if (total_errors==0)`），而 `Errors detected` 只在 `total_errors>0` 分支（`core_main.c:341-342`）。
> 两个分支互斥，因此**只要收到该行的任意前缀，就等于 `total_errors==0`**；再加上 5 个 CRC 检查点全部等于黄金值，结论成立。
> TB 的缺点（收尾只等 12000 周期）已记入 §8 的遗留改进项。

原始 64 位 tick（`core_portme.c:44` 新增行，日志里 `CPM_TICKS` 前缀被交错吃掉）：
```
hi=0 lo=655213650      -> t1 = 655,213,650，无 32 位回绕；t0 = 180,889
```

仿真侧计数：`cycles=658177948 retires=61293205 traps=0 faults=0 uart_chars=652 txd_writes=652`，`TEST_PASS T_COREMARK_BOUNDED`，`Errors: 0, Warnings: 0`，vsim 墙钟 **38 分 01 秒**。

**换算（tick 数为仿真实测，秒数与分数为算术推导）**：
- `total_time = 655,032,761 ticks`；50,000,000 Hz → **13.1007 s ≥ 10 s** → 该镜像在仿真内**实测满足**赛题 ≥10 s
- 先前线性推算值 654,980,800 与实测差 **0.008%** → 推算方法被证实
- `Iterations/Sec = 200 / 13.10065522 = 15.2665` → CoreMark/MHz = 15.2665 / 50 = **0.3053**

### 6.3 未取得的（必须显式声明）

- `13.1007 s` 是**仿真实测**，**不是板上实测**。仿真只证明"功能、CRC 与 tick 数符合预期"，不能当作板上用时的证据。
- 板上真实 CoreMark 分数、板上 ≥10 s 判据：**NOT RUN**（V14/V15/V16）。
- `Total ticks` 打印被 32 位截断，长跑必须取 `core_portme.c` 新增的 `CPM_TICKS hi=... lo=...` 行或 ILA；本次 `hi=0` 已证实未回绕。
- **本固件永远打印不出标准 `CoreMark 1.0 : <分数>` 行**：`tests/example/coremark/core_portme.h:16` 是 `#define HAS_FLOAT 0`，而 `core_main.c:325-339` 把分数行整段包在 `#if HAS_FLOAT` 里；同时 `tests/example/lib/xprintf.c` 无浮点能力（`:66` 自带注释 `<xprintf lacks floating point support>`，`:122-123` 的 `default: xputc(c);` 对 `%f` 只回显一个 `f` 且不消耗 double）。因此 `Total time (secs): 13` / `Iterations/Sec : 15` 都是整数截断。分数只能由 `Total ticks` + 已知 50 MHz 算出。修正属**软件/port** 改动（换支持 `%f` 的 printf 并重建镜像），不在本轮 RTL+平台范围；且不改也能满足"≥10 s 有效结果"（判据是 `Total ticks`）。

### 6.4 性能瓶颈（已定位，本轮未改）

`rtl/core/axi_read_engine.v` 的 `req_ready` 只在 `RD_IDLE` 拉高，导致**每次取指 9 个周期**，IPC 仅约 0.093，CoreMark/MHz 约 0.305。
这属于取指通路改造（后续优化项），本轮不动。

---

## 7. 赛题符合性对照（基本版本 vs 高级/统一）

| 赛题要求（基本版本） | 状态 | 证据 / 说明 |
|---|---|---|
| 32×32-bit GPR | PASS | V2 用例 1–7；x0 恒零由 `regs.v` 强制 |
| RV32I 指令集 | PASS | V2 全 15 例；`-march=rv32im` |
| M 扩展 | PASS | V2 用例 3 |
| ≥3 级流水线 + 数据冒险处理 / 旁路 / 停顿 / 分支 | PASS（3 级 IF/ID/EX） | 1 深 skid `pipe_slot`；`retire_ctrl` 单退休契约；**唯一**冒险机制是 `regs.v` 内同周期读写旁路；`ex` 实例化时 `.csr_we_i(1'b0)`、`.mem_rdata_i(32'd0)`，实为 ALU+分支解析 |
| 原生 AXI + 互联 | PASS | V5 20/20、V6 64/64、V7 20/20；S1 修复后可综合 |
| 程序 RAM + 数据 RAM | PASS | 程序 RAM 4096 字 `WRITE_ENABLE(0)` @0x00000000；数据 RAM 4096 字 @0x10000000；V8 40/40 |
| UART / GPIO / Timer / SPI / IRQ 控制器 | PASS | 从设备映射 2=0x20000000 timer、3=0x30000000 uart、4=0x40000000 gpio、5=0x50000000 spi、6=0x60003000 irq_ctrl；V2 用例 12–15 |
| CSR / 同步异常 / MRET / 中断 | PASS | V2 用例 6–11、15；优先级 外部 > 软件 > 定时器；`trap_enter` 原子覆盖 status/mepc/mcause/mtval 且不增 `minstret` |
| 启动与陷阱处理 | PASS | `start.S` + `init.c` + `trap_entry.S` + `trap_handler.c` 全链路 |
| 时序与 CoreMark 用时 | PASS（仿真内） | V10 `All Constraints Met`；V13 镜像构建通过；V12 仿真实测 655,032,761 ticks = 13.1007 s ≥ 10 s，见 §6.2；**板上仍 NOT RUN** |
| 盘古板顶层、引脚约束、PDS 工程 | PASS | `pango_native_top.v` + `.fdc` + `.pcf` + `platform/pango_native/build.tcl`；V10 |
| 上板下载验证 | **NOT RUN** | 无物理板 |

| 高级 / 统一评估项 | 状态 |
|---|---|
| Cache | 未实现（**本轮范围外，不列为基本版本缺陷**） |
| 动态分支预测 | 未实现（同上） |
| DDR | 未实现（同上） |
| DMA | 未实现（同上） |
| 完整 AI 应用 | 未实现（同上） |
| 性能分析文档（赛题要求提交） | **未完成**（方法学与仿真/综合数据齐备，但赛题要求的是基于**板上实测**的分数与波形；缺板 → 不能写成已完成） |
| CoreMark 关键算法 ILA 波形（赛题要求提交） | **NOT RUN**（无板，未采集；探针清单与触发配方已在 `platform/pango_native/README.md` 写好） |

---

## 8. 已知限制与未验证项（不得被解读为通过）

1. **没有上板**：下载、串口实测、按键复位实测、ILA 采集、板上 CoreMark 全部 `NOT RUN`。
2. **比特流 SCBV 未设置**：`Bitstream-2001` 告警存在，是否可烧录未验证。
3. **`Total ticks` 32 位截断**：长跑用时只能取 `CPM_TICKS` 行或 ILA。
4. **CoreMark ≥10 s 只在仿真内实测**：`13.1007 s @50 MHz` 来自仿真 tick 数（`655032761`），**不是板上实测**；板上仍需复现。
5. **CoreMark 成功行在日志中被截断**：TB 匹配到 `Correct operation` 后只等 12000 周期就 `$finish`，日志只收到 `# Correct operation v`。结论仍成立（该前缀只可能来自 `total_errors==0` 分支），但**无法从日志引用完整原文**。
6. **本固件打印不出标准 `CoreMark 1.0 : <分数>` 行**：`HAS_FLOAT 0` 把该分支整段预处理剔除，见 §6.3。
7. **riscv-compliance 官方套件未全量执行**（V17）。
8. **性能瓶颈未改**：取指 9 周期/次，IPC ≈ 0.093，CoreMark/MHz ≈ 0.305。
9. **数据 RAM 走分布式 LUTRAM**：见 §4 资源效率发现。
10. `led[0..7]` / `uart_*` / `key` / `rst_n` 无 I/O 时序约束（`Timing-4087/-4086`），FDC 有意不加 blanket false path。
11. PDS license 24 天后失效。
12. **UART 引脚 B24/C24 没有权威来源**（收尾轮新增）：`platform/pango_native/pango_native.pcf` 的 clk/rst_n/led[0..7] 与板厂 LED 参考工程一致，`key` 也对得上 `_pin_check/key_led`，但 UART TX/RX 两个引脚在**所有**参考约束文件里都找不到，只出现在本工程自己的 `platform/pango_native/README.md`。上板前必须按官方板卡资料核对，见 `09_validation_results/basic_closure/01_PLAN_RECONCILIATION.md` §5 B1。
13. **板卡资料缺失**：`07_board_references` 只有板厂示例工程与引脚核对工程，**没有原理图、没有用户手册**；板卡商品名 `MES2L676-100HP` 无独立来源。SCBV 因此无法确定，**未猜值**（B2/B3）。
14. **收尾轮的历史属性写法已被修正**：第 5 项改动原先用的 `(* keep = "true" *)` 被 PDS 拒绝（`PAP_KEEP` 值非法、`ASYNC_REG` 非法），19 个观测点里 14 个 + 2 个计数器**没有进实现网表**；收尾轮改成 `syn_keep` / `syn_preserve` 并重跑验证（V18）。详见 `04_change_notes/basic-final-implementation.md` §13。

### 8.1 遗留改进项（小，非阻塞）

| 项 | 改法 | 收益 |
|---|---|---|
| `tb_coremark_uart.sv` 收尾太早 | `wait(report_seen)` 后的 `repeat(12000)` 加长到覆盖整条成功行（或改为等 `uart_chars` 稳定 / 等 `"rules."`） | 日志能留下完整 `Correct operation validated.` 原文 |
| 固件分数行缺失 | 让 `ee_printf` 支持 `%f`（或换支持浮点的 printf）、必要时置 `HAS_FLOAT 1`，再重建镜像 | 能打印标准 `CoreMark 1.0 : …` 行 |
| 数据 RAM 改同步读 | 见 §4 | LUT 7761 → ~5681 |

---

## 9. 归档位置

| 内容 | 路径 |
|---|---|
| 本台账 | `E:\file\pango\project\05_verification\native-basic-final-status.md` |
| 改动记录 | `E:\file\pango\project\04_change_notes\basic-final-implementation.md` |
| 交付总报告（问题清单 + 命令 + 日志） | `E:\file\pango\project\09_validation_results\basic_final\BASIC_FINAL_REPORT.md` |
| 回归日志 | `09_validation_results\basic_final\regressions/*.txt` |
| halt/reset 明细 | `09_validation_results\basic_final\halt_reset/` |
| PDS 日志与产物 | `09_validation_results\basic_final\pds/` |
| CoreMark 镜像与日志 | `09_validation_results\basic_final\coremark/` |
| 全部源文件 SHA256 | `09_validation_results\basic_final\FINAL_SOURCE_SHA256.csv`（**旧清单，999 行，对应修复前版本**） |

**收尾轮（任务 m02843）证据根 `E:\file\pango\project\09_validation_results\basic_closure\`**：

| 内容 | 文件 |
|---|---|
| 基础版计划任务对账表（交付物 1） | `01_PLAN_RECONCILIATION.md` |
| 本轮改动与遗留问题（交付物 2） | `02_CLOSURE_CHANGES_AND_OPEN_ISSUES.md` |
| **最终源码 SHA256 清单（961 行，对应最终代码）** | `03_SOURCE_SHA256.csv` |
| 固件/初始化镜像/比特流对应关系（交付物 4） | `04_FIRMWARE_IMAGE_BITSTREAM.md` |
| 精确命令（交付物 5） | `05_COMMANDS.md` |
| 上板准备步骤（交付物 6） | `06_BOARD_BRINGUP.md` |
| 最终交付说明（交付物 7） | `BASIC_CLOSURE_FINAL_DELIVERY.md` |
| 收尾轮 PDS 重跑全部日志与产物 | `pds_rerun/` |
| 备份前 SHA256 记录 | `E:\file\pango\backups\tinyriscv_before_closure_20261011_1452.sha256.csv`（1335 行，全树） |

---

## 10. 比赛收口轮（2026-10-18，T4+LSU 候选）

- **正式代码位置**：生产树 `firmware/code`（本轮按候选逐文件合入必要源码/测试/构建脚本，排除 `build/`、`.sim_runs/`、`__pycache__`、`transcript`、`*.gitasis`、`*.baseline_hold0`，未整目录覆盖；生产独有 `platform/pango_native/base_project.pds`、`build.pds` 保留）。
- **冻结版本/身份**：
  - 候选源码快照 `evidence/records/bottleneck_audit/contest_final/freeze_20261018/candidate_src.zip`（候选树 168 源文件）；合并/冻结清单同目录 `merge_manifest_20261018.csv`、`manifest_sha256.tsv`。
  - 宏 ON `rtl/core/soc_config.vh` SHA256 `BD9A2677B58A093AB5BEE6027193BE34B9174C8464FEFBCF2E6957C22585AE2D`；宏全关 `5EAB5871…`（独立 clean 树）。
  - 合并前 HEAD `e60a1f4`；合并前生产树备份 `freeze_20261018/production_before_merge.zip`（回退版本）。
  - 正式位流（3,791,112 B）：cand perf `B3ACA53A7F1F5E8A…`、B0 perf `81C3D28272C34462…`、cand val `0397080AFD1177D8…`、B0 val `26E915CE32260273…`；ILA 调试位流 `CC351A11C90FC3F1…`。
  - 600 迭代固件 hex：perf `BD8BDFE5…`/`ED1BAFD7…`；val `E305533B…`/`FFFB01DC…`（同模式两版逐字节一致）。
- **有效成绩**（600 迭代、27 MHz、2000B data；CSV `evidence/records/bottleneck_audit/results/contest_final_600iter_ab.csv`）：
  - cand perf：339,639,071 ticks / 12 s / 1.7666 CoreMark/MHz / 47.698 CoreMark / crcfinal 0xbd59；B0 perf：481,086,155 / 17 s / 1.2472 / 33.674 → **+41.6463%**。
  - cand val：340,038,594 / 12 s / 1.7645 / 47.642 / 0xb8a0；B0 val：481,756,431 / 17 s / 1.2454 / 33.627 → +41.677%。
  - 四个成绩位流均 **All Constraints Met**；cand LUT 12,641 / FF 7,358，B0 LUT 12,572 / FF 7,398。
  - 合并前回归：宏 ON 13/13 PASS（`contest_final/logs/regression_on/`），宏全关 13/13 PASS（`regression_off/`）。
  - **合并后回归（生产树 `firmware/code`）：13/13 PASS**，日志 `contest_final/logs/regression_merged/`（13 个 suite log + summary.txt）。
- **证据路径**：板测原始 UART `evidence/records/bottleneck_audit/board/phase2/*.txt`；PDS 日志 `contest_final/logs/pds_*.log`；ILA 采集 `contest_final/logs/ila_capture_export3/`（`ila_samples_ascii.prn` 239,345 B、`ila_capture.wdf` 287,454 B、`ila_capture.dprj`）；触发值/人工步骤 `contest_final/logs/ila_gui_manual/`。
- **ILA 状态（如实记录）**：已有真实采样（512 采样 × 224 信号；PC 迹与指令逐条匹配 `firmware.dump` 的 `core_list_find`/`core_bench_list`，证明 CPU 在跑 CoreMark 链表算法）。**调试电路存在时序问题**：DebugCore_JCLK→JCLK hold WHS −0.326 ns（slow）/−0.135 ns（fast，仅 1 端点），用户 clk 域全部通过；该位流仅作调试用、不作为成绩位流。触发条件尚未闭环（Match Unit 未启用、值为全 X，实际为自由运行采集）。→ **已有采样，调试电路时序问题及正式波形验收待补。**
- **旧结论更正**：§8 第 1 条“无上板 / NOT RUN”已过期——本轮已完成上板 600 迭代 A/B（12 s / 17 s，均 ≥10 s）与 ILA 调试版上板采集；§8 其余限制（USB 易失配置、SCBV 未设置、长程仿真未全跑等）仍有效。
- **剩余问题**：
  1) ILA 触发条件需在 Fabric Debugger GUI 人工启用 Match Unit 并写入 224 位触发值（步骤与粘贴值见 `contest_final/logs/ila_gui_manual/trigger_values_paste.txt`），再做正式波形验收；
  2) ILA 调试版 DebugCore_JCLK hold 违例需修复约束或在调试版说明中接受（不影响成绩位流）；
  3) T4 在 600 迭代下的对照未单独重建（历史 T4 板上成绩为旧迭代数，不能与本轮直接混列）。
- **重建入口（直接引用，不重写）**：回归 `firmware/code/tools/run_regression.ps1 -OutDir <dir>`；PDS `firmware/code/platform/pango_native/build.tcl`（CWD 必须是 `<tree>/build/pango_native`）；位流/下载命令见 `evidence/records/bottleneck_audit/results/commands.md` §3.6。
