// -----------------------------------------------------------------------------
// core_defs.vh -- 流水线公共编码
//
// 所有编码都与 upstream/VexiiRiscv 的 SrcPlugin / IntAluPlugin 语义一一对应:
//   result = bitwise(SRC1,SRC2) | (ADD_SUB & addsub_en) | (LESS & sltx_en)
//   ADD_SUB = SRC1 + (revert ? ~SRC2 : SRC2) + revert
//   LESS    = (SRC1[31]==SRC2[31]) ? ADD_SUB[31] : (unsigned ? SRC2[31] : SRC1[31])
// 见 docs/architecture/reference-pipeline.md 的"early 执行"一节。
// -----------------------------------------------------------------------------
`ifndef CORE_DEFS_VH
`define CORE_DEFS_VH

// ---------------------------- 位宽选择 ---------------------------------------
`define SRC1_RF     2'd0
`define SRC1_U      2'd1      // LUI/AUIPC: imm.u (已 <<12)

`define SRC2_RF     2'd0
`define SRC2_I      2'd1
`define SRC2_S      2'd2
`define SRC2_PC     2'd3

// ---------------------------- ALU 位运算选择 ---------------------------------
`define ALU_BW_ZERO  2'd0
`define ALU_BW_XOR   2'd1
`define ALU_BW_OR    2'd2
`define ALU_BW_AND   2'd3

// ---------------------------- 写回来源 ---------------------------------------
`define WB_ALU      2'd0
`define WB_MEM      2'd1
`define WB_PC4      2'd2
`define WB_CSR      2'd3

// ---------------------------- 访存宽度/符号 ----------------------------------
`define MSIZE_B     2'd0
`define MSIZE_H     2'd1
`define MSIZE_W     2'd2

// ---------------------------- CSR 操作 ---------------------------------------
`define CSR_NONE    2'd0
`define CSR_RW      2'd1      // csrrw / csrrwi
`define CSR_RS      2'd2      // csrrs / csrrsi
`define CSR_RC      2'd3      // csrrc / csrrci

// ---------------------------- 例外原因 (mcause) ------------------------------
`define EXC_INSTR_MISALIGN   32'd0
`define EXC_INSTR_ACCESS     32'd1
`define EXC_ILLEGAL          32'd2
`define EXC_BREAKPOINT       32'd3
`define EXC_LOAD_MISALIGN    32'd4
`define EXC_LOAD_ACCESS      32'd5
`define EXC_STORE_MISALIGN   32'd6
`define EXC_STORE_ACCESS     32'd7
`define EXC_ECALL_M          32'd11
`define IRQ_M_TIMER          32'd7
`define IRQ_M_EXTERNAL       32'd11
`define IRQ_M_SOFTWARE       32'd3

// ---------------------------- CSR 地址 ---------------------------------------
`define CSR_MSTATUS     12'h300
`define CSR_MISA        12'h301
`define CSR_MIE         12'h304
`define CSR_MTVEC       12'h305
`define CSR_MSCRATCH    12'h340
`define CSR_MEPC        12'h341
`define CSR_MCAUSE      12'h342
`define CSR_MTVAL       12'h343
`define CSR_MIP         12'h344
`define CSR_MCYCLE      12'hB00
`define CSR_MINSTRET    12'hB02
`define CSR_MCYCLEH     12'hB80
`define CSR_MINSTRETH   12'hB82
`define CSR_MVENDORID   12'hF11
`define CSR_MARCHID     12'hF12
`define CSR_MIMPID      12'hF13
`define CSR_MHARTID     12'hF14
`define CSR_MCONFIGPTR  12'hF15
`define CSR_MCOUNTINHIBIT 12'h320

// mstatus 位
`define MSTATUS_MIE_BIT   3
`define MSTATUS_MPIE_BIT  7
`define MSTATUS_MPP_LSB   11

`endif // CORE_DEFS_VH
