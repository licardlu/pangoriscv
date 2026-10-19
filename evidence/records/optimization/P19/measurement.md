# P19 · store 数据随请求拍递出（板上实测 2.7381）

> ## ✅ 成绩有效性
> 本文件中的分数**已在真实开发板上实测**，与仿真逐周期一致。
> 原始串口抓取：`board_uart_score.txt`（691 B）。

---

## 1. 这一轮做了什么

把 **store 的数据**提前到"请求拍"就递给 D-Cache，LSU 从此不再需要单独一个
`WRITE_DATA` 状态。省掉的正是 `wdata_store` —— 那 3.8% 的周期纯粹是"为了把数据递过去
多等一拍"。

**与早前被否决的"posting store"（把 AXI 写事务延后到后台）的根本区别**：
本轮**不延后任何写事务**，AXI 写仍在数据到位后立即发起，访存顺序不变，
所以 `store→load` 与停机排空都不受影响。

改动：
- `lsu_axi.v`：请求拍即输出 W 拍；受理后直接进 `WRITE_WAIT`；
  `wtake_q` 让 W 拍**保持到引擎取走**（否则直连引擎的 harness 会等不到）；
  **W 数据在受理后的所有周期都取锁存值 `value_q/address_q/size_q`**，
  只有受理那一拍才用实时输入（用错会写出垃圾并导致 store 永不完成）。
- `dcache_axi.v`：受理拍锁存 `wdata_q/wstrb_q`、当拍做写通合并、数据 RAM 段当拍回 OKAY；
  `wreq_q` 保持 AW 直到引擎接收；`wsent_q` 把 W 拍归属到"本次 AW 已被接收"，
  避免引擎仍在为上一笔准备时被误置位。
- `tb/unit/tb_lsu_axi.sv`：激励与计分器同步改为"受理拍"语义。

## 2. 跑分（768 迭代）

| 项 | P18（原交付） | **P19** |
|---|---|---|
| ticks（仿真） | 284,997,892 | **280,487,382** |
| ticks（**板上实测**） | 284,997,892 | **280,487,382** |
| cycles | 286,784,100 | 282,273,122 |
| IPC | 0.7747 | **0.7871** |
| 用时 | 10.555 s | **10.388 s** |
| 五项 CRC | e9f5/e714/1fd7/8e3a/3c53 | **完全相同** |
| validated / traps / faults | True / 0 / 0 | **True / 0 / 0** |
| **CoreMark/MHz** | 2.6948 | **2.7381（+1.6%）** |
| store 通路 request 拍数 | 287,902 | **0** |

## 3. 实现（PDS 27 MHz，seed 11）

| 项 | P18 | **P19** |
|---|---|---|
| All Constraints Met | ✅ | ✅ |
| Setup(Slow) | +15.201 ns | **+15.289 ns** |
| Hold(Slow) | +0.024 ns | **+0.097 ns** |
| Hold(Fast) | +0.011 ns | **+0.066 ns** |
| 失败端点 | 0 | **0** |
| LUT（device_map） | 13,503 | **13,555** |
| FF | 8,507 | 8,508 |
| **CoreMark/kLUT** | 0.1994 | **0.2020（+1.3%）** |
| 位流 | 3,791,112 B | 3,791,112 B |

**三项指标同时改善**：① +1.6%、② hold 余量从 24 ps 提到 97 ps、③ +1.3%。

## 4. 上板条件

| 项 | 值 |
|---|---|
| 板卡 | Pango PG2L100H（MES2L676-100HP V1.2），27 MHz |
| 下载线 | Pango USB Cable II（D2XX），JTAG |
| 下载方式 | **SRAM（易失）**，`cfg_program succeed, 3.8` |
| 串口 | CP210x（COM34），115200 8N1 |

## 5. 证据文件

| 文件 | 内容 |
|---|---|
| `board_uart_score.txt` | 板测原始串口输出 691 B |
| `board_program_tcl.log` | `cfg_program succeed, 3.8` |
| `pds_27mhz_full/` | 位流 + `multiseed_summary.csv` + `report_timing.rtr` + 各阶段 log |

## 6. 一轮被浪费掉的时间：构建目录缺 `program.hex`（见 mistakes-log §11）

本轮的 6 次上板"零输出"**全部是假象**：为了做种子扫描我新建了 40 个构建目录，
却都没把 `program.hex` / `data.hex` 复制进去，导致综合出**没有程序**的位流。
综合日志里只有一行 `C:` 级提示 `Cannot open specified data file "program.hex"`，
整晚被忽略。

- **正确做法**：新目录跑 PDS 前先复制两个 hex，并 grep 日志确认
  `Loading memory data from file`。
- **镜像还会改变时序**：同一 RTL 同一种子，带镜像 hold −28 ps、不带镜像曾报 +18 ps。
  **不带镜像的 PDS 结果连时序都不可信。**

## 7. 下一步

- **4 KB I-Cache（仿真 +2.6%）** 仍被 hold 挡住（7 个种子全负，最好 −1 ps）——
  但现在知道要用**带镜像**的方式重测，值得再扫一轮。
- 若两条都吃下：2.7381 × 1.026 ≈ **2.81**。
