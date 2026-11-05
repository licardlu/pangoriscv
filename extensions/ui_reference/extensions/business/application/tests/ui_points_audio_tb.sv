`timescale 1ns/1ps
module ui_points_audio_tb;
reg clk=0,rst=1;always #5 clk=~clk;
reg[127:0]snapshot=0;wire fs,hs,vs,de;wire[23:0]rgb;
ui_rgb dut(clk,rst,snapshot,fs,hs,vs,de,rgb,897'b0,32'b0,);
task sample;input[10:0]px;input[9:0]py;input[23:0]expected;begin
 force dut.x=px;force dut.y=py;repeat(4)@(negedge clk);
 if(!de||rgb!==expected)$fatal(1,"UI %0d,%0d got %h expected %h",px,py,rgb,expected);
end endtask
initial begin
 repeat(4)@(negedge clk);rst=0;snapshot[63:32]=1200;
 sample(10,10,24'hf4f8f6);
 sample(48,256,24'hffffff);
 sample(640,719,24'hedf3f3); // camera extends all the way to the bottom
 sample(800,200,24'h158263); // persistent acquisition guide
 snapshot[124]=1;
 sample(420,630,24'h158263); // READY
 snapshot[123]=1;
 sample(420,630,24'h158263); // PLAYING
 snapshot[123]=0;snapshot[124]=0;
 sample(420,630,24'h52756b); // UNAVAILABLE
 // Start a conversion frame and retain all 10 numeric places for 32-bit points.
 force dut.x=0;force dut.y=0;repeat(2)@(negedge clk);
 force dut.x=1;repeat(40)@(negedge clk);
 sample(505,120,24'h17483f); // 1200 thousands digit (1), upper-right segment
 $display("TEST_PASS ui_points_audio labels, external speaker, file and state, points");$finish;
end
initial begin #100000;$fatal(1,"UI timeout");end
endmodule
