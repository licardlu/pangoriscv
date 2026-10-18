# P13 · 读命中可在写事务期间被受理（2026-10-18）

> 结论：**ticks −7.64%**（8,432,493 → 7,788,468，20 迭代），
> CoreMark/MHz **2.3708 → 2.5674（+8.29%）**，**面积零增量、触发器零增量**。
> 交付跑分：768 迭代、ticks **299,139,003**、11.08 s、`Correct operation validated`；
> 27 MHz 与 50 MHz 约束均 **All Constraints Met**。
>
> **这一步把指标推过了 2.5。**

---

## 1. 依据（P10 之后实测，20 迭代窗口 10,341,340 拍）

```
LSU_PATH empty=7726841 request=938598 wdata=287905 rdwait=1329141 wrwait=4530 complete=0
MEM_OPS  ops=1631804 ld=1343899 st=287905
```

| 事实 | 含义 |
|---|---|
| `request` = 938,598（9.1%） | **单项最大**。这是"引擎忙、这一拍收不下请求"的退路 |
| 每秒 store 占缓存 2.5 拍 | 287,905 笔 store × ~2.5 ≈ 720 K，与 `request` 量级吻合 |
| `d_miss` 仅 4,448（0.33%） | **不是缺失问题**：缓存是因为"正在处理写事务"而不是"正在取数"才拒收 |

**关键洞察**：一次读命中只需要 标签 RAM + 数据 RAM，**根本不需要状态机**。
而旧实现里 `req_ready` 只在 `ST_IDLE` 为高——写事务期间（`ST_WR_REQ`/`ST_WR_HOLD`/`ST_WR_DRAIN`）
缓存明明能答读，却把 CPU 挡在门外。

## 2. 改动（`dcache_axi.v` 两个表达式，共 8 行）

```verilog
// 一次读命中只依赖 RAM，与写状态机无关
wire read_hit_now = req_valid && !req_write && req_in_cache && hit_any;
assign req_ready = rst_n && !protocol_fault && !config_fault &&
                   ((state_q==ST_IDLE) ||
                    ((state_q==ST_WR_HOLD || state_q==ST_WR_DRAIN) && read_hit_now));

// 受理判定不再限定 ST_IDLE（响应本来就是组合给的）
wire accept_hit = rst_n && req_valid && req_ready && !req_write &&
                  req_in_cache && hit_any;
```

配合 P10 已有的"受理拍应答"，效果是：**在写事务占着缓存的这几拍里，读命中照样当拍完成**。

### 为什么不会打架

- 写事务仍只由 `req_write` 的请求触发；`req_ready` 对写请求依旧只在 `ST_IDLE` 为高
  （`read_hit_now` 含 `!req_write`）。
- 缓存状态本身**不变**（读命中是组合应答，不改 `state_q`），所以写状态机的
  `ST_WR_REQ → ST_WR_HOLD → ST_WR_DRAIN` 时序完全不受影响。
- 读与写不可能同时占用 LSU：LSU 在 `WRITE_WAIT` 时 `fast_issue=0`，`req_valid=0`；
  在 `EMPTY` 受理读时 `eng_b_ready=0`，不会把 store 的 B 取走。**两条路互斥。**
- 读**缺失**时仍落到 `request` 退路（`read_hit_now` 要求 `hit_any`），语义未变。

**一个已知的次要取舍**：在写状态期间服务的读命中不会更新 LRU
（LRU 只在 `ST_IDLE` 受理分支写）。这只影响替换优先级，不影响任何架构可见结果；
实测 768 迭代跑分 CRC 与基线逐项一致。

## 3. 曾被回退的一步（P12，记录备查）

同一晚还试过"把 store 的写确认提到 W 握手当拍"（P12）：
`wrwait` 从 291,691 掉到 4,530，但 `request` 反而从 708,411 升到 938,598，
净收益只有 **−0.64%**；更关键的是它让 store 不再经过 `WRITE_WAIT`，
`run_halt_reset_tests.py` 的场景 2/4（"写进行中时 halt/reset"）等不到注入点而超时。

