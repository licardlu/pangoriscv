// Full-width snapshot fallback below the 112-pixel header. Native video bypasses it.
module vision_overlay(input wire[10:0]x,input wire[9:0]y,input wire[127:0]ui,
 input wire[896:0]vision,output reg enable,camera,ink,output reg[23:0]color,
 output reg[12:0]pixel_addr,output reg[1:0]pixel_lane);
function automatic[23:0]class_color;input[7:0]c;begin
 case(c)0:class_color=24'hde596e;1:class_color=24'hd99f20;2:class_color=24'h158263;
 3:class_color=24'h397eb5;4:class_color=24'h9b58b5;default:class_color=24'h168b63;endcase
end endfunction
integer i,p,ax,ay,bx,by;reg[95:0]boxdata;reg target;
always @*begin
 enable=x<1280&&y>=112&&y<720;camera=enable&&vision[96];
 ink=0;color=24'hedf3f3;pixel_addr=0;pixel_lane=0;
 p=0;ax=0;ay=0;bx=0;by=0;boxdata=0;target=0;
 if(enable)begin
  p=(y/6)*160+(x/8);pixel_addr=p/4;pixel_lane=p%4;
  for(i=0;i<8;i=i+1)begin
   boxdata=vision[128+i*96+:96];
   ax=boxdata[15:0]*4;ay=boxdata[31:16]*3;
   bx=boxdata[47:32]*4;by=boxdata[63:48]*3;
   if(vision[96]&&i<vision[79:72]&&boxdata[15:0]<boxdata[47:32]&&
      boxdata[31:16]<boxdata[63:48]&&boxdata[47:32]<=320&&boxdata[63:48]<=240&&bx>0&&ax<1280&&by>112)begin
    target=1;
    if(x>=ax&&x<bx&&y>=ay&&y<by&&
       (x<ax+4||x>=bx-4||y<ay+4||y>=by-4))begin ink=1;color=class_color(boxdata[71:64]);end
   end
  end
  if(!target&&x>=480&&x<800&&y>=200&&y<520&&
     (x<484||x>=796||y<204||y>=516))begin ink=1;color=24'h158263;end
 end
end
endmodule
