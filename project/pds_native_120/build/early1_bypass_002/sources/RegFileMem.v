// Source-extraction compilation-unit preamble (not reference payload).
`timescale 1ns/1ps

module RegFileMem (
  input  wire          io_writes_0_valid,
  input  wire [4:0]    io_writes_0_address,
  input  wire [31:0]   io_writes_0_data,
  input  wire [15:0]   io_writes_0_uopId,
  input  wire          io_writes_1_valid,
  input  wire [4:0]    io_writes_1_address,
  input  wire [31:0]   io_writes_1_data,
  input  wire [15:0]   io_writes_1_uopId,
  input  wire          io_reads_0_valid,
  input  wire [4:0]    io_reads_0_address,
  output wire [31:0]   io_reads_0_data,
  input  wire          io_reads_1_valid,
  input  wire [4:0]    io_reads_1_address,
  output wire [31:0]   io_reads_1_data,
  input  wire          io_reads_2_valid,
  input  wire [4:0]    io_reads_2_address,
  output wire [31:0]   io_reads_2_data,
  input  wire          io_reads_3_valid,
  input  wire [4:0]    io_reads_3_address,
  output wire [31:0]   io_reads_3_data,
  input  wire          socCtrl_systemClk,
  input  wire          socCtrl_system_reset
);

  wire       [31:0]   ramSyncMwMux_1_io_read_0_rsp;
  wire       [31:0]   ramSyncMwMux_1_io_read_1_rsp;
  wire       [31:0]   ramSyncMwMux_1_io_read_2_rsp;
  wire       [31:0]   ramSyncMwMux_1_io_read_3_rsp;
  wire                conv_writes_0_valid;
  wire       [4:0]    conv_writes_0_payload_address;
  wire       [31:0]   conv_writes_0_payload_data;
  wire                conv_writes_1_valid;
  wire       [4:0]    conv_writes_1_payload_address;
  wire       [31:0]   conv_writes_1_payload_data;
  wire                conv_read_0_cmd_valid;
  wire       [4:0]    conv_read_0_cmd_payload;
  wire       [31:0]   conv_read_0_rsp;
  wire                conv_read_1_cmd_valid;
  wire       [4:0]    conv_read_1_cmd_payload;
  wire       [31:0]   conv_read_1_rsp;
  wire                conv_read_2_cmd_valid;
  wire       [4:0]    conv_read_2_cmd_payload;
  wire       [31:0]   conv_read_2_rsp;
  wire                conv_read_3_cmd_valid;
  wire       [4:0]    conv_read_3_cmd_payload;
  wire       [31:0]   conv_read_3_rsp;

  RamSyncMwMux ramSyncMwMux_1 (
    .io_writes_0_valid           (conv_writes_0_valid               ), //i
    .io_writes_0_payload_address (conv_writes_0_payload_address[4:0]), //i
    .io_writes_0_payload_data    (conv_writes_0_payload_data[31:0]  ), //i
    .io_writes_1_valid           (conv_writes_1_valid               ), //i
    .io_writes_1_payload_address (conv_writes_1_payload_address[4:0]), //i
    .io_writes_1_payload_data    (conv_writes_1_payload_data[31:0]  ), //i
    .io_read_0_cmd_valid         (conv_read_0_cmd_valid             ), //i
    .io_read_0_cmd_payload       (conv_read_0_cmd_payload[4:0]      ), //i
    .io_read_0_rsp               (ramSyncMwMux_1_io_read_0_rsp[31:0]), //o
    .io_read_1_cmd_valid         (conv_read_1_cmd_valid             ), //i
    .io_read_1_cmd_payload       (conv_read_1_cmd_payload[4:0]      ), //i
    .io_read_1_rsp               (ramSyncMwMux_1_io_read_1_rsp[31:0]), //o
    .io_read_2_cmd_valid         (conv_read_2_cmd_valid             ), //i
    .io_read_2_cmd_payload       (conv_read_2_cmd_payload[4:0]      ), //i
    .io_read_2_rsp               (ramSyncMwMux_1_io_read_2_rsp[31:0]), //o
    .io_read_3_cmd_valid         (conv_read_3_cmd_valid             ), //i
    .io_read_3_cmd_payload       (conv_read_3_cmd_payload[4:0]      ), //i
    .io_read_3_rsp               (ramSyncMwMux_1_io_read_3_rsp[31:0]), //o
    .socCtrl_systemClk           (socCtrl_systemClk                 ), //i
    .socCtrl_system_reset        (socCtrl_system_reset              )  //i
  );
  assign conv_writes_0_valid = io_writes_0_valid;
  assign conv_writes_0_payload_address = io_writes_0_address;
  assign conv_writes_0_payload_data = io_writes_0_data;
  assign conv_writes_1_valid = io_writes_1_valid;
  assign conv_writes_1_payload_address = io_writes_1_address;
  assign conv_writes_1_payload_data = io_writes_1_data;
  assign conv_read_0_cmd_valid = io_reads_0_valid;
  assign conv_read_0_cmd_payload = io_reads_0_address;
  assign io_reads_0_data = conv_read_0_rsp;
  assign conv_read_1_cmd_valid = io_reads_1_valid;
  assign conv_read_1_cmd_payload = io_reads_1_address;
  assign io_reads_1_data = conv_read_1_rsp;
  assign conv_read_2_cmd_valid = io_reads_2_valid;
  assign conv_read_2_cmd_payload = io_reads_2_address;
  assign io_reads_2_data = conv_read_2_rsp;
  assign conv_read_3_cmd_valid = io_reads_3_valid;
  assign conv_read_3_cmd_payload = io_reads_3_address;
  assign io_reads_3_data = conv_read_3_rsp;
  assign conv_read_0_rsp = ramSyncMwMux_1_io_read_0_rsp;
  assign conv_read_1_rsp = ramSyncMwMux_1_io_read_1_rsp;
  assign conv_read_2_rsp = ramSyncMwMux_1_io_read_2_rsp;
  assign conv_read_3_rsp = ramSyncMwMux_1_io_read_3_rsp;

endmodule
