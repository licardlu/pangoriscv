# 性能瓶颈诊断（Bottleneck Audit）

对象：`E:\file\pango\project` 的 RV32IM 软核（Pango 板，27 MHz）
范围：**只做现状核对、测量与分析，本轮不改任何 RTL、不优化、不换架构**
版本：**v3（第二轮评审修订版，2026-10-17）**。v1 报告曾用“两类瓶颈合计 62%”“store = 次数 × 11 拍”等
推断式表述；v2 按第一轮评审改为实测口径；v3 按第二轮评审修正四处：16.3% 降级为“机会指标”、
前端改动补正确性专项、A/B 改为同镜像、TB 加 `$fatal` 硬断言。修订记录见 §9。

---

## 0. 一句话结论

**周期花在三个量级相当的地方，不是“两个瓶颈吃掉 62%”**：退休本身 38.0%、访存停顿 43.0%
（其中 load 21.2%、store 21.8%）、前端空转 19.0%。
其中**不需要改动访存/写错误语义的前端那 19.0% 最值得先动**——它里面 16.3% 是“取指队列已空、
在等 I-Cache 响应”，根源是 **I-Cache 稳态 2 拍/条（每拍最多 0.5 条）+ IFU 同时只允许 1 个在途请求**。
**注意：16.3% 只是“优化机会指标”，不是严格收益上限**——这 131,022 拍里含不可消除的响应延迟，
且前端变快后分支重定向、流水重叠、队列填充都会改变，真实收益必须实测（§7 给了实测判据）。
store 那 21.8% 更值钱（其中 14.0% 纯粹在等 AXI 写响应），但**要做写缓冲就必须先解决
“晚到的写错误如何精确报告”**，这是架构级问题，本轮不批准。
精确成绩 **1.2481 CoreMark/MHz**（绝对分 33.69），历史文档的 1.35 用截断的 11 s 算得，虚高 8.1%。

---

## 1. 已核实的基线

### 1.1 硬件身份

| 项 | 核实结果 | 证据位置 |
|---|---|---|
| 实际顶层 | `pangoriscv_axi_soc`（2 主口 / 7 从口的 AXI4 SoC） | `firmware/code/rtl/soc/pangoriscv_axi_soc.v:1-128` |
| 核 | `pangoriscv_axi_top` → `pangoriscv`（RV32IM） | `rtl/core/pangoriscv_axi_top.v:100-178`、`rtl/core/pangoriscv.v` |
| 流水级 | **三级**：IF（含取指队列）｜ID+EX｜写回并入寄存器堆（无独立 WB 级寄存器） | `pangoriscv.v:125` `assign rd_valid = retire_fire && ewe && erd != 0;`、`:165` `u_regs` 直接由 `rd_valid` 写；全核 grep `wb_\|writeback` 零命中 |
| 源码清单 | `sim/native_axi_sources.f`（33 行），`+incdir+rtl/core`、`+incdir+rtl/perips` | `firmware/code/sim/native_axi_sources.f` |
| 编译开关 | `soc_config.vh:34-36` 三个宏 **默认全部注释**；全功能须 `+define+CACHE_ENABLE+PREDICT_ENABLE+PERF_ENABLE` | `rtl/core/soc_config.vh:31-36` |
| I-Cache | 32 组 × 8 字 × 2 路 = 2 KB，行 8 拍突发（ARLEN=7） | `rtl/core/icache_axi.v:1-40` |
| D-Cache | 32 组 × 2 路 × 8 字 = 2 KB，**写穿、无写分配**，`CACHED_LIMIT=0x2000_0000` | `rtl/core/dcache_axi.v` |
| 取指队列 | `DEPTH=8`，带预测链预取 | `rtl/core/ifu_axi.v:16,48,85`、`pangoriscv.v:32` |
| 分支预测 | BTB 32 项直接映射 | `rtl/core/branch_predictor.v:35` |
| LSU | **单笔在途**：`lsu_axi.v:42` `assign op_ready = rst_n && idle;` | `rtl/core/lsu_axi.v` |
| FENCE | 只推进 PC，无屏障动作（`id.v:160-161,285-286`、`ex.v:454-456`）；**今天的访存顺序完全依赖“单笔串行”这一事实** | 对应源码行 |

> 说明：README 里“四级流水（取指/译码/执行/写回）”与 `firmware/code/README.md:12` 的“三级”互相矛盾，
> 以 RTL 为准是**三级**。文档口径不一致，列入待改清单（本轮不改文档）。

### 1.2 源码 / 位流 / 工具链

