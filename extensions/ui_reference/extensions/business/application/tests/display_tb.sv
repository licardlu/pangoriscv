`timescale 1ns/1ps
module display_tb;
reg clk=0,rst=1;always #5 clk=~clk;reg[127:0]snapshot=0;wire fs,hs,vs,de;wire[23:0]rgb;
ui_rgb dut(clk,rst,snapshot,fs,hs,vs,de,rgb,897'b0,32'b0,);
integer img;initial begin img=$fopen("frame.ppm","wb");$fwrite(img,"P6\n1280 720\n255\n");end
integer active=0,lines=0,total=0;reg prior=0,started=0;
initial begin repeat(4)@(negedge clk);rst=0;snapshot[63:32]=1234567;snapshot[31:0]=2;snapshot[127:96]=32'h00820201;end
always @(negedge clk)if(!rst)begin
 if(fs)begin
  if(started)begin if(active!=1280*720||total!=1650*750)$fatal(1,"raster count %d %d",active,total);$fclose(img);$display("TEST_PASS display pixels=%d",active);$finish;end
  started=1;
 end
 if(started)begin total=total+1;if(de)begin $fwrite(img,"%c%c%c",rgb[23:16],rgb[15:8],rgb[7:0]);active=active+1;if(^rgb===1'bx)$fatal(1,"unknown RGB");end if(de&&!prior)lines=lines+1;prior=de;end
end
initial begin #26000000;$fatal(1,"display timeout");end
endmodule
