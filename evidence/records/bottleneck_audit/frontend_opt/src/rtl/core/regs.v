//=============================================================================
// pangoriscv - RV32IM processor core + native AXI4 SoC (Pango PG2L100H @ 27 MHz)
// Module : regs                   File : rtl/core/regs.v
// Rev    : 1.0                    Date : 2026-10-13
// Author : pango_lpenghan
// Brief  : 32 x 32-bit general-purpose register file with three ports: the
//          pipeline write/read pair and the debug (JTAG) write/read pair.
//          x0 is hard-wired to zero on read and discarded on write, the
//          pipeline write takes priority over the debug write when both are
//          asserted, and a read of the register being written in the same
//          cycle returns the new data (write-through).
//=============================================================================

`include "defines.v"

module regs(
    input  wire               clk,
    input  wire               rst,          // asynchronous-free, active low
    input  wire               we_i,         // pipeline write enable
    input  wire [`RegAddrBus] waddr_i,      // pipeline write address
    input  wire [`RegBus]     wdata_i,      // pipeline write data
    input  wire               jtag_we_i,    // debug write enable
    input  wire [`RegAddrBus] jtag_addr_i,  // debug read/write address
    input  wire [`RegBus]     jtag_data_i,  // debug write data
    input  wire [`RegAddrBus] raddr1_i,     // read port 1 address
    output reg  [`RegBus]     rdata1_o,     // read port 1 data
    input  wire [`RegAddrBus] raddr2_i,     // read port 2 address
    output reg  [`RegBus]     rdata2_o,     // read port 2 data
    output reg  [`RegBus]     jtag_data_o   // debug read data
);

    reg [`RegBus] rfile [0:`RegNum - 1];

    //--------------------------------------------------------- write decoding
    wire pipe_wr = we_i     && (waddr_i     != `ZeroReg);
    wire dbg_wr  = jtag_we_i && (jtag_addr_i != `ZeroReg);

    always @(posedge clk) begin
        if(rst == `RstDisable) begin
            if(pipe_wr) begin
                rfile[waddr_i] <= wdata_i;
            end else if(dbg_wr) begin
                rfile[jtag_addr_i] <= jtag_data_i;
            end
        end
    end

    //--------------------------------------------------- combinational reads
    // A read address that matches the register currently being written by the
    // pipeline returns the incoming write data instead of the stored value, so
    // the pipeline never needs a separate bypass stage.
    always @(*) begin
        if(raddr1_i == `ZeroReg) begin
            rdata1_o = `ZeroWord;
        end else if(we_i && (waddr_i == raddr1_i)) begin
            rdata1_o = wdata_i;
        end else begin
            rdata1_o = rfile[raddr1_i];
        end
    end

    always @(*) begin
        if(raddr2_i == `ZeroReg) begin
            rdata2_o = `ZeroWord;
        end else if(we_i && (waddr_i == raddr2_i)) begin
            rdata2_o = wdata_i;
        end else begin
            rdata2_o = rfile[raddr2_i];
        end
    end

    always @(*) begin
        if(jtag_addr_i == `ZeroReg) begin
            jtag_data_o = `ZeroWord;
        end else begin
            jtag_data_o = rfile[jtag_addr_i];
        end
    end

endmodule