| 项 | 值 |
|---|---|
| 源码树快照 | `results/baseline_tree_sha256.tsv`，146 文件，聚合 sha256 `8611ADDA40987826C9F6FD70E358E6D70ADB9BA87DFDAFB4B0AAA7D017E6814F` |
| 位流 | `bitstream/pangoriscv_i400.sbit`，3,791,112 B，sha256 `F8254F66EF9C78B53E3DD4E6516BA55BAA2F00C7C76EB2379D78FEC8962CE77C` |
| GCC | `riscv32-unknown-elf-gcc.exe (GCC) 7.1.1 20170509` |
| ModelSim | `ModelSim SE-64 vsim 10.6e 2018.06` |
| PDS | 2022.2-SP6.4（本轮**未**重跑综合） |
| 编译参数 | `-march=rv32im -mabi=ilp32 -mcmodel=medlow -O2 -ffreestanding -fno-builtin … -DCPU_FREQ_MHZ=27 -DITERATIONS=n` |
| CoreMark 口径 | performance 种子，400 次迭代（板测）/ 1 次迭代（仿真对照） |
| 时钟 | 27 MHz（37.037 ns） |

### 1.3 板测日志与源码/位流的关系（**证据强度已降级**）

- 板测数值：`Total ticks 320,541,251`、`Total time (secs): 11`、`Iterations/Sec: 36`、
  `Iterations: 400`、5 项 CRC（`0xe9f5/0xe714/0x1fd7/0x8e3a/0x25b5`）、`Correct operation validated`。
  **原始 UART 文本记录随 `09_validation_results` 一起在开发机误删**，上述现值来自
  `firmware/code/README.md:43-44` 的存档副本。
  **→ v3.1 已重做**：用本仓库 HEAD 源码独立重建成基线并上板复采，得到完整原始日志、
  全套 SHA256 与重复性验证，见 **`results/baseline_build.md`**（位流 `747C18CA…`、
  320,725,708 ticks、5 项 CRC 与交付完全一致、11.88 s、连跑两次逐字节相同）。
  本节下述关于“交付位流”的推理保留，但**后续 A/B 一律以 `results/baseline_build.md`
  那一对（源码＋镜像＋位流）为基线**。
- 仿真对照：当前源码 + 同参数 performance 镜像（1 次迭代）= **803,230 拍/迭代**；
  板测 320,541,251 ÷ 400 = **801,353 拍/迭代**，差 **+0.23%**。
- **这条 0.23% 只能说明“行为接近”**，不能证明源码/配置/位流同源：它是 1 次迭代 vs 400 次迭代，
  冷启动、Cache 预热、外设初始化占比都不同，也没有逐位复算 CRC 的手段。
- 能推的只有一条较弱结论：默认（三宏全关）构建同镜像为 **3,045,748 拍/迭代**，与板测相差 3.8 倍
  ⇒ **交付位流不是默认构建**；它是否恰好等于本仓库源码 + 三宏，属**间接推断**，
  标注为“同源关系：未确认，仅有行为接近证据”。（这条对比也已改成同镜像口径，见 §2.4。）

### 1.4 精确成绩（按原始 ticks，不用整数秒）

```
measured_cycles = 320,541,251
CoreMark/MHz    = iterations × 10^6 / measured_cycles = 400 × 10^6 / 320,541,251 = 1.2481
绝对分          = 1.2481 × 27 MHz = 33.69
```

历史 `README` 的 1.35 由 `400/11/27` 算得（`11.8719 s` 截断成 `11 s`），**虚高 8.1%**。
相对提升不受影响：未优化基线 656,167,771 ticks → 320,541,251 = **2.047×**。

---

## 2. 指标定义与测量结果

### 2.1 定义与 v1→v2 的口径修订

- 采样窗口＝CoreMark 计时区间：`core_portme.c` 的 `start_time()`/`stop_time()` 两次 `csrr cycle`；
  TB 在 `retire_inst==32'hc0002573` 的退休点采样，START＝第一次、STOP＝第二次。
  计数器 32 bit；27 MHz 下 159.07 s 回绕；本区间 11.87 s，不回绕。
- **互斥周期分类（v2）**：每个周期只归一类，优先级 `RETIRE > LSU_load/LSU_store > DIV > EX > frontend_idle`；
  TB 断言 `sum == cycles`（803,230 = 803,230 ✓）。
- `ifwait`（`fetch_enable && fetch_ready && !fetch_valid`）与 `lsuwait`（`op_valid && !done_valid`）是
  **独立事件，可以重叠**，本报告不把两者相加当总周期。
