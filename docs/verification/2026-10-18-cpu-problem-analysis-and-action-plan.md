# CPU 现状、风险与下一阶段行动方案

日期：2026-10-18  
用途：供队长安排竞赛开发与验收任务。  
边界：本轮只检查源码、历史原始日志和报告，检索一手参考资料；没有修改 RTL、重新仿真、运行 PDS、烧录或合并。

## 1. 给队长的结论

这是一个已经有板级运行证据、性能优化确有收益的 RV32 CPU 工程，不是只有演示视频的空壳。
但“能运行 CoreMark”“CPU 完整正确”“比赛任务全部完成”是三个不同结论。

目前应把最新版本称为：

> T4 前端优化 + LSU 控制气泡优化的实验候选版；已具有板测性能证据，但正式计分、case 7 归因及交付复现尚未闭环。

优先顺序：

1. 查清 case 7：区分测试时序假设错误与真实 CSR 硬件缺陷。
2. 核对优化后内部请求/写数据握手契约，补背压、异常和独立到达测试。
3. 使用足够迭代次数补齐两套种子的有效 CoreMark，冻结可信候选。
4. 测量最终候选的新瓶颈、补 ILA，再选择下一个单点优化。
5. 并行整理高阶任务完成矩阵，避免无限追分挤占中断、应用和材料时间。

不建议现在直接引入提前退休的写缓冲或整体替换 Cache。

## 2. DeepSeek 实际做了什么、效果有多大

### 2.1 三个版本必须分开

下表来自工程中保存的板级 UART、PDS 报告及实验记录，不代表本轮重新实测。

| 项目 | B0 基线 | T4 前端候选 | T4 + LSU 候选 |
|---|---:|---:|---:|
| 400 次迭代 ticks | 320,725,708 | 279,957,350 | 226,427,447 |
| 按 27 MHz 换算时间 | 11.8787 s | 10.3688 s | 8.3862 s |
| 400×10^6/ticks | 1.247172 | 1.428789 | 1.766570 |
| 相对 B0 吞吐提升 | — | 14.56% | 41.65% |
| LUT | 12,441 | 12,406 | 12,510 |
| 正式成绩时间条件 | 满足 | 满足 | **不满足** |

第三版相对 T4 的增量收益是吞吐约 +23.64%、周期约 -19.12%，不是额外再提升 41.65%。
第三版比 T4 增加 104 LUT；比 B0 增加 69 LUT。比较资源时必须注明参照版本。

### 2.2 两轮机制不是同一件事

T4：

- I-Cache 在交付旧响应的同拍接收下一请求。
- IFU 同拍收旧响应、发新请求。
- 仍然是单槽替换，不是增加多笔在途。
- ALU 微程序约 2.02 → 1.01 拍/条，指向前端吞吐改善。

LSU：

- 接受访存指令时直接发内部请求，store 数据可同拍送入。
- 去掉部分请求寄存和 WR_PREP 空转。
- B 响应同拍向上传递，减少控制等待。
- store 仍等待 B 成功，不是提前退休，也不是写缓冲。
- 诊断记录中 load 约 3.000 → 2.049 拍/笔、store 约 11.15 → 6.163 拍/笔。

这些是有价值的控制路径优化；并不需要为了显得“高级”而改写成某种论文架构。

## 3. P0：case 7 尚未闭环，但原报告归因有明显问题

### 3.1 已确认的事实

宏全开时，候选 ISA E2E 为 14/15；case 7 报 `x2=0 want 1`。
因此不能宣称“候选配置所有回归全过”，更不能用 CoreMark CRC 替代 ISA 验收。

但 `phase1_test_acceptance.md` §6.3 的解释与实际代码不一致：

- 报告称 CSR 在 ID 级读取，且测试写的是 mcycleh。
- 当前 `pangoriscv.v:141` 的 CSR 地址来自 EX 指令 `ei[31:20]`。
- `pangoriscv.v:124` 的 CSR 写回值直接使用 `csr_old`。
- `pangoriscv.v:169` 的 ID 级 CSR 输入接的是 `32'd0`。
- 实际测试写的是 **mcycle 低半 0xb00**，紧接着读高半 0xb80。

