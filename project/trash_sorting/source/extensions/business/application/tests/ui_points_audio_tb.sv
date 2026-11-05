`timescale 1ns/1ps
// Regression: the removed points/audio cards must not cover the camera.
module ui_points_audio_tb;
reg clk=0,rst=1;always #5 clk=~clk;
reg[127:0]snapshot=0;wire fs,hs,vs,de;wire[23:0]rgb;
ui_rgb dut(clk,rst,snapshot,fs,hs,vs,de,rgb,897'b0,32'b0,);
task sample;input[10:0]px;input[9:0]py;input[23:0]expected;begin
 force dut.x=px;force dut.y=py;repeat(4)@(negedge clk);
 if(!de||rgb!==expected)$fatal(1,"UI %0d,%0d got %h expected %h",px,py,rgb,expected);
end endtask
initial begin
 repeat(4)@(negedge clk);rst=0;
 sample(10,10,24'hf4f8f6);sample(650,50,24'he4f1eb);
 sample(0,112,24'hedf3f3);sample(1279,719,24'hedf3f3);
 sample(480,200,24'h158263);
 snapshot[63:32]=32'hffffffff;snapshot[124:123]=3;
 sample(48,256,24'hedf3f3);sample(420,630,24'hedf3f3);
 sample(505,120,24'hedf3f3);sample(10,10,24'hf4f8f6);
 $display("TEST_PASS ui_points_audio removed cards leave full-width camera clear");$finish;
end
initial begin #100000;$fatal(1,"UI timeout");end
endmodule
