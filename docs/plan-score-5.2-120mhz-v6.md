# 5.2 CoreMark/MHz + 120 MHz 执行计划 v6（访存为主，一步一测）

> 起点 = R5 已落地（`cb9b281`，tag `p9i`）。v5 的结论不再重复，本文件只回答两件事：
> **剩下 672,200 个 tick 从哪来**、**16.09 ns 的路径怎么砍到 8.33 ns**。
> 每条改动仍然只碰一个模块，改完立刻量，量不过就回退。

## 1. 起点实测（同一份 RTL、同一镜像 `sim20_o2`、20 迭代）

| 项 | 值 | 来源 |
|---|---:|---|
| `Total ticks` | 4,518,354 | `p9i` 仿真 |
| CoreMark/MHz | **4.427** | `20 / ticks × 1e6` |
| `cycles` / `retires` / IPC | 6,403,281 / 7,027,447 / 1.0975 | 同上 |
| 计分窗 | `cycles=4,539,252` `retires=5,782,458` `no_retire=871,904` | `SCORE_WINDOW` |
| 计分窗 IPC | 1.2739（上限 2.0） | 5,782,458 / 4,539,252 |
| `mem_wait` | 1,268,139 | `STALLDBG` |
| 五项 CRC | 全对（`0x4983`） | 同上 |
| LUT / FF / LUTRAM / DRM / APM | 17,369 / 7,576 / 3,684 / 8 / 6 | `build/p9synth126` |

## 2. 两个缺口，都换算成同一把尺子

```
分数：ticks 4,518,354 → 3,846,154（5.2）      ⇒ −672,200 tick
      相当于把 no_retire 从 871,904 压到 199,704（−77%）
频率：路径 16.09 ns（126 MHz 综合 WNS −8.156）→ 8.33 ns（120 MHz）  ⇒ −7.76 ns
```

**先做分数，再做频率**，理由和 v5 一样：分数是主指标，且访存改动会改变时序。
频率阶段只用 100 MHz 约束取路径表（教训 §37：126 MHz 约束跑不完布线）。

## 3. 已经量到的 mem_wait 三分（`p9i`，已扣掉"本来就该等的"）

| 项 | 周期 | 每次 | 含义 |
|---|---:|---:|---|
| `rdwait` | 584,037 | 4.60 | 自己那次 refill 在等 AXI（126,908 次 refill） |
| `request_load` | 499,707 | 3.94 | load 被 cache 拒收（`req_ready=0`） |
| `request_store` | 185,526 | — | store 被拒收（队列满） |
| 合计 | 1,268,139 | | 与 `STALLDBG mem_wait` 相符 |

配套：`DCACHE_PATH drain=2,079,603`（全程序 32%）、`refills=126,908`、
`axi_d_aw=410,588`（一次 store 一次 AXI 写，写通）、`axi_d_ar=126,937`。
`ST_WR_DRAIN` 每 store 5.06 拍 ⇒ **写路径吞吐 410,588 × 5 = 2.05 M 拍**，
这是 `dcache_axi` 读写共用 `state_q` 的直接后果。

## 4. 先量后改：D1 诊断（不改 RTL，只加测试台探针）

上面三分还不够决定"改哪一刀"，因为 `request_load` 的 500 k 到底是
"被 drain 挡住"还是"被另一个 miss 挡住"，读数一样。所以先跑一次纯探针仿真：

| 探针 | 回答的问题 |
|---|---|
| 拒收时的 `data_cache.state_q` 直方图（load / store 分开） | 500 k 里有多少是 drain 造成 |
| store 命中/未命中计数 | 写回（write-back）值不值得做 |
| 一次 miss 的 CPU 侧代价直方图（accept→rsp） | early-restart 能省几拍 |
| refill 期间同 line 再访问的次数 | in-flight 转发值不值得做 |

判据（写死在计划里，避免"改完再想为什么"）：
- 若 `request_load` 中 ≥ 60% 落在 `ST_WR_DRAIN/ST_WR_POST` ⇒ 打写路径（R6 走 4.2a）；
- 若 refill 平均 CPU 代价 ≥ 8 拍且同 line 追赶 ≥ 20% ⇒ early-restart + 转发（4.2b）；
- 若 store 命中率 ≥ 60% ⇒ write-back 有明确收益（4.2c）。

## 5. 模块清单（一次提交只动一个模块）

| 序 | 模块 | 改动 | 目标 | 预计 | 面积 |
|---|---|---|---|---|---|
| **R6** | `dcache_axi` | **写路径吞吐**：读状态机与写 drain 分离，且一拍接纳一个 store（写引擎改为 AW/W 流水 + 按 id 收 B），把 5.06 拍/store 压到 1–2 拍 | 分数 | −0.5 ~ −1.0 M 周期 | FF +~60，LUT 中性 |
| **R7** | `dcache_axi` | **早响应 refill**：AR 从被请求的那个字开始（线内旋转），第一个 beat 到达就回 CPU，其余 7 拍后台填；fill 期间同 line 的访问从已到的 beat 转发 | 分数 | −0.3 ~ −0.6 M 周期 | FF +~40 |
| **R8** | `perips/axi_ram` | 数据 RAM 从"IDLE→WAIT→DRAIN→RESP"四态改成写后可连续接纳，去掉每写的固定 2 拍气泡（仅在 R6 之后仍是瓶颈才做） | 分数 | −0.2 M 周期 | 0 |
| **R9** | `rv32_top` | 时序：寄存器堆读搬到 RD 级 / 误预测比较寄存一拍 / lane1 ALU 挪到 M1（按 100 MHz 路径表选，不按顺序全做） | 频率 | 每条 −1.5 ~ −3 ns | +~260 FF |

