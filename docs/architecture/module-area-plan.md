# 模块与面积架构（面积 / 效率专项的唯一依据）

> **强制力**：本文件是"分模块、有规划地写模块"的合同。
> 改动任何 RTL 之前先读本文件与 [`area-budget.csv`](area-budget.csv)；
> 改完必须同步更新；收尾必须跑 `firmware/code/tools/check_area_budget.py`，非零退出不得提交。
> 规则原文见 `SKILL.md` §9（供后续 AI 强制遵守）。
>
> **本专项范围**：只做面积与资源效率（CoreMark/kLUT），性能只允许"不回退"。
> 不做 8 KB Cache、不做 IPC 优化、不做 ILA / 应用场景 / 频率扫描。

---

## 1. 口径与术语

| 术语 | 含义 | 数据来源 |
|---|---|---|
| **LUT / FF / LUTRAM / DRM / APM** | 打包后的逻辑资源计数 | `device_map` 的 `Used` 行（工程口径，验收只认这个） |
| **站点总量 S** | `S = LUT + FF + LUTRAM` | 同上；本专项主指标（拥塞与可布线性跟着它走） |
| **模块原语数** | 综合网表里每个模块内 `GTP_LUT` / `GTP_DFF` / `RAM64X1D` / `DRM36K` / `APM` 的实例计数 | `build/<stage>/build/pango_native/synthesize/pangoriscv_top_syn.vm` |
| **物理映射** | 哪个存储阵列被推断成 LUTRAM 还是 BRAM | `synthesize/apm_drm_lutram_utilization.log` |

**为什么两个口径都要**：`Used` 是打包后的真值（验收用），模块原语数是**未打包**的（只用于模块间排序与预算分配）。两者不可混用，不可相互换算。

**当前基线（tag `score-3.4194-1024`，实现 `build/code_ic4k`）**

```
LUT 21,949 | FF 14,104 | LUTRAM 3,628 | DRM 4 | APM 6 | S = 39,681
27 MHz：All Constraints Met；setup +14.750/+22.341；hold +0.015/+0.002；失败端点 0
板上：299,467,030 ticks / 1024 迭代 / 11.091 s / 3.4194 / 五项 CRC 全对
```

**M1 落地后（`PERF_ENABLE` 关，2026-10-21 实测）**

```
LUT 20,422 | FF 12,335 | LUTRAM 3,628 | DRM 4 | APM 6 | S = 36,385（−8.30%）
证据：evidence/records/optimization/area-M1/measurement.md
控制组（PERF on）与上面的基线逐项一致 → 资源检查（compile+synthesize+dev_map）可作面积 A/B 代理
```

**M3 落地后（BTB 缩位宽，2026-10-21 实测）**

```
LUT 19,113 | FF 11,183 | LUTRAM 3,628 | DRM 4 | APM 6 | S = 33,924（相对基线 −14.51%）
证据：evidence/records/optimization/area-M3/measurement.md
20 迭代 A/B 与改前逐项一致：cycles 7,681,846 / mispred 137,933 / 五项 CRC 完全相同
```

---

## 2. 模块卡模板（11 个字段，缺一项不得进 RTL）

| # | 字段 | 说明 |
|---|---|---|
| 1 | 名称 / 文件 / 流水级 | 如 `ifu_axi` / `rtl/core/ifu_axi.v` / 取指 |
| 2 | 职责 | 一句话，并写明"不做什么"（防止模块越界长大） |
| 3 | 时钟域 / 复位 | 单 `clk` / `rst_n` 或其它；复位是否异步 |
| 4 | 接口 | 每类端口的**宽度**、协议、时序约定（不逐条抄端口名，写清契约） |
| 5 | 内部状态 | 寄存器/阵列清单：名称、位宽、复位值、副作用 |
| 6 | 存储资源 | 阵列深度×宽度、**推断成 LUTRAM / BRAM / ROM 及属性** |
| 7 | 面积 | 实测（网表原语）+ **预算**（本专项目标） |
| 8 | 物理区域 | 允许放哪个 region、依据（总线宽度 / 时序） |
| 9 | 关键路径 | 是否出现在 `report_timing.rtr` 的前若干条 |
| 10 | 测试 | 对应 tb 与回归脚本 |
| 11 | 变更记录 | 日期 / ΔLUT、ΔFF、ΔLUTRAM / 回退点（commit） |

**模块边界纪律**：**不为"好看"拆模块**。模块边界会阻断跨边界优化，通常**增加**面积。只有两种情况动结构：
① 模块超出预算；② 存储阵列的物理实现错误（如数据 RAM 落进 LUTRAM）。

---

## 3. 全设计面积账本

### 3.1 总量（`device_map` `Used`）

| LUT | FF | LUTRAM | DRM | APM | 站点 S |
|---:|---:|---:|---:|---:|---:|
| 21,949 | 14,104 | 3,628 | 4 | 6 | **39,681** |

### 3.2 逐模块（网表原语；FF 列可相加，LUT 列**不可**相加）

> **口径警告（必读）**：本表的 LUT 列只统计网表里的 `GTP_LUT*` / `GTP_ALUT*` 实例，
> **漏计 `GTP_MUX*` / `GTP_LUT7` / 其它组合原语**，全表相加得 **18,397**，而
> `device_map` 的真值是 **21,949**（差 16%）。因此：
> - **LUT 列只能做模块间相对排序**，不能相加、不能当预算基数；
> - **FF 列可以相加**（合计 14,234，与 `device_map` 的 14,104 差 0.9%，属舍入）；
> - **LUTRAM / DRM / APM 列以 `apm_drm_lutram_utilization.log` 为准**（见 §3.3）。

