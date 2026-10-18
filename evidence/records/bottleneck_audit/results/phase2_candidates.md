# Phase-2 候选方案与推荐（LSU 控制开销）

> 依据：`results/phase2_diag_trace.md`（逐拍/逐事务实测，窗口 701,500 拍，退休 305,069，IPC 0.434881）。
> 本文件只写**方案与解析估计**；所有"预期收益"都是按实测气泡拍数 × 可消除性做的解析上限，**不是实测**。
> RTL 实施在独立实验副本 `bottleneck_audit/lsu_opt/src`，不改正式交付树、不改基线位流。

> **2026-10-18 更新**：候选 A 已实施并完成回归 + 同镜像 A/B + 逐事务实测 + PDS，
> 实测结果与偏差分析见 `results/phase2_implementation.md`；本文件保留当初的方案与解析估计，作为对照。

---

## 0. 一句话

诊断结论是：前端提速后，LSU 的 **345,091 拍（窗口 49.19%）** 几乎全是"每条内存操作固定的 FSM/握手往返"，
不是 cache 缺失（load miss 仅 92 条）。所以本轮不动 Cache 结构、不写缓冲、不提前退休，
只做**握手合并**：把每笔内存操作多绕的 1~4 拍寄存器/状态级去掉，等 B 响应与退休语义保持原样。

两个候选方案的共同硬约束（源自用户指令）：

- 不提前退休 store：store 仍然要在收到成功 B 响应后才 `done`；
- 不写缓冲 / 不写回 Cache / 不做非阻塞 Cache / 不多在途 / 不双发射 / 不做流水级重构；
- 不改变功能、异常/错误响应语义、访问顺序；
- 不引入"Cache → CPU"的长组合数据路径（因此**不**把 `b_valid` 直接组合进 retire）；
- 27 MHz、已验证板卡/引脚/下载流程；编译/仿真/综合/布线/板测分开表述。

---

## 1. 候选 A（推荐）：LSU 内存操作"握手合并"

**目标**：消掉每笔内存操作里由"三级 FSM + 打拍寄存器"造成的空转，同时保留 COMPLETE→retire 的一拍。

| 子项 | 现状实测 | 改动 | 预期节省 |
|---|---|---|---|
| A1 发射合并（气泡 #1） | 每个内存操作都在 `EMPTY` 等 one-shot accept：71,510 拍（10.19%） | LSU 在 `op_ready` 拍**同拍**把请求交给 dcache（`eng_req_valid` 由 op 输入组合驱动）；`op_ready = idle && req_ready`，store 还要求 `w_ready` 同拍有效 | load −1 拍/条（55,823 拍）、store −1 拍/条（15,687 拍） |
| A2 W 与请求同拍（气泡 #3/#4） | dcache 打一拍 `i_req_valid_r`、inner 再经 `WR_PREP` 收 W：多 2 拍 | dcache 在 `ST_IDLE` 写接受时把 req+W 同拍送 inner；inner 在 `WR_IDLE` 同拍收 req+W 直接进 `WR_SEND`（仍保留 `WR_PREP` 作为 W 晚到的兼容路径） | store −2 拍/条（31,374 拍） |
| A3 B 直通（气泡 #2 的两拍） | B 返回后：inner `WR_RESP→WR_HOLD`、dcache `WR_RESP→WR_HOLD` 两拍寄存链 → LSU `b_valid` | B 在 `WR_RESP` 被接收的同拍，inner 组合给出 `b_valid`（`b_resp=m_bresp`），dcache 在 `ST_WR_RESP` 同拍消费并同拍把 `b_valid` 交给 LSU；LSU `WRITE_WAIT` 同拍接受后进 `COMPLETE` | store −2 拍/条（31,374 拍） |
| 不做（气泡 #6） | `b_valid→done` 1 拍 = COMPLETE 拍 | 保留 COMPLETE 拍，**不**把 done 组合进 retire（避免 B→retire 长组合路径） | 0 |

**预期（解析上限）**

- load hit：3.000 → **2.000** 拍/条；store：11.152 → **6.152** 拍/条；
- 窗口：701,500 → **567,242** 拍（−134,258，**−19.14%**）；IPC 上限 305,069/567,242 ≈ **0.538**（+23.6%）；
- 与诊断报告的"保守 21.37%"差 15,687 拍，正是主动保留的 #6（b→done 组合化）与 fabric/ram 模型项（#5/#7）不计。

**改写文件**（仅实验副本内 3 个）：

- `rtl/core/lsu_axi.v`：`op_ready/eng_req_valid/eng_w_valid` 改为接受拍组合发射（`bad_access` 仍本地走 COMPLETE，不发请求）；store 直接进 `WRITE_WAIT`、load 直接进 `READ_WAIT`；`REQUEST/WRITE_DATA` 保留为兼容路径但正常流程不再经过。
- `rtl/core/dcache_axi.v`：`ST_IDLE` 写接受时同拍把 `req_valid`+`w_valid` 转发给 inner（不再注册 `i_req_valid_r`、不再进 `ST_WR_REQ`），直接进 `ST_WR_RESP`；`w_ready` 在 IDLE 写接受时等于 inner 的 `i_w_ready`；`ST_WR_RESP` 收到 `i_b_valid` 同拍完成合并、置 `b_valid` 给 LSU（保留 `ST_WR_HOLD` 作为 `b_ready` 未就绪的兜底）。
- `rtl/core/axi_data_engine.v`：`w_ready` 在 `WR_IDLE`（req 与 W 同拍）有效；`WR_IDLE` 收 req+W 同拍后直接 `WR_SEND`；`WR_RESP` 收 B 同拍驱动 `b_valid`（`b_resp = m_bresp`），若下游 `b_ready` 同拍则直接回 `WR_IDLE` 否则进 `WR_HOLD`；B 的 `bid` 校验与错误路径保持。

