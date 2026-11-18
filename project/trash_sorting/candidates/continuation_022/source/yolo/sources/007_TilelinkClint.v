// Source-extraction compilation-unit preamble (not reference payload).
`timescale 1ns/1ps

module TilelinkClint (
  input  wire          io_bus_a_valid,
  output wire          io_bus_a_ready,
  input  wire [2:0]    io_bus_a_payload_opcode,
  input  wire [2:0]    io_bus_a_payload_param,
  input  wire [5:0]    io_bus_a_payload_source,
  input  wire [15:0]   io_bus_a_payload_address,
  input  wire [2:0]    io_bus_a_payload_size,
  input  wire [3:0]    io_bus_a_payload_mask,
  input  wire [31:0]   io_bus_a_payload_data,
  input  wire          io_bus_a_payload_corrupt,
  output wire          io_bus_d_valid,
  input  wire          io_bus_d_ready,
  output wire [2:0]    io_bus_d_payload_opcode,
  output wire [2:0]    io_bus_d_payload_param,
  output wire [5:0]    io_bus_d_payload_source,
  output wire [2:0]    io_bus_d_payload_size,
  output wire          io_bus_d_payload_denied,
  output wire [31:0]   io_bus_d_payload_data,
  output wire          io_bus_d_payload_corrupt,
  output wire [0:0]    io_timerInterrupt,
  output wire [0:0]    io_softwareInterrupt,
  output wire [63:0]   io_time,
  input  wire          io_stop,
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

  reg        [3:0]    _zz_factory_unburstify_last;
  wire       [15:0]   _zz_factory_unburstify_busA_payload_address;
  wire       [5:0]    _zz_factory_unburstify_busA_payload_address_1;
  wire       [13:0]   _zz_factory_address;
  wire                factory_readErrorFlag;
  wire                factory_writeErrorFlag;
  wire                factory_unburstify_isGet;
  reg        [3:0]    factory_unburstify_counter;
  wire                factory_unburstify_last;
  wire                factory_unburstify_busA_valid;
  wire                factory_unburstify_busA_ready;
  wire       [2:0]    factory_unburstify_busA_payload_opcode;
  wire       [2:0]    factory_unburstify_busA_payload_param;
  wire       [5:0]    factory_unburstify_busA_payload_source;
  wire       [15:0]   factory_unburstify_busA_payload_address;
  wire       [2:0]    factory_unburstify_busA_payload_size;
  wire       [3:0]    factory_unburstify_busA_payload_mask;
  wire       [31:0]   factory_unburstify_busA_payload_data;
  wire                factory_unburstify_busA_payload_corrupt;
  wire                factory_unburstify_busA_fire;
  wire                io_bus_a_fire;
  wire                when_SlaveFactory_l70;
  wire                factory_unburstify_withRsp;
  wire                factory_rspAsync_valid;
  reg                 factory_rspAsync_ready;
  wire       [2:0]    factory_rspAsync_payload_opcode;
  wire       [2:0]    factory_rspAsync_payload_param;
  wire       [5:0]    factory_rspAsync_payload_source;
  wire       [2:0]    factory_rspAsync_payload_size;
  wire                factory_rspAsync_payload_denied;
  reg        [31:0]   factory_rspAsync_payload_data;
  wire                factory_rspAsync_payload_corrupt;
  wire                factory_askWrite;
  wire                factory_askRead;
  wire                factory_doWrite;
  wire                factory_doRead;
  wire       [15:0]   factory_address;
  wire                factory_halt;
  reg                 logic_stop;
  reg        [63:0]   logic_time;
  wire                when_Clint_l39;
  reg        [63:0]   logic_harts_0_cmp;
  reg                 logic_harts_0_timerInterrupt;
  reg                 logic_harts_0_softwareInterrupt;
  reg                 when_Clint_l59;
  reg        [31:0]   _zz_factory_rspAsync_payload_data;
  wire       [2:0]    _zz_factory_rspAsync_payload_opcode;
  wire                factory_rspAsync_stage_valid;
  wire                factory_rspAsync_stage_ready;
  wire       [2:0]    factory_rspAsync_stage_payload_opcode;
  wire       [2:0]    factory_rspAsync_stage_payload_param;
  wire       [5:0]    factory_rspAsync_stage_payload_source;
  wire       [2:0]    factory_rspAsync_stage_payload_size;
  wire                factory_rspAsync_stage_payload_denied;
  wire       [31:0]   factory_rspAsync_stage_payload_data;
  wire                factory_rspAsync_stage_payload_corrupt;
  reg                 factory_rspAsync_rValid;
  reg        [2:0]    factory_rspAsync_rData_opcode;
  reg        [2:0]    factory_rspAsync_rData_param;
  reg        [5:0]    factory_rspAsync_rData_source;
  reg        [2:0]    factory_rspAsync_rData_size;
  reg                 factory_rspAsync_rData_denied;
  reg        [31:0]   factory_rspAsync_rData_data;
  reg                 factory_rspAsync_rData_corrupt;
  wire                when_Stream_l477;
  wire                when_SlaveFactory_l134;
  wire                when_SlaveFactory_l134_1;
  `ifndef SYNTHESIS
  reg [127:0] io_bus_a_payload_opcode_string;
  reg [119:0] io_bus_d_payload_opcode_string;
  reg [127:0] factory_unburstify_busA_payload_opcode_string;
  reg [119:0] factory_rspAsync_payload_opcode_string;
  reg [119:0] _zz_factory_rspAsync_payload_opcode_string;
  reg [119:0] factory_rspAsync_stage_payload_opcode_string;
  reg [119:0] factory_rspAsync_rData_opcode_string;
  `endif


  assign _zz_factory_unburstify_busA_payload_address_1 = ({2'd0,factory_unburstify_counter} <<< 2'd2);
  assign _zz_factory_unburstify_busA_payload_address = {10'd0, _zz_factory_unburstify_busA_payload_address_1};
  assign _zz_factory_address = (factory_unburstify_busA_payload_address >>> 2'd2);
  always @(*) begin
    case(io_bus_a_payload_size)
      3'b000 : _zz_factory_unburstify_last = 4'b0000;
      3'b001 : _zz_factory_unburstify_last = 4'b0000;
      3'b010 : _zz_factory_unburstify_last = 4'b0000;
      3'b011 : _zz_factory_unburstify_last = 4'b0001;
      3'b100 : _zz_factory_unburstify_last = 4'b0011;
      3'b101 : _zz_factory_unburstify_last = 4'b0111;
      default : _zz_factory_unburstify_last = 4'b1111;
    endcase
  end

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
    case(factory_unburstify_busA_payload_opcode)
      A_PUT_FULL_DATA : factory_unburstify_busA_payload_opcode_string = "PUT_FULL_DATA   ";
      A_PUT_PARTIAL_DATA : factory_unburstify_busA_payload_opcode_string = "PUT_PARTIAL_DATA";
      A_ARITHMETIC_DATA : factory_unburstify_busA_payload_opcode_string = "ARITHMETIC_DATA ";
      A_LOGICAL_DATA : factory_unburstify_busA_payload_opcode_string = "LOGICAL_DATA    ";
      A_GET : factory_unburstify_busA_payload_opcode_string = "GET             ";
      A_ACQUIRE_BLOCK : factory_unburstify_busA_payload_opcode_string = "ACQUIRE_BLOCK   ";
      A_ACQUIRE_PERM : factory_unburstify_busA_payload_opcode_string = "ACQUIRE_PERM    ";
      default : factory_unburstify_busA_payload_opcode_string = "????????????????";
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

  assign factory_readErrorFlag = 1'b0;
  assign factory_writeErrorFlag = 1'b0;
  assign factory_unburstify_isGet = (io_bus_a_payload_opcode == A_GET);
  assign factory_unburstify_last = (factory_unburstify_counter == _zz_factory_unburstify_last);
  assign factory_unburstify_busA_valid = io_bus_a_valid;
  assign factory_unburstify_busA_payload_opcode = io_bus_a_payload_opcode;
  assign factory_unburstify_busA_payload_param = io_bus_a_payload_param;
  assign factory_unburstify_busA_payload_source = io_bus_a_payload_source;
  assign factory_unburstify_busA_payload_size = io_bus_a_payload_size;
  assign factory_unburstify_busA_payload_mask = io_bus_a_payload_mask;
  assign factory_unburstify_busA_payload_data = io_bus_a_payload_data;
  assign factory_unburstify_busA_payload_corrupt = io_bus_a_payload_corrupt;
  assign io_bus_a_ready = (factory_unburstify_busA_ready && ((! factory_unburstify_isGet) || factory_unburstify_last));
  assign factory_unburstify_busA_fire = (factory_unburstify_busA_valid && factory_unburstify_busA_ready);
  assign io_bus_a_fire = (io_bus_a_valid && io_bus_a_ready);
  assign when_SlaveFactory_l70 = (io_bus_a_fire && (factory_unburstify_isGet || factory_unburstify_last));
  assign factory_unburstify_busA_payload_address = (io_bus_a_payload_address | _zz_factory_unburstify_busA_payload_address);
  assign factory_unburstify_withRsp = (factory_unburstify_isGet || factory_unburstify_last);
  assign factory_askWrite = (factory_unburstify_busA_valid && (|{(factory_unburstify_busA_payload_opcode == A_PUT_PARTIAL_DATA),(factory_unburstify_busA_payload_opcode == A_PUT_FULL_DATA)}));
  assign factory_askRead = (factory_unburstify_busA_valid && (|(factory_unburstify_busA_payload_opcode == A_GET)));
  assign factory_doWrite = (factory_askWrite && factory_unburstify_busA_ready);
  assign factory_doRead = (factory_askRead && factory_unburstify_busA_ready);
  assign factory_address = ({2'd0,_zz_factory_address} <<< 2'd2);
  assign factory_halt = 1'b0;
  always @(*) begin
    logic_stop = 1'b0;
    if(io_stop) begin
      logic_stop = 1'b1;
    end
  end

  assign when_Clint_l39 = (! logic_stop);
  always @(*) begin
    when_Clint_l59 = 1'b0;
    case(factory_address)
      16'hbff8 : begin
        if(factory_doRead) begin
          when_Clint_l59 = 1'b1;
        end
      end
      default : begin
      end
    endcase
  end

  assign io_timerInterrupt[0] = logic_harts_0_timerInterrupt;
  assign io_softwareInterrupt[0] = logic_harts_0_softwareInterrupt;
  assign io_time = logic_time;
  assign factory_unburstify_busA_ready = (factory_rspAsync_ready && (! factory_halt));
  assign factory_rspAsync_valid = ((factory_unburstify_busA_valid && (! factory_halt)) && factory_unburstify_withRsp);
  always @(*) begin
    factory_rspAsync_payload_data = 32'h0;
    case(factory_address)
      16'hbff8 : begin
        factory_rspAsync_payload_data[31 : 0] = logic_time[31 : 0];
      end
      16'hbffc : begin
        factory_rspAsync_payload_data[31 : 0] = _zz_factory_rspAsync_payload_data;
      end
      16'h0 : begin
        factory_rspAsync_payload_data[0 : 0] = logic_harts_0_softwareInterrupt;
      end
      default : begin
      end
    endcase
  end

  assign _zz_factory_rspAsync_payload_opcode = ((|(factory_unburstify_busA_payload_opcode == A_GET)) ? D_ACCESS_ACK_DATA : D_ACCESS_ACK);
  assign factory_rspAsync_payload_opcode = _zz_factory_rspAsync_payload_opcode;
  assign factory_rspAsync_payload_param = 3'b000;
  assign factory_rspAsync_payload_source = factory_unburstify_busA_payload_source;
  assign factory_rspAsync_payload_size = factory_unburstify_busA_payload_size;
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
  assign when_SlaveFactory_l134 = ((factory_address & (~ 16'h0003)) == 16'h4000);
  assign when_SlaveFactory_l134_1 = ((factory_address & (~ 16'h0003)) == 16'h4004);
  always @(posedge socCtrl_systemClk or posedge socCtrl_system_reset) begin
    if(socCtrl_system_reset) begin
      factory_unburstify_counter <= 4'b0000;
      logic_time <= 64'h0;
      logic_harts_0_softwareInterrupt <= 1'b0;
      factory_rspAsync_rValid <= 1'b0;
    end else begin
      if(factory_unburstify_busA_fire) begin
        factory_unburstify_counter <= (factory_unburstify_counter + 4'b0001);
        if(when_SlaveFactory_l70) begin
          factory_unburstify_counter <= 4'b0000;
        end
      end
      if(when_Clint_l39) begin
        logic_time <= (logic_time + 64'h0000000000000001);
      end
      if(factory_rspAsync_ready) begin
        factory_rspAsync_rValid <= factory_rspAsync_valid;
      end
      case(factory_address)
        16'h0 : begin
          if(factory_doWrite) begin
            logic_harts_0_softwareInterrupt <= factory_unburstify_busA_payload_data[0];
          end
        end
        default : begin
        end
      endcase
    end
  end

  always @(posedge socCtrl_systemClk) begin
    logic_harts_0_timerInterrupt <= (logic_harts_0_cmp <= logic_time);
    if(when_Clint_l59) begin
      _zz_factory_rspAsync_payload_data <= logic_time[63 : 32];
    end
    if(factory_rspAsync_ready) begin
      factory_rspAsync_rData_opcode <= factory_rspAsync_payload_opcode;
      factory_rspAsync_rData_param <= factory_rspAsync_payload_param;
      factory_rspAsync_rData_source <= factory_rspAsync_payload_source;
      factory_rspAsync_rData_size <= factory_rspAsync_payload_size;
      factory_rspAsync_rData_denied <= factory_rspAsync_payload_denied;
      factory_rspAsync_rData_data <= factory_rspAsync_payload_data;
      factory_rspAsync_rData_corrupt <= factory_rspAsync_payload_corrupt;
    end
    if(when_SlaveFactory_l134) begin
      if(factory_doWrite) begin
        logic_harts_0_cmp[31 : 0] <= factory_unburstify_busA_payload_data[31 : 0];
      end
    end
    if(when_SlaveFactory_l134_1) begin
      if(factory_doWrite) begin
        logic_harts_0_cmp[63 : 32] <= factory_unburstify_busA_payload_data[31 : 0];
      end
    end
  end


endmodule
