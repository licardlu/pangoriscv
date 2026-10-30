// -----------------------------------------------------------------------------
// core_rvc_decoder.v -- RVC (RV32C) 展开器
//
// 与 upstream/.../decode/DecoderPlugin.scala 的 RVC 展开职责一致:
//   输入 = 原始 16 位半字, 输出 = 等价的 32 位指令 + 合法性
//   原始半字由上层单独保存, 用于 mtval / 反汇编 / 事件追踪。
//
// 只实现 RV32C 的整数子集。F/D 相关编码 (C.FLD/C.FLW/C.FSD/C.FSW/C.FLDSP...)
// 一律判为非法, 因为冻结配置没有 F/D 扩展 —— 不能静默当成 NOP。
// -----------------------------------------------------------------------------

module core_rvc_decoder (
    input  wire [15:0] inst,
    output reg  [31:0] instr32,
    output reg         illegal
);
    // ------------------------------ 编码辅助 ---------------------------------
    function [31:0] enc_i;
        input [11:0] imm;
        input [4:0]  rs1;
        input [2:0]  f3;
        input [4:0]  rd;
        input [6:0]  opcode;
        begin
            enc_i = {imm, rs1, f3, rd, opcode};
        end
    endfunction

    function [31:0] enc_s;
        input [11:0] imm;
        input [4:0]  rs2;
        input [4:0]  rs1;
        input [2:0]  f3;
        begin
            enc_s = {imm[11:5], rs2, rs1, f3, imm[4:0], 7'b0100011};
        end
    endfunction

    function [31:0] enc_b;
        input [31:0] imm;
        input [4:0]  rs2;
        input [4:0]  rs1;
        input [2:0]  f3;
        begin
            enc_b = {imm[12], imm[10:5], rs2, rs1, f3, imm[4:1], imm[11], 7'b1100011};
        end
    endfunction

    function [31:0] enc_j;
        input [31:0] imm;
        input [4:0]  rd;
        begin
            enc_j = {imm[20], imm[10:1], imm[11], imm[19:12], rd, 7'b1101111};
        end
    endfunction

    // ------------------------------ 立即数拼装 -------------------------------
    wire [4:0] rs1p  = {2'b01, inst[9:7]};      // rs1' / rd'
    wire [4:0] rd_p  = {2'b01, inst[4:2]};
    wire [4:0] rs2p  = {2'b01, inst[4:2]};      // 与 rd_p 同位置, 语义不同

    wire [11:0] imm_addi4spn = {inst[10:7], inst[12:11], inst[5], inst[6], 2'b00};
    wire [6:0]  imm_lw      = {inst[5], inst[12:10], inst[6], 2'b00};
    wire [5:0]  imm_ci      = {inst[12], inst[6:2]};
    wire [31:0] imm_ci_sext = {{26{imm_ci[5]}}, imm_ci};
    wire [9:0]  imm_addi16sp = {inst[12], inst[4:3], inst[5], inst[2], inst[6], 4'b0000};
    wire [31:0] imm_sp_sext  = {{22{imm_addi16sp[9]}}, imm_addi16sp};
    wire [31:0] imm_lui      = {{14{inst[12]}}, inst[12], inst[6:2], 12'b0};
    wire [7:0]  imm_lwsp     = {inst[3:2], inst[12], inst[6:4], 2'b00};
    wire [7:0]  imm_swsp     = {inst[8:7], inst[12:9], 2'b00};

    // CJ / CB 偏移 (12/9 位有符号)
    wire [11:0] imm_cj = {inst[12], inst[8], inst[10:9], inst[6], inst[7],
                          inst[2], inst[11], inst[5:3], 1'b0};
    wire [31:0] imm_cj_sext = {{20{imm_cj[11]}}, imm_cj};
    wire [8:0]  imm_cb = {inst[12], inst[6:5], inst[2], inst[11:10], inst[4:3], 1'b0};
    wire [31:0] imm_cb_sext = {{23{imm_cb[8]}}, imm_cb};

    // ------------------------------ 主体译码 ---------------------------------
    always @(*) begin
        instr32 = {12'h000, 5'd0, 3'b000, 5'd0, 7'b0010011};   // 默认 NOP (addi x0,x0,0)
        illegal = 1'b0;

        case (inst[1:0])
        // ============================ Quadrant 0 =============================
        2'b00: begin
            case (inst[15:13])
                3'b000: begin // C.ADDI4SPN -> addi rd', x2, nzuimm
                    if (inst[12:5] == 8'd0) illegal = 1'b1;    // 全零保留
                    else instr32 = enc_i(imm_addi4spn, 5'd2, 3'b000, rd_p, 7'b0010011);
                end
                3'b010: begin // C.LW -> lw rd', uimm(rs1')
                    instr32 = enc_i({5'd0, imm_lw}, rs1p, 3'b010, rd_p, 7'b0000011);
                end
                3'b110: begin // C.SW -> sw rs2', uimm(rs1')
                    instr32 = {5'd0, imm_lw[6:5], rs2p, rs1p, 3'b010, imm_lw[4:0], 7'b0100011};
                end
                default: illegal = 1'b1;   // 001/011/100/101/111: FLD/FLW/FSD/FSW/保留
            endcase
        end
        // ============================ Quadrant 1 =============================
        2'b01: begin
            case (inst[15:13])
                3'b000: begin // C.ADDI / C.NOP
                    instr32 = enc_i(imm_ci_sext[11:0], inst[11:7], 3'b000, inst[11:7], 7'b0010011);
                end
                3'b001: begin // C.JAL (RV32) -> jal x1, offset
                    instr32 = enc_j(imm_cj_sext, 5'd1);
                end
                3'b010: begin // C.LI -> addi rd, x0, imm
                    instr32 = enc_i(imm_ci_sext[11:0], 5'd0, 3'b000, inst[11:7], 7'b0010011);
                end
                3'b011: begin
                    if (inst[11:7] == 5'd2) begin // C.ADDI16SP
                        if (imm_addi16sp == 10'd0) illegal = 1'b1;
                        else instr32 = enc_i(imm_sp_sext[11:0], 5'd2, 3'b000, 5'd2, 7'b0010011);
                    end else if (inst[11:7] == 5'd0) begin
                        illegal = 1'b1;          // C.LUI rd=0 保留
                    end else begin               // C.LUI
                        instr32 = {imm_lui[31:12], inst[11:7], 7'b0110111};
                    end
                end
                3'b100: begin
                    case (inst[11:10])
                        2'b00: // C.SRLI
                            instr32 = {7'b0000000, inst[6:2], rs1p, 3'b101, rs1p, 7'b0010011};
                        2'b01: // C.SRAI
                            instr32 = {7'b0100000, inst[6:2], rs1p, 3'b101, rs1p, 7'b0010011};
                        2'b10: // C.ANDI
                            instr32 = enc_i(imm_ci_sext[11:0], rs1p, 3'b111, rs1p, 7'b0010011);
                        default: begin // 寄存器-寄存器: SUB/XOR/OR/AND
                            if (inst[12] != 1'b0) illegal = 1'b1;
                            else case (inst[6:5])
                                2'b00: instr32 = {7'b0100000, rs2p, rs1p, 3'b000, rs1p, 7'b0110011};
                                2'b01: instr32 = {7'b0000000, rs2p, rs1p, 3'b100, rs1p, 7'b0110011};
                                2'b10: instr32 = {7'b0000000, rs2p, rs1p, 3'b110, rs1p, 7'b0110011};
                                default: instr32 = {7'b0000000, rs2p, rs1p, 3'b111, rs1p, 7'b0110011};
                            endcase
                        end
                    endcase
                end
                3'b101: begin // C.J -> jal x0, offset
                    instr32 = enc_j(imm_cj_sext, 5'd0);
                end
                3'b110: begin // C.BEQZ
                    instr32 = enc_b(imm_cb_sext, 5'd0, rs1p, 3'b000);
                end
                default: begin // C.BNEZ
                    instr32 = enc_b(imm_cb_sext, 5'd0, rs1p, 3'b001);
                end
            endcase
        end
        // ============================ Quadrant 2 =============================
        2'b10: begin
            case (inst[15:13])
                3'b000: begin // C.SLLI
                    instr32 = {7'b0000000, inst[6:2], inst[11:7], 3'b001, inst[11:7], 7'b0010011};
                end
                3'b010: begin // C.LWSP -> lw rd, uimm(x2)
                    if (inst[11:7] == 5'd0) illegal = 1'b1;
                    else instr32 = enc_i({4'd0, imm_lwsp}, 5'd2, 3'b010, inst[11:7], 7'b0000011);
                end
                3'b100: begin
                    if (inst[12] == 1'b0) begin
                        if (inst[6:2] == 5'd0) begin
                            // C.JR
                            if (inst[11:7] == 5'd0) illegal = 1'b1;
                            else instr32 = enc_i(12'd0, inst[11:7], 3'b000, 5'd0, 7'b1100111);
                        end else begin
                            // C.MV -> add rd, x0, rs2
                            instr32 = {7'b0000000, inst[6:2], 5'd0, 3'b000, inst[11:7], 7'b0110011};
                        end
                    end else begin
                        if (inst[11:7] == 5'd0 && inst[6:2] == 5'd0) begin
                            instr32 = 32'h0010_0073;               // C.EBREAK -> ebreak
                        end else if (inst[6:2] == 5'd0) begin
                            // C.JALR -> jalr x1, 0(rs1)
                            instr32 = enc_i(12'd0, inst[11:7], 3'b000, 5'd1, 7'b1100111);
                        end else begin
                            // C.ADD -> add rd, rd, rs2
                            instr32 = {7'b0000000, inst[6:2], inst[11:7], 3'b000, inst[11:7], 7'b0110011};
                        end
                    end
                end
                3'b110: begin // C.SWSP -> sw rs2, uimm(x2)
                    instr32 = {5'd0, imm_swsp[7:5], inst[6:2], 5'd2, 3'b010, imm_swsp[4:0], 7'b0100011};
                end
                default: illegal = 1'b1;   // 001/011/101/111: FLDSP/FLWSP/FSDSP/FSWSP
            endcase
        end
        default: illegal = 1'b1;           // inst[1:0]==11 不是 RVC
        endcase
    end
endmodule
