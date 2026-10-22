# 计划 v7：把分数推到 5.2，把时序推到 120 MHz

状态：执行中（2026-10-22 起）
起点：`ab17e77`，`Total ticks` 4,070,391 = **4.914 CoreMark/MHz**；
120 MHz 流程 `p13timing120` 不收敛（after placement −12,452 ps，布线不收敛）。

本轮只做两件事，每件事单独提交、单独测量：

| 阶段 | 目标 | 改哪个模块 | 判据 |
|---|---|---|---|
| **S1** | 5.2 CM/MHz | `icache_axi` + `ifu_axi` | `Total ticks` ≤ 3,846,585 |
| **T1** | 120 MHz 收敛 | `rv32_top` / `perf_regs` | `All Constraints Met` + `Estimated Period ≤ 8.333 ns` |

---

## 1. S1 的依据：5.2 就等于"把跨行取指变成成对"

§9.7 已经把预算算死了：

```
周期 ≈ 取指交付次数      4,090,694 周期 / 3,558,046 次交付
如果每次交付都成对        6,622,907 / 2 = 3,311,454 次交付 ⇒ 约 3.84 M 周期 = 5.20 CM/MHz
```

`refused_pair=550,214` 一分钱捡不到（memmem/lduse/mduse 是单读口与串行语义的**下限**），
`alone=22,740` 是串行语义。剩下的 `single=493,185` 才是纯供给损失，其中：

| `fetch_pc[4:2]` | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| 次数 | 43,602 | 27,215 | 24,917 | 31,197 | 48,178 | 15,866 | 109,655 | **192,555** |

`off=7` 独占 39%。原因是一条硬件边界：`hit_pair = (hit_word_off != 3'd7)`
（`icache_axi.v:139`）—— 成对需要 `(word7, word8)`，而 word8 在**下一条 32 B 行**，
两个词落在两个不同的组（`set` 与 `set+1`），而数据阵列只有一个读口。

### 为什么 off=7 会反复出现，而不是"顺流早就不在 7 上"

在 off=6 请求 `(6,7)` 后指针走 `+8`，所以**顺序流永远不会在 7 上请求**。
off=7 只来自重定向目标（分支目标 / 循环回边）。CoreMark 的热循环回边落在 off=7 上，
每次回边都要单独取一次 word7 —— 这正好解释了 `off[7]` 是 `off[5]` 的 12 倍。

**关键**：这类 off=7 的取指，其后续 word8 在第一次之后**一定已经在 I-Cache 里**
（第一次会 miss 并整行填充，之后每次回边都是命中）。所以跨行成对的命中率接近 100%，
不是"碰运气"。

### 做法（不改地址切片、不改 ARLEN、不动行长）

1. 在 `icache_axi` 里加两个 64 项的旁路阵列，索引 `set`，每项 53 b = `{tag[20:0], word0[31:0]}`：
   `succ0_mem` 存 way0 的那一行，`succ1_mem` 存 way1 的那一行。整行填充完成时顺带把
   `{tag_q, beat0 数据}` 写进去（beat0 已经在 `even_mem` 里落过一次，这里只是多一个副本）。
2. 读侧：`nxt_set = req_set + 1`，`nxt_tag = req_tag + (req_set == 63)`，
   两个阵列同时读，谁 tag 对上就用谁的 word0。
3. 有效性用两个可清位的 FF 阵列 `succv0/succv1`（128 个 FF）。
   `invalidate` 在这个 SoC 里是**电平**（`.invalidate(halt_req || halt_pending || halted || protocol_fault)`），
   不是脉冲，所以"invalidate 期间清 0"就够了，不需要 64 拍扫描，也不会漏。
4. `hit_pair = (hit_word_off != 7) || xline_ok`；`hit_word_hi` 在 off=7 时取 `succ_word0`。
5. `ifu_axi` 的 `expect_pair` 现在不能只看地址：它必须**和 cache 的判定逐位一致**，
   否则 `next_pc_q` 会走错（少一条指令 = CRC 崩）。所以从 cache 引一条组合输出
   `req_pair_ahead` 给 IFU，在同一拍（请求握手那一拍）用。cache 的响应寄存器
   也是在同一拍用同一个值装载的，两边**按构造一致**。
