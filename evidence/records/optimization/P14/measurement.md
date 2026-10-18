# P14 · store 在 W 握手当拍拿写确认（2026-10-18）

> 结论：**ticks −1.67%**（7,788,468 → 7,658,647，20 迭代），
> CoreMark/MHz **2.5674 → 2.6109（+1.70%）**，面积 +18 LUT（+0.13%）、触发器零增量。
> **累计相对最初交付正好翻一倍（+100.01%）。**
> 交付跑分：768 迭代、ticks **294,149,365**、10.89 s、`Correct operation validated`；
> 27 MHz 与 50 MHz 约束均 **All Constraints Met**。

---

## 1. 发现过程：先量、先证伪，再动手

这一轮一开始怀疑 `rdwait`（LSU 等读响应 1,050,358 拍，账面 11%）是块肥肉。加了三个
只在计分窗口内统计的探针之后，**结论是否定的**：

```
ADDR_REGION  ld_data=1,097,671  ld_hi=226,013   nonhit_data=4,569  nonhit_hi=226,013
HI_SPLIT     hi2=0  hi3=245,216  hi4=0  hi5=0  hi6=9
```

- 缓存窗口内的读缺失只有 **4,569 次（0.42%）**，完全不是问题。
- 226,013 次"高地址读"**全部落在 0x3000_0000**，也就是 **UART 状态寄存器的忙等轮询**，
  而且发生在 CoreMark 报告打印阶段——**在 `stop_time` 之后，不计入 `ticks`**。
- 所以 `rdwait` 的大头是"跑完分之后打串口"，**不是性能瓶颈**。

同时量出真正的账（每迭代 `ticks` 389,423，指令 289,294，额外 100,129 拍）：

| 来源 | 每迭代拍数 | 占比 |
|---|---|---|
| load | 54,884 | 54.8% |
| **store** | **28,702** | **28.7%** |
| 分支预测失败 | 15,386 | 15.4% |

并顺手证伪两个方向：

```
MISPRED_MIX ret=17,574  jal=23,961  br=112,151  other=0
```

- **返回地址栈（RAS）只值约 0.5%**（返回只占预测失败的 11.4%），不值得做。
- 预测失败 72.9% 是普通分支 → 只能靠更大的 BTB，而 BTB 64/128 项要 +15%/32% LUT，
  会把 ③ 拉低 13~24%，**性价比为负**。

于是锁定唯一还划算的一刀：**store 的 3 拍 → 2 拍**。

## 2. 改动（`dcache_axi.v` + `lsu_axi.v`）

一笔数据区 store 原本占三拍：受理 → 送 W 拍 → 等写确认（B）→ 退休。

`dcache_axi.v` ——"早释放"的写照一直在 `ST_WR_REQ` 收 W 拍时就已经知道结果是 OKAY
（因为它不等 B），却要把这个 OKAY 寄存到下一拍才交出去。改为**当拍交**：

```verilog
wire early_now = rst_n && (state_q==ST_WR_REQ) && early_q && w_valid && w_ready;
assign b_valid = rst_n && ((state_q==ST_WR_HOLD) || early_now);
assign b_resp  = early_now ? `AXI_RESP_OKAY : resp_q;
```

CPU 当拍接走时，直接进后台排空，不再在 `ST_WR_HOLD` 空停：

```verilog
if (b_ready) begin
    if (cached_q && hit_q) data_mem[didx(hit_way_q,set_wr_q,word_q)] <= merged_now;
    state_q <= (i_b_valid) ? ST_IDLE : ST_WR_DRAIN;
end else state_q <= ST_WR_HOLD;   // CPU 没接走：保持寄存版 OKAY（原逻辑不变）
```

注意写通合并必须用**原始** `w_data/w_strb`（`merged_now`），因为 `wdata_q/wstrb_q`
正好在这一拍才锁存。

`lsu_axi.v` —— 送 W 的那一拍也要能收写确认：

```verilog
assign eng_b_ready = rst_n && (state==WRITE_WAIT ||
                               (state==WRITE_DATA && eng_w_valid && eng_w_ready));
