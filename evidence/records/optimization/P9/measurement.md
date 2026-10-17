# P9 · 访存完成改在响应拍报出（2026-10-18）

> 结论：**ticks −10.67%**，CoreMark/MHz **1.8622 → 2.0843（+11.93%）**，
> 面积只 **+40 LUT（+0.31%）**、触发器 **零增量**。
> 交付跑分：640 迭代、ticks **307,055,517**、11.37 s、`Correct operation validated`；
> 27 MHz 与 50 MHz 约束均 **All Constraints Met**（0 失败端点）。
> 证据等级：仿真实测（同镜像 A/B）+ 单元测试 + ISA 15/15 + PDS 真实实现产物。

---

## 1. 先纠正一条错误判断（记录下来免得下次再走弯路）

P8 之后我曾判断"可以在 `COMPLETE` 拍同时受理下一条访存，低风险拿 12.7%"。**这是错的**：

```verilog
// pangoriscv.v:120
assign op_valid = rst_n && ex_valid && is_memory && !issued && !local_fault;
// pangoriscv.v:151
if(!rst_n || ex_leave) issued<=0;
```

在 A 指令的 `COMPLETE` 拍，EX 里住的仍是 A（`is_memory=1`、`issued=1`），所以
`op_valid=0` —— LSU 当拍**看不到**下一条访存（单发射，B 还在 ID）。即便看到，
`ex_leave` 的优先级也会清零 `issued`，导致重发。

真正能拿的收益只有一条：**把"报完成"这一拍本身去掉**。

## 2. 依据（P8 之后实测，20 迭代窗口 12,651,176 拍）

```
MEM_OPS  ops=1600800 ld=1312889 st=287911
LSU_PATH empty=7607509 request=490318 wdata=575822 rdwait=2085025 wrwait=291702 complete=1600800
EX_OCCUPANCY ex_busy=5049792 ex_mem_post=3442867 ex_div_busy=6125 lsu_nonidle=5043667
```

| 事实 | 含义 |
|---|---|
| `complete == 访存次数 == 1,600,800` | 每笔访存**恰好 1.0 拍**停在 COMPLETE |
| `ex_busy − ex_mem_post − div = 1,600,800` | 独立计数吻合，两处互相印证 |
| EX 占用率 `(retires+ex_busy)/cycles = 91.6%` | 仍是 EX 瓶颈，砍掉这拍能近似 1:1 变总周期 |
| 一笔命中 load 占 EX 三拍 | T0 受理+发请求 → T1 等结果 → **T2 COMPLETE/退休** |

## 3. 改动（只动 `rtl/core/lsu_axi.v`，CPU 侧一行未改）

### 3.1 `done_valid` 改为"响应拍或 COMPLETE 拍"组合产生

```verilog
wire rsp_fire=(state==READ_WAIT)&&eng_rsp_valid&&eng_rsp_ready;
wire b_fire  =(state==WRITE_WAIT)&&eng_b_valid&&eng_b_ready;
assign done_valid=rst_n && (state==COMPLETE || rsp_fire || b_fire);
```

### 3.2 结果与故障在响应拍组合可用（寄存器只作保持）

```verilog
wire [31:0] load_now=extend_load(eng_rsp_data,address_q[1:0],size_q,unsigned_q);
assign load_value=rsp_fire ? (eng_rsp_resp==0 ? load_now : 32'd0) : load_value_q;
assign fault     =rsp_fire ? (eng_rsp_resp!=0) : b_fire ? (eng_b_resp!=0) : fault_q;
```

`load_value` / `fault` 由 `output reg` 改为 `output wire` + 内部 `_q` 触发器
（端口名与位宽不变，实例化不受影响；触发器数量因此**恰好不变**）。

### 3.3 响应后直接回 EMPTY，但**保留 COMPLETE 作为反压保持态**

```verilog
READ_WAIT: if(eng_rsp_valid) begin
    fault_q<=eng_rsp_resp!=0;
    load_value_q<=extend_load(eng_rsp_data,address_q[1:0],size_q,unsigned_q);
    state<=done_ready?EMPTY:COMPLETE;      // 没被接走就停在 COMPLETE 保持
end
WRITE_WAIT: if(eng_b_valid) begin
    fault_q<=eng_b_resp!=0;
    state<=done_ready?EMPTY:COMPLETE;
end
```

**这是硬性协议，不是优化**：`tb_lsu_axi.sv` 的 `complete()` 会刻意压住 `done_ready`
四拍，要求 `done_valid`/`load_value`/`fault` 全程稳定。保留 COMPLETE 分支后，
响应拍组合为高 → 未被接走则下一拍进 COMPLETE 继续保持 → 握手才回 EMPTY，反压语义不变。

`bad_access`（非对齐）仍走 `EMPTY → COMPLETE`（不发请求），未动。

## 4. 20 迭代 A/B（同镜像 `perf_on`，两侧只差 `lsu_axi.v`，基线 `HEAD`）

