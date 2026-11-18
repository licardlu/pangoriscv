`timescale 1ns/1ps
module tb_feedback_voice_route;
 reg clk=0,rst=1,request_valid=0,benchmark_page=0,media_active=0,mute_voice=0;
 reg [3:0] request_asset_id=0;
 reg [1:0] request_bin_index=0;
 wire media_ready,audio_busy,playback_done,i2s_bclk,i2s_lrclk,i2s_data;
 integer prompts=0;
 always #5 clk=~clk;
 trash_voice_i2s #(.CLK_HZ(27000000),.ROM_FILE("voice_pcm8.hex")) dut(
  .clk(clk),.rst(rst),.request_valid(request_valid),.request_asset_id(request_asset_id),
  .request_bin_index(request_bin_index),.media_active(media_active),.media_valid(1'b0),
  .mute_voice(mute_voice),.benchmark_page(benchmark_page),.media_pcm(32'b0),
  .media_ready(media_ready),.audio_busy(audio_busy),.playback_done(playback_done),
  .i2s_bclk(i2s_bclk),.i2s_lrclk(i2s_lrclk),.i2s_data(i2s_data));
 always @(posedge clk)if(!rst && dut.player_request_valid&&dut.player_request_asset==14)prompts=prompts+1;
 task ticks(input integer n);repeat(n)@(negedge clk);endtask
 initial begin
  ticks(4);rst=0;ticks(4);
  request_valid=1;request_asset_id=2;ticks(1);request_valid=0;ticks(8);
  if(!dut.suffix_pending)$fatal(1,"Quiz phrase missing bin suffix");
  benchmark_page=1;ticks(8);
  if(prompts!=1||!dut.player.busy||dut.suffix_pending)$fatal(1,"Page prompt not isolated from quiz");
  request_valid=1;request_asset_id=3;ticks(1);request_valid=0;ticks(8);
  if(prompts!=1||dut.suffix_pending)$fatal(1,"Quiz leaked into page prompt");
  benchmark_page=0;ticks(5);if(dut.player.busy)$fatal(1,"Leaving page failed to cancel prompt");
  benchmark_page=1;ticks(8);if(prompts!=2||!dut.player.busy)$fatal(1,"Page re-entry did not speak once");
  media_active=1;mute_voice=1;benchmark_page=0;ticks(5);
  if(dut.player.busy||dut.suffix_pending)$fatal(1,"Media transition did not mute voice");
  $display("TEST_PASS voice route: page14 exactly once, quiz suffix isolated, page exit/re-entry and media cancellation");$finish;
 end
 initial begin #100000;$fatal(1,"Voice routing timeout");end
endmodule