- 修订项：
  1. v1 的直方图统计了整段仿真（含启动载入与 UART 打印），与区间混用 → **v2 全部改为只统计区间内**；
  2. v1 的 load/store 停顿是按“次数 × 推定拍数”倒推的（167,469 / 172,557）→ **v2 按周期直接按 `is_store`
     计数**（170,169 / 174,995），不再用乘法推断；
  3. v1 把剩余分类叫“STARVE（取指饿死）”并当成取指原因的证明 → **v2 改名 `frontend_idle` 并拆成 5 项**。

### 2.2 全功能构建（与交付位流同配置，performance 镜像 1 次迭代）

日志 `logs/sim_audit_v2_perf1.log`：

| 指标 | 数值 | 占比 |
|---|---|---|
| 区间周期 | **803,230** | 100% |
| 退休指令 | **305,069** | 38.0% |
| IPC / CPI | **0.3798 / 2.633** | — |
| **LSU_load 停顿**（实测） | **170,169** | **21.2%** |
| **LSU_store 停顿**（实测） | **174,995** | **21.8%** |
| **frontend_idle**（剩余分类） | **152,997** | **19.0%** |
| DIV / EX 停顿 | 0 / 0 | 0% |
| │ store 相位细分 | EMTPY+REQUEST 15,687×2；WRITE_DATA 31,374；**WRITE_WAIT 112,247** | 14.0% 纯等 B |
| │ load 相位细分 | EMPTY+REQUEST 55,823×2；READ_WAIT 58,523（≈1.05 拍/笔） | — |
| frontend_idle 细分 | **empty_wait_rsp 131,022（16.3%）**；empty_idle 10,914；bubble 11,061；redirect 10,914 | — |
| load / store 笔数 | 55,823 / 15,687 | — |
| I-Cache 请求 / miss | 334,459 / 397（0.12%） | — |
| D-Cache 请求 / miss | 71,510 / 92（0.13%） | — |
| AXI I 侧 | AR 397 次、R 3,176 拍（8 拍/行） | — |
| AXI D 侧 | AR 92 / R 736；AW=B=15,687 | — |
| 错预测 / 重定向 | 10,914 | — |

**同镜像 A/B（关键，替换旧稿的混镜像对比）**：
- performance 镜像：全功能 **803,230** vs 默认构建 **3,041,345** = **3.786×**（日志 `logs/sim_audit_v2_base_perf.log`；
  默认侧分类 retire 305,069 / lsu_load 650,698 / lsu_store 165,123 / frontend_idle 1,920,455，和精确相等）
- validation 镜像：全功能 **804,633** vs 默认构建 **3,045,748** = **3.785×**
两侧结论一致；退休数完全相同（305,069 / 305,505）⇒ 架构等价、只差性能。

### 2.3 关键结构性证据

1. **取指稳态 2 拍/条**：区间内 `IGAP gap=2` 占 **88.0%**（294,346/334,458 次），I-Cache 命中响应
   `lat=1` 占 99.9%；I-Cache 只在一个状态接收新请求（`icache_axi.v:122`
   `assign req_ready = rst_n && state == IC_IDLE;`），响应后回 IDLE（`:189`）⇒ 每 2 拍一次查找。
   IFU 侧同时只能有 1 个在途请求（`ifu_axi.v:98-99` 发请求要求 `state==S_IDLE`，
   `:104` 收响应要求 `state==S_WAIT`，互斥）⇒ **发新请求与收旧响应不能重叠**。
2. **取指队列常年见底**（区间内）：占用 0 项 **21.3%**、1 项 **25.2%**（合计 46.5%），满 8 项 14.2%。
   但“队列空”里有 131,022 拍是**有请求在途、等响应**（empty_wait_rsp），只有 10,914 拍真正无请求
   （empty_idle，恰好等于重定向次数）。
3. **store 阻塞退休**：区间内 `LLAT lat=11` 命中 15,579 次 ≈ store 数；相位归因显示每笔 store 有
   **7.16 拍在 WRITE_WAIT 等 B 响应**、2 拍在 WRITE_DATA 发 W。D-Cache 写穿必须等 B 才置 done
   （`lsu_axi.v:97-100` 在 WRITE_WAIT 用 B 响应给出 `fault`，这是**精确 store 异常**的唯一来源）。
4. **store 突发很小**（区间内）：连跑长度 len=1 占 **82.6%**（12,965/15,687），len=2 仅 342、len≥4 共 337，
   最长 27；平均 51.2 拍才一笔 store ⇒ **“缓冲会满”在本负载下不是主要风险**，
   但正确性设计必须以最坏情况（连续 27 笔）成立，不能靠“平均间隔大”。
