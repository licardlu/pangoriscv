// Source-extraction compilation-unit preamble (not reference payload).
`timescale 1ns/1ps

module BufferCC (
  input  wire          io_dataIn,
  output wire          io_dataOut,
  input  wire          socCtrl_systemClk,
  input  wire          socCtrl_system_reset
);

  (* async_reg = "true" , altera_attribute = "-name ADV_NETLIST_OPT_ALLOWED NEVER_ALLOW" *) reg                 buffers_0;
  (* async_reg = "true" *) reg                 buffers_1;

  assign io_dataOut = buffers_1;
  always @(posedge socCtrl_systemClk or posedge socCtrl_system_reset) begin
    if(socCtrl_system_reset) begin
      buffers_0 <= 1'b0;
      buffers_1 <= 1'b0;
    end else begin
      buffers_0 <= io_dataIn;
      buffers_1 <= buffers_0;
    end
  end


endmodule
