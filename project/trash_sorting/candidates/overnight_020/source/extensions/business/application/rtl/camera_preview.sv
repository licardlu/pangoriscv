// Independent camera observation path. RGB565 -> 160x120 RGB332 for 640x480.
// Complete frames switch banks only at HDMI boundaries. The capture side waits
// for the display acknowledgement before reusing a bank; no CPU/DDR/UART traffic.
module camera_preview #(parameter WIDTH=640,HEIGHT=480,STALE_FRAMES=120)(
 input wire pclk,prst,pixel_valid,input wire[15:0]pixel,
 input wire sof,frame_done,frame_abort,
 input wire pixel_clk,pixel_rst,frame_start,input wire[14:0]read_addr,
 output reg[7:0]read_pixel,output reg valid);
localparam PW=WIDTH/4,PH=HEIGHT/4,PIXELS=PW*PH;
(* ram_style="block" *) reg[7:0]bank0[0:PIXELS-1];
(* ram_style="block" *) reg[7:0]bank1[0:PIXELS-1];
reg publish,write_bank,published_bank,active;
reg[31:0]count,sampled;
reg[15:0]col,row;
(* async_reg="true" *) reg ack1,ack2,req1,req2,bank_sync1,bank_sync2;
reg ack,read_bank;reg[15:0]age;
wire pending=publish!=ack2;
wire[31:0]position=sof?0:count;
wire[15:0]sx=sof?16'b0:col,sy=sof?16'b0:row;
wire sample_pixel=sx[1:0]==0&&sy[1:0]==0;
wire[31:0]write_addr=(sy>>2)*PW+(sx>>2);
wire[7:0]rgb332={pixel[15:13],pixel[10:8],pixel[4:3]};
always @(posedge pclk)begin
 if(prst)begin publish<=0;write_bank<=0;published_bank<=0;active<=0;count<=0;sampled<=0;col<=0;row<=0;ack1<=0;ack2<=0;end
 else begin
  ack1<=ack;ack2<=ack1;
  if(frame_abort)begin active<=0;count<=0;sampled<=0;end
  else if(frame_done)begin
   if(active&&count==WIDTH*HEIGHT&&sampled==PIXELS&&!pending)begin
    published_bank<=write_bank;publish<=~publish;write_bank<=~write_bank;
   end
   active<=0;count<=0;sampled<=0;
  end else if(pixel_valid)begin
   if(sof)begin active<=!pending;count<=1;sampled<=!pending?1:0;col<=1;row<=0;end
   else if(active)begin
    count<=count+1;
    if(col==WIDTH-1)begin col<=0;row<=row+1;end else col<=col+1;
    if(sample_pixel)sampled<=sampled+1;
    if(count>=WIDTH*HEIGHT)active<=0;
   end
   if((sof?!pending:active)&&position<WIDTH*HEIGHT&&sample_pixel&&write_addr<PIXELS)begin
    if(write_bank)bank1[write_addr]<=rgb332;else bank0[write_addr]<=rgb332;
   end
  end
 end
end
always @(posedge pixel_clk)begin
 if(pixel_rst)begin req1<=0;req2<=0;bank_sync1<=0;bank_sync2<=0;ack<=0;read_bank<=0;valid<=0;age<=0;end
 else begin
  req1<=publish;req2<=req1;bank_sync1<=published_bank;bank_sync2<=bank_sync1;
  if(frame_start)begin
   if(req2!=ack)begin read_bank<=bank_sync2;ack<=req2;valid<=1;age<=0;end
   else if(age<STALE_FRAMES)begin age<=age+1;if(age==STALE_FRAMES-1)valid<=0;end
  end
 end
 if(read_addr<PIXELS)read_pixel<=read_bank?bank1[read_addr]:bank0[read_addr];
 else read_pixel<=0;
end
endmodule
