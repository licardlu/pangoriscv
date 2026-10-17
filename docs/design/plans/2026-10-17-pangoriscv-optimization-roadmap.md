# pangoriscv 分数优化路线图（2026-10-17）

> **目标**：在**不改变现有代码框架**的前提下，把三项评分指标逐项推高，且每一分都有可复现证据。
> **前提**：当前无物理开发板，本计划所有验收都是「仿真 + PDS」。板上实测按 §8 单独排期。
> **基线**：`evidence/records/coremark-sim-2026-10-17/`（400 迭代，GCC 15.2.0，三开关全开）。

---

## 0. 基线数字（所有优化的对照基准，不得改动这份记录）

| 项 | 基线值 | 来源 |
|---|---|---|
| Total ticks | **306,415,752** | 仿真 |
| 周期数 | 308,000,765 | 仿真 |
| 退休指令 | 115,803,118 | 仿真 |
| 每迭代指令数 | **289,508** | 115,803,118 ÷ 400 |
| 每迭代周期 | **770,002** | 308,000,765 ÷ 400 |
| 每指令周期 | **2.66** | 308,000,765 ÷ 115,803,118 |
| IPC | **0.3760** | — |
| 分支预测失败率 | **12.39%** | 3,040,222 ÷ 24,535,660 |
| trap / 总线故障 | 0 / 0 | — |
| CoreMark/MHz | **1.3054** | 评分项① |
| 约束频率 | 27 MHz（Setup WNS +16.440 ns） | 评分项② |
| Total LUTs | **12,572**（as logic 9,887 + as DRAM 2,685） | 评分项③ |
| CoreMark/LUTs | 0.1038 每 kLUT | 评分项③ |

**已定位的结构性事实**：

| 项 | 值 | 结论 |
|---|---|---|
| I-Cache 容量 | 32 组 × 2 路 × 32 B = **2 KB** | 程序 text = **13,324 B**，只装得下 15% |
| D-Cache 容量 | 同上 = **2 KB** | data+bss = **4,720 B**，只装得下 43% |
| 乘法器 | `ex.v:141` 组合 `*`，PDS 推断 3 组 APM | **已是 1 拍，无优化空间** |
| 数据 RAM 读 | `axi_ram.v:170` 已是同步读 | 被推成 LUTRAM 是工具选择，不是 RTL 结构问题 |
| 分支冲刷代价 | 重定向在 retire 时刻，惩罚 ≈ 2 周期 | 3.04 M × 2 ≈ 6 M 周期，仅占 **2%** |

---

## 1. 防止框架混乱的五条铁律

1. **每个优化必须能一键关掉**：新行为一律挂在 `rtl/core/soc_config.vh` 的开关后面，关闭时编译结果必须与基线**逐位等价**（用 A/B 跑同一镜像对比 ticks 与 CRC）。
2. **一次只动一个变量**：一个提交只做一件事，禁止"顺手改个命名/顺手重构"。
3. **接口合同冻结**：`CPU ↔ 访存`、`CPU ↔ CSR`、`AXI 端口列表`、`firmware 可见寄存器映射` 一律不改。优化只在模块**内部**改。
4. **每次必过三重门**（缺一不可，见 §3）：ISA 端到端 → CoreMark 五项 CRC → 同镜像 ticks 对比。
5. **新增文件必须登记**：RTL 新文件要进 `sim/native_axi_sources.f`，否则仿真与 PDS 会各自看到不同设计（这是最隐蔽的一类 bug）。

> 反例记录（本次已踩过，写进铁律）：`tb_coremark_uart.sv` 的探针名与 `axi_uart.v` 实际信号不一致，导致 vopt 精化直接失败 13 处。**测试台探针名必须与 RTL 信号名同步改。**

---

## 2. 阶段划分总览

| 阶段 | 内容 | 主攻 | 预期收益 | 风险 | 前置条件 |
|---|---|---|---|---|---|
| **P0** | 测量脚手架 | — | 0（但是后面一切的前提） | 低 | 无 |
| **P1** | 周期分诊 | — | 0（决定后面做哪个） | 无 | P0 |
| **P2** | 扩大 I/D-Cache | ① 执行效率 | **大**（估 +40~70% IPC） | 中 | P1 确认 miss 高 |
| **P3** | load-use 前递 | ① 执行效率 | 中 | **高** | P1 确认 LSU_WAIT 高 |
| **P4** | 分支预测增强 | ① 执行效率 | 小（≤5%） | 低 | P2/P3 之后 |
| **P5** | 提频 | ② 频率 | 中（27→~40 MHz） | 中 | 独立线，可并行 |
| **P6** | 强制数据 RAM 进 BRAM | ③ 资源效率 | **大**（LUT −21%） | 低 | 无 |

