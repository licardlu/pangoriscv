module snapshot_cdc #(parameter W=128)(input wire sclk,srst,send,input wire[W-1:0]data,output wire busy,
 input wire dclk,drst,frame_start,output reg[W-1:0]snapshot);
reg[W-1:0]hold;reg req,ack;
(* ASYNC_REG="TRUE" *)reg ack1,ack2,req1,req2;
assign busy=req!=ack2;
always @(posedge sclk)begin
 if(srst)begin hold<=0;req<=0;ack1<=0;ack2<=0;end
 else begin ack1<=ack;ack2<=ack1;if(send&&!busy)begin hold<=data;req<=~req;end end
end
always @(posedge dclk)begin
 if(drst)begin snapshot<=0;ack<=0;req1<=0;req2<=0;end
 else begin req1<=req;req2<=req1;if(frame_start&&req2!=ack)begin snapshot<=hold;ack<=req2;end end
end
endmodule
