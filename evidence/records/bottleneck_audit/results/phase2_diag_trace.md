# Phase-2 诊断：LSU 控制开销逐拍测量（候选前端优化树）

> 独立诊断（只测量、不改 RTL）。对象：`bottleneck_audit/frontend_opt/src` 候选树（CACHE_ENABLE + PREDICT_ENABLE 全开）。
> 仿真器：ModelSim SE-64 10.6e；镜像：CoreMark **1 迭代 performance** + 微程序 validation。
> 本文所有数字均来自本阶段新建 TB 的逐拍/逐事务日志，可用附录命令完整复现。

---

## 0. 结论摘要（先看这段）

1. **CoreMark 1-iter 窗口 = 701,500 拍（与 T4 完全一致）**，退休 305,069 条，IPC 0.434881。
   LSU 造成的 EX 停顿共 **345,091 拍 = 窗口的 49.19%**（load 170,146 + store 174,945），
   其中 **71,510 拍（10.19%）是"纯 LSU accept 拍"**（每个内存操作在 EMPTY 状态等 one-shot accept）。
2. **Load 命中占 99.835%（55,731/55,823）**，每条 load 命中固定 **3 拍**：
   `LSU accept 1 拍 + dcache 请求/命中 2 拍`。其中 accept 拍是纯控制开销（可省 55,731 拍）。
3. **Store 平均 11.152 拍/条**（15,687 条 = 174,945 拍），逐拍链为：
   `accept(A) → A+1 请求进 dcache → A+3 W 握手 → A+4 AW → A+5 AXI-W → A+8 AXI-B → A+10 LSU b_valid → A+11 done`。
   其中只有 `W→B=3` 的 3 拍是 AXI/BRAM 写延迟、`A+1` 的 1 拍是 dcache 输入寄存；
   **其余 7.15 拍是 LSU/dcache/inner-engine 三级 FSM 与 fabric 串行化产生的控制开销**。
4. **B 已返回后仍要 3 拍才 done**（`t_done - t_baxi = 47,061 = 3.00/店`），
   `AW→W` 被 fabric 强制串行化 1 拍（15,687），`dcache 请求→inner W` 多 2 拍（31,374），
   `inner W→AW` 多 1 拍（15,687），`LSU b→done` 1 拍（15,687）。
5. **保守可省 149,945 拍 = 21.37% 窗口 → IPC 0.435→0.553（+27%）**；
   乐观（含 fabric/ram 模型修改）可省 184,536 拍 = 26.31% → IPC 0.590（+36%）。
   收益几乎全部来自"缩短每个内存操作的固定 FSM 往返"，与 T4 假设一致：**前端优化后 LSU 一拍的延迟都没变**。
6. 微程序交叉验证：store 段 9.012 cyc/insn 中 store 事务 stall 占 22,552/25,378 拍（88.9%），
   每条 11.01 拍的结构与 CoreMark 完全一致（不是 CoreMark 特例）；
   load_independent/load_dependent 两段每条 load 均 3.00 拍。
7. 前端残余 `frontend_idle` 仍有 51,340 拍（7.32%）：LSU 提速后它将成为首要目标（本次未做其分解）。

---

## 1. 测量方法

### 1.1 TB 与探针（只读层次化引用，RTL 未改一行）

新 TB：`frontend_opt/src/tb/phase2/tb_lsu_trace.sv`（约 580 行 SV），直接例化 `pangoriscv_axi_soc`（与
`tb_coremark_audit_v3.sv` 相同的参数：`READ_DELAY=0, WRITE_DELAY=0`，与板级 `pangoriscv_top` 的默认一致）。
所有探针均为 `$root` 层次读引用（编译加 `-voptargs="+acc"`）：

| 观察对象 | 层次路径 | 用途 |
|---|---|---|
| LSU FSM | `soc.core.lsu.state`、`.op_valid/.op_ready/.is_store/.address/.access_size/.op_pc` | 事务接受、状态分解 |
| LSU 握手 | `soc.core.lsu.eng_req_valid/ready`、`eng_w_valid/ready`、`eng_rsp_*`、`eng_b_*`、`done_valid/done_ready` | op→请求→W/rsp/b→done 各阶段拍 |
| dcache FSM | `soc.core.data_cache.state_q`（9 状态）、`.hit_q`、`.cached_q`、`.req_in_cache`、`.miss_event`、`.w_ready`、`.inner.state_q` | 命中/缺失判定；dcache 与 inner engine 状态分解 |
| CPU EX 侧 | `soc.core.cpu.ex_valid/ex_done/is_memory/is_store/is_div/issued` | 判定 EX 是否阻塞在 memory |
| AXI 主机口 | `soc.core.m_{ar,aw,w,b}{valid,ready}[1]`、`m_r{valid,ready,last}[1]`（[0] 为取指口） | AR/R/AW/W/B 握手拍 |
| 退休 | `retire_fire/retire_inst`（rdcycle = `32'hc0002573`） | CoreMark 起止窗口、微程序 phase 切分 |

