// Source-extraction compilation-unit preamble (not reference payload).
`timescale 1ns/1ps

module WidthAdapter_1 (
  input  wire          io_up_a_valid,
  output wire          io_up_a_ready,
  input  wire [2:0]    io_up_a_payload_opcode,
  input  wire [2:0]    io_up_a_payload_param,
  input  wire [5:0]    io_up_a_payload_source,
  input  wire [28:0]   io_up_a_payload_address,
  input  wire [2:0]    io_up_a_payload_size,
  input  wire [7:0]    io_up_a_payload_mask,
  input  wire [63:0]   io_up_a_payload_data,
  input  wire          io_up_a_payload_corrupt,
  output wire          io_up_d_valid,
  input  wire          io_up_d_ready,
  output wire [2:0]    io_up_d_payload_opcode,
  output wire [2:0]    io_up_d_payload_param,
  output wire [5:0]    io_up_d_payload_source,
  output wire [2:0]    io_up_d_payload_size,
  output wire          io_up_d_payload_denied,
  output wire [63:0]   io_up_d_payload_data,
  output wire          io_up_d_payload_corrupt,
  output wire          io_down_a_valid,
  input  wire          io_down_a_ready,
  output wire [2:0]    io_down_a_payload_opcode,
  output wire [2:0]    io_down_a_payload_param,
  output wire [5:0]    io_down_a_payload_source,
  output wire [28:0]   io_down_a_payload_address,
  output wire [2:0]    io_down_a_payload_size,
  output wire [3:0]    io_down_a_payload_mask,
  output wire [31:0]   io_down_a_payload_data,
  output wire          io_down_a_payload_corrupt,
  input  wire          io_down_d_valid,
  output wire          io_down_d_ready,
  input  wire [2:0]    io_down_d_payload_opcode,
  input  wire [2:0]    io_down_d_payload_param,
  input  wire [5:0]    io_down_d_payload_source,
  input  wire [2:0]    io_down_d_payload_size,
  input  wire          io_down_d_payload_denied,
  input  wire [31:0]   io_down_d_payload_data,
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

  reg        [2:0]    _zz_io_up_a_tracker_last;
  wire       [28:0]   _zz_io_up_a_beatAddress;
  wire       [5:0]    _zz_io_up_a_beatAddress_1;
  reg        [3:0]    _zz_downsize_a_ctrl_burstLast;
  reg        [31:0]   _zz_io_down_a_payload_data;
  reg        [3:0]    _zz_io_down_a_payload_mask;
  reg        [3:0]    _zz_downsize_d_ctrl_burstLast;
  reg        [2:0]    io_up_a_tracker_beat;
  wire                io_up_a_tracker_last;
  wire                io_up_a_fire;
  wire       [28:0]   io_up_a_beatAddress;
  reg        [0:0]    downsize_a_ctrl_counter;
  wire       [0:0]    downsize_a_ctrl_sel;
  reg        [3:0]    io_down_a_tracker_beat;
  wire                downsize_a_ctrl_burstLast;
  wire                io_down_a_fire;
  reg        [3:0]    io_down_d_tracker_beat;
  wire                downsize_d_ctrl_burstLast;
  wire                io_down_d_fire;
  wire       [0:0]    downsize_d_sel;
  wire                downsize_d_ctrl_wordLast;
  reg                 downsize_d_ctrl_buffer_valid;
  reg                 downsize_d_ctrl_buffer_first;
  reg        [2:0]    downsize_d_ctrl_buffer_args_opcode;
  reg        [2:0]    downsize_d_ctrl_buffer_args_param;
  reg        [5:0]    downsize_d_ctrl_buffer_args_source;
  reg        [28:0]   downsize_d_ctrl_buffer_args_address;
  reg        [2:0]    downsize_d_ctrl_buffer_args_size;
  reg        [31:0]   downsize_d_ctrl_buffer_data_0;
  reg        [31:0]   downsize_d_ctrl_buffer_data_1;
  reg                 downsize_d_ctrl_buffer_corrupt;
  reg                 downsize_d_ctrl_buffer_denied;
  wire       [0:0]    _zz_when_WidthAdapter_l84;
  wire                when_WidthAdapter_l84;
  wire                when_WidthAdapter_l84_1;
  `ifndef SYNTHESIS
  reg [127:0] io_up_a_payload_opcode_string;
  reg [119:0] io_up_d_payload_opcode_string;
  reg [127:0] io_down_a_payload_opcode_string;
  reg [119:0] io_down_d_payload_opcode_string;
  reg [127:0] downsize_d_ctrl_buffer_args_opcode_string;
  `endif


  assign _zz_io_up_a_beatAddress_1 = ({3'd0,io_up_a_tracker_beat} <<< 2'd3);
  assign _zz_io_up_a_beatAddress = {23'd0, _zz_io_up_a_beatAddress_1};
  always @(*) begin
    case(io_up_a_payload_size)
      3'b000 : _zz_io_up_a_tracker_last = 3'b000;
      3'b001 : _zz_io_up_a_tracker_last = 3'b000;
      3'b010 : _zz_io_up_a_tracker_last = 3'b000;
      3'b011 : _zz_io_up_a_tracker_last = 3'b000;
      3'b100 : _zz_io_up_a_tracker_last = 3'b001;
      3'b101 : _zz_io_up_a_tracker_last = 3'b011;
      default : _zz_io_up_a_tracker_last = 3'b111;
    endcase
  end

  always @(*) begin
    case(io_down_a_payload_size)
      3'b000 : _zz_downsize_a_ctrl_burstLast = 4'b0000;
      3'b001 : _zz_downsize_a_ctrl_burstLast = 4'b0000;
      3'b010 : _zz_downsize_a_ctrl_burstLast = 4'b0000;
      3'b011 : _zz_downsize_a_ctrl_burstLast = 4'b0001;
      3'b100 : _zz_downsize_a_ctrl_burstLast = 4'b0011;
      3'b101 : _zz_downsize_a_ctrl_burstLast = 4'b0111;
      default : _zz_downsize_a_ctrl_burstLast = 4'b1111;
    endcase
  end

  always @(*) begin
    case(downsize_a_ctrl_sel)
      1'b0 : begin
        _zz_io_down_a_payload_data = io_up_a_payload_data[31 : 0];
        _zz_io_down_a_payload_mask = io_up_a_payload_mask[3 : 0];
      end
      default : begin
        _zz_io_down_a_payload_data = io_up_a_payload_data[63 : 32];
        _zz_io_down_a_payload_mask = io_up_a_payload_mask[7 : 4];
      end
    endcase
  end

  always @(*) begin
    case(io_down_d_payload_size)
      3'b000 : _zz_downsize_d_ctrl_burstLast = 4'b0000;
      3'b001 : _zz_downsize_d_ctrl_burstLast = 4'b0000;
      3'b010 : _zz_downsize_d_ctrl_burstLast = 4'b0000;
      3'b011 : _zz_downsize_d_ctrl_burstLast = 4'b0001;
      3'b100 : _zz_downsize_d_ctrl_burstLast = 4'b0011;
      3'b101 : _zz_downsize_d_ctrl_burstLast = 4'b0111;
      default : _zz_downsize_d_ctrl_burstLast = 4'b1111;
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
    case(downsize_d_ctrl_buffer_args_opcode)
      A_PUT_FULL_DATA : downsize_d_ctrl_buffer_args_opcode_string = "PUT_FULL_DATA   ";
      A_PUT_PARTIAL_DATA : downsize_d_ctrl_buffer_args_opcode_string = "PUT_PARTIAL_DATA";
      A_ARITHMETIC_DATA : downsize_d_ctrl_buffer_args_opcode_string = "ARITHMETIC_DATA ";
      A_LOGICAL_DATA : downsize_d_ctrl_buffer_args_opcode_string = "LOGICAL_DATA    ";
      A_GET : downsize_d_ctrl_buffer_args_opcode_string = "GET             ";
      A_ACQUIRE_BLOCK : downsize_d_ctrl_buffer_args_opcode_string = "ACQUIRE_BLOCK   ";
      A_ACQUIRE_PERM : downsize_d_ctrl_buffer_args_opcode_string = "ACQUIRE_PERM    ";
      default : downsize_d_ctrl_buffer_args_opcode_string = "????????????????";
    endcase
  end
  `endif

  assign io_up_a_tracker_last = ((! (|{(io_up_a_payload_opcode == A_LOGICAL_DATA),(io_up_a_payload_opcode == A_ARITHMETIC_DATA),(io_up_a_payload_opcode == A_PUT_PARTIAL_DATA),(io_up_a_payload_opcode == A_PUT_FULL_DATA)})) || (io_up_a_tracker_beat == _zz_io_up_a_tracker_last));
  assign io_up_a_fire = (io_up_a_valid && io_up_a_ready);
  assign io_up_a_beatAddress = (io_up_a_payload_address | _zz_io_up_a_beatAddress);
  assign downsize_a_ctrl_sel = (downsize_a_ctrl_counter + io_up_a_beatAddress[2 : 2]);
  assign downsize_a_ctrl_burstLast = ((! (|{(io_down_a_payload_opcode == A_LOGICAL_DATA),(io_down_a_payload_opcode == A_ARITHMETIC_DATA),(io_down_a_payload_opcode == A_PUT_PARTIAL_DATA),(io_down_a_payload_opcode == A_PUT_FULL_DATA)})) || (io_down_a_tracker_beat == _zz_downsize_a_ctrl_burstLast));
  assign io_down_a_fire = (io_down_a_valid && io_down_a_ready);
  assign io_down_a_valid = io_up_a_valid;
  assign io_down_a_payload_opcode = io_up_a_payload_opcode;
  assign io_down_a_payload_param = io_up_a_payload_param;
  assign io_down_a_payload_source = io_up_a_payload_source;
  assign io_down_a_payload_address = io_up_a_payload_address;
  assign io_down_a_payload_size = io_up_a_payload_size;
  assign io_down_a_payload_corrupt = io_up_a_payload_corrupt;
  assign io_up_a_ready = (io_down_a_ready && ((&downsize_a_ctrl_counter) || downsize_a_ctrl_burstLast));
  assign io_down_a_payload_data = _zz_io_down_a_payload_data;
  assign io_down_a_payload_mask = _zz_io_down_a_payload_mask;
  assign downsize_d_ctrl_burstLast = ((! ((1'b0 || (D_ACCESS_ACK_DATA == io_down_d_payload_opcode)) || (D_GRANT_DATA == io_down_d_payload_opcode))) || (io_down_d_tracker_beat == _zz_downsize_d_ctrl_burstLast));
  assign io_down_d_fire = (io_down_d_valid && io_down_d_ready);
  assign downsize_d_sel = io_down_d_tracker_beat[0:0];
  assign downsize_d_ctrl_wordLast = ((&downsize_d_sel) || downsize_d_ctrl_burstLast);
  assign io_up_d_valid = downsize_d_ctrl_buffer_valid;
  assign io_up_d_payload_opcode = downsize_d_ctrl_buffer_args_opcode;
  assign io_up_d_payload_param = downsize_d_ctrl_buffer_args_param;
  assign io_up_d_payload_source = downsize_d_ctrl_buffer_args_source;
  assign io_up_d_payload_size = downsize_d_ctrl_buffer_args_size;
  assign io_up_d_payload_data = {downsize_d_ctrl_buffer_data_1,downsize_d_ctrl_buffer_data_0};
  assign io_up_d_payload_corrupt = downsize_d_ctrl_buffer_corrupt;
  assign io_up_d_payload_denied = downsize_d_ctrl_buffer_denied;
  assign io_down_d_ready = ((! downsize_d_ctrl_buffer_valid) || io_up_d_ready);
  assign _zz_when_WidthAdapter_l84 = (3'b011 <= io_down_d_payload_size);
  assign when_WidthAdapter_l84 = (((downsize_d_sel ^ 1'b0) & _zz_when_WidthAdapter_l84) == 1'b0);
  assign when_WidthAdapter_l84_1 = (((downsize_d_sel ^ 1'b1) & _zz_when_WidthAdapter_l84) == 1'b0);
  always @(posedge socCtrl_systemClk or posedge socCtrl_system_reset) begin
    if(socCtrl_system_reset) begin
      io_up_a_tracker_beat <= 3'b000;
      downsize_a_ctrl_counter <= 1'b0;
      io_down_a_tracker_beat <= 4'b0000;
      io_down_d_tracker_beat <= 4'b0000;
      downsize_d_ctrl_buffer_valid <= 1'b0;
      downsize_d_ctrl_buffer_first <= 1'b1;
    end else begin
      if(io_up_a_fire) begin
        io_up_a_tracker_beat <= (io_up_a_tracker_beat + 3'b001);
        if(io_up_a_tracker_last) begin
          io_up_a_tracker_beat <= 3'b000;
        end
      end
      if(io_down_a_fire) begin
        io_down_a_tracker_beat <= (io_down_a_tracker_beat + 4'b0001);
        if(downsize_a_ctrl_burstLast) begin
          io_down_a_tracker_beat <= 4'b0000;
        end
      end
      if(io_down_a_fire) begin
        downsize_a_ctrl_counter <= (downsize_a_ctrl_counter + 1'b1);
        if(downsize_a_ctrl_burstLast) begin
          downsize_a_ctrl_counter <= 1'b0;
        end
      end
      if(io_down_d_fire) begin
        io_down_d_tracker_beat <= (io_down_d_tracker_beat + 4'b0001);
        if(downsize_d_ctrl_burstLast) begin
          io_down_d_tracker_beat <= 4'b0000;
        end
      end
      if(io_up_d_ready) begin
        downsize_d_ctrl_buffer_valid <= 1'b0;
      end
      if(io_down_d_fire) begin
        downsize_d_ctrl_buffer_valid <= downsize_d_ctrl_wordLast;
        downsize_d_ctrl_buffer_first <= downsize_d_ctrl_wordLast;
      end
    end
  end

  always @(posedge socCtrl_systemClk) begin
    if(io_down_d_fire) begin
      if(downsize_d_ctrl_buffer_first) begin
        downsize_d_ctrl_buffer_args_opcode <= io_down_d_payload_opcode;
        downsize_d_ctrl_buffer_args_param <= io_down_d_payload_param;
        downsize_d_ctrl_buffer_args_source <= io_down_d_payload_source;
        downsize_d_ctrl_buffer_args_size <= io_down_d_payload_size;
        downsize_d_ctrl_buffer_corrupt <= 1'b0;
        downsize_d_ctrl_buffer_denied <= 1'b0;
      end
      if(when_WidthAdapter_l84) begin
        downsize_d_ctrl_buffer_data_0 <= io_down_d_payload_data;
      end
      if(when_WidthAdapter_l84_1) begin
        downsize_d_ctrl_buffer_data_1 <= io_down_d_payload_data;
      end
      if(io_down_d_payload_corrupt) begin
        downsize_d_ctrl_buffer_corrupt <= 1'b1;
      end
      if(io_down_d_payload_denied) begin
        downsize_d_ctrl_buffer_denied <= 1'b1;
      end
    end
  end


endmodule