wire   b_fire      = eng_b_valid && eng_b_ready;
```

`WRITE_DATA` 分支：`b_fire` 就完成，否则照旧进 `WRITE_WAIT`。

## 3. 一个必须改的测试台假设（不是放宽，是换更准的观察点）

`run_halt_reset_tests.py` 的场景 2/4（"写进行中时 halt / reset"）原本靠
`wait(soc.core.lsu.state == LSU_WRITE_WAIT)` 找注入时机。P14 之后数据区 store
不再在 `WRITE_WAIT` 停留，这个等待永远等不到 → 超时失败。

**改法**：等"LSU 停着"**或 AX**"AXI 的 **AW 握手**"：

```verilog
wait (soc.core.lsu.state == LSU_WRITE_WAIT ||
      (soc.m_awvalid[1] === 1'b1 && soc.m_awready[1] === 1'b1));
```

这比原来的观察点**更贴近测试本意**（"写已经上了总线、B 还没回来"），
而且不依赖缓存有没有被实例化（`m_awvalid` 在两种配置下都存在）。
改完 5/5 全过，断言一个字没动。

> 对比记录：上一轮有个 P12 版本被**回退**了，因为当时只想靠"改测试"掩盖问题，
> 而且它净赚只有 0.64%。这一轮 P13 已经把"写期间的读"打通，同样的改动净赚升到 1.67%，
> 观察点也换成了更准的那个——所以留下。

## 4. 20 迭代 A/B（同镜像 `perf_on`，基线 `HEAD`）

| 指标 | P13 | 本版（P14） | 变化 |
|---|---|---|---|
| **ticks** | 7,788,468 | **7,658,647** | **−1.67%** |
| cycles | 9,691,758 | 9,561,172 | −1.35% |
| IPC | 0.6854 | **0.6947** | +1.4% |
| **`LSU wrwait`** | 291,155 | **4,140** | **−98.6%** |
| `DCACHE ST_WR_HOLD` | 287,902 | **743** | −99.7% |
| `LSU request` | 244,493 | 400,667 | +156,174 |
| `DCACHE drain` | 1,491,623 | 1,778,399 | +286,776 |
| 五项 CRC | — | 逐项相同 | 架构等价 |
| traps / faults | 0 / 0 | 0 / 0 | — |

**归因**：`wrwait` 掉 287,015 拍是直接收益；`request` 涨 156,174 拍是因为缓存把
"停一拍等 CPU"换成了"停一拍排空 B"，只是把等待挪了个位置（P13 已让读命中穿透，
所以只赔了一半）。净下来 store 早退休一拍，流水线整体前移，得 −1.67%。

## 5. 交付跑分（镜像 `score768`，768 迭代）

```
每迭代 ticks = 7,658,647 / 20 = 382,932
N ≥ ceil(10.5 × 27e6 / 382,932) = 741   → 取 768（10.89 s）
```

```
Total ticks      : 294149365
Total time (secs): 10
Iterations/Sec   : 76
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
| ticks / cycles / retires | 294,149,365 / 295,937,832 / 222,178,406 |
| **IPC** | **0.7508** |
| **CoreMark/MHz** | **2.6109** |
| traps / faults | 0 / 0 |

> 迭代数下限 741，实取 768 → 10.89 s，满足 ≥10 s。与 P13 同一镜像同一迭代数，
> `crcfinal` 同为 `0x3c53`，可直接横比 ticks。

## 6. PDS 实现

| 约束 | 结果 | Setup WNS | Hold WHS | 失败端点 | Total LUTs |
|---|---|---|---|---|---|
| 37.037 ns（27 MHz，交付） | **All Constraints Met** | **+16.909 ns** | **+0.105 ns** | **0 / 54,350** | **13,576** |
| 20 ns（50 MHz，过约束） | **All Constraints Met** | **+1.286 ns** | **+0.021 ns** | **0 / 54,731** | 13,797 |

