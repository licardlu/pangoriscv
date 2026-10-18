# 阶段 2：LSU 控制开销最小改动（候选 A）——实现与验证记录

状态：RTL 实现、单元/回归、ISA 端到端、同镜像 CoreMark A/B、逐事务实测、PDS 综合/布线（All Constraints
Met）、上板 A/B（400 迭代，各 2 次采集）全部完成。所有数字均来自本目录可复现的日志。
摘要：仿真 1 迭代镜像 803,230 → 567,741 拍（−29.32 %）；上板 400 迭代
320,725,708 → 226,427,447 拍（−29.40 %，1.247172 → 1.766570 CoreMark/MHz）；PDS 收敛、
LUT 12,510 / FF 7,228、估计 49.71 MHz；见 §5–§8。

实验副本：`E:\file\pango\project\evidence\records\bottleneck_audit\lsu_opt\src`（下文 `$lsu`）。
正式交付树 `firmware\code` 与基线位流未改动；本阶段只改实验副本，是否合并由用户决定。

## 1. 范围与不变量

改动目标（用户 m02813）：只处理诊断报告里 D 侧（数据 Cache / LSU）的逐拍握手与等待气泡，
不扩大为架构重构。

涉及文件（只 3 个 RTL，均在 `$lsu\rtl\core\`）：

| 文件 | 改前 sha256 | 改后 sha256 |
|---|---|---|
| `lsu_axi.v` | `e4d9cde1eba2ed3ef3bb77a8d0dfe9dbbe65452726576e75273cc2e89d839b94` | `e2e1c980ce0c13040c98a8bba643638c56aeaa63587d38d34c0982414c6f4b11` |
| `dcache_axi.v` | `acec20746cca67b860c064e568353fc9ad58e27d9dcd75ba66088e482453b010` | `3fabe424a473e8a8fb8e5c75ea6c77404ea2edbcfe9204692b26683d68405c8a` |
| `axi_data_engine.v` | `fa1077fbe391bffc1ec3f165c23a30d75b330eac4ff7bdeec13b4209848c3c10` | `0b4c970e9dcbbab45d4cde56716fe02a392a085aaa61a7c2ca95e3fab6debb4b` |

完整 unified diff：`..\lsu_opt\diff\*.diff`（4 个：三份 RTL + 单元测试台）。
除上述 3 个 RTL 与 `tb/unit/tb_lsu_axi.sv` 外，`$lsu` 其余文件与 T4 候选树逐字节相同
（对比基准 `..\lsu_opt\MANIFEST_rtl_before.txt`，38 个 rtl 文件只有这 3 个 sha 变化）。

保持的不变量（逐条都有测试覆盖）：

1. **不提前退休**：`done_valid` 仍只在数据返回（load 的 R）或写完成（store 的 B）被消费后拉高，
   EX 级继续阻塞到 `done_valid`；没有把完成信号组合进 `retire_fire`。
2. **访存顺序与精确异常**：同时最多 1 笔在途事务；`bad_access`（非对齐/超长）仍不发任何 AXI 请求、
   直接以 fault 完成（候选通路：`op_ready` 在 `bad_access` 时为 1，进 COMPLETE 给 fault）。
3. **store 写数组时刻不变**：写合并/写回仍发生在 AXI `B` 成功之后（`dcache_axi.v` 的
   `if (i_b_valid)` 分支），因此 load-after-store 的自洽性语义不变。
4. **不新增 Cache→CPU 长组合路径**：新增的组合路径只有 `inner WR_RESP → b_valid → LSU done`
   一段短的完成信号（不经过 data_mem/tag 读出），不存在从存储阵列直通 CPU 的组合数据路径。
5. **AXI 协议**：AW/W 仍按原协议在同一次事务里发出，W 与请求同拍进入 inner 只是把两级握手合并，
   没有改变 W 必须在 AW 之后/同拍、B 必须等 W last 等协议约束。

## 2. 逐文件改动

### 2.1 `lsu_axi.v`（Rev 1.1，105 → 约 130 行）

- 新增 `wire issuing = (state==EMPTY);`
  `wire launch = rst_n && issuing && op_valid && op_ready && !bad_access;`
- `op_ready = rst_n && issuing && (bad_access || (is_store ? (eng_req_ready && eng_w_ready) : eng_req_ready));`
  → 接受一条 store 的同一拍，把 req 与 W 一起交给 dcache（不再先 REQUEST 再 WRITE_DATA 两拍）。
- `eng_req_valid = rst_n && (issuing ? launch : (state==REQUEST));`，`eng_req_write/addr/size`
  在 `issuing` 拍直接用 op 输入，其余状态用锁存寄存器；`eng_w_valid` 同理
  （`issuing ? (launch && is_store) : (state==WRITE_DATA && store_q)`，数据/掩码双路选择）。
- EMPTY 接受时：`bad_access → COMPLETE`；store → `WRITE_WAIT`；load → `READ_WAIT`。
  旧 `REQUEST`/`WRITE_DATA` 状态保留但正常不再进入（兼容原状态机）。
- 保留原有 `extend_load`、`frame`、fault 处理与 `eng_b_ready`/`eng_rsp_ready` 语义。

### 2.2 `axi_data_engine.v`

- `w_ready = rst_n && (state_q==WR_IDLE || state_q==WR_PREP) && !protocol_fault && !config_fault;`
  → 请求到达的同一拍即可接收 W（原来必须先进 WR_PREP 再等一拍）。
  注意：`!protocol_fault && !config_fault` 是必须的——否则 sticky fault 之后 `w_ready` 仍为 1，
  测试台会报 `FAULT_FAKE_COMPLETION`（`tb/axi/tb_axi_read_engine.sv:319`）。
- 新增 `wire b_arrived = m_bvalid && (m_bid==id_q);`
  `b_valid = rst_n && ((state_q==WR_HOLD) || (state_q==WR_RESP && b_arrived));`
  `b_resp = (state_q==WR_RESP) ? m_bresp : resp_q;`
  → B 到达当拍就把完成交给 dcache（原来要再寄存一拍进 WR_HOLD）。
- `WR_IDLE` 收请求时若 `w_valid && w_ready`，同拍置 aw/w pending 并进 `WR_SEND`，否则仍走 `WR_PREP`
  （兼容旧接口）；`WR_RESP` 收 B 后 `state_q <= b_ready ? WR_IDLE : WR_HOLD;`（消费方同拍接收）。

### 2.3 `dcache_axi.v`

- 删除 `i_req_valid_r/i_req_write_r/i_req_addr_r/i_req_size_r/i_req_len_r/i_req_id_r` 六个打拍寄存器，
  inner 例化改直连：
  `wire i_req_valid = rst_n && (state_q==ST_IDLE) && req_valid && req_ready && req_write;`
- `req_ready = rst_n && (state_q==ST_IDLE) && !protocol_fault && !config_fault &&
  (!req_write || (i_req_ready && i_w_ready));`
  → 只有写请求的 req 与 W 都能同拍被 inner 接收时才接受，保证合并后的时序仍然成立。
- `i_b_ready = b_ready && ((state_q==ST_WR_RESP) || (state_q==ST_WR_HOLD));`
  `b_valid = rst_n && ((state_q==ST_WR_HOLD) || ((state_q==ST_WR_RESP) && i_b_valid));`
  `b_resp = (state_q==ST_WR_RESP) ? i_b_resp : resp_q;`
  → B 到达当拍同时向上游给出完成、并完成写合并/失效。
- `ST_IDLE` 写接受同拍锁存 `wdata_q/wstrb_q/w_captured_q` 并直接进 `ST_WR_RESP`
  （原路径要先进 `ST_WR_REQ` 等 W）；`ST_WR_RESP` 保留 legacy 补捕
  `if(!w_captured_q && w_valid && w_ready) ...`，使旧接口“W 晚到”时序仍可用
  （`w_captured_q` 为新寄存器，复位 0）。B 后 `state_q <= b_ready ? ST_IDLE : ST_WR_HOLD`。
- 写合并表达式、drop 行、miss 补行、`ST_BYP_RESP`（MMIO 旁路）路径均未改动。

### 2.4 `tb/unit/tb_lsu_axi.sv`（Rev 1.1）

旧测试台把“等 `op_ready` 前必须先看到 `eng_req_valid`”写死，无法适配同拍发射；已按新时序重写
（保留原检查项并加强）：背压时 5 拍内 `op_ready/eng_req_valid/eng_w_valid/done_valid` 全为 0；
接受同拍检查 req 各字段与 store 的 W 字段、load 不得有 W；接受后 `eng_req_valid/eng_w_valid`
立即归零；store 走 `WRITE_WAIT`、load 走 `READ_WAIT`；bad_access 不发请求直接 fault 完成；
完成信号稳定性 4 拍；末尾计数 `requests==10 && writes==3 && completions==13`。

## 3. 逐笔事务省了多少拍（设计推导，均已被第 5 节实测证实）

**store（写命中）原 11.14 拍 → 现 6.16 拍**（逐拍，A 为接受拍）：

| 拍 | 改前 | 改后 |
|---|---|---|
| A | LSU accept（EMPTY） | LSU accept，同拍发 req+W |
| A+1 | LSU REQUEST → dcache 接受 | dcache ST_WR_RESP 直通 inner，inner WR_SEND 发 AW |
| A+2 | dcache ST_WR_REQ 等 W | AXI W beat（fabric 强制 AW/W 串一拍） |
| A+3 | inner WR_PREP 收 W | ram 写延迟/等待 |
| A+4 | inner WR_SEND 发 AW | AXI B 返回，inner 同拍给 b_valid，dcache 同拍写合并并给 LSU done |
| A+5 | AXI W beat | — |
| A+6/7 | ram 写延迟 + WRITE_WAIT 等待 | — |
| A+8 | AXI B | — |
| A+9 | inner WR_HOLD | — |
| A+10 | dcache ST_WR_HOLD → b_valid | — |
| A+11 | LSU COMPLETE/done | — |

**load（读命中）原 3.00 拍 → 现 2.05 拍**：A 拍同拍发 req；A+1 dcache `ST_HIT` 直接给 rsp，
LSU 同拍 COMPLETE/done（原先是 A 拍 accept、A+1 REQ、A+2 HIT、A+3 done）。

## 4. 功能验证

编译：`vlog -sv -work ab_lsu +define+CACHE_ENABLE +define+PREDICT_ENABLE -f sim/native_axi_sources.f`
→ `Errors: 0, Warnings: 0`（`..\lsu_opt\logs\` 与 `..\lsu_opt\phase2_logs\compile.log`）。

### 4.1 回归套件（第一棵工作树 `$lsu`，日志 `$AUDIT\lsu_opt\logs\run_*`）

| 套件 | 结果 |
|---|---|
| unit（含新 tb_lsu_axi） | `SUMMARY 5 / 5 PASS` |
| engine（read/write engine 64 例） | `SUMMARY 64/64 PASS` |
| dcache | `SUMMARY 1/1 PASS` |
| ifu_engine | `SUMMARY 20/20 PASS` |
| interconnect | `SUMMARY 20 / 20 PASS` |
| ram | `SUMMARY 40/40 PASS` |
| icache / predictor / perf / gpio_trace | 各 `SUMMARY 1/1 PASS` |
| pipeline（全源，宏全开） | `TEST_PASS N03_PIPELINE retires=29 traps=9 operations=5` |

说明：`sim/run_pipeline_tests.py` 固定 13 个 core 源且**只用宏注释态**；本树宏全开时该 runner
会因缺 `branch_predictor` 报配置错误（与 T4 阶段同一已知问题），因此 pipeline 用
`sim/native_axi_sources.f` 全源复核（上表），宏注释态下 13 源 runner 也 `PASS N03_PIPELINE`。

### 4.2 ISA 端到端与 halt/reset

- `tools/run_isa_e2e.py`（宏全开）：**14 / 15 PASS**，唯一失败 `case 7 mcycle/minstret counters
  - x2=0 want 1 (mcycleh after wrap)`——这是阶段 1 已定位的 **G1 已知限制**（两棵树 core 相同，
  快速取指把 core 既有的 CSR 读/写时序隐患压成背靠背），与本次 LSU 改动无关：
  同一 RTL 宏注释态 `15 / 15 PASS`（`logs\isa_e2e_macrosoff.log`）；T4 候选宏全开时同样 14/15。
- `tools/run_halt_reset_tests.py`：**5 / 5 PASS**（含读/写事务在途时复位）。

### 4.3 第二棵独立干净工作树复核

`E:\file\pango\project\evidence\records\bottleneck_audit\lsu_opt_verify\src`（robocopy 独立副本，
与 `$lsu` 的 RTL/测试台 sha256 一致），重新跑全套件与 ISA 测试（日志 `..\lsu_opt_verify\logs\`，
汇总 `..\lsu_opt_verify\logs\SUMMARY.txt`），结果与第一棵树完全一致：

| 检查 | 第二棵树结果 |
|---|---|
| unit / engine / dcache | 5/5、64/64、1/1 PASS |
| ifu_engine / interconnect / ram | 20/20、20/20、40/40 PASS |
| icache / predictor / perf / gpio_trace | 各 1/1 PASS |
| `tools/run_isa_e2e.py`（宏全开） | 14/15（case 7 = G1，与第一棵树一致） |
| `tools/run_halt_reset_tests.py` | 5/5 PASS |

## 5. 同镜像 CoreMark A/B（仿真，1 迭代镜像）

镜像：`$AUDIT\work\tree\build\native_software\coremark\{performance,validation}`（两棵树加载同一组镜像，
两侧均验证五 CRC；测试台 `$AUDIT\scripts\tb_coremark_audit_v3.sv`，统计窗口 = 固件 mcycle 区间）。

| 镜像 | 基线周期 / 退休 / IPC | T4 候选（前端） | 本阶段候选（LSU） | 相对基线 |
|---|---|---|---|---|
| performance | 803,230 / 305,069 / 0.379803 | 701,500 / 305,069 / 0.434881 | **567,741 / 305,069 / 0.537338** | **−235,489（−29.32 %）** |
| validation | 804,633 / 305,505 / 0.379682 | 702,231 / 305,505 / 0.435049 | **568,721 / 305,505 / 0.537179** | **−235,912（−29.32 %）** |

- 退休指令数三段完全一致（305,069 / 305,505），说明省下的全部是等待拍，不是少做了工作。
- CRC（validation 镜像，两侧逐项相同）：`seedcrc 0x18f2`、`crclist 0xe3c1`、`crcmatrix 0x0747`、
  `crcstate 0x8d84`、`crcfinal 0xe3c1`。
- CRC（performance 镜像，两侧逐项相同）：`seedcrc 0xe9f5`、`crclist 0xe714`、`crcmatrix 0x1fd7`、
  `crcstate 0x8e3a`、`crcfinal 0xe714`（本阶段候选日志中的 UART 文本被 `# PROGRESS` 控制行交错，
  `crcmatrix` 一行被切成两段，原始日志仍可逐字符核对）。
