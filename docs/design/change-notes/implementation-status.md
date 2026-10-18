# 实施记录

最新范围：用户要求先完成基础版，Cache、动态预测、DDR、DMA、AI
暂不实施。用户将完整验证交给其他AI；后续“语法编译通过”不代表
仿真、综合、上板或比赛验收通过。

> **板级资料核对轮更新（m03415，2026-10-11）—— 本文件中的 "50MHz / 20ns" 均为修改前的历史记录。**
> 本文件写于 T00-T02 实施期，当时按"板钟 50 MHz"假设工作。官方资料已证明板载系统时钟是
> **27 MHz 单端晶振 → D18，周期 37.037 ns**（教程1 §2.1.2.2.3.2；教程2 §7.2「27MHZ…周期约为 37.037ns」；
> 官方 `2_8_uart_test` 的 `uart_top.v` 分频 234 = 27e6/115200）。因此本文件中出现的
> `50MHz`、`20ns`、`setup slack 16.588ns`、LED 例程时序报告等数值只描述**当时**的排查过程，
> **不能**当作当前工程的板钟或时序结论。
> 当前约束、镜像、PDS 复验与上板步骤见 `09_validation_results/board_material_audit/`
> （`01`~`05` 与 `BOARD_MATERIAL_AUDIT_FINAL.md`）。

日期：2026-10-10。唯一实施依据为上级目录
`docs/superpowers/plans/2026-10-09-tinyriscv-native-axi4-contest-plan.md`。
此文件只记录执行结果，不是第二份计划。获用户本轮授权进入实施，原计划中的
“本轮只修改计划”属于历史记录；其测试依赖和停止条件继续生效。

## 修改前赛题核对

已重新提取并目视核对用户提供的紫光同创选题指南 PDF 第10页，
提取第11页。证据保存在 `docs/evidence/baseline/`，
包括两页 PDF、文本、渲染图、原 PDF SHA256 和批准计划的快照。

结论：计划对选题一的需求映射相符，可以按关卡开始实施；
这不是最终代码符合性或参赛资格确认。

| 赛题要求 | 计划覆盖 | 尚需取得的实施证据 |
| --- | --- | --- |
| RV32I、至少三级流水线、数据冲突与分支 | B1/B2、T02/T05-I/T07a | 真实CPU回归和提交轨迹 |
| UART/GPIO基础外设 | B3、T05/T08a | 本板输出与控制演示 |
| 两路组相联指令和数据Cache、突发效率 | H1、T09 | 两侧Cache测试及优化前后对比 |
| 动态预测及完整异常/中断 | H2、T07b/T10 | 功能矩阵；M-only范围需确认 |
| YOLO或轻量大模型与传感/显示集成 | H3、T11/T12 | 模型、DDR契约、完整应用实测 |
| 指定工具链、CoreMark v1.0至少10秒 | E2/E3、T00-P/T13 | 实际编译、CRC、时钟、运行时间 |
| 性能、资源、时序及CoreMark关键算法波形 | E4/E6、T13 | PDS实现报告及板上采集 |

AXI4、不使用RIB桥、OV5640、HDMI不是赛题强制要求。
本轮保留用户批准的原生AXI4路线。不能把基础阶段完成说成高阶任务全部完成。
开源许可不等于比赛允许复用已有CPU；组织方答复及队伍贡献声明仍待提供。

## 备份与隔离

- 原始目录：`E:/donwload/tinyriscv-master/tinyriscv-master`，只读使用。
- 完整备份：`E:/file/pango/backups/tinyriscv_original_20261010_01`。
- 实施副本：`E:/file/pango/tinyriscv_axi4`。
- 修改前790个文件逐一比较SHA256，原目录、备份、副本一致。
- 清单：`docs/evidence/baseline/original-files.sha256.csv`。
- 原始Git提交：`6741872`，工作分支：`implementation/native-axi4`。
- Git原始提交记录787个文件；另外3个文件受原忽略规则影响，
  但全部790个文件均包含在独立完整备份与哈希清单中。

## 关卡状态

