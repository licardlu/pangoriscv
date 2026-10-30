`include "core_defs.vh"

module core_decoder (
    input  wire [31:0] instr,
    input  wire        rvc_illegal,
    output reg         illegal,

    // 寄存器索引与使能
    output reg  [4:0]  rd,
    output reg  [4:0]  rs1,
    output reg  [4:0]  rs2,
    output reg         rd_we,
    output reg         rs1_use,
    output reg         rs2_use,

    output reg  [31:0] imm,

    // 执行控制
    output reg  [1:0]  src1_sel,
    output reg  [1:0]  src2_sel,
    output reg  [1:0]  alu_bitwise,
    output reg         alu_addsub,
    output reg         alu_revert,
    output reg         alu_sltx,
    output reg         alu_unsigned,
    output reg         alu_zero_src2,
    output reg         is_shift,
    output reg  [1:0]  shift_mode,
    output reg  [1:0]  wb_sel,

    // 访存
    output reg         mem_read,
    output reg         mem_write,
    output reg  [1:0]  mem_size,
    output reg         mem_unsigned,

    // 控制流
    output reg         is_branch,
    output reg         is_jal,
    output reg         is_jalr,
    output reg  [2:0]  funct3,

    // 乘除
    output reg         is_mdu,
    output reg  [2:0]  mdu_op,

    // CSR / 系统
    output reg  [1:0]  csr_op,
    output reg  [11:0] csr_addr,
    output reg         csr_use_imm,
    output reg         is_ecall,
    output reg         is_ebreak,
    output reg         is_mret,
    output reg         is_fence,
    output reg         is_fence_i
);
    wire [6:0] opcode = instr[6:0];
    wire [2:0] f3     = instr[14:12];
    wire [6:0] f7     = instr[31:25];

    // --------------------------------- 立即数 ---------------------------------
    wire [31:0] imm_i = {{20{instr[31]}}, instr[31:20]};
    wire [31:0] imm_s = {{20{instr[31]}}, instr[31:25], instr[11:7]};
    wire [31:0] imm_b = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
    wire [31:0] imm_u = {instr[31:12], 12'b0};
    wire [31:0] imm_j = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};

    always @(*) begin
        // 缺省: 一条什么都不做的 NOP, 同时把 illegal 清零
        illegal      = rvc_illegal;
        rd           = instr[11:7];
        rs1          = instr[19:15];
        rs2          = instr[24:20];
        rd_we        = 1'b0;
        rs1_use      = 1'b0;
        rs2_use      = 1'b0;
        imm          = 32'd0;
        src1_sel     = `SRC1_RF;
        src2_sel     = `SRC2_RF;
        alu_bitwise  = `ALU_BW_ZERO;
        alu_addsub   = 1'b0;
        alu_revert   = 1'b0;
        alu_sltx     = 1'b0;
        alu_unsigned = 1'b0;
        alu_zero_src2= 1'b0;
        is_shift     = 1'b0;
        shift_mode   = 2'd0;
        wb_sel       = `WB_ALU;
        mem_read     = 1'b0;
        mem_write    = 1'b0;
        mem_size     = `MSIZE_W;
        mem_unsigned = 1'b0;
        is_branch    = 1'b0;
        is_jal       = 1'b0;
        is_jalr      = 1'b0;
        funct3       = f3;
        is_mdu       = 1'b0;
        mdu_op       = 3'd0;
        csr_op       = `CSR_NONE;
        csr_addr     = instr[31:20];
        csr_use_imm  = 1'b0;
        is_ecall     = 1'b0;
        is_ebreak    = 1'b0;
        is_mret      = 1'b0;
        is_fence     = 1'b0;
        is_fence_i   = 1'b0;

        case (opcode)
        // ------------------------------- LUI / AUIPC -------------------------
        7'b0110111: begin                                  // LUI
            rd          = instr[11:7];
            rd_we       = 1'b1;
            imm         = imm_u;
            src1_sel    = `SRC1_U;
            src2_sel    = `SRC2_RF;
            alu_addsub  = 1'b1;
            alu_zero_src2 = 1'b1;
        end
        7'b0010111: begin                                  // AUIPC
            rd          = instr[11:7];
            rd_we       = 1'b1;
            imm         = imm_u;
            src1_sel    = `SRC1_U;
            src2_sel    = `SRC2_PC;
            alu_addsub  = 1'b1;
        end
        // ------------------------------- JAL ---------------------------------
        7'b1101111: begin
            rd          = instr[11:7];
            rd_we       = 1'b1;
            imm         = imm_j;
            is_jal      = 1'b1;
            wb_sel      = `WB_PC4;
        end
        // ------------------------------- JALR --------------------------------
        7'b1100111: begin
            if (f3 != 3'b000) illegal = 1'b1;
            rd          = instr[11:7];
            rd_we       = 1'b1;
            rs1_use     = 1'b1;
            imm         = imm_i;
            is_jalr     = 1'b1;
            wb_sel      = `WB_PC4;
        end
        // ------------------------------- BRANCH ------------------------------
        7'b1100011: begin
            if (f3 == 3'b010 || f3 == 3'b011) illegal = 1'b1;
            rs1_use     = 1'b1;
            rs2_use     = 1'b1;
            imm         = imm_b;
            is_branch   = 1'b1;
        end
        // ------------------------------- LOAD --------------------------------
        7'b0000011: begin
            rs1_use     = 1'b1;
            imm         = imm_i;
            src2_sel    = `SRC2_I;      // 地址 = rs1 + imm.i
            alu_addsub  = 1'b1;
            mem_read    = 1'b1;
            rd_we       = 1'b1;
            wb_sel      = `WB_MEM;
            case (f3)
                3'b000: begin mem_size = `MSIZE_B; mem_unsigned = 1'b0; end
                3'b001: begin mem_size = `MSIZE_H; mem_unsigned = 1'b0; end
                3'b010: begin mem_size = `MSIZE_W; mem_unsigned = 1'b0; end
                3'b100: begin mem_size = `MSIZE_B; mem_unsigned = 1'b1; end
                3'b101: begin mem_size = `MSIZE_H; mem_unsigned = 1'b1; end
                default: illegal = 1'b1;
            endcase
        end
        // ------------------------------- STORE -------------------------------
        7'b0100011: begin
            rs1_use     = 1'b1;
            rs2_use     = 1'b1;
            imm         = imm_s;
            src2_sel    = `SRC2_S;      // 地址 = rs1 + imm.s
            alu_addsub  = 1'b1;
            mem_write   = 1'b1;
            case (f3)
                3'b000: mem_size = `MSIZE_B;
                3'b001: mem_size = `MSIZE_H;
                3'b010: mem_size = `MSIZE_W;
                default: illegal = 1'b1;
            endcase
        end
        // ------------------------------- OP-IMM ------------------------------
        7'b0010011: begin
            rd          = instr[11:7];
            rs1_use     = 1'b1;
            rd_we       = 1'b1;
            imm         = imm_i;
            src2_sel    = `SRC2_I;
            case (f3)
                3'b000: begin alu_addsub = 1'b1; alu_revert = 1'b0; end   // ADDI
                3'b010: begin alu_sltx = 1'b1; alu_revert = 1'b1; alu_unsigned = 1'b0; end // SLTI
                3'b011: begin alu_sltx = 1'b1; alu_revert = 1'b1; alu_unsigned = 1'b1; end // SLTIU
                3'b100: begin alu_bitwise = `ALU_BW_XOR; end               // XORI
                3'b110: begin alu_bitwise = `ALU_BW_OR;  end               // ORI
                3'b111: begin alu_bitwise = `ALU_BW_AND; end               // ANDI
                3'b001: begin                                              // SLLI
                    if (f7 != 7'b0000000) illegal = 1'b1;
                    is_shift = 1'b1; shift_mode = 2'd0;
                end
                3'b101: begin                                              // SRLI / SRAI
                    if (f7 == 7'b0000000)      shift_mode = 2'd1;
                    else if (f7 == 7'b0100000) shift_mode = 2'd2;
                    else illegal = 1'b1;
                    is_shift = 1'b1;
                end
            endcase
        end
        // ------------------------------- OP ----------------------------------
        7'b0110011: begin
            rd          = instr[11:7];
            rs1_use     = 1'b1;
            rs2_use     = 1'b1;
            rd_we       = 1'b1;
            if (f7 == 7'b0000001) begin                            // RV32M
                is_mdu = 1'b1;
                mdu_op = f3;
            end else begin
                case (f3)
                    3'b000: begin
                        if (f7 == 7'b0000000)      begin alu_addsub = 1'b1; alu_revert = 1'b0; end // ADD
                        else if (f7 == 7'b0100000) begin alu_addsub = 1'b1; alu_revert = 1'b1; end // SUB
                        else illegal = 1'b1;
                    end
                    3'b001: begin
                        if (f7 != 7'b0000000) illegal = 1'b1;
                        is_shift = 1'b1; shift_mode = 2'd0;             // SLL
                    end
                    3'b010: begin alu_sltx = 1'b1; alu_revert = 1'b1; alu_unsigned = 1'b0; end // SLT
                    3'b011: begin alu_sltx = 1'b1; alu_revert = 1'b1; alu_unsigned = 1'b1; end // SLTU
                    3'b100: begin alu_bitwise = `ALU_BW_XOR; end        // XOR
                    3'b101: begin
                        if (f7 == 7'b0000000)      shift_mode = 2'd1;
                        else if (f7 == 7'b0100000) shift_mode = 2'd2;
                        else illegal = 1'b1;
                        is_shift = 1'b1;                                 // SRL / SRA
                    end
                    3'b110: begin alu_bitwise = `ALU_BW_OR;  end        // OR
                    default: begin alu_bitwise = `ALU_BW_AND; end       // AND
                endcase
            end
        end
        // ------------------------------- MISC-MEM ----------------------------
        7'b0001111: begin
            case (f3)
                3'b000: begin is_fence = 1'b1; end
                3'b001: begin is_fence_i = 1'b1; end
                default: illegal = 1'b1;
            endcase
            rs1_use = (instr[19:15] != 5'd0);   // FENCE 的 pred/succ 字段
            rs2_use = 1'b0;
        end
        // ------------------------------- SYSTEM ------------------------------
        7'b1110011: begin
            case (f3)
                3'b000: begin
                    if (instr == 32'h0000_0073)      is_ecall  = 1'b1;
                    else if (instr == 32'h0010_0073) is_ebreak = 1'b1;
                    else if (instr == 32'h3020_0073) is_mret   = 1'b1;
                    else illegal = 1'b1;
                end
                3'b001: begin csr_op = `CSR_RW; end
                3'b010: begin csr_op = `CSR_RS; end
                3'b011: begin csr_op = `CSR_RC; end
                3'b101: begin csr_op = `CSR_RW; csr_use_imm = 1'b1; end
                3'b110: begin csr_op = `CSR_RS; csr_use_imm = 1'b1; end
                3'b111: begin csr_op = `CSR_RC; csr_use_imm = 1'b1; end
                default: illegal = 1'b1;
            endcase
            if (csr_op != `CSR_NONE || is_ecall || is_ebreak || is_mret) begin
                rd      = instr[11:7];
                rd_we   = (csr_op != `CSR_NONE) && (instr[11:7] != 5'd0);
                // csrrw/csrrwi 在 rd=x0 时不需要读 CSR, 但写仍要发生
                rs1_use = (csr_op == `CSR_RS) || (csr_op == `CSR_RC) ||
                          ((csr_op == `CSR_RW) && (instr[11:7] != 5'd0));
                wb_sel  = `WB_CSR;
                rs1     = instr[19:15];
            end
        end
        default: illegal = 1'b1;
        endcase
    end

    // FENCE 不写寄存器, 只是一次顺序屏障
    // (此处显式覆盖, 避免上面 SYSTEM 分支的通用赋值影响)
endmodule