**推荐执行顺序**：`P0 → P1 → P6 → P2 → P3 → P5 → P4`。
把 P6 提前，是因为它几乎零风险、且能立刻拿掉 21% 的 LUT，为 P2 扩 Cache 腾出资源预算。

---

## P0 · 测量脚手架（不改设计）

### P0.1 让 CoreMark 跑完自动打印性能计数器

**改什么**：`tests/example/coremark/core_portme.c` 的 `portable_fini()` 末尾。

**为什么放这里**：`core_main.c` 在 `stop_time()` **之后**才调 `portable_fini()`，所以打印落在计时区外，**不影响 ticks**。这是关键约束。

**寄存器映射**（`rtl/perips/perf_regs.v:13-40`，直接照抄 `tests/example/perf_probe/main.c:25-37` 的宏）：

| 偏移 | 含义 |
|---|---|
| `0x00` | CTRL：写 bit0 = SNAP（必须写，读才返回快照） |
| `0x04` | STATUS：bit0 = snapshot_valid |
| `0x10/0x14` | CYCLE（64 位） |
| `0x18/0x1C` | INSTRET（64 位） |
| `0x20/0x24` | IF_WAIT（64 位） |
| `0x28/0x2C` | LSU_WAIT（64 位） |
| `0x30/0x34` | I_MISS（64 位） |
| `0x38/0x3C` | D_MISS（64 位） |
| `0x40/0x44` | RET_CF（64 位） |
| `0x48/0x4C` | MISPRED（64 位） |
| `0x50..0x78` | AXI 活动计数（I_AR/I_AR_LEN7/I_R_BEAT/… /D_B） |

**验收**：
- 日志出现全部 9 个计数；
- **`Total ticks` 必须仍等于 306,415,752**。若变了，说明打印进了计时区，立即查调用位置。

**排错**：
- 全 0 → 没有先写 `CTRL.SNAP`（`perf_regs.v:36-38` 明确：不 SNAP 读到 0）；
- 读到 0 且 STATUS 也是 0 → 位流不是 `PERF_ENABLE` 编的；
- 计数离谱 → 64 位读取顺序错（先读 lo 再读 hi 会被撕裂）。

### P0.2 建立 A/B 记录表

新建 `evidence/records/optimization/ab-log.csv`，每行：阶段 / 开关状态 / ticks / IPC / I_MISS / D_MISS / IF_WAIT / LSU_WAIT / LUT / WNS / CRC 是否全对。**后面每一步都必须新增一行**。

### P0.3 确认仿真确定性

同一镜像连跑两次，ticks 必须完全一致。不一致说明 TB 有随机性，后续所有对比都不可信。

---

## P1 · 周期分诊（不改设计，只读数据）

### 要回答的问题

308 M 周期里，115.8 M 用于退休指令，**192.2 M 是空转**。这 192 M 花在哪？

### 方法

用 P0.1 打出来的计数，按下表估算占比：

| 指标 | 含义 | 判断 |
|---|---|---|
| `I_MISS` | I-Cache 缺失次数 | 每次缺失 ≈ 8 拍突发 + 握手 ≈ 12~15 周期 |
| `D_MISS` | D-Cache 缺失次数 | 同上 |
| `IF_WAIT` | IF 级就绪但没取到指令的周期 | 取指饥饿 |
| `LSU_WAIT` | load/store 等结果的周期 | 访存停顿 |
| `MISPRED` | 预测失败次数 | ×2 周期 |

**⚠️ 已知陷阱**：`perf_regs.v:41` 明确写了 `IF_WAIT` 与 `LSU_WAIT` 是**重叠视图，不可相加**。不要把它们加起来当总停顿，会得出大于 100% 的荒谬结论。

### 决策树

