# 性能分析文档 —— pangoriscv（RV32IM 2 发射）

> 对应赛题评分项："CoreMark 分数与周期数换算、IPC、瓶颈定位、优化前后 A/B 对比与原因"。
> 本文件所有数字都标了口径与来源；仿真值与上板值分开标注，不互相替换。

---

## 1. 摘要（同一份位流，三项指标）

实现：`bitstream/pangoriscv_board48_i2700_5p245.sbit`
SHA256 `331273cb7a9d19be167f4f95183eb3231302352e7d2ba31ac59b5566636c856e`

| 指标 | 值 | 口径 |
|---|---|---|
| CoreMark/MHz | **5.2447** | 上板：2700 × 10⁶ / 514,808,895 |
| 最高时钟频率 | **48 MHz** | 上板：约束 48 MHz、PLL 27×64/36=48.000 MHz；`report_timing` **All Constraints Met**（setup WNS +0.252 / 0 失败端点，hold WHS +0.021 / 0 失败端点），布线后 Estimated 48.5885 MHz |
| CoreMark/kLUT | **0.3066** | 5.2447 / 17.105 |
| 面积 | LUT 17,105 / FF 8,693 / LUTRAM 2,274 / DRM 12 | `device_map` |
| 运行时间 | 10.73 s（≥10 s 合规） | 514,808,895 / 48 MHz |

上板原始输出（`evidence/records/optimization/p30-dcache-path/board_p35a.txt`）：

```
Total ticks : 514808895      Iterations : 2700
seedcrc 0xe9f5  crclist 0xe714  crcmatrix 0x1fd7  crcstate 0x8e3a  crcfinal 0xa14c
Correct operation validated.
```

---

## 2. 口径（先定义，再给数）

| 量 | 定义 | 常见误用 |
|---|---|---|
| 分数 | `Iterations × 10⁶ / Total ticks`（**固件自报的 Total ticks**）| 用 runner 打印的 `cycles/iter` 代替——它含约 190 万拍启动期，20 迭代下会把分数低估 50%（mistakes-log §58）|
| IPC（整跑）| `retires / cycles` | 含启动期的 UART 轮询，低估真实 IPC |
| **IPC（计分窗口）** | 测试台 `SCORE_WINDOW` 行，**只统计与 `Total ticks` 同一区间** | —— 本文优先用这个 |
| 频率 | 必须 `report_timing` 通过（setup/hold 无失败端点），并注明"约束值 / 布线后值" | 用摆放阶段的 WNS 当结论（§54）|
| 每迭代拍数 | `Total ticks / Iterations`（仿真 20 迭代）| —— |

---

## 3. 周期去哪了

### 3.1 计分窗口总账（`SCORE_WINDOW`，20 迭代，交付 RTL）

```
cycles=3,830,610   retires=5,782,458   no_retire=531,147
```

| 量 | 每迭代 | 说明 |
|---|---|---|
| 周期 | 191,530 | |
| 退休指令 | 289,123 | |
| IPC | **1.5095** | 2 发射理论上限 2.0 ⇒ 已用 75.5% |
| **死周期**（0 条退休）| **26,557（13.9%）** | 依赖/访存/取指停顿 |
| 非死周期利用率 | **1.7525 / 2.0（87.6%）** | 2 发射几乎无余量 |

### 3.2 配对失败原因（`PAIRGAP`，`--define RV32_DEBUG`，全程 5,693,904 拍）

```
pair=2,896,669  no_pair=506,441  l1_notok=34,472(mem=0)
l0_alone=22,840  pkt_lduse=404,502  fault=0  nostall=1,524,574
```

| 桶 | 每迭代 | 含义 | 能否消除 |
|---|---|---|---|
| `pair` | 144,833 | 成功配对 | — |
| `pkt_lduse` | 20,225 | lane0 是 load，lane1 依赖它 ⇒ 不许配对 | 需双端口 D$ 或更宽发射 |
| `no_pair` | 25,322 | 取指只送来单条（奇地址）| 需 96 bit 取指窗口 |
| `l0_alone` | 1,142 | 控制指令独占（branch 非预测目标 / `jalr`）| 放开 `jalr` 实测只值 417 拍/迭代 |
| `nostall` | **76,229** | 前端没有指令可发（I$ 缺失/队列空）| **加宽发射无用** |

⇒ **最大的单项是不可发射的 76,229 拍**，其次是 `no_pair` 与 `pkt_lduse`。
这就是"2 发射到头了"的直接证据。

