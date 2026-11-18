// Source-extraction compilation-unit preamble (not reference payload).
`timescale 1ns/1ps

module TilelinkPlic (
  input  wire          io_bus_a_valid,
  output wire          io_bus_a_ready,
  input  wire [2:0]    io_bus_a_payload_opcode,
  input  wire [2:0]    io_bus_a_payload_param,
  input  wire [5:0]    io_bus_a_payload_source,
  input  wire [21:0]   io_bus_a_payload_address,
  input  wire [1:0]    io_bus_a_payload_size,
  input  wire [3:0]    io_bus_a_payload_mask,
  input  wire [31:0]   io_bus_a_payload_data,
  input  wire          io_bus_a_payload_corrupt,
  output wire          io_bus_d_valid,
  input  wire          io_bus_d_ready,
  output wire [2:0]    io_bus_d_payload_opcode,
  output wire [2:0]    io_bus_d_payload_param,
  output wire [5:0]    io_bus_d_payload_source,
  output wire [1:0]    io_bus_d_payload_size,
  output wire          io_bus_d_payload_denied,
  output wire [31:0]   io_bus_d_payload_data,
  output wire          io_bus_d_payload_corrupt,
  input  wire [1:0]    io_sources,
  output wire [0:0]    io_targets,
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

  wire       [19:0]   _zz_factory_address;
  wire                _zz_gateways_0_ip;
  wire                _zz_gateways_1_ip;
  wire       [1:0]    gateways_0_priority;
  reg                 gateways_0_ip;
  reg                 gateways_0_waitCompletion;
  wire                when_PlicGateway_l21;
  wire       [1:0]    gateways_1_priority;
  reg                 gateways_1_ip;
  reg                 gateways_1_waitCompletion;
  wire                when_PlicGateway_l21_1;
  wire                targets_0_ie_0;
  wire                targets_0_ie_1;
  wire       [1:0]    targets_0_threshold;
  wire       [1:0]    targets_0_requests_0_priority;
  wire       [1:0]    targets_0_requests_0_id;
  wire                targets_0_requests_0_valid;
  wire       [1:0]    targets_0_requests_1_priority;
  wire       [1:0]    targets_0_requests_1_id;
  wire                targets_0_requests_1_valid;
  wire       [1:0]    targets_0_requests_2_priority;
  wire       [1:0]    targets_0_requests_2_id;
  wire                targets_0_requests_2_valid;
  wire                _zz_targets_0_bestRequest_id;
  wire       [1:0]    _zz_targets_0_bestRequest_priority;
  wire                _zz_targets_0_bestRequest_valid;
  wire                _zz_targets_0_bestRequest_priority_1;
  reg        [1:0]    targets_0_bestRequest_priority;
  reg        [1:0]    targets_0_bestRequest_id;
  reg                 targets_0_bestRequest_valid;
  wire                targets_0_iep;
  wire       [1:0]    targets_0_claim;
  wire                factory_readErrorFlag;
  wire                factory_writeErrorFlag;
  wire                factory_rspAsync_valid;
  reg                 factory_rspAsync_ready;
  wire       [2:0]    factory_rspAsync_payload_opcode;
  wire       [2:0]    factory_rspAsync_payload_param;
  wire       [5:0]    factory_rspAsync_payload_source;
  wire       [1:0]    factory_rspAsync_payload_size;
  wire                factory_rspAsync_payload_denied;
  reg        [31:0]   factory_rspAsync_payload_data;
  wire                factory_rspAsync_payload_corrupt;
  wire                factory_askWrite;
  wire                factory_askRead;
  wire                factory_doWrite;
  wire                factory_doRead;
  wire       [21:0]   factory_address;
  reg                 factory_halt;
  reg        [1:0]    gateways_0_priority_driver;
  reg        [1:0]    gateways_1_priority_driver;
  reg                 mapping_claim_valid;
  reg        [1:0]    mapping_claim_payload;
  reg                 mapping_completion_valid;
  reg        [1:0]    mapping_completion_payload;
  reg                 mapping_coherencyStall_willIncrement;
  wire                mapping_coherencyStall_willDecrement;
  wire                mapping_coherencyStall_willClear;
  wire                mapping_coherencyStall_willLoad;
  reg        [0:0]    mapping_coherencyStall_valueNext;
  reg        [0:0]    mapping_coherencyStall_value;
  wire                mapping_coherencyStall_willOverflowIfInc;
  wire                mapping_coherencyStall_willUnderflowIfDec;
  wire                mapping_coherencyStall_willOverflow;
  wire                mapping_coherencyStall_willUnderflow;
  wire                when_PlicMapper_l122;
  reg        [1:0]    targets_0_threshold_driver;
  reg                 mapping_targetMapping_0_targetCompletion_valid;
  wire       [1:0]    mapping_targetMapping_0_targetCompletion_payload;
  reg                 targets_0_ie_0_driver;
  reg                 targets_0_ie_1_driver;
  wire       [2:0]    _zz_factory_rspAsync_payload_opcode;
  wire                factory_rspAsync_stage_valid;
  wire                factory_rspAsync_stage_ready;
  wire       [2:0]    factory_rspAsync_stage_payload_opcode;
  wire       [2:0]    factory_rspAsync_stage_payload_param;
  wire       [5:0]    factory_rspAsync_stage_payload_source;
  wire       [1:0]    factory_rspAsync_stage_payload_size;
  wire                factory_rspAsync_stage_payload_denied;
  wire       [31:0]   factory_rspAsync_stage_payload_data;
  wire                factory_rspAsync_stage_payload_corrupt;
  reg                 factory_rspAsync_rValid;
  reg        [2:0]    factory_rspAsync_rData_opcode;
  reg        [2:0]    factory_rspAsync_rData_param;
  reg        [5:0]    factory_rspAsync_rData_source;
  reg        [1:0]    factory_rspAsync_rData_size;
  reg                 factory_rspAsync_rData_denied;
  reg        [31:0]   factory_rspAsync_rData_data;
  reg                 factory_rspAsync_rData_corrupt;
  wire                when_Stream_l477;
  wire                when_SlaveFactory_l134;
  `ifndef SYNTHESIS
  reg [127:0] io_bus_a_payload_opcode_string;
  reg [119:0] io_bus_d_payload_opcode_string;
  reg [119:0] factory_rspAsync_payload_opcode_string;
  reg [119:0] _zz_factory_rspAsync_payload_opcode_string;
  reg [119:0] factory_rspAsync_stage_payload_opcode_string;
  reg [119:0] factory_rspAsync_rData_opcode_string;
  `endif


  assign _zz_factory_address = (io_bus_a_payload_address >>> 2'd2);
  `ifndef SYNTHESIS
  always @(*) begin
    case(io_bus_a_payload_opcode)
      A_PUT_FULL_DATA : io_bus_a_payload_opcode_string = "PUT_FULL_DATA   ";
      A_PUT_PARTIAL_DATA : io_bus_a_payload_opcode_string = "PUT_PARTIAL_DATA";
      A_ARITHMETIC_DATA : io_bus_a_payload_opcode_string = "ARITHMETIC_DATA ";
      A_LOGICAL_DATA : io_bus_a_payload_opcode_string = "LOGICAL_DATA    ";
      A_GET : io_bus_a_payload_opcode_string = "GET             ";
      A_ACQUIRE_BLOCK : io_bus_a_payload_opcode_string = "ACQUIRE_BLOCK   ";
      A_ACQUIRE_PERM : io_bus_a_payload_opcode_string = "ACQUIRE_PERM    ";
      default : io_bus_a_payload_opcode_string = "????????????????";
    endcase
  end
  always @(*) begin
    case(io_bus_d_payload_opcode)
      D_ACCESS_ACK : io_bus_d_payload_opcode_string = "ACCESS_ACK     ";
      D_ACCESS_ACK_DATA : io_bus_d_payload_opcode_string = "ACCESS_ACK_DATA";
      D_GRANT : io_bus_d_payload_opcode_string = "GRANT          ";
      D_GRANT_DATA : io_bus_d_payload_opcode_string = "GRANT_DATA     ";
      D_RELEASE_ACK : io_bus_d_payload_opcode_string = "RELEASE_ACK    ";
      default : io_bus_d_payload_opcode_string = "???????????????";
    endcase
  end
  always @(*) begin
    case(factory_rspAsync_payload_opcode)
      D_ACCESS_ACK : factory_rspAsync_payload_opcode_string = "ACCESS_ACK     ";
      D_ACCESS_ACK_DATA : factory_rspAsync_payload_opcode_string = "ACCESS_ACK_DATA";
      D_GRANT : factory_rspAsync_payload_opcode_string = "GRANT          ";
      D_GRANT_DATA : factory_rspAsync_payload_opcode_string = "GRANT_DATA     ";
      D_RELEASE_ACK : factory_rspAsync_payload_opcode_string = "RELEASE_ACK    ";
      default : factory_rspAsync_payload_opcode_string = "???????????????";
    endcase
  end
  always @(*) begin
    case(_zz_factory_rspAsync_payload_opcode)
      D_ACCESS_ACK : _zz_factory_rspAsync_payload_opcode_string = "ACCESS_ACK     ";
      D_ACCESS_ACK_DATA : _zz_factory_rspAsync_payload_opcode_string = "ACCESS_ACK_DATA";
      D_GRANT : _zz_factory_rspAsync_payload_opcode_string = "GRANT          ";
      D_GRANT_DATA : _zz_factory_rspAsync_payload_opcode_string = "GRANT_DATA     ";
      D_RELEASE_ACK : _zz_factory_rspAsync_payload_opcode_string = "RELEASE_ACK    ";
      default : _zz_factory_rspAsync_payload_opcode_string = "???????????????";
    endcase
  end
  always @(*) begin
    case(factory_rspAsync_stage_payload_opcode)
      D_ACCESS_ACK : factory_rspAsync_stage_payload_opcode_string = "ACCESS_ACK     ";
      D_ACCESS_ACK_DATA : factory_rspAsync_stage_payload_opcode_string = "ACCESS_ACK_DATA";
      D_GRANT : factory_rspAsync_stage_payload_opcode_string = "GRANT          ";
      D_GRANT_DATA : factory_rspAsync_stage_payload_opcode_string = "GRANT_DATA     ";
      D_RELEASE_ACK : factory_rspAsync_stage_payload_opcode_string = "RELEASE_ACK    ";
      default : factory_rspAsync_stage_payload_opcode_string = "???????????????";
    endcase
  end
  always @(*) begin
    case(factory_rspAsync_rData_opcode)
      D_ACCESS_ACK : factory_rspAsync_rData_opcode_string = "ACCESS_ACK     ";
      D_ACCESS_ACK_DATA : factory_rspAsync_rData_opcode_string = "ACCESS_ACK_DATA";
      D_GRANT : factory_rspAsync_rData_opcode_string = "GRANT          ";
      D_GRANT_DATA : factory_rspAsync_rData_opcode_string = "GRANT_DATA     ";
      D_RELEASE_ACK : factory_rspAsync_rData_opcode_string = "RELEASE_ACK    ";
      default : factory_rspAsync_rData_opcode_string = "???????????????";
    endcase
  end
  `endif

  assign _zz_gateways_0_ip = io_sources[0];
  assign _zz_gateways_1_ip = io_sources[1];
  assign when_PlicGateway_l21 = (! gateways_0_waitCompletion);
  assign when_PlicGateway_l21_1 = (! gateways_1_waitCompletion);
  assign targets_0_requests_0_priority = 2'b00;
  assign targets_0_requests_0_id = 2'b00;
  assign targets_0_requests_0_valid = 1'b1;
  assign targets_0_requests_1_priority = gateways_0_priority;
  assign targets_0_requests_1_id = 2'b01;
  assign targets_0_requests_1_valid = (gateways_0_ip && targets_0_ie_0);
  assign targets_0_requests_2_priority = gateways_1_priority;
  assign targets_0_requests_2_id = 2'b11;
  assign targets_0_requests_2_valid = (gateways_1_ip && targets_0_ie_1);
  assign _zz_targets_0_bestRequest_id = ((! targets_0_requests_1_valid) || (targets_0_requests_0_valid && (targets_0_requests_1_priority <= targets_0_requests_0_priority)));
  assign _zz_targets_0_bestRequest_priority = (_zz_targets_0_bestRequest_id ? targets_0_requests_0_priority : targets_0_requests_1_priority);
  assign _zz_targets_0_bestRequest_valid = (_zz_targets_0_bestRequest_id ? targets_0_requests_0_valid : targets_0_requests_1_valid);
  assign _zz_targets_0_bestRequest_priority_1 = ((! targets_0_requests_2_valid) || (_zz_targets_0_bestRequest_valid && (targets_0_requests_2_priority <= _zz_targets_0_bestRequest_priority)));
  assign targets_0_iep = (targets_0_threshold < targets_0_bestRequest_priority);
  assign targets_0_claim = (targets_0_iep ? targets_0_bestRequest_id : 2'b00);
  assign io_targets = targets_0_iep;
  assign factory_readErrorFlag = 1'b0;
  assign factory_writeErrorFlag = 1'b0;
  assign factory_askWrite = (io_bus_a_valid && (|{(io_bus_a_payload_opcode == A_PUT_PARTIAL_DATA),(io_bus_a_payload_opcode == A_PUT_FULL_DATA)}));
  assign factory_askRead = (io_bus_a_valid && (|(io_bus_a_payload_opcode == A_GET)));
  assign factory_doWrite = (factory_askWrite && io_bus_a_ready);
  assign factory_doRead = (factory_askRead && io_bus_a_ready);
  assign factory_address = ({2'd0,_zz_factory_address} <<< 2'd2);
  always @(*) begin
    factory_halt = 1'b0;
    if(when_PlicMapper_l122) begin
      factory_halt = 1'b1;
    end
  end

  assign gateways_0_priority = gateways_0_priority_driver;
  assign gateways_1_priority = gateways_1_priority_driver;
  always @(*) begin
    mapping_claim_valid = 1'b0;
    case(factory_address)
      22'h200004 : begin
        if(factory_doRead) begin
          mapping_claim_valid = 1'b1;
        end
      end
      default : begin
      end
    endcase
  end

  always @(*) begin
    mapping_claim_payload = 2'bxx;
    case(factory_address)
      22'h200004 : begin
        if(factory_doRead) begin
          mapping_claim_payload = targets_0_claim;
        end
      end
      default : begin
      end
    endcase
  end

  always @(*) begin
    mapping_completion_valid = 1'b0;
    if(mapping_targetMapping_0_targetCompletion_valid) begin
      mapping_completion_valid = 1'b1;
    end
  end

  always @(*) begin
    mapping_completion_payload = 2'bxx;
    if(mapping_targetMapping_0_targetCompletion_valid) begin
      mapping_completion_payload = mapping_targetMapping_0_targetCompletion_payload;
    end
  end

  always @(*) begin
    mapping_coherencyStall_willIncrement = 1'b0;
    if(when_PlicMapper_l122) begin
      mapping_coherencyStall_willIncrement = 1'b1;
    end
    if(when_SlaveFactory_l134) begin
      if(factory_askWrite) begin
        mapping_coherencyStall_willIncrement = 1'b1;
      end
      if(factory_askRead) begin
        mapping_coherencyStall_willIncrement = 1'b1;
      end
    end
  end

  assign mapping_coherencyStall_willDecrement = 1'b0;
  assign mapping_coherencyStall_willClear = 1'b0;
  assign mapping_coherencyStall_willLoad = 1'b0;
  assign mapping_coherencyStall_willOverflowIfInc = (mapping_coherencyStall_value == 1'b1);
  assign mapping_coherencyStall_willUnderflowIfDec = (mapping_coherencyStall_value == 1'b0);
  assign mapping_coherencyStall_willOverflow = (mapping_coherencyStall_willOverflowIfInc && mapping_coherencyStall_willIncrement);
  always @(*) begin
    mapping_coherencyStall_valueNext = (mapping_coherencyStall_value + mapping_coherencyStall_willIncrement);
    if(mapping_coherencyStall_willClear) begin
      mapping_coherencyStall_valueNext = 1'b0;
    end
  end

  assign mapping_coherencyStall_willUnderflow = (mapping_coherencyStall_willUnderflowIfDec && mapping_coherencyStall_willDecrement);
  assign when_PlicMapper_l122 = (mapping_coherencyStall_value != 1'b0);
  assign targets_0_threshold = targets_0_threshold_driver;
  always @(*) begin
    mapping_targetMapping_0_targetCompletion_valid = 1'b0;
    case(factory_address)
      22'h200004 : begin
        if(factory_doWrite) begin
          mapping_targetMapping_0_targetCompletion_valid = 1'b1;
        end
      end
      default : begin
      end
    endcase
  end

  assign targets_0_ie_0 = targets_0_ie_0_driver;
  assign targets_0_ie_1 = targets_0_ie_1_driver;
  assign mapping_targetMapping_0_targetCompletion_payload = io_bus_a_payload_data[1 : 0];
  assign io_bus_a_ready = (factory_rspAsync_ready && (! factory_halt));
  assign factory_rspAsync_valid = ((io_bus_a_valid && (! factory_halt)) && 1'b1);
  always @(*) begin
    factory_rspAsync_payload_data = 32'h0;
    case(factory_address)
      22'h000004 : begin
        factory_rspAsync_payload_data[1 : 0] = gateways_0_priority;
      end
      22'h001000 : begin
        factory_rspAsync_payload_data[1 : 1] = gateways_0_ip;
        factory_rspAsync_payload_data[3 : 3] = gateways_1_ip;
      end
      22'h00000c : begin
        factory_rspAsync_payload_data[1 : 0] = gateways_1_priority;
      end
      22'h200000 : begin
        factory_rspAsync_payload_data[1 : 0] = targets_0_threshold;
      end
      22'h200004 : begin
        factory_rspAsync_payload_data[1 : 0] = targets_0_claim;
      end
      22'h002000 : begin
        factory_rspAsync_payload_data[1 : 1] = targets_0_ie_0;
        factory_rspAsync_payload_data[3 : 3] = targets_0_ie_1;
      end
      default : begin
      end
    endcase
  end

  assign _zz_factory_rspAsync_payload_opcode = ((|(io_bus_a_payload_opcode == A_GET)) ? D_ACCESS_ACK_DATA : D_ACCESS_ACK);
  assign factory_rspAsync_payload_opcode = _zz_factory_rspAsync_payload_opcode;
  assign factory_rspAsync_payload_param = 3'b000;
  assign factory_rspAsync_payload_source = io_bus_a_payload_source;
  assign factory_rspAsync_payload_size = io_bus_a_payload_size;
  assign factory_rspAsync_payload_corrupt = 1'b0;
  assign factory_rspAsync_payload_denied = 1'b0;
  always @(*) begin
    factory_rspAsync_ready = factory_rspAsync_stage_ready;
    if(when_Stream_l477) begin
      factory_rspAsync_ready = 1'b1;
    end
  end

  assign when_Stream_l477 = (! factory_rspAsync_stage_valid);
  assign factory_rspAsync_stage_valid = factory_rspAsync_rValid;
  assign factory_rspAsync_stage_payload_opcode = factory_rspAsync_rData_opcode;
  assign factory_rspAsync_stage_payload_param = factory_rspAsync_rData_param;
  assign factory_rspAsync_stage_payload_source = factory_rspAsync_rData_source;
  assign factory_rspAsync_stage_payload_size = factory_rspAsync_rData_size;
  assign factory_rspAsync_stage_payload_denied = factory_rspAsync_rData_denied;
  assign factory_rspAsync_stage_payload_data = factory_rspAsync_rData_data;
  assign factory_rspAsync_stage_payload_corrupt = factory_rspAsync_rData_corrupt;
  assign io_bus_d_valid = factory_rspAsync_stage_valid;
  assign factory_rspAsync_stage_ready = io_bus_d_ready;
  assign io_bus_d_payload_opcode = factory_rspAsync_stage_payload_opcode;
  assign io_bus_d_payload_param = factory_rspAsync_stage_payload_param;
  assign io_bus_d_payload_source = factory_rspAsync_stage_payload_source;
  assign io_bus_d_payload_size = factory_rspAsync_stage_payload_size;
  assign io_bus_d_payload_denied = factory_rspAsync_stage_payload_denied;
  assign io_bus_d_payload_data = factory_rspAsync_stage_payload_data;
  assign io_bus_d_payload_corrupt = factory_rspAsync_stage_payload_corrupt;
  assign when_SlaveFactory_l134 = 1'b1;
  always @(posedge socCtrl_systemClk or posedge socCtrl_system_reset) begin
    if(socCtrl_system_reset) begin
      gateways_0_ip <= 1'b0;
      gateways_0_waitCompletion <= 1'b0;
      gateways_1_ip <= 1'b0;
      gateways_1_waitCompletion <= 1'b0;
      gateways_0_priority_driver <= 2'b00;
      gateways_1_priority_driver <= 2'b00;
      mapping_coherencyStall_value <= 1'b0;
      targets_0_threshold_driver <= 2'b00;
      targets_0_ie_0_driver <= 1'b0;
      targets_0_ie_1_driver <= 1'b0;
      factory_rspAsync_rValid <= 1'b0;
    end else begin
      if(when_PlicGateway_l21) begin
        gateways_0_ip <= _zz_gateways_0_ip;
        gateways_0_waitCompletion <= _zz_gateways_0_ip;
      end
      if(when_PlicGateway_l21_1) begin
        gateways_1_ip <= _zz_gateways_1_ip;
        gateways_1_waitCompletion <= _zz_gateways_1_ip;
      end
      if(mapping_claim_valid) begin
        case(mapping_claim_payload)
          2'b01 : begin
            gateways_0_ip <= 1'b0;
          end
          2'b11 : begin
            gateways_1_ip <= 1'b0;
          end
          default : begin
          end
        endcase
      end
      if(mapping_completion_valid) begin
        case(mapping_completion_payload)
          2'b01 : begin
            gateways_0_waitCompletion <= 1'b0;
          end
          2'b11 : begin
            gateways_1_waitCompletion <= 1'b0;
          end
          default : begin
          end
        endcase
      end
      mapping_coherencyStall_value <= mapping_coherencyStall_valueNext;
      if(factory_rspAsync_ready) begin
        factory_rspAsync_rValid <= factory_rspAsync_valid;
      end
      case(factory_address)
        22'h000004 : begin
          if(factory_doWrite) begin
            gateways_0_priority_driver <= io_bus_a_payload_data[1 : 0];
          end
        end
        22'h00000c : begin
          if(factory_doWrite) begin
            gateways_1_priority_driver <= io_bus_a_payload_data[1 : 0];
          end
        end
        22'h200000 : begin
          if(factory_doWrite) begin
            targets_0_threshold_driver <= io_bus_a_payload_data[1 : 0];
          end
        end
        22'h002000 : begin
          if(factory_doWrite) begin
            targets_0_ie_0_driver <= io_bus_a_payload_data[1];
            targets_0_ie_1_driver <= io_bus_a_payload_data[3];
          end
        end
        default : begin
        end
      endcase
    end
  end

  always @(posedge socCtrl_systemClk) begin
    targets_0_bestRequest_priority <= (_zz_targets_0_bestRequest_priority_1 ? _zz_targets_0_bestRequest_priority : targets_0_requests_2_priority);
    targets_0_bestRequest_id <= (_zz_targets_0_bestRequest_priority_1 ? (_zz_targets_0_bestRequest_id ? targets_0_requests_0_id : targets_0_requests_1_id) : targets_0_requests_2_id);
    targets_0_bestRequest_valid <= (_zz_targets_0_bestRequest_priority_1 ? _zz_targets_0_bestRequest_valid : targets_0_requests_2_valid);
    if(factory_rspAsync_ready) begin
      factory_rspAsync_rData_opcode <= factory_rspAsync_payload_opcode;
      factory_rspAsync_rData_param <= factory_rspAsync_payload_param;
      factory_rspAsync_rData_source <= factory_rspAsync_payload_source;
      factory_rspAsync_rData_size <= factory_rspAsync_payload_size;
      factory_rspAsync_rData_denied <= factory_rspAsync_payload_denied;
      factory_rspAsync_rData_data <= factory_rspAsync_payload_data;
      factory_rspAsync_rData_corrupt <= factory_rspAsync_payload_corrupt;
    end
  end


endmodule