| # | 模块 | 文件 | 级 | LUT | FF | LUTRAM | DRM | APM | 物理属性 |
|---|---|---|---:|---:|---:|---:|---:|---:|---|
| 1 | `ifu_axi` | core/ifu_axi.v | 取指 | 3,223 | 2,831 | 0 | 0 | 0 | 宽 FF 阵列 |
| 2 | `icache_axi` | core/icache_axi.v | 存储 | 2,089 | 3,071 | 1,024 | 0 | 0 | LUTRAM + 大 FF |
| 3 | `pangoriscv` | core/pangoriscv.v | 胶合 | 2,410 | 1 | 0 | 0 | 0 | 纯组合（`ctrl.v` 内联） |
| 4 | `branch_predictor` | core/branch_predictor.v | 取指 | 1,364 | 1,952 | 0 | 0 | 0 | 宽 FF 阵列 |
| 5 | `perf_regs` | perips/perf_regs.v | 仪表 | 850 | 1,665 | 0 | 0 | 0 | 计数器阵列 |
| 6 | `axi_ram`(program) | perips/axi_ram.v | 存储 | 150 | 143 | 0 | 4 | 0 | **BRAM（ROM）** |
| 7 | `axi_ram`(data) | perips/axi_ram.v | 存储 | 1,022 | 212 | **2,048** | 0 | 0 | **LUTRAM 热点** |
| 8 | `regs` | core/regs.v | 译码 | 857 | 992 | 0 | 0 | 0 | mux 密集 |
| 9 | `axi_interconnect` | bus/axi_interconnect.v | 总线 | 764 | 119 | 0 | 0 | 2 | 控制 |
| 10 | `dcache_axi` | core/dcache_axi.v | 存储 | 740 | 366 | 556 | 0 | 0 | LUTRAM |
| 11 | `ex` | core/ex.v | 执行 | 915 | 0 | 0 | 0 | 4 | 组合 + APM |
| 12 | `ex_alu` | core/ex_alu.v | 执行 | 665 | 0 | 0 | 0 | 0 | 组合 |
| 13 | `csr_native` | core/csr_native.v | 执行 | 419 | 289 | 0 | 0 | 0 | 小 |
| 14 | `id` | core/id.v | 译码 | 169 | 0 | 0 | 0 | 0 | 组合 |
| 15 | `id_alu` | core/id_alu.v | 译码 | 91 | 0 | 0 | 0 | 0 | 组合 |
| 16 | `if_id` | core/if_id.v | 译码 | 190 | 230 | 0 | 0 | 0 | 宽 FF |
| 17 | `pipe_slot` ×2 | core/pipe_slot.v | 流水 | 3 | 565 | 0 | 0 | 0 | 宽 FF |
| 18 | `lsu_axi` | core/lsu_axi.v | 访存 | 253 | 105 | 0 | 0 | 0 | 小 |
| 19 | `div` | core/div.v | 执行 | 210 | 172 | 0 | 0 | 0 | 小 |
| 20 | `div_adapter` | core/div_adapter.v | 执行 | 3 | 100 | 0 | 0 | 0 | 小 |
| 21 | `pc_reg` | core/pc_reg.v | 取指 | 33 | 32 | 0 | 0 | 0 | 小 |
| 22 | `retire_ctrl` | core/retire_ctrl.v | 退休 | 68 | 96 | 0 | 0 | 0 | 小 |
| 23 | `axi_read_engine` | core/axi_read_engine.v | 访存 | 3 | 4 | 0 | 0 | 0 | 小 |
| 24 | `axi_data_engine` | core/axi_data_engine.v | 访存 | 17 | 82 | 0 | 0 | 0 | 小 |
| 25 | `axi_reg_slave` ×6 | perips/axi_reg_slave.v | 外设 | **1,437** | 800 | 0 | 0 | 0 | 中（6 实例：594/175/168/168/167/165） |
| 26 | `axi_uart` | perips/axi_uart.v | 外设 | 134 | 159 | 0 | 0 | 0 | 小 |
| 27 | `axi_timer` | perips/axi_timer.v | 外设 | 85 | 96 | 0 | 0 | 0 | 小 |
| 28 | `axi_spi` | perips/axi_spi.v | 外设 | 72 | 89 | 0 | 0 | 0 | 小 |
| 29 | `axi_gpio` | perips/axi_gpio.v | 外设 | 35 | 68 | 0 | 0 | 0 | 小 |
| 30 | `irq_ctrl` | perips/irq_ctrl.v | 外设 | 9 | 7 | 0 | 0 | 0 | 小 |
| 31 | `axi_error_slave` | bus/axi_error_slave.v | 总线 | 40 | 26 | 0 | 0 | 0 | 小 |
| 32 | `pangoriscv_axi_top` | core/pangoriscv_axi_top.v | 胶合 | 6 | 0 | 0 | 0 | 0 | 胶合 |
| 33 | `pangoriscv_axi_soc` | soc/pangoriscv_axi_soc.v | 胶合 | 5 | 0 | 0 | 0 | 0 | 胶合 |
| 34 | `pangoriscv_top` | soc/pangoriscv_top.v | 封装 | 138 | 66 | 0 | 0 | 0 | 观测 / IO |
| 35 | 头文件 | core/defines.v、axi_defs.vh、native_axi_macros.vh、soc_config.vh | 参数 | — | — | — | — | — | 参数 |
| — | **采样合计** | — | — | **18,397** | **14,234** | 3,628 | 4 | 6 | 对比真值 21,949 / 14,104 |

### 3.3 存储阵列的物理归属（`apm_drm_lutram_utilization.log`）

| 阵列 | 深度 × 宽度 | 原语 | 数量 | 结论 |
|---|---|---|---:|---|
| `soc/program_ram/mem` | 4K × 32（4×4K×8） | `GTP_DRM36K_E1` | **4** | 已在 BRAM（**最优，不动**） |
| `soc/data_ram/mem`…`mem_3` | 4096 × 8 ×4 | `GTP_RAM64X1DP` | **2,048** | **LUTRAM（M2 要改）** |
| `soc/core/instruction_cache/even_mem`(+`_1`) | 512 × 32 | `GTP_RAM64X1DP` | 256 + 256 | LUTRAM |
| `.../odd_mem`(+`_1`) | 512 × 32 | `GTP_RAM64X1DP` | 256 + 256 | LUTRAM（M5 待判是否副本） |
| `soc/core/data_cache/data_mem`/`_1`/`_3` | 512 × 32 ×3 | `GTP_RAM64X1DP` | 256 ×3 | LUTRAM（M6 待判） |
| `.../tag_mem`、`tag_mem_1` | 64 × 22 | `GTP_RAM64X1DP` | 22 + 22 | LUTRAM |

> **已知口径差异（待 M6 查清）**：映射日志给 D-Cache 的 3 个数据阵列共 768 个 primitive，
> 网表按模块计数为 556。两者差 212，登记为 `M6` 的必查项，**在查清前不得引用 768 这个数**。

---

## 4. 面积预算与动作

### 4.1 预算（修订版：只用"可核"的分项）

> **预算修订说明**：初版写"S ≤ 31,000 / LUT ≤ 20,400"时，把 M1 的 LUT 增益当成了确定值。
> 但网表 LUT 采样漏计原语（见 §3.2 警告），M1 的打包 LUT 降幅**只能实测**。
> 因此预算按"确定的 FF/LUTRAM + 区间化的 LUT"重算，并把条件项单列。

| 分项 | 现状 | Δ（可信度） | 依据 |
|---|---|---|---|
| M1 仪表 | 1,444 LUT / 1,665 FF（采样） | **实测 −1,527 LUT / −1,769 FF（2026-10-21）** | 删 `perf_regs` + 其从机；证据 `area-M1/measurement.md` |
| M2 数据 RAM | 2,048 LUTRAM | **受阻（2026-10-21）**：三次尝试均未让映射器换表，已回退 | 见 `area-M2/measurement.md`；后续可改读端口形态或查 `PAP_RAM_STYLE` 取值 |
| M3 BTB | 1,952 FF | **实测 −1,152 FF / −1,309 LUT（2026-10-21）** | tag 25→7、target 32→14；LUT 收益远超预期（三个查表口的比较器一起塌下来） |
| M4b `q_pred_hi` | 512 FF | **FF −512（确定）** | 16×32 |
| M4a `DEPTH` 16→8 | 1,320 FF | **FF −1,320（确定）** | 4×32×16 → ×8 |
| M5 I-Cache 副本（条件） | 1,024 LUTRAM | LUTRAM −512 | 需实例名级证据 |
| M6 D-Cache 副本（条件） | 556 LUTRAM | LUTRAM −256 | 需实例名级证据 |

