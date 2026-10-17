# tinyriscv-AXI4 RV32IM 软核：CoreMark 提分文献调研（有引用来源）

**日期**：2026-10-13
**对象**：`01_code/pangoriscv_axi4`（RV32IM 顺序单发射，三级流水，AXI4 单 master 对，I/D-Cache 2 路×32 组×32 B，BTB 32 项 + 2 位饱和计数器，perf_regs 计数器）
**平台**：Pango Logos2 PG2L100H-6，CPU 27 MHz，CLMA 2,538/11,675（22%）
**实测基线**：CoreMark 200 迭代——无 Cache 656,167,771 ticks（IPC 0.0931）→ 加 I/D-Cache 351,948,617（IPC 0.1735）→ 加动态预测 326,735,694（IPC 0.1871）；错预测率 60.18%→15.83%，每次错预测代价 4.10 cycles。

---

## 0. 从 RTL 读出的瓶颈（本文所有排序的事实基础）

需求方给的 perf 线索（`if_wait`≫`lsu_wait`）在 RTL 里能定位到三条硬约束，它们决定了"哪个优化有收益"：

| 位置 | 事实（源码） | 推论 |
| --- | --- | --- |
| `rtl/core/ifu_axi.v:19,26,27,33,47-70` | `localparam EMPTY=0,WAIT_DATA=1,HOLD=2`；`eng_req_valid = rst_n && idle && enable && !redirect_valid && !local_fault`；`fetch_valid = state==HOLD && …`；HOLD 的出口条件是 `fetch_valid && fetch_ready` | **IFU 是"一发一等"的 3 态机**：EMPTY(发请求)→WAIT_DATA(收数据)→HOLD(交给流水线)。只有流水线**吃掉**当前指令后，下一拍才回到 EMPTY 发下一个请求。取指吞吐被钉死在 <1 IPC |
| `rtl/core/icache_axi.v:101,137-164` | `req_ready = rst_n && state==IC_IDLE`；命中后 `IC_IDLE→IC_HITRD→IC_RESP`，`IC_RESP` 等握手才回 `IC_IDLE` | **I-Cache 命中本身也是 2~4 拍**（tag 比较 1 拍 + 同步 BRAM 数据 1 拍 + 响应握手 1 拍），再叠加 IFU 的 3 态机 |
| `rtl/core/lsu_axi.v:42-48,82,89-92` | `eng_w_valid = state==WRITE_DATA`；`eng_b_ready = state==WRITE_WAIT`；`WRITE_WAIT: if(eng_b_valid && eng_b_ready) state<=COMPLETE`；`op_ready = rst_n && idle` | **每条 store 至少 4 拍且必须等 AXI B 响应**；LSU 全程 `idle=0`，没有任何 store buffer 吸收 |
| `rtl/core/branch_predictor.v:52-61,73` | 32 项直接映射，索引 `PC[6:2]`，tag `PC[31:7]`；`always @(posedge clk) … else if (train_valid && train_control)`，`train_valid = retire_fire` | **没有 RAS**（`JALR` 一律 predicted taken，目标来自 BTB 单表项）；**训练在 retire 边界**，不投机训练；32 项表小，CoreMark 控制流易冲突 |

> 一句话结论：**当前每取一条指令的最低成本 ≈ 5 拍**（IFU 3 拍 + I-Cache 命中 2 拍 + 重定向/停顿），这解释了 IPC 0.187 和 `if_wait` 主导。所以**收益最大的方向是"取指解耦 + I-Cache 命中路径流水化"，而不是继续加 Cache 容量**。

---

## 排序后的技术清单

> 排序依据 = 预期收益 ÷（风险 × 工作量），并只在"能落到本项目模块"的前提下排序。
> "预估收益"里标 ★ 的为我基于上表 RTL 事实的推断（无公开同规模数据）；标数字的为文献报告值。

