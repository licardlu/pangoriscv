# 发布版位流

> ## ✅ 交付定案（2026-10-28）：用 P48e `pangoriscv_board50_i2800_5p248.sbit`
>
> **50 MHz / CoreMark/MHz 5.2447 / LUT 17,174，`All Constraints Met`**
> （setup WNS +0.645、hold WHS **+0.010**、失败端点 **0**）
>
> ### 为什么不用分数更高的 v40（5.2599）
>
> | # | 理由 |
> |---|---|
> | 1 | 赛题指标②是「**在满足时钟约束的前提下**能达到的最高工作频率」。v40 带 **hold −0.158 ns / 2 个失败端点**，这一项会被动摇；P48e 是 `All Constraints Met`，站得住 |
> | 2 | 那 0.29% 的分数差**全部来自固件镜像**（GCC 15.2.0 `-O3` 4000 迭代 vs `-O2` 2800 迭代），与 RTL 无关。想拿高分只需换镜像，不必背一个时序违例 |
> | 3 | 换到 v40 只买到「综合关键路径 −0.744 ns / LUT −154」，代价是 2 个 hold 失败端点，**性价比不成立** |
>
> hold 的成因已定位（时钟插入延迟差 0.388 ns，0 级逻辑路径），修复尝试 `v43` 已否定、
> 参数修正版 `v44_holdfix2` 主动中止。**本版不再改动。**详见 `docs/v44-final-report.md` §6。
>
> ### 代码与位流一致（2026-10-28 已对齐）
>
> 仓库 `firmware/` 已整体回退到出 P48e 时的版本对齐点 `d7cbd6c`，
> 逐文件比对 `git diff d7cbd6c -- firmware/` **为空** ⇒ **RTL 与交付位流严格对应**。
>
> 撤销的内容：v40 引入的 **P33**（`rv32_top.v` 36 行）、`pangoriscv_top.v` 的 9 行探针注释、
> `tb_coremark_uart.sv` 的 54 行仿真探针、53/54 MHz 约束、`mulh_test`。
> P33 补丁保留在 `docs/patches/p33-csr-wb-value.txt` 作为记录，**未应用**。

> ## 历史：v40（2026-10-28，分数更高但 hold 未过，未采用）
> `pangoriscv_v40_o3_4000_5p26.sbit`
>
> **50 MHz / CoreMark/MHz 5.2599 / LUT 17,020**（同一份实现，三项指标可互校）
>
> | 项 | 值 | 口径 / 证据 |
> |---|---|---|
> | 约束频率 | **50.000 MHz**（PLL 27×50/27，VCO 1350）| `pango_native_50mhz.fdc`（单时钟 20.000 ns）|
> | `Design Summary` | ⚠️ **Some Constraints Violated（仅 hold，setup 全过）** | `build/v40_g15o3/report_timing/pangoriscv_top.rtr` |
> | setup（`core_clk` 50 MHz）| **WNS +0.199 ns，失败端点 0** | 布线后 19.801 ns |
> | hold | ⚠️ **WHS −0.158 ns，失败端点 2** | 路径 `data_cache/tag_di_q[1] → tag_mem_2/ram64x1d/DI`，0 级逻辑、数据 0.264 ns，成因是时钟插入延迟差（launch 2.209 / capture 2.597）|
> | 综合 WNS | **+1.139 ns（18.861 ns）** | 原交付为 +0.395（19.605 ns）|
> | 面积（`device_map` `Used`）| **LUT 17,020 / FF 8,645 / LUTRAM 2,274 / DRM 12 / APM 10** | `build/v40_g15o3/multiseed_summary.csv` |
> | CoreMark/MHz | **5.2599** | 真机 4000 迭代 `Total ticks 760,474,020` = **190,118.5 拍/迭代** |
> | CoreMark/kLUT | **0.3090** | 5.2599 / 17.020 |
> | 运行时间 | **15.21 s ≥ 10 s** | 760,474,020 / 50 MHz |
> | 五项 CRC | `0xe9f5 / 0xe714 / 0x1fd7 / 0x8e3a / **0x65c5**` | 真机 COM13，2026-10-28 12:23 |
> | 位流 SHA256 | `286e3815cb8523e3a94b32f92369db0c7f76d37fc8ab79404d91aceb3842d548` | |
>
> ### 相对 board50（P48e）改了什么
>
> 只有一处 RTL 改动 **P33**（`rv32_top.v`，36 行）：CSR 的编译器可见结果直接取
> `w_csr_old`，不再于 WB 二次读 CSR 阵列；`csr_native` 的读地址固定为 `id_csr_addr`。
> 其余差异只有镜像：GCC **15.2.0** `-O3`、4000 迭代。
>
> | 项 | board50（P48e） | v40 | 判定 |
> |---|---|---|---|
> | 综合 WNS | +0.395（19.605 ns）| **+1.139（18.861 ns）** | 关键路径 −0.744 ns |
> | LUT / FF | 17,174 / 8,693 | **17,020 / 8,645** | −154 / −48 |
> | 布线 setup | +0.645，0 端点 | +0.199，0 端点 | 都过 |
> | 布线 hold | +0.010，0 端点 | **−0.158，2 端点** | **未过，待修** |
> | 板测 ticks（同 `-O2` 镜像）| 533,875,894 | 533,875,894 | **逐位相同** |
> | 五项 CRC | e9f5/e714/1fd7/8e3a/bd59 | 完全相同 | **逐位相同** |
> | CoreMark/MHz | 5.2447（真机）| **5.2599**（真机）| +0.29% |
>
> **功能等价判据**：同一份 `-O2` 镜像（`g15o2_2800`）分别烧进 board50 与本版，
> `Total ticks` 与五项 CRC **逐位相同** ⇒ P33 不改变体系结构行为。
> `-O3` 只换 BRAM 初值、不改网表：两版的综合 WNS、LUT、FF、DRM、APM、
> 布线弧长（393,503）完全一致。
>
> ⚠️ **未完成的一项**：hold −0.158 ns。这条路径 P33 没有触碰，原版能过 hold 是因为
> 那次布线的时钟树更平衡（同树重布的抽样差可达 2.4 ns）。hold 修复版（`v43`，
> `-fix_hold_violation_iterations 200`）出流后应替换本文件，届时无需改 RTL、
> ticks 与 CRC 不变。详见 `docs/v44-final-report.md`。

