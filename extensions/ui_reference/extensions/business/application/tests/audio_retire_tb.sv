`timescale 1ns/1ps
module audio_retire_tb;
reg clk=0;always #5 clk=~clk;reg rst=1,en=0,valid=1;wire ready,b,l,s,started;wire[31:0]under,completed;
i2s_tx dut(clk,rst,en,valid,32'h11223344,ready,b,l,s,started,under,completed);
initial begin
 repeat(4)@(negedge clk);rst=0;en=1;
 wait(ready);@(negedge clk);repeat(3)@(negedge clk);
 if(completed!=0)$fatal(1,"FIFO pop is not completion");
 valid=0;repeat(260)@(negedge clk);
 if(completed!=1)$fatal(1,"full frame must complete once %d",completed);
 repeat(600)@(negedge clk);if(completed!=1)$fatal(1,"silence counted as PCM");
 $display("TEST_PASS audio_retire");$finish;
end
initial begin #100000;$fatal(1,"timeout");end
endmodule
