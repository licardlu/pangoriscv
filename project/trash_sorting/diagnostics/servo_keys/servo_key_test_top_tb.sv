`timescale 1ns/1ps
module servo_key_test_top_tb;
    reg sys_clk=0;
    always #5 sys_clk=~sys_clk;
    reg [3:0] key_n=15;
    wire [3:0] servo_pwm;
    servo_key_test_top #(.CLK_HZ(50000),.POR_CYCLES(500),.DEBOUNCE_MS(2)) dut(.*);
    integer ch,frame,tick,k,highs[0:3],expected,physical_expected;
    initial begin
        repeat(499)begin
            @(negedge sys_clk);
            if(servo_pwm!==0)$fatal(1,"PWM enabled before POR completed");
        end
        repeat(2200)@(negedge sys_clk);
        if(dut.open_state!==0)$fatal(1,"Startup opened a lid");
        // User's physical observation: ALL lids closed=1500us/open=500us.
        // At 50kHz: every closed pulse must last 75 clocks.
        @(posedge servo_pwm[0]);
        for(k=0;k<4;k=k+1)highs[k]=0;
        repeat(1000)begin
            @(negedge sys_clk);
            for(k=0;k<4;k=k+1)if(servo_pwm[k])highs[k]=highs[k]+1;
        end
        for(k=0;k<4;k=k+1)
            if(highs[k]!=75)$fatal(1,"Wrong startup closed width channel%0d: %0d",k,highs[k]);
        for(ch=0;ch<4;ch=ch+1)begin
            // Hold beyond one complete movement: no repeat opening.
            key_n[ch]=0;
            wait(dut.open_state==(1<<ch));
            for(frame=0;frame<=350;frame=frame+1)begin
                @(posedge servo_pwm[0]);
                for(k=0;k<4;k=k+1)highs[k]=0;
                repeat(1000)begin
                    @(negedge sys_clk);
                    if((dut.open_state & ~(4'b0001<<ch))!=0)
                        $fatal(1,"Key %0d opened wrong channel %b",ch+1,dut.open_state);
                    for(k=0;k<4;k=k+1)if(servo_pwm[k])highs[k]=highs[k]+1;
                end
                if(frame<50)expected=25+frame;
                else if(frame<300)expected=75;
                else if(frame<350)expected=25+349-frame;
                else expected=25;
                for(k=0;k<4;k=k+1)begin
                    physical_expected=(k==ch?expected:25);
                    physical_expected=100-physical_expected;
                    if(highs[k]!=physical_expected)
                        $fatal(1,"Key %0d PWM%0d frame%0d: %0d expected %0d",ch+1,k,frame,highs[k],physical_expected);
                end
            end
            repeat(8000)begin
                @(negedge sys_clk);
                if(dut.open_state!=0)$fatal(1,"Held key retriggered");
            end
            key_n=15;repeat(8000)@(negedge sys_clk);
        end
        $display("TEST_PASS servo_key_test_top POR, key1 green/key2 red/key3 gray/key4 blue, ALL4 closed1500us open500us; all4 startup, 50 opening steps, 250 frames hold=5s, 50 closing steps, non-target closed, held-key guard");
        $finish;
    end
    initial begin #20000000;$fatal(1,"Diagnostic timeout");end
endmodule
