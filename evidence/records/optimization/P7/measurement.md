# P7 · IFU 取指吞吐：两笔未完成请求 + I-Cache 背靠背命中（2026-10-18）

> 结论：**总周期 −12.97%、ticks −14.73%**，取指饥饿 `if_wait` 从 3,269,814 拍降到
> **742,122 拍（−77.3%）**，五项 CRC 与基线逐项一致，ISA 15/15 全过。
> 交付跑分：512 迭代、ticks **304,495,134**、11.28 s、`Correct operation validated`；
> 同镜像同迭代数的基线是 ticks 356,993,719 → **CoreMark/MHz 1.4342 → 1.6815（+17.24%）**。
> 27 MHz 交付约束下 **All Constraints Met**（setup WNS +14.127 ns，hold WHS +0.154 ns，
> 0/52,349 失败），位流、资源、时序出自同一份实现。
> 证据等级：仿真实测（同镜像 A/B）+ 单元测试 + ISA 端到端 + PDS 真实实现产物。

---

## 1. 根因（上一轮已定位，本轮用数据闭环）

`ifu_axi.v` 用"同时只有一笔取指请求在飞"的假设给响应配 PC（单份 `req_pc_q`），
`icache_axi.v` 又只在 `IC_IDLE` 受理请求、命中后要停在 `IC_RESP` 一拍。
两者锁步 → **取指供给上限 1 条 / 2 拍 = 0.5 IPC**。

本轮 A/B 把这条推断变成了数字：基线 `if_wait` = 3,269,814 拍，占 15.87 M 周期的 **20.6%**，
与"取指饥饿 18.1%"的分诊结论吻合；改完后只剩 742,122 拍（4.8%）。

---

## 2. 改了什么（只动两个文件）

### 2.1 `rtl/core/ifu_axi.v`：请求登记改 2 深

| 原实现 | 新实现 |
|---|---|
| `state`（1 位）+ `req_pc_q`/`req_pred_q`（各一份） | `pcf0_q`/`pcf1_q`、`pdf0_q`/`pdf1_q`（槽 0 = 最老）+ `ocnt_q`（0..2） |
| 响应固定配"唯一在飞的 PC" | 响应配槽 0，随即 `pcf0_q<=pcf1_q` 前移 |
| 重定向用单标志 `stale_q` 抑制迟到响应 | `stale_cnt_q` **按笔计数**，每笔迟到响应吞一次 |

三个关键细节：

1. **队列表项预留**：`count_q + ocnt_q < DEPTH` 才允许发请求。因此在飞的每一笔都已有队列空位，
   `eng_rsp_ready` 可以**无条件为高**，永远不会出现"已经要了响应却塞不进队列"而丢指令。
2. **同拍既收又发**：出队先移位、再登记新请求（非阻塞赋值后者胜），
   新请求落到 `ocnt_after_pop` 指向的槽，所以"响应与下发同拍"时恰好只留一笔。
3. **重定向累加清空**：`stale_cnt_q <= stale_cnt_q + ocnt_q - rsp_live`，
   同拍有响应当场扣掉，`redirect_valid` 持续多拍也不会把计数抹掉。
   `idle` 也把 `stale_cnt_q==0` 纳入，halt 握手不会在迟到响应未到时误报空闲。

### 2.2 `rtl/core/icache_axi.v`：命中路径受理与响应同拍

```verilog
wire rsp_leaving = (state==IC_RESP) && rsp_valid && rsp_ready;
assign req_ready = rst_n && (state==IC_IDLE || rsp_leaving);
```
`IC_IDLE` / `IC_RESP` 合并到同一个受理分支，输出寄存器在同拍重载，
所以**连续命中 1 拍 1 条**（原来是 2 拍 1 条）。miss 路径（AR/FILL/MISS_RD）原样保留。

---

## 3. A/B 实测（20 迭代，镜像 `perf_on` 两侧完全相同）

基线侧由 `tools/run_fetch_ab.py` 用 `git show 99e8bdb:./…` 取到临时目录编译，**工作区未被改动**。

