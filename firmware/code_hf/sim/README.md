# 验证环境（`sim/`）

本目录是 pangoriscv 的仿真验证入口：12 个套件 runner、1 个共享辅助模块 `runner_common.py`、
2 个源码清单和 1 个 AXI 一键脚本。PDS 构建只读取 `native_axi_sources.f`。

## 1. 源码清单

| 文件 | 内容 |
|---|---|
| `native_axi_sources.f` | 交付 RTL 的 33 个源文件（`rtl/core/**`、`rtl/bus/**`、`rtl/perips/**`、`rtl/soc/pangoriscv_top.v` 等） |
| `axi_sources.f` | AXI 测试台支撑文件：`tb/axi/axi_memory_model.sv`、`tb/axi/axi_monitor.sv`、`tb/axi/tb_axi_memory.sv` |

`platform/pango_native/native_sources.tcl` 按 `native_axi_sources.f` 把源码同步到
`build/pango_native/sources/`，顶层为 `pangoriscv_top`。编译必须带
`+incdir+<包根>/rtl/core`（`platform/pango_native/build.tcl` 已包含），否则
`` `include "native_axi_macros.vh" `` 等会报 `` Cannot find `include file ``。

## 2. 回归 runner

工作目录为本包根目录，例如 `python sim/run_unit_tests.py --case all`。每个 runner 自行创建
ModelSim work 库、编译、仿真，末行打印 `SUMMARY x / y PASS`，日志与波形写入
`.sim_runs/<suite>-<id>/`。

| Runner | 覆盖内容 | 回归套件名 |
|---|---|---|
| `run_unit_tests.py --case all` | 流水槽位 `pipe_slot`、除法握手适配器 `div_adapter`、`ifu_axi` / `lsu_axi` / `icache_axi` 单元 | `unit-all`（5/5） |
| `run_icache_tests.py` | 两路组相联 I-Cache 命中 / 缺失 / 替换 | `icache`（1/1） |
| `run_dcache_tests.py` | 两路组相联 D-Cache 写回与旁路 | `dcache`（1/1） |
| `run_predictor_tests.py` | 动态分支预测（BTB + 2 位饱和计数器） | `predictor`（1/1） |
| `run_pipeline_tests.py` | 操作接口 CPU 流水线 | `pipeline`（`N03_PIPELINE`） |
| `run_perf_tests.py` | `perf_regs` 性能计数器读数 | `perf`（1/1） |
| `run_gpio_trace_tests.py` | GPIO 追踪（`-DTRACE_*`） | `gpio-trace`（1/1） |
| `run_engine_tests.py --seeds 4` | 单拍 AXI 读写引擎，含致命 / 硬件故障（`+define+SYNTHESIS`） | `engine-s4`（32/32） |
| `run_interconnect_tests.py --seeds 4` | 原生 AXI 互连与锁定属主 | `interconnect-s4`（4/4） |
| `run_ram_tests.py --seeds 4` | RAM 端点与真实 LSU / 数据引擎 | `ram-s4`（8/8） |
| `run_ifu_engine_tests.py --seeds 4` | 真实 IFU / 读引擎重定向与禁用排空 | `ifu-engine-s4`（4/4） |
| `run_axi_tests.ps1` | 用 `axi_sources.f` 一键编译并仿真 AXI 测试台 | — |

另有两个整机套件 runner 位于 `tools/`：`run_halt_reset_tests.py`（halt / reset 场景，
`halt-reset` 5/5）与 `run_isa_e2e.py`（端到端 ISA / CSR / 定时器 / 中断，`isa-e2e` 15/15）；
`tools/run_coremark_ab.py` 用于 CoreMark A/B 对照。以上合计 13 个回归套件。

`tools/run_fetch_ab.py` 是**同一镜像、同一测试台、两个 RTL 修订**的 CoreMark A/B：
基线侧用 `git show <rev>:./<file>` 落到临时目录，工作区不被改动；两侧分别编译后并发仿真，
输出 ticks / cycles / retires / IPC / 五项 CRC / 陷阱计数 / perf 计数器 / 存路径分解。
取数命令见 `evidence/records/optimization/P7/measurement.md`。

## 3. 运行环境与产物

- ModelSim 2020.4（`vlib` / `vlog` / `vsim`）：先用 `vlib` 建 work 库再 `vlog -work` 编译，
  预先存在的空目录会让 `vlog` 报 `(vlib-35) Failed to create directory`。
- Python 3.11，仅用标准库。
- `.sim_runs/`、`__pycache__/`、`*.vcd`、`out.vvp`、`inst.data` 均为运行产物，不纳入提交。
- 实测数据与完整验证记录见上级 `README.md` 第 3 节。