因此，“已经证明 ID 级 CSR RAW 冒险，应加入旁路”的结论不能成立。
之前任何沿用该解释、把 G1 定为已证实硬件缺陷的判断，都应撤回到“根因待确认”。

### 3.2 更值得验证的假设：测试依赖了旧版气泡

实际序列：

```asm
li    x1, -1
csrw  0xb00, x1
csrrs x2, 0xb80, x0
```

测试器硬编码要求 x2 等于 1。
但写低半为 FFFFFFFF 后，紧接的高半读取是否已经跨过一次计数边沿，不能仅由汇编相邻关系保证。

当前 RTL 先计算 mcycle+1，再用显式写覆盖对应半部。
在连续执行情形下，一种与代码吻合的逐拍可能性是：

| 时刻 | 行为 |
|---|---|
| 边沿 k | 写低半提交，计数器成为 00000000_FFFFFFFF |
| k 至 k+1 | 下一条 CSR 读取当前高半 0 |
| 边沿 k+1 | 该读指令写回 0，同时计数器自然进位到高半 1 |

这是**静态分析假设，不是已经取得波形的最终归因**。
官方 CSR 规范强调顺序访问、读取指令执行前的状态；机器计数器规范说明写在写指令完成后生效。
不能通过无条件插入气泡或把读值改成 next-state 来强行满足旧测试。

### 3.3 诊断步骤与条件性修法

1. 最小程序只保留初始化、写低半、读高半和终止；分别跑 B0、T4、LSU。
2. 记录每拍 PC、EX 指令、retire_fire、CSR 地址、commit、write_data、mcycle、csr_old、寄存器写回。
3. 建立按周期更新的计数器参考模型；明确写覆盖、自然递增和读取采样位置。
4. 用不自动递增的 mscratch 做背靠背 CSRRW/CSRRS/CSRRC，区分普通 CSR 数据冒险与计数器进位问题。
5. 单独补 minstret：写覆盖、退休增加、trap 不退休等；不能认为当前 case 7 已覆盖这些。

若普通 CSR 的下一条读取看不到已提交的写，才检查执行/提交通路并设计前递或停顿。
若普通 CSR 正确、仅硬编码进位预期错误，应修测试模型和报告，不应降低 CPU 吞吐。
测试可使用明确经过足够周期后再检查进位的序列，但必须另外保留无间隔访问的正确性测试。
若支持 mcountinhibit，可利用禁止计数构造确定性读写测试；不支持时不能假定存在。

验收：根因有逐拍证据；不得删除 case 7 或放宽为任意值；最终交付宏配置全套通过。

## 4. P1：内部握手契约需要补证据

### 4.1 一个具体的静态风险

候选 `axi_data_engine.v:100` 在 WR_IDLE 或 WR_PREP 拉高内部 `w_ready`。
但 WR_IDLE 对 W 的捕获位于 `req_valid && req_ready && req_write` 分支内。

如果上游允许 W 比内部写请求先到，可能出现 `w_valid && w_ready` 已成立，却没有保存数据。
dcache 对该 ready 的转接也需要一起核对。

当前集成 LSU 通常请求和数据同拍发射，可能不触发上述情形。
所以这是**内部接口契约风险**，不能直接说成已发现板级数据损坏或外部 AXI 协议违规。

### 4.2 两种修法，选择一种并写清契约

- 原子请求契约：明确内部 store 请求与数据必须同拍接收，ready 只在实际可捕获时成立；检查 valid/ready 依赖不会死锁。
- 独立数据契约：加入一项数据保持寄存器，W 先到也能保存，并与后续请求唯一配对。

不要只改 ready 表达式就结束：当前 LSU 的 launch 依赖 ready，必须检查整个组合依赖关系。
外部 AXI 的 AW/W 是独立通道，不能把内部原子契约误写为“AXI 规定 W 必须晚于 AW”。

### 4.3 必测项目