关键判定定义：

- **事务接受拍** = `lsu.op_valid && lsu.op_ready`（也就是 EX 侧 `op_valid&&cpu_op_ready`），记 `accept`。
- **done 拍** = `lsu.done_valid`（`state==COMPLETE`），CPU 同拍 `ex_done=1` 退休；事务窗口取 `[accept .. done-1]`，
  因此**按状态累计的拍数之和 == lat == EX 为该操作停顿的拍数**（done 拍本身不再是 stall）。
- **命中/缺失**用 dcache 在请求握手拍寄存的 `hit_q/cached_q`（在 `eng_req` 握手后一拍读取，见 `dcache_axi.v:297-305`），
  避免依赖组合 `hit_any`；`cached_q==0` 且非 MMIO 视为 bypass（`kind=2`），CoreMark 窗口内 0 条。
  store 的 "miss" 指写命中拍时目标行不在 cache（write-through 不写分配，**不产生额外 AXI 事务**）。
- **正确性自检（全部硬断言通过）**：每个事务 `sum(LSU 状态拍)==sum(dcache 状态拍)==sum(inner 状态拍)==lat`
  （71,510/71,510 行成立）；CoreMark 窗口分类和==701,500；LSU 状态和==701,500；
  每类 `sum_lat` 与 per-cycle class 计数逐项相等（见 §4.3）。

### 1.2 两个镜像的跑法

| 镜像 | 路径 | 窗口 |
|---|---|---|
| CoreMark 1-iter performance | `frontend_opt/src/build/native_software/coremark/performance/{program,data}.hex` | rdcycle 区间 start=54,810 → stop=756,310，span=701,500 |
| 微程序 validation | `bottleneck_audit/work/tree/build/native_software/microbench/validation/{program,data}.hex`（候选树未构建微程序；该镜像与 T4 所用完全等价——9 个 phase 的 cycles 逐一复现 T4 数字） | 9 个 phase 由 rdcycle 退休切分：phase=nrdc/2，meas=nrdc%2 |

微程序 TB 侧过滤：只取 `meas==1 && 0<=phase<=8` 的事务（phase2=load_independent、phase3=load_dependent、phase4=store）。
boot 段与 xprintf 的 UART 轮询（162,674 条 `pc=0x900` 的 MMIO load，发生在打印间隙）全部排除，
每个 phase 的实测事务数恰为 **2048**（=8×256）。

---

## 2. 窗口级逐拍分解（CoreMark，701,500 拍）

### 2.1 分类（互斥，和==701,500）

| 类别 | 拍数 | 占比 | 说明 |
|---|---:|---:|---|
| RETIRE | 305,069 | 43.49% | 正常退休拍（=退休指令数） |
| LSU_load | 170,146 | 24.25% | EX 因 load 停顿 |
| LSU_store | 174,945 | 24.94% | EX 因 store 停顿 |
| frontend_idle | 51,340 | 7.32% | LSU 空闲且无退休（前端/分支残余；T4 的 ifwait 30,001 是其中一部分） |
| div | 0 | 0% | — |
| ex_other | 0 | 0% | — |
| **合计** | **701,500** | 100% | 硬断言通过 |

### 2.2 LSU 状态累计（和==701,500）

| LSU 状态 | 拍数 | 占比 | 其中 EX stall？ |
|---|---:|---:|---|
| EMPTY（空闲） | 356,409 | 50.81% | 仅 accept 拍 71,510 是 stall；纯空闲 284,899 |
| REQUEST | 71,510 | 10.19% | 是（每条 op 恰好 1 拍，无 stalled request） |
| WRITE_DATA | 31,374 | 4.47% | 是（每条 store 2 拍） |
| READ_WAIT | 58,500 | 8.34% | 是（命中 55,731 + 缺失 ~2,769） |
| WRITE_WAIT | 112,197 | 15.99% | 是（每条 store 7.15 拍） |
| COMPLETE | 71,510 | 10.19% | 否（done_valid 拍，EX 已可退休） |
| **合计** | **701,500** | 100% | **EX mem-stall = 345,091 = LSU class 和** |

交叉校验：`LSU 空闲 EMPTY 356,409 == RETIRE 305,069 + frontend_idle 51,340`（逐拍全等）。

### 2.3 dcache / inner-engine 状态累计（各自和==701,500）

