module camera_cdc #(parameter WIDTH=640,HEIGHT=480)(input wire pclk,prst,vsync,href,input wire[7:0]data,
 input wire clk,rst,ready,output wire valid,output wire[63:0]packet,output wire[31:0]dropped);
wire pv,sof,eol,fd,ab,wr_ready;wire[15:0]pix;wire[31:0]fid;reg bad;
dvp_rx #(.WIDTH(WIDTH),.HEIGHT(HEIGHT)) rx(pclk,prst,vsync,href,data,wr_ready,pv,pix,sof,eol,fd,ab,fid,dropped);
wire event_valid=pv||fd||ab;
wire[63:0]event_data={fd||ab?fid-1:fid,12'b0,ab||(fd&&bad),fd&&!bad,sof,pv,pix};
always @(posedge pclk)begin if(prst)bad<=0;else begin if(sof)bad<=0;if(event_valid&&!wr_ready)bad<=1;end end
app_async_fifo #(.W(64),.A(9)) fifo(pclk,prst,event_valid,event_data,wr_ready,clk,rst,ready,valid,packet);
endmodule
