`timescale 1ns/1ps
module light_panel_tb;
reg clk=0,rst=1;always #5 clk=~clk;
reg[10:0]x=0;reg[9:0]y=0;reg[127:0]snapshot=0;wire[23:0]rgb;
reg[31:0]reference_status[0:4859];reg[23:0]pal[0:15];
ui_light_panel dut(clk,rst,x,y,snapshot,rgb);
task sample;input[10:0]px;input[9:0]py;input[23:0]expected;begin
 @(negedge clk);x=px;y=py;repeat(3)@(negedge clk);
 if(rgb!==expected)$fatal(1,"header %0d,%0d: %h expected %h",px,py,rgb,expected);
end endtask
task check_status;input integer expected_state;integer px,py,idx;reg[31:0]w;begin
 for(py=0;py<12;py=py+1)for(px=0;px<278;px=px+7)begin
  idx=expected_state*4320+py*360+px;w=reference_status[idx/8];
  sample(660+px*2,56+py*2,pal[(w>>((idx%8)*4))&15]);
 end
end endtask
integer s;
initial begin
 $readmemh("ui_light_status.hex",reference_status);$readmemh("ui_light_palette.hex",pal);
 repeat(4)@(negedge clk);rst=0;
 sample(10,10,24'hf4f8f6);sample(650,50,24'he4f1eb);
 check_status(0); // normal-mode idle waits for camera recognition
 for(s=1;s<=7;s=s+1)begin snapshot[2:0]=s;check_status((s==3||s==7)?6:s);end
 snapshot[2:0]=2;snapshot[119]=1;snapshot[105:104]=2;snapshot[113:112]=2;
 check_status(7);snapshot[113:112]=1;check_status(8);
 snapshot[63:32]=32'hffffffff;snapshot[124:123]=3;
 sample(10,110,24'hf4f8f6); // former points/audio bits cannot add UI
 sample(10,112,24'hedf3f3);sample(1279,719,24'hedf3f3);
 sample(1649,749,24'hedf3f3); // blanking cannot address outside compact ROM
 $display("TEST_PASS light_panel compact header + all dynamic status sprites + ROM bounds");$finish;
end
initial begin #1000000;$fatal(1,"light panel timeout");end
endmodule