| 任务 | 状态 |
| --- | --- |
| 修改前核对赛题与计划 | 已完成本地PDF对照，保留以上待确认边界 |
| 完整备份及实施副本 | 已完成并校验 |
| G0来源与贡献 | 记录本地来源；上游提交、队友改动、赛事书面答复待提供 |
| N00/T00工具链 | ModelSim可用；已取得真实riscv32-unknown-elf-gcc 7.1.1，默认libgcc含C扩展，完整无C构建尚未验收 |
| N01测试入口 | 28项清单及runner已新增，15项Python测试通过，含真实进程树超时清理 |
| N01新编译原CPU回归 | 两处声明顺序兼容修复后，add及47/47预编译指令镜像通过 |
| T00-P平台前置 | 本轮ADS重新编译/综合/布局布线/位流完成，20ns时钟；尚未下载上板 |
| T01独立AXI环境 | 已实现，最终复测结果见下文 |
| T02流水线 | 已替换为操作接口CPU，保留原译码/ALU/div算法；单元测试27退休/9异常/5访存通过，尚未接AXI SoC |
| T03/T04 | IFU真实读引擎20 seed通过；LSU真实数据引擎/RAM20 seed通过，尚未接CPU整体 |
| N04/N05引擎 | 单拍读/数据AXI引擎64项测试本轮重跑通过，规范及质量复核通过 |
| N06 AXI RAM | 单拍RAM及真实LSU集成40/40通过，规范/质量复核通过；GPIO和实际综合未完成 |
| N07 IFU/LSU | 操作单元及引擎组合已实现，完整CPU接入待N09 |
| N08 互连 | 原生互连/error slave已写入，语法编译0错误0警告；按用户要求未仿真 |
| N09 CPU接入 | 原生CPU封装、2主2从SoC及production manifest已写入，语法编译通过；未运行指令 |
| N10/N12 CSR/中断 | 原生CSR、同步异常、MRET和中断边界代码已写入，语法编译通过；未仿真 |
| 基础外设接入 | UART/GPIO/Timer/SPI/IRQ共7目标SoC已写入，语法编译通过；未仿真 |
| 基础软件 | 启动/异常/计时已改，CoreMark无libgcc构建已编译链接；未运行 |
| 基础板级工程 | 顶层、官方引脚约束、PDS脚本已写入；语法编译通过，未综合/上板 |
| Cache/预测/DDR/DMA/AI | 按用户最新要求暂不实施 |

当前Python使用Codex运行时的完整路径，不依赖失效的`py`默认解释器配置。
已发现WCH交叉编译器，但未用它替代赛题指定的`riscv32-unknown-elf-gcc`，
也未修改现有软件Makefile去假装已经满足指定工具链要求。

## 复现入口

在实施副本根目录使用：

```powershell
$python = 'C:\Users\lenovo\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
$env:PATH = 'E:\donwload\win64;' + $env:PATH
& $python sim/run_baseline.py --case rv32ui-p-add
& $python sim/run_baseline.py --all
```

预编译的ISA测试镜像只能验证此次新编译RTL对这些镜像的行为，
不能证明本机已重新编译测试软件，也不构成完整RV32I认证。

## N01失败定位与已授权修复

新增文件为 `sim/baseline_sources.f`、`sim/run_baseline.py`、
`sim/test_baseline_runner.py`；原有仿真脚本保留。
runner按第27.3节实现，仅抽取日志判定与镜像转换函数用于单元测试。
15项测试已复跑通过，包括进程返回0但日志Fatal时必须拒绝、缺少或重复PASS、
失败/超时标记以及不足四字节的镜像尾部填充。

实际执行 `--case rv32ui-p-add` 返回1，编译日志位于
`.sim_runs/baseline-kgd50ugy/compile.log`，精简证据副本保存在
`docs/evidence/baseline/first-compile-failure.log`。

