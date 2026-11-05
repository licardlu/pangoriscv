`timescale 1ns/1ps
module overlay_tb;
reg[10:0]x=0;reg[9:0]y=0;reg[127:0]ui=0;reg[896:0]vision=0;
wire enable,camera,ink;wire[23:0]color;wire[12:0]addr;wire[1:0]lane;
vision_overlay dut(x,y,ui,vision,enable,camera,ink,color,addr,lane);
initial begin
 vision[96]=1;vision[79:64]=16'h0101;
 vision[159:128]={16'd20,16'd100};vision[191:160]={16'd120,16'd200};vision[223:192]=32'h00005803;
 x=0;y=112;#1;if(!enable||!camera||ink||addr!=720||lane!=0)$fatal(1,"lower camera origin");
 x=8;y=114;#1;if(addr!=760||lane!=1)$fatal(1,"native full-width sampling");
 x=400;y=120;#1;if(!ink||color!=24'h397eb5)$fatal(1,"YOLO edge");
 x=600;y=180;#1;if(!camera||ink)$fatal(1,"bbox filled interior");
 ui[96]=1;ui[2:0]=1;x=400;y=120;#1;if(!enable||!ink)$fatal(1,"quiz hides camera or box");
 ui[2:0]=2;#1;if(!enable||!ink)$fatal(1,"feedback hides camera or box");
 vision[79:72]=0;x=480;y=200;#1;if(!ink||color!=24'h158263)$fatal(1,"empty image needs guide");
 vision[96]=0;#1;if(!enable||camera||!ink)$fatal(1,"startup guide");
 y=111;#1;if(enable)$fatal(1,"camera crossed header boundary");
 x=1279;y=719;#1;if(!enable)$fatal(1,"camera does not fill lower region");
 $display("TEST_PASS overlay lower region, full-width coordinates, hollow boxes and persistent guide");$finish;
end
endmodule
