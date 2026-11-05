`timescale 1ns/1ps
module trash_peripherals_tb;
    reg clk=0,rst=1,start_ready=0;
    always #5 clk=~clk;
    reg [3:0] key_n=15;
    reg detect_event=0,bin_valid=0;
    reg [2:0] bin_code=0;
    wire [3:0] servo_pwm,open_state;
    wire voice_valid;
    wire [2:0] voice_asset_id;
    wire [127:0] snapshot;
    integer voice_count=0,last_asset=0,answer,choice,ch,baseline,target=-1;
    integer high_count[0:3],pulse_count[0:3];
    time opened_at;
    always @(open_state) if(open_state!=0)opened_at=$time;
    // Active configuration: camera answers 1 green,2 red,3 gray,4 blue.
    trash_peripherals #(.CLK_HZ(10000),.DEBOUNCE_MS(2),.OPEN_MS(5000),
        .TEST_MODE(0),.SERVO_REVERSED_MASK(4'b0000)) dut(.*);
    always @(negedge clk) if(voice_valid) begin
        voice_count=voice_count+1;last_asset=voice_asset_id;
    end
    // Check every complete pulse throughout debounce, opening, hold and close.
    integer monitor_channel;
    always @(negedge clk) begin
        if(rst) begin
            for(monitor_channel=0;monitor_channel<4;monitor_channel=monitor_channel+1)
                pulse_count[monitor_channel]=0;
        end else begin
            if(target<0 && open_state!==0)$fatal(1,"Idle opened a lid");
            if(target>=0 && (open_state & ~(4'b0001<<target))!=0)
                $fatal(1,"A non-target lid opened: target=%0d actual=%b",target,open_state);
            for(monitor_channel=0;monitor_channel<4;monitor_channel=monitor_channel+1) begin
                if(servo_pwm[monitor_channel])pulse_count[monitor_channel]=pulse_count[monitor_channel]+1;
                else if(pulse_count[monitor_channel]!=0) begin
                    if(pulse_count[monitor_channel]!=
                        ((open_state[monitor_channel]^((4'b0000>>monitor_channel)&1))?15:5))
                        $fatal(1,"Wrong pulse width channel=%0d open=%b cycles=%0d",
                            monitor_channel,open_state[monitor_channel],pulse_count[monitor_channel]);
                    pulse_count[monitor_channel]=0;
                end
            end
        end
    end
    task measure_frame(input integer expected_open);
        begin
            for(ch=0;ch<4;ch=ch+1)high_count[ch]=0;
            repeat(200)begin
                @(negedge clk);
                if(open_state!==expected_open)$fatal(1,"Lid state changed during frame");
                for(ch=0;ch<4;ch=ch+1)if(servo_pwm[ch])high_count[ch]=high_count[ch]+1;
            end
            for(ch=0;ch<4;ch=ch+1)
                if(high_count[ch]!=((((expected_open>>ch)&1)^((4'b0000>>ch)&1))?15:5))
                    $fatal(1,"Frame pulse channel=%0d count=%0d",ch,high_count[ch]);
        end
    endtask
    initial begin
        repeat(4)@(negedge clk);rst=0;
        repeat(20)@(negedge clk);
        if(voice_count!=0)$fatal(1,"prompt started before audio ready");
        start_ready=1;
        // Mode0 waits for a camera answer, even after audio startup.
        repeat(100400)begin
            @(negedge clk);
            if(open_state!==0 || voice_count!=0)$fatal(1,"Idle caused unsolicited motion/prompt");
        end
        measure_frame(0);
        key_n[0]=0;repeat(30)@(negedge clk);key_n[0]=1;
        repeat(30)@(negedge clk);
        if(open_state!=0 || voice_count!=0)$fatal(1,"Answered without camera detection");
        for(answer=1;answer<=4;answer=answer+1)begin
            for(choice=1;choice<=4;choice=choice+1)begin
                baseline=voice_count;target=answer-1;
                bin_code=answer;bin_valid=1;detect_event=1;
                @(negedge clk);detect_event=0;
                repeat(4)@(negedge clk);
                if(voice_count!=baseline+1 || last_asset!=1 || snapshot[105:104]!=(answer-1))
                    $fatal(1,"Camera answer did not start prompt: answer=%0d",answer);
                // A bounce must not answer the question.
                key_n[choice-1]=0;repeat(7)@(negedge clk);key_n[choice-1]=1;
                repeat(30)@(negedge clk);
                if(voice_count!=baseline+1 || open_state!=0)$fatal(1,"bounce accepted");
                key_n[choice-1]=0;repeat(30)@(negedge clk);
                if(voice_count!=baseline+2 || last_asset!=((answer==choice)?2:3))
                    $fatal(1,"Answer voice mismatch answer=%0d choice=%0d",answer,choice);
                if(snapshot[113:112]!=(choice-1) || !snapshot[119] || snapshot[2:0]!=2)
                    $fatal(1,"UI answer snapshot missing");
                wait(open_state==(1<<(answer-1)));
                // New camera results while answered must not redirect the lid.
                @(negedge clk);bin_code=(answer==4)?1:4;detect_event=1;
                @(negedge clk);detect_event=0;
                if(snapshot[105:104]!=(answer-1))$fatal(1,"Camera changed latched answer");
                measure_frame(1<<(answer-1));
                wait(open_state==0);
                if($time-opened_at!=500000)$fatal(1,"Lid did not hold for exactly five seconds");
                repeat(400)@(negedge clk);
                if(voice_count!=baseline+2 || snapshot[2:0]!=0)
                    $fatal(1,"Mode0 must wait for next detection after closing");
                measure_frame(0);
                key_n[choice-1]=1;repeat(30)@(negedge clk);target=-1;
            end
        end
        $display("TEST_PASS trash_peripherals camera mode0 all16 answer/key pairs, green/red/gray/blue, closed0.5ms/open1.5ms, 50Hz, exact5s close, locked answer, no stale re-prompt, debounce/hold/UI/audio events");
        $finish;
    end
    initial begin #12000000;$fatal(1,"peripherals timeout");end
endmodule
