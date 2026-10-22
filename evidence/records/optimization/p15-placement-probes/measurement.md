# P15 摆放/布线探针（120 MHz 目标能不能到）

日期：2026-10-22。目的：用 `pnr -place_only` 在 **8.333 ns 约束**下量"工具能把这个设计
摆到多快"，从而把"120 MHz 差多少"从推断变成实测。全部构建目录为 `firmware/code/build/<tag>`
（gitignore，已清理），数字与日志原文摘录如下。

RTL：`76b98cf`（= S1 icache way 拆分 + S2 `br_miss` 摘掉 `mem_wait`）。镜像：`hw_i6500_120`。

## 结果表

| tag | 配置 | 摆放 WNS | TNS | 判读 |
|---|---|---|---|---|
| p13po120（历史，pre-S1） | 无区域，seed 未知 | **−10,410 ps** | n/a | 基线 |
| p14po120b（历史） | floorplan v2 窄 y 带 | −10,998 ps | n/a | 负优化 |
| **p15po120a** | 无区域，seed 3 | **−11,055 ps** | −100,700,932 ps | 120 MHz 目标下最好的一次 |
| **p15po120b** | 紧凑 2D 方块（96×146，只绑 `soc.core`） | **−13,800 ps** | −133,969,439 ps | 比无区域**更差** |
| p15po120c | `-dc_duplication -logic_optimize -dispose_dram_prior -parallel 8` | 未取得 | — | 8/8 seed 因单 license 失败 |

日志原文（p15po120a）：

```
Worst slack after clock region global placement is -16621
Worst slack after post global placement     is -23136
Worst slack before detailed placement is -18137, TNS before detailed placement is -154339854
Worst slack after detailed placement  is -11060, TNS after detailed placement is -100626881
Worst slack is -11055, TNS after placement is -100700932
```

## 三个结论

1. **摆放上限 ≈ 19.39 ns**（8.333 + 11.055）⇒ 摆放层面就只到 ~51.6 MHz，
   离 120 MHz 差 2.33 倍。工具从 −23.1 ns 收到 −11.1 ns 已经用尽摆放手段（时间驱动、
   去拥塞、CE 共享全开）。
2. **区域约束三种形状全负**（横带 v2 / 竖带 v3 / 紧凑方块 p15b）。第三种是本轮新做的，
   只绑 `soc.core`、96×146 的方块（本地利用率约 48%），结果 −13.8 ns，比无区域差 2.7 ns。
   ⇒ 这条优化方向**封死**，不要再试第四种形状。
3. **`-parallel` 多 seed 并行不可用**：本机只有一份 fabric license，
   8 个子进程全部失败（`I: Running PnR with seed 21 failed. Total:8/8`），
   没有 `E:` 级错误，只能看 `I:` 行。单 license 环境必须一次一个 seed。

---

# 第二部分：提高频率为什么交付不了（布线不收敛的三次实测）

摆放能过 ≠ 能出位流。本轮 50 MHz / 45 MHz 各做过满实现，**摆放全部通过、详细布线全部不收敛**。
这决定了本轮交付频率仍是 36 MHz。

| tag | 约束 | 配方 | 摆放 WNS | 布线（Unrouted nets 轨迹） | 结局 |
|---|---|---|---|---|---|
| p15r50 | 50 MHz / 20.00 ns | seed 3, decong 1, CE-share, `-dc_duplication` | **+1.036 ns**（TNS 0） | 18,810@7 → 17,055@9 → 11,549@21（斜率 240/轮） | 34 min 后终止 |
| p15r45 | 45 MHz / 22.22 ns | seed 7, decong 1, CE-share | **+1.162 ns**（TNS 0） | 18,470@5 → 15,412@10 → 12,507@15 → 10,369@21 → 9,237@26（斜率 226/轮） | 38 min 后终止 |
| p15r45b | 45 MHz / 22.22 ns | seed 3, **decong 2**, **`-dispose_dram_prior`**, CE-share | **+1.300 ns**（TNS 0） | 21,859@4 → 18,807@9（斜率 610/轮，起点更差） | 23 min 后终止 |

## 判读

1. **摆放已经不是瓶颈**：45/50 MHz 都能摆到 TNS=0、WNS +1.0~+1.3 ns。
2. **详细布线是瓶颈**，而且**不是时序目标不可达**——是**收敛速度**：
   Unrouted nets 一直单调下降（不是震荡），但斜率从 600~800/轮 一路衰减到 ~230/轮，
   总在 9k~11k 处变平。按 P13 的成功案例（285 轮收敛），这个规模在**当前机器的速度**
   （40~90 s/轮）下要 2~4 小时，且不保证收敛。
3. **加强去拥塞（decong 2）与分布式 RAM 优先摆放（`-dispose_dram_prior`）没有帮助**，
   起点反而更差（21.9k@4 vs 18.5k@5）、斜率虽大但总量更落后。
4. 因此 **36 MHz 仍是目前唯一"能出位流"的频点**；`bitstream/pangoriscv_board36_i2000.sbit`
   保持有效，PLL 已回退到 56/42=36 MHz，保证仓库能复现该位流。

## 下一步该试什么（本轮没时间做完）

**A/B 假设：S1（I$ 数据阵列按 way 拆成 4 个 256×32）可能是布线变差的原因。**
P13 那次 285 轮收敛是 **S1 之前**；本轮全部不收敛是 **S1 之后**。
拆成 4 个阵列后，写地址/CE 扇出要在 4 个阵列之间交叉，正是"LUTRAM 走廊"问题。
判据：同一个 45 MHz 约束、同 seed，S1 回退 vs S1 保留，比 20 轮后的 Unrouted nets。
如果 S1 是元凶，就在"3 个 LUTRAM 阵列"上换布局（`-dispose_dram_prior`）而不是回退 S1。
