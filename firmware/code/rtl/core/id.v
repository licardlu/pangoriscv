//=============================================================================
// pangoriscv - RV32IM processor core + native AXI4 SoC (Pango PG2L100H @ 27 MHz)
// Module : id                     File : rtl/core/id.v
// Rev    : 1.0                    Date : 2026-10-13
// Author : pango_lpenghan
// Brief  : Instruction decode. The fetched word is sliced into fields, the
//          format-specific immediates are assembled once, and one table maps each
//          encoding onto the GPR, CSR and EX operand sources it drives.
//=============================================================================

`include "defines.v"

module id(
    input  wire                rst,            // active-low reset; decode holds no state
    input  wire [`InstBus]     inst_i,         // instruction word from IF
    input  wire [`InstAddrBus] inst_addr_i,    // address of that instruction
    input  wire [`RegBus]      reg1_rdata_i,   // GPR read port 1 data
    input  wire [`RegBus]      reg2_rdata_i,   // GPR read port 2 data
    input  wire [`RegBus]      csr_rdata_i,    // CSR read data
    input  wire                ex_jump_flag_i, // EX jump decision (interface compatibility)
    output reg  [`RegAddrBus]  reg1_raddr_o,   // GPR read port 1 address
    output reg  [`RegAddrBus]  reg2_raddr_o,   // GPR read port 2 address
    output reg  [`MemAddrBus]  csr_raddr_o,    // CSR read address
    output reg  [`MemAddrBus]  op1_o,          // EX operand 1
    output reg  [`MemAddrBus]  op2_o,          // EX operand 2
    output reg  [`MemAddrBus]  op1_jump_o,     // EX jump base operand
    output reg  [`MemAddrBus]  op2_jump_o,     // EX jump offset operand
    output reg  [`InstBus]     inst_o,         // instruction word to ID/EX
    output reg  [`InstAddrBus] inst_addr_o,    // instruction address to ID/EX
    output reg  [`RegBus]      reg1_rdata_o,   // GPR read port 1 data to ID/EX
    output reg  [`RegBus]      reg2_rdata_o,   // GPR read port 2 data to ID/EX
    output reg                 reg_we_o,       // GPR write enable
    output reg  [`RegAddrBus]  reg_waddr_o,    // GPR write address
    output reg                 csr_we_o,       // CSR write enable
    output reg  [`RegBus]      csr_rdata_o,    // CSR read data to ID/EX
    output reg  [`MemAddrBus]  csr_waddr_o,    // CSR write address
    output reg                 illegal_o,      // encoding has no implementation
    output reg                 uses_rs1_o,     // instruction consumes rs1
    output reg                 uses_rs2_o      // instruction consumes rs2
);

    //------------------------------------------------------------- field slices
    // The fields are cut out once and referenced by name from every block below.
    wire [6:0] op_field  = inst_i[6:0];
    wire [2:0] fn3_field = inst_i[14:12];
    wire [6:0] fn7_field = inst_i[31:25];
    wire [4:0] rd_field  = inst_i[11:7];
    wire [4:0] rs1_field = inst_i[19:15];
    wire [4:0] rs2_field = inst_i[24:20];

    //-------------------------------------------------------- immediate assembly
    // I, S, B and J immediates are sign-extended to XLEN.  The S and B layouts
    // spread their value over two groups of instruction bits, so they are
    // stitched back together here; the U immediate only needs its low bits
    // cleared.
    wire [`RegBus] imm_i = {{20{inst_i[31]}}, inst_i[31:20]};
    wire [`RegBus] imm_s = {{20{inst_i[31]}}, inst_i[31:25], inst_i[11:7]};
    wire [`RegBus] imm_b = {{20{inst_i[31]}}, inst_i[7], inst_i[30:25], inst_i[11:8], 1'b0};
    wire [`RegBus] imm_j = {{12{inst_i[31]}}, inst_i[19:12], inst_i[20], inst_i[30:21], 1'b0};
    wire [`RegBus] imm_u = {inst_i[31:12], 12'h000};

    // Address of the instruction after this one: the link value, and the
    // sequential next-PC published on the jump pair by FENCE and by the divider
    // handshake.
    wire [`RegBus] pc_inc = 32'h00000004;

    // CSR number lives in the I-immediate field and is zero-extended to the CSR
    // address width; the read and write ports share it.
    wire [`MemAddrBus] csr_sel = {20'h00000, inst_i[31:20]};

    //-------------------------------------------------------- selector encodings
    // Codes produced by the decode table below and consumed by the port mapping.
    localparam OP1_NONE = 2'd0;   // operand 1 is zero
    localparam OP1_RS1  = 2'd1;   // operand 1 is the rs1 read data
    localparam OP1_PC   = 2'd2;   // operand 1 is the instruction address
    localparam OP1_UIMM = 2'd3;   // operand 1 is the U immediate

    localparam OP2_NONE = 3'd0;   // operand 2 is zero
    localparam OP2_RS2  = 3'd1;   // operand 2 is the rs2 read data
    localparam OP2_IMMI = 3'd2;   // operand 2 is the I immediate
    localparam OP2_IMMS = 3'd3;   // operand 2 is the S immediate
    localparam OP2_IMMU = 3'd4;   // operand 2 is the U immediate
    localparam OP2_PC4  = 3'd5;   // operand 2 is the following PC

    localparam JMP_NONE = 3'd0;   // jump pair unused
    localparam JMP_BREL = 3'd1;   // PC + B immediate
    localparam JMP_LINK = 3'd2;   // PC + J immediate
    localparam JMP_REG  = 3'd3;   // rs1 + I immediate
    localparam JMP_HAND = 3'd4;   // PC + following PC (handshake only)

    // Decode selectors: which source feeds each destination port.
    reg        sel_wr;            // rd receives a result
    reg        sel_rs1;           // the rs1 read port is used
    reg        sel_rs2;           // the rs2 read port is used
    reg        sel_csr;           // the CSR address ports are used
    reg        sel_csrwe;         // the CSR write port is used
    reg  [1:0] sel_op1;           // source of operand 1
    reg  [2:0] sel_op2;           // source of operand 2
    reg  [2:0] sel_jmp;           // shape of the jump operand pair

    //----------------------------------------------------------- register usage
    // Tells the hazard logic whether the instruction really consumes rs1/rs2;
    // several encodings of the same opcode leave those fields unused.
    always @(*) begin
        uses_rs1_o = `WriteDisable;
        uses_rs2_o = `WriteDisable;

        if (op_field == `INST_TYPE_I || op_field == `INST_TYPE_L ||
            op_field == `INST_JALR) begin
            uses_rs1_o = `WriteEnable;
        end else if (op_field == `INST_TYPE_R_M || op_field == `INST_TYPE_S ||
                     op_field == `INST_TYPE_B) begin
            uses_rs1_o = `WriteEnable;
            uses_rs2_o = `WriteEnable;
        end else if (op_field == `INST_CSR) begin
            // The register forms read their source from rs1, the immediate forms
            // carry a uimm there instead, and the privileged encodings encode no
            // register operand at all.
            if (fn3_field == 3'b000)
                uses_rs1_o = `WriteDisable;
            else
                uses_rs1_o = ~fn3_field[2];
        end
    end

    //-------------------------------------------------------------- legality check
    // The flag is the exact complement of the implemented set, so an encoding
    // with unknown bits in a field never turns into a legal instruction.
    always @(*) begin
        illegal_o = `WriteDisable;

        if (op_field == `INST_TYPE_I) begin
            // Only the shift forms define the upper immediate bits; for the other
            // arithmetic forms those bits belong to the immediate.
            if (fn3_field == `INST_SLLI)
                illegal_o = (fn7_field != 7'h00);
            else if (fn3_field == `INST_SRI)
                illegal_o = (fn7_field != 7'h00) && (fn7_field != 7'h20);
        end else if (op_field == `INST_TYPE_R_M) begin
            // funct7 selects the family: 0x00 the base ALU set, 0x01 the M
            // extension, 0x20 a two-instruction part of the base set.
            illegal_o = !(fn7_field == 7'h00 ||
                          fn7_field == 7'h01 ||
                          (fn7_field == 7'h20 &&
                           (fn3_field == `INST_ADD_SUB || fn3_field == `INST_SR)));
        end else if (op_field == `INST_TYPE_L) begin
            illegal_o = !(fn3_field == `INST_LB  || fn3_field == `INST_LH  ||
                          fn3_field == `INST_LW  || fn3_field == `INST_LBU ||
                          fn3_field == `INST_LHU);
        end else if (op_field == `INST_TYPE_S) begin
            illegal_o = !(fn3_field == `INST_SB || fn3_field == `INST_SH ||
                          fn3_field == `INST_SW);
        end else if (op_field == `INST_TYPE_B) begin
            illegal_o = !(fn3_field == `INST_BEQ  || fn3_field == `INST_BNE ||
                          fn3_field == `INST_BLT  || fn3_field == `INST_BGE ||
                          fn3_field == `INST_BLTU || fn3_field == `INST_BGEU);
        end else if (op_field == `INST_JALR) begin
            // JALR requires the reserved funct3 = 000.
            illegal_o = (fn3_field != 3'b000);
        end else if (op_field == `INST_FENCE) begin
            // FENCE is implemented, FENCE.I is not.
            illegal_o = (fn3_field != 3'b000);
        end else if (op_field == `INST_CSR) begin
            if (fn3_field == 3'b000) begin
                // Privileged encodings: only the three implemented ones pass.
                illegal_o = !(inst_i == `INST_ECALL ||
                              inst_i == `INST_EBREAK ||
                              inst_i == `INST_MRET);
            end else begin
                // funct3 = 100 is the reserved CSR-immediate encoding.
                illegal_o = (fn3_field == 3'b100);
            end
        end else if (op_field == `INST_JAL || op_field == `INST_LUI ||
                     op_field == `INST_AUIPC) begin
            illegal_o = `WriteDisable;
        end else begin
            // No implementation for this opcode, the pipeline bubble included.
            illegal_o = `WriteEnable;
        end
    end

    //------------------------------------------------------------ decode table
    // One row per implemented encoding.  A row only names the sources that feed
    // the operand pair, the GPR ports and the CSR interface; turning a row into
    // actual port values happens once, in the mapping below.  Rows that a field
    // encoding does not select leave the inactive defaults in place.
    always @(*) begin
        sel_wr    = `WriteDisable;
        sel_rs1   = `WriteDisable;
        sel_rs2   = `WriteDisable;
        sel_csr   = `WriteDisable;
        sel_csrwe = `WriteDisable;
        sel_op1   = OP1_NONE;
        sel_op2   = OP2_NONE;
        sel_jmp   = JMP_NONE;

        if (op_field == `INST_TYPE_I) begin
            // Immediate ALU set.  All eight funct3 values are implemented and the
            // shift amount travels in the same immediate field, so the field needs
            // no further qualification.
            if (fn3_field == `INST_ADDI  || fn3_field == `INST_SLTI ||
                fn3_field == `INST_SLTIU || fn3_field == `INST_XORI ||
                fn3_field == `INST_ORI   || fn3_field == `INST_ANDI ||
                fn3_field == `INST_SLLI  || fn3_field == `INST_SRI) begin
                sel_wr  = `WriteEnable;
                sel_rs1 = `WriteEnable;
                sel_op1 = OP1_RS1;
                sel_op2 = OP2_IMMI;
            end
        end else if (op_field == `INST_TYPE_R_M) begin
            // Register ALU, multiply and divide.  Both ALU funct7 values share a
            // row; funct7 = 1 is the M extension, whose two halves differ only in
            // the divider handshake.
            if ((fn7_field == 7'h00 || fn7_field == 7'h20 || fn7_field == 7'h01) &&
                (fn3_field == `INST_ADD_SUB || fn3_field == `INST_SLL ||
                 fn3_field == `INST_SLT     || fn3_field == `INST_SLTU ||
                 fn3_field == `INST_XOR     || fn3_field == `INST_SR ||
                 fn3_field == `INST_OR      || fn3_field == `INST_AND)) begin
                sel_wr  = `WriteEnable;
                sel_rs1 = `WriteEnable;
                sel_rs2 = `WriteEnable;
                sel_op1 = OP1_RS1;
                sel_op2 = OP2_RS2;
                // The divider runs as a handshake, so its jump pair carries the
                // instruction address and the following PC instead of an offset.
                if (fn7_field == 7'h01 &&
                    (fn3_field == `INST_DIV || fn3_field == `INST_DIVU ||
                     fn3_field == `INST_REM || fn3_field == `INST_REMU))
                    sel_jmp = JMP_HAND;
            end
        end else if (op_field == `INST_TYPE_L) begin
            // Loads: address = rs1 + I immediate, the loaded data goes to rd.
            if (fn3_field == `INST_LB  || fn3_field == `INST_LH ||
                fn3_field == `INST_LW  || fn3_field == `INST_LBU ||
                fn3_field == `INST_LHU) begin
                sel_wr  = `WriteEnable;
                sel_rs1 = `WriteEnable;
                sel_op1 = OP1_RS1;
                sel_op2 = OP2_IMMI;
            end
        end else if (op_field == `INST_TYPE_S) begin
            // Stores: address = rs1 + S immediate, rs2 carries the data and no
            // register is written back.
            if (fn3_field == `INST_SB || fn3_field == `INST_SH ||
                fn3_field == `INST_SW) begin
                sel_rs1 = `WriteEnable;
                sel_rs2 = `WriteEnable;
                sel_op1 = OP1_RS1;
                sel_op2 = OP2_IMMS;
            end
        end else if (op_field == `INST_TYPE_B) begin
            // Conditional branches compare both GPRs and publish PC + offset as
            // the taken target.
            if (fn3_field == `INST_BEQ  || fn3_field == `INST_BNE ||
                fn3_field == `INST_BLT  || fn3_field == `INST_BGE ||
                fn3_field == `INST_BLTU || fn3_field == `INST_BGEU) begin
                sel_rs1 = `WriteEnable;
                sel_rs2 = `WriteEnable;
                sel_op1 = OP1_RS1;
                sel_op2 = OP2_RS2;
                sel_jmp = JMP_BREL;
            end
        end else if (op_field == `INST_JAL) begin
            // JAL links PC + 4 into rd and jumps PC-relative.
            sel_wr  = `WriteEnable;
            sel_op1 = OP1_PC;
            sel_op2 = OP2_PC4;
            sel_jmp = JMP_LINK;
        end else if (op_field == `INST_JALR) begin
            // JALR links the same value and jumps to rs1 + I immediate.
            sel_wr  = `WriteEnable;
            sel_rs1 = `WriteEnable;
            sel_op1 = OP1_PC;
            sel_op2 = OP2_PC4;
            sel_jmp = JMP_REG;
        end else if (op_field == `INST_LUI) begin
            // LUI ignores the PC; the U immediate is the whole operand.
            sel_wr  = `WriteEnable;
            sel_op1 = OP1_UIMM;
        end else if (op_field == `INST_AUIPC) begin
            // AUIPC adds the U immediate to the PC.
            sel_wr  = `WriteEnable;
            sel_op1 = OP1_PC;
            sel_op2 = OP2_IMMU;
        end else if (op_field == `INST_FENCE) begin
            // FENCE has no register effect and only advances the PC.
            sel_jmp = JMP_HAND;
        end else if (op_field == `INST_CSR) begin
            // The CSR number is decoded for every CSR opcode, the privileged ones
            // included.  Only the register and immediate forms can write, and only
            // the register forms read rs1.
            sel_csr = `WriteEnable;
            if (fn3_field == `INST_CSRRW || fn3_field == `INST_CSRRS ||
                fn3_field == `INST_CSRRC) begin
                sel_rs1   = `WriteEnable;
                sel_wr    = `WriteEnable;
                sel_csrwe = `WriteEnable;
            end else if (fn3_field == `INST_CSRRWI || fn3_field == `INST_CSRRSI ||
                         fn3_field == `INST_CSRRCI) begin
                sel_wr    = `WriteEnable;
                sel_csrwe = `WriteEnable;
            end
        end
        // `INST_NOP_OP (the bubble opcode) and every encoding with no row here
        // keep the inactive defaults written at the top of the block.
    end

    //------------------------------------------------------------ port mapping
    // Every port is written from this one place, so the same field set is never
    // spelled out again per encoding.  The selectors are always definite values,
    // which is why an unknown field reaches the operand path as zero and not as
    // an unknown operand.
    always @(*) begin
        // The instruction word and the GPR read data travel unchanged.
        inst_o       = inst_i;
        inst_addr_o  = inst_addr_i;
        reg1_rdata_o = reg1_rdata_i;
        reg2_rdata_o = reg2_rdata_i;
        csr_rdata_o  = csr_rdata_i;

        // GPR write port.
        if (sel_wr) begin
            reg_we_o    = `WriteEnable;
            reg_waddr_o = rd_field;
        end else begin
            reg_we_o    = `WriteDisable;
            reg_waddr_o = `ZeroReg;
        end

        // GPR read ports.
        if (sel_rs1)
            reg1_raddr_o = rs1_field;
        else
            reg1_raddr_o = `ZeroReg;

        if (sel_rs2)
            reg2_raddr_o = rs2_field;
        else
            reg2_raddr_o = `ZeroReg;

        // CSR address ports and CSR write strobe.
        if (sel_csr) begin
            csr_raddr_o = csr_sel;
            csr_waddr_o = csr_sel;
        end else begin
            csr_raddr_o = `ZeroWord;
            csr_waddr_o = `ZeroWord;
        end

        if (sel_csrwe)
            csr_we_o = `WriteEnable;
        else
            csr_we_o = `WriteDisable;

        // Operand 1.
        if (sel_op1 == OP1_RS1)
            op1_o = reg1_rdata_i;
        else if (sel_op1 == OP1_PC)
            op1_o = inst_addr_i;
        else if (sel_op1 == OP1_UIMM)
            op1_o = imm_u;
        else
            op1_o = `ZeroWord;

        // Operand 2.
        if (sel_op2 == OP2_RS2)
            op2_o = reg2_rdata_i;
        else if (sel_op2 == OP2_IMMI)
            op2_o = imm_i;
        else if (sel_op2 == OP2_IMMS)
            op2_o = imm_s;
        else if (sel_op2 == OP2_IMMU)
            op2_o = imm_u;
        else if (sel_op2 == OP2_PC4)
            op2_o = pc_inc;
        else
            op2_o = `ZeroWord;

        // Jump operand pair.
        if (sel_jmp == JMP_BREL || sel_jmp == JMP_LINK || sel_jmp == JMP_HAND)
            op1_jump_o = inst_addr_i;
        else if (sel_jmp == JMP_REG)
            op1_jump_o = reg1_rdata_i;
        else
            op1_jump_o = `ZeroWord;

        if (sel_jmp == JMP_BREL)
            op2_jump_o = imm_b;
        else if (sel_jmp == JMP_LINK)
            op2_jump_o = imm_j;
        else if (sel_jmp == JMP_REG)
            op2_jump_o = imm_i;
        else if (sel_jmp == JMP_HAND)
            op2_jump_o = pc_inc;
        else
            op2_jump_o = `ZeroWord;
    end

endmodule