- 27 MHz 快角：setup +23.631 / hold +0.077
- 50 MHz：**第三次尝试（seed 23）才收敛**——seed 11 得 −0.001、seed 41 得 −0.155，
  都是同一处 LUTRAM 时钟树偏斜造成的 hold。**50 MHz 的收敛是种子敏感的，
  不能拿一次通过当保证。**
- Total Registers **8,639**（P7 起七轮完全相同）
- 交付位流 `pangoriscv_i768.sbit`，3,791,112 B，
  SHA256 `7E2CCBDC0D5744491B15C1F24EC4FF9AA45E82E54533C66305AE83F8DB4B0D36`

## 7. 资源代价

| 项 | 基线 `HEAD`（P9） | 本版（P14） | 变化 |
|---|---|---|---|
| Total LUTs | 13,059 | **13,576** | **+517（+3.96%）** |
| ├ as logic | 10,374 | 10,635 | +261 |
| └ as DRAM | 2,685 | 2,941 | +256 |
| Total Registers | 8,639 | 8,639 | **0** |

本步（P14）自身只多 **18 LUT**；其余 +499 来自 P10 的同拍读。

## 8. 正确性与回归

| 门 | 结果 |
|---|---|
| `run_unit_tests.py --case all` | **5/5 PASS** |
| `run_isa_e2e.py --cases all` | **15/15 PASS** |
| CoreMark 五项 CRC | 与基线逐项相同；交付跑分 `Correct operation validated` |
| `run_ram_tests.py --seeds 20` | 40/40 PASS |
| `run_ifu_engine_tests.py --seeds 20` | 20/20 PASS |
| `run_halt_reset_tests.py` | **5/5 PASS**（注入点改为 AW 握手，断言未动） |
| `run_dcache_tests.py` | PASS |

## 9. 累计成绩

| 阶段 | CoreMark/MHz | LUT | CoreMark/kLUT |
|---|---|---|---|
| S0 基线（store 优化前） | 1.3054 | 12,572 | 0.1038 |
| P2' store 后台排空 B | 1.4342 | 12,622 | 0.1136 |
| P7 取指吞吐 | 1.6815 | 13,018 | 0.1292 |
| P8 访存快发 | 1.8622 | 13,059 | 0.1426 |
| P9 完成提前报 | 2.0843 | 13,099 | 0.1591 |
| P10 零延迟命中 | 2.3708 | 13,558 | 0.1749 |
| P13 读命中不阻塞 | 2.5674 | 13,558 | 0.1894 |
| **P14 store 当拍拿确认（本版）** | **2.6109** | **13,576** | **0.1923** |

**相对 S0：CoreMark/MHz 正好翻倍（+100.01%）、每 kLUT +85.22%，面积只 +7.99%。**

## 10. 现在剩下的账（都已量化过，性价比不足）

| 来源 | 每迭代 | 占比 | 结论 |
|---|---|---|---|
| load（1 拍/笔，受理即退休） | 54,884 | 54.8% | **这是流水线结构下限**：指令必须在 EX 停留至少一拍。要再省只能"从 ID 直接发访存"，属大改造 |
| store（现 2 拍/笔） | 14,351 | 14.3% | 只剩"受理 + 送 W"两拍，第三拍已消掉 |
| 分支预测失败 | 15,386 | 15.4% | 72.9% 是普通分支 → 只能加大 BTB（+15~32% LUT），③ 会掉 13~24%，**净亏** |
| 返回地址栈 | ~1,754 | 1.8% | 返回仅占预测失败 11.4%，**不值** |
| `rdwait` 大头 | — | — | 是跑完分后的 UART 忙等，**不在计分窗口** |
| I-Cache 4 KB | 实测 +3.56% | — | **已实测并否决**，见附录 A |

