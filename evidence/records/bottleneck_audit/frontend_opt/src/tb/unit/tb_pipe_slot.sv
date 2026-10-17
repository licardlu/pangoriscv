//=============================================================================
// pangoriscv - RV32IM processor core + native AXI4 SoC (Pango PG2L100H @ 27 MHz)
// Module : tb_pipe_slot           File : tb/unit/tb_pipe_slot.sv
// Rev    : 1.0                    Date : 2026-10-13
// Author : pango_lpenghan
// Brief  : Unit test for the pipeline slot handshake (valid/ready back-pressure, flush)
//=============================================================================

`timescale 1ns/1ps
module tb_pipe_slot;
    reg clk=0, rst_n=0, flush=0, iv=0, ordy=0;
    reg [31:0] idata=0;
    wire ir, ov;
    wire [31:0] od;
    always #5 clk=~clk;
    pipe_slot #(.WIDTH(32)) dut(.clk(clk),.rst_n(rst_n),.flush(flush),
        .in_valid(iv),.in_ready(ir),.in_data(idata),
        .out_valid(ov),.out_ready(ordy),.out_data(od));
    task tick; begin @(posedge clk); #1; end endtask
    initial begin
        #10000; $fatal(1,"TIMEOUT N02");
    end
    initial begin
        repeat(5) tick();
        if(ir!==0 || ov!==0 || od!==0) $fatal(1,"reset state");
        @(negedge clk); rst_n=1;
        @(negedge clk); iv=1; idata=32'hA;
        tick();
        if (ov!==1 || od!==32'hA) $fatal(1,"load A");
        @(negedge clk); idata=32'hB;
        repeat(10) begin
            tick();
            if(ir!==0 || ov!==1 || od!==32'hA) $fatal(1,"stall lost A");
        end
        @(negedge clk); ordy=1;
        tick();
        if(ov!==1 || od!==32'hB) $fatal(1,"replace A with B");
        @(negedge clk); flush=1; idata=32'hC;
        #1;
        if(ir!==0 || ov!==0) $fatal(1,"flush handshake");
        tick();
        @(negedge clk); flush=0; iv=0;
        tick();
        if(ov!==0) $fatal(1,"flush did not clear");
        @(negedge clk); iv=1; idata=32'hD; ordy=0;
        tick();
        if(ov!==1 || od!==32'hD) $fatal(1,"load D");
        @(negedge clk); flush=1; idata=32'hE;
        #1;
        if(ir!==0 || ov!==0) $fatal(1,"stall flush handshake");
        tick();
        @(negedge clk); flush=0; iv=0;
        tick();
        if(ov!==0) $fatal(1,"stall flush did not clear");
        @(negedge clk); iv=1; idata=32'hF;
        tick();
        @(negedge clk); rst_n=0; flush=1; ordy=1; idata=32'h10;
        #1;
        if(ir!==0 || ov!==0) $fatal(1,"reset handshake");
        tick();
        if(od!==0) $fatal(1,"reset must override flush and load");
        @(negedge clk); rst_n=1; flush=0; iv=0;
        tick();
        if(ov!==0) $fatal(1,"reset left stale valid");
        @(negedge clk); iv=1; idata=32'hAB; ordy=0;
        tick();
        if(ov!==1 || od!==32'hAB) $fatal(1,"load before drain");
        @(negedge clk); iv=0; ordy=1;
        tick();
        if(ov!==0) $fatal(1,"drain left valid");
        repeat(4) begin
            tick();
            if(ov!==0) $fatal(1,"duplicate transfer after drain");
        end
        $display("TEST_PASS N02"); $finish;
    end
endmodule
