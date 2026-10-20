# 性能计划：3.4222 → ≥3.60（P34：D-Cache posted store 队列）

日期：2026-10-21
起点：tag `score-3.4222-area`（LUT 18,006 / FF 9,877 / S 31,511，板上 3.4222，11.082 s，五项 CRC 全对）
本轮性质：**性能专项**（面积专项已定版）。面积只允许本轮这一处受控增量，其余仍守"只减不增"。

---

## 0. 目标与验收（缺一不可）

| 项 | 验收标准 |
|---|---|
| ① CoreMark/MHz | **≥ 3.60**，同一份位流、板上实测、1024 迭代、`Total time ≥ 10 s`、五项 CRC 全对 |
| ② 频率 | 27 MHz 约束下 `All Constraints Met`、失败端点 0、**hold 取 `multiseed_summary.csv` 的收尾值且 > 0** |
| ③ 资源 | LUT/FF/LUTRAM 取自**该位流**的 `device_map` `Used` 行，并报 CoreMark/kLUT |
| ④ 位流可跑 | 构建目录内有 `program.hex`/`data.hex`，综合日志有 **2 条** `Loading memory data from file`，无 `Cannot open specified data file` |
| ⑤ 证据 | `evidence/records/optimization/perf-store-fifo/` 一个实现一个目录（报告+日志+SHA256+串口原文） |

**换算**：3.4222 → 3.60 需 ticks 降 **4.94%**（299,226,614 → ≤284,500,000）。
本方案预期 −7.8%（≈3.70），留 2.5 个百分点余量。

---

## 1. 已测事实（20 迭代 A/B，评分窗口 5,843,953 周期 / 5,782,437 条）

| 项 | 数值 | 占比 |
|---|---:|---:|
| 有退休周期 | 4,435,496 | 75.9% |
| 无退休周期 | 1,408,456 | 24.1% |
| ├ store 占 EX 停顿 | **593,975** | **10.2%** |
| ├ load 占 EX 停顿 | 109,941 | 1.9% |
| └ 其余（重定向/前端/div） | ≈704,540 | 12.1% |
| 配对退休 | 1,346,942 | 占退休周期 30.4% |

**store 停顿的根因（已证实，不是推断）**：
`ST_REFUSE` 共 451,981 次拒绝，其中 **451,958 次（99.99%）是 `ST_WR_DRAIN + hold_valid`**
——D-Cache 只有一级 posted store buffer，上一笔还在等 AXI B（约 7.6 拍/笔）时它已满，第三笔只能被拒。
不是状态窗口（wrreq=0/wrresp=0）、不是读缺失（rd=0）、不是 MMIO（other=23）。

**配对被拒 2,457,231 周期的分桶**（决定"为什么先不改流水"）：

| 原因 | 周期 | 占比 | 为什么本轮不动 |
|---|---:|---:|---|
| RAW（lane0 写、lane1 读） | 896,708 | 36% | 要 EX→EX 内部旁路（两级 ALU 串联），改流水 + 时序风险高 |
| lane1 非 ALU/分支 | 665,343 | 27% | 多为 load/store 在 lane1 → 要第二访存口或记分板，属换架构 |
| lane0 非 ALU/访存 | 501,178 | 20% | 分支在 lane0 要"预测不跳+跳则冲刷"，正确性风险高 |
| WAW（两槽写同一 rd） | 210,181 | 8.5% | **低风险备选**，见 §6 |
| 不相邻 | 183,821 | 7.5% | 结构性，不可消 |

前端供给**不是**瓶颈：IFU 队列 91% 的周期占用 ≥2 项，`starve` 仅 446,939 且多数与重定向同拍。

---

## 2. 方案：P34 —— posted store 队列（只在 `dcache_axi` 一个模块内）

