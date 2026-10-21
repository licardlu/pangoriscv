# 设计与决策记录

> 本文件由 `docs/design/` 下 9 份文档合并而成（2026-10-18），内容按原样保留，
> 只把小标题降级并加了编号。**署名与来源请先看 §1**：它和根 README/LICENSE
> 的表述有冲突，尚未定案。

## 目录

1. §1 来源与署名（重要）
2. §2 CPU 与存储的契约
3. §3 CSR 与中断
4. §4 总体规划（2026-10-09）
5. §5 优化 roadmap（2026-10-17）
6. §6 CoreMark 优化文献综述
7. §7 实施状态
8. §8 基础版最终实现
9. §9 基础版交接

---

## §1 来源与署名（重要）

*原文件：`docs/design.md`*

### Source Provenance

Recorded: 2026-10-10.

This is a development copy of the locally supplied tinyriscv tree:
`E:/donwload/tinyriscv-master/tinyriscv-master`.
The source tree has no Git history. File timestamps do not establish an upstream
commit, download date, or authorship of subsequent changes.

| Category | Evidence and boundary |
| --- | --- |
| Upstream attribution | Original README, LICENSE and RTL author notices retained. |
| Locally supplied baseline | All 790 files backed up and SHA256 checked before edits. |
| Prior teammate changes | Unknown; requires contributor records or comparison against an identified upstream snapshot. |
| Teammate authorization | User explicitly confirmed teammate consent to modify this supplied tree on 2026-10-10. This authorizes implementation; it does not establish the history of prior edits. |
| Changes in this implementation | Track against Git baseline `6741872` and the implementation status record. |
| Contest reuse permission | Not established by the source license; organizer confirmation pending. |

Baseline file hashes are in `evidence/baseline/original-files.sha256.csv`.
Do not claim that this complete CPU is newly authored by the team.
Do not replace upstream attribution with team attribution.

The original RIB implementation remains available solely for the plan's
baseline tests. Its presence in the preserved baseline does not constitute the
future native-AXI implementation, which has not yet been integrated.

---

## §2 CPU 与存储的契约

*原文件：`docs/design.md`*

### CPU Memory Contract

Plan references: sections 3.5, 8.2, 9, 10.1 and 13.2.
Recorded 2026-10-10. This freezes the intended interfaces before T02;
it does not assert that these interfaces are integrated in the original CPU.
All interfaces share the CPU clock and active-low synchronous reset `rst_n`.
Payloads remain stable while valid is asserted and ready is low.
`fire = valid && ready` at the rising edge. Reset clears occupancy.

## Pipeline identity and retirement

IF/ID owns `valid`, `pc[31:0]`, `inst[31:0]`, `fault`,
`predicted_next_pc[31:0]`. ID/EX preserves these and decoded controls,
operands, `rd[4:0]` and CSR metadata. Stall holds identity and valid.
Flush clears younger valid slots and suppresses their internal handshakes.
An older EX branch may retire during its younger-slot flush.

EX owns one instruction until `ex_leave = retire_fire || trap_fire`.
`retire_fire` occurs once on normal completion; `trap_fire` accepts a
synchronous fault without normal retirement or rd writeback. Register/CSR
updates and branch training are tied to their defined commit event.
Monotonic `retire_order[63:0]` identifies retired instructions; PC is not
a unique identity. Decode samples operands only on entry to ID/EX, with
same-cycle completed EX writeback bypass or an explicit extra stall.

## Instruction operations

The IFU owns PC, redirect, request identity and a reserved result slot.
Its internal fetch request is `req_valid/req_ready`,
`req_pc[31:0]`, `req_predicted_next_pc[31:0]`.
The result is `rsp_valid/rsp_ready`, `rsp_pc[31:0]`, `rsp_inst[31:0]`,
`rsp_fault`, `rsp_predicted_next_pc[31:0]`. Fetch faults retain their
original PC; the trap cause is instruction access fault. Misaligned
targets are rejected before bus issue.

Identity begins at internal req_fire, before AR acceptance. Redirect
marks all younger identities stale, including requests accepted internally
on the redirect edge. An AXI VALID already asserted stays asserted until
handshake. Accepted stale reads drain to completion and are discarded.
Stale results never enter IF/ID or raise a wrong-path trap.
R reception uses the reserved slot independently of EX stalls, releasing
the shared bus before a waiting LSU request needs it.
Fetches to MMIO are rejected locally; no speculative peripheral read.

## Data operations

EX to LSU:

| Port | Width | Meaning |
| --- | --- | --- |
| op_valid / op_ready | 1 each | One operation handshake |
| is_store | 1 | Store versus load |
| address / store_value / pc | 32 each | Effective byte address, unshifted value, instruction PC |
| access_size | 3 | 0 byte, 1 halfword, 2 word; other values rejected |
| load_unsigned | 1 | Zero extension for byte/halfword loads |
| rd | 5 | Destination identity; x0 still performs the access |
| done_valid / done_ready | 1 each | Completion handshake |
| load_value / fault_addr | 32 each | Extended load result and original effective fault address |
| fault | 1 | Access failure; operation identity determines load/store cause |

LSU latches all request fields at op_fire. EX sets its issued bit only
on op_fire and never requests the same operation again while waiting.
done_valid and its payload are held until the corresponding retirement
or trap consumes them. A prechecked misalignment raises the synchronous
trap without issuing a memory request. Halfwords require address bit 0
zero; words require address bits 1:0 zero.

The request is presented from the execute stage itself (P9), so every field
above is combinational in that cycle; the load response is captured into
`ex_value` on the EX/M1 edge, which is what makes a load and an ALU result
equivalent to the bypass network (`docs/lessons/mistakes-log.md` section 36).
Because the issue point is one stage earlier than the commit point, the gate
into `op_valid` must cover *every* signal that can still invalidate the
operation in that same cycle: `kill_all` (trap/MRET at WB), a trap already
visible in M2 or WB,
and a lane-0 control transfer resolving onto a different PC than predicted
(`ctrl_miss_now`) -- otherwise a wrong-path lane-1 access reaches memory
(section 38). A gate that suppresses the issue without also removing the
operation from `mem_wait` deadlocks the stage, because the freeze it creates
is what keeps the invalidating signal from ever resolving.

LSU alone shifts store_value by 8*address[1:0], generates WSTRB, selects
the load lane and performs sign/zero extension. Cache and bypass return
an unextended aligned 32-bit word; they do not extend it a second time.
A store completes after B, not after AW/W. BRESP errors produce one
store fault and are never automatically retried.

## Transfer engines and cache ownership

I-cache/D-cache own tag/data/LRU/refill only. They cannot retire CPU
instructions, update architectural PC or generate an independent trap.
T09 inserts cache logic behind the above operation interfaces.

Engine descriptors: `valid/ready`, `addr[31:0]`, `size[2:0]`,
`len[7:0]`, `id[3:0]`. Write beats use independent `valid/ready`,
`data[31:0]`, `strb[3:0]`, `last`. Read beats return independent
`valid/ready`, `data[31:0]`, `resp[1:0]`, `last`; descriptor ownership
preserves ID. Write completion holds `valid/ready`, `resp[1:0]`
until consumed. IF uses ID 0 and data uses ID 1 initially.

AXI exposes all five channels, 32-bit addresses/data, 4-bit IDs,
AxLEN/SIZE/BURST/LOCK/CACHE/PROT/QOS and RRESP/BRESP/LAST.
There is no WID. First release permits one global outstanding transfer,
INCR bursts up to 16 beats, no 4 KiB crossing, no exclusives.
AW and W are accepted independently; arbitration locks the owner before
either write channel can be accepted. All asserted channel payloads hold
through backpressure. Errors drain the promised beats and produce one
completion error. The verification model is not synthesizable CPU RTL.

## Interrupt, halt and maintenance boundaries

`arch_next_pc[31:0]` identifies the next unexecuted architectural
instruction. Interrupt acceptance is possible after retirement and when
EX is empty, even if a young fetch is waiting. Acceptance blocks young
entry to EX on that edge. A retiring branch sets the actual next target;
CSR/MRET state updates precede the interrupt eligibility check.
An already issued store drains and resolves before asynchronous interrupt.

halt_pending blocks younger work but lets current EX issue and finish
its one required LSU/divider request. Current exceptions/redirects
resolve first. No reset/halt leaves a live remote AXI transaction orphaned;
reset needs coordinated endpoint quiescence/reset.

FENCE.I must either implement the plan's complete store/fetch drain,
IF/ID/prefetch/I-cache/BTB/refill invalidation and PC+4 refetch sequence,
or decode as illegal and exclude Zifencei from the software ISA flags.
No partial maintenance implementation is accepted.

---

## §3 CSR 与中断

*原文件：`docs/design.md`*

### Native M-Mode CSR and Trap Contract

This document describes implemented RTL, not simulation or board validation.
Production sources include `rtl/core/csr_native.v`; baseline `csr_reg.v` and
`clint.v` are unchanged and are not instantiated by the native CPU.

| CSR | Address | Policy |
| --- | --- | --- |
| mstatus | 300 | MIE bit 3 and MPIE bit 7 writable; MPP fixed M; other bits zero |
| misa | 301 | Read-only RV32IM, 0x40001100 |
| mie | 304 | Software/timer/external enables at bits 3/7/11 |
| mtvec | 305 | Direct only, low two bits forced zero |
| mscratch | 340 | Read/write |
| mepc | 341 | Read/write, low two bits forced zero |
| mcause, mtval | 342,343 | Read/write, trap overwrites atomically |
| mip | 344 | Read-only live hardware IRQ levels at bits 3/7/11 |
| mcycle, mcycleh | B00,B80 | Writable 64-bit counter |
| minstret, minstreth | B02,B82 | Writable 64-bit actual-retirement counter |
| cycle, cycleh | C00,C80 | Read-only mcycle aliases |
| instret, instreth | C02,C82 | Read-only minstret aliases |
| mhartid | F14 | Read-only zero |

Other addresses and writes to read-only CSRs trap as illegal instructions.
Counter half writes override that clock's increment and preserve the other
half from the pre-clock counter. Traps do not increment minstret.

All six Zicsr operations read CSR state in EX, never an ID snapshot. CSRRW
always writes, including rd=x0; no implemented CSR has read side effects.
CSRRS/CSRRC write intent depends on the encoded rs1 index (not its value).
Immediate operands are zero-extended zimm; zero zimm suppresses set/clear writes.
Only exact ECALL, EBREAK and MRET system encodings are accepted. FENCE is
supported at the serialized EX boundary; FENCE.I is illegal.

The wrapper and SoC expose irq_software, irq_timer and irq_external inputs.
Priority is external > software > timer. Interrupt eligibility uses the
post-normal-CSR-write and post-MRET state. Trap entry then copies that MIE
into MPIE, clears MIE, and records full 32-bit mcause.

Synchronous faults have priority. Interrupts are accepted only at actual
retirement or an empty EX boundary, never while memory/division is incomplete.
Interrupt mepc is the retired instruction's actual successor (including branch
and MRET), or arch_next_pc when EX is empty. Acceptance flushes younger fetch/ID
work before it can enter EX. trap_ready backpressure delays acceptance but does
not undo or repeat normal retirement. A retiring store has completed its response.
Halting suppresses interrupt acceptance while current EX drains.

trap_cause is now 32 bits. csr_mtvec exposes the architectural redirect target.
The old trap_vector input remains for connection compatibility but is unused:
native traps always redirect using architectural mtvec. mtvec resets to zero.

Syntax-only verification:
`vlog -sv -work sim/work_csr_native_compile +incdir+rtl/core -f sim/native_axi_sources.f`
completed with zero errors and zero warnings. No simulation was run.

---

## §4 总体规划（2026-10-09）

*原文件：`docs/design.md`*

### tinyriscv 原生 AXI4 改造与紫光赛题一实施计划书（合并版）

> For agentic workers: use $superpower-executing-plans to implement approved tasks one at a time. 本文是设计与实施计划，不是已完成或已测试的 RTL。执行时逐项打勾；没有通过验收，不进入依赖它的下一项。

**Goal：** 以现有 tinyriscv 为基础，直接重构取指、访存和 SoC 总线为原生 AXI4，不保留 RIB，不使用 RIB-to-AXI 桥；先完成基础任务及性能证据，再按G0确认的范围逐项开展高阶任务，不预先承诺全部高阶可完成。

**Architecture：** 保留三级流水线和已有算术/译码基础；重新设计有效位、暂停、提交和异常边界，加入 CPU 内部原生 AXI4 取指与访存单元。片上存储与外设成为原生 AXI4 从设备，互连只路由 AXI4，不转换 RIB。Cache、预测器、DDR、摄像头、AI 分阶段接入。

**Tech Stack：** 可综合 Verilog/SystemVerilog、ModelSim、RISC-V 裸机 GCC、PDS、板载逻辑分析工具。Icarus 可作为另一条回归路线，但本机当前 PATH 未找到它。

**日期：** 2026-10-09。**状态：** 第三轮“小白实施方法”扩充稿。保留原生AXI4总体方向；本轮只修改计划文档，没有改动现有CPU工程。独立文档模板的检查结果与真实CPU验证分开记录，见第36章“扩充计划复核报告”。

**阅读入口：** 第0-24节解释总体方案；第25-34节给出本轮新增的语法、逐文件修改方法、代码模板、测试任务卡和可选功能。先读25，再按26的顺序做，不能把所有代码块一次性粘进原工程。DDR引脚/IP、具体YOLO模型仍须通过资料关卡，不会凭空编造可上板代码。



**本轮结论：** 可作为开发基础，不宜按原顺序直接全量执行。优先修正总线前进性、CPU/Cache边界、异常软件配套与阶段依赖；先取得基础上板和CoreMark证据，再决定高阶投入。赛题没有强制AXI4、禁用桥、指定OV5640、垃圾检测或HDMI；这些属于队伍方案选择。

---

**唯一维护文档：** 本文件已合并总体方案、小白实施方法、历次评审意见与实际复核记录。第0-24章为总体方案，第25-34章为实施方法，第35章为历史评审依据，第36章为模板复核结果。原独立评审文件和旧备份已移除；第35-36章中的历史行号、哈希与过程记录仅用于追溯，不代表当前仍存在独立原稿。执行时以当前正文及明确验收门槛为准。

## 0. 先看懂这份计划

### 0.1 我们究竟修改什么

CPU 的指令含义不因总线变化而改变。例如 `lw x5, 0(x6)` 仍然是“从 x6 给出的地址读取一个字，写进 x5”。变化在于：

```text
原来：给出地址 -> 原有组合读数据路径 -> 执行级使用数据
改后：保存请求 -> AXI地址握手 -> 等待数据 -> 检查响应 -> 写回一次
```

“原生 AXI4”不要求把所有状态机塞进 `tinyriscv.v`。在 CPU 内部拆分 `ifu_axi.v` 和 `lsu_axi.v` 是合理的，它们分别属于取指单元和访存单元，不是保留旧 RIB 的协议桥。

最终结构：

```text
                         tinyriscv CPU
         +-------------------------------------------+
         | PC -> 取指单元 -> IF/ID -> ID -> ID/EX -> EX |
         |        |                              |   |
         |     两路I-Cache                 两路D-Cache |
         |        |                              |   |
         |     原生AXI读主接口              原生AXI读写主接口 |
         | 寄存器 / CSR / trap / 分支预测 / retire     |
         +--------|------------------------------|---+
                  +---------------+--------------+
                                  |
                             AXI4互连
                  +---------------+------------------+
                  |               |                  |
            程序RAM/数据RAM   UART/GPIO/Timer     AI控制寄存器
                  |                                  |
           DDR目标端口(须核验) <--- AXI4数据主接口 --- AI计算与DMA
                  ^
                  |
           摄像头DMA <- 异步FIFO <- OV5640 DVP采集
```

没有 Cache 的第一版，取指/访存单元直接访问 AXI4；加 Cache 后，缺失请求由 Cache 的补行逻辑发起。内部信号可以是 `valid/ready/address`，但不能保留 RIB 仲裁及其时序假设来伪装“原生改造”。CPU内部层次按第3.5节固定，避免T03/T04与T09分别实现互不兼容的请求入口。

### 0.2 本文四种状态

| 标记 | 意思 |
|---|---|
| 已查源码 | 本次在本地文件里确认有这段逻辑，不代表正确运行 |
| 赛题要求 | 来自用户提供的 PDF，而非网上二手总结 |
| 本方案选择 | 为降低开发难度做出的架构决定，不是官方强制 |
| 核验关卡 | 没有足够证据，完成指定核验后才能开展依赖工作 |

### 0.3 不做的事情

- 不把 AXI4-Lite 当作 AXI4，也不先做 Lite 再整体推翻。
- 不实现 RIB-to-AXI 桥。
- 不为了总线改造重写全部 ALU 和译码。
- 第一版不做多笔乱序 outstanding、不做多核一致性、不做操作系统移植。
- 不把“有 AXI4 接口”当成“已经实现 Cache/DDR/AI”，这些分别验收。
- 不承诺 YOLO 的帧率、准确率或时序收敛；这些必须测量。

## 1. 赛题逐项对齐

### 1.1 核对依据

已读取：

`C:\Users\lenovo\Desktop\全国大学生嵌入式芯片与系统设计竞赛'2026FPGA赛道选题指南-紫光同创.pdf`

PDF 第 10 页 = 页脚第 8 页：选题一核心设计任务。

PDF 第 11 页 = 页脚第 9 页：工具链、性能、应用、文档、运行时间要求。

下表是摘要，不代替原文。本文不假定高阶项全部为强制，也不臆造分值；最终评分权重、旧作品使用边界和提交期限须以赛事通知为准。

| 编号 | 赛题内容摘要 | 当前工程状态 | 本计划交付/证据 |
|---|---|---|---|
| B1 | RV32I 基础整数处理器 | 有译码、执行、32寄存器源码；未本机验证 | 指令回归、随机等待访存回归、签名/提交轨迹 |
| B2 | 不少于三级流水线，处理数据冲突与分支 | 有 IF/ID/EX 和控制源码；暂停语义要改 | 阶段有效位、相关指令测试、分支清除波形 |
| B3 | UART、GPIO 等基础外设 | 有外设源码 | 原生AXI4外设，CPU串口输出及LED/按键演示 |
| H1 | 两路组相联指令与数据 Cache，优化突发 | 未见对应实现 | 两路I-Cache + 两路D-Cache + AXI补行突发、命中率/周期对比 |
| H2a | 动态分支预测，如 BTB | 未见对应实现 | BTB + 两位方向计数器，预测对错计数及纠错测试 |
| H2b | 完整 RISC-V 异常/中断机制 | 有CSR/CLINT基础；不能认定完整 | 明确M模式边界、异常矩阵、精确mepc、屏蔽/返回测试 |
| H3 | 基于CPU构建边缘AI，移植YOLO或轻量大模型，融合传感/显示 | 当前CPU工程未见该系统 | YOLO软硬件协同，OV5640输入，CPU配置加速器并输出结果 |
| E1 | 紫光同创FPGA平台 | 示例为Xilinx流程 | 盘古100Pro+ PDS工程、引脚/时序约束、资源与时序报告 |
| E2 | riscv32-unknown-elf-gcc | 原脚本指向旧工具链 | 指定工具链或取得兼容工具链确认，记录版本/编译参数 |
| E3 | CoreMark v1.0，运行至少10秒 | 有源码与旧平台截图 | 本板CRC正确、实际时钟、时间、迭代数、完整UART日志 |
| E4 | CoreMark/MHz、最高时序合格频率、CoreMark/LUTs | 没有本板测量 | 同配置、同编译参数的基线/改造/优化对照 |
| E5 | 应用延迟、识别率、资源、时序、主频 | 未实现 | 独立测试集、端到端延迟及硬件资源报告 |
| E6 | 模块化、合理约束、注释、性能文档及ILA波形分析 | 尚无本项目提交包 | 原理图、模块说明、波形、测试复现脚本、贡献说明 |

**赛题解释边界：**

1. 原文没有把“必须 AXI4”列为基础任务。AXI4 是你们主动选择的架构，服务 H1/H3；不能替代 RV32I 与性能验证。
2. 高阶 AI 原文明示 YOLO 或轻量版大模型。小分类 CNN、加法器或单个卷积核可以当学习里程碑，但不能自行宣布已经满足该高阶任务。若最终只做 CNN 分类，需先向主办方确认是否接受。

3. 第10页使用“传感器或者显示设备”，不是要求摄像头和HDMI同时具备。OV5640输入配CPU输出检测结果可作为方案，仍需完成整套真实AI应用；HDMI可后置。第11页还单列应用场景构建，不能把只有跑分的系统称为全部测评内容已覆盖。

### 1.2 来源与参赛范围关卡 G0

- [ ] 保存本地PDF的SHA256和第10-11页；只适用选题一，不混入选题二的1080P帧率或选题三的95%车牌准确率等要求。
- [ ] 当前目录README明确介绍开源tinyriscv，RTL含Blue Liang署名，根目录含Apache-2.0 LICENSE。这只能确认有开源基础，不能据此判断队友没有修改，也不能把全部现有代码写成队伍原创。
- [ ] 队长提供所用上游版本/取得日期和队友改动记录，形成`docs/provenance.md`：上游已有、队友已有、本项目拟新增三列；无Git历史时以文件哈希和可取得的上游快照逐文件比对。
- [ ] 向赛事组织方确认开源CPU复用、已有作品与新增贡献的参赛边界，并保存书面答复。本PDF没有足够信息判定这方面允许或禁止；开源许可与比赛原创性要求分别核对。
- [ ] 确认板卡实际型号、可用开发周数、成员分工、CPU高阶/AI目标档位；未确认前，不把全功能路线当作已承诺交付范围。

源码基线和学习验证可以先做；G0没有完成，不提交“全自主设计/参赛资格已确认”等表述。

## 2. 源码核对与必须改的原因

原工程根目录：

`E:\donwload\tinyriscv-master\tinyriscv-master`

本次发现不是 Git 工作树。保留此目录作为参考，实施前建立独立版本管理副本；不删除旧版本。

| 已核对位置（相对上述根目录） | 当前行为 | 原生AXI改造必须处理 |
|---|---|---|
| `rtl/core/tinyriscv.v:25` | 对外RIB取指/数据接口，无逐笔完成反馈 | 替换成AXI通道，加入事务生命周期 |
| `rtl/core/tinyriscv.v:216` | 当前PC和取指数据直接交IF/ID | 返回指令必须配对保存的请求PC |
| `rtl/core/rib.v:114` | 4主6从固定优先级组合选择 | 用保存事务归属的AXI互连替换 |
| `rtl/utils/gen_dff.v:37` | `hold_en`为1时写默认值 | 此处是清空，不是保持；不可直接用于等待DDR |
| `rtl/core/pc_reg.v:43` | 没暂停就PC+4 | 只在相应取指结果被接纳后推进 |
| `rtl/core/ex.v:640` | SB/SH读取旧字并拼接 | 改成WSTRB字节使能，不先读MMIO |
| `rtl/core/regs.v:67` | 同周期写回到读端旁路 | 只旁路已有效完成的结果，不能旁路未返回的load |
| `rtl/core/ex.v:185`附近 | 除法启动配合原有清空/跳转模式 | 改成单次启动、等待、单次提交，不能直接冻结旧逻辑 |
| `rtl/core/clint.v` | 在译码相关信息上触发中断/异常处理 | 改为按指令年龄和提交边界处理，不打断已发出的AXI写 |
| `rtl/soc/tinyriscv_soc_top.v:326` | UART下载、JTAG也是总线主设备 | 同样要改或明确暂禁，不可只改CPU而漏掉下载链路 |
| `rtl/perips/rom.v`、`ram.v` | 4096个32位字，组合读 | 16KiB各一块；改同步RAM与AXI响应时序 |
| `rtl/core/defines.v` | `INST_NOP=32'h00000001` | 无C扩展时不能当标准32位NOP；改用valid气泡及0x00000013显示值 |
| `tests/example/link.lds` | 程序0x0/16KiB，RAM 0x10000000/16KiB | 尽量保留地址，扩容后同步改链接脚本 |

以上是改造影响分析，不是完整的原CPU缺陷审计。旧实现可能依赖自己的组合总线约定；本计划不能假定替换总线后其他逻辑自然正确。

## 3. 先冻结接口规格，再写代码

### 3.1 最小原生 AXI4 配置

本方案从第一版就使用 AXI4 通道字段，先运行单拍，后启用突发，不走 AXI4-Lite 过渡。

| 项目 | 本方案选择 |
|---|---|
| 地址/数据宽度 | 32位/32位，小端 |
| ID宽度 | 4位；取指=0、数据=1、UART下载=2、JTAG=3、摄像头DMA=4、AI DMA=5 |
| 第一版并发 | 互连全局只接受1笔未完成事务，事务结束后再仲裁 |
| 单拍访问 | AxLEN=0；不是AXI4-Lite |
| Cache补行 | INCR，8拍，每拍4字节，即32字节一行 |
| DMA突发 | INCR，1至16拍，避开4KiB边界 |
| CPU子字访问 | ARSIZE/AWSIZE按1/2/4字节，字节lane按地址低2位 |
| 首版不发出 | FIXED、WRAP、独占、乱序、多笔同ID挂起 |
| 首版响应 | 正常OKAY；地址未映射DECERR；目标访问错误SLVERR |
| 时钟域 | CPU、互连、BRAM、基础外设同域；DDR/相机独立处理 |
| 回压 | AR/AW/W/R/B都允许等待；保持VALID与负载直至握手 |

说明：不使用某些可选能力，不等于必须假装“支持AXI4全部可选特性”。交付时公开该 profile。外来主设备要满足它；不能把仅能接本系统流量的从设备宣传为任意AXI4流量全兼容。

### 3.2 五个通道，CPU数据主接口方向

| 通道 | CPU输出 | CPU输入 | 通俗含义 |
|---|---|---|---|
| AR | ARID[3:0], ARADDR[31:0], ARLEN[7:0], ARSIZE[2:0], ARBURST[1:0], ARLOCK, ARCACHE[3:0], ARPROT[2:0], ARQOS[3:0], ARVALID | ARREADY | 我要读哪里、读多少 |
| R | RREADY | RID[3:0], RDATA[31:0], RRESP[1:0], RLAST, RVALID | 对方返回读数据 |
| AW | AWID[3:0], AWADDR[31:0], AWLEN[7:0], AWSIZE[2:0], AWBURST[1:0], AWLOCK, AWCACHE[3:0], AWPROT[2:0], AWQOS[3:0], AWVALID | AWREADY | 我要写哪里、写多少 |
| W | WDATA[31:0], WSTRB[3:0], WLAST, WVALID | WREADY | 具体写入内容 |
| B | BREADY | BID[3:0], BRESP[1:0], BVALID | 整笔写事务是否成功 |

取指接口只需AR/R读通道；若顶层统一打包读写接口，明确禁用并固定写输出。AXI4没有WID。REGION/USER本系统不使用，若实际IP暴露则按其文档固定，不随意删必需信号。

固定值建议：AxLOCK=0，AxQOS=0，AxBURST=2'b01，AxCACHE首版=4'b0000。M模式非安全指令ARPROT=3'b111，数据AxPROT=3'b011；目标IP是否解释这些属性仍需核验。Cache内部可缓存区域由地址表单独控制，不能把AxCACHE直接当成本地cache开关。

### 3.3 看一个8拍读例子

读地址从0x10000000起连续32字节：

```verilog
ARADDR  = 32'h10000000;
ARLEN   = 8'd7;       // 拍数减1
ARSIZE  = 3'd2;       // 每拍字节数=2**2=4
ARBURST = 2'b01;      // INCR，地址递增
```

成功接收数据地址依次为0x10000000、04、08、0C、10、14、18、1C。只有 `RVALID && RREADY` 才算收到一拍；不是每过一个时钟就加计数。第8拍必须看到RLAST。

### 3.4 全工程必须遵守的规则

- VALID一旦置1，未握手时不得撤销；对应地址、长度、数据等必须保持。
- 发送方不能等READY变1才决定是否置VALID，否则可能互相等待。
- AW和W分别记录完成，不能要求两者同一拍握手。
- 写响应在AW及全部W拍被接收后才能完成；CPU不能仅因WREADY=1就认定store退休。
- 总线事务已经发出后，分支不能“取消”它；错误路径取指响应要接完再丢弃。
- 突发不能跨4KiB边界。按实际字节地址计算，不能按错误的字地址计算。
- 未握手时不要改变读写计数，RLAST/WLAST按拍数生成与检查。
- RRESP/BRESP错误不能当成0数据或正常完成。
- reset/halt不能把已接受事务遗留给仍在运行的另一端。
- 外设读可能有副作用，禁止把MMIO当普通RAM进行投机读、预取或Cache补行。

### 3.5 CPU内部接口与Cache插入位置

统一选择“CPU操作接口 -> 可选Cache/旁路 -> AXI事务引擎”，CPU顶层对外仍是原生AXI4。CPU内部操作接口不是RIB桥，不复用旧RIB仲裁和组合读完成语义。

| 模块 | 独占职责 | 不允许重复实现的职责 |
|---|---|---|
| `ifu_axi.v` | PC/redirect、请求身份、预留响应槽、正确路径结果交付；容纳可选I-Cache及读引擎 | 不让I-Cache另建一套架构PC或向流水线重复送指令 |
| `lsu_axi.v` | 锁存EX操作、对齐检查、一次完成/异常、load扩展；容纳可选D-Cache及数据引擎 | 不让D-Cache重复退休、再次移位字节或另发同一笔store |
| `icache_2way.v` / `dcache_2way.v` | tag/data/LRU、命中、缺失与补行控制；向下提交传输描述符 | 不直接改变GPR、CSR、架构PC或trap状态 |
| `axi_read_engine.v` / `axi_data_engine.v` | 保存AXI字段、VALID稳定、计拍、响应与错误；数据引擎含AW/W/B | 不解释RISC-V指令，不生成第二个CPU完成事件 |

无Cache时旁路控制器提交单拍描述符；有Cache时向同一引擎提交补行或直达描述符。引擎描述符使用`valid/ready, addr, size, len, id`，写数据单独`valid/ready, data, strb, last`；读返回逐拍`valid/ready, data, resp, last`，写结果保持至消费。

I侧操作请求保存`pc`及预测下一PC，返回原`pc/inst/fault`；D侧操作接口沿用第10.1节。D-Cache与旁路向LSU返回未扩展的对齐32位字，LSU只做一次lane选择及符号扩展。T02前把这些端口、位宽和生命周期写入`docs/cpu_memory_contract.md`；T09只能扩展Cache内部，不推翻EX/IF-ID合同。

### 3.6 必须能继续前进的约束

全局单事务只限制互连已经接纳/呈现到下游的事务，不意味着其他主机不得保持待处理VALID。每个主设备必须在发请求前保证最终能独立接收返回，不能依赖另一笔还在等待仲裁的事务完成。

- IFU发AR前预留一个完整响应槽；AR发出后，只要该槽空，就接R，即使EX因load暂停。否则会形成“IF占总线 -> IF等EX解除stall -> EX等LSU获得总线”的循环等待。Cache补行同理预留一行或可独立消化的逐拍存储。
- 写owner在首次呈现AWVALID时锁定。向目标发送WVALID不能依赖目标AWREADY或AW已握手；两者可以独立握手。需要缓存时分别记录上游AW/W接收与下游AW/W发送。
- 首版不从MMIO区域取指：在地址属性检查阶段生成instruction access fault，不发AR；不能因错路预测读取UART并弹出FIFO。DDR未就绪时也不提前发出会长期占住全局互连的请求。
- 轮询在完整事务结束后推进；持续竞争时按最大事务拍数、目标响应上界、仲裁者数量记录最坏等待。AI/视频接入后重新测吞吐和FIFO占用，首版单事务仅是正确性基线。

## 4. 地址地图：尽量不破坏已有软件