| dcache `state_q` | 拍数 | | inner `state_q` (写引擎) | 拍数 |
|---|---:|---|---|---:|
| IDLE | 499,429 | | WR_IDLE | 573,616 |
| HIT | 55,823 | | WR_PREP | 15,687 |
| RD_AR | 285 | | WR_SEND | 33,762 |
| RD_DATA | 2,392 | | WR_RESP | 47,061 |
| WR_REQ | 31,374 | | WR_HOLD | 31,374 |
| WR_RESP | 96,510 | | WR_FAULT | 0 |
| WR_HOLD | 15,687 | | | |
| BYP_RESP/FAULT | 0 | | | |
| **和** | **701,500** | | **和** | **701,500** |

`dcache IDLE = LSU 空闲(356,409) + 2×(每条 op 的 IDLE 拍) = 356,409+143,020 = 499,429`——精确吻合。

### 2.4 AXI 握手计数（窗口内）

| 事件 | D 侧（数据口） | I 侧（取指口） |
|---|---:|---:|
| AR 握手 | 92 | 421 |
| R beat | 736（92×8 行填充） | 3,368 |
| AW 握手 | 15,687（=store 数，写直达） | — |
| W 握手 | 15,687 | — |
| B 握手 | 15,687 | — |
| dcache 请求 | 71,510（=load+store 数） | — |
| dcache miss_event | 92（=AR） | — |

---

## 3. 事务级：四类内存操作的拍数与分解

### 3.1 条数 / 总拍 / 平均拍

| 类别 | 条数 | 占总指令 | 总拍数 | 平均拍 |
|---|---:|---:|---:|---:|
| load hit | 55,731 | 18.27% | 167,193 | **3.000** |
| load miss | 92 | 0.03% | 2,953 | 32.098（中位 30） |
| **load 合计** | **55,823** | 18.30% | 170,146 | 3.048 |
| store "hit"（行在 cache） | 15,502 | 5.08% | 172,754 | **11.144** |
| store "miss"（行不在 cache） | 185 | 0.06% | 2,191 | 11.843 |
| **store 合计** | **15,687** | 5.14% | 174,945 | **11.152** |
| **全部** | **71,510** | 23.44% | **345,091** | 4.826 |

### 3.2 按状态分解（拍/条，已用硬断言核对 sum==lat）

| 类别 | LSU：EMPTY/REQ/WDATA/RWAIT/WWAIT | dcache：IDLE/HIT/RD_AR/RD_DATA/WR_REQ/WR_RESP/WR_HOLD | inner：IDLE/PREP/SEND/RESP/HOLD |
|---|---|---|---|
| load hit | 1.00 / 1.00 / – / 1.00 / – | 2.00 / 1.00 / – / – / – / – / – | 3.00 / – / – / – / – |
| load miss | 1.00 / 1.00 / – / 30.10 / – | 2.00 / 1.00 / 3.10 / 26.00 / – / – / – | 32.10 / – / – / – / – |
| store hit | 1.00 / 1.00 / 2.00 / – / 7.14 | 2.00 / – / – / – / 2.00 / 6.14 / 1.00 | 3.00 / 1.00 / 2.14 / 3.00 / 2.00 |
| store miss | 1.00 / 1.00 / 2.00 / – / 7.84 | 2.00 / – / – / – / 2.00 / 6.84 / 1.00 | 3.00 / 1.00 / 2.84 / 3.00 / 2.00 |

### 3.3 稳态逐拍时间线（取 CoreMark 中一条 lat=11 的 store，`txn_coremark.csv` idx=4424，addr=0x1000067c）

| 拍 | 相对 accept | 事件/状态 | 性质 |
|---|---|---|---|
| A | 0 | `op_valid&&op_ready` 接受；LSU=EMPTY（EMPTY→REQUEST）；EX stall | **控制气泡**（LSU 只在 EMPTY 可接受） |
| A+1 | 1 | LSU=REQUEST，`eng_req` 握手进 dcache（dc=IDLE，请求寄存）；EX stall | 必要的输入寄存 |
| A+2 | 2 | LSU=WRITE_DATA；dc=WR_REQ；inner=WR_IDLE（收下请求） | **控制气泡**（inner 多一级） |
| A+3 | 3 | dc=WR_REQ 等 `w_ready`；inner=WR_PREP；LSU `eng_w` 握手 | **控制气泡**（W 本可 A+2 收） |
| A+4 | 4 | inner=WR_SEND 发出 **AW** 到 fabric | **控制气泡**（AW 可随 W 一拍早发） |
| A+5 | 5 | fabric 把状态切到 WRITE 后发出 **AXI-W** | **控制气泡**（AXI 允许 AW/W 同拍，fabric 强制串一拍） |
| A+6,A+7 | 6,7 | `axi_ram` write_select / WRITE_WAIT（`WRITE_DELAY=0` 时 WRITE_WAIT 空转 1 拍） | 写延迟+存储模型（A+7 属 ram 模型气泡） |
| A+8 | 8 | **AXI-B** 握手（`w→b=3`） | 存储写延迟 |
| A+9 | 9 | inner=WR_HOLD（把 B 寄存一拍 → `i_b_valid`） | **控制气泡** |
| A+10 | 10 | dc=WR_HOLD（`b_valid` 到 LSU）→ LSU 在 WRITE_WAIT 收 B | **控制气泡**（B 可直达 LSU） |
| A+11 | 11 | LSU=COMPLETE，`done_valid`（EX 退休） | **控制气泡**（done 可同拍产生） |