| 场景 | ΔFF | ΔLUTRAM | ΔLUT | ΔS | 目标 S | 目标 LUT |
|---|---:|---:|---:|---:|---:|---:|
| 只做必成项（M1~M4） | −4,649 | −2,048 | −1,100~−1,544 | −7,797~−8,241 | **≤ 31,900** | **≤ 20,900** |
| 含条件项（+M5/M6） | −4,649 | −2,816 | 同上 | −8,565~−9,009 | **≤ 31,200** | 同上 |

> **2026-10-21 修订（M2 受阻）**：M2（数据 RAM→BRAM，原计划 −2,048 LUTRAM）三次尝试均未生效并已回退，
> 见 `area-M2/measurement.md`。因此修订目标：
>
> | 场景 | ΔS | 目标 S | 目标 LUT |
> |---|---:|---:|---:|
> | M1+M3+M4（必成项，去掉 M2） | −1,527 −1,769 −1,152 −1,832 ≈ **−6,280** | **≤ 33,500** | **≤ 20,400** |
> | 再加 M5/M6（条件项） | −768 | **≤ 32,700** | 同上 |
>
> M1 已落地（S 39,681 → 36,385）；M3/M4 是确定性的 FF 收益，仍在计划内。

**结论口径**：验收以"必成项达成 S ≤ 31,900 且 LUT ≤ 20,900"为准；条件项达成则更好。
`CoreMark/kLUT` 由 0.1558 升到 **≈0.164**（LUT 取 20,900），**仍低于 P21 的 0.1718**——
继续压 LUT 只能动 `pangoriscv` 旁路网络（2,410 LUT）或 IFU 结构，属高风险，**不在本专项**。

### 4.2 动作总表

| 编号 | 模块 | 动作 | 预期 | 风险 | 回退条件 |
|---|---|---|---|---|---|
| M1 | `perf_regs` + 从机 | 交付构建关 `PERF_ENABLE`；`set_switches.py` 支持按名开关 | **实测 −1,527 LUT / −1,769 FF** | 分析计数器消失 → 改用仿真 | **已完成 2026-10-21**（delta 门禁 PASS） |
| M2 | `axi_ram`(data) | `/* synthesis syn_ramstyle = "block_ram" */`（必要时 `no_rw_check`） | ~~−2,048 LUTRAM~~ **受阻** | 读端口是组合读，映射器不认 | **已试用 3 次并回退**（`area-M2/measurement.md`） |
| M3 | `branch_predictor` | `TAG_BITS` 25→7、`target_q` 32→14（由 `PGM_BYTES` 派生） | **实测 −1,309 LUT / −1,152 FF** | 程序 >16 KB 别名（只影响预测） | **已完成 2026-10-21**（A/B 逐项一致，delta 门禁 PASS） |
| M4b | `ifu_axi` | 删 `q_pred_hi`（配对第二条 = `pc+4`） | −512 FF | 预测信息重算 | ticks +0.5% 即回退 |
| M4a | `ifu_axi` | `DEPTH` 16→8 | −1,320 FF | 取指突发下降 | ticks +0.5% 即回退 |
| M5 | `icache_axi` | 归属分析 → 证据成立才删阵列副本 | 条件性 −512 LUTRAM | 判断错会取错指令 | 任一 CRC 变即回退 |
| M6 | `dcache_axi` | 归属分析（含 212 primitive 差额） | 条件性 −256 LUTRAM | 同上 | 同上 |
| M7 | `regs` | 只做"4R2W 能否 LUTRAM/BRAM 化"调研 | 潜在 −857 LUT（不承诺） | 多端口不可行 | 只出报告，不改 RTL |
| M8 | `if_id`/`pipe_slot` | 仅有余量时评估 304 位 payload 恒零字段 | 潜在 −数百 FF | 高 | 只评估 |

---

## 5. 模块卡（全 34 项）

> 每张卡片 11 个字段。`面积` 一栏格式：**实测 LUT/FF/LUTRAM/DRM/APM → 预算**。
> "不在前 8" 指未出现在 `report_timing.rtr` 的前 8 条路径中（该报告前 8 条已逐条核对）。

### 5.1 取指与预测

#### M01 `pc_reg` — `rtl/core/pc_reg.v` — 取指
2. **职责**：PC 寄存器与下一 PC 选择（顺序/重定向/预测）；不做译码、不做分支判定。
3. **时钟/复位**：`clk`，`rst_n` 异步低有效。
4. **接口**：`next_pc`（32b）进、`pc`（32b）出、`redirect_valid/pc`（1b/32b）。
5. **内部状态**：`pc_q[31:0]`。
6. **存储**：无阵列。
7. **面积**：33/32/0/0/0 → **不变**。
8. **物理区域**：`R_FETCH`（必须与 `branch_predictor`、`ifu_axi` 同区）。
9. **关键路径**：不在前 8。
10. **测试**：`tb/unit/tb_pipeline.sv`。
11. **变更**：2026-10-21 立卡（基线 `f136a44`）。

#### M02 `ifu_axi` — `rtl/core/ifu_axi.v` — 取指
2. **职责**：16 项指令队列，按 `PC / PC+4` 双字送 IF，处理 chain、配对、重定向与 stale 计数；**不做**译码、不做分支预测本身。
4. **接口**：请求侧 `fetch_pc/predicted_next_pc`（32b）；响应侧 `result_pc/result_inst/result_pc_hi/result_inst_hi`（各 32b）+ `result_pair`；AXI 读侧 `eng_req_*`（32b 地址/数据、8b len、4b id）。
5. **内部状态**：`q_pc/q_inst/q_pred/q_inst_hi/q_pred_hi`（各 16×32b）、`q_cause`（16×5b）、`pcf0/1_q`、`pdf0/1_q`、`pdf0/1_q2`、`next_pc_q`、`ocnt_q`、`stale_cnt_q`、`head_q/tail_q/count_q`。
6. **存储**：全部 FF，无 LUTRAM/BRAM。
7. **面积**：3,223/2,831/0/0/0 → **3,100/1,000/0/0/0**（M4a+4b）。
8. **物理区域**：`R_FETCH`，紧邻 `R_ICACHE`（64b/拍取指总线）。
9. **关键路径**：不在前 8。
10. **测试**：`tb/unit/tb_ifu_axi.sv`、`tb/axi/tb_ifu_axi_engine.sv`、`tb_pipeline.sv`。
11. **变更**：2026-10-21 立卡；M4b（删 `q_pred_hi`）→ M4a（`DEPTH` 8），各自独立提交。