| 情形 | 检查 |
|---|---|
| 请求先到、W 先到、同时到 | 仅在真实捕获时握手，不丢不重 |
| W 只脉冲一拍、W 延迟多拍 | 已握手数据必须保留 |
| AWREADY/WREADY 独立随机背压 | payload 稳定，每项只接收一次 |
| B 延迟、B 背压、SLVERR/DECERR | 不提前成功退休；错误地址/PC 正确 |
| load/store 混排、MMIO、部分字节写 | 顺序、掩码、Cache 合并/失效正确 |
| halt/reset 到来时尚有事务 | 按系统复位契约排空，不孤立 R/B |

已有 AXI 测试通过是积极证据，但新契约仍需要对应的新定向用例。

## 5. P1：正式跑分必须补，不能把错误提示忽略

保存的 `lsu_opt/board/cand_run1.txt`、`cand_run2.txt` 都含：

```text
ERROR! Must execute for at least 10 secs for a valid result!
Errors detected
```

因此 1.766570 目前只能称实验归一化吞吐。
CRC 一致支持该负载计算结果一致，不代表完整 ISA 正确或正式 CoreMark 合格。

执行方案：

1. 在正确性问题归因闭环后，B0/T4/最终候选使用相同的新 performance 镜像，建议 600 或 800 次迭代。
2. 单独构建 validation 种子镜像：0x3415、0x3415、0x66；performance 为 0、0、0x66。
3. 总数据区 2000 字节，固定工具链、编译参数、链接布局、频率、宏及观测配置。
4. 保存 ELF、program.hex、data.hex、源清单、位流及 SHA256；先开串口，再下载。
5. 每配置至少两次完整采集；保存原始文本，不只截成功行。
6. 确认时长达标、种子/数据规模正确、算法校验正确，且不存在错误提示。

计分公式：

```text
CoreMark/MHz = iterations * 1,000,000 / ticks
CoreMark     = iterations * actual_clock_hz / ticks
CoreMark/LUT = CoreMark / LUT_count
```

不要使用打印后截断的整数秒计算成绩。
更改迭代次数后 crcfinal 可能变化，不能强求与旧 400 次镜像逐项相同；按新参数的官方参考值验证。
同参数 A/B 的 CRC 则应一致。

## 6. P1：交付复现、时序与 ILA

### 6.1 可复现性

生产树 `firmware/code` 与实验树不是同一版本；不能把实验性能直接贴到生产发布包。
本轮检查 `git ls-files .../lsu_opt/src` 只有 5 个跟踪文件，完整目录主要依靠上游版本加差量重建。
这不等于实现丢失，但部分 build.tcl、分析脚本和 diff 仍是未跟踪文件，换机器复现存在缺口。

应提交一个重建入口，明确：

- 精确基础提交 + T4 + LSU 补丁，不依赖某个本地临时目录。
- 宏配置、源列表、编译参数、内存初始化文件、PDS 工作目录。
- hold 修复参数、随机种子、完整时钟约束、所用工具版本。
- 从源码到镜像再到位流、UART 的哈希关联。

必须从干净目录重建一次，再决定合并；不要把整个临时 work 库入库。

### 6.2 时序结论的边界

第三版保存的结果为 All Constraints Met，慢角 setup +16.922 ns、hold +0.106 ns。
约 49.71 MHz 是工具估算，不是 CPU 已经在该频率板测通过。

保留已通过的 27 MHz 基准；以后若升频，必须有真实时钟/PLL配置、对应约束、重新实现和板测。
不得仅修改 CPU_FREQ_MHZ 来声称升频。
约束检查需包含生成时钟、未约束端点、CDC 和外设输入同步；“无违规”不自动等于“约束完整”。

### 6.3 ILA 是赛题交付项

赛题要求在 CoreMark 关键算法区间抓 ILA 分析流水线，不是任意 LED/UART 波形。
建议抓取 PC、retire、redirect、队列占用、Cache 命中/缺失、LSU 状态、AR/R/AW/W/B 握手。
触发使用算法入口/退出标记；避免仅抓启动与串口输出。
ILA 会改变资源和布局，带 ILA 版必须重新跑后端，成绩对比必须统一观测配置或明确分开。

## 7. 下一轮性能研究：先诊断后选题

第三版已经改变前端和 LSU，不可继续把旧版“49% 访存停顿”当作最新瓶颈。

对最终候选重新测：

