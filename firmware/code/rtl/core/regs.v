//=============================================================================
// pangoriscv - RV32IM processor core + native AXI4 SoC (Pango PG2L100H @ 27 MHz)
// Module : regs                   File : rtl/core/regs.v
// Rev    : 1.1                    Date : 2026-10-19
// Author : pango_lpenghan
// Brief  : 32 x 32-bit general-purpose register file.  Four combinational read
//          ports (two per issue slot) and two write ports (lane 0, lane 1) for
//          the superscalar issue experiment; the debug/JTAG pair is unchanged.
//          x0 is hard-wired to zero on read and discarded on write.  A read of
//          the register being written in the same cycle returns the incoming
//          data (write-through); when both lanes write the same register the
//          younger lane (lane 1) wins.
//=============================================================================

`include "defines.v"

module regs(
    input  wire               clk,
    input  wire               rst,          // asynchronous-free, active low
    input  wire               we_i,         // lane 0 write enable
    input  wire [`RegAddrBus] waddr_i,      // lane 0 write address
    input  wire [`RegBus]     wdata_i,      // lane 0 write data
    input  wire               we2_i,        // lane 1 write enable
    input  wire [`RegAddrBus] waddr2_i,     // lane 1 write address
    input  wire [`RegBus]     wdata2_i,     // lane 1 write data
    input  wire               jtag_we_i,    // debug write enable
    input  wire [`RegAddrBus] jtag_addr_i,  // debug read/write address
    input  wire [`RegBus]     jtag_data_i,  // debug write data
    input  wire [`RegAddrBus] raddr1_i,     // read port 1 address (lane 0 rs1)
    output reg  [`RegBus]     rdata1_o,     // read port 1 data
    input  wire [`RegAddrBus] raddr2_i,     // read port 2 address (lane 0 rs2)
    output reg  [`RegBus]     rdata2_o,     // read port 2 data
    input  wire [`RegAddrBus] raddr3_i,     // read port 3 address (lane 1 rs1)
    output reg  [`RegBus]     rdata3_o,     // read port 3 data
    input  wire [`RegAddrBus] raddr4_i,     // read port 4 address (lane 1 rs2)
    output reg  [`RegBus]     rdata4_o,     // read port 4 data
    output reg  [`RegBus]     jtag_data_o   // debug read data
);

    reg [`RegBus] rfile [0:`RegNum - 1];

    //--------------------------------------------------------- write decoding
    wire pipe_wr = we_i     && (waddr_i     != `ZeroReg);
    wire pipe_wr2 = we2_i   && (waddr2_i    != `ZeroReg);
    wire dbg_wr  = jtag_we_i && (jtag_addr_i != `ZeroReg);

    always @(posedge clk) begin
        if(rst == `RstDisable) begin
            // Lane 1 is younger: when both write the same register, its later
            // assignment wins.
            if(pipe_wr) begin
                rfile[waddr_i] <= wdata_i;
            end
            if(pipe_wr2) begin
                rfile[waddr2_i] <= wdata2_i;
            end
            if(!pipe_wr && !pipe_wr2 && dbg_wr) begin
                rfile[jtag_addr_i] <= jtag_data_i;
            end
        end
    end

    //--------------------------------------------------- combinational reads
    // A read address that matches the register currently being written by the
    // pipeline returns the incoming write data instead of the stored value, so
    // the pipeline never needs a separate bypass stage.  Lane 1 is younger and
    // therefore has priority on a same-address collision.
    // Explicit always blocks (not a function): ModelSim's `always @(*)`
    // sensitivity does not reliably include a dynamically indexed array read
    // written inside a function, which left the read port stale after another
    // instruction updated the register file.  Writing `rfile[raddr]` directly
    // in each block reproduces the original module's sensitivity.
    always @(*) begin
        if(raddr1_i == `ZeroReg)             rdata1_o = `ZeroWord;
        else if(pipe_wr2 && (waddr2_i == raddr1_i)) rdata1_o = wdata2_i;
        else if(pipe_wr  && (waddr_i  == raddr1_i)) rdata1_o = wdata_i;
        else                                  rdata1_o = rfile[raddr1_i];
    end
    always @(*) begin
        if(raddr2_i == `ZeroReg)             rdata2_o = `ZeroWord;
        else if(pipe_wr2 && (waddr2_i == raddr2_i)) rdata2_o = wdata2_i;
        else if(pipe_wr  && (waddr_i  == raddr2_i)) rdata2_o = wdata_i;
        else                                  rdata2_o = rfile[raddr2_i];
    end
    always @(*) begin
        if(raddr3_i == `ZeroReg)             rdata3_o = `ZeroWord;
        else if(pipe_wr2 && (waddr2_i == raddr3_i)) rdata3_o = wdata2_i;
        else if(pipe_wr  && (waddr_i  == raddr3_i)) rdata3_o = wdata_i;
        else                                  rdata3_o = rfile[raddr3_i];
    end
    always @(*) begin
        if(raddr4_i == `ZeroReg)             rdata4_o = `ZeroWord;
        else if(pipe_wr2 && (waddr2_i == raddr4_i)) rdata4_o = wdata2_i;
        else if(pipe_wr  && (waddr_i  == raddr4_i)) rdata4_o = wdata_i;
        else                                  rdata4_o = rfile[raddr4_i];
    end

    always @(*) begin
        if(jtag_addr_i == `ZeroReg) begin
            jtag_data_o = `ZeroWord;
        end else begin
            jtag_data_o = rfile[jtag_addr_i];
        end
    end

endmodule
