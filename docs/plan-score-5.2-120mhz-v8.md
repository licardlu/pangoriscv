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

### 3.2 物理实现形式（踩坑后定稿）

PDS 的区域约束两个入口最终都落成 `def_region` / `def_inst_region`：

- FDC：`define_global_attribute {PAP_REGION} {...}` + `define_attribute {i:...} {...}`。
- **PCF（本轮采用）**：`firmware/code/platform/pango_native/pango_native_floorplan.pcf`，
  `run_pds_flow.py --floorplan <file>` 用 `add_constraint` 在 dev_map 之后与板级 PCF 一起载入。

**不能用 `source` 载 Tcl 版**：pds_shell 在项目创建阶段就会执行被 source 的脚本，
此时设计数据库还不存在，裸 `def_region` 会把整个 shell **静默打死**
（无错误、无日志、exit 0——和 mistakes-log §11 的"无镜像位流"同级别的坑）。
区域约束必须走**约束文件**通道（deferred 解析），不能走脚本执行通道。

坐标系：**还在标定**（见 §6）。`show_device` 的 `CLMA_<x>_<y>` 后缀与 `.rtr` 的
`CLMA_<A>_<B>` 网格编号都不是 `def_region` 直接接受的坐标——第一轮按前者写被
`ConstraintEditor-0027: illegal floorplan coordinates` 全部拒绝。另注意
`PhysicalConstraintEditor-4040`：**只允许一个 .pcf**，后加的会顶掉板级 pcf。

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

## 6. 标定记录（进行中）

- `show_device` 命名 `CLMA_<x>_<y>`：x ∈ {10,...,122}、y ∈ {0,...,245}（2,600 tiles）。
- `.rtr`/`clk_region_info.txt` 网格命名 `CLMA_<A>_<B>`：A ≤ 357、B ≤ 1,219（11,675 个，约 6× 密）。
- **第一轮坐标标定（p13fp120b，已实测）**：按 show_device 空间写的 `def_region R_* 10 28 0 245`
  全部被拒：`ConstraintEditor-0027: Region value contains illegal floorplan coordinates`。
  ⇒ show_device 后缀**不是** def_region 坐标（推翻 §3.2 的假设）。
- **实例名（p13fp120b，已实测）**：斜杠形式 `soc/core/cpu`、`soc/uart_inst` 报
  `PhysicalConstraintEditor-0023: Instance ... cannot be found`。净表里的路径确实是
  `soc/fabric/...`、`soc/uart_inst/...`（合成日志可证），但约束命令要的是**点号**形式
  （UCE 手册示例 `u_top_module.sub_module`）——下一轮用 `soc.uart_inst` 试。
- **载入通道（p13fp120b，已实测）**：`PhysicalConstraintEditor-4040: Only one .pcf file can
  be added, old .pcf file is cleared` —— 后加的 floorplan.pcf 会**顶掉**板级 pcf（IO LOC）。
  最终形态要么合进一个 pcf，要么走 FDC 的 `PAP_REGION`。
- **第二轮坐标探针（p13fpcal2）——边界已钉死**：
  `y ≤ 203`（203 收、220/244/245 全拒）；`x ≤ 122` 且 `x≥118` 时 `y ≤ 199`
  （`(118,122,0,203)` 被拒、`(0,122,0,199)` 收）；零宽矩形 `(122,122,...)` 被拒。
  ⇒ **def_region 合法域：x∈[0,122]、y∈[0,203]，右上角 x≥118 时 y≤199**。
  y_max=203 恰好 = 网格 B_max/6（1219/6=203）——`def_region` 坐标疑似网格名编号的
  (A/3, B/6)；但 x=122 的存在（T15 收）说明 x 侧含 IO 环，网格名 A≤357 不够解释。
  **不依赖该映射**：floorplan 只需要"区域相对位置与合法性"，APM 列用宽矩形覆盖
  （R_CORE x[58,88] 含 show_device 的 x=86 APM 列）。
- 实例名：**两种都写**（点号在前、斜杠在后），被拒的那行只是 log 里的 E:，
  不阻断流程；以实际绑定成功的为准（下一轮 run.log 的 def_inst_region 行）。

## 7. 实测记录（随执行更新）

