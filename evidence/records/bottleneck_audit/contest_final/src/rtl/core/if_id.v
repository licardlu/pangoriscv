//=============================================================================
// pangoriscv - RV32IM processor core + native AXI4 SoC (Pango PG2L100H @ 27 MHz)
// Module : if_id                  File : rtl/core/if_id.v
// Rev    : 1.0                    Date : 2026-10-13
// Author : pango_lpenghan
// Brief  : IF to ID pipeline register
//=============================================================================

// Instruction identity is held as one indivisible slot.
module if_id(
    input wire clk, rst_n, flush,
    input wire in_valid, output wire in_ready,
    input wire [31:0] pc_i, inst_i,
    input wire fault_i, input wire [4:0] fault_cause_i,
    input wire [31:0] fault_tval_i, predicted_next_pc_i,
    output wire out_valid, input wire out_ready,
    output wire [31:0] pc_o, inst_o,
    output wire fault_o, output wire [4:0] fault_cause_o,
    output wire [31:0] fault_tval_o, predicted_next_pc_o
);
    localparam WIDTH = 32+32+1+5+32+32;
    wire [WIDTH-1:0] payload;
    pipe_slot #(.WIDTH(WIDTH)) slot(
        .clk(clk),.rst_n(rst_n),.flush(flush),
        .in_valid(in_valid),.in_ready(in_ready),
        .in_data({pc_i,inst_i,fault_i,fault_cause_i,fault_tval_i,predicted_next_pc_i}),
        .out_valid(out_valid),.out_ready(out_ready),.out_data(payload));
    assign {pc_o,inst_o,fault_o,fault_cause_o,fault_tval_o,predicted_next_pc_o}=payload;
endmodule