```
I_MISS 估算代价 > 60 M 周期  → P2.1（扩 I-Cache）
D_MISS 估算代价 > 60 M 周期  → P2.2（扩 D-Cache）
I_MISS/D_MISS 都低，但 LSU_WAIT 很高 → P3（load-use 前递）
MISPRED × 2 > 20 M 周期        → P4（预测增强，否则跳过）
以上都不显著                    → 回头查 AXI 握手效率与 IFU 队列（P7 待定）
```

### 验收

产出一张"周期去向表"，各来源相加 ≤ 192.2 M，剩余部分标注"未归因"。**不允许把未归因的部分硬塞进某一项。**

---

## P6 · 强制数据 RAM 进 BRAM（先做，零风险）

### 现状纠正

旧文档说"数据 RAM 是异步读，改同步读可省 2,685 LUT"——**这条已过时**。`axi_ram.v:170` 现在是 `if(read_good) read_data<=mem[read_index];`，**已经是同步读**。PDS 仍然把可写的那块推成 LUTRAM（`GTP_RAM64X1DP ×2048`），而只读的程序 RAM 正确推成了 BRAM（`GTP_DRM36K_E1 ×4`）。

### 改什么

在 `rtl/perips/axi_ram.v` 的存储阵列上加 PDS 认可的 RAM 风格属性（候选写法，按 PDS 语法文档选定，需先小规模试一个）：

```verilog
reg [31:0] mem[0:WORDS-1] /* synthesis syn_ramstyle = "block_ram" */;
```

或等价 PDS 属性。**不改变任何时序语义**。

### 验收

- `Total LUTs` 从 12,572 降到约 **9,900**（LUT-as-DRAM 2,685 → 接近 0）；
- **ticks 必须与基线完全一致**（本改动不应改变任何时序行为）；
- `All Constraints Met` 保持。

### 排错

| 症状 | 原因 | 处理 |
|---|---|---|
| ticks 变了 | RAM 输出变成了组合路径被 CPU 直接依赖 | 检查是否有跨模块组合依赖；本设计应无 |
| PDS 报属性非法 | 属性名不是 PDS 的写法 | 查 PDS 语法文档，或改用综合脚本侧设置 |
| BRAM 数量暴涨 | 两块 RAM 都被推成 BRAM | 只有可写那块需要改，只读那块保持现状 |

### 回滚

删掉属性即可，一行改动。

---

## P2 · 扩大 I/D-Cache（主攻执行效率）

### P2.1 先把 I-Cache 地址切分参数化（**危险步骤，单独一个提交**）

**现状**：`icache_axi.v:79` 是 `localparam SETS=32`，而 set index / tag / word 的位宽是**硬编码**的（`icache_axi.v:17-19`：set index = `addr[9:5]`，word = `addr[4:2]`，tag = `addr[31:10]`）。

**做法**（不改变行为，先把结构参数化）：

```verilog
parameter integer SETS = 32,              // 改成 parameter，由顶层传入
localparam integer IDXW = $clog2(SETS),   // 32 组 → 5 位
// 所有 addr[9:5] 改成 addr[4+IDXW : 5]
// 所有 tag 位宽 22 改成 32-(5+IDXW)
```

**验收**：
- `SETS=32` 时编译后的仿真 ticks **与基线完全一致**（证明参数化本身零行为改变）；
- `tb_icache_axi` 单元测试全绿。

**这是本计划里最容易引入新 bug 的一步**，所以单独一个提交、单独验收、不允许和扩容量混在一起。

### P2.2 扩 I-Cache 容量

修改顺序（一次一档，每档都要过三重门）：

| 档 | SETS | 容量 | 预期 I_MISS 变化 |
|---|---|---|---|
| 基线 | 32 | 2 KB | — |
| 档1 | 64 | 4 KB | −40~50% |
| 档2 | 128 | 8 KB | −70~85% |

**验收**：I_MISS 显著下降 → ticks 下降 → CRC 全对 → LUT 增量可接受（目标总 LUT ≤ 16 k）。

**排错**：
- CRC 错 → 99% 是 tag 比较位宽没跟着改，或 line 有效位与 index 错位；
- 用 `sim/run_icache_tests.py` 单跑 Cache 随机测试定位，**不要**在整机层面猜；
- 若只有某些地址出错 → 看地址跨 4 KB 边界的突发是否越界（AXI 规定突发不能跨 4 KB）。

