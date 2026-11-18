`timescale 1ns/1ps
module tb_benchmark_dashboard;
 reg clk=0,pclk=0,rst=1,vs=0,wr=0,audio_busy=0;
 always #5 clk=~clk;
 always #7 pclk=~pclk;
 reg [7:0]wa=0;reg[31:0]wd=0;wire[31:0]rd;
 reg[10:0]x=0;reg[9:0]y=0;wire[23:0]rgb;
 reg[31:0]words[0:879];integer fd,ink=0,right_ink=0,upper_ink=0;
 integer metric_ink[0:3]='{0,0,0,0};
 benchmark_page dut(.cpu_clk(clk),.cpu_rst(rst),.page_async(1'b1),
  .start_toggle_async(1'b0),.display_page_async(1'b1),.audio_busy_async(audio_busy),
  .wr_en(wr),.wr_addr(wa),.wr_data(wd),
  .rd_addr(8'hcc),.rd_data(rd),.debug_page(),.pix_clk(pclk),.pix_rst(rst),
  .frame_start(vs),.x(x),.y(y),.rgb(rgb),.page_pix());
 task write(input[7:0]a,input[31:0]d);
  begin @(negedge clk);wa=a;wd=d;wr=1;@(negedge clk);wr=0;end
 endtask
 initial begin
  $readmemh("dashboard_cells.hex",words);
  repeat(5)@(negedge clk);rst=0;repeat(5)@(negedge clk);
  write(8'hc0,0);
  for(integer i=0;i<880;i=i+1)write(8'hc4,words[i]);
  if(rd!=880)$fatal(1,"TEST_FAIL dashboard word count");
  if(dut.text_ram[1024+879]!==words[879])$fatal(1,"TEST_FAIL dashboard RAM bank or cursor aliases beyond 256 words");
  write(8'hc8,1);repeat(8)@(negedge pclk);
  vs=1;@(negedge pclk);vs=0;repeat(8)@(negedge pclk);
  fd=$fopen("dashboard.ppm","wb");$fwrite(fd,"P6\n1280 720\n255\n");
  for(integer py=0;py<720;py=py+1)begin
   for(integer px=0;px<1280;px=px+1)begin
    x=px;y=py;repeat(3)@(negedge pclk);
    $fwrite(fd,"%c%c%c",rgb[23:16],rgb[15:8],rgb[7:0]);
    if(py>=208&&py<256&&px>=80&&px<784&&rgb==24'h007fb5)begin
     ink=ink+1;if(py<224)upper_ink=upper_ink+1;
     if(px<272)metric_ink[(px-80)/48]=metric_ink[(px-80)/48]+1;
    end
    if(py>=192&&py<224&&px>=848&&px<1200&&rgb==24'h173952)right_ink=right_ink+1;
   end
  end
  $fclose(fd);
  // Three digits and a decimal point have fewer lit pixels than the old
  // historical reference string. Require each actual score glyph separately.
  if(ink<1000||right_ink<500||upper_ink<100||metric_ink[0]<100||metric_ink[1]<10||metric_ink[2]<100||metric_ink[3]<100)
   $fatal(1,"TEST_FAIL large metrics glyphs missing %0d %0d %0d",ink,right_ink,upper_ink);
  $display("TEST_PASS full RTL dashboard render, complete 880-word bank and scaled metric text");$finish;
 end
 initial begin #200000000;$fatal(1,"TEST_FAIL dashboard render timeout");end
endmodule