该行状态计数：LSU=`1,1,2,-,7`、dcache=`2,-,-,-,2,6,1`、inner=`3,1,2,3,2`，和均 =11。
**每条 store 的 11.15 拍里，约 7 拍是控制/寄存气泡，3 拍是 AXI 写延迟（其中 1 拍还是 ram 模型空转），1 拍是 dcache 必要的输入寄存。**
只 6 拍会被前端/取指影响：见 §5 的 I-fetch 争用。

### 3.4 Load 命中/缺失的逐拍链

- **load hit（3 拍）**：A 接受（LSU=EMPTY）→ A+1 `eng_req` 握手、dc=IDLE 做 tag 比较并寄存 → A+2 dc=HIT 输出 `eng_rsp` → A+3 COMPLETE/done。
  即 dcache 命中本身需要 1 拍寄存器输出（物理上正常），**多出来的只有 A 拍（accept）**。
- **load miss（典型 30 拍，均值 32.1）**：A 接受 → A+1 dc 收请求 → A+2 `AR`（典型，82/92）→ A+7 首个 R（`ar→rfirst=5`）
  → 每 3 拍一个 beat，共 8 beat（`rfirst→rlast=21`）→ +1 拍出 rsp → +1 拍 done。
  中位 30 拍 = 1(accept)+1(req)+5(AR→首 R)+21(8 beat×3)+1(rsp)+1(done)；
  均值被 10 条被取指争用推迟 AR 16~26 拍的 miss 拉高（`t_ar-t_req` 分布 {1:82, 2:2, 18,21,24,25,27,28×3}）。

---

## 4. AXI 握手阶段与空档（逐事务）

### 4.1 store：接受→各 AXI 事件（15,687 条，拍为相对 accept）

| 阶段 | 典型/平均拍 | 总拍数 | 备注 |
|---|---:|---:|---|
| accept → LSU `eng_req` 握手（进 dcache） | 1.000 | 15,687 | 每条固定 |
| req → LSU `eng_w` 握手（W 交给 dcache） | 2.000 | 31,374 | dcache 寄存 + inner WR_IDLE 各 1 |
| weng → **AW**（CPU 口） | 1.152（稳态 1.000） | 18,075 | 113 条被 I-fetch 争用推迟 2~28 拍 |
| **AW → W（CPU 口）** | 1.000 | 15,687 | fabric 串行化，全部 1 拍 |
| **W → B（CPU 口）** | 3.000 | 47,061 | ram 写延迟（fabric 无额外拍） |
| **B → LSU `b_valid`** | 2.000 | 31,374 | inner WR_HOLD + dcache WR_HOLD 各 1 |
| LSU b → done | 1.000 | 15,687 | WRITE_WAIT→COMPLETE→done_valid |
| **accept → done** | **11.152** | 174,945 | 与 §3.1 一致 |
| 派生：accept → AXI-W | 5.152 | 80,823 | |
| 派生：B → done | 3.000 | 47,061 | B 已到 CPU 仍要 3 拍 |
| 派生：W → done | 6.000 | 94,122 | 含 W→B 3 拍存储延迟 |

AW→W 分布：全部 15,687 条恰为 1 拍（`{1:15502}` + `{1:185}`）。
W→B 分布：全部恰为 3 拍。B→LSU b 分布：全部恰为 2 拍。b→done：全部恰为 1 拍。
**这些恒定值说明它们是纯结构/握手拍，与数据无关。**

### 4.2 load miss：AR/R 阶段（92 条）

| 阶段 | 平均 | 总拍 | 分布/备注 |
|---|---:|---:|---|
| accept → dc 请求 | 1.000 | 92 | |
| req → AR（CPU 口） | 3.098（**典型 1**） | 285 | {1:82, 2:2, 18,21,24,25,27,28×3}：10 条被 I-fetch 阻塞 |
| AR → 首 R | 5.000 | 460 | fabric+ram 读延迟 |
| 首 R → 末 R | 21.000 | 1,932 | 7 个间隔 ×3 拍（8 beat 行填充） |
| 末 R → LSU rsp | 1.000 | 92 | dcache HIT 服务 |
| LSU rsp → done | 1.000 | 92 | COMPLETE |
| 典型 accept → done | 30 | 2,760 | 均值 32.098 被 10 条争用拉高 |