| 区域 | 基地址 | 第一版实际范围 | 可缓存 | 访问策略 |
|---|---|---|---|---|
| 程序RAM，保留模块名rom | 0x00000000 | 16KiB，至0x00003FFF | I可缓存；D首版不缓存 | 调试停机后可写，运行时禁止误写代码 |
| 数据RAM | 0x10000000 | 16KiB，至0x10003FFF | D可缓存 | 支持1/2/4字节与补行 |
| Timer | 0x20000000 | 沿用原寄存器偏移 | 否 | 单拍 |
| UART | 0x30000000 | 沿用原寄存器偏移 | 否 | 单拍 |
| GPIO | 0x40000000 | 沿用原寄存器偏移 | 否 | 单拍 |
| SPI | 0x50000000 | 沿用原寄存器偏移 | 否 | 单拍 |
| AI控制，拟新增 | 0x60000000 | 4KiB地址窗口 | 否 | 单拍，未实现偏移报错 |
| 图像DMA控制，拟新增 | 0x60001000 | 4KiB地址窗口 | 否 | 单拍 |
| 性能计数器，拟新增 | 0x60002000 | 4KiB地址窗口 | 否 | 单拍，只读或显式清零 |
| IRQ控制，拟新增 | 0x60003000 | 4KiB地址窗口 | 否 | 单拍，软件pending/外部pending与mask，见13.2 |
| DDR，拟新增 | 0x80000000 | 容量由板卡/IP核验后冻结 | 程序/普通数据可缓存 | 图像共享缓冲设不可缓存区 |

原RIB按高4位选择设备，不代表设备真的有256MiB。新互连必须检查实际容量与有效寄存器偏移，越界返回错误，不允许数组索引越界或地址镜像。

本计划不沿用之前聊天中随口举的UART=0x10000000示例，它与当前工程真实地址分配不符。

## 5. 文件改造地图

所有相对文件名仅是目录图；打开文件时以这里的绝对根目录拼接。

实施副本拟定：`E:\file\pango\tinyriscv_axi4`。尚未创建，不把它当已存在的工程。

| 处理 | 原文件或拟建文件 | 职责/边界 |
|---|---|---|
| 修改 | rtl/core/tinyriscv.v | 删除RIB外部端口，连接原生取指/LSU、retire |
| 修改 | rtl/core/pc_reg.v | 基于取指消费与redirect更新PC |
| 修改 | rtl/core/if_id.v、id_ex.v | valid、ready、flush，保留未消费指令 |
| 修改 | rtl/core/ctrl.v | 分离stall、flush、redirect、halt |
| 修改 | rtl/core/ex.v | 生成访存意图，等待LSU；运算结果只有完成时有效 |
| 修改 | rtl/core/id.v | 保留译码主线，加入非法编码检测、源寄存器使用信息 |
| 修改 | rtl/core/regs.v、csr_reg.v | 提交写使能、旁路、CSR合法性、性能计数 |
| 修改 | rtl/core/clint.v | 指令年龄/提交边界上的异常中断控制 |
| 保留算法/增加控制层 | rtl/core/div.v、新增div_adapter.v | 原div运算中要求start持续为1；adapter将一次请求转换为保持电平并保存结果，不能直接打一拍start |
| 新建 | rtl/core/ifu_axi.v | 保存取指PC、发AR、收R、缓存响应、错路丢弃 |
| 新建 | rtl/core/lsu_axi.v | load/store状态机、WSTRB、响应错误与完成 |
| 新建 | rtl/core/axi_read_engine.v、axi_data_engine.v | CPU内部AXI传输引擎，旁路与Cache复用，详见3.5 |
| 新建 | rtl/core/retire_ctrl.v | 单次提交、同步异常、退休后异步中断 |
| 新建 | rtl/core/pipe_slot.v | 专用于新流水线的保持/清空槽，不全局改旧gen_dff |
| 新建 | rtl/core/axi_defs.vh | AXI参数和response常量，不覆盖ISA宏 |
| 替换 | rtl/core/rib.v -> rtl/bus/axi_interconnect.v | AXI仲裁、地址译码、保存owner、路由响应 |
| 新建 | rtl/bus/axi_error_slave.v | 未映射访问有界响应，不死等 |
| 修改 | rtl/perips/rom.v、ram.v | 原生AXI4，同步读，WSTRB，突发 |
| 修改 | rtl/perips/uart.v、gpio.v、timer.v、spi.v | 外设本体内实现AXI接收/响应，不保留RIB外部接口 |
| 修改 | rtl/debug/uart_debug.v、jtag_dm.v、jtag_top.v | 原生AXI调试内存访问，握手完成后才确认 |
| 修改 | rtl/soc/tinyriscv_soc_top.v | 删除RIB连接，暴露真实GPIO引脚，连接AXI网络 |
| 新建 | rtl/cache/icache_2way.v、dcache_2way.v | 两路Cache |
| 新建 | rtl/core/branch_predictor.v | BTB与方向计数器 |
| 新建 | rtl/perips/perf_regs.v | 计数器快照与读出 |
| 新建 | rtl/perips/irq_ctrl.v | T07b软件/外部中断来源、pending/mask、单拍MMIO |
| 新建 | rtl/ai/ai_control.v、mac_array.v、conv_engine.v、tensor_dma.v | 模型控制、计算、搬运 |
| 新建 | rtl/video/ov5640_capture.v、frame_dma.v | 相机接入，帧所有权 |
| 新建 | fpga/pango/pango_top.v | 板级时钟/复位、引脚、IP连接 |
| 修改/新增 | sim/、tb/、tests/ | 可变延迟、协议检查、程序测试和报告 |
| 修改 | tests/example/init.c、trap_entry.S、trap_handler.c、include/utils.h、lib/utils.c | 标准中断使能/分发、异常返回、CSR访问与64位计时 |
| 修改 | tests/example/common.mk、coremark/Makefile、link.lds、start.S | 工具链、ISA/ABI、内存容量、初始化镜像 |

ROM/外设把AXI请求解码成内部寄存器写使能是正常从设备实现，不是RIB桥。禁止在其外面留下旧RIB模块再套协议转换器。

## 6. 工具和基线：任务 T00

**目的：** 留下“修改之前能运行什么”的证据，后续坏了才知道是哪里引入。

### 操作

- [x] 已于2026-10-10复制到实施副本并另外完整备份；790个磁盘文件SHA256逐一一致，原目录保持不动。不推断外部编辑器是否另有未保存缓冲。
- [x] 已于2026-10-10在副本初始化Git，原始提交`6741872`，分支`implementation/native-axi4`。
- [x] 2026-10-10已保存赛题PDF摘要、计划快照、源文件SHA256及ModelSim版本到实施副本`docs/evidence/baseline/`。
- [ ] 在副本运行`Get-Command vsim,vlog,vlib,python`。本次发现ModelSim位于`E:\donwload\win64`，存在不等于许可证可用。
- [ ] 检查编译器：`riscv32-unknown-elf-gcc --version`；如果不存在，先配置工具链，不用宿主机GCC替代。
- [x] 2026-10-10两处寄存器声明顺序兼容修复后，add及47/47原镜像通过；当时逐项日志见 `evidence/records/baseline/compatible-original/`（已于 2026-10-18 清理，属早期验证）；首次原版编译失败记录保留在 `evidence/records/bottleneck_audit/provenance/early-baseline/first-compile-failure.log`。

原Icarus路径的运行命令（仅在iverilog/vvp已可用时）：

```powershell
Set-Location 'E:\file\pango\tinyriscv_axi4\sim'
python .\sim_new_nowave.py ..\tests\isa\generated\rv32ui-p-add.bin inst.data
python .\test_all_isa.py
```

现有脚本写死Icarus，不能因为已装ModelSim就直接认为能运行。**第三轮统一采用第27.2-27.3节的根目录相对文件清单与runner**。下面仅解释Tcl批处理含义，不再作为另一套基线入口；实际命令与工作目录以第27节为准：

```tcl
onerror {quit -code 1}
if {![file isdirectory work]} {vlib work}
vlog -sv +incdir+../rtl/core -f baseline_sources.f
vsim work.tinyriscv_soc_tb
run -all
quit -code 0
```

`baseline_sources.f`完整内容见27.2，仅含原设计，不夹入未来AXI模块。旧工具链的`$readmemh`输入可由`tools/BinToMem_CLI.py`生成；以下是原流程参考，新runner已集成尾字节填充和镜像生成，不必重复执行：

```powershell
python ..\tools\BinToMem_CLI.py ..\tests\isa\generated\rv32ui-p-add.bin inst.data
vsim -c -do modelsim_baseline.do -l baseline_add.log
```

基线测试台原先的`$finish`不保证进程退出码代表通过。因此外层运行脚本必须同时检查：进程结束、无fatal、日志含`TEST_PASS`、没有失败标记、确实执行了至少一个用例。若超时，终止本次子进程并失败，不留下后台仿真。

**通过标准：** 可复现的基线报告；失败项目明确记录，不能把已有失败算成改造成功。至少通过add及全套基线结果登记后才开始CPU替换；全套基线失败须先定位。独立T01平台不依赖CPU，可并行。

T01独立AXI测试平台可与T00并行；T02开始替换CPU前，必须完成全套原始基线结果登记与失败归因，而不只看add。源码目录现有`sim/out.vvp`和VCD不是本轮执行结果，不能拿来替代新编译日志。

### T00-P：尽早核验板卡和PDS，不等待总线重构

- [ ] 核对器件、PDS许可证、下载器、引脚和时钟；先复现板卡最小LED/UART或同步BRAM例程，保存实现及下载结果。
- [ ] 若需要原RIB上板C0参考，在独立参考工程进行，保留源目录不动；它不进入最终原生AXI文件清单，也不宣传为新增成果。
- [ ] 提前编译CoreMark移植层并生成map/size报告：检查程序镜像、`.data/.bss`、栈及堆是否落在实际16KiB窗口。超限先定BRAM扩容及地址译码，不把DDR当基础跑分必需条件。
- [ ] `BinToMem_CLI.py`当前只输出完整四字节组；若输入长度不是4的倍数，计划在副本的镜像工具中明确填充并验证，不能默默丢尾字节。PDS程序初始化需包含`.data`的装载镜像。

这是平台风险排查，不等于原生AXI CPU已上板。失败应尽早影响排期，而不是等T07结束才发现工具或板卡不可用。

## 7. 先做测试环境：任务 T01

**新建路径（均位于实施副本）：**

- `tb/axi/axi_memory_model.sv`
- `tb/axi/axi_monitor.sv`
- `tb/axi/tb_axi_memory.sv`
- `sim/run_axi_tests.ps1`
- `sim/axi_sources.f`

### 操作

- [x] 写一个同步时钟测试台，复位低有效至少5拍，然后在非采样边沿释放。
- [x] memory model独立保存AR、AW、W状态，不要求AW/W同周期；地址/写数据各设1项缓存。
- [x] 添加字节数组scoreboard：写操作只更新WSTRB对应字节，读操作逐字节比较。
- [x] 分别控制ARREADY、AWREADY、WREADY延迟，以及RVALID/BVALID延迟；主端也随机压低RREADY/BREADY。
- [x] 添加固定seed参数，记录失败seed、地址、期望值、实际值。
- [x] 加总周期watchdog，例如每个小测试100000周期；超时用`$fatal(1,"TIMEOUT")`。
- [x] 结束时检查事务计数与队列全部清空，再打印唯一`TEST_PASS <case>`。

2026-10-10实施副本T01实际验收：seed 1至20均通过；改变受阻AR地址的
负向注入触发稳定性Fatal。包含AW/W同拍及先后5拍直接间隔断言、
R/B阻塞、字节lane、8拍突发、未映射错误及同时读写请求。
证据见实施副本`docs/evidence/axi/`。仅验证独立环境，不表示CPU已接入AXI。

最小握手理解：

```verilog
wire ar_fire = arvalid && arready;
wire r_fire  = rvalid  && rready;
wire aw_fire = awvalid && awready;
wire w_fire  = wvalid  && wready;
wire b_fire  = bvalid  && bready;
```

监视器应检查的性质（用SVA或等价逐拍寄存器检查；老ModelSim不支持某些SVA时用后者）：

```systemverilog
assert property (@(posedge clk) disable iff (!rst_n)
    arvalid && !arready |=> arvalid &&
    $stable({araddr,arid,arlen,arsize,arburst,arlock,arcache,arprot,arqos}));
assert property (@(posedge clk) disable iff (!rst_n)
    wvalid && !wready |=> wvalid && $stable({wdata,wstrb,wlast}));
```

对AW/R/B也做同类稳定性检查。再检查无孤立响应、ID一致、拍数一致、最后拍正确。测试台不能只用永远READY=1的内存。

**具体首批用例：** 写0x12345678再读回；AW先到5拍、W先到5拍、同拍到；R阻塞7拍；B阻塞7拍；8拍突发每拍间隔不同；未映射地址返回错误。

**通过标准：** 先故意破坏一个稳定性/拍数规则，确认monitor能报错，再恢复测试模型使全部通过。一个“永远通过”的测试环境不能用来验收CPU。

## 8. 流水线语义：任务 T02

**修改文件：** `pc_reg.v`、`if_id.v`、`id_ex.v`、`ctrl.v`、`ex.v`、`tinyriscv.v`。同步定义`retire_ctrl.v`的正常提交/异常接纳合同，T07再完善异常矩阵，不能到T04才第一次决定retire接口。

### 8.1 三个词必须分开

| 词 | 意思 | 寄存器行为 |
|---|---|---|
| stall | 这条指令还没完成，等一下 | 保持内容与valid |
| flush | 这条指令走错路/被异常清除 | valid清零 |
| bubble | 没有真实指令 | valid=0，不产生任何副作用 |

不能用当前`gen_pipe_dff`的hold来代替stall，因为它写默认值。

### 8.2 冻结的流水线协议

- IF/ID保存`valid, pc, inst, fault, predicted_next_pc`。
- ID/EX保存同样身份字段及译码控制、操作数、rd、CSR信息。
- EX保持占有当前指令，直到运算/访存完成或产生同步异常。
- 初版采取保守策略：EX等待load/store/div时，冻结年轻阶段，不允许后续指令越过。
- EX完成且允许提交时形成一次`retire_fire`；寄存器、CSR和分支训练只在规定的提交事件更新。
- 已发出store不能因中断到来撤销；收完B并提交后才接纳异步中断。
- 同步异常不退休，不写rd；保存该指令PC进入trap。

年龄顺序固定为EX老于ID、ID老于IF。EX跳转/异常清除年轻槽，不清除已被接受的AXI事务；年轻取指错误先作为fault字段排队，不越过更老EX立即进入trap。维护独立`arch_next_pc`，表示下一条尚未执行的架构指令地址。异步中断在一条指令提交后可接纳，也必须在EX已空、只有年轻取指等待时检查；不能只用`retire_fire`作为检查触发。接纳时保存`arch_next_pc`，禁止同拍年轻指令进入EX。分支提交同拍中断返回PC为实际分支目标；MRET/CSR修改后用更新后的中断使能状态重新检查。详见13.2。

ID必须在真正进入ID/EX的那一拍读取并锁存操作数；若EX此拍提交相同rd，使用已完成写回结果旁路。不能在等待load的第一拍就冻结年轻指令的旧操作数，再在load完成后不重新取值。CSR相关也需提交时旁路或额外阻塞一拍。

槽位控制示意，`payload_i`指包含PC/指令等字段的打包数据：

```verilog
assign in_ready = rst_n && !flush && (!valid_q || out_ready);
assign out_valid = rst_n && !flush && valid_q;
always @(posedge clk) begin
    if (!rst_n) begin
        valid_q <= 1'b0;
    end else if (flush) begin
        valid_q <= 1'b0;
    end else if (in_ready) begin
        valid_q <= in_valid;
        if (in_valid) payload_q <= payload_i;
    end
end
```

这些是设计模板，不是把未声明变量直接复制进原工程即可编译的补丁。先在`pipe_slot.v`声明数据宽度参数与对应端口，再通过独立测试后替换两个流水线寄存器。

内部消费统一用`in_fire=in_valid && in_ready`、`out_fire=out_valid && out_ready`，flush周期均不能产生年轻槽位的握手或副作用。产生redirect的老EX指令仍可正常提交，只清其年轻槽位。外部AXI不使用此取消规则，仍须保持VALID并排空。增加flush与输入/输出原本可握手同拍的测试。

### 操作与测试

- [ ] `pipe_slot`测试：装入A、下游阻塞10拍、输出始终A，解除后只消费一次。
- [ ] flush与stall同时出现时，错误路径指令清除；复位最高优先。
- [ ] 保留纯算术译码，给普通ALU指令`ex_done=1`，load/store由LSU完成，div由除法完成。
- [ ] 删除旧除法“启动时跳转/清空”的控制用法；每条EX除法向`div_adapter`握手一次并保存rd。原`div.v`在START/CALC/END检查start电平，adapter须保持start直到ready，并在ready出现时阻止下一次意外启动；不是向原div打一拍脉冲。方法见28.4。
- [ ] 暂停期间不得反复写CSR、发store、训练预测器或重复启动除法。
- [ ] 执行`addi x1,x0,5; addi x2,x1,3; add x3,x1,x2`，期待5、8、13。
- [ ] 测试`lw x1,0(x10); add x2,x1,x1`，将读返回延后20拍，x2必须使用返回值。

**通过标准：** 用单调递增`retire_order`核对提交事件，按`PC/指令/rd/写值/内存效果`与参考轨迹比较；PC本身不充当唯一身份，因为循环会合法重复PC。

**依赖分层：** T02先用测试台注入指令和可控延迟LSU/div完成模型验槽位、旁路与单次提交；它不是完整SoC通过。T03/T04分别用AXI模型验单元，T05用测试主机验互连/从设备；上述单元都完成后，进行T05-I CPU集成回归，再宣称真实load-use/分支/AXI共同通过。不能要求T02先在尚不存在的T04/T05硬件上通过完整程序。

## 9. 原生取指：任务 T03

**新建：** `rtl/core/ifu_axi.v`及其内部`axi_read_engine.v`。**修改：** `pc_reg.v`、`tinyriscv.v`、`if_id.v`。以下状态表表示组合后的行为，AXI握手寄存器归引擎独占，不能在两层重复驱动。

### 保存的状态

`request_pc[31:0]`、`req_live`、`inst_buf[31:0]`、`response_pc[31:0]`、`response_valid`、`discard_pending`、`redirect_target[31:0]`、响应错误字段。`req_live`从IFU与读引擎的内部`req_fire`开始置位，直到该请求结果被交付或丢弃后才清零。

初版最多1笔取指事务，一个返回缓冲。

| 状态 | 行为 | 离开条件 |
|---|---|---|
| IDLE | 缓冲空且允许取指时，保存PC和AR字段 | 进入SEND_AR |
| SEND_AR | ARVALID保持1 | AR握手后进入WAIT_R |
| WAIT_R | 使用发AR前已预留的响应槽，接收不依赖EX stall | 收到唯一R拍并检查RLAST/RESP |
| HAVE_INST | 保存指令及请求PC，送IF/ID | IF/ID握手后清缓冲 |
| DRAIN | redirect后旧请求仍要完成 | 收完旧返回，丢弃后取新目标 |

### 必须覆盖的分支时序

- redirect与内部`req_fire`同拍：redirect优先；可以组合阻止旧请求接单，也可以接单后立即标记丢弃，但不能把旧PC当成新路径请求。
- 读引擎已内部接单、尚未向AXI完成AR握手：旧请求已经属于IFU，必须保持地址稳定、继续收尾并丢弃。不能等到观察到外部ARVALID或AR握手后才开始跟踪。
- 在ARVALID=1但ARREADY=0时跳转：不能撤销ARVALID或修改ARADDR；标为丢弃，握手并收完旧响应。
- AR已握手、R未返回时跳转：保存新目标；旧响应接收但不送译码。
- R返回与redirect同拍：redirect决定该年轻取指失效。
- R结果已停在读引擎/IFU返回槽、下游尚未接纳时跳转：清交付资格并丢弃，不能因为AXI事务已经结束就让旧指令进入IF/ID。
- 多次redirect发生在同一旧请求等待期间：保留最新架构有效目标；discard不能被第二次redirect清零。
- 旧路径取指报错：丢弃，不对新路径产生伪异常。

取指PC推进以返回指令被IF/ID接受为准；redirect优先。请求PC和当前PC必须是两个寄存器概念，禁止把新PC贴到旧返回指令上。

### 操作

- [ ] 先用ROM内容0x00500093等已知指令测试AR地址与返回配对。
- [ ] 仅AR/R单拍：ARLEN=0，ARSIZE=2，ARBURST=INCR，ARID=0。
- [ ] 测RRESP错误，正确路径产生取指访问异常；错误路径只排空。
- [ ] 测内部`req_fire`同拍、内部已接单但AR未握手、AR已握手等待R、R同拍及结果槽等待交付等redirect时刻和10次随机延迟seed。
- [ ] 单元探索阶段可先跑10次seed，阶段验收按第20节统一补齐固定seed 1至20。
- [ ] 将结果接IF/ID，运行无访存算术/跳转小程序。
- [ ] 取指已经占用全局互连时，令EX发load并暂停：旧R必须先进入预留槽释放互连，随后LSU获得服务，不形成相互等待。
- [ ] 分支目标/预测目标落入UART等MMIO时，IFU不发AR；正确路径报访问异常，错误路径丢弃fault且外设读副作用为零。

**通过标准：** 每个交给译码的指令和PC正确配对，redirect后没有错误路径退休。

## 10. 原生访存：任务 T04

**新建：** `rtl/core/lsu_axi.v`及其内部`axi_data_engine.v`。**修改：** `ex.v`、`tinyriscv.v`、`retire_ctrl.v`。以下状态表为整体事务流程；AXI通道寄存器在数据引擎内实现，LSU独占CPU操作的完成/异常状态。

### 10.1 EX与LSU内部接口

EX输出一次操作：`op_valid, is_store, address, store_value, access_size, load_unsigned, pc, rd`。

LSU用`op_ready`接收；收到后自行保存。输出`done_valid, load_value, fault, fault_addr`，EX返回`done_ready`。`done_fire=done_valid && done_ready`才释放LSU结果。接口不再有RIB的外部仲裁/组合读假设。

EX每条指令带`issued`位：新指令进入EX清零；`op_fire=op_valid && op_ready`时置1；`op_valid=ex_valid && is_memory && !issued && !precheck_fault`，防止等待期间重复发起。成功完成且提交控制允许时`retire_fire`发生一次；同步异常由`trap_fire`接纳，异常指令不计退休。`ex_leave=retire_fire || trap_fire`，正常离开才允许年轻指令进入EX，trap/redirect则禁止年轻指令同拍进入并执行清除。LSU结果在相应retire/trap接纳时由done_ready消费；前置未对齐异常没有LSU请求，直接由trap路径处理。issued仅在旧指令离开并装入新指令时清零。

### 10.2 读状态机

```text
IDLE -> 捕获一次load -> SEND_AR -> WAIT_R -> DONE -> IDLE
```

- ARID=1，ARLEN=0，ARSIZE=0/1/2分别对应byte/half/word。
- 保存有效地址低2位与有无符号，不能从已经变化的EX输入重新计算。
- R握手成功且响应OKAY后，移位选字节、符号扩展，再发done。
- R错误产生load access fault，不写rd。
- DONE必须保持结果直到EX消费，不能给一个可能被暂停吃掉的脉冲。

### 10.3 写状态机

```text
IDLE -> 捕获一次store -> SEND_AW_AND_W -> WAIT_B -> DONE -> IDLE
```

AW和W分别用`aw_pending`、`w_pending`记录；两者从保存字段独立产生VALID。某通道握手就只清该pending。单拍WLAST=1。两者都被接收后等待B；先返回B的从设备属于错误实现。

写完且收到OKAY才正常退休。BRESP错误产生store access fault；不得自动重试，因为外设可能已发生副作用。

### 10.4 SB/SH/SW：直接改写旧拼接逻辑

设`offset = address[1:0]`：

```verilog
// 下列值在接受操作时算好并保存。
// SB:
wdata = store_value << (8 * offset);
wstrb = 4'b0001 << offset;
// SH，只允许offset=0或2:
wdata = store_value << (8 * offset);
wstrb = 4'b0011 << offset;
// SW，只允许offset=0:
wdata = store_value;
wstrb = 4'b1111;
```

例如原字0x11223344，在base+1执行SB写0xAA：发送WDATA=0x0000AA00、WSTRB=0010，内存变成0x1122AA44。不能先读UART寄存器来保留其他字节。

load先把RDATA逻辑右移`8*offset`，LB/LH对选出的8/16位符号扩展，LBU/LHU补零。窄传输有效字节在哪个lane按AXI地址规则确定；测试模型必须同样按lane处理。

本方案选择对未对齐LH/SH/LW/SW产生同步异常，在发AXI请求前检查，不静默取错字节，也不首版实现跨字拆分。

### 验收

- [ ] 全部LB/LBU/LH/LHU/LW/SB/SH/SW，四个字节lane及合法halfword位置。
- [ ] AW先/W先/同拍，写响应推迟30拍，store只发生一次。
- [ ] load-use、store后load、连续store、存入x0对应数据、load目标x0仍需访问及处理错误。
- [ ] load后紧接ALU、分支、store数据依赖，提交同拍使用新结果旁路；load fault时下一条绝不能进入EX。
- [ ] 未对齐访问不产生任何总线事务；读写错误不错误写回。
- [ ] store等待中请求中断：先处理已发出事务，再在合法边界进入中断。

**通过标准：** 字节scoreboard与CPU寄存器结果一致，AW/W/B计数无多发漏发。

## 11. AXI存储、外设及互连：任务 T05

### 11.1 先做程序RAM/数据RAM

修改`rtl/perips/rom.v`、`ram.v`：

- [ ] 接收AR时保存地址、size、len、id；每拍生成同步存储读地址。
- [ ] 用输出寄存器保持RDATA/RID/RRESP/RLAST，R未消费不能覆盖。
- [ ] AW与第一拍W可以不同时间到达；AW缓存与W缓存分别设计。
- [ ] W握手只表示接收到缓存，不一定此刻写RAM。仅在AW描述符有效、对应W数据已缓存且地址检查通过后，才按WSTRB写一次；缓存占满时拉低WREADY。
- [ ] AW已接受且全部预期W拍已实际处理后才给一次B，检查WLAST与AWLEN一致；不能仅凭W先到或看到WLAST就响应。
- [ ] 支持单拍窄访问及32位INCR补行突发；检查容量、4KiB、拍数、WLAST。
- [ ] 不将整个RAM逐字复位，采用PDS支持的初始化方式，保持BRAM推断机会。
- [ ] 程序加载后恢复CPU运行前，清除I-Cache及预取内容。

### 11.2 外设直接实现AXI4

UART/GPIO/Timer/SPI保留内部功能逻辑，替换总线入口：

- [ ] 捕获AW和W后，只产生一次寄存器写事件；保留旧寄存器偏移。
- [ ] 根据WSTRB更新对应byte，不无条件全字覆盖。
- [ ] AR接受后只读取一次；若寄存器读有清除/FIFO弹出副作用，只执行一次并缓存返回。
- [ ] 单拍服务正常；不允许MMIO预取/突发。错误突发要消费到约定末拍并返回错误，不能随意丢通道造成死锁。
- [ ] 未实现寄存器/权限不符返回SLVERR；UART发送忙的处理沿用软件可见状态，不静默丢字。
- [ ] 写寄存器只读字段不生效；明确是忽略还是SLVERR，并与驱动一致。

原生AXI4从设备不等于所有外设都要实现“图像突发写寄存器”；主端对MMIO使用单拍即可。

### 11.3 第一版互连：简单但正确

新建`rtl/bus/axi_interconnect.v`：

- [ ] 空闲时在所有主设备的AR/AW请求中轮询，保存owner、读写类型、target、ID。
- [ ] 在首次向目标端呈现ARVALID/AWVALID时即锁定grant，不等地址握手才锁；目标READY低期间不得重新轮询或换地址。也可使用一级请求寄存缓冲，但上游接收与下游发送必须各自独立记录。
- [ ] 只对选中的请求拉READY；锁定owner直至读RLAST握手或写B握手。
- [ ] 写owner由AW请求grant锁定，不依赖AW握手完成；选定owner的AW/W独立向下游呈现，不能用`aw_done`门控下游WVALID。主端W可先保持VALID，尚未选定owner时互连可以暂不接收W，但选定后不得等待AWREADY才转发W。
- [ ] AXI4没有WID，不能中途把另一个主机的W数据混进本事务。
- [ ] R/B按保存的owner返回，不按当前地址重新选人。
- [ ] 未映射目标走error slave；读错误仍返回正确拍数与末拍，写错误收完W再返B。
- [ ] 正常或错误响应都必须等完整事务结束才释放owner：读到预期末拍握手，写到B握手；不能首拍RRESP报错就换owner。硬复位按T06协调所有端点，默认值不能制造虚假READY握手。

全局一笔未完成事务会限制吞吐，但逻辑容易验证。后续可以分目标、读写独立仲裁；这属于性能优化，不能在初版同时做多ID乱序。

**验收：** CPU取指与load/store竞争、2个测试主机交错读写、两个主机同时请求且目标AR/AW阻塞20拍、未映射访问、全部通道随机等待，无串包/死锁；UART只输出一次字符。

**新增必测：** 从设备只有看到WVALID才拉AWREADY，互连仍应完成写事务；读burst第2拍SLVERR但其余6拍仍返回时，owner必须保持到第8拍；CPU IF与LSU循环等待用例见T03。无映射读和协议正常的错误burst有界收尾；缺W拍、永不RLAST等违规主/从设备不能承诺“无限流量也恢复”，monitor报协议失败，硬件按协调故障处理。

**T05-I集成门槛：** T02控制单元、T03 IFU、T04 LSU、T05互连/存储各自通过后，再连接CPU并运行真实指令回归、随机等待和错误路径测试；新文件清单不得混入旧RIB。

## 12. 调试下载、错误与复位：任务 T06

不能只改CPU而留下调试主设备的旧总线。

- [ ] `uart_debug.v`：收完一个下载字形成原生AXI写，等BRESP成功才确认/推进地址；若串口不能回压，增加FIFO或软件分块确认。
- [ ] `jtag_dm.v/jtag_top.v`：DMI内存命令转为原生AXI状态机，等待完成再更新结果/状态；不保留RIB端口。
- [ ] 直接访问GPR/CSR只允许CPU已经安全halt；debug写不与CPU提交争抢。
- [ ] halt请求先锁存为`halt_pending`。它立即停止**新取指和年轻指令进入EX**，但“停止新请求”只指尚未属于当前架构指令的新工作，不能禁止当前EX老指令为完成自己而首次发出的load/store/div请求。
- [ ] 当前EX指令若尚未`op_fire`，仍允许它恰好发起一次必要的LSU/除法请求；若已经发出则继续等待完成或报错。halt与`op_fire`同拍时，该请求归当前老指令所有，必须完成，不能因halt把`issued`或AXI状态清零。
- [ ] 已发出的年轻取指继续排空并丢弃，不能送入IF/ID，也不能因错误路径RRESP产生架构异常。只有当前EX完成一次退休或同步异常处理、IFU/LSU/AXI在途事务均收尾、年轻槽位已清空后，才拉`halted`。
- [ ] 恢复PC取最终架构边界的`arch_next_pc`，不能取可能已经超前的`fetch_pc`。当前EX成功退休后保存其下一PC；EX为空时保存最老尚未执行的架构PC。恢复后第一条指令只执行一次，不跳过也不重复。
- [ ] halt时不仅总线空闲，还要使EX在可解释的指令边界完成/报错；无Cache时清年轻预取，有Cache后还需维护debug写数据命中的D-Cache以及I-Cache/BTB。写直达仍可能有陈旧读副本，不能只失效I侧。
- [ ] soft reset同样先排空；硬reset必须协调互连/目标一起复位。DDR继续运行时不能只清主设备。
- [ ] 首版允许编译开关暂禁JTAG/串口下载，用程序RAM初始化代替；禁用状态明确记录，最终恢复后才宣布全SoC改造完成。
- [ ] AXI无通用超时取消。仿真watchdog可以判失败，硬件watchdog只能进入受控故障/协调复位，不能清busy后继续发请求混淆旧响应。

### 12.1 redirect、异常、维护与halt的统一优先级

不要把这些事件分别散落成多个`if`。控制器每拍先确定“当前EX老指令发生什么”，再处理年轻取指。建议优先级与语义如下：

