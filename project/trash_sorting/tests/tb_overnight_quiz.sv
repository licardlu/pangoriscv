`timescale 1ns/1ps
module tb_overnight_quiz;
 reg clk=0,rst=1,start_ready=1,cancel_wait=0;
 reg [3:0] key_event=0,servo_open_state=0;
 reg detect_event=0,bin_valid=1;
 reg [2:0] bin_code=1;
 wire [3:0] servo_trigger,voice_asset_id;
 wire voice_valid;
 wire [127:0] snapshot;
 always #5 clk=~clk;
 trash_quiz_controller dut(.*);
 task ticks(input integer n);repeat(n)@(negedge clk);endtask
 task detect(input [2:0] bin);
  bin_code=bin;detect_event=1;ticks(1);detect_event=0;
  if(!voice_valid||voice_asset_id!=1||snapshot[2:0]!=1)$fatal(1,"Question not armed");
  ticks(2);
 endtask
 task answer(input [3:0] key,input integer expected_asset,expected_servo);
  key_event=key;ticks(1);key_event=0;
  if(!voice_valid||voice_asset_id!=expected_asset||servo_trigger!=expected_servo||snapshot[2:0]!=2)
   $fatal(1,"Answer feedback asset%0d expected%0d trigger%h expected%h",voice_asset_id,expected_asset,servo_trigger,expected_servo);
  ticks(2);servo_open_state=expected_servo;ticks(3);servo_open_state=0;ticks(3);
  if(snapshot[2:0]!=0)$fatal(1,"Question did not wait for actual servo feedback");
 endtask
 initial begin
  ticks(4);rst=0;ticks(5);
  detect(1);answer(1,2,1);
  detect(2);answer(2,8,2);
  detect(3);answer(4,9,4);
  if(snapshot[122:120]!=3)$fatal(1,"Real three-answer streak missing");
  detect(4);answer(8,10,8);
  detect(1);answer(1,11,1);
  detect(2);answer(1,3,2);
  if(snapshot[122:120]!=0)$fatal(1,"Wrong answer did not reset streak");
  detect(3);answer(1,12,4);
  detect(4);answer(1,13,8);
  detect(1);answer(1,2,1);
  // Cancel before answering; no old answer can survive into a new session.
  detect(4);cancel_wait=1;key_event=8;ticks(1);key_event=0;
  if(servo_trigger||voice_valid||snapshot[2:0]!=0)$fatal(1,"Canceled question answered");
  detect_event=1;ticks(3);detect_event=0;
  if(snapshot[2:0]!=0)$fatal(1,"Detected while recognition stopped");
  cancel_wait=0;ticks(2);detect(2);answer(2,2,2);
  // Navigation while a lid is moving cannot terminate the servo lifecycle.
  detect(1);key_event=1;ticks(1);key_event=0;servo_open_state=1;cancel_wait=1;ticks(4);
  if(snapshot[2:0]!=2)$fatal(1,"Navigation canceled active mechanics");
  servo_open_state=0;ticks(3);
  if(snapshot[2:0]!=0)$fatal(1,"Mechanics completion lost during navigation");
  $display("TEST_PASS overnight quiz: six new feedbacks, real streaks, wrong resets, four-bin mapping, cancel, mechanics completion");$finish;
 end
 initial begin #100000;$fatal(1,"Quiz timeout");end
endmodule
