// Source-extraction compilation-unit preamble (not reference payload).
`timescale 1ns/1ps

module RamAsyncMwReg (
  input  wire          io_writes_0_valid,
  input  wire [4:0]    io_writes_0_payload_address,
  input  wire [0:0]    io_writes_0_payload_data,
  input  wire          io_writes_1_valid,
  input  wire [4:0]    io_writes_1_payload_address,
  input  wire [0:0]    io_writes_1_payload_data,
  input  wire          io_read_0_cmd_valid,
  input  wire [4:0]    io_read_0_cmd_payload,
  output wire [0:0]    io_read_0_rsp,
  input  wire          io_read_1_cmd_valid,
  input  wire [4:0]    io_read_1_cmd_payload,
  output wire [0:0]    io_read_1_rsp,
  input  wire          io_read_2_cmd_valid,
  input  wire [4:0]    io_read_2_cmd_payload,
  output wire [0:0]    io_read_2_rsp,
  input  wire          io_read_3_cmd_valid,
  input  wire [4:0]    io_read_3_cmd_payload,
  output wire [0:0]    io_read_3_rsp,
  input  wire          socCtrl_systemClk,
  input  wire          socCtrl_system_reset
);

  reg        [0:0]    _zz_io_read_0_rsp;
  reg        [0:0]    _zz_io_read_1_rsp;
  reg        [0:0]    _zz_io_read_2_rsp;
  reg        [0:0]    _zz_io_read_3_rsp;
  reg        [0:0]    ram_0;
  reg        [0:0]    ram_1;
  reg        [0:0]    ram_2;
  reg        [0:0]    ram_3;
  reg        [0:0]    ram_4;
  reg        [0:0]    ram_5;
  reg        [0:0]    ram_6;
  reg        [0:0]    ram_7;
  reg        [0:0]    ram_8;
  reg        [0:0]    ram_9;
  reg        [0:0]    ram_10;
  reg        [0:0]    ram_11;
  reg        [0:0]    ram_12;
  reg        [0:0]    ram_13;
  reg        [0:0]    ram_14;
  reg        [0:0]    ram_15;
  reg        [0:0]    ram_16;
  reg        [0:0]    ram_17;
  reg        [0:0]    ram_18;
  reg        [0:0]    ram_19;
  reg        [0:0]    ram_20;
  reg        [0:0]    ram_21;
  reg        [0:0]    ram_22;
  reg        [0:0]    ram_23;
  reg        [0:0]    ram_24;
  reg        [0:0]    ram_25;
  reg        [0:0]    ram_26;
  reg        [0:0]    ram_27;
  reg        [0:0]    ram_28;
  reg        [0:0]    ram_29;
  reg        [0:0]    ram_30;
  reg        [0:0]    ram_31;
  wire       [31:0]   _zz_1;
  wire       [0:0]    _zz_ram_0;
  wire       [31:0]   _zz_2;
  wire       [0:0]    _zz_ram_0_1;

  initial begin
  `ifndef SYNTHESIS
    ram_0 = {$urandom};
    ram_1 = {$urandom};
    ram_2 = {$urandom};
    ram_3 = {$urandom};
    ram_4 = {$urandom};
    ram_5 = {$urandom};
    ram_6 = {$urandom};
    ram_7 = {$urandom};
    ram_8 = {$urandom};
    ram_9 = {$urandom};
    ram_10 = {$urandom};
    ram_11 = {$urandom};
    ram_12 = {$urandom};
    ram_13 = {$urandom};
    ram_14 = {$urandom};
    ram_15 = {$urandom};
    ram_16 = {$urandom};
    ram_17 = {$urandom};
    ram_18 = {$urandom};
    ram_19 = {$urandom};
    ram_20 = {$urandom};
    ram_21 = {$urandom};
    ram_22 = {$urandom};
    ram_23 = {$urandom};
    ram_24 = {$urandom};
    ram_25 = {$urandom};
    ram_26 = {$urandom};
    ram_27 = {$urandom};
    ram_28 = {$urandom};
    ram_29 = {$urandom};
    ram_30 = {$urandom};
    ram_31 = {$urandom};
  `endif
  end

  always @(*) begin
    case(io_read_0_cmd_payload)
      5'b00000 : _zz_io_read_0_rsp = ram_0;
      5'b00001 : _zz_io_read_0_rsp = ram_1;
      5'b00010 : _zz_io_read_0_rsp = ram_2;
      5'b00011 : _zz_io_read_0_rsp = ram_3;
      5'b00100 : _zz_io_read_0_rsp = ram_4;
      5'b00101 : _zz_io_read_0_rsp = ram_5;
      5'b00110 : _zz_io_read_0_rsp = ram_6;
      5'b00111 : _zz_io_read_0_rsp = ram_7;
      5'b01000 : _zz_io_read_0_rsp = ram_8;
      5'b01001 : _zz_io_read_0_rsp = ram_9;
      5'b01010 : _zz_io_read_0_rsp = ram_10;
      5'b01011 : _zz_io_read_0_rsp = ram_11;
      5'b01100 : _zz_io_read_0_rsp = ram_12;
      5'b01101 : _zz_io_read_0_rsp = ram_13;
      5'b01110 : _zz_io_read_0_rsp = ram_14;
      5'b01111 : _zz_io_read_0_rsp = ram_15;
      5'b10000 : _zz_io_read_0_rsp = ram_16;
      5'b10001 : _zz_io_read_0_rsp = ram_17;
      5'b10010 : _zz_io_read_0_rsp = ram_18;
      5'b10011 : _zz_io_read_0_rsp = ram_19;
      5'b10100 : _zz_io_read_0_rsp = ram_20;
      5'b10101 : _zz_io_read_0_rsp = ram_21;
      5'b10110 : _zz_io_read_0_rsp = ram_22;
      5'b10111 : _zz_io_read_0_rsp = ram_23;
      5'b11000 : _zz_io_read_0_rsp = ram_24;
      5'b11001 : _zz_io_read_0_rsp = ram_25;
      5'b11010 : _zz_io_read_0_rsp = ram_26;
      5'b11011 : _zz_io_read_0_rsp = ram_27;
      5'b11100 : _zz_io_read_0_rsp = ram_28;
      5'b11101 : _zz_io_read_0_rsp = ram_29;
      5'b11110 : _zz_io_read_0_rsp = ram_30;
      default : _zz_io_read_0_rsp = ram_31;
    endcase
  end

  always @(*) begin
    case(io_read_1_cmd_payload)
      5'b00000 : _zz_io_read_1_rsp = ram_0;
      5'b00001 : _zz_io_read_1_rsp = ram_1;
      5'b00010 : _zz_io_read_1_rsp = ram_2;
      5'b00011 : _zz_io_read_1_rsp = ram_3;
      5'b00100 : _zz_io_read_1_rsp = ram_4;
      5'b00101 : _zz_io_read_1_rsp = ram_5;
      5'b00110 : _zz_io_read_1_rsp = ram_6;
      5'b00111 : _zz_io_read_1_rsp = ram_7;
      5'b01000 : _zz_io_read_1_rsp = ram_8;
      5'b01001 : _zz_io_read_1_rsp = ram_9;
      5'b01010 : _zz_io_read_1_rsp = ram_10;
      5'b01011 : _zz_io_read_1_rsp = ram_11;
      5'b01100 : _zz_io_read_1_rsp = ram_12;
      5'b01101 : _zz_io_read_1_rsp = ram_13;
      5'b01110 : _zz_io_read_1_rsp = ram_14;
      5'b01111 : _zz_io_read_1_rsp = ram_15;
      5'b10000 : _zz_io_read_1_rsp = ram_16;
      5'b10001 : _zz_io_read_1_rsp = ram_17;
      5'b10010 : _zz_io_read_1_rsp = ram_18;
      5'b10011 : _zz_io_read_1_rsp = ram_19;
      5'b10100 : _zz_io_read_1_rsp = ram_20;
      5'b10101 : _zz_io_read_1_rsp = ram_21;
      5'b10110 : _zz_io_read_1_rsp = ram_22;
      5'b10111 : _zz_io_read_1_rsp = ram_23;
      5'b11000 : _zz_io_read_1_rsp = ram_24;
      5'b11001 : _zz_io_read_1_rsp = ram_25;
      5'b11010 : _zz_io_read_1_rsp = ram_26;
      5'b11011 : _zz_io_read_1_rsp = ram_27;
      5'b11100 : _zz_io_read_1_rsp = ram_28;
      5'b11101 : _zz_io_read_1_rsp = ram_29;
      5'b11110 : _zz_io_read_1_rsp = ram_30;
      default : _zz_io_read_1_rsp = ram_31;
    endcase
  end

  always @(*) begin
    case(io_read_2_cmd_payload)
      5'b00000 : _zz_io_read_2_rsp = ram_0;
      5'b00001 : _zz_io_read_2_rsp = ram_1;
      5'b00010 : _zz_io_read_2_rsp = ram_2;
      5'b00011 : _zz_io_read_2_rsp = ram_3;
      5'b00100 : _zz_io_read_2_rsp = ram_4;
      5'b00101 : _zz_io_read_2_rsp = ram_5;
      5'b00110 : _zz_io_read_2_rsp = ram_6;
      5'b00111 : _zz_io_read_2_rsp = ram_7;
      5'b01000 : _zz_io_read_2_rsp = ram_8;
      5'b01001 : _zz_io_read_2_rsp = ram_9;
      5'b01010 : _zz_io_read_2_rsp = ram_10;
      5'b01011 : _zz_io_read_2_rsp = ram_11;
      5'b01100 : _zz_io_read_2_rsp = ram_12;
      5'b01101 : _zz_io_read_2_rsp = ram_13;
      5'b01110 : _zz_io_read_2_rsp = ram_14;
      5'b01111 : _zz_io_read_2_rsp = ram_15;
      5'b10000 : _zz_io_read_2_rsp = ram_16;
      5'b10001 : _zz_io_read_2_rsp = ram_17;
      5'b10010 : _zz_io_read_2_rsp = ram_18;
      5'b10011 : _zz_io_read_2_rsp = ram_19;
      5'b10100 : _zz_io_read_2_rsp = ram_20;
      5'b10101 : _zz_io_read_2_rsp = ram_21;
      5'b10110 : _zz_io_read_2_rsp = ram_22;
      5'b10111 : _zz_io_read_2_rsp = ram_23;
      5'b11000 : _zz_io_read_2_rsp = ram_24;
      5'b11001 : _zz_io_read_2_rsp = ram_25;
      5'b11010 : _zz_io_read_2_rsp = ram_26;
      5'b11011 : _zz_io_read_2_rsp = ram_27;
      5'b11100 : _zz_io_read_2_rsp = ram_28;
      5'b11101 : _zz_io_read_2_rsp = ram_29;
      5'b11110 : _zz_io_read_2_rsp = ram_30;
      default : _zz_io_read_2_rsp = ram_31;
    endcase
  end

  always @(*) begin
    case(io_read_3_cmd_payload)
      5'b00000 : _zz_io_read_3_rsp = ram_0;
      5'b00001 : _zz_io_read_3_rsp = ram_1;
      5'b00010 : _zz_io_read_3_rsp = ram_2;
      5'b00011 : _zz_io_read_3_rsp = ram_3;
      5'b00100 : _zz_io_read_3_rsp = ram_4;
      5'b00101 : _zz_io_read_3_rsp = ram_5;
      5'b00110 : _zz_io_read_3_rsp = ram_6;
      5'b00111 : _zz_io_read_3_rsp = ram_7;
      5'b01000 : _zz_io_read_3_rsp = ram_8;
      5'b01001 : _zz_io_read_3_rsp = ram_9;
      5'b01010 : _zz_io_read_3_rsp = ram_10;
      5'b01011 : _zz_io_read_3_rsp = ram_11;
      5'b01100 : _zz_io_read_3_rsp = ram_12;
      5'b01101 : _zz_io_read_3_rsp = ram_13;
      5'b01110 : _zz_io_read_3_rsp = ram_14;
      5'b01111 : _zz_io_read_3_rsp = ram_15;
      5'b10000 : _zz_io_read_3_rsp = ram_16;
      5'b10001 : _zz_io_read_3_rsp = ram_17;
      5'b10010 : _zz_io_read_3_rsp = ram_18;
      5'b10011 : _zz_io_read_3_rsp = ram_19;
      5'b10100 : _zz_io_read_3_rsp = ram_20;
      5'b10101 : _zz_io_read_3_rsp = ram_21;
      5'b10110 : _zz_io_read_3_rsp = ram_22;
      5'b10111 : _zz_io_read_3_rsp = ram_23;
      5'b11000 : _zz_io_read_3_rsp = ram_24;
      5'b11001 : _zz_io_read_3_rsp = ram_25;
      5'b11010 : _zz_io_read_3_rsp = ram_26;
      5'b11011 : _zz_io_read_3_rsp = ram_27;
      5'b11100 : _zz_io_read_3_rsp = ram_28;
      5'b11101 : _zz_io_read_3_rsp = ram_29;
      5'b11110 : _zz_io_read_3_rsp = ram_30;
      default : _zz_io_read_3_rsp = ram_31;
    endcase
  end

  assign _zz_1 = ({31'd0,1'b1} <<< io_writes_0_payload_address);
  assign _zz_ram_0 = io_writes_0_payload_data;
  assign _zz_2 = ({31'd0,1'b1} <<< io_writes_1_payload_address);
  assign _zz_ram_0_1 = io_writes_1_payload_data;
  assign io_read_0_rsp = _zz_io_read_0_rsp;
  assign io_read_1_rsp = _zz_io_read_1_rsp;
  assign io_read_2_rsp = _zz_io_read_2_rsp;
  assign io_read_3_rsp = _zz_io_read_3_rsp;
  always @(posedge socCtrl_systemClk) begin
    if(io_writes_0_valid) begin
      if(_zz_1[0]) begin
        ram_0 <= _zz_ram_0;
      end
      if(_zz_1[1]) begin
        ram_1 <= _zz_ram_0;
      end
      if(_zz_1[2]) begin
        ram_2 <= _zz_ram_0;
      end
      if(_zz_1[3]) begin
        ram_3 <= _zz_ram_0;
      end
      if(_zz_1[4]) begin
        ram_4 <= _zz_ram_0;
      end
      if(_zz_1[5]) begin
        ram_5 <= _zz_ram_0;
      end
      if(_zz_1[6]) begin
        ram_6 <= _zz_ram_0;
      end
      if(_zz_1[7]) begin
        ram_7 <= _zz_ram_0;
      end
      if(_zz_1[8]) begin
        ram_8 <= _zz_ram_0;
      end
      if(_zz_1[9]) begin
        ram_9 <= _zz_ram_0;
      end
      if(_zz_1[10]) begin
        ram_10 <= _zz_ram_0;
      end
      if(_zz_1[11]) begin
        ram_11 <= _zz_ram_0;
      end
      if(_zz_1[12]) begin
        ram_12 <= _zz_ram_0;
      end
      if(_zz_1[13]) begin
        ram_13 <= _zz_ram_0;
      end
      if(_zz_1[14]) begin
        ram_14 <= _zz_ram_0;
      end
      if(_zz_1[15]) begin
        ram_15 <= _zz_ram_0;
      end
      if(_zz_1[16]) begin
        ram_16 <= _zz_ram_0;
      end
      if(_zz_1[17]) begin
        ram_17 <= _zz_ram_0;
      end
      if(_zz_1[18]) begin
        ram_18 <= _zz_ram_0;
      end
      if(_zz_1[19]) begin
        ram_19 <= _zz_ram_0;
      end
      if(_zz_1[20]) begin
        ram_20 <= _zz_ram_0;
      end
      if(_zz_1[21]) begin
        ram_21 <= _zz_ram_0;
      end
      if(_zz_1[22]) begin
        ram_22 <= _zz_ram_0;
      end
      if(_zz_1[23]) begin
        ram_23 <= _zz_ram_0;
      end
      if(_zz_1[24]) begin
        ram_24 <= _zz_ram_0;
      end
      if(_zz_1[25]) begin
        ram_25 <= _zz_ram_0;
      end
      if(_zz_1[26]) begin
        ram_26 <= _zz_ram_0;
      end
      if(_zz_1[27]) begin
        ram_27 <= _zz_ram_0;
      end
      if(_zz_1[28]) begin
        ram_28 <= _zz_ram_0;
      end
      if(_zz_1[29]) begin
        ram_29 <= _zz_ram_0;
      end
      if(_zz_1[30]) begin
        ram_30 <= _zz_ram_0;
      end
      if(_zz_1[31]) begin
        ram_31 <= _zz_ram_0;
      end
    end
    if(io_writes_1_valid) begin
      if(_zz_2[0]) begin
        ram_0 <= _zz_ram_0_1;
      end
      if(_zz_2[1]) begin
        ram_1 <= _zz_ram_0_1;
      end
      if(_zz_2[2]) begin
        ram_2 <= _zz_ram_0_1;
      end
      if(_zz_2[3]) begin
        ram_3 <= _zz_ram_0_1;
      end
      if(_zz_2[4]) begin
        ram_4 <= _zz_ram_0_1;
      end
      if(_zz_2[5]) begin
        ram_5 <= _zz_ram_0_1;
      end
      if(_zz_2[6]) begin
        ram_6 <= _zz_ram_0_1;
      end
      if(_zz_2[7]) begin
        ram_7 <= _zz_ram_0_1;
      end
      if(_zz_2[8]) begin
        ram_8 <= _zz_ram_0_1;
      end
      if(_zz_2[9]) begin
        ram_9 <= _zz_ram_0_1;
      end
      if(_zz_2[10]) begin
        ram_10 <= _zz_ram_0_1;
      end
      if(_zz_2[11]) begin
        ram_11 <= _zz_ram_0_1;
      end
      if(_zz_2[12]) begin
        ram_12 <= _zz_ram_0_1;
      end
      if(_zz_2[13]) begin
        ram_13 <= _zz_ram_0_1;
      end
      if(_zz_2[14]) begin
        ram_14 <= _zz_ram_0_1;
      end
      if(_zz_2[15]) begin
        ram_15 <= _zz_ram_0_1;
      end
      if(_zz_2[16]) begin
        ram_16 <= _zz_ram_0_1;
      end
      if(_zz_2[17]) begin
        ram_17 <= _zz_ram_0_1;
      end
      if(_zz_2[18]) begin
        ram_18 <= _zz_ram_0_1;
      end
      if(_zz_2[19]) begin
        ram_19 <= _zz_ram_0_1;
      end
      if(_zz_2[20]) begin
        ram_20 <= _zz_ram_0_1;
      end
      if(_zz_2[21]) begin
        ram_21 <= _zz_ram_0_1;
      end
      if(_zz_2[22]) begin
        ram_22 <= _zz_ram_0_1;
      end
      if(_zz_2[23]) begin
        ram_23 <= _zz_ram_0_1;
      end
      if(_zz_2[24]) begin
        ram_24 <= _zz_ram_0_1;
      end
      if(_zz_2[25]) begin
        ram_25 <= _zz_ram_0_1;
      end
      if(_zz_2[26]) begin
        ram_26 <= _zz_ram_0_1;
      end
      if(_zz_2[27]) begin
        ram_27 <= _zz_ram_0_1;
      end
      if(_zz_2[28]) begin
        ram_28 <= _zz_ram_0_1;
      end
      if(_zz_2[29]) begin
        ram_29 <= _zz_ram_0_1;
      end
      if(_zz_2[30]) begin
        ram_30 <= _zz_ram_0_1;
      end
      if(_zz_2[31]) begin
        ram_31 <= _zz_ram_0_1;
      end
    end
  end


endmodule
