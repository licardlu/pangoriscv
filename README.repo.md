# pangoriscv — RV32IM 处理器核 + 原生 AXI4 SoC

本仓库是一个两人共同维护的作品仓库：**代码 + 设计文档 + 验证记录**。

## 目录

| 路径 | 内容 |
|---|---|
| `01_code/pangoriscv_own/` | **全部作品代码**：RTL、测试台、仿真脚本、固件构建工具、平台约束、裸机示例（144 文件） |
| `03_plans/` | 计划书与调研文档（含优化的文献综述） |
| `04_change_notes/` | 变更记录：改了什么、为什么改、影响面 |
| `05_verification/` | 验证说明与状态汇总 |
| `06_evidence/` | 证据记录（日志、截屏、上板记录） |
| `08_contest/` | 赛题原文与要求摘录 |
| `scripts/` | 仓库级辅助脚本（`setup_remote.ps1`：远端建库/推送引导） |

代码包内的构建方法、性能数据与横向定位见 `01_code/pangoriscv_own/README.md`。

## 快速开始

```powershell
git clone <repo-url>
cd <repo>

# 1) 看代码结构
Get-ChildItem 01_code/pangoriscv_own

# 2) RTL 自包含编译检查（需要 ModelSim；work 库不入库）
Set-Location 01_code/pangoriscv_own
vlog -sv -work work +incdir+rtl/core -f sim/native_axi_sources.f

# 3) 构建固件（--toolchain-bin 指向本机 riscv32-unknown-elf 工具链）
python tools/build_native_software.py led_walk --toolchain-bin "<toolchain>\riscv32-unknown-elf-gcc\bin"

# 4) 跑一套仿真
python sim/run_icache_tests.py --modelsim "<ModelSim 目录>"
```

## 协作

两人都可以直接推 `main`；具体约定（提交信息格式、改动前先 `pull --rebase`、同一份文件避免同时改）见
[CONTRIBUTING.md](CONTRIBUTING.md)。

## 未纳入仓库的内容

`09_validation_results/`（约 458 MB 的位流、仿真日志与报告归档）、`02_original_backups/`、
`10_codex_chats/`、以及 `01_code/` 下几个历史构建目录（含 EDA 构建产物）**不入库**，原因与替代存放方式见
[REPO_LAYOUT.md](REPO_LAYOUT.md)。
