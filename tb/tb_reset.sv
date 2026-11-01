`timescale 1ns/1ps
module tb_reset;
  reg clk=0, rst_n=0, locked=0;
  wire reset;
  always #5 clk=~clk;
  pango_reset dut(.clk(clk), .rst_n(rst_n), .locked(locked), .reset(reset));
  initial begin
    #1; if(reset!==1) $fatal(1,"reset must assert without clock");
    #10; rst_n=1;
    repeat(5) @(negedge clk);
    if(reset!==1) $fatal(1,"reset released before PLL lock");
    locked=1;
    repeat(2) @(negedge clk);
    if(reset!==1) $fatal(1,"reset release lacks synchronization");
    repeat(4) @(negedge clk);
    if(reset!==0) $fatal(1,"reset failed to release");
    #1; locked=0; #1;
    if(reset!==1) $fatal(1,"PLL unlock must assert reset immediately");
    locked=1;
    repeat(6) @(negedge clk);
    #1; rst_n=0; #1;
    if(reset!==1) $fatal(1,"external reset must assert immediately");
    $display("TEST_PASS reset"); $finish;
  end
endmodule