### 4.3 操作间隔（accept-to-accept，窗口内）

| 类别 | 条数 | 平均间隔 | 中位 |
|---|---:|---:|---:|
| load（全部） | 55,822 | 12.56 拍 | 5 |
| store（全部） | 15,686 | 44.71 拍 | 19 |
| load miss | 91 | 6,243 拍 | 868 |
| store miss | 184 | 2,467 拍 | 20 |

store 平均每 44.7 拍一条，但每条却要占 LSU 11.15 拍（其中 ~7 拍可优化）——
CoreMark 中 store 只占 5.14% 指令，却吃掉 24.94% 的窗口拍数。

---

## 5. 关键气泡清单（按可省拍数排序；计数依据=实测条数×实测拍数）

> **气泡定义（本文口径）**：该拍处于"数据/AXI 传输之外"，由控制状态机、寄存级或总线串行化引起，
> 且在不改变存储容量、不改变 AXI 协议语义的前提下，可通过改控制器结构消除或与相邻事务重叠的拍。
> 每条给出：实测依据（本条拍数/总拍数）、根因（模块/行号）、预计每 CoreMark 可省拍数。

| # | 气泡 | 实测依据 | 根因（模块:行） | 可省拍数（CoreMark 窗口） |
|---|---|---|---:|---:|
| 1 | **LSU accept 拍**：每个内存操作在 EMPTY 状态等一拍才发出 `eng_req` | 1.000 拍/op × 71,510 op | `lsu_axi.v:41-42`（`op_ready=idle`），`:81-88`（EMPTY 才接受，REQUEST 下一拍才驱动 `eng_req`） | **71,510（10.19%）** |
| 2 | **store 的 B→LSU b_valid 寄存链**：B 到 CPU 后经 inner WR_HOLD、dcache WR_HOLD 两拍才到 LSU | 2.000 拍/店 × 15,687 | `axi_data_engine.v:112-113`（`m_bready` 在 WR_RESP，`b_valid` 在 WR_HOLD）；`dcache_axi.v:380-392`（`i_b_valid`→ST_WR_HOLD→`b_valid`），`:246` | **31,374（4.47%）**（保守 1 拍=15,687） |
| 3 | **store 请求→W 多一级 inner 引擎**：dcache 收请求后 inner 还要 WR_IDLE→WR_PREP 才 `w_ready` | 2.000 拍/店；本可 1 | `dcache_axi.v:294`（`i_req_valid_r` 单拍寄存）、`:237`；`axi_data_engine.v:95-97`（`req_ready` 在 WR_IDLE，`w_ready` 要 WR_PREP） | **15,687（2.24%）** |
| 4 | **WR_PREP→WR_SEND 一级**：W 收下后要等 state 进 WR_SEND 才发 AW | 1.000 拍/店（`weng→aw` 稳态值） | `axi_data_engine.v:97-98,108`（`m_awvalid/m_wvalid` 在 WR_SEND） | **15,687（2.24%）** |
| 5 | **fabric AW→W 串行化**：`m_wready` 只在 state==WRITE 有效，故 AW 握手后 W 必晚 1 拍（AXI 允许同拍） | 1.000 拍/店 × 15,687（分布 `{1:15687}` 恒定） | `axi_interconnect.v:154-157`（`m_awready` 仅 FREE）、`:158-159`（`m_wready` 仅 `state==WRITE`）、`:204`（AW fire 才 `state<=WRITE`）；从设备 `axi_ram.v:107-108` 的 `s_awready/s_wready` 其实同拍可用 | **15,687（2.24%）** |
| 6 | **LSU b→done 一拍**：WRITE_WAIT 收 B 后进 COMPLETE，`done_valid` 下一拍才出 | 1.000 拍/店 × 15,687 | `lsu_axi.v:97-101`（`WRITE_WAIT→COMPLETE→(done_valid&&done_ready)→EMPTY`；`:43`） | **15,687（2.24%）** |
| 7 | **axi_ram 在 WRITE_DELAY=0 时空转 WRITE_WAIT 一拍**（B 延迟 3 拍中 1 拍） | 1.000 拍/店 × 15,687（`w→b=3` 恒定） | `axi_ram.v:156-166`（IDLE→WRITE_WAIT），`:194-197`（`delay_left==0` 仍走一拍 WRITE_WAIT 才 WRITE_RESP） | **15,687（2.24%）**（属存储模型，见§7） |
| 8 | **store AW 被取指口争用推迟**：I-fetch 的 AR/R 占住 fabric 时 AW 等 2~28 拍 | 113/15,687 条；额外 2,388 拍（`weng→aw` 分布多出的部分） | `axi_interconnect.v:88-94,154-157`（两主一丛、AR/AW 同一 FREE 仲裁口，无写地址排队） | **2,388（0.34%）** |
| 9 | **load miss 的 AR 争用 + 行填充节拍空转** | 10/92 条 AR 被推迟（额外 193 拍）；8 beat 每个 3 拍中含 1 拍 READ_WAIT 空转（7×92≈644） | `axi_ram.v:169-177`（READ_MEM→READ_WAIT→READ_RESP；`READ_DELAY=0` 时 READ_WAIT 空转）；`axi_interconnect.v:154-157` 争用 | **约 829（0.12%）** |