**结论：本微架构（单发射三级流水 + 2 KB 写通 D-Cache + 32 项 BTB）在 13.6 K LUT
这个面积档上已经到效率拐点。** 再往上要么改流水线结构（从 ID 发访存 / 双发射），
要么用面积换不划算的速度。

---

## 附录 A · 计分窗口的精确分解（本轮新增探针）

上面第 1 节的账一开始是**有偏的**：`report_seen` 直到报告最后一行（"Correct operation"）
才置位，所以按它门控仍然把**整段报告打印**算进了统计。真正干净的切分点是
**第一次写 UART TXDATA**（CoreMark 只在 `stop_time()` 之后打印）。

新增探针（`tb_coremark_uart.sv`，全部只在计分窗口内计数）：

| 探针行 | 含义 |
|---|---|
| `SCORE_WINDOW` | 在第一次 TXDATA 写入时快照 `cycles/retires` 与 EX 占用分类 |
| `EX_SPLIT` | EX 占用按 load / store / 其他拆开，另含 `id_stall` |
| `DCACHE_PATH` | D-Cache 各状态拍数 + 进 READ_WAIT 次数 + 行填充次数 |
| `ADDR_REGION` / `HI_SPLIT` | 访存按地址区间分桶，定位"非缓存访问" |
| `MISPRED_MIX` | 预测失败按 `jalr/jal/branch` 分类 |

**P14 状态下的真实分解**（20 迭代）：

```
SCORE_WINDOW cycles=7,694,091 retires=5,782,501 no_retire=1,648,207
             load=139,567 store=666,915 other=35 id_stall=803,735
```

`sw_cycles` 与固件自测的 `ticks`（7,658,647）相差 0.5%，说明边界取得准。据此：

| 项 | 拍数 | 占额外开销 |
|---|---|---|
| `if_wait`（取指饥饿 ≈ I-Cache 缺失 × 43 拍） | ~775,000 | **40.5%** |
| store 占 EX（2.3 拍/笔） | 681,000 | 35.6% |
| 分支预测失败 | ~308,000 | 16.1% |
| load 占 EX | 148,000 | 7.7% |

**这纠正了第 1 节把 load 当成 54.8% 的说法**：`exb_load` 全量值 1,053,772 里
**绝大部分是报告阶段的 UART 忙等**（230,668 次非命中读 × ~4.5 拍），
计分窗口内 load 只占 139,567 拍（7.7%）。也就是说 **load 已经免费**（受理即退休），
这与"寄存器堆写透前递让 load-use 也免费"的预期一致。

## 附录 B · 被实测否决：I-Cache 2 KB → 4 KB

计分窗口里最大的单项是 `if_wait`（40.5%），根因是 I-Cache 缺一行要等**整行 8 拍填满**
才应答（`m_rlast` 之后才进 `IC_MISS_RD`），每次约 43 拍。

试了"把组数 32 → 64（2 KB → 4 KB）"，`icache_axi.v` 只改位宽与切片（tag 22→21 位、
set 5→6 位、index 9→10 位），**不新增任何逻辑**。

**效果（同镜像 20 迭代）**：

| 指标 | P14（2 KB） | 4 KB | 变化 |
|---|---|---|---|
| ticks | 7,658,647 | 7,395,351 | **−3.44%** |
| `i_miss` | 18,289 | **8,913** | −51% |
| `if_wait` | 788,983 | 543,931 | −245,052 |
| CoreMark/MHz | 2.6109 | 2.7040 | +3.56% |
| CRC | — | 逐项一致 | — |

**但面积代价是决定性的（受控 A/B，同流程同镜像）**：

| 项 | P14（2 KB） | 4 KB | 变化 |
|---|---|---|---|
| Total LUTs | 13,576 | **14,667** | **+1,091（+8.04%）** |
| ├ as logic | 10,635 | 11,470 | +835 |
| └ as DRAM | 2,941 | 3,197 | +256 |
| Total Registers | 8,639 | **10,016** | **+1,377** |

