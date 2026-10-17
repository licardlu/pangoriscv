# 测试台（`tb/`）

本目录是 pangoriscv 验证用的 SystemVerilog 测试台，全部由 `sim/run_*.py`、
`tools/run_halt_reset_tests.py`、`tools/run_isa_e2e.py` 调用（套件与 runner 的对应关系见
`../sim/README.md`）。

| 目录 | 内容 |
| --- | --- |
| `axi/` | 原生 AXI4 单元与互连测试台：`tb_axi_interconnect.sv`、`tb_axi_memory.sv`、`tb_axi_ram.sv`、`tb_axi_read_engine.sv`、`tb_axi_data_engine.sv`、`tb_ifu_axi_engine.sv`、`tb_lsu_axi_ram.sv`，以及公共模型 `axi_memory_model.sv`、`axi_monitor.sv`、`ram_init.hex` |
| `unit/` | 核内部单元测试台：`tb_pipe_slot.sv`、`tb_div_adapter.sv`、`tb_ifu_axi.sv`、`tb_lsu_axi.sv`、`tb_icache_axi.sv`、`tb_dcache_axi.sv`、`tb_branch_predictor.sv`、`tb_pipeline.sv`、`tb_perf_regs.sv` |
| `integration/` | 整机级测试台：`tb_coremark_uart.sv`、`tb_gpio_trace.sv`、`tb_halt_reset_drain.sv`、`tb_isa_e2e.sv`、`tb_led_walk.sv`、`tb_native_soc_integration.sv`、`tb_uart_tx_smoke.sv` |

所有测试台与被测 RTL 使用同一套接口约定：`valid`/`ready` 握手、`rst_n` 低有效复位、
`` `include "defines.v" ``（由 `+incdir+rtl/core` 解析）。
