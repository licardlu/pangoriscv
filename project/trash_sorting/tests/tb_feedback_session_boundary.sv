`timescale 1ns/1ps
// Combined control-path check. Clocks/debounce/frame cadence are accelerated;
// the real voice ROM/decoder/transmitter remain connected, not mocked.
module tb_feedback_session_boundary #(
 parameter integer CPU_HALF=5,PIX_HALF=7,CPU_OFFSET=0
);
 reg clk=0,cpu_clk=0,pix_clk=0,rst=1,key0_n=1;
 reg [3:0] key_n=15;
 reg detect_event=0;
 reg [2:0] bin_code=2;
 always #11 clk=~clk;
 initial begin #(CPU_OFFSET);forever #(CPU_HALF)cpu_clk=~cpu_clk;end
 always #(PIX_HALF) pix_clk=~pix_clk;
 wire next_page,long_press,toggle_recognition,benchmark_start_toggle;
 wire [1:0] page,display_page;
 wire automatic_blocked,benchmark_key_event;
 wire [3:0] servo_pwm,open_state,voice_asset_id;
 wire voice_valid;
 wire [127:0] snapshot;
 reg [2:0] onehot=4;
 always @(posedge clk)case(page)
  0:onehot<=1;1:onehot<=2;2:onehot<=4;default:onehot<=1;
 endcase
 benchmark_key_router #(.CLK_HZ(1000),.DEBOUNCE_MS(3),
  .LONG_PRESS_MS(80),.DOUBLE_CLICK_MS(18)) keys(
  .clk(clk),.rst(rst),.key0_n(key0_n),.toggle_page(next_page),
  .start_reference(long_press),.toggle_recognition(toggle_recognition));
 media_page_router #(.RESET_PAGE(2),.AUTO_ONEHOT(1)) pages(
  .clk(clk),.rst(rst),.next_page(next_page),.long_press(long_press),
  .debug_page_async(1'b0),.toggle_recognition(toggle_recognition),
  .benchmark_key_event(benchmark_key_event),.automatic_request_async(3'b001),
  .automatic_blocked(automatic_blocked),.page(page),
  .benchmark_start_toggle(benchmark_start_toggle));
 trash_peripherals #(.CLK_HZ(1000),.DEBOUNCE_MS(3),.OPEN_MS(60),
  .NAVIGATION_ENABLE(1),.SERVO_MOVE_FRAMES(2),.SERVO_REVERSED_MASK(4'b1111)) quiz(
  .clk(clk),.rst(rst),.start_ready(1'b1),.key_n(key_n),.navigation_page(page!=0),
  .detect_event(detect_event&&page==0),.bin_valid(1'b1),.bin_code(bin_code),
  .servo_pwm(servo_pwm),.open_state(open_state),.benchmark_key_event(benchmark_key_event),
  .voice_valid(voice_valid),.voice_asset_id(voice_asset_id),.snapshot(snapshot));
 wire media_ready,audio_busy,playback_done,bclk,lrclk,audio_data;
 trash_voice_i2s #(.CLK_HZ(27000000),.ROM_FILE("voice_pcm8.hex")) audio(
  .clk(clk),.rst(rst),.request_valid(voice_valid),.request_asset_id(voice_asset_id),
  .request_bin_index(snapshot[105:104]),.media_active(page==2),.mute_voice(page==2),
  .benchmark_page(page==1),.media_valid(1'b0),.media_pcm(32'b0),.media_ready(media_ready),
  .audio_busy(audio_busy),.playback_done(playback_done),
  .i2s_bclk(bclk),.i2s_lrclk(lrclk),.i2s_data(audio_data));
 reg [5:0] frame_count=0;
 always @(posedge pix_clk)frame_count<=frame_count+1'b1;
 wire frame_start=frame_count==0;
 wire [23:0] transition_rgb,benchmark_rgb;
 media_page_transition transition(.clk(pix_clk),.rst(rst),.frame_start(frame_start),
  .request_onehot_async(onehot),.rgb_in(24'hffffff),.display_page(display_page),.rgb_out(transition_rgb));
 wire [31:0] status;
 wire debug_page,page_pix;
 benchmark_page #(.FONT_FILE(""),.TRANSITION_ENABLE(1)) bench(
  .cpu_clk(cpu_clk),.cpu_rst(rst),.page_async(page==1),
  .start_toggle_async(benchmark_start_toggle),.display_page_async(display_page==1),
  .audio_busy_async(audio_busy),.wr_en(1'b0),.wr_addr(8'b0),.rd_addr(8'hd0),.wr_data(32'b0),
  .rd_data(status),.debug_page(debug_page),.pix_clk(pix_clk),.pix_rst(rst),
  .frame_start(frame_start),.x(11'b0),.y(10'b0),.rgb(benchmark_rgb),.page_pix(page_pix));
 integer prompts=0,answers=0,triggers=0;
 always @(posedge clk)if(!rst)begin
  if(audio.page_prompt)prompts=prompts+1;
  if(voice_valid&&voice_asset_id!=1)answers=answers+1;
  if(|quiz.servo_trigger)triggers=triggers+1;
 end
 task ticks(input integer n);repeat(n)@(negedge clk);endtask
 task click;key0_n=0;ticks(8);key0_n=1;ticks(8);endtask
 task single;click();ticks(30);endtask
 task double_click;click();click();ticks(3);endtask
 task key1;key_n=14;ticks(9);key_n=15;ticks(9);endtask
 task detect;detect_event=1;ticks(1);detect_event=0;ticks(4);endtask
 initial begin
  ticks(5);rst=0;ticks(15);
  key1();if(page!=2||triggers||status[0])$fatal(1,"Idle KEY1 escaped page gating");
  single();if(page!=0)$fatal(1,"Single click did not enable recognition");
  detect();if(snapshot[2:0]!=1)$fatal(1,"Question did not arm");
  key1();if(snapshot[2:0]!=2||triggers!=1||answers!=1||open_state!=2)
   $fatal(1,"Wrong answer failed to start the correct red-bin lifecycle");
  double_click();ticks(8);
  if(page!=1||prompts!=1||audio.suffix_pending||!audio.player.busy)
   $fatal(1,"Score entry failed to isolate page speech");
  if(snapshot[2:0]!=2||open_state!=2)$fatal(1,"Navigation canceled active mechanics");
  key1();ticks(10);
  if(!status[0]||!status[6]||status[1]||triggers!=1||answers!=1)
   $fatal(1,"KEY1 during speech did not remain a benchmark-only pending request");
  // Let the real PWM feedback finish even while the score page is active.
  ticks(220);
  if(snapshot[2:0]!=0||open_state||triggers!=1)$fatal(1,"Mechanics did not finish on score page");
  double_click();ticks(12);
  if(page!=2||status[0]||audio.player.busy||audio.suffix_pending)
   $fatal(1,"Exit retained pending run or quiz/page speech");
  double_click();ticks(12);
  if(page!=1||prompts!=2||status[0])$fatal(1,"Reentry auto-ran or missed its prompt");
  // Wait for actual pixel scanout to catch up; speech must still block start.
  ticks(1800);
  if(!status[5]||!status[6]||status[0])$fatal(1,"Displayed page/speech status inconsistent");
  single();if(page!=0||audio.player.busy)$fatal(1,"Recognition reentry retained page speech");
  detect();if(snapshot[2:0]!=1)$fatal(1,"New recognition question failed after navigation");
  single();ticks(10);
  if(page!=2||snapshot[2:0]!=0||audio.suffix_pending)$fatal(1,"Stop failed to cancel unanswered question");
  key1();if(triggers!=1||answers!=1||status[0])$fatal(1,"Stopped recognition accepted stale answer");
  $display("TEST_PASS feedback session boundary: real keys, question/servo completion, page speech, pending cancellation, scanout CDC and recognition reentry");
  $finish;
 end
 initial begin #2000000;$fatal(1,"Session timeout");end
endmodule