> ## ✅ 当前交付（P48e）：`pangoriscv_board50_i2800_5p248.sbit`
>
> **50 MHz / CoreMark/MHz 5.248 / LUT 17,174**（同一份实现，三项指标可互校）
>
> | 项 | 值 | 口径 / 证据 |
> |---|---|---|
> | 约束频率 | **50.000 MHz**（PLL 27×50/27，VCO 1350）| `pango_native_50mhz.fdc`（**单时钟 20.000 ns**）|
> | `Design Summary` | **All Constraints Met** | `evidence/records/optimization/p48e-board50/` |
> | setup（`core_clk` 50 MHz）| **WNS +0.645 ns，失败端点 0** | 布线后 **19.355 ns**（物理上限 51.67 MHz）|
> | hold | **WHS +0.010 ns，失败端点 0** | 同上 |
> | 详细布线 | **0 未布通 @ 114 轮** | `run.log`（`Unrouted nets 0 at the end of iteration 114/115`）|
> | 面积（`device_map` `Used`）| **LUT 17,174 / FF 8,693 / LUTRAM 2,274 / DRM 12 / APM 10** | `multiseed_summary.csv` |
> | CoreMark/MHz | **5.248** | 190,535 拍/迭代（20 迭代仿真 `Total ticks 3,810,700`）|
> | CoreMark/kLUT | **0.3056** | 5.248 / 17.174 |
> | 镜像 | `hw_i2800_50v17`（2800 迭代 / `CPU_FREQ_MHZ=50`）→ 533.5 M / 50 M = **10.67 s ≥ 10 s** | |
> | 位流 SHA256 | `5e1969fca5b06bb9880dd2368c1af0e8a036daad5fc363fa9f30de1c1db19ecf` | |
>
> ### 这一版是怎么把 50 MHz 拿下来的（重要）
>
> 不是靠换 seed（`pnr -seed` 实测是静默 no-op），而是**把 52 MHz 的"鞭子时钟"去掉**：
>
> | 构建 | 最紧声明时钟 | 摆放 WNS | 布线后 | 结果 |
> |---|---|---|---|---|
> | `p48r48d`（48 M 交付） | 20.000 ns | +1683 ps | **19.355 ns** | ✓ |
> | `p48r50` | 19.231 ns（鞭子 52） | +1072 ps | 21.600 ns | ✗ |
> | `p48r50b` | 19.231 ns（鞭子 52） | +1217 ps | 21.120 ns | ✗（仅 40 端点）|
> | **`p48r50e`** | **20.000 ns（单时钟）** | **+1683 ps** | **19.355 ns** | **✓ +0.645** |
>
> ⇒ **19.231 ns 是这条网表的坏点**，压得越紧布得越差；20.000 ns 恰好就是 50 MHz 的周期，
> 所以用单时钟声明 50 MHz 反而同时满足"摆放压力合适"和"声明合规"。
>
> ⚠️ **本版未上板**：2026-10-23 16:49 / 20:00 / 20:10 三次只读扫描都是
> `JtagServer-0306: No devices detected`（下载线能枚举、JtagServer 能起、端口能连，
> 就是链上没有器件）⇒ 板子未上电或 JTAG 排线未接。
> **板测值仍然只有 `board48_i2700_5p245` 那一份（5.2447 @48 MHz）**，
> 两者 RTL 行为逐位一致（190,535 拍/迭代）。

