# P15 — 零 CPI 路径手术 II + 物理优化：冲 120 MHz（v10）

> 接手时间 2026-10-22 19:10。前置：v9 的结论（S1 已落地、floorplan v2 负优化）。
> 本文是我（接手者）**自己复核后**的判断，不是照抄 v9。所有数字都标了出处。

## 0. 复核结论（先纠三个认知错误）

1. **真正参与综合的核是 `rtl/core/rv32/rv32_top.v`，不是 `pangoriscv.v`。**
   `soc_config.vh` 默认 `define CORE_RV32`，`pangoriscv_axi_top.v:66` 用 `ifdef CORE_RV32`
   选 `rv32_top`。v9/交接文档里"cpu 模块"的关键路径（`rr_rs1`/`hold_ex`/`br_miss`）
   全在 `rv32_top.v`。**改 `pangoriscv.v` 对位流零影响**——上一轮若真按 pangoriscv.v 动手，
   会白做。这是本轮第一个要钉死的事实。
2. **24.65 ns 里 19.89 ns 是布线，平均 0.74 ns/跳。** 同器件相邻 tile 约 0.15~0.25 ns，
   说明 **40 MHz 约束下 placer 根本不为这段路优化**（松弛 16 ns，它把逻辑摊开降拥塞）。
   所以"fmax=40.6 MHz"不是设计上限，是"没被要求"的结果：同 RTL 换 8.33 ns 约束做
   place-only，摆放 WNS 立刻从 −16 收到 −10.4（≈18.7 ns）。**基线口径必须写清**。
3. **拆流水线的 CPI 代价被 v9 高估了。** v9 说 +1 拍/mispredict = 88k ticks/20it（2.3%）。
   实测数字在 `rv32_top.v:748` 注释里：**54,455 mispredict / 20 it**，即 2,723/迭代；
   照 191,699 ticks/迭代 折算 **+1 拍 = +1.42% CPI → 5.213/1.0142 = 5.14**。
   仍然击穿 5.2，但量级是 1.4% 不是 2.3%。**结论不变：任何 +1 拍的重定向都不可接受。**

## 1. 目标与硬预算

| 项 | 现状 | 目标 | 判据 |
|---|---|---|---|
| CoreMark/MHz | 5.213（板上） | ≥5.20 | 20it 仿真 ticks ≤ 192,307/iter，CRC 五项全对 |
| **CPI 预算** | 191,699 ticks/iter | **≤192,307** | **只剩 608 ticks/iter = 0.32%** |
| fmax | 40.6 MHz（40 MHz 约束） | 120 MHz | 8.333 ns 约束下 setup/hold 0 失败端点 |
| 面积 | LUT 17,869 / FF 7,823 / LUTRAM 3,790 | Δ(LUT+FF+LUTRAM) ≤ 0 | check_area_budget.py |
| 交付 | — | 上板实测 ≥10 s、CRC 全对 | UART 抓取 |

**硬约束推导**：0.32% 的 CPI 余量意味着
- 不能加流水级（+1.42%）；
- 不能给 load 加拍（CoreMark 每迭代 load 数百条，同样秒杀预算）；
- 只能做**逐位等价、零 CPI** 的结构手术 + 物理优化。

## 2. 关键路径解剖（p13seed7 `.rtr`，40 MHz 约束构建）

```
24.65 ns = Logic 4.23 (17.5%) + Route 19.89 (82.5%)，27 级
rr_rs1(44) → N225_6 → N225_9 → _N96351(148) → alu_a → u_alu → alu_y
 → fwd1_h → mem_addr_h → ls_req_addr → dcache early_req → mem_wait(17)
 → [br_miss 被 !hold_ex 门控] → redirect_valid(61) → ifu ocnt_q → N56(117)
 → if_req_addr(25) → I$ tag LUTRAM DO → tag 比较 → hit0(71) → _N82(159)
 → I$ data LUTRAM DO → mux → rsp_data_hi_q
```

两类病灶，量级都很清楚：

| 病灶 | 证据 | 占比 |
|---|---|---|
| **A. 虚假依赖**：`br_miss` 被 `!hold_ex` 门控，而 `hold_ex ⊃ mem_wait ⊃ dcache early_req ⊃ mem_addr ⊃ ALU` | `rv32_top.v:736` | 中段 5 跳 ≈ 4.4 ns（15.6→19.97） |
| **B. 巨扇出 + 摊开摆放**：44/117/148/159 扇出的网各 0.7~1.65 ns，单跳 0.9~1.3 ns | `.rtr` net 列 | 尾段 + 前段 ≈ 14 ns |