| 优先级 | 事件 | 必须执行的动作 | 不能做的事 |
|---:|---|---|---|
| 1 | 硬复位 | 按系统复位合同同时复位CPU、互连和从设备 | 只清CPU而遗留旧AXI响应 |
| 2 | 当前EX同步异常 | 不退休该指令，原子写trap CSR，`arch_next_pc=mtvec` | 被halt或年轻redirect抹掉异常 |
| 3 | 当前EX的FENCE.I维护完成 | FENCE.I只退休一次，清年轻状态，从自身PC+4重取 | 执行已预取的旧PC+4指令 |
| 4 | 当前EX正常退休及其真实redirect | 完成一次写回/访存效果，更新`arch_next_pc` | 因halt提前撤销当前指令必要请求 |
| 5 | 指令边界接纳异步中断 | 在更老指令完成后写trap CSR并转`mtvec` | 截断不可取消的AXI事务 |
| 6 | `halt_pending` | 阻止下一条年轻指令进入，排空年轻取指；在上述架构事件完成后进入halt | 清除当前EX的`issued`/busy |
| 7 | IFU返回/顺序推进 | 仅在没有更高优先事件且请求仍有效时交付 | 把错误路径fault或旧指令送入流水线 |

halt与当前EX同步异常同拍时，先完成异常CSR更新并把恢复边界设为`mtvec`，随后在执行异常处理程序第一条之前进入halt；恢复后从trap入口开始。halt与当前EX真实分支redirect同拍时，保存真实目标为`arch_next_pc`后停机；恢复后从目标执行。这样debug看到的是明确架构边界，而不是猜测中的fetch PC。

**验收：** 对load和store分别在内部请求握手前、`op_fire`同拍、AXI等待地址/数据响应期间请求halt；检查当前EX操作仍只完成一次，年轻取指不执行，最终能进入halt，恢复后不重复/不漏执行。另测EX为空但旧取指在途的halt、下载程序并读回校验、加载代码后执行新指令、soft reset期间没有遗留响应污染新程序。

## 13. 异常中断与ISA对齐：任务 T07

“完整”必须先限定执行环境：本方案为单核RV32、M模式裸机，无S/U模式、无MMU；是否足够满足赛题“完整”措辞需要队伍向主办方确认。不能宣传支持没有实现的特权模式。

### 13.1 异常矩阵

| 事件 | mcause | mepc | mtval建议值 |
|---|---:|---|---|
| 指令地址未对齐 | 0 | 导致错误目标的跳转/分支指令PC | 错误目标地址 |
| 指令访问错误 | 1 | 实际故障取指PC | 取指地址 |
| 非法指令/非法CSR访问 | 2 | 当前指令PC | 指令编码 |
| EBREAK | 3 | 当前指令PC | 按所选特权规范固定 |
| load地址未对齐 | 4 | load PC | 有效地址 |
| load访问错误 | 5 | load PC | 有效地址 |
| store地址未对齐 | 6 | store PC | 有效地址 |
| store访问错误 | 7 | store PC | 有效地址 |
| M模式ECALL | 11 | 当前指令PC | 0 |
| 软件中断 | 0x80000003 | 下一条尚未执行指令PC | 0 |
| 定时器中断 | 0x80000007 | 下一条尚未执行指令PC | 0 |
| 外部中断/AI完成 | 0x8000000B | 下一条尚未执行指令PC | 0 |

当前`clint.v`实际代码写入cause=0x80000004，不能原样当标准M定时器中断；同时核验mie/mip、MIE/MPIE/MPP、mtvec、mret和CSR只读约束。代码模块名`clint`不代表已经实现标准平台定时器寄存器布局。

### 13.2 中断/CSR与软件共同修改的合同

**拆分任务：** T07a为基础正确性，含RV32I合法译码、同步异常、CSR访问合法性、FENCE及明确的停机/错误处理；T07b为高阶M模式中断与返回完善。T08a基础上板依赖T07a，不能因为T07b尚未全做完就无限延后上板；但未做完时不得宣称完整异常/中断。

- 中断需同时满足`mstatus.MIE`、相应`mie`位与`mip`挂起位。首版明确三个来源：软件pending寄存器、原timer事件锁存、外设聚合pending；分别映射MSIP(3)、MTIP(7)、MEIP(11)。首版同时有效时选外部 > 软件 > 定时器；每类来源/清除由地址表明确，不从旧8位`int_flag`随意取一个cause。
- 新增单拍MMIO窗口`IRQ_CTRL=0x60003000`：0x00 `SW_PENDING` bit0读写，0x04 `EXT_PENDING`读/W1C，0x08 `EXT_ENABLE`读写；仅已实现bit有效，新增外设分配需与C头文件同源。同步并锁存跨域/脉冲事件，W1C与新事件同拍以新事件优先。Timer仍用原寄存器清源；硬件pending由来源决定，不让软件随意写掉仍有效的电平。
- trap入口保存原MIE到MPIE、清MIE、设置MPP=M；MRET按MPIE恢复MIE并设置MPIE=1，M-only的MPP保持合法M值。`mtvec`首版只支持Direct并对不支持MODE执行合法化；`mepc`无C时保持4字节对齐，CSR保留位/read-only/WARL行为列成表。
- CSR写`mie/mstatus`及MRET后立即使用新状态检查pending。EX空且年轻取指被阻塞时，也在有限控制周期内检查；已发出的不可取消store需先收尾，不能靠清AXI FSM抢入中断。同步异常指令不退休，trap CSR更新必须原子可见。
- CSRRS/CSRRC的rs1=x0、立即数版本zimm=0不写CSR；不能用“寄存器读出来为0”代替“编码rs1为x0”。CSRRW rd=x0不读取旧CSR值但仍写CSR；只读CSR的非法写必须异常。
- 当前`init.c`只写mstatus，没有设置mie；标准化后必须显式设置所用mie位并先配置/清中断源，否则旧timer例程会不进中断。当前`trap_handler.c`把全部异步中断送timer函数；改按mcause分发，未注册源进入可诊断停机，不调用空弱符号。
- 当前`trap_entry.S`已区分异步返回，但对所有同步异常直接mepc+4。修订为仅经测试明确允许的ECALL等跳过；访问故障/非法指令记录并停止或交给明确恢复策略，不能静默跳过错误。
- 工具链冻结ISA profile：默认保留已有M算术，裸机CSR另明确Zicsr，FENCE.I若实现则明确Zifencei；I与IM性能分别编译和反汇编核验。不能仅把所有Makefile写成`rv32i`却仍假定CSR汇编和libgcc二进制自动匹配。Zicsr的存在不等同于具备完整特权架构。

**必测：** `mie=0`屏蔽、分别使能三类源、多个源同时挂起、MRET时pending仍在、CSR写使能同拍pending、EX空且取指延迟、中断与分支提交同拍、CSR只读零掩码、trap内再次发生异常的可诊断处理。每例核对cause/mepc/mstatus、源清除和返回后只执行一次。

### 操作

- [ ] 增加/核验`mtval`、`mip`以及已实现CSR；非法访问产生异常，不返回任意零值假装成功。
- [ ] 检查opcode之外的funct3/funct7合法性；禁用的扩展编码必须异常。
- [ ] 用valid=0表示气泡，合法NOP使用`addi x0,x0,0`即0x00000013。
- [ ] 同步异常优先于同条正常提交；先完成更老指令，再处理年轻取指/译码异常。
- [ ] 异步中断在明确架构指令边界接纳，包括EX空时；有load/store/div挂起时按13.2处理，不强行丢弃事务。
- [ ] 修改软件trap入口：不能一律mepc+=4。ECALL测试可以明确跳过；异步中断返回必须恢复原下一PC。
- [ ] 队伍在G0冻结是否支持Zifencei。若支持，FENCE.I必须按下述独立维护指令完整实现；若本阶段不支持，则该编码必须产生非法指令异常，工具链`-march`不得声明/生成Zifencei。禁止“识别了FENCE.I但只跳转或只清一部分缓冲”的半支持状态。FENCE仍等待此前访存完成。
- [ ] 支持Zifencei时，译码区分MISC-MEM的`funct3=000`(FENCE)和`funct3=001`(FENCE.I)，由EX锁存`fence_i_pending`直到维护确认，不能只当普通跳转或只清I-Cache。
- [ ] 选择支持Zifencei时，FENCE.I进入EX后立即阻止年轻`id_to_ex_fire`和新取指；等待此前store的B响应及数据引擎真正空闲；排空并丢弃已内部接单或已发到AXI的旧取指；清IFU返回槽、IF/ID年轻槽、预取/I-Cache及BTB；有在途I-Cache refill时等待其收尾且禁止旧行重新置valid。
- [ ] 选择支持Zifencei时，维护完成后以FENCE.I自身PC+4产生一次架构redirect并重新取指；FENCE.I本身在维护ack后只退休一次，不能被自己发出的flush清掉，也不能让原先已预取的PC+4旧指令执行。首版store等B才退休，因此通常不存在旧写缓冲；以后若增加写缓冲，FENCE.I必须同时等待其可见性。
- [ ] 选择支持Zifencei时，定向测试必须使用明确允许D侧写且允许I侧取指的测试RAM区域，不能在只读ROM或MMIO上伪造。先让旧版目标指令进入预取/IF槽，再由前序store把FENCE.I之后的目标指令从`addi x1,x0,1`改为`addi x1,x0,9`；执行FENCE.I后最终x1只能为9，并检查旧版指令退休次数为0、FENCE.I退休次数为1。
- [ ] 对CSR立即数指令、x31、JALR最低位清零、无C扩展的4字节目标对齐分别写测试。

**验收：** 每种事件都有触发程序、期望cause/epc/tval、返回后校验；中断与AXI响应同拍时仍只执行一次store。

## 14. 原生AXI首次上板与基础交付：任务 T08a/T08b

前置：T00-P平台核验、T01、T05-I集成及T07a通过；T06最小安全halt/reset通过即可，JTAG/在线下载允许关闭。T08a先验算术/RAM/UART/GPIO及基础CoreMark；T07b与软件配套通过后做T08b中断上板。无需先有DDR、Cache、摄像头。

T08a若尚无T07b，启动软件显式保持`mie=0`、`mstatus.MIE=0`且外部源关闭；同步异常仍走T07a的可诊断路径。不能照搬原`init.c`默认开全局中断后声称使用“关闭中断的基础配置”。

- [ ] 新建`fpga/pango/pango_top.v`，精确芯片型号以板卡标识/工程资料核对，不凭系列名选择。
- [ ] 只加入当前使用源码；原`rib.v`不在综合文件清单。
- [ ] 按板卡原理图约束时钟、复位、UART、GPIO；GPIO要真正作为顶层引脚引出。
- [ ] CPU/AXI初版同钟；PLL锁定后同步释放复位。不要直接照搬Xilinx PLL/BRAM原语。
- [ ] 确认片上RAM被映射到预期存储资源，初始化文件进入综合/配置流程。
- [ ] T08a用自检程序：算术 -> RAM读写 -> UART打印 -> GPIO翻转；T08b再验定时器/软件/外部中断。
- [ ] 建立真实`create_clock`周期、生成时钟和必要I/O约束；不能通过把所有路径设false path来“过时序”。
- [ ] 保存综合报告、布局布线后setup/hold报告和未约束路径检查。
- [ ] 使用PDS/板卡支持的片上逻辑分析工具抓PC、valid、retire、stall、AR/R/AW/W/B；按赛题ILA波形要求整理等价硬件观测证据。
- [ ] T13a在此执行第一份有效CoreMark：实际计时>=10秒、规定种子CRC正确，并抓取CoreMark算法区间的流水线波形，不用LED或任意程序波形替代。记录分析工具、插桩资源以及插桩前后时序变化。

**通过标准：** 原生AXI4 CPU在紫光板上可重复运行，B1/B2/B3及首次有效CoreMark有证据。基础应用先做串口配置的GPIO采集/控制演示，报告实际控制/采样延迟；不把它冒充AI加速。尚不能宣称高阶项或全赛题已完成。

## 15. 两路I/D Cache及突发：任务 T09

若申报完成赛题H1，两路指令Cache和两路数据Cache都要有；仅添加AXI接口或仅实现I-Cache不能声称满足H1。H1本身不是基础B1-B3的先决条件。

### 15.1 参数选择

每个Cache：2路 × 32组 × 32字节/行 = 2048字节。I+D数据部分共4KiB，另有tag/valid/替换状态资源。

32位地址拆分：

```text
tag        = address[31:10]   共22位
set_index  = address[9:5]     共5位，32组
byte_offset= address[4:0]     共5位，32字节/行
word_index = address[4:2]     共3位，每行8个字
```

每组2个tag和valid；1位LRU足够表示两路中优先替换谁。先用无效路，再替换LRU路。

### 15.2 I-Cache

- [ ] CPU给PC后同步查两路tag/data，命中返回对应字与原PC。
- [ ] 缺失保存地址/组号/替换路，行首`address & 32'hFFFFFFE0`。
- [ ] 发8拍INCR读，ARLEN=7、ARSIZE=2；每次R握手写一个word。
- [ ] 全行响应正确才设置valid并交付请求；中途错误清该行valid并传播取指故障。
- [ ] refill中redirect：继续接完总线，可以保留成功cache行，但不给错路指令提交。
- [ ] FENCE.I/代码下载后失效；在途refill也不得把刚失效的旧代码重新标有效。
- [ ] 代码更新同时失效相关BTB项及预取；debug写可缓存数据时，在安全halt下失效D侧对应行或全Cache。

### 15.3 D-Cache：首版选写直达、不写分配

这是降低复杂度的明确方案：读缺失8拍补行；写命中更新已有行，写缺失不补行；所有store都发单拍AXI并等B。无dirty位，无写回缓冲。

- [ ] 只缓存正常内存，MMIO与共享DMA缓冲绕过。
- [ ] store先保留待写数据；B成功后才更新命中cache行，失败则失效该行并异常。
- [ ] MMIO load/store不做cache填充，不能把UART读8次当一次补行。
- [ ] Cache失效操作只在无未完成数据事务时执行。
- [ ] CPU与DMA的第一版共享缓冲采用不可缓存区，避免读到旧数据。
- [ ] 不可缓存范围在T11确定DDR容量后写成具体base/limit，与链接脚本、内存分配器及DMA范围检查同源；按Cache行对齐，禁止同一物理缓冲另有可缓存别名。运行中不随意切换属性。

写直达并不意味着不满足“两路D-Cache”；但单拍store没有写回突发效率，优化报告应如实说明。需要更高性能时再设计写回Cache，不能混用两套一致性规则。

### 测试

- [ ] 读A、读B、再读A：A和B落同组不同tag，都应命中保留。
- [ ] 再读第三个同组地址C：验证LRU替换正确。
- [ ] 32字节行边界前后、4KiB边界附近访问。
- [ ] refill每拍随机延迟、R错误、redirect/失效与最后拍重合。
- [ ] store失败不在Cache内留下“成功值”。
- [ ] Cache开/关执行同程序得到相同结果，记录miss次数与周期。

**通过标准：** 两路冲突测试、随机读写scoreboard、CPU指令回归全部通过；板上能抓到ARLEN=7及8次R握手。

## 16. 动态预测：任务 T10

新建`rtl/core/branch_predictor.v`；选32项直接映射BTB，每项保存valid、完整tag、target、类型、2位饱和计数器。

- [ ] BTB索引PC[6:2]，tag=PC[31:7]；禁止只比索引不比tag。
- [ ] 条件分支计数器00/01预测不跳，10/11预测跳；取决于实际分支结果加减并饱和。
- [ ] BTB命中且预测跳，取target；否则PC+4。已学习无条件跳转使用其target。
- [ ] 保存每条指令的predicted_next_pc到EX，比较真实next_pc决定是否清年轻阶段。
- [ ] 在指令真实完成的边界更新一次，不训练被flush的指令。
- [ ] 错路在途AXI取指按T03排空，不能撤销握手。
- [ ] 测全跳、全不跳、交替、循环退出、同索引不同tag、目标变化JALR。

**通过标准：** 预测开/关架构结果完全相同；报告预测命中率、错预测代价、CoreMark变化，不能仅宣称“加入BTB所以更快”。

## 17. DDR接入前置核验：任务 T11（硬关卡）

### 17.1 已查到的真实限制

本地板卡示例：

`E:\daiduwangpan\盘古100Pro+开发板（MES2L676-100HP）配套资料\7_FMC扩展子卡及Demo\2_Demo\HDMI_DDR3_OV5640_100H\source\rtl\DDR3_50H\DDR3_50H.v`

该生成文件标注IP Generator 2022.1，实际接口有4位AxLEN和256位数据（默认MEM_DQ_WIDTH=32），但没有标准AXI4的WVALID输入、RREADY输入和完整BVALID/BREADY/BRESP通道；还有`axi_wusero_last`等专用信号。

**因此不能把这个示例直接当标准AXI4 Slave。名称中有axi不等于完整标准接口。**

### 17.2 必须完成的核验表

- [ ] 在已安装PDS中找到该型号支持的DDR IP文档和生成界面。
- [ ] 向厂商核对是否有该器件可用、带完整AXI4通道的控制器版本。
- [ ] 导出真实端口表：地址单位是byte还是word、数据宽度、最大burst、响应与回压规则、ID、时钟、校准完成、字节mask极性。
- [ ] 确认支持窄访问/非全字节写，或必须在存储子系统内部处理宽度。
- [ ] 明确写完成的定义；不能用AW握手、WREADY或`wusero_last`猜测标准B响应语义。
- [ ] 保存厂商答复或对应手册页到`docs/evidence/ddr-interface/`。

### 17.3 三种结果

1. **存在合适的原生AXI4 DDR控制器：** 使用它，处理总线宽度/CDC，继续下一项。
2. **只有非标准用户口，但允许在DDR子系统内设计原生AXI4前端：** 需要队伍明确同意该边界。它不是RIB桥，但确实包含DDR接口适配，不能偷偷叫“完全无协议适配”。
3. **要求整个系统连DDR边界也绝不适配，且无原生IP：** DDR路线阻塞。继续用AXI4 BRAM完成CPU/Cache/基础比赛证据，不能承诺按该限制完成DDR+YOLO。

当前设计明确禁止RIB桥；本计划不擅自批准第2种结果。若选择第2种，必须另写基于实际DDR手册的前端详细计划，不能凭当前信号名生成RTL。

“禁止RIB桥”与“禁止一切DDR适配”是两项不同选择，不要合并。以降低返工为目标，建议队长允许经验证的DDR前端/位宽/CDC适配，同时保留CPU与系统主干原生AXI4。此建议需队伍确认，不把建议写成已获批准，也不把自定义外设直接AXI化推广成相机必须讲AXI。

### 17.4 通过关卡后的接入步骤

- [ ] 先独立跑厂商DDR校准及数据读写例程，确认板卡、DDR时钟、复位。
- [ ] 用AXI测试主机写/读地址自增、全0/全1、walking-bit、固定seed随机图样，覆盖实际容量边界。
- [ ] 解决32位CPU与实际DDR端口宽度，不截断高位。优先使用厂商已验证同协议宽度转换/互连组件；它不是RIB协议桥，但需如实记录。
- [ ] 不同域通过经验证的AXI CDC组件或事务FIFO，不能对宽总线每bit打两拍。
- [ ] `ddr_init_done`之前不接受访问，或由系统启动流程明确等待；不把未校准数据返给CPU。
- [ ] CPU先测试不可缓存DDR读写，再打开Cache；写程序到DDR后刷新I侧再跳转执行。

**通过标准：** 数据校验、字节mask、突发、回压、CDC、校准等待均通过，并有本板实测日志。

## 18. OV5640与YOLO软硬件协同：任务 T12

这部分分小项目完成，不在CPU总线还没稳定时同时调试。

### 18.1 摄像头

- [ ] 参考现有`HDMI_DDR3_OV5640_100H`采集例程，只复用已读懂且验证过的相机配置/采集部分，不照搬其非标准DDR事务。
- [ ] 先采集彩条/固定测试图，验证像素格式、宽高、行有效、帧有效、字节顺序。
- [ ] OV5640的DVP不是AXI；采集模块通过异步FIFO进入系统域，再由原生AXI4 frame DMA写内存。
- [ ] FIFO满时明确丢弃整帧并计数，不能静默丢几个像素后仍标帧有效。
- [ ] 双缓冲状态FREE -> FILLING -> READY -> PROCESSING -> FREE，CPU不得把DMA正在写的帧给AI读。
- [ ] 帧READY只能在最后一笔内存写响应成功后发布。
- [ ] 先串口输出校验和/抽样像素，再增加HDMI显示；显示不是完成B1-B3的前置条件。

### 18.2 YOLO模型冻结关卡

不能现在凭模型名字保证适合。第一轮实验由CPU/软件与AI负责人完成：

- [ ] 固定一个YOLO变体、输入分辨率、类别表、算子清单和权重校验值。
- [ ] 使用有目标框标注的垃圾数据；只有整图类别标签的数据不能直接当目标检测标注。
- [ ] 划分训练/验证/独立测试集，避免同场景近重复图片泄漏。
- [ ] 先电脑运行浮点结果，再INT8量化模拟，记录精度损失。
- [ ] 导出每层输入/输出、scale、zero point、饱和/舍入规则，作为RTL黄金数据。
- [ ] 计算权重总字节、峰值中间张量、帧缓冲和代码所需空间，以及每帧MAC数量。
- [ ] 根据实际DDR/BRAM/DSP资源判断是否放得下；资源不够则缩小输入/模型或分层复用，不强行宣称实时。
- [ ] “垃圾检测”只是应用候选，不是选题一硬性类别；队伍明确场景后再冻结类别/数据集。另记录CPU软件回退算子的时间预算、相机写流量、权重/特征图流量及DDR实测持续带宽，不仅检查容量。
- [ ] 32位系统总线每秒有效数据上限按实际数据握手拍数计算，不能用DDR芯片标称带宽代替。单事务互连下CPU控制寄存器写、DMA读和DMA写也互相竞争；先做离线单帧，再决定是否增加并发。

模型版本、算子及DDR接口未冻结前，本节是工作分解与验收要求，不是可直接复制的完整YOLO RTL实现。最终模型不确定时编造每层硬件代码会误导实施。

### 18.3 加速器最小实现

首个计算核从INT8乘加开始：有符号INT8输入/权重、INT32累加；根据模型量化规则再缩放、舍入、饱和。不要先加自定义CPU指令。

建议复用少量MAC做分块卷积，由CPU配置每层参数；普通运算仍由CPU执行。原生AXI4数据主接口负责读权重/特征图和写结果。

AI控制寄存器方案：

| 偏移 | 含义 | 规则 |
|---|---|---|
| 0x00 CTRL | bit0启动 | 写1产生一次启动；BUSY时拒绝重复启动 |
| 0x04 STATUS | bit0 busy，bit1 done，bit2 error | done/error写1清除，不能读即清除 |
| 0x08 INPUT_ADDR | 输入张量地址 | 启动时锁存 |
| 0x0C WEIGHT_ADDR | 权重地址 | 启动时锁存 |
| 0x10 OUTPUT_ADDR | 输出地址 | 启动时锁存 |
| 0x14 DESC_ADDR | 层参数描述符地址 | 启动时锁存，CPU已完成描述符写入 |
| 0x18 IRQ_ENABLE | 完成中断使能 | 可读写 |
| 0x1C ERROR_CODE | 总线/参数/计算错误 | 只读 |

描述符字段需随冻结模型确定：宽高、输入输出通道、kernel、stride、padding、量化参数；对应C结构与RTL偏移生成同一份定义，不能手工维护两套不一致版本。

CPU流程：

```text
等完整帧 -> 配置张量/层参数 -> FENCE -> 启动AI
-> 等完成/中断 -> 检查错误 -> 读结果 -> 后处理/NMS -> 输出类别和框
```

DMA必须支持1至16拍INCR，按4KiB切块；不足整字的尾部用WSTRB，读端多读出的无效byte不参与计算，且不得跨分配边界/设备窗口。共享帧、输入/输出张量和描述符首版全部不可缓存，范围按T11冻结；非共享权重可只读缓存，但更新时遵守维护协议。B未完成之前不发AI DONE。启动MMIO需在锁存参数或报告BUSY错误后及时返回B，不能等整个计算完成才返回，否则全局单事务互连会阻塞加速器自己的DMA。

CPU启动前使用编译器内存屏障及明确的`fence iorw,iorw`，观察完成后再次执行相应顺序屏障再读结果；FENCE不是Cache失效指令。CPU/AI/相机/可选显示不能同时写同一缓冲，显示若仍在读该帧，不得将其提前标FREE。发生帧丢弃或AXI错误时，排空在途写并将该帧标无效，不发布半帧READY。

### 验收顺序

- [ ] 一个MAC的正负数、极值、累加边界。
- [ ] 一个小矩阵/卷积与软件逐元素一致。
- [ ] 一层量化卷积与电脑黄金输出一致。
- [ ] 单张预置图片完整YOLO路径，包括未加速算子的软件回退。
- [ ] 相机帧输入；记录精度、单帧总延迟和加速部分延迟。
- [ ] CPU-only基线与CPU+加速器使用相同模型、输入、精度设置；报告端到端加速比，不用单层MAC吞吐代替它。

## 19. CoreMark、性能和交付：任务 T13

拆为T13a基础跑分（紧接T08a）、T13b每次Cache/预测器改造后的同条件复测、T13c最终性能/应用报告。不再等T10完成才第一次运行CoreMark。

- [ ] 使用CoreMark v1.0；核心算法不因“提分”修改，仅调整允许的移植层/迭代次数。
- [ ] 保存所用CoreMark源码版本与哈希；按EEMBC Run Rules核验性能种子`0,0,0x66`及验证种子`0x3415,0x3415,0x66`、总数据区2000字节与全部CRC。只跑一次PERFORMANCE_RUN并看到一个CRC不足以完成规则核验；调试短跑不列为有效成绩。
- [ ] 使用指定工具链，记录`-march/-mabi/-O`、链接脚本、代码执行在BRAM还是DDR、Cache与预测器状态。
- [ ] RV32I基线和启用M扩展配置分开报告；不要把M扩展带来的收益混称RV32I流水线收益。
- [ ] 用板上实际运行频率填写`CPU_FREQ_HZ`；计时计数器在CPU暂停时仍正常增长。
- [ ] 测试有效运行时长>=10秒且校验CRC通过；总循环周期和计数器溢出正确处理。
- [ ] 32位cycle在高频长运行时可能回绕；采用64位计时或明确验证差分上限。读64位counter采用高-低-高一致性读取。
- [ ] 当前`lib/utils.c:get_cycle_value()`是低后高各读一次，跨回绕会读出不一致值；在实施副本改为高-低-高重试，并用计数器接近0xFFFFFFFF的定向测试验收。`include/utils.h`当前写死50MHz，必须与本板运行配置同源。
- [ ] `core_portme.c:time_in_secs()`当前把`ticks/256`截到32位，不能仅因为硬件cycle是64位就认定任意长测试正确；记录可测上界或改移植层为不会溢出的换算，并用合成tick值验证。
- [ ] 同配置重复测量，保留完整UART日志，不只截最后一个分数。

统一公式，Frequency以MHz计：

```text
CoreMark       = iterations / seconds
CoreMark/MHz   = iterations / seconds / frequency_MHz
CoreMark/LUTs  = iterations / seconds / LUT_count
```

报告最高频率以布局布线后满足约束的结果为准，不把PLL设置值或仿真时钟当Fmax。

资源统计分别报告CPU核、CPU+总线/Cache/BRAM接口、完整应用系统，并明确片上分析仪开关。主比较使用同一资源边界、同一频率及编译配置；另列各配置实际通过时序的最高频点。AI/DMA/相机是否运行必须记录，不能用空闲C3与满负载C4直接归因于CPU优化。

建议比较配置：

| 配置 | AXI | Cache | 预测 | 用途 |
|---|---|---|---|---|
| C0 | 原RIB基线 | 无 | 无 | 原代码参考，不混入最终原生AXI源码清单 |
| C1 | 原生AXI4 | 无 | 无 | 正确性及性能代价 |
| C2 | 原生AXI4 | 两路I/D | 无 | Cache收益 |
| C3 | 原生AXI4 | 两路I/D | 动态 | 预测收益 |
| C4 | C3系统 | 同C3 | 同C3 | 加AI后的资源与应用结果 |

性能计数器：cycle、instret、load/store等待周期、取指等待周期、I/D hit/miss、预测次数/错误次数、AXI有效数据拍数。计数条件必须有定义，不能把stall气泡当退休指令。

交付目录建议：

```text
docs/
  requirements.md           赛题编号与证据映射
  architecture.md           CPU/AXI/Cache/AI结构
  address_map.md            寄存器地图和驱动约定
  axi_profile.md            支持的AXI能力与限制
  test_report.md            用例/seed/工具版本/结果
  performance_report.md     CoreMark、时序、资源、AI对比
  evidence/                 UART日志、波形、板上抓取、工具报告
rtl/ sim/ tb/ tests/ fpga/   可重建源码与工程
```

## 20. 每阶段测试清单

| ID | 刺激 | 必须看到的结果 |
|---|---|---|
| AX01 | ARREADY低10拍 | ARVALID和全部AR字段不变 |
| AX02 | AW先、W先、同拍 | 一次写入、一次B |
| AX03 | RREADY/BREADY低7拍 | 响应负载保持，无丢失 |
| AX04 | 8/16拍突发随机间隔 | 只在握手计数，末拍准确 |
| AX05 | 请求接近4KiB边界 | DMA拆分，不产生跨界burst |
| AX06 | 无效地址/越界 | DECERR/SLVERR，不死锁 |
| AX07 | 从设备等WVALID才给AWREADY | AW/W独立前进，不相互等待 |
| AX08 | burst中途RRESP错误 | 收完剩余拍后释放owner，不串到下一事务 |
| CP01 | load返回晚20拍 | 后续相关指令不使用旧值 |
| CP02 | store响应晚30拍 | 内存/外设副作用一次 |
| CP03 | 分支时取指未完成 | 旧响应排空，错路不退休 |
| CP04 | div等待同时中断 | 不重复启动、不丢rd、合法边界trap |
| CP05 | 非法指令/未对齐/总线错误 | cause/epc/tval正确 |
| CP06 | IF占总线且EX等待LSU | IF返回可进入预留槽，随后LSU得到服务 |
| CP07 | 错路/正确路径PC指向MMIO | 均无外设AR副作用；只正确路径进入trap |
| CP08 | MRET/CSR更新使能且中断pending | 按新CSR状态重判，返回PC与使能状态正确 |
| CA01 | 同组A/B/C反复访问 | 两路及LRU可解释 |
| CA02 | refill中错误/flush | 无半行有效、无错路异常 |
| CA03 | DMA写共享区CPU读取 | 不读取陈旧Cache副本 |
| DB01 | busy时halt/reset | 已接受事务不遗失 |
| DB02 | halt后debug写已缓存数据/代码 | D/I/BTB维护后重启可见新内容 |
| HW01 | PDS综合布局布线 | 资源合理、时序与约束核验通过 |
| PF01 | CoreMark>=10秒 | CRC正确，频率/时间/迭代可复核 |
| PF02 | cycle低位回绕时读取时间 | 高-低-高重试，时间差无伪跳变 |
| AI01 | 同一图片软硬件推理 | 数值/精度达预先冻结标准 |
| AI02 | 启动寄存器写与AI请求DMA | 启动B及时返回，DMA不被自己阻塞 |

每个用例至少一次确定性测试，再用固定seed 1至20做随机回压。回压随机测试需要最终公平性约束，例如每通道最多连续阻塞31拍，否则测试可能制造永远不响应而不是找设计bug。

## 21. 新手每天怎样按这份计划做

不要一次打开二十个文件。每天只做一张任务卡：

```text
任务编号：T03-AR稳定性
今天只改：ifu_axi.v 和 tb_ifu_axi.sv
先看懂：ARVALID表示地址已准备好；ARREADY表示对方接收
先写测试：READY低10拍，检查VALID与地址不变
先看失败：旧逻辑不能通过
再修改：保存请求地址，握手后才清VALID
再运行：同一用例通过，随后跑已有回归
记录：改了什么、哪张波形、测试seed、是否通过
提交：只提交相关文件
```

遇到错误按层查：

