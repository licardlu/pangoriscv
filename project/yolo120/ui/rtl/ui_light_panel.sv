// Bright 640x720 control panel. x/y belong to the full 1280x720 raster.
// RGB is delayed by exactly two pixel clocks; the camera path must match it.
module ui_light_panel #(
 parameter BG="ui_light_bg.hex", PAL="ui_light_palette.hex", STATUS="ui_light_status.hex"
)(input wire clk,rst,input wire[10:0]x,input wire[9:0]y,
 input wire[127:0]snapshot,output reg[23:0]rgb);
`include "vision_font.vh"
reg[31:0]bg[0:28799],st[0:9719];reg[23:0]palette[0:15];
initial begin $readmemh(BG,bg);$readmemh(PAL,palette);$readmemh(STATUS,st);end
wire[31:0]points=snapshot[63:32];wire[39:0]digits;wire busy;
bcd32 convert(clk,rst,x==0&&y==0,points,digits,busy);
wire[2:0]state=snapshot[2:0];wire answered=snapshot[119];
wire[1:0]correct=snapshot[105:104],choice=snapshot[113:112];
wire[3:0]view_state=state==3?6:(state==2&&answered?(choice==correct?7:8):{1'b0,state});
function automatic label_ink;
 input integer kind,px,py;integer lx,ly;reg[111:0]str;reg[7:0]ch;
 begin
  case(kind)0:str="READY         ";1:str="PLAYING       ";default:str="UNAVAILABLE   ";endcase
  lx=px-420;ly=py-630;label_ink=0;ch=0;
  if(lx>=0&&lx<168&&ly>=0&&ly<14)begin
   ch=str[111-(lx/12)*8-:8];label_ink=glyph(ch,(lx/2)%6,ly/2);
  end
 end
endfunction
integer n,lx,ly;reg[3:0]digit;reg[6:0]segments;reg digit_on,visible;
reg over;reg[23:0]overcolor;reg[31:0]index;reg use_status;
reg[31:0]word_d;reg[2:0]lane_d;reg over_d;reg[23:0]overcolor_d;
always @*begin
 index=(y>>1)*640+(x>>1);use_status=0;
 if(x>=52&&x<608&&y>=510&&y<534)begin
  index=view_state*8640+((y-510)>>1)*360+((x-52)>>1);use_status=1;
 end
 over=0;overcolor=24'h158263;lx=0;ly=0;digit=0;segments=0;digit_on=0;visible=0;
 if(x<640)begin
  if(y>=220&&y<224&&((!snapshot[96]&&x>=32&&x<312)||(snapshot[96]&&x>=328&&x<608)))over=1;
  for(n=0;n<10;n=n+1)begin
   if(x>=320+n*28&&x<340+n*28&&y>=116&&y<152)begin
    lx=x-(320+n*28);ly=y-116;digit=digits[(9-n)*4+:4];visible=0;
    case(n)
     0:visible=points>=1000000000;1:visible=points>=100000000;
     2:visible=points>=10000000;3:visible=points>=1000000;
     4:visible=points>=100000;5:visible=points>=10000;
     6:visible=points>=1000;7:visible=points>=100;
     8:visible=points>=10;default:visible=1;
    endcase
    case(digit)
     0:segments=7'b1111110;1:segments=7'b0110000;2:segments=7'b1101101;
     3:segments=7'b1111001;4:segments=7'b0110011;5:segments=7'b1011011;
     6:segments=7'b1011111;7:segments=7'b1110000;8:segments=7'b1111111;
     default:segments=7'b1111011;
    endcase
    digit_on=(segments[6]&&ly<3&&lx>=3&&lx<17)||
      (segments[5]&&lx>=17&&ly>=3&&ly<17)||
      (segments[4]&&lx>=17&&ly>=19&&ly<33)||
      (segments[3]&&ly>=33&&lx>=3&&lx<17)||
      (segments[2]&&lx<3&&ly>=19&&ly<33)||
      (segments[1]&&lx<3&&ly>=3&&ly<17)||
      (segments[0]&&ly>=17&&ly<20&&lx>=3&&lx<17);
    if(digit_on&&visible)begin over=1;overcolor=24'h17483f;end
   end
  end
  if(label_ink(snapshot[123]?1:(snapshot[124]?0:2),x,y))begin
   over=1;overcolor=snapshot[124]||snapshot[123]?24'h158263:24'h52756b;
  end
 end
end
always @(posedge clk)begin
 if(rst)begin word_d<=0;lane_d<=0;over_d<=0;overcolor_d<=0;rgb<=24'hf4f8f6;end
 else begin
  if(x<1280&&y<720)word_d<=use_status?st[index>>3]:bg[index>>3];
  lane_d<=index[2:0];over_d<=over;overcolor_d<=overcolor;
  rgb<=over_d?overcolor_d:palette[(word_d>>(lane_d*4))&15];
 end
end
endmodule