- 相对 T4 候选再省 133,759 拍（−19.07 %）；T4 候选的验证链路见 `T4_frontend_results.md`。

### 5.1 微程序（同镜像，2,560 条循环）

| 场景 | 基线 cyc/insn ×100 | T4 候选 | 本阶段候选 |
|---|---|---|---|
| alu_independent | 202 | 101 | **101** |
| alu_dependent | 201 | 102 | **102** |
| load_independent | 320 | 320 | **246** |
| load_dependent | 379 | 379 | **290** |
| store | 901 | 901 | **537** |
| branch_taken | 205 | 104 | **104** |
| branch_alternating | 243 | 173 | **173** |
| mul_dependent | 201 | 102 | **102** |
| div_dependent | 2438 | 2438 | **2438** |

## 6. 逐事务实测（用阶段 2 诊断 TB 在候选 RTL 上重跑）

TB：`$lsu\tb\phase2\tb_lsu_trace.sv`（层次探针 + 每拍 CSV）；分析器：`$AUDIT\lsu_opt\phase2_logs\analyze.py`；
原始日志 `..\lsu_opt\phase2_logs\`（`cyc_coremark.csv` 567,741 行、`txn_coremark.csv` 76,132 行等）。

| 类别 | 基线（诊断报告） | 本阶段候选 | 变化 |
|---|---|---|---|
| load 命中（55,823 笔） | 3.000 拍/笔 | **2.049 拍/笔** | −0.95 拍/笔 |
| store（15,687 笔，命中+未命中） | 11.144 / 11.843 拍/笔 | **6.163 拍/笔** | −4.98 拍/笔 |
| LSU 忙碌拍合计 | 345,091（49.19 % 窗口） | **211,044（37.17 % 窗口）** | **−134,047 拍** |
| 窗口总拍 | 701,500 | 567,741 | −133,759（含前端交互） |

微程序逐事务：load_independent 3.00 → **2.00** 拍/笔；load_dependent 3.00 → **2.00**；
store 11.01 → **6.01**（`analysis_summary.txt` 的 phase 2/3/4）。

状态直方图（候选，窗口 567,741）：LSU `EMPTY=356,697, REQUEST=0, WRITE_DATA=0, READ_WAIT=58,541,
WRITE_WAIT=80,993, COMPLETE=71,510`；dcache `IDLE=428,207, HIT=55,823, WR_RESP=80,993, WR_REQ=0,
WR_HOLD=0`；inner `WR_IDLE=486,748, WR_SEND=33,932, WR_RESP=47,061, WR_PREP=0, WR_HOLD=0`。
旧的 `REQUEST/WRITE_DATA`（LSU）与 `ST_WR_REQ/ST_WR_HOLD`（dcache）、`WR_PREP/WR_HOLD`（inner）
已不再进入——这正是被合并掉的握手级数。

气泡闭合核对（对诊断报告 §5 的编号）：

| 气泡 | 诊断估计 | 本阶段处理 | 实测效果 |
|---|---|---|---|
| #1 LSU accept 拍 | 71,510（10.19 %） | **有意保留**（消掉它等于提前退休，属用户禁止范围） | 每笔仍 1 个 EMPTY 拍 |
| #2 B→LSU b_valid 两级寄存 | 31,374（保守 1 拍） | B 同拍给 dcache、dcache 同拍给 LSU | 已消除 |
| #3 dcache→inner 多一级 | 15,687 | ST_IDLE 接受请求同拍直通 inner | 已消除 |
| #4 inner WR_PREP→WR_SEND 一级 | 15,687 | WR_IDLE 同拍收 W 即进 WR_SEND | 已消除 |
| #6 LSU b→done 一拍 | 15,687 | B 同拍完成，不再多一级 | 已消除 |
| #5 fabric AW→W 串行 | 15,687 | 不改 fabric（用户边界） | 仍存在 |
| #7 ram 模型写延迟 | 15,687 | 属存储模型，单列不计收益 | 仍存在 |
| #8/#9 取指争用 | 2,388 / 829 | 不在本次范围 | 仍存在 |

实测 TOTAL 与预测的差异：诊断保守估计可省 149,945 拍（21.37 %），实测省 134,047 拍（19.10 %）；
`LSU_PHASE` 的读写等待里仍含 AXI B/ram 往返与 fabric 争用（#5/#7/#8），单笔 store 已从 11.14 压到 6.16，
剩余等待主要来自存储侧固定延迟，而非控制握手。

## 7. PDS 综合与布线（27 MHz 真实板级约束）

工具：Fabric Compiler 2022.2-SP6.1（PDS 2022.2-SP6.4 安装包），器件 PG2L100H-6FBG676；
时钟约束沿用 `platform/pango_native/pango_native.fdc` 的
`create_clock -name clk -period 37.037 -waveform {0 18.5185} [get_ports {clk}]`（27 MHz，D18）。
三次构建共用同一份镜像：**400 迭代 performance** 的 `program.hex`
（sha256 `4AD7DE6B14F6954BA3E04B93574713F4619101B3388DEC3CDE13F7B355E82EC6`）与 `data.hex`
（`6FFD4571DA129E86EEE388AC737C29191BF745BDEB9BB55B262EFF454CA06298`），流程日志均有两条
`Loading memory data from file`（program/data 各一条）。

### 7.1 时序与资源（All Constraints Met 的最终构建）

| 项目 | 基线（400-iter 全功能） | T4 前端版 | 本阶段 LSU 版 |
|---|---|---|---|
| Design Summary | All Constraints Met | All Constraints Met | **All Constraints Met** |
| Setup slow WNS (ns) | 16.262 | 17.131 | 16.922 |
| Hold slow WHS (ns) | 0.024 | 0.103 | 0.106 |
| Setup fast WNS (ns) | 24.216 | 23.799 | 24.355 |
| Hold fast WHS (ns) | 0.014 | 0.069 | 0.072 |
| 估计最高频率 (MHz) | 48.15 | 50.2361 | 49.7141 |
| 时序端点总数 | 48,478 | 48,478 | 48,584 |
| LUT | 12,441 | 12,406 | 12,510 |
| FF | 7,268 | 7,268 | 7,228 |
| DRM / APM / Distributed RAM | 4.5 / 6 / 2,685 | 4.5 / 6 / 2,685 | 4.5 / 6 / 2,685 |
| 位流 sbit sha256 | `747C18CA…68E6D77` | `DE0F9074…AA47B4F8` | `9B6742902FFF86A921FF8DF8585DA1C21F177D546D294970A84C74E4349C7CC0` |

- 与基线相比：LUT +69（+0.55%）、FF −40（−0.55%）、DRM/APM/分布式 RAM 不变；Setup slow 仍比
  27 MHz 周期（37.037 ns）富余 16.922 ns、估计 Fmax 49.71 MHz（基线 48.15 MHz）。
- 与 T4 前端版相比：Setup slow 少 0.209 ns（关键路径仍是 EX 乘法器 APM 级联，不属 LSU 改动），
  LUT +104；两者都远高于 27 MHz 需求。
- Recovery / Removal / 最小脉宽、slow/fast 两个角全部 `All Constraints Met`；约束文件未改，
  没有放宽任何周期或例外（只增加了 hold 修复力度和随机种子，见 7.2）。

### 7.2 hold 收敛过程（同一设计，只调工具修复力度与随机种子）

| 轮次 | 修复设置 | 结果 | 处理 |
|---|---|---|---|
| run1 | 继承 T4：阈值 100 ps / 100 iters | Convergence Fail：Hold slow **−0.032**（7 端点）、Hold fast −0.035 | 阈值升到 200 ps（工具合法上限） |
| run2 | 阈值 300 ps | 工具直接报错：`Flow-0186: ... legal value range is "0 ~ 200"` | 改回 200 ps |
| run3 | 阈值 200 ps / 300 iters | 仍 Fail，但改善到 Hold slow **−0.008**（1 端点）、Hold fast −0.014 | 分析失败路径后再加随机种子 |
| run4 | 200 ps / 300 iters + `-gplace_seed 2 -groute_seed 2` | **All Constraints Met**：Hold slow 0.106、Hold fast 0.072 | 采用 |

- 失败路径固定为 `soc/core/data_cache/set_q[3]` → `tag_mem_*/ram64x1d/WADDR[3]`（分布式 RAM 写地址），
  锁存时钟 3.825 ns、发起时钟 3.238 ns、skew 0.240：本阶段新增的 B 同拍完成逻辑让这个寄存器
  落到了偏慢的时钟列。200 ps 阈值把差距压到 8 ps，最后只差 1 个端点；换 placement/routing 种子后收敛。
- 设置的合理解释：`-fix_hold_violation_threshold` 单位是 ps，值越大要求工具修 hold 的力度越大；
  这里只提高“愿意为 hold 增加多少延迟”的上限（Setup 仍有 16.9 ns 余量），同时 `in_route TRUE`
  让布线阶段也参与修复；`platform/pango_native/build.tcl` 里保留 0→100→200 ps 的演进注释和
  `build.tcl.hold100.bak` / `build.tcl.baseline_hold0` 备份，可逐档回退。
- 证据：`lsu_opt/pds/run1_holdfail_100ps/`（失败报告+位流）、`run2_hold300_unlegal/`（工具报错记录）、
  `run3_hold200_8ps/`（−8 ps 报告+位流）、`run4_seed2_hold200/`（最终 rtr、multiseed_summary.csv、
  flow.log、generate_bitstream/pangoriscv_top.sbit、place_route 数据库）。
- 注意：run4 的 `report_timing/pangoriscv_top.rtr` 里输入/输出路径文字仍指向移动前的
  `lsu_opt/src/build/pango_native/...`（先构建后归档目录所致，报告内容本身有效）。

## 8. 上板 A/B（400 迭代 performance 镜像，27 MHz）

### 8.1 测试条件

| 项目 | 基线 | 本阶段候选 |
|---|---|---|
| 位流 | `baseline_build/artifacts/pangoriscv_i400_baseline_fullfeature.sbit` | `lsu_opt/pds/run4_seed2_hold200/generate_bitstream/pangoriscv_top.sbit` |
| 位流 sha256 | `747C18CA32DEFD118E2237863FD7BDAC9C6DB1E110EE734F6CC485FAF68E6D77` | `9B6742902FFF86A921FF8DF8585DA1C21F177D546D294970A84C74E4349C7CC0` |
| 大小 | 3,791,112 B | 3,791,112 B |
| 镜像 | 400 迭代 performance（编译进位流的 program/data hex，两侧同一份） | 同左 |
| 板卡 / 时钟 | PG2L100H 开发板，27 MHz（器件 ID `0x00602899`） | 同左 |
| 串口 | COM13，115200 8N1，先开串口再下载，捕获窗口 80 s | 同左 |

流程：`capture_uart.ps1 -Port COM13 -Seconds 80` 先开串口 → `run_flash.ps1 -Script
01b_program_only.tcl -Sbit <位流>` 经 JtagServer + `cdt_cfg.exe` 下载到 SRAM（日志均见
`lsu_opt/board/*_configuration_tcl.log`，每轮 `cfg_program succeed`）→ 收完整 UART 原文。
每个位流各跑 **2 次**，共 4 次采集，全部完成。

### 8.2 采集结果（同镜像、同板、同频点）

| 项目 | 基线 run1 | 基线 run2 | 候选 run1 | 候选 run2 |
|---|---|---|---|---|
| UART 捕获文件 | `base_run1.txt`（707 B） | `base_run2.txt`（707 B） | `cand_run1.txt`（710 B） | `cand_run2.txt`（710 B） |
| 捕获 sha256 | `78B7D08D…41A593F` | 同 run1（逐字节相同） | `A79135C5…92B3C377` | 同 run1（逐字节相同） |
| `CPM_TICKS lo` | 320,783,213 | 320,783,213 | 226,468,633 | 226,468,633 |
| `Total ticks` | **320,725,708** | **320,725,708** | **226,427,447** | **226,427,447** |

两轮各自逐字节相同，说明结果可复现；基线两次还与此前阶段 1 的采集 sha 相同。

### 8.3 派生指标（用精确 ticks 换算，不采用程序打印的整数秒）

| 指标 | 基线 | 候选 | 变化 |
|---|---|---|---|
| 总拍数（400 迭代） | 320,725,708 | 226,427,447 | **−94,298,261（−29.40 %）** |
| 运行时间 = ticks / 27 MHz | 11.8787 s | 8.3862 s | −3.4925 s |
| 吞吐 = 400 / 时间 | 33.6736 it/s | 47.6974 it/s | **+41.65 %** |
| CoreMark/MHz = 400×10⁶ / ticks | 1.247172 | **1.766570** | +0.519398（+41.65 %） |
| 五 CRC（seedcrc/crclist/crcmatrix/crcstate/crcfinal） | 0xe9f5 / 0xe714 / 0x1fd7 / 0x8e3a / 0x25b5 | 完全相同 | 不变 |

- 两侧 CRC 逐项相同、`CoreMark Size 666`、`Iterations 400`、编译器与编译参数完全相同，
  证明**工作量与结果一致**，差异只来自周期数。
- 与仿真 A/B 的对应关系：仿真 1 迭代镜像 −29.32 % 周期，板测 400 迭代 −29.40 %，互相印证；
  前端阶段（T4）板测为 320,725,708 → 279,957,350，本阶段在其基础上再降到 226,427,447。

### 8.4 关于 EEMBC "≥10 秒" 规则（必须说明）

候选跑完 400 迭代只需 8.386 s，固件按 EEMBC 规则打印
`ERROR! Must execute for at least 10 secs for a valid result!` 并在最后一行为 `Errors detected`；
基线 11.879 s ≥10 s，打印 `Correct operation validated`。这不是计算错误或功能失败——五 CRC 与基线
完全一致，只是**候选变快后触发了 CoreMark 的最短运行时间规则**。

- 本报告的 A/B 按用户要求保持**两侧同镜像（400 迭代）**，用精确 ticks 与 CRC 对比，因此结论有效；
  上表 CoreMark/MHz 是由实测 ticks 归一化得到的值。
- 若要把候选作为**正式 CoreMark 成绩**发布，需要把同一镜像的 `ITERATIONS` 提到 ≥477（建议 500），
  重新编译并重做位流与上板；这属于“出正式成绩”的额外步骤，本轮未做，也不影响优化前后对比结论。
  基线 400 迭代（11.879 s）本身满足 ≥10 s。

### 8.5 证据位置

`lsu_opt/board/`：`base_run{1,2}.txt`、`cand_run{1,2}.txt`（UART 原文）、
`*_configuration_tcl.log`（下载结果）、`*_jtagserver.log`、`run_flash.ps1`/`capture_uart.ps1`/
`01b_program_only.tcl` 脚本副本。板测使用的两个位流 sha256 见 8.1，位流本体在
`baseline_build/artifacts/` 与 `lsu_opt/pds/run4_seed2_hold200/generate_bitstream/`。

## 9. 已知限制与未做项

1. **G1（core CSR 时序隐患）**：宏全开时 `isa_e2e` case 7 失败，两棵树 core 相同，属既有隐患，
   不在本次范围；宏注释态 15/15。详见阶段 1 验收文档。
2. 未做：store buffer、写缓冲、写回 Cache、非阻塞 Cache、多笔在途、双发射、流水级重构（用户禁止）；
   AXI fabric 改动（#5）、ram 模型改动（#7）也不做。
3. 未提前退休 store：写完成仍以成功 B 响应为准；未改变访存顺序、异常精确性、MMIO 旁路路径。
4. 收益是 1 迭代镜像仿真 + 400 迭代镜像上板的实测；上板对比严格同镜像（400 迭代），
   候选 8.386 s 触发 EEMBC ≥10 s 规则（见 8.4），正式成绩需把 ITERATIONS 提到 ≥477 后重做位流，
   本轮未做；不预先承诺百分比。
5. RTL 改动只在实验副本 `lsu_opt/src`（以及只读复核用 `lsu_opt_verify/src`）；正式交付树
   `01_code/pangoriscv_own` 与已交付基线位流未动。

## 10. 复现要点

- 回归：`cd $lsu\sim && python run_unit_tests.py`（其余同理）；全源 pipeline 与 A/B 命令见
  `commands.md` §3.7/§3.8 与 `..\lsu_opt\logs\*`。
- A/B：`vlog -sv -work ab_lsu +define+CACHE_ENABLE +define+PREDICT_ENABLE -incdir rtl/core
  -incdir rtl/perips -f sim/native_axi_sources.f $AUDIT\scripts\tb_coremark_audit_v3.sv`；
  `vsim -c -work ab_lsu tb_coremark_audit_v3 "+PROG=…program.hex" "+DATA=…data.hex" "+MAX_CYCLES=5000000"`。
- 逐事务：TB 与命令见 `phase2_diag_trace.md` §9（把 `p2diag` 库换成 `p2_lsu`，本树 RTL 即可）。
- PDS：`$env:PANGO_NATIVE_REPO=$lsu`；`$env:PANGO_NATIVE_BOARD_DIR=$lsu\platform\pango_native`；
  `$env:NATIVE_IMAGE_DIR=$AUDIT\baseline_build\src\build\native_software\coremark\performance`（400 迭代）；
  `cd $lsu\build\pango_native && pds_shell -file $lsu\platform\pango_native\build.tcl -work_dir …`。

## 11. 清单

- [x] 诊断归因与逐拍分解（`phase2_diag_trace.md`）
- [x] 候选方案（`phase2_candidates.md`，推荐 A）
- [x] RTL 实现（3 文件）+ 单元测试台更新
- [x] 10 套回归 + 全源 pipeline + isa_e2e（宏全开 14/15=G1；宏注释 15/15）+ halt_reset 5/5
- [x] 第二棵独立干净工作树复核（10 套件 + isa_e2e + halt_reset，结果一致）
- [x] 同镜像 CoreMark A/B（perf/validation，五 CRC）
- [x] 微程序 + 逐事务实测
- [x] PDS 时序/资源（run4 收敛，All Constraints Met）
- [x] 上板 A/B 400 迭代（各 2 次采集，逐字节可复现；基线 320,725,708 → 候选 226,427,447 ticks）
- [ ] 合并进交付树（等用户决定）

## 12. 通俗总结（对应“六个问题”）

1. **最慢在哪？** 前端加速后，CPU 每 100 拍里有约 49 拍卡在“等内存操作走完握手”，而不是等 Cache
   数据（400 迭代镜像里 load miss 只有 92 笔）。具体是每笔 load/store 都要在 LSU → D-Cache →
   AXI 引擎之间走固定几级状态：load 3.000 拍/笔、store 11.1~11.8 拍/笔，合计 345,091 拍。
2. **省了哪些等待？** 省的是“控制握手”的空转，不是存储延迟：发射同拍就把请求送出去（省 1 拍）、
   D-Cache 不再把请求多打一拍再等写数据（省 1~2 拍）、AXI 引擎不再空转 WR_PREP（省 1 拍）、
   B 响应回来的同拍就交给 LSU（省 2 拍）。实测 load 3.000→2.049 拍/笔、store 11.15→6.163 拍/笔，
   LSU 忙碌从 345,091 拍到 211,044 拍。
3. **功能/异常/访存顺序变了吗？** 没变。store 仍然等成功 B 响应才退休（没有提前退休）；
   异常与 MMIO、写合并路径不变；访存顺序不变。同镜像 CoreMark 五 CRC 与基线逐项相同
   （0xe9f5/0xe714/0x1fd7/0x8e3a/0x25b5）。10 套回归全过、halt/reset 5/5、ISA 端到端
   宏注释态 15/15（宏全开的 case 7 是与本次无关的既有 G1）。
4. **板上提升多少？代价多少？** 同镜像 400 迭代：320,725,708 → 226,427,447 拍（−29.40 %），
   11.8787 s → 8.3862 s，1.247172 → 1.766570 CoreMark/MHz（+41.6 %）。代价：LUT +69（12,441→
   12,510，+0.55 %）、FF −40、DRAM/DRM/APM 不变；时序 All Constraints Met，Setup slow 16.922 ns，
   27 MHz 下仍有大余量（估计 Fmax 49.71 MHz）。hold 靠把修复力度调到 200 ps + 换种子收敛。
5. **能替换上一版吗？** 可以作为上一版（T4 前端版）的后续版本替换：接口不变、行为不变、测试全过。
   需要提醒两点：一是 LUT 多 69；二是候选更快后 400 迭代只跑 8.386 s，触发 CoreMark “≥10 秒”
   规则提示（CRC 正常），若要对外报正式成绩需把 ITERATIONS 提到 ≥477 重编镜像、重做位流。
   正式交付树是否合并、什么时候合并由用户决定。
6. **证据在哪？** 本文件各节 + `phase2_diag_trace.md`（逐拍诊断）、`phase2_candidates.md`（方案）、
   `commands.md` §3.9（全部命令）、`lsu_opt/logs/`（回归与 A/B 日志）、`lsu_opt/pds/`（四次布线
   报告与位流）、`lsu_opt/board/`（4 次上板 UART 原文与下载日志）、`lsu_opt/MANIFEST_phase2.md`
   （sha256 清单）。