#### M03 `branch_predictor` — `rtl/core/branch_predictor.v` — 取指
2. **职责**：32 项直接映射 BTB + 2-bit 方向计数器，双查表口（lane0/lane1）；只做预测，不判定分支结果。
4. **接口**：`lookup_pc/lookup_pc_hi`（32b）→ `hit/pred_next_pc`（各两路）；训练侧 `train_valid/train_pc/train_target/train_taken`。
5. **内部状态**：`tag_q[32][24:0]`、`target_q[32][31:0]`、`count_q[32][1:0]`（合计 1,888 FF）。
6. **存储**：FF 阵列（**非 LUTRAM**）。
7. **面积**：1,364/1,952/0/0/0 → **1,264/800/0/0/0**（M3）。
8. **物理区域**：`R_FETCH`。
9. **关键路径**：不在前 8。
10. **测试**：`tb/unit/tb_branch_predictor.sv`、`run_predictor_tests.py`。
11. **变更**：2026-10-21 立卡；M3 把 tag/target 位宽改为由 `PGM_BYTES` 派生（25→7、32→14）。

#### M04 `icache_axi` — `rtl/core/icache_axi.v` — 存储
2. **职责**：2 路组相联 I-Cache，**64 组 × 2 路 × 8 字 = 4 KB**；命中当拍返回，缺失走 AXI 8 拍补行；不做 MMU/权限。
4. **接口**：请求侧 `req_*`（32b 地址、8b len、4b id）；响应侧 `rsp_data/rsp_data_hi`（32b×2）、`rsp_pair`；AXI 读侧 `m_ar*/m_r*`。
5. **内部状态**：`state`、`addr_q`、`id_q`、`set_q`、`word_q`、`tag_q[20:0]`、`way_q`、`rd_index_q[9:0]`、`rsp_data_q/rsp_data_hi_q`、`beat_q`、`fill_bad_q/fill_kill`。
6. **存储**：`even_mem/odd_mem`（512×32，LUTRAM）+ 疑似副本 `even_mem_1/odd_mem_1`；标签 LUTRAM。
7. **面积**：2,089/3,071/1,024/0/0 → **2,089/待定/512**（M5 条件）。
8. **物理区域**：`R_ICACHE`（与 `R_FETCH` 相邻；同区总线最宽，禁止跨区）。
9. **关键路径**：**hold 前 5 之一**：`way_q → odd_mem_1_3_11/ram64x1d/WADDR[2]`。
10. **测试**：`tb/unit/tb_icache_axi.sv`、`run_icache_tests.py`。
11. **变更**：2026-10-21 立卡；M5 先做归属分析（3,071 FF 与源码 ~200 位不符），证据成立才删副本。**头注释 "32 sets" 已过时（实际 64 组），随 M5 一并修正。**

### 5.2 译码与流水寄存器

#### M05 `if_id` — `rtl/core/if_id.v` — 译码
2. **职责**：IF→ID 流水寄存器，两槽（超纯量），带 valid/ready/flush 语义。
4. **接口**：`in_*`/`out_*` 两槽各（32b pc、32b inst、32b pred）+ 故障字段；`in_ready/out_ready`。
5. **内部状态**：两槽 payload（≈150b/槽）+ valid 位。
6. **存储**：FF。
7. **面积**：190/230/0/0/0 → **不变**（M8 仅评估）。
8. **物理区域**：`R_CORE` 边缘（与 `R_FETCH` 相邻）。
9. **关键路径**：不在前 8。
10. **测试**：`tb_pipeline.sv`、`tb_isa_e2e.sv`。
11. **变更**：2026-10-21 立卡。

#### M06 `id` — `rtl/core/id.v` — 译码
2. **职责**：指令字段切分、立即数、寄存器读写口地址、CSR 地址；纯组合，无状态。
4. **接口**：`inst_i`（32b）、读数据（2×32b）→ 写地址/写使能/ALU 操作数选择。
5. **内部状态**：无（组合）。
6. **存储**：无。
7. **面积**：169/0/0/0/0 → **不变**。
8. **物理区域**：`R_CORE` 中心（与 `regs` 相邻）。
9. **关键路径**：不在前 8。
10. **测试**：`tb_isa_e2e.sv`（间接覆盖）。
11. **变更**：2026-10-21 立卡。

#### M07 `id_alu` — `rtl/core/id_alu.v` — 译码
2. **职责**：**lane1 的最小译码器**（只支持 ALU 类 / 分支 / JAL）；不做访存、不做 CSR。
4. **接口**：lane1 的 `inst`（32b）→ lane1 的 ALU 控制与配对合法性。
5. **内部状态**：无。
6. **存储**：无。
7. **面积**：91/0/0/0/0 → **不变**。
8. **物理区域**：`R_CORE`。
9. **关键路径**：不在前 8。
10. **测试**：`tb_isa_e2e.sv`、`tb_pipeline.sv`。
11. **变更**：2026-10-21 立卡。

#### M08 `regs` — `rtl/core/regs.v` — 译码
2. **职责**：32×32 通用寄存器堆，**4 个组合读口 + 2 个同步写口**（lane0/lane1）+ JTAG 写口；不做旁路。
4. **接口**：`raddr1..4`（5b）→ `rdata1..4`（32b）；`waddr/wdata/we`、`waddr2/wdata2/we2`。
5. **内部状态**：`rfile[32][31:0]`（1,024 位）。
6. **存储**：FF（4R2W 不映射 LUTRAM/BRAM）。
7. **面积**：857/992/0/0/0 → **不变**（M7 只调研能否 LUTRAM/BRAM 化）。
8. **物理区域**：`R_CORE` **正中心**（4×32b 读 + 2×32b 写是最高频总线）。
9. **关键路径**：**setup 前 3 之一**：`u_id_ex/slot/data_q[303] → u_regs/rfile[3][5]`（15.018 ns slack）。
10. **测试**：`tb_pipeline.sv`、`tb_isa_e2e.sv`。
11. **变更**：2026-10-21 立卡。

#### M09 `id_ex` — `rtl/core/id_ex.v` — 流水
2. **职责**：ID→EX 流水寄存器的**包装**（内部用两个 `pipe_slot`）；自身无逻辑。
7. **面积**：0/0（实例化 `pipe_slot` ×2：565 FF）→ 见 M10。
8. **物理区域**：`R_CORE`。
11. **变更**：2026-10-21 立卡。

#### M10 `pipe_slot` — `rtl/core/pipe_slot.v` — 流水
2. **职责**：参数化流水 payload 握手（valid/ready 反压、flush）。
5. **内部状态**：`data_q[303:0]` 等 payload 位。
6. **存储**：FF（319 + 246 FF 两个变体）。
7. **面积**：3/565/0/0/0 → **不变**（M8 仅在有余量时评估 304 位里是否有恒零字段）。
8. **物理区域**：`R_CORE`。
9. **关键路径**：**setup 最差路径的起点**：`u_id_ex/slot/data_q[303]`（14.750 ns slack）。
10. **测试**：`tb/unit/tb_pipe_slot.sv`、`tb_pipeline.sv`。
11. **变更**：2026-10-21 立卡。

### 5.3 执行与退休