- `rtl/utils/full_handshake_rx.v:60,68`：`req`在第81行声明之前使用。
- `rtl/utils/full_handshake_tx.v:71,79`：`ack`在第92行声明之前使用。
- ModelSim 10.6e报告 `Errors: 4, Warnings: 0`。
- 仅去掉`-sv`再编译这两个原文件，同样失败；不能归因于`-sv`单一选项。
- 该首次失败时add仿真没有启动；后续结果见下面，不能覆盖原失败证据。
- 不通过关闭JTAG、删源文件、压制错误或复用旧仿真产物绕过失败。

用户再次明确授权后，已仅在实施副本将上述声明移到首次使用之前，
保留逻辑、端口、复位和同步级数。这是原工程编译兼容修复，不是AXI CPU改造。
修改前源码再次备份至
`E:/file/pango/backups/tinyriscv_source_before_resume_20261010_171938`，
805个文件哈希一致；本次不含`.git`和存在访问限制的旧`.sim_runs`。
之前790文件完整原版备份继续保留。

新编译日志：`.sim_runs/baseline-3wl8mqev/compile.log`，
0 Errors / 0 Warnings。该目录47个用例日志全部唯一PASS，
当时逐项日志位于 `evidence/records/baseline/compatible-original/`，该目录已于 2026-10-18 清理（属早期 2026-10-10 的兼容性验证，已被后续 ISA 15/15 与优化轮次取代）。
ModelSim仿真各日志含15条原模型警告，未隐藏；
PASS只表示这些预编译镜像通过，不证明完整ISA、FENCE.I维护或本机软件编译。

`sim/check_baseline_negative.py`在隔离副本将真实TB成功条件固定false，
实际产生TEST_FAIL并被runner拒绝，原TB哈希未变。
日志：`.sim_runs/negative-ngbjb5w2/rv32ui-p-add-negative.log`。
随后add重跑通过：`.sim_runs/baseline-4yicpcw9/rv32ui-p-add.log`。
Python超时测试实际启动父/子进程并检查二者结束，15/15通过。

## T01与后续关卡

新增完整AXI字段的验证接口、字节内存模型、监视器、测试台与PowerShell入口。
测试覆盖同拍、AW先5拍、W先5拍，WSTRB与窄访问，
R/B阻塞7拍、8拍随机等待突发、未映射读写错误、读写同时请求、
ID/拍数/LAST/稳定性及结束清空。固定seed 1至20。
故意改变受阻AR地址必须触发`AXI_MONITOR AR_STABILITY` Fatal。
最终复测20/20通过，负向注入被检测，编译0 Errors / 0 Warnings。
最终目录：`.sim_runs/t01-eeb3241ce7ea4171ab04f71e5d9f1548/`，
日志证据副本位于`docs/evidence/axi/`。这仅是验证环境验收，
不是CPU原生AXI、Cache或SoC集成通过。

`docs/cpu_memory_contract.md`已按计划冻结接口与生命周期。
`pipe_slot.v`和`div_adapter.v`已实现并通过独立测试及规范/质量复核。
覆盖无替换消费后不重复输出、除法持续请求时只接收一次、
立即消费结果、活动运算/被阻塞结果期间复位及恢复。
除法测试14次请求、12次响应，另外2次被复位取消。
负向停顿清valid注入触发`stall lost A`。
日志：`.sim_runs/unit-pipe_slot-ngubucut/`、
`.sim_runs/unit-div_adapter-fdouod0n/`、
`.sim_runs/unit-pipe_slot-z5nwzkkn/`（预期失败）。
T02完整流水线控制链正在实施，尚未集成验收。

本轮新增修改前备份：
`E:/file/pango/backups/tinyriscv_before_cpu_20261010_174502`，
887个文件复制后逐一哈希一致，不含`.git/.sim_runs/__pycache__`。

已实际排查PDS：Synplify许可未配置，但原工程使用的ADS路径可用，
不能把Synplify失败泛化成PDS不可用。首次批处理约束加载过晚，
时序报告使用默认1000ns，不算50MHz通过；修正后于17:58:53生成
新的20ns报告，请以`docs/evidence/platform/counter_led.rtr`为准，
requested 50MHz、setup slack 16.588ns。这是LED例程，不是CPU时序。
位流生成完成，SCBV尚有配置提示，未下载板卡、未取得现场输出。
复现脚本及日志见`docs/evidence/platform/`。