- CoreMark 算法区间总 cycles、retired、load/store 阻塞、前端等待；互斥分类总和用硬断言校验。
- I/D 命中率、miss 次数与总代价，突发长度、有效 beat/总线周期。
- AW、W、B 各自延迟，仲裁等待及 I/D 相互阻塞。
- 分支预测准确率、redirect 次数、恢复延迟分布，尤其此前 16 拍长尾。
- PDS 前十关键路径、资源组成及可用时钟，不只看单一 WNS。

按结果只选一个候选：

| 候选 | 何时值得做 | 关键限制 |
|---|---|---|
| AW/W 与从机握手再去气泡 | 写完成仍主要耗在控制空转 | 保持 B 后完成；独立通道背压不可丢 |
| 分支恢复/预测器修正 | 错预测和恢复占比显著 | 区分预测错误、重定向和 Cache miss 长尾 |
| Cache 容量/路数/替换参数 | miss 代价确为主要来源 | CoreMark 命中率已高时加容量可能无收益 |
| 仲裁并发优化 | I/D 相互阻塞显著 | 事务 owner、ID、错误响应配对不可破坏 |
| FPGA 关键路径优化/合理升频 | MHz 项与绝对性能受限 | 不保证 CoreMark/MHz 提高；实际时钟板测 |
| 写缓冲/非阻塞 Cache | 等 B 或 miss 阻塞仍占主导 | 必须先解决晚到错误、FENCE、MMIO、顺序和排空 |

每个实验都做独立开关、同镜像 A/B、完整正确性测试、PDS、板测。
不承诺某项一定达到 2 或 3 CoreMark/MHz；收益可能重叠，不能简单相加。

## 8. 论文与开源参考：按问题选，不按刊物名选

以下已经通过官方仓库 README、规范原文或出版页核对。
论文部分只核对出版信息与摘要/仓库介绍，没有宣称完成全文复现。
本轮网页工具未返回可引用内容，改用 HTTP 直接读取一手来源；列明入口以便团队复查。

### A. RISC-V 官方规范：先解决 G1 判断标准

入口：
`https://github.com/riscv/riscv-isa-manual/blob/main/src/unpriv/zicsr.adoc`
`https://github.com/riscv/riscv-isa-manual/blob/main/src/priv/machine.adoc`

读 CSR Access Ordering 和 Machine Counter/Timers。
用于确定读写先后与计数器规则，不是性能优化论文。
采用比赛目标版本建立检查表；不要把最新规范所有可选扩展都强加到当前 CPU。

### B. PULP AXI：当前最直接的工程参考

入口：`https://github.com/pulp-platform/axi`

官方 README 列有：

- axi_cut：切断组合路径。
- axi_fifo：逐通道缓冲。
- axi_mux/axi_xbar：多主仲裁和互联。
- axi_rand_master/slave、axi_scoreboard：随机延迟与事务记分。

适用：参考握手保持、通道解耦和验证方法。
不适用：机械地加 FIFO 就假定降低单笔访存延迟；切寄存可能增加延迟。
SystemVerilog 类型、依赖库和 PDS 兼容性必须评估；复制代码前核对对应文件许可证。

### C. HPDcache：后置写缓冲/非阻塞 Cache 的参考

入口：`https://github.com/openhwgroup/cv-hpdcache`

官方介绍包含多笔在途、写缓冲、地址重叠事务顺序、写穿/写回策略。
两篇已从仓库参考文献核对的信息：

- César Fuguet, “HPDcache: Open-Source High-Performance L1 Data Cache for RISC-V Cores”, Computing Frontiers 2023，DOI `10.1145/3587135.3591413`。
- D. Million, N. Oliete-Escuín, C. Fuguet, “Breaking the Memory Wall with a Flexible Open-Source L1 Data-Cache”, DATE 2024，DOI `10.23919/DATE58400.2024.10546547`。

适用：学习为何需要事务跟踪、写缓冲及重叠地址顺序控制。
限制：成熟 Cache 子系统不等于与本工程接口兼容；不能认为它替我们解决 CPU 精确晚到写异常。
两篇是会议文献，不应包装成“顶刊论文”。仓库注明 Solderpad 2.1，使用前核对文件级声明。

### D. RVCoreP：FPGA 频率与结构优化参考

