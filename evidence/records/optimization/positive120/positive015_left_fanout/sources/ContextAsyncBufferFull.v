// Source-extraction compilation-unit preamble (not reference payload).
`timescale 1ns/1ps

module ContextAsyncBufferFull (
  input  wire          io_add_valid,
  output wire          io_add_ready,
  input  wire [0:0]    io_add_payload_context,
  input  wire          io_remove_valid,
  output wire [0:0]    io_query_context,
  input  wire          socCtrl_systemClk,
  input  wire          socCtrl_system_reset
);

  reg                 when_Phase_l776;
  wire                write_valid;
  wire       [0:0]    write_payload_data;
  wire       [0:0]    read_data;
  wire       [0:0]    _zz_read_data;
  reg        [0:0]    _zz_read_data_1;

  always @(*) begin
    when_Phase_l776 = 1'b0;
    if(write_valid) begin
      when_Phase_l776 = 1'b1;
    end
  end

  assign write_valid = io_add_valid;
  assign write_payload_data = io_add_payload_context;
  assign io_add_ready = 1'b1;
  assign read_data = _zz_read_data;
  assign io_query_context = read_data;
  assign _zz_read_data = _zz_read_data_1;
  always @(posedge socCtrl_systemClk) begin
    if(when_Phase_l776) begin
      _zz_read_data_1 <= write_payload_data;
    end
  end


endmodule