### P2.3 扩 D-Cache

`dcache_axi.v` 已参数化（`SETS`/`WAYS`），只需改 `pangoriscv_axi_top.v` 的实例参数。风险低于 P2.1。

**验收**：D_MISS 下降、ticks 下降、CRC 全对。

### P2.4 记录代价

每档都要记 LUT 增量与 WNS 变化。**Cache 增大通常会让 WNS 变好**（miss 少、切换少），但也可能因 tag RAM 变大而变差，必须实测。

---

## P3 · load-use 前递（高风险，必须先有 P1 证据）

### 前置条件（硬性）

**只有 P1 明确显示 `LSU_WAIT` 是主要空转来源，才做这一步。** 没有测量就做，等于赌博。

### 现状

`regs.v` 只有**同周期写回旁路**（EX 级写、ID 级读同一拍），load 的结果必须等 EX 完成才可用。所以 `lw` 后紧跟依赖指令必然停顿。

### 改什么

新增开关 `LOAD_FWD_ENABLE`，在 `pangoriscv.v` 里把 EX 的 `load_value` 反馈到 ID 级操作数选择（经典 EX→ID 前递），或在 `regs.v` 增加一个旁路口。

**必须遵守的约束**：
- 不改 `regs.v` 的端口列表（铁律 3）→ 优先在 `pangoriscv.v` 里做操作数选择；
- 前递必须带 `valid` 条件：只有 EX 当前确实是 load 且 `done_fire` 时才前递，否则会把垃圾数据推进去。

### 验收

- `LSU_WAIT` 下降；
- ticks 下降；
- **CRC 全对**（这是唯一可信的正确性判据）；
- `run_isa_e2e.py` 用例 2「load-use 冒险」通过。

### 排错

| 症状 | 原因 |
|---|---|
| CRC 错但 ISA 全绿 | 前递条件用了组合 `done_valid` 而不是握手完成的 `done_fire` |
| 只有某些指令错 | `access_size` 不同（LB/LH 的符号扩展）没走前递，反而用了原始字 |
| trap 计数非 0 | 前递把 fault 路径的垃圾数据带进了寄存器 |

### 回滚

关掉 `LOAD_FWD_ENABLE`，编译结果应与基线逐位等价。

---

## P4 · 分支预测增强（小收益，最后做）

### 先算清账

`MISPRED = 3,040,222`，每次惩罚 ≈ 2 周期 → 约 6 M 周期，占 308 M 的 **2%**。
**因此本阶段最高只能拿到 ~2% 的收益**，排在 P2/P3/P5 之后。若 P2/P3 之后 MISPRED 占比升到 10% 以上再回来做。

### 可选动作（按性价比）

1. **BTB 项数 32 → 64/128**（`branch_predictor.v`）：改动小；
2. **加返回地址栈 RAS**：CoreMark 有大量函数调用（`core_list_join` 的 `cmp_complex` 回调），JALR 返回是 BTB 的弱项；
3. **索引异或 PC 高位**：减少别名冲突。

### 验收

`MISPRED` 下降 + ticks 下降 + CRC 全对。

### 禁止

不要为了降 MISPRED 而去改 CoreMark 的编译分支布局（`-falign-*` 已在 flag 里，属于编译参数而不是架构优化，且会污染 A/B 结论）。

---

## P5 · 提频（评分项②，独立线，可与 P2~P4 并行）

### P5.1 先拿到真实的最差路径

现在的归档里**只有时序汇总，没有路径明细**（`pds_timing_summary_after_hold_fix.txt` 只有 WNS/TNS 表）。第一步必须重跑 PDS 并导出详细路径：

```tcl
report_timing -detail -max_paths 20
```

**验收**：能说出"最差路径是从 A 到 B"，不然下面的拆流水全是猜。

### P5.2 频率扫描实验

用现成的 `platform/pango_native/pango_native_50mhz_overconstraint.fdc` 思路，逐档收紧：

| 档 | 周期约束 | 等效频率 |
|---|---|---|
| 基线 | 37.037 ns | 27 MHz |
| 1 | 30 ns | 33 MHz |
| 2 | 25 ns | 40 MHz |
| 3 | 22 ns | 45 MHz |
| 4 | 20 ns | 50 MHz |

