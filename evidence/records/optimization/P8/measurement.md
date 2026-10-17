# P8 · 访存快发：削掉 LSU 的一次纯往返（2026-10-18）

> 结论：**总周期 −8.39%、ticks −9.71%**，CoreMark/MHz **1.6815 → 1.8622（+10.75%）**，
> 而面积只 **+41 LUT（+0.31%）**、触发器 **零增量**。
> 交付跑分：576 迭代、ticks **309,304,812**、11.46 s、`Correct operation validated`；
> 27 MHz 与 50 MHz 约束均 **All Constraints Met**（0 失败端点）。
> 证据等级：仿真实测（同镜像 A/B）+ 单元测试 + ISA 15/15 + PDS 真实实现产物。

---

## 1. 依据：先量准，再动手

`lsu_axi` 现行状态机（读/写共用）：`EMPTY → REQUEST → READ_WAIT|WRITE_DATA → … → COMPLETE`。
`REQUEST` 的唯一作用是"把地址先存进寄存器，下一拍再问引擎"。

新增 TB-only 探针 `LSU_PATH`（`tb/integration/tb_coremark_uart.sv`，按 `soc.core.lsu.state`
逐状态计数，写法与已有 `STORE_PATH` 一致），20 迭代基线：

```
MEM_OPS     ops=1576618 ld=1288707 st=287911
LSU_PATH    empty=7524515 request=1852431 wdata=575822 rdwait=1988053 wrwait=291676 complete=1576618
EX_OCCUPANCY ex_busy=6290725 ex_mem_post=4707982
```

| 事实 | 含义 |
|---|---|
| `complete == ops`（1,576,618） | 每次访存在 COMPLETE 恰好停 1 拍，符合设计 |
| **`request` = 1,852,431 → 1.175 拍/访存** | 这条纯开销每访存至少 1 拍，超出部分才是真正的"引擎忙" |
| `empty` = 7,524,515 / 13,809,115 | LSU 空闲仅 54.5%，其余时间都在走流程 |
| EX 占用 ≈ retires + ex_busy = 12.76 M / 13.81 M = **92.4%** | **EX 是瓶颈**，削 LSU 占用能 1:1 变成总周期下降 |

所以理论收益 = 1,576,618 拍 / 13,809,115 = **11.4%**。

---

## 2. 改动（只动 `rtl/core/lsu_axi.v`，端口列表不变）

**快发**：`EMPTY` 拍就把引擎请求直接拉起来，若引擎当拍收下就跳过 `REQUEST`。

```verilog
wire fast_issue=(state==EMPTY)&&op_valid&&!bad_access;
assign eng_req_valid=rst_n && ((state==REQUEST) || fast_issue);
assign eng_req_write=(state==REQUEST)?store_q   :is_store;
assign eng_req_addr =(state==REQUEST)?address_q :address;
assign eng_req_size =(state==REQUEST)?size_q    :access_size;
```

`EMPTY` 分支里按握手结果决定去向：

```verilog
if(bad_access)                                state<=COMPLETE;
else if(eng_req_valid && eng_req_ready)       state<=is_store?WRITE_DATA:READ_WAIT;  // 快发命中
else                                          state<=REQUEST;                        // 引擎忙，落回原路
```

三个要点：

1. **`REQUEST` 保留**为"引擎当拍没收下"的兜底（数据 Cache 还在排空 B、正在填充等），
   所以功能与原来逐位等价，只是常见路径少了一拍。
2. 分支判断用输入 `is_store` 而不是 `store_q`——`store_q` 在本拍末尾才赋值。
3. `eng_rsp_ready` / `eng_b_ready` / `done_valid` / `op_ready` 的表达式**一行未改**；
   `address_q/size_q/unsigned_q` 仍在 `EMPTY` 拍锁存，`extend_load` 与写数据通路照旧。

---

## 3. 20 迭代 A/B（同镜像 `perf_on`，两侧只差 `lsu_axi.v`，基线 `HEAD`）

| 指标 | 基线 | 本轮 | 变化 |
|---|---|---|---|
| **ticks** | 11,887,687 | **10,733,373** | **−9.71%** |
| cycles | 13,809,115 | 12,651,176 | −8.39% |
| IPC | 0.4686 | **0.5173** | +10.4% |
| **`LSU request`** | 1,852,431 | **490,318** | **−1,362,113** |
| `LSU complete` | 1,576,618 | 1,600,800 | 访存数随吞吐略增 |
| `ex_mem_post` | 4,707,982 | **3,442,867** | **−1,265,115** |
| `ex_busy` | 6,290,725 | 5,049,792 | −1,240,933 |
| 五项 CRC | — | 逐项相同 | 架构等价 |
| traps / faults | 0 / 0 | 0 / 0 | — |

**归因闭环**：`request` 掉了 1.362 M（正是理论的 1.577 M 减去真实引擎等待），
总周期跟着掉 1.158 M——**转化率 85%**，与"EX 占用率 92.4%"的推断一致。
`request` 仍剩 490,318 拍，就是那些引擎确实忙的场合，兜底路径在正常工作。