6. miss 时 `xline_ok` 天然为 0（`hit0||hit1` 为假），于是 off=7 的 miss 仍然只回一个词，
   IFU 也按"不成对"走 `+4`，与 `IC_MISS_RD` 的 `rd_pair=(rd_word!=7)=0` 一致。

面积代价（按 skill §9.4 需要单列，本轮**自行批准并记录**）：

| 项 | Δ |
|---|---|
| `succ0_mem`/`succ1_mem` | +53 × 64 × 2 = 6,784 b ≈ **+106 LUTRAM** |
| `succv0`/`succv1` | **+128 FF** |
| 两个 64:1 有效性选择 | **+~44 LUT** |
| `fill_w0_q` | +32 FF |

这是本轮唯一越过"Δ(LUT+FF+LUTRAM) ≤ 0"的改动，理由：它换来的是 39% 的单发损失，
是本轮唯一一条能单独打到 5.1 以上的路；且 LUT 只用 26%、FF 只用 5.8%，
加 300 个原语不改变拥堵结论。已写进 `docs/architecture/area-budget.csv`。

---

## 2. T1 的依据：不是布线器不努力，是单拍 39 个逻辑级

`p7_path40b` 布线后的真实报告（`report_timing`）给出的最差路径：

```
w_rd_h -> rd_valid_h (fanout 65, route 1.370) -> fwd2[15]
       -> u_mul APM 级联 x2            (~9.0 ns，两级 APM)
       -> u_alu_h N1.slt_* COUT 链      (32 b 有符号比较)
       -> br_taken_h -> ex_next_h COUT 链 (32 b 下一 PC)
       -> N665.eq_* COUT 链             (32 b 预测校验)
       -> br_miss_h (fanout 133, route 1.715)
       -> perf_if_wait -> cnt[2][*]/CECO x16 (16 级计数器进位链, 2.18 ns)
```

三个 32 位宽加法/比较**串在同一拍**，尾巴上还有 16 级计数器 CE 链。三条改法都不吃分数：

| 编号 | 改法 | 消掉什么 | 代价 |
|---|---|---|---|
| **T1a** | 性能计数器的事件抽头打一拍 | 路径末端 16 级 CECO 链 + `perf_if_wait` 一整坨锥 | 每抽头 1 FF |
| **T1b** | 分支条件用**独立比较器**，不经过 ALU 的 `y`；下一 PC 与预测校验并行算 | 把"比较 → 选下一 PC → 校验"三条串行链压成 max(比较, 加法) + 一跳 | 0（LUT 中性，比较器本来就在 ALU 里） |
| **T1c** | 乘法器**单独一级**（APM 级联移出 EX 拍） | 9 ns 的两级 APM | 每次 mul→紧邻使用 +1 拍（`mduse=72,211`，−1.7%） |

T1a/T1b 先做，量完再决定 T1c——如果 T1a+T1b 后 `Estimated Period` 已经接近 8.33 ns，
就不必付 T1c 的分数。

---

## 3. 执行顺序与回退

1. 写本文档（已完成）→ 提交。
2. S1：`icache_axi` + `ifu_axi` 一起改（两条信号必须同时存在，否则 IFU 走错 PC），
   跑 `sim20_o2`，必须五项 CRC 全对；`Total ticks` 不到 3,846,585 就继续找。
3. T1a：`perf_regs` 事件抽头打一拍，跑综合 + 120 MHz 摆放，看 `Estimated Period`。
4. T1b：`rv32_top` 分支比较/下一 PC 并行化，同上。
5. T1c：只有在 3、4 之后仍 > 10 ns 时才做，并单独量分数。
6. 任何一步 `Total ticks` 变差超过 0.5%，`git checkout` 回退并在 `mistakes-log.md` 记一条。

## 4. 本轮不改的东西（以及为什么）

- **D-Cache 第二读口**（`memmem=256,088`）：净代价 0.48 拍/次，收益 ≈ 123k，
  但要复制 4 KB 数据阵列 + tag + 写通路，是本轮 S1 的 4 倍面积与风险。排在 S1 之后。
- **写路径 R6 完整版**：`ST_WR_DRAIN` 占窗口 1,465,313 拍，但 `WIN_STALL mem=216,633`
  说明 store 队列放深度只值这么多；把写引擎改成 2 深投递是另一条独立工作流。
- **BTB 32→128**：+2.2k FF，且 §9.6 的探针显示 `mispred=88,087` 已经不大。
