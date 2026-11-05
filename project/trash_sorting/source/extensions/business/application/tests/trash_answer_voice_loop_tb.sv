`timescale 1ns/1ps
// Real controller + debounce + servo PWM + real WAV ROM + physical I2S.
// Only OPEN_MS is accelerated: one 20ms servo frame instead of five seconds.
// The separate trash_peripherals_tb covers the actual 5s configuration.
module trash_answer_voice_loop_tb;
    localparam integer CLK_HZ=27000000;
    reg clk=0; always #(1000000000.0/(2.0*CLK_HZ)) clk=~clk;
    reg rst=1,start_ready=0;
    reg [3:0] key_n=15;
    wire [3:0] servo_pwm,open_state;
    wire voice_valid;
    wire [2:0] voice_asset_id;
    wire [127:0] snapshot;
    wire audio_busy,playback_done,i2s_bclk,i2s_lrclk,i2s_data;
    trash_peripherals #(.CLK_HZ(CLK_HZ),.DEBOUNCE_MS(1),.OPEN_MS(20),.TEST_MODE(1)) peripherals(
        .clk(clk),.rst(rst),.start_ready(start_ready),.key_n(key_n),
        .detect_event(1'b0),.bin_valid(1'b0),.bin_code(3'b0),
        .servo_pwm(servo_pwm),.open_state(open_state),.voice_valid(voice_valid),
        .voice_asset_id(voice_asset_id),.snapshot(snapshot));
    trash_voice_i2s #(.CLK_HZ(CLK_HZ),.ROM_FILE("../../assets/audio_rom/voice_pcm8.hex")) audio(
        .clk(clk),.rst(rst),.request_valid(voice_valid),.request_asset_id(voice_asset_id),
        .audio_busy(audio_busy),.playback_done(playback_done),
        .i2s_bclk(i2s_bclk),.i2s_lrclk(i2s_lrclk),.i2s_data(i2s_data));

    reg [7:0] reference [0:115575];
    initial $readmemh("../../assets/audio_rom/voice_pcm8.hex",reference);
    integer requests=0,frame_samples=0,serial_channels=0,base=0;
    integer expected_assets[0:4];
    integer close_count=0,open_count=0;
    reg [3:0] old_open=0;
    reg [15:0] expected_frame=0;
    reg frame_valid=0;
    realtime opened_at=0, sample_window_start=0;
    integer sample_window_count=0, audio_windows_checked=0;
    // Check elapsed time with the real board input clock. Clock rounding at
    // 1ps precision contributes <1us over the accelerated 20ms open interval.
    // Track actual servo feedback rather than an independent quiz timer.
    always @(negedge clk) if(!rst) begin
        if(open_state != 0 && open_state != 1)
            $fatal(1,"Fixed answer must open correct BLUE only: %b",open_state);
        if(old_open==0 && open_state!=0) begin
            open_count=open_count+1;
            opened_at=$realtime;
        end
        if(old_open!=0 && open_state==0) begin
            close_count=close_count+1;
            if(($realtime-opened_at)<19999000 || ($realtime-opened_at)>20001000)
                $fatal(1,"27MHz servo opening did not last 20ms: %0fns",$realtime-opened_at);
        end
        old_open=open_state;
    end

    // 128 accepted stereo frames must take 128/48000 seconds. This measures
    // actual NCO output timing as well as the separate serial data decoder.
    always @(negedge clk) if(!rst && audio.sample_ready) begin
        if(sample_window_count==0) sample_window_start=$realtime;
        if(sample_window_count==128) begin
            if(($realtime-sample_window_start)<2665666 || ($realtime-sample_window_start)>2667667)
                $fatal(1,"27MHz audio output is not 48kHz: 128 frames in %0fns",$realtime-sample_window_start);
            audio_windows_checked=audio_windows_checked+1;
            sample_window_count=0;sample_window_start=$realtime;
        end
        sample_window_count=sample_window_count+1;
    end

    // The request is observed on the same edge on which the real player accepts it.
    always @(posedge clk) if(!rst) begin
        if(voice_valid) begin
            if(!start_ready) $fatal(1,"Audio requested before start_ready");
            if(requests>=5 || voice_asset_id!==expected_assets[requests])
                $fatal(1,"Request order %0d: asset %0d",requests,voice_asset_id);
            if(requests!=0 && (frame_samples<8 || serial_channels<8 || !audio_busy))
                $fatal(1,"Previous request did not reach actual ROM/I2S: samples=%0d channels=%0d busy=%b",frame_samples,serial_channels,audio_busy);
            if((requests==2 && close_count!=1) || (requests==4 && close_count!=2))
                $fatal(1,"New prompt issued before actual servo close");
            case(voice_asset_id)
                1: base=0;
                2: base=37192;
                3: base=77584;
                default: $fatal(1,"Invalid asset");
            endcase
            requests=requests+1;
            frame_samples=0;serial_channels=0;
        end
        if(audio.sample_ready) begin
            frame_valid=audio.sample_valid;
            expected_frame=audio.sample_valid ? audio.sample_pcm : 16'b0;
            if(audio.sample_valid) begin
                if(audio.sample_pcm !== {reference[base+frame_samples/3],8'b0})
                    $fatal(1,"Connected player sample mismatch request=%0d sample=%0d",requests,frame_samples);
                frame_samples=frame_samples+1;
            end
        end
        if(playback_done) $fatal(1,"Shortened test unexpectedly finished an entire real clip");
    end

    // Decode the actual I2S output for every transmitted channel, including
    // retained old-frame tails on a new request. Initial speech samples are
    // silence in the source WAV and are still valid PCM transfers.
    reg old_lrclk=1,decoding=0;
    integer channel_bit=0;
    reg [15:0] received=0;
    always @(posedge i2s_bclk) begin
        if(rst) begin old_lrclk=1;channel_bit=0;decoding=0; end
        else begin
            if(i2s_lrclk!=old_lrclk) begin
                old_lrclk=i2s_lrclk;channel_bit=0;
                if(!i2s_lrclk) decoding=frame_valid;
                if(i2s_data!==0) $fatal(1,"Bad I2S dummy bit");
            end else channel_bit=channel_bit+1;
            if(decoding && channel_bit>=1 && channel_bit<=16) begin
                received={received[14:0],i2s_data};
                if(channel_bit==16) begin
                    if(received!==expected_frame) $fatal(1,"Actual I2S data differs from accepted PCM");
                    serial_channels=serial_channels+1;
                end
            end
            if(channel_bit>=17 && channel_bit<=31 && i2s_data!==0)
                $fatal(1,"Bad I2S channel padding");
        end
    end

    initial begin
        expected_assets[0]=1;expected_assets[1]=2;expected_assets[2]=1;
        expected_assets[3]=3;expected_assets[4]=1;
        repeat(5) @(negedge clk);rst=0;
        repeat(10000) @(negedge clk);
        if(requests!=0 || audio_busy!=0) $fatal(1,"Readiness gate failed");
        start_ready=1;
        wait(requests==1);
        repeat(150000) @(negedge clk); // real prompt receives >100 frames
        if(!audio_busy || frame_samples<100) $fatal(1,"Startup prompt did not play");
        key_n[0]=0;
        wait(requests==2); // button 1 -> correct
        key_n=0; // press all remaining buttons during answered state
        wait(open_count==1);
        wait(requests==3);
        repeat(150000) @(negedge clk);
        if(requests!=3 || open_state!=0) $fatal(1,"Held keys repeated answer or restarted servo");
        key_n=15;
        repeat(100100) @(negedge clk); // release debounce
        key_n[1]=0;
        wait(requests==4); // button 2 -> wrong; opens correct BLUE servo
        key_n=0;
        wait(open_count==2);
        wait(requests==5);
        repeat(150000) @(negedge clk);
        if(requests!=5 || close_count!=2 || open_state!=0 || !audio_busy || frame_samples<100 || audio_windows_checked<4)
            $fatal(1,"Wrong-answer close/re-prompt/held-key loop failed");
        $display("TEST_PASS trash_answer_voice_loop real 27MHz + real audio ROM + I2S decode: prompt/correct+blue/wrong+blue/closed prompts; readiness and held-key guard; OPEN_MS=20 only");
        $finish;
    end
    initial begin #200000000;$fatal(1,"Answer/voice loop timeout");end
endmodule
