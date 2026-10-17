# P10 · 零延迟 D-Cache 命中 + 写请求提前交付（2026-10-18）

> 结论：**ticks −12.07%**（9,588,579 → 8,432,493，20 迭代），
> CoreMark/MHz **2.0843 → 2.3708（+13.75%）**，触发器零增量、面积 **+3.82%**。
> 交付跑分：768 迭代、ticks **323,940,991**、12.00 s、`Correct operation validated`；
> 27 MHz 与 50 MHz 约束均 **All Constraints Met**。
> 证据等级：仿真实测（同镜像 A/B）+ 单元测试 + ISA 15/15 + PDS 真实实现产物。

---

## 1. 依据（P9 之后实测，20 迭代窗口 11,499,752 拍）

```
MEM_OPS  ops=1631338 ld=1343430 st=287908   d_miss=4209（0.31%）
LSU_PATH empty=7710550 request=714058 wdata=575816 rdwait=2207632 wrwait=291696 complete=0
EX_OCCUPANCY ex_busy=3795257 ex_mem_post=2157864 ex_div_busy=6055
```

| 事实 | 含义 |
|---|---|
| `rdwait` = 1.35 拍/load | 命中也要占 **1 拍等结果**（受理拍与响应拍是两拍） |
| `wdata` = 2.00 拍/store | 写引擎要两拍才收下 W 拍 |
| `request` = 0.51 拍/访存 | 引擎忙（D-Cache 在处理写事务/缺失）时的退路 |
| `d_miss` 仅 4,209（0.31%） | **不是缺失问题**，是命中路径的长度问题 |

一笔命中 load 原来占 EX 两拍：T0 受理 → T1 拿结果并退休。T0 这一拍就是纯等。

## 2. 改动（两个动作，跨 3 个文件）

### P10：D-Cache 命中在受理当拍应答

`dcache_axi.v` —— 标签比较本来就在 `req_addr` 上组合跑，所以数据字可以在同一拍读出：

```verilog
wire accept_hit = rst_n && (state_q==ST_IDLE) && req_valid && req_ready &&
                  !req_write && req_in_cache && hit_any;
wire [31:0] accept_word = data_mem[didx(hit_way,req_set,req_addr[4:2])];
assign rsp_valid = rst_n && ((state_q==ST_HIT) || (state_q==ST_BYP_RESP) || accept_hit);
assign rsp_data  = ... accept_hit ? accept_word : ...;
```

受理分支在"当拍就被接走"时**直接回 `ST_IDLE`**，不再停 `ST_HIT`（否则同一响应会重复出现两次）。

`lsu_axi.v` —— 受理拍也要准备接响应：

```verilog
assign eng_rsp_ready = rst_n && (state==READ_WAIT || fast_issue);
wire   rsp_fire      = eng_rsp_valid && eng_rsp_ready;
```

`pangoriscv.v` —— 允许"受理当拍即完成"：

```verilog
wire mem_issued = issued || (op_valid && op_ready);   // issued 是寄存器，受理拍还是 0
wire ex_done    = local_fault || (is_memory ? (mem_issued && done_valid) : ...);
wire ex_fault   = local_fault || (is_memory && mem_issued && done_valid && fault);
assign done_ready = ex_leave && is_memory && mem_issued;
```

三处都检查过组合环：`done_valid ← dcache hit ← req_addr`，不依赖 `op_ready`/`ex_leave`；
`op_valid ← !issued`（寄存器）；`eng_rsp_ready` 只看状态与 `op_valid`。**无环。**

### P11：写请求在受理拍就交给写引擎

`dcache_axi.v` —— 原来 dcache 先把写请求寄存一拍（`i_req_valid_r`）再给内层引擎，
所以引擎要下一拍才进 `WR_PREP`、再下一拍才收 W。改为受理拍就用组合信号递交：

```verilog
wire i_write_accept = rst_n && (state_q==ST_IDLE) && req_valid && req_ready && req_write;
wire        i_req_valid = i_req_valid_r || i_write_accept;
wire [31:0] i_req_addr  = i_write_accept ? req_addr : i_req_addr_r;   // size/len/id/write 同理
```

引擎在 `WR_IDLE` 只看 `req_valid`，所以那个寄存器脉冲在后续周期被忽略，无副作用。

