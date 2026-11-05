// 1280x720 RGB565 -> 320x180 immutable DDR mailbox events. Whole-frame drop
// on FIFO overflow; a bad/partial frame is never published to the host.
module camera_events #(parameter W=1280,H=720)(
 input wire pclk,rst,vs,de,input wire[15:0]pixel,
 input wire clk,srst,ready,output wire valid,output wire[63:0]packet,
 output wire pv,sof,done,abort_frame,output wire[15:0]sample);
 reg vd,dd,active,bad;reg[15:0]x,y;reg[31:0]fid,count;
 reg ev;reg[63:0]data;wire er;
 assign pv=ev&&data[16];assign sof=data[17];assign done=ev&&data[18];
 assign abort_frame=ev&&data[19];assign sample=data[15:0];
 app_async_fifo #(.W(64),.A(9)) fifo(pclk,rst,ev,data,er,clk,srst,ready,valid,packet);
 always @(posedge pclk)begin
  if(rst)begin vd<=0;dd<=0;active<=0;bad<=0;x<=0;y<=0;fid<=0;count<=0;ev<=0;data<=0;end
  else begin
   vd<=vs;dd<=de;ev<=0;
   if(ev&&!er)bad<=1;
   if(vs&&!vd)begin
    if(active)begin ev<=1;data<={fid,12'b0,(bad||count!=W*H),(!bad&&count==W*H),2'b0,16'b0};end
    active<=1;bad<=0;x<=0;y<=0;count<=0;fid<=fid+1;
   end else if(active&&!vs)begin
    if(de)begin
     x<=x+1;count<=count+1;
     if(x<W&&y<H&&x[1:0]==0&&y[1:0]==0)begin
      ev<=1;data<={fid,12'b0,2'b0,(x==0&&y==0),1'b1,pixel};
     end
     if(x>=W||y>=H)bad<=1;
    end
    if(dd&&!de)begin if(x!=W)bad<=1;x<=0;y<=y+1;end
   end
  end
 end
endmodule
