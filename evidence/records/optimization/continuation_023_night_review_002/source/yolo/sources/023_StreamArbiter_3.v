// Source-extraction compilation-unit preamble (not reference payload).
`timescale 1ns/1ps

module StreamArbiter_3 (
  input  wire          io_inputs_0_valid,
  output wire          io_inputs_0_ready,
  input  wire [2:0]    io_inputs_0_payload_opcode,
  input  wire [2:0]    io_inputs_0_payload_param,
  input  wire [5:0]    io_inputs_0_payload_source,
  input  wire [31:0]   io_inputs_0_payload_address,
  input  wire [2:0]    io_inputs_0_payload_size,
  input  wire [7:0]    io_inputs_0_payload_mask,
  input  wire [63:0]   io_inputs_0_payload_data,
  input  wire          io_inputs_0_payload_corrupt,
  input  wire          io_inputs_1_valid,
  output wire          io_inputs_1_ready,
  input  wire [2:0]    io_inputs_1_payload_opcode,
  input  wire [2:0]    io_inputs_1_payload_param,
  input  wire [5:0]    io_inputs_1_payload_source,
  input  wire [31:0]   io_inputs_1_payload_address,
  input  wire [2:0]    io_inputs_1_payload_size,
  input  wire [7:0]    io_inputs_1_payload_mask,
  input  wire [63:0]   io_inputs_1_payload_data,
  input  wire          io_inputs_1_payload_corrupt,
  input  wire          io_inputs_2_valid,
  output wire          io_inputs_2_ready,
  input  wire [2:0]    io_inputs_2_payload_opcode,
  input  wire [2:0]    io_inputs_2_payload_param,
  input  wire [5:0]    io_inputs_2_payload_source,
  input  wire [31:0]   io_inputs_2_payload_address,
  input  wire [2:0]    io_inputs_2_payload_size,
  input  wire [7:0]    io_inputs_2_payload_mask,
  input  wire [63:0]   io_inputs_2_payload_data,
  input  wire          io_inputs_2_payload_corrupt,
  output wire          io_output_valid,
  input  wire          io_output_ready,
  output wire [2:0]    io_output_payload_opcode,
  output wire [2:0]    io_output_payload_param,
  output wire [5:0]    io_output_payload_source,
  output wire [31:0]   io_output_payload_address,
  output wire [2:0]    io_output_payload_size,
  output wire [7:0]    io_output_payload_mask,
  output wire [63:0]   io_output_payload_data,
  output wire          io_output_payload_corrupt,
  output wire [1:0]    io_chosen,
  output wire [2:0]    io_chosenOH,
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

  wire       [5:0]    _zz__zz_maskProposal_0_2;
  wire       [5:0]    _zz__zz_maskProposal_0_2_1;
  wire       [2:0]    _zz__zz_maskProposal_0_2_2;
  reg        [2:0]    _zz_io_output_tracker_last;
  reg        [2:0]    _zz__zz_io_output_payload_opcode;
  reg        [2:0]    _zz_io_output_payload_param_1;
  reg        [5:0]    _zz_io_output_payload_source;
  reg        [31:0]   _zz_io_output_payload_address;
  reg        [2:0]    _zz_io_output_payload_size;
  reg        [7:0]    _zz_io_output_payload_mask;
  reg        [63:0]   _zz_io_output_payload_data;
  reg                 _zz_io_output_payload_corrupt;
  reg                 locked;
  wire                maskProposal_0;
  wire                maskProposal_1;
  wire                maskProposal_2;
  reg                 maskLocked_0;
  reg                 maskLocked_1;
  reg                 maskLocked_2;
  wire                maskRouted_0;
  wire                maskRouted_1;
  wire                maskRouted_2;
  wire       [2:0]    _zz_maskProposal_0;
  wire       [5:0]    _zz_maskProposal_0_1;
  wire       [5:0]    _zz_maskProposal_0_2;
  wire       [2:0]    _zz_maskProposal_0_3;
  wire                io_output_fire;
  reg        [2:0]    io_output_tracker_beat;
  wire                io_output_tracker_last;
  wire                when_Stream_l871;
  wire       [1:0]    _zz_io_output_payload_param;
  wire       [2:0]    _zz_io_output_payload_opcode;
  wire                _zz_io_chosen;
  wire                _zz_io_chosen_1;
  `ifndef SYNTHESIS
  reg [127:0] io_inputs_0_payload_opcode_string;
  reg [127:0] io_inputs_1_payload_opcode_string;
  reg [127:0] io_inputs_2_payload_opcode_string;
  reg [127:0] io_output_payload_opcode_string;
  reg [127:0] _zz_io_output_payload_opcode_string;
  `endif


  assign _zz__zz_maskProposal_0_2 = (_zz_maskProposal_0_1 - _zz__zz_maskProposal_0_2_1);
  assign _zz__zz_maskProposal_0_2_2 = {maskLocked_1,maskLocked_0,maskLocked_2};
  assign _zz__zz_maskProposal_0_2_1 = {3'd0, _zz__zz_maskProposal_0_2_2};
  always @(*) begin
    case(io_output_payload_size)
      3'b000 : _zz_io_output_tracker_last = 3'b000;
      3'b001 : _zz_io_output_tracker_last = 3'b000;
      3'b010 : _zz_io_output_tracker_last = 3'b000;
      3'b011 : _zz_io_output_tracker_last = 3'b000;
      3'b100 : _zz_io_output_tracker_last = 3'b001;
      3'b101 : _zz_io_output_tracker_last = 3'b011;
      default : _zz_io_output_tracker_last = 3'b111;
    endcase
  end

  always @(*) begin
    case(_zz_io_output_payload_param)
      2'b00 : begin
        _zz__zz_io_output_payload_opcode = io_inputs_0_payload_opcode;
        _zz_io_output_payload_param_1 = io_inputs_0_payload_param;
        _zz_io_output_payload_source = io_inputs_0_payload_source;
        _zz_io_output_payload_address = io_inputs_0_payload_address;
        _zz_io_output_payload_size = io_inputs_0_payload_size;
        _zz_io_output_payload_mask = io_inputs_0_payload_mask;
        _zz_io_output_payload_data = io_inputs_0_payload_data;
        _zz_io_output_payload_corrupt = io_inputs_0_payload_corrupt;
      end
      2'b01 : begin
        _zz__zz_io_output_payload_opcode = io_inputs_1_payload_opcode;
        _zz_io_output_payload_param_1 = io_inputs_1_payload_param;
        _zz_io_output_payload_source = io_inputs_1_payload_source;
        _zz_io_output_payload_address = io_inputs_1_payload_address;
        _zz_io_output_payload_size = io_inputs_1_payload_size;
        _zz_io_output_payload_mask = io_inputs_1_payload_mask;
        _zz_io_output_payload_data = io_inputs_1_payload_data;
        _zz_io_output_payload_corrupt = io_inputs_1_payload_corrupt;
      end
      default : begin
        _zz__zz_io_output_payload_opcode = io_inputs_2_payload_opcode;
        _zz_io_output_payload_param_1 = io_inputs_2_payload_param;
        _zz_io_output_payload_source = io_inputs_2_payload_source;
        _zz_io_output_payload_address = io_inputs_2_payload_address;
        _zz_io_output_payload_size = io_inputs_2_payload_size;
        _zz_io_output_payload_mask = io_inputs_2_payload_mask;
        _zz_io_output_payload_data = io_inputs_2_payload_data;
        _zz_io_output_payload_corrupt = io_inputs_2_payload_corrupt;
      end
    endcase
  end

  `ifndef SYNTHESIS
  always @(*) begin
    case(io_inputs_0_payload_opcode)
      A_PUT_FULL_DATA : io_inputs_0_payload_opcode_string = "PUT_FULL_DATA   ";
      A_PUT_PARTIAL_DATA : io_inputs_0_payload_opcode_string = "PUT_PARTIAL_DATA";
      A_ARITHMETIC_DATA : io_inputs_0_payload_opcode_string = "ARITHMETIC_DATA ";
      A_LOGICAL_DATA : io_inputs_0_payload_opcode_string = "LOGICAL_DATA    ";
      A_GET : io_inputs_0_payload_opcode_string = "GET             ";
      A_ACQUIRE_BLOCK : io_inputs_0_payload_opcode_string = "ACQUIRE_BLOCK   ";
      A_ACQUIRE_PERM : io_inputs_0_payload_opcode_string = "ACQUIRE_PERM    ";
      default : io_inputs_0_payload_opcode_string = "????????????????";
    endcase
  end
  always @(*) begin
    case(io_inputs_1_payload_opcode)
      A_PUT_FULL_DATA : io_inputs_1_payload_opcode_string = "PUT_FULL_DATA   ";
      A_PUT_PARTIAL_DATA : io_inputs_1_payload_opcode_string = "PUT_PARTIAL_DATA";
      A_ARITHMETIC_DATA : io_inputs_1_payload_opcode_string = "ARITHMETIC_DATA ";
      A_LOGICAL_DATA : io_inputs_1_payload_opcode_string = "LOGICAL_DATA    ";
      A_GET : io_inputs_1_payload_opcode_string = "GET             ";
      A_ACQUIRE_BLOCK : io_inputs_1_payload_opcode_string = "ACQUIRE_BLOCK   ";
      A_ACQUIRE_PERM : io_inputs_1_payload_opcode_string = "ACQUIRE_PERM    ";
      default : io_inputs_1_payload_opcode_string = "????????????????";
    endcase
  end
  always @(*) begin
    case(io_inputs_2_payload_opcode)
      A_PUT_FULL_DATA : io_inputs_2_payload_opcode_string = "PUT_FULL_DATA   ";
      A_PUT_PARTIAL_DATA : io_inputs_2_payload_opcode_string = "PUT_PARTIAL_DATA";
      A_ARITHMETIC_DATA : io_inputs_2_payload_opcode_string = "ARITHMETIC_DATA ";
      A_LOGICAL_DATA : io_inputs_2_payload_opcode_string = "LOGICAL_DATA    ";
      A_GET : io_inputs_2_payload_opcode_string = "GET             ";
      A_ACQUIRE_BLOCK : io_inputs_2_payload_opcode_string = "ACQUIRE_BLOCK   ";
      A_ACQUIRE_PERM : io_inputs_2_payload_opcode_string = "ACQUIRE_PERM    ";
      default : io_inputs_2_payload_opcode_string = "????????????????";
    endcase
  end
  always @(*) begin
    case(io_output_payload_opcode)
      A_PUT_FULL_DATA : io_output_payload_opcode_string = "PUT_FULL_DATA   ";
      A_PUT_PARTIAL_DATA : io_output_payload_opcode_string = "PUT_PARTIAL_DATA";
      A_ARITHMETIC_DATA : io_output_payload_opcode_string = "ARITHMETIC_DATA ";
      A_LOGICAL_DATA : io_output_payload_opcode_string = "LOGICAL_DATA    ";
      A_GET : io_output_payload_opcode_string = "GET             ";
      A_ACQUIRE_BLOCK : io_output_payload_opcode_string = "ACQUIRE_BLOCK   ";
      A_ACQUIRE_PERM : io_output_payload_opcode_string = "ACQUIRE_PERM    ";
      default : io_output_payload_opcode_string = "????????????????";
    endcase
  end
  always @(*) begin
    case(_zz_io_output_payload_opcode)
      A_PUT_FULL_DATA : _zz_io_output_payload_opcode_string = "PUT_FULL_DATA   ";
      A_PUT_PARTIAL_DATA : _zz_io_output_payload_opcode_string = "PUT_PARTIAL_DATA";
      A_ARITHMETIC_DATA : _zz_io_output_payload_opcode_string = "ARITHMETIC_DATA ";
      A_LOGICAL_DATA : _zz_io_output_payload_opcode_string = "LOGICAL_DATA    ";
      A_GET : _zz_io_output_payload_opcode_string = "GET             ";
      A_ACQUIRE_BLOCK : _zz_io_output_payload_opcode_string = "ACQUIRE_BLOCK   ";
      A_ACQUIRE_PERM : _zz_io_output_payload_opcode_string = "ACQUIRE_PERM    ";
      default : _zz_io_output_payload_opcode_string = "????????????????";
    endcase
  end
  `endif

  assign maskRouted_0 = (locked ? maskLocked_0 : maskProposal_0);
  assign maskRouted_1 = (locked ? maskLocked_1 : maskProposal_1);
  assign maskRouted_2 = (locked ? maskLocked_2 : maskProposal_2);
  assign _zz_maskProposal_0 = {io_inputs_2_valid,io_inputs_1_valid,io_inputs_0_valid};
  assign _zz_maskProposal_0_1 = {_zz_maskProposal_0,_zz_maskProposal_0};
  assign _zz_maskProposal_0_2 = (_zz_maskProposal_0_1 & (~ _zz__zz_maskProposal_0_2));
  assign _zz_maskProposal_0_3 = (_zz_maskProposal_0_2[5 : 3] | _zz_maskProposal_0_2[2 : 0]);
  assign maskProposal_0 = _zz_maskProposal_0_3[0];
  assign maskProposal_1 = _zz_maskProposal_0_3[1];
  assign maskProposal_2 = _zz_maskProposal_0_3[2];
  assign io_output_fire = (io_output_valid && io_output_ready);
  assign io_output_tracker_last = ((! (|{(io_output_payload_opcode == A_LOGICAL_DATA),(io_output_payload_opcode == A_ARITHMETIC_DATA),(io_output_payload_opcode == A_PUT_PARTIAL_DATA),(io_output_payload_opcode == A_PUT_FULL_DATA)})) || (io_output_tracker_beat == _zz_io_output_tracker_last));
  assign when_Stream_l871 = (io_output_fire && io_output_tracker_last);
  assign io_output_valid = (((io_inputs_0_valid && maskRouted_0) || (io_inputs_1_valid && maskRouted_1)) || (io_inputs_2_valid && maskRouted_2));
  assign _zz_io_output_payload_param = {maskRouted_2,maskRouted_1};
  assign _zz_io_output_payload_opcode = _zz__zz_io_output_payload_opcode;
  assign io_output_payload_opcode = _zz_io_output_payload_opcode;
  assign io_output_payload_param = _zz_io_output_payload_param_1;
  assign io_output_payload_source = _zz_io_output_payload_source;
  assign io_output_payload_address = _zz_io_output_payload_address;
  assign io_output_payload_size = _zz_io_output_payload_size;
  assign io_output_payload_mask = _zz_io_output_payload_mask;
  assign io_output_payload_data = _zz_io_output_payload_data;
  assign io_output_payload_corrupt = _zz_io_output_payload_corrupt;
  assign io_inputs_0_ready = (maskRouted_0 && io_output_ready);
  assign io_inputs_1_ready = (maskRouted_1 && io_output_ready);
  assign io_inputs_2_ready = (maskRouted_2 && io_output_ready);
  assign io_chosenOH = {maskRouted_2,maskRouted_1,maskRouted_0};
  assign _zz_io_chosen = io_chosenOH[1];
  assign _zz_io_chosen_1 = io_chosenOH[2];
  assign io_chosen = {_zz_io_chosen_1,_zz_io_chosen};
  always @(posedge socCtrl_systemClk or posedge socCtrl_system_reset) begin
    if(socCtrl_system_reset) begin
      locked <= 1'b0;
      maskLocked_0 <= 1'b0;
      maskLocked_1 <= 1'b0;
      maskLocked_2 <= 1'b1;
      io_output_tracker_beat <= 3'b000;
    end else begin
      if(io_output_valid) begin
        maskLocked_0 <= maskRouted_0;
        maskLocked_1 <= maskRouted_1;
        maskLocked_2 <= maskRouted_2;
      end
      if(io_output_valid) begin
        locked <= 1'b1;
      end
      if(io_output_fire) begin
        io_output_tracker_beat <= (io_output_tracker_beat + 3'b001);
        if(io_output_tracker_last) begin
          io_output_tracker_beat <= 3'b000;
        end
      end
      if(when_Stream_l871) begin
        locked <= 1'b0;
      end
    end
  end


endmodule
