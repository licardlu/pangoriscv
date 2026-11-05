// A >=10ms UART BREAK toggles maintenance/business ownership on release.
// Legal 115200-baud data cannot contain such a long low interval.
module uart_mode #(parameter BREAK_CYCLES=270000)(
 input wire clk,rst,rx,yolo_tx,business_tx,
 output wire tx,yolo_rx,business_rx,output reg maintenance);
 (* ASYNC_REG="TRUE" *)reg r1,r2;reg[19:0]low_count;reg armed;
 assign tx=maintenance?yolo_tx:business_tx;
 assign yolo_rx=maintenance?rx:1'b1;
 assign business_rx=maintenance?1'b1:rx;
 always @(posedge clk)begin
  if(rst)begin r1<=1;r2<=1;low_count<=0;armed<=0;maintenance<=0;end
  else begin
   r1<=rx;r2<=r1;
   if(!r2)begin
    if(low_count<BREAK_CYCLES)low_count<=low_count+1;
    else armed<=1;
   end else begin
    low_count<=0;armed<=0;if(armed)maintenance<=~maintenance;
   end
  end
 end
endmodule
