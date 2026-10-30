// -----------------------------------------------------------------------------
// core_sources.f -- 新核源文件清单 (顺序即编译顺序, 先叶子后顶层)
//
// 用法:
//   vlog +incdir+<root>/rtl/core -f <root>/rtl/core/core_sources.f
//   PDS 侧由 project/core_replica/build.tcl 按同一份清单 add_design
//
// 约束: 本清单不得出现 rtl/generated/MicroSoc.v。参考设计只允许出现在验证侧。
// -----------------------------------------------------------------------------

// ---- 前端 ----
rtl/core/frontend/instruction_aligner.v
rtl/core/decode/rvc_decoder.v

// ---- 译码 ----
rtl/core/decode/decoder.v
rtl/core/decode/dispatch_buffer.v

// ---- 执行 ----
rtl/core/execute/alu.v
rtl/core/execute/shifter.v
rtl/core/execute/branch_unit.v
rtl/core/execute/multiplier.v
rtl/core/execute/divider.v
rtl/core/execute/operand_select.v

// ---- 寄存器堆 ----
rtl/core/regfile/integer_regfile.v

// ---- 访存 ----
rtl/core/lsu/load_store_unit.v

// ---- 控制 ----
rtl/core/control/csr_file.v

// ---- 核顶层 ----
rtl/core/pango_cpu.v

// ---- 存储与外设 ----
rtl/soc/ram_tdp.v
rtl/perips/uart_tx.v

// ---- SoC ----
rtl/soc/pango_soc.v

// ---- 板级顶层 ----
rtl/pango_pll.sv
rtl/pango_reset.sv
rtl/pango_cpu_top.sv