**风险与时序关注点**

1. `op_ready` 现在依赖 dcache `req_ready`：EX→LSU 的 ready 路径多一级组合（dcache 状态位），需 PDS 复核；当前基线 Setup slow 17.131 ns，27 MHz 有较大余量。
2. AXI B→LSU `b_valid` 成为组合路径（只进入 LSU 的 resp 寄存器，不直接进 CPU 退休），需时序确认。
3. MMIO/非缓存旁路读路径保持原样；`dcache` 写命中合并仍在成功 B 后执行；失败 B 仍作废该行。
4. 若 `req_ready`/`w_ready` 未同拍有效而 `op_valid` 已到，按新 `op_ready` 语义继续等（不会丢 op）；halt/reset 语义不变。

**验证计划**：现有 unit/engine/ram/interconnect/dcache/ifu-engine/pipeline 全量 runner → `tools/run_isa_e2e.py` → `tools/run_halt_reset_tests.py` → 同镜像 CoreMark 1-iter A/B（perf + validation 两镜像，五 CRC 与 retires 比对）→ PDS 时序/资源（与 T4 候选位流同条件）→ 上板 400-iter（≥2 次、完整 UART 原文、精确 ticks）。

---

## 2. 候选 B（回退）：只做 store 握手合并

**目标**：不碰 EX→LSU 发射路径（`op_ready` 语义保持"必有一拍 accept"），只把 store 路径的两段寄存器去掉。

- 内容：候选 A 的 A2 + A3（W 同拍 + B 直通），但不做 A1（保留 `REQUEST` 拍作为请求发射拍）。
- 预期：store 11.152 → **7.152** 拍/条（−4 拍 = 62,748 拍，**−8.94%** 窗口）；load 不变（3.000）；
  窗口 701,500 → 638,752，IPC 上限 ≈0.478（+9.9%）。
- 优点：完全不改 CPU 侧握手，风险最低；缺点：收益只有 A 的一半左右。
- 用途：若 A1 在 PDS 出现新的关键路径或功能回归无法及时收敛，退到 B。

---

## 3. 推荐

**推荐候选 A**。理由：

1. 收益 2.1 倍于 B（解析上限 −19.1% vs −8.9%），且 A 覆盖 B 的全部改动（A2/A3 相同）；
2. A1 只改 LSU 的"发射时机"，不改 EX 流水线、不改退休语义，失败面窄；
3. A 不引入"Cache→CPU"组合路径（B 直通止于 LSU resp 寄存器）；A2/A3 都是纯寄存器/状态级消除；
4. 与 T4 的成功经验同构（同一拍收旧发新），便于用同一套 A/B / PDS / 上板流程验收；
5. 若 A1 时序不收敛，立即回退候选 B，仍可交付 −8.9% 的保守收益。

**本轮不做**：fabric `AW→W` 串行化（#5）、`axi_ram` 存储模型空转（#7）——前者属互连共享逻辑，后者属仿真存储模型，均不计入 LSU 控制收益；store buffer/写回/非阻塞/多在途按用户指令不做。

---

## 4. 参考论文（均核对原文/DOI）

1. **[已核实原文与 DOI]** H. Miyazaki, T. Kanamori, Md A. Islam, K. Kise, "RVCoreP: An Optimized RISC-V Soft Processor of Five-Stage Pipelining," *IEICE Transactions on Information and Systems*, vol. E103.D, no. 12, pp. 2494–2503, 2020. DOI: [10.1587/transinf.2020PAP0015](https://doi.org/10.1587/transinf.2020PAP0015)。
   摘要原文（J-STAGE 页面核对）："Three effective methods are applied to the processor to improve the operating frequency. These methods are **instruction fetch unit optimization, ALU optimization, and data memory optimization**." —— 与本项目"取指（T4）→ ALU/LSU（T5+）"两个阶段的问题划分一致。
2. **[已核实 DOI]** D. Million, N. Oliete-Escuín, C. Fuguet, "Breaking the Memory Wall with a Flexible Open-Source L1 Data-Cache," *DATE 2024*. DOI: [10.23919/DATE58400.2024.10546547](https://doi.org/10.23919/DATE58400.2024.10546547)。
   摘要原文："The lack of **concurrency and pipelining in the memory sub-system** of recent open-source RISC-V processors ... is increasingly becoming the performance bottleneck. Recent updates ... (HPDcache) ... bring significant (up to +234%) speedups ... with a negligible 5.92% area impact." —— 支持"访存子系统的流水/并发不足是瓶颈"这一诊断方向；本项目在其上只取"控制握手合并"这一最小子集。
3. **[已检索，未核全文]** N. P. Jouppi, "Improving Direct-Mapped Cache Performance by the Addition of a Small Fully-Associative Cache and Prefetch Buffers," *ISCA 1990*, pp. 364–373. [ACM DL](https://dl.acm.org/doi/abs/10.1145/325164.325162)。用于说明"Cache 结构级优化（预取/victim）"与"控制级优化"的边界；本轮不做结构级改动。

> 说明：候选 A/B 的收益数字全部来自本项目 `phase2_diag_trace.md` 的实测拍数，不引用文献的加速比；文献只用于确认"访存控制/流水是公认瓶颈"这一方向。
