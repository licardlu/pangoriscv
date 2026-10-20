//=============================================================================
// pangoriscv - RV32IM processor core + native AXI4 SoC (Pango PG2L100H @ 27 MHz)
// Module : ex_alu                 File : rtl/core/ex_alu.v
// Rev    : 1.0                    Date : 2026-10-20
// Author : pango_lpenghan
// Brief  : Minimal lane-1 execute unit: ALU / branch / JAL only
//=============================================================================

// Lane 1 can only be an ALU-class instruction, a conditional branch or JAL.
// The full `ex` module contains the CSR, load/store, divide and multiply
// datapaths; duplicating it for lane 1 inferred a second 32x32 multiplier and
// memory/CSR control for a unit that can never issue those operations.  This
// module keeps exactly the ALU/branch datapath and is bit-identical to `ex` for
// every encoding the pair rules allow.
`include "defines.v"

module ex_alu(
    input  wire               rst,
    input  wire [`RegBus]     inst_i,
    input  wire [`InstAddrBus] inst_addr_i,
    input  wire [`RegBus]     reg1_rdata_i,
    input  wire [`RegBus]     reg2_rdata_i,
    input  wire [`RegBus]     op1_i,
    input  wire [`RegBus]     op2_i,
    input  wire [`RegBus]     op1_jump_i,
    input  wire [`RegBus]     op2_jump_i,
    output reg  [`RegBus]     reg_wdata_o,
    output reg                jump_flag_o,
    output reg  [`InstAddrBus] jump_addr_o
);
    wire [6:0] opcode = inst_i[6:0];
    wire [2:0] funct3 = inst_i[14:12];
    wire [6:0] funct7 = inst_i[31:25];

    wire signed_ge = ($signed(op1_i) >= $signed(op2_i));
    wire unsigned_ge = (op1_i >= op2_i);
    wire operands_equal = (op1_i == op2_i);

    wire [`RegBus] add_result = op1_i + op2_i;
    wire [`RegBus] sub_result = op1_i - op2_i;
    wire [`RegBus] target_sum = op1_jump_i + op2_jump_i;
    wire [`RegBus] slt_result   = ($signed(op1_i) < $signed(op2_i)) ? 32'd1 : 32'd0;
    wire [`RegBus] sltu_result  = (op1_i < op2_i) ? 32'd1 : 32'd0;

    wire [`RegBus] rshift_low = reg1_rdata_i >> inst_i[24:20];
    wire [`RegBus] rshift_mask = 32'hffffffff >> inst_i[24:20];
    wire [`RegBus] rshift_sign = {32{reg1_rdata_i[31]}} & (~rshift_mask);
    wire [`RegBus] srai_result = ((rshift_low & rshift_mask) | rshift_sign);
    wire [`RegBus] srai_sel = inst_i[30] ? srai_result : rshift_low;

    wire [`RegBus] rshiftv_low = reg1_rdata_i >> reg2_rdata_i[4:0];
    wire [`RegBus] rshiftv_mask = 32'hffffffff >> reg2_rdata_i[4:0];
    wire [`RegBus] rshiftv_sign = {32{reg1_rdata_i[31]}} & (~rshiftv_mask);
    wire [`RegBus] srav_result = ((rshiftv_low & rshiftv_mask) | rshiftv_sign);
    wire [`RegBus] srav_sel = inst_i[30] ? srav_result : rshiftv_low;

    always @(*) begin
        reg_wdata_o = `ZeroWord;
        jump_flag_o = `JumpDisable;
        jump_addr_o = `ZeroWord;

        case(opcode)
            `INST_TYPE_I: begin
                case(funct3)
                    `INST_ADDI:  reg_wdata_o = add_result;
                    `INST_SLTI:  reg_wdata_o = slt_result;
                    `INST_SLTIU: reg_wdata_o = sltu_result;
                    `INST_XORI:  reg_wdata_o = op1_i ^ op2_i;
                    `INST_ORI:   reg_wdata_o = op1_i | op2_i;
                    `INST_ANDI:  reg_wdata_o = op1_i & op2_i;
                    `INST_SLLI:  reg_wdata_o = reg1_rdata_i << inst_i[24:20];
                    `INST_SRI:   reg_wdata_o = srai_sel;
                    default:     reg_wdata_o = `ZeroWord;
                endcase
            end
            `INST_TYPE_R_M: begin
                if((funct7 == 7'b0000000) || (funct7 == 7'b0100000)) begin
                    case(funct3)
                        `INST_ADD_SUB: reg_wdata_o = inst_i[30] ? sub_result : add_result;
                        `INST_SLL:     reg_wdata_o = op1_i << op2_i[4:0];
                        `INST_SLT:     reg_wdata_o = slt_result;
                        `INST_SLTU:    reg_wdata_o = sltu_result;
                        `INST_XOR:     reg_wdata_o = op1_i ^ op2_i;
                        `INST_SR:      reg_wdata_o = srav_sel;
                        `INST_OR:      reg_wdata_o = op1_i | op2_i;
                        `INST_AND:     reg_wdata_o = op1_i & op2_i;
                        default:       reg_wdata_o = `ZeroWord;
                    endcase
                end else begin
                    reg_wdata_o = `ZeroWord;   // MUL/DIV never reach lane 1
                end
            end
            `INST_TYPE_B: begin
                reg_wdata_o = `ZeroWord;
                case(funct3)
                    `INST_BEQ:  begin jump_flag_o = operands_equal & `JumpEnable;
                                      jump_addr_o = {32{operands_equal}} & target_sum; end
                    `INST_BNE:  begin jump_flag_o = (~operands_equal) & `JumpEnable;
                                      jump_addr_o = {32{~operands_equal}} & target_sum; end
                    `INST_BLT:  begin jump_flag_o = (~signed_ge) & `JumpEnable;
                                      jump_addr_o = {32{~signed_ge}} & target_sum; end
                    `INST_BGE:  begin jump_flag_o = signed_ge & `JumpEnable;
                                      jump_addr_o = {32{signed_ge}} & target_sum; end
                    `INST_BLTU: begin jump_flag_o = (~unsigned_ge) & `JumpEnable;
                                      jump_addr_o = {32{~unsigned_ge}} & target_sum; end
                    `INST_BGEU: begin jump_flag_o = unsigned_ge & `JumpEnable;
                                      jump_addr_o = {32{unsigned_ge}} & target_sum; end
                    default: begin end
                endcase
            end
            `INST_JAL: begin
                reg_wdata_o = add_result;          // link address
                jump_flag_o = `JumpEnable;
                jump_addr_o = target_sum;
            end
            `INST_LUI, `INST_AUIPC: begin
                reg_wdata_o = add_result;
            end
            default: begin
                reg_wdata_o = `ZeroWord;
            end
        endcase
    end
endmodule
