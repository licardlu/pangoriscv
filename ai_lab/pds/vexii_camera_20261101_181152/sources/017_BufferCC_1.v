// Source-extraction compilation-unit preamble (not reference payload).
`timescale 1ns/1ps

module BufferCC_1 (
  input  wire [0:0]    io_dataIn,
  output wire [0:0]    io_dataOut,
  input  wire          socCtrl_systemClk,
  input  wire          socCtrl_system_reset
);

  (* async_reg = "true" *) reg        [0:0]    buffers_0;
  (* async_reg = "true" *) reg        [0:0]    buffers_1;

  assign io_dataOut = buffers_1;
  always @(posedge socCtrl_systemClk) begin
    buffers_0 <= io_dataIn;
    buffers_1 <= buffers_0;
  end


endmodule