> ## 历史交付（2026-10-23 P48d）：`pangoriscv_board48_i2700_w148.sbit`
>
> **48 MHz / CoreMark/MHz 5.2447 / LUT 17,174**（同一份实现，三项指标可互校）
>
> | 项 | 值 | 口径 / 证据 |
> |---|---|---|
> | 约束频率 | **48.000 MHz**（PLL 27×64/36，VCO 1728）| `platform/pango_native/pango_native_48mhz.fdc` |
> | `Design Summary` | **All Constraints Met** | `evidence/records/optimization/p48d-board48-w148/` |
> | setup（`core_clk` 48 MHz）| **WNS +1.478 ns，失败端点 0** | 布线后 **19.355 ns** |
> | setup（`core_clk_pnr` 50 MHz，鞭子时钟）| +0.645 ns，失败端点 0 | 只用于逼摆放器，**不作为频率声明** |
> | hold | **WHS +0.010 ns，失败端点 0** | 同上 |
> | 详细布线 | **0 未布通 @ 115 轮** | `run.log`（`Unrouted nets 0 at the end of iteration 115`）|
> | 面积（`device_map` `Used`）| **LUT 17,174 / FF 8,693 / LUTRAM 2,274 / DRM 12 / APM 10** | `multiseed_summary.csv` |
> | CoreMark/MHz | **5.2447** | 同 RTL 同镜像 20 迭代仿真 `Total ticks 3,810,700`；板测值沿用 ticks 逐位相同的 `board48` |
> | CoreMark/kLUT | **0.3054** | 5.2447 / 17.174 |
> | 镜像 | `hw_i2700_48`（2700 迭代 / `CPU_FREQ_MHZ=48`）→ 10.72 s ≥ 10 s | 同上 |
> | 位流 SHA256 | `71f64023b8f70ce600c891fc59ce1ef162b072d83d0b8003b54a8f36f5168e4d` | |
>
> ⚠️ **本版未上板**：2026-10-23 16:49 起 JTAG 链一直 `No devices detected`（板子未上电/排线未接），
> 详见 `docs/plan-v17-board50.md` §8。**板测值仍然只有 `board48` 那一份（5.2447）**，
> 两份位流的 RTL 行为逐位一致（`Total ticks 3,810,700` 相同），差别只是实现质量。
>
> 相对 `board48`：**setup 余量 +0.252 → +1.478 ns（×5.9）**、布线 151 → 115 轮、LUT +69
> （来自 `irq_trap` 的中断边界修复：原来只认 lane0 的控制流，lane1 控制流永远等不到中断边界）。