## 3. 踩到并修掉的死锁（值得记下来）

第一版 P10 **死锁**（5124 条后卡在 PC 0x2c0）：`accept_hit` 忘了排除写操作。
一次**缓存写命中**被当成"读同拍应答"——LSU 以为已完成并退休，而 dcache 同时走进
`ST_WR_REQ` 开始写事务，随后 `ST_WR_HOLD` 等 LSU 的 `b_ready`，但 LSU 早已不在
`WRITE_WAIT`，B 永远没人接 → 挂死。

修法：`accept_hit` 加 `!req_write`。教训：**同拍应答必须按"读/写"分流**，
写事务的完成语义来自 B 响应，不能走读的快捷路径。

## 4. 两级 A/B（同镜像 `perf_on`，每步只改一处）

| 指标 | P9 基线 | +P10 | +P11（本版） |
|---|---|---|---|
| ticks | 9,588,579 | 8,713,558（**−9.12%**） | **8,432,493（再 −3.23%）** |
| cycles | 11,499,752 | 10,626,093 | 10,341,340 |
| IPC | 0.5770 | 0.6248 | **0.6421** |
| `LSU rdwait` | 2,207,632 | **1,324,990** | 1,325,930 |
| `LSU wdata` | 575,816 | 575,810 | **287,905（精确减半）** |
| `lsu_wait` | 1,611,112 | 1,611,112 | **723,166** |
| 五项 CRC | — | 逐项相同 | 逐项相同 |
| traps / faults | 0 / 0 | 0 / 0 | 0 / 0 |

归因干净：`rdwait` 掉 882,642 拍（load 不再付受理拍），`wdata` 精确减半（写引擎早一拍收到 W），
`lsu_wait` 随之减半。`if_wait`/`mispred` 未变差。

## 5. 交付跑分（镜像 `score768`，768 迭代）

```
每迭代 ticks = 8,432,493 / 20 = 421,625
N ≥ ceil(10.5 × 27e6 / 421,625) = 673   → 取 768（12.00 s）
```

```
Total ticks      : 323940991
Total time (secs): 11
Iterations/Sec   : 64
Iterations       : 768
seedcrc          : 0xe9f5
[0]crclist       : 0xe714
[0]crcmatrix     : 0x1fd7
[0]crcstate      : 0x8e3a
[0]crcfinal      : 0x3c53
Correct operation validated. See readme.txt for run and reporting rules.
```

| 项 | 值 |
|---|---|
| ticks / cycles / retires | 323,940,991 / 325,735,779 / 222,177,475 |
| 每迭代指令 | 289,294（基线 289,508，同一工作负载） |
| **IPC** | **0.6821** |
| **CoreMark/MHz** | **2.3708** |
| traps / faults | 0 / 0 |

> `crcfinal` 随迭代数变化：20→0x4983、400→0x25b5、512→0xdfc8、576→0x7b65、
> 640→0x382f、768→**0x3c53**。官方只校验 list/matrix/state（与迭代数无关）。

## 6. PDS 实现（同一份源码 + 同一份 `score768` 镜像）

| 约束 | 结果 | Setup WNS | Hold WHS | 失败端点 | Total LUTs |
|---|---|---|---|---|---|
| 37.037 ns（27 MHz，交付） | **All Constraints Met** | **+14.986 ns** | **+0.016 ns** | **0 / 54,433** | **13,558** |
| 20 ns（50 MHz，过约束） | **All Constraints Met** | **+3.361 ns** | **+0.073 ns** | **0 / 54,715** | 13,737 |

- 27 MHz 快角：setup +22.607 / hold **+0.000**
- Total Registers **8,639**（P7/P8/P9/P10 完全相同）
- 交付位流 `pangoriscv_i768.sbit`，3,791,112 B，
  SHA256 `50FB9F2DFA24C4706D4EA33CFFAF57DD384734B76F11FCDBA47A086B027E39AA`

**P10 原本的最大疑虑没有兑现**：把"缓存字 RAM 读出 → 符号扩展 → 寄存器堆写回"
压进同一拍，理论上会砍掉频率余量。实测 50 MHz 仍收敛且余量反而变大（+3.361 ns），
27 MHz 也保持 +14.986 ns。综合把 `extend_load` 与写回选择合并得比预期好。

