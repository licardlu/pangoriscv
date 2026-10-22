# 计划 v8（P13）：模块化布线 + 120 MHz 攻坚

状态：执行中（2026-10-22）
起点：`05cece2`，`Total ticks` 3,833,976 / 20 迭代 = **5.217 CoreMark/MHz**（仿真，五项 CRC 全对）。
时序起点：`p14timing120`（同一 RTL、PERF off、120 MHz 约束）详细摆放后
**WNS −10,410 ps**，即最差路径 ≈ 18.75 ns；布线 312 轮仍有 ~3,780 条未布通（不收敛）。

本轮目标（按用户指令：5.2 分 + 120 MHz + 模块化布线 + 注意面积 + 总结错误经验）：

| 目标 | 现状 | 本轮判据 |
|---|---|---|
| 分数 ≥ 5.2 CM/MHz | 5.217（已达） | 任何 RTL 改动后 20 迭代 `Total ticks` ≤ 3,846,585 且五项 CRC 全对 |
| 120 MHz 时序 | 摆放差 10.4 ns | 8.333 ns 约束下 `All Constraints Met` + 失败端点 0 |
| 模块化布线 | 未做（无任何物理区域约束） | R_FETCH/R_ICACHE/R_CORE/R_DCACHE/R_MEM/R_IO 六区落地并 A/B |
| 面积 | LUT 17.3k / FF 7.7k / LUTRAM 3,684 | `check_area_budget.py` 通过；本轮不加面积（物理约束不动 RTL） |
| 错误经验 | mistakes-log 至 §45 | 新增条目只收"下次遇到同样现象能直接告诉查什么/怎么办"的 |

---

## 1. 先把 120 MHz 的账算清（动手前，用实测数字）

`p14timing120` 给的是**当前 RTL、真实约束、摆放终值**，不是估算：

```
Worst slack after detailed placement = −10,410 ps（TNS −97.4 M）
⇒ 摆放期最差路径 8.333 + 10.410 = 18.74 ns
⇒ 按 mistakes-log §43 校准（布线后比摆放再差 ~4 ns）⇒ 真实 fmax ≈ 43~45 MHz
```

120 MHz 需要 8.333 ns，**要再砍 55%**。可砍的杠杆只有两类：

1. **布线分量**（摆放期 ~18.7 ns 里 route 约占一半，见 p7_path40b 的 56.5%）。
   模块化布线（物理区域）直接打这一块。乐观估计能拿回 3~5 ns。
2. **逻辑深度**（Logic 11.3 ns 的构成见 §2）。T1a（计数器抽头打拍）和 T1b
   （下一 PC/预测校验并行）已在 `1fba07d`/`b528d84` 落地，p14 已含。
   剩下的深度在"旁路 mux → ALU/比较 → br_taken → 重定向 → 冲刷"这一段。

**结论（先写死，避免做完再找说法）**：模块化布线 + 无 CPI 损失的收路径，
现实上限是 **60~80 MHz**。到 120 MHz 必须把执行/分支结清拆成两级流水
（EX 拆级或 RD/EX 拆级），那一刀**必然动分支惩罚**，要用 CPI 折算后再动，
作为独立的 P14 处理。本轮先交付"模块化布线后能过约束的最高频率 + 5.2 守住"。

如果本轮结束实测超过上述估计（比如模块化后 100 MHz 布通），立刻上调目标冲 120。

---

## 2. 当前关键路径要先解剖再动刀

p7_path40b（旧 RTL）的 39 级路径是：
`w_rd_h → rd_valid_h(fanout 65) → fwd2 → u_mul APM x2(9 ns) → alu.slt 比较链 →
br_taken(fanout 33) → ex_next 加法链 → 预测校验链 → br_miss(fanout 133) →
perf_if_wait → cnt/CECO x16(2.18 ns)`。

其中 u_mul（P8 已摘）、计数器尾巴（T1a + 交付 PERF off 已消）、
三条串行加法（T1b 已并行）。**当前路径构成未知，必须重测**——
所以 S0 先跑 40 MHz 满实现拿 `.rtr` 文本（`report_timing` 只认 PnR 后数据库，§34）。