> ## 历史交付（2026-10-23 P30）：`pangoriscv_board48_i2700_5p245.sbit`
>
> **板上 CoreMark/MHz = 5.2447 @ 48 MHz / LUT 17,105**（三项指标同出这一份位流，**唯一有板测的一份**）
>
> | 项 | 值 | 证据 |
> |---|---|---|
> | 板测 `Total ticks` | **514,808,895** | `evidence/records/optimization/p30-dcache-path/board_p35a.txt` |
> | 板测 `Iterations` | 2700 | 同上 |
> | 运行时间 | 514,808,895 / 48 MHz = **10.72 s ≥ 10 s** ✓ | 由 ticks 反推 |
> | 板测五项 CRC | `0xe9f5 / 0xe714 / 0x1fd7 / 0x8e3a / 0xa14c` | 同上，`Correct operation validated` |
> | **CoreMark/MHz** | **5.2447** | 2700 × 1e6 / 514,808,895 |
> | 约束频率 / 布线后 | **48.000 MHz** / **48.5885 MHz** | `report_timing.rtr` |
> | setup | **WNS +0.252 ns，失败端点 0** | 同上（`All Constraints Met`）|
> | hold | **WHS +0.021 ns，失败端点 0** | 同上 —— 上一版的 −0.007/2 端点残留**已清除** |
> | 面积（`device_map` `Used`）| **LUT 17,105 / FF 8,693 / LUTRAM 2,274 / DRM 12** | `synthesize_device_map_run.log` |
> | CoreMark/kLUT | **0.3066** | 5.2447 / 17.105 |
> | 位流 SHA256 | `331273cb7a9d19be167f4f95183eb3231302352e7d2ba31ac59b5566636c856e` | |
> | 约束文件 | `pango_native_48mhz.fdc`；PLL `27*64/36 = 48.000 MHz`，VCO 1728 MHz | |
> | 镜像 | `build/native_software/coremark/performance/hw_i2700_48`（`CPU_FREQ_MHZ=48`）| |
>
> **相对上一版 `board39` 的三项指标**：
>
> | 指标 | board39 | **board48** | 变化 |
> |---|---|---|---|
> | 最高时钟频率 | 39 MHz | **48 MHz** | **+23.1%** |
> | CoreMark/MHz | 5.2941 | **5.2447** | −0.9% |
> | CoreMark/kLUT | 0.3311 | 0.3066 | −7.4% |
>
> 频率 +23.1%、分数仍 ≥5.2（5.2447）、指标三项中的两项小幅回落（D$ 从 2 KB 加到 4 KB
> 换来"重定向切断"的周期预算，LUT 由 15,992 增到 17,105）。
> **若以 CoreMark/kLUT 或纯 CoreMark/MHz 为准，`board39` 仍是更好的选择，两份位流都保留。**
>
> 本版 RTL 相对 board39 的四处改动（每处都实测 `Total ticks` 逐位不变或已单独记账）：
> ① D$ 2→4 KB（−3,070 拍/迭代）② `ifu_axi` 重定向切断（+4,791 拍/迭代）
> ③ D$ 数据阵列按字节通道拆分（0）④ LRU 替换位延后一拍写（0）。
> ③④ 是纯物理改动，见 `evidence/records/optimization/p30-dcache-path/measurement.md`。
>
> ---
>
> ## 历史交付（2026-10-23 P20）：`pangoriscv_board39_i2300_5p294.sbit`
>
> **板上 CoreMark/MHz = 5.2941 @ 39 MHz / LUT 15,992**（三项指标同出这一份位流）
>
> | 项 | 值 | 证据 |
> |---|---|---|
> | 板测 `Total ticks` | **434,442,833** | `evidence/records/optimization/p19-bram-btb64/board_p20b.txt` |
> | 板测 `Iterations` | 2300 | 同上 |
> | 运行时间 | 434,442,833 / 39 MHz = **11.14 s ≥ 10 s** ✓ | 由 ticks 反推 |
> | 板测五项 CRC | `0xe9f5 / 0xe714 / 0x1fd7 / 0x8e3a / 0x988c` | 同上，`Correct operation validated` |
> | **CoreMark/MHz** | **5.2941** | 2300 × 1e6 / 434,442,833 |
> | 约束频率 / 布线后 | 39.000 MHz / **39.3252 MHz**（WNS **+0.212 ns**，setup 失败端点 **0**）| `report_timing.rtr` |
> | hold | WHS **−0.007 ns**，2 个端点失败（见下"已知残留"）| `report_timing.rtr` |
> | 面积（`device_map` `Used`）| **LUT 15,992 / FF 7,823 / LUTRAM 1,742 / DRM 12** | `synthesize_device_map_run.log` |
> | CoreMark/kLUT | **0.3311** | 5.2941 / 15.992 |
> | 位流 SHA256 | `771477ce099cb9afae0c99eadf905d87dd7c41e3e25fd06b046cd73567932612` | |
> | 约束文件 | `pango_native_39mhz.fdc`；PLL `27*52/36` | |
> | 镜像 | `build/native_software/coremark/performance/hw_i2300_39` | |
>
> **后续测量（2026-10-23 P21，未改变本交付）**：把 D$ 从 2 KB 加到 4 KB
> 再加"重定向切断"，仿真分数可到 **5.3834（仅 D$4KB）/ 5.2483（含切断）**，
> 布线后关键路径从 25.429 ns 降到 **20.613 ns（48.51 MHz）**；
> 但在 50/45/42 MHz 三个约束下分别差 0.61 / 0.46 / 1.12 ns，
> 没有任何一个约束能同时满足"收敛 + 满足自身周期"。
> 两处改动以 `docs/patches/dcache-4kb.patch` 与
> `docs/patches/apply-redirect-cut.py` 形式保存，**未应用**，
> 因为仓库必须能复现本文件交付的那一份位流。
>
> **已知残留**：hold 有 2 个端点差 7 ps（`WHS −0.007`，慢/快角各 2 个）。
> 上一版交付 `board36` 同样有 1 个端点的同类残留且上板正常。这一项**不合规**
> （要求 setup/hold 均无失败端点），正在用 `-fix_hold_violation_threshold 100`
> 与 `-check_clk_net_route_by_srb TRUE` 重跑修正。
>
> **相对上一版（`pangoriscv_board36_i2000.sbit`：5.213 @ 36 MHz / 18,181 LUT）**：
> 分数 +1.6%、频率 +8.3%、LUT −12.0%、LUTRAM −54%。
>
> **`crcfinal` 随迭代数变化，不是错**：`core_main.c` 的 `iterate()` 里
> `res->crc=crcu16(crc,res->crc)` 在 `for(i=0;i<iterations;i++)` 内累积，
> 20 迭代是 0x4983，2300 迭代是 0x988c。`seedcrc 0xe9f5` 才是 CoreMark
> performance run 的固定值。旧文档把 20 迭代仿真的 CRC 当上板判据，是错的。

