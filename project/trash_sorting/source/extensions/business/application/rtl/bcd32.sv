// 32-cycle shift/add-3 conversion. No variable division in the pixel path.
module bcd32(input wire clk,rst,start,input wire[31:0]value,output reg[39:0]digits,output reg busy);
reg[71:0]work,adjusted;reg[5:0]count;integer i;
always @*begin
 adjusted=work;
 for(i=0;i<10;i=i+1)if(work[32+i*4+:4]>=5)adjusted[32+i*4+:4]=work[32+i*4+:4]+3;
end
always @(posedge clk)begin
 if(rst)begin work<=0;digits<=0;count<=0;busy<=0;end
 else if(start&&!busy)begin work<={40'b0,value};count<=0;busy<=1;end
 else if(busy)begin
  work<=adjusted<<1;count<=count+1'b1;
  if(count==31)begin digits<={adjusted[70:32],1'b0}|{39'b0,adjusted[31]};busy<=0;end
 end
end
endmodule
