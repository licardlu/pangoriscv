`timescale 1ns/1ps
module tb_overnight_adpcm;
 reg clk=0,rst=1,request_valid=0,sample_ready=0;
 reg [3:0] request_asset_id=0;
 wire sample_valid,sample_last,busy;
 wire [15:0] sample_pcm;
 reg [15:0] expected[0:237768];
 integer lengths[1:13],offsets[1:13];
 integer id,accepted,cycle,total=0;
 reg stalled=0;
 reg [15:0] stalled_pcm;
 reg stalled_last;
 always #5 clk=~clk;
 trash_voice_rom_player #(.ROM_FILE("../../project/trash_sorting/candidates/overnight_020/source/extensions/business/application/assets/audio_rom/voice_pcm8.hex")) dut(.*);
 task ticks(input integer n);repeat(n)@(negedge clk);endtask
 task play(input integer asset);
  @(negedge clk);request_valid=1;request_asset_id=asset;sample_ready=0;
  @(negedge clk);request_valid=0;accepted=0;cycle=0;stalled=0;
  while(accepted<lengths[asset]*4)begin
   @(negedge clk);sample_ready=(cycle%7!=0)&&(cycle%101<95);
   request_valid=cycle==37;request_asset_id=15; // Invalid request must not preempt.
   @(posedge clk);
   if(stalled&&(sample_pcm!==stalled_pcm||sample_last!==stalled_last||!sample_valid))
    $fatal(1,"Backpressure changed output at asset%0d sample%0d",asset,accepted);
   stalled=sample_valid&&!sample_ready;stalled_pcm=sample_pcm;stalled_last=sample_last;
   if(sample_valid&&sample_ready)begin
    if(sample_pcm!==expected[offsets[asset]+accepted/4])
     $fatal(1,"ADPCM mismatch asset%0d sample%0d got%h expected%h",asset,accepted,sample_pcm,expected[offsets[asset]+accepted/4]);
    if(sample_last!==(accepted==lengths[asset]*4-1))$fatal(1,"Last flag at wrong sample");
    accepted=accepted+1;total=total+1;
   end
   cycle=cycle+1;
  end
  @(negedge clk);sample_ready=0;request_valid=0;ticks(3);
  if(busy||sample_valid)$fatal(1,"Asset did not finish");
  $display("ASSET_PASS %0d samples%0d",asset,accepted);
 endtask
 initial begin
  $readmemh("audio/vectors/voice_expected.hex",expected);
  `include "voice_vectors.svh"
  ticks(4);rst=0;ticks(4);
  for(id=1;id<=13;id=id+1)play(id);
  // Preempt a live long clip: the next clip must start with fresh codec state.
  request_asset_id=9;request_valid=1;ticks(1);request_valid=0;sample_ready=1;ticks(100);
  play(1);
  request_asset_id=9;request_valid=1;ticks(1);request_valid=0;ticks(10);rst=1;ticks(2);
  if(sample_valid||busy)$fatal(1,"Reset failed to cancel audio");
  $display("TEST_PASS overnight ADPCM: all13 clips bit-exact to audioop, four repeats, stalls, invalid request, preemption, reset; transfers=%0d",total);
  $finish;
 end
 initial begin #100000000;$fatal(1,"ADPCM test timeout");end
endmodule