| 指标 | 基线 `99e8bdb` | 本轮 | 变化 |
|---|---|---|---|
| **Total ticks** | 13,940,928 | **11,887,687** | **−14.73%** |
| cycles | 15,866,750 | 13,809,115 | −12.97% |
| retires | 6,419,341 | 6,471,148 | 采样点差异 |
| IPC | 0.4046 | **0.4686** | +15.8% |
| 每退休指令周期 | 2.4717 | 2.1341 | **−13.66%** |
| `if_wait` | 3,269,814 | **742,122** | **−77.30%** |
| `lsu_wait` | 1,560,772 | 1,560,816 | +0.00% |
| `i_miss` | 17,679 | 18,474 | +4.50% |
| `d_miss` | 4,209 | 4,209 | 0 |
| `ret_cf` | 1,401,059 | 1,401,103 | +0.00% |
| `mispred` | 154,321 | 154,315 | −0.00% |
| traps / faults | 0 / 0 | 0 / 0 | — |
| 五项 CRC | seedcrc/list/matrix/state/final | **逐项相同** | 架构等价 |

**读法**：只有 `if_wait` 大幅下降，`lsu_wait`、`d_miss`、`mispred` 一动没动
——证明收益确实来自取指供给，而不是把别处的等待挪了个位置。
`i_miss` 略升 4.5%（多取了一些随后被冲刷的预测路径行），代价约 0.08% 周期，可忽略。

按 20 迭代折算：**1.4346 → 1.6824 CoreMark/MHz（+17.3%）**。

---

## 4. 交付跑分（512 迭代，镜像 `score512`）

### 4.1 迭代数为什么从 400 提到 512

赛题硬性要求"一次运行实际时间 ≥10 s"。性能提升后 400 迭代会掉到 10 s 以下：

```
每迭代 ticks = 304,495,134 / 512 = 594,717
N ≥ ceil(10.5 × 27e6 / 594,717) = ceil(476.8) = 477
取 512（>477，留 7% 余量）→ 512 × 594,717 / 27e6 = 11.28 s ✓
```

### 4.2 结果

```
Total ticks      : 304495134
Total time (secs): 11
Iterations/Sec   : 46
Iterations       : 512
seedcrc          : 0xe9f5
[0]crclist       : 0xe714
[0]crcmatrix     : 0x1fd7
[0]crcstate      : 0x8e3a
[0]crcfinal      : 0xdfc8
Correct operation validated. See readme.txt for run and reporting rules.
```

| 项 | 值 |
|---|---|
| ticks / cycles / retires | 304,495,134 / 306,299,998 / 148,241,731 |
| 每迭代指令 | 289,534（与基线 289,508 一致 → 同一工作负载） |
| IPC | 0.4840 |
| **CoreMark/MHz**（`iterations/ticks`） | **1.6815** |
| traps / faults | 0 / 0 |
| 五项 CRC | 全部正确，`Correct operation validated` 已打印 |

> `crcfinal` 随迭代数变化（CoreMark 的最终 CRC 是跨迭代累积的），
> 官方只把 `crclist/crcmatrix/crcstate` 与已知表比对；这三项与本轮
> `known_id=3`（"2K performance run parameters"）完全一致，故 `total_errors` 为 0。
> 赛题按整数秒口径读是 512/11/27 MHz ≈ 1.72，按 tick 精确是 **1.6815**；本文一律用后者。

### 4.3 同镜像同迭代数的绝对 A/B（512 迭代，两侧都是有效跑分）

20 迭代 A/B 只能给"比例"，因为短镜像必然触发 ≥10 s 规则。所以基线 `99e8bdb` 也在
**同一份 `score512` 镜像**上跑了一次完整 512 迭代：

| 指标 | 基线 `99e8bdb` | 本轮 | 变化 |
|---|---|---|---|
| ticks | 356,993,719 | **304,495,134** | **−14.71%** |
| cycles | 358,802,946 | 306,299,998 | −14.63% |
| retires | 148,181,914 | 148,241,731 | 采样点 |
| IPC | 0.4130 | **0.4840** | +17.2% |
| **CoreMark/MHz** | **1.4342** | **1.6815** | **+17.24%** |
| `Correct operation validated` | 是 | 是 | 两侧都是有效跑分 |
| **crcfinal** | **0xdfc8** | **0xdfc8** | **完全一致** |

