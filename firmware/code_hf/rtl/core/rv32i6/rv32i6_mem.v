//=============================================================================
// pangoriscv - rv32i6 memories (G1: plain BRAM, one-cycle read, hex preloaded)
// Module : rv32i6_mem             File : rtl/core/rv32i6/rv32i6_mem.v
// Rev    : 0.1                    Date : 2026-10-22
// Brief  : 32 KiB program (64 b read) + 16 KiB data (1R1W with byte enables)
//=============================================================================
// Why plain BRAM and not a cache: the delivered core's distributed-RAM caches are
// the measured cause of the routing wall above 36 MHz (four LUTRAM banks share
// one write-address/CE bus, so that bus must cross column banks).  A BRAM read is
// one cycle -- exactly a cache hit -- and a 4 KiB 2-way cache would only save
// BRAM, which this device has 155 of and the design uses 8.
//
// The G3 revision replaces these with 2-way BRAM caches so the contest's
// "2-way set-associative I/D cache" requirement stays satisfied; the interface
// here is already the one those caches present (read latency 1).
`timescale 1ns/1ps

module rv32i6_mem #(
    parameter PROG_WORDS = 8192,        // 32 KiB
    parameter DATA_WORDS = 4096,        // 16 KiB
    parameter PROG_HEX   = "program.hex",
    parameter DATA_HEX   = "data.hex"
)(
    input  wire        clk,

    input  wire [31:0] imem_addr,
    output wire [63:0] imem_data,

    input  wire [31:0] dmem_addr,
    input  wire        dmem_we,
    input  wire [2:0]  dmem_size,
    input  wire [31:0] dmem_wdata,
    output wire [31:0] dmem_rdata
);
    // ---------------- program: two 32 b banks read in parallel ----------------
    reg [31:0] p_even [0:PROG_WORDS/2-1];
    reg [31:0] p_odd  [0:PROG_WORDS/2-1];
    reg [31:0] p_tmp  [0:PROG_WORDS-1];

    integer i;
    initial begin
        for (i = 0; i < PROG_WORDS; i = i + 1) p_tmp[i] = 32'h0000_0013;
        $readmemh(PROG_HEX, p_tmp);
        for (i = 0; i < PROG_WORDS/2; i = i + 1) begin
            p_even[i] = p_tmp[2*i];
            p_odd[i]  = p_tmp[2*i+1];
        end
    end

    reg [31:0] imem_even_q, imem_odd_q;
    always @(posedge clk) begin
        imem_even_q <= p_even[imem_addr[14:3]];
        imem_odd_q  <= p_odd [imem_addr[14:3]];
    end
    assign imem_data = {imem_odd_q, imem_even_q};

    // ---------------- data: 1R1W with byte enables ---------------------------
    reg [31:0] dmem [0:DATA_WORDS-1];
    initial begin
        for (i = 0; i < DATA_WORDS; i = i + 1) dmem[i] = 32'd0;
        $readmemh(DATA_HEX, dmem);
    end

    wire [1:0]  off  = dmem_addr[1:0];
    wire [29:0] widx = dmem_addr[31:2];
    reg  [3:0]  wmask;
    always @(*) begin
        case (dmem_size[1:0])
            2'd0:    wmask = 4'b0001 << off;               // SB
            2'd1:    wmask = 4'b0011 << off;               // SH
            default: wmask = 4'b1111;                      // SW
        endcase
    end

    reg [31:0] dmem_rdata_q;
    always @(posedge clk) begin
        if (dmem_we) begin
            if (wmask[0]) dmem[widx][7:0]   <= dmem_wdata[7:0];
            if (wmask[1]) dmem[widx][15:8]  <= dmem_wdata[15:8];
            if (wmask[2]) dmem[widx][23:16] <= dmem_wdata[23:16];
            if (wmask[3]) dmem[widx][31:24] <= dmem_wdata[31:24];
        end
        dmem_rdata_q <= dmem[widx];
    end
    assign dmem_rdata = dmem_rdata_q;

endmodule
