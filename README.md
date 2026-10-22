# pangoriscv — RV32IM 处理器核 + 原生 AXI4 SoC

用 Verilog 实现的一款 RISC-V RV32IM 处理器核，自带原生 AXI4 总线与 SoC，已在 Pango PG2L100H 开发板上
跑通 CoreMark（400 次迭代，5 项 CRC 全部符合）。

> **当前交付（2026-10-22 P13，板上实测）**：**5.213 CoreMark/MHz @ 36 MHz**
> （2000 迭代 / 10.66 s / 五项 CRC 全对 / `Correct operation validated`）。
> 位流 `bitstream/pangoriscv_board36_i2000.sbit`（SHA256 `CCEFDD8B…3E37F6`）；
> 证据 `evidence/records/optimization/p13-board-verify/`。
> 分数口径：`Iterations × 1e6 / Total ticks = 2000e6 / 383,673,358`（不用整数截断的秒数）。
> 频率口径：位流 PLL 实配 36 MHz（27×56/42）；同 RTL 在 **40 MHz 约束下 All Constraints Met**
> （setup +0.558 / hold +0.033 / 0 失败端点，分析构建 `p13seed7`，估计 fmax 40.56 MHz）。
> 交付位流 setup +1.200 ns 全过、hold 残留 3 端点 −0.035 ns（data_ram 写地址跨列偏斜，
> 板上实测不受影响，见 measurement.md"时序遗留"）。
> **布线配方**（PDS 2022.2-SP6.1，缺省 hold 参数 + `-gplace_seed 3 -plc_decongestion 1
> -share_router_control_signal TRUE`）——可布性靠 placement seed，详见
> [docs/plan-score-5.2-120mhz-v8.md](docs/plan-score-5.2-120mhz-v8.md) §8 与
> [mistakes-log §48](docs/lessons/mistakes-log.md)。
> 120 MHz 目标：实测路径 24.65 ns（约 40.5 MHz），要到 120 MHz 需 EX 拆级（P14 计划），
> 会吃约 2.3% 分数——边界与折算已写进 plan v8。
>
> **P15 结论（2026-10-22 深夜，只动 RTL 不动分数）**：120 MHz **在本微架构上与 5.2 分互斥**，
> 已从"推断"变成"实测"——① 8.333 ns 约束下工具**摆放上限只有 19.4 ns**（−11.055 ns，TNS −100 M），
> 差 2.33 倍；② CPI 余量只剩 **608 ticks/iter（0.32%）**，而 +1 拍重定向要 **3,441 ticks/iter（1.8%）**，
> 分数会掉到 5.12；③ 区域约束三种形状（横带/竖带/紧凑方块）全部负优化，这条方向封死。
> **更要紧的是派生出的一条**：45 MHz、50 MHz 的**摆放都能过（TNS=0，WNS +1.0~+1.3 ns）**，
> 但**详细布线不收敛**（Unrouted nets 单调下降到 9k~11k 后斜率衰减到 ~230/轮），
> 所以短期连 45 MHz 也交付不了，**36 MHz 仍是唯一能出位流的频点**（PLL 已回退 56/42）。
> 已落地的零 CPI 改动：`br_miss` 摘掉 `!hold_ex`，把 D-cache 请求路径（5 跳 / 4.4 ns）
> 从"重定向→I$ 读出"的同一周期里移出去；CoreMark 20it `Total ticks 3,833,976`
> **与交付镜像逐位一致**（`76b98cf`）。详见
> [plan v10](docs/plan-score-5.2-120mhz-v10.md) §7–9 与
> [P15 交接](docs/HANDOFF-2026-10-22-p15.md)。
>
> **历史交付**：`pangoriscv_i1152_e2.sbit`（旧核 3.8557 板测，1152 迭代 / 27 MHz）；
> 完整问题、验收缺口与修复顺序见 **[docs/verification.md](docs/verification.md)**。