#### M11 `ex` — `rtl/core/ex.v` — 执行
2. **职责**：ALU、分支/跳转判定、访存发射、CSR 访问、乘除法发起；不负责访存完成。
4. **接口**：操作数（2×32b）、`imm`、CSR 数据；出 `mem_*`、`reg_wdata`、`branch_taken`。
5. **内部状态**：无（组合）+ 4 个 APM 乘法器实例。
6. **存储**：4 APM。
7. **面积**：915/0/0/0/4 → **不变**（乘法必需）。
8. **物理区域**：`R_CORE`。
9. **关键路径**：不在前 8。
10. **测试**：`tb_isa_e2e.sv`、`tb_pipeline.sv`。
11. **变更**：2026-10-21 立卡。

#### M12 `ex_alu` — `rtl/core/ex_alu.v` — 执行
2. **职责**：**lane1 的最小执行单元**（ALU / 分支 / JAL）；不做访存、不做 CSR、不做乘除。
7. **面积**：665/0/0/0/0 → **不变**。
8. **物理区域**：`R_CORE`。
9. **关键路径**：不在前 8。
10. **测试**：`tb_isa_e2e.sv`。
11. **变更**：2026-10-21 立卡。

#### M13 `csr_native` — `rtl/core/csr_native.v` — 执行
2. **职责**：机器模式 CSR（mstatus/mtvec/mepc/mcause/mtval/mie/mip/mcycle/minstret）+ 异常进入/`mret`；不仲裁中断源。
4. **接口**：CSR 地址/写数据（12b/32b）、trap 相关（32b×4）、中断挂起（3b）。
5. **内部状态**：`mstatus/mie/mtvec/mscratch/mepc/mcause/mtval`（32b×7）+ `mcycle/minstret`（64b×2）。
6. **存储**：FF。
7. **面积**：419/289/0/0/0 → **不变**（CSR 语义要求 64 位计数器）。
8. **物理区域**：`R_CORE`。
9. **关键路径**：不在前 8。
10. **测试**：`tb_isa_e2e.sv`、`tb/integration/tb_halt_reset_drain.sv`。
11. **变更**：2026-10-21 立卡。

#### M14 `div` — `rtl/core/div.v` — 执行
2. **职责**：迭代式移位/减法除法器（DIV/DIVU/REM/REMU），非流水；不做握手。
3. **时钟/复位**：`clk`，同步启动。
5. **内部状态**：被除数/除数/商/余数寄存器（32b×4 + 计数）。
7. **面积**：210/172/0/0/0 → **不变**。
8. **物理区域**：`R_CORE`。
9. **关键路径**：不在前 8。
10. **测试**：`tb/unit/tb_div_adapter.sv`、`tb_isa_e2e.sv`。
11. **变更**：2026-10-21 立卡。

#### M15 `div_adapter` — `rtl/core/div_adapter.v` — 执行
2. **职责**：除法握手适配（start/done 时序、结果捕获）；不做运算。
7. **面积**：3/100/0/0/0 → **不变**。
8. **物理区域**：`R_CORE`（与 `div` 相邻）。
10. **测试**：`tb/unit/tb_div_adapter.sv`。
11. **变更**：2026-10-21 立卡。

#### M16 `retire_ctrl` — `rtl/core/retire_ctrl.v` — 退休
2. **职责**：退休/提交控制（`retire_fire`、`retire_order`、预测器训练触发、halt/trap 大门）。
5. **内部状态**：`retire_order[63:0]`、`arch_next_pc[31:0]`、`halt_pending/halted`。
7. **面积**：68/96/0/0/0 → **不变**（`retire_order` 供 ILA 关联，赛题必需）。
8. **物理区域**：`R_CORE`。
9. **关键路径**：不在前 8。
10. **测试**：`tb/integration/tb_halt_reset_drain.sv`、`tb_pipeline.sv`。
11. **变更**：2026-10-21 立卡。

#### M17 `ctrl` — `rtl/core/ctrl.v` — 控制（**网表内联进 `pangoriscv`**）
2. **职责**：流水重定向与停顿控制（四类异步事件的优先级仲裁）。
5. **内部状态**：无（组合）。
7. **面积**：无独立实例（并入 `pangoriscv` 的 2,410 LUT）。
8. **物理区域**：随 `R_CORE`。
10. **测试**：`tb_pipeline.sv`、`tb_halt_reset_drain.sv`。
11. **变更**：2026-10-21 立卡（记录"无独立实例"这一事实，避免以后按名找）。

### 5.4 访存

#### M18 `lsu_axi` — `rtl/core/lsu_axi.v` — 访存
2. **职责**：访存请求/完成的握手与字节掩码、故障上报；**不改写**访存顺序语义（本专项不碰）。
4. **接口**：`op_valid/op_ready`、`is_store/address/store_value/access_size`（32b、3b）、`done_valid/load_value/fault`（32b）。
5. **内部状态**：`state`、`address_q/value_q/size_q/pc_q/rd_q`。
7. **面积**：253/105/0/0/0 → **不变**。
8. **物理区域**：`R_CORE` 边缘，紧邻 `R_DCACHE`。
9. **关键路径**：不在前 8。
10. **测试**：`tb/unit/tb_lsu_axi.sv`、`tb/axi/tb_lsu_axi_ram.sv`。
11. **变更**：2026-10-21 立卡（**本专项禁止改动其语义**）。

#### M19 `dcache_axi` — `rtl/core/dcache_axi.v` — 存储
2. **职责**：2 路组相联 D-Cache，**32 组 × 2 路 × 8 字 = 2 KB**，写通 + 行填充，MMIO 走 bypass；不做一致性。
5. **内部状态**：`state_q`、`tag_q`、`lru`、`wdata_q/wstrb_q`、`rsp_*`。
6. **存储**：`data_mem`/`data_mem_1`/`data_mem_3`（512×32 ×3）+ `tag_mem/tag_mem_1`（64×22）。
7. **面积**：740/366/556/0/0 → **740/366/556~300**（M6 条件）。
8. **物理区域**：`R_DCACHE`（与 `R_CORE` 的 LSU 相邻；**不与 `R_ICACHE` 共用走廊**）。
9. **关键路径**：**hold 最差**：`tag_q[11] → tag_mem_1_11/ram64x1d/DI`（**+0.015 ns**）。
10. **测试**：`tb/unit/tb_dcache_axi.sv`、`run_dcache_tests.py`。
11. **变更**：2026-10-21 立卡；M6 只做归属分析（3 个阵列 vs 2 KB 容量 → 疑似副本；另有 212 primitive 差额待查）。**明确不缩 tag 位宽**（MMIO 混用，别名风险高）。

#### M20 `axi_read_engine` — `rtl/core/axi_read_engine.v` — 访存
2. **职责**：AXI4 读引擎（AR/R），支持猝发；不做地址译码。
7. **面积**：3/4/0/0/0 → **不变**。
8. **物理区域**：`R_IO`。
10. **测试**：`tb/axi/tb_axi_read_engine.sv`。
11. **变更**：2026-10-21 立卡。

