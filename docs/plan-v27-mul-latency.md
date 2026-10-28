# v27 —— 把乘法器从关键路径上拆掉（先计划、后执行）

> 触发：v26 的满流程把最差路径从 D\$ 换成了**乘法器**，而且给出了逐段账：
> 一个 33×33 有符号乘法在 v26 的网表里串了 **9.9 ns**，还挂在 lane 0 的 ALU 后面。
> 本轮只做这一件事，判据先写死。

---

## 0. 依据（v26 实测，`build/v26_ic_bram_50/report_timing/pangoriscv_top.rtr`）

```
Startpoint  soc/core/cpu/ex_valid
            -> alu_y[20] -> fwd1_h[20]                       (ALU + 旁路)
            -> u_mul_h/N17_m1/PO[0]   1.969 ns  -> P_0[19]    1.362 ns
            -> net 2.850 ns
            -> u_mul_h/N17_m3/PO[0]   1.608 ns  -> P_0[11]    1.362 ns
            -> net 0.719 ns -> prod[52] -> ex_value_h[20]
Data arrival 24.275 ns   Logic 7.859 (36%)  Route 13.787 (64%)   Slack -2.178
```

综合报告 `synthesize/apm_drm_lutram_utilization.log` 说明了为什么串这么深：

| APM | X Size | Y Size | Cascade |
|---|---|---|---|
| `u_mul_h/N17_m1` | 24(unsigned) | 17(unsigned) | `CPO>>24 + N17_m2` |
| `u_mul_h/N17_m2` | 17(unsigned) | 9(signed) | / |
| `u_mul_h/N17_m3` | 24(unsigned) | 16(signed) | `CPO>>24 + N17_m4` |
| `u_mul_h/N17_m4` | 16(signed) | 9(signed) | / |

一个 33×33 被拆成两条 `PO→P` 级联，再在两个物理站点之间拉一根 2.85 ns 的网线。
**而且这 9.9 ns 是 `mul`（CoreMark 高频使用）在付**，因为低 32 位和高 32 位出自同一个阵列。

---

## 1. 两个改动（都不改语义）

### 改动 1（rev 1.3，`build/v27b_mullo_56`）：`mul` 用截断的 32×32

```
wire [31:0] lo = a * b;        // 目标宽度截断，综合器可以剪掉上半部分
...
assign y = (op == MUL_MUL) ? lo : prod[63:32];
```

正确性来自二进制补码本身：**乘积的低 32 位与操作数按有符号还是无符号解释无关**
（`prod_signed[31:0] == (a*b)[31:0]`，对任意 a,b 恒成立）。

综合结果（`build/v27b_mullo_56/synthesize/...`）：

```
32 x 32  Multipliers := 2      <- 新增，每 lane 一个，给 `mul` 用
33 x 33  Multipliers := 2      <- 保留，只给 mulh/mulhsu/mulhu 用
u_mul/N0_m1  24x17  P=41   standalone
u_mul/N0_m2  17x8   P=8    standalone
u_mul/N0_m3  24x15  P=15   standalone     <- 三条都是独立块，没有级联
```

面积：LUT 17,174 → **17,087**（−87），APM 8 → 14，DRM 12 不变。
**低 32 位这条路从"2 条级联 + 2.85 ns 跨站点网线"变成"单块 APM + LUT 加法树"。**

### 改动 2（rev 2.0）：`mulh*` 改成两级流水，付一拍 `mulh_wait`

高位三条指令本来就不可能在 8 ns 里算完，所以把 33×33 显式拆成两级：

```
A = ah*2^17 + al        (ah: 16 位有符号, al: 17 位无符号)
A*B = ah*bh*2^34 + (ah*bl + al*bh)*2^17 + al*bl
```

- 第 1 级：4 个部分积（各 1 块 APM，互相独立，没有级联）→ 打拍
- 第 2 级：66 位加法树 → 输出 `[63:32]`

`rv32_top` 用 `mulh_wait` 冻结一拍，形状与 `div_wait` 完全一致
（`mulh_issue` 只在 `!mulh_done_q` 时成立，所以每个乘法只捕获一次；
冻结期间 `rr_*` 不变，所以捕获的部分积不会被覆盖）。

**代价**：每条 `mulh/mulhsu/mulhu` 多一拍。CoreMark 计时循环里这三条指令预计不出现，
所以代价应当接近 0 —— 但这是**假设**，必须用 `Total ticks` 实测确认。