1. 编译不过：先看端口/位宽/文件清单，不上板。
2. 总线卡住：查五个通道哪个握手没完成、owner是谁。
3. 指令错：查请求PC、返回PC、valid、retire，再查译码。
4. 仿真过但上板错：查复位、BRAM读延迟、时序、CDC、管脚。
5. AI结果错：用单层黄金输出定位，不先跑整套相机系统。

## 22. 依赖顺序、分工和停止条件

```text
G0来源/范围确认 + T00基线 + T00-P早期PDS核验
T01独立AXI平台可并行 -> T02槽位/提交单元测试
-> T03取指 / T04访存 / T05互连与存储分别测试
-> T05-I完整CPU集成 -> T06最小halt/reset + T07a ISA/同步异常
-> T08a基础上板 -> T13a有效CoreMark与基础应用
-> T07b中断及软件 -> T08b中断上板
-> T09两路Cache -> T13b复测 -> T10预测器 -> T13b复测

T06完整JTAG/在线下载可后置；若不交付则明确裁剪，不冒充全SoC改造

T11 DDR接口核验应尽早并行做；DDR实际接入在总线稳定后进行
T12模型离线冻结可并行；摄像头/AI系统集成依赖T11与AXI回归
-> T13c最终报告/应用测量
```

建议分工（不是强制）：

- 你：PC/握手学习、IFU测试、AXI RAM/GPIO、PDS基础上板，之后做摄像头控制。
- 队友：流水线提交/LSU/异常边界/互连审查，随后Cache与性能。
- 一起：每周复盘波形、模型资源预算、CoreMark日志；互相能解释对方的端口和状态机。

不承诺几天必成。每个任务以测试通过为结束标准，DDR IP不兼容、许可证不可用或模型放不下都可能改变日程。

停止进入下一阶段的情况：

- 原始CPU基线没有可复现结果。
- AXI随机等待会重复写外设。
- 已接受事务被flush/halt直接清状态、不排空协议，或其结果仍被错误提交；正确做法是事务继续收尾，按所有者决定交付或丢弃。
- DDR接口尚未核验，却开始按“标准AXI4”硬连。
- 基础RV32I/中断没通过，却开始凭CoreMark截图宣布符合比赛。
- 只有单层卷积成功，却宣布YOLO移植成功。

**裁剪规则：** 板卡/许可证/基线不通，先停止CPU大改；T08a/T13a未闭环，不把相机+YOLO设为当前集成任务；DDR或模型关卡不通过，保留已验收CPU成果并如实标AI未完成，不用CNN学习样例顶替。详细排期由队长在G0填写，不虚构完成天数。

## 23. 开工前确认单

- [ ] 同意CPU/外设原生AXI4，不保留RIB，不建RIB桥。
- [ ] 同意32位数据、4位ID、首版全局单事务、后续8/16拍INCR。
- [ ] 同意先完成基础赛题证据，再加两路I/D Cache、预测器和AI。
- [ ] 确认DDR边界“不使用桥”是否也禁止厂商IP用户口适配；在T11事实核验前不承诺。
- [ ] 确认本次只交付计划，后续从T00逐步修改，不一次性覆盖原工程。
- [ ] 确认G0开源来源与队友贡献核对、T00-P平台前置，以及T13a在Cache/预测器之前验收。
- [ ] 确认3.5 CPU/Cache合同、3.6前进性约束、13.2中断软硬件合同；它们是本轮提出的修订，尚不等于团队已签核。

## 24. 资料与证据边界

1. 赛题：本地PDF第10-11页，已提取核对；本计划是与这份文件对齐，不声称在线核验了之后的新通知。
2. 原代码：上述源码目录，已读取接口、控制、访存、存储、调试、编译脚本；未实际运行。
3. DDR：上述`DDR3_50H.v`真实端口已读取；PDS其他版本/IP可用性未核验。
4. 协议实施须以Arm AMBA AXI/ACE Protocol Specification（IHI 0022中AXI4章节）作规范依据；接口profile需要在编码前逐项签核。
5. ISA与异常实施须以RISC-V Unprivileged及Privileged Architecture的冻结版本为依据，并在报告记录版本。
6. 本轮内置网页检索未返回可用结果；随后直接读取了RISC-V官方仓库`src/priv/machine.adoc`的中断检查条款及EEMBC/CoreMark官方README的Run Rules，仅用于技术交叉核对，不替代赛题。Arm在线规范请求未成功，AXI细节仍需在实施前用冻结的IHI 0022版本复核；没有声称已核验最新赛事通知。
7. 本计划给出决策、文件边界、状态机、关键代码模板、测试刺激与验收标准；它不是数千行完整可编译补丁。CPU改造任务可逐步展开；DDR与具体YOLO层级实现必须先通过各自资料/模型冻结关卡。

**当前停在计划评审：队伍先确认本轮修订和G0范围。获准进入实施后，首先执行T00/T00-P，建立不破坏原工程的基线与平台证据；本轮不执行任何RTL改造。下列新增章节将前面的任务展开为具体方法。**

## 25. 小白阅读法、术语与修改纪律

### 25.1 先分清四类东西

| 名称 | 人话 | 本项目例子 |
|---|---|---|
| ISA | 软件说什么话、每句是什么意思 | `addi x1,x0,5`令x1变成5；与使用何种总线无关 |
| 流水线 | 多条指令分阶段工作 | 本项目IF取指、ID译码、EX执行；EX也负责等待内存/除法，不强改五级 |
| AXI | 不同模块如何发请求、等待及收结果 | 发读地址AR，然后收到读数据R；两者不要求同一拍 |
| Cache | 保存近期用过的内存副本 | 命中不用外部读，缺失才用AXI补32字节一行 |
| retire | 一条指令已经成功完成、正式记账 | 成功load写寄存器一次；错误load不退休而进入异常 |
| trap | CPU转去处理错误或中断 | 保存故障PC/原因，跳到软件处理入口 |
| BFM/scoreboard | 测试台里的模拟设备/对账本 | BFM故意晚20拍返回；scoreboard检查没有多写字节 |

学习次序固定：**先解释语法 -> 再看原代码 -> 再看改后人话 -> 最后用一条具体指令验证**。遇到还不懂的下一模块先暂停，不靠一次改完全部文件碰运气。

### 25.2 最小Verilog语法

```verilog
wire fire = valid && ready; // 两边同一上升沿为1才接受一次
always @(posedge clk) begin
    if (!rst_n) valid_q <= 1'b0;
    else if (flush) valid_q <= 1'b0;
    else if (load_en) begin
        valid_q <= in_valid;
        if (in_valid) data_q <= in_data;
    end
end
```

这是语法片段，不是独立文件。`wire`是连接/组合结果，`reg`是过程赋值变量；`[31:0]`是32位；`<=`在时钟沿描述寄存器更新，不能按软件逐行立即生效理解。`always @(*)`组合逻辑先给所有输出默认值，避免意外锁存器。`4'b0010`只有第二个字节通道有效；`32'h10000000`是32位十六进制地址。

原工程`rst`实际上低有效，`defines.v`明确`RstEnable=0`。新模块统一叫`rst_n`，连接`.rst_n(rst)`，绝不能因为旧名字没n就再取反。先保持同一个时钟；异步传感器/DDR另做CDC，不把多位总线每bit打两拍当协议转换。

### 25.3 文件角色与禁止事项

- 原始只读参考：`E:/donwload/tinyriscv-master/tinyriscv-master`。
- 经批准后才创建实施副本：`E:/file/pango/tinyriscv_axi4`。本轮没有创建它。
- 本文所有`rtl/...`、`tests/...`、`sim/...`新建/修改路径均以实施副本为根；不是去另一个YSYX目录修改。
- **完整模板**可保存成所标文件再单元测试；**集成片段**只替换标出的连接或分支，不能整段覆盖已有模块；**状态表**必须落实为寄存器/FSM并按指定用例验证，不是“已经写好的RTL”。修改原文件保留其已有版权和来源说明，新文件记录真实贡献，不把本计划模板标为既有上游代码。
- 不全局替换gen_dff，不一次删掉旧代码，保留独立基线编译清单；新SoC文件清单排除RIB，旧基线清单仍保留RIB。
- 每张卡完成时记录：改过的文件、编译日志、PASS/FAIL、seed、关键波形和尚未解决的问题。未通过不打勾，不把旧VCD当本次结果。

## 26. 建议新增功能与实际执行顺序

### 26.1 我的建议：先做看得见原因的CPU，再追求更多功能

| 建议 | 为什么值得做 | 实施位置 | 取舍 |
|---|---|---|---|
| 退休事件轨迹 | 比“最后寄存器错了”更快定位第一条错误指令 | 28.3；仿真记录PC/rd/值/异常 | 必做验证设施，不宣称ISA认证 |
| 性能快照寄存器 | 解释CoreMark为何快/慢，直接支撑分析报告 | 32.1；先cycle/instret，再等待与命中计数 | 推荐，先不加复杂可编程事件 |
| 小型GPIO边沿采集/控制应用 | 不依赖DDR和AI也能演示CPU真实控制外设 | 32.2；先轮询再中断 | 推荐基础应用，不代替高阶AI |
| 配置对照开关 | 同一软件比较Cache/预测开关的正确性和性能 | 31与32；综合时固定开关 | 推荐，先不实现危险的运行时切换 |
| 调试错误状态 | 访问错地址时给出PC/地址/cause，不直接死机无信息 | 30；CSR及串口错误日志 | 基础路径必须可诊断 |
| 更宽DMA/更多并发 | 带宽测量确认瓶颈后才投入 | 33 | 后置，先验证单事务路径 |
| 自定义指令/操作系统/五级改造 | 与当前问题关系较弱、会扩大验证范围 | 本轮不安排 | 不建议为“看起来高级”而加 |

这些建议来自项目目标与现有结构，不是额外赛事硬性要求；队长可以裁剪可选应用，但不能裁掉正确性验证。

### 26.2 任务卡执行图

```text
N00 基线工具与副本 -> N01 原CPU新编译回归
N02 pipe_slot独立模块 -> N03 退休门控/译码/除法adapter
N04 单拍AXI读引擎 / N05 单拍AXI写引擎 / N06 RAM+GPIO从设备
N07 IFU与LSU / N08 互连 -> N09 全CPU集成与错误路径
N10 ISA/同步异常+基础软件 -> N11 基础上板+CoreMark
N12 中断软硬件 -> N13 I/D Cache -> N14 动态预测
N15 性能快照及GPIO应用
N16 DDR和模型事实冻结 -> N17 DMA/完整单帧AI
```

映射：N00-01=T00，N02-03=T02，N04-08=T01/T03/T04/T05，N09=T05-I，N10=T07a，N11=T08a/T13a，N12=T07b/T08b，N13=T09，N14=T10，N15=T13及推荐应用，N16-17=T11/T12。T06安全halt/reset穿插于N09-11，完整调试下载可以后置。每张卡先看相应原章节约束，下面是操作说明，不是第二套架构。

### 26.3 每张卡的完成单

1. 在Git副本建独立提交点，写出本卡唯一目标及旧行为。
2. 先写会失败的最小测试；模块未创建导致编译失败是第一步，但之后还要证明测试能发现故意植入的行为错误。
3. 只改本卡列出的文件；若需要新接口，同一次提交修改模块、实例和测试台。
4. 跑单元定向测试，再固定seed 1-20；CPU集成阶段再跑已有47个`.bin`及新增异常/时序用例。
5. 保存证据；检查新增warning中的多驱动、截断、锁存器、未连接端口，不用“warning很多但能跑”跳过。

## 27. N00/N01：第一份可复现基线怎么做

### 27.1 准备副本，不覆盖任何已有目录

以下是未来执行命令，不是本轮已经执行的操作：

```powershell
$src = 'E:\donwload\tinyriscv-master\tinyriscv-master'
$dst = 'E:\file\pango\tinyriscv_axi4'
if (!(Test-Path -LiteralPath $src)) { throw 'Source missing' }
if (Test-Path -LiteralPath $dst) { throw 'Destination exists; inspect it first' }
Copy-Item -LiteralPath $src -Destination $dst -Recurse
Set-Location -LiteralPath $dst
git init
git add .
git commit -m "chore: preserve original tinyriscv baseline"
if ($LASTEXITCODE -ne 0) { throw 'Baseline commit failed' }
Get-Command vsim,vlog,vlib,python
```

首次Git若提示身份未配置，按队伍真实身份配置后重试，不随便写其他人的姓名邮箱。已存在团队仓库就沿用它，不再次初始化。已复查本机`vlog -version`输出ModelSim SE-64 10.6e；这只证明编译器可启动，不代表仿真许可证、CPU测试或PDS已通过。当前PATH仍未发现iverilog/vvp，默认先走ModelSim，不假装两者已安装。

### 27.2 原脚本的风险，先修测试入口再改CPU

源码`sim/test_all_isa.py`只查TEST_PASS，零个bin也可能报告All PASS；`compile_rtl.py`未检查编译返回码，`sim_new_nowave.py`超时不杀仿真。**不删除这些原脚本**，新增独立runner，用全新work库，避免误跑旧`out.vvp`。

新建`sim/baseline_sources.f`，完整内容如下（相对实施副本根目录）：

```text
tb/tinyriscv_soc_tb.v
rtl/core/clint.v
rtl/core/csr_reg.v
rtl/core/ctrl.v
rtl/core/div.v
rtl/core/ex.v
rtl/core/id.v
rtl/core/id_ex.v
rtl/core/if_id.v
rtl/core/pc_reg.v
rtl/core/regs.v
rtl/core/rib.v
rtl/core/tinyriscv.v
rtl/perips/ram.v
rtl/perips/rom.v
rtl/perips/timer.v
rtl/perips/uart.v
rtl/perips/gpio.v
rtl/perips/spi.v
rtl/debug/jtag_dm.v
rtl/debug/jtag_driver.v
rtl/debug/jtag_top.v
rtl/debug/uart_debug.v
rtl/soc/tinyriscv_soc_top.v
rtl/utils/full_handshake_rx.v
rtl/utils/full_handshake_tx.v
rtl/utils/gen_buf.v
rtl/utils/gen_dff.v
```

`defines.v`通过include引入，不作为独立module；这是普通ISA testbench清单，不是另一个compliance_test testbench。两者同名，不能同时编译。

### 27.3 完整模板：新的ModelSim基线runner

保存为实施副本`sim/run_baseline.py`，只用Python标准库。它不改RTL，在副本的`.sim_runs`建唯一运行目录，保存每次编译/仿真输出；发现任何失败立即非零退出。

```python
from pathlib import Path
import argparse
import os
import re
import shutil
import subprocess
import sys
import tempfile

def run(cmd, cwd, log, timeout):
    with log.open('w', encoding='utf-8') as out:
        p = subprocess.Popen(cmd, cwd=cwd, stdout=out,
                             stderr=subprocess.STDOUT)
        try:
            rc = p.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            if os.name == 'nt':
                subprocess.run(['taskkill', '/PID', str(p.pid), '/T', '/F'],
                               stdout=out, stderr=subprocess.STDOUT)
            else:
                p.kill()
            p.wait()
            raise RuntimeError('TIMEOUT: ' + str(log))
    text = log.read_text(encoding='utf-8', errors='replace')
    if rc != 0 or re.search(r'\*\*\s*(Error|Fatal)', text, re.I):
        raise RuntimeError('COMMAND_FAIL: ' + str(log))
    return text

def main():
    a = argparse.ArgumentParser()
    a.add_argument('--case', default='rv32ui-p-add')
    a.add_argument('--all', action='store_true')
    args = a.parse_args()
    root = Path(__file__).resolve().parents[1]
    tools = {x: shutil.which(x) for x in ('vlib', 'vlog', 'vsim')}
    if not all(tools.values()):
        raise RuntimeError('ModelSim tools not in PATH: ' + str(tools))
    manifest = root / 'sim/baseline_sources.f'
    sources = [root / x.strip() for x in manifest.read_text().splitlines()
               if x.strip() and not x.lstrip().startswith('#')]
    if not sources or not all(x.is_file() for x in sources):
        raise RuntimeError('Source manifest missing or invalid')
    bindir = root / 'tests/isa/generated'
    bins = sorted(bindir.glob('*.bin')) if args.all else [bindir / (args.case + '.bin')]
    if not bins or not all(x.is_file() for x in bins):
        raise RuntimeError('No valid input binaries')
    parent = root / '.sim_runs'
    parent.mkdir(exist_ok=True)
    work = Path(tempfile.mkdtemp(prefix='baseline-', dir=parent))
    print('RUN_DIR', work, flush=True)
    run([tools['vlib'], 'work'], work, work/'vlib.log', 30)
    cmd = [tools['vlog'], '-sv', '-work', 'work',
           '+incdir+' + str(root/'rtl/core'),
           '+incdir+' + str(root/'rtl/perips')] + [str(x) for x in sources]
    run(cmd, work, work/'compile.log', 120)
    script = work/'run.do'
    script.write_text('onerror {quit -f -code 1}\nrun -all\nquit -f -code 0\n',
                      encoding='ascii')
    passed = 0
    for binary in bins:
        data = binary.read_bytes()
        if not data or len(data) > 16384:
            raise RuntimeError('Binary empty or exceeds original program RAM')
        data += bytes((-len(data)) % 4)
        words = [data[i:i+4][::-1].hex() for i in range(0, len(data), 4)]
        (work/'inst.data').write_text('\n'.join(words)+'\n', encoding='ascii')
        log = work/(binary.stem+'.log')
        text = run([tools['vsim'], '-c', '-onfinish', 'stop',
                    'work.tinyriscv_soc_tb', '-do', 'run.do'], work, log, 120)
        if text.count('TEST_PASS') != 1 or re.search(r'TEST_FAIL|Time\s*Out|TIMEOUT', text, re.I):
            raise RuntimeError('TEST_FAIL_OR_NO_PASS: '+str(log))
        passed += 1
        print('PASS', binary.name, flush=True)
    print('SUMMARY', passed, '/', len(bins), 'PASS', flush=True)

if __name__ == '__main__':
    try:
        main()
    except Exception as e:
        print('RUN_FAILED:', e, file=sys.stderr)
        sys.exit(1)
```

未来运行命令：

```powershell
Set-Location 'E:\file\pango\tinyriscv_axi4'
python .\sim\run_baseline.py --case rv32ui-p-add
if ($LASTEXITCODE -ne 0) { throw 'Baseline add failed' }
python .\sim\run_baseline.py --all
if ($LASTEXITCODE -ne 0) { throw 'Baseline suite failed' }
```

当前源码目录有47个bin；目录没有变化时应显示`SUMMARY 47 / 47 PASS`。这是期望值，不是本轮实跑结果。runner语法通过也不能代替这47例。负向验证：把测试台成功条件暂改为固定false，必须报错；恢复后再跑。`.sim_runs`仅做本地证据，提交精简日志清单，不把全部大VCD加进Git。

### 27.4 新模块统一怎么跑

以N02为例，在实施副本`sim`工作目录执行；每个任务使用不同work库名，不污染原CPU基线：

```powershell
vlib work_n02
if ($LASTEXITCODE -ne 0) { throw 'vlib failed' }
vlog -sv -work work_n02 +incdir+../rtl/core ../rtl/core/pipe_slot.v ../tb/unit/tb_pipe_slot.sv
if ($LASTEXITCODE -ne 0) { throw 'compile failed' }
vsim -c -onfinish stop work_n02.tb_pipe_slot -do 'run -all; quit -f -code 0' -l n02.log
if ($LASTEXITCODE -ne 0) { throw 'simulation failed' }
$log = Get-Content -Raw .\n02.log
if ($log -notmatch 'TEST_PASS N02' -or $log -match 'TEST_FAIL|TIMEOUT|\*\*\s*(Error|Fatal)') { throw 'N02 not passed' }
```

已有库则直接重编译，不无条件递归删除。命令等仿真结束后才继续；测试台自带总周期watchdog，进程层仍需120秒超时保护，正式自动回归用27.3的`run()`逻辑包裹同样命令。

日志中`Errors: 0`是成功摘要，不应因含单词Error就判失败。ModelSim 10.6e中onerror应放`.do`宏文件内；在一串命令中直接调用可能只给出“for use within macro”警告。正式runner使用上面的run.do，并同时检查日志与退出码，不能只靠其中一项。

## 28. N02/N03：流水线、提交、译码和除法怎样改

### 28.1 完整模板：pipe_slot.v

**新建：** `rtl/core/pipe_slot.v`。原`gen_pipe_dff`在hold时装默认值；此模块阻塞时保持原数据。用它替换新流水线槽，不改旧通用触发器。

```verilog
module pipe_slot #(parameter WIDTH = 32)(
    input wire clk, input wire rst_n, input wire flush,
    input wire in_valid, output wire in_ready,
    input wire [WIDTH-1:0] in_data,
    output wire out_valid, input wire out_ready,
    output wire [WIDTH-1:0] out_data
);
    reg valid_q;
    reg [WIDTH-1:0] data_q;
    assign in_ready = rst_n && !flush && (!valid_q || out_ready);
    assign out_valid = rst_n && !flush && valid_q;
    assign out_data = data_q;
    always @(posedge clk) begin
        if (!rst_n) begin
            valid_q <= 1'b0;
            data_q <= {WIDTH{1'b0}};
        end else if (flush) begin
            valid_q <= 1'b0;
        end else if (in_ready) begin
            valid_q <= in_valid;
            if (in_valid) data_q <= in_data;
        end
    end
endmodule
```

逐行理解：`valid_q`表示槽里有没有真指令；`!valid_q || out_ready`表示“空着，或者旧指令本拍会出去”，因此能接新指令；flush优先，不同时接入年轻指令；`data_q`在stall时不更新。**不能把当前EX自己的redirect接到当前EX槽的out_valid门控上**，否则redirect依赖retire、retire又依赖out_valid，可能形成组合环。redirect清IF/ID和送入EX的年轻输入；当前EX由retire/trap离开。

### 28.2 完整模板：tb_pipe_slot.sv

**新建：** `tb/unit/tb_pipe_slot.sv`。先写这个测试，缺少模块时编译失败，再添加28.1并按27.4运行。