按 .rtr 逐条分类：可砍（fanout 寄存复制、并行化、死逻辑）/ 不可砍
（动一拍就吃 CPI）。不可砍的留给 P14。

---

## 3. 模块化布线方案（本轮主菜）

依据 `docs/architecture/module-area-plan.md` 的 34 张模块卡（第 8 字段"物理区域"）
与 skill §9.9 三条规矩：**最宽最频繁的总线不跨 region；两个 LUTRAM 阵列不共用走廊；
BRAM/DRM 放外圈**。

### 3.1 六个区域与归属（与 module-area-plan 卡片字段 8 一致，2026-10-22 同步）

| 区域 | 矩形（x1,x2,y1,y2） | 实例 | 依据 |
|---|---|---|---|
| `R_ICACHE` | (10,28,0,245) | `soc.core.instruction_cache`、`soc.program_ram` | 64b/拍取指总线两端同侧；程序 ROM 的 DRM 列 x=26 画进本区 |
| `R_FETCH` | (30,50,0,245) | `soc.core.ifu`、`soc.core.cpu.u_bp` | 与 `R_ICACHE`/`R_CORE` 都相邻；BTB 在取指环上（卡 M03） |
| `R_CORE` | (58,86,20,225) | `soc.core.cpu`（regs/ALU/2mul/div/CSR/ctrl） | **必须含 x=86 的 APM 列**，两个乘法器才落得进；紧凑方块，区内关键路径（旁路→ALU→比较→重定向） |
| `R_DCACHE` | (90,108,0,245) | `soc.core.data_cache`、`soc.core.lsu`、`soc.data_ram` | 与 `R_CORE` 相邻；data_ram 是 2,048 LUTRAM（M2 被阻断）要 CLMA 列；与 I 侧不共走廊 |
| `R_IO` | (110,122,0,245) | `soc.fabric`、两个 AXI 引擎、uart/gpio/timer/spi/irq | 薄适配器与外设，贴引脚一侧 |

DRM 列（x=26/54/106）与 APM 列（x=86）是硬件固定资源，区域矩形把它们含进对应集群。

### 3.2 物理实现形式

PDS 的区域约束有两个入口，都落成 `def_region` / `def_inst_region`：

- FDC：`define_global_attribute {PAP_REGION} {...}` + `define_attribute {i:...} {PAP_REGION} {...}`，
  dev_map 沿层级展开到 GTP 实例。
- PCF/Tcl（**本轮采用**）：`firmware/code/platform/pango_native/pango_native_floorplan.tcl`，
  `run_pds_flow.py --floorplan <file>` 在 dev_map 之后 source 它。用 Tcl 而不是 PCF 文本，
  是为了让每个 `def_*` 都能 `catch` 并把结果打进 run.log——静默失效的区域约束
  和生效的约束在日志上长得一模一样（mistakes-log §34 的教训）。

坐标系：`show_device` 输出的站点名 `CLMA_<x>_<y>` 的后缀就是 floorplan 坐标
（x∈10..122、y∈0..245；26/54/106 为 DRM 列、86 为 APM 列）。`.rtr` 里的
`CLMA_<A>_<B>`（A≤357、B≤1219）是**另一套网格编号**，不要混用。

### 3.3 区域几何（编码了两个硬事实）

```
x 10          28 30      50  58            86  90          108 110     122
  [  R_ICACHE  ][ R_FETCH][    R_CORE      ][   R_DCACHE   ][   R_IO   ]
  icache+prog   ifu+u_bp  cpu regs/ALU/APM   dcache+lsu+data  fabric+
  ROM(DRM x=26)            (APM 列 x=86!)   ram(LUTRAM)      perips
  |<-- 64b fetch bus -->|  |<-- lsu/mem -->|
```

1. `u_mul`/`u_mul_h` 是 APM 原语，而全芯片 APM 列只有 x=86 ⇒ `R_CORE` 的矩形
   **必须含 x=86**，否则乘法器在区内无处安放。