| 构建 | 约束 | 改动 | 结果 |
|---|---|---|---|
| `p14timing120`（起点） | 120 MHz | 无区域 | 摆放 WNS **−10,410 ps**（路径 ≈18.7 ns）；布线 312 轮 3,787 条未布通，终止 |
| `p13anat40` | 40 MHz | 无区域 | 摆放 WNS **+1,475 ps**（满足式约束下工具不压时序，路径 ≈23.5 ns）；布线 273 轮后 pds_shell 无解释退出，剩 2,119 条未布通，**无 .rtr** |
| `p13fp120b` | 120 MHz | 区域（坐标错） | `ConstraintEditor-0027` 全拒 + 实例名斜杠被拒；pnr 13 s 失败 |
| `p13fpcal`/`p13fpcal2` | 120 MHz | 坐标探针 | 坐标合法域钉死：x≤122、y≤203、x≥118 时 y≤199（见 §6） |
| `p13fp120c` | 120 MHz | 区域（坐标对） | 5 个 region 全部 OK；核心实例绑定 OK（点/斜杠都被收），perips 实例被合成拍扁（找不到，无害）；**pnr 在 constraint check 后失败** |
| `p13po120` | 120 MHz | 仅 `-place_only`、无区域 | 摆放 WNS **−10,410 ps**——与 p14 逐位相同 ⇒ `-place_only` 没问题，可复现 |
| `p13fpmin` | 40 MHz | 5 regions + 4 绑定（点号） | 绑定全部 "successfully"，pnr 仍死 |
| `p13fpbig` | 40 MHz | 1 region + 1 绑定（整芯片区域绑 cpu） | **pnr 仍死** ⇒ 任何 `def_inst_region` 都崩 |
| `p13fpro` | 40 MHz | **只定义 region、无绑定** | **pnr 正常进入摆放**（super clustering, slack −21,850）⇒ 崩溃点在绑定机制 |
| `p13fpfdc` | 40 MHz | FDC 通道 `PAP_REGION` | _（填：绕开 PCF 绑定的备选通道）_ |

**崩溃隔离结论**：`def_region` 本身无害，`def_inst_region` 让 PDS 2022.2-SP6.1 的 pnr
在 "Constraint check end" 后 15 秒内以空错误退出（`E: Failed to execute the script : `）。
即使"整芯片区域只绑一个 cpu 实例"也崩——不是容量问题、不是名字问题、不是 `u_bp`
父子冲突，是**绑定机制本身**在这条流程上不可用。绕行：FDC 的 `PAP_REGION`
（dev_map 展开成 GTP 级属性）。

---

# 修订（2026-10-22 12:30，用户指令）：布线收敛优先 + 结果必须上板

用户指令明确：**"目前最大问题是布线不行"**，且**"最后的结果必须上版子验证才有效果"**。
据此把本轮的优先级倒过来：先让布线收敛、出位流、上板实测，再谈 120 MHz 与区域约束。

## R1. 布线不收敛的三个假设（按可证伪性排序）

实测事实：40 MHz 无区域约束时**摆放是过的**（WNS +1,475 ps），全局布线 15 轮后 0 条未布，
但**详细布线**在 27k→2.1k 条卡死（273 轮后 pds_shell 无解释退出，无 .rtr）。
120 MHz 同样卡死（3,787 条 / 312 轮）。⇒ 不是时序目标不可达这么简单，是详细路由器收不了尾。

| 假设 | 机制 | 判别实验 |
|---|---|---|
| **H1 hold-fix 空转** | `-fix_hold_violation_in_route TRUE` + threshold 0 ps：慢性 hold 路径（cache tag 写地址）反复被拆线重布，"未布数"其实是在被拆 | `pnr` **不带任何 hold 参数** 跑 40 MHz，看详细布线能否收敛 |
| **H2 拥塞** | LUTRAM 阵列（data_ram 2,048 + cache ~3,000 + regfile）挤在走廊里，细节路由器最后 2k 条是真挤 | `-plc_decongestion 1`（pnr 自带的摆放去拥塞模式）+ `-dump_router_congestion_plot TRUE` |
| **H3 路由器自己** | 单线程、迭代上限 | `-number_of_router_thread 4`（p13routeA 在跑） |

先跑 H1（最便宜、最可能）；H1 不中再叠 H2/H3。**只要有一次完整布通，就以此为基线。**

## R2. 上板验证链（最终判据）

位流在**真实硬件**跑 CoreMark、UART 抓输出、五项 CRC 全对，才算数（skill 硬性规则）。
工具链项目里都是现成的（`evidence/records/bottleneck_audit/board/`）：

1. **频率真相**：`pangoriscv_top.v` 的 GTP_PPLL 是 `F=56/O=12` ⇒ 核时钟 **126 MHz 硬编码**。
   旧交付（3.8557 板测）是 `core_clk = clk` 直通 27 MHz（PLL 是 `179ff4b` 为 126 MHz
   目标才加的）。**当前核 ~23 ns 的路径直接跑 126 MHz 必然花屏** ⇒ 上板位流必须把
   PLL 改到时序能过的频率（PPLL 合法域 VCO 1330..2133、PFD≥19 ⇒ F∈50..79，
   可达频点：F=56 时 O=56→27、O=42→36、O=36→42、O=28→54…MHz）。
2. **位流口径**：PLL 频点 = 时序约束频点 = 镜像 `--cpu-mhz`（UART 波特率与秒数换算）。
   迭代数按 "ticks/iter ÷ 频率 ≥ 10 s" 反推（27 MHz 约 1152 迭代，与旧交付同法）。
