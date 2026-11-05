// Model CPU owns flash while booting. It hands over only between complete
// transactions; the independent account CPU owns it for the rest of that boot.
module shared_boot_flash #(parameter DIV=4)(
 input wire clk,rstn,ywr,input wire[7:0]ya,yr,input wire[31:0]yd,output wire[31:0]yq,
 input wire swr,input wire[7:0]sa,sr,input wire[31:0]sd,output wire[31:0]sq,
 output wire cs_n,sck,mosi,input wire miso);
 reg granted,model_ok;wire[31:0]q;wire[31:0]status={30'b0,model_ok,granted};
 wire handoff=ywr&&ya==8'hb8&&yd[0];
 always @(posedge clk)begin
  if(!rstn)begin granted<=0;model_ok<=0;end
  else if(handoff&&(granted||(cs_n&&!sck)))begin granted<=1;model_ok<=yd[1];end
 end
 assign sq=(sr==8'hb8) ? status : granted ? q : (sr==8'hfc) ? 32'b1 : 32'b0;
 assign yq=(yr==8'hb8) ? status : granted ? 32'b0 : q;
 model_flash_spi #(.DIV(DIV)) engine(.clk(clk),.rstn(rstn),
  .wr_en(granted?swr:ywr&&ya!=8'hb8),.wr_addr(granted?sa:ya),
  .rd_addr(granted?sr:yr),.wr_data(granted?sd:yd),.rd_data(q),
  .cs_n(cs_n),.sck(sck),.mosi(mosi),.miso(miso));
endmodule