2. `soc.data_ram` 是 2,048 个 LUTRAM（M2 转 BRAM 被阻断）⇒ 它要 CLMA 列，
   不能只给 DRM 列；放 D 侧集群（load miss 回填最短）。

### 3.4 风险与回退

| 风险 | 处置 |
|---|---|
| 坐标标定错 → 约束失效或工具报错 | 校准构建先验证"落点确实改变"，否则不进主流程 |
| 区域太小放不下 | 逐区查 `device_map` 的 Used 数；按 1.5× 裕量起步 |
| 区域反而变差（拥塞） | 同种子 A/B；变差就按 .rtr 重排边界，一次只动一个区 |
| 报告口径 | 摆放 WNS 与布线 WNS 分开报；只有 `All Constraints Met` 的实现才报 fmax |

---

## 4. 执行顺序（每步单独测量、单独提交）

1. **S0 解剖**：`run_pds_flow.py --tag p13anat40 --freq 40 --mode full`（已在跑）
   → `.rtr` 文本，当前路径构成 + Logic/Route 占比。
2. **S0b 标定**：校准构建确定 def_region 坐标系（一次，~10 分钟，只到 placement）。
3. **S1 落区域**：写 `pango_native_floorplan.fdc`，提交（`module: pnr-physical`）。
   RTL 不动 ⇒ 分数、面积天然不动。
4. **S2 A/B**：同 RTL 同种子，无区域 vs 有区域：
   - 120 MHz 停在 placement 比 WNS（布线不收敛时路由数字无意义）；
   - 40/50/60 MHz 满实现比 routed WNS 与 .rtr 路径；
   - 二分找出**能 All Constraints Met 的最高频率**（可报口径）。
5. **S3 收路径**：按 S0 的 .rtr 逐条砍无 CPI 损失项；每刀
   `run_coremark_sim.py --tag ...` 20 迭代，五项 CRC 全对 + ticks 不得差 >0.5%，
   差了立即 `git checkout` 回退并记 mistakes-log。
6. **S4 收尾**：证据目录、mistakes-log、area-budget.csv、门禁、清理、提交。

## 5. 本轮不做的（以及为什么）

- **EX/RD-EX 拆级**：唯一能到 120 MHz 的路，但必然把分支结清推后一拍
  （`mispred=88,087`，+1 拍 ≈ +2.3% ticks ⇒ 5.217→5.09，先破 5.2 再谈 120）。
  要做必须先有 CPI 折算表 + kill_young/br_miss 全套重审，放 P14 单独一轮。
- **D-Cache 第二读口 / R6 写路径 / BTB 扩容**：v7 §4 已排后，理由不变。
- **为好看拆模块**：skill §9.8，模块边界阻断跨边界优化，通常加面积。

## 6. 标定记录（坐标系已定）

- `show_device` 命名 `CLMA_<x>_<y>` 的后缀**就是 floorplan 坐标**（`def_region` 用的就是这套）：
  x ∈ {10,14,18,22,30,...,122}（24 列；26/54/106 是 DRM 列、86 是 APM 列），
  y ∈ {0,1,4,...,245}（120 行）。CLMA 1,940 + CLMS 660 = 2,600 tiles。
- `.rtr`/`clk_region_info.txt` 里的 `CLMA_<A>_<B>`（A∈21..357 step 6、B∈6k/6k+1、
  11,675 个）是**网格编号**（约 6× 细于 tile 编号），只用于读时序报告，
  不要拿去当 def_region 坐标。
- `def_region` 越界值的行为：_（S2 的 run.log 里 FLOORPLAN 行会给出）_
- 实例名格式：`def_inst_region` 接受 `soc.core.cpu`（点）还是 `soc/core/cpu`（斜杠）：
  _（同上，fp_bind 两种都试并打印）_

## 7. 实测记录（随执行更新）

- p14timing120（起点，无区域）：placement WNS **−10,410 ps** @120 MHz；
  布线 312 轮 3,787 条未布通，已终止（路由器空转）。
- S0 40 MHz 解剖：_（填）_
- S2 A/B：_（填）_
