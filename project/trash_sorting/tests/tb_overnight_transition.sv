`timescale 1ns/1ps
module tb_overnight_transition;
 reg clk=0,rst=1,frame_start=0;
 reg [2:0] request_onehot_async=1;
 reg [23:0] rgb_in=24'hff8041;
 wire [1:0] display_page;
 wire [23:0] rgb_out;
 integer i;
 reg [2:0] level;
 always #5 clk=~clk;
 media_page_transition dut(.*);
 task ticks(input integer n);repeat(n)@(negedge clk);endtask
 task frame;
   frame_start=1;ticks(1);level=dut.brightness;ticks(15);
   if(level!==dut.brightness)$fatal(1,"VS level caused repeated fade updates");
   frame_start=0;ticks(6);
 endtask
 task request_page(input [2:0] p);request_onehot_async=p;ticks(6);endtask
 initial begin
   ticks(4);rst=0;ticks(6);
   if(rgb_out!==rgb_in||display_page!=0)$fatal(1,"Reset output");
   request_page(2);
   for(i=0;i<4;i=i+1)begin frame();if(display_page!=0)$fatal(1,"Switched before black");end
   if(rgb_out!==0)$fatal(1,"Fade out did not reach black");
   frame();if(display_page!=1||rgb_out!==0)$fatal(1,"Black page switch");
   frame();if(rgb_out!==0)$fatal(1,"No blank frame for page consumers");
   frame();if(rgb_out!==24'h3f2010)$fatal(1,"Quarter brightness/channel carry");
   frame();if(rgb_out!==24'h7f4020)$fatal(1,"Half brightness");
   frame();if(rgb_out!==24'hc06031)$fatal(1,"Three-quarter brightness");
   frame();if(rgb_out!==rgb_in)$fatal(1,"Full brightness");
   request_page(0);repeat(7)frame();
   if(display_page!=1||rgb_out!==rgb_in)$fatal(1,"Invalid CDC request changed page");
   request_page(4);frame();frame();request_page(2);frame();frame();
   if(display_page!=1||rgb_out!==rgb_in)$fatal(1,"Reversed request did not recover");
   request_page(4);repeat(5)frame();request_page(1);repeat(10)frame();
   if(display_page!=0||rgb_out!==rgb_in)$fatal(1,"Back-to-back page requests");
   $display("TEST_PASS overnight transition: frame edges, black switch, CDC hold, reversal, RGB levels");$finish;
 end
 initial begin #200000;$fatal(1,"Transition timeout");end
endmodule