| # | 技术 | 来源与报告收益 | 本设计适配性 | 预估收益（CoreMark） | 风险/工作量 |
| --- | --- | --- | --- | --- | --- |
| 1 | **取指解耦：小指令队列（fetch queue）+ 提前取下一拍 PC** | Shanley & Anderson, *PCI System Architecture* 类"预取缓冲"描述属经典教材级；学术上最贴合的是 Skadron/Ahuja/Martonosi, *Instruction Fetching: A Case for Fetch-Directed Prefetching*, ISCA 2002（[IEEE](https://ieeexplore.ieee.org/document/809439/)）——主张用预测流驱动取指、把已预测路径的指令提前搬进队列。另：Continual Flow Pipelines, ASPLOS 2004（[PDF](https://uwaterloo.ca/scholar/sites/ca.scholar/files/z399huan/files/continual_flow_pipelines.pdf)）论证"窄发射核的瓶颈常在取指供给而非执行" | **极高**：改 `ifu_axi.v` 即可，不动 AXI/Cache。把 EMPTY→WAIT_DATA→HOLD 改成"IFU 可连续向 I-Cache 发请求、结果入 4~8 项 FIFO"，重定向只 flush FIFO，不再把在途请求标 `stale_q` 丢弃 | ★ IF 等待几乎清零，保守 +25~40%（IPC 0.187→0.24~0.26） | 低。改动 ~80 行；需处理 redirect 与在途响应、FIFO 空/满与 `enable` 门控。有 `tb_ifu_axi.sv`/`tb_ifu_axi_engine.sv` 现成 TB |
| 2 | **BTB 扩容：32→128/256 项 + 加 RAS（8 项）+ 索引去掉低位对齐** | TAGE/COTTAGE 的"等价存储预算下显著优于 CBP-2004 所有预测器"（Seznec & Michaud, JILP 8, 2006，[HAL](https://inria.hal.science/hal-03408381v1)）；RAS 属教科书级结构（Hennessy & Patterson, *CA:AQA*）。软核上唯一的公开同规模对照：*Exploration of High-Performance Branch Predictors for Softcore Implementations*（FPL 投稿，[Southampton ePrints](https://eprints.soton.ac.uk/513929/)）报告 2 位预测器把错预测率从 **60.96% 降到 7.08%**（−88.4%），面积代价仅 3.x% 量级（该数字来自检索片段，**未核实**其核型与工艺） | **极高**：`branch_predictor.v` 是纯寄存器表，`ENTRIES` 已是参数；33 KB 空间里加 96 项只多几百 LUT/FF。RAS 对 CoreMark 的 `list_*`/`core_*` 函数调用返回尤其有效 | ★ 错预测率 15.83%→10~12%，约 +3~6%；RAS 单独可能 +1~3% | 低。`ENTRIES` 直接加大即可，但 tag 位宽会变（需同步改 `TAG_BITS`）；RAS 需新增 push/pop 语义与 TB 用例 |
| 3 | **I-Cache 命中路径流水化 + way prediction（把 2~4 拍命中延迟压到 1~2 拍）** | Way prediction 属商用核常用微架构（ARM/Xilinx 专利与手册有描述，如 [US11048637](https://patentimages.storage.googleapis.com/9f/76/98/1da3981eee5274/US11048637.pdf) "way predictor tables … leverage the spatial locality of cache accesses"）；延迟降低的收益可用 Amdahl 直接推算 | **高**：`icache_axi.v` 命中路径现在走 `IC_HITRD`（同步 BRAM 读）→`IC_RESP`。可改为"tag 比较与数据 BRAM 读同拍发起、命中即当拍出数据"，再用 1 位 way 预测表省掉读后再选路一拍 | ★ 每条指令省 1~3 拍 ≈ +15~30%（与 #1 有重叠，先做 #1 再做 #3 可叠加剩余部分） | 中。命中组合路径变长，**27 MHz 不紧张但要注意保持时序**；`invalidate` 与在途 fill 的互锁逻辑要重审 |
| 4 | **I-Cache next-line / sequential prefetch（顺序预取下一行）** | Jouppi, *Improving Direct-Mapped Cache Performance by the Addition of a Small Fully-Associative Cache and Prefetch Buffers*, ISCA 1990（[ACM](https://dl.acm.org/doi/abs/10.1145/325164.325162)）首创 stream buffer/prefetch buffer；同派生的 next-line 预取在 Berkeley CS152 讲义（Kubiatowicz, Spring 2004, [lec20-cache.pdf](https://people.eecs.berkeley.edu/~kubitron/courses/cs152-S04/lectures/lec20-cache.pdf)）中引用了 16 B/项配置下 **1.23×~1.32×** 的等效收益曲线（二手引用，**未核实**具体对应关系） | **高**：`icache_axi.v` 已有 8 拍 `ARLEN=7` 整行补行机制（`m_arlen = 8'd7`），加"预取下一行"只需在 fill 完成后追加一次 `AR` 请求 + 一个 1 位 pending 寄存器；`I_AR_LEN7` 计数器现成可量 | ★ `i_miss=48` 相对 `cycle=123,535` 很小，但每次 miss 代价 = 8 拍突发 + 总线延迟；预取可把这部分藏到当前行执行之后，约 +3~8% | 中。必须保证**预取不越过可执行区**（`EXEC_BASE/EXEC_BYTES`）与 MMIO 边界；与 `invalidate`（halt/下载后）的互锁要小心，否则会"预取回旧代码" |
| 5 | **Store buffer + 写合并（把"等 B 才退休"变成解耦）** | 教科书级结构（Hennessy & Patterson, *CA:AQA*, Ch.3/附录 memory hierarchy）；AMBA AXI 允许 **AW 提前发出、B 乱序返回**（Arm, *AMBA AXI Protocol Specification*, IHI 0022，[documentation-service.arm.com](https://documentation-service.arm.com/documentation/ihi0022/l?lang=en&rev=0)），这正是 store buffer 的协议基础 | **中高**：`lsu_axi.v` 现在 `WRITE_WAIT` 死等 B。改成"store 入 4~8 项 FIFO 即 `COMPLETE`，后台 drain"，并把相邻同 4 KB 的 store 合并成长度>1 的 INCR 写突发。**必须保持 MMIO 区强序**（`dcache_axi.v` 的 `CACHED_LIMIT` 旁路路径） | ★ `lsu_wait=5,963` 只占 4.8%，但每条 store 的 4+ 拍是流水线气泡；实测约 +4~8%，配合写合并涨 AXI 有效带宽后对 DDR/慢 slave 收益更大 | 中高。**B 响应与 fault 语义**：store 的 fault 不能再同步在 `COMPLETE` 报告；halt/reset 必须 drain FIFO（现有 `tb_halt_reset_drain.sv` 要扩展）；`d_b_fire` 计数含义变化 |
| 6 | **D-Cache 写回 + 写分配（write-back/write-allocate）+ Victim cache** | 写回/写分配收益见 Jouppi ISCA 1990（同上）；victim cache 的原始结果同样出自该文（Berkeley 讲义引用其 16 B 配置收益曲线，**未核实**）。现代同源证据：Million/Oliete-Escuín/Fuguet, *Breaking the Memory Wall with a Flexible Open-Source L1 Data-Cache*, DATE 2024（[HAL](https://hal.science/hal-04600058v1)，DOI 10.23919/DATE58400.2024.10546547）——把 CVA6 的 L1D 换成带并发/流水化的非阻塞 HPDcache，关键基准**最高 +234% 加速，面积仅 +5.92%** | **中**：当前 `dcache_axi.v` 4 处注释写明 `write-through, no write allocate`，`d_miss=61` 很小，说明 D 侧不是主矛盾。真正值得抄的是 DATE 2024 的"内存子系统缺并发/流水"诊断 | ★ 对 CoreMark 直接收益小（D miss 少）；但对含矩阵/缓冲区的负载才是主收益。**不建议本轮做** | 高。脏行回写、fault 精确定位、`invalidate` 语义、读改写全要重做；用 CoreMark 衡量会"投入大、回报小" |
| 7 | **非阻塞 Cache / MSHR（hit-under-miss）** | Kroft, *Lockup-free Instruction Fetch/Prefetch Cache Organization*, ISCA 1981（[ACM](https://dl.acm.org/doi/abs/10.5555/800052.801868)）是开山之作；量化收益见 DATE 2024（+234%，如上） | **中低**：本设计 I/D 各一个 engine，`axi_read_engine` 明确限制 `AXI_ENGINE_MAX_LEN`，要支持多 outstanding 需改互连与 ID 管理（`icache_axi.v` 已有 `m_rid != id_q` 的协议 fault 检查，说明 ID 机制在位） | ★ I miss 少（48 次）→ 收益有限；对小核是"结构正确但性价比低" | 高。需要 MSHR 表、多 ID 分配、与 interconnect 的 outstanding 深度协商 |
| 8 | **TAGE / 长历史预测器（替换 2 位计数器）** | Seznec & Michaud, *A case for (partially) tagged geometric history length branch prediction*, JILP 8, 2006（[HAL](https://inria.hal.science/hal-03408381v1)）——**明确声明"在等价存储预算下，TAGE 显著优于 CBP-2004 上所有预测器"**（原文未给单一百分比）；ETH 收录的 TAGE-SC-L 讲义（[PDF](https://safari.ethz.ch/digitaltechnik/spring2023/lib/exe/fetch.php?media=tage-sc-l2014seznec.pdf)）给出实现细节 | **中**：TAGE 的最小可用配置（几个 tagged 表 + 几何历史）在 FPGA 上是 BRAM/LUTRAM 友好的，但**索引需要全局历史移位寄存器 + 多路 hash**，在 27 MHz 顺序核上主要成本是设计与验证，不是面积 | ★ 若 #2 已把错预测率压到 ~11%，TAGE 顶多再降到 7~8%，即 **+1~3%**，边际收益低 | 中高。训练/投机更新的正确性难验证（现有 `tb_branch_predictor.sv` 要重写）；建议**先做 #2，把 TAGE 留作后续** |
| 9 | **Loop buffer / 指令行缓冲（消除循环体的 I-Cache 访问与命中延迟）** | 低能耗嵌入式取指缓冲的系统性探索：*Instruction buffering exploration for low energy embedded processors*, Journal of Embedded Computing（[ACM](https://dl.acm.org/doi/abs/10.5555/1233748.1233753)）；另有 *Reducing Power and Energy Overhead in Instruction Prefetching for Embedded Processor Systems*（IGI Global 书章，ISBN 9781466627857，[viewtitlesample](https://www.igi-global.com/viewtitlesample.aspx?id=73220&ptid=69828)）。两者的报告指标以**取指能耗下降**为主，公开的 IPC 提升数据我没找到 | **中高**：CoreMark 的 `core_list_join`/`core_state_transition` 循环体小，loop buffer 命中率高；且它同时**绕过了 IFU 状态机与 I-Cache 命中延迟**，与 #1 天然互补 | ★ 与 #1 叠加后可能是"压死 if_wait"的最后一步，+5~15%；但**无同规模公开数据，属推断** | 中。循环边界检测（后向分支 + 迭代计数）与重定向交互是主要复杂度；建议在 #1/#3 之后按 perf 数据决定是否做 |
| 10 | **取指-分支预测解耦（predictor 与取指队列握手重构）** | Skadron et al., ISCA 2002（[IEEE](https://ieeexplore.ieee.org/document/809439/)）的核心论点；Continual Flow Pipelines, ASPLOS 2004（[PDF](https://uwaterloo.ca/scholar/sites/ca.scholar/files/z399huan/files/continual_flow_pipelines.pdf)） | **高**：这一条其实是 #1 的"另一半"——`ifu_axi.v` 的 `redirect_valid` 会 `stale_q<=1` 并在 WAIT_DATA 直接丢弃响应，是纯浪费。解耦后可让在途响应"落地但不交付" | ★ 已包含在 #1 的收益里 | 低（与 #1 同一次改动） |
| 11 | **分支预测训练前移（retire 训练 → EX 训练 / 投机训练）** | 无直接对口文献；`branch_predictor.v:15-17` 的注释说明当前是刻意选择 retire 训练以保证"与 predict-not-taken 架构等价" | **高**：CoreMark 错预测 15.83%，而 4.10 cycles/miss 的代价里有一部分来自"表更新太晚导致同一分支连续错两次" | ★ +1~3%；**无公开数据，属推断** | 中。会破坏"预测开关不影响架构结果"的等价性论证，`run_predictor_tests.py` 需要新增断言 |
| 12 | **双发射（最小代价做法）** | 最贴合的公开数据：Mendes/Figueiredo/Menotti, *TORVS: A Lightweight Dual-Issue Superscalar RISC-V Core for FPGA-Based Systems*, SBESC 2025（[SBC OpenLib 摘要](https://sol.sbc.org.br/index.php/sbesc/article/view/40351)，IEEE Xplore 11288856）——RV32I 五级双流水，CoreMark **1.176–1.600 CoreMark/MHz**（参数化设计点），Dhrystone 1.708–2.331 DMIPS/MHz，结论是"轻量设计在基础操作上有竞争力，复杂负载下效率下降"。另有 FPGA 软处理器并行执行单元/writeback 设计研究（[IEEE 9114632](https://ieeexplore.ieee.org/document/9114632)） | **中**：需再加一条流水线 + 寄存器堆第二读口/写口 + 旁路网络 + 冲突检测。当前 CLMA 余量（22%）够，但**三级流水双发射的冒险检测复杂度上升很快** | ★ TORVS 的参数化结果暗示双发射相对单发射有可观提升，但它没有给出"单发射基线"，**不能直接外推到本设计**；本项目自测单发射 0.61 CoreMark/MHz，即使到 1.0 也只 ~1.6× | 高。属"重写半个核"，不应与 #1~#5 并行做 |
| 13 | **寄存器堆 banking / 多端口化** | FPGA 上多泵多端口寄存器堆的实现与面积曲线：*Efficient Implementations of Multi-pumped Multi-port Register Files in FPGAs*, DSD 2013（DOI 10.1109/DSD.2013.28，检索命中，**未核实**细节） | **低（除非做 #12）**：当前 `rtl/core/regs.v` 仅 95 行，单发射不需要 banking | ★ 单发射下 ≈0% | 中。只有 #12 落地后才有意义 |
| 14 | **位串行 / 流水化 ALU** | *Study of Interlock Collapsing ALUs for RISC-V Microprocessors*（TU Delft 学位论文，[PDF](https://repository.tudelft.nl/file/File_5494a8b8-c690-4e80-a089-6069cfc3ebbb?preview=1)）——研究互锁合并型 ALU；检索片段还命中"serialized ALU 由 control/shift/… 组成"的描述（[ACM DL](https://dlnext.acm.org/doi/pdf/10.1145/3801488.3807977)），**两处细节均未核实** | **低**：27 MHz 下 ALU 不是时序瓶颈；`ex.v` 862 行里真正贵的是一次除法（`div.v` 205 行，逐位迭代） | ★ 若 CoreMark 有除法热点才有收益；否则 ≈0%。**无公开数据，属推断** | 中。会改变多周期指令的时序契约 |
| 15 | **频率提升（27 MHz → 更高）** | FPGA 侧方法论引用 AMD/Xilinx 官方指南 UG949 *Vivado Design Methodology*（[PDF](https://china.xilinx.com/content/dam/xilinx/support/documents/sw_manuals/xilinx2017_2/ug949-vivado-design-methodology.pdf)）、UG901 *Vivado Synthesis*（[PDF](https://www.ecs.csun.edu/~smirzaei/docs/ece524/ug901-vivado-synthesis-en-us-2025.1.pdf)）。**Pango 官方 PDS 时序/综合指南我未取得可引用链接，标注"未核实"** | **高（但要先证明时序余量）**：CoreMark 分数 ∝ 频率，若 27 MHz 时 WNS 富余很大，提频是**唯一"零架构风险"的线性收益** | 频率 ×1.5 → 分数 ×1.5（若 WNS 允许） | 低~中。风险全在时序收敛：`icache_axi.v` 的 tag 比较 + `ex.v` 的旁路/比较器是关键路径。CLMA 22% 说明有布线余量 |
| 16 | **I-Cache 容量/行大小/相联度调整** | Jouppi ISCA 1990 的 stream buffer + victim cache 组合是"小 Cache 提命中"的经典答案（[ACM](https://dl.acm.org/doi/abs/10.1145/325164.325162)） | **中**：CoreMark 代码体积约几 KB 量级（官方口径下 `core_list_join`/`core_matrix`/`core_state` 为主体；精确值**未核实**），当前 I-Cache 2,048 B 已接近临界；CLMA 只用 22%，扩到 4 KB 几乎免费 | ★ 若 CoreMark 代码 > 2 KB，扩到 4 KB I-Cache 可能直接消掉一部分 `i_miss` | 低。改 `SETS` 参数即可，但要同步 `tb_icache_axi.sv` 的几何断言与板级 CLMA 记录 |
| 17 | **软件/工具链：`-O3` / `-funroll-loops` / `-flto` / `-march=rv32im`** | **CoreMark 官方口径**：`eembc/coremark` 仓库说明与 `core_portme.mak` 的 `PORT_CFLAGS`/`ITERATIONS` 机制（[GitHub](https://github.com/eembc/coremark)，检索片段确认存在；`raw.githubusercontent.com` 在本环境超时，正文**未能逐字核对**）；官方 Run Rules PDF 的旧链接 <http://www.eembc.org/coremark/CoreMarkRunRules.pdf> 现已 404。Embench 侧的权威公开材料：Bennett, *How good is RISC-V: Comparing benchmark results*, FOSDEM 2025 RISC-V devroom（[日程页](https://archive.fosdem.org/2025/schedule/event/fosdem-2025-5678-how-good-is-risc-v-comparing-benchmark-results/)）——明确讲"不同扩展与编译器对编译代码性能的影响"，并给出用 ML 辅助调优在 **24 小时内把 OpenHW CV32E40Pv2 的代码密度改善 7%** 的实测 | **极高（零 RTL 风险）** | 官方口径下 `-O3`/LTO 通常比 `-O2` 高个位数百分比，但**我没有找到可核实的 CoreMark `-O2`→`-O3` 具体百分比**，必须本地 A/B 实测 | 极低。你的构建器已支持传参（见 `README.md` 的 `tools/build_native_software.py`）；只需扩成矩阵扫描 |
| 18 | **软件：不改代码只改放置（I-Cache 感知的链接/对齐、去掉 `printf` 等冷路径）** | 同 FOSDEM 2025（代码密度 −7% 的实测）；CoreMark 官方明令**不得**为跑分而预计算/改算法（见"口径"小节） | **极高**：把热循环对齐到 32 B 行边界、让 `core_state_transition` 的状态机表不跨行，能直接减少 `i_miss` | ★ 与 #17 一起做，合计可能 +5~15%；**无公开同规模数据，属推断** | 极低。纯构建/链接配置 + `nm`/反汇编核对 |

### CoreMark 跑分口径（必须先钉死，否则所有 A/B 都不可比）
- 官方用 `-DITERATIONS=<n>`（或 `core_portme.mak` 的 `ITERATIONS`）控制迭代次数，`-DPERFORMANCE_RUN=1` 走性能口径、`-DVALIDATION_RUN` 走校验口径；性能口径用固定种子（CoreMark 1.0 常见为 `0,0,0x66`，**我未能逐字核对官方源码，标注未核实**）。[[eembc/coremark](https://github.com/eembc/coremark)]
- 因此**200 迭代的自定义跑分不是官方成绩**，只能做本项目内部 A/B。建议同时报 `CoreMark/MHz = 1e6 / (ticks_per_iteration × MHz_factor)` 归一化值；按你现有数据：326,735,694 ticks / 200 迭代 / 27 MHz ≈ **0.61 CoreMark/MHz**——这个数字可以直接拿去和公开软核对照（例如 TORVS 报 1.176–1.600 CoreMark/MHz，[SBESC 2025](https://sol.sbc.org.br/index.php/sbesc/article/view/40351)）。
- 官方要求**每次测量前重新编译并重新验证**（`-DVALIDATION_RUN` 输出必须匹配期望 CRC）。CI 里把 validation run 作为 gate 是防"优化把算法算错还跑得快"的唯一有效手段。

---

## Top 5 落地方案

### T1. 取指解耦：IFU 加指令队列 + 提前发下一拍请求
**改哪里**：`01_code/pangoriscv_axi4/rtl/core/ifu_axi.v`（72 行，主改动）；`rtl/core/if_id.v` 的握手条件可能要放松；`rtl/perips/perf_regs.v` 的 `if_wait` tap 保持不变以便对照。

**怎么改**（三段）：
1. **拆掉"一发一等"**：把 `EMPTY/WAIT_DATA/HOLD` 语义改为 `IDLE/REQ/WAIT/FILL`，允许 `eng_req_valid` 在当前请求被接受后**立即**再次拉高（不再要求 `idle`）；`eng_req_ready` 到 `eng_rsp_valid` 之间用一个小 `pending` 计数跟踪在途请求数（I-Cache 当前 `req_ready = state==IC_IDLE`，所以实际在途 ≤1，这对第一版够用；若 #3 一起做则可 >1）。
2. **加 4~8 项指令 FIFO**：`fetch_valid/result_*` 由 FIFO 非空驱动，而不是由状态机 `HOLD` 驱动。`fetch_ready` 变成 FIFO 的 pop 信号。
3. **重定向只 flush，不丢弃在途响应**：现在 `if(redirect_valid && state!=EMPTY) stale_q<=1;` 会让在途响应白跑。改成：redirect 只清 FIFO 并切 `fetch_pc`，在途响应回来时**如果地址已过期就丢弃数据但不回 IDLE**（继续发新请求）。这正是文献里"取指与重定向解耦"的最小形态 [[Skadron et al., ISCA 2002](https://ieeexplore.ieee.org/document/809439/)]。

**为什么能提分**：当前每条指令取指占用 ≥3 拍（EMPTY→WAIT_DATA→HOLD），I-Cache 命中再加 2 拍，`if_wait=80,962 / cycle=123,535`（65.5%）就是它的直接证据。解耦后稳态下 I-Cache 命中延迟被 FIFO 深度掩盖，`if_wait` 应大幅下降。按 IPC 0.187 → 0.24~0.26 估，**分数 +25~40%**。

**风险**：(a) FIFO 与 `enable`/halt 的门控——halt 时不能继续预取；(b) `EXEC_BASE/EXEC_BYTES` 边界与 `local_fault` 路径必须逐条复核，fault 指令也要按序进 FIFO；(c) redirect 与 FIFO 满的交互要穷举。

**怎么验证**：
- `sim/tb/unit/tb_ifu_axi.sv` + `sim/run_ifu_engine_tests.py`：新增"连续 4 条指令背靠背、无流水线气泡"断言（`if_wait` 在稳态 N 拍内 =0）。
- `sim/run_pipeline_tests.py` + `sim/test_all_isa.py`（ISA E2E 15 项）：FIFO 不得改变任何架构可见结果；fault/重定向用例要新增。
- `tb/integration/tb_coremark_uart.sv` A/B 跑核心：读 `perf_regs` 的 `IF_WAIT`/`CYCLE`/`INSTRET`，要求 `IF_WAIT` 绝对值下降 ≥40% 且 `INSTRET` 不变。
- 板上：CLI 烧录 + UART 采 CoreMark 200 迭代 ticks，与 326,735,694 对比。

---

### T2. BTB 32→128 项 + 8 项 RAS
**改哪里**：`rtl/core/branch_predictor.v`（98 行）。

**怎么改**：
1. `ENTRIES` 参数 32→128（`IDX_BITS` 5→7，`TAG_BITS` 25→23 自动跟随）；索引改成 `PC[8:2]`（保持按 4 B 对齐），**顺带消掉现在 `PC[6:2]` 索引在 CoreMark 小函数密集时的整行冲突**。
2. 加 **8 项 RAS**：`JAL/JALR` 且 `rd == x1/x5` 判定为 call，push `pc+4`；`JALR` 且 `rs1 == x1/x5` 且 `rd != x1/x5` 判定为 return，pop 作为 `predict_target`。返回地址栈在软核上的成本约 8×(32+1) FF。
3. 保留 `train_valid = retire_fire` 的训练语义不动（这是现有"预测开关不影响架构结果"等价性的基础，见 `branch_predictor.v:15-22` 注释）。

**为什么能提分**：错预测率 15.83%、代价 4.10 cycles/miss。32 项直接映射对 CoreMark 的 `core_list_join`/`core_state_transition` 明显偏小；而**没有 RAS** 意味着每个函数返回都靠 BTB 单表项——CoreMark 里 call/return 密度高。文献侧：软核上 2 位预测器可从 60.96% 降到 7.08% 错预测率 [[FPL 投稿, Southampton](https://eprints.soton.ac.uk/513929/)]，说明"表变大 + 计数变好"在软核上收益显著。**估 +3~6%**。

**风险**：索引位宽变了以后，`tb_branch_predictor.sv` 里所有硬编码索引/tag 位要同步；RAS 需要精确的 push/pop 条件（误判 return 会让预测目标彻底跑偏，比不预测更差，但架构正确性不受影响）。

**怎么验证**：`sim/run_predictor_tests.py`（新增 RAS 溢出/下溢、call-return 配对、预测 vs 不预测架构等价）；`run_pipeline_tests.py`；CoreMark A/B 看 `MISPRED`/`RET_CF` 比值下降。

---

### T3. I-Cache 命中路径流水化 + way prediction
**改哪里**：`rtl/core/icache_axi.v`（220 行）。

**怎么改**：
1. **命中去掉一拍**：现在 `IC_IDLE`（比较 tag）→ `IC_HITRD`（读 BRAM）→ `IC_RESP`。把数据 BRAM 索引改成"用 `req_addr` 直接读、不等 tag 比较结果"，即 `req_valid` 当拍就发起数据读，`IC_HITRD` 只做选路。若 BRAM 读延迟固定 1 拍，命中延迟可压到 2 拍。
2. **加 1 位 way 预测表**（32 项，索引 = set）：预测上次命中的 way，先按预测 way 读数据，tag 比较失败再回退读另一路。这需要数据读与 tag 比较**并行**，代价是回退路径一拍。参考商用实现思路 [[US11048637](https://patentimages.storage.googleapis.com/9f/76/98/1da3981eee5274/US11048637.pdf)]。
3. **保持 fill 语义不变**：`IC_AR/IC_FILL/IC_MISS_RD` 与 `fill_kill` 逻辑不动，避免破坏已验证的"线在全部 8 拍 OKAY 后才有效"契约（`icache_axi.v:14-18` 注释）。

**为什么能提分**：与 T1 叠加——T1 让请求能连续发，T3 让每个请求更快返回。命中延迟从 2~4 拍降到 1~2 拍，直接抬高 IPC 上限。按每条指令省 1~2 拍估，**+15~30%（与 T1 部分重叠）**。

**风险**：命中组合路径变长（`req_addr` → BRAM → 选路 → IFU），27 MHz 下应无问题但需重跑 PDS 时序并记录 WNS；way 预测错误时必须**无副作用地**回退（不能污染 LRU）；`invalidate` 落在预测窗口内要正确处理。

**怎么验证**：`sim/run_icache_tests.py` + `tb/unit/tb_icache_axi.sv`（新增 way-prediction 命中/回退/与 invalidate 并发用例）；`run_ifu_engine_tests.py` 保证 IFU-Cache 握手协议不破；板上看 `I_MISS`（必须不变）与 `CYCLE`（必须下降）。

---

### T4. I-Cache next-line 顺序预取（含可执行区边界保护）
**改哪里**：`rtl/core/icache_axi.v`（加一个 `PF_*` 子状态与 1 位 `pf_pending`）。

**怎么改**：在一次 fill 成功后（`state==IC_MISS_RD` 出口），若 `line_addr + 32` 仍落在 `[EXEC_BASE, EXEC_BASE+EXEC_BYTES)` 内，则挂一个待处理预取，在 `IC_IDLE` 空闲时发起 `ARLEN=7` 读下一行、填进预期受害 way（用 `lru_mem` 选 way，但**不更新 LRU、不交付响应**）。预取命中已有的 8 拍 INCR 机制，`m_arlen` 保持 `8'd7`。

**落地前先量**：把 `i_miss=48` 的绝对数放到整跑（200 迭代）尺度上重新读一遍。48 次是探针样本（`cycle=123,535`），如果整跑 I miss 也只有几百次，那 T4 的收益主要来自"把 8 拍突发藏起来"而不是"少 miss"，此时 T4 的优先级应排在 T3 之后。

**为什么能提分**：CoreMark 的 `core_list_join` 是长顺序遍历，next-line 预取对这种模式几乎全命中；Jouppi 的 prefetch buffer 正是为这类顺序流设计 [[ISCA 1990](https://dl.acm.org/doi/abs/10.1145/325164.325162)]，Berkeley 讲义引用的同族配置收益曲线在 1.23×~1.32× 量级（**二手引用，未核实**）。**估 +3~8%**。

**风险**：(a) **必须**做可执行区边界与 MMIO 检查，否则会向非存储区发读 → interconnect 报错甚至挂死；(b) 与 `invalidate`（halt/下载后由 SoC 驱动，见 `icache_axi.v:21-23`）竞争——预取在途时 invalidate 必须 kill 掉它，否则会"复活旧代码"；(c) 预取占用的 AR 通道会与 demand miss 抢带宽，需要"demand 优先"。

**怎么验证**：`tb/unit/tb_icache_axi.sv` 新增"预取不发往 MMIO/越界"断言（这是回归的第一优先级）；`tb/integration/tb_halt_reset_drain.sv` 扩展预取在途 + invalidate 用例；perf 侧新增 `I_AR_LEN7` 对比（预取会使它上升而 `CYCLE` 下降，这是"预取真的在藏延迟"的证据）。

---

### T5. Store buffer + 写合并（带 MMIO 强序旁路）
**改哪里**：`rtl/core/lsu_axi.v`（97 行）+ `rtl/core/dcache_axi.v` 的写通道（393 行里的写路径）。

**怎么改**：
1. 在 `lsu_axi.v` 的 store 路径上加 4~8 项 FIFO：`REQUEST` 后 store 直接 `COMPLETE`（不再进 `WRITE_WAIT` 等 B），FIFO 项在后台由 AXI 写通道 drain。
2. **写合并**：相邻、同 4 KB 页、地址连续的 store 合并为一次 `AWLEN>0` 的 INCR 突发（现在是 `eng_req_len=0` 的单拍写，见 `lsu_axi.v:40`）。AXI 协议允许 AW 提前发出、B 乱序返回 [[AMBA AXI IHI 0022](https://documentation-service.arm.com/documentation/ihi0022/l?lang=en&rev=0)]，这是 store buffer 能成立的前提。
3. **MMIO 强序旁路**：`dcache_axi.v` 已有 `CACHED_LIMIT` 旁路（注释 `MMIO / non-cacheable space (addr >= CACHED_LIMIT) bypasses the arrays`）。旁路区必须**先 drain FIFO 再单拍发**。
4. **Fault 语义**：store 的 B 响应错误不能再在 `COMPLETE` 同步报告。要么在 FIFO 项上带 fault 并在下一次访存/CSR 读取时报告，要么（更保守）对旁路区的 store 保持同步等待。

**为什么能提分**：现在每条 store ≥4 拍（REQUEST→WRITE_DATA→WRITE_WAIT→COMPLETE，还要加 B 往返）且 LSU 全程 `idle=0`，流水线在 EX 阶段被钉住。`lsu_wait=5,963` 只占 4.8%，但那是"等待"计数，实际气泡还包括握手本身。经典 store buffer 就是为解耦这件事存在的 [Hennessy & Patterson, *CA:AQA*]。**估 +4~8%**。

**风险**：高——(a) halt/reset 必须 drain 所有在途写，否则最后一次 store 会丢（`tb_halt_reset_drain.sv` 是现成的扩展点）；(b) MMIO 顺序语义必须保持，UART/GPIO 的写时序不能变；(c) `perf_regs` 的 `D_AW`/`D_W_BEAT`/`D_B` 三个计数的语义会变（写合并后一次 AW 覆盖多个 store），改完后**旧基线数据不可直接对比**，需要在 `04_change_notes` 里显式记录口径变更。

**怎么验证**：`sim/run_dcache_tests.py` + `tb/unit/tb_lsu_axi.sv` + `tb/axi/tb_lsu_axi_ram.sv`（新增：合并正确性——合并后的字节内容逐字节比对；乱序 B；旁路区强序）；`run_halt_reset_tests.py`（drain 用例）；ISA E2E 15 项全过；最后 CoreMark A/B，并**同时比对 UART 输出的 validation CRC**。

---

## 参考文献

> 标注约定：**[已核实]** = 我在本次调研中实际打开过该 URL 并读到相关内容；**[检索命中]** = 在搜索结果中确认条目存在（作者/标题/会议），但正文未能打开（PDF 或反爬）；**[未核实]** = 信息来自二手引用或我无法确认的片段，**不应作为准确数字的来源**。

### Cache / 访存
1. **[已核实]** D. Million, N. Oliete-Escuín, C. Fuguet, "Breaking the Memory Wall with a Flexible Open-Source L1 Data-Cache," *DATE 2024*. DOI [10.23919/DATE58400.2024.10546547](https://dx.doi.org/10.23919/DATE58400.2024.10546547) · [HAL 记录页](https://hal.science/hal-04600058v1)。**摘要原文**："The lack of concurrency and pipelining in the memory sub-system of recent open-source RISC-V processors, such as the CVA6, is increasingly becoming the performance bottleneck. Recent updates to the new RISC-V High Performance L1 Data-cache (HPDcache), now fully integrated with the CVA6, bring significant (up to +234%) speedups in key benchmarks with a negligible 5.92% area impact."
2. **[检索命中]** N. P. Jouppi, "Improving direct-mapped cache performance by the addition of a small fully-associative cache and prefetch buffers," *ISCA 1990*, pp. 364–373. [ACM DL](https://dl.acm.org/doi/abs/10.1145/325164.325162)（另见 [SIGARCH CAN 版](https://dl.acm.org/doi/abs/10.1145/325096.325162)）。victim cache + stream buffer/prefetch buffer 的原始出处。
3. **[未核实]** Jouppi 1990 的具体收益数字（16 B 配置下 1.23×/1.32× 之类的曲线）来自二手讲义：[J. Kubiatowicz, CS152 Spring 2004, lec20-cache.pdf, UC Berkeley](https://people.eecs.berkeley.edu/~kubitron/courses/cs152-S04/lectures/lec20-cache.pdf)（检索片段显示表格含 `| 16 | 1.23 | 1.32 | 1.32 | 1.32 |`）。**引用该数字时必须注明是二手引用。**
4. **[检索命中]** D. Kroft, "Lockup-free instruction fetch/prefetch cache organization," *ISCA 1981*, pp. 81–87. [ACM DL](https://dl.acm.org/doi/abs/10.5555/800052.801868) · [Semantic Scholar](https://www.semanticscholar.org/paper/Lockup-free-instruction-fetch-prefetch-cache-Kroft/6ed152e43e15d69f63e2ea5d16e719ff81572c85) · [ETH Safari 镜像 PDF](https://safari.ethz.ch/architecture/fall2019/lib/exe/fetch.php?media=p81-kroft.pdf)。非阻塞 Cache / MSHR 的开山之作。
5. **[检索命中]** "Instruction buffering exploration for low energy embedded processors," *Journal of Embedded Computing*. [ACM DL](https://dl.acm.org/doi/abs/10.5555/1233748.1233753)。loop buffer / 指令缓冲的系统性探索（报告指标以能耗为主）。
6. **[检索命中]** "Reducing Power and Energy Overhead in Instruction Prefetching for Embedded Processor Systems," IGI Global 书章, ISBN 9781466627857. [样例页](https://www.igi-global.com/viewtitlesample.aspx?id=73220&ptid=69828)（抓取被 429 拦截，仅确认条目存在）。

### 取指 / 分支预测
7. **[检索命中]** G. Skadron, P. Ahuja, M. Martonosi, "Instruction Fetching: A Case for Fetch-Directed Prefetching," *ISCA 2002*. [IEEE Xplore 809439](https://ieeexplore.ieee.org/document/809439/)。取指解耦 + 预测流驱动预取的核心论点。
8. **[检索命中]** "Continual Flow Pipelines," *ASPLOS 2004*. [ACM DL](https://dl.acm.org/doi/epdf/10.1145/1024393.1024407) · [UW 镜像 PDF](https://uwaterloo.ca/scholar/sites/ca.scholar/files/z399huan/files/continual_flow_pipelines.pdf)。窄发射核中"长延迟操作阻塞后续指令"的资源高效解决思路。
9. **[已核实]** A. Seznec, P. Michaud, "A case for (partially) tagged geometric history length branch prediction," *The Journal of Instruction-Level Parallelism*, vol. 8, 2006. [HAL 记录页](https://inria.hal.science/hal-03408381v1)。**摘要原文含**："at equivalent storage budgets, the TAGE predictor significantly outperforms all the predictors that were presented at the Championship Branch Prediction in december 2004"。**注意：原文没有给出单一加速百分比。**
10. **[检索命中]** A. Seznec, "TAGE-SC-L Branch Predictors," CBP-2016 描述文档。 [ETH Safari 镜像 PDF](https://safari.ethz.ch/digitaltechnik/spring2023/lib/exe/fetch.php?media=tage-sc-l2014seznec.pdf)（PDF 未能解析为文本）。
11. **[检索命中/部分未核实]** "Exploration of High-Performance Branch Predictors for Softcore Implementations," FPL 投稿（Southampton ePrints [513929](https://eprints.soton.ac.uk/513929/)）。检索片段称 "2-bit predictor reduces the misprediction rate from **60.96% to 7.08%**, an **88.4%** improvement, with only a **3.x%** area overhead"——百分比数字来自搜索片段，**工艺/核型未能核实**；页面本身有反爬（Anubis PoW）。
12. **[检索命中]** "Skia: Exposing Shadow Branches," *ASPLOS 2025*. [Princeton 镜像 PDF](http://liberty.cs.princeton.edu/Publications/asplos25_skia.pdf)。用于说明"分支解析前取指浪费"仍是活跃研究方向（非本设计直接可用）。

### 结构 / 微架构
13. **[已核实]** L. A. Mendes, M. Figueiredo, R. Menotti, "TORVS: A Lightweight Dual-Issue Superscalar RISC-V Core for FPGA-Based Systems," *SBESC 2025*, pp. 127–132. [SBC OpenLib 摘要页](https://sol.sbc.org.br/index.php/sbesc/article/view/40351) · [IEEE Xplore 11288856](https://ieeexplore.ieee.org/document/11288856)。**摘要原文**：RV32I 五级双流水，参数化于 (i) 分支预测器选择 (ii) 可派发到第二条流水线的指令子集；CoreMark **1.176–1.600 CoreMark/MHz**，Dhrystone 1.708–2.331 DMIPS/MHz；结论"轻量设计在基础操作上有竞争力，复杂负载下效率下降"。
14. **[检索命中]** "Exploring Writeback Designs for Efficiently Leveraging Parallel-Execution Units in FPGA-Based Soft-Processors," *FCCM 2020*（DOI 10.1109/FCCM.2018.00010 相关条目见 [IEEE 9114632](https://ieeexplore.ieee.org/document/9114632)）。FPGA 软处理器并行执行单元 / 写回设计。
15. **[未核实]** "Efficient Implementations of Multi-pumped Multi-port Register Files in FPGAs," *DSD 2013*, DOI [10.1109/DSD.2013.28](https://doi.org/10.1109/DSD.2013.28)。检索命中条目，细节未核实。
16. **[未核实]** "Study of Interlock Collapsing ALUs for RISC-V Microprocessors," TU Delft 学位论文. [TU Delft Repository](https://repository.tudelft.nl/file/File_5494a8b8-c690-4e80-a089-6069cfc3ebbb?preview=1)（PDF 无法解析，仅确认条目存在）。

### 协议 / FPGA 工具 / 基准口径
17. **[检索命中]** Arm, *AMBA AXI Protocol Specification*, IHI 0022（最新修订版 L）. [documentation-service.arm.com](https://documentation-service.arm.com/documentation/ihi0022/l?lang=en&rev=0)。AW 可早于 W 发出、B 响应可乱序返回——store buffer 的协议基础。
18. **[检索命中]** AMD/Xilinx, *Vivado Design Methodology*, UG949. [PDF 镜像](https://china.xilinx.com/content/dam/xilinx/support/documents/sw_manuals/xilinx2017_2/ug949-vivado-design-methodology.pdf)；*Vivado Synthesis*, UG901. [PDF 镜像](http://www.ecs.csun.edu/~smirzaei/docs/ece524/ug901-vivado-synthesis-en-us-2025.1.pdf)。时序收敛与方法论。
19. **[未核实]** Pango（紫光同创）PDS 综合/时序指南与 Logos2 PG2L100H 器件手册——**本次调研未取得可引用的官方链接**，频率提升方案必须由你们自己的 PDS 报告（WNS/TNS）作依据。
20. **[已核实（条目）/未核实（正文）]** EEMBC, *CoreMark* 官方仓库与说明. [github.com/eembc/coremark](https://github.com/eembc/coremark)。`ITERATIONS` / `PERFORMANCE_RUN` / `VALIDATION_RUN` 口径的权威出处；`raw.githubusercontent.com` 在本环境超时，**正文未能逐字核对**；官方 Run Rules 旧链接 <http://www.eembc.org/coremark/CoreMarkRunRules.pdf> **已 404**。
21. **[已核实]** J. Bennett, "How good is RISC-V: Comparing benchmark results," *FOSDEM 2025, RISC-V devroom*. [日程页](https://archive.fosdem.org/2025/schedule/event/fosdem-2025-5678-how-good-is-risc-v-comparing-benchmark-results/)。讲"不同扩展与编译器对编译代码性能的影响"，并以 OpenHW CV32E40Pv2 为例给出"用 ML 辅助调优在 **24 小时内改善代码密度 7%**"的实测。
22. **[检索命中]** Embench 相关论文与文档（Embench 0.5 / Embench IoT 2.0）。示例：[CARRV 2020 paper 12 (Perotti et al.)](https://www.research-collection.ethz.ch/bitstream/handle/20.500.11850/461404/CARRV2020_paper_12_Perotti.pdf?sequence=1&isAllowed=y)。

---

## 我只能说"无公开数据 / 未核实"的部分（请勿当作结论引用）

- **CoreMark `-O2`→`-O3` / `-flto` / `-funroll-loops` 的具体百分比**：本次调研**没有找到可核实的权威数字**（EEMBC 官方 Run Rules PDF 已下线，`eembc/coremark` 正文抓取超时）。这一项必须**本地 A/B 实测**，而且它的性价比（零 RTL 风险）决定了它应该排在所有 RTL 改动之前。
- **本项目规模（2 KB I-Cache / 单发射 / 32 项 BTB）下各技术的公开加速数据**：几乎没有。上面标 ★ 的数字都是我基于 `ifu_axi.v`/`icache_axi.v`/`lsu_axi.v` 源码事实（取指 3 拍、命中 2~4 拍、store 等 B）做的推断，**不是文献结论**。落地必须按 A/B 实测校准。
- **27 MHz → 更高频率的可行性**：完全取决于你们 PDS 的 WNS 报告，我没有可引用的 Pango 官方时序文档。
- **Victim cache 的具体 miss 降低百分比**：Jouppi 原文数字我只能通过二手讲义引用，未直接在原文核实。

## 建议的执行顺序（含口径纪律）

1. **先做 T0（软件/口径）**：#17+#18 的编译矩阵 A/B，同时把 `PERFORMANCE_RUN` / 迭代数 / 种子 / 归一化 `CoreMark/MHz` 写进 `04_change_notes`，并加一个 `-DVALIDATION_RUN` 的 CI gate。零 RTL 风险，且之后的硬件改动都在同一个可比口径上评估。
2. **T1 → T2 → T3**：都只碰单文件（`ifu_axi.v` / `branch_predictor.v` / `icache_axi.v`），彼此独立可分别 A/B。按现有计数器（`IF_WAIT`、`MISPRED`、`CYCLE`、`INSTRET`）就能判定每步是否真的赚了。
3. **T4 / T5**：先看 T1~T3 之后 `i_miss`/`lsu_wait` 的占比是否已经小到不值得动。T5 会改变 perf 计数口径，动手前先在 `04_change_notes` 冻结旧基线。
4. **#12 双发射 与 #8 TAGE**：不建议本轮做。等 T1~T5 把 IPC 从 0.187 推到 0.3 以上后，再重新评估哪一项变成新的主要瓶颈。
