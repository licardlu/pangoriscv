`timescale 1ns/1ps
module tb_overnight_standby;
 reg clk=0,rst=1,vs=0,has_frame=0;reg[1:0]page=0;reg[3:0]state=3;
 reg[10:0]x=0;reg[9:0]y=0;wire[23:0]rgb;wire active;
 always #5 clk=~clk;
 media_display dut(.clk(clk),.rst(rst),.page_async(page),.frame_start(vs),
  .ui_state_async(state),.has_frame_async(has_frame),.x(x),.y(y),
  .video_rgb(24'h123456),.page_active(active),.rgb(rgb));
 task frame;
  begin vs=1;repeat(8)@(negedge clk);vs=0;repeat(8)@(negedge clk);end
 endtask
 task render(input string name,output integer ink);
  integer fd;
  begin
   ink=0;fd=$fopen(name,"wb");$fwrite(fd,"P6\n1280 720\n255\n");
   for(integer py=0;py<720;py++)for(integer px=0;px<1280;px++)begin
    x=px;y=py;repeat(3)@(negedge clk);
    if((^rgb)===1'bx)$fatal(1,"TEST_FAIL unknown standby pixel");
    $fwrite(fd,"%c%c%c",rgb[23:16],rgb[15:8],rgb[7:0]);
    if(py>=440&&py<520&&px>=448&&px<832&&(rgb==24'h19b7d7||rgb==24'h3cbd9c))ink++;
   end
   $fclose(fd);
  end
 endtask
 integer ink0,ink1;reg[6:0]old_phase;reg[23:0]pixel0;
 initial begin
  repeat(5)@(negedge clk);rst=0;page=2;repeat(6)@(negedge clk);
  frame();if(dut.wave_phase!=1||!active)$fatal(1,"TEST_FAIL VS edge/page active");
  render("standby0.ppm",ink0);
  x=449;y=465;repeat(3)@(negedge clk);pixel0=rgb;
  repeat(20)frame();if(dut.wave_phase!=21)$fatal(1,"TEST_FAIL per-frame phase");
  repeat(3)@(negedge clk);if(rgb===pixel0)$fatal(1,"TEST_FAIL static wave");
  render("standby1.ppm",ink1);
  if(ink0<3000||ink1<3000)$fatal(1,"TEST_FAIL missing wave columns");
  page=0;repeat(6)@(negedge clk);old_phase=dut.wave_phase;frame();
  if(dut.wave_phase!=old_phase||active)$fatal(1,"TEST_FAIL animation did not pause off page");
  page=2;state=2;has_frame=1;repeat(6)@(negedge clk);frame();
  repeat(3)@(negedge clk);if(rgb!==24'h123456)$fatal(1,"TEST_FAIL video passthrough");
  rst=1;repeat(4)@(negedge clk);
  if(active||dut.wave_phase!=0||dut.show_video)$fatal(1,"TEST_FAIL reset");
  $display("TEST_PASS standby two-phase render, VS edge, pause, video passthrough and reset");$finish;
 end
 initial begin #100000000;$fatal(1,"TEST_FAIL standby timeout");end
endmodule