3. **流程**：`gen_bit_stream` 出 .sbit → `cdt_cfg.exe -file 01_program_sram.tcl`
   （`PANGO_SBIT`/`PANGO_JTAG_PORT`）烧 SRAM → `capture_uart.ps1` 115200 8N1 抓输出
   → 核对 `Total ticks` / 五项 CRC / `Correct operation validated`。
4. **三项同源**：分数、ticks、LUT、时序报告必须出自这同一份位流（skill §3）。

## R3. 120 MHz 与模块化布线在本轮的定位

- **5.2 分**：上板实测就是最终判据（仿真 5.217 只是预测）。
- **120 MHz**：实测摆放差 10.4 ns、详细布线不收敛；上板频点以"布通 + 时序过"为准。
  120 MHz 要走 P14 拆流水线（分支惩罚 +88k ticks ⇒ 折算后 5.10，会跌破 5.2）——
  **不在本轮赌**，写清边界。
- **模块化布线**：PCF 的 `def_inst_region` 会让 pnr 15 秒内空错误退出（隔离实验证实：
  只定义 region 不绑定 → 正常；任一绑定 → 崩）。备选通道是 FDC 的 `PAP_REGION`
  （dev_map 展开）。在布线收敛之后、时间允许时上这条通道，目标是给 LUTRAM 阵列
  疏通走廊（H2 的根治手段）。
- **面积**：本轮动的是平台层（PLL 参数）与约束，核心 RTL 不动 ⇒ 面积不变，仍以
  p12 的 LUT 18,723 / FF 9,478 为准（PERF on 口径）。

## R4. 执行顺序（修订）

1. H1：无 hold 参数的 40 MHz 全流程（`p13routeB`）——判 hold 空转假设。
2. 不管 H1 结果，用最松的 27 MHz 约束拿一次完整布通（保底基线 + .rtr 路径解剖）。
3. 按布通结果定上板频点 F_run（要留 ≥2 ns 裕量）→ 改 PLL 参数（`module: pangoriscv_top`
   提交，Δ0 面积）→ 重建镜像（`--cpu-mhz F_run`、迭代 ≥10 s）→ 出位流。
4. 烧板 + 抓 UART + 核 CRC/分数 → 证据入 `evidence/records/optimization/p13-board-verify/`。
5. 若时间还有：FDC `PAP_REGION` 模块化布线 A/B（对拥塞与最差路径），守住分数面积。
6. 错误经验（布线类）进 mistakes-log；清理 build 下 A/B 目录；README 状态块刷新。

## 8. 布线收敛战报（13:00-14:00 实测）

| 实验 | 配方 | 详细布线结局 |
|---|---|---|
| p13anat40 / p13routeB2 | 交付 hold 参数 / `--plain-pnr` | 卡 2.1~2.5k，**震荡** ⇒ hold 参数不是原因 |
| p13routeC | +`-plc_decongestion 1` | 无尾部改善 |
| **p13seed7** | `--plain-pnr -gplace_seed 7 -plc_decongestion 1 -share_router_control_signal TRUE` | **285 轮收 0**，全程单调下降 |
| p13combo2 | FDC 区域约束 + decongestion + CE-share + dc_duplication（无 seed） | 尾部 ~1.2k 震荡（好于 2.2k 但不收） |

**根因：摆放随机性 + 拥塞**。`-gplace_seed 7` 换了一个摆放，详细布线就能收敛——
这是本轮的"钥匙"。区域约束（模块化布线）把尾部从 2.2k 压到 1.2k 但单独不够；
两者叠加（seed + 区域）未测（时间优先给上板）。

**p13seed7 时序（40 MHz 约束，同一位流构建）**：
`All Constraints Met`；setup WNS **+0.558 ns**、hold WHS +0.033 ns、0/66,481 失败端点；
估计 fmax **40.56 MHz**（24.65 ns 路径）。关键路径：`cpu/rr_rs1[*]` →
`instruction_cache/rsp_data_hi_q` / `ifu/q_pc|q_pred`（R_CORE→R_FETCH/R_ICACHE 跨界）。

**上板位流 `p13board36`**：PLL 27×56/42 = **36 MHz**（24.65 ns 路径留 3.1 ns 裕量；
42 MHz 装不下、126 MHz 必花）、`pango_native_36mhz.fdc`、镜像 2000 迭代/`--cpu-mhz 36`
（10.65 s ≥ 10 s）、同 seed7 布线配方。摆放 WNS **+3,095 ps** ✓。

**⚠️ 重要教训（补）**：同一 seed 不同 PLL 净表 → 摆放不同 → 可布性不同。
`p13board36`（36 MHz PLL、seed 7 同款配方）在 2.6k 处**开始震荡**（2,605→2,441→2,641），
与 seed7（126 MHz PLL 净表）285 轮收 0 不是同一回事。**换 PLL 后必须重新找 seed**。
已并行开 `p13b36s3`（seed 3）与 `p13b36s13`（seed 13 + dc_duplication）重试。
