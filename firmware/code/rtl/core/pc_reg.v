//=============================================================================
// pangoriscv - RV32IM processor core + native AXI4 SoC (Pango PG2L100H @ 27 MHz)
// Module : pc_reg                 File : rtl/core/pc_reg.v
// Rev    : 1.0                    Date : 2026-10-13
// Author : pango_lpenghan
// Brief  : Program counter feeding the fetch unit. Rather than a reset/redirect/
//          advance priority chain inside the clocked block, the successor address
//          is resolved combinationally by a nested ternary mux, and the clocked
//          block loads that one resolved value unconditionally. Priority is
//          reset, then a redirect target, then the predicted address when the
//          fetch/ID handshake fires, and otherwise the PC reloads itself and so
//          holds. The redirect wins because it is the left-most test of the
//          nested mux; hold is the default branch of both inner tests.
//=============================================================================

`include "defines.v"

module pc_reg(
    input  wire        clk,                // core clock
    input  wire        rst_n,              // active-low reset
    input  wire        redirect_valid,     // redirect qualifies redirect_pc
    input  wire [31:0] redirect_pc,        // branch/jump/trap target
    input  wire        if_to_id_fire,      // fetch accepted by ID this cycle
    input  wire [31:0] predicted_next_pc,  // predicted successor address
    output reg  [31:0] pc_o                // address presented to the fetcher
);

    //---------------------------------------------------------- successor mux
    // Hold is expressed as an explicit self-reload, which keeps the whole
    // selection in one expression instead of an if/else priority chain.
    wire [31:0] hold_pc   = pc_o;
    wire [31:0] stream_pc = if_to_id_fire ? predicted_next_pc : hold_pc;
    wire [31:0] branch_pc = redirect_valid ? redirect_pc : stream_pc;
    wire [31:0] next_pc   = rst_n ? branch_pc : `CpuResetAddr;

    //-------------------------------------------------------------- PC update
    always @(posedge clk) pc_o <= next_pc;

endmodule