同迭代数下 `crcfinal` 逐位相同，比只看"四项打印值"更强的架构等价证据。

### 4.4 三项数字的完整链条（别再混口径）

| 阶段 | 每迭代 ticks | CoreMark/MHz | 相对上一步 |
|---|---|---|---|
| S0 基线（store 优化前，400 迭代交付） | 766,039 | 1.3054 | — |
| P2' store 后台排空 B | 697,254 | 1.4342 | +9.87% |
| **P7 取指吞吐（本轮）** | **594,717** | **1.6815** | **+17.24%** |
| **累计** | | | **+28.81%** |

**注意**：1.3054 是 **store 优化前**的交付数字。上一轮交接里写的"约 1.434"是折算值，
本轮用 512 迭代实跑确认就是 **1.4342**（预测与实测吻合到小数点后三位）。
所以"本轮提升"要拿 **1.4342 → 1.6815** 来说（+17.24%），不是 1.3054 → 1.6815。

---

## 5. 27 MHz 交付实现（与跑分同一份源码 + 同一镜像 `score512`）

| 项 | 值 |
|---|---|
| Design Summary | **All Constraints Met** |
| Setup (Slow) | WNS **+14.127 ns**，TNS 0，失败端点 **0 / 52,349** |
| Hold (Slow) | WHS **+0.154 ns**，THS 0，失败端点 **0 / 52,349** |
| Setup (Fast) | WNS +22.882 ns，0 失败 |
| Hold (Fast) | WHS +0.113 ns，0 失败 |
| Recovery / Removal / Min Pulse Width | 空（无违例） |
| Total LUTs | **13,018**（as logic 10,333 + as DRAM 2,685） |
| Total Registers | 8,639 |
| DRM / APM | 4.5 / 6 |
| 位流 | `pangoriscv_i512.sbit`，3,791,112 B，SHA256 `CCE6CD7215E797C5E46AC745744D69EC08900198DE5079DD1E97B0996984855B` |

**频率口径**：这是**约束频率 27 MHz**（板载晶振）下的收敛结果，不是板上实测最高频率。
上一轮的 50 MHz 过约束实验另有记录（`P5/`）。

### 5.1 hold 收敛过程（这轮踩到的坑）

第一次 27 MHz 全流程：setup WNS +16.521 ns、0 失败，但 **hold 4 个端点 −0.020 ns 不过**。
失败路径全部是 I-Cache 分布式 RAM 写口：

```
soc/core/instruction_cache/set_q[0] → soc/m_araddr[5]（fanout 332）
    → instruction_cache/data_mem_*/ram64x1d/WADDR[4]
launch  HCKBROUTE_2（列 535）时钟 3.238 ns
capture HCKBROUTE_1（列 1101）时钟 3.832 ns   ← 跨时钟树分支偏斜
```

两轮失败后定位到是**时钟树分支偏斜**，不是数据路径太长：hold slack 只差 0.02 ns，
数据侧反而是 0.312 ns 的广播网络延迟在吃余量。修法**不放松任何约束**：

```powershell
$env:PANGO_NATIVE_PNR_EXTRA = "-fix_hold_violation -fix_hold_violation_threshold 150 " +
  "-fix_hold_violation_threshold_for_clk_tree 150 " +
  "-fix_hold_violation_threshold_for_clock_path_cross_srb 150 " +
  "-fix_hold_violation_iterations 400 -max_hold_violated_paths_num 4000 " +
  "-groute_seed 23 -gplace_seed 23"
```

即"只多修 hold"（阈值从 0 提到 150 ps、换走线/布局种子），
**没有 set_false_path、没有 multicycle、没有降时钟周期**。
结果 hold 从 −0.020 ns 变 **+0.154 / +0.113 ns，0 失败**。

> `build.tcl` 为此新增了 `PANGO_NATIVE_PNR_EXTRA` 环境变量钩子（默认参数不变）；
> 默认流程仍等价于原来的 `pnr -fix_hold_violation_threshold 0 …`。

---

## 6. 资源代价（受控对比：同流程、同镜像、仅这两个文件不同）

