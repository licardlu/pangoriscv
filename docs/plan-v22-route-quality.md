# v22 —— 布线质量攻坚：把 50 MHz 抬到 52 MHz（不动一行 RTL、不花一个拍）

## 0. 为什么还有这一步

`plan-v21` 已用三条独立证据关掉 120 MHz（ILP 上界 IPC 2.504；切级代价 2,314 / 34,757 拍每迭代；
5.2 只剩 1,780 拍）。但**频率指标本身还可以往上抬**，只要不花拍数、不动 RTL：

| 事实 | 数值 | 出处 |
|---|---|---|
| 交付网表布线后 | **19.355 ns** @ 50 MHz 约束（预算 20.000，WNS **+0.645**）| `build/p48r50e` |
| 52 MHz 预算 | **19.231 ns** | 1000/52 |
| 全族历史最好的布线结果 | **19.324 ns**（另一棵树）| `build/p55max2` |
| ⇒ 到 52 MHz 的缺口 | **0.124 ns**（0.6% of path）| 交付树 19.355 → 19.231 |

**0.12 ns 是唯一一个"只差一点点"的目标。** 55 MHz 要 18.181（缺口 1.17 ns），120 MHz 要 8.333
（缺口 11.0 ns）——只有 52 MHz 值得再花一次满流程。

## 1. 病因（已量化，不再猜）

`p50r52` 的 `report_timing.rtr` 逐跳分解：

```
Logic:  3.685 ns (18.3%)      Route: 16.470 ns (81.7%)      约 20 根网线 = 0.82 ns/根
```

单根最贵的：

| 网线 | fanout | 延迟 |
|---|---|---|
| PLL `CLKOUT0` → 全局时钟缓冲 | 1 | 1.112 ns |
| `rr_rs1[4]` → RF 读地址/旁路比较 | 39 | **1.051 ns** |
| 某二级组合 | **2** | **0.958 ns** |
| `mem_from_h` | 126 | 0.861 ns |

**延迟由物理距离决定，不是逻辑深度、不是扇出本身**（fanout=2 也值 0.958 ns）。
所以要对症的动作只有一类：**让布线器把关键网线放在短路径上，并把高扇出驱动复制开**。

## 2. 六个从未用过的 pnr 选项（`help pnr` 全表里筛出来的）

| 选项 | 语义 | 为什么对症 |
|---|---|---|
| `-dc_duplication TRUE` | Design Cells Duplication（复制驱动单元）| 直接打 fanout=126 / 39 那两根（0.861 / 1.051 ns）|
| `-slack_prior_in_global_router TRUE` | 全局布线按 slack 优先 | 关键网线先占短通道 |
| `-refineplacement_cluster TRUE` | 摆放后按连接关系重新聚类 | 把相连单元拉到一起 ⇒ 缩短物理距离 |
| `-refineplacement_iteration N` | 上面的迭代次数 | 同上 |
| `-optimize_routing_recovery TRUE` | 布线期做 recovery 分析 | 布线后回修 |
| `-enable_route_constraint_iterate ...` | 对最差路径做"布线-约束"迭代 | **已验证有效**：`p55max2` 靠它拿到全族最好的 19.324 |

（另有 `-logic_optimize_enable`、`-share_router_control_signal`、`-max_ctrl_chain_length`、
`-plc_decongestion`、`-pin_cost_increasing_speed` 未纳入本轮，留作下一档。）

## 3. 本轮实验的配置

| 项 | 值 | 理由 |
|---|---|---|
| 分支 | `exp/f52` = `exp/pair45`（**交付树**，无切②、无 P57/P63）| 交付树是全族布线最好的一次（19.355），拍数 190,535（5.2484）|
| RTL 改动 | **零**。只改 PLL `STATIC_RATIOF 50→52`（27×52/27，VCO 1404）| 不动逻辑 ⇒ 拍数逐位不变、无需重跑 ISA/halt |
| 镜像 | `hw_i2900_52b`（2900 迭代；2900×190,535÷52 MHz = **10.63 s** ≥10 s）| 已有 |
| 约束 | `--freq 52` | 1000/52 = 19.231 ns |
| pnr 选项 | `-dc_duplication TRUE -slack_prior_in_global_router TRUE -refineplacement_cluster TRUE -refineplacement_iteration 2 -optimize_routing_recovery TRUE -enable_route_constraint_iterate -route_constraint_slack 0.10 -route_constraint_max_timing_path 500 -route_constraint_iterate_times 30` | 见 §2；**故意不加 `-place_worst_slack`**（已证有害：要 +8 ns 反而让摆放从 16.93 退到 17.18）|

## 4. 判据（先写死，跑完照着核，不许事后解释）

| # | 判据 | 阈值 |
|---|---|---|
| 1 | `Unrouted nets` 归零 | 必须 |
| 2 | `Design Summary` | `All Constraints Met` |
| 3 | setup WNS / 失败端点 | **≥ 0** / **0** |
| 4 | hold WHS / 失败端点 | ≥ 0 / 0 |
| 5 | 面积 | LUT ≤ 18,000（布线门槛，lesson 9）|
| 6 | 位流里有程序 | `Loading memory data from file` ×2、`Cannot open specified data file` ×0 |

通过 ⇒ 三项指标变成 **5.2484 / 52 MHz / 0.3056**（唯一变化是频率 +4%，因为 RTL 未变、拍数未变）；
不通过 ⇒ 交付保持 50 MHz 版不动，52 MHz 归档为"布线质量杠杆不足 0.13 ns"。

## 5. 与 120 MHz 的关系（不重复论证）

抬到 52 MHz **不改变** 120 MHz 的结论：那需要 `S = 20.1/8.333 = 2.41` 级、至少 2 级访存流水，
按 ILP 上界即使 4 发射 + 4 访存端口也只剩 4.727 分。本轮只是把"5.2 分这一档能跑多快"推到极限。
