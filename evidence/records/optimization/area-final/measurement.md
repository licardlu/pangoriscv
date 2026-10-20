# area-final：面积优化后的交付位流 —— 板上 **3.4222**（11.082 s，五项 CRC 全对）

日期：2026-10-21（板上实测 00:50–00:52）
性质：**定版**：M1（去仪表化）+ M3（BTB 缩位宽）+ M4a（取指队列 8）三项落地后的交付位流

---

## 1. 三项指标（同一份位流）

| 指标 | 数值 | 口径 |
|---|---|---|
| **① CoreMark/MHz** | **3.4222** | 板上串口原始输出：`Total ticks 299,226,614 / Iterations 1024` → `1024/299,226,614×1e6`；用时 **11.082 s ≥ 10 s** |
| **② 时钟频率** | **27 MHz 约束**，`All Constraints Met` | `multiseed_summary.csv`：`single,OK,OK`，setup **+12.972 / +21.131**，hold **+0.020 / +0.015**，失败端点 **0**（本文件是**约束频率**，不是"最高频率实测"） |
| **③ CoreMark/kLUT** | **0.1901** | `3.4222 / 18.006`（LUT 取自 `device_map` 的 `Used` 行） |

板上原始输出：`board_uart_score.txt`
```
Total ticks      : 299226614
Total time (secs): 11
Iterations       : 1024
seedcrc 0xe9f5  crclist 0xe714  crcmatrix 0x1fd7  crcstate 0x8e3a  crcfinal 0x9ce8
Correct operation validated.
```

## 2. 与优化前同源对比

| 项 | 优化前（tag `score-3.4194-1024`） | **本版** | Δ |
|---|---:|---:|---:|
| LUT | 21,949 | **18,006** | **−18.0%** |
| FF | 14,104 | **9,877** | **−30.0%** |
| LUTRAM | 3,628 | 3,628 | 0 |
| DRM / APM | 4 / 6 | 4 / 6 | 0 |
| 站点 S | 39,681 | **31,511** | **−20.6%** |
| setup（慢角） | +14.750 | **+12.972** | −1.8 ns（仍大量余量） |
| **hold（慢/快）** | **+0.015 / +0.002** | **+0.020 / +0.015** | **余量变好** |
| 失败端点 | 0 | **0** | — |
| 板上 ticks | 299,467,030 | **299,226,614** | **−0.08%** |
| **CoreMark/MHz** | 3.4194 | **3.4222** | +0.08% |
| CoreMark/kLUT | 0.1558 | **0.1901** | **+22.0%** |

（`CoreMark/kLUT` 相对**优化前同版** +22.0%；相对 P21 交付版 0.1718 为 **+10.6%**。）

## 3. 位流与构建

| 项 | 值 |
|---|---|
| 位流 | `bitstream/pangoriscv_i1024_area.sbit`（3,791,112 B） |
| SHA256 | `521EC6FEFD867E244DF4C955D6DA98519BEA06F5559E36498ED928DB5B9416BB` |
| 构建目录 | `firmware/code/build/pango_native`（**禁止再跑第二次实现**） |
| 镜像 | `score1024`：`program.hex` = `F67A0299…F42C4`，`data.hex` = `5D5F267A…CA9A0` |
| 镜像装载 | `compile/run.log` 有 **2** 条 `Loading memory data from file`（已复核，**没有** `Cannot open specified data file`） |
| 构建 profile | **交付 profile**：`PERF_ENABLE` 关，`CACHE_ENABLE`/`PREDICT_ENABLE` 开 |
| 烧写 | `cfg_program succeed` 00:50:26，`done bit 1`，`device id 0x00602899` |

## 4. 这次构建踩过的坑（值得记住）

第一次从 `build/area_final`（新目录）启动 `build.tcl`，结果：

```
C: Verilog-3001: Cannot open specified data file "program.hex" / "data.hex"
DRM = 0（程序 ROM 消失）
```

**原因**：`build.tcl` 把构建目录写死为 `build/pango_native`，而 PDS 解析 `$readmemh`
用的是**进程 cwd**；从别处启动 → 镜像找不到 → 位流没有程序（正是 mistakes-log §0 的铁律）。
**正确姿势**：先建 `build/pango_native`，`-WorkingDirectory` 指向它再启动，
并在综合前 grep `Loading memory data from file` 两条。第二次就正常了。

## 5. 门禁输出

```
# 终局预算（budget 模式）
LUT 20,400 vs 18,006  margin +2,394
FF   9,900 vs  9,877  margin    +23
LUTRAM 3,628 vs 3,628 margin     +0
DRM     4 vs 4        margin     +0
PASS

# 相对 M1 基线（delta 模式）
LUT -2,416 / FF -2,458 / S -4,874
PASS
```

## 6. 证据文件

| 文件 | 内容 |
|---|---|
| `multiseed_summary.csv` | 时序与资源（`single,OK,OK` + `Used` 行） |
| `report_timing.rtr` | 完整时序报告 |
| `synthesize_run.log` / `device_map_run.log` / `place_route_run.log` | 三阶段原始日志 |
| `lutram_attrib.log` | 存储阵列物理归属 |
| `board_uart_score.txt` | 板上串口原始输出（691 B） |

## 7. 仍未做的（下一阶段，不属于面积专项）

- **ILA 波形**（赛题文档评分项，尚未抓）；
- **最高频率扫描**（现在只证明 27 MHz 约束；板上只有 27 MHz 晶振，实测更高频率不可行）；
- **应用场景章节**；
- 可选：`M4b`（配对预测需第 4 个 BTB 查表口）、缓存搬 BRAM（需降到单读口）。