**合计**：
- **保守**（#1+#3+#4+#5+#6 + #2 的 1 拍）= 71,510+15,687×4+15,687 = **149,945 拍 = 21.37% 窗口**
  → 新窗口 ≈ 551,555，IPC ≈ 0.553（+27.2%）。
- **乐观**（再加 #2 的另 1 拍、#7、#8、#9）= **184,536 拍 = 26.31% 窗口**
  → 新窗口 ≈ 516,964，IPC ≈ 0.590（+35.7%）。
- 若把 `axi_ram` 的 3 拍写延迟也视为可缩短（改为 1 拍流水），还可再省 ~2×15,687≈31K 拍，但这已超出"LSU 控制"范围。

估算依据说明：CoreMark 为单发射顺序核，任一时刻最多 1 个未完成内存操作，per-txn stall 拍数可近似 1:1 折算为窗口拍数；
上述节省量均用**本窗口实测条数 × 实测每拍数**计算，未使用历史估计值。扣除 frontend_idle 与依赖链重叠后实际收益可能略低（见 §7.3）。

---

## 6. 微程序交叉验证（结构不是 CoreMark 特例）

每个 phase 测量 2048 次内存操作（8 次/迭代 × 256 迭代），实测量：

| phase | 实测周期（rdcycle） | 事务数 | 命中/缺失 | 平均拍 | 其中 EX mem-stall | 周期/指令 |
|---|---:|---:|---|---:|---:|---:|
| 2 load_independent | 8,977 | 2,048 load | 2048 hit | **3.00** | 6,144 | 3.188（T4 3.18） |
| 3 load_dependent | 8,752 | 2,048 load | 2048 hit | **3.00** | 6,144 | 3.799（T4 3.79） |
| 4 store | 25,378 | 2,048 store | 2048 hit | **11.01** | 22,552 | 9.012（T4 9.01） |
| 0,1,5,6,7,8（无内存） | — | 0 | — | — | 0 | 与 T4 完全一致（101/102/104/173/102/2438） |

- 三个 phase 的 `EX mem-stall == sum(lat)`（6,144 / 6,144 / 22,552）逐项相等，说明事务窗口统计无缺口。
- store 段 9.012 cyc/insn 中，store 事务 stall 占 22,552 拍（88.9%）；按 §5 的 6~7 拍/店可省，
  store 段可降到 **~13,090 拍 ≈ 4.65 cyc/insn（−48%）**；load 段每条省 1 拍 → **2.46 cyc/insn（−23%）**。
- 微程序实测与 CoreMark 的每拍链完全同构：load hit 3 拍、store 11 拍（store 段无 I-fetch 争用，故 11.01 而非含争用的 11.15）。

---

## 7. 与 T4/历史计数对照、以及不确定/未测事项

### 7.1 与 T4 对照（同一 CoreMark 1-iter performance 镜像）

| 项目 | T4 记录 | 本次实测 | 一致性 |
|---|---:|---:|---|
| 窗口 | 701,500 | 701,500 | ✓ |
| 退休数 | 305,069 | 305,069 | ✓ |
| IPC | 0.4349 | 0.434881 | ✓ |
| load / store 条数 | 55,823 / 15,687 | 55,823 / 15,687 | ✓ |
| load=3 拍命中数 | 55,731 | 55,731 | ✓ |
| store=11 拍数 | 15,579 | 15,574（15,396 hit + 178 miss；其余 113 条被 I-fetch 争用，17~38 拍） | ≈（−5 条为窗口边界） |
| dcache 请求 / miss | 71,510 / 92 | 71,510 / 92 | ✓ |
| AXI D 侧 AR/R/AW=W=B | 92/736/15,687 | 92/736/15,687 | ✓ |
| load READ_WAIT 拍 | 58,523 | 58,500 | −23 拍（0.04%，窗口边界口径） |
| store WRITE_WAIT 拍 | 112,247 | 112,197 | −50 拍（0.04%，同上） |
| frontend ifwait | 30,001 | frontend_idle 51,340（含 ifwait 30,001 + 其它前端停顿 21,339） | 口径差异，见§7.2 |

结论：**前端优化（ifwait 153,442→30,001，总窗口 −12.66%）没有改动 LSU 的任何一拍**；
本次把 LSU 的 345,091 拍（49.19%）按阶段拆开，确认其绝大部分是控制/握手开销而非缓存缺失。

