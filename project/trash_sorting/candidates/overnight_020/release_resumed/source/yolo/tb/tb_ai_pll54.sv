`timescale 1ns/1ps
// Actual vendor PLL behavioral model: check the new output and preserve the
// three pre-existing frequencies. This is simulation, not a clock measurement.
module tb_ai_pll54;
    reg clkin1=0;
    wire clkout0,clkout1,clkout2,clkout3,lock;
    pll dut(.*);
    always #(500.0/27.0) clkin1=~clkin1;
    task check_period(input integer which,input real expected);
        real started,elapsed;
        integer i;
        begin
            case(which)
                0: @(posedge clkout0);
                1: @(posedge clkout1);
                2: @(posedge clkout2);
                3: @(posedge clkout3);
            endcase
            started=$realtime;
            for(i=0;i<100;i=i+1) begin
                case(which)
                    0: @(posedge clkout0);
                    1: @(posedge clkout1);
                    2: @(posedge clkout2);
                    3: @(posedge clkout3);
                endcase
            end
            elapsed=($realtime-started)/100.0;
            if(elapsed<expected-0.003 || elapsed>expected+0.003)
                $fatal(1,"PLL output%0d period=%f expected=%f",which,elapsed,expected);
            $display("PLL_PERIOD output%0d %f ns",which,elapsed);
        end
    endtask
    real started,high_ns;
    initial begin
        wait(lock===1'b1);
        repeat(20) @(posedge clkout3);
        check_period(0,1000.0/74.25);
        check_period(1,1000.0*119.0/1188.0);
        check_period(2,1000.0/24.75);
        check_period(3,1000.0/54.0);
        @(posedge clkout3);started=$realtime;
        @(negedge clkout3);high_ns=$realtime-started;
        if(high_ns<9.256 || high_ns>9.263)
            $fatal(1,"54MHz high width=%f ns",high_ns);
        $display("TEST_PASS ai_pll54 vendor model all4 frequencies and 50pct AI duty");
        $finish;
    end
    initial begin #1000000;$fatal(1,"PLL lock/clock timeout");end
endmodule