顺序硬性：**R6 → R7 →（R8）→ 分数验收 → R9**。
R6/R7 都是 `dcache_axi`，但**分两次提交、两次测量**，否则分不清谁起作用。

## 6. 面积纪律

- 起点 17,369 / 7,576 / 3,684，门禁 `Δ(LUT+FF+LUTRAM) ≤ 0`，
  收尾跑 `check_area_budget.py`。
- 缓存阵列已经是 LUTRAM 映射（2 KB = 3,684 LUTRAM 的大头），
  **不许靠扩大 cache 换命中率**——`SETS 32→128` 会加约 11 k LUTRAM，直接破门禁。
  这条写进"不做什么"。
- DRM 8 / APM 6 不动。

## 7. 验收顺序（每步都跑，不许跳）

1. `run_coremark_sim.py --image sim20_o2 --define RV32_DEBUG` →
   `Total ticks` 折分、五项 CRC、`STALLDBG`/`MEMWAITDBG`。
2. `run_isa_e2e.py` 全 21 例（基线 20/21，新红即回退）。
3. `run_pds_flow.py --freq 126 --mode synth` → 面积（时序要 `--mode full`）。
4. 频率：`--freq 100 --mode full` 取路径表，改完复测；收敛判据见 §37
   （`All Constraints Met` 且 WNS 接近 0，Route < 70%）。
5. 结论写 `evidence/records/optimization/<阶段>/measurement.md`；教训回写 `mistakes-log.md`。

## 8. 不做什么（明确排除）

- **不**扩大 cache 容量换命中率（LUTRAM 门禁）。
- **不**做 MSHR/多 outstanding refill：AXI 从设备（`axi_ram`）单 outstanding，
  多 MSHR 只会把等待搬个地方。
- **不**为 ns 牺牲配对（`PAIRGAP` 的 pair 数不许掉）。
- **不**用"满足式宽约束"证明频率（§37）。
- **不**在没有 `Total ticks` 读数的情况下声称分数变化。

## 9. 执行记录

### 9.1 分数（每步都有 `Total ticks` 读数）

| 提交 | 模块 | Total ticks | CM/MHz |
|---|---|---:|---:|
| `cb9b281` | 起点（R5） | 4,518,354 | 4.427 |
| `1b7acf0` | ifu_axi + rv32_top（lane1 真实 PC） | 4,390,102 | 4.556 |
| `458ed8b` | dcache_axi（STQ 4→8，R6 的最小版本） | 4,308,858 | 4.641 |
| `297b768` | ifu_axi（重定向当拍取指） | 4,179,679 | 4.786 |
| `0842e48` | perf_regs + csr_native（计数器进位链拆分） | 4,179,679 | 4.786 |
| `01ba45e` | rv32_top（lane1 自己的乘法器） | **4,070,391** | **4.914** |

**距 5.2 还差 224,237 tick**。下面每一节都写了"为什么没做"，不是没算过。

### 9.2 §4 的诊断判据跑出来什么（`--tag d6why`）

