// Source-extraction compilation-unit preamble (not reference payload).
`timescale 1ns/1ps

module StreamFifo (
  input  wire          io_push_valid,
  output wire          io_push_ready,
  input  wire [31:0]   io_push_payload_address,
  input  wire          io_push_payload_unique,
  input  wire [2:0]    io_push_payload_from,
  input  wire [2:0]    io_push_payload_to,
  input  wire [11:0]   io_push_payload_stride,
  output wire          io_pop_valid,
  input  wire          io_pop_ready,
  output wire [31:0]   io_pop_payload_address,
  output wire          io_pop_payload_unique,
  output wire [2:0]    io_pop_payload_from,
  output wire [2:0]    io_pop_payload_to,
  output wire [11:0]   io_pop_payload_stride,
  input  wire          io_flush,
  output wire [2:0]    io_occupancy,
  output wire [2:0]    io_availability,
  input  wire          socCtrl_systemClk,
  input  wire          socCtrl_system_reset
);

  wire       [50:0]   logic_ram_spinal_port1;
  wire       [50:0]   _zz_logic_ram_port;
  reg                 _zz_1;
  wire                logic_ptr_doPush;
  wire                logic_ptr_doPop;
  wire                logic_ptr_full;
  wire                logic_ptr_empty;
  reg        [2:0]    logic_ptr_push;
  reg        [2:0]    logic_ptr_pop;
  wire       [2:0]    logic_ptr_occupancy;
  wire       [2:0]    logic_ptr_popOnIo;
  wire                when_Stream_l1557;
  reg                 logic_ptr_wentUp;
  wire                io_push_fire;
  wire                logic_push_onRam_write_valid;
  wire       [1:0]    logic_push_onRam_write_payload_address;
  wire       [31:0]   logic_push_onRam_write_payload_data_address;
  wire                logic_push_onRam_write_payload_data_unique;
  wire       [2:0]    logic_push_onRam_write_payload_data_from;
  wire       [2:0]    logic_push_onRam_write_payload_data_to;
  wire       [11:0]   logic_push_onRam_write_payload_data_stride;
  wire                logic_pop_addressGen_valid;
  wire                logic_pop_addressGen_ready;
  wire       [1:0]    logic_pop_addressGen_payload;
  wire                logic_pop_addressGen_fire;
  wire       [31:0]   logic_pop_async_readed_address;
  wire                logic_pop_async_readed_unique;
  wire       [2:0]    logic_pop_async_readed_from;
  wire       [2:0]    logic_pop_async_readed_to;
  wire       [11:0]   logic_pop_async_readed_stride;
  wire       [50:0]   _zz_logic_pop_async_readed_address;
  wire                logic_pop_addressGen_translated_valid;
  wire                logic_pop_addressGen_translated_ready;
  wire       [31:0]   logic_pop_addressGen_translated_payload_address;
  wire                logic_pop_addressGen_translated_payload_unique;
  wire       [2:0]    logic_pop_addressGen_translated_payload_from;
  wire       [2:0]    logic_pop_addressGen_translated_payload_to;
  wire       [11:0]   logic_pop_addressGen_translated_payload_stride;
  (* ram_style = "distributed" *) reg [50:0] logic_ram [0:3];

  assign _zz_logic_ram_port = {logic_push_onRam_write_payload_data_stride,logic_push_onRam_write_payload_data_to,logic_push_onRam_write_payload_data_from,logic_push_onRam_write_payload_data_unique,logic_push_onRam_write_payload_data_address};
  always @(posedge socCtrl_systemClk) begin
    if(_zz_1) begin
      logic_ram[logic_push_onRam_write_payload_address] <= _zz_logic_ram_port;
    end
  end

  assign logic_ram_spinal_port1 = logic_ram[logic_pop_addressGen_payload];
  always @(*) begin
    _zz_1 = 1'b0;
    if(logic_push_onRam_write_valid) begin
      _zz_1 = 1'b1;
    end
  end

  assign when_Stream_l1557 = (logic_ptr_doPush != logic_ptr_doPop);
  assign logic_ptr_full = (((logic_ptr_push ^ logic_ptr_popOnIo) ^ 3'b100) == 3'b000);
  assign logic_ptr_empty = (logic_ptr_push == logic_ptr_pop);
  assign logic_ptr_occupancy = (logic_ptr_push - logic_ptr_popOnIo);
  assign io_push_ready = (! logic_ptr_full);
  assign io_push_fire = (io_push_valid && io_push_ready);
  assign logic_ptr_doPush = io_push_fire;
  assign logic_push_onRam_write_valid = io_push_fire;
  assign logic_push_onRam_write_payload_address = logic_ptr_push[1:0];
  assign logic_push_onRam_write_payload_data_address = io_push_payload_address;
  assign logic_push_onRam_write_payload_data_unique = io_push_payload_unique;
  assign logic_push_onRam_write_payload_data_from = io_push_payload_from;
  assign logic_push_onRam_write_payload_data_to = io_push_payload_to;
  assign logic_push_onRam_write_payload_data_stride = io_push_payload_stride;
  assign logic_pop_addressGen_valid = (! logic_ptr_empty);
  assign logic_pop_addressGen_payload = logic_ptr_pop[1:0];
  assign logic_pop_addressGen_fire = (logic_pop_addressGen_valid && logic_pop_addressGen_ready);
  assign logic_ptr_doPop = logic_pop_addressGen_fire;
  assign _zz_logic_pop_async_readed_address = logic_ram_spinal_port1;
  assign logic_pop_async_readed_address = _zz_logic_pop_async_readed_address[31 : 0];
  assign logic_pop_async_readed_unique = _zz_logic_pop_async_readed_address[32];
  assign logic_pop_async_readed_from = _zz_logic_pop_async_readed_address[35 : 33];
  assign logic_pop_async_readed_to = _zz_logic_pop_async_readed_address[38 : 36];
  assign logic_pop_async_readed_stride = _zz_logic_pop_async_readed_address[50 : 39];
  assign logic_pop_addressGen_translated_valid = logic_pop_addressGen_valid;
  assign logic_pop_addressGen_ready = logic_pop_addressGen_translated_ready;
  assign logic_pop_addressGen_translated_payload_address = logic_pop_async_readed_address;
  assign logic_pop_addressGen_translated_payload_unique = logic_pop_async_readed_unique;
  assign logic_pop_addressGen_translated_payload_from = logic_pop_async_readed_from;
  assign logic_pop_addressGen_translated_payload_to = logic_pop_async_readed_to;
  assign logic_pop_addressGen_translated_payload_stride = logic_pop_async_readed_stride;
  assign io_pop_valid = logic_pop_addressGen_translated_valid;
  assign logic_pop_addressGen_translated_ready = io_pop_ready;
  assign io_pop_payload_address = logic_pop_addressGen_translated_payload_address;
  assign io_pop_payload_unique = logic_pop_addressGen_translated_payload_unique;
  assign io_pop_payload_from = logic_pop_addressGen_translated_payload_from;
  assign io_pop_payload_to = logic_pop_addressGen_translated_payload_to;
  assign io_pop_payload_stride = logic_pop_addressGen_translated_payload_stride;
  assign logic_ptr_popOnIo = logic_ptr_pop;
  assign io_occupancy = logic_ptr_occupancy;
  assign io_availability = (3'b100 - logic_ptr_occupancy);
  always @(posedge socCtrl_systemClk or posedge socCtrl_system_reset) begin
    if(socCtrl_system_reset) begin
      logic_ptr_push <= 3'b000;
      logic_ptr_pop <= 3'b000;
      logic_ptr_wentUp <= 1'b0;
    end else begin
      if(when_Stream_l1557) begin
        logic_ptr_wentUp <= logic_ptr_doPush;
      end
      if(io_flush) begin
        logic_ptr_wentUp <= 1'b0;
      end
      if(logic_ptr_doPush) begin
        logic_ptr_push <= (logic_ptr_push + 3'b001);
      end
      if(logic_ptr_doPop) begin
        logic_ptr_pop <= (logic_ptr_pop + 3'b001);
      end
      if(io_flush) begin
        logic_ptr_push <= 3'b000;
        logic_ptr_pop <= 3'b000;
      end
    end
  end


endmodule
