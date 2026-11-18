`timescale 1ns/1ps
// Real PCM ROM, I2S transmitter and quiz: all 16 bin/key combinations.
module trash_voice_category_tb;
    reg clk=0; always #5 clk=~clk;
    reg rst=1,start_ready=1;
    reg [3:0] key_event=0,servo_open_state=0;
    reg detect_event=0,bin_valid=1;
    reg [2:0] bin_code=1;
    wire [3:0] servo_trigger;
    wire request_valid;
    wire [2:0] request_asset_id;
    wire [127:0] snapshot;
    wire [1:0] request_bin_index=snapshot[105:104];
    wire audio_busy,playback_done,i2s_bclk,i2s_lrclk,i2s_data;
    trash_quiz_controller quiz(.clk(clk),.rst(rst),.start_ready(start_ready),
        .key_event(key_event),.servo_open_state(servo_open_state),
        .detect_event(detect_event),.bin_valid(bin_valid),.bin_code(bin_code),
        .servo_trigger(servo_trigger),.voice_valid(request_valid),
        .voice_asset_id(request_asset_id),.snapshot(snapshot));
    // Hierarchical overrides retain the actual production wrapper and player.
    trash_voice_i2s #(.CLK_HZ(6144000),
        .ROM_FILE("../../tests/voice_category_test.hex")) dut(.*);
    defparam dut.player.ROM_SAMPLES=14;
    defparam dut.player.PROMPT_START=0,dut.player.PROMPT_LENGTH=2;
    defparam dut.player.CORRECT_START=2,dut.player.CORRECT_LENGTH=2;
    defparam dut.player.WRONG_START=4,dut.player.WRONG_LENGTH=2;
    defparam dut.player.KITCHEN_START=6,dut.player.KITCHEN_LENGTH=2;
    defparam dut.player.HAZARDOUS_START=8,dut.player.HAZARDOUS_LENGTH=2;
    defparam dut.player.OTHER_START=10,dut.player.OTHER_LENGTH=2;
    defparam dut.player.RECYCLABLE_START=12,dut.player.RECYCLABLE_LENGTH=2;
    reg [7:0] reference[0:13];
    initial $readmemh("../../tests/voice_category_test.hex",reference);
    integer expected[0:13];
    integer count=0,done_count=0,answer,choice,j,prefix;
    reg checking=0;
    always @(posedge clk) if(!rst && checking) begin
        if(dut.sample_ready && dut.sample_valid) begin
            if(count>=14 || dut.sample_pcm!=={reference[expected[count]],8'b0})
                $fatal(1,"Wrong PCM/category bin=%0d choice=%0d sample=%0d got=%h",answer,choice,count,dut.sample_pcm);
            count=count+1;
        end
        if(playback_done) begin
            if(count!=14) $fatal(1,"Answer completed before category: %0d samples",count);
            done_count=done_count+1;
        end
    end
    initial begin
        repeat(4)@(negedge clk);rst=0;repeat(4)@(negedge clk);
        for(answer=1;answer<=4;answer=answer+1) begin
            for(choice=1;choice<=4;choice=choice+1) begin
                bin_code=answer;detect_event=1;
                @(negedge clk);detect_event=0;repeat(8)@(negedge clk);
                // A later camera result must not alter the spoken category.
                bin_code=answer==4?1:4;detect_event=1;
                @(negedge clk);detect_event=0;
                prefix=answer==choice?2:4;
                for(j=0;j<6;j=j+1) expected[j]=prefix+j/3;
                for(j=6;j<14;j=j+1) expected[j]=6+(answer-1)*2+(j-6)/4;
                count=0;done_count=0;checking=1;
                key_event=1<<(choice-1);
                @(negedge clk);key_event=0;
                wait(done_count==1);@(negedge clk);
                repeat(3000)@(negedge clk);
                if(done_count!=1 || audio_busy) $fatal(1,"Duplicate/incomplete answer playback");
                checking=0;servo_open_state=1<<(answer-1);
                repeat(3)@(negedge clk);servo_open_state=0;
                repeat(3)@(negedge clk);
            end
        end
        // Reset while a suffix is pending must cancel the old category.
        bin_code=1;detect_event=1;@(negedge clk);detect_event=0;
        repeat(8)@(negedge clk);key_event=1;@(negedge clk);key_event=0;
        repeat(100)@(negedge clk);rst=1;repeat(4)@(negedge clk);rst=0;
        repeat(15000)@(negedge clk);
        if(audio_busy || playback_done) $fatal(1,"Reset retained a stale category");
        $display("TEST_PASS trash_voice_category: 16 answer/key pairs, actual ordered PCM and I2S completion, latched correct category, no duplicate, reset cancellation");
        $finish;
    end
    initial begin #100000000;$fatal(1,"category timeout");end
endmodule