每档记录：是否 `All Constraints Met`、WNS、失败端点数。**收敛点 = 仍然 0 失败的最紧约束。**

### P5.3 针对性拆流水

只有 P5.1 拿到路径后才知道拆哪。已知的高概率嫌疑：

| 嫌疑 | 位置 | 拆法 |
|---|---|---|
| 除法组合链 | `div.v`（134 行迭代移位相减） | 已经是多周期，检查是否被综合成单拍大组合 |
| Cache tag 比较 + 数据选择 | `icache_axi`/`dcache_axi` | tag 比较寄存一拍 |
| AXI 互连仲裁 | `axi_interconnect.v` | 组合仲裁改寄存仲裁 |
| 乘法器 | `ex.v` APM | 若 APM 后还有宽加法，考虑打拍 |

**禁止**：为了解决时序而加 `set_false_path` 掩盖路径。这会同时破坏赛题「频率合规」的口径。

### P5.4 ⚠️ 提频会破坏「运行时间 ≥10 s」

**这是最容易翻车的点**。迭代数必须随频率重算：

```
N ≥ ceil(10.5 × f_Hz / 每迭代周期数)        // 10.5 s 留 5% 余量
```

按当前 770,002 周期/迭代：

| 频率 | 需要迭代数 | 建议取值 | 实际运行时间 |
|---|---|---|---|
| 27 MHz | 369 | **400**（现值） | 11.35 s ✓ |
| 33 MHz | 451 | 500 | 11.67 s |
| 40 MHz | 546 | 600 | 11.55 s |
| 45 MHz | 614 | 700 | 11.98 s |
| 50 MHz | 683 | 700 | 10.78 s |

**而且：P2/P3 优化成功后每迭代周期会下降，迭代数还要再涨！** 例如降到 500,000 周期/迭代、跑 45 MHz 时：

```
N ≥ ceil(10.5 × 45e6 / 500000) = 945  → 建议 1000
```

**每次改完性能或频率，必须重算一次，否则成绩作废**（赛题硬性规则，见 skill §4）。

---

## 3. 三重门（每一步都必须全过，缺一不可）

```powershell
# 工作目录：firmware/code

# 门1：RTL 编译 0 error 0 warning
vlog -sv -work work +incdir+rtl/core -f sim/native_axi_sources.f

# 门2：ISA 端到端（真实工具链程序 vs 参考模型，15 个用例）
python tools/run_isa_e2e.py --cases all

# 门3：CoreMark 五项 CRC 全对 + ticks 对比基线
vsim -c -do "run -all; quit -f" -l transcript.txt work.tb_coremark_uart ...
python build/coremark_score/parse_score.py transcript.txt --iterations 400 --mhz 27
```

**外加（改到 Cache/预测器/流水时必须跑）：**

```powershell
python sim/run_icache_tests.py --modelsim "<ModelSim>"
python sim/run_dcache_tests.py --modelsim "<ModelSim>"
python sim/run_predictor_tests.py --modelsim "<ModelSim>"
python sim/run_pipeline_tests.py --modelsim "<ModelSim>"
python sim/run_perf_tests.py --modelsim "<ModelSim>"
python tools/run_halt_reset_tests.py
```

**改到总线/外设时再加：**

```powershell
python sim/run_interconnect_tests.py --seeds 20
python sim/run_engine_tests.py
python sim/run_ram_tests.py
python sim/run_ifu_engine_tests.py
```

---

## 4. 排错手册（本次已经踩过或极可能踩的坑）