**决定：回退 P12，保留 P13**。理由：0.64% 换一个要改 halt/reset 测试语义的风险不划算，
而且 P13 在 P12 回退后依然拿到 −7.64%。这也让 halt-reset 5/5 原样通过。

## 4. 20 迭代 A/B（同镜像 `perf_on`，基线 `HEAD`）

| 指标 | P10 状态 | 本版（P13） | 变化 |
|---|---|---|---|
| **ticks** | 8,432,493 | **7,788,468** | **−7.64%** |
| cycles | 10,341,340 | 9,691,758 | −6.28% |
| IPC | 0.6421 | **0.6854** | +6.7% |
| **`LSU request`** | 938,598 | **244,654** | **−693,944** |
| `rdwait` | 1,329,141 | 1,127,424 | −201,717 |
| `lsu_wait` | 726,360 | 518,445 | −207,915 |
| 五项 CRC | — | 逐项相同 | 架构等价 |
| traps / faults | 0 / 0 | 0 / 0 | — |

归因闭环：`request` 掉 693,944 拍、`rdwait` 掉 201,717 拍，总周期掉 649,582 拍
（转化率约 73%，其余被取指/分支的随机波动吸收）。

## 5. 交付跑分（镜像 `score768`，768 迭代）

```
每迭代 ticks = 7,788,468 / 20 = 389,423
N ≥ ceil(10.5 × 27e6 / 389,423) = 728   → 取 768（11.08 s）
```

```
Total ticks      : 299139003
Total time (secs): 11
Iterations/Sec   : 69
Iterations       : 768
seedcrc          : 0xe9f5
[0]crclist       : 0xe714
[0]crcmatrix     : 0x1fd7
[0]crcstate      : 0x8e3a
[0]crcfinal      : 0x3c53
Correct operation validated. See readme.txt for run and reporting rules.
```
> （本行串口输出被 `PROGRESS` 控制行打断，数值由已核验的整数截断模型推导：`floor(ticks/27e6)` 秒、`iterations / 该整数`）

> 注：固件的 `Total time (secs)` 与 `Iterations/Sec` 是**整数截断**打印的（`core_portme.h` 里 `HAS_FLOAT 0`，见 `native-basic-final-status.md`）。所以它们的值来自 `floor(ticks/27e6)` 与 `iterations / 那个整数`，**不能用它们反推分数**——分数必须用 `Total ticks` 计算，即 `iterations / ticks × 1e6`。


| 项 | 值 |
|---|---|
| ticks / cycles / retires | 299,139,003 / 300,928,216 / 222,178,327 |
| **IPC** | **0.7383** |
| **CoreMark/MHz** | **2.5674** |
| traps / faults | 0 / 0 |

> 与 P10 同一份 `score768` 镜像、同一迭代数，所以 `crcfinal` 同为 `0x3c53`，
> 可以直接横向对比 ticks。

## 6. PDS 实现（同一份源码 + 同一份 `score768` 镜像）

| 约束 | 结果 | Setup WNS | Hold WHS | 失败端点 | Total LUTs |
|---|---|---|---|---|---|
| 37.037 ns（27 MHz，交付） | **All Constraints Met** | **+14.864 ns** | **+0.066 ns** | **0 / 54,514** | **13,558** |
| 20 ns（50 MHz，过约束） | **All Constraints Met** | **+0.587 ns** | **+0.016 ns** | **0 / 54,745** | 13,758 |

- 27 MHz 快角：setup +23.010 / hold +0.031
- Total Registers **8,639**（P7 起六轮完全相同）
- 交付位流 `pangoriscv_i768.sbit`，3,791,112 B，
  SHA256 `EF79F99599497255407BD53EBF1F01AC78FA4B9BB9B696DA68B35136FC6BC409`

### 6.1 hold 收敛过程（重要经验）

P10/P13 的 27 MHz 全流程多次卡在 **1~5 个 hold 端点，−0.001 ~ −0.027 ns**，
换 `groute/gplace seed` 只有概率性效果（7→−0.027、23→−0.002、41→−0.001）。
**根因是 D-Cache LUTRAM 写口跨时钟树分支（HCKBROUTE_1 vs _2）的偏斜**，
不是逻辑本身的问题。

