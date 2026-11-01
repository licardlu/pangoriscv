// Parallel-direction implementation derived from the reference equations.
// Original provenance and copyright notices remain in ../manifest.json and THIRD_PARTY_NOTICES.md.
// Provenance and equation source lines: ../manifest.json
`timescale 1ns/1ps
module replica_late1_shifter(
  input wire execute_ctrl4_down_BarrelShifterPlugin_LEFT_lane1,
  input wire execute_ctrl4_down_BarrelShifterPlugin_SIGNED_lane1,
  input wire [31:0] execute_ctrl4_down_late1_SrcPlugin_SRC1_lane1,
  input wire [31:0] execute_ctrl4_down_late1_SrcPlugin_SRC2_lane1,
  output wire [31:0] execute_ctrl4_down_late1_BarrelShifterPlugin_SHIFT_RESULT_lane1
);
  wire [4:0] amount = execute_ctrl4_down_late1_SrcPlugin_SRC2_lane1[4:0];
  wire fill = execute_ctrl4_down_BarrelShifterPlugin_SIGNED_lane1 &&
              execute_ctrl4_down_late1_SrcPlugin_SRC1_lane1[31];
  wire signed [32:0] right_extended = {fill, execute_ctrl4_down_late1_SrcPlugin_SRC1_lane1};
  wire [32:0] right_shifted = right_extended >>> amount;
  // The low half supplies the original fill semantics even when LEFT and SIGNED
  // are both asserted; all 32 possible amounts preserve the reference result.
  wire [63:0] left_extended = {execute_ctrl4_down_late1_SrcPlugin_SRC1_lane1, {32{fill}}};
  wire [63:0] left_shifted = left_extended << amount;
  assign execute_ctrl4_down_late1_BarrelShifterPlugin_SHIFT_RESULT_lane1 =
      execute_ctrl4_down_BarrelShifterPlugin_LEFT_lane1 ? left_shifted[63:32] : right_shifted[31:0];
endmodule