> **性能专项（2026-10-21）**：**当前交付 3.8557 CoreMark/MHz**（板上实测，**1152** 迭代 / 11.066 s /
> 五项 CRC 全对且 `Correct operation validated` / 27 MHz `All Constraints Met`，setup +4.484、
> hold +0.032、失败端点 0 / **17,534 LUT / 7,153 FF**）。
> 位流 `bitstream/pangoriscv_i1152_e2.sbit`（同分数、面积 −10.9%）；证据 `evidence/records/optimization/perf-area-lutram/`；
> 计划与 A/B 见 [docs/plan-perf-3.8.md](docs/plan-perf-3.8.md)。
> 相对面积专项定版 3.4222：**+12.7% 分数、站点 +0.9%**（CoreMark/kLUT 0.1901 → **0.2103**）。
>
> **5.2 分 / 126 MHz 专项（2026-10-22，P8：把 9 ns 的乘法摘出 lane1 通路）**
>
> **先更正两条旧记录**（v2/§19 的结论建立在错误的基线上）：
> 1. 板测 **3.8557** 是**旧核 `pangoriscv`** 的成绩——`build/perf_p37b` 的 compile 日志里
>    `rv32_top` 出现 0 次。当前工作树默认编译的是**新核 `rv32_top`**。
> 2. 20 迭代仿真的**总周期**含 1,886,231 周期固定启动开销（占 26%）。分数只能取
>    CoreMark 打印的 `Total ticks`。
>
> **本轮（P8）的实质进展**：`p7_path40b` 的最差路径 26.647 ns 里，
> 有 **9.0 ns 是 `u_mul` 的四级 DSP 级联**，而它出现在路径上的唯一理由是
> "lane0 乘、lane1 同拍读同包结果"这一种包（`fwd1_h = lane0_raw1 ? ex_value_w : ...`）。
> 拒绝这一种包、并把该旁路输入改成 `alu_y`，**分数零代价**（6,960,622 → 6,960,617 周期），
> 同时还按 skill §9.7 关掉了交付配置的 `PERF_ENABLE`（它自己也是原路径的终点，4.6 ns）。
>
> | 指标 | P7 | **P8（当前）** |
> |---|---:|---:|
> | CoreMark/MHz（`Total ticks` 5,073,264/20，**仿真**） | 3.942 | **3.942** |
> | 126 MHz 综合 `Synthesize Setup WNS` | −13.490 ns | **−8.156 ns（−5.33 ns）** |
> | 40 MHz 满实现（`All Constraints Met`） | 未全过，26.647 ns | **WNS +1.053，23.947 ns** |
> | LUT / FF（126 MHz `device_map`） | 18,723 / 9,478 | **17,323 / 7,680（−1,400 / −1,798）** |
> | ISA e2e | 20/21 | **20/21** |
>
> **还没到目标线，原因已经算清**：
> - **分数**：5.2 需要 192,307 周期/迭代，当前 253,663。差 1.23 M 周期，
>   而 `load_use = 1,714,576` 周期正是这一块。三轮里三种互锁写法都失败（20/21、16/21、17/21），
>   因为**消费者的执行发生在读寄存器那一拍**（`ex_value/ex_addr` 都是 RR 拍算好再寄存），
>   load 的数据永远晚一拍——**这是结构问题，不是写法问题**（mistakes-log §36）。
>   唯一解：ALU 从 RR 挪到 EX、地址加法器留在 RR，让 load 数据与 ALU 结果同拍落地。
> - **频率**：100 MHz 约束**布不通**（11,786 条未布线），40 MHz 全过。真实上限在 40~100 MHz 之间。
>   注意 `p8_path40` 的 `Route 19.447 ns (83%)` —— 宽约束下工具提前收敛、不再优化时序，
>   所以 **23.947 ns 不是上限**（mistakes-log §37）。
>
> 详见 [docs/plan-score-5.2-126mhz-v4.md](docs/plan-score-5.2-126mhz-v4.md) 与
> [evidence/records/optimization/P8-mul-bypass/measurement.md](evidence/records/optimization/P8-mul-bypass/measurement.md)。
>
> **面积 / 效率专项（2026-10-21）**：该阶段结论已并入上表，其后不再限制性能改动。
> 动手前必读 **[docs/architecture/module-area-plan.md](docs/architecture/module-area-plan.md)**
> （34 个模块的 11 字段面积合同）与 [area-budget.csv](docs/architecture/area-budget.csv)；
> 门禁脚本 `firmware/code/tools/check_area_budget.py`（非零退出不得提交）。
> 冻结基线：tag `score-3.4194-1024`，板上 **3.4194**（1024 迭代 / 11.091 s / 五项 CRC 全对），
> 位流 `bitstream/pangoriscv_i1024.sbit`（SHA256 `8D12C9D1…5FA6A643`）。

| 项 | 值 |
|---|---|
| 指令集 | RV32IM（32 位整数、乘除） |
| 流水线 | 四级（取指 / 译码 / 执行 / 写回），输出级独立访存槽 |
| 总线 | 原生 AXI4，取指与访存双通道，读写引擎各自独立 |
| 性能 | **1.35 CoreMark/MHz**（官方整数秒口径；按 tick 精确为 1.25） |
| 板级 | Pango PG2L100H，27 MHz，串口 / LED / 按键 |

## 仓库结构

```
firmware/code/          作品代码（RTL + 测试台 + 仿真脚本 + 固件工具 + 平台约束）
docs/
  design/plans/         方案书与调研
  design/change-notes/  变更记录：改了什么、为什么改
  verification.md       验证计划、状态与问题总表（含问题台账）
  contest/              赛题原文与要求摘录
  evidence/
  logs/                 仿真运行日志（按用例归档）
  records/              上板记录、时序报告、ISA 合规日志、基线证据
bitstream/              发布版位流（见其中 README.md）
scripts/                仓库级辅助脚本
```

代码包内的构建方法、性能数据与横向定位见 [firmware/code/README.md](firmware/code/README.md)。

## 快速开始

```powershell
git clone <repo-url>
cd <repo>

# 1) RTL 自包含编译检查（需要 ModelSim；work 库不入库）
cd firmware/code
vlog -sv -work work +incdir+rtl/core -f sim/native_axi_sources.f

# 2) 构建固件（--toolchain-bin 指向本机 riscv32-unknown-elf 工具链）
python tools/build_native_software.py led_walk --toolchain-bin "<toolchain>\riscv32-unknown-elf-gcc\bin"

# 3) 跑一套仿真
python sim/run_icache_tests.py --modelsim "<ModelSim 目录>"
```

## 协作

两人都可以直接推 `main`。提交信息格式、改动前先 `pull --rebase`、同一份文件避免同时改等约定见
`docs/verification.md`（问题台账）与 `docs/lessons/rules.md`（动手清单）。

## 入库范围

仓库只收**作品代码、设计文档、验证证据**（约 5 MB）。位流、仿真波形、EDA 构建产物、历史工作树、
原始备份与聊天记录不入库；可再生产物不得入库的规则见 skill `pango-riscv-contest` 的「仓库放置与清理约定」与 `docs/lessons/rules.md`。
