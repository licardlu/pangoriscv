
module pango_replica_core (
  input  wire [63:0]   PrivilegedPlugin_logic_rdtime,
  input  wire          PrivilegedPlugin_logic_harts_0_int_m_timer /* verilator public */ ,
  input  wire          PrivilegedPlugin_logic_harts_0_int_m_software /* verilator public */ ,
  input  wire          PrivilegedPlugin_logic_harts_0_int_m_external /* verilator public */ ,
  output wire          FetchL1TileLinkPlugin_logic_down_a_valid,
  input  wire          FetchL1TileLinkPlugin_logic_down_a_ready,
  output wire [2:0]    FetchL1TileLinkPlugin_logic_down_a_payload_opcode,
  output wire [2:0]    FetchL1TileLinkPlugin_logic_down_a_payload_param,
  output wire [2:0]    FetchL1TileLinkPlugin_logic_down_a_payload_source,
  output wire [31:0]   FetchL1TileLinkPlugin_logic_down_a_payload_address,
  output wire [2:0]    FetchL1TileLinkPlugin_logic_down_a_payload_size,
  input  wire          FetchL1TileLinkPlugin_logic_down_d_valid,
  output wire          FetchL1TileLinkPlugin_logic_down_d_ready,
  input  wire [2:0]    FetchL1TileLinkPlugin_logic_down_d_payload_opcode,
  input  wire [2:0]    FetchL1TileLinkPlugin_logic_down_d_payload_param,
  input  wire [2:0]    FetchL1TileLinkPlugin_logic_down_d_payload_source,
  input  wire [2:0]    FetchL1TileLinkPlugin_logic_down_d_payload_size,
  input  wire          FetchL1TileLinkPlugin_logic_down_d_payload_denied,
  input  wire [63:0]   FetchL1TileLinkPlugin_logic_down_d_payload_data,
  input  wire          FetchL1TileLinkPlugin_logic_down_d_payload_corrupt,
  output reg           LsuL1TileLinkPlugin_logic_down_a_valid,
  input  wire          LsuL1TileLinkPlugin_logic_down_a_ready,
  output reg  [2:0]    LsuL1TileLinkPlugin_logic_down_a_payload_opcode,
  output wire [2:0]    LsuL1TileLinkPlugin_logic_down_a_payload_param,
  output reg  [3:0]    LsuL1TileLinkPlugin_logic_down_a_payload_source,
  output reg  [31:0]   LsuL1TileLinkPlugin_logic_down_a_payload_address,
  output wire [2:0]    LsuL1TileLinkPlugin_logic_down_a_payload_size,
  output wire [7:0]    LsuL1TileLinkPlugin_logic_down_a_payload_mask,
  output wire [63:0]   LsuL1TileLinkPlugin_logic_down_a_payload_data,
  output wire          LsuL1TileLinkPlugin_logic_down_a_payload_corrupt,
  input  wire          LsuL1TileLinkPlugin_logic_down_d_valid,
  output wire          LsuL1TileLinkPlugin_logic_down_d_ready,
  input  wire [2:0]    LsuL1TileLinkPlugin_logic_down_d_payload_opcode,
  input  wire [2:0]    LsuL1TileLinkPlugin_logic_down_d_payload_param,
  input  wire [3:0]    LsuL1TileLinkPlugin_logic_down_d_payload_source,
  input  wire [2:0]    LsuL1TileLinkPlugin_logic_down_d_payload_size,
  input  wire          LsuL1TileLinkPlugin_logic_down_d_payload_denied,
  input  wire [63:0]   LsuL1TileLinkPlugin_logic_down_d_payload_data,
  input  wire          LsuL1TileLinkPlugin_logic_down_d_payload_corrupt,
  output wire          LsuTileLinkPlugin_logic_bridge_down_a_valid,
  input  wire          LsuTileLinkPlugin_logic_bridge_down_a_ready,
  output wire [2:0]    LsuTileLinkPlugin_logic_bridge_down_a_payload_opcode,
  output wire [2:0]    LsuTileLinkPlugin_logic_bridge_down_a_payload_param,
  output wire [31:0]   LsuTileLinkPlugin_logic_bridge_down_a_payload_address,
  output wire [1:0]    LsuTileLinkPlugin_logic_bridge_down_a_payload_size,
  output wire [3:0]    LsuTileLinkPlugin_logic_bridge_down_a_payload_mask,
  output wire [31:0]   LsuTileLinkPlugin_logic_bridge_down_a_payload_data,
  output wire          LsuTileLinkPlugin_logic_bridge_down_a_payload_corrupt,
  input  wire          LsuTileLinkPlugin_logic_bridge_down_d_valid,
  output wire          LsuTileLinkPlugin_logic_bridge_down_d_ready,
  input  wire [2:0]    LsuTileLinkPlugin_logic_bridge_down_d_payload_opcode,
  input  wire [2:0]    LsuTileLinkPlugin_logic_bridge_down_d_payload_param,
  input  wire [1:0]    LsuTileLinkPlugin_logic_bridge_down_d_payload_size,
  input  wire          LsuTileLinkPlugin_logic_bridge_down_d_payload_denied,
  input  wire [31:0]   LsuTileLinkPlugin_logic_bridge_down_d_payload_data,
  input  wire          LsuTileLinkPlugin_logic_bridge_down_d_payload_corrupt,
  input  wire          socCtrl_systemClk,
  input  wire          socCtrl_system_reset
);
  localparam IntAluPlugin_AluBitwiseCtrlEnum_XOR_1 = 2'd0;
  localparam IntAluPlugin_AluBitwiseCtrlEnum_OR_1 = 2'd1;
  localparam IntAluPlugin_AluBitwiseCtrlEnum_AND_1 = 2'd2;
  localparam IntAluPlugin_AluBitwiseCtrlEnum_ZERO = 2'd3;
  localparam BranchPlugin_BranchCtrlEnum_B = 2'd0;
  localparam BranchPlugin_BranchCtrlEnum_JAL = 2'd1;
  localparam BranchPlugin_BranchCtrlEnum_JALR = 2'd2;
  localparam EnvPluginOp_ECALL = 3'd0;
  localparam EnvPluginOp_EBREAK = 3'd1;
  localparam EnvPluginOp_PRIV_RET = 3'd2;
  localparam EnvPluginOp_FENCE_I = 3'd3;
  localparam EnvPluginOp_SFENCE_VMA = 3'd4;
  localparam EnvPluginOp_WFI = 3'd5;
  localparam EnvPluginOp_HFENCE_GVMA = 3'd6;
  localparam EnvPluginOp_HFENCE_VVMA = 3'd7;
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
  localparam TrapPlugin_logic_harts_0_trap_fsm_RESET = 4'd0;
  localparam TrapPlugin_logic_harts_0_trap_fsm_RUNNING = 4'd1;
  localparam TrapPlugin_logic_harts_0_trap_fsm_COMPUTE = 4'd2;
  localparam TrapPlugin_logic_harts_0_trap_fsm_TRAP_EPC = 4'd3;
  localparam TrapPlugin_logic_harts_0_trap_fsm_TRAP_TVAL = 4'd4;
  localparam TrapPlugin_logic_harts_0_trap_fsm_TRAP_HTVAL = 4'd5;
  localparam TrapPlugin_logic_harts_0_trap_fsm_TRAP_HTINST = 4'd6;
  localparam TrapPlugin_logic_harts_0_trap_fsm_TRAP_TVEC = 4'd7;
  localparam TrapPlugin_logic_harts_0_trap_fsm_TRAP_WAIT = 4'd8;
  localparam TrapPlugin_logic_harts_0_trap_fsm_TRAP_APPLY = 4'd9;
  localparam TrapPlugin_logic_harts_0_trap_fsm_XRET_EPC = 4'd10;
  localparam TrapPlugin_logic_harts_0_trap_fsm_XRET_APPLY = 4'd11;
  localparam TrapPlugin_logic_harts_0_trap_fsm_JUMP = 4'd12;
  localparam TrapPlugin_logic_harts_0_trap_fsm_LSU_FLUSH = 4'd13;
  localparam TrapPlugin_logic_harts_0_trap_fsm_FETCH_FLUSH = 4'd14;
  localparam CsrAccessPlugin_logic_fsm_IDLE = 2'd0;
  localparam CsrAccessPlugin_logic_fsm_READ = 2'd1;
  localparam CsrAccessPlugin_logic_fsm_WRITE = 2'd2;
  localparam CsrAccessPlugin_logic_fsm_COMPLETION = 2'd3;
  localparam LsuL1CmdOpcode_LSU = 3'd0;
  localparam LsuL1CmdOpcode_ACCESS_1 = 3'd1;
  localparam LsuL1CmdOpcode_STORE_BUFFER = 3'd2;
  localparam LsuL1CmdOpcode_FLUSH = 3'd3;
  localparam LsuL1CmdOpcode_PREFETCH = 3'd4;
  localparam LsuPlugin_logic_flusher_IDLE = 2'd0;
  localparam LsuPlugin_logic_flusher_SB_DRAIN = 2'd1;
  localparam LsuPlugin_logic_flusher_CMD = 2'd2;
  localparam LsuPlugin_logic_flusher_COMPLETION = 2'd3;
  localparam PerformanceCounterPlugin_logic_fsm_BOOT = 3'd0;
  localparam PerformanceCounterPlugin_logic_fsm_IDLE = 3'd1;
  localparam PerformanceCounterPlugin_logic_fsm_READ_LOW = 3'd2;
  localparam PerformanceCounterPlugin_logic_fsm_CALC_LOW = 3'd3;
  localparam PerformanceCounterPlugin_logic_fsm_READ_HIGH = 3'd4;
  localparam PerformanceCounterPlugin_logic_fsm_CALC_HIGH = 3'd5;
  localparam PerformanceCounterPlugin_logic_fsm_CSR_WRITE = 3'd6;

  wire                early0_DivPlugin_logic_processing_div_io_cmd_valid;
  reg                 LsuPlugin_logic_flusher_arbiter_io_output_ready;
  wire                LsuPlugin_logic_onAddress0_arbiter_io_output_ready;
  reg                 integer_RegFilePlugin_logic_regfile_fpga_io_writes_0_valid;
  reg        [4:0]    integer_RegFilePlugin_logic_regfile_fpga_io_writes_0_address;
  reg        [31:0]   integer_RegFilePlugin_logic_regfile_fpga_io_writes_0_data;
  wire       [30:0]   BtbPlugin_logic_ras_mem_stack_spinal_port0;
  reg        [51:0]   PrefetcherRptPlugin_logic_storage_ram_spinal_port0;
  reg        [63:0]   FetchL1Plugin_logic_banks_0_mem_spinal_port1;
  reg        [63:0]   FetchL1Plugin_logic_banks_1_mem_spinal_port1;
  reg        [20:0]   FetchL1Plugin_logic_ways_0_mem_spinal_port1;
  reg        [20:0]   FetchL1Plugin_logic_ways_1_mem_spinal_port1;
  reg        [0:0]    FetchL1Plugin_logic_plru_mem_spinal_port1;
  reg        [7:0]    GSharePlugin_logic_mem_banks_0_spinal_port1;
  reg        [101:0]  BtbPlugin_logic_mem_spinal_port1;
  reg        [77:0]   LsuPlugin_logic_storeBuffer_ops_mem_spinal_port0;
  reg        [63:0]   LsuL1Plugin_logic_banks_0_mem_spinal_port1;
  reg        [63:0]   LsuL1Plugin_logic_banks_1_mem_spinal_port1;
  reg        [21:0]   LsuL1Plugin_logic_ways_0_mem_spinal_port1;
  reg        [21:0]   LsuL1Plugin_logic_ways_1_mem_spinal_port1;
  reg        [2:0]    LsuL1Plugin_logic_shared_mem_spinal_port1;
  reg        [63:0]   LsuL1Plugin_logic_writeback_victimBuffer_spinal_port1;
  reg        [31:0]   CsrRamPlugin_logic_mem_spinal_port1;
  wire                PrefetcherRptPlugin_logic_order_queueWithOccupancy_io_push_ready;
  wire                PrefetcherRptPlugin_logic_order_queueWithOccupancy_io_pop_valid;
  wire       [31:0]   PrefetcherRptPlugin_logic_order_queueWithOccupancy_io_pop_payload_address;
  wire                PrefetcherRptPlugin_logic_order_queueWithOccupancy_io_pop_payload_unique;
  wire       [2:0]    PrefetcherRptPlugin_logic_order_queueWithOccupancy_io_pop_payload_from;
  wire       [2:0]    PrefetcherRptPlugin_logic_order_queueWithOccupancy_io_pop_payload_to;
  wire       [11:0]   PrefetcherRptPlugin_logic_order_queueWithOccupancy_io_pop_payload_stride;
  wire       [2:0]    PrefetcherRptPlugin_logic_order_queueWithOccupancy_io_occupancy;
  wire       [2:0]    PrefetcherRptPlugin_logic_order_queueWithOccupancy_io_availability;
  wire                early0_DivPlugin_logic_processing_div_io_cmd_ready;
  wire                early0_DivPlugin_logic_processing_div_io_rsp_valid;
  wire       [31:0]   early0_DivPlugin_logic_processing_div_io_rsp_payload_result;
  wire       [31:0]   early0_DivPlugin_logic_processing_div_io_rsp_payload_remain;
  wire                streamArbiter_7_io_inputs_0_ready;
  wire                streamArbiter_7_io_inputs_1_ready;
  wire                streamArbiter_7_io_output_valid;
  wire       [31:0]   streamArbiter_7_io_output_payload_pcOnLastSlice;
  wire       [31:0]   streamArbiter_7_io_output_payload_pcTarget;
  wire                streamArbiter_7_io_output_payload_taken;
  wire                streamArbiter_7_io_output_payload_isBranch;
  wire                streamArbiter_7_io_output_payload_isPush;
  wire                streamArbiter_7_io_output_payload_isPop;
  wire                streamArbiter_7_io_output_payload_wasWrong;
  wire                streamArbiter_7_io_output_payload_badPredictedTarget;
  wire       [11:0]   streamArbiter_7_io_output_payload_history;
  wire       [15:0]   streamArbiter_7_io_output_payload_uopId;
  wire       [1:0]    streamArbiter_7_io_output_payload_ctx_GSharePlugin_GSHARE_COUNTER_0;
  wire       [1:0]    streamArbiter_7_io_output_payload_ctx_GSharePlugin_GSHARE_COUNTER_1;
  wire       [1:0]    streamArbiter_7_io_output_payload_ctx_GSharePlugin_GSHARE_COUNTER_2;
  wire       [1:0]    streamArbiter_7_io_output_payload_ctx_GSharePlugin_GSHARE_COUNTER_3;
  wire       [0:0]    streamArbiter_7_io_chosen;
  wire       [1:0]    streamArbiter_7_io_chosenOH;
  wire                LsuPlugin_logic_flusher_arbiter_io_inputs_0_ready;
  wire                LsuPlugin_logic_flusher_arbiter_io_output_valid;
  wire       [0:0]    LsuPlugin_logic_flusher_arbiter_io_chosenOH;
  wire                LsuPlugin_logic_onAddress0_arbiter_io_inputs_0_ready;
  wire                LsuPlugin_logic_onAddress0_arbiter_io_inputs_1_ready;
  wire                LsuPlugin_logic_onAddress0_arbiter_io_inputs_2_ready;
  wire                LsuPlugin_logic_onAddress0_arbiter_io_inputs_3_ready;
  wire                LsuPlugin_logic_onAddress0_arbiter_io_output_valid;
  wire       [2:0]    LsuPlugin_logic_onAddress0_arbiter_io_output_payload_op;
  wire       [31:0]   LsuPlugin_logic_onAddress0_arbiter_io_output_payload_address;
  wire       [1:0]    LsuPlugin_logic_onAddress0_arbiter_io_output_payload_size;
  wire                LsuPlugin_logic_onAddress0_arbiter_io_output_payload_load;
  wire                LsuPlugin_logic_onAddress0_arbiter_io_output_payload_store;
  wire                LsuPlugin_logic_onAddress0_arbiter_io_output_payload_execute;
  wire                LsuPlugin_logic_onAddress0_arbiter_io_output_payload_atomic;
  wire                LsuPlugin_logic_onAddress0_arbiter_io_output_payload_clean;
  wire                LsuPlugin_logic_onAddress0_arbiter_io_output_payload_invalidate;
  wire                LsuPlugin_logic_onAddress0_arbiter_io_output_payload_guest;
  wire       [11:0]   LsuPlugin_logic_onAddress0_arbiter_io_output_payload_storeId;
  wire       [1:0]    LsuPlugin_logic_onAddress0_arbiter_io_chosen;
  wire       [3:0]    LsuPlugin_logic_onAddress0_arbiter_io_chosenOH;
  wire       [31:0]   integer_RegFilePlugin_logic_regfile_fpga_io_reads_0_data;
  wire       [31:0]   integer_RegFilePlugin_logic_regfile_fpga_io_reads_1_data;
  wire       [31:0]   integer_RegFilePlugin_logic_regfile_fpga_io_reads_2_data;
  wire       [31:0]   integer_RegFilePlugin_logic_regfile_fpga_io_reads_3_data;
  wire       [31:0]   _zz_early0_IntAluPlugin_logic_alu_result;
  wire       [31:0]   _zz_early0_IntAluPlugin_logic_alu_result_1;
  wire       [31:0]   _zz_early0_IntAluPlugin_logic_alu_result_2;
  wire       [31:0]   _zz_early0_IntAluPlugin_logic_alu_result_3;
  wire       [31:0]   _zz_early0_IntAluPlugin_logic_alu_result_4;
  wire       [0:0]    _zz_early0_IntAluPlugin_logic_alu_result_5;
  // Reference line 8133 moved verbatim to replica_early0_shifter.
  // Reference line 8134 moved verbatim to replica_early0_shifter.
  // Reference line 8135 moved verbatim to replica_early0_shifter.
  // Reference line 8136 moved verbatim to replica_early0_shifter.
  // Reference line 8137 moved verbatim to replica_early0_shifter.
  // Reference line 8138 moved verbatim to replica_early0_shifter.
  // Reference line 8139 moved verbatim to replica_early0_shifter.
  // Reference line 8140 moved verbatim to replica_early0_shifter.
  // Reference line 8141 moved verbatim to replica_early0_shifter.
  // Reference line 8142 moved verbatim to replica_early0_shifter.
  // Reference line 8143 moved verbatim to replica_early0_shifter.
  // Reference line 8144 moved verbatim to replica_early0_shifter.
  // Reference line 8145 moved verbatim to replica_early0_shifter.
  // Reference line 8146 moved verbatim to replica_early0_shifter.
  // Reference line 8147 moved verbatim to replica_early0_shifter.
  // Reference line 8148 moved verbatim to replica_early0_shifter.
  // Reference line 8149 moved verbatim to replica_early0_shifter.
  wire       [2:0]    _zz_PrefetcherRptPlugin_logic_counter;
  wire       [2:0]    _zz_PrefetcherRptPlugin_logic_counter_1;
  wire       [0:0]    _zz_PrefetcherRptPlugin_logic_counter_2;
  wire       [3:0]    _zz_PrefetcherRptPlugin_logic_pip2_node_0_MUL;
  wire       [31:0]   _zz_PrefetcherRptPlugin_logic_pip2_node_1_adder_ADDR;
  wire       [31:0]   _zz_PrefetcherRptPlugin_logic_pip2_node_1_adder_ADDR_1;
  wire       [31:0]   _zz_PrefetcherRptPlugin_logic_pip2_node_1_adder_ADDR_2;
  wire       [51:0]   _zz_PrefetcherRptPlugin_logic_storage_ram_port;
  wire       [32:0]   _zz_execute_ctrl2_down_MUL_SRC1_lane0;
  wire       [32:0]   _zz_execute_ctrl2_down_MUL_SRC2_lane0;
  wire       [46:0]   _zz_execute_ctrl2_down_early0_MulPlugin_logic_mul_VALUES_1_lane0;
  wire       [33:0]   _zz_execute_ctrl2_down_early0_MulPlugin_logic_mul_VALUES_1_lane0_1;
  wire       [17:0]   _zz_execute_ctrl2_down_early0_MulPlugin_logic_mul_VALUES_1_lane0_2;
  wire       [15:0]   _zz_execute_ctrl2_down_early0_MulPlugin_logic_mul_VALUES_1_lane0_3;
  wire       [46:0]   _zz_execute_ctrl2_down_early0_MulPlugin_logic_mul_VALUES_2_lane0;
  wire       [33:0]   _zz_execute_ctrl2_down_early0_MulPlugin_logic_mul_VALUES_2_lane0_1;
  wire       [15:0]   _zz_execute_ctrl2_down_early0_MulPlugin_logic_mul_VALUES_2_lane0_2;
  wire       [17:0]   _zz_execute_ctrl2_down_early0_MulPlugin_logic_mul_VALUES_2_lane0_3;
  wire       [29:0]   _zz_execute_ctrl2_down_early0_MulPlugin_logic_mul_VALUES_3_lane0;
  wire       [31:0]   _zz_execute_ctrl2_down_early0_MulPlugin_logic_mul_VALUES_3_lane0_1;
  wire       [15:0]   _zz_execute_ctrl2_down_early0_MulPlugin_logic_mul_VALUES_3_lane0_2;
  wire       [15:0]   _zz_execute_ctrl2_down_early0_MulPlugin_logic_mul_VALUES_3_lane0_3;
  wire       [62:0]   _zz_execute_ctrl3_down_early0_MulPlugin_logic_steps_0_adders_0_lane0_3;
  wire       [62:0]   _zz_execute_ctrl3_down_early0_MulPlugin_logic_steps_0_adders_0_lane0_4;
  wire       [62:0]   _zz_execute_ctrl3_down_early0_MulPlugin_logic_steps_0_adders_0_lane0_5;
  wire       [62:0]   _zz_execute_ctrl3_down_early0_MulPlugin_logic_steps_0_adders_0_lane0_6;
  wire       [4:0]    _zz_execute_ctrl3_down_early0_MulPlugin_logic_steps_0_adders_1_lane0_3;
  wire       [4:0]    _zz_execute_ctrl3_down_early0_MulPlugin_logic_steps_0_adders_1_lane0_4;
  wire       [4:0]    _zz_execute_ctrl3_down_early0_MulPlugin_logic_steps_0_adders_1_lane0_5;
  wire       [4:0]    _zz_execute_ctrl3_down_early0_MulPlugin_logic_steps_0_adders_1_lane0_6;
  wire       [31:0]   _zz_execute_ctrl2_down_RsUnsignedPlugin_RS1_UNSIGNED_lane0;
  wire       [0:0]    _zz_execute_ctrl2_down_RsUnsignedPlugin_RS1_UNSIGNED_lane0_1;
  wire       [31:0]   _zz_execute_ctrl2_down_RsUnsignedPlugin_RS2_UNSIGNED_lane0;
  wire       [0:0]    _zz_execute_ctrl2_down_RsUnsignedPlugin_RS2_UNSIGNED_lane0_1;
  wire       [31:0]   _zz_execute_ctrl2_down_DivPlugin_DIV_RESULT_lane0_1;
  wire       [31:0]   _zz_execute_ctrl2_down_DivPlugin_DIV_RESULT_lane0_2;
  wire       [0:0]    _zz_execute_ctrl2_down_DivPlugin_DIV_RESULT_lane0_3;
  wire       [1:0]    _zz_PrivilegedPlugin_logic_harts_0_privilegeMode;
  wire       [31:0]   _zz_late0_IntAluPlugin_logic_alu_result;
  wire       [31:0]   _zz_late0_IntAluPlugin_logic_alu_result_1;
  wire       [31:0]   _zz_late0_IntAluPlugin_logic_alu_result_2;
  wire       [31:0]   _zz_late0_IntAluPlugin_logic_alu_result_3;
  wire       [31:0]   _zz_late0_IntAluPlugin_logic_alu_result_4;
  wire       [0:0]    _zz_late0_IntAluPlugin_logic_alu_result_5;
  // Reference line 8194 moved verbatim to replica_late0_shifter.
  // Reference line 8195 moved verbatim to replica_late0_shifter.
  // Reference line 8196 moved verbatim to replica_late0_shifter.
  // Reference line 8197 moved verbatim to replica_late0_shifter.
  // Reference line 8198 moved verbatim to replica_late0_shifter.
  // Reference line 8199 moved verbatim to replica_late0_shifter.
  // Reference line 8200 moved verbatim to replica_late0_shifter.
  // Reference line 8201 moved verbatim to replica_late0_shifter.
  // Reference line 8202 moved verbatim to replica_late0_shifter.
  // Reference line 8203 moved verbatim to replica_late0_shifter.
  // Reference line 8204 moved verbatim to replica_late0_shifter.
  // Reference line 8205 moved verbatim to replica_late0_shifter.
  // Reference line 8206 moved verbatim to replica_late0_shifter.
  // Reference line 8207 moved verbatim to replica_late0_shifter.
  // Reference line 8208 moved verbatim to replica_late0_shifter.
  // Reference line 8209 moved verbatim to replica_late0_shifter.
  // Reference line 8210 moved verbatim to replica_late0_shifter.
  wire       [31:0]   _zz_early1_IntAluPlugin_logic_alu_result;
  wire       [31:0]   _zz_early1_IntAluPlugin_logic_alu_result_1;
  wire       [31:0]   _zz_early1_IntAluPlugin_logic_alu_result_2;
  wire       [31:0]   _zz_early1_IntAluPlugin_logic_alu_result_3;
  wire       [31:0]   _zz_early1_IntAluPlugin_logic_alu_result_4;
  wire       [0:0]    _zz_early1_IntAluPlugin_logic_alu_result_5;
  // Reference line 8217 moved verbatim to replica_early1_shifter.
  // Reference line 8218 moved verbatim to replica_early1_shifter.
  // Reference line 8219 moved verbatim to replica_early1_shifter.
  // Reference line 8220 moved verbatim to replica_early1_shifter.
  // Reference line 8221 moved verbatim to replica_early1_shifter.
  // Reference line 8222 moved verbatim to replica_early1_shifter.
  // Reference line 8223 moved verbatim to replica_early1_shifter.
  // Reference line 8224 moved verbatim to replica_early1_shifter.
  // Reference line 8225 moved verbatim to replica_early1_shifter.
  // Reference line 8226 moved verbatim to replica_early1_shifter.
  // Reference line 8227 moved verbatim to replica_early1_shifter.
  // Reference line 8228 moved verbatim to replica_early1_shifter.
  // Reference line 8229 moved verbatim to replica_early1_shifter.
  // Reference line 8230 moved verbatim to replica_early1_shifter.
  // Reference line 8231 moved verbatim to replica_early1_shifter.
  // Reference line 8232 moved verbatim to replica_early1_shifter.
  // Reference line 8233 moved verbatim to replica_early1_shifter.
  wire       [31:0]   _zz_late1_IntAluPlugin_logic_alu_result;
  wire       [31:0]   _zz_late1_IntAluPlugin_logic_alu_result_1;
  wire       [31:0]   _zz_late1_IntAluPlugin_logic_alu_result_2;
  wire       [31:0]   _zz_late1_IntAluPlugin_logic_alu_result_3;
  wire       [31:0]   _zz_late1_IntAluPlugin_logic_alu_result_4;
  wire       [0:0]    _zz_late1_IntAluPlugin_logic_alu_result_5;
  // Reference line 8240 moved verbatim to replica_late1_shifter.
  // Reference line 8241 moved verbatim to replica_late1_shifter.
  // Reference line 8242 moved verbatim to replica_late1_shifter.
  // Reference line 8243 moved verbatim to replica_late1_shifter.
  // Reference line 8244 moved verbatim to replica_late1_shifter.
  // Reference line 8245 moved verbatim to replica_late1_shifter.
  // Reference line 8246 moved verbatim to replica_late1_shifter.
  // Reference line 8247 moved verbatim to replica_late1_shifter.
  // Reference line 8248 moved verbatim to replica_late1_shifter.
  // Reference line 8249 moved verbatim to replica_late1_shifter.
  // Reference line 8250 moved verbatim to replica_late1_shifter.
  // Reference line 8251 moved verbatim to replica_late1_shifter.
  // Reference line 8252 moved verbatim to replica_late1_shifter.
  // Reference line 8253 moved verbatim to replica_late1_shifter.
  // Reference line 8254 moved verbatim to replica_late1_shifter.
  // Reference line 8255 moved verbatim to replica_late1_shifter.
  // Reference line 8256 moved verbatim to replica_late1_shifter.
  wire       [20:0]   _zz_FetchL1Plugin_logic_ways_0_mem_port;
  wire                _zz_FetchL1Plugin_logic_ways_0_mem_port_1;
  wire       [20:0]   _zz_FetchL1Plugin_logic_ways_1_mem_port;
  wire                _zz_FetchL1Plugin_logic_ways_1_mem_port_1;
  wire       [7:0]    _zz__zz_26;
  wire       [6:0]    _zz_FetchL1Plugin_logic_refill_hazard;
  wire       [6:0]    _zz_FetchL1Plugin_logic_refill_hazard_1;
  wire                _zz_FetchL1Plugin_logic_refill_hazard_2;
  wire                _zz_FetchL1Plugin_logic_refill_hazard_3;
  wire       [0:0]    _zz_FetchL1Plugin_logic_refill_hazard_4;
  wire       [1:0]    _zz_FetchL1Plugin_logic_refill_hazard_5;
  wire                _zz_when;
  wire                _zz_when_1;
  wire                _zz_when_2;
  wire                _zz_when_3;
  wire                _zz_when_4;
  wire                _zz_when_5;
  wire                _zz_when_6;
  wire                _zz_FetchL1Plugin_logic_refill_onCmd_propoedOh;
  wire                _zz_FetchL1Plugin_logic_refill_onCmd_propoedOh_1;
  wire       [0:0]    _zz_FetchL1Plugin_logic_refill_onCmd_propoedOh_2;
  wire                _zz_FetchL1Plugin_logic_refill_onCmd_propoedOh_3;
  wire                _zz_FetchL1Plugin_logic_refill_onCmd_propoedOh_4;
  wire       [4:0]    _zz_FetchL1Plugin_logic_refill_onCmd_propoedOh_5;
  wire                _zz_FetchL1Plugin_logic_refill_onCmd_propoedOh_6;
  wire                _zz_FetchL1Plugin_logic_refill_onCmd_propoedOh_7;
  wire       [0:0]    _zz_FetchL1Plugin_logic_refill_onCmd_propoedOh_8;
  wire                _zz_FetchL1Plugin_logic_refill_onCmd_propoedOh_9;
  wire                _zz_FetchL1Plugin_logic_refill_onCmd_propoedOh_10;
  wire                _zz_FetchL1Plugin_logic_refill_onCmd_propoedOh_11;
  wire       [2:0]    _zz_FetchL1Plugin_logic_refill_onCmd_propoedOh_12;
  wire                _zz_FetchL1Plugin_logic_refill_onCmd_propoedOh_13;
  wire                _zz_FetchL1Plugin_logic_refill_onCmd_propoedOh_14;
  wire                _zz_FetchL1Plugin_logic_refill_onCmd_propoedOh_15;
  wire                _zz_FetchL1Plugin_logic_refill_onCmd_propoedOh_16;
  wire       [0:0]    _zz_FetchL1Plugin_logic_refill_onCmd_propoedOh_17;
  wire                _zz_FetchL1Plugin_logic_refill_onCmd_propoedOh_18;
  wire                _zz_FetchL1Plugin_logic_refill_onCmd_propoedOh_19;
  wire                _zz_FetchL1Plugin_logic_refill_onCmd_propoedOh_20;
  wire                _zz_FetchL1Plugin_logic_refill_onCmd_propoedOh_21;
  wire       [0:0]    _zz_FetchL1Plugin_logic_refill_onCmd_propoedOh_22;
  wire                _zz_FetchL1Plugin_logic_refill_onCmd_propoedOh_23;
  wire                _zz_FetchL1Plugin_logic_refill_onCmd_propoedOh_24;
  wire                _zz_FetchL1Plugin_logic_refill_onCmd_propoedOh_25;
  wire                _zz_FetchL1Plugin_logic_refill_onCmd_propoedOh_26;
  wire       [0:0]    _zz_FetchL1Plugin_logic_refill_onCmd_propoedOh_27;
  wire                _zz_FetchL1Plugin_logic_refill_onCmd_propoedOh_28;
  wire                _zz_FetchL1Plugin_logic_refill_onCmd_propoedOh_29;
  wire       [5:0]    _zz_FetchL1Plugin_logic_refill_onCmd_propoedOh_30;
  wire                _zz_FetchL1Plugin_logic_refill_onCmd_propoedOh_31;
  wire                _zz_FetchL1Plugin_logic_refill_onCmd_propoedOh_32;
  wire       [0:0]    _zz_FetchL1Plugin_logic_refill_onCmd_propoedOh_33;
  wire                _zz_FetchL1Plugin_logic_refill_onCmd_propoedOh_34;
  wire                _zz_FetchL1Plugin_logic_refill_onCmd_propoedOh_35;
  wire                _zz_FetchL1Plugin_logic_refill_onCmd_propoedOh_36;
  wire       [3:0]    _zz_FetchL1Plugin_logic_refill_onCmd_propoedOh_37;
  wire                _zz_FetchL1Plugin_logic_refill_onCmd_propoedOh_38;
  wire                _zz_FetchL1Plugin_logic_refill_onCmd_propoedOh_39;
  wire                _zz_FetchL1Plugin_logic_refill_onCmd_propoedOh_40;
  wire                _zz_FetchL1Plugin_logic_refill_onCmd_propoedOh_41;
  wire       [0:0]    _zz_FetchL1Plugin_logic_refill_onCmd_propoedOh_42;
  wire                _zz_FetchL1Plugin_logic_refill_onCmd_propoedOh_43;
  wire                _zz_FetchL1Plugin_logic_refill_onCmd_propoedOh_44;
  wire                _zz_FetchL1Plugin_logic_refill_onCmd_propoedOh_45;
  wire                _zz_FetchL1Plugin_logic_refill_onCmd_propoedOh_46;
  wire       [1:0]    _zz_FetchL1Plugin_logic_refill_onCmd_propoedOh_47;
  wire       [0:0]    _zz_FetchL1Plugin_logic_refill_onCmd_propoedOh_48;
  wire                _zz_FetchL1Plugin_logic_refill_onCmd_propoedOh_49;
  wire                _zz_FetchL1Plugin_logic_refill_onCmd_propoedOh_50;
  wire                _zz_FetchL1Plugin_logic_refill_onCmd_propoedOh_51;
  wire                _zz_FetchL1Plugin_logic_refill_onCmd_propoedOh_52;
  wire       [0:0]    _zz_FetchL1Plugin_logic_refill_onCmd_propoedOh_53;
  wire                _zz_FetchL1Plugin_logic_refill_onCmd_propoedOh_54;
  wire                _zz_FetchL1Plugin_logic_refill_onCmd_propoedOh_55;
  wire                _zz_FetchL1Plugin_logic_refill_onCmd_propoedOh_56;
  wire                _zz_FetchL1Plugin_logic_refill_onCmd_propoedOh_57;
  wire       [6:0]    _zz_FetchL1Plugin_logic_refill_onCmd_propoedOh_58;
  wire                _zz_FetchL1Plugin_logic_refill_onCmd_propoedOh_59;
  wire                _zz_FetchL1Plugin_logic_refill_onCmd_propoedOh_60;
  wire       [0:0]    _zz_FetchL1Plugin_logic_refill_onCmd_propoedOh_61;
  wire                _zz_FetchL1Plugin_logic_refill_onCmd_propoedOh_62;
  wire                _zz_FetchL1Plugin_logic_refill_onCmd_propoedOh_63;
  wire                _zz_FetchL1Plugin_logic_refill_onCmd_propoedOh_64;
  wire       [4:0]    _zz_FetchL1Plugin_logic_refill_onCmd_propoedOh_65;
  wire                _zz_FetchL1Plugin_logic_refill_onCmd_propoedOh_66;
  wire                _zz_FetchL1Plugin_logic_refill_onCmd_propoedOh_67;
