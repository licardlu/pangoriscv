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
