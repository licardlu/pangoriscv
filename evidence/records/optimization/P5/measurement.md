# P5 · 时钟频率收敛实验（2026-10-17）

> 结论：**当前设计在 50 MHz 约束（20 ns）下时序收敛**，0 失败端点，位流已生成。
> 这是"约束收敛实验"的结果，**不是**板上实测最高频率（板载晶振固定 27 MHz）。
> 证据等级：PDS 真实实现产物（非仿真）。

---

## 1. 实验设置

| 项 | 值 |
|---|---|
| 约束文件 | `platform/pango_native/pango_native_50mhz_overconstraint.fdc` |
| 有效时钟 | `create_clock -name clk -period 20 -waveform {0 10}`（日志确认已下发） |
| 器件 | PG2L100H-6FBG676 |
| RTL 配置 | CACHE / PREDICT / PERF 三开关全开（与交付位流一致），BTB 128 项 |
| 镜像 | `score400`（400 迭代 CoreMark） |
| 运行目录 | `build/pango_50mhz`（**全新目录，无陈旧产物**） |

> 上一轮实验曾因运行目录里残留 27 MHz 的 `timing_summary` 文件而得出"WNS +16.440 ns"
> 的矛盾结果（20 ns 周期下不可能）。本轮先删除整个运行目录再跑，时序汇总时间戳
> 20:24:07 与本次 `report_timing` 阶段一致，数据可信。

---

## 2. 结果

```
Design Summary : All Constraints Met.
```

| 角 | 项 | 值 | 失败端点 |
|---|---|---|---|
| Slow | Setup WNS | **+2.372 ns** | **0 / 66,247** |
| Slow | Hold WHS | **+0.024 ns** | 0 / 66,247 |
| — | Recovery / Removal / Min Pulse Width | 空（无违例） | — |

位流：`generate_bitstream/pangoriscv_top.sbit`，3,791,112 B，
SHA256 `7321AB61E1215A19E95821E4AC6FFFD9A8599586F250327C898433188245A3E9`。

---

## 3. 口径（必须照此写）

| 说法 | 是否允许 |
|---|---|
| "交付位流在 27 MHz 板载时钟约束下时序合规" | ✅ 允许（`pango_native.fdc`，WNS +16.440@37.037 ns） |
| "设计在 50 MHz 约束下时序收敛，WNS +2.372 ns，0 失败" | ✅ 允许（本实验，过约束） |
| "实测最高工作频率 50 MHz" | ❌ 不允许——板卡没有 50 MHz 晶振，未上板运行 |
| "关键路径 17.63 ns ⇒ Fmax ≈ 56.7 MHz" | ⚠️ 只能写成"由 slack 推算"，不能写成实测 |

推算值仅为参考：20 − 2.372 = 17.63 ns ⇒ 约 56.7 MHz。按赛题诚信边界，
**工具按 slack 推算的频率不得报成实测最高频率**。

---

## 4. 对三项评分的意义

指标②（时钟频率）此前只有"27 MHz 约束值"一个可报数；本实验补上了**收敛上界**这一侧：
设计余量足够在 50 MHz 下收敛。若要真正提高该项得分，还需在板级引入 PLL 把
27 MHz 倍频后驱动内核，并按新频率重跑全部验证——那是板级改造，不在本轮范围。

---

## 5. 复现命令

```powershell
$env:PANGO_NATIVE_REPO = "<repo>/firmware/code"
$env:PANGO_NATIVE_BOARD_DIR = "<repo>/firmware/code/platform/pango_native"
$env:NATIVE_IMAGE_DIR = "<repo>/firmware/code/build/native_software/coremark/performance/score400"
$env:PANGO_NATIVE_FDC = "<repo>/firmware/code/platform/pango_native/pango_native_50mhz_overconstraint.fdc"
cd "<repo>/firmware/code/build/pango_50mhz"     # 必须是全新空目录
pds_shell.exe -file "<repo>/firmware/code/platform/pango_native/build.tcl"
```

注意：PDS 把流程产物写到**当前工作目录**，不是 `build.tcl` 里 `cd` 的目录。
每次实验前清空工作目录，否则会读到上一次的 `timing_summary`。