`platform/pango_native/resource_check.tcl`：与 `build.tcl` 相同的前端（同源清单、同 include
路径、同约束、同镜像、同样的"两幅存储器已载入"守卫），但**停在 device_map**，
三分钟拿到与正式位流一致的 LUT/FF/DRAM 计数。

| 项 | 基线 `99e8bdb` | 本轮 | 变化 |
|---|---|---|---|
| Total LUTs | 12,622 | **13,018** | **+396（+3.14%）** |
| ├ as logic | 9,937 | 10,333 | +396 |
| └ as DRAM | 2,685 | 2,685 | 0 |
| Total Registers | 7,402 | 8,639 | +1,237 |

基线侧与归档记录（`coremark-sim-2026-10-17/pds_resource_summary.txt`：12,572 LUT / 7,398 FF）
相差 0.4% / 0.05%，说明这个受控脚本与正式流程口径一致。

**口径说明**：LUT 计数取自 `device_map` 的 `Total LUTs` 行（= as logic + as DRAM），
与上一轮报告"12,572 LUT"同一口径。触发器增幅大于手写改动量（2 深 FIFO 实测只新增约 70 个，
网表里 `pcf0_q`/`pcf1_q`/`ocnt_q`/`stale_cnt_q` 也没有被复制），
属综合在共享/编码策略上的整体选择差异——它不进入评分项③（该项按 LUT），也不影响时序
（27 MHz 下 setup 仍余 +14.127 ns）。

**评分项③（CoreMark/LUTs，单位：每 kLUT）**

| 对比 | CoreMark/MHz | Total LUTs | CoreMark/kLUT | 变化 |
|---|---|---|---|---|
| 本轮前后（同镜像同流程） | 1.4342 → 1.6815 | 12,622 → 13,018 | 0.1136 → **0.1292** | **+13.7%** |
| 相对最初交付（S0） | 1.3054 → 1.6815 | 12,572 → 13,018 | 0.1038 → **0.1292** | **+24.4%** |

也就是说：**性能涨 17.2%，面积只涨 3.14%**，三项并列评分下这一轮是净赚，不是 BTB 那次的净亏。

---

## 7. 正确性证据（三重门 + 回归）

| 门 | 结果 |
|---|---|
| `run_unit_tests.py --case all` | **5/5 PASS**（pipe_slot / div_adapter / ifu_axi / lsu_axi / icache_axi） |
| `run_ifu_engine_tests.py --seeds 20` | **20/20 PASS**（真实 IFU + 真实 AXI 读引擎） |
| `run_isa_e2e.py --cases all` | **15/15 PASS**（含 load-use、分支冲刷、CSR、trap、定时器中断） |
| CoreMark 五项 CRC | 与基线逐项相同；交付跑分 `Correct operation validated` |
| `run_halt_reset_tests.py` | 5/5（halting 依赖 `idle`，本轮改了 `idle` 语义，专门验过） |
| pipeline / predictor / perf / dcache | 全 PASS |
| engine / ram / interconnect | 64/64、40/40、20/20 PASS |

### 7.1 单元级新增覆盖

- `tb_ifu_axi.sv`：引擎模型改为**可收 2 笔未完成请求**（`mq` FIFO + 逐笔剩余延迟），
  并新增三条断言：
  1. **绝不出现 3 笔未完成**（`IFU_THREE_REQUESTS_OUTSTANDING`）；
  2. **绝不反压响应**（`IFU_BACKPRESSURED_A_RESPONSE`，这是"预留队列表项"的直接后果）；
  3. **背靠背判据**：把引擎延迟切到 1 拍后，要求连续受理拍数 `run_max ≥ 4`
     ——单笔实现最多只能到 1。实测 **run_max = 8**（8 拍连续受理）。
  另有"重定向撞上响应同拍"的定向用例（旧流欠下的响应必须一笔不多一笔不少地吞掉，
  结尾 `answered == reqs` 校验）。
- `tb_icache_axi.sv` 新增 **T9 背靠背命中**：填充一条新行后连续查 7 个字，
  要求每拍都有响应且数据正确（旧实现在第 2 个字就断，一眼挂）。

---

## 8. 复现命令

