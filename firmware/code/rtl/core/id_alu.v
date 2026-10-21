//=============================================================================
// pangoriscv - RV32IM processor core + native AXI4 SoC (Pango PG2L100H @ 27 MHz)
// Module : id_alu                 File : rtl/core/id_alu.v
// Rev    : 1.0                    Date : 2026-10-20
// Author : pango_lpenghan
// Brief  : Lane-1 decoder: ALU / branch / JAL / single shared-LSU memory
//=============================================================================

// The second issue slot executes ALU, branch, JAL or load/store instructions
// (the pair rules exclude CSR, FENCE, JALR and MUL/DIV). Memory is steered to
// the one shared LSU by the core; this decoder adds no second memory port.
// Reusing the full `id` decoder for this slot inferred the
// CSR and memory control logic for a unit that can never use it; this module
// keeps the register-write, operand and jump fields and drives everything else
// constant.  Architecturally it must match `id` exactly for these encodings.
`include "defines.v"

module id_alu(
    input  wire               rst,
    input  wire [`RegBus]     inst_i,
    input  wire [`InstAddrBus] inst_addr_i,
    input  wire [`RegBus]     reg1_rdata_i,
    input  wire [`RegBus]     reg2_rdata_i,
    output reg  [`RegBus]     inst_o,
    output reg  [`InstAddrBus] inst_addr_o,
    output reg  [`RegBus]     reg1_rdata_o,
    output reg  [`RegBus]     reg2_rdata_o,
    output wire [`RegAddrBus] reg1_raddr_o,
    output wire [`RegAddrBus] reg2_raddr_o,
    output reg                reg_we_o,
    output reg  [`RegAddrBus] reg_waddr_o,
    output wire               csr_we_o,
    output wire [`RegAddrBus] csr_waddr_o,
    output wire [`RegBus]     csr_rdata_o,
    output reg  [`RegBus]     op1_o,
    output reg  [`RegBus]     op2_o,
    output reg  [`RegBus]     op1_jump_o,
    output reg  [`RegBus]     op2_jump_o,
    output reg                illegal_o,
    output wire               uses_rs1_o,
    output wire               uses_rs2_o
);
    wire [6:0] opcode = inst_i[6:0];
    wire [2:0] funct3 = inst_i[14:12];
    wire [6:0] funct7 = inst_i[31:25];
    wire [4:0] rd     = inst_i[11:7];

    wire [`RegBus] imm_i = {{20{inst_i[31]}}, inst_i[31:20]};
    wire [`RegBus] imm_s = {{20{inst_i[31]}}, inst_i[31:25], inst_i[11:7]};
    wire [`RegBus] imm_b = {{20{inst_i[31]}}, inst_i[7], inst_i[30:25],
                            inst_i[11:8], 1'b0};
    wire [`RegBus] imm_j = {{12{inst_i[31]}}, inst_i[19:12], inst_i[20],
                            inst_i[30:21], 1'b0};
    wire [`RegBus] imm_u = {inst_i[31:12], 12'h000};
    wire [`RegBus] pc_inc = 32'h00000004;

    assign csr_we_o     = `WriteDisable;
    assign csr_waddr_o  = `ZeroReg;
    assign csr_rdata_o  = `ZeroWord;
    assign uses_rs1_o   = 1'b0;
    assign uses_rs2_o   = 1'b0;
    assign reg1_raddr_o = inst_i[19:15];
    assign reg2_raddr_o = inst_i[24:20];

    always @(*) begin
        inst_o       = inst_i;
        inst_addr_o  = inst_addr_i;
        reg1_rdata_o = reg1_rdata_i;
        reg2_rdata_o = reg2_rdata_i;
        reg_we_o     = `WriteDisable;
        reg_waddr_o  = `ZeroReg;
        op1_o        = `ZeroWord;
        op2_o        = `ZeroWord;
        op1_jump_o   = `ZeroWord;
        op2_jump_o   = `ZeroWord;
        illegal_o    = 1'b0;

        case(opcode)
            `INST_TYPE_L: begin
                op1_o = reg1_rdata_i;
                op2_o = imm_i;
                case(funct3)
                    `INST_LB, `INST_LH, `INST_LW, `INST_LBU, `INST_LHU: begin
                        reg_we_o = `WriteEnable;
                        reg_waddr_o = rd;
                    end
                    default: illegal_o = 1'b1;
                endcase
            end
            `INST_TYPE_S: begin
                op1_o = reg1_rdata_i;
                op2_o = imm_s;
                case(funct3)
                    `INST_SB, `INST_SH, `INST_SW: begin end
                    default: illegal_o = 1'b1;
                endcase
            end
            `INST_TYPE_I: begin
                reg_we_o    = `WriteEnable;
                reg_waddr_o = rd;
                op1_o       = reg1_rdata_i;
                op2_o       = imm_i;
            end
            `INST_TYPE_R_M: begin
                if((funct7 == 7'b0000000) || (funct7 == 7'b0100000)) begin
                    reg_we_o    = `WriteEnable;
                    reg_waddr_o = rd;
                    op1_o       = reg1_rdata_i;
                    op2_o       = reg2_rdata_i;
                end else begin
                    // MUL/DIV are not lane-1 instructions
                    illegal_o = 1'b1;
                end
            end
            `INST_TYPE_B: begin
                op1_o      = reg1_rdata_i;
                op2_o      = reg2_rdata_i;
                op1_jump_o = inst_addr_i;
                op2_jump_o = imm_b;
            end
            `INST_JAL: begin
                reg_we_o    = `WriteEnable;
                reg_waddr_o = rd;
                op1_o       = inst_addr_i;
                op2_o       = pc_inc;
                op1_jump_o  = inst_addr_i;
                op2_jump_o  = imm_j;
            end
            `INST_LUI: begin
                reg_we_o    = `WriteEnable;
                reg_waddr_o = rd;
                op1_o       = imm_u;
                op2_o       = `ZeroWord;
            end
            `INST_AUIPC: begin
                reg_we_o    = `WriteEnable;
                reg_waddr_o = rd;
                op1_o       = inst_addr_i;
                op2_o       = imm_u;
            end
            default: begin
                // CSR, FENCE, JALR: never paired into lane 1
                illegal_o = 1'b1;
            end
        endcase
    end
endmodule