---

## 4. 交付跑分（镜像 `score576`，576 迭代）

迭代数按新速度重算（不能沿用 512）：

```
每迭代 ticks = 10,733,373 / 20 = 536,669
N ≥ ceil(10.5 × 27e6 / 536,669) = 529   → 取 576（11.46 s）
```

```
Total ticks      : 309304812
Total time (secs): 11
Iterations/Sec   : 49
Iterations       : 576
seedcrc          : 0xe9f5
[0]crclist       : 0xe714
[0]crcmatrix     : 0x1fd7
[0]crcstate      : 0x8e3a
[0]crcfinal      : 0x7b65
Correct operation validated. See readme.txt for run and reporting rules.
```

| 项 | 值 |
|---|---|
| ticks / cycles / retires | 309,304,812 / 311,106,054 / 166,754,299 |
| 每迭代指令 | 289,504（与基线 289,508 一致 → 同一工作负载） |
| IPC | **0.5360** |
| **CoreMark/MHz** | **1.8622** |
| traps / faults | 0 / 0 |

> `crcfinal` 随迭代数变化（跨迭代累积）：20→0x4983，400→0x25b5，512→0xdfc8，576→**0x7b65**。
> 官方只校验 list/matrix/state（0xe714/0x1fd7/0x8e3a，与迭代数无关）。

---

## 5. PDS 实现（同一份源码 + 同一份 `score576` 镜像）

| 约束 | 结果 | Setup WNS | Hold WHS | 失败端点 | Total LUTs |
|---|---|---|---|---|---|
| 37.037 ns（27 MHz，交付） | **All Constraints Met** | **+13.398 ns** | **+0.058 ns** | **0 / 52,404** | **13,059** |
| 20 ns（50 MHz，过约束） | **All Constraints Met** | **+2.557 ns** | **+0.061 ns** | **0 / 52,388** | 13,139 |

- 27 MHz 快角：setup +21.293 / hold +0.043，均 0 失败
- Total Registers **8,639**（与 P7 完全相同）
- 交付位流 `pangoriscv_i576.sbit`，3,791,112 B，
  SHA256 `D3C603C7058FE49E867085E1D358CADF9F2033B8F131FC89A4DE54ADAF0FD4D2`

**hold 收敛过程**：第一次 27 MHz 全流程 hold 有 1 个端点 −0.029 ns（D-Cache `tag_mem`
LUTRAM 写口，跨时钟树分支偏斜）。把 hold 目标提到 300 ps（时钟树那一档的合法上限是
200 ps）并换 `-groute_seed/-gplace_seed 41` 后收敛到 +0.058 ns。
**没有任何时序例外**：无 false path、无 multicycle、未降时钟周期。

**复现性说明**：同一组参数重跑，slack 与失败端点数完全一致（+13.398/+0.058/0 与
52,404 端点），但 `.sbit` 的 SHA256 每次不同（Pango 位流容器含非确定性元数据）。
所以**时序与资源可复现，位流字节不可复现**——归档时必须同时记录 SHA256 与该次运行的
时序汇总。

---

## 6. 资源代价（受控 A/B：同流程、同镜像、仅 `lsu_axi.v` 不同）

用 `platform/pango_native/resource_check.tcl`（与 `build.tcl` 同前端，停在 `device_map`）：

| 项 | 基线 `HEAD` | 本轮 | 变化 |
|---|---|---|---|
| Total LUTs | 13,018 | **13,059** | **+41（+0.31%）** |
| ├ as logic | 10,333 | 10,374 | +41 |
| └ as DRAM | 2,685 | 2,685 | 0 |
| Total Registers | 8,639 | 8,639 | **0** |

**这是一个纯组合改动**：只多了一组 2:1 选择器，没有新增触发器。

---

## 7. 正确性与回归

| 门 | 结果 |
|---|---|
| `run_unit_tests.py --case all` | **5/5 PASS** |
| `run_isa_e2e.py --cases all` | **15/15 PASS**（见 §7.1） |
| CoreMark 五项 CRC | 与基线逐项相同；交付跑分 `Correct operation validated` |
| `run_ram_tests.py --seeds 20` | **40/40 PASS**（真实 LSU + 数据引擎） |
| `run_ifu_engine_tests.py --seeds 20` | 20/20 PASS |
| `run_halt_reset_tests.py` | **5/5 PASS**（含"飞行中读/写时 halt/reset"） |
| `run_dcache_tests.py` | PASS |

### 7.1 ISA 用例 7 的相位脆弱性（本轮唯一一次红灯，已修测试而非改设计）

加上快发后，用例 7 报 `x2=0 want 1 (mcycleh after wrap)`。查清后结论是**设计正确、
用例脆弱**：

```
csrw 0xb00, -1     ; mcycle = 0xffffffff，写入在 retire 那一拍生效
csrrs x2, 0xb80    ; 读 mcycleh，期望 1（进位）
```

