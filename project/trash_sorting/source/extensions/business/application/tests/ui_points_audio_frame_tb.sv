`timescale 1ns/1ps
// UI-only fixture. The preview area has no injected camera/detection result.
module ui_points_audio_frame_tb;
reg clk=0,rst=1;always #5 clk=~clk;
reg[127:0]snapshot=0;wire fs,hs,vs,de;wire[23:0]rgb;
ui_rgb dut(clk,rst,snapshot,fs,hs,vs,de,rgb,897'b0,32'b0,);
integer img,active=0,total=0;reg started=0;
initial begin
 img=$fopen("frame.ppm","wb");$fwrite(img,"P6\n1280 720\n255\n");
 repeat(4)@(negedge clk);rst=0;snapshot[63:32]=1200;
 snapshot[123]=1;snapshot[124]=1;
end
always @(negedge clk)if(!rst)begin
 if(fs)begin
  if(started)begin
   if(active!=1280*720||total!=1650*750)$fatal(1,"incomplete display raster");
   $fclose(img);$display("TEST_PASS ui_points_audio_frame 921600 known pixels");$finish;
  end
  started=1;
 end
 if(started)begin
  total=total+1;
  if(de)begin
   if(^rgb===1'bx)$fatal(1,"unknown display pixel");
   $fwrite(img,"%c%c%c",rgb[23:16],rgb[15:8],rgb[7:0]);active=active+1;
  end
 end
end
initial begin #26000000;$fatal(1,"display timeout");end
endmodule