### 2.1 为什么不选别的
store 这项是**唯一**同时满足"收益 10.2%、只动一个模块、不改变任何完成语义"的改动。
四条被排除的路线（RAW 旁路 / lane1 访存 / lane0 分支 / 写响应不等 B）都要改流水或异常模型，
而其中"写响应不等 B"已被 P19–P32 六次失败证明是架构级改动。

### 2.2 语义边界（先说清"什么不变"）
1. **完成时刻不变**：data-RAM（`0x1000_0000..0x1000_4000`）的 store 仍在 **accept 拍**返回 OKAY；
   范围外（MMIO / 空洞）仍走同步 B —— `tb_isa_e2e` case 11（store access fault）必须原样通过。
2. **写合并时刻不变**：仍在 accept 拍用 `merged_accept` 写进 `data_mem`（命中行）。
3. **顺序不变**：队列 FIFO，AXI 写按程序序发出；读缺失仍**不得越过**任何在途写。
4. **不动**：`lsu_axi`、`icache_axi`、`branch_predictor`、`regs`、`axi_data_engine`、halt 语义。

### 2.3 设计（可直接对着写 RTL）
新增仅 4 个存储体 + 少量控制，取代现有单条 `hold_*`：

```
STORE_Q（深度 D，D 由 Phase 0 实测定，候选 2/4）
  每项 75 bit：addr[31:0] data[31:0] strb[3:0] size[2:0] id[3:0]
  （不再需要 set/word/way/hit/cached —— 合并已在 accept 拍完成）
  指针：head/tail(D 位) + count($clog2(D+1) 位，不需要 full 位比较）
drain_q  保持不变：代表"已交给写引擎、还在等 B 的那一笔"
在途总数 = count + drain_q
```

- **接受条件**（取代 `accept_early` / `accept_post`）：
  `req_ready` 对 data-RAM store 放开到 `state_q ∈ {ST_IDLE, ST_WR_DRAIN, ST_WR_POST}` 且 `count != D`；
  `b_valid=1, b_resp=OKAY` 于 accept 拍（与今天一致）。
  仍**拒绝**在 `ST_RD_AR/ST_RD_DATA/ST_HIT` 接受写入（`data_mem` 写口当拍被填充/无写口冲突风险）。
- **释放**：`count!=0 && !drain_q && 无在途引擎请求` → 把队头装入现有
  `i_req_*` / `wdata_q` / `wstrb_q` / `wreq_q`，置 `drain_q`，`state_q→ST_WR_DRAIN`。
  收到 B 时 `count` 不变（该笔已在释放时出队），只清 `drain_q`，再判断是否继续释放。
- **顺序门控**：读缺失的接受条件加 `count==0 && !drain_q`（今天由 `state_q==ST_IDLE` 隐式保证，改为显式）。
- **停机**：`dc_idle` 追加 `&& count==0`（否则 halt 会丢掉已应答的写）。
- 现有 `ST_WR_REQ` 经探针确认**从未被占用**（`st_wr_req=0`、拒绝桶 wrreq=0），本轮不删，只在注释里标注，
  避免"顺手清理"扩大改动面。

### 2.4 面积与布线
| 项 | 估算 | 说明 |
|---|---|---|
| ΔFF | **+220**（4×75 + 6 指针 − 86 现 hold） | 交付 profile FF 9,877 → ≈10,097 |
| ΔLUT | **+50 ~ +80** | `req_ready` 判据 + 队头多路选择 |
| LUTRAM/DRM/APM | 0 | 不新增阵列 |

**布线纪律（针对当前 hold 只有 +0.020/+0.015）**：
1. 新增 FF 全部留在 `R_DCACHE`，不新增跨区宽总线；FIFO→引擎保持 `wdata_q` 作为**寄存边界**，
   AXI 侧（`m_wdata`/`m_aw*`）时序与今天逐位相同。
2. 新增组合逻辑只允许落在 `req_ready` 与 `merged_accept` 两条已有路径上，**不得**进入
   `report_timing` 前 10 条（改完逐条核对）。
3. 若 PDS 报 hold < 0：先把 D 从 4 收到 2；仍负则整条回退到 tag `score-3.4222-area`，不带病定版。