题名：RVCoreP: An Optimized RISC-V Soft Processor of Five-Stage Pipelining。
作者：Hiromu Miyazaki、Takuto Kanamori、Md Ashraful Islam、Kenji Kise。
出版：IEICE Transactions on Information and Systems，2020-12；DOI `10.1587/transinf.2020PAP0015`。
入口：
`https://www.jstage.jst.go.jp/article/transinf/E103.D/12/E103.D_2020PAP0015/_article`

出版页摘要明确围绕 FPGA RV32I 五级流水，优化取指、ALU、数据存储以提高频率。
适合本队阅读其“IPC × 频率 × 资源”的分析方法。
限制：不是相同流水级数、AXI 系统或 FPGA 平台，论文中的提升百分比不可直接套用。
若要复现，先阅读全文并选取与本工程真实关键路径对应的一个机制。

### E. EEMBC CoreMark：计分与移植的权威来源

入口：`https://github.com/eembc/coremark`

官方 README 明确要求至少 10 秒、两套种子验证、2000 字节数据规模及编译参数披露。
这是本次修订计分流程的直接依据。

## 9. 面向比赛的任务安排与验收门槛

| 阶段 | 工作 | 完成标准 |
|---|---|---|
| A 正确性 | G1 最小复现、波形、参考模型，按根因修测试或 RTL | 最终宏配置全套通过；解释可被独立复核 |
| B 接口安全 | req/W、AW/W、B 错误、背压、reset/halt | 无丢失/重复/假握手；错误仍精确 |
| C 正式成绩 | 600/800 迭代，两套种子，同镜像 A/B | ≥10 s、校验成功、完整 UART、身份链 |
| D 冻结交付 | 干净重建，明确唯一生产入口 | 源码/宏/镜像/位流/报告可关联 |
| E 比赛分析 | 新瓶颈统计 + ILA + 时序资源分析 | 报告每个主张有日志或波形支持 |
| F 高阶发展 | 核对 Cache/突发、预测、中断、AI 应用 | 每项区分已实现、仿真、板测、未做 |
| G 后续优化 | 基于 E 选一个机制 | 正确性不退化，实测收益大于资源/时序代价 |

高阶要求包括两路组相联 I/D Cache、突发传输、动态分支预测、完整异常/中断、AI 加速和传感/显示应用。
文件存在、宏打开或模块单测通过，不足以把上述各项统称完成。
先核对当前实现与板级证据，再确定队员分工；不要让所有人都只追 CoreMark。

## 10. 本轮主要本地依据

所有路径基于 `E:\file\pango\project\`：

- `docs/contest/contest-pages-10-11.txt`：基础、高阶、统一测评、ILA 与 10 秒要求。
- `docs/design/plans/2026-10-09-pangoriscv-native-axi4-contest-plan.md`：计划与验证任务。
- `evidence/records/bottleneck_audit/results/T4_frontend_results.md`：T4 结果。
- `evidence/records/bottleneck_audit/results/phase1_test_acceptance.md`：case 7 失败及待纠正归因。
- `evidence/records/bottleneck_audit/results/phase2_implementation.md`：LSU 改动与后端结果。
- `evidence/records/bottleneck_audit/lsu_opt/board/cand_run1.txt`、`cand_run2.txt`：候选原始串口。
- `evidence/records/bottleneck_audit/lsu_opt/src/rtl/core/pangoriscv.v`：EX CSR 接线。
- `evidence/records/bottleneck_audit/lsu_opt/src/rtl/core/csr_native.v`：计数器更新与显式写。
- `evidence/records/bottleneck_audit/lsu_opt/src/rtl/core/axi_data_engine.v`：内部 W 握手。
- `evidence/records/bottleneck_audit/frontend_opt/src/tests/isa_e2e/isa_e2e.S`：case 7 实际程序。
- `evidence/records/bottleneck_audit/frontend_opt/src/tools/run_isa_e2e.py`：硬编码进位判据。

最终建议：肯定两轮优化的实际收益，但暂缓把第三版直接宣布为最终比赛版本。
先花一个小闭环解决“正确性判据、有效成绩、版本复现”，随后用最新数据决定优化和高阶应用投入。
