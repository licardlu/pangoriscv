//=============================================================================
// pangoriscv - RV32IM processor core + native AXI4 SoC (Pango PG2L100H @ 27 MHz)
// Module : defines                File : rtl/core/defines.v
// Rev    : 1.0                    Date : 2026-10-13
// Author : pango_lpenghan
// Brief  : Single source of truth for the core's shared compile-time constants:
//          reset/zero values, pipeline handshake levels, interrupt and hold
//          encodings, the RV32IM instruction map (opcode plus funct3 fields),
//          CSR addresses, and the memory / register bus widths. These names are
//          a frozen interface consumed by every module in the project, so only
//          their grouping, spacing and prose may change - never a name or value.
//=============================================================================

//------------------------------------------------------------------ reset & zero
`define CpuResetAddr          32'h00000000   // architectural reset vector
`define RstEnable             1'b0           // reset asserted (active low)
`define RstDisable            1'b1           // reset released
`define ZeroWord              32'h00000000   // 32-bit all-zero literal
`define ZeroReg               5'h00          // register index x0

//--------------------------------------------------------- write / jump enables
`define WriteEnable           1'b1
`define WriteDisable          1'b0
`define JumpEnable            1'b1
`define JumpDisable           1'b0
`define True                  1'b1
`define False                 1'b0

//----------------------------------------------------------- divider handshake
`define DivStart              1'b1           // request a divide operation
`define DivStop               1'b0           // idle the divider
`define DivResultReady        1'b1           // quotient / remainder valid
`define DivResultNotReady     1'b0           // result still being computed

//------------------------------------------------------ hold (pipeline freeze)
`define HoldEnable            1'b1
`define HoldDisable           1'b0
`define Hold_Flag_Bus         2:0
`define Hold_None             3'b000
`define Hold_Pc               3'b001
`define Hold_If               3'b010
`define Hold_Id               3'b011

//-------------------------------------------------------- request / interrupt
`define PANGO_REQ             1'b1
`define PANGO_NREQ            1'b0
`define PANGO_INT_ASSERT      1'b1
`define PANGO_INT_DEASSERT    1'b0
`define INT_BUS               7:0
`define INT_NONE              8'h00

//--------------------------------------------------------------- opcode map
// Primary opcodes occupy instruction bits [6:0]; funct3 sub-fields live in
// bits [14:12] and are listed under the opcode that owns them.
`define INST_LUI              7'b0110111   // U-type
`define INST_AUIPC            7'b0010111   // U-type

`define INST_JAL              7'b1101111   // J-type
`define INST_JALR             7'b1100111   // I-type jump

`define INST_TYPE_B           7'b1100011   // B-type branches
`define INST_BEQ              3'b000
`define INST_BNE              3'b001
`define INST_BLT              3'b100
`define INST_BGE              3'b101
`define INST_BLTU             3'b110
`define INST_BGEU             3'b111

`define INST_TYPE_L           7'b0000011   // loads
`define INST_LB               3'b000
`define INST_LH               3'b001
`define INST_LW               3'b010
`define INST_LBU              3'b100
`define INST_LHU              3'b101

`define INST_TYPE_S           7'b0100011   // stores
`define INST_SB               3'b000
`define INST_SH               3'b001
`define INST_SW               3'b010

`define INST_TYPE_I           7'b0010011   // register-immediate ALU
`define INST_ADDI             3'b000
`define INST_SLTI             3'b010
`define INST_SLTIU            3'b011
`define INST_XORI             3'b100
`define INST_ORI              3'b110
`define INST_ANDI             3'b111
`define INST_SLLI             3'b001
`define INST_SRI              3'b101       // SRLI / SRAI share this field

`define INST_TYPE_R_M         7'b0110011   // register-register ALU + RV32M
`define INST_ADD_SUB          3'b000       // ADD / SUB
`define INST_SLL              3'b001
`define INST_SLT              3'b010
`define INST_SLTU             3'b011
`define INST_XOR              3'b100
`define INST_SR               3'b101       // SRL / SRA
`define INST_OR               3'b110
`define INST_AND              3'b111
`define INST_MUL              3'b000
`define INST_MULH             3'b001
`define INST_MULHSU           3'b010
`define INST_MULHU            3'b011
`define INST_DIV              3'b100
`define INST_DIVU             3'b101
`define INST_REM              3'b110
`define INST_REMU             3'b111

`define INST_FENCE            7'b0001111   // memory ordering

`define INST_CSR              7'b1110011   // SYSTEM opcode
`define INST_CSRRW            3'b001
`define INST_CSRRS            3'b010
`define INST_CSRRC            3'b011
`define INST_CSRRWI           3'b101
`define INST_CSRRSI           3'b110
`define INST_CSRRCI           3'b111

//------------------------------------------------------ system instruction words
// Whole 32-bit encodings consumed directly by the decoder.
`define INST_NOP              32'h00000001
`define INST_NOP_OP           7'b0000001
`define INST_MRET             32'h30200073
`define INST_ECALL            32'h00000073
`define INST_EBREAK           32'h00100073

//------------------------------------------------------------- CSR addresses
// Address field layout: [11:10] privilege, [9:8] read/write class, [7:0] number.
`define CSR_MSTATUS           12'h300
`define CSR_MIE               12'h304
`define CSR_MTVEC             12'h305
`define CSR_MSCRATCH          12'h340
`define CSR_MEPC              12'h341
`define CSR_MCAUSE            12'h342
`define CSR_CYCLE             12'hc00
`define CSR_CYCLEH            12'hc80

//--------------------------------------------------- memory geometry and buses
`define RomNum                4096          // instruction ROM depth, in words
`define MemNum                4096          // data memory depth, in words
`define MemBus                31:0          // data word width
`define MemAddrBus            31:0          // data byte address width
`define InstBus               31:0          // instruction word width
`define InstAddrBus           31:0          // instruction byte address width

//------------------------------------------------------------ register file
`define RegAddrBus            4:0           // one-hot enough for 32 entries
`define RegBus                31:0
`define DoubleRegBus          63:0          // MULH-class product / retire order
`define RegNum                32            // entries x0..x31