---

## 3. 阶段与检查点

### Phase 0 —— 先量 burst 长度（决定深度 D，不猜）
在 `tb_coremark_uart.sv` 加一个"连续 store 长度"直方图探针（纯层次化，不碰 RTL），
用 20 迭代镜像跑一次（约 2.5 min），按 P90/P99 选 D。
**检查点 C0**：给出 D 的选择依据（直方图 + 覆盖比例）。

### Phase 1 —— 测试先行（RTL 未改，先让新用例能红）
`tb/unit/tb_dcache_axi.sv` 新增 5 条定向用例：
1. **背靠背 store 吸收**：连续 D 笔 data-RAM store，`b_valid` 每拍都有、LSU 不反压；
2. **顺序**：D 笔写不同地址，AXI `AW` 地址严格单调且与程序序一致；
3. **写后读**：队列未排空时 `load` 命中同地址必须读到新值（合并已在 accept 拍）；
4. **读缺失门控**：队列非空/`drain_q` 时，读缺失不得被接受（`req_ready=0`）；
5. **停机排空**：队列非空时 `dc_idle=0`，排空后才置 1。
同时把现有 3 个会摸写握手时序的 TB 复核一遍（教训：任何写时序改动都要动 3 个 TB）：
`tb_dcache_axi.sv`、`tb_lsu_axi.sv`、`tb/axi/tb_lsu_axi_ram.sv`。
**检查点 C1**：新用例在旧 RTL 上必须**失败**（证明确实在测新行为），其余用例不回归。

### Phase 2 —— 改 RTL（只改 `dcache_axi.v`）
按 §2.3 落地；`git commit -m "module: dcache_axi +80/+220/0"`（数字以实测为准）。
同提交内更新：`docs/architecture/module-area-plan.md` M19 卡（11 字段：存储资源、内部状态、面积、
变更记录）+ `docs/architecture/area-budget.csv` 加一行（`status active`，注明"性能专项批准增量"）。

### Phase 3 —— 回归（全绿才往下走）
`run_unit_tests.py`（9 套）、`run_icache_tests.py`、`run_dcache_tests.py`、`run_predictor_tests.py`、
`run_pipeline_tests.py`、`run_ram_tests.py`、`run_interconnect_tests.py`、`run_engine_tests.py`、
`run_ifu_engine_tests.py`、`run_isa_e2e.py`（15/15）、`run_halt_reset_tests.py`。
**检查点 C2**：任何一条 FAIL 立即停下修，不带病进入 A/B。

### Phase 4 —— 20 迭代 A/B（唯一允许用来判断"值不值"的数字）
`run_coremark_ab.py --switch CACHE --sides on --image-dir .../area20`，
判据：**五项 CRC 与基线逐项相同**（架构等价）+ `cycles` 降幅。
**检查点 C3**：`cycles` 需从 7,677,085 降到 ≤7,290,000（对应板上 3.60）。
若只到 7,33x,xxx（3.57~3.59）→ 追加 §6 的 WAW，再跑一次 A/B。

### Phase 5 —— PDS 实现（新构建目录，不复用 area-final 的）
1. 建 **`build/perf_p34/`**（教训：一个实现一个目录，`build/pango_native` 已有 area-final 证据，禁止重跑）；
2. 把 `performance/score1024/{program,data}.hex` 拷进该目录，`cwd=build/perf_p34` 启动
   `pds_shell -file platform/pango_native/build.tcl`（`PANGO_NATIVE_REPO` 指向 `firmware/code`）；
3. 交付 profile：`PERF_ENABLE=off`，`CACHE_ENABLE`/`PREDICT_ENABLE` on；构建后立刻还原并 `git status` 复核；
4. 综合前 grep `Loading memory data from file` 两条；
5. 布通判据：`Unrouted 0` + `All Constraints Met` + 失败端点 0 + `multiseed_summary.csv` hold > 0。
**检查点 C4**：hold 若 <0，按 §2.4 第 3 条降深度或回退。

