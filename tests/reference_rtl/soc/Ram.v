// Source-extraction compilation-unit preamble (not reference payload).
`timescale 1ns/1ps

module Ram (
  input  wire          io_up_a_valid,
  output reg           io_up_a_ready,
  input  wire [2:0]    io_up_a_payload_opcode,
  input  wire [2:0]    io_up_a_payload_param,
  input  wire [5:0]    io_up_a_payload_source,
  input  wire [15:0]   io_up_a_payload_address,
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

  reg        [63:0]   mem_spinal_port0;
  reg        [2:0]    _zz_when_Ram_l55;
  wire       [12:0]   _zz_port_address;
  reg        [2:0]    _zz_io_up_a_tracker_last;
  wire       [7:0]    _zz_ordering_payload_bytes;
  wire                pipeline_ctrl_0_up_isValid;
  wire                pipeline_ctrl_1_down_isReady;
  wire                pipeline_ctrl_1_up_isValid;
  wire                pipeline_ctrl_0_down_isValid;
  wire                pipeline_ctrl_0_down_isReady;
  reg                 pipeline_ctrl_1_up_cmd_LAST;
  reg        [5:0]    pipeline_ctrl_1_up_cmd_SOURCE;
  reg        [2:0]    pipeline_ctrl_1_up_cmd_SIZE;
  reg                 pipeline_ctrl_1_up_cmd_IS_GET;
  reg                 pipeline_ctrl_1_down_valid;
  wire                pipeline_ctrl_0_down_valid;
  wire                pipeline_ctrl_0_up_ready;
  reg                 pipeline_ctrl_0_down_ready;
  reg                 pipeline_ctrl_1_up_ready;
  wire       [2:0]    pipeline_ctrl_1_down_cmd_SIZE;
  wire       [5:0]    pipeline_ctrl_1_down_cmd_SOURCE;
  reg                 pipeline_ctrl_1_up_valid;
  wire                pipeline_ctrl_1_down_cmd_IS_GET;
  wire                pipeline_ctrl_1_down_cmd_LAST;
  wire                pipeline_ctrl_0_up_isFiring;
  wire                pipeline_ctrl_0_up_isReady;
  reg                 pipeline_ctrl_0_up_valid;
  reg                 pipeline_ctrl_0_down_cmd_LAST;
  reg        [5:0]    pipeline_ctrl_0_down_cmd_SOURCE;
  reg        [2:0]    pipeline_ctrl_0_down_cmd_SIZE;
  reg                 pipeline_ctrl_0_down_cmd_IS_GET;
  wire       [12:0]   port_address;
  wire       [63:0]   port_rdata;
  wire       [63:0]   port_wdata;
  wire                port_enable;
  wire                port_write;
  wire       [7:0]    port_mask;
  wire       [63:0]   _zz_port_rdata;
  wire       [12:0]   pipeline_cmd_addressShifted;
  reg        [2:0]    pipeline_cmd_fsm_counter;
  reg        [12:0]   pipeline_cmd_fsm_address;
  reg        [2:0]    pipeline_cmd_fsm_size;
  reg        [5:0]    pipeline_cmd_fsm_source;
  reg                 pipeline_cmd_fsm_isGet;
  wire                pipeline_cmd_fsm_busy;
  wire                when_Ram_l43;
  wire                io_up_a_fire;
  wire                when_Ram_l48;
  wire                when_Ram_l55;
  wire                pipeline_rsp_takeIt;
  wire                pipeline_ctrl_1_haltRequest_Ram_l75;
  wire       [2:0]    _zz_io_up_d_payload_opcode;
  wire                when_StageLink_l71;
  wire                when_CtrlLink_l219;
  wire                ordering_valid;
  wire       [6:0]    ordering_payload_bytes;
  reg        [2:0]    io_up_a_tracker_beat;
  wire                io_up_a_tracker_last;
  reg                 ordering_stage_valid;
  reg        [6:0]    ordering_stage_payload_bytes;
  `ifndef SYNTHESIS
  reg [127:0] io_up_a_payload_opcode_string;
  reg [119:0] io_up_d_payload_opcode_string;
  reg [119:0] _zz_io_up_d_payload_opcode_string;
  `endif

  reg [7:0] mem_symbol0 [0:8191];
  reg [7:0] mem_symbol1 [0:8191];
  reg [7:0] mem_symbol2 [0:8191];
  reg [7:0] mem_symbol3 [0:8191];
  reg [7:0] mem_symbol4 [0:8191];
  reg [7:0] mem_symbol5 [0:8191];
  reg [7:0] mem_symbol6 [0:8191];
  reg [7:0] mem_symbol7 [0:8191];
  reg [7:0] _zz_memsymbol_read;
  reg [7:0] _zz_memsymbol_read_1;
  reg [7:0] _zz_memsymbol_read_2;
  reg [7:0] _zz_memsymbol_read_3;
  reg [7:0] _zz_memsymbol_read_4;
  reg [7:0] _zz_memsymbol_read_5;
  reg [7:0] _zz_memsymbol_read_6;
  reg [7:0] _zz_memsymbol_read_7;

  assign _zz_port_address = {10'd0, pipeline_cmd_fsm_counter};
  assign _zz_ordering_payload_bytes = ({7'd0,1'b1} <<< io_up_a_payload_size);
  initial begin
    $readmemb("MicroSoc.v_toplevel_system_ram_thread_logic_mem_symbol0.bin",mem_symbol0);
    $readmemb("MicroSoc.v_toplevel_system_ram_thread_logic_mem_symbol1.bin",mem_symbol1);
    $readmemb("MicroSoc.v_toplevel_system_ram_thread_logic_mem_symbol2.bin",mem_symbol2);
    $readmemb("MicroSoc.v_toplevel_system_ram_thread_logic_mem_symbol3.bin",mem_symbol3);
    $readmemb("MicroSoc.v_toplevel_system_ram_thread_logic_mem_symbol4.bin",mem_symbol4);
    $readmemb("MicroSoc.v_toplevel_system_ram_thread_logic_mem_symbol5.bin",mem_symbol5);
    $readmemb("MicroSoc.v_toplevel_system_ram_thread_logic_mem_symbol6.bin",mem_symbol6);
    $readmemb("MicroSoc.v_toplevel_system_ram_thread_logic_mem_symbol7.bin",mem_symbol7);
  end
  always @(*) begin
    mem_spinal_port0 = {_zz_memsymbol_read_7, _zz_memsymbol_read_6, _zz_memsymbol_read_5, _zz_memsymbol_read_4, _zz_memsymbol_read_3, _zz_memsymbol_read_2, _zz_memsymbol_read_1, _zz_memsymbol_read};
  end
  always @(posedge socCtrl_systemClk) begin
    if(port_enable) begin
      _zz_memsymbol_read <= mem_symbol0[port_address];
      _zz_memsymbol_read_1 <= mem_symbol1[port_address];
      _zz_memsymbol_read_2 <= mem_symbol2[port_address];
      _zz_memsymbol_read_3 <= mem_symbol3[port_address];
      _zz_memsymbol_read_4 <= mem_symbol4[port_address];
      _zz_memsymbol_read_5 <= mem_symbol5[port_address];
      _zz_memsymbol_read_6 <= mem_symbol6[port_address];
      _zz_memsymbol_read_7 <= mem_symbol7[port_address];
    end
  end

  always @(posedge socCtrl_systemClk) begin
    if(port_mask[0] && port_enable && port_write ) begin
      mem_symbol0[port_address] <= _zz_port_rdata[7 : 0];
    end
    if(port_mask[1] && port_enable && port_write ) begin
      mem_symbol1[port_address] <= _zz_port_rdata[15 : 8];
    end
    if(port_mask[2] && port_enable && port_write ) begin
      mem_symbol2[port_address] <= _zz_port_rdata[23 : 16];
    end
    if(port_mask[3] && port_enable && port_write ) begin
      mem_symbol3[port_address] <= _zz_port_rdata[31 : 24];
    end
    if(port_mask[4] && port_enable && port_write ) begin
      mem_symbol4[port_address] <= _zz_port_rdata[39 : 32];
    end
    if(port_mask[5] && port_enable && port_write ) begin
      mem_symbol5[port_address] <= _zz_port_rdata[47 : 40];
    end
    if(port_mask[6] && port_enable && port_write ) begin
      mem_symbol6[port_address] <= _zz_port_rdata[55 : 48];
    end
    if(port_mask[7] && port_enable && port_write ) begin
      mem_symbol7[port_address] <= _zz_port_rdata[63 : 56];
    end
  end

  always @(*) begin
    case(pipeline_ctrl_0_down_cmd_SIZE)
      3'b000 : _zz_when_Ram_l55 = 3'b000;
      3'b001 : _zz_when_Ram_l55 = 3'b000;
      3'b010 : _zz_when_Ram_l55 = 3'b000;
      3'b011 : _zz_when_Ram_l55 = 3'b000;
      3'b100 : _zz_when_Ram_l55 = 3'b001;
      3'b101 : _zz_when_Ram_l55 = 3'b011;
      default : _zz_when_Ram_l55 = 3'b111;
    endcase
  end

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
    case(_zz_io_up_d_payload_opcode)
      D_ACCESS_ACK : _zz_io_up_d_payload_opcode_string = "ACCESS_ACK     ";
      D_ACCESS_ACK_DATA : _zz_io_up_d_payload_opcode_string = "ACCESS_ACK_DATA";
      D_GRANT : _zz_io_up_d_payload_opcode_string = "GRANT          ";
      D_GRANT_DATA : _zz_io_up_d_payload_opcode_string = "GRANT_DATA     ";
      D_RELEASE_ACK : _zz_io_up_d_payload_opcode_string = "RELEASE_ACK    ";
      default : _zz_io_up_d_payload_opcode_string = "???????????????";
    endcase
  end
  `endif

  assign _zz_port_rdata = port_wdata;
  assign port_rdata = mem_spinal_port0;
  always @(*) begin
    pipeline_ctrl_0_down_cmd_IS_GET = (|(io_up_a_payload_opcode == A_GET));
    if(pipeline_cmd_fsm_busy) begin
      pipeline_ctrl_0_down_cmd_IS_GET = pipeline_cmd_fsm_isGet;
    end
  end

  always @(*) begin
    pipeline_ctrl_0_down_cmd_SIZE = io_up_a_payload_size;
    if(pipeline_cmd_fsm_busy) begin
      pipeline_ctrl_0_down_cmd_SIZE = pipeline_cmd_fsm_size;
    end
  end

  always @(*) begin
    pipeline_ctrl_0_down_cmd_SOURCE = io_up_a_payload_source;
    if(pipeline_cmd_fsm_busy) begin
      pipeline_ctrl_0_down_cmd_SOURCE = pipeline_cmd_fsm_source;
    end
  end

  always @(*) begin
    pipeline_ctrl_0_down_cmd_LAST = 1'b1;
    if(when_Ram_l55) begin
      pipeline_ctrl_0_down_cmd_LAST = 1'b0;
    end
  end

  always @(*) begin
    pipeline_ctrl_0_up_valid = io_up_a_valid;
    if(when_Ram_l43) begin
      pipeline_ctrl_0_up_valid = 1'b1;
    end
  end

  always @(*) begin
    io_up_a_ready = pipeline_ctrl_0_up_isReady;
    if(when_Ram_l43) begin
      io_up_a_ready = 1'b0;
    end
  end

  assign pipeline_cmd_addressShifted = (io_up_a_payload_address >>> 2'd3);
  assign port_enable = pipeline_ctrl_0_up_isFiring;
  assign port_write = (! pipeline_ctrl_0_down_cmd_IS_GET);
  assign port_wdata = io_up_a_payload_data;
  assign port_mask = io_up_a_payload_mask;
  assign pipeline_cmd_fsm_busy = (pipeline_cmd_fsm_counter != 3'b000);
  assign when_Ram_l43 = (pipeline_cmd_fsm_busy && pipeline_cmd_fsm_isGet);
  assign io_up_a_fire = (io_up_a_valid && io_up_a_ready);
  assign when_Ram_l48 = (io_up_a_fire && (! pipeline_cmd_fsm_busy));
  assign when_Ram_l55 = (pipeline_cmd_fsm_counter != _zz_when_Ram_l55);
  assign port_address = ((pipeline_cmd_fsm_busy ? pipeline_cmd_fsm_address : pipeline_cmd_addressShifted) | _zz_port_address);
  assign pipeline_rsp_takeIt = (pipeline_ctrl_1_down_cmd_LAST || pipeline_ctrl_1_down_cmd_IS_GET);
  assign pipeline_ctrl_1_haltRequest_Ram_l75 = ((! io_up_d_ready) && pipeline_rsp_takeIt);
  assign io_up_d_valid = (pipeline_ctrl_1_up_valid && pipeline_rsp_takeIt);
  assign _zz_io_up_d_payload_opcode = (pipeline_ctrl_1_down_cmd_IS_GET ? D_ACCESS_ACK_DATA : D_ACCESS_ACK);
  assign io_up_d_payload_opcode = _zz_io_up_d_payload_opcode;
  assign io_up_d_payload_param = 3'b000;
  assign io_up_d_payload_source = pipeline_ctrl_1_down_cmd_SOURCE;
  assign io_up_d_payload_size = pipeline_ctrl_1_down_cmd_SIZE;
  assign io_up_d_payload_denied = 1'b0;
  assign io_up_d_payload_corrupt = 1'b0;
  assign io_up_d_payload_data = port_rdata;
  always @(*) begin
    pipeline_ctrl_0_down_ready = pipeline_ctrl_1_up_ready;
    if(when_StageLink_l71) begin
      pipeline_ctrl_0_down_ready = 1'b1;
    end
  end

  assign when_StageLink_l71 = (! pipeline_ctrl_1_up_isValid);
  assign pipeline_ctrl_0_down_valid = pipeline_ctrl_0_up_valid;
  assign pipeline_ctrl_0_up_ready = pipeline_ctrl_0_down_isReady;
  always @(*) begin
    pipeline_ctrl_1_down_valid = pipeline_ctrl_1_up_valid;
    if(when_CtrlLink_l219) begin
      pipeline_ctrl_1_down_valid = 1'b0;
    end
  end

  always @(*) begin
    pipeline_ctrl_1_up_ready = pipeline_ctrl_1_down_isReady;
    if(when_CtrlLink_l219) begin
      pipeline_ctrl_1_up_ready = 1'b0;
    end
  end

  assign when_CtrlLink_l219 = (|pipeline_ctrl_1_haltRequest_Ram_l75);
  assign pipeline_ctrl_1_down_cmd_IS_GET = pipeline_ctrl_1_up_cmd_IS_GET;
  assign pipeline_ctrl_1_down_cmd_SIZE = pipeline_ctrl_1_up_cmd_SIZE;
  assign pipeline_ctrl_1_down_cmd_SOURCE = pipeline_ctrl_1_up_cmd_SOURCE;
  assign pipeline_ctrl_1_down_cmd_LAST = pipeline_ctrl_1_up_cmd_LAST;
  assign pipeline_ctrl_0_down_isValid = pipeline_ctrl_0_down_valid;
  assign pipeline_ctrl_0_down_isReady = pipeline_ctrl_0_down_ready;
  assign pipeline_ctrl_1_up_isValid = pipeline_ctrl_1_up_valid;
  assign pipeline_ctrl_0_up_isFiring = (pipeline_ctrl_0_up_isValid && pipeline_ctrl_0_up_isReady);
  assign pipeline_ctrl_0_up_isValid = pipeline_ctrl_0_up_valid;
  assign pipeline_ctrl_0_up_isReady = pipeline_ctrl_0_up_ready;
  assign pipeline_ctrl_1_down_isReady = 1'b1;
  assign io_up_a_tracker_last = ((! (|{(io_up_a_payload_opcode == A_LOGICAL_DATA),(io_up_a_payload_opcode == A_ARITHMETIC_DATA),(io_up_a_payload_opcode == A_PUT_PARTIAL_DATA),(io_up_a_payload_opcode == A_PUT_FULL_DATA)})) || (io_up_a_tracker_beat == _zz_io_up_a_tracker_last));
  assign ordering_valid = (io_up_a_fire && io_up_a_tracker_last);
  assign ordering_payload_bytes = _zz_ordering_payload_bytes[6:0];
  always @(posedge socCtrl_systemClk or posedge socCtrl_system_reset) begin
    if(socCtrl_system_reset) begin
      pipeline_cmd_fsm_counter <= 3'b000;
      pipeline_ctrl_1_up_valid <= 1'b0;
      io_up_a_tracker_beat <= 3'b000;
      ordering_stage_valid <= 1'b0;
    end else begin
      if(pipeline_ctrl_0_up_isFiring) begin
        pipeline_cmd_fsm_counter <= (pipeline_cmd_fsm_counter + 3'b001);
        if(pipeline_ctrl_0_down_cmd_LAST) begin
          pipeline_cmd_fsm_counter <= 3'b000;
        end
      end
      if(pipeline_ctrl_0_down_isReady) begin
        pipeline_ctrl_1_up_valid <= pipeline_ctrl_0_down_isValid;
      end
      if(io_up_a_fire) begin
        io_up_a_tracker_beat <= (io_up_a_tracker_beat + 3'b001);
        if(io_up_a_tracker_last) begin
          io_up_a_tracker_beat <= 3'b000;
        end
      end
      ordering_stage_valid <= ordering_valid;
    end
  end

  always @(posedge socCtrl_systemClk) begin
    if(when_Ram_l48) begin
      pipeline_cmd_fsm_size <= io_up_a_payload_size;
      pipeline_cmd_fsm_source <= io_up_a_payload_source;
      pipeline_cmd_fsm_isGet <= (|(io_up_a_payload_opcode == A_GET));
      pipeline_cmd_fsm_address <= pipeline_cmd_addressShifted;
    end
    if(pipeline_ctrl_0_down_isReady) begin
      pipeline_ctrl_1_up_cmd_IS_GET <= pipeline_ctrl_0_down_cmd_IS_GET;
      pipeline_ctrl_1_up_cmd_SIZE <= pipeline_ctrl_0_down_cmd_SIZE;
      pipeline_ctrl_1_up_cmd_SOURCE <= pipeline_ctrl_0_down_cmd_SOURCE;
      pipeline_ctrl_1_up_cmd_LAST <= pipeline_ctrl_0_down_cmd_LAST;
    end
    ordering_stage_payload_bytes <= ordering_payload_bytes;
  end


endmodule
