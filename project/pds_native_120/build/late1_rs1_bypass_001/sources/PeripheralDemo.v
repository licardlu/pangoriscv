// Source-extraction compilation-unit preamble (not reference payload).
`timescale 1ns/1ps

module PeripheralDemo (
  input  wire          io_bus_a_valid,
  output wire          io_bus_a_ready,
  input  wire [2:0]    io_bus_a_payload_opcode,
  input  wire [2:0]    io_bus_a_payload_param,
  input  wire [5:0]    io_bus_a_payload_source,
  input  wire [11:0]   io_bus_a_payload_address,
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
  output wire [7:0]    io_leds,
  input  wire [0:0]    io_buttons,
  output wire          io_interrupt,
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

  wire       [0:0]    io_buttons_buffercc_io_dataOut;
  wire       [9:0]    _zz_mapper_address;
  wire                mapper_readErrorFlag;
  wire                mapper_writeErrorFlag;
  wire                mapper_rspAsync_valid;
  reg                 mapper_rspAsync_ready;
  wire       [2:0]    mapper_rspAsync_payload_opcode;
  wire       [2:0]    mapper_rspAsync_payload_param;
  wire       [5:0]    mapper_rspAsync_payload_source;
  wire       [1:0]    mapper_rspAsync_payload_size;
  wire                mapper_rspAsync_payload_denied;
  reg        [31:0]   mapper_rspAsync_payload_data;
  wire                mapper_rspAsync_payload_corrupt;
  wire                mapper_askWrite;
  wire                mapper_askRead;
  wire                mapper_doWrite;
  wire                mapper_doRead;
  wire       [11:0]   mapper_address;
  wire                mapper_halt;
  reg        [7:0]    ledReg;
  wire       [0:0]    buttonsCc;
  reg        [0:0]    interrupts_enables;
  wire       [2:0]    _zz_mapper_rspAsync_payload_opcode;
  wire                mapper_rspAsync_stage_valid;
  wire                mapper_rspAsync_stage_ready;
  wire       [2:0]    mapper_rspAsync_stage_payload_opcode;
  wire       [2:0]    mapper_rspAsync_stage_payload_param;
  wire       [5:0]    mapper_rspAsync_stage_payload_source;
  wire       [1:0]    mapper_rspAsync_stage_payload_size;
  wire                mapper_rspAsync_stage_payload_denied;
  wire       [31:0]   mapper_rspAsync_stage_payload_data;
  wire                mapper_rspAsync_stage_payload_corrupt;
  reg                 mapper_rspAsync_rValid;
  reg        [2:0]    mapper_rspAsync_rData_opcode;
  reg        [2:0]    mapper_rspAsync_rData_param;
  reg        [5:0]    mapper_rspAsync_rData_source;
  reg        [1:0]    mapper_rspAsync_rData_size;
  reg                 mapper_rspAsync_rData_denied;
  reg        [31:0]   mapper_rspAsync_rData_data;
  reg                 mapper_rspAsync_rData_corrupt;
  wire                when_Stream_l477;
  `ifndef SYNTHESIS
  reg [127:0] io_bus_a_payload_opcode_string;
  reg [119:0] io_bus_d_payload_opcode_string;
  reg [119:0] mapper_rspAsync_payload_opcode_string;
  reg [119:0] _zz_mapper_rspAsync_payload_opcode_string;
  reg [119:0] mapper_rspAsync_stage_payload_opcode_string;
  reg [119:0] mapper_rspAsync_rData_opcode_string;
  `endif


  assign _zz_mapper_address = (io_bus_a_payload_address >>> 2'd2);
  (* keep_hierarchy = "TRUE" *) BufferCC_1 io_buttons_buffercc (
    .io_dataIn            (io_buttons                    ), //i
    .io_dataOut           (io_buttons_buffercc_io_dataOut), //o
    .socCtrl_systemClk    (socCtrl_systemClk             ), //i
    .socCtrl_system_reset (socCtrl_system_reset          )  //i
  );
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
    case(mapper_rspAsync_payload_opcode)
      D_ACCESS_ACK : mapper_rspAsync_payload_opcode_string = "ACCESS_ACK     ";
      D_ACCESS_ACK_DATA : mapper_rspAsync_payload_opcode_string = "ACCESS_ACK_DATA";
      D_GRANT : mapper_rspAsync_payload_opcode_string = "GRANT          ";
      D_GRANT_DATA : mapper_rspAsync_payload_opcode_string = "GRANT_DATA     ";
      D_RELEASE_ACK : mapper_rspAsync_payload_opcode_string = "RELEASE_ACK    ";
      default : mapper_rspAsync_payload_opcode_string = "???????????????";
    endcase
  end
  always @(*) begin
    case(_zz_mapper_rspAsync_payload_opcode)
      D_ACCESS_ACK : _zz_mapper_rspAsync_payload_opcode_string = "ACCESS_ACK     ";
      D_ACCESS_ACK_DATA : _zz_mapper_rspAsync_payload_opcode_string = "ACCESS_ACK_DATA";
      D_GRANT : _zz_mapper_rspAsync_payload_opcode_string = "GRANT          ";
      D_GRANT_DATA : _zz_mapper_rspAsync_payload_opcode_string = "GRANT_DATA     ";
      D_RELEASE_ACK : _zz_mapper_rspAsync_payload_opcode_string = "RELEASE_ACK    ";
      default : _zz_mapper_rspAsync_payload_opcode_string = "???????????????";
    endcase
  end
  always @(*) begin
    case(mapper_rspAsync_stage_payload_opcode)
      D_ACCESS_ACK : mapper_rspAsync_stage_payload_opcode_string = "ACCESS_ACK     ";
      D_ACCESS_ACK_DATA : mapper_rspAsync_stage_payload_opcode_string = "ACCESS_ACK_DATA";
      D_GRANT : mapper_rspAsync_stage_payload_opcode_string = "GRANT          ";
      D_GRANT_DATA : mapper_rspAsync_stage_payload_opcode_string = "GRANT_DATA     ";
      D_RELEASE_ACK : mapper_rspAsync_stage_payload_opcode_string = "RELEASE_ACK    ";
      default : mapper_rspAsync_stage_payload_opcode_string = "???????????????";
    endcase
  end
  always @(*) begin
    case(mapper_rspAsync_rData_opcode)
      D_ACCESS_ACK : mapper_rspAsync_rData_opcode_string = "ACCESS_ACK     ";
      D_ACCESS_ACK_DATA : mapper_rspAsync_rData_opcode_string = "ACCESS_ACK_DATA";
      D_GRANT : mapper_rspAsync_rData_opcode_string = "GRANT          ";
      D_GRANT_DATA : mapper_rspAsync_rData_opcode_string = "GRANT_DATA     ";
      D_RELEASE_ACK : mapper_rspAsync_rData_opcode_string = "RELEASE_ACK    ";
      default : mapper_rspAsync_rData_opcode_string = "???????????????";
    endcase
  end
  `endif

  assign mapper_readErrorFlag = 1'b0;
  assign mapper_writeErrorFlag = 1'b0;
  assign mapper_askWrite = (io_bus_a_valid && (|{(io_bus_a_payload_opcode == A_PUT_PARTIAL_DATA),(io_bus_a_payload_opcode == A_PUT_FULL_DATA)}));
  assign mapper_askRead = (io_bus_a_valid && (|(io_bus_a_payload_opcode == A_GET)));
  assign mapper_doWrite = (mapper_askWrite && io_bus_a_ready);
  assign mapper_doRead = (mapper_askRead && io_bus_a_ready);
  assign mapper_address = ({2'd0,_zz_mapper_address} <<< 2'd2);
  assign mapper_halt = 1'b0;
  assign io_leds = ledReg;
  assign buttonsCc = io_buttons_buffercc_io_dataOut;
  assign io_interrupt = ((interrupts_enables & io_buttons) != 1'b0);
  assign io_bus_a_ready = (mapper_rspAsync_ready && (! mapper_halt));
  assign mapper_rspAsync_valid = ((io_bus_a_valid && (! mapper_halt)) && 1'b1);
  always @(*) begin
    mapper_rspAsync_payload_data = 32'h0;
    case(mapper_address)
      12'h0 : begin
        mapper_rspAsync_payload_data[7 : 0] = ledReg;
      end
      12'h004 : begin
        mapper_rspAsync_payload_data[0 : 0] = buttonsCc;
      end
      12'h010 : begin
        mapper_rspAsync_payload_data[0 : 0] = interrupts_enables;
      end
      default : begin
      end
    endcase
  end

  assign _zz_mapper_rspAsync_payload_opcode = ((|(io_bus_a_payload_opcode == A_GET)) ? D_ACCESS_ACK_DATA : D_ACCESS_ACK);
  assign mapper_rspAsync_payload_opcode = _zz_mapper_rspAsync_payload_opcode;
  assign mapper_rspAsync_payload_param = 3'b000;
  assign mapper_rspAsync_payload_source = io_bus_a_payload_source;
  assign mapper_rspAsync_payload_size = io_bus_a_payload_size;
  assign mapper_rspAsync_payload_corrupt = 1'b0;
  assign mapper_rspAsync_payload_denied = 1'b0;
  always @(*) begin
    mapper_rspAsync_ready = mapper_rspAsync_stage_ready;
    if(when_Stream_l477) begin
      mapper_rspAsync_ready = 1'b1;
    end
  end

  assign when_Stream_l477 = (! mapper_rspAsync_stage_valid);
  assign mapper_rspAsync_stage_valid = mapper_rspAsync_rValid;
  assign mapper_rspAsync_stage_payload_opcode = mapper_rspAsync_rData_opcode;
  assign mapper_rspAsync_stage_payload_param = mapper_rspAsync_rData_param;
  assign mapper_rspAsync_stage_payload_source = mapper_rspAsync_rData_source;
  assign mapper_rspAsync_stage_payload_size = mapper_rspAsync_rData_size;
  assign mapper_rspAsync_stage_payload_denied = mapper_rspAsync_rData_denied;
  assign mapper_rspAsync_stage_payload_data = mapper_rspAsync_rData_data;
  assign mapper_rspAsync_stage_payload_corrupt = mapper_rspAsync_rData_corrupt;
  assign io_bus_d_valid = mapper_rspAsync_stage_valid;
  assign mapper_rspAsync_stage_ready = io_bus_d_ready;
  assign io_bus_d_payload_opcode = mapper_rspAsync_stage_payload_opcode;
  assign io_bus_d_payload_param = mapper_rspAsync_stage_payload_param;
  assign io_bus_d_payload_source = mapper_rspAsync_stage_payload_source;
  assign io_bus_d_payload_size = mapper_rspAsync_stage_payload_size;
  assign io_bus_d_payload_denied = mapper_rspAsync_stage_payload_denied;
  assign io_bus_d_payload_data = mapper_rspAsync_stage_payload_data;
  assign io_bus_d_payload_corrupt = mapper_rspAsync_stage_payload_corrupt;
  always @(posedge socCtrl_systemClk or posedge socCtrl_system_reset) begin
    if(socCtrl_system_reset) begin
      ledReg <= 8'h0;
      mapper_rspAsync_rValid <= 1'b0;
    end else begin
      if(mapper_rspAsync_ready) begin
        mapper_rspAsync_rValid <= mapper_rspAsync_valid;
      end
      case(mapper_address)
        12'h0 : begin
          if(mapper_doWrite) begin
            ledReg <= io_bus_a_payload_data[7 : 0];
          end
        end
        default : begin
        end
      endcase
    end
  end

  always @(posedge socCtrl_systemClk) begin
    if(mapper_rspAsync_ready) begin
      mapper_rspAsync_rData_opcode <= mapper_rspAsync_payload_opcode;
      mapper_rspAsync_rData_param <= mapper_rspAsync_payload_param;
      mapper_rspAsync_rData_source <= mapper_rspAsync_payload_source;
      mapper_rspAsync_rData_size <= mapper_rspAsync_payload_size;
      mapper_rspAsync_rData_denied <= mapper_rspAsync_payload_denied;
      mapper_rspAsync_rData_data <= mapper_rspAsync_payload_data;
      mapper_rspAsync_rData_corrupt <= mapper_rspAsync_payload_corrupt;
    end
    case(mapper_address)
      12'h010 : begin
        if(mapper_doWrite) begin
          interrupts_enables <= io_bus_a_payload_data[0 : 0];
        end
      end
      default : begin
      end
    endcase
  end


endmodule