### Phase 6 —— 上板实测
用 `evidence/records/bottleneck_audit/board/flash_and_capture.ps1`
（先开串口再烧写，教训 §7.6；`-Port COM34`、`-Seconds 90`、`-Sbit <新位流>`、PdsBin 已指向 D: 盘），
捕获后核对：`Total ticks`、`Total time (secs) ≥ 10`、五项 CRC、`Correct operation validated`。
**检查点 C5**：算分 `1024/ticks×1e6`，落证据目录，更新 `bitstream/README.md` 与 README 口径段。

---

## 4. 文档合规（skill §9，缺一项不许进 RTL/不许提交）

| 文档 | 改什么 |
|---|---|
| `module-area-plan.md` M19 卡 | 内部状态（队列项）、存储资源（FF 队列，非阵列）、面积实测值、物理区域仍 `R_DCACHE`、变更记录、测试清单 |
| `area-budget.csv` | 加一行 `delta,dcache_axi,...,active,note=性能专项 P34`；`__max__` 的 FF 上限按实测 + 余量上调并写明理由 |
| `docs/lessons/mistakes-log.md` | 只有出现**可复用**新坑才写；一次性事实不写 |
| `verification.md` 问题台账 | 记录 P34 与其验证状态 |

---

## 5. 回退
任一门禁不过 → `git revert` 到 `score-3.4222-area`，位流仍用 `pangoriscv_i1024_area.sbit`（已入库、已上板验证）。
不留半成品、不留第二次实现在同一目录。

---

## 6. 备选：WAW 放行（仅在 Phase 4 差一点点时启用，+3.6%）
`pair_ok` 里 `(drd==0||drdh==0||drd!=drdh)` 是纯保守检查：`regs.v` 的写口与 4 个读口都已按
"同址双写 lane1 赢"实现（文件头注释即如此声明）。删除该条 → 约 210k 周期变配对。
风险：需 `tb_pipeline.sv` 加一条"两槽写同一 rd"定向用例；面积 **0**。
若启用，独立提交 `module: pangoriscv 0/0/0`，与前一项分开 A/B。

---

## 7. 需要你拍板的两件事

1. **面积 +220 FF / +80 LUT 是否批准**（这是性能专项唯一允许的增量；不批就只能走 §6 的 3.6% 路线，到不了 3.6）。
2. **深度 D 由 Phase 0 实测决定（2 或 4）**，我不预设；若你希望"一次就选 4、少跑一轮"，也可以直接定 4
   （代价：比 2 多 150 FF，收益取决于 burst 长度）。

---

## 8. 执行结果（2026-10-21 05:00）

**已落地**：D-Cache posted store 队列（`STQ_DEPTH=4`）+ `tag_wr_q` 复制寄存器，
只动 `dcache_axi.v`（+ 两个测试台 + ISA case 16）。

| 项 | 基线 area-final | 本版 | 结论 |
|---|---:|---:|---|
| 板上 ticks | 299,226,614 | **291,733,469** | −2.50% |
| **板上 CoreMark/MHz** | 3.4222 | **3.5101** | **+2.56%（实测）** |
| 五项 CRC | 全对 | 全对且逐项相同 | 架构等价 |
| LUT/FF/LUTRAM | 18,006/9,877/3,628 | 18,085/9,808/3,664 | +0.17% 站点，面积中性 |
| hold | +0.020/+0.015 | **−0.002/−0.001** | **1 失败端点 → ② 不合规** |