指定编译器已经获取；实际板卡下载、DDR标准接口仍待验证。
继续实施不依赖这些物理输入的RTL单元，不以仿真代替上板关卡。
完整计划尚未完成。
原目录与完整备份各790文件已再次按原哈希清单通过核验。

## 流水线与操作单元本轮续作

新增 `retire_ctrl.v` 并改造 IF/ID、ID/EX、PC、控制与CPU连接。
EX当前采用内部操作接口，不再接旧RIB。CSR/SYSTEM/FENCE.I暂按非法
指令处理，尚未完成T07；不能把此阶段结果当成完整ISA符合性。
原CPU模块复制到 `tb/reference/`，仅由独立baseline manifest使用，
不会混入新CPU。隔离后原镜像47/47再次通过，
日志 `.sim_runs/baseline-uhlxnx_7/`。

流水线新日志 `.sim_runs/pipeline-74kt4oc2/`：
27次退休、9次异常、5次访存，0 errors / 0 warnings。
测试包括真实排队年轻fault的分支冲刷、正确路径取指fault、
访存ready背压及halt排空、load/store总线错误等待trap_ready、
依赖旁路、除法、JALR bit0和目标对齐。只读复核确认原三项覆盖缺口已补齐。
老分支停顿使用测试台force模拟EX延迟；不是真实AXI系统回归。

`ifu_axi.v` 保存请求PC/预测PC及保留返回槽，从内部握手起标记在途。
重定向排空旧请求并丢弃错误返回；只允许程序RAM取指。
`lsu_axi.v` 保存操作身份，生成窄访问数据/WSTRB并只扩展一次，
对齐失败不发总线描述符，store只在B返回后完成。
描述符层测试：
`.sim_runs/unit-ifu_axi-7cnqe9gp/`（5请求/5结果），
`.sim_runs/unit-lsu_axi-wc812hjh/`（10请求/3写/13完成），均0 errors。
这些模块与真实AXI引擎、互连、RAM尚未整体集成，不标完整T03/T04完成。

引擎已有证据：
`.sim_runs/engines-o6jthykx/`、`.sim_runs/engines-hw-2td27ph0/`，
40个正常seed、12个预期fatal、12个SYNTHESIS宏故障保持用例。
首版只接受len=0；突发留到T09，不能称现有引擎已支持Cache补行。
SYNTHESIS宏仿真不代表实际综合通过。

工具链压缩包位于上级 `toolchains/openisa-1.0.0-windows.zip`，
SHA256 `7E5D27F7B71F578547A9CEE87A6C6E4A9AF1055045DD8C6F8673E8570C9D5E9C`。
GCC实际安装于 `toolchains/openisa-1.0.0/gcc/riscv32-unknown-elf-gcc/bin`。
原CoreMark试编译目录 `.sim_runs/coremark-original-build/`，
ELF含RVC及libgcc压缩指令，故该镜像不能用于当前无C CPU验收。
计时端口尚需64位整数转换与high-low-high读取修正；
不得改CoreMark关键算法或把编译成功误报为CPU运行成功。

## 追加独立复跑与复核

引擎本轮独立复跑：
`.sim_runs/engines-m9mses1p/`、`.sim_runs/engines-hw-lbdyl_ok/`，
64/64通过。规范及质量复核均通过，只适用于单拍引擎。
仍缺主动保持第二个请求的争用用例；SYNTHESIS宏只跑故障路径，
不把普通功能宏等价性、综合和板测算作已验证。

流水线质量复核新增并修复重定向断言：
正常分支/JALR纠正、trap向量与halt-resume的redirect信号及目标
都在实际发生边沿检查，覆盖计数2/9/2，并拒绝额外redirect。
取指描述符层用不同指令字并在返回后改变输入，逐拍检查保持数据，
不再仅检查PC。两项修复经只读质量复核通过。
父任务独立复跑日志：
`.sim_runs/pipeline-ek0auz54/`，
`.sim_runs/unit-ifu_axi-bnlebxa0/`，
`.sim_runs/unit-lsu_axi-6j16186m/`，全部通过。