---

## 历史版本

> **当前交付（2026-10-21）：`pangoriscv_i1152_e2.sbit` —— 板上 3.8557（同一分数，面积 −10.9%）**
> （298,780,717 ticks / 1152 迭代 / 11.066 s / 五项 CRC 全对；LUT 17,534 / FF 7,153 / kLUT 0.2199；
> setup +7.816 / hold +0.025 / 失败端点 0）
>
> 上一版（同分数、更大面积）：`pangoriscv_i1152_p37.sbit` —— 板上 3.8557
> （298,780,717 ticks / **1152** 迭代 / **11.066 s ≥ 10 s** / 五项 CRC 全对 / `Correct operation validated`）
> 交付镜像换用 **1152 迭代**：3.6345 那版用 1024 迭代已降到 9.83 s，CoreMark 判 "must execute for at least 10 secs"，
> 那就不再是有效成绩。详见 `evidence/records/optimization/perf-pair-raw-3.86/measurement.md`。
>
> 上一版交付（历史）：`pangoriscv_i1024_p36.sbit` —— 板上 3.6345
> （ticks 281,741,495 / 1024 迭代 / 10.435 s / 五项 CRC 全对 / 27 MHz `All Constraints Met`，
> hold +0.002 / 失败端点 0 / LUT 18,099）。下面 2026-10-19 的声明是历史版本（2.8833），
> 详细对比见文末「写通路吞吐版」一节。

> ## （历史）成绩有效性声明（2026-10-19：P21 位流 2.8833）
>
> **① 的分数已经在本文件这份位流上、于真实开发板上跑出来了。**
>
> | 项 | 值 |
> |---|---|
> | 板测 `Total ticks` | **288,558,769** |
> | 板测 `Iterations` | 768 |
> | 板测用时 | 10.687 s（≥10 s ✓，**832 迭代**） |
> | 板测五项 CRC | `0xe9f5 / 0xe714 / 0x1fd7 / 0x8e3a / 0x3c53` |
> | 板测结论 | `Correct operation validated` |
> | 板测 `Compiler version` | GCC15.2.0 |
> | 板测 **CoreMark/MHz** | **2.8833** |
>
> 原始串口抓取：`evidence/records/optimization/P21/board_uart_score.txt`
> （691 B）；烧写记录与 PDS 全套：同目录。
> 板卡 PG2L100H、27 MHz 晶振、Pango USB Cable II 下载、串口 CP210x @115200 8N1。
>
> **与仿真的关系**：位流中带有固件镜像（综合日志确认
> `Loading memory data from file .../program.hex`），板上串口直接读出 `Total ticks`，
> 这是**实测值**，不依赖仿真推算。
>
> **仍缺的证据**：②（时序收敛）与 ③（综合资源）是真实工具产物，已具备；
> **ILA 波形尚未抓取**（赛题文档评分项），应用场景章节尚未撰写。

## 2026-10-21 追加：写通路吞吐版（板上 **3.6345**）—— **当前交付**

> 位流 `pangoriscv_i1024_p36.sbit`。同镜像 score1024、同工具、同流程；
> 改动只有 D-Cache 的 posted store 队列 + tag 写数据重定时，以及 AXI 写引擎的两处握手重叠
> （详见 `evidence/records/optimization/perf-writepath-3.63/measurement.md`）。

| 项 | 值 |
|---|---|
| 板上 `Total ticks` | **281,741,495** |
| 板上 `Iterations` | 1024 |
| 板上用时 | **10.435 s ≥ 10 s** |
| 五项 CRC | `0xe9f5 / 0xe714 / 0x1fd7 / 0x8e3a / 0x9ce8`（与基线逐项相同） |
| 结论 | `Correct operation validated` |
| **CoreMark/MHz** | **3.6345**（相对 3.4222 → +6.21%） |
| ② 时序 | 27 MHz `All Constraints Met`，setup **+10.041**，hold **+0.002/+0.001**，失败端点 **0** |
| ③ 资源 | LUT **18,099** / FF **9,931** / LUTRAM **3,628** → CoreMark/kLUT **0.2008** |

⚠️ **这份位流 hold 只有 +0.002 ns，不要再重跑同一个构建目录**（重跑会覆盖证据，且新种子可能更差）。
若必须重建，先确认 `multiseed_summary.csv` 仍是 `single,OK,OK` 且 hold > 0。