```systemverilog
`timescale 1ns/1ps
module tb_pipe_slot;
    reg clk=0, rst_n=0, flush=0, iv=0, ordy=0;
    reg [31:0] idata=0;
    wire ir, ov;
    wire [31:0] od;
    always #5 clk=~clk;
    pipe_slot #(.WIDTH(32)) dut(.clk(clk),.rst_n(rst_n),.flush(flush),
        .in_valid(iv),.in_ready(ir),.in_data(idata),
        .out_valid(ov),.out_ready(ordy),.out_data(od));
    task tick; begin @(posedge clk); #1; end endtask
    initial begin
        #10000; $fatal(1,"TIMEOUT N02");
    end
    initial begin
        repeat(5) tick();
        @(negedge clk); rst_n=1;
        @(negedge clk); iv=1; idata=32'hA;
        tick();
        if (ov!==1 || od!==32'hA) $fatal(1,"load A");
        @(negedge clk); idata=32'hB;
        repeat(10) begin
            tick();
            if(ir!==0 || ov!==1 || od!==32'hA) $fatal(1,"stall lost A");
        end
        @(negedge clk); ordy=1;
        tick();
        if(ov!==1 || od!==32'hB) $fatal(1,"replace A with B");
        @(negedge clk); flush=1; idata=32'hC;
        #1;
        if(ir!==0 || ov!==0) $fatal(1,"flush handshake");
        tick();
        @(negedge clk); flush=0; iv=0;
        tick();
        if(ov!==0) $fatal(1,"flush did not clear");
        $display("TEST_PASS N02"); $finish;
    end
endmodule
```

验收负向：临时把stall分支改成清valid，应报`stall lost A`；恢复后重新通过。时钟沿前在negedge施加输入，posedge后`#1`检查，避免测试台和非阻塞赋值竞态。

### 28.3 逐文件修改卡：让ALU先通过，再接真实访存

**文件：** `if_id.v, id_ex.v, pc_reg.v, ctrl.v, id.v, ex.v, regs.v, tinyriscv.v`；新增`retire_ctrl.v`、`tb/unit/tb_retire_ctrl.sv`。一次改一个接口链，但每次更新相应实例和测试台。

1. **IF/ID：** 原文件分别例化inst/pc/int三个gen_pipe_dff。新槽打包`{pc[31:0],inst[31:0],fault[0],fault_cause[4:0],fault_tval[31:0],predicted_next_pc[31:0]}`，总宽134位，按同一顺序解包。外设中断不再随每条IF指令的`int_flag`流动，改独立pending路径至retire_ctrl。
2. **ID/EX：** 把现有inst、PC、reg_we、rd、reg1/reg2值、CSR控制、四个op字段一次锁存；新加fault元数据和预测下一PC，宽度用每个字段位宽相加的localparam，不手猜。先保留现有ALU字段名称，避免连线全改。只在ID实际被EX接收时读操作数。
3. **寄存器堆：** 保留32寄存器和x0逻辑。将`tinyriscv.v:u_regs.we_i`从旧EX组合写使能接到`retire_fire && ex_writes_rd && rd!=0`；旁路同样只用该有效写使能与最终完成值。不能用尚未返回的load输出做旁路。
4. **EX：** 保留算术/比较/乘法计算；将结果当候选值，不直接写回。删除`reg_wdata | div_wdata`及rd按位OR的选择方式，改为明确mux：load结果 / div结果 / ALU结果。每条EX槽只拥有一个最终结果来源。
5. **PC：** `pc_reg.v`保留唯一fetch_pc寄存器；IFU只保存请求副本，不再额外维护第二个自由递增PC。更新优先级`reset > 架构redirect > if_to_id_fire推进到预测next_pc > 保持`。`arch_next_pc`在retire_ctrl记录提交边界，不能代替fetch_pc。
6. **ctrl：** 不再用一个hold向量同时表达flush/stall/halt。输出年轻阶段flush、装入禁止及redirect；AXI RREADY由返回缓冲决定，不接全局流水线stall。
7. **先验纯ALU：** 用测试台注入`addi x1,x0,5; addi x2,x1,3; add x3,x1,x2`，分别期待5、8、13，恰好3次retire。没有LSU前，load使用受控结果模型而非假数据0。

**集成片段的信号定义：** `ex_valid`来自EX槽，`ex_done`是本指令结果已齐，`ex_fault`是本条确定的同步异常，`trap_ready`是异常控制器可以接纳，`cpu_running`表示不在reset/安全halt完成态，`ex_writes_rd`来自译码，`result_mux`是上述最终值。

```verilog
wire trap_fire = cpu_running && ex_valid && ex_done && ex_fault && trap_ready;
wire retire_fire = cpu_running && ex_valid && ex_done && !ex_fault;
wire ex_leave = retire_fire || trap_fire;
wire rf_we = retire_fire && ex_writes_rd && (ex_rd != 5'd0);
wire [31:0] rf_wdata = result_mux;
```

同步fault不退休。中断若接在成功退休之后，该条可以写回，之后禁止年轻指令进入；不能用旧`int_assert`把已经成功的老指令写回一起抹掉。halt请求也先完成老指令，再置halted，不把`cpu_running`提前清零卡死老store。无backpressure的ALU本拍离开，下一条可同拍接入；但分支错预测/trap/接纳中断/halt时禁止年轻装入。

这里的“halt先完成老指令”必须按12.1执行：`halt_pending`可以阻止年轻装入，但不能参与当前EX的`op_fire`、`ex_done`、`trap_fire`门控。当前EX若发生同步异常或真实redirect，先形成正确`arch_next_pc`，再进入halt。

`retire_order`复位为0，每个retire加1。仿真每次打印`order,pc,inst,rd_valid,rd,wdata,mem_addr,mem_mask,trap`；同步异常另有trap事件，不增加instret。以顺序号识别重复，不用PC唯一性判断循环。

**N03验收刺激：** 三条ALU；ALU写x0；load延迟20拍后立即add；store数据来自上一条load；rd相同连续写；除法中暂停；同拍EX完成与分支flush。逐项检查次数，不只看最后值。

### 28.4 完整模板：保留旧div算法的adapter

**源码事实：** `div.v`的START/CALC/END在`start_i=0`时退出运算。一次CPU请求不等于一次旧start电平脉冲。本方案在CPU内部新增adapter，不修改除法算法。

**新建：** `rtl/core/div_adapter.v`；CPU不再同时实例化第二个原div，原`u_div`移到adapter内。输入请求字段在握手时锁存；结果保存到EX消费，rd仍由EX槽持有。

```verilog
module div_adapter(
    input wire clk, input wire rst_n,
    input wire req_valid, output wire req_ready,
    input wire [31:0] dividend, divisor,
    input wire [2:0] op,
    output wire rsp_valid, input wire rsp_ready,
    output wire [31:0] rsp_data
);
    reg active_q, result_valid_q;
    reg [31:0] dividend_q, divisor_q, result_q;
    reg [2:0] op_q;
    wire raw_ready, raw_busy;
    wire [31:0] raw_result;
    wire [4:0] unused_rd;
    wire raw_start = active_q && !raw_ready;
    assign req_ready = rst_n && !active_q && !result_valid_q;
    assign rsp_valid = rst_n && result_valid_q;
    assign rsp_data = result_q;
    div u_div(.clk(clk),.rst(rst_n),.dividend_i(dividend_q),
        .divisor_i(divisor_q),.start_i(raw_start),.op_i(op_q),
        .reg_waddr_i(5'd0),.result_o(raw_result),.ready_o(raw_ready),
        .busy_o(raw_busy),.reg_waddr_o(unused_rd));
    always @(posedge clk) begin
        if(!rst_n) begin
            active_q<=0; result_valid_q<=0;
            dividend_q<=0; divisor_q<=0; op_q<=0; result_q<=0;
        end else begin
            if(req_valid && req_ready) begin
                dividend_q<=dividend; divisor_q<=divisor; op_q<=op;
                active_q<=1;
            end
            if(active_q && raw_ready) begin
                result_q<=raw_result; result_valid_q<=1; active_q<=0;
            end
            if(rsp_valid && rsp_ready) result_valid_q<=0;
        end
    end
endmodule
```

`raw_ready`来自原div寄存器；完成后马上让raw_start变0，防止旧div回到IDLE时把仍为1的start当第二次启动。完成值同时保存，不受原div下一拍清结果影响。EX只在`req_valid&&req_ready`置issued，只消费一次rsp。除法本身无外部写副作用，但本方案仍等待结果在指令边界接中断，避免中途取消协议增加难度。

**完整测试模板：** 新建`tb/unit/tb_div_adapter.sv`，vlog清单为`div.v div_adapter.v tb_div_adapter.sv`，include仍是`rtl/core`，top=`tb_div_adapter`。

```systemverilog
`timescale 1ns/1ps
module tb_div_adapter;
    reg clk=0,rst_n=0,qv=0,rr=0;
    reg [31:0] a=0,b=0;
    reg [2:0] op=0;
    wire qr,rv; wire [31:0] data;
    always #5 clk=~clk;
    div_adapter dut(.clk(clk),.rst_n(rst_n),.req_valid(qv),.req_ready(qr),
        .dividend(a),.divisor(b),.op(op),.rsp_valid(rv),.rsp_ready(rr),.rsp_data(data));
    task check_div(input [31:0] x,y,input [2:0] fn,input [31:0] expected);
        integer n;
        begin
            @(negedge clk); a=x;b=y;op=fn;qv=1;
            if(qr!==1) $fatal(1,"request not ready");
            @(posedge clk); #1;
            @(negedge clk); qv=0;
            n=0;
            while(rv!==1 && n<100) begin @(posedge clk);#1;n=n+1;end
            if(rv!==1 || data!==expected) $fatal(1,"bad division");
            repeat(7) begin
                @(posedge clk);#1;
                if(rv!==1 || data!==expected || qr!==0) $fatal(1,"lost result");
            end
            @(negedge clk);rr=1;
            @(posedge clk);#1;
            @(negedge clk);rr=0;
            repeat(3) begin @(posedge clk);#1;if(rv!==0) $fatal(1,"duplicate result");end
        end
    endtask
    initial begin #200000;$fatal(1,"TIMEOUT DIV");end
    initial begin
        repeat(5) @(posedge clk);
        @(negedge clk);rst_n=1;
        check_div(20,3,3'b100,6);
        check_div(32'hFFFFFFEC,3,3'b100,32'hFFFFFFFA);
        check_div(32'hFFFFFFEC,3,3'b110,32'hFFFFFFFE);
        check_div(32'hFFFFFFFF,2,3'b101,32'h7FFFFFFF);
        check_div(32'hFFFFFFFF,2,3'b111,1);
        check_div(9,0,3'b100,32'hFFFFFFFF);
        check_div(9,0,3'b110,9);
        check_div(32'h80000000,32'hFFFFFFFF,3'b100,32'h80000000);
        check_div(32'h80000000,32'hFFFFFFFF,3'b110,0);
        $display("TEST_PASS N03_DIV");$finish;
    end
endmodule
```

### 28.5 译码合法性与JALR的最小改法

**修改：** `id.v`加入`illegal,uses_rs1,uses_rs2`输出并进入EX槽；`ex.v`只计算合法操作。不是把所有default从零改成NOP。按opcode进一步验证funct3/funct7：LOAD仅000/001/010/100/101；STORE仅000/001/010；BRANCH仅000/001/100/101/110/111；JALR要求funct3=000；SLLI要求高7位0000000；SRLI/SRAI要求0000000/0100000；OP的减法/算术右移与M扩展分别检查完整编码。

**替换定位：** 搜索`ex.v`的`INST_JAL, INST_JALR`，拆开目标计算。下列为集成片段，`sum`是rs1+符号扩展I立即数，`taken`由合法分支比较得出。

```verilog
wire [31:0] jalr_target = sum & 32'hFFFF_FFFE;
wire target_misaligned = actual_taken && (actual_target[1:0] != 2'b00);
```

先清JALR bit0，再检查无C配置4字节对齐；未采取的条件分支不得因为候选目标不对齐而异常。只有跳转成功才提交link rd。`0x00000001`不再是合法32位NOP，作为真实取到的指令应非法，气泡由valid=0处理。

**必测程序：** rs1=0x101、imm=0，JALR实际到0x100；rs1=0x102则cause0且link寄存器不变；beq不成立且候选目标+2，不应异常；非法SLLI高位与正常SLLI分别测试。保留原M乘法结果但增加极值回归，不把“算法保留”当做“无需再测”。

## 29. N04-N09：AXI、取指、访存、存储和互连的具体修改方法

### 29.1 先做单拍，但一开始保留AXI4字段

**文件：** 新建`axi_read_engine.v, axi_data_engine.v`以及`tb/axi/tb_axi_read_engine.sv, tb_axi_data_engine.sv`。外部位宽沿用3.2，不删LEN/LAST/ID。N04/05仅接受len=0，N13加8拍，N17加1-16拍，未启用长度在内部描述符入口报告配置错误，不能静默截短。

每个字段只由一个always块或assign驱动。先在纸上标明“CPU内部请求握手”和“外部AXI握手”是两个事件，前者锁存参数，后者不再读取变化的EX输入。

**固定内部描述符：** `req_valid/req_ready, req_addr[31:0], req_size[2:0], req_len[7:0], req_id[3:0]`；数据引擎额外`req_write`。写数据流`w_valid/w_ready,w_data[31:0],w_strb[3:0],w_last`。读结果`rsp_valid/rsp_ready,rsp_data[31:0],rsp_resp[1:0],rsp_last,rsp_id[3:0]`；写结果`b_valid/b_ready,b_resp[1:0],b_id[3:0]`。以上是内部信号，不与顶层AXI同名混接；统一加`eng_`前缀。

**读引擎状态卡：**

| 状态 | 本拍输出/动作 | 转移 |
|---|---|---|
| RD_IDLE | req_ready=1，其他VALID=0；接受req时锁存全部AR字段 | req_fire后RD_ADDR |
| RD_ADDR | ARVALID=1，AR负载固定，RREADY=0 | AR握手后RD_DATA |
| RD_DATA | RREADY在内部返回槽空或将被消费时为1；R握手锁存数据/RESP/ID/LAST | len=0时收到一拍进入RD_HOLD |
| RD_HOLD | rsp_valid=1，结果保持；不得发第二笔AR | rsp_fire后RD_IDLE |

返回延迟最短可紧随AR握手的下一拍；从设备RVALID出现后会保持到RREADY，不要求引擎在AR握手同拍就接收R。RRESP!=OKAY是总线错误；RID不匹配或len=0却RLAST=0属于协议违例，在测试中fatal、硬件协调故障，不自造一个“正常完成”掩盖失步。

**写引擎状态卡：**

| 状态 | 本拍输出/动作 | 转移 |
|---|---|---|
| WR_IDLE | req_ready=1；锁存地址及单拍写数据，或进入等待内部写数据的准备态 | 描述符和首拍数据都保存后WR_SEND |
| WR_SEND | aw_pending产生AWVALID，w_pending产生WVALID；各自握手各自清除 | 两者都完成后WR_RESP |
| WR_RESP | BREADY在写结果槽有空间时为1，B握手锁存BRESP/BID | WR_HOLD |
| WR_HOLD | b_valid=1保持，成功/失败都只交付一次 | b_fire后WR_IDLE |

N05单拍可在接受描述符后等待内部w流到齐再同时发外部AW/W，这不要求外部READY先高。N17突发再加逐拍数据缓存。任何阶段不得用BRESP失败自动重试store。

**集成片段：** `aw_pending_q/w_pending_q`属于WR_SEND，握手事件是当前输出VALID与READY，不用READY单独计数。

```verilog
wire aw_fire = m_awvalid && m_awready;
wire w_fire  = m_wvalid  && m_wready;
wire aw_complete_now = !aw_pending_q || aw_fire;
wire w_complete_now  = !w_pending_q  || w_fire;
// WR_SEND时，aw_fire清aw_pending_q，w_fire清w_pending_q。
// 两个complete_now同时为1才进入WR_RESP。
```

### 29.2 从第一天就加逐拍协议检查

**新建：** `tb/axi/axi_monitor.sv`。以下完整小模块可作为AR/AW/W/R/B五类稳定性检查共用单元，payload必须包含该通道全部字段，不能漏ID/LAST。

```systemverilog
module stable_channel_check #(parameter W=32)(
    input wire clk,rst_n,valid,ready,
    input wire [W-1:0] payload
);
    reg blocked_q;
    reg [W-1:0] payload_q;
    always @(posedge clk) begin
        if(!rst_n) begin blocked_q<=0;payload_q<=0;end
        else begin
            if(blocked_q && (valid!==1'b1 || payload!==payload_q))
                $fatal(1,"CHANNEL_CHANGED_WHILE_BLOCKED");
            blocked_q <= valid && !ready;
            payload_q <= payload;
        end
    end
endmodule
```

文件名是`axi_monitor.sv`，模块名是`stable_channel_check`，例化时不要写错。另用整数计数器记录AR数量、R拍数、AW数量、W拍数、B数量；单拍结束要求AR=R、AW=W=B，突发按每笔len+1检查。错误响应也计入完成，不把error当作没有事务。

**具体刺激而非一句“随机测试”：**

| 用例 | 测试台动作 | 必查结果 |
|---|---|---|
| AR阻塞 | 发送地址0x10000000，ARREADY低10拍，期间改变CPU原始地址输入 | 总线ARADDR仍为旧地址，最后只一笔AR |
| AW先到 | AWREADY=1，WREADY低5拍 | AW一次，WDATA/WSTRB稳定，B一次 |
| W先到 | WREADY=1，AWREADY低5拍 | W一次，AW稳定，不能提前提交 |
| 从设备依赖 | AWREADY只有看到WVALID才置1 | 写仍完成，无相互等待 |
| 返回被堵 | 上层rsp_ready或b_ready低7拍 | 返回数据/错误码保持 |
| 错误 | 注入RRESP=SLVERR或BRESP=SLVERR | fault一次，load不写rd、store不重发 |

随机只改变等待长度0-31拍，每次用`+SEED=1`至20固定种子，driver必须保证最终会响应；切换ready在negedge，比较在posedge采样，避免竞争。随机等待不替代上述确定性反例。

### 29.3 IFU修改卡：PC和指令必须成对

**修改/新增：** `pc_reg.v, ifu_axi.v, if_id.v, tinyriscv.v`；测试`tb/unit/tb_ifu_axi.sv`。

1. `pc_reg.pc_o`作为fetch_pc输入；IFU空闲时保存`req_pc_q=fetch_pc`及预测下一PC，预留1个返回槽，然后发引擎请求。
2. 所有返回使用`req_pc_q`标记，不用此时可能已跳转的fetch_pc。
3. 返回槽按28.1方法与IF/ID握手；IF/ID接纳时才推进fetch_pc到保存的预测next_pc。redirect优先于该推进。
4. IFU从内部`req_fire=eng_req_valid&&eng_req_ready`起就拥有一笔在途请求，不能等看到外部ARVALID或AR握手后才算在途。保存`req_pc_q`的同一拍同时保存`req_live_q=1`；从RD_ADDR、RD_DATA到返回槽被消费/丢弃前都保持该身份。
5. redirect优先于顺序取指推进。若redirect到来时尚未内部接单，组合门控使旧`req_valid=0`；若redirect与旧`req_fire`同拍，允许引擎接单但必须把该请求标成`discard_pending=1`，不得依赖非阻塞赋值后的旧`req_live_q`漏标。若已经内部接单但尚在RD_ADDR、已经AR握手、等待R或结果停在返回槽，均继续排空并丢弃。
6. `discard_pending`只由“该请求最终被丢弃并释放”清零，第二次redirect只更新最新`redirect_target`，不能把discard清掉。旧请求的RRESP错误和协议fault不得进入架构trap；正确路径fault才带PC与地址送入流水线。
7. 完成旧请求后，只能用pc_reg已接纳的最新redirect目标重新发请求。新目标请求不得覆盖旧`req_pc_q`，直到旧请求的引擎结果与IFU返回槽都释放。
8. IFU只允许在程序RAM或已启用且标可执行的普通内存取指。数据RAM是否可执行在地址属性表显式规定；首版只设程序RAM可执行，不默认所有地址可执行。

**逐拍样例：** 请求PC=0x20 -> AR握手 -> EX跳转0x80 -> 旧R返回0x20内容 -> R被接收但IF/ID不装入 -> 新AR=0x80。观察req_pc/discard/AR/R/IFvalid，而不是只看PC最后等于0x80。无Cache首版的请求槽从内部req握手到返回消费只占一条指令，不能消费前又发第二笔覆盖req_pc。

**必须新增的redirect相位测试：** 固定旧PC=0x20、新目标=0x80，分别让redirect出现在：(a)内部`req_fire`同拍；(b)内部已接单、读引擎处于RD_ADDR且ARREADY=0；(c)AR已握手等待R；(d)R已进入RD_HOLD/IFU返回槽但IF/ID未接纳。四例都要求旧指令退休次数为0、旧fault次数为0、最终只交付0x80指令。再增加连续两次redirect，最终目标取第二次值且旧请求仍被排空。

### 29.4 LSU修改卡：把旧的读改写变成字节使能

**修改/新增：** `ex.v, lsu_axi.v, axi_data_engine.v, tinyriscv.v`；测试`tb/unit/tb_lsu_axi.sv`。

1. EX计算有效地址，但不读旧内存拼SB/SH；保存地址、rs2、size、unsigned、PC/rd到LSU请求。
2. op握手置EX的issued；等done或fault前不再发op。离开EX后才清issued用于下一条。
3. 在请求AXI之前检查LH/SH地址bit0，LW/SW低2位；未对齐立即fault，AR/AW/W计数保持零。
4. 外部ARADDR/AWADDR保留原字节地址，size编码byte=0/half=1/word=2；发送数据左移8*offset，strb为1/3/15相应移位。**不能把byte地址对齐后仍沿用原lane规则而不修改AXI size语义。**
5. 返回的32位RDATA只有该次窄访问涉及的lane保证有效，LSU提取所需字节后扩展；Cache命中也返回对应32位字且沿用一次提取。
6. B成功才使store完成，load R成功才使最终数据有效；done在EX消费前保持。x0目的load也要执行内存读及错误检查。

**完整小函数模板，可放在lsu_axi模块内：**

```verilog
function [31:0] extend_load;
    input [31:0] raw;
    input [1:0] offset;
    input [2:0] size;
    input is_unsigned;
    reg [31:0] shifted;
    begin
        shifted = raw >> (8*offset);
        case(size)
            3'd0: extend_load = is_unsigned ? {24'b0,shifted[7:0]} :
                                                   {{24{shifted[7]}},shifted[7:0]};
            3'd1: extend_load = is_unsigned ? {16'b0,shifted[15:0]} :
                                                   {{16{shifted[15]}},shifted[15:0]};
            3'd2: extend_load = shifted;
            default: extend_load = 32'b0;
        endcase
    end
endfunction
```

default不是非法size访问的成功结果：译码/前置检查必须先拒绝size>2。测试`raw=0x807FFF01`：LB(base+2)=0x7F，LB(base+3)=0xFFFFFF80，LBU(base+3)=0x80，LH(base)=0xFFFFFF01，LHU(base)=0x0000FF01。

**短汇编测试输入：** 程序从0开始，无C扩展；EX退休监视器检查x3/x4和数据RAM四字节，testbench在完成标志退休时停，不使用无限等待。

```asm
.option norvc
.section .text
.globl _start
_start:
    lui  x10, 0x10000
    addi x1, x0, 5
    sw   x1, 0(x10)
    lw   x2, 0(x10)
    add  x3, x2, x2
    addi x4, x0, -1
    sb   x4, 1(x10)
    lbu  x4, 1(x10)
    addi x27, x0, 1
    addi x26, x0, 1
1:  jal x0, 1b
```

预期x3=10、x4=255，RAM[0x10000000]整字=0x0000FF05。分别让load R延迟20拍、store B延迟30拍；每笔store内存事件仍一次。单独的对齐/总线错误测试不能复用“只等x26”的无限结束条件，错误路径由trap日志核对。

### 29.5 RAM与GPIO从设备：先一个目标，再扩整套

**修改：** `rtl/perips/rom.v, ram.v, gpio.v`；新建`tb/axi/tb_axi_ram.sv, tb_axi_gpio.sv`。

程序RAM/数据RAM保留数组容量与初始化路径；数组不逐字复位。先用同步读口，读地址第k拍锁存、第k+1拍得到数据、第k+2拍装入R槽也可以，宁可先多一拍明确正确，不用组合读假装BRAM。

1. 各设AR描述符槽、AW描述符槽、W数据槽；N06单事务策略下READY只在对应槽空且可预留结果时拉高。
2. W先到先存`data/strb/last`，不知道AW地址时绝不写RAM；AW到齐、长度/size/范围合法再一次写入。
3. word索引使用`(addr-base)>>2`，先验证整个请求范围在物理容量内，再索引，不能仅丢弃高位形成镜像。
4. 按strb分四个byte写；R槽满且未消费时不得覆盖。先不实现同周期同地址双端口读写，事务串行确定顺序。
5. GPIO保留CTRL=0、DATA=4偏移；2bit/引脚的模式不改成另一套不兼容布局。原仅两个输入，真实顶层引脚数量按板卡确认；按键需同步，消抖是软件/独立模块功能，不把抖动当CPU错。

**集成片段，变量归属：** `write_event`只在保存的AW/W被内部执行一次时为1；`word_idx`是已检查索引；`wdata_q/wstrb_q`来自W槽。

```verilog
integer lane;
always @(posedge clk) begin
    if(write_event) begin
        for(lane=0;lane<4;lane=lane+1)
            if(wstrb_q[lane])
                mem[word_idx][8*lane +: 8] <= wdata_q[8*lane +: 8];
    end
end
```

GPIO控制/数据普通RW字段可用相同byte mask；Timer pending的W1C不适用普通“写数据覆盖”。Timer到期与清pending同拍应按已公布优先级处理，UART状态硬件事件与软件写也不能因一个大if/else丢事件。

**UART具体取舍：** 保留CTRL/STATUS/BAUD/TXDATA/RXDATA偏移0/4/8/C/10与STATUS bit定义。首版TX忙时写TXDATA返回SLVERR且不发送，驱动先轮询busy=0；不得默默返回OKAY却丢字。RX-over沿用旧可写bit语义，若改W1C须同时改驱动，不能只改硬件。每次AXI接受只产生一次`tx_data_valid`脉冲，连续其他寄存器写不应把该脉冲延长。

**N06验收地址：** 0x10000000读写、0x10003FFC最后字、0x10004000越界；GPIO写CTRL=1、DATA=1后读回；WSTRB=0010只改目标第二字节；无效寄存器报SLVERR无副作用。

### 29.6 互连：先2主2从，再扩大端口数量

**新建：** `rtl/bus/axi_interconnect.v, axi_error_slave.v`；测试`tb/axi/tb_axi_interconnect.sv`。

先连接IF读主与LSU读写主、程序RAM与数据RAM，保留固定ID 0/1；调试和AI端口未实现时绑无效。不要一次写6主十几个从设备再查串包。地址译码函数在唯一位置，以完整窗口范围判断；外设低偏移是否合法由目标判断。

| 状态 | 保存/路由 | 退出 |
|---|---|---|
| FREE | 轮询AR/AW候选；选中时保存owner、type、target | 一旦向下呈现地址即进入R_LOCK/W_LOCK |
| R_LOCK | 只转发owner的AR，握手后收目标R；响应只返回owner | 预期末拍R握手，错误也要排空 |
| W_LOCK | 同一owner的AW和W独立转发，分别记录完成；不接其他owner的W | 目标B握手 |

组合路由必须保持锁定的owner/target，不能每拍用“当前谁优先”重选。若加输入寄存切片，上游握手与下游握手分别记录，不能用一个fire代替两端。目标AWREADY可依赖WVALID，W路径不得再依赖目标AWREADY；自定义从设备输出VALID也不能组合依赖输入READY。

**错误slave：** 合法格式未映射读回len+1拍DECERR、原ID、末拍LAST；写保存AW，消费len+1拍后B=DECERR且不写任何目标。WLAST不一致/少拍是协议错误，用watchdog判错，不能承诺对永不结束的非法输入自动恢复。

**N09接回CPU的顺序：** 纯算术 -> 分支 -> 数据RAM -> UART/GPIO -> 可变延迟 -> 错误响应 -> 原47例 -> 新ISA/中断例。原47例通过不覆盖协议与非法指令，所以后两类不能省。每步新编译清单只含一个SoC top，不与原RIB同名实现混编。

## 30. N10-N12：异常、中断与软件逐项修改

### 30.1 同步异常先做好，不等待全部外设中断

**文件：** `id.v, ex.v, retire_ctrl.v, csr_reg.v, clint.v`及`tests/axi/trap_cases.S`。先实现主文13.1中同步原因0/1/2/3/4/5/6/7/11。对同一条指令先做译码和对齐检查，失败就不发访存；后到的总线错误只属于真正发出的那一条。取指错误带身份走至EX，不能越过老store。

**单点CSR更新方法：** csr_reg新增`trap_enter, trap_pc, trap_cause, trap_tval, mret_fire`输入。由同一时钟过程更新mepc/mcause/mtval/mstatus；不再让旧clint连续几拍串行改多个CSR期间允许CPU继续提交。正常CSR写与trap入口同拍时，先形成正常指令提交后的候选CSR值，再按trap规则更新，尤其“写mstatus后立即接中断”不能保存旧MIE。

**集成算法而非覆盖原文件：**

```text
csr_next = csr_current
若 csr_commit：按只读/WARL/位掩码处理正常CSR写
若 mret_fire：MIE <- 当前MPIE；MPIE <- 1；MPP <- M
若 trap_enter：
    mepc <- trap_pc按IALIGN规则合法化
    mcause <- trap_cause；mtval <- trap_tval
    MPIE <- 此时csr_next.MIE；MIE <- 0；MPP <- M
时钟沿一次写入csr_next
```

正常异常指令没有csr_commit。一次MRET后立即接新中断时，trap_pc是MRET恢复的目标，不是MRET+4。只支持M模式时，不实现的权限位读合法固定值，不能允许软件写出假S/U状态。未实现CSR非法访问；只读计数器的读与有零掩码CSRRS/CSRRC合法，非零写非法。

### 30.2 中断来源和软件更新，不要只改mcause

**硬件文件：** `irq_ctrl.v, timer.v, csr_reg.v, retire_ctrl.v, tinyriscv_soc_top.v`。Timer事件接MTIP；IRQ_CTRL软件bit接MSIP；AI或GPIO来源先同步/锁存到EXT_PENDING，再经EXT_ENABLE聚合为MEIP，最后还要受mie.MEIE与mstatus.MIE控制。

**基础启动修改：** `tests/example/init.c`在T08a先明确关闭中断。T08b timer例程先写mtvec、关闭/清除Timer旧pending、配置Timer计数、设置mie.MTIE，最后开MIE。以下为集成片段，`trap_entry`沿用原汇编入口，Timer寄存器操作沿用原驱动。

```c
extern void trap_entry(void);
static inline void enable_timer_irq(void) {
    unsigned long vector = (unsigned long)&trap_entry;
    unsigned long mask = 1UL << 7;
    __asm__ volatile ("csrw mtvec, %0" :: "r"(vector) : "memory");
    __asm__ volatile ("csrs mie, %0" :: "r"(mask) : "memory");
    __asm__ volatile ("csrsi mstatus, 8" ::: "memory");
}
```

首版固定RV32裸机，`unsigned long`应为32位；编译时检查`-mabi=ilp32`及ELF属性，不用宿主机编译器验证可执行性。启动环境先建立SP、初始化.data/.bss再开中断，不能栈尚未准备就跳C handler。

**trap_entry.S改法：** 保留保存/恢复x1-x31的框架和16字节栈对齐；旧SIMULATION跳过保存x26/x27仅用于旧测试哨兵，新中断回归应保存全部架构寄存器，完成状态由专用测试监视器/提交事件判断。去掉“全部同步异常直接+4”的通用分支，统一调用C分发函数，C返回下一mepc。

```asm
    # 在保存寄存器之后，替换旧同步/异步分叉段
    csrr a0, mcause
    csrr a1, mepc
    csrr a2, mtval
    call trap_dispatch
    csrw mepc, a0
    # 接原寄存器恢复段，最后mret
```

`trap_dispatch`原型明确为`uint32_t trap_dispatch(uint32_t cause,uint32_t epc,uint32_t tval)`，返回恢复PC。异步分支按最高位和原因码3/7/11清相应源后返回原epc。只有**测试专用**ECALL cause11允许return epc+4；未知同步异常先保存cause/epc/tval到RAM诊断结构并禁止中断、停在死循环，不读写可能再次故障的外设。没有完整串口可用前，不强行在异常内printf。

**必须测试：** 定时中断前后x1-x31哨兵不变；mie屏蔽期间pending保留；enable后恰好处理；pending未清MRET后重新进入是预期，不是“CPU重复中断bug”；只读CSR写报cause2；MRET返回低位合法化；陷阱期间新事件不丢失。

### 30.3 64位计时的完整替换函数

**修改：** `tests/example/lib/utils.c:get_cycle_value()`，替换原低后高各一次读取，保留其他函数。

```c
#include <stdint.h>
uint64_t get_cycle_value(void) {
    uint32_t hi0, lo, hi1;
    do {
        __asm__ volatile ("csrr %0, cycleh" : "=r"(hi0));
        __asm__ volatile ("csrr %0, cycle"  : "=r"(lo));
        __asm__ volatile ("csrr %0, cycleh" : "=r"(hi1));
    } while (hi0 != hi1);
    return ((uint64_t)hi1 << 32) | lo;
}
```

时间读取函数不等于DMA排序屏障，需要前后内存顺序时另用`asm volatile(... ::: "memory")`。测试计数器从`0x00000000FFFFFFFE`附近开始跨回绕，函数必须重试而非跳增一个高32位周期。`time_in_secs`另核验换算上界；CPU频率宏由一个构建参数生成，UART分频也按实际频率计算，不一直写死50MHz。

### 30.4 基础上板的通过顺序

只导入新CPU文件清单与板级top，保留器件/引脚/电压来自真实板卡资料，不提供虚构引脚号。先低风险频率设置并通过布局布线时序，按算术签名、RAM测试、UART一串固定字符、GPIO变化、CoreMark两套种子与>=10秒记录逐项验收。T08b再加入中断；若加中断后失败，回退功能开关定位，不重写所有模块。

CoreMark需检查算法源没有被修改、`.map`中程序与栈不重叠、软乘除libgcc与声明ISA匹配、实际运行频率与计时一致。原47例不包含CoreMark，不把两者混成同一测试覆盖。

## 31. N13/N14：两路Cache和预测器的详细任务卡

### 31.1 第一张卡只做tag/LRU，不马上连CPU

**文件：** `rtl/cache/icache_2way.v, dcache_2way.v`；测试`tb/cache/tb_cache_tags.sv`。参数沿用2路、32组、32字节行，不改变主文容量。

数组逻辑：每路32个22bit tag、32个valid；每组1bit victim；每路data=32组×8个32bit word。复位只清valid和victim，不遍历清data。同步data读分`LOOKUP_REQ -> LOOKUP_RESP`，不要把异步数组读当作将来一定推断BRAM。首次综合查看实际BRAM/LUT映射。

**集成片段：** `set=request_addr[9:5]`，`tag=request_addr[31:10]`；hit条件含valid。优先选无效路，否则选victim；访问way0后victim=1，访问way1后victim=0。

```verilog
wire hit0 = valid0[set] && tag0[set] == tag;
wire hit1 = valid1[set] && tag1[set] == tag;
wire choose_way = !valid0[set] ? 1'b0 :
                  !valid1[set] ? 1'b1 : victim[set];
```

期望两路不同时hit同一地址；双hit在仿真报错。用A=0x10000000、B=0x10000400、C=0x10000800，同组不同tag，顺序A、B、A、C、A、B：前2次miss，第3次hit，C淘汰B，A仍hit，最后B miss。不要错误用相差0x20的地址测试同组，它们是相邻组。

### 31.2 第二张卡实现补行，再接I侧

**测试：** `tb/cache/tb_icache_2way.sv`，使用29章AXI模型。状态`IDLE -> LOOKUP -> MISS_REQ -> REFILL -> REPLAY -> RESP`。

1. miss时保存原始请求PC、行地址、组、way；立即清受害way.valid，不允许旧tag配新写入的数据。
2. 发ARADDR=addr&~31、LEN=7、SIZE=2、INCR，beat计数0至7仅在R握手增加；每拍写word[beat]。
3. 错误累计`refill_error |= RRESP!=OKAY`；第8拍确认RLAST、ID正确、无错误且未发生失效，才写tag并置valid；否则保持invalid。
4. 首版不early restart，整行到齐后用保存的word_index取请求字交付。把refill第3拍返回错码，后5拍仍须排空，最终只一次fault。
5. 普通分支redirect只取消本次交付，可保留成功cache行；FENCE.I/debug代码修改属于失效，禁止在途旧行重新置valid。首版用`invalidate_pending`停新请求、排空refill、扫描清valid后才ack，不用会回绕的1bit epoch草率判断多次失效。

**引擎扩充：** N04的RD_DATA/RD_HOLD在burst下改为可反复流出的逐拍返回槽，`rsp_last`消费后才回IDLE；不得第1拍R后就释放全笔busy。对RREADY回压和同拍消费/下一拍装入逐一测试。

### 31.3 第三张卡接D侧：先写直达、不写分配

**测试：** `tb/cache/tb_dcache_2way.sv`。读命中返回word；读miss补8拍；store无论命中与否都下发单拍，等待B成功再修改命中行。size/strb由LSU生成一次，不在Cache内二次移位。B失败使匹配行失效并报store fault，不回写“猜测成功”的数据。

首版每个D-Cache一次只处理一个CPU操作。MMIO完全旁路，程序RAM的D访问按主文不缓存；IFU与LSU不是一致性多核系统，debug/DMA修改可缓存内存必须按维护协议。对共享缓冲，地址匹配器先判断不可缓存，再考虑普通DDR可缓存，优先级不可反转。

**CPU集成验收：** Cache关/开跑同一个已编译程序，其架构提交结果一致；单测A/B/C冲突序列、SB/SH命中、写miss不分配、B错误、行尾与边界、debug修改后可见。性能可变，但错误不能用“缓存时序不同”解释。

### 31.4 动态预测先预测，再统计真实收益

**文件：** `branch_predictor.v`及`tb/unit/tb_branch_predictor.sv`。32项BTB，index=PC[6:2]、tag=PC[31:7]；valid复位0，方向2bit初值01（弱不跳）。命中且conditional计数器最高位1才取目标；已学习无条件跳转直接取目标。

完整饱和计数器函数，放模块内部：

```verilog
function [1:0] update_counter;
    input [1:0] old_value;
    input taken;
    begin
        if(taken) update_counter = old_value==2'b11 ? 2'b11 : old_value+2'b01;
        else update_counter = old_value==2'b00 ? 2'b00 : old_value-2'b01;
    end
endfunction
```

预测值随着PC/指令传到EX；实际next_pc与预测next_pc不等才redirect。训练只在合法控制流指令retire，异常/flush不训练；taken目标计算和JALR bit0处理沿用真实执行逻辑。对于条件分支not-taken，更新方向但BTB target仍保存分支跳转目标，不能保存PC+4冒充分支目标。

测试计数器上下饱和、同index不同tag、循环退出、JALR目标改变、普通ALU处BTB残留（代码更新应失效）、错路不能训练。核心验收是预测开/关程序结果相同；报告mispredict/branch与周期，不保证加入预测器一定提分。

## 32. N15：推荐增加的性能观测与基础应用

### 32.1 性能快照寄存器：可解释、可测量，不靠截图猜测

**新建：** `rtl/perips/perf_regs.v`，`tests/example/include/perf.h`，`tests/example/perf_demo/main.c`，测试`tb/unit/tb_perf_regs.sv`。地址沿用0x60002000，不另占与AI冲突的窗口。

| 偏移 | 内容 | 写规则 |
|---|---|---|
| 0x00 CTRL | bit0 SNAP命令、bit1 CLEAR命令，读为0 | 两bit同时写1返回SLVERR，无副作用 |
| 0x04 STATUS | bit0 snapshot_valid | 只读 |
| 0x10/14 | cycle低/高 | 只读快照 |
| 0x18/1C | instret低/高 | 只读快照 |
| 0x20/24 | IF等待周期低/高 | 只读快照 |
| 0x28/2C | LSU等待周期低/高 | 只读快照 |
| 0x30/34 | I miss操作数低/高 | 只读快照 |
| 0x38/3C | D miss操作数低/高 | 只读快照 |
| 0x40/44 | 退休控制流指令数低/高 | 只读快照 |
| 0x48/4C | 错预测数低/高 | 只读快照 |

冻结事件定义：cycle每个非reset系统时钟加1，含CPU暂停；instret仅retire_fire；IF等待=CPU运行、IF/ID可接且没有可交付取指结果；LSU等待=EX有效且内存操作已发但结果未齐；miss只计一次lookup miss，不每个refill拍都加。等待周期可以重叠，不能把它们相加声称等于总周期。原有CSR cycle保持独立，CLEAR只清本perf块计数器，不篡改架构时钟计数。

SNAP在内部write_event一次性复制全部计数器，随后CPU读的都是快照；定义快照捕获该时钟沿之前的counter值，报告窗口一致即可。CLEAR优先于本块该拍increment，并清snapshot_valid；多寄存器读期间不能自动刷新快照。

**测试：** 注入10拍，其中retire=4、LSU等待=3，SNAP后计数继续增长但读回仍10/4/3；再SNAP后更新；CLEAR后快照无效；未实现偏移SLVERR；WSTRB不含byte0时CTRL命令不触发。C端输出`CPI=delta_cycle/delta_instret`，instret=0时报告无有效样本，不除零。

### 32.2 小应用：GPIO边沿记录与CPU控制响应

先复用已有GPIO，不再立刻新增高吞吐采集硬件。输入按钮或外部方波，CPU轮询输入位，检测变化后记录cycle时间、输入值并翻转另一输出位，通过UART输出记录。它说明CPU确实执行采集/控制程序；不是“只有LED闪了一下”的展示，也不是高阶AI。

**文件：** `tests/example/gpio_trace/main.c`，复用gpio/uart/utils头文件；记录缓冲固定64项放数据RAM，每项`uint64_t ticks + uint32_t pins`，按实际C对齐用`sizeof`核验容量，不假设12字节。先在仿真注入8次相隔100周期输入变化，输出8条单调时间戳，UART输出放采集结束后，避免发送耗时污染采样。

后续可选升级：GPIO边沿pending接IRQ_CTRL中的一个EXT来源，ISR只存记录不printf；记录满后置overflow并停止存入，不覆盖旧数据却不提示。高频信号可能轮询漏边沿，明确频率边界，不能宣传实时逻辑分析仪精度。若要精确硬件采集，另立FIFO/采样时钟任务，不混入CPU主线。

### 32.3 对比配置怎么组织

在`rtl/core/soc_config.vh`集中定义CACHE_ENABLE/PREDICT_ENABLE/PERF_ENABLE以及实际内存大小；每种配置独立生成综合文件清单及bitstream名。第一次仅允许编译时开关；运行中更改cache属性/开关容易造成旧数据和在途事务问题，不给小白增加这一层风险。

每份报告记录配置、源码提交、ELF哈希、工具版本、频率、BRAM或DDR运行位置、CoreMark两套种子、UART原始日志、资源边界。比较C1/C2/C3优先同一个ELF、同频率；再单列各配置最高时序合格频点，不把频率升高当CPI改进。

## 33. N16/N17：DDR、DMA与AI怎样细化而不虚构硬件

### 33.1 明确哪些现在能做，哪些必须先拿到资料

现在能做：AXI内存模型上的DMA、INT8乘加与一层卷积黄金数据比较；不能直接做：假设厂商DDR就是标准AXI4、猜引脚/校准参数、只凭YOLO名字写固定层数RTL。后者需要主文T11/T12的实际IP端口、模型图与权重。

通过关卡的交付物固定为`docs/ddr_contract.md`和`docs/model_contract.md`：DDR文档列字节/字地址、位宽、burst单位、写完成、回压、mask极性、校准/reset/时钟；模型文档列版本/权重哈希、输入大小、全部算子/张量尺寸、量化/舍入/饱和规则、CPU回退算子、独立测试数据与目标精度。缺一项就不写依赖该项的板级RTL，不用“参考常见设计”填入猜测。

### 33.2 先做DMA复制，不先做摄像头加卷积

**新建：** `rtl/ai/tensor_dma.v`、`tb/ai/tb_tensor_dma.sv`、`tests/example/dma_copy/main.c`。首版只支持4字节对齐src/dst、字节数为4的倍数、src/dst不重叠；不支持条件直接参数错误，不偷偷扩大到任意memmove。

DMA与CPU共用全局单事务时，**不得先发读取描述符然后依赖另一笔写事务才腾出读接收空间**。先用16-word本地FIFO：读完整块 -> 释放读事务 -> 发写块 -> 等B -> 下一块。每次最多64字节，并同时考虑源与目标4KiB边界。

```text
chunk_bytes = min(remaining_bytes, 64,
                  4096 - (src_addr & 4095),
                  4096 - (dst_addr & 4095))
beats = chunk_bytes / 4
ARLEN/AWLEN = beats - 1
```

参数已保证word对齐与长度倍数，因此chunk非零且为4倍数。后续AI张量需要尾字节时单独扩展：分配边界内读取，写最后拍WSTRB精确生成；完成该测试后再放宽第一版限制。

测试src偏移0xFF0、dst偏移0xFF8、长度128字节：第一块最多8字节，不能只按src切块。检查所有读写地址、FIFO顺序与B完成；注入第二块读错误，停止发布新事务并排空在途，status=error，不能同时done=success。写START的B在锁存参数后返回，DONE等最后数据B成功才置位。

### 33.3 从一个MAC到一层，不从模型名字跳到整个系统

**新建：** `rtl/ai/mac_array.v`、`tb/ai/tb_mac_int8.sv`。首张卡只做signed INT8×INT8→INT16积、INT32累加。无浮点、无自定义ISA，CPU通过MMIO发任务。

```verilog
wire signed [7:0] a_s = input_byte;
wire signed [7:0] b_s = weight_byte;
wire signed [15:0] product = a_s * b_s;
wire signed [31:0] extended_product = {{16{product[15]}},product};
// mac_fire有效且非clear时：acc_q <= acc_q + extended_product;
// clear优先时本拍不同时累加；driver不得把首项与clear重合。
```

测试向量`[-128,-1,2,127]`与`[-128,3,-4,127]`点积=32502。测试clear、插入valid气泡、最后结果被下游阻塞；只有输入握手才累加。乘加次数K与bias决定溢出上界，不能因为用了INT32就认为任意卷积安全；冻结模型后检查`K*max_abs_product + abs(bias)`是否在界内或使用更宽内部累加。

下一卡先限定3×3、stride1、padding0、单输入单输出通道；生成明确小图逐元素对比。之后再按冻结模型逐项加stride/padding、多通道、bias、requant、activation；每加一项都保留前一项回归。INT8非对称量化需要减zero point，不能把原始INT8相乘当最终模型正确。

### 33.4 整机接入顺序和停止标准

1. 厂商DDR独立例程通过，保存实际板上日志；再接经验证的AXI前端/宽度转换/CDC，CPU不可缓存读写通过。
2. DMA仅在BRAM模型中通过后到DDR自检；先单主再与CPU争用，记录吞吐与最长等待，不以DDR芯片标称速率代替。
3. 预置单层输入/权重运行CPU+加速器，与电脑黄金数据逐元素比较；失败先查最早错误元素。
4. 预置一张图片完成全部模型，包括CPU回退算子与NMS；成功前不接实时相机。
5. OV5640彩条/固定帧校验后接双缓冲DMA，写响应结束才READY；整帧满/错时作废该帧；AI完成才释放PROCESSING帧。
6. 独立测试集报告检测精度和端到端时间；CPU-only基线使用同模型与量化。只做出卷积核不算完整YOLO移植，慢但正确的系统不谎称实时。

相机曝光、数据集、输入分辨率与帧丢弃都会影响演示结果，保存配置。HDMI是可选后续工作；选择只有摄像头与串口结果也要说明实际应用怎么使用检测结果，不能只有串口打印固定类别。

## 34. 写完后的复核、风险与使用边界

### 34.1 第二次检查清单

| 检查维度 | 本轮检查方法 | 不通过时怎么办 |
|---|---|---|
| 赛题覆盖 | 将B1-B3/H1-H3/E1-E6映射原任务和N任务，不把自选项写成强制 | 调整范围说明/补验收，不虚构分值 |
| 原代码锚点 | 对pc/slot/regs/ex/div/CSR/外设/runner查真实实现 | 修改方法必须服从当前源码，不套另一CPU |
| 接口一致性 | 核对复位极性、PC拥有者、字节lane、size/len、fault/retire、done保持 | 先改合同和两端任务，再开工 |
| 依赖可执行性 | 单元用替身模型，完整CPU另有T05-I门槛 | 不让前置任务依赖尚未创建的下游实现 |
| 文档代码 | Python语法解析、独立RTL模板编译/仿真（工具许可允许时） | 报出具体失败，不能把静态通过写成CPU通过 |
| 负向测试 | 临时样本故意破坏stall/握手规则，确认测试报错 | 检查测试有效性，恢复文档正确模板 |
| 未修改工程 | 对原目录所有文件排序聚合哈希，前后比较 | 若不同停止宣称未改并定位差异 |
| 决策边界 | DDR/YOLO/板卡/主办方信息仍需真实资料 | 在门槛前停，不能靠代码模板假装解决 |

### 34.2 本轮新增发现和修正

- 原div是持续start电平协议，已用adapter明确转换，避免直接一拍启动导致算法中止。
- 原EX用ALU/div结果按位OR合并；暂停重构后该假设不再成立，改为明确单一来源mux。
- 原`pc_reg`与新IFU都可能被理解为PC拥有者；现在规定pc_reg持有fetch_pc，IFU仅保存请求PC副本，retire_ctrl持有arch_next_pc。
- 原UART写寄存器路径可能延长tx_data_valid且软件写与硬件事件互斥；AXI化时明确一次发送事件，并测试同时发生的状态更新。
- 原测试脚本可能漏报编译失败/零用例；新增runner明确新编译、有效用例数、退出码和超时。
- 原程序默认开全局中断；基础T08a关闭中断配置必须同步修改启动程序，不能只口头说关闭。
- 加Cache后必须先清受害行valid再补行；代码失效须排空旧refill，防止旧内容重新标有效。

### 34.3 如何理解“详细且可跟做”

本计划提供可独立运行的小模块模板、逐文件修改卡、明确状态表、测试输入/期望值与命令。**不等于已有一份完整CPU替换补丁**：AXI整套互连、完整CSR环境、Cache及模型加速器仍按任务卡逐步实现，每步必须仿真；DDR/YOLO部分在事实冻结后还要针对真实端口/算子展开专属实现卡。遇到这些门槛时先补资料，不让小白猜参数继续写。

本轮复核结果已合并在第36章，以实际工具输出为准。没有运行的测试继续标为未运行；没有上板的设计绝不标为赛题已经达标。

**实际完成的文档模板复核：** Python runner语法解析通过；pipe_slot、div_adapter、稳定性检查器及两个测试台在ModelSim 10.6e编译通过；流水线槽测试与9例除法测试通过。临时副本植入stall清空错误后测试报Fatal，恢复后再次通过。并非完整CPU仿真或AXI/Cache认证；详细日志和边界见复核报告。

---

## 35. 历次评审意见与修订依据

评审日期：2026-10-09。范围：赛题选题一、本地tinyriscv源码、队长原计划。只修改计划，不改RTL、软件、测试脚本、工程约束或原始PDF。

### 35.1 结论

**原计划总体方向合理，基础要求映射基本正确，但不能按原稿直接当成已经闭合的实施合同。** 主要问题不是“用了错误的CPU”或“AXI不符合比赛”，而是若干协议条件未写清、软硬件配套缺项、验收顺序太靠后，以及项目规模尚未按队伍资源裁剪。

建议保留原生AXI4、有效位流水线、精确提交、两路I/D Cache、DDR先核验、逐步完成AI的主线。当时已修改原计划正文并保留原稿备份；本次合并后仅保留当前文档，历史备份不再单独保留。修订是供队伍确认的方案，不是批准开工，也不是硬件正确性认证。

### 35.2 本轮依据

- 赛题：`C:/Users/lenovo/Desktop/全国大学生嵌入式芯片与系统设计竞赛'2026FPGA赛道选题指南-紫光同创.pdf`，共17页；已提取并渲染目视核对PDF第10-11页（印刷页8-9）。
- PDF SHA256：`D4D7D389E22F88AC0D362072FC0C73711959816D374168692E102D25453D2CE6`。
- 评审对象为本文件的早期版本；下文“原稿行号”仅是当时评审定位，不对应当前正文行号。相关修改已整合到正文，保留这些位置用于解释问题来源。
- 历史原稿SHA256：`32D5D0B69CAB16CBA5542ED037B26EAAE197A8C7623556A4218A52AE7775C7B2`。原备份文件已在本次合并后移除。
- CPU根目录：`E:/donwload/tinyriscv-master/tinyriscv-master`。重点检查core、总线、存储、CSR、中断、仿真入口、启动/异常软件、CoreMark移植与链接脚本，并非穷尽所有RTL路径。
- DDR：重新读取原计划第17节指定的本地`DDR3_50H.v`生成文件，确认其端口不是可直接连接的完整AXI4从接口。
- 旧上下文是另一个YSYX工程；本轮没有把它的16寄存器问题套到tinyriscv。当前`rtl/core/defines.v:159-164`是5位地址、32个寄存器。

### 35.3 必须修改的问题

#### P1-01：写通道owner的描述可能导向死锁

**原稿位置：** 11.3节，原稿541-545行。前面要求呈现AWVALID时锁定grant，后面又说“写owner由AW接收确定”。二者若都指同一个owner而没有区分，实现者可能等AW握手后才放行W。

**反例：** 目标等待WVALID才拉AWREADY；互连等待AWREADY才转发WVALID，则两边永远等对方。CPU自身AW/W独立并不能修复互连内新增的依赖。

**修订：** grant/owner在选择AW请求并开始呈现时锁定；下游AW/W独立前进，不能用AW已完成门控WVALID。增加“目标等WVALID才给AWREADY”测试。错误读burst也必须排空至末拍，不能看见第一拍错误即释放owner。

这是原稿表达歧义及潜在实施风险，不是宣称现有tinyriscv的RIB发生该AXI死锁。

#### P1-02：全局单事务与流水线冻结缺少联合前进性条件

**原稿位置：** 3.1节全局单事务；8.2节EX等待时冻结年轻阶段；9节IFU等待返回；11.3节owner占用到响应结束。

**反例：** IF已经占住互连；EX执行load要申请总线；如果“冻结年轻阶段”也让IF的RREADY变低，那么IF等EX、EX等LSU、LSU等IF释放互连。

**修订：** 发AR前预留返回槽，接收R独立于流水线stall；Cache补行独立消化返回。增加IF占总线且EX等待LSU的交叉测试。禁止向MMIO发取指AR，避免错路取指带来UART读副作用。

#### P1-03：标准中断不能只改RTL与cause数字

**原稿位置：** T07，原稿568-602行，以及文件改造表。

**源码证据：** `rtl/core/clint.v:142`实际写入`0x80000004`；`tests/example/init.c:12-15`只设mtvec/mstatus，没有设mie；`trap_handler.c:4-10`将中断无条件交timer弱函数；`trap_entry.S:56-58`对所有同步异常直接加4。

**影响：** 修正硬件为标准mie/mip门控后，旧timer程序可能不再进中断；新增软件/外部中断若共用旧handler会错误分发；访问错误可能被静默跳过。

**修订：** 增加启动/异常软件文件清单、源映射与清除规则、mie设置、mcause分发、MRET/mstatus/mtvec合法化及回归。限定M模式并保留“赛事是否认可完整措辞需确认”，不擅自扩大为S/U/MMU要求。

#### P1-04：只在retire_fire检查异步中断不够明确

**原稿位置：** 8.2节和T07的“退休后/直到明确退休边界”。

**影响：** EX已经空闲、只有取指等待时可能长时间没有retire_fire；MRET或CSR写更新使能后如果使用旧值，则中断响应会错位。

**修订：** 独立维护arch_next_pc，在架构指令边界检查，包括EX空闲；MRET及相关CSR写后用更新状态检查。已发不可取消事务仍需安全收尾，不能以抢中断为由丢AXI事务。增补定向用例。

**交叉依据：** 本轮直接读取RISC-V官方源码`src/priv/machine.adoc`，其中`intr_mip_mie_bounded_time`与`intr_mip_mie_xret_csrwr`条款要求有界检查及xRET/相关CSR写后的立即重判；实施需冻结具体规范版本。

#### P1-05：CPU、Cache和AXI引擎的归属没有冻结

**原稿位置：** 0.1节、T03/T04的直接AXI FSM、T09的Cache补行。

**影响：** 后期加Cache时不清楚它接在操作接口还是AXI接口；容易重复发store、重复扩展load或重写IFU/LSU端口。

**修订：** 固定“CPU操作接口 -> Cache/旁路 -> 事务引擎”，明确每层职责与原PC/故障/结果返回合同。IFU/LSU是CPU内部原生AXI单元，不使用RIB桥。Cache前后复用事务引擎，T09不推翻EX与流水线接口。

#### P1-06：T02验收依赖尚未完成的T04/T05

**原稿位置：** T02要求真实延迟load-use与完整提交轨迹，但依赖顺序要求T02通过后才能开始T03/T04/T05。

**影响：** 严格照“未通过不得进入下一项”执行会卡在没有真实LSU/总线的阶段；放宽执行又容易把替身模型测试当成SoC已经通过。

**修订：** T02先用受控完成模型验流水线单元，IFU/LSU/互连分别测试，增加T05-I真实CPU集成门槛。明确哪些是单元通过、哪些是完整系统通过。

#### P1-07：来源/贡献和比赛允许范围尚无证据闭环

**原稿位置：** 1.1节仅一句“使用边界以通知为准”，T00未把来源核对作为显式关卡。

**源码证据：** 根目录README介绍开源tinyriscv，LICENSE及多份RTL含上游署名；没有可供本轮使用的Git历史来识别队友全部改动。

**修订：** 增加G0：上游版本/哈希、队友已有改动、本次新增、来源及许可材料、组织方关于复用边界的答复分别保存。

**边界：** 不能凭目录名判断队友没设计，也不能凭该选题PDF断言开源CPU禁止参赛。这里是需要确认的参赛风险，不是违规结论。

### 35.4 应修改的安排与验收

#### P2-01：首次PDS与CoreMark太靠后

原稿T08要求T00-T07全部通过；T13排在Cache和预测器之后。这样会很晚才暴露PDS/板卡、镜像容量或软件移植问题。

已加T00-P早期平台核验；T07拆基础ISA/同步异常与高阶中断；T08拆基础与中断上板；T13拆首次有效跑分、每次优化复测、最终报告。完整JTAG/在线下载可以后置且明确裁剪，不阻塞基础赛题。

保持原生AXI路线无需先实现RIB桥；原RIB仅作为独立参考基线可选，不混入最终工程。

#### P2-02：CoreMark已提规则，但软件落点和证据口径不够

- `lib/utils.c:11-12`是低后高各读一次，回绕时可能读出不一致64位时间。
- `include/utils.h:4-5`写死50MHz；`core_portme.c`还将缩放tick截成32位。
- 当前CoreMark Makefile仅配置PERFORMANCE_RUN；验证种子也需纳入计划。
- 原稿虽要求ILA波形，但未在前期明确必须抓CoreMark算法区间，而非任意测试程序。

已补具体文件、回绕测试、两套种子与CRC、内存map/size检查、真实频率与统计资源边界；不把源代码有64位cycle等同于计时移植自动正确。

#### P2-03：调试和DMA的Cache维护范围不完整

只失效I侧不足以保证debug改数据后CPU读到新内容。共享不可缓存缓冲也需覆盖描述符/张量并冻结具体范围，不只是口头称“图像缓冲不可缓存”。

已补halt后的D/I/BTB维护、无别名共享区、FENCE与编译器屏障、帧所有权。AI启动控制写必须及时返回B，不能等计算结束才返回，否则全局单事务互连会阻塞该AI自己发起的DMA。

#### P2-04：AI范围、吞吐预算和裁剪条件需更清楚

垃圾检测、OV5640、HDMI是队伍选择，不是选题一硬性指定。首版全局单事务可用于验证正确性，但不能因此承诺视频实时性能。

已补CPU回退算子时间、实际持续带宽、相机/特征图/权重流量及单帧优先验收；AI关卡失败不推翻已有CPU成果，也不能把单卷积/CNN样例当作YOLO系统完成。

### 35.5 原计划正确且保留的部分

1. RV32I、不少于三级、冲突与分支、UART/GPIO的基础要求映射正确。
2. 两路I-Cache和两路D-Cache均需实现才能声称完成H1；写直达D-Cache不因没有写回就自动不符合“两路”要求。
3. 原计划已经知道AXI4并非赛题强制，也区分原生AXI与RIB桥；本轮没有把这点误报为原稿缺失。
4. 以valid区分气泡与指令，stall不能套用旧gen_pipe_dff清空语义，这个判断有源码支撑。
5. store等B、错误路径取指排空、窄写WSTRB、不可缓存MMIO、DDR接口先核验，均值得保留。
6. 当前tinyriscv是32寄存器，不需要套用另一个YSYX项目的16改32任务。
7. `tb/tinyriscv_soc_tb.v:57`已有TEST_PASS；原稿这一条件没有错。仍需同时检查TEST_FAIL、Time Out、编译失败及用例数。
8. 本地DDR示例确实缺少标准完整写响应/读回压端口；不能仅因信号名含axi直接接入。
9. 没有证据证明“必须五级”“必须写回Cache”“必须HDMI”或“必须实现S/U/MMU”；不把这些个人偏好写成赛题要求。

### 35.6 队伍需确认的决策

- 比赛实际允许的开源复用/已有成果范围，以及你们可说明的新贡献。
- 原生AXI作为最终目标是否仍坚持；本轮保留，没有擅自改成桥接路线。
- “不要RIB桥”是否允许DDR用户口前端、位宽转换与CDC。建议允许后者，但未代替队伍批准。
- 开发人力、真实可用周数与高阶目标档位。建议先基础闭环，再CPU高阶，再完整AI。
- M-only异常/中断范围是否满足主办方“完整”措辞；是否采用OV5640垃圾检测这项应用选择。

这些未确认项不妨碍阅读和原工程基线核验，但阻止承诺最终全高阶交付。

### 35.7 本轮验证边界

- 已完成：原计划全文审阅、选题一PDF文本与页面目视核对、关键RTL/软件静态核对、本地DDR端口复核、修订计划并保留备份。
- 未完成且未声称：CPU仿真、ISA符合性认证、综合/时序、实际CoreMark成绩、板卡连通性、完整上游差异核对、主办方答复。
- 内置网页搜索没有返回可用结果。通过直接HTTPS读取EEMBC官方CoreMark README及RISC-V官方规范源码作技术交叉核验；Arm在线页面请求失败。正式实施仍需保存冻结规范版本及协议检查证据。
- EEMBC引用定位：官方`eembc/coremark`仓库`README.md`的Run Rules/Required；RISC-V引用定位：官方`riscv/riscv-isa-manual`仓库`src/priv/machine.adoc`的上述norm标签。没有用这些资料代替赛事新通知。
- 源码修改前对243个RTL/软件/脚本/约束及Makefile文件计算聚合SHA256：`36c585d202a440d0f3639b56929953e7bbac1557de2773b16ca5f78dea90edec`。按相对路径排序，每个文件纳入UTF-8路径及内容SHA256；交付前重新核对。

**最终定位：** 这是一份经过第二轮审阅的可讨论、可分阶段细化计划，不是“照抄即可编译”的完整补丁。正文保留T00、T01至T13任务编号以方便对照；细分任务用后缀表示，未执行项继续保持未勾选。

---

## 36. 扩充计划复核报告

日期：2026-10-09。对象：本文件第三轮扩充稿。以下是当时实际复核结果，现归入本合并文档；本次合并没有重新运行CPU仿真或硬件验证。

### 36.1 结论

**已在原计划上新增第25-34章，并完成文档一致性复核和部分独立模板的实际编译/仿真。** 计划可以作为分阶段学习与实施指南；不是完整CPU替换补丁，不代表全部总线/Cache/异常/AI方案已经通过测试，也不保证初学者无需任何调试即可完成。

保留原生AXI4、三级流水线与队友现有算术/译码基础，未擅自改为五级、桥接或全新CPU。没有改动原CPU工程；独立模板检查在临时目录完成，旧div.v只作为只读仿真输入。

### 36.2 本轮新增内容

| 章节 | 内容 | 新手可执行的交付 |
|---|---|---|
| 25 | ISA/流水线/AXI/Cache/retire/trap术语和语法 | 先语法、再原代码、再人话、再指令验证 |
| 26 | 功能建议与N00-N17任务卡映射 | 分清必做、推荐与后置，不混成赛事强制 |
| 27 | 副本与基线、源文件清单、ModelSim runner | 完整28文件清单、Python入口、退出码/日志/超时检查 |
| 28 | 流水线、退休门控、译码、除法 | pipe_slot和div_adapter完整模板及完整单元测试台 |
| 29 | 读写引擎、IFU/LSU、RAM/GPIO/UART、互连 | 明确状态表、信号位宽、逐文件修改卡、反例与期望值 |
| 30 | 异常、中断、启动软件、64位计时 | CSR更新次序、C/汇编衔接、具体软件替换函数 |
| 31 | 两路Cache和预测器 | 同组A/B/C地址、LRU、补行错误、BTB训练与测试 |
| 32 | 性能快照和GPIO采集/控制 | 固定寄存器表、事件定义、采样边界和公平性能对比 |
| 33 | DDR/DMA/AI分阶段方法 | DMA切块、双边4KiB边界、MAC黄金值、模型/IP资料关卡 |
| 34 | 写后复核与使用边界 | 不能把模板通过、软件模拟或文档完成当成上板达标 |

新增功能建议优先级：退休轨迹/错误诊断优先；性能快照和简单GPIO应用推荐；Cache/预测器按高阶目标开展；更多AXI并发、宽DMA、HDMI后置；不建议此阶段增加操作系统、自定义指令或同时五级重构。

### 36.3 写后发现并修正的问题

#### R1：原除法器不能用单周期start直接驱动

源码`rtl/core/div.v`在START、CALC、END反复检查start_i，为0时回到IDLE。原计划的“一次启动”容易被误读为打一拍脉冲。

修订为CPU请求仅握手一次，adapter持续拉start直到旧div输出ready；ready出现后组合压低start防止回到IDLE再启动；结果在独立槽保持到EX消费。已用实际旧div进行9例验证。

#### R2：ModelSim日志检查会误杀正常结果

初稿27.4使用`Fatal|Error`泛匹配，`Errors: 0`也会匹配，导致全部正常测试失败。

改为检测`TEST_FAIL|TIMEOUT|\*\*\s*(Error|Fatal)`，同时必须出现预期TEST_PASS。已验证正常摘要、有Fatal、无PASS、Time Out四种文本。

#### R3：ModelSim onerror的调用位置不对

首次独立仿真发现内联`-do`命令中的onerror/onbreak提示仅供macro使用。调整正式Python runner为先生成run.do再调用；移除会误处理正常finish的多余onbreak。最终独立仿真用run.do执行成功。

负向测试还证实：仿真出现Fatal后显式quit 0可能仍返回进程码0，因此必须检查日志，不能只看退出码。

#### R4：旧第6节和新增第27节的文件清单路径可能冲突

旧说明以sim目录为工作目录，新完整manifest以工程根目录为基准。已将第27节指定为唯一正式入口，第6节Tcl/旧镜像命令标为解释性参考，避免小白混用路径。

#### R5：多处结构归属容易重复驱动

明确pc_reg持有fetch_pc，IFU只保存请求副本，retire_ctrl持有arch_next_pc；EX候选结果由mux选择，不再用旧ALU/div输出按位OR。redirect只清年轻槽，当前EX不因自己的redirect组合失去valid。

#### R6：Cache/DMA/外设边界补充

明确Cache受害way先invalid、错误补行排空、代码失效不允许旧refill重标valid；DMA同时按源和目标4KiB边界切块；UART TX忙写返回错误且驱动先轮询，不能响应成功却静默丢字。

这些是静态设计方法与验证要求，不应解释为上述全部模块已实现并通过仿真。

### 36.4 实际执行的验证

验证目录：

`C:/Users/lenovo/.codex/visualizations/2026/10/09/01a120d3-e77d-7f41-8276-50b3f6de10ec/plan-template-check-xqumv49l`

从计划中提取完整模板到该目录，没有写入CPU源码目录。

| 检查 | 实际结果 | 证据/限制 |
|---|---|---|
| ModelSim版本 | vlog 10.6e可运行 | 非PDS验证 |
| 模板编译 | 0 Errors / 0 Warnings | pipe_slot、div_adapter、checker、两个TB及只读原div |
| 流水线槽 | TEST_PASS N02，196ns | final_pipe.log |
| 除法适配 | TEST_PASS N03_DIV，3716ns | final_div.log，9例 |
| stall错误注入 | Fatal: stall lost A，76ns | negative_stall.log，无PASS；证明该测试能抓此缺陷 |
| 恢复正确模板 | 流水线和除法再次通过 | 临时样本与文档模块逐字比较一致 |
| Python runner | AST语法解析通过 | 未对整套CPU实际执行；不能声称47例已过 |
| 日志判断 | 四种文本判定通过 | 通过摘要、Fatal、无PASS、Time Out |
| manifest | 28个路径均存在 | include清单不等同于完整SoC实际编译结果 |
| 文档结构 | 代码围栏配对，25-34章节齐全，无替换字符 | 文档静态检查 |
| 文件保护 | 原工程全部790文件聚合哈希一致 | 见36.5节 |

除法9例：20/3、-20/3、-20%3、无符号0xFFFFFFFF/2、无符号余数、除0、除0取余、有符号最小值/-1及相应余数；每例额外保持rsp_ready低7拍检查结果保持并检查无重复完成。这不是对所有2^64输入穷尽验证。

稳定性检查器只完成编译，没有独立运行完整AXI通道测试；AXI、Cache、CSR、完整CPU、CoreMark均仍需按任务卡实现和验证。

### 36.5 文件变更与保护证据

- 第三轮扩充前快照曾单独备份；本次按只保留一份文档的要求移除，保留下列历史哈希记录。
- 历史快照SHA256：`3845B8E50861FE0D2BA8C7EA0D199022E9CDBF132FFDE91F80B78205439227A4`，交付前已复核。
- 原工程范围：`E:/donwload/tinyriscv-master/tinyriscv-master`全部790个文件，按相对路径排序，聚合UTF-8路径及各文件内容SHA256。
- 修改前后聚合SHA256相同：`3637ff3566893e3c653c6828375b68388a4b61b624e2ae8743f8d295b4ea798b`。
- 新实现副本`E:/file/pango/tinyriscv_axi4`没有由本轮创建；项目实际实施任务未被勾选为完成。

### 36.6 仍需确认或实测的内容

1. 开源复用与队伍贡献边界、板卡实际型号、PDS实现与主办方认可范围。
2. 完整基线47例、软件工具链/ISA/ABI、CoreMark两个种子及真实>=10秒运行。
3. AXI读写/互连/从设备实现、随机回压、CPU集成、CSR/异常精确性与Cache/预测器回归。
4. DDR IP用户口真实契约、数据宽度/CDC/写完成、板上校准；不能凭模板确认可连。
5. 具体YOLO图/权重/量化、资源/带宽预算、独立数据集精度和完整单帧软硬协同。

本轮内置网络检索未返回可用结果，未据此宣称获得新的赛事规则或最新协议版本。赛题依据沿用本聊天已核对的用户PDF第10-11页；技术细节实施时仍需冻结规范版本。复核是本轮自查和工具检查，没有声称另一个独立审查代理已经审批。

### 36.7 第四轮并发控制复核

本轮针对“取指内部接单窗口、FENCE.I年轻指令、halt当前EX请求”重新反向审查。结论不是因为提出者身份而采纳，而是逐项按握手所有权、精确架构状态和可终止性判断：

1. **取指建议成立，按P1处理。** 原规则若只从ARVALID/AR握手开始标旧请求，会漏掉内部`req_fire`到外部AR之间的窗口；redirect与`req_fire`同拍也可能因寄存器旧值漏标。计划现规定所有权从内部握手开始，并补四个相位及连续redirect测试。
2. **FENCE.I建议成立，但带ISA边界。** 若声明Zifencei，只清I-Cache而不清IF/ID、预取和在途补行，旧代码仍可能执行；因此采用独立维护流程并从FENCE.I PC+4重取。若不准备完整实现，则必须非法指令并从工具链移除Zifencei，不能半支持。自修改代码测试只在明确可写且可执行RAM中有效。
3. **halt建议成立，项目优先级可记P2，但T06内部是阻断项。** 若halt禁止当前EX尚未发出的必要load/store/div请求，会形成halt等待完成、操作等待许可的死锁。计划现用`halt_pending`只封锁年轻工作，让当前EX恰好启动一次并完成；异常和真实redirect先形成正确`arch_next_pc`再停。
4. **一致性复核结果。** 前文T03、T06、T07、N02/N04任务卡和停止条件已经统一为“已接受事务必须协议收尾，结果按有效性提交或丢弃”；未再发现与这三条规则直接矛盾的旧描述。

本节仍是静态设计复核，不代表故障已在真实CPU复现，也不代表修订后的RTL已经仿真通过。实施时必须用本节列出的定向测试证明规则落地。

**交付状态：** 文档扩充与上述验证完成；仍停在计划阶段。下一步先由队伍确认G0与功能范围，获准后按N00/N01开始真实工程基线，不直接把所有模板一次性并入CPU。

---

## §5 优化 roadmap（2026-10-17）

*原文件：`docs/design.md`*

### pangoriscv 分数优化路线图（2026-10-17）

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
| **P0/P1 测量** | 完成 | 访存 36.5% / 取指饥饿 18.1% / 预测 1.8% / 除法 0.04% | `evidence/records/optimization/early/P1-measurement.md` |
| **P2 D-Cache 扩容** | **否决** | 2→8 KB 只快 0.53%，面积 ×4 | `.../P2/` |
| **P2' store 路径** | **采纳** | **周期 −8.98%**（ticks 15,316,450→13,940,928），等 B 从 1,775,055→3,808 拍；CRC 一致、ISA 15/15 | `.../P2-store/` |
| **P4 分支预测** | **否决** | 64/128 项快 1.68%/1.84%，但 LUT +15%/+32%，指标③ −12%/−23%，净亏；恢复 32 项 | `.../P4/` |
| **P5 时钟频率** | **完成（实验）** | 50 MHz 过约束收敛，WNS +2.372 ns，0/66,247 失败；27 MHz 交付约束 WNS +17.920 ns | `.../P5/` |
| **P7 IFU 取指吞吐** | **完成（采纳）** | 两笔未完成请求 + I-Cache 背靠背命中：**周期 −12.97%**（ticks 13,940,928→11,887,687，−14.73%），`if_wait` **−77.30%**（3,269,814→742,122），`lsu_wait` 纹丝不动；CRC 逐项一致、ISA 15/15 | `.../P7/` |
| **P8 访存快发** | **完成（采纳）** | LSU 请求改在受理拍发出、命中则跳过 `REQUEST`：**ticks −9.71%**（11,887,687→10,733,373），`LSU request` 1,852,431→**490,318**，`ex_mem_post` −1,265,115；面积仅 **+41 LUT（+0.31%）**、触发器零增量 | `.../P8/` |
| **P9 完成提前报** | **完成（采纳）** | 访存完成改在引擎响应拍报出、响应后直接回 `EMPTY`（`COMPLETE` 仅作反压保持）：**ticks −10.67%**（10,733,373→9,588,579），`LSU complete` 1,600,800→**0**，`ex_mem_post` −1,284,003；面积 **+40 LUT（+0.31%）**、触发器零增量 | `.../P9/` |
| **P10 零延迟命中** | **完成（采纳）** | D-Cache 命中改在**受理当拍**应答（跨 `dcache`/`lsu`/`pangoriscv` 三文件）+ 写请求在受理拍就交给写引擎：**ticks −12.07%**（9,588,579→8,432,493），`rdwait` −882,642、`wdata` 精确减半；面积 **+499 LUT（+3.82%）**、触发器零增量 | `.../P10/` |
| **P13 读命中不阻塞** | **完成（采纳）** | 读命中只需要 RAM，不必等写状态机：`req_ready`/`accept_hit` 允许在 `ST_WR_HOLD`/`ST_WR_DRAIN` 期间受理读：**ticks −7.64%**（8,432,493→7,788,468），`LSU request` 708,411→**244,654**；**面积与触发器零增量** | `.../P13/` |
| **P14 store 当拍拿确认** | **完成（采纳）** | "早释放"的 OKAY 在 W 握手当拍就交给 CPU（P13 打通读路径后重做）：**ticks −1.67%**（7,788,468→7,658,647），`wrwait` 291,155→**4,140**；面积 **+18 LUT**、触发器零增量。同步把 halt-reset 场景 2/4 的注入点从 LSU `WRITE_WAIT` 换成 **AW 握手**（更准且不依赖缓存实例化） | `.../P14/` |
| **P16 突发气泡清除** | **完成（采纳）** | `axi_ram` 在 READ_DELAY=0 时仍在 READ_WAIT 白等一拍，致使每个突发拍要 3 个周期：去掉后 **ticks −2.35%**（7,658,647→7,478,647），if_wait −134,008，I-Cache 填充 26→18 拍/缺失；**面积 −2 LUT / −2 FF** | .../P16/ |
| **P17 LRU 修复** | **完成（采纳）** | 独立复核 R03：P10 的快命中路径直接回 `ST_IDLE`，跳过了写在 `ST_HIT` 里的 LRU 更新 → 替换退化。补上同值更新后 `d_miss` **4,655→4,270（−8.3%）**；重新出分 **2.6740→2.6757**，并按复核意见把 27/50 MHz 的 slack 改引 `multiseed_summary.csv` 收尾值、LUT 标明 device_map 阶段 | `.../P17/` |

## 当前交付状态

- **CoreMark/MHz**：**2.6757**（768 迭代有效跑分，ticks 287,030,751，10.63 s，
  `Correct operation validated`，五项 CRC 正确）
  - 上一版为 2.6740（P16）→ 本轮 **+0.06%**；本版主要修掉复核 R03（LRU 漏更新）
  - 链条：S0 1.3054 → store 1.4342 → 取指 1.6815 → 访存快发 1.8622 → 完成提前报 2.0843
    → 零延迟命中 2.3708 → 读命中不阻塞 2.5674 → store 当拍确认 2.6109 → 突发气泡清除 2.6740 → **LRU 修复 2.6757**
    （累计 **+104.97%**）
- **频率**：**27 MHz 与 50 MHz 约束均 All Constraints Met**
  - 27 MHz：setup WNS **+14.578 ns**、hold WHS **+0.115 ns**，0 失败端点（取 `multiseed_summary.csv`）
  - 50 MHz 过约束：setup **+1.262 ns**、hold **+0.121 ns**，0 失败端点
- **资源**：**13,481 LUT（device_map）**，synthesis 为 13,574、后布线更小 —— 引用必须写阶段；
  触发器 8,507；CoreMark/LUTs **0.1985 每 kLUT**（累计 +91.24%）
- **回归**：单元 5/5、ISA 15/15、ram 40/40、halt-reset 5/5、IFU 引擎 20/20、dcache PASS

**PDS 收敛经验（务必保留）**：27 MHz 的 hold 必须用
`-fix_hold_violation_threshold 500`（不是 300），否则留下 1~5 个 −0.001~−0.027 ns 端点
（D-Cache LUTRAM 写口跨时钟树分支偏斜）。**50 MHz 是种子敏感的**：本版 seed 11→−0.001、
seed 41→−0.155、seed 23 才通过，换一次 PnR 就可能不收敛。

**下一步：性价比已到拐点，建议不要再加功能，转上板验证。**

计分窗口的**精确**分解（新增 `SCORE_WINDOW`/`EX_SPLIT`/`DCACHE_PATH`/`ADDR_REGION`/`MISPRED_MIX`
探针，以"第一次写 UART TXDATA"为窗口边界；20 迭代，`sw_cycles=7,694,091` ≈ `ticks=7,658,647`）：

| 来源 | 拍数 | 占额外开销 | 结论 |
|---|---|---|---|
| `if_wait`（取指饥饿 ≈ I-Cache 缺失 × 43 拍） | ~775 K | **40.5%** | 见下，**已实测否决** |
| store 占 EX（2.3 拍/笔） | 681 K | 35.6% | 下限 2.0 拍，只剩 0.3 拍（1.2%） |
| 分支预测失败 | ~308 K | 16.1% | 72.9% 是普通分支；BTB 加倍要 +15~32% LUT，**③ 净亏** |
| load 占 EX | 148 K | 7.7% | **已经免费**（受理即退休 + 寄存器堆写透前递） |

> 早期按 `report_seen` 门控的统计是**有偏的**——它直到报告最后一行才置位，
> 会把整段报告打印（UART 忙等 0x3000_0000）算进去，导致误判 load 占 54.8%。

**已实测否决：I-Cache 2 KB → 4 KB（组数 32→64）**
- 收益：`i_miss` 18,289→8,913（−51%）、`if_wait` −245 K、**ticks −3.44%**、CM/MHz 2.6109→2.7040
- 代价：**LUT 13,576→14,667（+8.04%）、FF 8,639→10,016（+1,377）**
- 三项算下来 **① +3.56% 但 ③ −4.11%**，净亏 → **已回退**（`icache_axi.v` 与 HEAD 逐字节一致）
- 早起动（early restart）同样不做：CPU 恢复后下一条取指仍落在正在填充的行上，只是把停顿挪位置

明确不再碰：D-Cache/BTB 扩容、I-Cache 扩容、非法提频（板载 27 MHz）。
**要继续压 ① 就必须付面积（③ 的分母）或改流水线结构**（从 ID 发访存 / 双发射），
余下价值在上板验证（ILA 波形、实板串口实测）而不是再挤百分比。

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

---

## §6 CoreMark 优化文献综述

*原文件：`docs/design.md`*

### tinyriscv-AXI4 RV32IM 软核：CoreMark 提分文献调研（有引用来源）

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

---

## §7 实施状态

*原文件：`docs/design.md`*

### 实施记录

最新范围：用户要求先完成基础版，Cache、动态预测、DDR、DMA、AI
暂不实施。用户将完整验证交给其他AI；后续“语法编译通过”不代表
仿真、综合、上板或比赛验收通过。

> **板级资料核对轮更新（m03415，2026-10-11）—— 本文件中的 "50MHz / 20ns" 均为修改前的历史记录。**
> 本文件写于 T00-T02 实施期，当时按"板钟 50 MHz"假设工作。官方资料已证明板载系统时钟是
> **27 MHz 单端晶振 → D18，周期 37.037 ns**（教程1 §2.1.2.2.3.2；教程2 §7.2「27MHZ…周期约为 37.037ns」；
> 官方 `2_8_uart_test` 的 `uart_top.v` 分频 234 = 27e6/115200）。因此本文件中出现的
> `50MHz`、`20ns`、`setup slack 16.588ns`、LED 例程时序报告等数值只描述**当时**的排查过程，
> **不能**当作当前工程的板钟或时序结论。
> 当前约束、镜像、PDS 复验与上板步骤见 `09_validation_results/board_material_audit/`
> （`01`~`05` 与 `BOARD_MATERIAL_AUDIT_FINAL.md`）。

日期：2026-10-10。唯一实施依据为上级目录
`docs/superpowers/plans/2026-10-09-tinyriscv-native-axi4-contest-plan.md`。
此文件只记录执行结果，不是第二份计划。获用户本轮授权进入实施，原计划中的
“本轮只修改计划”属于历史记录；其测试依赖和停止条件继续生效。

## 修改前赛题核对

已重新提取并目视核对用户提供的紫光同创选题指南 PDF 第10页，
提取第11页。证据保存在 `docs/evidence/baseline/`，
包括两页 PDF、文本、渲染图、原 PDF SHA256 和批准计划的快照。

结论：计划对选题一的需求映射相符，可以按关卡开始实施；
这不是最终代码符合性或参赛资格确认。

| 赛题要求 | 计划覆盖 | 尚需取得的实施证据 |
| --- | --- | --- |
| RV32I、至少三级流水线、数据冲突与分支 | B1/B2、T02/T05-I/T07a | 真实CPU回归和提交轨迹 |
| UART/GPIO基础外设 | B3、T05/T08a | 本板输出与控制演示 |
| 两路组相联指令和数据Cache、突发效率 | H1、T09 | 两侧Cache测试及优化前后对比 |
| 动态预测及完整异常/中断 | H2、T07b/T10 | 功能矩阵；M-only范围需确认 |
| YOLO或轻量大模型与传感/显示集成 | H3、T11/T12 | 模型、DDR契约、完整应用实测 |
| 指定工具链、CoreMark v1.0至少10秒 | E2/E3、T00-P/T13 | 实际编译、CRC、时钟、运行时间 |
| 性能、资源、时序及CoreMark关键算法波形 | E4/E6、T13 | PDS实现报告及板上采集 |

AXI4、不使用RIB桥、OV5640、HDMI不是赛题强制要求。
本轮保留用户批准的原生AXI4路线。不能把基础阶段完成说成高阶任务全部完成。
开源许可不等于比赛允许复用已有CPU；组织方答复及队伍贡献声明仍待提供。

## 备份与隔离

- 原始目录：`E:/donwload/tinyriscv-master/tinyriscv-master`，只读使用。
- 完整备份：`E:/file/pango/backups/tinyriscv_original_20261010_01`。
- 实施副本：`E:/file/pango/tinyriscv_axi4`。
- 修改前790个文件逐一比较SHA256，原目录、备份、副本一致。
- 清单：`docs/evidence/baseline/original-files.sha256.csv`。
- 原始Git提交：`6741872`，工作分支：`implementation/native-axi4`。
- Git原始提交记录787个文件；另外3个文件受原忽略规则影响，
  但全部790个文件均包含在独立完整备份与哈希清单中。

## 关卡状态

| 任务 | 状态 |
| --- | --- |
| 修改前核对赛题与计划 | 已完成本地PDF对照，保留以上待确认边界 |
| 完整备份及实施副本 | 已完成并校验 |
| G0来源与贡献 | 记录本地来源；上游提交、队友改动、赛事书面答复待提供 |
| N00/T00工具链 | ModelSim可用；已取得真实riscv32-unknown-elf-gcc 7.1.1，默认libgcc含C扩展，完整无C构建尚未验收 |
| N01测试入口 | 28项清单及runner已新增，15项Python测试通过，含真实进程树超时清理 |
| N01新编译原CPU回归 | 两处声明顺序兼容修复后，add及47/47预编译指令镜像通过 |
| T00-P平台前置 | 本轮ADS重新编译/综合/布局布线/位流完成，20ns时钟；尚未下载上板 |
| T01独立AXI环境 | 已实现，最终复测结果见下文 |
| T02流水线 | 已替换为操作接口CPU，保留原译码/ALU/div算法；单元测试27退休/9异常/5访存通过，尚未接AXI SoC |
| T03/T04 | IFU真实读引擎20 seed通过；LSU真实数据引擎/RAM20 seed通过，尚未接CPU整体 |
| N04/N05引擎 | 单拍读/数据AXI引擎64项测试本轮重跑通过，规范及质量复核通过 |
| N06 AXI RAM | 单拍RAM及真实LSU集成40/40通过，规范/质量复核通过；GPIO和实际综合未完成 |
| N07 IFU/LSU | 操作单元及引擎组合已实现，完整CPU接入待N09 |
| N08 互连 | 原生互连/error slave已写入，语法编译0错误0警告；按用户要求未仿真 |
| N09 CPU接入 | 原生CPU封装、2主2从SoC及production manifest已写入，语法编译通过；未运行指令 |
| N10/N12 CSR/中断 | 原生CSR、同步异常、MRET和中断边界代码已写入，语法编译通过；未仿真 |
| 基础外设接入 | UART/GPIO/Timer/SPI/IRQ共7目标SoC已写入，语法编译通过；未仿真 |
| 基础软件 | 启动/异常/计时已改，CoreMark无libgcc构建已编译链接；未运行 |
| 基础板级工程 | 顶层、官方引脚约束、PDS脚本已写入；语法编译通过，未综合/上板 |
| Cache/预测/DDR/DMA/AI | 按用户最新要求暂不实施 |

当前Python使用Codex运行时的完整路径，不依赖失效的`py`默认解释器配置。
已发现WCH交叉编译器，但未用它替代赛题指定的`riscv32-unknown-elf-gcc`，
也未修改现有软件Makefile去假装已经满足指定工具链要求。

## 复现入口

在实施副本根目录使用：

```powershell
$python = 'C:\Users\lenovo\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
$env:PATH = 'E:\donwload\win64;' + $env:PATH
& $python sim/run_baseline.py --case rv32ui-p-add
& $python sim/run_baseline.py --all
```

预编译的ISA测试镜像只能验证此次新编译RTL对这些镜像的行为，
不能证明本机已重新编译测试软件，也不构成完整RV32I认证。

## N01失败定位与已授权修复

新增文件为 `sim/baseline_sources.f`、`sim/run_baseline.py`、
`sim/test_baseline_runner.py`；原有仿真脚本保留。
runner按第27.3节实现，仅抽取日志判定与镜像转换函数用于单元测试。
15项测试已复跑通过，包括进程返回0但日志Fatal时必须拒绝、缺少或重复PASS、
失败/超时标记以及不足四字节的镜像尾部填充。

实际执行 `--case rv32ui-p-add` 返回1，编译日志位于
`.sim_runs/baseline-kgd50ugy/compile.log`，精简证据副本保存在
`docs/evidence/baseline/first-compile-failure.log`。

- `rtl/utils/full_handshake_rx.v:60,68`：`req`在第81行声明之前使用。
- `rtl/utils/full_handshake_tx.v:71,79`：`ack`在第92行声明之前使用。
- ModelSim 10.6e报告 `Errors: 4, Warnings: 0`。
- 仅去掉`-sv`再编译这两个原文件，同样失败；不能归因于`-sv`单一选项。
- 该首次失败时add仿真没有启动；后续结果见下面，不能覆盖原失败证据。
- 不通过关闭JTAG、删源文件、压制错误或复用旧仿真产物绕过失败。

用户再次明确授权后，已仅在实施副本将上述声明移到首次使用之前，
保留逻辑、端口、复位和同步级数。这是原工程编译兼容修复，不是AXI CPU改造。
修改前源码再次备份至
`E:/file/pango/backups/tinyriscv_source_before_resume_20261010_171938`，
805个文件哈希一致；本次不含`.git`和存在访问限制的旧`.sim_runs`。
之前790文件完整原版备份继续保留。

新编译日志：`.sim_runs/baseline-3wl8mqev/compile.log`，
0 Errors / 0 Warnings。该目录47个用例日志全部唯一PASS，
当时逐项日志位于 `evidence/records/baseline/compatible-original/`，该目录已于 2026-10-18 清理（属早期 2026-10-10 的兼容性验证，已被后续 ISA 15/15 与优化轮次取代）。
ModelSim仿真各日志含15条原模型警告，未隐藏；
PASS只表示这些预编译镜像通过，不证明完整ISA、FENCE.I维护或本机软件编译。

`sim/check_baseline_negative.py`在隔离副本将真实TB成功条件固定false，
实际产生TEST_FAIL并被runner拒绝，原TB哈希未变。
日志：`.sim_runs/negative-ngbjb5w2/rv32ui-p-add-negative.log`。
随后add重跑通过：`.sim_runs/baseline-4yicpcw9/rv32ui-p-add.log`。
Python超时测试实际启动父/子进程并检查二者结束，15/15通过。

## T01与后续关卡

新增完整AXI字段的验证接口、字节内存模型、监视器、测试台与PowerShell入口。
测试覆盖同拍、AW先5拍、W先5拍，WSTRB与窄访问，
R/B阻塞7拍、8拍随机等待突发、未映射读写错误、读写同时请求、
ID/拍数/LAST/稳定性及结束清空。固定seed 1至20。
故意改变受阻AR地址必须触发`AXI_MONITOR AR_STABILITY` Fatal。
最终复测20/20通过，负向注入被检测，编译0 Errors / 0 Warnings。
最终目录：`.sim_runs/t01-eeb3241ce7ea4171ab04f71e5d9f1548/`，
日志证据副本位于`docs/evidence/axi/`。这仅是验证环境验收，
不是CPU原生AXI、Cache或SoC集成通过。

`docs/cpu_memory_contract.md`已按计划冻结接口与生命周期。
`pipe_slot.v`和`div_adapter.v`已实现并通过独立测试及规范/质量复核。
覆盖无替换消费后不重复输出、除法持续请求时只接收一次、
立即消费结果、活动运算/被阻塞结果期间复位及恢复。
除法测试14次请求、12次响应，另外2次被复位取消。
负向停顿清valid注入触发`stall lost A`。
日志：`.sim_runs/unit-pipe_slot-ngubucut/`、
`.sim_runs/unit-div_adapter-fdouod0n/`、
`.sim_runs/unit-pipe_slot-z5nwzkkn/`（预期失败）。
T02完整流水线控制链正在实施，尚未集成验收。

本轮新增修改前备份：
`E:/file/pango/backups/tinyriscv_before_cpu_20261010_174502`，
887个文件复制后逐一哈希一致，不含`.git/.sim_runs/__pycache__`。

已实际排查PDS：Synplify许可未配置，但原工程使用的ADS路径可用，
不能把Synplify失败泛化成PDS不可用。首次批处理约束加载过晚，
时序报告使用默认1000ns，不算50MHz通过；修正后于17:58:53生成
新的20ns报告，请以`docs/evidence/platform/counter_led.rtr`为准，
requested 50MHz、setup slack 16.588ns。这是LED例程，不是CPU时序。
位流生成完成，SCBV尚有配置提示，未下载板卡、未取得现场输出。
复现脚本及日志见`docs/evidence/platform/`。

指定编译器已经获取；实际板卡下载、DDR标准接口仍待验证。
继续实施不依赖这些物理输入的RTL单元，不以仿真代替上板关卡。
完整计划尚未完成。
原目录与完整备份各790文件已再次按原哈希清单通过核验。

## 流水线与操作单元本轮续作

新增 `retire_ctrl.v` 并改造 IF/ID、ID/EX、PC、控制与CPU连接。
EX当前采用内部操作接口，不再接旧RIB。CSR/SYSTEM/FENCE.I暂按非法
指令处理，尚未完成T07；不能把此阶段结果当成完整ISA符合性。
原CPU模块复制到 `tb/reference/`，仅由独立baseline manifest使用，
不会混入新CPU。隔离后原镜像47/47再次通过，
日志 `.sim_runs/baseline-uhlxnx_7/`。

流水线新日志 `.sim_runs/pipeline-74kt4oc2/`：
27次退休、9次异常、5次访存，0 errors / 0 warnings。
测试包括真实排队年轻fault的分支冲刷、正确路径取指fault、
访存ready背压及halt排空、load/store总线错误等待trap_ready、
依赖旁路、除法、JALR bit0和目标对齐。只读复核确认原三项覆盖缺口已补齐。
老分支停顿使用测试台force模拟EX延迟；不是真实AXI系统回归。

`ifu_axi.v` 保存请求PC/预测PC及保留返回槽，从内部握手起标记在途。
重定向排空旧请求并丢弃错误返回；只允许程序RAM取指。
`lsu_axi.v` 保存操作身份，生成窄访问数据/WSTRB并只扩展一次，
对齐失败不发总线描述符，store只在B返回后完成。
描述符层测试：
`.sim_runs/unit-ifu_axi-7cnqe9gp/`（5请求/5结果），
`.sim_runs/unit-lsu_axi-wc812hjh/`（10请求/3写/13完成），均0 errors。
这些模块与真实AXI引擎、互连、RAM尚未整体集成，不标完整T03/T04完成。

引擎已有证据：
`.sim_runs/engines-o6jthykx/`、`.sim_runs/engines-hw-2td27ph0/`，
40个正常seed、12个预期fatal、12个SYNTHESIS宏故障保持用例。
首版只接受len=0；突发留到T09，不能称现有引擎已支持Cache补行。
SYNTHESIS宏仿真不代表实际综合通过。

工具链压缩包位于上级 `toolchains/openisa-1.0.0-windows.zip`，
SHA256 `7E5D27F7B71F578547A9CEE87A6C6E4A9AF1055045DD8C6F8673E8570C9D5E9C`。
GCC实际安装于 `toolchains/openisa-1.0.0/gcc/riscv32-unknown-elf-gcc/bin`。
原CoreMark试编译目录 `.sim_runs/coremark-original-build/`，
ELF含RVC及libgcc压缩指令，故该镜像不能用于当前无C CPU验收。
计时端口尚需64位整数转换与high-low-high读取修正；
不得改CoreMark关键算法或把编译成功误报为CPU运行成功。

## 追加独立复跑与复核

引擎本轮独立复跑：
`.sim_runs/engines-m9mses1p/`、`.sim_runs/engines-hw-lbdyl_ok/`，
64/64通过。规范及质量复核均通过，只适用于单拍引擎。
仍缺主动保持第二个请求的争用用例；SYNTHESIS宏只跑故障路径，
不把普通功能宏等价性、综合和板测算作已验证。

流水线质量复核新增并修复重定向断言：
正常分支/JALR纠正、trap向量与halt-resume的redirect信号及目标
都在实际发生边沿检查，覆盖计数2/9/2，并拒绝额外redirect。
取指描述符层用不同指令字并在返回后改变输入，逐拍检查保持数据，
不再仅检查PC。两项修复经只读质量复核通过。
父任务独立复跑日志：
`.sim_runs/pipeline-ek0auz54/`，
`.sim_runs/unit-ifu_axi-bnlebxa0/`，
`.sim_runs/unit-lsu_axi-6j16186m/`，全部通过。

新增真实IFU/read-engine测试 `tb/axi/tb_ifu_axi_engine.sv`，
入口 `sim/run_ifu_engine_tests.py`。
20 seed独立复跑 `.sim_runs/ifu-real-engine-e2i8mpn9/`，每例
14次内部请求/AR/R/引擎结果、8次有效交付，其余旧请求被排空丢弃。
覆盖内部接单边沿、AR受阻、等待R、引擎RD_HOLD与IFU返回槽，
连续redirect、旧错误返回、正确路径fault和禁用期间排空。
规范及质量复核通过。负向临时指令清零变异被检测：
`.sim_runs/ifu-real-engine-55qoqzpt/`。
测试台手动提供新PC，不宣称CPU自主重启取指或真实指令退休已联测。

## RAM Endpoint Integration

Added `rtl/perips/axi_ram.v`: synchronous 4096-word memory, optional
initialization, no array reset, checked full-address indexing, independent
AW/W capture, byte enables and held responses. Unsupported bursts are
fully framed SLVERR transactions; malformed WLAST fails closed. Actual
cache-fill bursts remain for T09.

Added standalone RAM and real LSU/data-engine/RAM benches plus
`sim/run_ram_tests.py`. Fresh parent run `.sim_runs/ram-19d8d_wx/`
passed 40/40 (20 RAM and 20 LSU seeds). Specification and quality reviews
approved this subset. Real LSU coverage includes SW/LW/SB/LBU, bus errors,
local alignment rejection and 20/30-cycle read/write target delays.
The arithmetic result in that bench is a testbench model, not CPU execution.

Still unverified: full lane coverage in the real composition, malformed
mid-burst WLAST, maximum LEN, PDS BRAM inference, GPIO and full T05/CPU.
Supported RAM parameters assume word-aligned BASE_ADDR, positive WORDS
and nonnegative delays.

N08 interconnect/error-slave code is implemented; syntax-only compilation
reported zero errors and warnings. No interconnect simulation was run.
Original reference modules remain isolated and unchanged.

## Code-First Handoff

User delegated full verification to another AI. Subsequent code changes
receive syntax checks only, not acceptance claims. Verification instructions
are in `docs/external-verification-plan.md`.

N09 added `tinyriscv_axi_top.v`, `tinyriscv_axi_soc.v`,
`native_axi_macros.vh` and `sim/native_axi_sources.f`. Packed port zero
is instruction and port one data. The SoC connects both engines through
the interconnect to program/data RAM without RIB. Program RAM disables
writes via the new optional RAM `WRITE_ENABLE` parameter. Halt drains
existing work and engine/fabric faults block fresh acceptance.
Native-manifest syntax compile passed with zero errors and warnings.
This is not native ISA execution, synthesis or board evidence.

## Basic Version Delivery

Latest user scope defers Cache, prediction, DDR, DMA and AI. No such
advanced implementation was added.

Native CSR/interrupts and seven-target peripheral SoC code are present.
Software startup, trap dispatch, 64-bit timing and freestanding CoreMark
build were updated. CoreMark compiled/linked with GCC 7.1.1 without
libc/libgcc; execution and CRC/duration are unverified.

Board entry: `rtl/soc/pango_native_top.v`.
Build instructions: `platform/pango_native/README.md`.
Official UART pins are TX C24 / RX B24; provenance is recorded there.
The PDS SystemVerilog project setting must be enabled externally before
the provided build script is used; its Tcl equivalent is not established.
No native PDS synthesis, timing report, bitstream or board run was performed.

Final basic-release manifest includes `pipe_slot.v` and the board top.
Fresh library `sim/native_release_load_work` compiled and loaded
`pango_native_top` with zero errors and warnings. Logs:
`sim/native_release_compile.log`, `sim/native_release_load.log`.
The load command immediately quit; no simulation `run` was issued.

---

## §8 基础版最终实现

*原文件：`docs/design.md`*

### 基本版本落地实现记录（2026-10-10）

> **板级资料核对轮更新（m03415，2026-10-11，最新）—— 本文所有 "50 MHz" 一律作废。**
> 官方板卡资料证明本板系统时钟是 **27 MHz 单端晶振 → D18**（教程1 §2.1.2.2.3.2；教程2 §7.2 与 §7.3；
> 官方 `2_8_uart_test` 的 `uart_top.v BPS_NUM = 234`），板上没有 50 MHz 晶振。
> 本轮据此修改了 `platform/pango_native/pango_native.fdc`（37.037 ns）、`rtl/perips/axi_uart.v`（分频 234）、
> `tests/example/include/utils.h`（`CPU_FREQ_MHZ 27U`）、`tests/example/lib/uart.c`（写 `UART0_BAUD`）、
> `tools/build_native_software.py`（默认 `--cpu-mhz 27`）、三个测试台分频常量、`platform/pango_native/build.tcl`
> （`PANGO_NATIVE_FDC` 覆盖 + 板钟/镜像一致性检查 + 空 ROM 守卫）与 `platform/pango_native/README.md`。
> **本轮改动的逐条记录（旧值/新值/证据/影响/哈希）以
> `09_validation_results/board_material_audit/03_CONSTRAINT_CHANGE_LOG.md` 为准**；
> 复验结论见同目录 `04_PDS_REVALIDATION_REPORT.md`。

> 本文记录"把基本版本做完"这一轮（任务 m01844）对生产文件的**全部**改动。
>
> 阅读边界：`09_validation_results/BASIC_VERSION_VERIFICATION_REPORT.md` 是**验证轮**的报告，
> 该轮的边界是"不改生产文件"，因此它写的"RTL / C / 汇编 / 板级约束未做任何修改"只对该轮成立。
> 本轮（实现轮）的任务就是按验证轮给出的最小修复建议把问题修掉，所以**有**生产文件改动，逐条列在下面。
>
> 全部改动前都有备份，见 §7。

工程根：`E:\file\pango\project\01_code\tinyriscv_axi4`
所有仿真 / 综合命令都必须在该目录下执行（`sim/native_axi_sources.f` 内是相对工程根的路径）。

---

## 1. 改动总表

| # | 文件 | 性质 | 解决验证轮的哪个问题 | 回归证据 |
|---|---|---|---|---|
| 1 | `rtl/bus/axi_interconnect.v` | RTL 修复 | S1（PDS `bmsSMOD` 无法映射，综合直接失败） | `run_interconnect_tests.py --seeds 20` → 20/20 PASS；PDS 综合通过 |
| 2 | `rtl/perips/axi_ram.v` | RTL 修复 | S5（全清单唯一的 SystemVerilog-only 构造，逼着 PDS 开 SV 前端） | 29 源整体编译 0 error；RAM/LSU 40/40 PASS |
| 3 | `platform/pango_native/build.tcl` | 工程脚本修复 | S4（`pds_shell -file` 下相对约束路径不可读，流程 `Flow-0049` 中断） | 完整 PDS 流程 exit 0，产出 `.sbit` |
| 4 | `tb/unit/tb_pipeline.sv` | 测试台修复 | S2（回归台还在连已废弃的 `trap_vector` 端口，跑起来数值就是错的） | `run_pipeline_tests.py` → `PASS N03_PIPELINE` |
| 5 | `rtl/soc/pango_native_top.v` | 可观测性增强 | S6（CPU 内部状态没有引出观测点，板上无法抓 ILA） | 编译 0 error 0 warning；端口未变 |
| 6 | `tests/example/coremark/core_portme.c` | C 修复 | S8（CoreMark 用时只能靠 32 位 `Total ticks` 打印，长跑必然截断） | 1 迭代 CRC 与黄金值一致；200 迭代 `Total ticks 655032761`（13.1007 s ≥ 10 s）、成功行前缀、无 `Errors detected` |
| 7 | `tb/integration/tb_coremark_uart.sv` | 测试台增强 | —（让 CoreMark 回归能自己认出报告结尾，不必烧满周期上限） | CoreMark 回归正常收敛 |
| 8 | `platform/pango_native/README.md` | 文档 | S6 余项（ILA 探针清单与触发配方） | — |
| 9 | `tests/halt_reset/*`、`tb/integration/tb_halt_reset_drain.sv`、`tools/run_halt_reset_tests.py` | **新增**测试覆盖 | 清单第 5 项（halt/reset 事务排空与恢复） | 5/5 PASS |
| 10 | `rtl/soc/pango_native_top.v`（**同一文件再改一次**） | RTL 修复（收尾轮） | **新发现**：第 5 项用的 `(* keep = "true" *)` 被 PDS 拒绝（`PAP_KEEP` 值非法），19 个观测点里 14 个 + 两个计数器**根本没进网表**；`(* ASYNC_REG = "TRUE" *)` 也是非法属性 | 见 §13：新网表中 18 个 `obs_*` 名全部存在；29 源重新精化 0 error 0 warning；完整 PDS 流程重跑 |

前 8 项都是**最小修复**：只动必须动的那几行，不改架构、不改接口、不降断言。
第 10 项是**收尾轮**（任务 m02843）的追加修复，原因、证据、影响面见 §13。

**改造轮（修复前）综合/实现结果（一句话，证据见 `05_verification/native-basic-final-status.md` §4）**：`pds_shell` 完整流程 exit 0，`Design Summary : All Constraints Met`；Slack Setup `WNS 3.258 ns`（慢角，29238 端点 0 失败）、Hold `WHS 0.139 ns`；关键路径 20 − 3.258 = 16.742 ns（等效 Fmax 约 59.7 MHz，**推算**），50 MHz 板振下有余量；`Total LUTs 7622 / 66600 (11.44%)`、`Total Registers 2984 / 133200 (2.24%)`；比特流 `build/pango_native/generate_bitstream/pango_native_top.sbit`（3791112 B，SHA256 `A8D616B3…`）。**未上板下载。**（**以下数值已被收尾轮取代，见下方引用块与 §13.4**）

> **上表的时序/资源/比特流数值已被收尾轮（任务 m02843）取代**：收尾轮修掉观测点属性后重跑同一套 PDS 流程，
> 最终数值见 §13.3 与 §13.4——`WNS 5.219 ns`（慢角，29018 端点）、`WHS 0.124 ns`、
> `Total LUTs 7761 / 66600 (11.65%)`、`Total Registers 3114 / 133200 (2.34%)`、
> 比特流 SHA256 `5ED76142…`。上方 3.258 ns / 7622 LUT / `A8D616B3…` 是**修复前**那一轮的数值，
> 只作为前后对比保留，**不得**再当作最终交付数值引用。

---

## 2. S1 —— `rtl/bus/axi_interconnect.v`：把取模/除法换成环绕扫描 + 位选择

### 原因
PDS 的 ADS/Synplify 前端把参数化取模当成真的取模器，在 `MASTERS=2`（即 `2*MASTERS=4`，明明是 2 的幂）时也没有常量折叠，留下 `bmsSMOD` 原语无法映射，`synthesize` 直接以 exit code 1 结束且**没有产出网表**。

### 改法
- `rtl/bus/axi_interconnect.v:125-135`：仲裁扫描不再用 `(rr+k)%(2*MASTERS)`

```verilog
choice=-1;
candidate=rr;
// Rotating scan instead of (rr+k)%(2*MASTERS) and /2: modulo and
// division are not folded ...
    if(choice==-1 && (candidate[0]==1'b0 ? m_arvalid[candidate>>1] :
                                             m_awvalid[candidate>>1]))
        choice=candidate;
    candidate=(candidate>=2*MASTERS-1)?0:candidate+1;
```

- `:147-148`：`if(choice[0]==1'b0) m_arready[choice>>1]=1; else m_awready[choice>>1]=1;`
- `:184-185`：`owner<=choice>>1; rr<=(choice+1>=2*MASTERS)?0:(choice+1);`
- 其余 16 处 `(choice/2)` → `(choice>>1)`，`choice%2==0` → `choice[0]==1'b0`。

语义等价（`MASTERS` 为 2 的幂，`choice/2 == choice>>1`，`choice%2 == choice[0]`），但不再要求综合器做代数化简。
全文件已无 `%` 与 `/2`。

### 验证
```
python sim/run_interconnect_tests.py --seeds 20      →  SUMMARY 20 / 20 PASS
```
PDS 全流程随后在**同一份 RTL** 上通过（§6）。

---

## 3. S5 —— `rtl/perips/axi_ram.v`：去掉唯一的 SystemVerilog-only 构造

### 原因
对 `sim/native_axi_sources.f` 里 29 个源文件做了一次 SV-only 构造扫描（`always_ff` / `always_comb` / `logic` / `typedef` / `struct` / `enum` / `interface` / `for(integer ...)`），
命中**恰好一处**：`rtl/perips/axi_ram.v:93`（原行号）的 `for(integer lane=0;lane<4;lane=lane+1)`。
它使 PDS 必须在工程设置里打开 SystemVerilog 前端，而 `pds_shell -file` 批处理模式下这个设置项不可靠。

### 改法
- 在已有 `integer delay_left;` 旁加声明 `integer lane;`（现 `:48`，附注释说明为什么不能内联）。
- `:93`（现 `:98`）改为 `for(lane=0;lane<4;lane=lane+1)`。

改完后 29 个源文件全部是 Verilog-2001 合法，**PDS 用默认前端**即可综合。
（`rtl/core/axi_read_engine.v`、`rtl/core/axi_data_engine.v` 里的 `$fatal` 都在 `ifndef SYNTHESIS` 内，安全。）

---

## 4. S4 —— `platform/pango_native/build.tcl`：批处理模式下的路径解析

### 原因
`pds_shell -file <script>` 的批处理解析器下 `[info script]` 取不到可用路径，`./pango_native.fdc` 这类相对路径报：
```
E: Flow-0049: The file {./pango_native.fdc} is not readable
E: Flow-0163: ... build.tcl at line 33/37
```

### 改法
- 布局目录：优先 `$::env(PANGO_NATIVE_BOARD_DIR)`；否则只在 `[file dirname [file normalize [info script]]]` 下确实存在 `native_sources.tcl` 时才采用；都不成立就报错并提示调用方设置环境变量。
- 仓库根：优先 `$::env(PANGO_NATIVE_REPO)`，否则 `$board_dir/../..`。
- 先断言 `native_sources.tcl` / `pango_native.fdc` / `pango_native.pcf` 三个文件都在。
- `add_constraint` 使用**绝对路径** `$fdc_file` / `$pcf_file`。

流程主体未变：逐源 `add_design` 到 `build/pango_native/sources/**`，从 `$repo/build/native_software/coremark/performance`（或 `$::env(NATIVE_IMAGE_DIR)`）拷 `program.hex`/`data.hex`，
`cd $run_dir` → `set_arch -family Logos2 -device PG2L100H -speedgrade -6 -package FBG676` →
`compile -top_module pango_native_top -include_path [list $repo/rtl/core]` →
`synthesize -ads -selected_syn_tool_opt 2` → `dev_map` → `pnr` → `report_timing` → `gen_bit_stream`。

### 实际调用（可复现）
```powershell
$pds='E:\donwload\PDS_2022.2-SP6.4\PDS_2022.2-SP6.1\bin\pds_shell.exe'
$env:PANGO_NATIVE_REPO='E:\file\pango\project\01_code\tinyriscv_axi4'
$env:PANGO_NATIVE_BOARD_DIR='E:\file\pango\project\01_code\tinyriscv_axi4\platform\pango_native'
Set-Location 'E:\file\pango\project\01_code\tinyriscv_axi4\build\pango_native'
& $pds -file 'E:\file\pango\project\01_code\tinyriscv_axi4\platform\pango_native\build.tcl'
```
结果 exit 0，见 §6。

---

## 5. S2 —— `tb/unit/tb_pipeline.sv`：回归台对齐架构 `mtvec`

### 原因
原生 CPU 的陷入重定向走的是架构 `mtvec` CSR，旧顶层端口 `trap_vector` 已经不再使用（`pango_native_top`/原生 SoC 里被接 0）。
回归台还在给 `trap_vector` 喂值，于是"陷入目标正确"这条检查实际上在测一个悬空信号——即使通过也不构成证据。

### 改法
- 新增 `wire ... halt_pending;` 与 `wire [31:0] ... csr_mtvec;`
- 端口连接补 `.halt_pending(halt_pending)`、`.irq_software(1'b0),.irq_timer(1'b0),.irq_external(1'b0),.csr_mtvec(csr_mtvec)`（顺带消掉 5 个 vopt 悬空端口告警）。
- 检查改为
  ```systemverilog
  if(!redirect_valid || redirect_pc!==csr_mtvec) $fatal(1,"trap redirect missing or wrong target");
  ```
- 在第一个陷入用例前插入 CSR 引导（`mtvec` 必须先被程序写进去）：
  ```systemverilog
  insn(236,32'h00001fb7,1,31,32'h1000);   // lui  x31,1
  insn(240,32'h305f9073,0,0,0);           // csrrw x0,mtvec,x31
  drain();
  if(csr_mtvec!==32'h1000) $fatal(1,"mtvec was not programmed");
  ```
  （用 x31 是因为后面 x1 要当除法操作数。）

### 验证
```
python sim/run_pipeline_tests.py    →  PASS N03_PIPELINE   (运行目录 .sim_runs/pipeline-ydi0l7pu)
```

---

## 6. S6 —— `rtl/soc/pango_native_top.v`：板级可观测性（ILA 观测点）

### 原因
赛题要求提交"CPU 流水线在 CoreMark 关键算法上的 ILA 波形"。原顶层把 CPU 状态输出接成匿名表达式后就没再用，综合器会全部优化掉，板上根本抓不到。

### 改法
**端口完全不变**（`clk, rst_n, key, uart_rx, uart_tx, led[7:0]`）——不臆造引脚。
所有 CPU 状态改接到带 `(* keep = "true" *)` 的**命名内部网线**：

`obs_retire_fire`、`obs_retire_order[63:0]`、`obs_retire_pc`、`obs_retire_inst`、`obs_rd_valid`、`obs_rd[4:0]`、`obs_wdata`、
`obs_trap_fire`、`obs_trap_cause`、`obs_trap_pc`、`obs_trap_tval`、`obs_halted`、`obs_arch_next_pc`、`obs_protocol_fault`、
`obs_csr_mtvec`、`obs_uart_tx`，外加两个自由运行计数器 `obs_retire_count` / `obs_trap_count`（用来做 ILA 触发条件）。

探针清单与触发配方写在 `platform/pango_native/README.md`。
**本次没有做任何 ILA 采集**（无物理板），该项仍为 `NOT RUN`。

---

## 7. S8 —— `tests/example/coremark/core_portme.c`：64 位 tick 打印

### 原因
比赛判据是 `CoreMark_Iterations / (Total_Time × Frequency)`，且要求 CoreMark v1.0 **运行 ≥ 10 秒**才算有效。
但：
- `tests/example/coremark/core_main.c:288` 打印 `Total ticks` 时显式做了 `(ee_u32)total_time` 截断；
- `tests/example/lib/xprintf.c` 只实现了 32 位 `long` 转换（第 76/97/127 行）。

于是长跑（几十秒）时 tick 数必然被截断，无法从串口证明"确实跑够了 10 秒"。

### 改法
`stop_time()` 里增加一行：

```c
t1 = get_cycle_value();
ee_printf("CPM_TICKS hi=%lu lo=%lu\n", (unsigned long)(t1 >> 32), (unsigned long)(t1 & 0xffffffffUL));
```

注释里写明：**比赛用时证据只能取这一行或 ILA，不能取被截断的 `Total ticks`**。
计分路径不受影响——`core_main.c` 用 `time_in_secs(get_time())` 算时间，本来就是 64 位。

---

## 8. 清单第 5 项 —— 新增 halt/reset 事务排空与恢复回归

| 文件 | 作用 |
|---|---|
| `tests/halt_reset/link.ld` | 极简链接脚本（text 落 0x0） |
| `tests/halt_reset/halt_reset.S` | 持续 lw/sw 到数据 RAM 的循环，保证 halt/reset 一定打在**真实 AXI 事务**中间 |
| `tb/integration/tb_halt_reset_drain.sv` | 在完整原生 SoC 上跑 5 个场景，含逐周期 AXI VALID/载荷稳定性监视器 |
| `tools/run_halt_reset_tests.py` | 汇编 → 转 4096 字 hex → 编译清单+TB → 逐场景跑 |

5 个场景：
1. 事务进行中 halt（等 `lsu.state==3` LSU_READ_WAIT）
2. 事务进行中 halt（等 `lsu.state==4` LSU_WRITE_WAIT）
3. 事务进行中 reset
4. 事务进行中 reset
5. 空闲时 reset

检查项：已接受的读必须仍返回 R、已接受的写必须仍返回 B（HR_DRAIN）；halt 后 `halted` 必须拉高且 `arch_next_pc` 不再前进；halt 期间 400 周期内任何主设备不得再拉 ARVALID/AWVALID/WVALID（HR_HALTED_QUIET）；释放后第一个 AR 地址必须等于之前捕获的 `arch_next_pc`（HR_RESUME）且退休恢复；reset 场景中所有主设备 valid/ready 必须为低 100 周期（HR_RESET_QUIET）且没有从设备驱动 VALID；释放后首个取指必须是 PC 0（HR_RESTART）且退休恢复；全程 `protocol_fault` 保持低。

验证：`python tools/run_halt_reset_tests.py` → **5 / 5 PASS**。

---

## 9. 其它（测试台/文档，不改设计行为）

- `tb/integration/tb_coremark_uart.sv`：加滚动匹配器 `match_reg`/`report_seen`/`report_cycle`，主 `initial` 改为
  `fork begin wait(cycles>=max_cycles); end begin wait(report_seen); repeat(12000) @(posedge clk); end join_any`
  ——CoreMark 打印完报告就收尾，不烧满周期上限；删掉失效的 PC_HIST 打印。
  触发串同时匹配 `"CoreMark 1.0"`、`"Correct operation"`、`"Errors detected"`（第三条永远不会出现，见 §12；第二条是本固件唯一的成功终点）。
- `platform/pango_native/README.md`：状态小节更新为本次真实综合结果；SystemVerilog 选项一节改为"**不再需要**"；补 PDS 环境变量说明、200 迭代 CoreMark 构建命令与 13.1007 s 仿真实测、`Timing-4087/-4086` 属预期、以及完整 ILA 探针清单 + 触发配方。

---

## 10. 备份

| 备份 | 位置 |
|---|---|
| 本轮改动前的整棵源码树 | `E:\file\pango\project\02_original_backups\tinyriscv_source_before_resume_20261010_171938` |
| 本轮改动前的备份脚本与清单 | `E:\file\pango\project\09_validation_results\basic_final\backup_before_basic_final.ps1` |
| 10000 迭代 CoreMark 镜像（被本轮重建替换前） | `E:\file\pango\project\09_validation_results\basic_final\coremark\performance_10000_iter`（含 `SHA256.csv`） |

改动后全部源文件的 SHA256 清单：`E:\file\pango\project\09_validation_results\basic_final\FINAL_SOURCE_SHA256.csv`。

---

## 11. 明确未做的事

- 没有改 `rtl/core/**`（CPU 数据通路、CSR、IFU/LSU 引擎）——验证轮定的冻结契约不动。
- 没有改 `platform/pango_native/pango_native.fdc` / `.pcf`（时钟 20 ns、引脚定义保持原样；FDC 故意不加 blanket false path）。
- 没有实现 Cache / 动态分支预测 / DDR / DMA（属高级任务，本轮范围外）。
- 没有改 `FENCE.I` 译码（保持非法指令，不声称 Zifencei）。
- 没有更快的取指改造（IPC 提升属后续优化项）。
- 没有上板下载、没有 ILA 采集。

**收尾轮（任务 m02843）额外"没有做"的**：

- 没有为了修观测点去改 `syn_probe`（会把探针变成顶层端口，本设计引脚已固定）。
- 没有猜 SCBV 值：本地 Pango 文档只写"按实际板卡电压选择"，`07_board_references` 里没有任何板卡原理图/用户手册，**缺少资料就如实标 BLOCKED**。
- 没有动 `platform/pango_native/pango_native.fdc` 去加 blanket false path 来"消掉"未约束路径告警。
- 没有改动 9 组功能回归所依赖的任何 RTL（收尾轮唯一的 RTL 改动是 `rtl/soc/pango_native_top.v` 的属性写法）。
- 没有把仿真的 13.1007 s / 0.3053 CoreMark/MHz 写成板上成绩；板级项全部 `NOT RUN`。

---

## 12. CoreMark 用时取证结论（V11 / V12），以及一处**软件侧**能力限制

本节不记录"改动"，只记录跑完之后的取证边界，因为签名/交付时一定会被问到。

### 12.1 已取得的

| 项 | 结果 |
|---|---|
| 1 迭代性能镜像（V11） | 串口报告 5 项 CRC 与 `core_main.c` 黄金表 index 3 一致；`Total ticks 3274904`；打印 `Total time (secs): 0` 与 `ERROR! Must execute for at least 10 secs…` —— **该镜像本身不满足 ≥10 s** |
| 200 迭代性能镜像（V12） | `Total ticks 655032761`、`Total time (secs): 13`、`Iterations/Sec : 15`、`Iterations : 200`、CRC 全对（`crcfinal 0x382f`）、成功行**前缀** `Correct operation v`、**无** `Errors detected` |
| 64 位原始 tick | `CPM_TICKS hi=0 lo=655213650` → `t1=655213650`，`t0=180889`，**无 32 位回绕** |
| 仿真规模 | `cycles=658177948 retires=61293205 traps=0 faults=0 uart_chars=652 txd_writes=652`；vsim 墙钟 38 分 01 秒；0 error 0 warning |
| ≥10 s 判据 | `655032761 / 50000000 = 13.1007 s ≥ 10 s` —— 在**仿真内实测**成立 |
| 推算自校验 | 线性推算 654,980,800 与实测 655,032,761 差 0.008% |
| 分数（算术推导） | `200 / 13.10065522 = 15.2665 iter/s` → CoreMark/MHz `0.3053` |
| 证据路径 | `09_validation_results/basic_final/coremark/coremark_perf_200iter_50MHz.log`、`coremark_perf_200iter_compile.log`、`performance_200_iter/`（`coremark.elf` `5EDB52BA…`、`program.bin` `B0A03D96…`，与 `manifest.json` 的 `artifact_sha256` 逐项一致） |

### 12.2 **没有**取得的

- **板上实测**：无物理板，V14/V15/V16 全部 `NOT RUN`；仿真的 13.1007 s **不能**当作板上用时证据。
- 板上真实 CoreMark 分数、板上最高实际频率：**均未实测**。

### 12.3 本固件**永远打印不出**标准 `CoreMark 1.0 : <分数>` 行（新发现，未修）

| 位置 | 内容 | 后果 |
|---|---|---|
| `tests/example/coremark/core_portme.h:16` | `#define HAS_FLOAT 0` | 关掉全部浮点打印分支 |
| `tests/example/lib/xprintf.c:122-123` | `default: xputc(c); continue;`（`%f` 走 default，回显一个 `f` 且**不消耗** va_arg 的 double） | 该 port 的 `ee_printf` 无浮点能力；`xprintf.c:66` 自带注释就是 `<xprintf lacks floating point support>` |
| `tests/example/coremark/core_main.c:294,296` | `#else` 分支用 `%d` 打印 `Total time (secs)` / `Iterations/Sec` | 小数被截断，故打印 `13` / `15` |
| `tests/example/coremark/core_main.c:325-339` | `#if HAS_FLOAT` 包住 `if (known_id==3) ee_printf("CoreMark 1.0 : %f …")` | `HAS_FLOAT 0` 时**整段被预处理剔除**，该行在本镜像里不可能出现 |

结论：本镜像唯一的成功终点是 `Correct operation validated.`（`core_main.c:324`），这也是 `total_errors==0` 能给出的最强证据；分数只能由 `Total ticks` + 已知 `CPU_FREQ_MHZ=50` 算出。

> **日志截断（必须如实说明）**：200 迭代日志里只捕获到该行的**前缀** `# Correct operation v`（log 第 2827 行），其后 TB 就 `$finish` 了（`tb/integration/tb_coremark_uart.sv(319)`，`stop_cycle=658177948`），`alidated. See readme.txt …` 没有传完——TB 匹配到 `"Correct operation"` 后只等 12000 周期。
> **结论不受影响**：`ee_printf("Correct operation validated. …")` 只在 `total_errors==0` 分支执行，`Errors detected` 只在 `total_errors>0` 分支，两者互斥，**收到任意前缀即等价于 `total_errors==0`**；且 5 个 CRC 检查点全部等于黄金值。引用时不要写成完整原文。

**要不要修**：属**软件/port** 改动，不在本轮 RTL+平台交付范围；不改也能满足"≥10 s 有效结果"（判据是 `Total ticks`，不是分数行）。若评审坚持要看到原文，最小改法是让 `ee_printf` 支持 `%f` 后重建镜像，**不要**改 `core_main.c` 的判据逻辑。

**读日志注意**：`tb_coremark_uart.sv` 的 `PROGRESS`/`LIVE` 行会**插进被解码的固件输出中间**，把一行拆成多段（如 `Iterations/Sec : 1` 之后隔两行才是续下来的 `5`；`CPM_TICKS` 前缀被吃掉只剩 `hi=0 lo=655213650`）。引用固件输出时必须容忍这种交错。

---

## 13. 收尾轮（任务 m02843）追加修复：上表第 5 项的观测点原本**没有进网表**

### 13.1 发现

上表第 5 项给 `rtl/soc/pango_native_top.v` 的 19 个观测信号加了 `(* keep = "true" *)`，当时的判据只是"编译 0 error 0 warning、端口未变"，**没有检查综合网表**。收尾轮核对 PDS 日志时发现该属性被工具**拒绝并忽略**：

| 日志位置 | 原文 |
|---|---|
| `build/pango_native/compile/run.log:188-205` | `I: [... pango_native_top.sv(line number: 36..54)] Convert attribute name from keep to PAP_KEEP` |
| `build/pango_native/compile/run.log:214+` | `W: [... pango_native_top.sv(line number: 36..54)] The value of attribute PAP_KEEP is invalid, ignore it.` |
| `build/pango_native/compile/run.log:213` | `W: Sdm-2008: The attribute named ASYNC_REG is not legal, then it has no effect, ignore its value.` |

后果（旧综合网表 `build/pango_native/synthesize/pango_native_top_syn.vm`，2026-10-10 23:14:57 生成）：19 个观测名里**只剩 4 个**（`obs_rd`/`obs_retire_fire`/`obs_retire_inst`/`obs_trap_fire`），`obs_retire_order`、`obs_retire_pc`、`obs_wdata`、`obs_trap_cause/pc/tval`、`obs_halted`、`obs_arch_next_pc`、`obs_protocol_fault`、`obs_csr_mtvec`、`obs_uart_tx` 全部消失，两个计数器 `retire_count`/`trap_count` 在 `build/pango_native` 下**0 次命中**。同一网表里 `uart_tx`/`led`/`gpio_data`/`gpio_ctrl` 都在，说明这是死端网络被真实优化掉，不是命名问题。**即：按原样交付，`platform/pango_native/README.md` 里那张 ILA 探针表在实现后的网表上根本抓不到点。**

### 13.2 改动（只动属性写法，不动逻辑、不动端口）

依据本机 Pango 文档 `E:\donwload\PDS_2022.2-SP6.4\PDS_2022.2-SP6.1\syn\doc\fpga_attribute_reference.pdf`（Synplify Pro for Pango Attribute Reference，202 页）：

| 指令 | 页 | 用法与原文要点 |
|---|---|---|
| `syn_keep` | 85/87 | `object /* synthesis syn_keep = 1 */;`，保留指定连线不被优化；"object is a wire or reg declaration for combinational logic"，且对象名与注释斜杠之间**必须有空格** |
| `syn_preserve` | 123 | "Prevents sequential optimizations such as constant propagation, inverter push-through, and FSM extraction"，用于保留寄存器 |
| `syn_probe` | 127 | 会**把探针变成顶层端口**——本设计引脚已固定，**不能用** |

改动内容（`rtl/soc/pango_native_top.v`，85 行 3603 B → 101 行 5027 B）：

1. `(* ASYNC_REG = "TRUE" *) reg [1:0] reset_sync;` → `reg [1:0] reset_sync /* synthesis syn_preserve = 1 */;`（本 wrapper 单时钟域，复位同步器只需保持结构）。
2. 16 个组合观测信号 → `wire obs_x /* synthesis syn_keep = 1 */;`。
3. 2 个死端计数器 → `reg [31:0] obs_retire_count /* synthesis syn_keep = 1, syn_preserve = 1 */;`（`obs_trap_count` 同）。
4. 删掉全部 `(* keep = "true" *)`（否则每次编译仍有 19 条 `PAP_KEEP` 警告）。

### 13.3 复验

- **重新精化**：`vlib .sim_runs/closure_elab/work` + `vlog -sv -work .sim_runs/closure_elab/work +incdir+rtl/core -f sim/native_axi_sources.f`（CWD = 工程根）→ 29 个模块全部编译，`Top level modules: pango_native_top`，**Errors: 0, Warnings: 0**（日志 `.sim_runs/closure_elab/elab.log`，收尾轮证据里另存一份 `pds_rerun/elab.log`）。
- **属性已被工具接受**：新编译日志 `build/pango_native/compile/run.log:188-207` 只有
  `I: [... pango_native_top.sv(line number: 20)] Convert attribute name from syn_preserve to PAP_PRESERVE`
  与 17 条 `I: [... (line number: 51..70)] Convert attribute name from syn_keep to PAP_KEEP`，
  **不再有** `The value of attribute PAP_KEEP is invalid, ignore it.`，也**不再有** `W: Sdm-2008` 的 `ASYNC_REG` 警告。
- **重新综合/实现**：删除 `build/pango_native/{compile,constraint_check,synthesize,device_map,place_route,generate_bitstream}` 后重跑 `platform/pango_native/build.tcl`。
  新网表 `build/pango_native/synthesize/pango_native_top_syn.vm`（5,477,576 B，SHA256 `CED470656CC29D2C4F0A2CC80585863EBA32A5C2B16FD2876208BF2F4DD5A2B5`）中 18 个观测名**全部存在**，
  出现次数：`obs_retire_fire` 34、`obs_retire_order` 2、`obs_retire_pc` 33、`obs_retire_inst` 103、`obs_rd_valid` 2、`obs_rd` 4、`obs_wdata` 2、`obs_trap_fire` 34、`obs_trap_cause` 6、`obs_trap_pc` 2、`obs_trap_tval` 2、`obs_halted` 1、`obs_arch_next_pc` 2、`obs_protocol_fault` 2、`obs_csr_mtvec` 31、`obs_uart_tx` 3、`obs_retire_count` 137、`obs_trap_count` 137。修复**已生效**。
  （上面提到的"旧网表只剩 4 个名、两个计数器 0 次命中"指修复前那一版 `pango_native_top_syn.vm`；此处数字以**收尾轮重跑后的最终网表**为准。）
- **影响面判断（必须如实写明）**：`pango_native_top` 不被任何仿真 testbench 例化（SoC 级 testbench 例化的是 `tinyriscv_axi_soc`），所以本轮**没有重跑功能回归**，理由是 9 组回归所依赖的 RTL 一行未改；但该文件是 `sim/native_axi_sources.f` 的 29 个源之一，**必须**重新精化——已做。

### 13.4 收尾轮重跑后的最终实现数值（取代 §1 上方的旧数值）

| 项 | 修复前（2026-10-10 那一轮） | **收尾轮重跑（最终）** | 证据 |
|---|---|---|---|
| 流程结果 | `Design Summary : All Constraints Met.` | **同上，exit 0** | `09_validation_results/basic_closure/pds_rerun/pds_rerun_closure.log` |
| 时序端点 | 29238 | **29018** | `pds_rerun/place_route/pango_native_top_timing_summary_after_hold_fix.txt` |
| 慢角 Setup WNS | 3.258 ns | **5.219 ns**（TNS 0.000，0 失败） | 同上 |
| 慢角 Hold WHS | 0.139 ns | **0.124 ns**（THS 0.000，0 失败） | 同上 |
| 快角 Setup / Hold | 8.368 ns / 0.101 ns | **10.156 ns / 0.088 ns** | 同上 |
| Recovery / Removal / 最小脉宽 | 空（无违例） | **空（无违例）** | 同上 |
| 关键路径 / 等效 Fmax | 16.742 ns / 约 59.7 MHz | **20 − 5.219 = 14.781 ns / 约 67.6 MHz** | 算术推导 |
| Total LUTs | 7622 / 66600 (11.44%) | **7761 / 66600 (11.65%)**（其中 `LUTs as dram` 2080、`LUTs as logic` 5681） | `pds_rerun/place_route/run.log` |
| Total Registers | 2984 / 133200 (2.24%) | **3114 / 133200 (2.34%)** | 同上 |
| Latches / APM / I/O | 0 / 6.00 of 240 / 13 of 300 | **0 / 6.00 of 240 (2.50%) / 13 of 300 (4.33%)** | 同上 |
| 比特流 | `A8D616B31B2E53B91A668F5883E82A423FBC8F3B6874EA32181B80454DC693B1` | **`5ED76142DF321F752F01E9637F8616B54AB7083DCE85C040E21B44BC1CE529F4`**（3,791,112 B） | `pds_rerun/generate_bitstream/pango_native_top.sbit` |
| 流程耗时 | — | compile→gen_bit_stream CPU 0h:4m:43s，进程总 CPU 0h:5m:20s | `pds_rerun_closure.log` |

**代价与收益（如实记录）**：把观测点真正留在网表里，代价是 **+139 个 LUT、+130 个寄存器**（`+0.21%` LUT、`+0.10%` 寄存器），
收益是 `platform/pango_native/README.md` 的 ILA 探针表在**实现后的网表上确实抓得到**——这是"能上板"和"只能上板但抓不到"的区别。
时序数值的变化（3.258 → 5.219 ns）来自修复后网表布线结果不同，**不是**"改属性提升了主频"，不要把两者写成因果关系。

> **仍未做**：比特流**没有下载、没有上板、没有 ILA 采集**；`C: Bitstream-2001: SCBV has not been set.` 警告依旧存在（原因见 `09_validation_results/basic_closure/01_PLAN_RECONCILIATION.md` §5 B2），**未猜值**。
> `Timing-4086/4087`（`led[0..7]`、`uart_tx`、`key`、`rst_n`、`uart_rx` 未约束）依旧存在，属 FDC 故意不加 blanket false path 的预期结果。

---

## §9 基础版交接

*原文件：`docs/design.md`*

### 基础版交付入口

本次按用户最新要求只交付基础版代码。Cache、动态预测、DDR、
DMA、AI暂不做。原版及修改前备份保留在上级 `backups` 目录。

## 代码

- CPU：`rtl/core/tinyriscv.v`，三级流水线、32个32位寄存器、
  RV32IM译码/执行、单次退休、访存等待及分支重定向。
- 原生AXI封装：`rtl/core/tinyriscv_axi_top.v`。
- SoC：`rtl/soc/tinyriscv_axi_soc.v`，程序/数据RAM及
  UART、GPIO、Timer、SPI、IRQ控制器。
- CSR/异常：`rtl/core/csr_native.v`，同步异常与M模式中断，
  FENCE.I暂按非法指令处理。
- 板级顶层：`rtl/soc/pango_native_top.v`。
- 原生源码清单：`sim/native_axi_sources.f`；不要混编旧RIB顶层。
- 软件构建：`tools/build_native_software.py`。
- PDS工程脚本及引脚：`platform/pango_native/`。

## 当前证据

新增基础版源码做过语法编译和板级顶层加载，均0错误、0警告；
没有执行仿真run。日志为 `sim/native_release_compile.log`、
`sim/native_release_load.log`。CoreMark做过编译链接。
这些不代表完整CPU仿真、ISA符合性、CoreMark有效成绩、
PDS综合/时序合格或上板通过。早期单元测试结果只适用于
当时的代码，后续CSR和SoC改动需重新验证。

PDS运行前须按 `platform/pango_native/README.md`
启用SystemVerilog工程选项；尚未确认相应Tcl开关。

## 交给其他AI的验证任务

请在当前目录阅读 `docs/external-verification-plan.md`，
只执行基础版范围。先确认原生清单和顶层连接，再检查CPU退休、
AXI背压/错误、外设、CSR/异常、软件镜像，最后综合及上板。
遇到失败应报告最早错误位置和实际日志，不把编译成功当成功运行。
旧流水线测试需适配新增IRQ输入和内部mtvec，而不是继续依赖
已不控制异常入口的外部trap_vector。

完整验证由用户交给其他AI执行，本次没有启动完整回归。
