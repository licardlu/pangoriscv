# 执行命令与配置（bottleneck audit）

本文件记录本轮所有可复现的命令。路径均为 `E:\file\pango\project` 下的实际路径。
所有产物在 `evidence/records/bottleneck_audit/`，**发布树 `firmware/code` 与 `bitstream/` 未被任何命令写入**。

## 0. 环境（已核实）

| 工具 | 路径 | 版本 |
|---|---|---|
| RISC-V GCC | `E:\file\pango\toolchains\openisa-1.0.0\gcc\riscv32-unknown-elf-gcc\bin` | `riscv32-unknown-elf-gcc.exe (GCC) 7.1.1 20170509` |
| ModelSim | `E:\donwload\win64`（vlog/vsim/vlib/vmap） | `ModelSim SE-64 vsim 10.6e 2018.06` |
| PDS | `E:\donwload\PDS_2022.2-SP6.4` | 2022.2-SP6.4 |
| Python | 系统 Python | 3.11.9 |

## 1. 基线快照（只读）

```powershell
# 源码树哈希（146 文件，聚合 sha256 8611ADDA...E6814F）
Get-ChildItem E:\file\pango\project\firmware\code -Recurse -File |
  ForEach-Object { "$((Get-FileHash $_.FullName -Algorithm SHA256).Hash)`t$($_.FullName.Replace('E:\file\pango\project\',''))" } |
  Set-Content evidence\records\bottleneck_audit\results\baseline_tree_sha256.tsv

# 位流哈希（3,791,112 B, sha256 F8254F66...2CE77C）
Get-FileHash E:\file\pango\project\bitstream\pangoriscv_i400.sbit -Algorithm SHA256
```

工作副本：`work/tree` = `firmware/code` 的完整复制（146 文件），CoreMark 源从
`E:\file\pango\backups\tinyriscv_before_advanced_cpu_20261012_212358\tests\example\coremark\`
还原到 `work/tree/tests/example/coremark/`。

## 2. 固件构建

```powershell
$tree = 'E:\file\pango\project\evidence\records\bottleneck_audit\work\tree'
$tc   = 'E:\file\pango\toolchains\openisa-1.0.0\gcc\riscv32-unknown-elf-gcc\bin'
Set-Location $tree

# CoreMark validation（1 次迭代）—— 机制测量用的基线镜像
python tools\build_native_software.py coremark --iterations 1 --mode validation `
       --cpu-mhz 27 --toolchain-bin $tc

# CoreMark performance（1 次迭代）—— 与板上 400 次迭代同参数的对照组
python tools\build_native_software_mb.py coremark --iterations 1 --mode performance `
       --cpu-mhz 27 --toolchain-bin $tc

# 微程序（脚本为 build_native_software.py 的副本，仅在 --application 的 choices 里加了 microbench）
python tools\build_native_software_mb.py microbench --iterations 1 --mode validation `
       --cpu-mhz 27 --toolchain-bin $tc
```

编译参数（脚本固定）：`-march=rv32im -mabi=ilp32 -mcmodel=medlow -O2 -ffreestanding
-fno-builtin -fno-common -ffunction-sections -fdata-sections -falign-functions=4
-falign-jumps=4 -falign-loops=4 -DCPU_FREQ_MHZ=27 -D<MODE>_RUN=1 -DITERATIONS=<n>`，
链接脚本 `tests/example/link.lds`（flash 0x00000000 16 KB，ram 0x10000000 16 KB，stack 8 KB）。

输出：`build/native_software/<app>/<mode>/{program.hex,data.hex,*.elf,firmware.map,manifest.json}`。

## 3. 仿真编译与运行

**关键陷阱（已踩过）**
1. `-work` 后面跟**绝对路径**时，反斜杠会被 ModelSim 当成库名+模块名分隔，报
   `(vopt-2253) No module name found in command-line argument "...\sim_work.tb_x"`。
   解决：在 `work/tree` 下建**相对库名**（`vlib work_mb; vmap work_mb work_mb`）。
2. `-f sim/native_axi_sources.f` 里是相对路径，必须在 `work/tree` 目录下执行 vlog。
3. 层次化探测（`+acc`）必须传 `-voptargs="+acc"`，否则 `soc.core.*` 内部信号被优化掉。
4. TB 一定要接 `halt_req`：漏接会让 CPU 停在复位/停摆状态，表现为“0 字符、跑到超时”。

### 3.1 全功能配置（与交付位流同配置）— v1 TB，仅作对照

> v1 TB（`tb_coremark_audit.sv`）的直方图统计了整段仿真、load/store 停顿未分项，
> **报告数据一律取 3.4 的 v2 结果**；这里保留 v1 命令只为复现旧日志。

```powershell
$audit = 'E:\file\pango\project\evidence\records\bottleneck_audit'
$tree  = "$audit\work\tree"
$w64   = 'E:/donwload/win64'
Set-Location $tree

# CoreMark 区间审计 TB（24 个计数器 + 互斥分类 + 直方图）
& "$w64/vlog.exe" -sv -work work_mb `
   +define+CACHE_ENABLE+PREDICT_ENABLE+PERF_ENABLE `
   +incdir+rtl/core +incdir+rtl/perips -f sim/native_axi_sources.f `
   "$audit/scripts/tb_coremark_audit.sv"

$img = "$tree/build/native_software/coremark/performance"
& "$w64/vsim.exe" -c -voptargs="+acc" -work work_mb tb_coremark_audit `
   "+PROG=$img/program.hex" "+DATA=$img/data.hex" "+MAX_CYCLES=4000000" `
   -do "run -all; quit -f" -l "$audit/logs/sim_audit_perf1.log"
```

### 3.2 默认配置（三个宏全关）

```powershell
& "$w64/vlib.exe" work_mb_base; & "$w64/vmap.exe" work_mb_base work_mb_base
& "$w64/vlog.exe" -sv -work work_mb_base +incdir+rtl/core +incdir+rtl/perips `
   -f sim/native_axi_sources.f "$audit/scripts/tb_coremark_audit.sv" `
   "$audit/scripts/tb_uart_run.sv"
& "$w64/vsim.exe" -c -voptargs="+acc" -work work_mb_base tb_coremark_audit `
   "+PROG=$img/program.hex" "+DATA=$img/data.hex" "+MAX_CYCLES=8000000" `
   -do "run -all; quit -f" -l "$audit/logs/sim_audit_base_iter1.log"
```

（同一份 TB 在两个配置下都能 elaborate：`perf_*` 事件在源码里改为直接表达式，
Cache 探针包在 `` `ifdef CACHE_ENABLE `` 里。见 `scripts/tb_coremark_audit.sv` 头部说明。）

### 3.4 v2 审计 TB（口径修订版，**报告采用的就是这一版**）

```powershell
$audit = 'E:\file\pango\project\evidence\records\bottleneck_audit'
$tree  = "$audit\work\tree"
$w64   = 'E:/donwload/win64'
Set-Location $tree

# (1) 全功能：perf 镜像，1 次迭代
& "$w64/vlog.exe" -sv -work work_mb +define+CACHE_ENABLE+PREDICT_ENABLE+PERF_ENABLE `
   +incdir+rtl/core +incdir+rtl/perips -f sim/native_axi_sources.f `
   "$audit/scripts/tb_coremark_audit_v2.sv"
$img = "$tree/build/native_software/coremark/performance"
& "$w64/vsim.exe" -c -voptargs="+acc" -work work_mb tb_coremark_audit_v2 `
   "+PROG=$img/program.hex" "+DATA=$img/data.hex" "+MAX_CYCLES=4000000" `
   -do "run -all; quit -f" -l "$audit/logs/sim_audit_v2_perf1.log"

# (2) 默认构建（三宏全关）：validation 镜像，1 次迭代
$img2 = "$tree/build/native_software/coremark/validation"
& "$w64/vlog.exe" -sv -work work_mb_base +incdir+rtl/core +incdir+rtl/perips `
   -f sim/native_axi_sources.f "$audit/scripts/tb_coremark_audit_v2.sv"
& "$w64/vsim.exe" -c -voptargs="+acc" -work work_mb_base tb_coremark_audit_v2 `
   "+PROG=$img2/program.hex" "+DATA=$img2/data.hex" "+MAX_CYCLES=8000000" `
   -do "run -all; quit -f" -l "$audit/logs/sim_audit_v2_base.log"
```

v2 日志里 `AUDIT_INT_CLASS` 是互斥分类（`lsu_load` / `lsu_store` 分开），
`AUDIT_INT_LSU_PHASE` 是 LSU 状态归因，`AUDIT_INT_FE_IDLE` 是前端空转拆解，
`AUDIT_INT_STORE_SHAPE` / `AUDIT_RUN` 是 store 连跑长度。性能镜像不打印
`Correct operation`，所以 `TEST_FAIL … report_seen=0` 属预期（不是功能失败）。

### 3.5 微程序（UART 直读）

```powershell
& "$w64/vsim.exe" -c -voptargs="+acc" -work work_mb tb_uart_run `
   "+PROG=$img/program.hex" "+DATA=$img/data.hex" "+MAX_CYCLES=4000000" `
   -do "run -all; quit -f" -l "$audit/logs/sim_microbench_full.log"
```

## 3.6 位流重建（基线上板用；v3 新增，v3.1 实测修订）

**结论先行：`+define+` 走 PDS 走不通。** `compile -compiler_directives "+define+CACHE_ENABLE ..."`
会被 PDS 拒绝，日志三条：

```
W: The "+define+CACHE_ENABLE" in compiler directives is invalid, ignore it.
```

构建照样跑完、`done` 位照样是 1，但**实际构建的是默认配置**（无 Cache / 预测 / perf），
板上慢约 3.79×。所以本轮改用**只在构建副本里取消 `soc_config.vh` 三行注释**的办法，
仓库工作树与 HEAD 源文件都不动（`build.tcl` 上那版本轮加的 `PANGO_NATIVE_DEFINES` 改动已
`git checkout --` 回退到 HEAD，sha256 `BB992560…28 407AE`）。

```powershell
$bb  = 'E:\file\pango\project\evidence\records\bottleneck_audit\baseline_build'
$pds = 'E:\donwload\PDS_2022.2-SP6.4\PDS_2022.2-SP6.1\bin'
$run = "$bb\src\build\pango_native"

# 1) 展开 HEAD 源码（git archive 必须先落盘；PowerShell 里 `git archive | tar -x` 会坏归档）
git archive --format=tar -o tree.tar HEAD firmware/code
tar -xf tree.tar

# 2) 打开三个宏（只在副本里；改前备份 soc_config.vh.gitasis）
#    原 sha256 248838404F6F8ACF49E9874A13C63293E168C02336D25CDB329B9236928FF07D
#    改后 sha256 BD9A2677B58A093AB5BEE6027193BE34B9174C8464FEFBCF2E6957C22585AE2D

# 3) 生成 400 迭代 performance 镜像（详见 §3.1 的固件构建段）

# 4) 综合（CWD = 流程目录！）
$env:PANGO_NATIVE_REPO      = "$bb\src"
$env:PANGO_NATIVE_BOARD_DIR = "$bb\src\platform\pango_native"
$env:NATIVE_IMAGE_DIR       = "$bb\src\build\native_software\coremark\performance"
Set-Location $run
& "$pds\pds_shell.exe" -file "$bb\src\platform\pango_native\build.tcl" -work_dir $run
```

**三个必须记住的坑（实测）**：
1. **PDS 忽略 `-work_dir`，流程目录 = 进程 CWD**。若在项目根启动，`compile/`、`build.pds` 等
   会写进仓库根，且 `axi_ram.sv` 的相对 `INIT_FILE = program.hex` 打不开 → 日志出现
   `C: Verilog-3001: Cannot open specified data file "program.hex"`，流程**仍然跑完**并生成
   **空程序**位流（`device_map` 里 DRM=0）。所以必须 `Set-Location $run` 再启动，
   并确认日志有 `Board check: 2 memory images loaded into the design.`
2. 相对路径 `INIT_FILE` 是按流程目录解析的，不是按脚本目录。
3. **宏到底开没开，看资源和端点，不看 build.tcl 的提示行**：脚本打印的
   `Board config: default (no -compiler_directives; ...)` 只表示没走 directives 分支。
   默认配置 = LUT 7,589 / 29,461 端点；全功能 = LUT 12,441 / 48,214 端点（交付 stageT 也是 48,214）。

**上板与串口采集**（`board/` 目录）：

```powershell
# 1) 只读扫描链（确认电缆/器件）
powershell -ExecutionPolicy Bypass -File .\board\run_flash.ps1 -Script 00_scan_chain.tcl

# 2) 先开串口（后台），再下载位流到 SRAM —— 顺序不能反，镜像只打印一次
Start-Job { & .\board\capture_uart.ps1 -Port COM13 -Seconds 90 -Out "$bb\board_uart_baseline.txt" }
powershell -ExecutionPolicy Bypass -File .\board\run_flash.ps1 `
  -Script 01b_program_only.tcl -Sbit "$bb\src\build\pango_native\generate_bitstream\pangoriscv_top.sbit"
```

`run_flash.ps1` 会启动 `cdt_js.exe`（JtagServer）→ 从日志解析 `use port : N` →
用 `cdt_cfg.exe -file <tcl>` 执行 → 结束后关服务；判定以 `program OK: 1` / `PROGRAM_ONLY_DONE` 为准。
**`cfg_verify` 不能当判据**（`E: JtagServer-0607`、`E: Configuration-0008` 属该板/该工具组合的固有失败），
且一次失败的 verify 会把后续命令全部锁死（`W: Public-4023: ... run command clean`），
而 `cfg_clean` 命令在该版本里**不存在**——唯一恢复办法是杀掉 `cdt_js` / `cdt_cfg` 进程重来。

## 3.7 T4 前端优化：编译、契约 TB、A/B 与微程序（本轮实测）

两棵树各自建**相对名** work 库（cwd = 树根；用绝对库名在 `vsim` 时会报 `(vopt-2253)`）：

```powershell
$env:PATH='E:\donwload\win64;'+$env:PATH
$audit = 'E:\file\pango\project\evidence\records\bottleneck_audit'
$trees = @{ cand = "$audit\frontend_opt\src"; base = "$audit\baseline_build\src" }
$defs  = @('+define+CACHE_ENABLE','+define+PREDICT_ENABLE','+incdir+rtl/core','+incdir+rtl/perips')

foreach($k in 'cand','base'){
  Set-Location $trees[$k]
  if(!(Test-Path "ab2_$k")){ & vlib "ab2_$k" }
  # 契约 TB（候选树）
  & vlog -sv -work "ab2_$k" @defs -f sim/native_axi_sources.f `
        tb/unit/tb_icache_contract.sv tb/unit/tb_ifu_contract.sv 2>&1 | Select-String 'Errors:'
}
Set-Location $trees['cand']
& vsim -c -work ab2_cand tb_icache_contract -do "run -all; quit -f" -l "$audit\frontend_opt\ab\cand_icontract.log"
& vsim -c -work ab2_cand tb_ifu_contract    -do "run -all; quit -f" -l "$audit\frontend_opt\ab\cand_ifucontract.log"
```

CoreMark 同镜像 A/B（**长窗口** TB，`repeat(30000)` 的 v2 只够 12 字符，已改 v3）：

```powershell
# 审计 TB 编译进两棵树
foreach($k in 'cand','base'){
  Set-Location $trees[$k]
  & vlog -sv -work "ab2_$k" @defs -f sim/native_axi_sources.f "$audit\scripts\tb_coremark_audit_v3.sv"
  & vsim -c -work "ab2_$k" tb_coremark_audit_v3 `
      "+PROG=$audit\work\tree\build\native_software\coremark\validation\program.hex" `
      "+DATA=$audit\work\tree\build\native_software\coremark\validation\data.hex" `
      "+MAX_CYCLES=5000000" -do "run -all; quit -f" -l "$audit\frontend_opt\ab\$($k)_cmval_v3b.log"
}
# 提取：先去掉 UART 载荷里的控制行（# PROGRESS / # AUDIT_），否则 "Total ticks" 会被截断
```

微程序（端口级 TB，只探 `clk/rst_n/uart_tx`；镜像用 `work/tree/.../microbench/validation`）：

```powershell
& vsim -c -work ab2_cand tb_uart_run `
   "+PROG=$audit\work\tree\build\native_software\microbench\validation\program.hex" `
   "+DATA=$audit\work\tree\build\native_software\microbench\validation\data.hex" `
   "+MAX_CYCLES=3000000" -do "run -all; quit -f" -l "$audit\frontend_opt\ab\cand_micro.log"
```

**结果**：`results/T4_frontend_results.md`；原始日志在 `frontend_opt/ab/`
（`cand_cm3.log`、`cand_cmval_v3b.log`、`cand_micro.log`、`base_*` 同名）。
坑：微程序镜像跑完打印 `MICROBENCH done.` 后 TB 仍会跑到 `+MAX_CYCLES` 上限（日志尾部
`TB TIMEOUT after 3000000 cycles`），所有阶段数据在 `done` 之前已打印完毕，不影响取值。

## 3.8 T4 后端与上板（本轮实测）

候选树综合前先开宏（与基线开宏版逐字节相同，sha256 `BD9A2677…`）：

```powershell
$cand = "$audit\frontend_opt\src"; $run = "$cand\build\pango_native"
# rtl/core/soc_config.vh:34-36 取消三行注释（先 cp soc_config.vh 到 soc_config.vh.t4bak）
$env:PANGO_NATIVE_REPO      = $cand
$env:PANGO_NATIVE_BOARD_DIR = "$cand\platform"
$env:NATIVE_IMAGE_DIR       = "$audit\baseline_build\src\build\native_software\coremark\performance"  # 400 iter
pds_shell -file "$cand\platform\pango_native\build.tcl" -work_dir $run
```

- 流程目录 = `$cand\build\pango_native`（PDS 按**进程 CWD** 落流程目录；cwd 必须是这个目录，
  否则位流为空/DRM=0）。
- 候选 `build.tcl` 只改了一处：`pnr` 的 hold 修复阈值 `0 → 100` ps、迭代 `50 → 100`
  （更严，不放松约束；备份 `build.tcl.baseline_hold0`）。不改则 Hold slow −0.036 ns 不过。
- 结果：`frontend_opt/pds/run2_hold100/`（rtr、multiseed_summary.csv、sbit、flow.log）。

上板（串口必须先开，镜像只打印一次）：

```powershell
$b = "$audit\board"
powershell -NoProfile -ExecutionPolicy Bypass -File "$b\capture_uart.ps1" -Port COM13 -Seconds 75 -Out "$b\board_uart_candidate.txt"   # 后台先跑
powershell -NoProfile -ExecutionPolicy Bypass -File "$b\run_flash.ps1" -Script 01b_program_only.tcl `
    -Sbit "$audit\frontend_opt\pds\run2_hold100\pangoriscv_top.sbit" -TimeoutSec 120
```

- `run_flash.ps1` 会自己起/停 JtagServer 并解析真实端口；`cdt_cfg.exe` 跑完 file-only Tcl
  不退出，脚本按超时杀进程，成功以 `configuration_tcl.log` 里的 `cfg_program succeed` 为准。
- 结果：`results/board_uart_candidate.txt` 与 `board_uart_candidate_run2.txt`
  （sha256 `D4DC2B50…`，两次逐字节相同；`Total ticks 279957350`，1.4288 CoreMark/MHz）；
  基线捕获同目录 `board_uart_baseline.txt` / `board_uart_baseline_run2.txt`。
- 坑：本机启动 `cdt_js.exe` 有 ftdibus.sys 内核 bugcheck 前科（0x139），本轮未复现；
  串口未先开就下载 ⇒ UART 输出丢失，只能重下。

## 4. 源清单与开关

- 源清单：`work/tree/sim/native_axi_sources.f`（33 行，`+incdir+rtl/core`、`+incdir+rtl/perips`）
- 编译开关：`rtl/core/soc_config.vh:34-36` 三个宏 `CACHE_ENABLE` / `PREDICT_ENABLE` /
  `PERF_ENABLE` **默认全被注释**，必须在编译期用 `+define+`（仿真）或 PDS 工程宏（综合）打开。
  未打开时：I/D 侧换成 `axi_read_engine` / `axi_data_engine`，无 Cache、无预测、无 perf 计数。
- 顶层：`pangoriscv_axi_soc`（`rtl/soc/pangoriscv_axi_soc.v`）→ `pangoriscv_axi_top`
  （`rtl/core/pangoriscv_axi_top.v`）→ `pangoriscv`（`rtl/core/pangoriscv.v`，三级流水）。
- Cache/预测器参数：I-Cache SETS=32 / WORDS=8 / LINE_BEATS=8（2 KB，2 路）；
  D-Cache SETS=32 / WAYS=2 / LINE_WORDS=8（2 KB，2 路，写穿、CACHED_LIMIT=0x2000_0000）；
  BTB 32 项直接映射；取指队列 DEPTH=8，带预测链预取（T1）。

## 5. 本轮没有做的事

- **没有改生产 RTL**：写缓冲继续搁置；T4 前端改造只做在独立副本 `frontend_opt/src/`，
  交付树 `firmware/code` 未合并。
- 没有接 ILA：本轮全部结论来自仿真器件级信号与 UART 输出。
- `REC lat=16` 的 1,592 次长尾没定位；两个 AXI 主口的仲裁对取指的影响没单独测；
  `RVCoreP-32IC` 等两篇候选论文的作者信息未核实。
- T4 前端优化的 PDS 资源/时序与上板已补测（见 §3.8、`results/T4_frontend_results.md` §8）。
