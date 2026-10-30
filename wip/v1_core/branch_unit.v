`include "core_defs.vh"

module core_branch_unit (
    input  wire [31:0] pc,
    input  wire [31:0] imm,
    input  wire [31:0] src1,
    input  wire [31:0] src2,
    input  wire [2:0]  funct3,
    input  wire        is_branch,
    input  wire        is_jal,
    input  wire        is_jalr,
    input  wire [31:0] pc_plus_len,
    output wire        taken,
    output wire [31:0] target
);
    // 条件分支: funct3[2:0] = BEQ/BNEZ/BLT/BGE/BLTU/BGEU
    reg cond;
    always @(*) begin
        case (funct3)
            3'b000:  cond = (src1 == src2);            // BEQ
            3'b001:  cond = (src1 != src2);            // BNE
            3'b100:  cond = ($signed(src1) < $signed(src2));  // BLT
            3'b101:  cond = !($signed(src1) < $signed(src2)); // BGE
            3'b110:  cond = (src1 < src2);             // BLTU
            3'b111:  cond = !(src1 < src2);            // BGEU
            default: cond = 1'b0;
        endcase
    end

    wire [31:0] pc_rel = pc + imm;
    wire [31:0] jalr_t = (src1 + imm) & 32'hFFFF_FFFE;

    assign taken  = is_jal | is_jalr | (is_branch & cond);
    assign target = is_jalr ? jalr_t : pc_rel;

    // pc_plus_len 由上层按指令长度给, 这里只做透传位宽的占位, 保证端口完整。
    wire unused = ^pc_plus_len;
endmodule
