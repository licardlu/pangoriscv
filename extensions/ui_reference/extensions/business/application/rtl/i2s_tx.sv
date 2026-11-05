module i2s_tx(input wire clk,rst,enable,sample_valid,input wire[31:0]sample,output wire sample_ready,output reg bclk,lrclk,sdout,started,output reg[31:0]underruns,completed);
// clk must be exactly 12.288MHz: BCLK=clk/4, 64 clocks/stereo frame => 48kHz.
reg div;reg[5:0]bit_index;reg[31:0]frame;reg active,frame_valid;
wire[5:0]next_bit=bit_index+1'b1;
assign sample_ready=enable&&div&&bclk&&bit_index==63;
always @(posedge clk)begin
 if(rst)begin div<=0;bclk<=0;lrclk<=0;sdout<=0;started<=0;bit_index<=63;frame<=0;active<=0;frame_valid<=0;underruns<=0;completed<=0;end
 else begin
  started<=0;
  if(!enable)begin div<=0;bclk<=0;lrclk<=0;sdout<=0;bit_index<=63;active<=0;frame_valid<=0;end
  else begin
   div<=~div;
   if(div)begin
    bclk<=~bclk;
    if(bclk)begin
     bit_index<=next_bit;lrclk<=next_bit>=32;sdout<=0;
     if(next_bit==0)begin
      if(frame_valid)completed<=completed+1'b1;
      frame_valid<=sample_valid;
      frame<=sample_valid?sample:32'b0;
      if(sample_valid)begin if(!active)started<=1;active<=1;end
      else begin underruns<=underruns+1;active<=0;end
     end else if(next_bit>=1&&next_bit<=16)sdout<=frame[32-next_bit];
     else if(next_bit>=33&&next_bit<=48)sdout<=frame[48-next_bit];
    end
   end
  end
 end
end
endmodule