5. **load 命中 3 拍**（`LLAT lat=3` 55,731 次），其中 2 拍是 LSU 状态机串行开销，1.05 拍是 Cache 等待。
6. **错预测恢复快但量大**：`REC lat=5` 占 74.1%（8,084 次），长尾 `lat=16` 1,592 次。
7. **乘除不是问题**：本镜像区间内 `mdiv=0`、DIV 停顿 0；微程序实测 div ≈36.5 拍/次、mul 1 拍流水。

### 2.4 默认构建（三宏全关）作为对照

日志 `logs/sim_audit_v2_base.log`：区间 **3,045,748** 拍、退休 305,505 条（架构等价）、IPC **0.1003**；
分类 RETIRE 10.0% / LSU_load 21.5% / LSU_store 5.4% / frontend_idle **63.1%**；
`empty_wait_rsp` **1,646,086**（每次取指都要等一次单拍 AXI 读）；
I 侧 **AR = R = 346,770**（取指与响应不能重叠）；错预测 41,265（无 BTB）。

⇒ **同镜像 A/B = 3,045,748 / 804,633 = 3.785×**（两侧都是 validation 镜像、同一源码、同一工具链；
Cache+预测器的净收益）。历史材料的 1.86×/2.05× 出自旧 RTL，不能与当前源码混用。
（本文 §2.2 主表用 performance 镜像，两侧各自成表，**不跨镜像相除**；`perf` 侧对照见 §2.2 脚注。）

---

## 3. 微程序：机制级证据

固件 `work/tree/tests/example/microbench/main.c`（9 个相位），TB `scripts/tb_uart_run.sv` 直读 UART。

| 相位 | 全功能 cycles/条 | 默认 cycles/条 | 说明 |
|---|---|---|---|
| ALU 独立 | **2.03** | 8.80 | 8 条独立 `addi` 连发 |
| ALU 依赖链 | **2.02** | 8.80 | 8 条 `addi x,x,1` 链 |
| load 独立 | **3.20** | 11.64 | 8 条不同地址 `lw` |
| load 依赖（地址自增同链） | **3.79** | 13.34 | load-use 相关 |
| store | **9.02** | 10.91 | 8 条 `sw` |
| 分支必跳 | 2.05 | 10.68 | 循环回边 |
| 分支交替（每 2 次错一次） | 2.43 | 9.61 | 交替跳/不跳 |
| mul 依赖 | 2.02 | 8.80 | 8 条 `mul` |
| div 依赖 | 24.38 | 26.92 | 4 条 `div`（≈36.5 拍/次） |

**读法**：ALU 独立与 ALU 依赖几乎一样（2.03 vs 2.02）⇒ 执行级不是瓶颈，**取指供给才是**；
不开 Cache 时每次取指一次 AXI 读、约 8.8 拍/条，Cache 把取指压到 1/4.3；
store 开不开 Cache 都慢（9.02 / 10.91）⇒ 写通路结构性问题，与 Cache 无关。

> 注意：微程序只解释机制，**不能**把它外推成 CoreMark 收益比例。

---

## 4. 瓶颈排序

### 4.1 已证实的瓶颈（按“可消除比例”排）

**P1｜前端供给：I-Cache 2 拍/条 + IFU 单在途请求（机会指标 131,022 拍 = 16.3%，非收益上限）**
- 证据：区间 `empty_wait_rsp` 131,022（16.3%）、`IGAP gap=2` 88.0%、`ILAT hit=1` 99.9%、
  队列占用 0~1 项 46.5%、ALU 直线代码 2.03 拍/条且与依赖链无关、无 Cache 时 8.80 拍/条；
  源码 `icache_axi.v:122,189`、`ifu_axi.v:98-104`。
- 性质：**吞吐限制**（稳态 0.5 条/拍），不是单条指令的长延迟。其中 1 拍是“查找占 2 个状态”，
  另 1 拍是“收响应与发新请求互斥”造成的空拍。
- 可消除部分：把查询改成 1 拍/条流水（响应当拍即可接收下一请求）+ IFU 允许 2 个在途，
  `empty_wait_rsp` 会大幅下降。**16.3% 只是机会指标**：含不可消除的响应延迟，且前端变快后
  重定向/流水重叠会改变，真实收益必须同条件实测。
- 风险：不改变 LSU 退休与写错误机制；但**仍涉及前端正确性**（重定向丢弃旧响应、错误路径取指
  异常抑制、背压、队列满、invalidate、halt/reset、指令与预测配对），§6.1 给了专项用例清单。