| 文件 | 大小 | SHA256 | 板上实测 |
|---|---|---|---|
| `pangoriscv_i768.sbit` | 3,791,112 B | `1FAC6F435BA34641BB8D16285CFFFA7811D2F787AEAF08805B4F5369A2B41F23` | 2.8833（2026-10-19） |
| `pangoriscv_i1024.sbit` | 3,791,112 B | `8D12C9D114C0DBE4455E0A50C0F944B7D8506273DB28ADAEBC3755205FA6A643` | 3.4194（2026-10-20，**面积优化前**） |
| `pangoriscv_i1024_area.sbit` | 3,791,112 B | `521EC6FEFD867E244DF4C955D6DA98519BEA06F5559E36498ED928DB5B9416BB` | 3.4222（2026-10-21，面积优化版） |
| `pangoriscv_i1024_p36.sbit` | 3,791,112 B | `BE749BC4830E33BB198BD2835251DE09526F4F7F267DCB19D3A08E536EA57737` | 3.6345（2026-10-21，上一版） |
| `pangoriscv_i1152_p37.sbit` | 3,791,112 B | `81C1D04936D3D5B5F70945A847EF6E9C5832D5A21B38FA9B46C60543BBE72B62` | 3.8557（2026-10-21，P37） |
| **`pangoriscv_i1152_e2.sbit`** | 3,791,112 B | `D7BF5E41B708F893DF57F5E049BA8A0168BE39BABB4773E3BFFEA5C0C25D3137` | **3.8557（2026-10-21，当前交付，面积 −10.9%）** |

## 2026-10-21 追加：面积优化版（板上 **3.4222**，LUT −18% / FF −30%）

> **当前候选交付位流**。与 `pangoriscv_i1024.sbit` 功能完全相同（同镜像、同 CRC），
> 但经过面积专项三项减法：M1 去仪表化 + M3 BTB 缩位宽 + M4a 取指队列 16→8。

| 项 | 优化前（`i1024`） | **本版（`i1024_area`）** | Δ |
|---|---:|---:|---:|
| 板测 `Total ticks` | 299,467,030 | **299,226,614** | −0.08% |
| 板测用时 | 11.091 s | **11.082 s**（≥10 s ✓） | — |
| 板测五项 CRC | `e9f5/e714/1fd7/8e3a/9ce8` | 同 | 0 |
| 板测 **CoreMark/MHz** | 3.4194 | **3.4222** | +0.08% |
| LUT（device_map） | 21,949 | **18,006** | **−18.0%** |
| FF | 14,104 | **9,877** | **−30.0%** |
| 分布式 RAM / DRM / APM | 3,628 / 4 / 6 | 3,628 / 4 / 6 | 0 |
| **站点 S = LUT+FF+LUTRAM** | 39,681 | **31,511** | **−20.6%** |
| setup（慢角） | +14.750 | **+12.972** | 仍大量余量 |
| **hold（慢/快）** | +0.015 / +0.002 | **+0.020 / +0.015** | **余量变好** |
| 失败端点 | 0 | **0** | — |
| **CoreMark/kLUT** | 0.1558 | **0.1901** | **+22.0%** |

- 构建目录：`firmware/code/build/pango_native`（**禁止再跑第二次实现**）；
- 构建 profile：**`PERF_ENABLE` 关**（交付 profile），`CACHE_ENABLE`/`PREDICT_ENABLE` 开；
- 镜像：`score1024`（`program.hex` = `F67A0299…F42C4`），综合日志有 2 条 `Loading memory data from file`；
- 完整证据（时序报告/三阶段日志/板上原文/资源表）：`evidence/records/optimization/area-final/`；
- 面积账本与模块合同：`docs/architecture/module-area-plan.md` + `area-budget.csv`。

## 2026-10-20 追加：4 KB I-Cache + 最小 lane1 双发射（板上 3.4194，面积优化前）

> 这个文件是**备份**，不改变上面 2.8833 那份的交付地位；用哪一份交付由评审/作者决定。
> 之所以必须备份：它是**踩线收敛**的唯一一份位流（同一 RTL 的其它种子在 22k 上布不通）。

| 项 | 值 |
|---|---|
| 板测 `Total ticks` | **299,467,030** |
| 板测 `Iterations` | 1024 |
| 板测用时 | 11.091 s（≥10 s ✓） |
| 板测五项 CRC | `0xe9f5 / 0xe714 / 0x1fd7 / 0x8e3a / 0x9ce8` |
| 板测结论 | `Correct operation validated` |
| 板测 **CoreMark/MHz** | **3.4194**（= 1024 / 299,467,030 × 1e6） |
| 资源（device_map） | 21,949 LUT / 14,104 FF / DRM 4 / APM 6 / 分布式 RAM 3,628 |
| 时序（`multiseed_summary.csv`） | `All Constraints Met`；setup +14.750 / +22.341；**hold +0.015 / +0.002**；失败端点 0 |
| 配置 | 三开关全开；I-Cache 64 组（4 KB）；双发射最小 lane1 |
| 镜像 | `program.hex` = 1024 迭代（`F67A0299…`），`data.hex` = `5D5F267A…` |
| 构建目录 | `firmware/code/build/code_ic4k`（**禁止在该目录再跑第二次实现**） |
| 原始抓取 | `evidence/records/optimization/4kb_3.423/uart_4kb_recheck.txt` |