```powershell
$py = "<Python 3.10>"
$tc = "<repo>/../toolchains/xpack-riscv-none-elf-gcc-15.2.0-1/bin"

# 0) 打开三个开关（编译前显式打开，结束必须还原）
#    rtl/core/soc_config.vh -> CACHE_ENABLE / PREDICT_ENABLE / PERF_ENABLE

# 1) 门 1/2：单元 + 真实引擎 + ISA
python sim\run_unit_tests.py --case all
python sim\run_ifu_engine_tests.py --seeds 20
python tools\run_isa_e2e.py --cases all --toolchain-bin $tc `
  --prefix riscv-none-elf- "--extra-flag=-march=rv32im_zicsr" `
  --modelsim "D:\FPGA_Project\Modelism\win64"

# 2) 门 3：20 迭代同镜像 A/B（基线用 git show 取，不动工作区）
python tools\run_fetch_ab.py --baseline-rev 99e8bdb `
  --files rtl/core/ifu_axi.v rtl/core/icache_axi.v `
  --image-dir build\native_software\coremark\performance\perf_on `
  --max-cycles 40000000

# 3) 交付跑分：512 迭代
python tools\build_native_software.py coremark --iterations 512 --mode performance `
  --cpu-mhz 27 --toolchain-bin $tc --prefix riscv-none-elf- `
  "--extra-flag=-march=rv32im_zicsr" --tag score512
python tools\run_fetch_ab.py --baseline-rev 99e8bdb `
  --files rtl/core/ifu_axi.v rtl/core/icache_axi.v --sides work `
  --image-dir build\native_software\coremark\performance\score512 `
  --max-cycles 500000000 --out build\score512_run

# 4) PDS 27 MHz（必须在 run 目录里启动，见 §9）
$env:PANGO_NATIVE_REPO="<repo>/firmware/code"
$env:PANGO_NATIVE_BOARD_DIR="<repo>/firmware/code/platform/pango_native"
$env:NATIVE_IMAGE_DIR="<repo>/firmware/code/build/native_software/coremark/performance/score512"
$env:PANGO_NATIVE_PNR_EXTRA="-fix_hold_violation -fix_hold_violation_threshold 150 -fix_hold_violation_threshold_for_clk_tree 150 -fix_hold_violation_threshold_for_clock_path_cross_srb 150 -fix_hold_violation_iterations 400 -max_hold_violated_paths_num 4000 -groute_seed 23 -gplace_seed 23"
cd "<repo>/firmware/code/build/pango_native"      # 全新空目录，且必须是当前目录
pds_shell.exe -file "<repo>/firmware/code/platform/pango_native/build.tcl"

# 5) 资源受控对比（停到 device_map）
#    基线侧先用 run_fetch_ab --sides base 把基线文件落到
#    build\score512_base\base\baseline_src，再用 RESOURCE_BASELINE_DIR 指过去
```

---

## 9. 本轮新增的两个环境坑（上一轮 7 条之外）

| 坑 | 现象 | 应对 |
|---|---|---|
| **PDS 的 `$readmemh` 用进程工作目录，不是 `build.tcl` 里 `cd` 的目录** | 从别的目录启动 `pds_shell`，日志出现 `Cannot open specified data file "program.hex"`，PDS 仍出位流 → **程序/数据存储器全空**；而 build.tcl 的守卫因为读不到 `compile/run.log` 只打印一句"未校验"就放行 | **必须在 `build/pango_native` 里启动**；日志必须出现 `Board check: 2 memory images loaded into the design.`。`resource_check.tcl` 把"找不到 compile log"直接升级为 error |
| **不能在要删的目录里删它自己** | `workdir` 设成目标目录后再 `Remove-Item -Recurse` 会失败，`PDS` 于是打开**残留的旧工程**继续干（资源计数看似正常，`report_timing` 却是旧网表） | 删目录的进程 `cwd` 放在**父目录**，删完再另起一个在目标目录里跑的作业 |

> 另外：`run_halt_reset_tests.py` 硬编码 `riscv32-unknown-elf-` 前缀，而本机工具链是
> `riscv-none-elf-`。已在工具链 bin 目录里补了 `riscv32-unknown-elf-{gcc,objcopy,objdump}.exe`
> 三个同目录副本（gcc 按自身路径找 libexec，同目录改名可用）。
