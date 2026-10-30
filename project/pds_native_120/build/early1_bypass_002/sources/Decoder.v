// Source-extraction compilation-unit preamble (not reference payload).
`timescale 1ns/1ps

module Decoder (
  input  wire          io_up_a_valid,
  output wire          io_up_a_ready,
  input  wire [2:0]    io_up_a_payload_opcode,
  input  wire [2:0]    io_up_a_payload_param,
  input  wire [5:0]    io_up_a_payload_source,
  input  wire [28:0]   io_up_a_payload_address,
  input  wire [2:0]    io_up_a_payload_size,
  input  wire [3:0]    io_up_a_payload_mask,
  input  wire [31:0]   io_up_a_payload_data,
  input  wire          io_up_a_payload_corrupt,
  output wire          io_up_d_valid,
  input  wire          io_up_d_ready,
  output wire [2:0]    io_up_d_payload_opcode,
  output wire [2:0]    io_up_d_payload_param,
  output wire [5:0]    io_up_d_payload_source,
  output wire [2:0]    io_up_d_payload_size,
  output wire          io_up_d_payload_denied,
  output wire [31:0]   io_up_d_payload_data,
  output wire          io_up_d_payload_corrupt,
  output wire          io_downs_0_a_valid,
  input  wire          io_downs_0_a_ready,
  output wire [2:0]    io_downs_0_a_payload_opcode,
  output wire [2:0]    io_downs_0_a_payload_param,
  output wire [5:0]    io_downs_0_a_payload_source,
  output wire [28:0]   io_downs_0_a_payload_address,
  output wire [1:0]    io_downs_0_a_payload_size,
  output wire [3:0]    io_downs_0_a_payload_mask,
  output wire [31:0]   io_downs_0_a_payload_data,
  output wire          io_downs_0_a_payload_corrupt,
  input  wire          io_downs_0_d_valid,
  output wire          io_downs_0_d_ready,
  input  wire [2:0]    io_downs_0_d_payload_opcode,
  input  wire [2:0]    io_downs_0_d_payload_param,
  input  wire [5:0]    io_downs_0_d_payload_source,
  input  wire [1:0]    io_downs_0_d_payload_size,
  input  wire          io_downs_0_d_payload_denied,
  input  wire [31:0]   io_downs_0_d_payload_data,
  input  wire          io_downs_0_d_payload_corrupt,
  output wire          io_downs_1_a_valid,
  input  wire          io_downs_1_a_ready,
  output wire [2:0]    io_downs_1_a_payload_opcode,
  output wire [2:0]    io_downs_1_a_payload_param,
  output wire [5:0]    io_downs_1_a_payload_source,
  output wire [15:0]   io_downs_1_a_payload_address,
  output wire [2:0]    io_downs_1_a_payload_size,
  output wire [3:0]    io_downs_1_a_payload_mask,
  output wire [31:0]   io_downs_1_a_payload_data,
  output wire          io_downs_1_a_payload_corrupt,
  input  wire          io_downs_1_d_valid,
  output wire          io_downs_1_d_ready,
  input  wire [2:0]    io_downs_1_d_payload_opcode,
  input  wire [2:0]    io_downs_1_d_payload_param,
  input  wire [5:0]    io_downs_1_d_payload_source,
  input  wire [2:0]    io_downs_1_d_payload_size,
  input  wire          io_downs_1_d_payload_denied,
  input  wire [31:0]   io_downs_1_d_payload_data,
  input  wire          io_downs_1_d_payload_corrupt,
  input  wire          socCtrl_systemClk,
  input  wire          socCtrl_system_reset
);
  localparam A_PUT_FULL_DATA = 3'd0;
  localparam A_PUT_PARTIAL_DATA = 3'd1;
  localparam A_ARITHMETIC_DATA = 3'd2;
  localparam A_LOGICAL_DATA = 3'd3;
  localparam A_GET = 3'd4;
  localparam A_ACQUIRE_BLOCK = 3'd6;
  localparam A_ACQUIRE_PERM = 3'd7;
  localparam D_ACCESS_ACK = 3'd0;
  localparam D_ACCESS_ACK_DATA = 3'd1;
  localparam D_GRANT = 3'd4;
  localparam D_GRANT_DATA = 3'd5;
  localparam D_RELEASE_ACK = 3'd6;

  wire       [2:0]    d_arbiter_io_inputs_0_payload_size;
  wire                d_arbiter_io_inputs_0_ready;
  wire                d_arbiter_io_inputs_1_ready;
  wire                d_arbiter_io_output_valid;
  wire       [2:0]    d_arbiter_io_output_payload_opcode;
  wire       [2:0]    d_arbiter_io_output_payload_param;
  wire       [5:0]    d_arbiter_io_output_payload_source;
  wire       [2:0]    d_arbiter_io_output_payload_size;
  wire                d_arbiter_io_output_payload_denied;
  wire       [31:0]   d_arbiter_io_output_payload_data;
  wire                d_arbiter_io_output_payload_corrupt;
  wire       [0:0]    d_arbiter_io_chosen;
  wire       [1:0]    d_arbiter_io_chosenOH;
  wire       [0:0]    _zz_a_logic_0_hit;
  wire       [0:0]    _zz_a_logic_1_hit;
  wire       [28:0]   _zz_downs_1_a_payload_address;
  reg        [1:0]    _zz_1;
  wire       [1:0]    _zz_2;
  wire                downs_0_a_valid;
  wire                downs_0_a_ready;
  wire       [2:0]    downs_0_a_payload_opcode;
  wire       [2:0]    downs_0_a_payload_param;
  wire       [5:0]    downs_0_a_payload_source;
  wire       [28:0]   downs_0_a_payload_address;
  wire       [1:0]    downs_0_a_payload_size;
  wire       [3:0]    downs_0_a_payload_mask;
  wire       [31:0]   downs_0_a_payload_data;
  wire                downs_0_a_payload_corrupt;
  wire                downs_0_d_valid;
  wire                downs_0_d_ready;
  wire       [2:0]    downs_0_d_payload_opcode;
  wire       [2:0]    downs_0_d_payload_param;
  wire       [5:0]    downs_0_d_payload_source;
  wire       [1:0]    downs_0_d_payload_size;
  wire                downs_0_d_payload_denied;
  wire       [31:0]   downs_0_d_payload_data;
  wire                downs_0_d_payload_corrupt;
  wire                downs_1_a_valid;
  wire                downs_1_a_ready;
  wire       [2:0]    downs_1_a_payload_opcode;
  wire       [2:0]    downs_1_a_payload_param;
  wire       [5:0]    downs_1_a_payload_source;
  wire       [15:0]   downs_1_a_payload_address;
  wire       [2:0]    downs_1_a_payload_size;
  wire       [3:0]    downs_1_a_payload_mask;
  wire       [31:0]   downs_1_a_payload_data;
  wire                downs_1_a_payload_corrupt;
  wire                downs_1_d_valid;
  wire                downs_1_d_ready;
  wire       [2:0]    downs_1_d_payload_opcode;
  wire       [2:0]    downs_1_d_payload_param;
  wire       [5:0]    downs_1_d_payload_source;
  wire       [2:0]    downs_1_d_payload_size;
  wire                downs_1_d_payload_denied;
  wire       [31:0]   downs_1_d_payload_data;
  wire                downs_1_d_payload_corrupt;
  wire       [31:0]   a_key;
  wire                a_logic_0_hit;
  wire                a_logic_1_hit;
  wire                a_miss;
  `ifndef SYNTHESIS
  reg [127:0] io_up_a_payload_opcode_string;
  reg [119:0] io_up_d_payload_opcode_string;
  reg [127:0] io_downs_0_a_payload_opcode_string;
  reg [119:0] io_downs_0_d_payload_opcode_string;
  reg [127:0] io_downs_1_a_payload_opcode_string;
  reg [119:0] io_downs_1_d_payload_opcode_string;
  reg [127:0] downs_0_a_payload_opcode_string;
  reg [119:0] downs_0_d_payload_opcode_string;
  reg [127:0] downs_1_a_payload_opcode_string;
  reg [119:0] downs_1_d_payload_opcode_string;
  `endif


  assign _zz_a_logic_0_hit = (|{((a_key & 32'h00800000) == 32'h00800000),((a_key & 32'h00010000) == 32'h0)});
  assign _zz_a_logic_1_hit = (|((a_key & 32'h00810000) == 32'h00010000));
  assign _zz_downs_1_a_payload_address = (io_up_a_payload_address - 29'h10010000);
  assign _zz_2 = {io_downs_1_a_valid,io_downs_0_a_valid};
  StreamArbiter_4 d_arbiter (
    .io_inputs_0_valid           (downs_0_d_valid                        ), //i
    .io_inputs_0_ready           (d_arbiter_io_inputs_0_ready            ), //o
    .io_inputs_0_payload_opcode  (downs_0_d_payload_opcode[2:0]          ), //i
    .io_inputs_0_payload_param   (downs_0_d_payload_param[2:0]           ), //i
    .io_inputs_0_payload_source  (downs_0_d_payload_source[5:0]          ), //i
    .io_inputs_0_payload_size    (d_arbiter_io_inputs_0_payload_size[2:0]), //i
    .io_inputs_0_payload_denied  (downs_0_d_payload_denied               ), //i
    .io_inputs_0_payload_data    (downs_0_d_payload_data[31:0]           ), //i
    .io_inputs_0_payload_corrupt (downs_0_d_payload_corrupt              ), //i
    .io_inputs_1_valid           (downs_1_d_valid                        ), //i
    .io_inputs_1_ready           (d_arbiter_io_inputs_1_ready            ), //o
    .io_inputs_1_payload_opcode  (downs_1_d_payload_opcode[2:0]          ), //i
    .io_inputs_1_payload_param   (downs_1_d_payload_param[2:0]           ), //i
    .io_inputs_1_payload_source  (downs_1_d_payload_source[5:0]          ), //i
    .io_inputs_1_payload_size    (downs_1_d_payload_size[2:0]            ), //i
    .io_inputs_1_payload_denied  (downs_1_d_payload_denied               ), //i
    .io_inputs_1_payload_data    (downs_1_d_payload_data[31:0]           ), //i
    .io_inputs_1_payload_corrupt (downs_1_d_payload_corrupt              ), //i
    .io_output_valid             (d_arbiter_io_output_valid              ), //o
    .io_output_ready             (io_up_d_ready                          ), //i
    .io_output_payload_opcode    (d_arbiter_io_output_payload_opcode[2:0]), //o
    .io_output_payload_param     (d_arbiter_io_output_payload_param[2:0] ), //o
    .io_output_payload_source    (d_arbiter_io_output_payload_source[5:0]), //o
    .io_output_payload_size      (d_arbiter_io_output_payload_size[2:0]  ), //o
    .io_output_payload_denied    (d_arbiter_io_output_payload_denied     ), //o
    .io_output_payload_data      (d_arbiter_io_output_payload_data[31:0] ), //o
    .io_output_payload_corrupt   (d_arbiter_io_output_payload_corrupt    ), //o
    .io_chosen                   (d_arbiter_io_chosen                    ), //o
    .io_chosenOH                 (d_arbiter_io_chosenOH[1:0]             ), //o
    .socCtrl_systemClk           (socCtrl_systemClk                      ), //i
    .socCtrl_system_reset        (socCtrl_system_reset                   )  //i
  );
  always @(*) begin
    case(_zz_2)
      2'b00 : _zz_1 = 2'b00;
      2'b01 : _zz_1 = 2'b01;
      2'b10 : _zz_1 = 2'b01;
      default : _zz_1 = 2'b10;
    endcase
  end

  `ifndef SYNTHESIS
  always @(*) begin
    case(io_up_a_payload_opcode)
      A_PUT_FULL_DATA : io_up_a_payload_opcode_string = "PUT_FULL_DATA   ";
      A_PUT_PARTIAL_DATA : io_up_a_payload_opcode_string = "PUT_PARTIAL_DATA";
      A_ARITHMETIC_DATA : io_up_a_payload_opcode_string = "ARITHMETIC_DATA ";
      A_LOGICAL_DATA : io_up_a_payload_opcode_string = "LOGICAL_DATA    ";
      A_GET : io_up_a_payload_opcode_string = "GET             ";
      A_ACQUIRE_BLOCK : io_up_a_payload_opcode_string = "ACQUIRE_BLOCK   ";
      A_ACQUIRE_PERM : io_up_a_payload_opcode_string = "ACQUIRE_PERM    ";
      default : io_up_a_payload_opcode_string = "????????????????";
    endcase
  end
  always @(*) begin
    case(io_up_d_payload_opcode)
      D_ACCESS_ACK : io_up_d_payload_opcode_string = "ACCESS_ACK     ";
      D_ACCESS_ACK_DATA : io_up_d_payload_opcode_string = "ACCESS_ACK_DATA";
      D_GRANT : io_up_d_payload_opcode_string = "GRANT          ";
      D_GRANT_DATA : io_up_d_payload_opcode_string = "GRANT_DATA     ";
      D_RELEASE_ACK : io_up_d_payload_opcode_string = "RELEASE_ACK    ";
      default : io_up_d_payload_opcode_string = "???????????????";
    endcase
  end
  always @(*) begin
    case(io_downs_0_a_payload_opcode)
      A_PUT_FULL_DATA : io_downs_0_a_payload_opcode_string = "PUT_FULL_DATA   ";
      A_PUT_PARTIAL_DATA : io_downs_0_a_payload_opcode_string = "PUT_PARTIAL_DATA";
      A_ARITHMETIC_DATA : io_downs_0_a_payload_opcode_string = "ARITHMETIC_DATA ";
      A_LOGICAL_DATA : io_downs_0_a_payload_opcode_string = "LOGICAL_DATA    ";
      A_GET : io_downs_0_a_payload_opcode_string = "GET             ";
      A_ACQUIRE_BLOCK : io_downs_0_a_payload_opcode_string = "ACQUIRE_BLOCK   ";
      A_ACQUIRE_PERM : io_downs_0_a_payload_opcode_string = "ACQUIRE_PERM    ";
      default : io_downs_0_a_payload_opcode_string = "????????????????";
    endcase
  end
  always @(*) begin
    case(io_downs_0_d_payload_opcode)
      D_ACCESS_ACK : io_downs_0_d_payload_opcode_string = "ACCESS_ACK     ";
      D_ACCESS_ACK_DATA : io_downs_0_d_payload_opcode_string = "ACCESS_ACK_DATA";
      D_GRANT : io_downs_0_d_payload_opcode_string = "GRANT          ";
      D_GRANT_DATA : io_downs_0_d_payload_opcode_string = "GRANT_DATA     ";
      D_RELEASE_ACK : io_downs_0_d_payload_opcode_string = "RELEASE_ACK    ";
      default : io_downs_0_d_payload_opcode_string = "???????????????";
    endcase
  end
  always @(*) begin
    case(io_downs_1_a_payload_opcode)
      A_PUT_FULL_DATA : io_downs_1_a_payload_opcode_string = "PUT_FULL_DATA   ";
      A_PUT_PARTIAL_DATA : io_downs_1_a_payload_opcode_string = "PUT_PARTIAL_DATA";
      A_ARITHMETIC_DATA : io_downs_1_a_payload_opcode_string = "ARITHMETIC_DATA ";
      A_LOGICAL_DATA : io_downs_1_a_payload_opcode_string = "LOGICAL_DATA    ";
      A_GET : io_downs_1_a_payload_opcode_string = "GET             ";
      A_ACQUIRE_BLOCK : io_downs_1_a_payload_opcode_string = "ACQUIRE_BLOCK   ";
      A_ACQUIRE_PERM : io_downs_1_a_payload_opcode_string = "ACQUIRE_PERM    ";
      default : io_downs_1_a_payload_opcode_string = "????????????????";
    endcase
  end
  always @(*) begin
    case(io_downs_1_d_payload_opcode)
      D_ACCESS_ACK : io_downs_1_d_payload_opcode_string = "ACCESS_ACK     ";
      D_ACCESS_ACK_DATA : io_downs_1_d_payload_opcode_string = "ACCESS_ACK_DATA";
      D_GRANT : io_downs_1_d_payload_opcode_string = "GRANT          ";
      D_GRANT_DATA : io_downs_1_d_payload_opcode_string = "GRANT_DATA     ";
      D_RELEASE_ACK : io_downs_1_d_payload_opcode_string = "RELEASE_ACK    ";
      default : io_downs_1_d_payload_opcode_string = "???????????????";
    endcase
  end
  always @(*) begin
    case(downs_0_a_payload_opcode)
      A_PUT_FULL_DATA : downs_0_a_payload_opcode_string = "PUT_FULL_DATA   ";
      A_PUT_PARTIAL_DATA : downs_0_a_payload_opcode_string = "PUT_PARTIAL_DATA";
      A_ARITHMETIC_DATA : downs_0_a_payload_opcode_string = "ARITHMETIC_DATA ";
      A_LOGICAL_DATA : downs_0_a_payload_opcode_string = "LOGICAL_DATA    ";
      A_GET : downs_0_a_payload_opcode_string = "GET             ";
      A_ACQUIRE_BLOCK : downs_0_a_payload_opcode_string = "ACQUIRE_BLOCK   ";
      A_ACQUIRE_PERM : downs_0_a_payload_opcode_string = "ACQUIRE_PERM    ";
      default : downs_0_a_payload_opcode_string = "????????????????";
    endcase
  end
  always @(*) begin
    case(downs_0_d_payload_opcode)
      D_ACCESS_ACK : downs_0_d_payload_opcode_string = "ACCESS_ACK     ";
      D_ACCESS_ACK_DATA : downs_0_d_payload_opcode_string = "ACCESS_ACK_DATA";
      D_GRANT : downs_0_d_payload_opcode_string = "GRANT          ";
      D_GRANT_DATA : downs_0_d_payload_opcode_string = "GRANT_DATA     ";
      D_RELEASE_ACK : downs_0_d_payload_opcode_string = "RELEASE_ACK    ";
      default : downs_0_d_payload_opcode_string = "???????????????";
    endcase
  end
  always @(*) begin
    case(downs_1_a_payload_opcode)
      A_PUT_FULL_DATA : downs_1_a_payload_opcode_string = "PUT_FULL_DATA   ";
      A_PUT_PARTIAL_DATA : downs_1_a_payload_opcode_string = "PUT_PARTIAL_DATA";
      A_ARITHMETIC_DATA : downs_1_a_payload_opcode_string = "ARITHMETIC_DATA ";
      A_LOGICAL_DATA : downs_1_a_payload_opcode_string = "LOGICAL_DATA    ";
      A_GET : downs_1_a_payload_opcode_string = "GET             ";
      A_ACQUIRE_BLOCK : downs_1_a_payload_opcode_string = "ACQUIRE_BLOCK   ";
      A_ACQUIRE_PERM : downs_1_a_payload_opcode_string = "ACQUIRE_PERM    ";
      default : downs_1_a_payload_opcode_string = "????????????????";
    endcase
  end
  always @(*) begin
    case(downs_1_d_payload_opcode)
      D_ACCESS_ACK : downs_1_d_payload_opcode_string = "ACCESS_ACK     ";
      D_ACCESS_ACK_DATA : downs_1_d_payload_opcode_string = "ACCESS_ACK_DATA";
      D_GRANT : downs_1_d_payload_opcode_string = "GRANT          ";
      D_GRANT_DATA : downs_1_d_payload_opcode_string = "GRANT_DATA     ";
      D_RELEASE_ACK : downs_1_d_payload_opcode_string = "RELEASE_ACK    ";
      default : downs_1_d_payload_opcode_string = "???????????????";
    endcase
  end
  `endif

  assign io_downs_0_a_valid = downs_0_a_valid;
  assign downs_0_a_ready = io_downs_0_a_ready;
  assign io_downs_0_a_payload_opcode = downs_0_a_payload_opcode;
  assign io_downs_0_a_payload_param = downs_0_a_payload_param;
  assign io_downs_0_a_payload_source = downs_0_a_payload_source;
  assign io_downs_0_a_payload_address = downs_0_a_payload_address;
  assign io_downs_0_a_payload_size = downs_0_a_payload_size;
  assign io_downs_0_a_payload_mask = downs_0_a_payload_mask;
  assign io_downs_0_a_payload_data = downs_0_a_payload_data;
  assign io_downs_0_a_payload_corrupt = downs_0_a_payload_corrupt;
  assign downs_0_d_valid = io_downs_0_d_valid;
  assign io_downs_0_d_ready = downs_0_d_ready;
  assign downs_0_d_payload_opcode = io_downs_0_d_payload_opcode;
  assign downs_0_d_payload_param = io_downs_0_d_payload_param;
  assign downs_0_d_payload_source = io_downs_0_d_payload_source;
  assign downs_0_d_payload_size = io_downs_0_d_payload_size;
  assign downs_0_d_payload_denied = io_downs_0_d_payload_denied;
  assign downs_0_d_payload_data = io_downs_0_d_payload_data;
  assign downs_0_d_payload_corrupt = io_downs_0_d_payload_corrupt;
  assign io_downs_1_a_valid = downs_1_a_valid;
  assign downs_1_a_ready = io_downs_1_a_ready;
  assign io_downs_1_a_payload_opcode = downs_1_a_payload_opcode;
  assign io_downs_1_a_payload_param = downs_1_a_payload_param;
  assign io_downs_1_a_payload_source = downs_1_a_payload_source;
  assign io_downs_1_a_payload_address = downs_1_a_payload_address;
  assign io_downs_1_a_payload_size = downs_1_a_payload_size;
  assign io_downs_1_a_payload_mask = downs_1_a_payload_mask;
  assign io_downs_1_a_payload_data = downs_1_a_payload_data;
  assign io_downs_1_a_payload_corrupt = downs_1_a_payload_corrupt;
  assign downs_1_d_valid = io_downs_1_d_valid;
  assign io_downs_1_d_ready = downs_1_d_ready;
  assign downs_1_d_payload_opcode = io_downs_1_d_payload_opcode;
  assign downs_1_d_payload_param = io_downs_1_d_payload_param;
  assign downs_1_d_payload_source = io_downs_1_d_payload_source;
  assign downs_1_d_payload_size = io_downs_1_d_payload_size;
  assign downs_1_d_payload_denied = io_downs_1_d_payload_denied;
  assign downs_1_d_payload_data = io_downs_1_d_payload_data;
  assign downs_1_d_payload_corrupt = io_downs_1_d_payload_corrupt;
  assign a_key = {io_up_a_payload_opcode,io_up_a_payload_address};
  assign a_logic_0_hit = _zz_a_logic_0_hit[0];
  assign downs_0_a_valid = (io_up_a_valid && a_logic_0_hit);
  assign downs_0_a_payload_opcode = io_up_a_payload_opcode;
  assign downs_0_a_payload_param = io_up_a_payload_param;
  assign downs_0_a_payload_source = io_up_a_payload_source;
  assign downs_0_a_payload_mask = io_up_a_payload_mask;
  assign downs_0_a_payload_data = io_up_a_payload_data;
  assign downs_0_a_payload_corrupt = io_up_a_payload_corrupt;
  assign downs_0_a_payload_address = io_up_a_payload_address;
  assign downs_0_a_payload_size = io_up_a_payload_size[1:0];
  assign a_logic_1_hit = _zz_a_logic_1_hit[0];
  assign downs_1_a_valid = (io_up_a_valid && a_logic_1_hit);
  assign downs_1_a_payload_opcode = io_up_a_payload_opcode;
  assign downs_1_a_payload_param = io_up_a_payload_param;
  assign downs_1_a_payload_source = io_up_a_payload_source;
  assign downs_1_a_payload_mask = io_up_a_payload_mask;
  assign downs_1_a_payload_data = io_up_a_payload_data;
  assign downs_1_a_payload_corrupt = io_up_a_payload_corrupt;
  assign downs_1_a_payload_address = _zz_downs_1_a_payload_address[15:0];
  assign downs_1_a_payload_size = io_up_a_payload_size;
  assign io_up_a_ready = (|{(downs_1_a_ready && a_logic_1_hit),(downs_0_a_ready && a_logic_0_hit)});
  assign a_miss = (! (|{a_logic_1_hit,a_logic_0_hit}));
  assign downs_0_d_ready = d_arbiter_io_inputs_0_ready;
  assign d_arbiter_io_inputs_0_payload_size = {1'd0, downs_0_d_payload_size};
  assign downs_1_d_ready = d_arbiter_io_inputs_1_ready;
  assign io_up_d_valid = d_arbiter_io_output_valid;
  assign io_up_d_payload_opcode = d_arbiter_io_output_payload_opcode;
  assign io_up_d_payload_param = d_arbiter_io_output_payload_param;
  assign io_up_d_payload_source = d_arbiter_io_output_payload_source;
  assign io_up_d_payload_size = d_arbiter_io_output_payload_size;
  assign io_up_d_payload_denied = d_arbiter_io_output_payload_denied;
  assign io_up_d_payload_data = d_arbiter_io_output_payload_data;
  assign io_up_d_payload_corrupt = d_arbiter_io_output_payload_corrupt;
  always @(posedge socCtrl_systemClk or posedge socCtrl_system_reset) begin
    if(socCtrl_system_reset) begin
    end else begin
      `ifndef SYNTHESIS
        `ifdef FORMAL
          assert((! (io_up_a_valid && a_miss))); // Decoder.scala:L108
        `else
          if(!(! (io_up_a_valid && a_miss))) begin
            $display("FAILURE Tilelink decoder miss ???"); // Decoder.scala:L108
            $finish;
          end
        `endif
      `endif
      `ifndef SYNTHESIS
        `ifdef FORMAL
          assert((! (io_up_a_valid && (_zz_1 != 2'b01)))); // Decoder.scala:L109
        `else
          if(!(! (io_up_a_valid && (_zz_1 != 2'b01)))) begin
            $display("FAILURE Tilelink decoder miss ???"); // Decoder.scala:L109
            $finish;
          end
        `endif
      `endif
    end
  end


endmodule