| 症状 | 原因 | 怎么查 | 怎么修 |
|---|---|---|---|
| `vopt-7063 Failed to find 'xxx'` | 测试台探针名与 RTL 信号名不一致 | 对照 RTL 的 `reg/wire` 声明 | 改测试台探针名，**不改 RTL** |
| `extension 'zicsr' required` | GCC 12+ 不再把 Zicsr 隐含在 rv32i 里 | 看报错行 | 加 `-march=rv32im_zicsr` |
| 仿真时间推进但无任何输出 | ModelSim 复用了陈旧的 `_opt` 优化缓存 | 看 `work/@_opt*` 目录 | 删 `work/@_opt*` 重跑 |
| `QProcess: CreateFile failed` / `Flow-0189` | PDS 建子进程管道被安全策略拦 | PDS 日志 | 用完整权限跑 PDS |
| 日志里 `Correct operation val` 被截断 | TB 只等 12000 周期就 `$finish` | `tb_coremark_uart.sv:330` | 加长等待；结论不受影响（该串只在 `total_errors==0` 分支打印） |
| `Total ticks` 两位数字都不对 | 32 位截断 | `core_portme.h:84` 的 `CORE_TICKS` | 长跑取 `CPM_TICKS hi/lo` 行或 perf 的 64 位 CYCLE |
| `Total ticks` 变了但 CRC 对 | 优化生效（正常） | — | 记录进 A/B 表 |
| `Total ticks` 变了且 CRC 错 | 功能 bug | 先跑 ISA e2e | **立即回滚**，不要试图在优化分支上调试正确性 |
| PDS 记忆体为空（位流没程序） | `$readmemh` 路径错，PDS 不报错仍出位流 | `build.tcl` 已内置检查 `Loading memory data from file` 计数 | 照 `build.tcl:104-121` 的检查走 |
| 时序报告 Recovery/Removal 为空 | 复位输入没有 I/O 时序约束 | 约束文件只有 `create_clock` | 见 §7 的 I/O 约束补全 |

---

## 5. 排期与优先级

| 序 | 阶段 | 预期收益 | 风险 | 建议工作量 |
|---|---|---|---|---|
| 1 | P0 测量脚手架 | 0（前提） | 低 | 半天 |
| 2 | P1 分诊 | 0（决策依据） | 无 | 半天（含一次仿真） |
| 3 | **P6 强制 BRAM** | ③ LUT −21% | 低 | 半天 |
| 4 | **P2 I/D-Cache 扩容** | ① IPC 可能 +40~70% | 中 | 2~3 天 |
| 5 | P5 提频 | ② 27→~40 MHz | 中 | 2 天 |
| 6 | P3 load-use 前递 | ① 中 | **高** | 2 天 |
| 7 | P4 预测增强 | ① ≤5% | 低 | 1 天 |

**建议先做 P0+P1+P6+（P2 档1）**，这四步就能拿到大部分收益，且风险可控。

---

## 6. 明确不做的事（防止范围蔓延）

- ❌ 不上双发射、不改 ISA 语义、不加 DMA/乱序执行（超出赛题范围，且会让"三项数据同一份位流"难以自证）
- ❌ 不用 `set_false_path` 做时序收敛
- ❌ 不改 CoreMark 源码或编译参数来"美化"分数（`core_*.c` 必须与官方逐字节一致）
- ❌ 不在优化分支上修正确性 bug（先回滚到能过的版本，再单独修）
- ❌ 不同时改多个模块（一次一个变量）

---

## 7. 两个必须一起处理的已知遗留

### 7.1 fdc 的 I/O 时序警告（19 条）

补齐即可消除（详见之前的分析）：

```tcl
set_input_delay  -clock clk 5.0 [get_ports {rst_n uart_rx key}]
set_output_delay -clock clk 5.0 [get_ports {uart_tx}]
set_output_delay -clock clk 5.0 [get_ports {led[*]}]
```

同时给 `pangoriscv_top.v` 的 `key` 补两级同步器（`rst_n`、`uart_rx` 已有）。

### 7.2 SCBV 未设置

`C: Bitstream-2001`。需要按板卡 PCB 确定 SCBV，现有资料无权威来源。**在有板子之前不猜值**，只在报告里如实标注"未设置，可烧录性未验证"。

---

## 8. 有板子之后的收尾（不在本计划范围内，但要预留）

本计划所有产出都是仿真 + PDS。拿到板子后必须补：

1. 下载位流，串口抓完整 CoreMark 报告（**板上 ≥10 s 必须重新验证**）；
2. ILA 抓 CoreMark 关键算法波形（赛题文档评分项，目前 NOT RUN）；
3. 板上实测频率（约束值 → 收敛实测值，两个口径分开写）；
4. 用板上数据**替换**仿真分数，并重算迭代数。

---

## 9. 每阶段的归档约定

每完成一步，在 `evidence/records/optimization/<阶段号>/` 下留：

