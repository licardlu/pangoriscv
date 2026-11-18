// Source-extraction compilation-unit preamble (not reference payload).
`timescale 1ns/1ps

module RamSyncMwMux (
  input  wire          io_writes_0_valid,
  input  wire [4:0]    io_writes_0_payload_address,
  input  wire [31:0]   io_writes_0_payload_data,
  input  wire          io_writes_1_valid,
  input  wire [4:0]    io_writes_1_payload_address,
  input  wire [31:0]   io_writes_1_payload_data,
  input  wire          io_read_0_cmd_valid,
  input  wire [4:0]    io_read_0_cmd_payload,
  output wire [31:0]   io_read_0_rsp,
  input  wire          io_read_1_cmd_valid,
  input  wire [4:0]    io_read_1_cmd_payload,
  output wire [31:0]   io_read_1_rsp,
  input  wire          io_read_2_cmd_valid,
  input  wire [4:0]    io_read_2_cmd_payload,
  output wire [31:0]   io_read_2_rsp,
  input  wire          io_read_3_cmd_valid,
  input  wire [4:0]    io_read_3_cmd_payload,
  output wire [31:0]   io_read_3_rsp,
  input  wire          socCtrl_systemClk,
  input  wire          socCtrl_system_reset
);

  reg        [31:0]   ram_0_spinal_port1;
  reg        [31:0]   ram_0_spinal_port2;
  reg        [31:0]   ram_0_spinal_port3;
  reg        [31:0]   ram_0_spinal_port4;
  reg        [31:0]   ram_1_spinal_port1;
  reg        [31:0]   ram_1_spinal_port2;
  reg        [31:0]   ram_1_spinal_port3;
  reg        [31:0]   ram_1_spinal_port4;
  wire       [0:0]    location_io_read_0_rsp;
  wire       [0:0]    location_io_read_1_rsp;
  wire       [0:0]    location_io_read_2_rsp;
  wire       [0:0]    location_io_read_3_rsp;
  reg        [31:0]   _zz_io_read_0_rsp;
  reg        [31:0]   _zz_io_read_1_rsp;
  reg        [31:0]   _zz_io_read_2_rsp;
  reg        [31:0]   _zz_io_read_3_rsp;
  wire       [31:0]   reads_0_reads_0;
  wire       [31:0]   reads_0_reads_1;
  reg        [4:0]    reads_0_addressReg;
  wire       [31:0]   reads_1_reads_0;
  wire       [31:0]   reads_1_reads_1;
  reg        [4:0]    reads_1_addressReg;
  wire       [31:0]   reads_2_reads_0;
  wire       [31:0]   reads_2_reads_1;
  reg        [4:0]    reads_2_addressReg;
  wire       [31:0]   reads_3_reads_0;
  wire       [31:0]   reads_3_reads_1;
  reg        [4:0]    reads_3_addressReg;
  reg [31:0] ram_0 [0:31];
  reg [31:0] ram_1 [0:31];

  always @(posedge socCtrl_systemClk) begin
    if(io_writes_0_valid) begin
      ram_0[io_writes_0_payload_address] <= io_writes_0_payload_data;
    end
  end

  always @(posedge socCtrl_systemClk) begin
    if(io_read_0_cmd_valid) begin
      ram_0_spinal_port1 <= ram_0[io_read_0_cmd_payload];
    end
  end

  always @(posedge socCtrl_systemClk) begin
    if(io_read_1_cmd_valid) begin
      ram_0_spinal_port2 <= ram_0[io_read_1_cmd_payload];
    end
  end

  always @(posedge socCtrl_systemClk) begin
    if(io_read_2_cmd_valid) begin
      ram_0_spinal_port3 <= ram_0[io_read_2_cmd_payload];
    end
  end

  always @(posedge socCtrl_systemClk) begin
    if(io_read_3_cmd_valid) begin
      ram_0_spinal_port4 <= ram_0[io_read_3_cmd_payload];
    end
  end

  always @(posedge socCtrl_systemClk) begin
    if(io_writes_1_valid) begin
      ram_1[io_writes_1_payload_address] <= io_writes_1_payload_data;
    end
  end

  always @(posedge socCtrl_systemClk) begin
    if(io_read_0_cmd_valid) begin
      ram_1_spinal_port1 <= ram_1[io_read_0_cmd_payload];
    end
  end

  always @(posedge socCtrl_systemClk) begin
    if(io_read_1_cmd_valid) begin
      ram_1_spinal_port2 <= ram_1[io_read_1_cmd_payload];
    end
  end

  always @(posedge socCtrl_systemClk) begin
    if(io_read_2_cmd_valid) begin
      ram_1_spinal_port3 <= ram_1[io_read_2_cmd_payload];
    end
  end

  always @(posedge socCtrl_systemClk) begin
    if(io_read_3_cmd_valid) begin
      ram_1_spinal_port4 <= ram_1[io_read_3_cmd_payload];
    end
  end

  RamAsyncMwReg location (
    .io_writes_0_valid           (io_writes_0_valid               ), //i
    .io_writes_0_payload_address (io_writes_0_payload_address[4:0]), //i
    .io_writes_0_payload_data    (1'b0                            ), //i
    .io_writes_1_valid           (io_writes_1_valid               ), //i
    .io_writes_1_payload_address (io_writes_1_payload_address[4:0]), //i
    .io_writes_1_payload_data    (1'b1                            ), //i
    .io_read_0_cmd_valid         (1'b1                            ), //i
    .io_read_0_cmd_payload       (reads_0_addressReg[4:0]         ), //i
    .io_read_0_rsp               (location_io_read_0_rsp          ), //o
    .io_read_1_cmd_valid         (1'b1                            ), //i
    .io_read_1_cmd_payload       (reads_1_addressReg[4:0]         ), //i
    .io_read_1_rsp               (location_io_read_1_rsp          ), //o
    .io_read_2_cmd_valid         (1'b1                            ), //i
    .io_read_2_cmd_payload       (reads_2_addressReg[4:0]         ), //i
    .io_read_2_rsp               (location_io_read_2_rsp          ), //o
    .io_read_3_cmd_valid         (1'b1                            ), //i
    .io_read_3_cmd_payload       (reads_3_addressReg[4:0]         ), //i
    .io_read_3_rsp               (location_io_read_3_rsp          ), //o
    .socCtrl_systemClk           (socCtrl_systemClk               ), //i
    .socCtrl_system_reset        (socCtrl_system_reset            )  //i
  );
  always @(*) begin
    case(location_io_read_0_rsp)
      1'b0 : _zz_io_read_0_rsp = reads_0_reads_0;
      default : _zz_io_read_0_rsp = reads_0_reads_1;
    endcase
  end

  always @(*) begin
    case(location_io_read_1_rsp)
      1'b0 : _zz_io_read_1_rsp = reads_1_reads_0;
      default : _zz_io_read_1_rsp = reads_1_reads_1;
    endcase
  end

  always @(*) begin
    case(location_io_read_2_rsp)
      1'b0 : _zz_io_read_2_rsp = reads_2_reads_0;
      default : _zz_io_read_2_rsp = reads_2_reads_1;
    endcase
  end

  always @(*) begin
    case(location_io_read_3_rsp)
      1'b0 : _zz_io_read_3_rsp = reads_3_reads_0;
      default : _zz_io_read_3_rsp = reads_3_reads_1;
    endcase
  end

  assign reads_0_reads_0 = ram_0_spinal_port1;
  assign reads_0_reads_1 = ram_1_spinal_port1;
  assign io_read_0_rsp = _zz_io_read_0_rsp;
  assign reads_1_reads_0 = ram_0_spinal_port2;
  assign reads_1_reads_1 = ram_1_spinal_port2;
  assign io_read_1_rsp = _zz_io_read_1_rsp;
  assign reads_2_reads_0 = ram_0_spinal_port3;
  assign reads_2_reads_1 = ram_1_spinal_port3;
  assign io_read_2_rsp = _zz_io_read_2_rsp;
  assign reads_3_reads_0 = ram_0_spinal_port4;
  assign reads_3_reads_1 = ram_1_spinal_port4;
  assign io_read_3_rsp = _zz_io_read_3_rsp;
  always @(posedge socCtrl_systemClk) begin
    if(io_read_0_cmd_valid) begin
      reads_0_addressReg <= io_read_0_cmd_payload;
    end
    if(io_read_1_cmd_valid) begin
      reads_1_addressReg <= io_read_1_cmd_payload;
    end
    if(io_read_2_cmd_valid) begin
      reads_2_addressReg <= io_read_2_cmd_payload;
    end
    if(io_read_3_cmd_valid) begin
      reads_3_addressReg <= io_read_3_cmd_payload;
    end
  end


endmodule
