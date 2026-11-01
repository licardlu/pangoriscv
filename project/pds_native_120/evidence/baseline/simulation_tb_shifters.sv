`timescale 1ns/1ps
module tb_shifters;
reg [31:0] src1,src2;
reg left,arith;
wire [31:0] actual[0:3];
reg [31:0] reversed,shifted,expected;
reg signed [32:0] extended;
integer seed=20261030, pattern,amplitude,control,k,j,vectors=0;
replica_early0_shifter dut0(.execute_ctrl2_down_BarrelShifterPlugin_LEFT_lane0(left),.execute_ctrl2_down_BarrelShifterPlugin_SIGNED_lane0(arith),.execute_ctrl2_down_early0_SrcPlugin_SRC1_lane0(src1),.execute_ctrl2_down_early0_SrcPlugin_SRC2_lane0(src2),.execute_ctrl2_down_early0_BarrelShifterPlugin_SHIFT_RESULT_lane0(actual[0]));
replica_late0_shifter dut1(.execute_ctrl4_down_BarrelShifterPlugin_LEFT_lane0(left),.execute_ctrl4_down_BarrelShifterPlugin_SIGNED_lane0(arith),.execute_ctrl4_down_late0_SrcPlugin_SRC1_lane0(src1),.execute_ctrl4_down_late0_SrcPlugin_SRC2_lane0(src2),.execute_ctrl4_down_late0_BarrelShifterPlugin_SHIFT_RESULT_lane0(actual[1]));
replica_early1_shifter dut2(.execute_ctrl2_down_BarrelShifterPlugin_LEFT_lane1(left),.execute_ctrl2_down_BarrelShifterPlugin_SIGNED_lane1(arith),.execute_ctrl2_down_early1_SrcPlugin_SRC1_lane1(src1),.execute_ctrl2_down_early1_SrcPlugin_SRC2_lane1(src2),.execute_ctrl2_down_early1_BarrelShifterPlugin_SHIFT_RESULT_lane1(actual[2]));
replica_late1_shifter dut3(.execute_ctrl4_down_BarrelShifterPlugin_LEFT_lane1(left),.execute_ctrl4_down_BarrelShifterPlugin_SIGNED_lane1(arith),.execute_ctrl4_down_late1_SrcPlugin_SRC1_lane1(src1),.execute_ctrl4_down_late1_SrcPlugin_SRC2_lane1(src2),.execute_ctrl4_down_late1_BarrelShifterPlugin_SHIFT_RESULT_lane1(actual[3]));
initial begin
 for(pattern=0;pattern<264;pattern=pattern+1) begin
  case(pattern)
   0:src1=0; 1:src1=32'hffffffff; 2:src1=32'h80000000; 3:src1=1;
   4:src1=32'h7fffffff; 5:src1=32'haaaaaaaa; 6:src1=32'h55555555; 7:src1=32'hdeadbeef;
   default:src1=$random(seed);
  endcase
  for(amplitude=0;amplitude<32;amplitude=amplitude+1)
   for(control=0;control<4;control=control+1) begin
    src2=32'hffffff00|amplitude; left=control[0]; arith=control[1];
    for(j=0;j<32;j=j+1) reversed[j]=src1[31-j];
    extended={arith&src1[31],left?reversed:src1};
    shifted=$signed(extended)>>>amplitude;
    for(j=0;j<32;j=j+1) expected[j]=left?shifted[31-j]:shifted[j];
    #1;
    for(k=0;k<4;k=k+1) if(actual[k]!==expected) $fatal(1,"shifter=%0d pattern=%0d amp=%0d ctrl=%0d",k,pattern,amplitude,control);
    vectors=vectors+1;
   end
 end
 $display("TEST_PASS reference_shifters modules=4 vectors=%0d all_amplitudes=32 all_controls=4",vectors);
 $finish;
end
endmodule
