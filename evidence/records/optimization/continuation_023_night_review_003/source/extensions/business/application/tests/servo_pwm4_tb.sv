`timescale 1ns/1ps
module servo_pwm4_tb;
    reg clk=0,rst=1;
    always #5 clk=~clk;
    reg [3:0] trigger=0;
    wire [3:0] pwm,open_state,reverse_pwm,reverse_open;
    integer mask,ch,frame,cycle,position,expected,high_count[0:3],reverse_high[0:3];
    servo_pwm4 #(.CLK_HZ(50000)) dut(.*);
    servo_pwm4 #(.CLK_HZ(50000),.REVERSED_MASK(4'b0101)) reversed(
        .clk(clk),.rst(rst),.trigger(trigger),.pwm(reverse_pwm),.open_state(reverse_open));
    // Measure every output over a FULL 20ms frame, independently of RTL state.
    // At 50kHz: 500us=25 clocks, each 20us step=1 clock, 1500us=75.
    task check_frame(input integer active, input integer step);
        begin
            @(posedge pwm[0]);
            for(ch=0;ch<4;ch=ch+1)begin high_count[ch]=0;reverse_high[ch]=0;end
            for(cycle=0;cycle<1000;cycle=cycle+1)begin
                @(negedge clk);
                // The state may advance at the final clock of this frame.
                if(cycle<999 && (open_state!==active || reverse_open!==active))
                    $fatal(1,"Wrong busy feedback mask=%b frame=%0d got=%b",active,frame,open_state);
                for(ch=0;ch<4;ch=ch+1)begin
                    if(pwm[ch])high_count[ch]=high_count[ch]+1;
                    if(reverse_pwm[ch])reverse_high[ch]=reverse_high[ch]+1;
                end
            end
            for(ch=0;ch<4;ch=ch+1)begin
                expected=25+(((mask>>ch)&1)?step:0);
                if(high_count[ch]!=expected)
                    $fatal(1,"PWM mask=%b ch=%0d frame=%0d expected=%0d got=%0d",mask,ch,frame,expected,high_count[ch]);
                if(reverse_high[ch]!=(((4'b0101>>ch)&1)?100-expected:expected))
                    $fatal(1,"Optional polarity failed ch=%0d",ch);
            end
        end
    endtask
    initial begin
        repeat(4)@(negedge clk);rst=0;
        mask=0;check_frame(0,0);check_frame(0,0);
        for(mask=1;mask<16;mask=mask+1)begin
            // A one-clock request outside the PWM boundary must not be lost.
            repeat(31)@(negedge clk);trigger=mask;
            @(negedge clk);trigger=0;
            wait(open_state==mask);
            for(frame=0;frame<=350;frame=frame+1)begin
                if(frame<50)position=frame;
                else if(frame<300)position=50;
                else if(frame<350)position=349-frame;
                else position=0;
                check_frame(frame<350?mask:0,position);
                // Busy edges must not restart/extend/queue the movement.
                if(frame==60 || frame==120)trigger=mask;
                if(frame==61)trigger=0;
            end
            repeat(8)check_frame(0,0); // held high must not retrigger
            trigger=0;
            repeat(6)check_frame(0,0); // rearm after 100ms low
        end
        // Independent requests on different channels can overlap in time.
        mask=15;
        trigger=1;@(negedge clk);trigger=0;
        wait(open_state==1);
        repeat(23000)@(negedge clk);
        @(negedge clk);trigger=8;@(negedge clk);trigger=0;
        wait(open_state==9);
        wait(open_state==8);
        wait(open_state==0);
        // A new quiz answer immediately after closing is a valid request.
        // Buffer it through the 100ms rearm interval instead of losing it.
        @(negedge clk);trigger=8;@(negedge clk);trigger=0;
        repeat(4000)begin
            @(negedge clk);
            if(open_state!=0)$fatal(1,"Reopened before the 100ms rearm interval");
        end
        wait(open_state==8);
        wait(open_state==0);
        // Reset during opening/hold/closing cancels movement and starts closed.
        for(frame=0;frame<3;frame=frame+1)begin
            repeat(6000)@(negedge clk);trigger=15;
            @(negedge clk);trigger=0;wait(open_state==15);
            repeat((frame==0?10:frame==1?100:320)*1000)@(negedge clk);
            rst=1;repeat(3)@(negedge clk);
            if(pwm!==0 || open_state!==0)$fatal(1,"Reset did not clear motion");
            rst=0;mask=0;check_frame(0,0);mask=15;
        end
        $display("TEST_PASS servo_pwm4 all16 masks: full PWM frames, 50x20us open/close steps, 250 endpoint frames=5s, busy/held-high guards, rearm, independent channels, reset in all phases");
        $finish;
    end
    initial begin #100000000;$fatal(1,"servo bank timeout");end
endmodule