### 3.3 数据侧事件（`DCDBG`，20 迭代）

```
rd_new=720,813  hit=596,992  miss=123,821  wr_new=143,921
```

| 量 | 每迭代 | 用途 |
|---|---|---|
| 读请求 | 36,041 | load 总量 |
| 读命中 | **29,850** | 决定了"给 D$ 加一拍"至少 +29,850 拍/迭代 |
| 读缺失 | 6,191 | 其中约一半是同一行的重复呈现，真实缺失 ≈3,100 |
| 写请求 | 7,196 | |

---

## 4. 关键路径的分段账（布线后 20.581 ns）

`report_timing` 最差路径：`rr_inst[22] → data_mem_b0_12_1/ram64x1d/WE`。

| 段 | 耗时 | 占比 | 内容 |
|---|---|---|---|
| ① 指令位 → 操作数寄存器 | **7.33 ns** | 35.6% | 寄存器堆读（32:1）+ 旁路 mux；其中 `rr_inst[21]` 单根 fanout=136 网 2.67 ns |
| ② ALU | 1.39 ns | 6.8% | 32 位进位链 |
| ③ ALU → AGU → LSU 地址 | 4.14 ns | 20.1% | 地址 mux + fanout 110/151 的地址网 |
| ④ D$ tag 比较 → hit | 1.87 ns | 9.1% | tag 阵列读 + 21 位比较 |
| ⑤ 阵列写使能扇出 | 3.25 ns | 15.8% | 一根 fanout≈144 的 WE 网 |

**特征**：Logic 3.53 ns / Route 16.95 ns（**82.8% 是走线**）。
这不是"逻辑太深"，而是"一段里塞得太多"——ID + 寄存器读 + ALU + AGU + D$ tag 全在一拍。
**5.24 这个分数正是"长时钟周期"换来的**：L1 命中当拍返回、重定向只要一次。

---

## 5. 优化 A/B 全史（每项都是实测）

### 5.1 已进入交付的改动

| # | 改动 | Δ Total ticks（20 迭代）| 分数效果 | 频率效果 |
|---|---|---|---|---|
| 1 | `data_ram` 从分布式 RAM 进块 RAM | **−2,048 LUTRAM / −2,189 LUT**，ticks 不变 | 不变 | **使布线首次收敛**（18,181 LUT 永不收敛 → 15,992 LUT 212 轮布通）|
| 2 | BTB 32 → 64 | −57,688（3,833,976 → 3,776,288）| 5.2165 → 5.2963 | 略降（面积 +800 LUT）|
| 3 | D$ 2 KB → 4 KB | −61,406（→3,714,882）| → 5.3834 | 读 mux 深一级 |
| 4 | 重定向切断（`fetch_ptr` 去掉 `redirect_valid?redirect_pc:`）| **+95,818**（→3,810,700）| 5.3834 → 5.2483 | **25.43 → 20.61 ns** |
| 5 | D$ 阵列按字节通道拆分 | **0**（逐位不变）| 不变 | 50 MHz 处 20.613 → 20.135 ns，失败端点 417 → 3 |
| 6 | LRU 替换位延后一拍 | **0**（逐位不变）| 不变 | 切断 `m_inst→AGU→tag→lru_mem` 整锥 |

### 5.2 被数据否掉的改动（不要再试）

| 改动 | 实测 | 结论 |
|---|---|---|
| `-seed` / `-dc_duplication` / `-refineplacement_cluster` / `-logic_optimize_enable` / `-slack_prior_in_global_router` / `-max_ctrl_chain_length` / `-place_worst_slack` / `-fix_hold_violation*` | 摆放与布线**逐位相同** | 全部是静默 no-op（§55/§64）|
| floorplan（横带/竖带/紧凑方块）| −0.6 ~ −2.7 ns | 设计占区域网格 33%，无压缩空间（§56）|
| 把异常推送（`local_push`）寄存器化 | ticks 不变（真机验证前曾误判）| 收益只在路径上 |
| **把 D$ 读改成寄存读（BRAM）** | 需 **+29,850 拍/迭代** | 预算只有 1,772 ⇒ 差 17 倍，永久关闭 |
| 3 发射 | 前沿 ~97 MHz，120 MHz 需 2 级 ⇒ 分数 4.26 | 见 `plan-v15 §8` |

### 5.3 三个"最后杠杆"的实测值

