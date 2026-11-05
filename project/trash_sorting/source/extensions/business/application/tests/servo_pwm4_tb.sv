`timescale 1ns/1ps
module servo_pwm4_tb;
    reg clk=0,rst=1;
    always #5 clk=~clk;
    reg [3:0] trigger=0;
    wire [3:0] pwm,open_state,normal_pwm,normal_open_state;
    integer mask,ch,n,high_count[0:3],normal_high[0:3];
    time opened_at;
    servo_pwm4 #(.CLK_HZ(10000),.OPEN_FRAMES(250),.REVERSED_MASK(4'b0101)) dut(
        .clk(clk),.rst(rst),.trigger(trigger),.pwm(pwm),.open_state(open_state));
    // Default remains compatible with installations whose four lids rotate alike.
    servo_pwm4 #(.CLK_HZ(10000),.OPEN_FRAMES(250)) normal(
        .clk(clk),.rst(rst),.trigger(trigger),.pwm(normal_pwm),.open_state(normal_open_state));
    task measure_frame(input integer opened);
        begin
            for(ch=0;ch<4;ch=ch+1) begin high_count[ch]=0;normal_high[ch]=0;end
            repeat(200) begin
                @(negedge clk);
                if(open_state!==opened || normal_open_state!==opened)
                    $fatal(1,"Unexpected open state during PWM frame mask=%b",opened);
                for(ch=0;ch<4;ch=ch+1) begin
                    if(pwm[ch])high_count[ch]=high_count[ch]+1;
                    if(normal_pwm[ch])normal_high[ch]=normal_high[ch]+1;
                end
            end
            for(ch=0;ch<4;ch=ch+1) begin
                if(high_count[ch]!=(((opened>>ch)&1)^((4'b0101>>ch)&1)?15:5))
                    $fatal(1,"Reversed channel %0d mask=%b high=%0d",ch,opened,high_count[ch]);
                if(normal_high[ch]!=(((opened>>ch)&1)?15:5))
                    $fatal(1,"Default channel %0d mask=%b high=%0d",ch,opened,normal_high[ch]);
            end
        end
    endtask
    initial begin
        repeat(4)@(negedge clk);rst=0;
        repeat(400)@(negedge clk);
        measure_frame(0); // Green/gray closed=1.5ms; red/blue closed=0.5ms.
        for(mask=1;mask<16;mask=mask+1) begin
            trigger=mask;@(negedge clk);trigger=0;
            wait(open_state==mask);opened_at=$time;
            // Measure a complete frame, with every selected/unselected channel checked.
            measure_frame(mask);
            wait(open_state==0);
            if($time-opened_at!=500000)
                $fatal(1,"Mask %b did not remain open for exactly 250 frames / 5s: %0t",mask,$time-opened_at);
            repeat(400)@(negedge clk);
            measure_frame(0);
        end
        $display("TEST_PASS servo_pwm4 all16 combinations, normal and reversed widths, green/gray closed1.5ms, 50Hz, exact5s restore");
        $finish;
    end
    initial begin #10000000;$fatal(1,"servo bank timeout");end
endmodule
