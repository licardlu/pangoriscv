// Standalone compact-header layout. The MMIO adapter is a snapshot fallback;
// the board live path uses light_split_video with native RGB565 pixels.
module ui_rgb #(parameter BG="ui_bg.hex",PAL="ui_palette.hex",STATUS="ui_status.hex",BUSINESS=0)(
 input wire clk,rst,input wire[127:0]snapshot,output wire frame_start,
 output wire hs,vs,de,output wire[23:0]rgb,
 input wire[896:0]vision,input wire[31:0]vision_pixels,output wire[12:0]vision_addr);
reg[10:0]x;reg[9:0]y;
always @(posedge clk)begin
 if(rst)begin x<=0;y<=0;end
 else if(x==1649)begin x<=0;y<=y==749?0:y+1'b1;end
 else x<=x+1'b1;
end
generate if(BUSINESS)begin:legacy_profile
 ui_rgb_legacy #(.BG(BG),.PAL(PAL),.STATUS(STATUS),.BUSINESS(1)) display(
  clk,rst,snapshot,frame_start,hs,vs,de,rgb,vision,vision_pixels,vision_addr);
end else begin:light_profile
 assign frame_start=x==0&&y==0;
 wire[23:0]header_rgb,color;wire enable,camera,ink;wire[1:0]lane;
 ui_light_panel panel(clk,rst,x,y,snapshot,header_rgb);
 vision_overlay camera_panel(x,y,snapshot,vision,enable,camera,ink,color,vision_addr,lane);
 reg enable_d,enable_dd,camera_d,ink_d;reg[1:0]lane_d;
 reg[23:0]color_d,camera_rgb;reg[1:0]hp,vp,dp;
 wire[7:0]pixel=(vision_pixels>>(lane_d*8))&255;
 wire[23:0]pixel_rgb={pixel[7:5],pixel[7:5],pixel[7:6],pixel[4:2],pixel[4:2],pixel[4:3],{4{pixel[1:0]}}};
 always @(posedge clk)begin
  if(rst)begin
   enable_d<=0;enable_dd<=0;camera_d<=0;ink_d<=0;lane_d<=0;color_d<=0;camera_rgb<=0;hp<=3;vp<=3;dp<=0;
  end else begin
   hp<={hp[0],!(x>=1390&&x<1430)};vp<={vp[0],!(y>=725&&y<730)};dp<={dp[0],x<1280&&y<720};
   enable_d<=enable;enable_dd<=enable_d;camera_d<=camera;ink_d<=ink;lane_d<=lane;color_d<=color;
   camera_rgb<=camera_d&&!ink_d?pixel_rgb:color_d;
  end
 end
 assign hs=hp[1];assign vs=vp[1];assign de=dp[1];
 assign rgb=dp[1]?(enable_dd?camera_rgb:header_rgb):24'b0;
end endgenerate
endmodule

module ui_rgb_legacy #(parameter BG="ui_bg.hex",PAL="ui_palette.hex",STATUS="ui_status.hex",BUSINESS=0)(
input wire clk,rst,input wire[127:0]snapshot,output wire frame_start,output reg hs,vs,de,output reg[23:0]rgb,
input wire[896:0]vision,input wire[31:0]vision_pixels,output wire[12:0]vision_addr);
reg[10:0]x;reg[9:0]y;wire active=x<1280&&y<720;
assign frame_start=x==0&&y==0;
reg[31:0]bg[0:28799],st[0:9719];reg[23:0]palette[0:15];
initial begin $readmemh(BG,bg);$readmemh(PAL,palette);$readmemh(STATUS,st);end
wire ve,vc,vi;wire[23:0]vcolor;wire[1:0]vlane;
reg ved,vcd,vid;reg[23:0]vcolor_d;reg[1:0]vlane_d;
wire[7:0]vp=(vision_pixels>>(vlane_d*8))&255;
wire[23:0]vrgb={vp[7:5],vp[7:5],vp[7:6],vp[4:2],vp[4:2],vp[4:3],vp[1:0],vp[1:0],vp[1:0],vp[1:0]};
generate if(!BUSINESS)begin:with_vision
 vision_overlay recognition(x,y,snapshot,vision,ve,vc,vi,vcolor,vision_addr,vlane);
end else begin:no_vision
 assign ve=0;assign vc=0;assign vi=0;assign vcolor=0;assign vision_addr=0;assign vlane=0;
