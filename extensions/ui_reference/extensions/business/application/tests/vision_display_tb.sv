`timescale 1ns/1ps
module vision_display_tb;
reg clk=0,pc=0,rst=1;always #5 clk=~clk;always #7 pc=~pc;
reg wr=0,fs=0;reg[15:0]addr=0;reg[31:0]wd=0;wire[31:0]q,pixels;wire bad;
wire[896:0]snap;wire[12:0]pa;reg[127:0]ui=0;wire hs,vs,de;wire[23:0]rgb;wire dfs;
vision_mmio mm(clk,rst,wr,1'b0,addr,wd,4'hf,q,bad,pc,rst,fs,pa,pixels,snap);
ui_rgb display(pc,rst,ui,dfs,hs,vs,de,rgb,snap,pixels,pa);
task write;input[15:0]a;input[31:0]v;begin
 @(negedge clk);addr=a;wd=v;wr=1;#1;if(bad)$fatal(1,"MMIO %h",a);
 @(negedge clk);wr=0;
end endtask
task check;input[10:0]px;input[9:0]py;input[23:0]expected;begin
 force display.x=px;force display.y=py;
 repeat(4)@(negedge pc);
 if(rgb!==expected||!de)$fatal(1,"RGB sample %d,%d got %h expected %h",px,py,rgb,expected);
end endtask
integer i;
initial begin
 repeat(5)@(negedge clk);rst=0;
 // No valid camera frame yet: the fixed green acquisition guide is visible.
 check(800,200,24'h158263);
 write(8,1);
 for(i=0;i<4800;i=i+1)write(16'h1000+i*4,32'h031ce0ff);
 write(16'h10,77);write(16'h14,123);write(16'h18,16'h101);write(16'h1c,1);
 write(16'h100,{16'd20,16'd10});write(16'h104,{16'd120,16'd100});write(16'h108,32'h5803);
 write(12,1);repeat(10)@(negedge pc);fs=1;@(negedge pc);fs=0;repeat(10)@(negedge clk);
 check(640,0,24'hffffff);check(648,0,24'hff0000);check(656,0,24'h00ff00);check(664,0,24'h0000ff);
 check(700,60,24'h397eb5);
 ui[96]=1;check(700,60,24'h397eb5); /* boxes remain visible during a quiz */
 ui[96]=0;
 write(8,1);write(16'h18,0);write(12,1);
 repeat(10)@(negedge pc);fs=1;@(negedge pc);fs=0;repeat(10)@(negedge clk);
 check(800,200,24'h158263); /* valid image with zero detections -> guide */
 $display("TEST_PASS vision_display MMIO -> dual-clock RAM -> HDMI pixel pipeline, RGB332 lanes and bbox privacy");$finish;
end
initial begin #1000000;$fatal(1,"vision display timeout");end
endmodule
