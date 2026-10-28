# v31 / v32 阶段报告：乘法器二级化失败，双 ALU 链被拆掉

日期：2026-10-27
状态：v31 闭档（负结果，已回滚）；v32 布线中

---

## 1. v31：`rv32_mul` rev 2.0 是净负收益，已回滚

`build/v31_50mul`，50 MHz，镜像 `v24_50`，与交付版同约束、同镜像，唯一变量是乘法器。

| 项目 | 交付版 | v31 两级乘 | 判定 |
|---|---|---|---|
| WNS | +0.645 | **−1.160** | 差 1.8 ns |
| 估算周期 | 19.355 ns | **21.160 ns** | 差 +1.805 ns |
| 估算频率 | 51.67 MHz | 47.259 MHz | — |
| TNS / 失败端点 | 0 / 0 | −110.0 / 559 | — |
| LUT | 17,174 | **17,784** | +610 |
| APM | 8 | 16 | +8 |
| 布线收敛 | 114 迭代 | 564 迭代 | — |

布线是真收敛的（`Unrouted nets 0`，迭代 564），所以这是**逻辑变差**，不是没布通。

结论：高位通路要拼 66 位加树（`ah*bh<<34 + mid<<17 + al*bl`），代价 +610 LUT；
本设计 86% 的延迟是布线，面积涨就是延迟涨，省下的级联延迟被布线吃光还有余。
`rv32_mul.v` 已 `git checkout` 回交付版（rev 1.3），两级方案与 800,484 向量的位精确性
证明保留在 `docs/plan-v27-mul-latency.md` 与 `docs/patches/rv32_mul_rev13_truncated_only.sv.txt`。

**更重要的副产品**：v31 的时序报告证明关键路径根本不在乘法器上。

## 2. v31 时序报告给出的真相：一个周期里串了两条 ALU 链

`build/v31_50mul/report_timing/pangoriscv_top.rtr` 的最差路径，23.438 ns：

```
m_valid (fanout 271) 2.833
  -> 旁路选择 N237/N286(fanout 20)/N304   5.203
  -> u_alu lane 0 (slt -> y_28 -> y_29)  12.991
  -> fwd2_h[0] = mem_sdata_h[0]          13.065
  -> alu_b_h[0] (fanout 69, 2.392 ns)    15.457   CLMA_195 -> CLMS_351，跨 156 列
  -> u_alu_h lane 1                      20.666
  -> ex_value_h[15]                      23.438
Logic 2.879 ns (13.8%) / Route 17.929 ns (86.2%) / 16 级
```

`lane0 的 ALU 结果` 同拍喂给 `lane1 的 ALU` —— **两条 32 位 ALU 链 + 一级旁路挤进一个周期**。
8 ns/ALU ⇒ 16 ns + 旁路 4.7 ns ≈ 20.6 ns，正好是 50 MHz 能收敛、54/56 MHz 收敛不了的分界线。

这不是 seed、不是布局、不是约束的问题。这是结构问题。

## 3. v32：把那条 mux 分支从 RTL 里删掉（P32）

关键教训：**`pair_ok` 对综合不可见**。译码级"拒绝这个配对"永远不能让路径消失
（`packet_md_use` 已经踩过一次）。必须从 RTL 里删掉分支，再为正确性拒绝配对。

改动（`rtl/core/rv32/rv32_top.v`）：

1. `fwd1_h` / `fwd2_h` 删掉首级 `lane0_raw1/2 ? alu_y :` 分支，`lane0_raw1/2` 一并删除。
   lane 1 的 EX 输入从此只是**一堆触发器的纯 mux**。
2. 新增 `packet_l0_use`，并入 `pair_ok`：
   ```verilog
   wire packet_l0_use = dec_we && !(dec_mul || dec_div) &&
                        ((dec_u1_h && (dec_rd == dec_rs1_h)) ||
                         (dec_u2_h && (dec_rd == dec_rs2_h)));
   ```
   被拒的 lane 1 下一拍作为下一个 packet 的 lane 0 重新发射，操作数来自
   `ex_value` / `m_value` / 寄存器堆，全是寄存器源。

面积：利用率 27% → **26%**。综合时序：50 MHz 下 **WNS +0.334（19.666 ns）**，
v31 同点为 −1.344 —— 逻辑短了 1.68 ns。

### 3.1 但综合报告暴露了第二条同样长的路径

v32 综合后的最差路径换了头：

```
w_csr (fanout 77) -> N634[1] (fanout 20) -> u_csr/read_data_16..34 (5 级)
  -> csr_rdata[3] -> N174[3] -> 寄存器堆写数据 -> 写穿透 -> 读 mux
  -> alu_a[3] -> u_alu
```

即 **CSR 读数据在 WB 拍组合地穿进 EX 的 ALU 操作数**。它不是假路径：`wb_value` 对
`csrr*` 指令取 `csr_rdata`，而 `regs` 把写穿透并进了读 mux（那是 distance-3 的旁路）。

交付版的 19.355 ns 最差路径是同一家族（`w_valid -> u_csr/read_data_5[3]_2 -> alu_a[8]`）。
**换句话说：这个设计一直有两条 ~20 ns 的路径，拆掉一条只会露出另一条。**
下一步（v33）必须同时解决 CSR 读这条，才能把频率真正抬起来。

## 4. 验收门槛（不变）

上板五项 CRC `e9f5 / e714 / 1fd7 / 8e3a / bd59`，`Total ticks = 533,875,894`（2800 迭代），
逐位不变 ⇒ 5.2447 CoreMark/MHz。CoreMark 跑通本身就同时是功能判据：配对规则若破坏
任何语义，CRC 立刻不一致。
