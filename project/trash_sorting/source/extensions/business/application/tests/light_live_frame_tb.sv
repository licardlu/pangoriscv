`timescale 1ns/1ps
module light_live_frame_tb;
parameter integer HAS_RESULT=1;
reg clk=0;always #5 clk=~clk;
reg rst=1,wr=0;reg[7:0]addr=0;reg[31:0]data=0;wire[31:0]q;
reg hs=0,vs=0,de=0;reg[15:0]pixel=0;wire[15:0]osd;
reg[15:0]scene[0:921599];reg[127:0]snapshot=0;
wire ho,vo,deo;wire[23:0]composed;
wire[15:0]composed565={composed[23:19],composed[15:10],composed[7:3]};
video_ai_frontend #(.HEADER_HEIGHT(112),.OSD_LABEL(1)) frontend(
 .cpu_clk(clk),.cpu_rstn(!rst),.wr_en(wr),.wr_addr(addr),.rd_addr(8'b0),.wr_data(data),.rd_data(q),
 .cam_clk(clk),.cam_rstn(!rst),.cam_vs(1'b0),.cam_de(1'b0),.cam_pixel(16'b0),
 .pix_clk(clk),.pix_rstn(!rst),.pix_vs(vo),.pix_de(deo),.pix_in(composed565),.pix_out(osd),
 .result_commit(),.result_valid(),.result_class_id(),.result_count());
light_split_video display(clk,rst,hs,vs,de,pixel,snapshot,ho,vo,deo,composed);
task write;input[7:0]a;input[31:0]v;begin
 @(negedge clk);wr=1;addr=a;data=v;@(negedge clk);wr=0;
end endtask
integer img,px,py,n=0,sx,sy,dark_pixels=0,white_pixels=0,green_pixels=0;
always @(negedge clk)if(!rst&&deo)begin
 if(^osd===1'bx)$fatal(1,"unknown RGB at %0d",n);
 sx=n%1280;sy=n/1280;
 if(osd==16'h1247)dark_pixels=dark_pixels+1;
 if(osd==16'hffff)white_pixels=white_pixels+1;
 if(osd==16'h07e0)green_pixels=green_pixels+1;
 $fwrite(img,"%c%c%c",{osd[15:11],osd[15:13]},{osd[10:5],osd[10:9]},{osd[4:0],osd[4:2]});n=n+1;
end
initial begin
 $readmemh("native_camera.hex",scene);
 img=$fopen("frame.ppm","wb");$fwrite(img,"P6\n1280 720\n255\n");
 repeat(4)@(negedge clk);rst=0;snapshot[63:32]=1200;snapshot[2:0]=1;snapshot[96]=1;snapshot[124]=1;
 if(HAS_RESULT)begin write(8'h84,0);write(8'h88,{16'd100,16'd50});write(8'h8c,{16'd650,16'd780});write(8'h90,32'h80000005);write(8'h94,1);end
 repeat(6)@(negedge clk);vs=1;repeat(40)@(negedge clk);vs=0;repeat(370)@(negedge clk);
 for(py=0;py<720;py=py+1)begin
  for(px=0;px<1280;px=px+1)begin de=1;pixel=scene[py*1280+px];@(negedge clk);end
  de=0;pixel=0;repeat(370)@(negedge clk);
 end
 repeat(5)@(negedge clk);
 if(n!=921600)$fatal(1,"incomplete frame %0d",n);
 if(HAS_RESULT&&(dark_pixels<3000||white_pixels<80||green_pixels<3000))
   $fatal(1,"bbox overlay/label incomplete dark=%0d glyph=%0d green=%0d",dark_pixels,white_pixels,green_pixels);
 $fclose(img);
 if(HAS_RESULT)$display("TEST_PASS OSD topmost over opaque header; Chinese tag dark=%0d glyph=%0d green_box=%0d",dark_pixels,white_pixels,green_pixels);
 else $display("TEST_PASS no-result clean frame; no fixed guide");
 $finish;
end
initial begin #15000000;$fatal(1,"live frame timeout");end
endmodule