| 探针 | 读数 | 判决 |
|---|---|---|
| `WIN_NOPAIR cnt<=1 / cnt>1` | 494,108 / **0** | 加队列深度、加预取**无用**：队里从来不是"有两条" |
| `WIN_NOPAIR off[0..7]` | …/109,655/**193,436** | 61% 的单发射卡在行尾两格；offset 7 是跨行成对，结构性的 |
| `WIN_MEMMEM` | ll=197,924 / ls=40,624 / sl=19,020 / ss=7,608 | 77% 是两条 load 抢读口 |
| `WIN_L1BAD` | mul=115,086 / jalr=35,946 / 其余 106 | 只有 mul 值得做（R9a 已做） |
| `WIN_NOISSUE other` | 142,478 | 重定向后的 1 拍气泡，137,289 次重定向的必然结果 |

### 9.3 明确判死的三条（附理由，避免重算）

1. **跨行成对**（能救 19.3 万单发射里的绝大多数）：要给 I$ 加第二个 LUTRAM 读口，
   2 KB 阵列复制 ≈ +1,800 LUTRAM，**破面积门禁**。
2. **lane1 延后访存**（能救 25.6 万访存拒收）：需要 (a) 一个真正能冻结
   M1/M2/WB 的机制（现有 `hold_m1` 只会插气泡），(b) 第三条寄存器堆写口。
   这两条都超出"一次只改一个模块"，且踩过 `hold_ex` 依赖环的死锁。
3. **扩大 BTB**（能压 `mispred=88,088`）：32 项 → 128 项 ≈ +2.2 k FF，**破面积门禁**。

### 9.4 频率

- `p11timing120`（120 MHz 核时钟、RTL `297b768`）：detailed placement
  **−5038 ps**、布线停在 2~3 根未布线，**不收敛**。证据在
  `build/p11timing120/NOTE-not-met.md`。
- 按 §43 的校准（布线后比摆放估计再差 ~4 ns），这条 RTL 的真实 fmax 在
  **45~55 MHz**，120 MHz 差 2.5 倍左右。**这不是 R9 那种"挪一两级"能补的量**，
  要动流水线深度本身（EX 拆两级 / D$ 访问拆两级），而那会回头吃掉分数。
- 本轮已经做的频率工作只有一件事：`0842e48` 把 64 b 计数器拆成 16 b 四段
  （`p7_path40b` 的三条最差路径有两条终结在 `cnt[2][56]`）。
- **未完成**：`01ba45e`（lane1 第二个乘法器）又新增了一条 ~9 ns 的级联，
  对 120 MHz 是负贡献。这一条是明确的取舍，写在提交信息里。

### 9.5 R10：返回地址栈（RAS）——**已回退**，判据与理由见 mistakes-log §44

| 探针 | 读数 |
|---|---:|
| `WIN_RAS push/pop` | 32,292 / 32,331 |
| `WIN_RAS fetch_ret` | 23,480 |
| `WIN_RAS sp_max` | **8**（== `RAS_DEPTH`，顶满） |
| `WIN_RAS jalr / jalr_pred_ok` | 44,448 / 26,579（60%） |

`Total ticks` 4,070,391 → 4,068,258（−2,133，0.05%），`mispred` 88,087 → 87,742。
栈顶满后错位抵消了命中的收益，且 40% 的 `jalr` 是 `jr` 型、RAS 天生不覆盖。
已 `git checkout 01ba45e` 回退并重跑确认读数回到 4,070,391。
**判据**：先证明有界结构"从不溢出"（`max occupancy < capacity`），再谈命中率。

### 9.6 频率：关键路径到底在哪（`p7_path40b` 布线后的真实报告）

`build/p7_path40b/report_timing/pangoriscv_top.rtr`（25 ns 约束、已布通）
的 `Performance Summary`：`Estimated Period 26.6469 ns`（37.53 MHz），
`WNS -1.647`，**只有 43 个端点不满足 / 共 69,277 个**。

最差路径 39 个逻辑级，`Logic 11.345 ns (43.5%) / Route 14.749 ns (56.5%)`：

```
w_rd_h[4]            dcache 读数据
  -> rd_valid_h / u_regs/N41            (fanout 65, route 1.370 ns)
  -> fwd2[15]                            (旁路选通)
  -> u_mul  APM/PO -> APM/P  x2          (两跳 APM 级联, 1.806+1.362+1.764+1.608+1.362+1.106 ≈ 9.0 ns)
  -> u_alu_h  N1.slt_*  COUT 链          (32 b 进位链, 分支比较)
  -> br_taken_h                          (fanout 33)
  -> ex_next_h COUT 链                   (32 b 下一 PC 加法器)
  -> N665.eq_* COUT 链                   (32 b 相等比较, 预测校验)
  -> br_miss_h                           (fanout 133, route 1.715 ns)
  -> perf_if_wait
  -> cnt[2][0..60]/CECO x16              (计数器进位链, 16 x 0.136 = 2.18 ns)
  -> cnt[2][63]/CE
```

三个 32 位宽加法器（ALU 比较、下一 PC、预测校验）**串在同一拍里**，再加
16 级计数器 CE 链。这不是"布线器没努力"，是这一拍里放了太多东西。

资源（同一个 build 的 `synthesize/run.log`）：

| 项 | 用量 | 占比 |
|---|---:|---:|
| Total LUTs | 17,405 / 66,600 | **26.1%** |
| Total Registers | 7,776 / 133,200 | **5.8%** |
| DRM | 8 / 155 | 5.2% |
| APM | 10 / 240 | 4.2% |

**结论修正**：设计**不是**面积受限、**不是**拥塞受限（26% LUT），
是**逻辑深度受限**。想上 120 MHz（8.333 ns）必须把单拍逻辑级从 39 压到
16~18 级，也就是**改流水线深度**：
- EX 拆两级（ALU/乘法一级、分支解析 + 下一 PC 一级）；
- 乘法器单独一级（现在两跳 APM 级联 ≈ 9 ns，本身就超过 8.33 ns 的预算）；
- 计数器事件抽头打一拍（把 `perf_if_wait` 那一大坨锥从计数器 CE 前面切掉）；
- 旁路网络（`fwd2` 前那一跳 route 1.0~1.4 ns）需要按来源分组选通，不能一根线走全场。

**这四条都吃分数**（多一级流水 = 多一拍分支惩罚），和 5.2 的目标直接冲突。
本轮不做，因为它会把已经拿到的 4.914 打回去，而且在数据通路定型前做等于白做。