**风险（交付前必须写进口径）**：hold 仅 **+0.015 / +0.002 ns**，是"刚好过"的量级；
换种子/换温度都可能翻负。若重新实现，先看 `multiseed_summary.csv` 的 hold 列。

**板卡**：Pango PG2L100H，27 MHz 晶振。

**配置**：`CACHE_ENABLE` / `PREDICT_ENABLE` / `PERF_ENABLE` 三开关全开（全功能配置），BTB 32 项。

**固件**：CoreMark v1.0 性能跑（`PERFORMANCE_RUN=1`），**832 次迭代**，`-DCPU_FREQ_MHZ=27`。
> 迭代数随性能变化而重算：本版每迭代 346,827 ticks，
> `N ≥ ceil(10.5 × 27e6 / 346,827) = 818`，取 832 → 实测 10.687 s。
> **性能每提升一次都必须重算，否则 <10 s 会被判无效**（本版曾用 768 迭代跑出 9.865 s 而作废）。

> 迭代数为什么是 768：赛题要求单次运行 ≥10 s。本轮把 AXI RAM 猝发读的两个白等周期去掉后，
> 每迭代 ticks 降到 373,738，按 `N ≥ ceil(10.5 × 27e6 / 373,738) = 759` 重算后取 768，
> 实际 10.64 s。**性能每变一次都必须重算，否则成绩作废。**

**串口输出（2026-10-19 板上实测，同一镜像 `score768`）**：

```
Total ticks      : 288558769
Total time (secs): 10
Iterations/Sec   : 76
Iterations       : 768
seedcrc          : 0xe9f5
[0]crclist       : 0xe714
[0]crcmatrix     : 0x1fd7
[0]crcstate      : 0x8e3a
[0]crcfinal      : 0x3c53
Correct operation validated. See readme.txt for run and reporting rules.
```
> 注：`Total time (secs)` 与 `Iterations/Sec` 是固件的**整数截断**打印（`core_portme.h` 里 `HAS_FLOAT 0`）。真实时间是 10.631 s，固件按 `floor(10.631)=10` 打印，故 `Iterations/Sec = 768/10 = 76`。**分数必须用 `Total ticks` 计算**：`768 / 287,211,317 × 1e6 = 2.6740`，不能用 `Iterations/Sec` 反推。


`crcfinal` 随迭代数变化（最终 CRC 是跨迭代累积的）：20→`0x4983`、400→`0x25b5`、
512→`0xdfc8`、576→`0x7b65`、640→`0x382f`、768→`0x3c53`。官方只与已知表比对
`crclist / crcmatrix / crcstate`，三项全对，`total_errors` 为 0，故
`Correct operation validated` 已打印。

**评分口径**

| 项 | 值 | 口径 |
|---|---|---|
| ① 执行效率 | **2.6757 CoreMark/MHz** | `iterations / ticks × 1e6`，迭代数无关的归一化指标 |
| ② 时钟频率 | **27 MHz 约束 All Constraints Met**；**50 MHz 过约束同样 All Constraints Met** | 数值取自各次 PDS 的 `multiseed_summary.csv`（**收尾权威值，不是 `*_after_hold_fix.txt` 中间快照**）。27 MHz：setup **+14.578 ns**、hold **+0.115 ns**，0 失败端点，见 `evidence/records/optimization/P17/pds_27mhz_full/`。50 MHz：setup **+1.262 ns**、hold **+0.121 ns**，0 失败端点，见 `evidence/records/optimization/P17/pds_50mhz_full/`。板载晶振 27 MHz，**不是**板上实测最高频率 |
| ③ 资源效率 | **0.1985 CoreMark/kLUT** | `13,481 LUT`，**取自 device_map**（`multiseed_summary.csv` 的 `Used` 行）。同一实现另有两个阶段的数：synthesis 13,574、后布线更小；**引用 LUT 必须写阶段** |

**提升幅度**