| 杠杆 | Δ 拍/迭代 | 备注 |
|---|---|---|
| `-O3` 代替 `-O2` | −425（0.22%）| 热循环已到编译器极限 |
| `jalr` 允许与 lane1 配对 | −417 | 误预测同时 −89/迭代 |
| BTB 64→128 | −515 | 要 +800 LUT |
| 合计 | **−1,357** | 仍小于"最便宜的一级流水线"7,196 |

---

## 6. 频点扫描（布线后实测，U 形曲线）

| 约束 | 布线后路径 | 收敛 | 判定 |
|---|---|---|---|
| 45 MHz | 22.943 ns | 0 @211 | ✗ 差 0.72 |
| **48 MHz** | **20.581 ns** | **0 @151** | **✓ 交付（WNS +0.252）** |
| 50 MHz（3 种网表）| 20.135 / 21.633 / 21.189 | 0 @250~371 | ✗ 最好差 0.135 |
| 52 MHz | 22.460 ns | 0 @311 | ✗ 差 3.23 |
| 55 MHz | — | 停 1,921@182 | ✗ 布不通 |
| 60 MHz | — | 停 7,359@29 | ✗ 布不通 |

**越过 50 MHz 后限制从"时序"变成"拥塞"**：55/60 MHz 的摆放估计（16.98 / 15.59 ns）已优于
各自需要的周期，但线布不完——更紧的约束把逻辑聚得过密。

---

## 7. 瓶颈结论

1. **单拍逻辑量过大**：`指令→寄存器堆读→ALU→AGU→D$ tag→阵列写使能` 在同一拍，
   其中 82.8% 是走线。想提频必须切流水。
2. **切流水的预算不存在**：5.2 对应 `Total ticks ≤ 3,846,154`（每迭代 ≤192,307 拍），
   当前 190,535，**余量 1,772 拍**；而能压到 8.3 ns 的每一刀都落在 load 通路上，
   单价 ≈38,355 拍（误预测 +2,314 与 load-use +36,041）⇒ 差 21 倍。
3. **加宽发射也不够**：3 发射（非死周期 2.2 条/拍）→ 157,977 拍 → 分数 6.33，
   能付**一级**（→ ~97 MHz），付不了**两级**（→ 4.26）。
4. **面积与频率互相封死**：D$ 退回 2 KB 可省 ~1.1k LUT（利于密度）但要 +3,070 拍，
   而全部剩余杠杆只有 1,357 拍。

⇒ 在"CoreMark/MHz ≥ 5.2"这一约束下，本核族的频率前沿是 **48~52 MHz**；
   本实现取 48 MHz（唯一同时满足"布通 + 满足自身周期 + hold 干净"的点）。

---

## 8. 复现方法

```bash
# 1) 20 迭代功能/分数仿真（等价性 + Total ticks）
python tools/run_coremark_sim.py --image build/native_software/coremark/performance/sim20_O2 --tag chk

# 2) 计数分解（配对失败原因 / D$ 访问次数）
python tools/run_coremark_sim.py --image .../sim20_O2 --tag gap  --define RV32_DEBUG
python tools/run_coremark_sim.py --image .../sim20_O2 --tag cnt  --define DC_DBG

# 3) ISA 端到端（应 20/21，case 21 基线即红）
python tools/run_isa_e2e.py --modelsim ... --toolchain-bin ... --prefix riscv-none-elf- --extra-flag=-march=rv32im_zicsr

# 4) 重新实现（约束=PLL=48 MHz 由 pll_check() 强制一致）
python tools/run_pds_flow.py --tag NEW --freq 48 --mode full --seed 7 --image .../hw_i2700_48 \
       --pnr-extra "-plc_decongestion 2 -dispose_dram_prior TRUE -share_router_control_signal TRUE"
```

---

## 9. 待补：真机计数器（唯一还缺的一行）

片上 `perf_regs`（`0x60002000`，`PERF_ENABLE` 已开）可输出：

```
P <cycle> <instret> <if_wait> <lsu_wait> <i_miss> <d_miss> <ret_cf> <mispred>
```

交付镜像未编 `-DPERF_DUMP`；已备好分析镜像 `hw_i2700_48_prof` 与位流
`build/P44a/generate_bitstream/pangoriscv_top.sbit`（48 MHz）。
**2026-10-23 14:20 / 14:23 / 14:26 三次烧录均报
`JtagServer-0306: No devices detected while scanning the JTAG chain` 且串口零输出
⇒ 目标板未上电**。取数命令见 `evidence/records/optimization/p44-onboard-perf/README.md`；
拿到后填入本节即可完成"真机瓶颈复核"。
