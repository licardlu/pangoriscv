# perf-store-fifo：D-Cache posted store 队列（P34）—— 板上 **3.5101**，但 hold **未闭合**

日期：2026-10-21（板上实测 04:47）
性质：**性能专项的第一项**。功能与性能均已验证；**②频率合规未通过**，因此**这不是可交付位流**，
`bitstream/` 里仍然是 area-final 的 3.4222。

---

## 1. 三项指标（同一份位流）

| 指标 | 数值 | 口径 |
|---|---|---|
| **① CoreMark/MHz** | **3.5101**（实测，非估算） | 板上串口原文 `Total ticks 291,733,469 / Iterations 1024` → `1024e6/291,733,469`；用时 **10.805 s ≥ 10 s** |
| **② 时钟频率** | 27 MHz 约束，**`Convergence = Fail`** | `multiseed_summary_p34.csv`：setup **+11.615**，**hold −0.002 / −0.001**，失败端点 **1** |
| **③ CoreMark/kLUT** | **0.1941** | `3.5101 / 18.085`（LUT 取自 `device_map` `Used`） |

板上串口原文：`board_uart_p34.txt`
```
Total ticks      : 291733469
Total time (secs): 10
Iterations       : 1024
Iterations/Sec   : 102
seedcrc 0xe9f5  crclist 0xe714  crcmatrix 0x1fd7  crcstate 0x8e3a  crcfinal 0x9ce8
Correct operation validated.
```

## 2. 与交付基线对比（同一镜像 score1024、同一流程）

| 项 | area-final（交付） | **本版** | Δ |
|---|---:|---:|---:|
| 板上 ticks | 299,226,614 | **291,733,469** | **−2.50%** |
| **CoreMark/MHz** | 3.4222 | **3.5101** | **+2.56%** |
| 时长 | 11.082 s | 10.805 s | — |
| 五项 CRC | 全对 | **全对且逐项相同** | 架构等价 |
| LUT / FF / LUTRAM | 18,006 / 9,877 / 3,628 | **18,085 / 9,808 / 3,664** | +79 / −69 / +36（+0.17% 站点，**面积中性**） |
| setup（慢角） | +12.972 | +11.615 | −1.36 ns |
| **hold（慢/快）** | **+0.020 / +0.015** | **−0.002 / −0.001** | **倒退，1 个失败端点** |

## 3. 改了什么（只动 `dcache_axi`）

1. 单条 `hold` posted store 缓冲 → **4 深队列**（`STQ_DEPTH=4`，每项 75 bit：addr/data/strb/size/id；
   写合并在 accept 拍完成，所以不再需要 set/word/way/hit/cached）。
2. 接受条件放宽到 `ST_WR_DRAIN` 与 `ST_WR_POST` 两态；**行合并写同时补进这两个状态分支**
   （漏了 POST 会静默读到旧值，见下）。
3. 读缺失的顺序门控显式化：`q_empty && !drain_q`（原来靠 `state==ST_IDLE` 隐式保证）。
4. `tag_wr_q`：tag RAM 写数据的物理复制寄存器（hold 关闭用；本轮被综合合并，未生效）。

## 4. 实测收益的分解（20 迭代 A/B，analysis profile）

| 项 | 基线 | 本版 | Δ |
|---|---:|---:|---:|
| 总 cycles | 7,677,085 | **7,530,451** | −146,634 |
| **评分窗口 cycles** | **5,843,953** | **5,697,334** | **−146,619（−2.51%）** |
| store EX 停顿 | 593,975 | **433,394** | −160,581 |
| store 被拒周期 | 451,981 | **327,522** | −124,459 |
| 其中 `drain 期队列满` | 451,958 | 327,475 | −124,483 |
| 配对退休 | 1,346,942 | 1,346,939 | ≈0（本项不影响配对） |

**为什么只到 2.5%**：队列只吸收瞬态。`core_list_init` 每个节点 1 load + 5 store，
需求率 ≈1 笔/8 拍，正好等于写出吞吐（379k 笔 / 2.88M drain 周期 = **7.6 拍/笔**）。
持续压力下加深队列收益≈0（实测占用在"满 4"上停了 805k 周期）。

## 5. 未闭合项与下一步（不是"待定"，是已定位）

- **hold −0.002 ns / 1 端点**：失败路径 `soc/core/data_cache/tag_q[4] → tag_mem_1_4/ram64x1d/DI`，
  是老紧点（area-final 时为 +0.020）。`tag_wr_q` 复制寄存器被综合合并（FF 两个构建都是 9,808），
  所以本轮只有"换种子"一个变量；seed 7 那轮布线在 8~11 条未布通上震荡失败。
  **下一步**：给复制寄存器加 keep 属性（`/* synthesis syn_keep = 1 */`）或换默认种子重跑；
  若仍不开，再考虑 `tag_mem` 写口就近布局。
- **3.60 未达到**：还差约 142k 窗口周期。唯一大杠杆是**写出吞吐**（2.88M drain 周期占窗口一半）。
  `axi_data_engine` 是串行 5 态；本轮试过两种小改：
  - B-in-SEND：SoC 内**空操作**（cycles 逐位不变），已回退；
  - HOLD 期接收下一笔：被 `tb_axi_data_engine` 的 `WRITE_OWNERSHIP` 契约挡住，已回退。
  **要做 3.6 必须做写引擎流水化（2 outstanding）**，预计可到 ~4.0，属下一轮独立立项。

## 6. 证据文件

| 文件 | 内容 |
|---|---|
| `board_uart_p34.txt` | 板上串口原文（692 B） |
| `multiseed_summary_p34.csv` | 时序/资源收尾值（`single,OK,Fail` + Used） |
| `report_timing_p34.rtr` | 完整时序报告（失败路径在第 453 行附近） |
| `sha256.txt` | 位流 / program.hex / data.hex 的 SHA256 |
| `../../../../docs/plan-perf-3.6.md` | 计划、门禁、A/B 判据 |
| `../../../../docs/lessons/mistakes-log.md` §13 | 本轮三条可复用教训 |
