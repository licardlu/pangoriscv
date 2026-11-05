`timescale 1ns/1ps
module light_panel_tb;
reg clk=0,rst=1; always #5 clk=~clk;
reg[10:0]x=0;reg[9:0]y=0;reg[127:0]snapshot=0;wire[23:0]rgb;
ui_light_panel dut(clk,rst,x,y,snapshot,rgb);
task sample;input[10:0]px;input[9:0]py;input[23:0]expected;begin
 @(negedge clk);x=px;y=py;repeat(4)@(negedge clk);
 if(rgb!==expected)$fatal(1,"light panel %0d,%0d: %h expected %h",px,py,rgb,expected);
end endtask
initial begin
 repeat(4)@(negedge clk);rst=0;
 sample(10,10,24'hf4f8f6);
 sample(48,256,24'hffffff);
 sample(34,220,24'h158263); // active automatic mode underline
 snapshot[96]=1;
 sample(330,220,24'h158263); // quiz mode underline
 snapshot[124]=1;
 sample(420,630,24'h158263); // READY, first ink of R
 snapshot[123]=1;
 sample(420,630,24'h158263); // PLAYING, first ink of P
 snapshot[63:32]=1200;
 @(negedge clk);x=0;y=0;repeat(2)@(negedge clk);x=1;
 repeat(40)@(negedge clk);
 sample(505,120,24'h17483f); // thousands digit 1 upper right segment
 $display("TEST_PASS light_panel bright left UI, points, mode, music");$finish;
end
initial begin #100000;$fatal(1,"light panel timeout");end
endmodule