## 3. 手术清单（全部零 CPI，按 ROI 排序）

### S2 — 摘掉 `br_miss` 的 `!hold_ex`（**本轮主刀**）

`br_miss = rr_valid && is_ctrl && !hold_ex && !ex_trap_w && ctrl_miss_w`

`hold_ex = mem_wait || div_wait || trap_wait`。但要证明：**lane0 是控制指令时，
`mem_wait` 恒为 0**：
- `ex_is_mem = rr_valid && (rr_load || rr_store) && !ex_trap_w`：`rr_load/rr_store` 与
  `is_ctrl` 是对同一 opcode 字段的互斥译码（0x03/0x23 vs 0x63/0x6f/0x67）；
- `ex_is_mem_h` 需要 `rr_v1 && (rr_load_h||rr_store_h)`，而配对规则
  （`pair_ok`：`ctrl0` 只与 `alu1` 配，`alu1` 排除 load/store）保证 lane1 不是访存；
- `div_wait`：lane0 控制 ⇒ 非 div；lane1 在 `ctrl0` 配对下是 ALU ⇒ 也非 div。

所以 `mem_wait`/`div_wait` 对 `br_miss` 是**冗余门控**，唯一真正需要的是 `trap_wait`
（老指令在 WB 陷入且 `trap_ready` 低时，重定向必须让位于 trap）。

新形式（**行为等价，仅去掉假依赖**）：
```verilog
wire lane1_mem_raw = rr_v1 && (rr_load_h || rr_store_h);   // opcode 级，不含地址
wire br_miss = rr_valid && is_ctrl && !trap_wait && !div_wait &&
               !lane1_mem_raw && !ex_trap_w && ctrl_miss_w;
```
保留 `lane1_mem_raw` 是**防御性**的（万一配对不变量被将来的改动破坏，行为退回原样）。
`br_miss_h` **不动**（lane0 可能是访存，`!hold_ex` 在那里是真需求）。

预期：砍掉 dcache 往返 5 跳 + `mem_wait` 扇出网，**≈4~4.5 ns**。

### S3 — 巨扇出治理（零 CPI）

`.rtr` 里 5 条网的扇出分别是 44 / 117 / 148 / 159 / 71，每条 0.7~1.65 ns。

1. `-dc_duplication TRUE` 进 pnr（若该开关存在），让工具自动复制；
2. 手写寄存器复制：`rr_rs1` 按消费者分组各留一份（+32~64 FF，走 D1+CSV 备案）；
3. `redirect_valid`（扇出 61）：拆成"给 IFU 的"和"给 kill/flush 的"两路寄存缓冲——
   注意它必须是**组合**的（S2 才刚把它从 dcache 里捞出来），只能复制不能寄存。

### S4 — 压缩摆放（物理）

上一轮 floorplan 的教训是"收窄 y 带的线性带更差"。原因不是区域约束无效，而是**做法**：
线性带把 5 个模块排成一条横跨全宽的带，关键路径反而要横穿。本轮改为：
- **紧凑 2D 方块**（不是带），只约束 `cpu + ifu + icache + dcache` 四个模块进同一片
  相邻区域，让 4 次跨模块的路径落在 2~3 个 CLB 列内；
- 先 place-only 探 WNS（8.33 ns），**只有比无区域的 −10.4 ns 更好才继续**；
- 区域文件走已验证的 FDC `PAP_REGION` 通道（PCF 通道证崩，§47）。

### S5 — 频率阶梯 + 上板

place-only 定性 → 满实现（`--plain-pnr` + 收敛 seed）→ `report_timing` → 位流 → 上板。
PLL 频点：120.7(76/17) / 121.5(72/16) 为 ≥120 的最近点（**恰 120.000 不可达**）。

## 4. 判据与回退

- **每改一处 RTL**：CoreMark 20it 仿真 `Total ticks` 与基线**逐位一致**（功能等价），
  CRC 五项一致；icache/ifu/isa 单测绿。变差 >0.5% 立即回退。
- **面积门禁**：`check_area_budget.py --mode baseline --tolerance 1.0` 非零不提交。
- **时序判据**：8.333 ns 约束下 setup WNS ≥ 0 且 hold 0 失败端点，才算"可报频"。
- 上板 CRC 任一失配 → 该位流作废。

## 5. 边界声明（必须先写清，避免自欺）

按 S2+S3 的收益估算（24.65 → 约 14~16 ns），**本轮的现实落点大概率是 60~90 MHz，
不是 120 MHz**。要到 120 MHz 还差 2 倍，只有两条路，都要付 CPI：

