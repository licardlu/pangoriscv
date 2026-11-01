//=============================================================================
// pangoriscv - RV32IM processor core + native AXI4 SoC (Pango PG2L100H @ 27 MHz)
// Module : id_ex                  File : rtl/core/id_ex.v
// Rev    : 1.0                    Date : 2026-10-13
// Author : pango_lpenghan
// Brief  : ID to EX pipeline register
//=============================================================================

// Operands are sampled only at the actual ID-to-EX handshake.
module id_ex(
    input wire clk, rst_n,
    input wire in_valid, output wire in_ready,
    output wire out_valid, input wire out_ready,
    input wire [31:0] inst_i, inst_addr_i,
    input wire reg_we_i, input wire [4:0] reg_waddr_i,
    input wire [31:0] reg1_rdata_i, reg2_rdata_i,
    input wire csr_we_i, input wire [31:0] csr_waddr_i, csr_rdata_i,
    input wire [31:0] op1_i,op2_i,op1_jump_i,op2_jump_i,
    input wire fault_i, input wire [4:0] fault_cause_i,
    input wire [31:0] fault_tval_i,predicted_next_pc_i,
    input wire illegal_i,uses_rs1_i,uses_rs2_i,
    output wire [31:0] inst_o, inst_addr_o,
    output wire reg_we_o, output wire [4:0] reg_waddr_o,
    output wire [31:0] reg1_rdata_o,reg2_rdata_o,
    output wire csr_we_o, output wire [31:0] csr_waddr_o,csr_rdata_o,
    output wire [31:0] op1_o,op2_o,op1_jump_o,op2_jump_o,
    output wire fault_o, output wire [4:0] fault_cause_o,
    output wire [31:0] fault_tval_o,predicted_next_pc_o,
    output wire illegal_o,uses_rs1_o,uses_rs2_o
);
    localparam WIDTH=32+32+1+5+32+32+1+32+32+32+32+32+32+1+5+32+32+1+1+1;
    wire [WIDTH-1:0] payload;
    // EX is oldest: a redirect removes its successors, never this slot's event.
    pipe_slot #(.WIDTH(WIDTH)) slot(
        .clk(clk),.rst_n(rst_n),.flush(1'b0),
        .in_valid(in_valid),.in_ready(in_ready),
        .in_data({inst_i,inst_addr_i,reg_we_i,reg_waddr_i,reg1_rdata_i,reg2_rdata_i,
            csr_we_i,csr_waddr_i,csr_rdata_i,op1_i,op2_i,op1_jump_i,op2_jump_i,
            fault_i,fault_cause_i,fault_tval_i,predicted_next_pc_i,
            illegal_i,uses_rs1_i,uses_rs2_i}),
        .out_valid(out_valid),.out_ready(out_ready),.out_data(payload));
    assign {inst_o,inst_addr_o,reg_we_o,reg_waddr_o,reg1_rdata_o,reg2_rdata_o,
        csr_we_o,csr_waddr_o,csr_rdata_o,op1_o,op2_o,op1_jump_o,op2_jump_o,
        fault_o,fault_cause_o,fault_tval_o,predicted_next_pc_o,
        illegal_o,uses_rs1_o,uses_rs2_o}=payload;
endmodule
