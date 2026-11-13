`timescale 1ns/1ps
module trash_voice_i2s_tb;
    reg clk = 0; always #10 clk = ~clk; // exact 50 MHz source
    reg rst = 1, request_valid = 0;
    reg [2:0] request_asset_id = 0;
    wire ready, valid, last, busy, bclk, lrclk, sdout, frame_active, done;
    wire [15:0] pcm;
    trash_voice_rom_player #(
        .ROM_FILE("../../tests/voice_test_pcm8.hex"), .ROM_SAMPLES(6),
        .PROMPT_START(0), .PROMPT_LENGTH(2), .CORRECT_START(2), .CORRECT_LENGTH(2),
        .WRONG_START(4), .WRONG_LENGTH(2)
    ) player (.clk(clk),.rst(rst),.request_valid(request_valid),
        .request_asset_id(request_asset_id),.sample_ready(ready),
        .sample_valid(valid),.sample_pcm(pcm),.sample_last(last),.busy(busy));
    trash_i2s_tx tx(.clk(clk),.rst(rst),.sample_valid(valid),.sample_pcm(pcm),
        .sample_last(last),.sample_ready(ready),.bclk(bclk),.lrclk(lrclk),
        .sdout(sdout),.frame_active(frame_active),.playback_done(done));

    reg [15:0] expected [0:5];
    integer accepted = 0, checked_channels = 0, done_count = 0;
    integer asset, i;
    reg checking = 0;
    // Check the streaming interface as well as the physical serial outputs.
    always @(posedge clk) if(!rst && valid && ready && checking) begin
        if(accepted >= 6 || pcm !== expected[accepted] || last !== (accepted == 5))
            $fatal(1,"PCM transfer %0d incorrect: data=%h last=%b", accepted,pcm,last);
        accepted = accepted + 1;
    end
    always @(posedge clk) if(!rst && done) begin
        done_count = done_count + 1;
        if(accepted != 6 || checked_channels != 12)
            $fatal(1,"Done before final stereo frame: accepted=%0d channels=%0d",accepted,checked_channels);
    end

    // Independent I2S receiver: WS transition, one dummy bit, then 16 MSB-first
    // data bits followed by zero padding to a 32-bit channel slot.
    reg old_lrclk = 1, decoding = 0;
    integer channel_bit = 0;
    reg [15:0] received;
    always @(posedge bclk) begin
        if(rst) begin old_lrclk = 1; channel_bit = 0; decoding = 0; end
        else begin
            if(lrclk != old_lrclk) begin
                old_lrclk = lrclk; channel_bit = 0;
                if(lrclk == 0) decoding = frame_active && checking;
                if(sdout !== 0) $fatal(1,"I2S dummy bit must be zero");
            end else channel_bit = channel_bit + 1;
            if(decoding && channel_bit >= 1 && channel_bit <= 16) begin
                received = {received[14:0],sdout};
                if(channel_bit == 16) begin
                    if(received !== expected[checked_channels/2])
                        $fatal(1,"I2S channel %0d incorrect: %h expected %h",checked_channels,received,expected[checked_channels/2]);
                    checked_channels = checked_channels + 1;
                end
            end
            if(channel_bit >= 17 && channel_bit <= 31 && sdout !== 0)
                $fatal(1,"I2S padding not zero");
        end
    end

    // Validate fractional division over 50,000 sys_clk cycles (1 ms).
    integer rising_count = 0;
    always @(posedge bclk) if(!rst) rising_count = rising_count + 1;
    initial begin
        repeat(3) @(negedge clk); rst = 0;
        repeat(50000) @(negedge clk);
        if(rising_count < 3071 || rising_count > 3073)
            $fatal(1,"BCLK rate incorrect: %0d edges/ms",rising_count);
        for(asset=1;asset<=3;asset=asset+1) begin
            for(i=0;i<6;i=i+1) begin
                case(asset)
                    1: expected[i] = i<3 ? 16'h0100 : 16'h7f00;
                    2: expected[i] = i<3 ? 16'h8000 : 16'h1200;
                    3: expected[i] = i<3 ? 16'hfa00 : 16'h4500;
                endcase
            end
            accepted = 0; checked_channels = 0; done_count = 0; checking = 1;
            @(negedge clk); request_valid = 1; request_asset_id = asset;
            @(negedge clk); request_valid = 0;
            wait(done_count == 1);
            @(negedge clk);
            if(busy !== 0 || frame_active !== 0) $fatal(1,"Playback did not retire");
            checking = 0;
            repeat(2200) @(negedge clk);
            if(done_count != 1) $fatal(1,"Duplicate done pulse");
        end
        @(negedge clk); request_valid = 1; request_asset_id = 7;
        @(negedge clk); request_valid = 0;
        repeat(10) @(negedge clk);
        if(busy !== 0 || valid !== 0) $fatal(1,"Invalid request was not ignored");
        $display("PASS: 50MHz fractional I2S rate, 3 ROM clips, signed PCM, x3 repeat, stereo bits, padding and completion");
        $finish;
    end
    initial begin #5000000; $fatal(1,"Timeout"); end
endmodule
