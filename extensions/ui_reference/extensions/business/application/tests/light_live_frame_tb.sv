`timescale 1ns/1ps
// Synthetic camera fixture -> real YOLO frontend OSD -> native split compositor.
// The supplied box is a test vector, never claimed to be a neural inference.
module light_live_frame_tb;
reg clk=0;always #5 clk=~clk;
reg rst=1,wr=0;reg[7:0]addr=0;reg[31:0]data=0;wire[31:0]q;
reg hs=0,vs=0,de=0;reg[15:0]pixel=0;wire[15:0]osd;
reg[15:0]scene[0:921599];reg[127:0]snapshot=0;
reg[15:0]native_osd[0:921599];integer native_count=0;
wire ho,vo,deo;wire[23:0]rgb;
video_ai_frontend frontend(.cpu_clk(clk),.cpu_rstn(!rst),.wr_en(wr),.wr_addr(addr),.rd_addr(8'b0),.wr_data(data),.rd_data(q),
 .cam_clk(clk),.cam_rstn(!rst),.cam_vs(1'b0),.cam_de(1'b0),.cam_pixel(16'b0),
 .pix_clk(clk),.pix_rstn(!rst),.pix_vs(vs),.pix_de(de),.pix_in(pixel),.pix_out(osd));
light_split_video display(clk,rst,hs,vs,de,osd,snapshot,ho,vo,deo,rgb);
task write;input[7:0]a;input[31:0]v;begin
 @(negedge clk);wr=1;addr=a;data=v;@(negedge clk);wr=0;
end endtask
function[23:0]expand;input[15:0]p;begin expand={p[15:11],p[15:13],p[10:5],p[10:9],p[4:0],p[4:2]};end endfunction
integer img,px,py,n=0,sx,sy;reg[23:0]expected;reg[15:0]raw;
// Record the actual native OSD stream at the compositor's input handshake.
// The crop scoreboard therefore includes label foreground AND background,
// without duplicating the frontend's font renderer inside this test.
always @(posedge clk)if(!rst&&de)begin
 native_osd[native_count]=osd;native_count=native_count+1;
end
always @(negedge clk)if(!rst&&deo)begin
 if(^rgb===1'bx)$fatal(1,"unknown RGB at %0d",n);
 sx=n%1280;sy=n/1280;
 // Verify every right-panel pixel with independent output coordinates.
 if(sx>=640)begin
  if(sy*1280+sx-320>=native_count)$fatal(1,"crop read ahead of input");
  raw=native_osd[sy*1280+sx-320];expected=expand(raw);
  if(rgb!==expected)$fatal(1,"native crop mismatch %0d,%0d %h != %h",sx,sy,rgb,expected);
 end
 $fwrite(img,"%c%c%c",rgb[23:16],rgb[15:8],rgb[7:0]);n=n+1;
end
initial begin
 $readmemh("native_camera.hex",scene);
 img=$fopen("frame.ppm","wb");$fwrite(img,"P6\n1280 720\n255\n");
 repeat(4)@(negedge clk);rst=0;snapshot[63:32]=1200;snapshot[2:0]=1;snapshot[96]=1;snapshot[124]=1;
 write(8'h84,0);write(8'h88,{16'd100,16'd500});write(8'h8c,{16'd650,16'd780});
 write(8'h90,32'h80000005);write(8'h94,1);repeat(6)@(negedge clk);
 vs=1;repeat(40)@(negedge clk);vs=0;repeat(370)@(negedge clk);
 for(py=0;py<720;py=py+1)begin
  for(px=0;px<1280;px=px+1)begin de=1;pixel=scene[py*1280+px];@(negedge clk);end
  de=0;pixel=0;
  repeat(370)begin hs=1;@(negedge clk);end
  hs=0;
 end
 repeat(5)@(negedge clk);
 if(n!=921600)$fatal(1,"incomplete frame %0d",n);
 if(native_count!=921600)$fatal(1,"incomplete native stream %0d",native_count);
 if(native_osd[100*1280+500]!==16'h07e0)$fatal(1,"missing green box border");
 if(native_osd[142*1280+580]!==16'hffff)$fatal(1,"missing white OSD label");
 $fclose(img);$display("TEST_PASS light_live_frame 921600 native RGB565 pixels + OSD crop + white panel");$finish;
end
initial begin #15000000;$fatal(1,"live frame timeout");end
endmodule