#### M21 `axi_data_engine` — `rtl/core/axi_data_engine.v` — 访存
2. **职责**：AXI4 写引擎（AW/W/B），写掩码与错误响应。
7. **面积**：17/82/0/0/0 → **不变**。
8. **物理区域**：`R_IO`。
10. **测试**：`tb/axi/tb_axi_data_engine.sv`。
11. **变更**：2026-10-21 立卡。

### 5.5 存储

#### M22 `axi_ram`（program）— `rtl/perips/axi_ram.v` — 存储
2. **职责**：0x0000_0000 的 16 KB 程序存储器（`WRITE_ENABLE=0`，只读），带 `$readmemh` 初始化。
6. **存储**：`mem[4096][31:0]` → **4 × `GTP_DRM36K_E1`（BRAM/ROM）**，已是最优。
7. **面积**：150/143/0/4/0 → **不变**。
8. **物理区域**：`R_MEM`（外圈；BRAM 走专用布线）。
10. **测试**：`tb/axi/tb_axi_ram.sv`、`tb/axi/tb_axi_memory.sv`。
11. **变更**：2026-10-21 立卡（**它是 M2 的可行性依据**：同文件同流程已能推断 BRAM）。

#### M23 `axi_ram`（data）— `rtl/perips/axi_ram.v` — 存储（**M2 目标**）
2. **职责**：0x1000_0000 的 16 KB 数据 RAM（可写、字节掩码）。
6. **存储**：`mem[4096][31:0]` 被推断成 **4 × 4096×8 的 LUTRAM（2,048 个 `GTP_RAM64X1DP`）** ← 本专项最大热点。
7. **面积**：1,022/212/**2,048**/0/0 → **1,022/212/0（DRM 4→8）**。
8. **物理区域**：`R_MEM`（M2 之后走 BRAM 专用布线，可放外圈）。
9. **关键路径**：**hold 前 6 之一**：`data_ram/aw_addr[7] → mem_3_50_5/ram64x1d/WADDR[5]`（M2 会同时缓解这条路径）。
10. **测试**：`tb/axi/tb_axi_ram.sv`、`run_ram_tests.py`（20/20）。
11. **变更**：2026-10-21 立卡；M2 加 `syn_ramstyle="block_ram"`，必要时 `no_rw_check`。

### 5.6 总线

#### M24 `axi_interconnect` — `rtl/bus/axi_interconnect.v` — 总线
2. **职责**：1 主/多从的地址译码、轮询仲裁、ID 跟踪、错误从站兜底；不做数据宽度转换。
3. **时钟/复位**：`clk`/`rst_n` 单域。
4. **接口**：两套 AXI4 主口（`m_*`）与 7~8 套从口（`s_*`）；地址/数据 32b、len 8b、id 4b。
5. **内部状态**：`state`、`owner/target/rr/addr/id/len/size/burst`、`beats_left/write_left`。
7. **面积**：764/119/0/0/2 → **随 M1 略缩**（从机 8→7）。
8. **物理区域**：`R_IO`（在核心区与 `R_MEM` 之间）。
9. **关键路径**：不在前 8。
10. **测试**：`tb/axi/tb_axi_interconnect.sv`。
11. **变更**：2026-10-21 立卡。

#### M25 `axi_error_slave` — `rtl/bus/axi_error_slave.v` — 总线
2. **职责**：未映射地址的 DECERR 应答（fail-closed）；不做合法地址转发。
7. **面积**：40/26/0/0/0 → **不变**。
8. **物理区域**：`R_IO`。
10. **测试**：`tb/axi/tb_axi_interconnect.sv`（间接）。
11. **变更**：2026-10-21 立卡。

### 5.7 外设

#### M26 `axi_reg_slave` × 6 — `rtl/perips/axi_reg_slave.v` — 外设
2. **职责**：外设寄存器桥（地址窗口校验、字节掩码、读写事件）；不做业务逻辑。
5. **内部状态**：AW/W 暂存、`rvalid/bvalid`、`rleft/windex` 等。
7. **面积**：6 个实例合计 ≈1,000 LUT / ≈800 FF；**其中最大的 594 LUT 是 `perf_regs` 的从机，随 M1 消失**。
8. **物理区域**：`R_IO`（每个实例贴着自己的外设）。
10. **测试**：各外设 tb 间接覆盖。
11. **变更**：2026-10-21 立卡。

#### M27 `axi_uart` — `rtl/perips/axi_uart.v` — 外设
2. **职责**：115200 8N1 收发（27 MHz，分频 234），byte 宽寄存器窗；**是 CoreMark 的输出通道，绝不能动语义**。
5. **内部状态**：`ctrl_q/stat_q/baud_q/rxbyte_q`、`ph_q/bit_q/tick_q/byte_q/push_q/line_q`。
7. **面积**：134/159/0/0/0 → **不变**。
8. **物理区域**：`R_IO` 边缘（引脚 C24）。
10. **测试**：`tb/integration/tb_uart_tx_smoke.sv`、`tb_coremark_uart.sv`、板上 `flash_and_capture.ps1`。
11. **变更**：2026-10-21 立卡。

#### M28 `axi_timer` — `rtl/perips/axi_timer.v` — 外设
2. **职责**：27 MHz 计数 + 比较中断。
7. **面积**：85/96/0/0/0 → **不变**。
8. **物理区域**：`R_IO`。
10. **测试**：`tb_isa_e2e.sv`（定时器中断场景）。
11. **变更**：2026-10-21 立卡。

#### M29 `axi_spi` — `rtl/perips/axi_spi.v` — 外设
2. **职责**：SPI 主机（字节宽寄存器窗）。
7. **面积**：72/89/0/0/0 → **不变**。
8. **物理区域**：`R_IO`。
10. **测试**：无专门 tb（间接覆盖）。
11. **变更**：2026-10-21 立卡。

#### M30 `axi_gpio` — `rtl/perips/axi_gpio.v` — 外设
2. **职责**：两路双向引脚（板级 KEY0 / LED）。
7. **面积**：35/68/0/0/0 → **不变**。
8. **物理区域**：`R_IO` 边缘。
10. **测试**：`tb/integration/tb_gpio_trace.sv`、`tb_led_walk.sv`。
11. **变更**：2026-10-21 立卡。

#### M31 `irq_ctrl` — `rtl/perips/irq_ctrl.v` — 外设
2. **职责**：软件/定时器/外部中断源汇聚到 CSR。
7. **面积**：9/7/0/0/0 → **不变**。
8. **物理区域**：`R_IO`。
10. **测试**：`tb_halt_reset_drain.sv`、`tb_isa_e2e.sv`。
11. **变更**：2026-10-21 立卡。

