// Source-extraction compilation-unit preamble (not reference payload).
`timescale 1ns/1ps

module WidthAdapter (
  input  wire          io_up_a_valid,
  output wire          io_up_a_ready,
  input  wire [2:0]    io_up_a_payload_opcode,
  input  wire [2:0]    io_up_a_payload_param,
  input  wire [31:0]   io_up_a_payload_address,
  input  wire [1:0]    io_up_a_payload_size,
  input  wire [3:0]    io_up_a_payload_mask,
  input  wire [31:0]   io_up_a_payload_data,
  input  wire          io_up_a_payload_corrupt,
  output wire          io_up_d_valid,
  input  wire          io_up_d_ready,
  output wire [2:0]    io_up_d_payload_opcode,
  output wire [2:0]    io_up_d_payload_param,
  output wire [1:0]    io_up_d_payload_size,
  output wire          io_up_d_payload_denied,
  output wire [31:0]   io_up_d_payload_data,
  output wire          io_up_d_payload_corrupt,
  output wire          io_down_a_valid,
  input  wire          io_down_a_ready,
  output wire [2:0]    io_down_a_payload_opcode,
  output wire [2:0]    io_down_a_payload_param,
  output wire [31:0]   io_down_a_payload_address,
  output wire [1:0]    io_down_a_payload_size,
  output wire [7:0]    io_down_a_payload_mask,
  output wire [63:0]   io_down_a_payload_data,
  output wire          io_down_a_payload_corrupt,
  input  wire          io_down_d_valid,
  output wire          io_down_d_ready,
  input  wire [2:0]    io_down_d_payload_opcode,
  input  wire [2:0]    io_down_d_payload_param,
  input  wire [1:0]    io_down_d_payload_size,
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

  wire                upsize_d_ctx_io_add_valid;
  wire       [0:0]    upsize_d_ctx_io_add_payload_context;
  wire                upsize_d_ctx_io_remove_valid;
  wire                upsize_d_ctx_io_add_ready;
  wire       [0:0]    upsize_d_ctx_io_query_context;
  wire       [31:0]   _zz_upsize_ia_beatAddress;
  wire       [1:0]    _zz_upsize_ia_beatAddress_1;
  wire       [31:0]   _zz_io_up_a_beatAddress;
  wire       [1:0]    _zz_io_up_a_beatAddress_1;
  reg        [31:0]   _zz_io_up_d_payload_data;
  reg                 upsize_iaHalt;
  wire                _zz_io_up_a_ready;
  wire                upsize_ia_valid;
  wire                upsize_ia_ready;
  wire       [2:0]    upsize_ia_payload_opcode;
  wire       [2:0]    upsize_ia_payload_param;
  wire       [31:0]   upsize_ia_payload_address;
  wire       [1:0]    upsize_ia_payload_size;
  wire       [3:0]    upsize_ia_payload_mask;
  wire       [31:0]   upsize_ia_payload_data;
  wire                upsize_ia_payload_corrupt;
  wire                upsize_a_ctrl_burstLast;
  wire                upsize_ia_fire;
  wire       [31:0]   upsize_ia_beatAddress;
  wire       [0:0]    _zz_upsize_a_ctrl_wordLast;
  wire                upsize_a_ctrl_wordLast;
  reg                 upsize_a_ctrl_buffer_valid;
  reg                 upsize_a_ctrl_buffer_first;
  reg        [2:0]    upsize_a_ctrl_buffer_args_opcode;
  reg        [2:0]    upsize_a_ctrl_buffer_args_param;
  reg        [31:0]   upsize_a_ctrl_buffer_args_address;
  reg        [1:0]    upsize_a_ctrl_buffer_args_size;
  reg        [31:0]   upsize_a_ctrl_buffer_data_0;
  reg        [31:0]   upsize_a_ctrl_buffer_data_1;
  reg        [3:0]    upsize_a_ctrl_buffer_mask_0;
  reg        [3:0]    upsize_a_ctrl_buffer_mask_1;
  reg                 upsize_a_ctrl_buffer_corrupt;
  wire       [1:0]    _zz_1;
  wire       [1:0]    _zz_2;
  wire                io_up_a_fire;
  wire                io_up_a_tracker_last;
  wire                when_ContextBuffer_l19;
  wire                io_up_d_fire;
  wire                upsize_d_ctrl_burstLast;
  wire       [31:0]   io_up_a_beatAddress;
  reg        [0:0]    upsize_d_ctrl_counter;
  wire       [0:0]    upsize_d_ctrl_sel;
  `ifndef SYNTHESIS
  reg [127:0] io_up_a_payload_opcode_string;
  reg [119:0] io_up_d_payload_opcode_string;
  reg [127:0] io_down_a_payload_opcode_string;
  reg [119:0] io_down_d_payload_opcode_string;
  reg [127:0] upsize_ia_payload_opcode_string;
  reg [127:0] upsize_a_ctrl_buffer_args_opcode_string;
  `endif


  assign _zz_upsize_ia_beatAddress_1 = 2'b00;
  assign _zz_upsize_ia_beatAddress = {30'd0, _zz_upsize_ia_beatAddress_1};
  assign _zz_io_up_a_beatAddress_1 = 2'b00;
  assign _zz_io_up_a_beatAddress = {30'd0, _zz_io_up_a_beatAddress_1};
  ContextAsyncBufferFull upsize_d_ctx (
    .io_add_valid           (upsize_d_ctx_io_add_valid          ), //i
    .io_add_ready           (upsize_d_ctx_io_add_ready          ), //o
    .io_add_payload_context (upsize_d_ctx_io_add_payload_context), //i
    .io_remove_valid        (upsize_d_ctx_io_remove_valid       ), //i
    .io_query_context       (upsize_d_ctx_io_query_context      ), //o
    .socCtrl_systemClk      (socCtrl_systemClk                  ), //i
    .socCtrl_system_reset   (socCtrl_system_reset               )  //i
  );
  always @(*) begin
    case(upsize_d_ctrl_sel)
      1'b0 : _zz_io_up_d_payload_data = io_down_d_payload_data[31 : 0];
      default : _zz_io_up_d_payload_data = io_down_d_payload_data[63 : 32];
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
    case(upsize_ia_payload_opcode)
      A_PUT_FULL_DATA : upsize_ia_payload_opcode_string = "PUT_FULL_DATA   ";
      A_PUT_PARTIAL_DATA : upsize_ia_payload_opcode_string = "PUT_PARTIAL_DATA";
      A_ARITHMETIC_DATA : upsize_ia_payload_opcode_string = "ARITHMETIC_DATA ";
      A_LOGICAL_DATA : upsize_ia_payload_opcode_string = "LOGICAL_DATA    ";
      A_GET : upsize_ia_payload_opcode_string = "GET             ";
      A_ACQUIRE_BLOCK : upsize_ia_payload_opcode_string = "ACQUIRE_BLOCK   ";
      A_ACQUIRE_PERM : upsize_ia_payload_opcode_string = "ACQUIRE_PERM    ";
      default : upsize_ia_payload_opcode_string = "????????????????";
    endcase
  end
  always @(*) begin
    case(upsize_a_ctrl_buffer_args_opcode)
      A_PUT_FULL_DATA : upsize_a_ctrl_buffer_args_opcode_string = "PUT_FULL_DATA   ";
      A_PUT_PARTIAL_DATA : upsize_a_ctrl_buffer_args_opcode_string = "PUT_PARTIAL_DATA";
      A_ARITHMETIC_DATA : upsize_a_ctrl_buffer_args_opcode_string = "ARITHMETIC_DATA ";
      A_LOGICAL_DATA : upsize_a_ctrl_buffer_args_opcode_string = "LOGICAL_DATA    ";
      A_GET : upsize_a_ctrl_buffer_args_opcode_string = "GET             ";
      A_ACQUIRE_BLOCK : upsize_a_ctrl_buffer_args_opcode_string = "ACQUIRE_BLOCK   ";
      A_ACQUIRE_PERM : upsize_a_ctrl_buffer_args_opcode_string = "ACQUIRE_PERM    ";
      default : upsize_a_ctrl_buffer_args_opcode_string = "????????????????";
    endcase
  end
  `endif

  always @(*) begin
    upsize_iaHalt = 1'b0;
    if(when_ContextBuffer_l19) begin
      upsize_iaHalt = 1'b1;
    end
  end

  assign _zz_io_up_a_ready = (! upsize_iaHalt);
  assign upsize_ia_valid = (io_up_a_valid && _zz_io_up_a_ready);
  assign io_up_a_ready = (upsize_ia_ready && _zz_io_up_a_ready);
  assign upsize_ia_payload_opcode = io_up_a_payload_opcode;
  assign upsize_ia_payload_param = io_up_a_payload_param;
  assign upsize_ia_payload_address = io_up_a_payload_address;
  assign upsize_ia_payload_size = io_up_a_payload_size;
  assign upsize_ia_payload_mask = io_up_a_payload_mask;
  assign upsize_ia_payload_data = io_up_a_payload_data;
  assign upsize_ia_payload_corrupt = io_up_a_payload_corrupt;
  assign upsize_a_ctrl_burstLast = ((! (|{(upsize_ia_payload_opcode == A_LOGICAL_DATA),(upsize_ia_payload_opcode == A_ARITHMETIC_DATA),(upsize_ia_payload_opcode == A_PUT_PARTIAL_DATA),(upsize_ia_payload_opcode == A_PUT_FULL_DATA)})) || 1'b1);
  assign upsize_ia_fire = (upsize_ia_valid && upsize_ia_ready);
  assign upsize_ia_beatAddress = (upsize_ia_payload_address | _zz_upsize_ia_beatAddress);
  assign _zz_upsize_a_ctrl_wordLast = upsize_ia_beatAddress[2 : 2];
  assign upsize_a_ctrl_wordLast = ((&_zz_upsize_a_ctrl_wordLast) || upsize_a_ctrl_burstLast);
  assign io_down_a_valid = upsize_a_ctrl_buffer_valid;
  assign io_down_a_payload_opcode = upsize_a_ctrl_buffer_args_opcode;
  assign io_down_a_payload_param = upsize_a_ctrl_buffer_args_param;
  assign io_down_a_payload_address = upsize_a_ctrl_buffer_args_address;
  assign io_down_a_payload_size = upsize_a_ctrl_buffer_args_size;
  assign io_down_a_payload_mask = {upsize_a_ctrl_buffer_mask_1,upsize_a_ctrl_buffer_mask_0};
  assign io_down_a_payload_data = {upsize_a_ctrl_buffer_data_1,upsize_a_ctrl_buffer_data_0};
  assign io_down_a_payload_corrupt = upsize_a_ctrl_buffer_corrupt;
  assign upsize_ia_ready = ((! upsize_a_ctrl_buffer_valid) || io_down_a_ready);
  assign _zz_1 = ({1'd0,1'b1} <<< _zz_upsize_a_ctrl_wordLast);
  assign _zz_2 = ({1'd0,1'b1} <<< _zz_upsize_a_ctrl_wordLast);
  assign io_up_a_fire = (io_up_a_valid && io_up_a_ready);
  assign io_up_a_tracker_last = ((! (|{(io_up_a_payload_opcode == A_LOGICAL_DATA),(io_up_a_payload_opcode == A_ARITHMETIC_DATA),(io_up_a_payload_opcode == A_PUT_PARTIAL_DATA),(io_up_a_payload_opcode == A_PUT_FULL_DATA)})) || 1'b1);
  assign upsize_d_ctx_io_add_valid = (io_up_a_fire && io_up_a_tracker_last);
  assign when_ContextBuffer_l19 = (! upsize_d_ctx_io_add_ready);
  assign io_up_d_fire = (io_up_d_valid && io_up_d_ready);
  assign upsize_d_ctrl_burstLast = ((! ((1'b0 || (D_ACCESS_ACK_DATA == io_up_d_payload_opcode)) || (D_GRANT_DATA == io_up_d_payload_opcode))) || 1'b1);
  assign upsize_d_ctx_io_remove_valid = ((io_up_d_fire && upsize_d_ctrl_burstLast) && (|{(io_up_d_payload_opcode == D_GRANT_DATA),(io_up_d_payload_opcode == D_GRANT),(io_up_d_payload_opcode == D_ACCESS_ACK_DATA),(io_up_d_payload_opcode == D_ACCESS_ACK)}));
  assign io_up_a_beatAddress = (io_up_a_payload_address | _zz_io_up_a_beatAddress);
  assign upsize_d_ctx_io_add_payload_context = io_up_a_beatAddress[2 : 2];
  assign upsize_d_ctrl_sel = (upsize_d_ctrl_counter + upsize_d_ctx_io_query_context);
  assign io_up_d_valid = io_down_d_valid;
  assign io_up_d_payload_opcode = io_down_d_payload_opcode;
  assign io_up_d_payload_param = io_down_d_payload_param;
  assign io_up_d_payload_size = io_down_d_payload_size;
  assign io_up_d_payload_denied = io_down_d_payload_denied;
  assign io_up_d_payload_corrupt = io_down_d_payload_corrupt;
  assign io_down_d_ready = (io_up_d_ready && ((&upsize_d_ctrl_counter) || upsize_d_ctrl_burstLast));
  assign io_up_d_payload_data = _zz_io_up_d_payload_data;
  always @(posedge socCtrl_systemClk or posedge socCtrl_system_reset) begin
    if(socCtrl_system_reset) begin
      upsize_a_ctrl_buffer_valid <= 1'b0;
      upsize_a_ctrl_buffer_first <= 1'b1;
      upsize_d_ctrl_counter <= 1'b0;
    end else begin
      if(io_down_a_ready) begin
        upsize_a_ctrl_buffer_valid <= 1'b0;
      end
      if(upsize_ia_fire) begin
        upsize_a_ctrl_buffer_valid <= upsize_a_ctrl_wordLast;
        upsize_a_ctrl_buffer_first <= upsize_a_ctrl_wordLast;
      end
      if(io_up_d_fire) begin
        upsize_d_ctrl_counter <= (upsize_d_ctrl_counter + 1'b1);
        if(upsize_d_ctrl_burstLast) begin
          upsize_d_ctrl_counter <= 1'b0;
        end
      end
    end
  end

  always @(posedge socCtrl_systemClk) begin
    if(upsize_ia_fire) begin
      if(upsize_a_ctrl_buffer_first) begin
        upsize_a_ctrl_buffer_args_opcode <= upsize_ia_payload_opcode;
        upsize_a_ctrl_buffer_args_param <= upsize_ia_payload_param;
        upsize_a_ctrl_buffer_args_address <= upsize_ia_payload_address;
        upsize_a_ctrl_buffer_args_size <= upsize_ia_payload_size;
        upsize_a_ctrl_buffer_corrupt <= 1'b0;
        upsize_a_ctrl_buffer_mask_0 <= 4'b0000;
        upsize_a_ctrl_buffer_mask_1 <= 4'b0000;
      end
      if(_zz_1[0]) begin
        upsize_a_ctrl_buffer_data_0 <= upsize_ia_payload_data;
      end
      if(_zz_1[1]) begin
        upsize_a_ctrl_buffer_data_1 <= upsize_ia_payload_data;
      end
      if(_zz_2[0]) begin
        upsize_a_ctrl_buffer_mask_0 <= upsize_ia_payload_mask;
      end
      if(_zz_2[1]) begin
        upsize_a_ctrl_buffer_mask_1 <= upsize_ia_payload_mask;
      end
      if(upsize_ia_payload_corrupt) begin
        upsize_a_ctrl_buffer_corrupt <= 1'b1;
      end
    end
  end


endmodule
