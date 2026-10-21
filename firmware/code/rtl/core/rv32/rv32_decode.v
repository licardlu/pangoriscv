//=============================================================================
// pangoriscv - rv32 core (5.2 CoreMark/MHz @126 MHz rewrite)
// Module : rv32_decode            File : rtl/core/rv32/rv32_decode.v
// Rev    : 1.0                    Date : 2026-10-21
// Brief  : RV32IM instruction decoder: one explicit control bundle per slot
//=============================================================================

// Decoding used to be split between `id`/`id_alu` (operands, write enables) and
// `ex` (which operation to perform).  That split put a second instruction-fetch
// dependent mux in front of the ALU.  This decoder emits the operation itself,
// so the execute stage is one adder plus one shift/compare tree with no
// instruction decode in the path (plan v2 section 3, stage S3).
//
// Source-register usage flags are exact: `lui`/`auipc`/`jal` read nothing and
// `jalr` reads only rs1.  A conservative flag would stall on the immediate
// field and cost cycles (mistakes-log 13.7).
//
// ALU op encoding (one-hot-ish, 4 bits):
//   0 ADD 1 SUB 2 AND 3 OR 4 XOR 5 SLL 6 SRL 7 SRA 8 SLT 9 SLTU 10 PASS_B 11 PASS_A
// Operand selects:
//   a_sel 0 = rs1, 1 = pc, 2 = zero
//   b_sel 0 = rs2, 1 = imm
module rv32_decode(
    input  wire [31:0] inst,
    output wire [4:0]  rs1,
    output wire [4:0]  rs2,
    output wire [4:0]  rd,
    output wire        uses_rs1,
    output wire        uses_rs2,
    output wire        reg_we,
    output wire [3:0]  alu_op,
    output wire [1:0]  a_sel,
    output wire [1:0]  b_sel,
    output wire [31:0] imm,
    output wire        is_load,
    output wire        is_store,
    output wire        is_branch,
    output wire        is_jal,
    output wire        is_jalr,
    output wire        is_csr,
    output wire        is_mret,
    output wire        is_ecall,
    output wire        is_ebreak,
    output wire [2:0]  br_op,
    output wire [1:0]  mem_size,
    output wire        load_unsigned,
    output wire        is_mul,
    output wire        is_div,
    output wire [2:0]  muldiv_op,
    output wire [1:0]  csr_op,
    output wire [11:0] csr_addr,
    output wire        illegal
);
    localparam [6:0] OP_LUI   = 7'b0110111;
    localparam [6:0] OP_AUIPC = 7'b0010111;
    localparam [6:0] OP_JAL   = 7'b1101111;
    localparam [6:0] OP_JALR  = 7'b1100111;
    localparam [6:0] OP_BR    = 7'b1100011;
    localparam [6:0] OP_LOAD  = 7'b0000011;
    localparam [6:0] OP_STORE = 7'b0100011;
    localparam [6:0] OP_IMM   = 7'b0010011;
    localparam [6:0] OP_REG   = 7'b0110011;
    localparam [6:0] OP_FENCE = 7'b0001111;
    localparam [6:0] OP_SYS   = 7'b1110011;

    wire [6:0] opcode = inst[6:0];
    wire [2:0] funct3 = inst[14:12];
    wire [6:0] funct7 = inst[31:25];

    assign rs1 = inst[19:15];
    assign rs2 = inst[24:20];
    assign rd  = inst[11:7];

    wire [31:0] imm_i = {{20{inst[31]}}, inst[31:20]};
    wire [31:0] imm_s = {{20{inst[31]}}, inst[31:25], inst[11:7]};
    wire [31:0] imm_b = {{19{inst[31]}}, inst[31], inst[7], inst[30:25],
                         inst[11:8], 1'b0};
    wire [31:0] imm_u = {inst[31:12], 12'h000};
    wire [31:0] imm_j = {{11{inst[31]}}, inst[31], inst[19:12], inst[20],
                         inst[30:21], 1'b0};

    wire is_muldiv_class = (opcode == OP_REG) && (funct7 == 7'b0000001);

    reg [3:0]  alu_op_r;
    reg [1:0]  a_sel_r, b_sel_r;
    reg [31:0] imm_r;
    reg        we_r, l_r, s_r, br_r, jal_r, jalr_r, csr_r, mret_r, ecall_r, ebrk_r;
    reg [1:0]  size_r;
    reg        uns_r;
    reg [2:0]  br_op_r, md_op_r;
    reg [1:0]  csr_op_r;
    reg        illegal_r;
    reg        u1_r, u2_r;

    always @(*) begin
        alu_op_r = 4'd0; a_sel_r = 2'd0; b_sel_r = 2'd0; imm_r = 32'd0;
        we_r = 0; l_r = 0; s_r = 0; br_r = 0; jal_r = 0; jalr_r = 0;
        csr_r = 0; mret_r = 0; ecall_r = 0; ebrk_r = 0;
        size_r = 2'd2; uns_r = 0; br_op_r = 3'd0; md_op_r = 3'd0; csr_op_r = 2'd0;
        illegal_r = 0; u1_r = 0; u2_r = 0;

        case (opcode)
            OP_LUI: begin
                we_r = 1; alu_op_r = 4'd10; a_sel_r = 2'd2; b_sel_r = 2'd1;
                imm_r = imm_u;
            end
            OP_AUIPC: begin
                we_r = 1; alu_op_r = 4'd0; a_sel_r = 2'd1; b_sel_r = 2'd1;
                imm_r = imm_u;
            end
            OP_JAL: begin
                // The link value (pc+4) and the jump displacement are two
                // different constants: the ALU produces pc+4 (b_sel=2 is the
                // literal 4) while the target adder uses imm_j.
                we_r = 1; jal_r = 1; alu_op_r = 4'd0; a_sel_r = 2'd1;
                b_sel_r = 2'd2; imm_r = imm_j;
            end
            OP_JALR: begin
                if (funct3 == 3'd0) begin
                    // rd = pc+4, target = rs1+imm_i (computed by the target adder).
                    we_r = 1; jalr_r = 1; u1_r = 1;
                    alu_op_r = 4'd0; a_sel_r = 2'd1; b_sel_r = 2'd2; imm_r = imm_i;
                end else illegal_r = 1;
            end
            OP_BR: begin
                // The comparator is the ALU, so the branch compares rs1 against
                // **rs2**; b_sel=1 (immediate) would compare rs1 against the
                // displacement.  bne survives that mistake by accident (1 != 16)
                // which is why only beq/blt/bge showed up as broken.
                br_r = 1; u1_r = 1; u2_r = 1;
                imm_r = imm_b; b_sel_r = 2'd0;
                case (funct3)
                    3'd0: br_op_r = 3'd0;   // beq
                    3'd1: br_op_r = 3'd1;   // bne
                    3'd4: br_op_r = 3'd2;   // blt
                    3'd5: br_op_r = 3'd3;   // bge
                    3'd6: br_op_r = 3'd4;   // bltu
                    3'd7: br_op_r = 3'd5;   // bgeu
                    default: illegal_r = 1;
                endcase
            end
            OP_LOAD: begin
                u1_r = 1;
                // load_unsigned means ZERO-extend, so lb/lh are signed (0) and
                // lbu/lhu are unsigned (1).  Getting this backwards swaps the
                // sign of every byte/halfword load -- exactly what the ISA
                // regression reported (lbu returning 0xffffffcd, and vice versa).
                case (funct3)
                    3'd0: begin l_r = 1; size_r = 2'd0; uns_r = 0; end  // lb
                    3'd1: begin l_r = 1; size_r = 2'd1; uns_r = 0; end  // lh
                    3'd2: begin l_r = 1; size_r = 2'd2; uns_r = 1; end  // lw
                    3'd4: begin l_r = 1; size_r = 2'd0; uns_r = 1; end  // lbu
                    3'd5: begin l_r = 1; size_r = 2'd1; uns_r = 1; end  // lhu
                    default: illegal_r = 1;
                endcase
                if (!illegal_r) begin
                    we_r = 1; alu_op_r = 4'd0; a_sel_r = 2'd0; b_sel_r = 2'd1;
                    imm_r = imm_i;
                end
            end
            OP_STORE: begin
                u1_r = 1; u2_r = 1;
                case (funct3)
                    3'd0: begin s_r = 1; size_r = 2'd0; end
                    3'd1: begin s_r = 1; size_r = 2'd1; end
                    3'd2: begin s_r = 1; size_r = 2'd2; end
                    default: illegal_r = 1;
                endcase
                if (!illegal_r) begin
                    alu_op_r = 4'd0; a_sel_r = 2'd0; b_sel_r = 2'd1; imm_r = imm_s;
                end
            end
            OP_IMM: begin
                u1_r = 1; we_r = 1;
                a_sel_r = 2'd0; b_sel_r = 2'd1;
                case (funct3)
                    3'd0: begin alu_op_r = 4'd0; imm_r = imm_i; end
                    3'd2: begin alu_op_r = 4'd8; imm_r = imm_i; end
                    3'd3: begin alu_op_r = 4'd9; imm_r = imm_i; end
                    3'd4: begin alu_op_r = 4'd4; imm_r = imm_i; end
                    3'd6: begin alu_op_r = 4'd3; imm_r = imm_i; end
                    3'd7: begin alu_op_r = 4'd2; imm_r = imm_i; end
                    3'd1: begin
                        if (funct7 == 7'b0000000) begin
                            alu_op_r = 4'd5; imm_r = {27'd0, inst[24:20]};
                        end else illegal_r = 1;
                    end
                    3'd5: begin
                        if (funct7 == 7'b0000000) begin
                            alu_op_r = 4'd6; imm_r = {27'd0, inst[24:20]};
                        end else if (funct7 == 7'b0100000) begin
                            alu_op_r = 4'd7; imm_r = {27'd0, inst[24:20]};
                        end else illegal_r = 1;
                    end
                    default: illegal_r = 1;
                endcase
            end
            OP_REG: begin
                u1_r = 1; u2_r = 1;
                a_sel_r = 2'd0; b_sel_r = 2'd0;
                if (funct7 == 7'b0000001) begin
                    we_r = 1;
                    case (funct3)
                        3'd0: begin md_op_r = 3'd0; end   // mul
                        3'd1: begin md_op_r = 3'd1; end   // mulh
                        3'd2: begin md_op_r = 3'd2; end   // mulhsu
                        3'd3: begin md_op_r = 3'd3; end   // mulhu
                        3'd4: begin md_op_r = 3'd4; end   // div
                        3'd5: begin md_op_r = 3'd5; end   // divu
                        3'd6: begin md_op_r = 3'd6; end   // rem
                        3'd7: begin md_op_r = 3'd7; end   // remu
                    endcase
                end else begin
                    we_r = 1;
                    case ({funct7, funct3})
                        {7'b0000000, 3'd0}: alu_op_r = 4'd0;  // add
                        {7'b0100000, 3'd0}: alu_op_r = 4'd1;  // sub
                        {7'b0000000, 3'd1}: alu_op_r = 4'd5;  // sll
                        {7'b0000000, 3'd2}: alu_op_r = 4'd8;  // slt
                        {7'b0000000, 3'd3}: alu_op_r = 4'd9;  // sltu
                        {7'b0000000, 3'd4}: alu_op_r = 4'd4;  // xor
                        {7'b0000000, 3'd5}: alu_op_r = 4'd6;  // srl
                        {7'b0100000, 3'd5}: alu_op_r = 4'd7;  // sra
                        {7'b0000000, 3'd6}: alu_op_r = 4'd3;  // or
                        {7'b0000000, 3'd7}: alu_op_r = 4'd2;  // and
                        default: illegal_r = 1;
                    endcase
                end
            end
            OP_FENCE: begin
                // FENCE is an architectural nop on a single hart.  FENCE.I stays
                // illegal on purpose: the ISA regression (case 9) requires the
                // mcause=2 trap with mtval=0x0000100f, and the core has no
                // instruction-cache invalidate path (mistakes-log R05).
                if (funct3 != 3'd0) illegal_r = 1;
            end
            OP_SYS: begin
                case (funct3)
                    3'd0: begin
                        if (inst == 32'h30200073) mret_r = 1;        // mret
                        else if (inst[31:20] == 12'h000) ecall_r = 1; // ecall
                        else if (inst[31:20] == 12'h001) ebrk_r = 1;  // ebreak
                        else illegal_r = 1;
                    end
                    3'd1, 3'd2, 3'd3, 3'd5, 3'd6, 3'd7: begin
                        csr_r = 1; we_r = 1;
                        // funct3 1/2/3 are the rs1 forms, 5/6/7 the immediate
                        // forms (csrrwi/csrrsi/csrrci) whose rs1 field IS the
                        // 5-bit zimm.  Testing only ==5 made csrrsi/csrrci read
                        // a register instead of their immediate.
                        u1_r = (funct3 < 3'd5);
                        csr_op_r = (funct3 == 3'd1 || funct3 == 3'd5) ? 2'd0 :
                                   (funct3 == 3'd2 || funct3 == 3'd6) ? 2'd1 : 2'd2;
                    end
                    default: illegal_r = 1;
                endcase
            end
            default: illegal_r = 1;
        endcase
    end

    // M-extension split: the multiplier is a separate pipelined unit, the
    // divider keeps its iterative engine, so neither may appear in alu_op.
    assign is_mul    = is_muldiv_class && (funct3[2] == 1'b0);
    assign is_div    = is_muldiv_class && (funct3[2] == 1'b1);
    assign muldiv_op = md_op_r;

    assign reg_we        = we_r && !illegal_r;
    assign alu_op        = alu_op_r;
    assign a_sel         = a_sel_r;
    assign b_sel         = b_sel_r;
    assign imm           = imm_r;
    assign is_load       = l_r && !illegal_r;
    assign is_store      = s_r && !illegal_r;
    assign is_branch     = br_r && !illegal_r;
    assign is_jal        = jal_r && !illegal_r;
    assign is_jalr       = jalr_r && !illegal_r;
    assign is_csr        = csr_r && !illegal_r;
    assign is_mret       = mret_r;
    assign is_ecall      = ecall_r;
    assign is_ebreak     = ebrk_r;
    assign br_op         = br_op_r;
    assign mem_size      = size_r;
    assign load_unsigned = uns_r;
    assign csr_op        = csr_op_r;
    assign csr_addr      = inst[31:20];
    assign illegal       = illegal_r;
    assign uses_rs1      = u1_r;
    assign uses_rs2      = u2_r;
endmodule