end endgenerate
always @(posedge clk)begin
 if(rst)begin ved<=0;vcd<=0;vid<=0;vcolor_d<=0;vlane_d<=0;end
 else begin ved<=ve;vcd<=vc;vid<=vi;vcolor_d<=vcolor;vlane_d<=vlane;end
end
reg overlay_d;reg[23:0]over_d;
reg[31:0]word;reg[2:0]nibble;reg hd,vd,dd;reg overlay;reg[23:0]overcolor;
wire[9:0]xx=x>>1;wire[8:0]yy=y>>1;
reg[31:0]index;reg[3:0]digit;reg[6:0]segments;reg digit_on;integer n,lx,ly,power;
wire[31:0]points=snapshot[63:32];wire[2:0]state=snapshot[2:0];wire mode=snapshot[96];
wire[39:0]point_digits,user_digits;wire pb,ub;
bcd32 points_bcd(clk,rst,frame_start,points,point_digits,pb);
bcd32 user_bcd(clk,rst,frame_start,snapshot[95:64],user_digits,ub);
wire[1:0]correct=snapshot[105:104],choice=snapshot[113:112];wire answered=snapshot[119];
wire[3:0]view_state=state==2&&answered?(choice==correct?7:8):(state>6?6:state);
// Standalone flags: bit 27 is music actually started, bit 28 is MUSIC0 ready.
// The legacy BUSINESS profile keeps its existing, separate flag meanings.
wire music_playing=snapshot[123],music_ready=snapshot[124];
`include "vision_font.vh"
function automatic panel_text;
 input integer kind,x0,y0,px,py;integer tx,ty;reg[191:0]label_text;reg[7:0]ch;begin
 case(kind)
  0:label_text="POINTS                  ";
  1:label_text="AUDIO REWARD            ";
  2:label_text="MUSIC0.WAV              ";
  3:label_text="MORNING PATH            ";
  4:label_text="EXTERNAL SPEAKER        ";
  5:label_text="I2S 48KHZ PCM16         ";
  6:label_text="READY                   ";
  7:label_text="PLAYING                 ";
  8:label_text="ASSET MISSING           ";
  9:label_text="CORRECT ANSWER          ";
  default:label_text="AUTO PLAY MUSIC         ";
 endcase
 tx=px-x0;ty=py-y0;panel_text=0;ch=0;
 if(tx>=0&&tx<288&&ty>=0&&ty<14)begin
  ch=label_text[191-(tx/12)*8-:8];
  panel_text=(ch==8'd46) ? ((tx/2)%6==2&&ty/2==6) : glyph(ch,(tx/2)%6,ty/2);
 end
 end
endfunction
always @*begin
 index=yy*640+xx;overlay=0;overcolor=24'h33d2b0;digit_on=0;digit=0;segments=0;lx=0;ly=0;power=1;
 if(!BUSINESS&&xx>=424&&xx<616&&((yy>=16&&yy<104)||(yy>=110&&yy<338)))begin
  overlay=1;overcolor=24'h192b3d;
 end
 if(yy>=72&&yy<98&&((mode&&xx>=212&&xx<384)||(!mode&&xx>=24&&xx<196)))if(yy==72||yy==97)overlay=1;
 if(state==2)begin
  if(yy>=124&&yy<286&&xx>=24&&xx<384)begin
   if(((correct==0&&xx<196&&yy<200)||(correct==1&&xx>=212&&yy<200)||(correct==2&&xx<196&&yy>=210)||(correct==3&&xx>=212&&yy>=210))&&((yy==124||yy==199||yy==210||yy==285)||(xx==24||xx==195||xx==212||xx==383)))overlay=1;
  end
  if(answered&&choice==correct&&xx>=348&&xx<384&&yy>=110&&yy<122)begin overlay=1;overcolor=24'h33d2b0;end
 end
 for(n=0;n<10;n=n+1)begin
  if(xx>=440+n*16&&xx<452+n*16&&yy>=46&&yy<72)begin
   lx=xx-(440+n*16);ly=yy-46;power=1;
   case(n)0:power=1000000000;1:power=100000000;2:power=10000000;3:power=1000000;4:power=100000;5:power=10000;6:power=1000;7:power=100;8:power=10;default:power=1;endcase
   digit=point_digits[(9-n)*4+:4];
   case(digit)0:segments=7'b1111110;1:segments=7'b0110000;2:segments=7'b1101101;3:segments=7'b1111001;4:segments=7'b0110011;5:segments=7'b1011011;6:segments=7'b1011111;7:segments=7'b1110000;8:segments=7'b1111111;default:segments=7'b1111011;endcase
   digit_on=(segments[6]&&ly<3&&lx>=3&&lx<9)||(segments[5]&&lx>=9&&ly>=3&&ly<12)||(segments[4]&&lx>=9&&ly>=14&&ly<23)||(segments[3]&&ly>=23&&lx>=3&&lx<9)||(segments[2]&&lx<3&&ly>=14&&ly<23)||(segments[1]&&lx<3&&ly>=3&&ly<12)||(segments[0]&&ly>=11&&ly<14&&lx>=3&&lx<9);
   if(digit_on&&(points>=power||n==9)&&(!BUSINESS||snapshot[127]))begin overlay=1;overcolor=24'hffffff;end
  end
 end
 if(snapshot[122:120]!=0&&xx>=424&&xx<616&&yy>=286&&yy<318)if(yy==286||yy==317)overlay=1;
 if(BUSINESS)begin
  if(!snapshot[127]&&xx>=544&&xx<600&&yy>=59&&yy<62)begin overlay=1;overcolor=24'h91a9bb;end
  if(xx>=602&&xx<609&&yy>=27&&yy<34)begin overlay=1;overcolor=snapshot[127]?24'h33d2b0:24'h91a9bb;end
  if(xx>=440&&xx<600&&yy>=101&&yy<104)begin overlay=1;overcolor=points>=800||xx-440<(points>>2)?24'h33d2b0:24'h314b61;end
  for(n=0;n<6;n=n+1)begin
   if(xx>=510+n*15&&xx<522+n*15&&yy>=80&&yy<94)begin
    lx=xx-(510+n*15);ly=(yy-80)*2;digit=user_digits[(5-n)*4+:4];
    case(digit)0:segments=7'b1111110;1:segments=7'b0110000;2:segments=7'b1101101;3:segments=7'b1111001;4:segments=7'b0110011;5:segments=7'b1011011;6:segments=7'b1011111;7:segments=7'b1110000;8:segments=7'b1111111;default:segments=7'b1111011;endcase
    digit_on=(segments[6]&&ly<3&&lx>=3&&lx<9)||(segments[5]&&lx>=9&&ly>=3&&ly<12)||(segments[4]&&lx>=9&&ly>=14&&ly<23)||(segments[3]&&ly>=23&&lx>=3&&lx<9)||(segments[2]&&lx<3&&ly>=14&&ly<23)||(segments[1]&&lx<3&&ly>=3&&ly<12)||(segments[0]&&ly>=11&&ly<14&&lx>=3&&lx<9);
    if(digit_on&&snapshot[127])begin overlay=1;overcolor=24'h33d2b0;end
   end
  end
 end
 if(!BUSINESS)begin
  if(panel_text(0,880,52,x,y)||panel_text(1,880,236,x,y))begin overlay=1;overcolor=24'hc7d7e2;end
  if(panel_text(2,880,286,x,y))begin overlay=1;overcolor=24'hffffff;end
  if(panel_text(3,880,320,x,y)||panel_text(4,880,376,x,y)||panel_text(5,880,408,x,y)||
     panel_text(9,880,508,x,y)||panel_text(10,880,540,x,y))begin overlay=1;overcolor=24'h91a9bb;end
  if(panel_text(music_playing?7:(music_ready?6:8),880,448,x,y))begin
   overlay=1;overcolor=music_playing?24'hffcb6b:(music_ready?24'h33d2b0:24'hf47782);
  end
 end
end
always @(posedge clk)begin
 if(rst)begin x<=0;y<=0;hs<=1;vs<=1;de<=0;rgb<=0;word<=0;nibble<=0;hd<=1;vd<=1;dd<=0;end
 else begin
  if(x==1649)begin x<=0;if(y==749)y<=0;else y<=y+1'b1;end else x<=x+1'b1;
  if(active)begin
   if(xx>=24&&xx<384&&yy>=312&&yy<336)begin word<=st[(view_state*8640+(yy-312)*360+xx-24)>>3];nibble<=(xx-24)%8;end
   else begin word<=bg[index>>3];nibble<=index[2:0];end
  end
  hd<=!(x>=1390&&x<1430);vd<=!(y>=725&&y<730);dd<=active;
  hs<=hd;vs<=vd;de<=dd;rgb<=dd?(ved?((vcd&&!vid)?vrgb:vcolor_d):(overlay_d?over_d:palette[(word>>(nibble*4))&15])):24'b0;
 end
end
always @(posedge clk)begin overlay_d<=overlay;over_d<=overcolor;end
endmodule