**⚠️ 必须记下的风险：27 MHz 的 hold 余量只剩 +0.016 ns**（快角 +0.000）。
这是通过的（0 失败端点），但余量已接近零，属于该版本最脆的一项。
第一次 27 MHz 全流程曾出现 1 个 hold 端点 −0.029 ns（D-Cache LUTRAM 写口跨时钟树分支），
换 `-groute_seed/-gplace_seed 7` 后收住。**上板前建议再留一档更保守的种子或降低 LUT 压力。**

## 7. 资源代价（受控 A/B：同流程、同镜像、仅 3 个 RTL 文件不同）

| 项 | 基线 `HEAD`（P9） | 本轮（P10+P11） | 变化 |
|---|---|---|---|
| Total LUTs | 13,059 | **13,558** | **+499（+3.82%）** |
| ├ as logic | 10,374 | 10,617 | +243 |
| └ as DRAM | 2,685 | **2,941** | **+256** |
| Total Registers | 8,639 | 8,639 | **0** |

DRAM 增加 256 是因为同拍读出要求数据 RAM 走**组合读**，工具把更多 `data_mem` 推成
分布式 RAM（LUTRAM 单元本身就占 LUT 位）。这是零延迟命中的必然代价。

## 8. 正确性与回归

| 门 | 结果 |
|---|---|
| `run_unit_tests.py --case all` | **5/5 PASS** |
| `run_isa_e2e.py --cases all` | **15/15 PASS**（含 load/store 故障、MMIO、定时器中断） |
| CoreMark 五项 CRC | 与基线逐项相同；交付跑分 `Correct operation validated` |
| `run_ram_tests.py --seeds 20` | 40/40 PASS |
| `run_halt_reset_tests.py` | 5/5 PASS |
| `run_dcache_tests.py` | PASS |

## 9. 累计成绩

| 阶段 | CoreMark/MHz | LUT | CoreMark/kLUT |
|---|---|---|---|
| S0 基线（store 优化前） | 1.3054 | 12,572 | 0.1038 |
| P2' store 后台排空 B | 1.4342 | 12,622 | 0.1136 |
| P7 取指吞吐 | 1.6815 | 13,018 | 0.1292 |
| P8 访存快发 | 1.8622 | 13,059 | 0.1426 |
| P9 完成提前报 | 2.0843 | 13,099 | 0.1591 |
| **P10 零延迟命中（本版）** | **2.3708** | **13,558** | **0.1749** |

- 相对 P9：**+13.75%**，面积 +3.50%
- 相对 S0：**+81.61% CoreMark/MHz**、**+68.41% CoreMark/kLUT**，面积仅 **+7.84%**

## 10. 距离 2.5 还差什么（下一轮的准确清单）

现在 2.3708，到 2.5 还差 **+5.45%**（约 560 K 拍 / 20 迭代窗口 10.34 M）。
剩下的账（P10 实测窗口）：

| 来源 | 拍数 | 占比 | 可行性 |
|---|---|---|---|
| `request`（引擎忙退路） | 708,411 | 6.8% | **结构性**：D-Cache 是单上下文的，写事务/缺失期间不能受理读。要吃得做"读写双上下文"或非阻塞缺失（MSHR） |
| `if_wait`（取指饥饿） | 782,973 | 7.6% | I-Cache 2 KB 装不下 13 KB 文本；4 KB 约能拿 1.5~2%，代价 +约 1 K LUT |
| `wrwait`（store 等 B） | 291,691 | 2.8% | 已经是 1.0 拍/笔，除非让"早释放"的 OKAY 在 W 握手当拍就报（要处理 drain 与 b_ready 的耦合，风险中） |
| `mispred` | 153,686 × 2 | 3.0% | RAS 约能拿 1~1.5% |
| `rdwait` | 1,325,930 | 1.04/load | 已接近理论下限（只有缺失/旁路才等） |

**结论**：本微架构在"单发射三级流水 + 单上下文 D-Cache"下，内存路径已经挖到接近底
（命中 load = 1 拍、store = 3 拍）。要到 2.5 必须动 `request` 这一项 —— 那是结构性改造
（读写双上下文或 MSHR），不是调参；或者接受 I-Cache 扩容 + RAS 的 3% 零碎收益到约 2.44。