按三项指标算：**① +3.56%，③（CoreMark/kLUT）0.1923 → 0.1844 = −4.11%。**

**结论：②③ 里的 ③ 净亏，⑨ 收益抵不过面积，否决并回退。**
回退后复测 `ticks` 回到 7,658,647，`icache_axi.v` 与 HEAD 逐字节一致（`git diff` 为空）。

**同时说明"早起动（early restart）"为什么也没做**：即使让 CPU 在目标字到达时就恢复，
它的下一条取指仍落在同一条正在填充的行上、依然不可命中，只会把停顿挪一次；
要真正受益得引入"填充缓冲/渐进可用行"，那是数量级更大的改动。

## 附录 C · 结论

**P14（2.6109）是本轮的最终交付。** 计分窗口内剩下的三块：
- `if_wait` 40.5% —— 只有"更大 I-Cache（净亏）"或"渐进填充行（大改造）"两条路，**都否**；
- store 35.6% —— 已经 2.3 拍/笔，理论下限 2.0 拍，**只剩 0.3 拍（1.2%）**；
- 分支预测 16.1% —— 只能加大 BTB，**③ 净亏**。

继续压 ① 就必须付面积或改流水线结构，而面积是 ③ 的分母。**到此为止是理性选择**，
余下的价值在上板验证（ILA 波形、实板串口）而不是再挤百分比。

---

## 附录 D · 交付前审计：顺手修掉一个预存缺陷

交付前把每个改动逐行过了一遍，发现并修掉一个**在我动手之前就存在**的问题：

`tb_coremark_uart.sv` 里的层级探针直接引用 `soc.core.data_cache.state_q`
（P2' 时代加的 `STORE_PATH` 探针就是如此），但 `tools/run_coremark_ab.py`
**会同时跑 `cache_off` 一侧**——那一侧根本不存在 `data_cache` 实例。

**实测证据**（把测试台临时还原成 HEAD 版本 + `set_switches.py off`）：

```
** Error (suppressible): (vopt-7063) tb_coremark_uart.sv(318):
   Failed to find 'data_cache' in hierarchical name '/soc/core/data_cache/state_q'.
```

因为是 suppressible，仿真仍会跑完，所以这个错误一直没被发现——探针读到 `x`，
`STORE_PATH` 那一行在 `cache_off` 下永远是 0，属于"悄悄失效的证据"。

**修法（两步，都在测试台侧）**：
1. 所有访问 `soc.core.data_cache` 的探针用 `` `ifdef CACHE_ENABLE `` 包起来
   （`STORE_PATH` 与新增的 `DCACHE_PATH` 两处）；缓存关掉时计数保持 0，
   `$display` 照常输出，不引入悬空引用。
2. 测试台开头 `\`include "soc_config.vh"`。原因：这里的 `vlog` 是**按文件**编译单元，
   宏不会从 RTL 文件带到测试台，所以必须自己 include 同一份配置头，
   guard 才会跟着真实构建走（否则 guard 恒假，探针静默失效）。

**验证**：
- `cache_off` + 本测试台：`vopt-7063` 出现次数 **0**（修前为 1 条）。
- `cache_on` + 本测试台：`SCORE_WINDOW` / `DCACHE_PATH` / `STORE_PATH` 全部正常输出，
  `ticks` 与 CRC 与修前完全一致（`7,658,647`，五项 CRC 逐项相同）。
- 全量回归重跑：单元 5/5、ISA 15/15、ram 40/40、halt-reset 5/5、
  IFU 引擎 20/20、dcache PASS、icache PASS。

另外清掉了调查期间临时加的 `HI_READ` 调试打印与 `hi_first` 计数器
（一次性排查用，不应留在交付里）；`ADDR_REGION`/`HI_SPLIT`/`MISPRED_MIX`
三条分桶统计保留，它们是可复用的测量手段。
