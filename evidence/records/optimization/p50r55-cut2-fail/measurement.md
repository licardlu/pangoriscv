# P50r55 —— 切② 之后的第一档满流程：55 MHz 未收敛（2026-10-24）

| 项 | 值 |
|---|---|
| 构建 | `firmware/code/build/p50r55`（`exp/split`，含切②，无 S1+S2、无切⑥）|
| 约束 / PLL | 55.0025 MHz / 18.181 ns（27×55/27，VCO 1485）|
| 镜像 | `hw_i2900_55`：2900 迭代，10.05 s |
| 收敛 | **Fail** |
| Setup WNS | **−1.595 ns**，2,222 失败端点，TNS −537.963 |
| Hold WHS | −0.028 ns（1 端点）|
| 摆放 | KPI：After DP **+1.264 ns**、After Placement **+1.256 ns** |
| 布线后 | 19.776 ns（**布线在摆放之上又吃掉 2.85 ns**）|
| 面积 | LUT 17,316 / FF 8,597 / DRM 12 / DRAM 2,274 |
| 位流 | `generate_bitstream/pangoriscv_top.sbit`，sha256 见 `bitstream.sha256`（**时序违规，不交付**）|

## 最差路径（`report_timing.rtr`，21.852 ns 到达）

```
rr_inst[21] (fanout 137, net 1.192)
  -> u_regs/N44 -> alu_b mux (net 1.591)
  -> u_alu 4 levels (8.075..11.992)
  -> fwd1_h (net 0.975, 13.041)
  -> u_mul_h 4xAPM cascade (15.010 -> 21.852, 约 8.8 ns)
  -> ex_value_h[28]
Logic 8.015 ns, Route 11.215 ns, 15 levels
```

**这是本轮最重要的发现**：切② 把原来那条 `w_valid→CSR→ALU→AGU→D$` 路径拆掉之后，
新的最差路径变成了 **lane-1 乘法器**：`lane 0 的 ALU 结果 → fwd1_h → 4 个 DSP 级联`。
`packet_md_use` 只禁了反方向（lane 0 乘法 → lane 1 读），这个方向一直没人管。

⇒ 后续修复见 `docs/plan-v21` §P57：**必须把 `alu_y` 从乘法器的操作数里结构性摘掉**
（只禁配对不够——综合读不到 `pair_ok`，锥还在）。实测代价 ticks 3,810,700 → 3,810,540（−160），
即 8 拍/迭代，基本免费。
