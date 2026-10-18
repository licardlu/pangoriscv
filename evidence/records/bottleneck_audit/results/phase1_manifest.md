# 阶段 1-D：冻结“前端优化后实验基线”

日期：2026-10-17
对应指令：m02813 第三节 D（保存源码/配置/固件/位流/构建命令/工具版本/时序资源报告/板测日志的哈希清单；旧基线可恢复；未得合并授权前不改正式交付树）

## 1. 冻结对象

| 项 | 位置 | 说明 |
|---|---|---|
| 实验基线源码 | `$AUDIT\frontend_opt\src`（$AUDIT=`E:\file\pango\project\evidence\records\bottleneck_audit`） | 生产交付树的完整副本 + 两个文件的 T4 改动 |
| 冻结副本 | `$AUDIT\frontend_opt\frozen\` | 位流、镜像、时序/资源报告、板测原始 UART、哈希清单 |
| 哈希清单 | `$AUDIT\frontend_opt\frozen\SHA256SUMS.txt`（101 行） | 覆盖 frozen 目录 + `src/rtl`、`src/tb`、`src/platform`、`src/tools` |
| 位流 | `frozen\bitstream\pangoriscv_frontend_opt.sbit` | sha256 `de0f907466874e7113f4e7fc535ff101b416cb185e2686cc5f508fa0aa47b4f8`，3,791,112 B |
| 固件镜像 | `frozen\image\program.hex`、`data.hex` | 400 迭代 performance；sha256 `4ad7de6b…` / `6ffd4571…` |
| 时序/资源报告 | `frozen\reports\pangoriscv_top.rtr`、`multiseed_summary.csv` | All Constraints Met；Setup slow 17.131 / Hold slow 0.103 |
| 构建日志 | `frozen\reports\flow.log`、`run.log`、`build.pds`、`impl.tcl` | 完整 PDS 流程记录 |
| 板测日志 | `frozen\board\base_run{1,2}.txt`、`cand_run{1,2}.txt` | 4 次原始 UART，各 707 B |

## 2. 与旧基线的关系（可恢复性）

| 基线 | 身份 | 恢复方式 |
|---|---|---|
| 旧基线（前端优化前，交付版） | git commit `80e39ce`；位流 sha256 `747C18CA32DEFD118E2237863FD7BDAC9C6DB1E110EE734F6CC485FAF68E6D77` | `git checkout 80e39ce` / `git archive`；位流在 `$AUDIT\baseline_build\artifacts\pangoriscv_i400_baseline_fullfeature.sbit`；源码在 `$AUDIT\baseline_build\src` |
| 新实验基线（前端优化后） | 本文件 §1 | `$AUDIT\frontend_opt\src` + `frozen\bitstream\*` |

- 正式交付树 `firmware\code` **未改动**；合并授权尚未获得（上一轮已明确记为待定）。
- 旧基线源码/位流/构建目录均保留，未被覆盖。

## 3. 身份对应表（源码 ↔ 配置 ↔ 镜像 ↔ 位流 ↔ 日志）

| 环节 | 值 |
|---|---|
| RTL 差异 | 仅 `rtl/core/icache_axi.v`（`3f45a38d…`）与 `rtl/core/ifu_axi.v`（`222c35ae…`），其余 RTL 与基线逐字节相同 |
| 配置 | `rtl/core/soc_config.vh` sha256 `bd9a2677…`（CACHE/PREDICT/PERF 三宏开启，两树相同） |
| 构建脚本 | `platform/pango_native/build.tcl` sha256 `47276929…`（候选副本 pnr hold 修复强度 100 ps/100 迭代；基线版 `bb992560…`） |
| 镜像 | `4ad7de6b…` / `6ffd4571…`（PDS 流程目录内实测 sha256 相同） |
| 位流 | `de0f9074…`（板测 4 次均为该位流、该镜像） |
| 板测 | 基线 320,725,708 ticks / 候选 279,957,350 ticks；CRC 五项两侧相同 |

## 4. 构建与测量命令（可复现）

```powershell
# PDS（cwd = 流程目录；环境变量指向候选树与基线 400 迭代镜像）
$env:PANGO_NATIVE_REPO      = '$AUDIT\frontend_opt\src'
$env:PANGO_NATIVE_BOARD_DIR = '$AUDIT\frontend_opt\src\platform'
$env:NATIVE_IMAGE_DIR       = '$AUDIT\baseline_build\work\tree\build\native_software\coremark\performance'
pds_shell -file build.tcl -work_dir .\build\pango_native

# 板测（先开串口，再下载）
powershell -File $AUDIT\board\capture_uart.ps1 -Port COM13 -Seconds 75 -Out $AUDIT\board\phase1\cand_runN.txt
powershell -File $AUDIT\board\run_flash.ps1 -Script 01b_program_only.tcl `
    -Sbit $AUDIT\frontend_opt\pds\run2_hold100\pangoriscv_top.sbit -TimeoutSec 180
```

工具版本：
- PDS：Fabric Compiler 2022.2-SP6.1 build 138931（安装目录 `E:\donwload\PDS_2022.2-SP6.4\PDS_2022.2-SP6.1`）
- 编译器：GCC7.1.1 20170509（`riscv32-unknown-elf`）
- 仿真：ModelSim 10.6e（阶段 1-A 回归）

## 5. 生效条件与边界

- 冻结在**阶段 1-A 测试核验通过后生效**；若 1-A 发现缺口，先补测试/补日志再冻结对应证据（不修改已冻结位流）。
- 冻结只覆盖仿真/综合/布局布线/板测证据，不含论文与报告文字本身。
- 第二阶段（LSU 控制开销）以本冻结版本为基线；任何新候选必须独立副本、独立 work 库、独立位流，且不得覆盖本冻结位流。