**P2｜store 等 AXI 写响应（可消除上限 112,247 拍 = 14.0%；总值 174,995 = 21.8%）**
- 证据：`WRITE_WAIT 112,247`（7.16 拍/笔）、`LLAT lat=11` 15,579 次、微程序 store 9.02 拍/条；
  D-Cache 写穿必须等 B；源码 `dcache_axi.v:380-392`（好 B 才合并数据、坏 B 失效该行）、
  `lsu_axi.v:97-100`（B 响应同时给出 `fault`）。
- 性质：**延迟限制**（每笔 store 等一次 AXI 往返），且 store 频度低（51.2 拍/笔，82.6% 是孤立 store）。
- **为什么本轮不选它**：现在 store 退休与 B 绑定（`lsu_axi.v:97-100` → `pangoriscv.v:71-73`
  `memory_fault = is_memory && issued && done_valid && fault`），这是**精确 store 异常**的唯一来源。
  若 AW/W 发完就退休，就必须补一套“晚到写错误”的报告机制（否则异常变不精确）；
  同时缓存内 load-after-store 的可见性、字节写合并、miss/refill 冲突、
  `CACHED_LIMIT` 以上 MMIO 的顺序、FENCE 语义、以及“复位/异常时已被 AXI 接收的在途写如何排空”
  都要重新定义——**这是架构级改动，不是加个 FIFO**。详见 §6.2。

**P3｜load 命中 3 拍（不可消除项，占 21.2% 但每笔只 3 拍）**
- 证据：`LLAT lat=3` 55,731 次、微程序 3.20 拍/条；LSU 单笔在途（`lsu_axi.v:42`）。
- 性质：**结构限制**。三级流水无记分板、LSU 只有 1 笔在途，load 数据必须回到 EX 才能继续，
  要藏这 3 拍得改成非阻塞 LSU（多笔在途 + 记分板），属换架构级别，本轮不建议。

### 4.2 次要 / 待验证

- **错预测 10,914 次**：`REC lat=5` 占 74.1%，单次约 3.8 拍（微程序交替分支交叉验证）；
  `redirect_cycles` 仅 10,914 拍（1.4%），**不是独立瓶颈**。
- **`REC lat=16`（1,592 次）未定位**：可能是 I-Cache miss 与重定向叠加，imiss 只有 397 次不足以解释。
- **两主口 AXI 仲裁未单独测**：D 侧写流量 AW/W/B 各 15,687 拍，I 侧只 3,176 拍读；
  默认构建下 I 侧 346,770 次读与 D 侧写争用总线。**待验证假设**。
- **DIV/EX 停转为 0**：乘除与总分无关。

### 4.3 未运行 / 未确认（NOT RUN）

> **v3.1 更新**：下面第 1、2 条已在本轮补齐（独立重建基线 + 上板复采），结果见
> `results/baseline_build.md`；保留原文便于对照。

- 综合资源与时序：~~本轮未重跑 PDS~~ → **已重跑**：LUT 12,441 / FF 7,268 / DRM 4.5 / IO 13，
  Setup slow 16.440 / Hold 0.018 / Setup fast 24.232 / Hold 0.012 ns，48,214 端点，All Constraints Met。
- 板测：~~未上板、原始日志已丢失~~ → **已重采**：320,725,708 ticks、CRC 全同、11.88 s、两次逐字节一致。
- ILA：未接入，所有结论来自仿真。
- 同源关系：交付位流仍只有“行为接近”证据；**但本轮基线自身（源码＋镜像＋位流）三者同源已由 SHA256 锁定**。

---

## 5. 针对性论文（2 篇核实 + 2 篇候选）

1. **H. Miyazaki, T. Kanamori, Md A. Islam, K. Kise, "RVCoreP: An Optimized RISC-V Soft Processor of
   Five-Stage Pipelining", IEICE Trans. Inf. Syst., Vol.E103.D, No.12, pp.2494–2503, 2020.
   DOI: 10.1587/transinf.2020PAP0015**
   适配理由：其三项优化之一正是**取指单元优化**（指令缓冲/预取，降低 FPGA 上 BRAM 读延迟造成的
   取指空拍），与本案 P1（I-Cache 2 拍/条 + 队列见底）同型；同为 FPGA 软核，五级 vs 本案三级，
   成本参照合理。区分：论文原方法是“缓冲+连续预取”，本案照搬需改 IFU 与 I-Cache 接口；
   这是**适配推断**，不是论文结论。

