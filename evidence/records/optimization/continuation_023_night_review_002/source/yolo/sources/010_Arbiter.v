// Source-extraction compilation-unit preamble (not reference payload).
`timescale 1ns/1ps

module Arbiter (
  input  wire          io_ups_0_a_valid,
  output wire          io_ups_0_a_ready,
  input  wire [2:0]    io_ups_0_a_payload_opcode,
  input  wire [2:0]    io_ups_0_a_payload_param,
  input  wire [2:0]    io_ups_0_a_payload_source,
  input  wire [31:0]   io_ups_0_a_payload_address,
  input  wire [2:0]    io_ups_0_a_payload_size,
  output wire          io_ups_0_d_valid,
  input  wire          io_ups_0_d_ready,
  output wire [2:0]    io_ups_0_d_payload_opcode,
  output wire [2:0]    io_ups_0_d_payload_param,
  output wire [2:0]    io_ups_0_d_payload_source,
  output wire [2:0]    io_ups_0_d_payload_size,
  output wire          io_ups_0_d_payload_denied,
  output wire [63:0]   io_ups_0_d_payload_data,
  output wire          io_ups_0_d_payload_corrupt,
  input  wire          io_ups_1_a_valid,
  output wire          io_ups_1_a_ready,
  input  wire [2:0]    io_ups_1_a_payload_opcode,
  input  wire [2:0]    io_ups_1_a_payload_param,
  input  wire [31:0]   io_ups_1_a_payload_address,
  input  wire [1:0]    io_ups_1_a_payload_size,
  input  wire [7:0]    io_ups_1_a_payload_mask,
  input  wire [63:0]   io_ups_1_a_payload_data,
  input  wire          io_ups_1_a_payload_corrupt,
  output wire          io_ups_1_d_valid,
  input  wire          io_ups_1_d_ready,
  output wire [2:0]    io_ups_1_d_payload_opcode,
  output wire [2:0]    io_ups_1_d_payload_param,
  output wire [1:0]    io_ups_1_d_payload_size,
  output wire          io_ups_1_d_payload_denied,
  output wire [63:0]   io_ups_1_d_payload_data,
  output wire          io_ups_1_d_payload_corrupt,
  input  wire          io_ups_2_a_valid,
  output wire          io_ups_2_a_ready,
  input  wire [2:0]    io_ups_2_a_payload_opcode,
  input  wire [2:0]    io_ups_2_a_payload_param,
  input  wire [3:0]    io_ups_2_a_payload_source,
  input  wire [31:0]   io_ups_2_a_payload_address,
  input  wire [2:0]    io_ups_2_a_payload_size,
  input  wire [7:0]    io_ups_2_a_payload_mask,
  input  wire [63:0]   io_ups_2_a_payload_data,
  input  wire          io_ups_2_a_payload_corrupt,
  output wire          io_ups_2_d_valid,
  input  wire          io_ups_2_d_ready,
  output wire [2:0]    io_ups_2_d_payload_opcode,
  output wire [2:0]    io_ups_2_d_payload_param,
  output wire [3:0]    io_ups_2_d_payload_source,
  output wire [2:0]    io_ups_2_d_payload_size,
  output wire          io_ups_2_d_payload_denied,
  output wire [63:0]   io_ups_2_d_payload_data,
  output wire          io_ups_2_d_payload_corrupt,
  output wire          io_down_a_valid,
  input  wire          io_down_a_ready,
  output wire [2:0]    io_down_a_payload_opcode,
  output wire [2:0]    io_down_a_payload_param,
  output wire [5:0]    io_down_a_payload_source,
  output wire [31:0]   io_down_a_payload_address,
  output wire [2:0]    io_down_a_payload_size,
  output wire [7:0]    io_down_a_payload_mask,
  output wire [63:0]   io_down_a_payload_data,
  output wire          io_down_a_payload_corrupt,
  input  wire          io_down_d_valid,
  output wire          io_down_d_ready,
  input  wire [2:0]    io_down_d_payload_opcode,
  input  wire [2:0]    io_down_d_payload_param,
  input  wire [5:0]    io_down_d_payload_source,
  input  wire [2:0]    io_down_d_payload_size,
  input  wire          io_down_d_payload_denied,
  input  wire [63:0]   io_down_d_payload_data,
  input  wire          io_down_d_payload_corrupt,
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

  wire       [2:0]    a_arbiter_io_inputs_1_payload_size;
  wire                a_arbiter_io_inputs_0_ready;
  wire                a_arbiter_io_inputs_1_ready;
  wire                a_arbiter_io_inputs_2_ready;
  wire                a_arbiter_io_output_valid;
  wire       [2:0]    a_arbiter_io_output_payload_opcode;
  wire       [2:0]    a_arbiter_io_output_payload_param;
  wire       [5:0]    a_arbiter_io_output_payload_source;
  wire       [31:0]   a_arbiter_io_output_payload_address;
  wire       [2:0]    a_arbiter_io_output_payload_size;
  wire       [7:0]    a_arbiter_io_output_payload_mask;
  wire       [63:0]   a_arbiter_io_output_payload_data;
  wire                a_arbiter_io_output_payload_corrupt;
  wire       [1:0]    a_arbiter_io_chosen;
  wire       [2:0]    a_arbiter_io_chosenOH;
  wire       [5:0]    _zz_ups_0_a_payload_source;
  wire       [5:0]    _zz_ups_2_a_payload_source;
  reg                 _zz_io_down_d_ready;
  wire                ups_0_a_valid;
  wire                ups_0_a_ready;
  wire       [2:0]    ups_0_a_payload_opcode;
  wire       [2:0]    ups_0_a_payload_param;
  wire       [5:0]    ups_0_a_payload_source;
  wire       [31:0]   ups_0_a_payload_address;
  wire       [2:0]    ups_0_a_payload_size;
  wire                ups_0_d_valid;
  wire                ups_0_d_ready;
  wire       [2:0]    ups_0_d_payload_opcode;
  wire       [2:0]    ups_0_d_payload_param;
  wire       [5:0]    ups_0_d_payload_source;
  wire       [2:0]    ups_0_d_payload_size;
  wire                ups_0_d_payload_denied;
  wire       [63:0]   ups_0_d_payload_data;
  wire                ups_0_d_payload_corrupt;
  wire                ups_1_a_valid;
  wire                ups_1_a_ready;
  wire       [2:0]    ups_1_a_payload_opcode;
  wire       [2:0]    ups_1_a_payload_param;
  wire       [5:0]    ups_1_a_payload_source;
  wire       [31:0]   ups_1_a_payload_address;
  wire       [1:0]    ups_1_a_payload_size;
  wire       [7:0]    ups_1_a_payload_mask;
  wire       [63:0]   ups_1_a_payload_data;
  wire                ups_1_a_payload_corrupt;
  wire                ups_1_d_valid;
  wire                ups_1_d_ready;
  wire       [2:0]    ups_1_d_payload_opcode;
  wire       [2:0]    ups_1_d_payload_param;
  wire       [5:0]    ups_1_d_payload_source;
  wire       [1:0]    ups_1_d_payload_size;
  wire                ups_1_d_payload_denied;
  wire       [63:0]   ups_1_d_payload_data;
  wire                ups_1_d_payload_corrupt;
  wire                ups_2_a_valid;
  wire                ups_2_a_ready;
  wire       [2:0]    ups_2_a_payload_opcode;
  wire       [2:0]    ups_2_a_payload_param;
  wire       [5:0]    ups_2_a_payload_source;
  wire       [31:0]   ups_2_a_payload_address;
  wire       [2:0]    ups_2_a_payload_size;
  wire       [7:0]    ups_2_a_payload_mask;
  wire       [63:0]   ups_2_a_payload_data;
  wire                ups_2_a_payload_corrupt;
  wire                ups_2_d_valid;
  wire                ups_2_d_ready;
  wire       [2:0]    ups_2_d_payload_opcode;
  wire       [2:0]    ups_2_d_payload_param;
  wire       [5:0]    ups_2_d_payload_source;
  wire       [2:0]    ups_2_d_payload_size;
  wire                ups_2_d_payload_denied;
  wire       [63:0]   ups_2_d_payload_data;
  wire                ups_2_d_payload_corrupt;
  wire       [1:0]    d_sel;
  `ifndef SYNTHESIS
  reg [127:0] io_ups_0_a_payload_opcode_string;
  reg [119:0] io_ups_0_d_payload_opcode_string;
  reg [127:0] io_ups_1_a_payload_opcode_string;
  reg [119:0] io_ups_1_d_payload_opcode_string;
  reg [127:0] io_ups_2_a_payload_opcode_string;
  reg [119:0] io_ups_2_d_payload_opcode_string;
  reg [127:0] io_down_a_payload_opcode_string;
  reg [119:0] io_down_d_payload_opcode_string;
  reg [127:0] ups_0_a_payload_opcode_string;
  reg [119:0] ups_0_d_payload_opcode_string;
  reg [127:0] ups_1_a_payload_opcode_string;
  reg [119:0] ups_1_d_payload_opcode_string;
  reg [127:0] ups_2_a_payload_opcode_string;
  reg [119:0] ups_2_d_payload_opcode_string;
  `endif


  assign _zz_ups_0_a_payload_source = {3'd0, io_ups_0_a_payload_source};
  assign _zz_ups_2_a_payload_source = {2'd0, io_ups_2_a_payload_source};
  StreamArbiter_3 a_arbiter (
    .io_inputs_0_valid           (ups_0_a_valid                                                       ), //i
    .io_inputs_0_ready           (a_arbiter_io_inputs_0_ready                                         ), //o
    .io_inputs_0_payload_opcode  (ups_0_a_payload_opcode[2:0]                                         ), //i
    .io_inputs_0_payload_param   (ups_0_a_payload_param[2:0]                                          ), //i
    .io_inputs_0_payload_source  (ups_0_a_payload_source[5:0]                                         ), //i
    .io_inputs_0_payload_address (ups_0_a_payload_address[31:0]                                       ), //i
    .io_inputs_0_payload_size    (ups_0_a_payload_size[2:0]                                           ), //i
    .io_inputs_0_payload_mask    (8'bxxxxxxxx                                                         ), //i
    .io_inputs_0_payload_data    (64'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx), //i
    .io_inputs_0_payload_corrupt (1'b0                                                                ), //i
    .io_inputs_1_valid           (ups_1_a_valid                                                       ), //i
    .io_inputs_1_ready           (a_arbiter_io_inputs_1_ready                                         ), //o
    .io_inputs_1_payload_opcode  (ups_1_a_payload_opcode[2:0]                                         ), //i
    .io_inputs_1_payload_param   (ups_1_a_payload_param[2:0]                                          ), //i
    .io_inputs_1_payload_source  (ups_1_a_payload_source[5:0]                                         ), //i
    .io_inputs_1_payload_address (ups_1_a_payload_address[31:0]                                       ), //i
    .io_inputs_1_payload_size    (a_arbiter_io_inputs_1_payload_size[2:0]                             ), //i
    .io_inputs_1_payload_mask    (ups_1_a_payload_mask[7:0]                                           ), //i
    .io_inputs_1_payload_data    (ups_1_a_payload_data[63:0]                                          ), //i
    .io_inputs_1_payload_corrupt (ups_1_a_payload_corrupt                                             ), //i
    .io_inputs_2_valid           (ups_2_a_valid                                                       ), //i
    .io_inputs_2_ready           (a_arbiter_io_inputs_2_ready                                         ), //o
    .io_inputs_2_payload_opcode  (ups_2_a_payload_opcode[2:0]                                         ), //i
    .io_inputs_2_payload_param   (ups_2_a_payload_param[2:0]                                          ), //i
    .io_inputs_2_payload_source  (ups_2_a_payload_source[5:0]                                         ), //i
    .io_inputs_2_payload_address (ups_2_a_payload_address[31:0]                                       ), //i
    .io_inputs_2_payload_size    (ups_2_a_payload_size[2:0]                                           ), //i
    .io_inputs_2_payload_mask    (ups_2_a_payload_mask[7:0]                                           ), //i
    .io_inputs_2_payload_data    (ups_2_a_payload_data[63:0]                                          ), //i
    .io_inputs_2_payload_corrupt (ups_2_a_payload_corrupt                                             ), //i
    .io_output_valid             (a_arbiter_io_output_valid                                           ), //o
    .io_output_ready             (io_down_a_ready                                                     ), //i
    .io_output_payload_opcode    (a_arbiter_io_output_payload_opcode[2:0]                             ), //o
    .io_output_payload_param     (a_arbiter_io_output_payload_param[2:0]                              ), //o
    .io_output_payload_source    (a_arbiter_io_output_payload_source[5:0]                             ), //o
    .io_output_payload_address   (a_arbiter_io_output_payload_address[31:0]                           ), //o
    .io_output_payload_size      (a_arbiter_io_output_payload_size[2:0]                               ), //o
    .io_output_payload_mask      (a_arbiter_io_output_payload_mask[7:0]                               ), //o
    .io_output_payload_data      (a_arbiter_io_output_payload_data[63:0]                              ), //o
    .io_output_payload_corrupt   (a_arbiter_io_output_payload_corrupt                                 ), //o
    .io_chosen                   (a_arbiter_io_chosen[1:0]                                            ), //o
    .io_chosenOH                 (a_arbiter_io_chosenOH[2:0]                                          ), //o
    .socCtrl_systemClk           (socCtrl_systemClk                                                   ), //i
    .socCtrl_system_reset        (socCtrl_system_reset                                                )  //i
  );
  always @(*) begin
    case(d_sel)
      2'b00 : _zz_io_down_d_ready = ups_0_d_ready;
      2'b01 : _zz_io_down_d_ready = ups_1_d_ready;
      default : _zz_io_down_d_ready = ups_2_d_ready;
    endcase
  end

  `ifndef SYNTHESIS
  always @(*) begin
    case(io_ups_0_a_payload_opcode)
      A_PUT_FULL_DATA : io_ups_0_a_payload_opcode_string = "PUT_FULL_DATA   ";
      A_PUT_PARTIAL_DATA : io_ups_0_a_payload_opcode_string = "PUT_PARTIAL_DATA";
      A_ARITHMETIC_DATA : io_ups_0_a_payload_opcode_string = "ARITHMETIC_DATA ";
      A_LOGICAL_DATA : io_ups_0_a_payload_opcode_string = "LOGICAL_DATA    ";
      A_GET : io_ups_0_a_payload_opcode_string = "GET             ";
      A_ACQUIRE_BLOCK : io_ups_0_a_payload_opcode_string = "ACQUIRE_BLOCK   ";
      A_ACQUIRE_PERM : io_ups_0_a_payload_opcode_string = "ACQUIRE_PERM    ";
      default : io_ups_0_a_payload_opcode_string = "????????????????";
    endcase
  end
  always @(*) begin
    case(io_ups_0_d_payload_opcode)
      D_ACCESS_ACK : io_ups_0_d_payload_opcode_string = "ACCESS_ACK     ";
      D_ACCESS_ACK_DATA : io_ups_0_d_payload_opcode_string = "ACCESS_ACK_DATA";
      D_GRANT : io_ups_0_d_payload_opcode_string = "GRANT          ";
      D_GRANT_DATA : io_ups_0_d_payload_opcode_string = "GRANT_DATA     ";
      D_RELEASE_ACK : io_ups_0_d_payload_opcode_string = "RELEASE_ACK    ";
      default : io_ups_0_d_payload_opcode_string = "???????????????";
    endcase
  end
  always @(*) begin
    case(io_ups_1_a_payload_opcode)
      A_PUT_FULL_DATA : io_ups_1_a_payload_opcode_string = "PUT_FULL_DATA   ";
      A_PUT_PARTIAL_DATA : io_ups_1_a_payload_opcode_string = "PUT_PARTIAL_DATA";
      A_ARITHMETIC_DATA : io_ups_1_a_payload_opcode_string = "ARITHMETIC_DATA ";
      A_LOGICAL_DATA : io_ups_1_a_payload_opcode_string = "LOGICAL_DATA    ";
      A_GET : io_ups_1_a_payload_opcode_string = "GET             ";
      A_ACQUIRE_BLOCK : io_ups_1_a_payload_opcode_string = "ACQUIRE_BLOCK   ";
      A_ACQUIRE_PERM : io_ups_1_a_payload_opcode_string = "ACQUIRE_PERM    ";
      default : io_ups_1_a_payload_opcode_string = "????????????????";
    endcase
  end
  always @(*) begin
    case(io_ups_1_d_payload_opcode)
      D_ACCESS_ACK : io_ups_1_d_payload_opcode_string = "ACCESS_ACK     ";
      D_ACCESS_ACK_DATA : io_ups_1_d_payload_opcode_string = "ACCESS_ACK_DATA";
      D_GRANT : io_ups_1_d_payload_opcode_string = "GRANT          ";
      D_GRANT_DATA : io_ups_1_d_payload_opcode_string = "GRANT_DATA     ";
      D_RELEASE_ACK : io_ups_1_d_payload_opcode_string = "RELEASE_ACK    ";
      default : io_ups_1_d_payload_opcode_string = "???????????????";
    endcase
  end
  always @(*) begin
    case(io_ups_2_a_payload_opcode)
      A_PUT_FULL_DATA : io_ups_2_a_payload_opcode_string = "PUT_FULL_DATA   ";
      A_PUT_PARTIAL_DATA : io_ups_2_a_payload_opcode_string = "PUT_PARTIAL_DATA";
      A_ARITHMETIC_DATA : io_ups_2_a_payload_opcode_string = "ARITHMETIC_DATA ";
      A_LOGICAL_DATA : io_ups_2_a_payload_opcode_string = "LOGICAL_DATA    ";
      A_GET : io_ups_2_a_payload_opcode_string = "GET             ";
      A_ACQUIRE_BLOCK : io_ups_2_a_payload_opcode_string = "ACQUIRE_BLOCK   ";
      A_ACQUIRE_PERM : io_ups_2_a_payload_opcode_string = "ACQUIRE_PERM    ";
      default : io_ups_2_a_payload_opcode_string = "????????????????";
    endcase
  end
  always @(*) begin
    case(io_ups_2_d_payload_opcode)
      D_ACCESS_ACK : io_ups_2_d_payload_opcode_string = "ACCESS_ACK     ";
      D_ACCESS_ACK_DATA : io_ups_2_d_payload_opcode_string = "ACCESS_ACK_DATA";
      D_GRANT : io_ups_2_d_payload_opcode_string = "GRANT          ";
      D_GRANT_DATA : io_ups_2_d_payload_opcode_string = "GRANT_DATA     ";
      D_RELEASE_ACK : io_ups_2_d_payload_opcode_string = "RELEASE_ACK    ";
      default : io_ups_2_d_payload_opcode_string = "???????????????";
    endcase
  end
  always @(*) begin
    case(io_down_a_payload_opcode)
      A_PUT_FULL_DATA : io_down_a_payload_opcode_string = "PUT_FULL_DATA   ";
      A_PUT_PARTIAL_DATA : io_down_a_payload_opcode_string = "PUT_PARTIAL_DATA";
      A_ARITHMETIC_DATA : io_down_a_payload_opcode_string = "ARITHMETIC_DATA ";
      A_LOGICAL_DATA : io_down_a_payload_opcode_string = "LOGICAL_DATA    ";
      A_GET : io_down_a_payload_opcode_string = "GET             ";
      A_ACQUIRE_BLOCK : io_down_a_payload_opcode_string = "ACQUIRE_BLOCK   ";
      A_ACQUIRE_PERM : io_down_a_payload_opcode_string = "ACQUIRE_PERM    ";
      default : io_down_a_payload_opcode_string = "????????????????";
    endcase
  end
  always @(*) begin
    case(io_down_d_payload_opcode)
      D_ACCESS_ACK : io_down_d_payload_opcode_string = "ACCESS_ACK     ";
      D_ACCESS_ACK_DATA : io_down_d_payload_opcode_string = "ACCESS_ACK_DATA";
      D_GRANT : io_down_d_payload_opcode_string = "GRANT          ";
      D_GRANT_DATA : io_down_d_payload_opcode_string = "GRANT_DATA     ";
      D_RELEASE_ACK : io_down_d_payload_opcode_string = "RELEASE_ACK    ";
      default : io_down_d_payload_opcode_string = "???????????????";
    endcase
  end
  always @(*) begin
    case(ups_0_a_payload_opcode)
      A_PUT_FULL_DATA : ups_0_a_payload_opcode_string = "PUT_FULL_DATA   ";
      A_PUT_PARTIAL_DATA : ups_0_a_payload_opcode_string = "PUT_PARTIAL_DATA";
      A_ARITHMETIC_DATA : ups_0_a_payload_opcode_string = "ARITHMETIC_DATA ";
      A_LOGICAL_DATA : ups_0_a_payload_opcode_string = "LOGICAL_DATA    ";
      A_GET : ups_0_a_payload_opcode_string = "GET             ";
      A_ACQUIRE_BLOCK : ups_0_a_payload_opcode_string = "ACQUIRE_BLOCK   ";
      A_ACQUIRE_PERM : ups_0_a_payload_opcode_string = "ACQUIRE_PERM    ";
      default : ups_0_a_payload_opcode_string = "????????????????";
    endcase
  end
  always @(*) begin
    case(ups_0_d_payload_opcode)
      D_ACCESS_ACK : ups_0_d_payload_opcode_string = "ACCESS_ACK     ";
      D_ACCESS_ACK_DATA : ups_0_d_payload_opcode_string = "ACCESS_ACK_DATA";
      D_GRANT : ups_0_d_payload_opcode_string = "GRANT          ";
      D_GRANT_DATA : ups_0_d_payload_opcode_string = "GRANT_DATA     ";
      D_RELEASE_ACK : ups_0_d_payload_opcode_string = "RELEASE_ACK    ";
      default : ups_0_d_payload_opcode_string = "???????????????";
    endcase
  end
  always @(*) begin
    case(ups_1_a_payload_opcode)
      A_PUT_FULL_DATA : ups_1_a_payload_opcode_string = "PUT_FULL_DATA   ";
      A_PUT_PARTIAL_DATA : ups_1_a_payload_opcode_string = "PUT_PARTIAL_DATA";
      A_ARITHMETIC_DATA : ups_1_a_payload_opcode_string = "ARITHMETIC_DATA ";
      A_LOGICAL_DATA : ups_1_a_payload_opcode_string = "LOGICAL_DATA    ";
      A_GET : ups_1_a_payload_opcode_string = "GET             ";
      A_ACQUIRE_BLOCK : ups_1_a_payload_opcode_string = "ACQUIRE_BLOCK   ";
      A_ACQUIRE_PERM : ups_1_a_payload_opcode_string = "ACQUIRE_PERM    ";
      default : ups_1_a_payload_opcode_string = "????????????????";
    endcase
  end
  always @(*) begin
    case(ups_1_d_payload_opcode)
      D_ACCESS_ACK : ups_1_d_payload_opcode_string = "ACCESS_ACK     ";
      D_ACCESS_ACK_DATA : ups_1_d_payload_opcode_string = "ACCESS_ACK_DATA";
      D_GRANT : ups_1_d_payload_opcode_string = "GRANT          ";
      D_GRANT_DATA : ups_1_d_payload_opcode_string = "GRANT_DATA     ";
      D_RELEASE_ACK : ups_1_d_payload_opcode_string = "RELEASE_ACK    ";
      default : ups_1_d_payload_opcode_string = "???????????????";
    endcase
  end
  always @(*) begin
    case(ups_2_a_payload_opcode)
      A_PUT_FULL_DATA : ups_2_a_payload_opcode_string = "PUT_FULL_DATA   ";
      A_PUT_PARTIAL_DATA : ups_2_a_payload_opcode_string = "PUT_PARTIAL_DATA";
      A_ARITHMETIC_DATA : ups_2_a_payload_opcode_string = "ARITHMETIC_DATA ";
      A_LOGICAL_DATA : ups_2_a_payload_opcode_string = "LOGICAL_DATA    ";
      A_GET : ups_2_a_payload_opcode_string = "GET             ";
      A_ACQUIRE_BLOCK : ups_2_a_payload_opcode_string = "ACQUIRE_BLOCK   ";
      A_ACQUIRE_PERM : ups_2_a_payload_opcode_string = "ACQUIRE_PERM    ";
      default : ups_2_a_payload_opcode_string = "????????????????";
    endcase
  end
  always @(*) begin
    case(ups_2_d_payload_opcode)
      D_ACCESS_ACK : ups_2_d_payload_opcode_string = "ACCESS_ACK     ";
      D_ACCESS_ACK_DATA : ups_2_d_payload_opcode_string = "ACCESS_ACK_DATA";
      D_GRANT : ups_2_d_payload_opcode_string = "GRANT          ";
      D_GRANT_DATA : ups_2_d_payload_opcode_string = "GRANT_DATA     ";
      D_RELEASE_ACK : ups_2_d_payload_opcode_string = "RELEASE_ACK    ";
      default : ups_2_d_payload_opcode_string = "???????????????";
    endcase
  end
  `endif

  assign ups_0_a_valid = io_ups_0_a_valid;
  assign io_ups_0_a_ready = ups_0_a_ready;
  assign ups_0_a_payload_opcode = io_ups_0_a_payload_opcode;
  assign ups_0_a_payload_param = io_ups_0_a_payload_param;
  assign ups_0_a_payload_address = io_ups_0_a_payload_address;
  assign ups_0_a_payload_size = io_ups_0_a_payload_size;
  assign io_ups_0_d_valid = ups_0_d_valid;
  assign ups_0_d_ready = io_ups_0_d_ready;
  assign io_ups_0_d_payload_opcode = ups_0_d_payload_opcode;
  assign io_ups_0_d_payload_param = ups_0_d_payload_param;
  assign io_ups_0_d_payload_size = ups_0_d_payload_size;
  assign io_ups_0_d_payload_denied = ups_0_d_payload_denied;
  assign io_ups_0_d_payload_data = ups_0_d_payload_data;
  assign io_ups_0_d_payload_corrupt = ups_0_d_payload_corrupt;
  assign ups_0_a_payload_source = (_zz_ups_0_a_payload_source | 6'h0);
  assign io_ups_0_d_payload_source = ups_0_d_payload_source[2:0];
  assign ups_1_a_valid = io_ups_1_a_valid;
  assign io_ups_1_a_ready = ups_1_a_ready;
  assign ups_1_a_payload_opcode = io_ups_1_a_payload_opcode;
  assign ups_1_a_payload_param = io_ups_1_a_payload_param;
  assign ups_1_a_payload_address = io_ups_1_a_payload_address;
  assign ups_1_a_payload_size = io_ups_1_a_payload_size;
  assign ups_1_a_payload_mask = io_ups_1_a_payload_mask;
  assign ups_1_a_payload_data = io_ups_1_a_payload_data;
  assign ups_1_a_payload_corrupt = io_ups_1_a_payload_corrupt;
  assign io_ups_1_d_valid = ups_1_d_valid;
  assign ups_1_d_ready = io_ups_1_d_ready;
  assign io_ups_1_d_payload_opcode = ups_1_d_payload_opcode;
  assign io_ups_1_d_payload_param = ups_1_d_payload_param;
  assign io_ups_1_d_payload_size = ups_1_d_payload_size;
  assign io_ups_1_d_payload_denied = ups_1_d_payload_denied;
  assign io_ups_1_d_payload_data = ups_1_d_payload_data;
  assign io_ups_1_d_payload_corrupt = ups_1_d_payload_corrupt;
  assign ups_1_a_payload_source = (6'h0 | 6'h10);
  assign ups_2_a_valid = io_ups_2_a_valid;
  assign io_ups_2_a_ready = ups_2_a_ready;
  assign ups_2_a_payload_opcode = io_ups_2_a_payload_opcode;
  assign ups_2_a_payload_param = io_ups_2_a_payload_param;
  assign ups_2_a_payload_address = io_ups_2_a_payload_address;
  assign ups_2_a_payload_size = io_ups_2_a_payload_size;
  assign ups_2_a_payload_mask = io_ups_2_a_payload_mask;
  assign ups_2_a_payload_data = io_ups_2_a_payload_data;
  assign ups_2_a_payload_corrupt = io_ups_2_a_payload_corrupt;
  assign io_ups_2_d_valid = ups_2_d_valid;
  assign ups_2_d_ready = io_ups_2_d_ready;
  assign io_ups_2_d_payload_opcode = ups_2_d_payload_opcode;
  assign io_ups_2_d_payload_param = ups_2_d_payload_param;
  assign io_ups_2_d_payload_size = ups_2_d_payload_size;
  assign io_ups_2_d_payload_denied = ups_2_d_payload_denied;
  assign io_ups_2_d_payload_data = ups_2_d_payload_data;
  assign io_ups_2_d_payload_corrupt = ups_2_d_payload_corrupt;
  assign ups_2_a_payload_source = (_zz_ups_2_a_payload_source | 6'h20);
  assign io_ups_2_d_payload_source = ups_2_d_payload_source[3:0];
  assign ups_0_a_ready = a_arbiter_io_inputs_0_ready;
  assign ups_1_a_ready = a_arbiter_io_inputs_1_ready;
  assign a_arbiter_io_inputs_1_payload_size = {1'd0, ups_1_a_payload_size};
  assign ups_2_a_ready = a_arbiter_io_inputs_2_ready;
  assign io_down_a_valid = a_arbiter_io_output_valid;
  assign io_down_a_payload_opcode = a_arbiter_io_output_payload_opcode;
  assign io_down_a_payload_param = a_arbiter_io_output_payload_param;
  assign io_down_a_payload_source = a_arbiter_io_output_payload_source;
  assign io_down_a_payload_address = a_arbiter_io_output_payload_address;
  assign io_down_a_payload_size = a_arbiter_io_output_payload_size;
  assign io_down_a_payload_mask = a_arbiter_io_output_payload_mask;
  assign io_down_a_payload_data = a_arbiter_io_output_payload_data;
  assign io_down_a_payload_corrupt = a_arbiter_io_output_payload_corrupt;
  assign d_sel = io_down_d_payload_source[5 : 4];
  assign io_down_d_ready = _zz_io_down_d_ready;
  assign ups_0_d_valid = (io_down_d_valid && (d_sel == 2'b00));
  assign ups_0_d_payload_opcode = io_down_d_payload_opcode;
  assign ups_0_d_payload_param = io_down_d_payload_param;
  assign ups_0_d_payload_source = io_down_d_payload_source;
  assign ups_0_d_payload_denied = io_down_d_payload_denied;
  assign ups_0_d_payload_size = io_down_d_payload_size;
  assign ups_0_d_payload_data = io_down_d_payload_data;
  assign ups_0_d_payload_corrupt = io_down_d_payload_corrupt;
  assign ups_1_d_valid = (io_down_d_valid && (d_sel == 2'b01));
  assign ups_1_d_payload_opcode = io_down_d_payload_opcode;
  assign ups_1_d_payload_param = io_down_d_payload_param;
  assign ups_1_d_payload_source = io_down_d_payload_source;
  assign ups_1_d_payload_denied = io_down_d_payload_denied;
  assign ups_1_d_payload_size = io_down_d_payload_size[1:0];
  assign ups_1_d_payload_data = io_down_d_payload_data;
  assign ups_1_d_payload_corrupt = io_down_d_payload_corrupt;
  assign ups_2_d_valid = (io_down_d_valid && (d_sel == 2'b10));
  assign ups_2_d_payload_opcode = io_down_d_payload_opcode;
  assign ups_2_d_payload_param = io_down_d_payload_param;
  assign ups_2_d_payload_source = io_down_d_payload_source;
  assign ups_2_d_payload_denied = io_down_d_payload_denied;
  assign ups_2_d_payload_size = io_down_d_payload_size;
  assign ups_2_d_payload_data = io_down_d_payload_data;
  assign ups_2_d_payload_corrupt = io_down_d_payload_corrupt;

endmodule