### 7.2 不确定 / 未测到（如实声明）

1. **收益是解析估计，不是实测**：本轮只改测量、未改 RTL，因此 §5 的可省拍数来自"实测拍数 × 可消除性判断"。
   每条改动实际可行性与是否引入新临界路径需 RTL/时序评审；建议按 #1→#2→#5 顺序做增量实验（改完重跑本 TB 即可复测）。
2. **1:1 折算的乐观性**：CoreMark 存在数据相关分支，缩短 LSU 停顿后可能暴露新的依赖/前端停顿；
   且 `frontend_idle 51,340` 拍不一定全部被吸收。给出的 IPC 为**上限估计**。
3. **`axi_ram` 的 3 拍写延迟/1 拍写空转属存储模型**（`WRITE_DELAY=0` 为空时，板级 `pangoriscv_top` 与仿真 TB 相同），
   是否算"控制开销"取决于验收口径；建议单列，不计入 LSU 控制收益（报告已单列为 #7/#9）。
4. **微程序镜像来自 `work/tree` 而非候选树**（候选树未构建微程序）；已用 9 个 phase 的 cycles 完全复现 T4 数字证明两镜像等价。
5. **MMIO/bypass 事务**：CoreMark 窗口内 0 条；微程序里有 162,674 条 UART 轮询 MMIO load（`pc=0x900`），已从测量中排除，
   未纳入任何统计。
6. **boot/窗口边界**：CoreMark 前 54,810 拍（boot、.data 拷贝、预热）只用于验证（首个 load miss 30 拍；
   boot 段第一个 store 因取指争用 AW 等 22 拍、lat=32，第二个起即恢复 11 拍），
   不计入窗口；窗口内接受的 71,510 条事务与 per-cycle 计数逐项相等，无跨界泄漏。
7. **未测**：400 迭代 CoreMark（用 1-iter performance，与 T4 同口径）；dcache 一致性/正确性功能验证（本轮只做时序计数，但 traps=0、faults=0、`done_stall_iv=0`、全部状态和/分类和断言通过）；FPGA 时序/频率/功耗；下板与串口。
8. **#2/#3/#4 的可消除性判断**依赖对 `axi_data_engine` 与 `dcache` 状态机的阅读（行号已在表中给出），
   未做门级/时序验证；若把 B 直接透传需确认 `b_resp` 错误路径不受影响。

---

## 8. 交付物与复现命令

### 8.1 文件

| 类型 | 路径 |
|---|---|
| 新 TB（唯一新增源码） | `frontend_opt/src/tb/phase2/tb_lsu_trace.sv` |
| 编译日志 | `frontend_opt/phase2_logs/compile.log` |
| CoreMark vsim 日志 | `frontend_opt/phase2_logs/vsim_coremark.log`（+ `_console.log`） |
| 微程序 vsim 日志 | `frontend_opt/phase2_logs/vsim_micro.log`（+ `_console.log`） |
| CoreMark 逐拍 CSV | `frontend_opt/phase2_logs/cyc_coremark.csv`（701,501 行 = 表头+701,500 拍） |
| CoreMark 逐事务 CSV | `frontend_opt/phase2_logs/txn_coremark.csv`（76,102 行） |
| 微程序逐拍 CSV | `frontend_opt/phase2_logs/cyc_micro.csv`（58,668 行，含 9 个测量窗口） |
| 微程序逐事务 CSV | `frontend_opt/phase2_logs/txn_micro.csv`（179,136 行） |
| 分析脚本 | `frontend_opt/phase2_logs/analyze.py` |
| 分析输出（本文全部表格的机器可读来源） | `frontend_opt/phase2_logs/analysis_summary.txt` |

RTL / 既有 TB / 既有结果文件均未改动。

### 8.2 完整复现命令（PowerShell；`$T` = `frontend_opt/src`，`$L` = `frontend_opt/phase2_logs`）

