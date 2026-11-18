// Source-extraction compilation-unit preamble (not reference payload).
`timescale 1ns/1ps

module BufferCC_3 (
  input  wire          io_dataIn,
  output wire          io_dataOut,
  input  wire          socCtrl_systemClk,
  input  wire          socCtrl_debug_fiber_holder_reset
);

  (* async_reg = "true" *) reg                 buffers_0;
  (* async_reg = "true" *) reg                 buffers_1;

  assign io_dataOut = buffers_1;
  always @(posedge socCtrl_systemClk or posedge socCtrl_debug_fiber_holder_reset) begin
    if(socCtrl_debug_fiber_holder_reset) begin
      buffers_0 <= 1'b1;
      buffers_1 <= 1'b1;
    end else begin
      buffers_0 <= io_dataIn;
      buffers_1 <= buffers_0;
    end
  end


endmodule
