# P14 — 零 CPI 路径手术 + 模块化布线：冲 120 MHz（v9）

> 前置事实（全部实测，来自 `p13-board-verify`）：
> 分数 **5.213 CM/MHz 板上实测**（5.2 达成）；fmax ≈ **40.6 MHz**（24.65 ns 路径）；
> 布线收敛配方已掌握（`-gplace_seed N -plc_decongestion 1 -share_router_control_signal TRUE`）。
> 本轮唯一缺口：**频率**。用户指令：5.2 分 + 120 MHz，模块化布线，注意面积，必须上板。

## 0. 关键路径解剖（p13seed7 .rtr，40 MHz 约束 slack +0.346）

```
24.65 ns = Logic 4.23 ns (17.5%) + Route 19.89 ns (82.5%)，27 级逻辑
```

链条（跨 4 模块的组合长链）：
`rr_rs1(扇出44) → 旁路 → ALU×3级 → fwd1_h → mem_addr 加法链 → ls_req_addr
 → dcache early_req 译码 → mem_wait → hold_ex 门 → redirect_valid(扇出61)
 → ifu fetch_ptr/ocnt_q → if_req_addr → I$ tag_mem 读 → hit0(扇出71) → _N82(扇出159!)
 → odd_mem 读 → hit_word_hi 选择 → rsp_data_hi_q 寄存器`

**三个可动刀的结构性事实**：
1. **I$ tag→data 串行读**：数据阵列索引含 `hit_way`（= f(tag 比较)），tag 比较在数据读**之前**——
   尾部 5 跳 ~5.2 ns 白白串行。拆 way 后两路并行读、按 hit 后选，**零 CPI、面积中性**（总位数不变）。
2. **route 占 82.5%**：.rtr 坐标横跨 x∈[135,327]、y∈[798,1158]——icache 自己的阵列就散在
   135~261。模块化布线（把 cpu/dcache/ifu/icache 焊进相邻紧凑区）+ 巨扇出复制是主战场。
3. **巨扇出**：_N82(159)、_N96351(148)、N56(117)、hit0(71)、redirect_valid(61)、rr_rs1(44)。

## 1. 目标与预算

| 项 | 现状 | 目标 | 判据 |
|---|---|---|---|
| CoreMark/MHz | 5.213（板上） | **≥5.2 保持** | 20it 仿真 ticks ≤ 192,307/iter（5.2 线），CRC 五项全对 |
| fmax | 40.6 MHz | **≥120 MHz** | 约束下 report_timing setup/hold 0 失败端点 |
| 面积 | LUT 17,869 / FF 7,823 / LUTRAM 3,790 | Δ(LUT+FF+LUTRAM) ≤ 0（复制类例外走 D1+CSV 记录） | check_area_budget.py |
| 交付 | — | **位流上板实测**，≥10 s，CRC 全对 | UART 抓取 |

频率口径（skill §3）：报**约束频率/收敛实验最高频率**，不混称。PLL 可用频点（VCO=27F∈[1330,2133]，F∈50..79，CLKOUT=27F/O）：
126(56/12)、121.5(72/16)、120.7(76/17)、118.5(79/18)、116.3(56/13)…
**恰 120.000 不可达**（需 F=40/O=9，VCO 越界）。取 ≥120 的最高可闭合点上板。

## 2. 手术清单（按 ROI 排序，全部零 CPI 优先）

### S1 — I$ 并行 way 读（icache_axi.v，ΔLUTRAM 0）
把 `even_mem/odd_mem`（512×32，索引 {set,way,off}）拆成 `even_w0/even_w1/odd_w0/odd_w1`
（256×32，索引 {set,off}）：命中路径**无条件**读 w0/w1，`hit_way` 只做输出级 mux。
tag 比较与数据读并行。读口结构不变（每阵列仍 2 读口：命中 + miss 回放），总位数不变。
写路径按 `way_q` 分流。预期砍 ~2.5-3 ns。
**回归**：run_icache_tests.py 全过 + CoreMark 20it CRC 五项一致、ticks 不变（功能等价）。

### S2 — 模块化布线 v2（FDC PAP_REGION 通道，PCF 通道已证崩）
紧凑线性带（y 收窄强迫打包）：`R_ICACHE | R_FETCH | R_CORE | R_DCACHE | R_IO`，
R_CORE 含 APM 列 x=86；两个 LUTRAM 阵列（I$ 数据 / data_ram）不同走廊；data_ram 在 R_DCACHE。
关键路径四模块（cpu/dcache/ifu/icache）必须**相邻**（现状布局顺序已对，问题是区太大没压住散点）。
y 带收窄到 [40,160] 量级；绑定实例用**点号**形式（斜杠报 cannot be found，§47）。

### S3 — 巨扇出治理
rr_rs1 寄存复制（ALU 侧/访存侧各一份，+32 FF 例外，记 D1+CSV）；
`-dc_duplication TRUE` 进 pnr；观察 _N96351/N56 是否被复制。

### S4 — 频率阶梯实测
place-only 先探 WNS（8.333 ns 约束），再满实现 + seed 抽签（配方已证）。
判据链：Unrouted 单调下降=收敛；WNS≥0 且 hold 0 失败=可报频。

### S5 — 上板交付（最终判据）
按闭合频点选 PLL（约束周期=板上周期，不混称）→ 镜像迭代数 = ceil(10.5 s × f / ticks_per_iter) →
`--cpu-mhz F` → 位流 → JTAG 烧 SRAM（cdt_js + 01b_program_only.tcl）→ **先开串口后烧录**
（capture_uart.ps1，-ExecutionPolicy Bypass）→ 核对 CRC/分数/ticks。

### S6 — 若 120 不达：升级选项（按代价排序）
(a) clock 树平衡（capture 比 launch 少 0.575 ns）；
(b) `early_req/mem_wait/redirect` 门重构（收窄 hold_ex 锥）；
(c) EX 拆级（+1 拍/mispredict）——**必须先测 mispred 实数并找 CPI 补偿**（BTB 扩容），
    折算后 <5.2 则否决，写清边界（用户要求 5.2 与 120 兼得，不可单保频率破分数）。

## 3. 执行顺序

1. S1 RTL 手术 + 仿真回归（icache 单测 + CoreMark 20it）
2. S2 floorplan v2 + S3 扇出（同轮 pnr）
3. S4 频率阶梯（120 → 121.5 → 126 逐级探）
4. S5 上板 + 证据
5. mistakes-log（可复用条目）、area 门禁、build 清理、README 状态刷新

**回退判据**：任何改动使 20it ticks 变差 >0.5% 或 CRC 变 → 立即回退；
上板 CRC 任一失配 → 该位流作废，不得报分。