---

## 2. 正确性验证（没有 Verilog 仿真 license，所以分两半做）

| 部分 | 手段 | 结果 |
|---|---|---|
| 算术分解是否位精确 | 用 Python 复刻 RTL 的位宽语义，对 4 种 op × 200,484 组向量（含 11×11 边界值对）比对精确 33×33 乘积 | **800,484 组，0 不符** |
| 流水/冒险是否正确 | 上板：`Total ticks` + 五项 CRC | 见 §3 |
| `mulh*` 是否真的对（CoreMark 可能根本不执行它）| 新镜像 `tests/example/mulh_test`（24 组向量 × 4 条指令，期望值是离线算好的字面常量，结果用内联汇编读回，防止编译器把被测对象常量折叠）| 见 §3 |

边界向量包含 `0 / 1 / 2 / 0x7fffffff / 0x80000000 / 0xffffffff / 0x80000001 /
0xfffffffe / 0x00010000 / 0xffff0000` 的全组合——`mulh` 的正负号陷阱全在里面。

### 2.1 `mulh_wait` 的两种错误写法（写代码时各撞了一次，记下来）

**错法一：用裸的 "done" 标志。**
```
mulh_done_q <= mulh_issue;            // 每个乘法置一拍
mulh_wait = mulh_any && !mulh_done_q;
```
连续两条 `mulh` 时，第一条在 N 拍置位，N+1 拍标志仍是 1，**第二条直接跳过等待、拿走第一条的积**。

**错法二：把 kill 项放进 `mulh_wait`。**
`mulh_wait` 送入 `hold_ex`，而 `br_miss_h` 读 `!hold_ex`、`kill_young` 又来自 `br_miss_h`，
于是 `hold_ex → br_miss_h → kill_young → mulh_wait → hold_ex` **组合环**。

**最终写法：用 PC 当身份证。**
```
mulh_same = mulh_v_q && (rr_pc == mulh_pc_q);
mulh_wait = mulh_any && !mulh_same;
```
- 连续两条 `mulh` 的 PC 必然不同 ⇒ 第二条正确等待；
- 被 kill 的乘法会被 PC 不同的下一条替换 ⇒ 自动"没算完"，不需要把 kill 项接进来（环也不存在）；
- 等待期间 `hold_ex` 冻结 `rr_*`，操作数不动 ⇒ 寄存的部分积一直对应当前这条指令。

---

## 3. 验收判据

| 项 | 判据 | 说明 |
|---|---|---|
| 功能 | 上板五项 CRC = `e9f5 / e714 / 1fd7 / 8e3a / bd59` | 任何一项不符即作废 |
| 分数 | `Total ticks ≤ 192,307 × 3000`（56 MHz 镜像 3000 迭代） | 换算 ≤ 5.20 |
| 时序 | `report_timing` 的 `WNS ≥ 0`、失败端点 0、`Estimated` ≥ 56.0000 MHz | 56 MHz 预算 17.857 ns |
| 可布性 | `Unrouted nets = 0` | ≥54 MHz 的真正门槛 |
| 运行时长 | ≥10 s（3000 迭代 @56 MHz = 53.6 s，远超） | |

---

## 4. 已知风险（按严重度）

1. **`mulh*` 的冒险逻辑没有任何仿真覆盖**（本机 ModelSim 无 license，lesson 109）。
   缓解：形状完全照抄 `div_wait`（同一条 `hold_ex` 通路）；算术已用 Python 证明；
   剩余风险是接线级的（op 译码、lane 选择），靠代码复核 + CoreMark CRC。
2. **CoreMark 可能根本不执行 `mulh*`**，那样 CRC 就覆盖不到改动 2 的功能。
   缓解：若 56 MHz 通过，再用 ISA 用例做一次上板回归（`tools/run_isa_e2e.py` 的镜像
   若能直接装进 program.hex，就可在板上跑 21 个用例）。
3. 56 MHz 需要 17.857 ns，而本族网表布线后的历史分布是 19.3~21.5 ns（跨度 2.2 ns）。
   即使路径真的短了 6 ns，**一次抽样仍可能落在分布右侧**。判据是先看
   `Estimated Frequency`，再看 WNS。

---

## 5. 结果

（待 v27b / v28 落定后填写）
