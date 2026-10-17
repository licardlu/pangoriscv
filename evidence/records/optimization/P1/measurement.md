# P1 · 周期分诊结果（2026-10-17）

> 目的：在执行任何优化之前，先用实测数据确定周期花在哪。
> 结论：**原计划把"扩 I-Cache"排第一是错的**，真正的瓶颈是**访存通路**。
> 证据等级：仿真实测（20 迭代，perf_on / perf_off 对照）。不是板上数据。

---

## 1. 测量方法

| 项 | 做法 |
|---|---|
| 镜像 | `core_portme.c` 的 `portable_fini()` 打印 `perf_regs` 快照（`-DPERF_DUMP`） |
| 对照 | 同迭代数、不带 `-DPERF_DUMP` 的镜像，用来核对 ticks 扰动 |
| 补充 | 测试台层次探针（**只改 tb，不改 RTL**）：EX 占用分解、访存条数、AXI 事务数 |
| 迭代数 | 20（诊断用；因 `Total time < 10 s`，CoreMark 会报 `Errors detected`，这是**预期**，不是功能错误） |

测试台新增打印（`tb/integration/tb_coremark_uart.sv`）：

```
P <cycle_lo> <instret> <if_wait> <lsu_wait> <i_miss> <d_miss> <ret_cf> <mispred>
EX_OCCUPANCY ex_busy=.. ex_mem_post=.. ex_div_busy=.. lsu_nonidle=..
MEM_OPS ops=.. ld=.. st=..  axi_d_ar=.. axi_d_aw=..
```

---

## 2. 原始数据（20 迭代）

```
P 17006718 6320118 3121268 1560542 17738 4209 1400829 154318
CORE_SUMMARY cycles=17256182 retires=6418312 traps=0 faults=0 uart_chars=745 txd_writes=744 ctrl=1466083 mispred=154553
EX_OCCUPANCY ex_busy=7781444 ex_mem_post=6198639 ex_div_busy=6195 lsu_nonidle=7775249
MEM_OPS ops=1576610 ld=1288696 st=287914  axi_d_ar=194298 axi_d_aw=287914
```

对照组（不带 PERF_DUMP，20 迭代）：`Total ticks 15,323,106` → 带打印 `15,316,450`，差 **0.043%**。
差异来自代码布局变化改变了 I-Cache 映射，**不是打印进了计时区**（`portable_fini` 在 `stop_time()` 之后）。
400 迭代基线（306,415,752 ticks）不受本改动影响，仍是评分基准。

---

## 3. 分解

总周期 17,256,182，退休 6,418,312 → **每指令 2.69 拍**，IPC 0.372。

| 来源 | 周期 | 占总周期 |
|---|---|---|
| **访存：发出后等待** | **6,198,639** | **35.9%** |
| 取指饥饿（ID 就绪但无指令） | 3,121,268 | 18.1% |
| 访存：发出前等待 | 1,560,542 | 9.0% |
| 分支预测失败（×2 拍） | ~309,000 | 1.8% |
| 除法 | 6,195 | 0.04% |
| EX 占用合计 | 7,781,444 | 45.1% |

**关键比例**：每访存操作占用 LSU = 7,775,249 ÷ 1,576,610 = **4.93 拍**。

### 访存为什么这么慢

| 事实 | 含义 |
|---|---|
| `axi_d_aw = 287,914` = store 条数 | **每个 store 都要走完整 AXI 写（AW→W→B）才能退休**（write-through，无写合并） |
| `axi_d_ar = 194,298`，load 1,288,696 条 | **D-Cache 缺失率 15%**，每次缺失 8 拍突发补行 |
| `lsu_nonidle ≈ ex_busy` | 访存通路**从不空闲**，它是饱和资源 |

粗算：store 侧约 2.3~2.9 M 拍，load 缺失侧约 2.3~2.9 M 拍，与实测 6.2 M 吻合。

---

## 4. 两个测量缺陷（必须记录，别再被骗）

| 缺陷 | 表现 | 原因 |
|---|---|---|
| `D_MISS` 少报 46 倍 | 计数 4,209，实际 AXI 读突发 194,298 | `dcache_axi` 的 `miss_pulse` 只在特定状态脉冲，没覆盖全部补行 |
| `LSU_WAIT` 只算一半 | 1,560,542，实际访存等待 7.76 M | 它是 `op_valid && !done_valid`，而 `op_valid` 在 `issued` 置位后立刻拉低 |

**结论：`perf_regs` 的这两个计数不能单独用来定位访存瓶颈**，必须配合 AXI 事务计数（`I_AR/D_AR/D_AW`）或测试台探针。

---

## 4.1 第三次纠正：2,685 个 LUT-as-DRAM 不是 `axi_ram`，是 D-Cache

