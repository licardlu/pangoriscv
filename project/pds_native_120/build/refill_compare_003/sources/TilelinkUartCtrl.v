// Source-extraction compilation-unit preamble (not reference payload).
`timescale 1ns/1ps

module TilelinkUartCtrl (
  input  wire          io_bus_a_valid,
  output wire          io_bus_a_ready,
  input  wire [2:0]    io_bus_a_payload_opcode,
  input  wire [2:0]    io_bus_a_payload_param,
  input  wire [5:0]    io_bus_a_payload_source,
  input  wire [7:0]    io_bus_a_payload_address,
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
  output wire          io_uart_txd,
  input  wire          io_uart_rxd,
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
  localparam UartStopType_ONE = 1'd0;
  localparam UartStopType_TWO = 1'd1;
  localparam UartParityType_NONE = 2'd0;
  localparam UartParityType_EVEN = 2'd1;
  localparam UartParityType_ODD = 2'd2;

  reg                 uartCtrl_1_io_read_queueWithOccupancy_io_pop_ready;
  wire                uartCtrl_1_io_write_ready;
  wire                uartCtrl_1_io_read_valid;
  wire       [7:0]    uartCtrl_1_io_read_payload;
  wire                uartCtrl_1_io_uart_txd;
  wire                uartCtrl_1_io_readError;
  wire                uartCtrl_1_io_readBreak;
  wire                bridge_write_streamUnbuffered_queueWithOccupancy_io_push_ready;
  wire                bridge_write_streamUnbuffered_queueWithOccupancy_io_pop_valid;
  wire       [7:0]    bridge_write_streamUnbuffered_queueWithOccupancy_io_pop_payload;
  wire       [5:0]    bridge_write_streamUnbuffered_queueWithOccupancy_io_occupancy;
  wire       [5:0]    bridge_write_streamUnbuffered_queueWithOccupancy_io_availability;
  wire                uartCtrl_1_io_read_queueWithOccupancy_io_push_ready;
  wire                uartCtrl_1_io_read_queueWithOccupancy_io_pop_valid;
  wire       [7:0]    uartCtrl_1_io_read_queueWithOccupancy_io_pop_payload;
  wire       [5:0]    uartCtrl_1_io_read_queueWithOccupancy_io_occupancy;
  wire       [5:0]    uartCtrl_1_io_read_queueWithOccupancy_io_availability;
  wire       [5:0]    _zz_busCtrl_address;
  wire       [0:0]    _zz_bridge_misc_readError;
  wire       [0:0]    _zz_bridge_misc_readOverflowError;
  wire       [0:0]    _zz_bridge_misc_breakDetected;
  wire       [0:0]    _zz_bridge_misc_doBreak;
  wire       [0:0]    _zz_bridge_misc_doBreak_1;
  wire       [5:0]    _zz_busCtrl_rspAsync_payload_data;
  wire                busCtrl_readErrorFlag;
  wire                busCtrl_writeErrorFlag;
  wire                busCtrl_rspAsync_valid;
  reg                 busCtrl_rspAsync_ready;
  wire       [2:0]    busCtrl_rspAsync_payload_opcode;
  wire       [2:0]    busCtrl_rspAsync_payload_param;
  wire       [5:0]    busCtrl_rspAsync_payload_source;
  wire       [1:0]    busCtrl_rspAsync_payload_size;
  wire                busCtrl_rspAsync_payload_denied;
  reg        [31:0]   busCtrl_rspAsync_payload_data;
  wire                busCtrl_rspAsync_payload_corrupt;
  wire                busCtrl_askWrite;
  wire                busCtrl_askRead;
  wire                busCtrl_doWrite;
  wire                busCtrl_doRead;
  wire       [7:0]    busCtrl_address;
  wire                busCtrl_halt;
  wire                bridge_busCtrlWrapped_readErrorFlag;
  wire                bridge_busCtrlWrapped_writeErrorFlag;
  reg        [2:0]    bridge_uartConfigReg_frame_dataLength;
  reg        [0:0]    bridge_uartConfigReg_frame_stop;
  reg        [1:0]    bridge_uartConfigReg_frame_parity;
  reg        [19:0]   bridge_uartConfigReg_clockDivider;
  reg                 _zz_bridge_write_streamUnbuffered_valid;
  wire                bridge_write_streamUnbuffered_valid;
  wire                bridge_write_streamUnbuffered_ready;
  wire       [7:0]    bridge_write_streamUnbuffered_payload;
  reg                 bridge_read_streamBroken_valid;
  reg                 bridge_read_streamBroken_ready;
  wire       [7:0]    bridge_read_streamBroken_payload;
  reg                 bridge_interruptCtrl_writeIntEnable;
  reg                 bridge_interruptCtrl_readIntEnable;
  wire                bridge_interruptCtrl_readInt;
  wire                bridge_interruptCtrl_writeInt;
  wire                bridge_interruptCtrl_interrupt;
  reg                 bridge_misc_readError;
  reg                 when_BusSlaveFactory_l342;
  wire                when_BusSlaveFactory_l348;
  reg                 bridge_misc_readOverflowError;
  reg                 when_BusSlaveFactory_l342_1;
  wire                when_BusSlaveFactory_l348_1;
  wire                uartCtrl_1_io_read_isStall;
  reg                 bridge_misc_breakDetected;
  reg                 uartCtrl_1_io_readBreak_regNext;
  wire                when_UartCtrl_l164;
  reg                 when_BusSlaveFactory_l342_2;
  wire                when_BusSlaveFactory_l348_2;
  reg                 bridge_misc_doBreak;
  reg                 when_BusSlaveFactory_l378;
  wire                when_BusSlaveFactory_l380;
  reg                 when_BusSlaveFactory_l342_3;
  wire                when_BusSlaveFactory_l348_3;
  wire       [2:0]    _zz_busCtrl_rspAsync_payload_opcode;
  wire                busCtrl_rspAsync_stage_valid;
  wire                busCtrl_rspAsync_stage_ready;
  wire       [2:0]    busCtrl_rspAsync_stage_payload_opcode;
  wire       [2:0]    busCtrl_rspAsync_stage_payload_param;
  wire       [5:0]    busCtrl_rspAsync_stage_payload_source;
  wire       [1:0]    busCtrl_rspAsync_stage_payload_size;
  wire                busCtrl_rspAsync_stage_payload_denied;
  wire       [31:0]   busCtrl_rspAsync_stage_payload_data;
  wire                busCtrl_rspAsync_stage_payload_corrupt;
  reg                 busCtrl_rspAsync_rValid;
  reg        [2:0]    busCtrl_rspAsync_rData_opcode;
  reg        [2:0]    busCtrl_rspAsync_rData_param;
  reg        [5:0]    busCtrl_rspAsync_rData_source;
  reg        [1:0]    busCtrl_rspAsync_rData_size;
  reg                 busCtrl_rspAsync_rData_denied;
  reg        [31:0]   busCtrl_rspAsync_rData_data;
  reg                 busCtrl_rspAsync_rData_corrupt;
  wire                when_Stream_l477;
  wire       [1:0]    _zz_bridge_uartConfigReg_frame_parity;
  wire       [0:0]    _zz_bridge_uartConfigReg_frame_stop;
  wire                when_SlaveFactory_l134;
  `ifndef SYNTHESIS
  reg [127:0] io_bus_a_payload_opcode_string;
  reg [119:0] io_bus_d_payload_opcode_string;
  reg [119:0] busCtrl_rspAsync_payload_opcode_string;
  reg [23:0] bridge_uartConfigReg_frame_stop_string;
  reg [31:0] bridge_uartConfigReg_frame_parity_string;
  reg [119:0] _zz_busCtrl_rspAsync_payload_opcode_string;
  reg [119:0] busCtrl_rspAsync_stage_payload_opcode_string;
  reg [119:0] busCtrl_rspAsync_rData_opcode_string;
  reg [31:0] _zz_bridge_uartConfigReg_frame_parity_string;
  reg [23:0] _zz_bridge_uartConfigReg_frame_stop_string;
  `endif


  assign _zz_busCtrl_address = (io_bus_a_payload_address >>> 2'd2);
  assign _zz_bridge_misc_readError = 1'b0;
  assign _zz_bridge_misc_readOverflowError = 1'b0;
  assign _zz_bridge_misc_breakDetected = 1'b0;
  assign _zz_bridge_misc_doBreak = 1'b1;
  assign _zz_bridge_misc_doBreak_1 = 1'b0;
  assign _zz_busCtrl_rspAsync_payload_data = (6'h20 - bridge_write_streamUnbuffered_queueWithOccupancy_io_occupancy);
  UartCtrl uartCtrl_1 (
    .io_config_frame_dataLength (bridge_uartConfigReg_frame_dataLength[2:0]                          ), //i
    .io_config_frame_stop       (bridge_uartConfigReg_frame_stop                                     ), //i
    .io_config_frame_parity     (bridge_uartConfigReg_frame_parity[1:0]                              ), //i
    .io_config_clockDivider     (bridge_uartConfigReg_clockDivider[19:0]                             ), //i
    .io_write_valid             (bridge_write_streamUnbuffered_queueWithOccupancy_io_pop_valid       ), //i
    .io_write_ready             (uartCtrl_1_io_write_ready                                           ), //o
    .io_write_payload           (bridge_write_streamUnbuffered_queueWithOccupancy_io_pop_payload[7:0]), //i
    .io_read_valid              (uartCtrl_1_io_read_valid                                            ), //o
    .io_read_ready              (uartCtrl_1_io_read_queueWithOccupancy_io_push_ready                 ), //i
    .io_read_payload            (uartCtrl_1_io_read_payload[7:0]                                     ), //o
    .io_uart_txd                (uartCtrl_1_io_uart_txd                                              ), //o
    .io_uart_rxd                (io_uart_rxd                                                         ), //i
    .io_readError               (uartCtrl_1_io_readError                                             ), //o
    .io_writeBreak              (bridge_misc_doBreak                                                 ), //i
    .io_readBreak               (uartCtrl_1_io_readBreak                                             ), //o
    .socCtrl_systemClk          (socCtrl_systemClk                                                   ), //i
    .socCtrl_system_reset       (socCtrl_system_reset                                                )  //i
  );
  StreamFifo_1 bridge_write_streamUnbuffered_queueWithOccupancy (
    .io_push_valid        (bridge_write_streamUnbuffered_valid                                  ), //i
    .io_push_ready        (bridge_write_streamUnbuffered_queueWithOccupancy_io_push_ready       ), //o
    .io_push_payload      (bridge_write_streamUnbuffered_payload[7:0]                           ), //i
    .io_pop_valid         (bridge_write_streamUnbuffered_queueWithOccupancy_io_pop_valid        ), //o
    .io_pop_ready         (uartCtrl_1_io_write_ready                                            ), //i
    .io_pop_payload       (bridge_write_streamUnbuffered_queueWithOccupancy_io_pop_payload[7:0] ), //o
    .io_flush             (1'b0                                                                 ), //i
    .io_occupancy         (bridge_write_streamUnbuffered_queueWithOccupancy_io_occupancy[5:0]   ), //o
    .io_availability      (bridge_write_streamUnbuffered_queueWithOccupancy_io_availability[5:0]), //o
    .socCtrl_systemClk    (socCtrl_systemClk                                                    ), //i
    .socCtrl_system_reset (socCtrl_system_reset                                                 )  //i
  );
  StreamFifo_1 uartCtrl_1_io_read_queueWithOccupancy (
    .io_push_valid        (uartCtrl_1_io_read_valid                                  ), //i
    .io_push_ready        (uartCtrl_1_io_read_queueWithOccupancy_io_push_ready       ), //o
    .io_push_payload      (uartCtrl_1_io_read_payload[7:0]                           ), //i
    .io_pop_valid         (uartCtrl_1_io_read_queueWithOccupancy_io_pop_valid        ), //o
    .io_pop_ready         (uartCtrl_1_io_read_queueWithOccupancy_io_pop_ready        ), //i
    .io_pop_payload       (uartCtrl_1_io_read_queueWithOccupancy_io_pop_payload[7:0] ), //o
    .io_flush             (1'b0                                                      ), //i
    .io_occupancy         (uartCtrl_1_io_read_queueWithOccupancy_io_occupancy[5:0]   ), //o
    .io_availability      (uartCtrl_1_io_read_queueWithOccupancy_io_availability[5:0]), //o
    .socCtrl_systemClk    (socCtrl_systemClk                                         ), //i
    .socCtrl_system_reset (socCtrl_system_reset                                      )  //i
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
    case(busCtrl_rspAsync_payload_opcode)
      D_ACCESS_ACK : busCtrl_rspAsync_payload_opcode_string = "ACCESS_ACK     ";
      D_ACCESS_ACK_DATA : busCtrl_rspAsync_payload_opcode_string = "ACCESS_ACK_DATA";
      D_GRANT : busCtrl_rspAsync_payload_opcode_string = "GRANT          ";
      D_GRANT_DATA : busCtrl_rspAsync_payload_opcode_string = "GRANT_DATA     ";
      D_RELEASE_ACK : busCtrl_rspAsync_payload_opcode_string = "RELEASE_ACK    ";
      default : busCtrl_rspAsync_payload_opcode_string = "???????????????";
    endcase
  end
  always @(*) begin
    case(bridge_uartConfigReg_frame_stop)
      UartStopType_ONE : bridge_uartConfigReg_frame_stop_string = "ONE";
      UartStopType_TWO : bridge_uartConfigReg_frame_stop_string = "TWO";
      default : bridge_uartConfigReg_frame_stop_string = "???";
    endcase
  end
  always @(*) begin
    case(bridge_uartConfigReg_frame_parity)
      UartParityType_NONE : bridge_uartConfigReg_frame_parity_string = "NONE";
      UartParityType_EVEN : bridge_uartConfigReg_frame_parity_string = "EVEN";
      UartParityType_ODD : bridge_uartConfigReg_frame_parity_string = "ODD ";
      default : bridge_uartConfigReg_frame_parity_string = "????";
    endcase
  end
  always @(*) begin
    case(_zz_busCtrl_rspAsync_payload_opcode)
      D_ACCESS_ACK : _zz_busCtrl_rspAsync_payload_opcode_string = "ACCESS_ACK     ";
      D_ACCESS_ACK_DATA : _zz_busCtrl_rspAsync_payload_opcode_string = "ACCESS_ACK_DATA";
      D_GRANT : _zz_busCtrl_rspAsync_payload_opcode_string = "GRANT          ";
      D_GRANT_DATA : _zz_busCtrl_rspAsync_payload_opcode_string = "GRANT_DATA     ";
      D_RELEASE_ACK : _zz_busCtrl_rspAsync_payload_opcode_string = "RELEASE_ACK    ";
      default : _zz_busCtrl_rspAsync_payload_opcode_string = "???????????????";
    endcase
  end
  always @(*) begin
    case(busCtrl_rspAsync_stage_payload_opcode)
      D_ACCESS_ACK : busCtrl_rspAsync_stage_payload_opcode_string = "ACCESS_ACK     ";
      D_ACCESS_ACK_DATA : busCtrl_rspAsync_stage_payload_opcode_string = "ACCESS_ACK_DATA";
      D_GRANT : busCtrl_rspAsync_stage_payload_opcode_string = "GRANT          ";
      D_GRANT_DATA : busCtrl_rspAsync_stage_payload_opcode_string = "GRANT_DATA     ";
      D_RELEASE_ACK : busCtrl_rspAsync_stage_payload_opcode_string = "RELEASE_ACK    ";
      default : busCtrl_rspAsync_stage_payload_opcode_string = "???????????????";
    endcase
  end
  always @(*) begin
    case(busCtrl_rspAsync_rData_opcode)
      D_ACCESS_ACK : busCtrl_rspAsync_rData_opcode_string = "ACCESS_ACK     ";
      D_ACCESS_ACK_DATA : busCtrl_rspAsync_rData_opcode_string = "ACCESS_ACK_DATA";
      D_GRANT : busCtrl_rspAsync_rData_opcode_string = "GRANT          ";
      D_GRANT_DATA : busCtrl_rspAsync_rData_opcode_string = "GRANT_DATA     ";
      D_RELEASE_ACK : busCtrl_rspAsync_rData_opcode_string = "RELEASE_ACK    ";
      default : busCtrl_rspAsync_rData_opcode_string = "???????????????";
    endcase
  end
  always @(*) begin
    case(_zz_bridge_uartConfigReg_frame_parity)
      UartParityType_NONE : _zz_bridge_uartConfigReg_frame_parity_string = "NONE";
      UartParityType_EVEN : _zz_bridge_uartConfigReg_frame_parity_string = "EVEN";
      UartParityType_ODD : _zz_bridge_uartConfigReg_frame_parity_string = "ODD ";
      default : _zz_bridge_uartConfigReg_frame_parity_string = "????";
    endcase
  end
  always @(*) begin
    case(_zz_bridge_uartConfigReg_frame_stop)
      UartStopType_ONE : _zz_bridge_uartConfigReg_frame_stop_string = "ONE";
      UartStopType_TWO : _zz_bridge_uartConfigReg_frame_stop_string = "TWO";
      default : _zz_bridge_uartConfigReg_frame_stop_string = "???";
    endcase
  end
  `endif

  assign io_uart_txd = uartCtrl_1_io_uart_txd;
  assign busCtrl_readErrorFlag = 1'b0;
  assign busCtrl_writeErrorFlag = 1'b0;
  assign busCtrl_askWrite = (io_bus_a_valid && (|{(io_bus_a_payload_opcode == A_PUT_PARTIAL_DATA),(io_bus_a_payload_opcode == A_PUT_FULL_DATA)}));
  assign busCtrl_askRead = (io_bus_a_valid && (|(io_bus_a_payload_opcode == A_GET)));
  assign busCtrl_doWrite = (busCtrl_askWrite && io_bus_a_ready);
  assign busCtrl_doRead = (busCtrl_askRead && io_bus_a_ready);
  assign busCtrl_address = ({2'd0,_zz_busCtrl_address} <<< 2'd2);
  assign busCtrl_halt = 1'b0;
  assign bridge_busCtrlWrapped_readErrorFlag = 1'b0;
  assign bridge_busCtrlWrapped_writeErrorFlag = 1'b0;
  always @(*) begin
    _zz_bridge_write_streamUnbuffered_valid = 1'b0;
    case(busCtrl_address)
      8'h0 : begin
        if(busCtrl_doWrite) begin
          _zz_bridge_write_streamUnbuffered_valid = 1'b1;
        end
      end
      default : begin
      end
    endcase
  end

  assign bridge_write_streamUnbuffered_valid = _zz_bridge_write_streamUnbuffered_valid;
  assign bridge_write_streamUnbuffered_payload = io_bus_a_payload_data[7 : 0];
  assign bridge_write_streamUnbuffered_ready = bridge_write_streamUnbuffered_queueWithOccupancy_io_push_ready;
  always @(*) begin
    bridge_read_streamBroken_valid = uartCtrl_1_io_read_queueWithOccupancy_io_pop_valid;
    if(uartCtrl_1_io_readBreak) begin
      bridge_read_streamBroken_valid = 1'b0;
    end
  end

  always @(*) begin
    uartCtrl_1_io_read_queueWithOccupancy_io_pop_ready = bridge_read_streamBroken_ready;
    if(uartCtrl_1_io_readBreak) begin
      uartCtrl_1_io_read_queueWithOccupancy_io_pop_ready = 1'b1;
    end
  end

  assign bridge_read_streamBroken_payload = uartCtrl_1_io_read_queueWithOccupancy_io_pop_payload;
  always @(*) begin
    bridge_read_streamBroken_ready = 1'b0;
    case(busCtrl_address)
      8'h0 : begin
        if(busCtrl_doRead) begin
          bridge_read_streamBroken_ready = 1'b1;
        end
      end
      default : begin
      end
    endcase
  end

  assign bridge_interruptCtrl_readInt = (bridge_interruptCtrl_readIntEnable && bridge_read_streamBroken_valid);
  assign bridge_interruptCtrl_writeInt = (bridge_interruptCtrl_writeIntEnable && (! bridge_write_streamUnbuffered_queueWithOccupancy_io_pop_valid));
  assign bridge_interruptCtrl_interrupt = (bridge_interruptCtrl_readInt || bridge_interruptCtrl_writeInt);
  always @(*) begin
    when_BusSlaveFactory_l342 = 1'b0;
    case(busCtrl_address)
      8'h10 : begin
        if(busCtrl_doWrite) begin
          when_BusSlaveFactory_l342 = 1'b1;
        end
      end
      default : begin
      end
    endcase
  end

  assign when_BusSlaveFactory_l348 = io_bus_a_payload_data[0];
  always @(*) begin
    when_BusSlaveFactory_l342_1 = 1'b0;
    case(busCtrl_address)
      8'h10 : begin
        if(busCtrl_doWrite) begin
          when_BusSlaveFactory_l342_1 = 1'b1;
        end
      end
      default : begin
      end
    endcase
  end

  assign when_BusSlaveFactory_l348_1 = io_bus_a_payload_data[1];
  assign uartCtrl_1_io_read_isStall = (uartCtrl_1_io_read_valid && (! uartCtrl_1_io_read_queueWithOccupancy_io_push_ready));
  assign when_UartCtrl_l164 = (uartCtrl_1_io_readBreak && (! uartCtrl_1_io_readBreak_regNext));
  always @(*) begin
    when_BusSlaveFactory_l342_2 = 1'b0;
    case(busCtrl_address)
      8'h10 : begin
        if(busCtrl_doWrite) begin
          when_BusSlaveFactory_l342_2 = 1'b1;
        end
      end
      default : begin
      end
    endcase
  end

  assign when_BusSlaveFactory_l348_2 = io_bus_a_payload_data[9];
  always @(*) begin
    when_BusSlaveFactory_l378 = 1'b0;
    case(busCtrl_address)
      8'h10 : begin
        if(busCtrl_doWrite) begin
          when_BusSlaveFactory_l378 = 1'b1;
        end
      end
      default : begin
      end
    endcase
  end

  assign when_BusSlaveFactory_l380 = io_bus_a_payload_data[10];
  always @(*) begin
    when_BusSlaveFactory_l342_3 = 1'b0;
    case(busCtrl_address)
      8'h10 : begin
        if(busCtrl_doWrite) begin
          when_BusSlaveFactory_l342_3 = 1'b1;
        end
      end
      default : begin
      end
    endcase
  end

  assign when_BusSlaveFactory_l348_3 = io_bus_a_payload_data[11];
  assign io_interrupt = bridge_interruptCtrl_interrupt;
  assign io_bus_a_ready = (busCtrl_rspAsync_ready && (! busCtrl_halt));
  assign busCtrl_rspAsync_valid = ((io_bus_a_valid && (! busCtrl_halt)) && 1'b1);
  always @(*) begin
    busCtrl_rspAsync_payload_data = 32'h0;
    case(busCtrl_address)
      8'h0 : begin
        busCtrl_rspAsync_payload_data[16 : 16] = (bridge_read_streamBroken_valid ^ 1'b0);
        busCtrl_rspAsync_payload_data[7 : 0] = bridge_read_streamBroken_payload;
      end
      8'h04 : begin
        busCtrl_rspAsync_payload_data[21 : 16] = _zz_busCtrl_rspAsync_payload_data;
        busCtrl_rspAsync_payload_data[15 : 15] = bridge_write_streamUnbuffered_queueWithOccupancy_io_pop_valid;
        busCtrl_rspAsync_payload_data[29 : 24] = uartCtrl_1_io_read_queueWithOccupancy_io_occupancy;
        busCtrl_rspAsync_payload_data[0 : 0] = bridge_interruptCtrl_writeIntEnable;
        busCtrl_rspAsync_payload_data[1 : 1] = bridge_interruptCtrl_readIntEnable;
        busCtrl_rspAsync_payload_data[8 : 8] = bridge_interruptCtrl_writeInt;
        busCtrl_rspAsync_payload_data[9 : 9] = bridge_interruptCtrl_readInt;
      end
      8'h10 : begin
        busCtrl_rspAsync_payload_data[0 : 0] = bridge_misc_readError;
        busCtrl_rspAsync_payload_data[1 : 1] = bridge_misc_readOverflowError;
        busCtrl_rspAsync_payload_data[8 : 8] = uartCtrl_1_io_readBreak;
        busCtrl_rspAsync_payload_data[9 : 9] = bridge_misc_breakDetected;
      end
      default : begin
      end
    endcase
  end

  assign _zz_busCtrl_rspAsync_payload_opcode = ((|(io_bus_a_payload_opcode == A_GET)) ? D_ACCESS_ACK_DATA : D_ACCESS_ACK);
  assign busCtrl_rspAsync_payload_opcode = _zz_busCtrl_rspAsync_payload_opcode;
  assign busCtrl_rspAsync_payload_param = 3'b000;
  assign busCtrl_rspAsync_payload_source = io_bus_a_payload_source;
  assign busCtrl_rspAsync_payload_size = io_bus_a_payload_size;
  assign busCtrl_rspAsync_payload_corrupt = 1'b0;
  assign busCtrl_rspAsync_payload_denied = 1'b0;
  always @(*) begin
    busCtrl_rspAsync_ready = busCtrl_rspAsync_stage_ready;
    if(when_Stream_l477) begin
      busCtrl_rspAsync_ready = 1'b1;
    end
  end

  assign when_Stream_l477 = (! busCtrl_rspAsync_stage_valid);
  assign busCtrl_rspAsync_stage_valid = busCtrl_rspAsync_rValid;
  assign busCtrl_rspAsync_stage_payload_opcode = busCtrl_rspAsync_rData_opcode;
  assign busCtrl_rspAsync_stage_payload_param = busCtrl_rspAsync_rData_param;
  assign busCtrl_rspAsync_stage_payload_source = busCtrl_rspAsync_rData_source;
  assign busCtrl_rspAsync_stage_payload_size = busCtrl_rspAsync_rData_size;
  assign busCtrl_rspAsync_stage_payload_denied = busCtrl_rspAsync_rData_denied;
  assign busCtrl_rspAsync_stage_payload_data = busCtrl_rspAsync_rData_data;
  assign busCtrl_rspAsync_stage_payload_corrupt = busCtrl_rspAsync_rData_corrupt;
  assign io_bus_d_valid = busCtrl_rspAsync_stage_valid;
  assign busCtrl_rspAsync_stage_ready = io_bus_d_ready;
  assign io_bus_d_payload_opcode = busCtrl_rspAsync_stage_payload_opcode;
  assign io_bus_d_payload_param = busCtrl_rspAsync_stage_payload_param;
  assign io_bus_d_payload_source = busCtrl_rspAsync_stage_payload_source;
  assign io_bus_d_payload_size = busCtrl_rspAsync_stage_payload_size;
  assign io_bus_d_payload_denied = busCtrl_rspAsync_stage_payload_denied;
  assign io_bus_d_payload_data = busCtrl_rspAsync_stage_payload_data;
  assign io_bus_d_payload_corrupt = busCtrl_rspAsync_stage_payload_corrupt;
  assign _zz_bridge_uartConfigReg_frame_parity = io_bus_a_payload_data[9 : 8];
  assign _zz_bridge_uartConfigReg_frame_stop = io_bus_a_payload_data[16 : 16];
  assign when_SlaveFactory_l134 = ((busCtrl_address & (~ 8'h03)) == 8'h08);
  always @(posedge socCtrl_systemClk or posedge socCtrl_system_reset) begin
    if(socCtrl_system_reset) begin
      bridge_uartConfigReg_clockDivider <= 20'h0;
      bridge_uartConfigReg_clockDivider <= 20'h00081;
      bridge_uartConfigReg_frame_dataLength <= 3'b111;
      bridge_uartConfigReg_frame_parity <= UartParityType_NONE;
      bridge_uartConfigReg_frame_stop <= UartStopType_ONE;
      bridge_interruptCtrl_writeIntEnable <= 1'b0;
      bridge_interruptCtrl_readIntEnable <= 1'b0;
      bridge_misc_readError <= 1'b0;
      bridge_misc_readOverflowError <= 1'b0;
      bridge_misc_breakDetected <= 1'b0;
      bridge_misc_doBreak <= 1'b0;
      busCtrl_rspAsync_rValid <= 1'b0;
    end else begin
      if(when_BusSlaveFactory_l342) begin
        if(when_BusSlaveFactory_l348) begin
          bridge_misc_readError <= _zz_bridge_misc_readError[0];
        end
      end
      if(uartCtrl_1_io_readError) begin
        bridge_misc_readError <= 1'b1;
      end
      if(when_BusSlaveFactory_l342_1) begin
        if(when_BusSlaveFactory_l348_1) begin
          bridge_misc_readOverflowError <= _zz_bridge_misc_readOverflowError[0];
        end
      end
      if(uartCtrl_1_io_read_isStall) begin
        bridge_misc_readOverflowError <= 1'b1;
      end
      if(when_UartCtrl_l164) begin
        bridge_misc_breakDetected <= 1'b1;
      end
      if(when_BusSlaveFactory_l342_2) begin
        if(when_BusSlaveFactory_l348_2) begin
          bridge_misc_breakDetected <= _zz_bridge_misc_breakDetected[0];
        end
      end
      if(when_BusSlaveFactory_l378) begin
        if(when_BusSlaveFactory_l380) begin
          bridge_misc_doBreak <= _zz_bridge_misc_doBreak[0];
        end
      end
      if(when_BusSlaveFactory_l342_3) begin
        if(when_BusSlaveFactory_l348_3) begin
          bridge_misc_doBreak <= _zz_bridge_misc_doBreak_1[0];
        end
      end
      if(busCtrl_rspAsync_ready) begin
        busCtrl_rspAsync_rValid <= busCtrl_rspAsync_valid;
      end
      case(busCtrl_address)
        8'h0c : begin
          if(busCtrl_doWrite) begin
            bridge_uartConfigReg_frame_dataLength <= io_bus_a_payload_data[2 : 0];
            bridge_uartConfigReg_frame_parity <= _zz_bridge_uartConfigReg_frame_parity;
            bridge_uartConfigReg_frame_stop <= _zz_bridge_uartConfigReg_frame_stop;
          end
        end
        8'h04 : begin
          if(busCtrl_doWrite) begin
            bridge_interruptCtrl_writeIntEnable <= io_bus_a_payload_data[0];
            bridge_interruptCtrl_readIntEnable <= io_bus_a_payload_data[1];
          end
        end
        default : begin
        end
      endcase
      if(when_SlaveFactory_l134) begin
        if(busCtrl_doWrite) begin
          bridge_uartConfigReg_clockDivider[19 : 0] <= io_bus_a_payload_data[19 : 0];
        end
      end
    end
  end

  always @(posedge socCtrl_systemClk) begin
    uartCtrl_1_io_readBreak_regNext <= uartCtrl_1_io_readBreak;
    if(busCtrl_rspAsync_ready) begin
      busCtrl_rspAsync_rData_opcode <= busCtrl_rspAsync_payload_opcode;
      busCtrl_rspAsync_rData_param <= busCtrl_rspAsync_payload_param;
      busCtrl_rspAsync_rData_source <= busCtrl_rspAsync_payload_source;
      busCtrl_rspAsync_rData_size <= busCtrl_rspAsync_payload_size;
      busCtrl_rspAsync_rData_denied <= busCtrl_rspAsync_payload_denied;
      busCtrl_rspAsync_rData_data <= busCtrl_rspAsync_payload_data;
      busCtrl_rspAsync_rData_corrupt <= busCtrl_rspAsync_payload_corrupt;
    end
  end


endmodule