新增真实IFU/read-engine测试 `tb/axi/tb_ifu_axi_engine.sv`，
入口 `sim/run_ifu_engine_tests.py`。
20 seed独立复跑 `.sim_runs/ifu-real-engine-e2i8mpn9/`，每例
14次内部请求/AR/R/引擎结果、8次有效交付，其余旧请求被排空丢弃。
覆盖内部接单边沿、AR受阻、等待R、引擎RD_HOLD与IFU返回槽，
连续redirect、旧错误返回、正确路径fault和禁用期间排空。
规范及质量复核通过。负向临时指令清零变异被检测：
`.sim_runs/ifu-real-engine-55qoqzpt/`。
测试台手动提供新PC，不宣称CPU自主重启取指或真实指令退休已联测。

## RAM Endpoint Integration

Added `rtl/perips/axi_ram.v`: synchronous 4096-word memory, optional
initialization, no array reset, checked full-address indexing, independent
AW/W capture, byte enables and held responses. Unsupported bursts are
fully framed SLVERR transactions; malformed WLAST fails closed. Actual
cache-fill bursts remain for T09.

Added standalone RAM and real LSU/data-engine/RAM benches plus
`sim/run_ram_tests.py`. Fresh parent run `.sim_runs/ram-19d8d_wx/`
passed 40/40 (20 RAM and 20 LSU seeds). Specification and quality reviews
approved this subset. Real LSU coverage includes SW/LW/SB/LBU, bus errors,
local alignment rejection and 20/30-cycle read/write target delays.
The arithmetic result in that bench is a testbench model, not CPU execution.

Still unverified: full lane coverage in the real composition, malformed
mid-burst WLAST, maximum LEN, PDS BRAM inference, GPIO and full T05/CPU.
Supported RAM parameters assume word-aligned BASE_ADDR, positive WORDS
and nonnegative delays.

N08 interconnect/error-slave code is implemented; syntax-only compilation
reported zero errors and warnings. No interconnect simulation was run.
Original reference modules remain isolated and unchanged.

## Code-First Handoff

User delegated full verification to another AI. Subsequent code changes
receive syntax checks only, not acceptance claims. Verification instructions
are in `docs/external-verification-plan.md`.

N09 added `tinyriscv_axi_top.v`, `tinyriscv_axi_soc.v`,
`native_axi_macros.vh` and `sim/native_axi_sources.f`. Packed port zero
is instruction and port one data. The SoC connects both engines through
the interconnect to program/data RAM without RIB. Program RAM disables
writes via the new optional RAM `WRITE_ENABLE` parameter. Halt drains
existing work and engine/fabric faults block fresh acceptance.
Native-manifest syntax compile passed with zero errors and warnings.
This is not native ISA execution, synthesis or board evidence.

## Basic Version Delivery

Latest user scope defers Cache, prediction, DDR, DMA and AI. No such
advanced implementation was added.

Native CSR/interrupts and seven-target peripheral SoC code are present.
Software startup, trap dispatch, 64-bit timing and freestanding CoreMark
build were updated. CoreMark compiled/linked with GCC 7.1.1 without
libc/libgcc; execution and CRC/duration are unverified.

Board entry: `rtl/soc/pango_native_top.v`.
Build instructions: `platform/pango_native/README.md`.
Official UART pins are TX C24 / RX B24; provenance is recorded there.
The PDS SystemVerilog project setting must be enabled externally before
the provided build script is used; its Tcl equivalent is not established.
No native PDS synthesis, timing report, bitstream or board run was performed.

Final basic-release manifest includes `pipe_slot.v` and the board top.
Fresh library `sim/native_release_load_work` compiled and loaded
`pango_native_top` with zero errors and warnings. Logs:
`sim/native_release_compile.log`, `sim/native_release_load.log`.
The load command immediately quit; no simulation `run` was issued.
