# pangoriscv — RV32IM 处理器核 + 原生 AXI4 SoC

用 Verilog 实现的一款 RISC-V RV32IM 处理器核，自带原生 AXI4 总线与 SoC，已在 Pango PG2L100H 开发板上
跑通 CoreMark（400 次迭代，5 项 CRC 全部符合）。

> **当前状态（2026-10-18 独立复核）**：最新交付为 **768 迭代、2.6740 CoreMark/MHz（RTL 仿真，未上板）**；
> 下文的 400 迭代 / 1.35 / 12,694 LUT / “四级流水线”等均为历史版本。
> 完整问题、验收缺口与修复顺序见 **[docs/verification.md](docs/verification.md)**。

> **面积 / 效率专项（2026-10-21 起）**：本阶段**只做面积与资源效率**，性能只要求"不回退"。
> 动手前必读 **[docs/architecture/module-area-plan.md](docs/architecture/module-area-plan.md)**
> （34 个模块的 11 字段面积合同）与 [area-budget.csv](docs/architecture/area-budget.csv)；
> 门禁脚本 `firmware/code/tools/check_area_budget.py`（非零退出不得提交）。
> 冻结基线：tag `score-3.4194-1024`，板上 **3.4194**（1024 迭代 / 11.091 s / 五项 CRC 全对），
> 位流 `bitstream/pangoriscv_i1024.sbit`（SHA256 `8D12C9D1…5FA6A643`）。

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
  verification.md       验证计划、状态与问题总表（含问题台账）
  contest/              赛题原文与要求摘录
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
`docs/verification.md`（问题台账）与 `docs/lessons/rules.md`（动手清单）。

## 入库范围

仓库只收**作品代码、设计文档、验证证据**（约 5 MB）。位流、仿真波形、EDA 构建产物、历史工作树、
原始备份与聊天记录不入库；可再生产物不得入库的规则见 skill `pango-riscv-contest` 的「仓库放置与清理约定」与 `docs/lessons/rules.md`。
