# pangoriscv — RV32IM 处理器核 + 原生 AXI4 SoC（提交源码包）

本目录为作品提交用的**自研源码包**：全部代码为自主实现，作者与版权人 `pango_lpenghan`，
许可 MIT（见 `LICENSE`）。每个源文件顶部为统一文件头：`Module`（模块名）/ `File`（相对路径）/
`Rev` / `Date` / `Author` / `Brief`。

## 1. 设计概述

| 特性 | 说明 |
|---|---|
| 指令集 | RV32IM：基础整数指令 + M 扩展（乘/除/取余）+ Zicsr 机器模式 CSR；`mtime`/`mtimecmp` 定时器中断与 `MRET` |
| 流水线 | 三级（IF / ID / EX）+ 流水寄存器 `if_id`、`id_ex`；取指解耦（8 项指令队列 + 预测链预取） |
| 分支预测 | BTB + 2 位饱和计数器动态预测 |
| Cache | 两路组相联 I-Cache / D-Cache；AXI4 INCR 突发（ARLEN 最大 7，8 拍 R 握手） |
| 总线 | 原生 AXI4 主机接口 + 互连（`axi_interconnect`）、读写引擎、错误从机 |
| 外设 | AXI4 从机：RAM / UART / SPI / GPIO / timer / irq_ctrl / perf_regs |
| 平台 | Pango PG2L100H，27 MHz，串口 / LED / 按键 |
| 成绩 | CoreMark **1.35 CoreMark/MHz**（官方整数秒口径；按 tick 精确为 1.25）；IPC 0.380（仿真，T1+T3 优化后） |

## 2. 目录结构

```
rtl/core/       处理器核：取指 ifu、译码 id、执行 ex、除法 div、寄存器堆 regs、CSR csr_native、
                流水寄存器 if_id / id_ex、分支预测 branch_predictor、I/D Cache icache_axi / dcache_axi、
                取指/访存引擎 ifu_axi / lsu_axi、AXI 读写引擎、退休控制 retire_ctrl、性能计数 perf_regs、
                顶层 pangoriscv / pangoriscv_axi_top，公共头 defines.v / axi_defs.vh / soc_config.vh / native_axi_macros.vh
rtl/bus/        AXI4 互连与错误从机
rtl/perips/     AXI4 外设：RAM / UART / SPI / GPIO / timer / irq_ctrl / 寄存器从机
rtl/soc/        SoC 顶层（pangoriscv_axi_soc）与板级顶层（pangoriscv_top）
tb/axi/         AXI 总线与引擎测试台（含存储器模型、协议监视器）
tb/unit/        单元测试台（除法适配、流水槽位、Cache、预测器、性能计数、流水、halt/reset）
tb/integration/ 整机测试台（ISA 端到端、CoreMark UART、GPIO 跟踪、LED 行走、SoC 集成、UART 发送）
sim/            回归入口：12 个套件 runner、共享模块 runner_common.py、源码清单 *.f、AXI 一键脚本
tools/          固件构建（build_native_software.py）与整机套件 runner（halt/reset、ISA 端到端、CoreMark A/B）
platform/       Pango PDS 流程与约束：build.tcl、native_sources.tcl、.fdc / .pcf 引脚与时序约束
tests/          裸机示例与整机用例（led_walk、gpio、timer、uart、spi、irq_test、selftest、perf_probe 等）
```

## 3. 板上实测（2026-10-13，同一器件、同一 flow）

| 项目 | 结果 |
|---|---|
| CoreMark（400 次迭代，CRC 校验通过） | `Total ticks 320,541,251`、`Total time (secs) 11`、`Iterations/Sec 36`；5 项 CRC（`seedcrc 0xe9f5` / `[0]crclist 0xe714` / `[0]crcmatrix 0x1fd7` / `[0]crcstate 0x8e3a` / `[0]crcfinal 0x25b5`）全部符合，`Correct operation validated` |
| 换算成绩（27 MHz） | **1.35 CoreMark/MHz**（官方整数秒口径 `400/11/27`）；按 tick 精确 `400/(320,541,251/27e6)/27` = **1.25** |
| 相对本设计未优化版 | 未优化基线 0.61 CoreMark/MHz（656,167,771 ticks）→ **2.04×–2.18×**；仿真同镜像 A/B：327,998,564 → 259,852,944（取指队列）→ 162,025,576（+Cache 命中路径压平）= **2.024×**，IPC 0.1871 → 0.3802，两侧 CRC 全同 |
| 资源 | CLMA 2,694 / 11,675（24%）；总 LUT 12,694 / 66,600（19.06%） |
| 时序 | Setup 慢角 +16.262 ns、快角 +24.216 ns；Hold 慢角 +0.024 ns、快角 +0.014 ns；**0 失败 / 48,214 端点** |
| 位流 | `pangoriscv_i400.sbit` 3,791,112 B，sha256 `F8254F66EF9C78B53E3DD4E6516BA55BAA2F00C7C76EB2379D78FEC8962CE77C` |
| 仿真回归 | 13 个套件全绿：单元（5）/ I-Cache / D-Cache / 分支预测 / 流水 / 性能计数 / GPIO 跟踪 / halt-reset（5）/ 数据引擎（32）/ 互连（4）/ RAM（8）/ IFU 引擎（4）/ ISA 端到端（15） |

