`timescale 1ns/1ps
module gate_tb;
 reg sys_clk=0; always #18.5185 sys_clk=~sys_clk;
 reg [3:0] key_n=15; wire [3:0] servo_pwm;
 servo_key_test_top dut(.*);
 realtime rise_at, width, last_rise;
 integer pulses=0;
 initial begin #45000000;key_n=14; #30000000;key_n=15; #60000000;
 if(pulses<5)$fatal(1,"No PWM generated");
 $display("TEST_PASS gate startup and key activity");$finish;end
 always @(posedge servo_pwm[0]) begin
 rise_at=$realtime;
 if(pulses>0 && ($realtime-last_rise<19999000 || $realtime-last_rise>20001000))$fatal(1,"Bad PWM period");
 last_rise=$realtime;
 end
 always @(negedge servo_pwm[0]) if($realtime>10000000)begin
 width=$realtime-rise_at;pulses=pulses+1;
 $display("PULSE t=%0t width_ns=%0f reset=%b por=%0d",$time,width,dut.reset_release,dut.por_count);
 if(pulses==1 && (width<1499900 || width>1500100))$fatal(1,"Bad initial pulse");
 if(pulses==6 && width>=1500000)$fatal(1,"Key did not move servo");
 end
endmodule
