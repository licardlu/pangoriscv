# P18 · 修复 R01/R02/R04 后重新出分并上板（2026-10-19）

> ## ✅ 成绩有效性
> 本文件中的分数**已在真实开发板上实测**，与仿真逐周期一致。
> 板测原始串口抓取：`board_uart_score.txt`（691 B）。

---

## 1. 这一轮做了什么

上一轮（P17）交付的位流只含 **R03**（LRU 修复）。之后独立复核提出的另外三处
RTL 缺陷（R01/R02/R04）在 `f8c2b43` 中修好，但当时按"不重新跑分"的要求没有重建位流，
造成**源码 ≠ 位流**。本轮把三者对齐并重新出分：

| 修复 | 内容 |
|---|---|
| **R01** | 数据 RAM 之外的 store 不再提前应答（`DATA_RAM_LIMIT=0x1000_4000`），DECERR 能上报为 store fault |
| **R02** | MMIO 的 byte/halfword 读带真实 `ARSIZE`，不再触发 SLVERR |
| **R04** | 2-bit 预测器真正饱和（`11` 不再被打回 `10`） |

## 2. 跑分（768 迭代，仿真 + 上板）

| 项 | P17（仅 R03） | **P18（R01+R02+R03+R04）** |
|---|---|---|
| ticks（仿真） | 287,030,751 | **284,997,892** |
| ticks（**板上实测**） | 287,030,751 | **284,997,892** |
| cycles | 288,817,154 | 286,784,100 |
| retires | 222,179,042 | 222,179,135 |
| IPC | 0.7693 | **0.7747** |
| 用时 | 10.631 s | **10.555 s** |
| **CoreMark/MHz** | 2.6757 | **2.6948** |
| 五项 CRC | e9f5/e714/1fd7/8e3a/3c53 | **完全相同** |
| validated / traps / faults | True / 0 / 0 | **True / 0 / 0** |

迭代下限 `ceil(10.5×27e6/371,091) = 764`，实取 768 → 10.555 s ≥ 10 s ✓。

**仿真与上板再次逐周期一致**（284,997,892 对 284,997,892）。

## 3. 实现（PDS 27 MHz）

| 项 | 值 |
|---|---|
| All Constraints Met | ✅ |
| Setup(Slow) / Hold(Slow) | **+15.201 ns / +0.024 ns**（0 失败端点，`multiseed_summary.csv`） |
| 端点 | 54,333 |
| LUT（device_map） | **13,503** |
| FF | 8,507 |
| **CoreMark/kLUT** | **0.1995**（2.6948 / 13.503） |
| 位流 | 3,791,112 B，SHA256 `6C5D819C6DB7DA00D4C874B543B49DB76D9F4572596DF3F2B67010AE657CAF65` |

> hold 余量只有 **+0.024 ns**，是本设计最紧的一项；上板已通过，但属于需要盯的风险点。

## 4. 上板条件

| 项 | 值 |
|---|---|
| 板卡 | Pango PG2L100H（MES2L676-100HP V1.2），27 MHz |
| 下载线 | Pango USB Cable II（D2XX），JTAG；扫描链 `PG2L100H` / ID `0x00602899` |
| 下载方式 | **SRAM（易失）**；烧写后 `done bit: 1` |
| 串口 | Silicon Labs CP210x（COM34），115200 8N1 |
| 工具链 | xPack GCC 15.2.0（`riscv32-unknown-elf-gcc` 前缀，`-dumpmachine` 报 `riscv-none-elf`） |

## 5. 证据文件

| 文件 | 内容 |
|---|---|
| `board_uart_score.txt` | 板测原始串口输出 691 B |
| `board_program_tcl.log` | `cfg_program succeed, 3.8` |
| `board_program_stdout.txt` | 烧写客户端完整输出 |
| `pds_27mhz_full/` | 位流 + `multiseed_summary.csv` + `report_timing.rtr` + 各阶段 log |

## 6. 结论与下一步方向

- 现状：**2.6948**，距单发射物理上限 **3.457**（`1e6/289,296`）还有 0.76。
- 已量化的剩余预算（P16 窗口，占全部周期）：
  **store 等 B 响应 5.1%**、`if_wait` 8.6%、分支预测 3.7%、load 占用 1.4%。
