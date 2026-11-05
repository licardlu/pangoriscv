// Compact 1280x112 header. RGB latency is exactly two pixel clocks.
// Only title, tagline and current status remain; no points/music overlays.
module ui_light_panel #(
 parameter BG="ui_light_bg.hex", PAL="ui_light_palette.hex", STATUS="ui_light_status.hex"
)(input wire clk,rst,input wire[10:0]x,input wire[9:0]y,
 input wire[127:0]snapshot,output reg[23:0]rgb);
reg[31:0]bg[0:4479],st[0:4859];reg[23:0]palette[0:15];
initial begin $readmemh(BG,bg);$readmemh(PAL,palette);$readmemh(STATUS,st);end
wire[2:0]state=snapshot[2:0];wire answered=snapshot[119];
wire[1:0]correct=snapshot[105:104],choice=snapshot[113:112];
// Idle waits for a camera result; the key legend appears after a result latches.
wire[3:0]view_state=(state==3||state>6)?6:
 (state==2&&answered?(choice==correct?7:8):{1'b0,state});
reg[15:0]index;reg use_status;
reg[31:0]word_d;reg[2:0]lane_d;
always @*begin
 index=(y>>1)*640+(x>>1);use_status=0;
 if(x>=660&&x<1216&&y>=56&&y<80)begin
  index=view_state*4320+((y-56)>>1)*360+((x-660)>>1);use_status=1;
 end
end
always @(posedge clk)begin
 if(rst)begin word_d<=0;lane_d<=0;rgb<=24'hf4f8f6;end
 else begin
  // Guard the compact ROM against camera and blanking coordinates.
  if(x<1280&&y<112)word_d<=use_status?st[index>>3]:bg[index>>3];
  else word_d<=32'h77777777;
  lane_d<=index[2:0];
  rgb<=palette[(word_d>>(lane_d*4))&15];
 end
end
endmodule