`csr_native.v` 里 `ncy=mcycle+1` 与写入是同一组赋值：写入拍不递增，**下一拍**才进位。
所以"写完立刻读高位"得到 0 是正确行为；要读到 1 必须至少隔**一拍**。
原本这条用例能过，是因为恰有一条取指气泡落在两条 CSR 之间；任何流水线时序变化都可能
把气泡挤掉——这次就是被挤掉了。

修法：在两条 CSR 之间插入一条 `nop`，并把这个前提写进注释
（`tests/isa_e2e/isa_e2e.S`）。**这不降低检查强度**：进位仍然被验证，而且不再依赖
"气泡恰好落在这里"。参考模型的期望 `x2==1` 未改动。

---

## 8. 累计成绩

| 阶段 | CoreMark/MHz | LUT | CoreMark/kLUT |
|---|---|---|---|
| S0 基线（store 优化前） | 1.3054 | 12,572 | 0.1038 |
| P2' store 后台排空 B | 1.4342 | 12,622 | 0.1136 |
| P7 取指吞吐 | 1.6815 | 13,018 | 0.1292 |
| **P8 访存快发（本版）** | **1.8622** | **13,059** | **0.1426** |

- 相对 P7：**+10.75%**，面积 **+0.31%**
- 相对 S0：**+42.65%**，CoreMark/kLUT **+37.34%**

---

## 9. 复现命令

```powershell
$py = "<Python 3.10>"; $tc = "<xpack>/bin"

# 0) 打开三开关（结束必须还原）
python tools\set_switches.py on

# 1) S0 测量（TB-only 探针）
python tools\run_fetch_ab.py --baseline-rev HEAD --files rtl/core/lsu_axi.v --sides work `
  --image-dir build\native_software\coremark\performance\perf_on --max-cycles 40000000

# 2) 门 1/2
python sim\run_unit_tests.py --case all
python tools\run_isa_e2e.py --cases all --toolchain-bin $tc --prefix riscv-none-elf- `
  "--extra-flag=-march=rv32im_zicsr" --modelsim "<ModelSim>"

# 3) 20 迭代 A/B
python tools\run_fetch_ab.py --baseline-rev HEAD --files rtl/core/lsu_axi.v --sides both `
  --image-dir build\native_software\coremark\performance\perf_on --max-cycles 40000000

# 4) 交付跑分（迭代数按 §4 重算）
python tools\build_native_software.py coremark --iterations 576 --mode performance `
  --cpu-mhz 27 --toolchain-bin $tc --prefix riscv-none-elf- `
  "--extra-flag=-march=rv32im_zicsr" --tag score576
python tools\run_fetch_ab.py --baseline-rev HEAD --files rtl/core/lsu_axi.v --sides work `
  --image-dir build\native_software\coremark\performance\score576 `
  --max-cycles 500000000 --out build\score576_run

# 5) PDS（务必在 run 目录里启动，见 §10）
$env:PANGO_NATIVE_PNR_EXTRA = "-fix_hold_violation -fix_hold_violation_threshold 300 " +
  "-fix_hold_violation_threshold_for_clk_tree 200 " +
  "-fix_hold_violation_threshold_for_clock_path_cross_srb 200 " +
  "-fix_hold_violation_iterations 600 -max_hold_violated_paths_num 8000 " +
  "-groute_seed 41 -gplace_seed 41"
cd "<repo>/firmware/code/build/pango_native"    # 全新空目录，且必须是当前目录
pds_shell.exe -file "<repo>/firmware/code/platform/pango_native/build.tcl"

# 6) 资源受控 A/B
python tools\stage_baseline_files.py build\p8_res_stage HEAD rtl/core/lsu_axi.v
#    然后 RESOURCE_BASELINE_DIR 指向 build\p8_res_stage 跑 resource_check.tcl
```

---

## 10. 本轮新增的三个坑（除 P7 的 9 条之外）

| 坑 | 现象 | 应对 |
|---|---|---|
| **在 PDS 的 run 目录里删它自己** | `workdir` 设成目标目录再 `Remove-Item -Recurse` 失败，PDS 于是打开**残留旧工程**继续跑；更糟的是若先前 `cd` 到了源码根，产物会写进 `firmware/code/`（`generate_bitstream/` 等未忽略目录） | 删目录的进程 `cwd` 必须在**父目录**；启动 PDS 用**独立一次调用**且 `workdir` 就是 run 目录。跑完检查 `git status` 有没有多出未跟踪目录 |
| **`-fix_hold_violation_threshold_for_clk_tree` 合法范围 0~200 ps** | 传 300 直接 `E: Flow-0186 ... legal value range is "0 ~ 200"`，流程中止 | 时钟树那一档用 ≤200，其余两档可更高 |
| **`.sbit` 字节不可复现** | 同一组 seed 重跑，slack/端点完全一致，但 SHA256 不同 | 归档时同时记录该次运行的时序汇总；不要用"位流哈希一致"证明可复现 |