- 最大杠杆是 **2 条写队列**（让 D-Cache 在等上一笔 B 时仍能受理下一笔 store）。
  机制已定位：LSU 在 REQUEST 状态累计 14.77M 拍等待，其中 **99.1% 是 store**，
  因为 P14 让 store 在 W 握手就完成，而缓存还在 `ST_WR_DRAIN` 等 B。
- `-O3` 已排除：程序 RAM 只有 16 KiB，`-O3` 溢出 5,220 B（见 mistakes-log §8.2）。

---

## 7. 下一轮（P19）实施方案：把数据 RAM 的 store 变成"受理即完成 + 单条后台缓冲"

> 这是目前**最大且已量化**的杠杆：store 等 B 响应占全部周期 **5.1%**。
> 收益预估 **+5%**（2.6948 → 约 2.83），改动集中在 `dcache_axi.v`，不碰 LSU。

### 7.1 为什么现在会等

时间线（`early_q=1` 的数据 RAM store）：

```
受理(1 拍) → ST_WR_REQ 等 LSU 给 W(1~2 拍) → 回答 CPU(early_now，b_valid)
           → 引擎发 AW/W、等 B(约 5 拍，期间 state=ST_WR_DRAIN)
           → 这 5 拍里 req_ready 是低的 → 下一笔 store 的请求被挡住
```

实测：LSU 在 REQUEST 状态累计等待 **14.77M 拍**，其中 **99.1% 是 store**
（`LSU_REQ_SPLIT request_store=14,636,166` / `request_load=130,381`），
平均每笔 store 等 **1.35 拍** × 1088 万笔 = 5.1% 的总周期。

根因是 P14 让 store 在 **W 握手**就完成并退休，CPU 往前跑了，
但 D-Cache 仍独占写引擎直到 B 返回。

### 7.2 方案（不动 LSU）

对 `req_write && early_q`（**数据 RAM 范围内、不可能失败**的 store）：

1. `ST_IDLE` 受理 → 进新状态 `ST_WR_POST`（替代 `ST_WR_REQ`）。
2. `ST_WR_POST`：等 `w_valid`，把 `{addr,data,strb,size,id,cached,hit,way,set,word}`
   锁进**单条后台缓冲** `pend_*`；同拍推进写通合并（cached hit）；
   **当拍置 `b_valid`/`b_resp=OKAY`** 回答 CPU；`state_q <= ST_IDLE`。
3. 独立的小 FSM 在引擎空闲时把 `pend_*` 发出去（把引擎的 `req_valid`/`w_data`
   从 LSU 源切换为缓冲源），拿到 B 后清 `pend_valid`；B 出错则作废对应缓存行。
4. `pend_valid` 为 1 且又有新的数据 RAM store 到来且引擎未空闲 → 保持
   `req_ready` 为低（背压）。实测 store 间隔约 26 拍、AXI 写约 6 拍，**极少触发**。
5. **顺序保护**：`pend_valid` 期间，任何**非缓存命中**的读（缺失填充 / MMIO）必须
   等 `pend_valid` 清零后再发 AR（保守全序）。缓存命中的读不受影响
   （合并已在第 2 步完成）。
6. MMIO 写（`early_q=0`）**保持原同步路径**，不参与排队，避免外设时序被改。

### 7.3 验收标准（不达标就回退）

- 20 迭代 A/B：**五项 CRC 逐项相同**，ticks 明显下降（目标 −4% 以上）
- `run_unit_tests` / `run_dcache_tests` / `run_isa_e2e` 15/15 / `run_ram_tests` 40/40 /
  `run_halt_reset_tests` 5/5 全绿
- 768 迭代跑分 + PDS + **上板实测**与仿真一致
- 若 `-O3` 那样被容量或其他硬约束挡住，或 CRC 不收敛 → **回退并记录原因**

### 7.4 更远的路（3.5 的必要条件）

`CM/MHz = IPC × 1e6 / 289,296`，单发射上限 **3.457**。若确实要 ≥3.5：

- 必须 **IPC > 1** → 双发射（取指双发 + 双 ALU/双端口寄存器堆），属于微架构重写；
- 或把**每迭代指令数**降到 285,714 以下（−1.2%），但 `-O3` 已被 16 KiB 程序 RAM 否决，
  需先扩程序 RAM（BRAM 成本会拖累 ③）；
- 现实目标：**3.1~3.3**（IPC 0.90~0.95），需要 store 缓冲 + if_wait + 分支预测三项都吃掉。