#### M32 `perf_regs` — `rtl/perips/perf_regs.v` — 仪表（**M1 移除**）
2. **职责**：周期/退休/取指等待/访存等待/Cache 缺失/误预测 计数器，窗口 0x6000_2000；**只用于分析，不参与功能**。
5. **内部状态**：6~8 个 64 位计数器 + 快照寄存器。
7. **面积**：850/1,665/0/0/0（+ 从机 594 LUT）→ **0/0/0/0/0**。
8. **物理区域**：交付构建中**不存在**。
10. **测试**：`tb/unit/tb_perf_regs.sv`、`run_perf_tests.py`（**仅 PERF 开的构建**）。
11. **变更**：2026-10-21 立卡；M1 关 `PERF_ENABLE`（交付），分析构建保持开启。

### 5.8 SoC 与封装

#### M33 `pangoriscv` — `rtl/core/pangoriscv.v` — 胶合
2. **职责**：核心顶层：流水级互联、旁路网络、发射/退休判定（含被内联的 `ctrl.v`）；不含 Cache/总线。
7. **面积**：2,410/1/0/0/0 → **不变**（旁路网络是双发射正确性核心，本专项不碰）。
8. **物理区域**：`R_CORE` 主体。
9. **关键路径**：其子路径 `u_id_ex → u_regs` 是 setup 前 3。
10. **测试**：`tb_pipeline.sv`、`tb_isa_e2e.sv`。
11. **变更**：2026-10-21 立卡（登记为"未来 LUT 下探的唯一大目标"，需单独立项）。

#### M34 `pangoriscv_axi_top` — `rtl/core/pangoriscv_axi_top.v` — 胶合
2. **职责**：核心 + 取指/访存引擎（或 Cache）的集成；`perf_*` 端口在 `PERF_ENABLE` 下才存在。
7. **面积**：6/0/0/0/0 → **随 M1 去 `perf_*` 端口**。
8. **物理区域**：`R_CORE` 与 `R_IO` 的交界。
11. **变更**：2026-10-21 立卡。

#### M35 `pangoriscv_axi_soc` — `rtl/soc/pangoriscv_axi_soc.v` — 胶合
2. **职责**：从机表（8 或 7 个）、中断汇聚、`PERF_ENABLE` 条件编译、复位同步。
7. **面积**：5/0/0/0/0 → **随 M1 从机 8→7**。
8. **物理区域**：`R_IO`。
11. **变更**：2026-10-21 立卡。

#### M36 `pangoriscv_top` — `rtl/soc/pangoriscv_top.v` — 封装
2. **职责**：FPGA 顶层：时钟/复位同步、引脚、BRAM 初始化参数、`obs_*` ILA 观测网。
5. **内部状态**：`reset_sync[1:0]`、`obs_retire_count[31:0]`、`obs_trap_count[31:0]`。
7. **面积**：138/66/0/0/0 → **不变**（`obs_*` 供赛题 ILA 证据，保留）。
8. **物理区域**：引脚侧。
9. **关键路径**：`reset_sync[0] → led[5]/led[7]` 出现在前 8（hold 类）。
11. **变更**：2026-10-21 立卡。

### 5.9 参数与头文件

#### M37 `defines.v` — `rtl/core/defines.v`
2. **职责**：核内共享常量唯一来源：`RegAddrBus`（4:0）、`RegBus`（31:0）、`DoubleRegBus`（63:0）、`RegNum`（32）等。
7. **面积影响**：`RegNum` 决定寄存器堆大小；改它等于改 ISA 可见状态 → **本专项不动**。
11. **变更**：2026-10-21 立卡。

#### M38 `axi_defs.vh` / `native_axi_macros.vh` — `rtl/core/`
2. **职责**：AXI4 端口宏与位宽定义；`AXI_SLAVE_PORTS` / `AXI_MASTER_PORTS` / 连接宏。
7. **面积影响**：改位宽会改整条总线 → 本专项只在 M1（去 `perf_*`）时触及连接宏的使用方，**不改宏本身**。
11. **变更**：2026-10-21 立卡。

#### M39 `soc_config.vh` — `rtl/core/soc_config.vh`
2. **职责**：三个构建开关 `CACHE_ENABLE` / `PREDICT_ENABLE` / `PERF_ENABLE`。
7. **面积影响**：`PERF_ENABLE` 约 3,100 站点（M1）；其余两个本专项不动。
11. **变更**：2026-10-21 立卡；**仓库默认保持三开**（分析构建），交付构建在独立 staging 目录关闭 PERF。

---

## 6. 物理区域与放置规则（P7 执行）

### 6.1 区域草案

| Region | 放什么 | 依据 |
|---|---|---|
| `R_FETCH` | `pc_reg`、`branch_predictor`、`ifu_axi` | 与 `R_ICACHE` 之间是 **64 b/拍** 取指总线 |
| `R_ICACHE` | `icache_axi` 的 `even_mem/odd_mem` 阵列 | LUTRAM 阵列需成片、就近 |
| `R_CORE` | `id`、`id_alu`、`regs`、`if_id`、`id_ex`、`pipe_slot`、`ex`、`ex_alu`、`csr_native`、`retire_ctrl`、`pangoriscv` | `regs` 是 4×32 b 读 + 2×32 b 写/拍，必须居中 |
| `R_DCACHE` | `dcache_axi` 的 `data_mem` 阵列 | 与 `lsu_axi` 相邻，**不与 `R_ICACHE` 共走廊** |
| `R_MEM` | `program_ram`（DRM）、`data_ram`（M2 后 DRM） | BRAM 走专用布线，可放外圈 |
| `R_IO` | `axi_interconnect`、`axi_error_slave`、`axi_reg_slave`×6、`axi_uart/timer/spi/gpio`、`irq_ctrl`、`axi_*_engine`、`lsu_axi` 外沿 | 与引脚/BRAM 相邻 |

### 6.2 三条放置规则

1. **最宽最频繁的总线不跨区**：`R_FETCH↔R_ICACHE`（64 b/拍）、`R_CORE` 内的 regfile（6×32 b/拍）。
2. **两个 LUTRAM 阵列分到两侧**：`R_ICACHE` 与 `R_DCACHE` 不共用同一条局部走线走廊。
3. **BRAM 放外圈**：27 MHz 周期 37.04 ns、setup 余量 +14.75 ns，拉长几 ns 完全吃得下；拥塞才是致命的。

### 6.3 实现方式（按可行性）

先试 PCF 文本约束（`def_region` + `def_inst_region`，实例路径以网表为准：
`pangoriscv_top/soc/core/cpu/instruction_cache`、`.../data_cache`、`.../u_regs`、`soc/data_ram`、`soc/program_ram`）；
若 PCF 被接受但不生效 → 用 PCE GUI 画区域并导出 PCF。

---

## 7. 现状关键路径（`4kb_3.423/report_timing.rtr` 前 8 条）