```powershell
$env:PATH='E:\donwload\win64;'+$env:PATH          # ModelSim 10.6e
$T='E:\file\pango\project\evidence\records\bottleneck_audit\frontend_opt\src'
$L='E:\file\pango\project\evidence\records\bottleneck_audit\frontend_opt\phase2_logs'
Set-Location $T
# 0) 新库（相对路径；不要用绝对 -work，会触发 vopt-2253）
vlib p2diag
# 1) 编译（33 个 RTL 源 + 新 TB）
vlog -sv -work p2diag +define+CACHE_ENABLE +define+PREDICT_ENABLE `
     +incdir+rtl/core +incdir+rtl/perips -f sim/native_axi_sources.f `
     tb/phase2/tb_lsu_trace.sv 2>&1 | Tee-Object -FilePath "$L\compile.log"
# 2) CoreMark 1-iter performance（窗口 701,500 拍）
$CM="$T\build\native_software\coremark\performance"
vsim -c -voptargs="+acc" -work p2diag tb_lsu_trace `
  "+PROG=$CM\program.hex" "+DATA=$CM\data.hex" `
  "+MAX_CYCLES=1500000" "+MODE=coremark" "+CYCLE_GATE=iv" "+DRAIN_AFTER_STOP=2000" `
  "+CYCLE_CSV=$L\cyc_coremark.csv" "+TXN_CSV=$L\txn_coremark.csv" `
  -do "run -all; quit -f" -l "$L\vsim_coremark.log"
# 3) 微程序 validation（9 个 phase，meas 窗口）
$MB='E:\file\pango\project\evidence\records\bottleneck_audit\work\tree\build\native_software\microbench\validation'
vsim -c -voptargs="+acc" -work p2diag tb_lsu_trace `
  "+PROG=$MB\program.hex" "+DATA=$MB\data.hex" `
  "+MAX_CYCLES=4000000" "+MODE=micro" "+CYCLE_GATE=meas" "+DRAIN_AFTER_STOP=2000" `
  "+CYCLE_CSV=$L\cyc_micro.csv" "+TXN_CSV=$L\txn_micro.csv" `
  -do "run -all; quit -f" -l "$L\vsim_micro.log"
# 4) 汇总分析（生成 analysis_summary.txt，即本文所有表格）
Set-Location $L; python analyze.py
```

运行时间：编译 ~5 s；CoreMark ~22 s；微程序 ~33 s；分析 <5 s。

### 8.3 逐事务 CSV 列定义（62 列，与 `txn_coremark.csv` 表头逐字一致）

`idx,is_store,kind,cached,addr,size,pc,iv,phase,meas,nrdc,accept,dcfirst,treq,tar,trfirst,trlast,nrbeats,tweng,taw,twaxi,tbaxi,trsp,tbeng,tdone,lat,done_stall,lc0,lc1,lc2,lc3,lc4,lc5,dc0,dc1,dc2,dc3,dc4,dc5,dc6,dc7,dc8,in0,in1,in2,in3,in4,in5,breqwait,bwdatawait,brwait,bwwait,dwrreq,dwrreqdead,dwrresp,dwrhold,drdar,drddata,drddata_nor,dchit,didle,dcmiss`

- `kind`：0=hit、1=miss、2=bypass(MMIO)、3=unknown；`cached`=请求是否落在缓存区；
- `t_*` 为绝对周期戳（`lat=t_done-t_accept`）；`done_stall`=该事务期间 `done_valid&&!done_ready` 的拍数（窗口内恒 0）；
- `lc*`/`dc*`/`in*` = 该事务窗口 `[accept..done-1]` 内 LSU（EMPTY..COMPLETE 6 态）/dcache（ST_IDLE..ST_FAULT 9 态）/
  inner 写引擎（WR_IDLE..WR_FAULT 6 态）各状态各占几拍，三者之和均等于 `lat`（71,510/71,510 行校验通过）；
- `b_*wait` = 该事务里 LSU 处于 REQUEST/WRITE_DATA/READ_WAIT/WRITE_WAIT 且握手未完成的拍；
  `dwrreq/dwrreqdead/dwrresp/dwrhold/drdar/drddata/drddata_nor/dchit/didle` = 该事务内 dcache 的
  ST_WR_REQ / 其中 w_ready 死等 / ST_WR_RESP / ST_WR_HOLD / ST_RD_AR / ST_RD_DATA / 其中无 R 节拍 / ST_HIT / ST_IDLE 拍数
  （与 `dc0..dc8` 冗余，便于直读）；`dcmiss`=该事务内 miss_event 拍。

### 8.4 逐拍 CSV 列定义（37 列，CoreMark 窗口）

`cyc,nrdc,iv,lsu,dc,inner,exv,exd,ismem,isst,opv,opr,issued,donv,donr,ereqv,ereqr,ewv,ewr,erspv,erspr,ebv,ebr,darv,darr,drv,drr,drl,dawv,dawr,dwv,dwr,dbv,dbr,dcmiss,dcreqv,dcreqr`

- `lsu/dc/inner` 为状态编号；`exv/exd`=ex_valid/ex_done；`opv/opr`=LSU op_valid/op_ready；
  `donv/donr`=done_valid/done_ready；`ereq*=eng_req_valid/ready`、`ew*=eng_w_*`、`ersp*=eng_rsp_*`、`eb*=eng_b_*`；
  `darv/darr`=数据口 AR valid/ready（`dr*`=R、`daw*`=AW、`dw*`=W、`db*`=B；`drl`=R last）；
  `dcmiss`=miss_event、`dcreqv/dcreqr`=dcache req_valid/req_ready。