- `change.patch`（改了什么）
- `before_after.csv`（A/B 数字，一行）
- `transcript.txt`（CoreMark 日志）
- `timing_summary.txt` + `resource_summary.txt`（PDS 产物）
- `notes.md`（为什么这么做、遇到什么坑）

**没有这五项，这一步不算完成。**

---

# 附：执行结果汇总（2026-10-17 实测）

| 族 | 结论 | 数字 | 证据 |
|---|---|---|---|
| **P0/P1 测量** | 完成 | 访存 36.5% / 取指饥饿 18.1% / 预测 1.8% / 除法 0.04% | `evidence/records/optimization/P1/` |
| **P2 D-Cache 扩容** | **否决** | 2→8 KB 只快 0.53%，面积 ×4 | `.../P2/` |
| **P2' store 路径** | **采纳** | **周期 −8.98%**（ticks 15,316,450→13,940,928），等 B 从 1,775,055→3,808 拍；CRC 一致、ISA 15/15 | `.../P2-store/` |
| **P4 分支预测** | **否决** | 64/128 项快 1.68%/1.84%，但 LUT +15%/+32%，指标③ −12%/−23%，净亏；恢复 32 项 | `.../P4/` |
| **P5 时钟频率** | **完成（实验）** | 50 MHz 过约束收敛，WNS +2.372 ns，0/66,247 失败；27 MHz 交付约束 WNS +17.920 ns | `.../P5/` |
| **P7 IFU 取指吞吐** | **完成（采纳）** | 两笔未完成请求 + I-Cache 背靠背命中：**周期 −12.97%**（ticks 13,940,928→11,887,687，−14.73%），`if_wait` **−77.30%**（3,269,814→742,122），`lsu_wait` 纹丝不动；CRC 逐项一致、ISA 15/15 | `.../P7/` |

## 当前交付状态

- **CoreMark/MHz**：**1.6815**（512 迭代有效跑分，ticks 304,495,134，11.28 s，
  `Correct operation validated`，五项 CRC 正确）
  - 同镜像同 512 迭代基线是 **1.4342**（ticks 356,993,719）→ 本轮 **+17.24%**
  - 链条：S0 基线 1.3054 → store 1.4342 → 取指 1.6815（累计 **+28.8%**）
- **频率**：**27 MHz 约束下 All Constraints Met**（setup WNS +14.127 ns、hold WHS +0.154 ns，
  0 / 52,349 失败端点）；50 MHz 收敛实验见 `P5/`
- **资源**：**13,018 LUT**（as logic 10,333 + as DRAM 2,685），基线受控同流程实测 12,622 → **+3.14%**；
  CoreMark/LUTs 0.1038 → **0.1292 每 kLUT**（累计 +24.4%；本轮 +13.7%）
- **回归**：单元 5/5、真实 IFU 引擎 20/20、ISA 15/15、halt-reset 5/5、
  pipeline/predictor/perf/dcache PASS、engine 64/64、ram 40/40、interconnect 20/20

## P7 已完成（原"下一轮"清单的落实结果）

1. I-Cache：`req_ready = rst_n && (state==IC_IDLE || rsp_leaving)`，
   `IC_IDLE`/`IC_RESP` 合并受理分支 → 连续命中 1 拍 1 条；
2. IFU：`state` 与单份 `req_pc_q` 换成 2 深 PC FIFO（`pcf0/pcf1`、`pdf0/pdf1`）+ `ocnt_q`，
   响应按槽 0 配对；`count_q + ocnt_q < DEPTH` 预留队列表项，故 `eng_rsp_ready` 可无条件为高；
3. 重定向丢弃改为 `stale_cnt_q` 按笔计数（同拍响应当场扣减，`redirect_valid` 持续多拍也正确）；
   `idle` 也纳入 `stale_cnt_q==0`，halt 握手不会误报空闲；
4. `tb_ifu_axi` 已覆盖：2 笔未完成上限、绝不反压响应、背靠背连续受理（`run_max=8`）、
   重定向撞响应同拍；`tb_icache_axi` 新增 T9 背靠背命中 7 个字；
5. 入口门槛全过：单元 PASS + ISA 15/15 + 五项 CRC 与基线一致。

**到此三项评分都有数据，剩下的只有上板**（实板串口、ILA 波形、板上实测频率、按实测重算迭代数）。