| 阶段 | ticks | CoreMark/MHz | LUT | CoreMark/kLUT |
|---|---|---|---|---|
| S0 基线（store 优化前，400 迭代） | 306,415,752 | 1.3054 | 12,572 | 0.1038 |
| store 后台排空 B 响应（512 迭代） | 356,993,719 | 1.4342 | 12,622 | 0.1136 |
| 取指吞吐（512 迭代） | 304,495,134 | 1.6815 | 13,018 | 0.1292 |
| 访存快发（576 迭代） | 309,304,812 | 1.8622 | 13,059 | 0.1426 |
| 访存完成提前报（640 迭代） | 307,055,517 | 2.0843 | 13,099 | 0.1591 |
| 零延迟 D-Cache 命中（768 迭代） | 323,940,991 | 2.3708 | 13,558 | 0.1749 |
| 读命中不阻塞写事务（768 迭代） | 299,139,003 | 2.5674 | 13,558 | 0.1894 |
| store 当拍拿写确认（768 迭代） | 294,149,365 | 2.6109 | 13,576 | 0.1923 |
| AXI 猝发气泡清除（768 迭代） | 287,211,317 | 2.6740 | 13,574 | 0.1970 |
| LRU 修复 + 重新实现（768 迭代） | 287,030,751 | 2.6757 | 13,481 | 0.1985 |
| 复核 R01/R02/R04 修复 + 重建（768 迭代） | 284,997,892 | 2.6948 | 13,503 | 0.1995 |
| store 数据随请求拍递出（768 迭代） | 280,487,382 | 2.7381 | 13,555 | 0.2020 |
| I-Cache 扩到 4 KB（64 组）+ 上述改动 | 273,172,370 | 2.8115 | 14,622 | 0.1923 |
| **I-Cache 扩到 8 KB（128 组）+ 上述改动（本版位流，832 迭代）** | **288,558,769** | **2.8833** | **16,782** | **0.1718** |

累计 **+104.97% CoreMark/MHz**（超过一倍）、**+91.24% CoreMark/kLUT**，
面积仅 **+7.23%**（12,572 → 13,481）。本版相对上一版是 **性能 +0.06%**；主要变更是修掉独立复核提出的 R03（快命中路径漏更新 LRU，`d_miss` −8.3%）。

**三项数据同源**：本目录位流、`13,481 LUT`、27 MHz 时序，全部来自同一次 PDS 运行，整套原始产物已归档在 `evidence/records/optimization/P17/pds_27mhz_full/`（位流 + `multiseed_summary.csv` + `report_timing.rtr` + `device_map` / `synthesize` / `place_route` / `compile` 日志）。50 MHz 那一套在同级 `pds_50mhz_full/`。

**时序余量说明**

- 27 MHz：setup **+14.578 ns**、hold **+0.115 ns**，0 失败端点（`multiseed_summary.csv` 收尾值）。
- 50 MHz：setup **+1.262 ns**、hold **+0.121 ns**，0 失败端点，是本版最紧的一项。
- **口径**：`place_route/*_after_hold_fix.txt` 是中间快照，其 slack 与最终值不同（本版中间值 17.390，收尾 14.578）。引 slack 只用 `multiseed_summary.csv`。
- 收敛经验（务必保留）：
  - 27 MHz 的 hold 必须用 **`-fix_hold_violation_threshold 500`**（不是 300）；
    但对本版而言**阈值不再敏感**（500 与 700 的结果完全相同，都是 3 个端点 −0.012），
    最终靠 `-groute_seed/-gplace_seed 11` 才通过。`seed 41` 路由器甚至不收敛
    （1042 次迭代后仍有 1096 根未布线）。
  - **50 MHz 是种子敏感的**：本版 `seed 23` 一次通过。换一次 PnR 可能不收敛，
    **不能拿一次通过当保证**。

**可复现性**：同一组 PnR 参数重跑，slack 与失败端点数完全一致，但 `.sbit` 的 SHA256
每次不同（Pango 位流容器含非确定性元数据）。所以"位流哈希一致"不能当作可复现的证据，
必须连同该次运行的时序汇总一起归档。

**证据等级（重要）**：CoreMark 的 ticks / CRC / 运行时间均来自**周期精确的 RTL 仿真**，
不是板上实测——目前没有物理开发板。仿真里"总时间"由固件按 `CPU_FREQ_MHZ=27` 从 ticks 换算，
因此在 27 MHz 板卡上就是表中的 10.64 s；但**串口实物输出仍需上板复现**。
频率一栏是约束收敛结果，按赛题诚信边界不得写成"实测最高频率"。

上板后必须补的三件事：实板串口抓完整报告、ILA 抓 CoreMark 关键算法波形、
以及用实测数据重算迭代数。详见 `docs/verification.md` 与
`evidence/records/optimization/P16/measurement.md`。

**已取代**：`pangoriscv_i400.sbit`、`pangoriscv_i512.sbit`、`pangoriscv_i576.sbit`、
`pangoriscv_i640.sbit` 均已从本目录移除，其数据保留在 git 历史与 `evidence/records/` 中。

自行重新构建位流的流程见 `firmware/code/platform/pango_native/README.md`。
**注意**：必须在 `build/pango_native` 目录里直接启动 `pds_shell`，否则 `$readmemh`
找不到 `program.hex`/`data.hex`，会得到存储器全空的位流；反过来若从源码根启动，
产物会写进 `firmware/code/` 污染工作区。