| 路线 | 代价 | 结论 |
|---|---|---|
| 重定向寄存 1 拍 | +1.42% CPI → 5.14 | **击穿 5.2，否决** |
| I$ 命中拆 2 拍 | +1.42% CPI（同一条重定向路径） | 同上，否决 |
| 微架构重写（深流水 + 强预测） | 分数回落到 3.5~4.0 | 与 5.2 目标冲突 |

因此本轮按"**先钉死 5.2、把频率做到零 CPI 能到的极限**"执行；如果最终停在 70~90 MHz，
报告里三项指标照实写（约束频率 / 收敛实测 / LUT 同源），并把 120 MHz 的边界写成
"需要 +1.42% CPI，与 5.2 互斥"。**不拿仿真或工具外推当板测。**

## 6. 执行顺序

1. 基线仿真复核（新工具链重建镜像 → 20it ticks 必须与 RTL 改动前一致）
2. S2 改 `rv32_top.v` + 仿真回归
3. P&R：无区域 8.33 ns place-only（比 −10.4 ns 好？）→ 满实现 seed 抽签
4. S3/S4 迭代（按实测决定先后）
5. 定频上板 + 证据目录 + mistakes-log + README/模块卡同步

## 7. 实测记录（随执行更新）

| 构建 | 配置 | 结果 |
|---|---|---|
| base_oct22 | HEAD RTL + 新镜像（GCC 15 重建 20it） | `Total ticks 3,833,976`，与交付位流口径**逐位一致**；cycles 5,716,551 / retires 7,025,687 / mispred 68,827 / CRC 0x4983 → **基线锚点** |
| s2（第一版） | br_miss 去掉 `!hold_ex`，外加 `lane1_mem_raw` 防御项 | **失败**：CoreMark 在 retire 2855 分歧，0xc8 的 JAL 丢失重定向，错路 0xd0 被退休，traps=1 |
| s2b（修正版） | `ctrl_hold_ok = !trap_wait && !div_wait` | **通过**：cycles/retires/mispred/CRC 与基线**完全相同**，`Total ticks 3,833,976` → 零 CPI 成立 |
| p15po120a | 8.333 ns 摆放探测，seed 3，无区域 | 摆放 WNS **−11,055 ps**（TNS −100,700,932）⇒ 摆放上限 19.4 ns |
| p15po120b | 同上 + 紧凑 2D 方块（96×146，只绑 soc.core） | **−13,800 ps**，比无区域更差 ⇒ 区域约束第三次负优化 |
| p15po120c | 同上 + `-dc_duplication/-logic_optimize/-dispose_dram_prior/-parallel 8` | 8/8 seed 因单 license 失败，无数据 |
| p15r50 | 50 MHz 满实现，seed 3，decong 1 + CE-share + dc_dup | 摆放 **+1.036 ns / TNS 0**；布线 18,810@7 → 11,549@21（斜率 240/轮）**不收敛**，34 min 终止 |
| p15r45 | 45 MHz 满实现，seed 7，decong 1 + CE-share | 摆放 **+1.162 ns / TNS 0**；布线 18,470@5 → 9,237@26（斜率 226/轮）**不收敛**，38 min 终止 |
| p15r45b | 45 MHz，seed 3，decong 2 + `-dispose_dram_prior` | 摆放 **+1.300 ns / TNS 0**；布线起点更差（21,859@4）**不收敛**，23 min 终止 |

**结论**：摆放已经不是瓶颈（45/50 MHz 都 TNS=0），**详细布线是瓶颈**，且是"收敛速度"而非
"不可达"——单调下降但斜率衰减，总在 9k~11k 处变平。36 MHz（27.78 ns）仍是唯一能出位流的频点，
PLL 已回退 56/42。下一轮第一件事：验证 **S1 是否是布线恶化的元凶**（P13 的 285 轮收敛在 S1 之前）。

**S2 为什么会踩坑（写进 mistakes-log）**：`lane1_mem_raw = rr_v1 && (rr_load_h||rr_store_h)`
看起来是"配对不变量"的安全复述，实际会**反向**生效——冻结期间 lane1 的旧译码仍在，
于是一条本该成立的重定向被挡住。真正的保证已经在设计里：`ex_is_mem_h` 带
`!ctrl_miss_now`，而 `ctrl_miss_now` 就是 `rr_valid && is_ctrl && ctrl_miss_w`，
与 `br_miss` 的触发条件同源。**结论：这条路径上只有 `trap_wait`/`div_wait` 需要保留。**

## 8. PDS `pnr` 的完整选项表（本轮新发现，之前只用过 3 个）

用 `pds_shell` 的 `help pnr` 直接导出（`build/_help`）。与"冲频率"直接相关的：