## 4. 构建与验证

所有脚本都以**本包根目录**为工作目录运行（默认仓库路径由脚本自身位置推导，无需改代码）：

```powershell
# RTL 自包含编译检查（ModelSim）
vlog -sv -work work +incdir+rtl/core -f sim/native_axi_sources.f

# 固件构建（--toolchain-bin 指向本机 riscv32-unknown-elf 工具链的 bin 目录）
python tools/build_native_software.py led_walk `
  --toolchain-bin "<toolchain>\riscv32-unknown-elf-gcc\bin"

# 仿真套件（--repo 默认即本包根目录）
python sim/run_icache_tests.py --modelsim "<ModelSim 安装目录>"
```

* 综合/实现：Pango Design Suite 2022.2-SP6.1（`platform/pango_native/` 下的 Tcl 流程，
  `rtl/core/soc_config.vh` 选择 CACHE / PREDICT / PERF 三个编译开关；交付位流以三个开关全开构建）。
* 仿真：ModelSim 2020.4（`sim/` 下的 runner，`sim/native_axi_sources.f` 是唯一源码清单，含
  `+incdir+rtl/core`）；已验证本包 RTL 独立编译 **0 error / 0 warning**。
* 固件：`riscv32-unknown-elf-gcc`（`tools/build_native_software.py`，说明见 `tools/NATIVE_SOFTWARE.md`）。
* **外部路径**（不属于本包，需按本机填写）：`--modelsim`（ModelSim 安装目录，默认 `E:\donwload\win64`）、
  `--toolchain-bin`（riscv32-unknown-elf-gcc 的 bin 目录）；`platform/pango_native/README.md` 中的
  PDS 可执行文件路径同理。缺省的绝对路径只影响开箱即用，不影响源码内容。

## 5. 第三方说明

本包**收录** CoreMark v1.01（EEMBC）官方源码，位于 `tests/example/coremark/`，并随附其
`LICENSE.md`。除裸机移植层 `core_portme.c`/`core_portme.h` 与本作品自行实现的格式化输出
`ee_printf.c` 外，`core_*.c`、`coremark.h` 与官方发布版逐字节一致（SHA256 已核对），
基准本体未做任何裁剪或修改。
EDA 厂商提供的辅助脚本（如 Pango 的 `BinToMem_CLI.py`）未纳入。示例固件中的格式化输出
（`tests/example/lib/xprintf.c`、`include/xprintf.h`）为本作品自行实现。

## 6. 许可与署名

MIT License，Copyright (c) 2026 pango_lpenghan。所有源文件头部 `Author : pango_lpenghan`。

## 7. 性能定位（横向参照）

同口径 CoreMark/MHz 公开数据（均为 RV32 软核，已核对原始出处）：

| 核 | 配置 | CoreMark/MHz |
|---|---|---|
| 本设计 | RV32IM，三级流水 + I/D-Cache + BTB 动态预测 + 原生 AXI4 | **1.35**（整数秒口径）/ 1.25（tick 精确） |
| lowRISC Ibex `micro` | RV32EC，2 级流水 | 0.904 |
| lowRISC Ibex `small` | RV32IMC，3 周期乘法 | 2.47 |
| lowRISC Ibex `maxperf` | +1 周期乘法 + 分支目标 ALU + 写回级 | 3.13 |
| TORVS（SBESC 2025，轻量双发射） | RV32I，五级双发射 | 1.176–1.600 |

定位：**中上**——高于 Ibex 最弱配置，落在轻量双发射设计的区间内，低于 Ibex 的 `small`/`maxperf`
（其优势来自更宽的发射与更短的分支/乘法延迟）。本设计的瓶颈已定位在**前端取指供给**
（优化前 `if_wait` 占 65.5%），取指队列 + Cache 命中路径压平两项已把 IPC 从 0.187 提到 0.380；
进一步提分空间在 I-Cache 单拍命中、双发射与乘法器延迟（本轮范围外，未做）。
频率侧：27 MHz 约束下 Setup 余量 +16.262 ns（周期 37.037 ns）⇒ 关键路径 ≈20.8 ns，理论上限约 48 MHz。
