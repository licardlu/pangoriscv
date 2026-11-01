// Source-extraction compilation-unit preamble (not reference payload).
`timescale 1ns/1ps

module StreamArbiter_1 (
  input  wire          io_inputs_0_valid,
  output wire          io_inputs_0_ready,
  output wire          io_output_valid,
  input  wire          io_output_ready,
  output wire [0:0]    io_chosenOH
);

  wire                maskProposal_0;

  assign maskProposal_0 = io_inputs_0_valid;
  assign io_output_valid = io_inputs_0_valid;
  assign io_inputs_0_ready = io_output_ready;
  assign io_chosenOH = 1'b1;

endmodule
