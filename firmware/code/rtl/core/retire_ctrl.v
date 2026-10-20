//=============================================================================
// pangoriscv - RV32IM processor core + native AXI4 SoC (Pango PG2L100H @ 27 MHz)
// Module : retire_ctrl            File : rtl/core/retire_ctrl.v
// Rev    : 1.0                    Date : 2026-10-13
// Author : pango_lpenghan
// Brief  : Retire / commit control: retire_fire, retire_order, predictor training
//=============================================================================

`include "defines.v"
module retire_ctrl(
    input wire clk,rst_n,
    input wire ex_valid,ex_done,ex_fault,trap_ready,irq_pending,
    input wire [1:0] retire_count,
    input wire [31:0] actual_next_pc,trap_vector,
    input wire halt_req,fetch_idle,data_idle,
    output wire retire_fire,trap_fire,ex_leave,
    output reg [63:0] retire_order,
    output reg [31:0] arch_next_pc,
    output reg halt_pending,halted
);
    assign retire_fire=rst_n && !halted && ex_valid && ex_done && !ex_fault;
    assign trap_fire=rst_n && !halted && trap_ready &&
        ((ex_valid && ex_done && ex_fault) ||
         (irq_pending && !halt_req && !halt_pending &&
          (!ex_valid || retire_fire)));
    assign ex_leave=retire_fire || (trap_fire && ex_valid && ex_fault);
    always @(posedge clk) begin
        if(!rst_n) begin
            retire_order<=0; arch_next_pc<=`CpuResetAddr;
            halt_pending<=0; halted<=0;
        end else begin
            if(retire_fire) begin
                retire_order<=retire_order+retire_count;
                arch_next_pc<=actual_next_pc;
            end
            if(trap_fire) arch_next_pc<=trap_vector;
            if(halt_req) halt_pending<=1;
            if((halt_req || halt_pending) && (!ex_valid || ex_leave) &&
                fetch_idle && data_idle) halted<=1;
            if(halted && !halt_req) begin halted<=0; halt_pending<=0; end
        end
    end
endmodule