原计划 P6 认为"16 KiB 数据 RAM 被推成分布式 LUTRAM，强制 BRAM 可省 2,685 LUT"。
**实测（综合后网表按层次归类）证明这条是错的**：

```
256x RAM64X1DP, soc/core/data_cache     ← 全部在这里
```

- 只读程序 RAM（`axi_ram` 的 `WRITE_ENABLE=0` 实例）→ **已经是块 RAM**（DRM）
- I-Cache 数据阵列 → **也是块 RAM**
- **D-Cache 的 `data_mem[0:511]`（2 KiB）→ 分布式 LUTRAM**

原因看 `dcache_axi.v:240-241`：

```verilog
assign rsp_data = (state_q==ST_BYP_RESP) ? rdata_q
                 : data_mem[didx(...)];      // 组合读
```

**D-Cache 是组合读命中路径**（命中 1 拍返回）。块 RAM 不支持组合读，改成 BRAM 就必须加一级寄存 → **每次 D-Cache 命中多 1 拍**。

按实测数据估算代价：每 20 迭代 1,288,696 次 load，命中率约 85% → 约 1.1 M 次命中 → **+1.1 M 拍 ≈ +6.4% 总周期**，换 −2,685 LUT（资源效率 +27%）。

**所以 P6 不是免费的胜利，而是一个明确的交换**：CoreMark/MHz 掉约 6%，CoreMark/LUTs 涨约 27%。
是否值得必须用 A/B 实测后决定，不能想当然。`axi_ram.v` 上的实验属性已回退。

---

## 5. 修正后的优先级

| 原计划 | 修正 | 依据 |
|---|---|---|
| P2 扩 I-Cache 排第一 | **降级**。I-Cache 缺失只有 17,738 次，不是瓶颈 | `i_miss`；代码 13 KB 但热循环小 |
| （原无） | **升为 P2'：store 路径** | 287,914 次 store **全部**走完整 AXI 写（AW→W→B）才能退休，粗算 2.3~2.9 M 拍 |
| （原无） | **升为 P2''：D-Cache 缺失** | 15% 缺失率，194,298 次 8 拍突发补行，粗算 2.3~2.9 M 拍 |
| P6 强制 BRAM | **改成交换实验**，不是白赚 | 见 §4.1：−2,685 LUT 换 +6.4% 周期 |
| P3 load-use 前递 | **降级**。被访存延迟淹没 | `LSU_WAIT` 仅 9%，且测量本身偏小 |
| P4 预测增强 | **保持最低**（1.8%） | `mispred × 2` |
| （原无） | **新增 P7：IFU 取指吞吐** | 取指饥饿 18.1%，与 I-Cache 缺失（0.28%）不匹配，是结构性吞吐限制 |
| P5 提频 | 保持独立 | — |

---

## 6. 下一步（按修正后的顺序）

1. **P2' store 路径**（最大单项，35.9% 里的主要部分）
   - 现状：写命中也要等 AXI 的 B 响应（`dcache_axi.v:252` 注释写明"write-through: applies after a good B"）
   - 方向 A：写命中时立即更新本地副本并退休，AXI 写放进浅写缓冲
   - 方向 B：D-Cache 改写回（dirty 位），把重复写合并
   - **可行性关键**：可缓存区域内的写不会 fault（未映射地址走 error slave，且 D-Cache 用 `req_in_cache` 判断），所以推迟 B 响应在正确性上可行；但必须在报告里写清"store fault 精确性"的边界
   - 风险：中高。必须先跑 ISA e2e + CoreMark CRC 双确认
2. **P2'' D-Cache 扩容**（15% → 5% 以下）
   - `dcache_axi` 已参数化（`SETS`/`WAYS`），改实例参数即可
   - 代价：`data_mem` 是 LUTRAM，容量翻倍 → LUT 增长，必须和资源指标一起权衡
3. **P7 IFU 吞吐**：读 `ifu_axi.v` 的入队/出队握手，确认"是不是每 N 拍只能送一条"，再决定是否改
4. P6 交换实验（可选，看资源指标是否吃紧）
5. 之后才是预测、提频

---

## 7. 复现命令

```powershell
# 工作目录 firmware/code
python tools/build_native_software.py coremark --mode performance --iterations 20 `
  --cpu-mhz 27 --toolchain-bin "<toolchain>\bin" --prefix riscv-none-elf- `
  "--extra-flag=-march=rv32im_zicsr" --define PERF_DUMP --tag perf_on

# 按交付配置 vlog（三开关全开），然后：
vsim -c -do "run -all; quit -f" -l perf_on.log work.tb_coremark_uart `
  "+PROG=<...>/perf_on/program.hex" "+DATA=<...>/perf_on/data.hex" "+MAX_CYCLES=25000000"
```
