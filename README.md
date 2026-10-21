# pangoriscv — RV32IM 处理器核 + 原生 AXI4 SoC

用 Verilog 实现的一款 RISC-V RV32IM 处理器核，自带原生 AXI4 总线与 SoC，已在 Pango PG2L100H 开发板上
跑通 CoreMark（400 次迭代，5 项 CRC 全部符合）。

> **当前状态（2026-10-18 独立复核）**：最新交付为 **768 迭代、2.6740 CoreMark/MHz（RTL 仿真，未上板）**；
> 下文的 400 迭代 / 1.35 / 12,694 LUT / “四级流水线”等均为历史版本。
> 完整问题、验收缺口与修复顺序见 **[docs/verification.md](docs/verification.md)**。

> **性能专项（2026-10-21）**：**当前交付 3.8557 CoreMark/MHz**（板上实测，**1152** 迭代 / 11.066 s /
> 五项 CRC 全对且 `Correct operation validated` / 27 MHz `All Constraints Met`，setup +4.484、
> hold +0.032、失败端点 0 / **17,534 LUT / 7,153 FF**）。
> 位流 `bitstream/pangoriscv_i1152_e2.sbit`（同分数、面积 −10.9%）；证据 `evidence/records/optimization/perf-area-lutram/`；
> 计划与 A/B 见 [docs/plan-perf-3.8.md](docs/plan-perf-3.8.md)。
> 相对面积专项定版 3.4222：**+12.7% 分数、站点 +0.9%**（CoreMark/kLUT 0.1901 → **0.2103**）。
>
> **5.2 分 / 120 MHz 专项（2026-10-22，P6）**：结论是**这一版结构到不了**，两个边界都算清楚了，
> 详见 [docs/plan-score-5.2-120mhz-v2.md](docs/plan-score-5.2-120mhz-v2.md) 第 19 节。
> - **分数**：`sim20_o2` 20 迭代 **7,168,871 → 6,960,622 周期（−2.9%）**，IPC 0.962 → 0.991，
>   五项 CRC 与基线一致（`0xe9f5 / 0xe714 / 0x1fd7 / 0x8e3a / 0x4983`）。
>   按周期数折算 **≈3.97 CoreMark/MHz**（**RTL 仿真折算，未上板**，不能当板上实测引用）。
> - **为什么到不了 5.2**：5.2 ⇔ 192,307 周期/迭代 ⇔ 需要 IPC **1.79**。2 发射、零气泡、零停顿的
>   绝对上限是 IPC 2.00（5.80），而 D-Cache 缺失一笔就吃掉 ~13 拍、全run 110,640 笔 ≈ 1.44 M 周期。
>   本版现实区间是 **3.9 ~ 4.4 CM/MHz**；5.2 需要换架构（乱序或 ≥3 发射），不是再调一轮。
> - **为什么到不了 120 MHz**：126 MHz 综合 Setup WNS **−13.490 ns**（路径 ≈21.4 ns，布线后 ≈16.9 ns），
>   要 8.33 ns 得砍掉 **51%**。而唯一有效的切分（RR/EX 拆开、操作数寄存）被"包内 RAW"钉死——
>   lane 1 的操作数必须是 lane 0 这一拍 ALU 输出的函数。本版能收敛的频率约 **59 MHz**。
> - **面积**：LUT **18,723（基线 −106）**、FF 9,478（+3）、S −103；门禁在 FF 行 `exit=1`，
>   原因与判据见 mistakes-log §30。ISA e2e **20/21**（case 21 是探针口径问题，非功能缺陷）。
>
> **面积 / 效率专项（2026-10-21）**：该阶段结论已并入上表，其后不再限制性能改动。
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
