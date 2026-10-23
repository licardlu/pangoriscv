# P48 —— 50 MHz 频点探测（2026-10-23）

**目的**：在不改 RTL 结构的前提下，把交付频点从 48 MHz 往上推一档（分数与频率无关，
提频不损失 CoreMark/MHz，只提升"最高时钟频率"这一项）。

**结论：失败。50 MHz 布通了，但时序不收敛（core_clk WNS −1.595 ns）。48 MHz 仍是唯一合规点。**

---

## 构建

| 项 | 值 |
|---|---|
| tag | `build/p48r50` |
| RTL | 交付 RTL（`91d5282` 的树，**不含** P48b 的 lane1 旁路） |
| PLL | 27×50/27 = 50.000 MHz，VCO 1350（`STATIC_RATIOF=50 / STATIC_RATIO0=27`） |
| 约束 | `core_clk` 50 MHz（20.000 ns）＋ `core_clk_pnr` 52 MHz（19.2308 ns，`-add`，只给摆放器加鞭） |
| 镜像 | `hw_i2800_50v17`（2800 迭代 / `CPU_FREQ_MHZ=50`）→ 10.67 s ≥ 10 s |
| 配方 | `-plc_decongestion 2 -dispose_dram_prior TRUE -share_router_control_signal TRUE`，seed 7 |
| 面积 | LUT 17,103 / FF 8,693 / DRAM 2,274 / DRM 12（与交付 17,105 一致） |
| 综合 WNS | −1.161 ns（50 MHz）|
| 位流 | `generate_bitstream/pangoriscv_top.sbit`，sha256 `60095327358669fa…1fd0ba0`（**不合规，不发布**）|

## 结果

| 项 | 值 | 判据 |
|---|---|---|
| 详细布线 | **Unrouted 0 @ iteration 707** | ✓ 布通了 |
| `core_clk`（50 MHz） | **WNS −1.595 ns，失败端点 3,202 / 58,154** | ✗ |
| `core_clk_pnr`（52 MHz） | WNS −2.365 ns，失败 8,729 | （不计入合规）|
| hold | WHS **+0.009 ns，0 失败端点** | ✓ |
| 总耗时 | 1 h 19 m | —— |

⇒ 布线后最差路径 ≈ **21.6 ns**，与 P33a/P37a/P45a/P46a 那条"主导摆放吸引子 21.633 ns"
完全一致（mistakes-log §73）。这已经是第 6 个样本，**21.6 ns 是这个网表族的稳态，
20.581 ns（交付的 48 MHz）才是偶发**。

## 本次最差路径（`report_timing_50mhz.rtr`）

```
u_regs/rfile[10][28] → 寄存器堆读 + 旁路 mux → alu_a → ALU → alu_y → fwd1_h
→ mem_addr_h → ls_req_addr[9]（fanout 233，1.839 ns）→ D$ tag 读出
→ hit_way_q → hit_way（fanout 38，2.183 ns）→ 数据 way mux（1.756 ns）
→ ls_rsp_data → lsu/extend_load → load_value_q
Slack −1.785 ns，即 ≈21.8 ns
```

**这一轮的最差路径是"load 数据返回"，不是上一轮（`p30`/48 MHz）的"store 写使能"。**
所以"把 store 阵写延后一拍"那类改动在本轮次里一点用都没有 —— 也再次说明
**瓶颈在同一条 20 ns 的数据通路上来回漂移，单点摘除只对当次摆放有效**。

## 对后续判断的影响

1. **不改结构就别再抽 50 MHz 了**：6 个样本里 5 个落在 21.6 ns 附近，
   50 MHz 需要 ≤20.0 ns，差 1.6 ns，远超逐次波动 σ≈0.4 ns 的量级（§75）。
2. **想提频只能切流水**（v16 §5 的 A/B/C 三级），而切流水会吃掉 v16 §3 算出来的 CPI 预算，
   必须和 4 发射一起做 —— 这就是 v16 的 M1~M4 路线。
3. 48 MHz 这一档的交付位流（`board48`，板测 5.2447）**已经是一次幸运摆放**，
   重跑不一定复现（§69/§73）。所以**不要为了"再试一次"而覆盖它**。