| 指标 | 基线（P8） | 本轮（P9） | 变化 |
|---|---|---|---|
| **ticks** | 10,733,373 | **9,588,579** | **−10.67%** |
| cycles | 12,651,176 | 11,499,752 | −9.10% |
| IPC | 0.5173 | **0.5770** | +11.5% |
| **`LSU complete`** | 1,600,800 | **0** | **归零** |
| `ex_mem_post` | 3,442,867 | 2,157,864 | −1,284,003 |
| `ex_busy` | 5,049,792 | 3,795,257 | −1,254,535 |
| 五项 CRC | — | 逐项相同 | 架构等价 |
| traps / faults | 0 / 0 | 0 / 0 | — |

**归因闭环**：`complete` 从 1,600,800 精确归零，`ex_busy` 掉 1.255 M，
总周期掉 1.151 M（**转化率 92%**）。`rdwait`/`wdata` 未变差
（`rdwait` 从 2,085,025 升到 2,207,632 是因为同样的时间里多跑了 3 万次 load，
单位值 1.59 → 1.64，属正常）。

## 5. 交付跑分（镜像 `score640`，640 迭代）

```
每迭代 ticks = 9,588,579 / 20 = 479,429
N ≥ ceil(10.5 × 27e6 / 479,429) = 592   → 取 640（11.37 s）
```

```
Total ticks      : 307055517
Total time (secs): 11
Iterations/Sec   : 56
Iterations       : 640
seedcrc          : 0xe9f5
[0]crclist       : 0xe714
[0]crcmatrix     : 0x1fd7
[0]crcstate      : 0x8e3a
[0]crcfinal      : 0x382f
Correct operation validated. See readme.txt for run and reporting rules.
```

| 项 | 值 |
|---|---|
| ticks / cycles / retires | 307,055,517 / 308,852,640 / 185,284,697 |
| 每迭代指令 | 289,507（与基线 289,508 一致 → 同一工作负载） |
| IPC | **0.5999** |
| **CoreMark/MHz** | **2.0843** |
| traps / faults | 0 / 0 |

> `crcfinal` 随迭代数变化：20→0x4983，400→0x25b5，512→0xdfc8，576→0x7b65，640→**0x382f**。
> 官方只校验 list/matrix/state（0xe714/0x1fd7/0x8e3a，与迭代数无关）。

## 6. PDS 实现（同一份源码 + 同一份 `score640` 镜像）

| 约束 | 结果 | Setup WNS | Hold WHS | 失败端点 | Total LUTs |
|---|---|---|---|---|---|
| 37.037 ns（27 MHz，交付） | **All Constraints Met** | **+16.231 ns** | **+0.068 ns** | **0 / 52,260** | **13,099** |
| 20 ns（50 MHz，过约束） | **All Constraints Met** | **+3.191 ns** | **+0.182 ns** | **0 / 52,292** | 13,181 |

- 27 MHz 快角：setup +23.829 / hold +0.046，均 0 失败
- Total Registers **8,639**（P7/P8/P9 完全相同）
- 交付位流 `pangoriscv_i640.sbit`，3,791,112 B，
  SHA256 `27E406246A1ED89AC9E2F889238419EFD970EA30A7A79912770390A412CA1B5E`

**关键结论：把完成报出提前一拍，50 MHz 依然收敛（余量 +3.191 ns）。**
P9 原本最担心"缓存数据 → 符号扩展 → 寄存器写回"这条组合路径会吃掉频率余量，
实测没有：综合把 `extend_load` 与随后的写回选择合并得很好，27 MHz 的 setup 余量
反而从 P8 的 +13.398 ns 升到 **+16.231 ns**（PnR 差异，但至少没有恶化）。

**复现性**：同一组参数重跑，slack 与失败端点数完全一致，但 `.sbit` 的 SHA256 不同
（Pango 位流容器含非确定性元数据）。时序与资源可复现，位流字节不可复现。

## 7. 资源代价（受控 A/B：同流程、同镜像、仅 `lsu_axi.v` 不同）

| 项 | 基线 `HEAD`（P8） | 本轮（P9） | 变化 |
|---|---|---|---|
| Total LUTs | 13,059 | **13,099** | **+40（+0.31%）** |
| ├ as logic | 10,374 | 10,414 | +40 |
| └ as DRAM | 2,685 | 2,685 | 0 |
| Total Registers | 8,639 | 8,639 | **0** |

触发器零增量是设计使然：`load_value`/`fault` 原来就是寄存器，只是改成
"组合输出 + 内部 `_q` 保持"，没有新增状态。

## 8. 正确性与回归

| 门 | 结果 |
|---|---|
| `run_unit_tests.py --case all` | **5/5 PASS**（`lsu_axi` 的四拍反压保持是本轮最关键的一条） |
| `run_isa_e2e.py --cases all` | **15/15 PASS**（含 load/store 故障陷入，故障现在早一拍报出） |
| CoreMark 五项 CRC | 与基线逐项相同；交付跑分 `Correct operation validated` |
| `run_ram_tests.py --seeds 20` | 40/40 PASS |
| `run_ifu_engine_tests.py --seeds 20` | 20/20 PASS |
| `run_halt_reset_tests.py` | 5/5 PASS |
| `run_dcache_tests.py` | PASS |

