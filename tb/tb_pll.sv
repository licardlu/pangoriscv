`timescale 1ns/1ps
module tb_pll;
  reg clk=0, rst_n=0;
  always #18.518518519 clk=~clk;
  wire core_clk,locked,reset;
  pango_pll pll(.clk(clk),.rst_n(rst_n),.core_clk(core_clk),.locked(locked));
  pango_reset rst(.clk(core_clk),.rst_n(rst_n),.locked(locked),.reset(reset));
  realtime t0,t1,period;
  initial begin
    #100 rst_n=1;
    wait(locked===1);
    repeat(20) @(posedge core_clk);
    if(reset!==0) $fatal(1,"Reset did not release after PLL lock");
    t0=$realtime;
    repeat(1000) @(posedge core_clk);
    t1=$realtime; period=(t1-t0)/1000;
    if(period<8.300 || period>8.303) $fatal(1,"Wrong CPU period %f",period);
    #1 rst_n=0;
    #0.01 if(reset!==1) $fatal(1,"Reset did not assert asynchronously");
    $display("TEST_PASS pll period_ns=%f",period); $finish;
  end
  initial begin #1000000; $fatal(1,"PLL lock timeout"); end
endmodule
