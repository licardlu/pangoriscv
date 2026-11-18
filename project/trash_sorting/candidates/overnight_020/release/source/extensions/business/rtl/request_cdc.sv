// One outstanding request. Payload remains held until its response returns.
// Both sides must reset together when DDR calibration/PLL is lost.
module request_cdc(
 input wire clk,rst,valid,write,input wire[31:0]addr,wdata,input wire[3:0]strb,
 output wire ready,output reg response,output reg[31:0]rdata,output reg error,
 input wire dclk,drst,output wire nvalid,nwrite,output wire[31:0]naddr,nwdata,
 output wire[3:0]nstrb,input wire nready,nresponse,input wire[31:0]nrdata,input wire nerror);
 reg req,ack,seen,active,sent;reg[68:0]payload;reg[32:0]reply;
 (* ASYNC_REG="TRUE" *)reg a1,a2,q1,q2;
 assign ready=req==a2;
 assign nvalid=active&&!sent;
 assign {nwrite,naddr,nwdata,nstrb}=payload;
 always @(posedge clk)begin
  if(rst)begin req<=0;a1<=0;a2<=0;seen<=0;response<=0;rdata<=0;error<=0;payload<=0;end
  else begin
   a1<=ack;a2<=a1;response<=0;
   if(valid&&ready)begin payload<={write,addr,wdata,strb};req<=~req;end
   if(a2!=seen)begin seen<=a2;{error,rdata}<=reply;response<=1;end
  end
 end
 always @(posedge dclk)begin
  if(drst)begin ack<=0;q1<=0;q2<=0;active<=0;sent<=0;reply<=0;end
  else begin
   q1<=req;q2<=q1;
   if(!active&&q2!=ack)begin active<=1;sent<=0;end
   if(nvalid&&nready)sent<=1;
   if(active&&(sent||(nvalid&&nready))&&nresponse)begin
    reply<={nerror,nrdata};ack<=q2;active<=0;sent<=0;
   end
  end
 end
endmodule
