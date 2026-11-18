`timescale 1ns/1ps
module tb_benchmark_navigation_boundary;
 reg cpu_clk=0,pix_clk=0,cpu_rst=1,pix_rst=1,page_async=0,wr_en=0;
 reg start_toggle_async=0,display_page_async=0,audio_busy_async=0;
 reg [7:0] wr_addr=0,rd_addr=8'hd0;reg [31:0] wr_data=0;
 reg frame_start=0;reg [10:0] x=0;reg [9:0] y=0;
 wire [31:0] rd_data;wire debug_page,page_pix;wire [23:0] rgb;
 always #5 cpu_clk=~cpu_clk;
 always #7 pix_clk=~pix_clk;
 benchmark_page #(.FONT_FILE(""),.TRANSITION_ENABLE(1)) dut(.*);
 task ticks(input integer n);repeat(n)@(negedge cpu_clk);endtask
 task write(input [31:0] v);wr_addr=8'hd0;wr_data=v;wr_en=1;ticks(1);wr_en=0;ticks(2);endtask
 initial begin
  ticks(4);cpu_rst=0;pix_rst=0;ticks(6);
  page_async=1;ticks(6);
  start_toggle_async=1;ticks(6);if(!rd_data[0])$fatal(1,"Visible-page key did not queue");
  page_async=0;ticks(6);if(rd_data[0])$fatal(1,"Exit did not clear pending");
  // A start toggle crossing domains can arrive after page exit cancellation.
  // It must be consumed without leaving a request for the next page entry.
  start_toggle_async=0;ticks(6);
  if(rd_data[0])$fatal(1,"Late start outside score page queued a stale benchmark");
  page_async=1;ticks(6);if(rd_data[0])$fatal(1,"Reentry auto-started from stale key");
  start_toggle_async=1;ticks(6);if(!rd_data[0])$fatal(1,"Fresh page key lost");
  write(1);if(!rd_data[1]||rd_data[0])$fatal(1,"Start acknowledgment failed");
  start_toggle_async=0;ticks(6);if(rd_data[0])$fatal(1,"Key during running queued another run");
  page_async=0;ticks(6);write(2);if(rd_data[1]||rd_data[0])$fatal(1,"Finish outside page retained request");
  page_async=1;ticks(6);if(rd_data[0])$fatal(1,"Completed run restarted on reentry");
  $display("TEST_PASS benchmark navigation boundary: late start discarded, reentry manual, running key ignored");$finish;
 end
 initial begin #20000;$fatal(1,"Boundary timeout");end
endmodule
