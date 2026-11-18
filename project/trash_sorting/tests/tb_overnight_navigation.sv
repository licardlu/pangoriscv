`timescale 1ns/1ps
module tb_overnight_navigation;
  reg clk=0,rst=1,key0_n=1;
  always #5 clk=~clk;
  wire toggle_page,start_reference,toggle_recognition;
  wire [1:0] page;
  wire benchmark_start_toggle;
  integer singles=0,doubles=0,longs=0;
  benchmark_key_router #(.CLK_HZ(1000),.DEBOUNCE_MS(3),
    .LONG_PRESS_MS(40),.DOUBLE_CLICK_MS(12)) keys(.*);
  media_page_router pages(.clk(clk),.rst(rst),.next_page(toggle_page),
    .long_press(start_reference),.debug_page_async(1'b0),
    .toggle_recognition(toggle_recognition),.page(page),
    .benchmark_start_toggle(benchmark_start_toggle));
  always @(posedge clk) if(!rst) begin
    if(toggle_recognition) singles=singles+1;
    if(toggle_page) doubles=doubles+1;
    if(start_reference) longs=longs+1;
    if((toggle_recognition&&toggle_page)||(toggle_recognition&&start_reference))
      $fatal(1,"Navigation events overlap");
  end
  task ticks(input integer n); repeat(n) @(negedge clk); endtask
  task press(input integer n); key0_n=0;ticks(n);key0_n=1;endtask
  task reset_all; rst=1;key0_n=1;ticks(4);rst=0;ticks(4);
    singles=0;doubles=0;longs=0;endtask
  task check(input integer s,d,l,p);
    if(singles!=s||doubles!=d||longs!=l||page!=p)
      $fatal(1,"Expected events %0d/%0d/%0d page%0d; got %0d/%0d/%0d page%0d",
        s,d,l,p,singles,doubles,longs,page);
  endtask
  initial begin
    reset_all();
    // Short contact bounce cannot navigate.
    press(1);ticks(2);press(1);ticks(25);check(0,0,0,0);
    // A single release must wait for the double-click window.
    press(8);ticks(7);check(0,0,0,0);ticks(16);check(1,0,0,2);
    press(8);ticks(24);check(2,0,0,0);
    // Double click does not generate a single event, including while held.
    press(8);ticks(7);key0_n=0;ticks(25);check(2,0,0,0);
    key0_n=1;ticks(25);check(2,1,0,1);
    if(!benchmark_start_toggle)$fatal(1,"Entering score page did not start demo");
    press(8);ticks(7);press(8);ticks(25);check(2,2,0,2);
    press(8);ticks(7);press(8);ticks(25);check(2,3,0,0);
    // Long press fires once, with no delayed click after release.
    press(70);ticks(30);check(2,3,1,1);
    // Long second press cancels the first pending single as well.
    press(8);ticks(7);press(70);ticks(30);check(2,3,2,1);
    // Two clicks outside the window remain two independent singles.
    reset_all();press(8);ticks(25);press(8);ticks(25);check(2,0,0,0);
    // Reset clears an in-flight pending click.
    press(8);ticks(6);reset_all();ticks(30);check(0,0,0,0);
    $display("TEST_PASS overnight navigation: debounce, single/double arbitration, long press, page cycle, reset");
    $finish;
  end
  initial begin #100000;$fatal(1,"Navigation test timed out");end
endmodule