**检查点结论**：
- C0（burst 深度）：97.2% 孤立单笔，2 深 4,478 / 3 深 5,114 → 取 `STQ_DEPTH=4`。
- C1（测试先行）：E1 在旧 RTL 上红、改后绿；ISA 16/16；dcache 全绿；engine 64/64。
- C3（A/B）：窗口 5,843,953 → 5,697,334（−2.51%），预测 3.5103，**板上实测 3.5101（误差 0.01%）**。
- **C4（PDS）：hold 未过 → 本版不进 `bitstream/`**。失败路径
  `data_cache/tag_q[4] → tag_mem_1_4/DI`；`tag_wr_q` 被综合合并（FF 未变），只有种子一个变量；
  seed 7 那轮布线在 8~11 条未布通震荡失败。
- **目标 3.60 未达成**：还差约 142k 窗口周期。

**下一轮（按收益排序，均已定位）**：
1. **写引擎流水化（2 outstanding）**：drain 2.88M 周期 / 7.6 拍每笔是窗口的一半，
   需求率≈吞吐；预计可到 ~4.0。需先改 `tb_axi_data_engine` 的 `WRITE_OWNERSHIP` 契约。
2. **hold 闭合**：给 `tag_wr_q` 加 keep 属性或换默认种子重跑；否则 3.5101 只能算实验值。
3. 次要：I-Cache 4KB→8KB（旧实测 +3.0%，但 +2.6k FF，会破坏面积专项成果，不推荐）。

---

## 9. 3.6 → 3.8 计划（P35：写通路吞吐，2026-10-21 05:10）

### 9.1 依据（已实测，不再重复验证）
- 评分窗口 5,697,334 周期；**drain 2.88M 周期 = 窗口的 50%**，379,252 笔 store → **7.6 拍/笔**。
- 需求率 ≈ 吞吐（`core_list_init` 每节点 1 load + 5 store），所以**加深队列无效**（占用在"满 4"停 805k 周期）。
- 7.6 拍的构成（逐拍对照 RTL）：IDLE 收请求(1) → PREP 收 W(1) → SEND 发 AW/W(1~2) → RESP 等 B(1) → HOLD 交 B(1)。

### 9.2 两步，每步单独 A/B + PDS + 上板
| 步 | 改动 | 预期窗口 | 预期分 |
|---|---|---|---|
| **P35a** | `axi_data_engine`：允许在 `WR_HOLD` 收下一笔（与交 B 同拍）；`dcache_axi`：把队头在释放拍**组合**递给引擎（P11 同款脉冲） | 5.32M | ~3.76 |
| **P35b** | `axi_data_engine`：接受请求的同拍**锁 W 拍**（跳过 PREP），`w_ready` 需 `!protocol_fault && !config_fault` | 4.94M | ~4.05 |

### 9.3 必须先改的测试契约（否则会"假红"）
`tb/axi/tb_axi_read_engine.sv` 的 `WRITE_OWNERSHIP` 目前断言"交 B 之后 `req_ready` 必须仍为低"，
它编码的是**旧微架构**（HOLD 期不接受）。新契约应是：
> **B 未被主机取走之前，`req_ready` 必须为低；取走的那一拍允许接受下一笔。**

改判据要在 TB 里写清"为什么改"，并在 A/B 前先跑 `run_engine_tests.py`（64 例）确认不是放松检查。

### 9.4 每步之后必须做的四件事（用户要求，按顺序）
1. 面积/布线复核：`device_map` `Used`、`R_DCACHE`/`R_IO` 不新增跨区宽总线、`report_timing` 前 10 条复核；
2. 删冗余：被综合合并的寄存器、未用状态/信号、临时探针（保留有复用价值的）；
3. 查 bug：ISA 16/16、dcache、engine 64/64、halt-reset、A/B 五项 CRC 逐项相同；
4. 同步文档：`module-area-plan.md` 模块卡（11 字段）+ `area-budget.csv` + `mistakes-log.md`。

### 9.5 回退点
- `a751712` = P34 检查点（板上 3.5101，hold 未闭合）；
- `bitstream/pangoriscv_i1024_area.sbit` = 仍可交付的 3.4222；
- 任一步 hold<0 / 布线不收敛 / CRC 变 → `git revert` 到 `a751712` 并保留旧的 3.4222 交付。