### 8.1 测试台的探针同步（已知坑：探针必须跟 RTL 对齐）

`tb/integration/tb_coremark_uart.sv` 里统计 LSU 故障的那条诊断探针原本写死
`soc.core.lsu.state==3'd5`（COMPLETE）。改完后故障在 `READ_WAIT(3)`/`WRITE_WAIT(4)`
就报出，探针已放宽为 `(state==3||state==4||state==5) && done_valid && fault`，
否则该诊断行会在改动后静默变 0（不影响 PASS/FAIL，但会丢掉证据）。

`tb_lsu_axi.sv` / `tb_lsu_axi_ram.sv` **无需修改**：反压语义没变，四拍稳定性检查原样通过。

## 9. 累计成绩

| 阶段 | CoreMark/MHz | LUT | CoreMark/kLUT |
|---|---|---|---|
| S0 基线（store 优化前） | 1.3054 | 12,572 | 0.1038 |
| P2' store 后台排空 B | 1.4342 | 12,622 | 0.1136 |
| P7 取指吞吐 | 1.6815 | 13,018 | 0.1292 |
| P8 访存快发 | 1.8622 | 13,059 | 0.1426 |
| **P9 完成改在响应拍（本版）** | **2.0843** | **13,099** | **0.1591** |

- 相对 P8：**+11.93%**，面积 **+0.31%**
- 相对 S0：**+59.67% CoreMark/MHz**、**+53.24% CoreMark/kLUT**，面积仅 **+4.19%**

## 10. 复现命令

```powershell
$py = "<Python 3.10>"; $tc = "<xpack>/bin"

python tools\set_switches.py on          # 跑分/PDS 前打开，结束必须 off

# 单元 + ISA
python sim\run_unit_tests.py --case all
python tools\run_isa_e2e.py --cases all --toolchain-bin $tc --prefix riscv-none-elf- `
  "--extra-flag=-march=rv32im_zicsr" --modelsim "<ModelSim>"

# 20 迭代 A/B（基线 = HEAD，只替换 lsu_axi.v）
python tools\run_fetch_ab.py --baseline-rev HEAD --files rtl/core/lsu_axi.v --sides both `
  --image-dir build\native_software\coremark\performance\perf_on --max-cycles 40000000

# 交付跑分（迭代数按 §5 重算）
python tools\build_native_software.py coremark --iterations 640 --mode performance `
  --cpu-mhz 27 --toolchain-bin $tc --prefix riscv-none-elf- `
  "--extra-flag=-march=rv32im_zicsr" --tag score640
python tools\run_fetch_ab.py --baseline-rev HEAD --files rtl/core/lsu_axi.v --sides work `
  --image-dir build\native_software\coremark\performance\score640 `
  --max-cycles 500000000 --out build\score640_run

# PDS（务必在 run 目录里启动）
$env:PANGO_NATIVE_PNR_EXTRA = "-fix_hold_violation -fix_hold_violation_threshold 300 " +
  "-fix_hold_violation_threshold_for_clk_tree 200 " +
  "-fix_hold_violation_threshold_for_clock_path_cross_srb 200 " +
  "-fix_hold_violation_iterations 600 -max_hold_violated_paths_num 8000 " +
  "-groute_seed 41 -gplace_seed 41"
cd "<repo>/firmware/code/build/pango_native"; pds_shell.exe -file "...\build.tcl"

# 资源受控 A/B
python tools\stage_baseline_files.py build\p9_res_stage HEAD rtl/core/lsu_axi.v
```

## 11. 剩余可挖（按性价比，供下一轮参考）

| 方向 | 估计收益 | 风险 | 说明 |
|---|---|---|---|
| store 的 W 拍 2→1 拍（`wdata` = 2.0/笔 store） | −2.3% | 中 | 要动 AXI 写引擎内部流水 |
| `request` 退路（0.44/笔访存） | −3~4% | 中 | 要缩短 dcache `ST_WR_DRAIN` 的排空时间 |
| `rdwait` 超出 1 拍的部分（缺失/旁路） | −3~4% | 中 | 约 1% 的 load 缺失 + MMIO 旁路 |
| RAS 返回地址栈 | −1~2% | 低 | `mispred` 3.89 M 里 JALR 返回占相当比例，面积小 |
| I-Cache 2 KB→4 KB | −2% | 低 | +约 2 K LUT，会拉低③ |

**已经到顶的部分**：`complete`/`request`/访存受理这条主链基本挖干净了
（每笔访存从 P8 前的 3.15 拍 LSU 占用降到现在的 ~1.6 拍）。
再往下要动写引擎或缓存容量，收益都是个位数百分比且要付面积/时序代价。