| 选项 | 作用 | 本轮用途 |
|---|---|---|
| `-dc_duplication TRUE/FALSE` | **Design Cells Duplication**——自动复制高扇出单元 | 直接打 `.rtr` 里 44/117/148/159 扇出的 5 条网 |
| `-logic_optimize_enable TRUE` | 摆放期逻辑优化 | 可能重排 27 级 |
| `-logic_optimize_lut6d_combing_strategy N` | LUT6D 打包策略 | 深度压缩 |
| `-dispose_dram_prior TRUE` | 分布式 RAM 优先摆放 | 把 I$ 的 LUTRAM 阵列贴到消费逻辑旁（当前偏了 126 列！） |
| `-dispose_carrychain_prior TRUE` | 进位链优先 | ALU/地址加法链 |
| `-parallel N` `-gplace_times N` `-saved_outcome 1` | **多种子并行摆放，留最好的一次** | 一次跑 8 个 seed，直接解决"可布性靠抽签" |
| `-route_parallel N` `-route_saved_outcome 1` | 多种子并行布线 | 同上 |
| `-place_worst_slack ps` | 摆放期 WNS 目标 | 逼工具更狠 |
| `-refineplacement_mode/-iteration/-cluster` | 精修摆放 | 最后一档 |
| `-slack_weight N`、`-pin_cost_increasing_speed N` | 时序权重 | 调优 |
| `-fast_router` | 快速布线（放弃质量） | 不用 |
| `-number_of_router_thread` | **本器件不支持**（Flow-0182） | 不用 |

这一条本身就是本轮最大的流程收获：**"只能靠 seed 抽签"是工具用法没吃透，不是工具限制。**


## 9. 120 MHz 的边界：三条硬数据（本轮实测，不再是推断）

### 9.1 摆放上限 ≈ 19.4 ns（120 MHz 目标下工具能到的最好摆放）

```
p15po120a  seed 3, 8.333 ns 约束, -place_only:
  Worst slack after detailed placement is -11060
  Worst slack is -11055  (TNS after placement -100,700,932 ps)
```
⇒ 120 MHz 目标下，**工具能把最差路径摆到约 19.4 ns**，离 8.333 ns 差 2.3 倍。
同一次摆放过程中最差松弛从 −23.1 ns（post-GP）一路收到 −11.1 ns，说明工具已经尽力，
不是"没优化"。`-dc_duplication TRUE` 那一档（p15po120c）因为单 license 并行失败，未取得数据。

### 9.2 区域约束第三次证明是负优化

| 实验 | 形状 | 摆放 WNS（8.333 ns 目标） |
|---|---|---|
| p13po120 | 无区域 | −10,410 ps |
| p14po120b | v2 窄 y 带（五条竖带，x 10..117） | −10,998 ps |
| **p15po120b** | **紧凑 2D 方块（96×146，只绑 soc.core）** | **−13,800 ps（更好？没有，更差）** |
| p15po120a | 无区域（S1+S2 后） | −11,055 ps |

**结论**：三种形状（横带、竖带、方块）都是负优化。在这个 27% 利用率的设计上，
**区域约束削弱的是 placer 分配逻辑的自由度，换不来足够的邻近性**——因为关键路径的
27 级里绝大多数跳是"逻辑相邻但没有物理相邻"的短跳，压区域并不能让它们变短，
反而让拥塞集中在方块边界。**这条路封死，别再试第四种形状。**

### 9.3 CPI 预算：任何 +1 拍的重定向都不可接受

```
mispredict 实测 68,827 / 20 iter = 3,441 / iter
ticks/iter 191,699；5.2 的线是 192,307 ⇒ 余量 608 ticks/iter = 0.32%
+1 拍/mispredict = +3,441 ticks/iter = +1.8% ⇒ 分数 5.12 < 5.2
```
所以 P14（EX 拆级）、重定向寄存、I$ 命中拆两拍——**全部否决**，不是保守，是算术不允许。

### 9.4 结论（写进报告的话术）

> 本设计在 5.2 CoreMark/MHz 这个 CPI 上，等效需要**单周期内完成
> ALU→AGU→D$ 请求→退休判决→重定向→IFU→I$ tag 比较→I$ 数据读出→写回寄存器**
> 这一整条链（27 级）。这条链就是 5.2 分的来源：它让重定向的惩罚是 **0 拍**。
> 把它拆成 2 拍，CPI 掉 1.8%，分数掉到 5.12。**5.2 与 120 MHz 在同一个微架构上互斥。**
> 同时得到两者需要重写微架构（深流水 + 强预测 + 更大的 BTB），分数会回落到 3.5~4.0。