最后用 **`-fix_hold_violation_threshold 500`**（而不是之前一直用的 300）
一次收住，hold 余量从 +0.016 ns 提到 **+0.066 ns**（快角 +0.031）。
**这条参数应作为该设计的默认值保留**：300 ps 的目标留给工具的空间不够，
500 ps 才让它真正把偏斜修掉。

50 MHz 同样需要两组种子：`seed 11` 得 −0.156 ns（失败），`seed 41` 得 +0.587 ns（通过）。
**50 MHz 的 setup 余量只有 +0.587 ns，是本设计最紧的约束。**

## 7. 资源代价

| 项 | 基线 `HEAD`（P9） | 本版（P13） | 变化 |
|---|---|---|---|
| Total LUTs | 13,059 | **13,558** | **+499（+3.82%）** |
| ├ as logic | 10,374 | 10,617 | +243 |
| └ as DRAM | 2,685 | 2,941 | +256 |
| Total Registers | 8,639 | 8,639 | **0** |

注意：**本步（P13）本身面积零增量**——13,558 与 P10 完全相同。
+499 的代价全部来自 P10 的"受理拍应答"（同拍读要求数据 RAM 走组合读，
工具把更多 `data_mem` 推成分布式 RAM）。

## 8. 正确性与回归

| 门 | 结果 |
|---|---|
| `run_unit_tests.py --case all` | **5/5 PASS** |
| `run_isa_e2e.py --cases all` | **15/15 PASS**（含 load/store 故障、MMIO 旁路、定时器中断） |
| CoreMark 五项 CRC | 与基线逐项相同；交付跑分 `Correct operation validated` |
| `run_ram_tests.py --seeds 20` | 40/40 PASS |
| `run_ifu_engine_tests.py --seeds 20` | 20/20 PASS |
| `run_halt_reset_tests.py` | **5/5 PASS**（P12 回退后恢复，含"写进行中 halt/reset"） |
| `run_dcache_tests.py` | PASS |

## 9. 累计成绩

| 阶段 | CoreMark/MHz | LUT | CoreMark/kLUT |
|---|---|---|---|
| S0 基线（store 优化前） | 1.3054 | 12,572 | 0.1038 |
| P2' store 后台排空 B | 1.4342 | 12,622 | 0.1136 |
| P7 取指吞吐 | 1.6815 | 13,018 | 0.1292 |
| P8 访存快发 | 1.8622 | 13,059 | 0.1426 |
| P9 完成提前报 | 2.0843 | 13,099 | 0.1591 |
| P10 零延迟命��� | 2.3708 | 13,558 | 0.1749 |
| **P13 读命中不阻塞（本版）** | **2.5674** | **13,558** | **0.1894** |

- 相对 P10：**+8.29%**，面积 **零增量**
- 相对 S0：**+96.67% CoreMark/MHz**、**+82.37% CoreMark/kLUT**，面积仅 **+7.84%**

## 10. 再往上的空间（供后续参考）

| 来源 | 拍数 / 20 迭代 | 占比 | 说明 |
|---|---|---|---|
| `rdwait` | 1,127,424 | 11.6% | 主要是 4,448 次读缺失 × 8 拍突发 + MMIO 旁路。要吃得扩 D-Cache 或做非阻塞缺失（MSHR） |
| `if_wait` | 788,983 | 8.1% | I-Cache 2 KB 装不下 13 KB 文本；4 KB 约 1.5~2%，代价 +约 1 K LUT |
| `wrwait` | 291,683 | 3.0% | 已试（P12）净赚仅 0.64% 且破坏 halt 测试语义，**不再做** |
| `request`（残余） | 244,654 | 2.5% | 已是纯读缺失造成的，属 `rdwait` 同源 |
| `mispred` | 153,686 × 2 | 3.2% | RAS 约 1~1.5% |

**内存主链已经彻底挖到底**：读命中 1 拍、写 3 拍、写事务期间读仍可 1 拍命中。
再往上必须动缓存容量或非阻塞缺失，那是数量级更大的改造。
