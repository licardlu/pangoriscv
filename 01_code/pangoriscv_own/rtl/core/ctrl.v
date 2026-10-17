//=============================================================================
// pangoriscv - RV32IM processor core + native AXI4 SoC (Pango PG2L100H @ 27 MHz)
// Module : ctrl                   File : rtl/core/ctrl.v
// Rev    : 1.0                    Date : 2026-10-13
// Author : pango_lpenghan
// Brief  : Pipeline redirect and stall control. Four asynchronous events ask the
//          front end to abandon the instruction currently in flight: a mispredict
//          or taken-branch redirect, a halt that is already waiting to take
//          effect, a fresh halt request, and the halted state itself. Any of them
//          raises young_flush, which squashes the young (fetch/ID) stages, and
//          block_entry, which additionally holds the issue slot back while reset
//          is asserted or while a flush is in progress.
//=============================================================================

`include "defines.v"

module ctrl(
    input  wire rst_n,          // active-low reset
    input  wire redirect_valid, // branch/jump redirect is redirecting the PC
    input  wire halt_pending,   // halt accepted, not yet in effect
    input  wire halt_req,       // halt requested by the debug/halt port
    input  wire halted,         // core is in the halted state
    output wire young_flush,    // squash younger stages
    output wire block_entry     // keep the issue slot blocked this cycle
);

    //------------------------------------------------------------ flush sources
    // Any redirect, pending halt, fresh halt request or held halt state squashes
    // the instructions younger than the stage that raised it.
    assign young_flush = redirect_valid | halt_pending | halt_req | halted;

    //---------------------------------------------------------- entry blocking
    // Reset blocks entry unconditionally; otherwise a flush of any kind does.
    assign block_entry = ~rst_n | young_flush;

endmodule
