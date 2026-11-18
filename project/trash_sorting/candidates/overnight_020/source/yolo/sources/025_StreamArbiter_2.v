// Source-extraction compilation-unit preamble (not reference payload).
`timescale 1ns/1ps

module StreamArbiter_2 (
  input  wire          io_inputs_0_valid,
  output wire          io_inputs_0_ready,
  input  wire [2:0]    io_inputs_0_payload_op,
  input  wire [31:0]   io_inputs_0_payload_address,
  input  wire [1:0]    io_inputs_0_payload_size,
  input  wire          io_inputs_0_payload_load,
  input  wire          io_inputs_0_payload_store,
  input  wire          io_inputs_0_payload_execute,
  input  wire          io_inputs_0_payload_atomic,
  input  wire          io_inputs_0_payload_clean,
  input  wire          io_inputs_0_payload_invalidate,
  input  wire          io_inputs_0_payload_guest,
  input  wire [11:0]   io_inputs_0_payload_storeId,
  input  wire          io_inputs_1_valid,
  output wire          io_inputs_1_ready,
  input  wire [2:0]    io_inputs_1_payload_op,
  input  wire [31:0]   io_inputs_1_payload_address,
  input  wire [1:0]    io_inputs_1_payload_size,
  input  wire          io_inputs_1_payload_load,
  input  wire          io_inputs_1_payload_store,
  input  wire          io_inputs_1_payload_execute,
  input  wire          io_inputs_1_payload_atomic,
  input  wire          io_inputs_1_payload_clean,
  input  wire          io_inputs_1_payload_invalidate,
  input  wire          io_inputs_1_payload_guest,
  input  wire [11:0]   io_inputs_1_payload_storeId,
  input  wire          io_inputs_2_valid,
  output wire          io_inputs_2_ready,
  input  wire [2:0]    io_inputs_2_payload_op,
  input  wire [31:0]   io_inputs_2_payload_address,
  input  wire [1:0]    io_inputs_2_payload_size,
  input  wire          io_inputs_2_payload_load,
  input  wire          io_inputs_2_payload_store,
  input  wire          io_inputs_2_payload_execute,
  input  wire          io_inputs_2_payload_atomic,
  input  wire          io_inputs_2_payload_clean,
  input  wire          io_inputs_2_payload_invalidate,
  input  wire          io_inputs_2_payload_guest,
  input  wire [11:0]   io_inputs_2_payload_storeId,
  input  wire          io_inputs_3_valid,
  output wire          io_inputs_3_ready,
  input  wire [2:0]    io_inputs_3_payload_op,
  input  wire [31:0]   io_inputs_3_payload_address,
  input  wire [1:0]    io_inputs_3_payload_size,
  input  wire          io_inputs_3_payload_load,
  input  wire          io_inputs_3_payload_store,
  input  wire          io_inputs_3_payload_execute,
  input  wire          io_inputs_3_payload_atomic,
  input  wire          io_inputs_3_payload_clean,
  input  wire          io_inputs_3_payload_invalidate,
  input  wire          io_inputs_3_payload_guest,
  input  wire [11:0]   io_inputs_3_payload_storeId,
  output wire          io_output_valid,
  input  wire          io_output_ready,
  output wire [2:0]    io_output_payload_op,
  output wire [31:0]   io_output_payload_address,
  output wire [1:0]    io_output_payload_size,
  output wire          io_output_payload_load,
  output wire          io_output_payload_store,
  output wire          io_output_payload_execute,
  output wire          io_output_payload_atomic,
  output wire          io_output_payload_clean,
  output wire          io_output_payload_invalidate,
  output wire          io_output_payload_guest,
  output wire [11:0]   io_output_payload_storeId,
  output wire [1:0]    io_chosen,
  output wire [3:0]    io_chosenOH
);
  localparam LsuL1CmdOpcode_LSU = 3'd0;
  localparam LsuL1CmdOpcode_ACCESS_1 = 3'd1;
  localparam LsuL1CmdOpcode_STORE_BUFFER = 3'd2;
  localparam LsuL1CmdOpcode_FLUSH = 3'd3;
  localparam LsuL1CmdOpcode_PREFETCH = 3'd4;

  wire       [3:0]    _zz__zz_maskProposal_1_1;
  reg        [2:0]    _zz__zz_io_output_payload_op;
  reg        [31:0]   _zz_io_output_payload_address_3;
  reg        [1:0]    _zz_io_output_payload_size;
  reg                 _zz_io_output_payload_load;
  reg                 _zz_io_output_payload_store;
  reg                 _zz_io_output_payload_execute;
  reg                 _zz_io_output_payload_atomic;
  reg                 _zz_io_output_payload_clean;
  reg                 _zz_io_output_payload_invalidate;
  reg                 _zz_io_output_payload_guest;
  reg        [11:0]   _zz_io_output_payload_storeId;
  wire                maskProposal_0;
  wire                maskProposal_1;
  wire                maskProposal_2;
  wire                maskProposal_3;
  wire       [3:0]    _zz_maskProposal_1;
  wire       [3:0]    _zz_maskProposal_1_1;
  wire                _zz_io_output_payload_address;
  wire                _zz_io_output_payload_address_1;
  wire       [1:0]    _zz_io_output_payload_address_2;
  wire       [2:0]    _zz_io_output_payload_op;
  wire                _zz_io_chosen;
  wire                _zz_io_chosen_1;
  wire                _zz_io_chosen_2;
  `ifndef SYNTHESIS
  reg [95:0] io_inputs_0_payload_op_string;
  reg [95:0] io_inputs_1_payload_op_string;
  reg [95:0] io_inputs_2_payload_op_string;
  reg [95:0] io_inputs_3_payload_op_string;
  reg [95:0] io_output_payload_op_string;
  reg [95:0] _zz_io_output_payload_op_string;
  `endif


  assign _zz__zz_maskProposal_1_1 = (_zz_maskProposal_1 - 4'b0001);
  always @(*) begin
    case(_zz_io_output_payload_address_2)
      2'b00 : begin
        _zz__zz_io_output_payload_op = io_inputs_0_payload_op;
        _zz_io_output_payload_address_3 = io_inputs_0_payload_address;
        _zz_io_output_payload_size = io_inputs_0_payload_size;
        _zz_io_output_payload_load = io_inputs_0_payload_load;
        _zz_io_output_payload_store = io_inputs_0_payload_store;
        _zz_io_output_payload_execute = io_inputs_0_payload_execute;
        _zz_io_output_payload_atomic = io_inputs_0_payload_atomic;
        _zz_io_output_payload_clean = io_inputs_0_payload_clean;
        _zz_io_output_payload_invalidate = io_inputs_0_payload_invalidate;
        _zz_io_output_payload_guest = io_inputs_0_payload_guest;
        _zz_io_output_payload_storeId = io_inputs_0_payload_storeId;
      end
      2'b01 : begin
        _zz__zz_io_output_payload_op = io_inputs_1_payload_op;
        _zz_io_output_payload_address_3 = io_inputs_1_payload_address;
        _zz_io_output_payload_size = io_inputs_1_payload_size;
        _zz_io_output_payload_load = io_inputs_1_payload_load;
        _zz_io_output_payload_store = io_inputs_1_payload_store;
        _zz_io_output_payload_execute = io_inputs_1_payload_execute;
        _zz_io_output_payload_atomic = io_inputs_1_payload_atomic;
        _zz_io_output_payload_clean = io_inputs_1_payload_clean;
        _zz_io_output_payload_invalidate = io_inputs_1_payload_invalidate;
        _zz_io_output_payload_guest = io_inputs_1_payload_guest;
        _zz_io_output_payload_storeId = io_inputs_1_payload_storeId;
      end
      2'b10 : begin
        _zz__zz_io_output_payload_op = io_inputs_2_payload_op;
        _zz_io_output_payload_address_3 = io_inputs_2_payload_address;
        _zz_io_output_payload_size = io_inputs_2_payload_size;
        _zz_io_output_payload_load = io_inputs_2_payload_load;
        _zz_io_output_payload_store = io_inputs_2_payload_store;
        _zz_io_output_payload_execute = io_inputs_2_payload_execute;
        _zz_io_output_payload_atomic = io_inputs_2_payload_atomic;
        _zz_io_output_payload_clean = io_inputs_2_payload_clean;
        _zz_io_output_payload_invalidate = io_inputs_2_payload_invalidate;
        _zz_io_output_payload_guest = io_inputs_2_payload_guest;
        _zz_io_output_payload_storeId = io_inputs_2_payload_storeId;
      end
      default : begin
        _zz__zz_io_output_payload_op = io_inputs_3_payload_op;
        _zz_io_output_payload_address_3 = io_inputs_3_payload_address;
        _zz_io_output_payload_size = io_inputs_3_payload_size;
        _zz_io_output_payload_load = io_inputs_3_payload_load;
        _zz_io_output_payload_store = io_inputs_3_payload_store;
        _zz_io_output_payload_execute = io_inputs_3_payload_execute;
        _zz_io_output_payload_atomic = io_inputs_3_payload_atomic;
        _zz_io_output_payload_clean = io_inputs_3_payload_clean;
        _zz_io_output_payload_invalidate = io_inputs_3_payload_invalidate;
        _zz_io_output_payload_guest = io_inputs_3_payload_guest;
        _zz_io_output_payload_storeId = io_inputs_3_payload_storeId;
      end
    endcase
  end

  `ifndef SYNTHESIS
  always @(*) begin
    case(io_inputs_0_payload_op)
      LsuL1CmdOpcode_LSU : io_inputs_0_payload_op_string = "LSU         ";
      LsuL1CmdOpcode_ACCESS_1 : io_inputs_0_payload_op_string = "ACCESS_1    ";
      LsuL1CmdOpcode_STORE_BUFFER : io_inputs_0_payload_op_string = "STORE_BUFFER";
      LsuL1CmdOpcode_FLUSH : io_inputs_0_payload_op_string = "FLUSH       ";
      LsuL1CmdOpcode_PREFETCH : io_inputs_0_payload_op_string = "PREFETCH    ";
      default : io_inputs_0_payload_op_string = "????????????";
    endcase
  end
  always @(*) begin
    case(io_inputs_1_payload_op)
      LsuL1CmdOpcode_LSU : io_inputs_1_payload_op_string = "LSU         ";
      LsuL1CmdOpcode_ACCESS_1 : io_inputs_1_payload_op_string = "ACCESS_1    ";
      LsuL1CmdOpcode_STORE_BUFFER : io_inputs_1_payload_op_string = "STORE_BUFFER";
      LsuL1CmdOpcode_FLUSH : io_inputs_1_payload_op_string = "FLUSH       ";
      LsuL1CmdOpcode_PREFETCH : io_inputs_1_payload_op_string = "PREFETCH    ";
      default : io_inputs_1_payload_op_string = "????????????";
    endcase
  end
  always @(*) begin
    case(io_inputs_2_payload_op)
      LsuL1CmdOpcode_LSU : io_inputs_2_payload_op_string = "LSU         ";
      LsuL1CmdOpcode_ACCESS_1 : io_inputs_2_payload_op_string = "ACCESS_1    ";
      LsuL1CmdOpcode_STORE_BUFFER : io_inputs_2_payload_op_string = "STORE_BUFFER";
      LsuL1CmdOpcode_FLUSH : io_inputs_2_payload_op_string = "FLUSH       ";
      LsuL1CmdOpcode_PREFETCH : io_inputs_2_payload_op_string = "PREFETCH    ";
      default : io_inputs_2_payload_op_string = "????????????";
    endcase
  end
  always @(*) begin
    case(io_inputs_3_payload_op)
      LsuL1CmdOpcode_LSU : io_inputs_3_payload_op_string = "LSU         ";
      LsuL1CmdOpcode_ACCESS_1 : io_inputs_3_payload_op_string = "ACCESS_1    ";
      LsuL1CmdOpcode_STORE_BUFFER : io_inputs_3_payload_op_string = "STORE_BUFFER";
      LsuL1CmdOpcode_FLUSH : io_inputs_3_payload_op_string = "FLUSH       ";
      LsuL1CmdOpcode_PREFETCH : io_inputs_3_payload_op_string = "PREFETCH    ";
      default : io_inputs_3_payload_op_string = "????????????";
    endcase
  end
  always @(*) begin
    case(io_output_payload_op)
      LsuL1CmdOpcode_LSU : io_output_payload_op_string = "LSU         ";
      LsuL1CmdOpcode_ACCESS_1 : io_output_payload_op_string = "ACCESS_1    ";
      LsuL1CmdOpcode_STORE_BUFFER : io_output_payload_op_string = "STORE_BUFFER";
      LsuL1CmdOpcode_FLUSH : io_output_payload_op_string = "FLUSH       ";
      LsuL1CmdOpcode_PREFETCH : io_output_payload_op_string = "PREFETCH    ";
      default : io_output_payload_op_string = "????????????";
    endcase
  end
  always @(*) begin
    case(_zz_io_output_payload_op)
      LsuL1CmdOpcode_LSU : _zz_io_output_payload_op_string = "LSU         ";
      LsuL1CmdOpcode_ACCESS_1 : _zz_io_output_payload_op_string = "ACCESS_1    ";
      LsuL1CmdOpcode_STORE_BUFFER : _zz_io_output_payload_op_string = "STORE_BUFFER";
      LsuL1CmdOpcode_FLUSH : _zz_io_output_payload_op_string = "FLUSH       ";
      LsuL1CmdOpcode_PREFETCH : _zz_io_output_payload_op_string = "PREFETCH    ";
      default : _zz_io_output_payload_op_string = "????????????";
    endcase
  end
  `endif

  assign _zz_maskProposal_1 = {io_inputs_3_valid,io_inputs_2_valid,io_inputs_1_valid,io_inputs_0_valid};
  assign _zz_maskProposal_1_1 = (_zz_maskProposal_1 & (~ _zz__zz_maskProposal_1_1));
  assign maskProposal_0 = io_inputs_0_valid;
  assign maskProposal_1 = _zz_maskProposal_1_1[1];
  assign maskProposal_2 = _zz_maskProposal_1_1[2];
  assign maskProposal_3 = _zz_maskProposal_1_1[3];
  assign io_output_valid = ((((io_inputs_0_valid && maskProposal_0) || (io_inputs_1_valid && maskProposal_1)) || (io_inputs_2_valid && maskProposal_2)) || (io_inputs_3_valid && maskProposal_3));
  assign _zz_io_output_payload_address = (maskProposal_1 || maskProposal_3);
  assign _zz_io_output_payload_address_1 = (maskProposal_2 || maskProposal_3);
  assign _zz_io_output_payload_address_2 = {_zz_io_output_payload_address_1,_zz_io_output_payload_address};
  assign _zz_io_output_payload_op = _zz__zz_io_output_payload_op;
  assign io_output_payload_op = _zz_io_output_payload_op;
  assign io_output_payload_address = _zz_io_output_payload_address_3;
  assign io_output_payload_size = _zz_io_output_payload_size;
  assign io_output_payload_load = _zz_io_output_payload_load;
  assign io_output_payload_store = _zz_io_output_payload_store;
  assign io_output_payload_execute = _zz_io_output_payload_execute;
  assign io_output_payload_atomic = _zz_io_output_payload_atomic;
  assign io_output_payload_clean = _zz_io_output_payload_clean;
  assign io_output_payload_invalidate = _zz_io_output_payload_invalidate;
  assign io_output_payload_guest = _zz_io_output_payload_guest;
  assign io_output_payload_storeId = _zz_io_output_payload_storeId;
  assign io_inputs_0_ready = (maskProposal_0 && io_output_ready);
  assign io_inputs_1_ready = (maskProposal_1 && io_output_ready);
  assign io_inputs_2_ready = (maskProposal_2 && io_output_ready);
  assign io_inputs_3_ready = (maskProposal_3 && io_output_ready);
  assign io_chosenOH = {maskProposal_3,maskProposal_2,maskProposal_1,maskProposal_0};
  assign _zz_io_chosen = io_chosenOH[3];
  assign _zz_io_chosen_1 = (io_chosenOH[1] || _zz_io_chosen);
  assign _zz_io_chosen_2 = (io_chosenOH[2] || _zz_io_chosen);
  assign io_chosen = {_zz_io_chosen_2,_zz_io_chosen_1};

endmodule
