//=============================================================================
// pangoriscv - RV32IM processor core + native AXI4 SoC (Pango PG2L100H @ 27 MHz)
// Module : ex                     File : rtl/core/ex.v
// Rev    : 1.0                    Date : 2026-10-13
// Author : pango_lpenghan
// Brief  : Execute stage: ALU, branch and jump resolution, load/store issue, CSR access
//=============================================================================

`include "defines.v"

// Pure combinational execute stage. There is no clock and no state here: every
// output is a function of the current inputs only.
module ex #(parameter MUL_ENABLE = 1)(

    input  wire               rst,              // active-low reset; unused, this stage has no state

    // from id
    input  wire [`InstBus]     inst_i,           // instruction word
    input  wire [`InstAddrBus] inst_addr_i,      // instruction address; no RTL load
    input  wire                reg_we_i,         // general register write request
    input  wire [`RegAddrBus]  reg_waddr_i,      // general register write address
    input  wire [`RegBus]      reg1_rdata_i,     // source operand 1 value
    input  wire [`RegBus]      reg2_rdata_i,     // source operand 2 value
    input  wire                csr_we_i,         // CSR write request
    input  wire [`MemAddrBus]  csr_waddr_i,      // CSR write address
    input  wire [`RegBus]      csr_rdata_i,      // CSR value read back
    input  wire                int_assert_i,     // interrupt asserted
    input  wire [`InstAddrBus] int_addr_i,       // interrupt vector; no RTL load
    input  wire [`MemAddrBus]  op1_i,            // ALU operand 1
    input  wire [`MemAddrBus]  op2_i,            // ALU operand 2
    input  wire [`MemAddrBus]  op1_jump_i,       // branch/jump target base
    input  wire [`MemAddrBus]  op2_jump_i,       // branch/jump target offset

    // from mem
    input  wire [`MemBus]      mem_rdata_i,      // data read back from memory

    // from div
    input  wire                div_ready_i,      // divider result valid
    input  wire [`RegBus]      div_result_i,     // divider result
    input  wire                div_busy_i,       // divider still running
    input  wire [`RegAddrBus]  div_reg_waddr_i,  // register the result belongs to

    // to mem
    output reg  [`MemBus]      mem_wdata_o,      // store data, merged with the old word
    output reg  [`MemAddrBus]  mem_raddr_o,      // load address
    output reg  [`MemAddrBus]  mem_waddr_o,      // store address
    output wire                mem_we_o,         // store request
    output wire                mem_req_o,        // memory access request

    // to regs
    output wire [`RegBus]      reg_wdata_o,      // register write data
    output wire                reg_we_o,         // register write request
    output wire [`RegAddrBus]  reg_waddr_o,      // register write address

    // to csr reg
    output reg  [`RegBus]      csr_wdata_o,      // CSR write data
    output wire                csr_we_o,         // CSR write request
    output wire [`MemAddrBus]  csr_waddr_o,      // CSR write address

    // to div
    output wire                div_start_o,      // start the divider
    output reg  [`RegBus]      div_dividend_o,   // divider dividend
    output reg  [`RegBus]      div_divisor_o,    // divider divisor
    output reg  [2:0]          div_op_o,         // divider operation select
    output reg  [`RegAddrBus]  div_reg_waddr_o,  // register the result belongs to

    // to ctrl
    output wire                hold_flag_o,      // stall the front of the pipe
    output wire                jump_flag_o,      // redirect the fetch address
    output wire [`InstAddrBus] jump_addr_o       // redirect target
);

    //------------------------------------------------------------ instruction fields
    wire [6:0] opcode = inst_i[6:0];
    wire [2:0] funct3 = inst_i[14:12];
    wire [6:0] funct7 = inst_i[31:25];
    wire [4:0] rd     = inst_i[11:7];      // destination register number
    wire [4:0] uimm   = inst_i[19:15];     // 5-bit immediate of the CSR immediate forms

    //------------------------------------------------------------- operand helpers
    wire [`RegBus] reg1_negate = ~reg1_rdata_i + 32'd1;
    wire [`RegBus] reg2_negate = ~reg2_rdata_i + 32'd1;

    wire signed_ge = ($signed(op1_i) >= $signed(op2_i));   // SLT/BLT/BGE style compare
    wire unsigned_ge = (op1_i >= op2_i);                   // SLTU/BLTU/BGEU style compare
    wire operands_equal = (op1_i == op2_i);

    wire [`RegBus] add_result = op1_i + op2_i;
    wire [`RegBus] sub_result = op1_i - op2_i;
    wire [`RegBus] target_sum = op1_jump_i + op2_jump_i;

    // A right shift is done in two pieces so that the arithmetic variant can
    // paste the replicated sign bit over the vacated high bits.
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

    //----------------------------------------------------------- multiplier inputs
    // All four M-extension multiplies share one array; only the operand
    // conditioning differs. MULH and MULHSU need the magnitude of a negative
    // operand, so the sign is stripped before the multiply (see mul_full below)
    // and restored on the product afterwards.
    wire signed_mul = ((opcode == `INST_TYPE_R_M) && (funct7 == 7'b0000001));
    reg  [`RegBus] mul_a;
    reg  [`RegBus] mul_b;

    always @(*) begin
        if(signed_mul) begin
            case(funct3)
                `INST_MUL, `INST_MULHU: begin
                    mul_a = reg1_rdata_i;
                    mul_b = reg2_rdata_i;
                end
                `INST_MULHSU: begin
                    mul_a = reg1_rdata_i[31] ? reg1_negate : reg1_rdata_i;
                    mul_b = reg2_rdata_i;
                end
                `INST_MULH: begin
                    mul_a = reg1_rdata_i[31] ? reg1_negate : reg1_rdata_i;
                    mul_b = reg2_rdata_i[31] ? reg2_negate : reg2_rdata_i;
                end
                default: begin
                    mul_a = reg1_rdata_i;
                    mul_b = reg2_rdata_i;
                end
            endcase
        end else begin
            mul_a = reg1_rdata_i;
            mul_b = reg2_rdata_i;
        end
    end

    // A pipelined caller supplies M-extension results from its own registered
    // multiplier. Constant-disable removes this legacy combinational array.
    wire [`DoubleRegBus] mul_full = MUL_ENABLE ? mul_a * mul_b : 64'd0;
    wire [`DoubleRegBus] mul_full_negated = ~mul_full + 64'd1;

    //---------------------------------------------------------------- ALU selects
    // The comparators drive these flags; a one-bit true/false is expanded to a
    // full word before it is written back.
    wire [`RegBus] slt_result  = {32{~signed_ge}}   & 32'h1;
    wire [`RegBus] sltu_result = {32{~unsigned_ge}} & 32'h1;

    // SH-style multi-cycle forms deposit the sign extension mask-wise, so the
    // two halves of the product are selected with the same trick.
    wire [`RegBus] mulhu_result = mul_full[63:32];
    wire [`RegBus] mulh_result =
        ({reg1_rdata_i[31], reg2_rdata_i[31]} == 2'b00) ? mul_full[63:32] :
        ({reg1_rdata_i[31], reg2_rdata_i[31]} == 2'b11) ? mul_full[63:32] :
                                                          mul_full_negated[63:32];
    wire [`RegBus] mulhsu_result = reg1_rdata_i[31] ? mul_full_negated[63:32]
                                                    : mul_full[63:32];

    //----------------------------------------------------------- load lane select
    // The lane index re-derives the effective address from the register file read
    // port, exactly as the datapath does, while the address outputs use the ALU
    // operand sum. Both are truncated by their 32-bit nets.
    wire [`MemAddrBus] load_addr  = add_result;
    wire [`MemAddrBus] store_addr = add_result;
    wire [1:0] load_lane  = (reg1_rdata_i + {{20{inst_i[31]}}, inst_i[31:20]}) & 2'b11;
    wire [1:0] store_lane = (reg1_rdata_i + {{20{inst_i[31]}}, inst_i[31:25], inst_i[11:7]}) & 2'b11;

    wire [`RegBus] lb_result =
        (load_lane == 2'b00) ? {{24{mem_rdata_i[7]}},  mem_rdata_i[7:0]}   :
        (load_lane == 2'b01) ? {{24{mem_rdata_i[15]}}, mem_rdata_i[15:8]}  :
        (load_lane == 2'b10) ? {{24{mem_rdata_i[23]}}, mem_rdata_i[23:16]} :
                               {{24{mem_rdata_i[31]}}, mem_rdata_i[31:24]};
    wire [`RegBus] lbu_result =
        (load_lane == 2'b00) ? {24'h0, mem_rdata_i[7:0]}   :
        (load_lane == 2'b01) ? {24'h0, mem_rdata_i[15:8]}  :
        (load_lane == 2'b10) ? {24'h0, mem_rdata_i[23:16]} :
                               {24'h0, mem_rdata_i[31:24]};
    wire [`RegBus] lh_result = (load_lane == 2'b00)
        ? {{16{mem_rdata_i[15]}}, mem_rdata_i[15:0]}
        : {{16{mem_rdata_i[31]}}, mem_rdata_i[31:16]};
    wire [`RegBus] lhu_result = (load_lane == 2'b00)
        ? {16'h0, mem_rdata_i[15:0]}
        : {16'h0, mem_rdata_i[31:16]};

    wire [`RegBus] sb_merge =
        (store_lane == 2'b00) ? {mem_rdata_i[31:8],  reg2_rdata_i[7:0]} :
        (store_lane == 2'b01) ? {mem_rdata_i[31:16], reg2_rdata_i[7:0], mem_rdata_i[7:0]} :
        (store_lane == 2'b10) ? {mem_rdata_i[31:24], reg2_rdata_i[7:0], mem_rdata_i[15:0]} :
                                {reg2_rdata_i[7:0],  mem_rdata_i[23:0]};
    wire [`RegBus] sh_merge = (store_lane == 2'b00)
        ? {mem_rdata_i[31:16], reg2_rdata_i[15:0]}
        : {reg2_rdata_i[15:0], mem_rdata_i[15:0]};

    //-------------------------------------------------------- driven registers
    // These nets are produced by the two always blocks below and consumed either
    // by the output assigns or by the write-back selection.
    reg [`RegBus]      reg_wdata;      // value written back to the register file
    reg                reg_we;         // register file write request
    reg [`RegAddrBus]  reg_waddr;      // register file write address
    reg                hold_flag;      // pipeline stall request
    reg                jump_flag;      // fetch redirect request
    reg [`InstAddrBus] jump_addr;      // fetch redirect target
    reg                mem_we;         // memory store request
    reg                mem_req;        // memory access request

    //------------------------------------------------------ divider handshake
    // div_we/div_wdata/div_waddr are local to these two blocks; the result is
    // committed through reg_wdata_o together with the ALU path.
    reg        div_busy_active;
    reg        div_hold_flag;
    reg        div_jump_flag;
    reg [`InstAddrBus] div_jump_addr;
    reg [`RegBus]     div_wdata;
    reg               div_we;
    reg [`RegAddrBus] div_waddr;

    always @(*) begin
        // The three status outputs are simply copied through; the divider is fed
        // with the raw operands and the funct3 field as the operation select.
        div_dividend_o  = reg1_rdata_i;
        div_divisor_o   = reg2_rdata_i;
        div_op_o        = funct3;
        div_reg_waddr_o = reg_waddr_i;

        if(signed_mul) begin
            div_we = `WriteDisable;
            div_wdata = `ZeroWord;
            div_waddr = `ZeroWord;
            case(funct3)
                `INST_DIV, `INST_DIVU, `INST_REM, `INST_REMU: begin
                    div_busy_active = `DivStart;
                    div_jump_flag = `JumpEnable;
                    div_hold_flag = `HoldEnable;
                    div_jump_addr = target_sum;      // the divider stalls the pipe here
                end
                default: begin
                    div_busy_active = `DivStop;
                    div_jump_flag = `JumpDisable;
                    div_hold_flag = `HoldDisable;
                    div_jump_addr = `ZeroWord;
                end
            endcase
        end else begin
            // Any other instruction: if the divider is still working the pipe is
            // held; once it reports a result the very same word is written back.
            div_jump_flag = `JumpDisable;
            div_jump_addr = `ZeroWord;
            if(div_busy_i) begin
                div_busy_active = `DivStart;
                div_we = `WriteDisable;
                div_wdata = `ZeroWord;
                div_waddr = `ZeroWord;
                div_hold_flag = `HoldEnable;
            end else begin
                div_busy_active = `DivStop;
                div_hold_flag = `HoldDisable;
                if(div_ready_i == `DivResultReady) begin
                    div_wdata = div_result_i;
                    div_waddr = div_reg_waddr_i;
                    div_we = `WriteEnable;
                end else begin
                    div_we = `WriteDisable;
                    div_wdata = `ZeroWord;
                    div_waddr = `ZeroWord;
                end
            end
        end
    end

    //----------------------------------------------------------- output gating
    // An interrupt drains the pipeline: no register file write, no store, no
    // memory request and no CSR write may survive. The divider is stopped too.
    wire int_taken = (int_assert_i == `PANGO_INT_ASSERT);

    assign div_start_o = int_taken ? `DivStop : div_busy_active;
    assign reg_wdata_o = reg_wdata;
    // The register write address and request are pure passthroughs here: the
    // divider's own write-back lands through div_adapter outside this module, so
    // ex must not substitute its internal write-back selection for the pipeline
    // request. The memory and CSR sides are gated by the interrupt instead.
    assign reg_we_o    = reg_we_i;
    assign reg_waddr_o = reg_waddr_i;
    assign mem_we_o    = int_taken ? `WriteDisable : mem_we;
    assign mem_req_o   = int_taken ? `PANGO_NREQ   : mem_req;
    assign csr_we_o    = int_taken ? `WriteDisable : csr_we_i;
    assign csr_waddr_o = csr_waddr_i;
    assign hold_flag_o = hold_flag;
    assign jump_flag_o = jump_flag;
    assign jump_addr_o = jump_addr;

    //--------------------------------------------------------------- ALU / LSU
    always @(*) begin
        // Divider handshake results enter the write-back path from here.
        reg_we    = div_we;
        reg_waddr = div_waddr;
        reg_wdata = div_wdata;

        // Defaults first: every net below is otherwise assigned in each branch.
        mem_req = `PANGO_NREQ;
        csr_wdata_o = `ZeroWord;
        mem_wdata_o = `ZeroWord;
        mem_raddr_o = `ZeroWord;
        mem_waddr_o = `ZeroWord;
        mem_we = `WriteDisable;
        jump_flag = `JumpDisable;
        hold_flag = `HoldDisable;
        jump_addr = `ZeroWord;

        case(opcode)
            //---------------------------------------------------- register/immediate
            `INST_TYPE_I: begin
                case(funct3)
                    `INST_ADDI:  reg_wdata = add_result;
                    `INST_SLTI:  reg_wdata = slt_result;
                    `INST_SLTIU: reg_wdata = sltu_result;
                    `INST_XORI:  reg_wdata = op1_i ^ op2_i;
                    `INST_ORI:   reg_wdata = op1_i | op2_i;
                    `INST_ANDI:  reg_wdata = op1_i & op2_i;
                    `INST_SLLI:  reg_wdata = reg1_rdata_i << inst_i[24:20];
                    `INST_SRI:   reg_wdata = srai_sel;
                    default:     reg_wdata = `ZeroWord;
                endcase
            end

            `INST_TYPE_R_M: begin
                if((funct7 == 7'b0000000) || (funct7 == 7'b0100000)) begin
                    case(funct3)
                        `INST_ADD_SUB: reg_wdata = inst_i[30] ? sub_result : add_result;
                        `INST_SLL:     reg_wdata = op1_i << op2_i[4:0];
                        `INST_SLT:     reg_wdata = slt_result;
                        `INST_SLTU:    reg_wdata = sltu_result;
                        `INST_XOR:     reg_wdata = op1_i ^ op2_i;
                        `INST_SR:      reg_wdata = srav_sel;
                        `INST_OR:      reg_wdata = op1_i | op2_i;
                        `INST_AND:     reg_wdata = op1_i & op2_i;
                        default:       reg_wdata = `ZeroWord;
                    endcase
                end else if(funct7 == 7'b0000001) begin
                    case(funct3)
                        `INST_MUL:    reg_wdata = mul_full[31:0];
                        `INST_MULHU:  reg_wdata = mulhu_result;
                        `INST_MULH:   reg_wdata = mulh_result;
                        `INST_MULHSU: reg_wdata = mulhsu_result;
                        default:      reg_wdata = `ZeroWord;
                    endcase
                end else begin
                    reg_wdata = `ZeroWord;
                end
            end

            //----------------------------------------------------------------- loads
            `INST_TYPE_L: begin
                case(funct3)
                    `INST_LB: begin
                        mem_req = `PANGO_REQ;
                        mem_raddr_o = load_addr;
                        reg_wdata = lb_result;
                    end
                    `INST_LH: begin
                        mem_req = `PANGO_REQ;
                        mem_raddr_o = load_addr;
                        reg_wdata = lh_result;
                    end
                    `INST_LW: begin
                        mem_req = `PANGO_REQ;
                        mem_raddr_o = load_addr;
                        reg_wdata = mem_rdata_i;
                    end
                    `INST_LBU: begin
                        mem_req = `PANGO_REQ;
                        mem_raddr_o = load_addr;
                        reg_wdata = lbu_result;
                    end
                    `INST_LHU: begin
                        mem_req = `PANGO_REQ;
                        mem_raddr_o = load_addr;
                        reg_wdata = lhu_result;
                    end
                    default: begin
                        reg_wdata = `ZeroWord;
                    end
                endcase
            end

            //---------------------------------------------------------------- stores
            // The store word is merged with the word read back on the same cycle,
            // so the untouched byte lanes keep their old contents.
            `INST_TYPE_S: begin
                reg_wdata   = `ZeroWord;
                mem_we      = `WriteEnable;
                mem_req     = `PANGO_REQ;
                mem_waddr_o = store_addr;
                mem_raddr_o = store_addr;
                case(funct3)
                    `INST_SB: mem_wdata_o = sb_merge;
                    `INST_SH: mem_wdata_o = sh_merge;
                    `INST_SW: mem_wdata_o = reg2_rdata_i;
                    default: begin
                    end
                endcase
            end

            //------------------------------------------------------------- branches
            `INST_TYPE_B: begin
                reg_wdata   = `ZeroWord;
                case(funct3)
                    `INST_BEQ: begin
                        jump_flag = operands_equal & `JumpEnable;
                        jump_addr = {32{operands_equal}} & target_sum;
                    end
                    `INST_BNE: begin
                        jump_flag = (~operands_equal) & `JumpEnable;
                        jump_addr = {32{~operands_equal}} & target_sum;
                    end
                    `INST_BLT: begin
                        jump_flag = (~signed_ge) & `JumpEnable;
                        jump_addr = {32{~signed_ge}} & target_sum;
                    end
                    `INST_BGE: begin
                        jump_flag = signed_ge & `JumpEnable;
                        jump_addr = {32{signed_ge}} & target_sum;
                    end
                    `INST_BLTU: begin
                        jump_flag = (~unsigned_ge) & `JumpEnable;
                        jump_addr = {32{~unsigned_ge}} & target_sum;
                    end
                    `INST_BGEU: begin
                        jump_flag = unsigned_ge & `JumpEnable;
                        jump_addr = {32{unsigned_ge}} & target_sum;
                    end
                    default: begin
                    end
                endcase
            end

            //---------------------------------------------------------- jumps / upper
            `INST_JAL, `INST_JALR: begin
                reg_wdata   = add_result;                 // link address
                jump_flag   = `JumpEnable;
                jump_addr   = (opcode == `INST_JALR)
                            ? (target_sum & 32'hfffffffe)  // JALR clears the low bit
                            : target_sum;
            end

            `INST_LUI, `INST_AUIPC: begin
                reg_wdata   = add_result;
            end

            `INST_NOP_OP: begin
                reg_wdata   = `ZeroWord;
            end

            // FENCE is treated as an unconditional redirect to the same target
            // sum the branch units use, which serialises the memory operations.
            `INST_FENCE: begin
                reg_wdata   = `ZeroWord;
                jump_flag   = `JumpEnable;
                jump_addr   = target_sum;
            end

            //------------------------------------------------------------------ CSR
            `INST_CSR: begin
                case(funct3)
                    `INST_CSRRW: begin
                        csr_wdata_o = reg1_rdata_i;
                        reg_wdata   = csr_rdata_i;
                    end
                    `INST_CSRRS: begin
                        csr_wdata_o = reg1_rdata_i | csr_rdata_i;
                        reg_wdata   = csr_rdata_i;
                    end
                    `INST_CSRRC: begin
                        csr_wdata_o = csr_rdata_i & (~reg1_rdata_i);
                        reg_wdata   = csr_rdata_i;
                    end
                    `INST_CSRRWI: begin
                        csr_wdata_o = {27'h0, uimm};
                        reg_wdata   = csr_rdata_i;
                    end
                    `INST_CSRRSI: begin
                        csr_wdata_o = {27'h0, uimm} | csr_rdata_i;
                        reg_wdata   = csr_rdata_i;
                    end
                    `INST_CSRRCI: begin
                        csr_wdata_o = (~{27'h0, uimm}) & csr_rdata_i;
                        reg_wdata   = csr_rdata_i;
                    end
                    default: begin
                        csr_wdata_o = `ZeroWord;
                        reg_wdata   = `ZeroWord;
                    end
                endcase
            end

            //---------------------------------------------------------------- idle
            default: begin
                reg_wdata   = `ZeroWord;
            end
        endcase
    end

endmodule