2. **Md A. Islam, H. Miyazaki, K. Kise, "RVCoreP-32IM: An effective architecture to implement mul/div
   instructions for five stage RISC-V soft processors", arXiv:2010.16171, 2020-10-30.**
   适配理由：给出 RV32IM 乘除实现与资源/频率权衡（radix-4 / DSP 乘法器上比 RV32I 快 1.87–3.13 倍）。
   与本案对照：本案区间内 `mdiv=0`、DIV 停顿 0 ⇒ **换乘除实现对成绩无意义**，引用它是为了**排除**
   这条看似便宜的路线。

3. （候选，未完全核实）"RVCoreP-32IC: A high-performance RISC-V soft processor with an efficient
   fetch unit supporting the compressed instructions", arXiv:2011.11246 — **仅题名与 arXiv 号经索引核实，
   作者与日期未取到，不作为证据引用**。

4. （候选，未完全核实）“An Efficient Instruction Fetch Architecture for a RISC-V Soft Processor on an
   FPGA”，HEART 2019 前后，DOI 10.1145/3337801.3337803 — ACM 返回 403，作者未核实。

两篇已核实论文均非“顶刊/顶会”表述，仅按 IST 期刊 / arXiv 预印本如实标注。

---

## 6. 唯一的优先建议（本轮不实施）

### 6.1 建议：先把前端供给做成 1 拍/条（I-Cache 流水化 + IFU 允许重叠）

**改什么**（下一轮）
- `rtl/core/icache_axi.v`：把“接收请求→查找→响应”改成**每拍可接收一个新请求**的流水形态
  （命中时在 T+1 给出数据、同拍接收 T+1 的请求），miss 时按现有 refill 逻辑停顿；
  关键是 `req_ready` 不再只在 `IC_IDLE` 有效。
- `rtl/core/ifu_axi.v`：允许“发新请求”与“收旧响应”重叠（例如响应端加 1~2 项缓冲，
  或让状态机在 `S_WAIT` 也能发下一笔），保留现有 `DEPTH=8` 取指队列与预测链预取。
- **不改**：流水级数、D-Cache、LSU、BTB 算法、乘除、异常与访存语义。

**预期（推断，非实测）**
- `empty_wait_rsp` 131,022 拍（16.3%）会显著下降 ⇒ 区间**有机会**从 803,230 降到约 700,000 拍附近。
  **这不是收益上限，只是“优化机会指标”**：该数字是当前“队列空且等响应”的周期数，其中含不可消除的
  响应延迟；前端变快后，分支重定向次数、流水重叠、队列填充行为都会变，因此真实收益**必须实测**，
  本文不承诺任何百分比，也不承诺 CoreMark/MHz 的具体落点。

**验证方法（正确性必须先于性能）**
1. **功能回归**：`sim/` 的 13 个套件全过（unit 5、icache/dcache/predictor/perf/gpio-trace 各 1、
   pipeline、halt-reset 5、engine-s4 32、interconnect-s4 4、ram-s4 8、ifu-engine-s4 4、isa-e2e 15）；
   CoreMark 5 项 CRC 与当前完全一致。
2. **前端正确性专项**（前端改动同样涉及正确性，不能只说“不碰 LSU 退休”）：
   - **重定向时旧响应必须丢弃**：`redirect` 后仍在途的取指响应不得进入 `if_id`/队列，且不得污染
     `pred_miss`/`btb` 配对（指令与预测信息必须成对流水，不能错位）；
   - **错误路径取指的异常必须抑制**：被 flush 的取指不得产生取指异常/总线 fault 上报给 CSR；
   - **响应背压**：下游 `fetch_ready` 拉低时响应不得丢、不得重复（队列满 8 项场景）；
   - **队列满/空边界**：满时 `req_ready` 必须回压，空且 halt/reset 时不得残留未完成状态；
   - **invalidate/flush** 与在途事务的交互（清 Cache 时不得让旧响应回来写队列）；
   - **halt/reset** 中途复位后能干净重启（现有 `halt-reset` 5 用例覆盖）。
   落地方式：为上述 6 条各加一条定向用例（放在 `tb/unit`），并与现有 `isa-e2e` 一起跑。
3. **成绩**：同镜像、同 TB、同工具链但**独立干净的 work 库与构建目录**，比较区间周期与五类占比。
4. **微程序**：ALU 直线相位应从 2.03 降到 ≈1.0~1.1 拍/条（最灵敏的机制判据）。
5. **资源/时序**：PDS 重跑，Setup/Hold 余量 ≥ 0，LUT/FF/BRAM 增量记录在案。
6. **资源风险点**：I-Cache 流水化会多一级流水寄存（tag/data 输出打拍）或双端口化 BRAM，
   需观察 27 MHz 下的 Setup 余量（当前仅 +16.262 ns）。

