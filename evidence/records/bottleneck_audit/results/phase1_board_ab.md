# 阶段 1-C：板测 A/B（前端优化候选 vs 基线，400 迭代）

日期：2026-10-17 23:01–23:14
对应指令：m02813 第三节 C（同板卡/频率/工具链/固件/种子/迭代数/配置，各 ≥2 次，每次 ≥10 s，先开串口再配置位流）

## 1. 结论

- 同一板卡、同一 27 MHz、同一 400 迭代 performance 固件、同一工具链、同一 CoreMark 种子/迭代数，仅 RTL 位流不同：
  - 基线：`Total ticks = 320,725,708` → **1.2472 CoreMark/MHz**
  - 候选：`Total ticks = 279,957,350` → **1.4288 CoreMark/MHz**
  - 周期减少 **(320,725,708 − 279,957,350) / 320,725,708 = 12.7113 %**
  - 性能提升 `320,725,708 / 279,957,350 − 1 = 14.5623 %`
- 每种配置各跑 2 次，4 次原始 UART 文本全部逐字节可复现（同配置两次文件 sha256 相同）。
- 五组 CRC（`seedcrc/crclist/crcmatrix/crcstate/crcfinal`）两侧逐项相同，且均打印 `Correct operation validated.`。
- 每次运行实际时长 ≥10 s（按精确 ticks / 27 MHz 计算：基线 11.8787 s、候选 10.3688 s；UART 打印的 `Total time (secs)` 是整数截断，不用于计分）。

## 2. 硬件与流程

| 项 | 值 |
|---|---|
| 板卡 | 盘古 PG2L100H（MES2L676-100HP），板载单端 27 MHz 晶振（D18） |
| 器件 ID（读回） | `0x00602899`（PG2L100H-6FBG676） |
| 串口 | COM13，115200 8N1 |
| 下载器 | PANGO USB Cable II（`cdt_js.exe` + `cdt_cfg.exe`，PDS 2022.2-SP6.4） |
| 下载方式 | SRAM 配置（`cfg_program`），非 Flash；done bit = 1 |
| 位流（基线） | `$AUDIT\baseline_build\artifacts\pangoriscv_i400_baseline_fullfeature.sbit`，sha256 `747C18CA32DEFD11…` |
| 位流（候选） | `$AUDIT\frontend_opt\pds\run2_hold100\pangoriscv_top.sbit`，sha256 `DE0F907466874E71…` |
| 固件 | 400 迭代 performance 镜像（`program.hex` sha256 `4AD7DE6B14F6954B…`、`data.hex` `6FFD4571DA129E86…`），两版位流内嵌同一镜像 |
| 编译器 | GCC7.1.1 20170509，参数两侧打印逐字段相同（`-DCPU_FREQ_MHZ=27 -DITERATIONS=400 -DPERFORMANCE_RUN=1`） |

流程（每次运行相同）：
1. 先启动串口采集（`board/capture_uart.ps1 -Port COM13 -Seconds 75 -Out …`），确保不会漏掉上电/复位后的唯一一次打印；
2. 再配置位流（`board/run_flash.ps1 -Script 01b_program_only.tcl -Sbit <sbit> -TimeoutSec 180`），`configuration_tcl.log` 判成功（本轮 4 次均 `cfg_program succeed`）；
3. 采集结束后核对：`CPM_TICKS`、`Total ticks`、5 组 CRC、`Correct operation validated`。

运行时间戳（`configuration_tcl.log` 记录）：
- 基线 run1 23:02:05–23:02:13，run2 23:05:48–23:05:52
- 候选 run1 23:09:28–23:09:31，run2 23:13:05–23:13:09

## 3. 原始 UART 证据（`$AUDIT\board\phase1\`）

| 文件 | 大小 | sha256 | 位流 |
|---|---|---|---|
| `base_run1.txt` | 707 B | `78B7D08D0C6AAB0AB7EE575182C46A21EB458136C78CCE0CF2B0C3CC241A593F` | 基线 |
| `base_run2.txt` | 707 B | `78B7D08D0C6AAB0AB7EE575182C46A21EB458136C78CCE0CF2B0C3CC241A593F` | 基线 |
| `cand_run1.txt` | 707 B | `D4DC2B50609BDF9EB8FFBB4158750898E9D803F5F72EFBECED85EC7905062555` | 候选 |
| `cand_run2.txt` | 707 B | `D4DC2B50609BDF9EB8FFBB4158750898E9D803F5F72EFBECED85EC7905062555` | 候选 |

