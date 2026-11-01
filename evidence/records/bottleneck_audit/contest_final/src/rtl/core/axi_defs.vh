//=============================================================================
// pangoriscv - RV32IM processor core + native AXI4 SoC (Pango PG2L100H @ 27 MHz)
// Module : axi_defs               File : rtl/core/axi_defs.vh
// Rev    : 1.0                    Date : 2026-10-13
// Author : pango_lpenghan
// Brief  : AXI4 interface definitions shared by the native bus
//=============================================================================

`ifndef PANGO_AXI_DEFS_VH
`define PANGO_AXI_DEFS_VH
`define AXI_BURST_INCR 2'b01
`define AXI_RESP_OKAY 2'b00
`define AXI_RESP_SLVERR 2'b10
`define AXI_RESP_DECERR 2'b11
// N04/N05 deliberately support one beat. Longer descriptors are rejected.
`define AXI_ENGINE_MAX_LEN 8'd0
`define AXI_ENGINE_MAX_SIZE 3'd2
`endif