| # | 起点 | 终点 | slack | 类型 |
|---|---|---|---:|---|
| 1 | `u_id_ex/slot/data_q[303]` | `u_id_ex_h/slot/data_q[167]` | **14.750** | setup（最差） |
| 2 | `u_id_ex/slot/data_q[303]` | `u_id_ex_h/slot/data_q[141]` | 15.018 | setup |
| 3 | `u_id_ex/slot/data_q[303]` | `u_regs/rfile[3][5]` | 15.018 | setup |
| 4 | `data_cache/tag_q[11]` | `tag_mem_1_11/ram64x1d/DI` | **0.015** | **hold（最差）** |
| 5 | `instruction_cache/way_q` | `odd_mem_1_3_11/ram64x1d/WADDR[2]` | — | hold |
| 6 | `data_ram/aw_addr[7]` | `mem_3_50_5/ram64x1d/WADDR[5]` | — | hold |
| 7-8 | `reset_sync[0]` | `led[5]` / `led[7]` | — | hold |

**结论**：hold 的两个紧点都在 **LUTRAM 写端口**（`data_cache`、`instruction_cache`、`data_ram`）。
→ M2（数据 RAM 进 BRAM）会**顺带消掉第 6 条**；
→ 若 M5/M6 减少阵列副本，写入扇出变小，hold 也有机会变好。

---

## 8. 必须跟着改的资产（否则会"假红/假绿"）

| 资产 | 触发时机 | 要改什么 |
|---|---|---|
| `tb/unit/tb_branch_predictor.sv` | M3 | tag/target 位宽跟随参数（若写死 25/32） |
| `tb/unit/tb_ifu_axi.sv`、`tb/axi/tb_ifu_axi_engine.sv` | M4a | 队列深度的指针/计数假设跟随 `AW` |
| `tb/unit/tb_icache_axi.sv` | M5 | 若删副本，读端口/延迟断言复核 |
| `tb/unit/tb_dcache_axi.sv` | M6 | 同上 |
| `tb/integration/tb_coremark_uart.sv` | M1 | 确认**不探测** `soc.perf_inst`（PERF 关的构建会编译失败） |
| `tools/set_switches.py` | M1 | 支持按名开关（`PERF_ENABLE=off`） |
| `sim/run_perf_tests.py` | M1 | 标注"仅 PERF 开的构建" |
| `platform/pango_native/pango_native.pcf` | P7 | 写入 region 约束 |
| `bitstream/README.md` | 每次定版 | 位流 SHA 与口径 |

**先改测试台、再改 RTL**（教训 §4.11 的顺序）。

---

## 9. 变更流程

1. **一模块一提交**：`module: <名> ΔLUT/ΔFF/ΔLUTRAM`（例：`module: branch_predictor −100/−1152/0`）。
2. **提交前**：`check_area_budget.py --mode baseline`（防漂移）→ 改完后 `--mode budget`（防超预算）。
3. **每次改动四道门**：20 迭代 A/B（CRC 逐项相同）→ 单元/ISA/halt-reset/RAM 全绿 → PDS（`All Constraints Met`、hold>0）→ 定版时上板。
4. **预算超限即回退**，不留半成品（教训 §4.16）。
5. **本文件同步更新**：模块卡的"面积"与"变更记录"两栏必须反映最后一次改动的实测值。

---

## 10. 数据来源与复现命令

```powershell
# 1) 总量（验收口径）
Get-Content firmware\code\build\code_ic4k\build\pango_native\multiseed_summary.csv |
  Select-String '^Used,'

# 2) 逐模块原语（本文件 §3.2 的来源）
#    脚本见 tools/check_area_budget.py --netlist <vm> 的实现；vm 路径：
#    firmware\code\build\<stage>\build\pango_native\synthesize\pangoriscv_top_syn.vm

# 3) 存储阵列物理归属
Get-Content firmware\code\build\code_ic4k\build\pango_native\synthesize\apm_drm_lutram_utilization.log

# 4) 时序路径
Select-String -Path evidence\records\optimization\4kb_3.423\report_timing.rtr -Pattern 'Startpoint|Endpoint|Slack'
```

---

## 11. 待查与待办

| 编号 | 事项 | 归属 | 状态 |
|---|---|---|---|
| M1 | 关 `PERF_ENABLE`（交付）+ 按名开关 | `perf_regs`/`soc_config.vh` | **完成 2026-10-21**：LUT −1,527 / FF −1,769（`area-M1/measurement.md`） |
| M2 | 数据 RAM 强制 BRAM | `axi_ram.v` | **受阻（2026-10-21）**：`syn_ramstyle` 被翻译成 `PAP_RAM_STYLE` 后无效果；`block_ram`、`block_ram,no_rw_check`、显式字节写三次都试过，LUTRAM 仍 3,628 / DRM 仍 4。RTL 已回退。诊断与后续方案见 `evidence/records/optimization/area-M2/measurement.md` |
| M3 | BTB 位宽按 `PGM_BYTES` 派生 | `branch_predictor.v` | **完成 2026-10-21**：LUT −1,309 / FF −1,152（`area-M3/measurement.md`） |
| M4b/4a | 取指队列去 `q_pred_hi` / `DEPTH` 8 | `ifu_axi.v` | 待执行 |
| M5 | I-Cache 3,071 FF 归属 + 副本判定 | `icache_axi.v` | 待分析 |
| M6 | D-Cache 3 阵列归属 + **556 vs 768 的 212 primitive 差额** | `dcache_axi.v` | 待分析 |
| M7 | 4R2W 寄存器堆能否 LUTRAM/BRAM 化 | `regs.v` | 只调研 |
| M8 | 304 位 payload 恒零字段 | `if_pipe`/`pipe_slot` | 仅评估 |
| — | `icache_axi.v` 头注释 "32 sets" 过时（实际 64 组） | `icache_axi.v` | 随 M5 修正 |

---

## 12. 构建 profile：交付 vs 分析

本专项引入两种 profile，**必须分开，不许混用**：

| profile | 开关 | 用途 | 谁生成 |
|---|---|---|---|
| **交付**（delivery） | `PERF_ENABLE=off`；`CACHE_ENABLE`/`PREDICT_ENABLE` 保持 on | 出位流、上板报分 | `set_switches.py PERF_ENABLE=off` → 构建 → `PERF_ENABLE=on` 还原 |
| **分析**（analysis） | 三开关全 on | 仿真、停顿/缺失统计、ILA 波形 | 仓库默认状态 |

纪律：

1. **仓库默认永远是三开**（`soc_config.vh` 不改死）；交付构建在独立 staging 目录里关 PERF，构建后立刻还原，
   并 `git status` 确认 `soc_config.vh` 与 HEAD 一致（教训 §4.12）。
2. 两个 profile 的 `device_map` 必须分别留证据（本专项的 M1 就是这样测的）。
3. **任何 CoreMark 对比必须在同一 profile 内做**：交付 vs 交付、分析 vs 分析。
   拿"PERF off 的交付位流"和"PERF on 的仿真"比 ticks 是错的。
4. 交付 profile 少一层 AXI 从机（0x6000_2000 消失），固件不得引用该窗口。

命令：

```powershell
cd firmware\code
python tools\set_switches.py status
python tools\set_switches.py PERF_ENABLE=off        # 交付/profile A
# ... 构建 ...
python tools\set_switches.py PERF_ENABLE=on         # 立即还原
python tools\set_switches.py status
```
