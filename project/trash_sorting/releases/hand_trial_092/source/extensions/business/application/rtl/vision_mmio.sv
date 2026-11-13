// Frozen recognition image and metadata. CPU only writes the inactive bank.
// A commit switches image/boxes together on the next HDMI frame boundary.
module vision_mmio(input wire clk,rst,wr,rd,input wire[15:0]addr,
 input wire[31:0]wdata,input wire[3:0]wstrb,output reg[31:0]rdata,output reg invalid,
 input wire pixel_clk,pixel_rst,frame_start,input wire[12:0]pixel_addr,
 output reg[31:0]pixel_data,output wire[896:0]snapshot);
reg[31:0]image0[0:4799],image1[0:4799];
reg[895:0]staging;reg[896:0]payload;reg send,write_bank,recording;
reg[12:0]loaded;wire busy_cdc;wire busy=busy_cdc||send;
wire ram=addr>=16'h1000&&addr<16'h5b00;
wire[12:0]index=(addr-16'h1000)>>2;
wire boxreg=addr>=16'h100&&addr<16'h180&&addr[3:2]!=3;
wire[2:0]slot=addr[6:4];
integer bit_index;
snapshot_cdc #(.W(897)) transfer(clk,rst,send,payload,busy_cdc,pixel_clk,pixel_rst,frame_start,snapshot);
always @(posedge pixel_clk)begin
 if(pixel_addr<4800)pixel_data<=snapshot[896]?image1[pixel_addr]:image0[pixel_addr];
 else pixel_data<=0;
end
always @*begin
 invalid=0;rdata=0;bit_index=128+slot*96+addr[3:2]*32;
 case(addr)
 0:rdata=32'h00010000;
 4:rdata={17'b0,loaded,recording,busy};
 16'h10:rdata=staging[31:0];16'h14:rdata=staging[63:32];
 16'h18:rdata=staging[95:64];16'h1c:rdata=staging[127:96];
 8,12:rdata=0;
 default:begin if(boxreg)rdata=staging[bit_index+:32];else if(rd)invalid=1;end
 endcase
 if(wr)begin
  if(busy)invalid=1;
  else if(addr==8)begin if(wdata!=1)invalid=1;end
  else if(addr==12)begin
   if(wdata!=1||!recording||(staging[96]&&loaded!=4800)||staging[79:72]>8)invalid=1;
  end
  else if(ram)begin if(!recording||index!=loaded)invalid=1;end
  else if(!(recording&&(addr==16'h10||addr==16'h14||addr==16'h18||addr==16'h1c||boxreg)))invalid=1;
 end
 if((wr||rd)&&addr[1:0]!=0)invalid=1;
 if(wr&&wstrb!=15)invalid=1;
end
always @(posedge clk)begin
 if(rst)begin staging<=0;payload<=0;send<=0;write_bank<=0;loaded<=0;recording<=0;end
 else begin
  send<=0;
  if(wr&&!invalid)begin
   if(addr==8)begin staging<=0;loaded<=0;recording<=1;end
   else if(addr==12)begin payload<={write_bank,staging};write_bank<=~write_bank;send<=1;recording<=0;end
   else if(ram)begin
    if(write_bank)image1[index]<=wdata;else image0[index]<=wdata;
    loaded<=loaded+1'b1;
   end else case(addr)
    16'h10:staging[31:0]<=wdata;16'h14:staging[63:32]<=wdata;
    16'h18:staging[95:64]<=wdata;16'h1c:staging[127:96]<=wdata;
    default:staging[128+slot*96+addr[3:2]*32+:32]<=wdata;
   endcase
  end
 end
end
endmodule
