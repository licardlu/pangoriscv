# D1 —— 计分窗口归因（不改 RTL，只加测试台探针）

日期：2026-10-22
计划：`docs/plan-score-5.2-120mhz-v6.md` §4
起点：R5 已落地（`cb9b281`，4.427 CM/MHz，`Total ticks` 4,518,354）
产物：`firmware/code/.sim_runs/coremark_sim/{d1win,d2why,d3acc,d4ref}/transcript.txt`

## 1. 为什么先做这一步（这条是本次最重要的经验）

前一轮（v5 §7）把 `mem_wait=1,268,139` 当成"计分窗口里最大的浪费"，
并据此规划了 D$ 的读写解耦。**这个判断是错的**，因为它读的是一组
`ifdef CACHE_ENABLE ... if(rst_n && !report_seen)` 的计数器 —— 它们统计的是**整个程序**，
而 CoreMark 打印报告时 CPU 会在 UART 状态寄存器上自旋：

```
ADDR_REGION ld_hi=122,461  nonhit_hi=122,461
```

12.2 万次**不可缓存的 MMIO 读**，每次约 4.6 拍 = 0.58 M 拍，全部落在计分窗口**之外**。
把这 0.58 M 当窗口内的瓶颈，就会去优化"打印机"。

**可复用判据**：读任何一个性能计数器之前，先确认它的门控。
`!report_seen` = 全程序（含打印）；`!sw_done` = 计分窗口（第一次 TXDATA 写之前）。
两个数在 CoreMark 上差 40%，混用一定指错方向。

## 2. 窗口内的真实结构（`d1win`）

计分窗口 `cycles=4,539,252`，`retires=5,782,458`，IPC 1.2739。三者严格自洽：

| 桶 | 周期 | 占比 |
|---|---:|---:|
| `pair`（一拍退 2 条） | 2,333,049 | 51.4% |
| `single`（一拍退 1 条） | 1,752,487 | 38.6% |
| `none`（一拍 0 条） | 453,716 | 10.0% |
| 合计 | 4,539,252 | 100% |

`none` 再分：`starve=308,623`（取指没有指令）+ `other=145,093`（有指令但不前进）。

**窗口内访存其实很轻**：`WIN_STALL mem=287,320`（占 6.3%），
其中 LSU 在 `REQUEST`（等 D$ 收下）194,163、`READ_WAIT`（等数据）93,123。
D$ 在窗口内几乎不干活：`WIN_DC idle=2,976,325 rdar=9,615 rddata=79,112`。

## 3. 配对为什么被拒（`d3acc`，对齐到同一个握手沿）

`WIN_ACCEPT pair=2,264,900 single=443,126 refused_pair=1,096,006`：

| 拒收原因 | 周期 | 能不能救 |
|---|---:|---|
| `lduse`（lane0 load，lane1 消费者） | 286,065 | **不能**：load 数据在下一个沿才到 |
| `alone`（lane0 是跳转，lane1 不是预测目标） | 252,538 | **能**：见 §4 |
| `memmem`（两条访存） | 221,713 | 要第二个访存端口，代价大 |
| `mduse`（lane0 乘除，lane1 消费者） | 186,372 | 不能（同 load） |
| `l1bad`（lane1 是 CSR/mul/div/illegal） | 149,318 | 需要第二个乘法器，**伤时序**，不做 |

## 4. `alone` 的真因：第二槽 PC 被写成了 `fetch_pc+4`

`lane0_issue_alone = dec_serial || dec_jalr || ((dec_br||dec_jal) && !lane1_is_pred)`，
而 `lane1_is_pred = (fetch_pc_hi == fetch_predicted_next_pc)`。

IFU 的 `result_pair` 用的是 `pair_adj`：**队里第二项的 PC 等于第一项的"预测后继"**
（预测跳转时那就是目标）。也就是说 IFU 已经专门把"分支 + 目标"凑成一个包了，
但 `result_pc_hi` 写的是 `result_pc + 32'd4` —— 于是 `fetch_pc_hi != target`，
`lane1_is_pred` 恒为 0，**这个已经被预取到手的包 100% 被自己拒掉**。
实测 229,798 次/程序，每次 1 拍。

修法（两处，缺一不可）：
1. `ifu_axi`：`result_pc_hi = response_bypass ? result_pc+4 : q_pc[head_nxt]`；
2. `rv32_top`：`id_pc_h <= fetch_pc_hi`（原来写死 `fetch_pc+4`，会让 lane1
   用"对的指令 + 错的 PC"执行，链接地址与分支目标全错，实测直接跑飞）。

**顺带发现一个潜伏 bug**：`q_pc[head_q+1'b1]` 在 Verilog 里按 32 位算术求值，
`head_q==DEPTH-1` 时读到 `q_pc[DEPTH]`（越界 X）。旧代码只把它放在
`count_q>1` 后面，掩盖了一半；改成无条件使用后必须让它像指针一样回绕
（`head_nxt = head_q + 1'b1`，位宽 AW）。

## 5. 访存拒收的真因（`d4ref`）：不是读被写挡住，是 store 挤不进队列

| 桶 | 周期 | 其中在 `ST_WR_DRAIN` |
|---|---:|---:|
| store 在 `REQUEST` 等 D$ | 183,324 | **183,323（99.999%）** |
| load 在 `REQUEST` 等 D$ | 10,839 | 9,958 |

所以 v5 里"读写共用 state_q 挡住 load miss"的推断，在窗口内只值 1 万拍；
真正的大头是 **store 队列满（`drain_full`）**：写通 + 单 outstanding 写引擎
= 每 store 5.06 拍，`ST_WR_DRAIN` 占窗口 1,460,234 拍（32%），
连续写一旦超过队列深度 4，CPU 就被顶住。

**判据**：`ST_WR_DRAIN` 占用率高 ≠ 读被挡住。要看**谁在 REQUEST 里等**，
并且按 load/store 分开 —— 两者一个值 1 万、一个值 18 万，修法完全不同。

## 6. 复现

```bash
python tools/run_coremark_sim.py --image build/native_software/coremark/performance/sim20_o2 \
       --tag d1win --define RV32_DEBUG
```
探针全部在 `tb/integration/tb_coremark_uart.sv` 的 `WIN_*` 块（`!sw_done` 门控），
不发 `RV32_DEBUG` 之外的新宏，不碰 RTL。
