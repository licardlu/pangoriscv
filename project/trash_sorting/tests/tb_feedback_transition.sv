`timescale 1ns/1ps
module tb_feedback_transition;
 reg clk=0,rst=1,frame_start=0;
 reg [2:0] request_onehot_async=1;
 reg [23:0] rgb_in=24'hff8041;
 wire [1:0] display_page;wire [23:0] rgb_out;
 reg [3:0] level;reg [23:0] previous;
 integer i;
 always #5 clk=~clk;
 media_page_transition dut(.*);
 task ticks(input integer n);repeat(n)@(negedge clk);endtask
 task frame;
  frame_start=1;ticks(1);level=dut.brightness;ticks(15);
  if(level!==dut.brightness)$fatal(1,"Repeated VS fade");
  frame_start=0;ticks(6);
 endtask
 task request_page(input [2:0] p);request_onehot_async=p;ticks(6);endtask
 initial begin
  ticks(4);rst=0;ticks(6);if(rgb_out!==rgb_in)$fatal(1,"Reset brightness");
  request_page(2);previous=rgb_in;
  for(i=0;i<8;i=i+1)begin
   frame();if(display_page!=0||rgb_out>=previous)$fatal(1,"Fade out not monotonic");previous=rgb_out;
  end
  if(rgb_out!==0)$fatal(1,"Not black");
  frame();if(display_page!=1||rgb_out!==0)$fatal(1,"Switch not black");
  frame();if(rgb_out!==0)$fatal(1,"Consumer settle missing");
  for(i=0;i<8;i=i+1)begin
   frame();if(rgb_out<=previous)$fatal(1,"Fade in not monotonic");previous=rgb_out;
  end
  if(rgb_out!==rgb_in)$fatal(1,"Full brightness");
  request_page(0);repeat(20)frame();if(display_page!=1||rgb_out!==rgb_in)$fatal(1,"Invalid request");
  request_page(4);repeat(4)frame();request_page(2);repeat(8)frame();
  if(display_page!=1||rgb_out!==rgb_in)$fatal(1,"Reversed fade");
  request_page(4);repeat(9)frame();request_page(1);repeat(20)frame();
  if(display_page!=0||rgb_out!==rgb_in)$fatal(1,"Back-to-back targets");
  $display("TEST_PASS overnight transition: eased 18-frame fade, black page switch, CDC hold, reversal");$finish;
 end
 initial begin #200000;$fatal(1,"Transition timeout");end
endmodule
