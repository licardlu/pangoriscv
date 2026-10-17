# pangoriscv — RV32IM 处理器核 + 原生 AXI4 SoC

用 Verilog 实现的一款 RISC-V RV32IM 处理器核，自带原生 AXI4 总线与 SoC，已在 Pango PG2L100H 开发板上
跑通 CoreMark（400 次迭代，5 项 CRC 全部符合）。

| 项 | 值 |
|---|---|
| 指令集 | RV32IM（32 位整数、乘除） |
| 流水线 | 四级（取指 / 译码 / 执行 / 写回），输出级独立访存槽 |
| 总线 | 原生 AXI4，取指与访存双通道，读写引擎各自独立 |
| 性能 | **1.35 CoreMark/MHz**（官方整数秒口径；按 tick 精确为 1.25） |
| 板级 | Pango PG2L100H，27 MHz，串口 / LED / 按键 |

## 仓库结构

```
firmware/code/          作品代码（RTL + 测试台 + 仿真脚本 + 固件工具 + 平台约束）
docs/
  design/plans/         方案书与调研
  design/change-notes/  变更记录：改了什么、为什么改
  verification/         验证计划与状态汇总
  contest/              赛题原文与要求摘录
  repo/                 CONTRIBUTING.md / LAYOUT.md（协作约定与入库范围）
evidence/
  logs/                 仿真运行日志（按用例归档）
  records/              上板记录、时序报告、ISA 合规日志、基线证据
bitstream/              发布版位流（见其中 README.md）
scripts/                仓库级辅助脚本
```

代码包内的构建方法、性能数据与横向定位见 [firmware/code/README.md](firmware/code/README.md)。

## 快速开始

```powershell
git clone <repo-url>
cd <repo>

# 1) RTL 自包含编译检查（需要 ModelSim；work 库不入库）
cd firmware/code
vlog -sv -work work +incdir+rtl/core -f sim/native_axi_sources.f

# 2) 构建固件（--toolchain-bin 指向本机 riscv32-unknown-elf 工具链）
python tools/build_native_software.py led_walk --toolchain-bin "<toolchain>\riscv32-unknown-elf-gcc\bin"

# 3) 跑一套仿真
python sim/run_icache_tests.py --modelsim "<ModelSim 目录>"
```

## 协作

两人都可以直接推 `main`。提交信息格式、改动前先 `pull --rebase`、同一份文件避免同时改等约定见
[docs/repo/CONTRIBUTING.md](docs/repo/CONTRIBUTING.md)。

## 入库范围

仓库只收**作品代码、设计文档、验证证据**（约 5 MB）。位流、仿真波形、EDA 构建产物、历史工作树、
原始备份与聊天记录不入库，原因与替代存放方式见 [docs/repo/LAYOUT.md](docs/repo/LAYOUT.md)。