### 6.2 为什么不是先做 store 写缓冲

外部评审指出、我也在 RTL 里核实的三个硬约束：

1. **精确异常**：`lsu_axi.v:97-100` 在 WRITE_WAIT 用 B 响应给出 `fault`，
   `pangoriscv.v:71-73` 用它产生 `memory_fault`。AW/W 发完就退休 ⇒ 写错误发生在指令退休之后，
   异常不再精确；要么放弃精确 store 异常（架构回退），要么设计延迟错误报告（重放/存档，代价大）。
2. **可见性**：`dcache_axi.v:380-392` 现在**只在好 B 之后**把数据合并进阵列（`:385`），坏 B 让该行失效
   （`:388`）。若提前合并，后续 load 会读到“将来可能失败的写”；不仅缓存命中要处理，
   miss/refill、字节写合并、`CACHED_LIMIT` 以上 MMIO 的顺序、FENCE 语义也都要重新定义。
3. **在途排空**：复位/异常时“清空在途表”不可行——已被 AXI 接收的写必须继续跟踪排空，
   否则主机侧可能看到丢写或错配。这需要一套独立于 CPU 的排空状态机。

⇒ 结论：**写缓冲不是“加个 FIFO”**，它牵动异常模型与内存一致性模型；在解决 late fault 之前
不批准。若将来要做，正确顺序是：先定“晚到写错误如何报告”的方案 → 再改 `dcache_axi` → 最后改 `lsu_axi` 退休条件。

---

## 7. 下一轮同条件 A/B 方案

| 项 | 固定为 |
|---|---|
| 镜像 | performance，1 次迭代（板测同参数）；validation 作第二组 |
| 配置 | `+define+CACHE_ENABLE+PREDICT_ENABLE+PERF_ENABLE`（与交付位流一致） |
| 工具 | 同一 GCC 7.1.1、同一 ModelSim 10.6e、同一 work 库与编译参数 |
| 度量 | 区间周期、退休数、IPC、五类互斥占比、`LLAT`/`IGAP`/`OCC` 区间直方图、AXI 事务计数 |
| 正确性门槛 | CoreMark 5 项 CRC 全同 + isa-e2e 全过 + unit 套件无回归 |
| 资源门槛 | PDS 综合：无新的时序违例，Setup/Hold 余量 ≥ 0，LUT/FF 增量记录在案 |
| 记录 | 每次运行的命令、日志、sha256 写入 `results/`，与 `baseline_tree_sha256.tsv` 对照 |
| 基线（已完成） | 独立重建 + 上板重采已在 v3.1 完成：`results/baseline_build.md`（源码 HEAD `613fc88`、镜像 `4AD7DE6B…`、位流 `747C18CA…`、320,725,708 ticks） |

两版必须在同一台机器、同一 session、同一镜像上跑，避免环境漂移。

---

## 8. 直接用大白话回答四个问题

1. **现在主要慢在哪里？**
   三块差不多大：干活本身 38%；等内存 43%（其中等 load 21.2%、等 store 21.8%）；
   **前端空转 19%**——这 19% 里有 16.3% 是“取指队列空了、正在等 I-Cache 回话”，
   因为 I-Cache 每 2 拍才交一条指令，而取指单元同一时刻只允许一笔请求在途。
   store 那 21.8% 里，有 14.0% 是纯粹在等 AXI 写响应（每笔约 7.16 拍）。
2. **证据是什么？**
   803,230 拍的区间里：退休 305,069（38.0%）、LSU_load 170,169（21.2%）、LSU_store 174,995（21.8%）、
   前端空转 152,997（19.0%，其中等响应 131,022），四类之和精确等于总周期；
   `IGAP gap=2` 占 88.0%、取指队列 0~1 项占 46.5%、`LLAT lat=11` 出现 15,579 次；
   微程序：ALU 直线 2.03 拍/条、store 9.02 拍/条、load 命中 3.20 拍/条。
   **注意**：0.23% 的板测/仿真差异只能说明“行为接近”，不能证明源码/位流同源。
3. **还有什么没确认？**
   (a) 板测原始日志已丢失，需重新采集；(b) 交付位流与当前源码是否逐位同源，只有间接推断；
   (c) 两主口 AXI 仲裁对取指的影响没单独测；(d) `REC lat=16` 的 1,592 次长尾没定位；
   (e) 综合资源/时序本轮没重跑；(f) 两篇候选论文作者未核实。
