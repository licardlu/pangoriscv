`timescale 1ns/1ps
module trash_quiz_controller_tb;
    reg clk=0,rst=1,start_ready=1;always #5 clk=~clk;
    reg [3:0] key_event=0;
    reg [3:0] servo_open_state=0;
    reg detect_event=0,bin_valid=0;
    reg [2:0] bin_code=0;
    wire [3:0] servo_trigger;
    wire voice_valid;
    wire [2:0] voice_asset_id;
    wire [127:0] snapshot;
    integer answer,choice;
    trash_quiz_controller #(.TEST_MODE(0)) dut(.*);
    initial begin
        repeat(3)@(negedge clk);rst=0;
        key_event=1;@(negedge clk);key_event=0;
        if(servo_trigger!=0) $fatal(1,"camera mode accepted answer before detection");
        bin_code=0;detect_event=1;bin_valid=1;
        @(negedge clk);detect_event=0;
        if(snapshot[2:0]!=0 || voice_valid || servo_trigger)
            $fatal(1,"invalid camera bin started a session");
        for(answer=1;answer<=4;answer=answer+1) begin
            for(choice=1;choice<=4;choice=choice+1) begin
                bin_code=answer;detect_event=1;bin_valid=1;
                @(negedge clk);detect_event=0;
                if(voice_valid!=1 || voice_asset_id!=1 || snapshot[2:0]!=1)
                    $fatal(1,"recognition did not latch and prompt");
                // Later inference must not change the latched correct answer,
                // replay the prompt, or open any lid without a key.
                bin_code=(answer==4)?1:4; detect_event=1;
                @(negedge clk);detect_event=0;
                repeat(12) begin
                    @(negedge clk);
                    if(snapshot[2:0]!=1 || snapshot[105:104]!=(answer-1) ||
                       voice_valid || servo_trigger)
                        $fatal(1,"waiting for answer changed session or opened a lid");
                end
                key_event=1<<(choice-1);
                @(negedge clk);key_event=0;
                if(servo_trigger!=(1<<(answer-1))) $fatal(1,"must open correct lid even on wrong answer");
                if(voice_asset_id!=((answer==choice)?2:3) || !voice_valid)
                    $fatal(1,"correct/wrong audio request failed");
                if(snapshot[105:104]!=(answer-1) || snapshot[113:112]!=(choice-1) || !snapshot[119])
                    $fatal(1,"UI latched answer failed");
                // Answered session ignores repeated answers.
                servo_open_state=1<<(answer-1);
                key_event=15;detect_event=1;
                @(negedge clk);key_event=0;detect_event=0;
                if(servo_trigger!=0 || voice_valid!=0) $fatal(1,"duplicate answer accepted");
                if(snapshot[105:104]!=(answer-1)) $fatal(1,"camera replaced answered session");
                repeat(5)@(negedge clk);
                servo_open_state=0;
                repeat(8)@(negedge clk);
                if(snapshot[2:0]!=0 || voice_valid || servo_trigger)
                    $fatal(1,"normal session did not return to idle after closing");
            end
        end
        $display("TEST_PASS trash_quiz_controller normal mode: 16 right/wrong combinations, latched camera answer, no key no opening, single correct lid, prompt, close then idle");
        $finish;
    end
    initial begin #20000;$fatal(1,"quiz timeout");end
endmodule
