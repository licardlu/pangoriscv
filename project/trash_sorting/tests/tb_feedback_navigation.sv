`timescale 1ns/1ps
module tb_feedback_navigation;
 reg clk=0,rst=1,key0_n=1,benchmark_key_event=0;
 always #5 clk=~clk;
 wire toggle_page,start_reference,toggle_recognition;
 wire [1:0] page;
 wire benchmark_start_toggle;
 benchmark_key_router #(.CLK_HZ(1000),.DEBOUNCE_MS(3),.LONG_PRESS_MS(40),.DOUBLE_CLICK_MS(12)) keys(.*);
 media_page_router #(.RESET_PAGE(2)) pages(.clk(clk),.rst(rst),.next_page(toggle_page),
  .long_press(start_reference),.debug_page_async(1'b0),.toggle_recognition(toggle_recognition),
  .benchmark_key_event(benchmark_key_event),.page(page),.benchmark_start_toggle(benchmark_start_toggle));
 task ticks(input integer n);repeat(n)@(negedge clk);endtask
 task click;key0_n=0;ticks(8);key0_n=1;ticks(7);endtask
 task double_click;click();click();ticks(20);endtask
 task start;benchmark_key_event=1;ticks(1);benchmark_key_event=0;ticks(3);endtask
 initial begin
  ticks(4);rst=0;ticks(5);
  start();if(benchmark_start_toggle||page!=2)$fatal(1,"KEY1 outside score");
  double_click();if(page!=1||benchmark_start_toggle)$fatal(1,"Entry must wait for KEY1");
  ticks(100);if(benchmark_start_toggle)$fatal(1,"Idle triggered a measurement");
  start();if(!benchmark_start_toggle)$fatal(1,"KEY1 failed to start");
  double_click();if(page!=2||!benchmark_start_toggle)$fatal(1,"Exit retriggered");
  start();if(!benchmark_start_toggle)$fatal(1,"Animation key triggered benchmark");
  double_click();if(page!=1||!benchmark_start_toggle)$fatal(1,"Reentry auto-start");
  start();if(benchmark_start_toggle)$fatal(1,"Second manual measurement");
  click();ticks(22);if(page!=0)$fatal(1,"Single click recognition");
  start();if(benchmark_start_toggle)$fatal(1,"Answer key escaped recognition page");
  key0_n=0;ticks(70);key0_n=1;ticks(30);
  if(page!=1||benchmark_start_toggle)$fatal(1,"Long press should navigate only");
  $display("TEST_PASS stereo_keys: manual KEY1 only, entry/reentry/long press no auto-run, recognition isolation");$finish;
 end
 initial begin #200000;$fatal(1,"Navigation timeout");end
endmodule