4. **下一步只改哪一个机制？**
   **只改前端供给**：把 I-Cache 的命中吞吐从 2 拍/条降到 1 拍/条，并允许 IFU 收发重叠。
   机会指标 16.3%（约 131k 拍），**不是收益上限**，真实收益要按 §7 同条件实测；
   它不改 LSU 退休与写错误机制，但前端自身的重定向丢弃、错误路径时钟门控等仍要专项验证（§6.1）。
   store 写缓冲机会更大（14.0%），但它要重定义“晚到写错误怎么报”，属于架构级改动，
   **本轮不批准**，留到下一轮先出方案。

---

## 9. 修订记录

### 9.1 v2 → v3（按第二轮外部评审意见修订，2026-10-17）

| 项 | v2 表述（有问题） | v3 修正 |
|---|---|---|
| 16.3% 的性质 | 写成“可消除上限 / 收益上限” | 降级为**优化机会指标**：含不可消除延迟，前端变快后重定向与流水重叠都会变，收益必须实测；§0/§4.1/§6.1/§8 同步改 |
| 前端优化的风险表述 | “完全不碰异常与访存语义” | 改为“不改变 LSU 退休与写错误机制，但**仍涉及前端正确性**”，§6.1 增 6 条专项用例（重定向丢弃旧响应、错误路径异常抑制、背压、队列满、invalidate、halt/reset、指令/预测配对） |
| A/B 对照 | 3.79× 用“默认 validation ÷ 全功能 performance” | 改为**同镜像对比**：performance 803,230 vs 3,041,345 = 3.786×；validation 804,633 vs 3,045,748 = 3.785× |
| 求和“断言” | TB 只打印 `sum`，报告称“和精确等于总周期” | TB 加三处 `$fatal` 硬断言（`AUDIT_CHECK`），不等即 `$fatal`；四组运行全部通过 |

### 9.2 v1 → v2（第一轮评审）

| 项 | v1 表述（有误） | v2 修正 |
|---|---|---|
| 总体结论 | “两处瓶颈合计约 62%” | 三类并列：LSU 43.0%（load 21.2% / store 21.8%）、前端空转 19.0%、退休 38.0%；不再给“62%” |
| store 停顿 | 15,687 × 11 = 172,557（推断） | 实测 174,995（按周期、按 `is_store` 直接计数） |
| load 停顿 | 55,823 × 3 = 167,469（推断） | 实测 170,169 |
| 直方图 | 整段仿真（含启动与打印） | 只统计 CoreMark 区间 |
| “STARVE” | 当作取指饿死 | 改名 `frontend_idle`，拆成 empty_wait_rsp / empty_idle / bubble / redirect |
| 同源关系 | “强间接证据：交付位流是全功能构建” | “行为接近，未确认；只能排除‘默认构建’” |
| store 突发 | 只说“平均 51 拍一笔，缓冲不会满” | 补实测分布：82.6% 孤立 store，最长连跑 27；正确性设计须按最坏情况 |
| 优先建议 | 加写缓冲 | 改为前端 1 拍/条；写缓冲列为“未批准，需先解决 late fault” |

---

## 附录：文件清单

| 文件 | 内容 |
|---|---|
| `BOTTLENECK_AUDIT.md` | 本报告（v2） |
| `results/measurements.md` | 全部原始测量表与定义（v2 口径） |
| `results/commands.md` | 环境、命令、开关、踩坑 |
| `results/baseline_tree_sha256.tsv` | 源码树 146 文件哈希 |
| `results/baseline_bitstream_sha256.tsv` | 位流哈希 |
| `scripts/tb_coremark_audit_v2.sv` | **v2** CoreMark 区间审计 TB（区间直方图 + load/store 分项 + LSU 相位 + 前端拆解 + store 突发） |
| `scripts/tb_coremark_audit.sv` | v1 TB（保留作对照，口径有缺陷） |
| `scripts/tb_uart_run.sv` | 最小 UART 直读 TB（微程序） |
| `logs/sim_audit_v2_perf1.log` | **v2** 全功能 performance 1 迭代 |
| `logs/sim_audit_v2_base.log` | **v2** 默认构建 validation 1 迭代 |
| `logs/sim_audit_perf1.log` / `sim_audit_full_iter1.log` / `sim_audit_base_iter1.log` | v1 日志（对照） |
| `logs/sim_microbench_full.log` / `_base.log` | 微程序两配置 |
| `work/tree` | 工作副本（发布树的复制，只含诊断期改动） |
| `work/tree/tests/example/microbench/main.c` | 微程序固件 |