同配置两次运行逐字节相同 ⇒ 板测结果在该环境下确定、可复现。原始内容（基线 run1，候选仅数值不同）：

```
CPM_TICKS hi=0 lo=320783213
2K performance run parameters for coremark.
CoreMark Size    : 666
Total ticks      : 320725708
Total time (secs): 11
Iterations/Sec   : 36
Iterations       : 400
Compiler version : GCC7.1.1 20170509
Compiler flags   : -march=rv32im -mabi=ilp32 -mcmodel=medlow -O2 -ffreestanding -fno-builtin -fno-common -ffunction-sections -fdata-sections -falign-functions=4 -falign-jumps=4 -falign-loops=4 -DCPU_FREQ_MHZ=27 -DITERATIONS=400 -DPERFORMANCE_RUN=1
Memory location  : STATIC
seedcrc          : 0xe9f5
[0]crclist       : 0xe714
[0]crcmatrix     : 0x1fd7
[0]crcstate      : 0x8e3a
[0]crcfinal      : 0x25b5
Correct operation validated. See readme.txt for run and reporting rules.
```

## 4. 计分（精确 ticks，不做整数秒截断）

CPU_HZ = 27,000,000；iterations = 400。

| 指标 | 基线 | 候选 | 差异 |
|---|---|---|---|
| `Total ticks`（CPU 周期） | 320,725,708 | 279,957,350 | −40,768,358 |
| 运行秒数 = ticks / 27 MHz | 11.8787 s | 10.3688 s | −1.5099 s |
| 迭代/秒 = 400 / 秒数 | 33.6736 | 38.5773 | +14.56 % |
| CoreMark = 迭代/秒 | 33.6736 | 38.5773 | +4.9037 |
| CoreMark/MHz = 400 × 10⁶ / ticks | 1.247172 | 1.428789 | +0.181617 |
| 周期减少率 | — | — | **12.7113 %** |
| 性能提升率 = base/cand − 1 | — | — | **14.5623 %** |

- 计时窗口：固件用 CPU 周期计数器（`rdcycle`）在 CoreMark 算法区间采样 `start_time/stop_time`，`Total ticks` = 二者之差，单位是 CPU 周期、不含串口打印时间（源码核验见 `results/phase1_test_acceptance.md`）。
- `CPM_TICKS hi/lo` 是另一处周期计数值（两侧分别 320,783,213 / 280,012,186），与 `Total ticks` 相差固定采样偏移，不影响计分；用 `Total ticks` 计分。
- 两次正式运行都 ≥10 s（精确值 11.8787 s / 10.3688 s），无需改迭代数。

## 5. 正确性检查（板测层面）

| 检查项 | 基线（2 次） | 候选（2 次） |
|---|---|---|
| `seedcrc` | 0xe9f5 | 0xe9f5 |
| `crclist` | 0xe714 | 0xe714 |
| `crcmatrix` | 0x1fd7 | 0x1fd7 |
| `crcstate` | 0x8e3a | 0x8e3a |
| `crcfinal` | 0x25b5 | 0x25b5 |
| `Correct operation validated` | 有 | 有 |
| CoreMark Size / Iterations | 666 / 400 | 666 / 400 |

CRC + validated 与仿真侧（`$AUDIT\frontend_opt\ab\`）完全一致，说明“仿真同镜像 A/B”与“板测 A/B”是同一固件、同一算法结果。

## 6. 与上一轮板测的关系

上一轮已归档的捕获（基线 sha `78B7D08D…`、候选 sha `D4DC2B50…`）与本次 4 次重采逐字节相同，数值完全一致 ⇒ 本轮为**独立重复采集**，不是复用历史数值。

## 7. NOT RUN / 边界

- 未改 Flash 配置、未做掉电保持测试；本 A/B 全部为 SRAM 配置后单次运行。
- 未测不同频率/电压点（赛题与基线均固定 27 MHz、板载晶振）。
- 未在其它板卡复测（仅这一块已核实的 PG2L100H 板）。
- 正式成绩仍以“同条件 A/B + 精确 ticks”表述；不把本轮收益外推到不同固件/迭代数。
