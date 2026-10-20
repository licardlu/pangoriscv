# perf-writepath-3.63：写通路吞吐（P35 + 深度 2 + tag 重定时）—— 板上 **3.6345**，时序全过

日期：2026-10-21（板上实测 09:12）
性质：**可交付**（三项指标同一份位流，hold > 0、失败端点 0）

---

## 1. 三项指标

| 指标 | 数值 | 口径 |
|---|---|---|
| **① CoreMark/MHz** | **3.6345** | 板上串口原文 `Total ticks 281,741,495 / Iterations 1024` → `1024e6/281,741,495`；用时 **10.435 s ≥ 10 s** |
| **② 时钟频率** | **27 MHz 约束，`All Constraints Met`** | `multiseed_summary_p36.csv`：`single,OK,OK`；setup **+10.041 / +19.422**，hold **+0.002 / +0.001**，失败端点 **0** |
| **③ CoreMark/kLUT** | **0.2008** | `3.6345 / 18.099`（LUT 取自 `device_map` `Used`） |

板上原文：`board_uart_p36.txt`
```
Total ticks      : 281741495
Total time (secs): 10
Iterations       : 1024
seedcrc 0xe9f5  crclist 0xe714  crcmatrix 0x1fd7  crcstate 0x8e3a  crcfinal 0x9ce8
Correct operation validated.
```

## 2. 与交付基线对比（同镜像 score1024、同流程、同工具）

| 项 | area-final（原交付） | **本版** | Δ |
|---|---:|---:|---:|
| 板上 ticks | 299,226,614 | **281,741,495** | **−5.84%** |
| **CoreMark/MHz** | 3.4222 | **3.6345** | **+6.21%** |
| 时长 | 11.082 s | 10.435 s | — |
| 五项 CRC | 全对 | **全对且逐项相同** | 架构等价 |
| LUT / FF / LUTRAM | 18,006 / 9,877 / 3,628 | **18,099 / 9,931 / 3,628** | +93 / +54 / 0（+0.47% 站点） |
| setup（慢角） | +12.972 | +10.041 | −2.93 ns（仍 >0） |
| **hold（慢/快）** | +0.020 / +0.015 | **+0.002 / +0.001** | 仍为正、端点 0；余量更薄，**该位流不再重跑** |
| CoreMark/kLUT | 0.1901 | **0.2008** | +5.6% |

## 3. 三处改动（两个模块）

1. **`axi_data_engine`（写引擎）**
   - 允许与主机交 B 的**同拍**接收下一笔（`req_ready` 门控在 `b_valid && b_ready`，
     所以 `EARLY_STORE_COMPLETION` / `WRITE_OWNERSHIP` 契约不变，engine 64/64 原样通过）；
   - 请求与 W 拍**同拍**到达时跳过 `WR_PREP`（`w_ready` 加 `!protocol_fault && !config_fault` 门控，
     粘滞故障契约不变）。
2. **`dcache_axi`（D-Cache）**
   - 队头在**释放拍**用组合路径递给引擎（`i_release`），W 拍随请求同拍（`eng_w_now`）；
   - `STQ_DEPTH` 4 → **2**（省 150 FF，缓解 `R_DCACHE` 拥塞；A/B 代价仅 0.78%）；
   - `tag_di_q`：tag RAM 写数据的**真实流水级**（源是 `tag_q`，综合无法折叠），
     把 `tag_q → tag_mem/DI` 这条从 P34 起就一直失败的 hold 路径切成两段。

## 4. A/B 分解（20 迭代，analysis profile）

| 项 | area-final | P34 | P35+深度2（本版） |
|---|---:|---:|---:|
| 评分窗口 cycles | 5,843,953 | 5,697,334 | **5,498,599** |
| store EX 停顿 | 593,975 | 433,394 | **244,753** |
| drain 拍/笔 | 7.6 | 7.6 | **6.15**（2,333,747 / 379k） |
| 五项 CRC | — | 相同 | **相同** |

预测分 3.4222 × 5,843,953/5,498,599 = **3.637**，板上 3.6345（差 0.07%，见上表）。
逐版数字由 `tb_coremark_uart.sv` 的 `SCORE_WINDOW` / `DCACHE_PATH` 探针给出。

## 5. 回归（全部在改完后重跑）

`engine 64/64`（含粘滞故障 8 例）、`dcache D1–D9 + E1–E5`、`ISA e2e 16/16`（含新增配对内 WAW）、
CoreMark 20 迭代 A/B 五项 CRC 与基线逐项相同。

## 6. 证据文件

| 文件 | 内容 |
|---|---|
| `board_uart_p36.txt` | 板上串口原文 |
| `multiseed_summary_p36.csv` | 时序/资源收尾值（`single,OK,OK` + Used） |
| `report_timing_p36.rtr` | 完整时序报告（失败端点 0） |
| `sha256.txt` | 位流 / program.hex / data.hex |
| `../../../../bitstream/pangoriscv_i1024_p36.sbit` | 交付位流本体 |

## 7. 下一步（3.8）

窗口 5.50M → 3.8 需要 ≤5.26M（再省 ~240k）。写通路仍是 2.1M drain 周期（38%），
但每笔已到 6.2 拍（HOLD 收请求 + SEND + B + HOLD 交 B），**下一档只能做 2 outstanding**
（AW/W 与上一笔的 B 重叠），预估窗口 ~4.7M → 约 4.1。设计见 `docs/plan-perf-3.6.md` §10。
