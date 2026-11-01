// Generator : SpinalHDL dev    git head : de72faf6062206a89b445e5cc07e32ed982712c8
// Component : MicroSoc

`timescale 1ns/1ps

module MicroSoc (
  input  wire          socCtrl_systemClk,
  input  wire          socCtrl_asyncReset,
  output wire          system_peripheral_uart_logic_uart_txd,
  input  wire          system_peripheral_uart_logic_uart_rxd,
  output wire [7:0]    system_peripheral_demo_logic_leds,
  input  wire [0:0]    system_peripheral_demo_logic_buttons
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

  wire                system_peripheral_clint_thread_core_io_stop;
  reg        [1:0]    system_peripheral_plic_thread_logic_io_sources;
  wire                system_cpu_logic_core_FetchL1TileLinkPlugin_logic_down_a_valid;
  wire       [2:0]    system_cpu_logic_core_FetchL1TileLinkPlugin_logic_down_a_payload_opcode;
  wire       [2:0]    system_cpu_logic_core_FetchL1TileLinkPlugin_logic_down_a_payload_param;
  wire       [2:0]    system_cpu_logic_core_FetchL1TileLinkPlugin_logic_down_a_payload_source;
  wire       [31:0]   system_cpu_logic_core_FetchL1TileLinkPlugin_logic_down_a_payload_address;
  wire       [2:0]    system_cpu_logic_core_FetchL1TileLinkPlugin_logic_down_a_payload_size;
  wire                system_cpu_logic_core_FetchL1TileLinkPlugin_logic_down_d_ready;
  wire                system_cpu_logic_core_LsuL1TileLinkPlugin_logic_down_a_valid;
  wire       [2:0]    system_cpu_logic_core_LsuL1TileLinkPlugin_logic_down_a_payload_opcode;
  wire       [2:0]    system_cpu_logic_core_LsuL1TileLinkPlugin_logic_down_a_payload_param;
  wire       [3:0]    system_cpu_logic_core_LsuL1TileLinkPlugin_logic_down_a_payload_source;
  wire       [31:0]   system_cpu_logic_core_LsuL1TileLinkPlugin_logic_down_a_payload_address;
  wire       [2:0]    system_cpu_logic_core_LsuL1TileLinkPlugin_logic_down_a_payload_size;
  wire       [7:0]    system_cpu_logic_core_LsuL1TileLinkPlugin_logic_down_a_payload_mask;
  wire       [63:0]   system_cpu_logic_core_LsuL1TileLinkPlugin_logic_down_a_payload_data;
  wire                system_cpu_logic_core_LsuL1TileLinkPlugin_logic_down_a_payload_corrupt;
  wire                system_cpu_logic_core_LsuL1TileLinkPlugin_logic_down_d_ready;
  wire                system_cpu_logic_core_LsuTileLinkPlugin_logic_bridge_down_a_valid;
  wire       [2:0]    system_cpu_logic_core_LsuTileLinkPlugin_logic_bridge_down_a_payload_opcode;
  wire       [2:0]    system_cpu_logic_core_LsuTileLinkPlugin_logic_bridge_down_a_payload_param;
  wire       [31:0]   system_cpu_logic_core_LsuTileLinkPlugin_logic_bridge_down_a_payload_address;
  wire       [1:0]    system_cpu_logic_core_LsuTileLinkPlugin_logic_bridge_down_a_payload_size;
  wire       [3:0]    system_cpu_logic_core_LsuTileLinkPlugin_logic_bridge_down_a_payload_mask;
  wire       [31:0]   system_cpu_logic_core_LsuTileLinkPlugin_logic_bridge_down_a_payload_data;
  wire                system_cpu_logic_core_LsuTileLinkPlugin_logic_bridge_down_a_payload_corrupt;
  wire                system_cpu_logic_core_LsuTileLinkPlugin_logic_bridge_down_d_ready;
  wire                socCtrl_debug_fiber_aggregator_asyncBuffers_0_io_dataOut;
  wire                socCtrl_debug_fiber_buffer_io_dataOut;
  wire                socCtrl_system_fiber_aggregator_asyncBuffers_0_io_dataOut;
  wire                socCtrl_system_fiber_buffer_io_dataOut;
  wire                system_mainBus_arbiter_core_io_ups_0_a_ready;
  wire                system_mainBus_arbiter_core_io_ups_0_d_valid;
  wire       [2:0]    system_mainBus_arbiter_core_io_ups_0_d_payload_opcode;
  wire       [2:0]    system_mainBus_arbiter_core_io_ups_0_d_payload_param;
  wire       [2:0]    system_mainBus_arbiter_core_io_ups_0_d_payload_source;
  wire       [2:0]    system_mainBus_arbiter_core_io_ups_0_d_payload_size;
  wire                system_mainBus_arbiter_core_io_ups_0_d_payload_denied;
  wire       [63:0]   system_mainBus_arbiter_core_io_ups_0_d_payload_data;
  wire                system_mainBus_arbiter_core_io_ups_0_d_payload_corrupt;
  wire                system_mainBus_arbiter_core_io_ups_1_a_ready;
  wire                system_mainBus_arbiter_core_io_ups_1_d_valid;
  wire       [2:0]    system_mainBus_arbiter_core_io_ups_1_d_payload_opcode;
  wire       [2:0]    system_mainBus_arbiter_core_io_ups_1_d_payload_param;
  wire       [1:0]    system_mainBus_arbiter_core_io_ups_1_d_payload_size;
  wire                system_mainBus_arbiter_core_io_ups_1_d_payload_denied;
  wire       [63:0]   system_mainBus_arbiter_core_io_ups_1_d_payload_data;
  wire                system_mainBus_arbiter_core_io_ups_1_d_payload_corrupt;
  wire                system_mainBus_arbiter_core_io_ups_2_a_ready;
  wire                system_mainBus_arbiter_core_io_ups_2_d_valid;
  wire       [2:0]    system_mainBus_arbiter_core_io_ups_2_d_payload_opcode;
  wire       [2:0]    system_mainBus_arbiter_core_io_ups_2_d_payload_param;
  wire       [3:0]    system_mainBus_arbiter_core_io_ups_2_d_payload_source;
  wire       [2:0]    system_mainBus_arbiter_core_io_ups_2_d_payload_size;
  wire                system_mainBus_arbiter_core_io_ups_2_d_payload_denied;
  wire       [63:0]   system_mainBus_arbiter_core_io_ups_2_d_payload_data;
  wire                system_mainBus_arbiter_core_io_ups_2_d_payload_corrupt;
  wire                system_mainBus_arbiter_core_io_down_a_valid;
  wire       [2:0]    system_mainBus_arbiter_core_io_down_a_payload_opcode;
  wire       [2:0]    system_mainBus_arbiter_core_io_down_a_payload_param;
  wire       [5:0]    system_mainBus_arbiter_core_io_down_a_payload_source;
  wire       [31:0]   system_mainBus_arbiter_core_io_down_a_payload_address;
  wire       [2:0]    system_mainBus_arbiter_core_io_down_a_payload_size;
  wire       [7:0]    system_mainBus_arbiter_core_io_down_a_payload_mask;
  wire       [63:0]   system_mainBus_arbiter_core_io_down_a_payload_data;
  wire                system_mainBus_arbiter_core_io_down_a_payload_corrupt;
  wire                system_mainBus_arbiter_core_io_down_d_ready;
  wire                system_ram_thread_logic_io_up_a_ready;
  wire                system_ram_thread_logic_io_up_d_valid;
  wire       [2:0]    system_ram_thread_logic_io_up_d_payload_opcode;
  wire       [2:0]    system_ram_thread_logic_io_up_d_payload_param;
  wire       [5:0]    system_ram_thread_logic_io_up_d_payload_source;
  wire       [2:0]    system_ram_thread_logic_io_up_d_payload_size;
  wire                system_ram_thread_logic_io_up_d_payload_denied;
  wire       [63:0]   system_ram_thread_logic_io_up_d_payload_data;
  wire                system_ram_thread_logic_io_up_d_payload_corrupt;
  wire                system_cpu_dBus_to_system_mainBus_widthAdapter_io_up_a_ready;
  wire                system_cpu_dBus_to_system_mainBus_widthAdapter_io_up_d_valid;
  wire       [2:0]    system_cpu_dBus_to_system_mainBus_widthAdapter_io_up_d_payload_opcode;
  wire       [2:0]    system_cpu_dBus_to_system_mainBus_widthAdapter_io_up_d_payload_param;
  wire       [1:0]    system_cpu_dBus_to_system_mainBus_widthAdapter_io_up_d_payload_size;
  wire                system_cpu_dBus_to_system_mainBus_widthAdapter_io_up_d_payload_denied;
  wire       [31:0]   system_cpu_dBus_to_system_mainBus_widthAdapter_io_up_d_payload_data;
  wire                system_cpu_dBus_to_system_mainBus_widthAdapter_io_up_d_payload_corrupt;
  wire                system_cpu_dBus_to_system_mainBus_widthAdapter_io_down_a_valid;
  wire       [2:0]    system_cpu_dBus_to_system_mainBus_widthAdapter_io_down_a_payload_opcode;
  wire       [2:0]    system_cpu_dBus_to_system_mainBus_widthAdapter_io_down_a_payload_param;
  wire       [31:0]   system_cpu_dBus_to_system_mainBus_widthAdapter_io_down_a_payload_address;
  wire       [1:0]    system_cpu_dBus_to_system_mainBus_widthAdapter_io_down_a_payload_size;
  wire       [7:0]    system_cpu_dBus_to_system_mainBus_widthAdapter_io_down_a_payload_mask;
  wire       [63:0]   system_cpu_dBus_to_system_mainBus_widthAdapter_io_down_a_payload_data;
  wire                system_cpu_dBus_to_system_mainBus_widthAdapter_io_down_a_payload_corrupt;
  wire                system_cpu_dBus_to_system_mainBus_widthAdapter_io_down_d_ready;
  wire                system_peripheral_clint_thread_core_io_bus_a_ready;
  wire                system_peripheral_clint_thread_core_io_bus_d_valid;
  wire       [2:0]    system_peripheral_clint_thread_core_io_bus_d_payload_opcode;
  wire       [2:0]    system_peripheral_clint_thread_core_io_bus_d_payload_param;
  wire       [5:0]    system_peripheral_clint_thread_core_io_bus_d_payload_source;
  wire       [2:0]    system_peripheral_clint_thread_core_io_bus_d_payload_size;
  wire                system_peripheral_clint_thread_core_io_bus_d_payload_denied;
  wire       [31:0]   system_peripheral_clint_thread_core_io_bus_d_payload_data;
  wire                system_peripheral_clint_thread_core_io_bus_d_payload_corrupt;
  wire       [0:0]    system_peripheral_clint_thread_core_io_timerInterrupt;
  wire       [0:0]    system_peripheral_clint_thread_core_io_softwareInterrupt;
  wire       [63:0]   system_peripheral_clint_thread_core_io_time;
  wire                system_peripheral_busXlen_decoder_core_io_up_a_ready;
  wire                system_peripheral_busXlen_decoder_core_io_up_d_valid;
  wire       [2:0]    system_peripheral_busXlen_decoder_core_io_up_d_payload_opcode;
  wire       [2:0]    system_peripheral_busXlen_decoder_core_io_up_d_payload_param;
  wire       [5:0]    system_peripheral_busXlen_decoder_core_io_up_d_payload_source;
  wire       [2:0]    system_peripheral_busXlen_decoder_core_io_up_d_payload_size;
  wire                system_peripheral_busXlen_decoder_core_io_up_d_payload_denied;
  wire       [31:0]   system_peripheral_busXlen_decoder_core_io_up_d_payload_data;
  wire                system_peripheral_busXlen_decoder_core_io_up_d_payload_corrupt;
  wire                system_peripheral_busXlen_decoder_core_io_downs_0_a_valid;
  wire       [2:0]    system_peripheral_busXlen_decoder_core_io_downs_0_a_payload_opcode;
  wire       [2:0]    system_peripheral_busXlen_decoder_core_io_downs_0_a_payload_param;
  wire       [5:0]    system_peripheral_busXlen_decoder_core_io_downs_0_a_payload_source;
  wire       [28:0]   system_peripheral_busXlen_decoder_core_io_downs_0_a_payload_address;
  wire       [1:0]    system_peripheral_busXlen_decoder_core_io_downs_0_a_payload_size;
  wire       [3:0]    system_peripheral_busXlen_decoder_core_io_downs_0_a_payload_mask;
  wire       [31:0]   system_peripheral_busXlen_decoder_core_io_downs_0_a_payload_data;
  wire                system_peripheral_busXlen_decoder_core_io_downs_0_a_payload_corrupt;
  wire                system_peripheral_busXlen_decoder_core_io_downs_0_d_ready;
  wire                system_peripheral_busXlen_decoder_core_io_downs_1_a_valid;
  wire       [2:0]    system_peripheral_busXlen_decoder_core_io_downs_1_a_payload_opcode;
  wire       [2:0]    system_peripheral_busXlen_decoder_core_io_downs_1_a_payload_param;
  wire       [5:0]    system_peripheral_busXlen_decoder_core_io_downs_1_a_payload_source;
  wire       [15:0]   system_peripheral_busXlen_decoder_core_io_downs_1_a_payload_address;
  wire       [2:0]    system_peripheral_busXlen_decoder_core_io_downs_1_a_payload_size;
  wire       [3:0]    system_peripheral_busXlen_decoder_core_io_downs_1_a_payload_mask;
  wire       [31:0]   system_peripheral_busXlen_decoder_core_io_downs_1_a_payload_data;
  wire                system_peripheral_busXlen_decoder_core_io_downs_1_a_payload_corrupt;
  wire                system_peripheral_busXlen_decoder_core_io_downs_1_d_ready;
  wire                system_mainBus_decoder_core_io_up_a_ready;
  wire                system_mainBus_decoder_core_io_up_d_valid;
  wire       [2:0]    system_mainBus_decoder_core_io_up_d_payload_opcode;
  wire       [2:0]    system_mainBus_decoder_core_io_up_d_payload_param;
  wire       [5:0]    system_mainBus_decoder_core_io_up_d_payload_source;
  wire       [2:0]    system_mainBus_decoder_core_io_up_d_payload_size;
  wire                system_mainBus_decoder_core_io_up_d_payload_denied;
  wire       [63:0]   system_mainBus_decoder_core_io_up_d_payload_data;
  wire                system_mainBus_decoder_core_io_up_d_payload_corrupt;
  wire                system_mainBus_decoder_core_io_downs_0_a_valid;
  wire       [2:0]    system_mainBus_decoder_core_io_downs_0_a_payload_opcode;
  wire       [2:0]    system_mainBus_decoder_core_io_downs_0_a_payload_param;
  wire       [5:0]    system_mainBus_decoder_core_io_downs_0_a_payload_source;
  wire       [15:0]   system_mainBus_decoder_core_io_downs_0_a_payload_address;
  wire       [2:0]    system_mainBus_decoder_core_io_downs_0_a_payload_size;
  wire       [7:0]    system_mainBus_decoder_core_io_downs_0_a_payload_mask;
  wire       [63:0]   system_mainBus_decoder_core_io_downs_0_a_payload_data;
  wire                system_mainBus_decoder_core_io_downs_0_a_payload_corrupt;
  wire                system_mainBus_decoder_core_io_downs_0_d_ready;
  wire                system_mainBus_decoder_core_io_downs_1_a_valid;
  wire       [2:0]    system_mainBus_decoder_core_io_downs_1_a_payload_opcode;
  wire       [2:0]    system_mainBus_decoder_core_io_downs_1_a_payload_param;
  wire       [5:0]    system_mainBus_decoder_core_io_downs_1_a_payload_source;
  wire       [28:0]   system_mainBus_decoder_core_io_downs_1_a_payload_address;
  wire       [2:0]    system_mainBus_decoder_core_io_downs_1_a_payload_size;
  wire       [7:0]    system_mainBus_decoder_core_io_downs_1_a_payload_mask;
  wire       [63:0]   system_mainBus_decoder_core_io_downs_1_a_payload_data;
  wire                system_mainBus_decoder_core_io_downs_1_a_payload_corrupt;
  wire                system_mainBus_decoder_core_io_downs_1_d_ready;
  wire                system_peripheral_plic_thread_logic_io_bus_a_ready;
  wire                system_peripheral_plic_thread_logic_io_bus_d_valid;
  wire       [2:0]    system_peripheral_plic_thread_logic_io_bus_d_payload_opcode;
  wire       [2:0]    system_peripheral_plic_thread_logic_io_bus_d_payload_param;
  wire       [5:0]    system_peripheral_plic_thread_logic_io_bus_d_payload_source;
  wire       [1:0]    system_peripheral_plic_thread_logic_io_bus_d_payload_size;
  wire                system_peripheral_plic_thread_logic_io_bus_d_payload_denied;
  wire       [31:0]   system_peripheral_plic_thread_logic_io_bus_d_payload_data;
  wire                system_peripheral_plic_thread_logic_io_bus_d_payload_corrupt;
  wire       [0:0]    system_peripheral_plic_thread_logic_io_targets;
  wire                system_peripheral_uart_logic_core_io_bus_a_ready;
  wire                system_peripheral_uart_logic_core_io_bus_d_valid;
  wire       [2:0]    system_peripheral_uart_logic_core_io_bus_d_payload_opcode;
  wire       [2:0]    system_peripheral_uart_logic_core_io_bus_d_payload_param;
  wire       [5:0]    system_peripheral_uart_logic_core_io_bus_d_payload_source;
  wire       [1:0]    system_peripheral_uart_logic_core_io_bus_d_payload_size;
  wire                system_peripheral_uart_logic_core_io_bus_d_payload_denied;
  wire       [31:0]   system_peripheral_uart_logic_core_io_bus_d_payload_data;
  wire                system_peripheral_uart_logic_core_io_bus_d_payload_corrupt;
  wire                system_peripheral_uart_logic_core_io_uart_txd;
  wire                system_peripheral_uart_logic_core_io_interrupt;
  wire                system_peripheral_demo_logic_core_io_bus_a_ready;
  wire                system_peripheral_demo_logic_core_io_bus_d_valid;
  wire       [2:0]    system_peripheral_demo_logic_core_io_bus_d_payload_opcode;
  wire       [2:0]    system_peripheral_demo_logic_core_io_bus_d_payload_param;
  wire       [5:0]    system_peripheral_demo_logic_core_io_bus_d_payload_source;
  wire       [1:0]    system_peripheral_demo_logic_core_io_bus_d_payload_size;
  wire                system_peripheral_demo_logic_core_io_bus_d_payload_denied;
  wire       [31:0]   system_peripheral_demo_logic_core_io_bus_d_payload_data;
  wire                system_peripheral_demo_logic_core_io_bus_d_payload_corrupt;
  wire       [7:0]    system_peripheral_demo_logic_core_io_leds;
  wire                system_peripheral_demo_logic_core_io_interrupt;
  wire                system_mainBus_to_system_peripheral_busXlen_widthAdapter_io_up_a_ready;
  wire                system_mainBus_to_system_peripheral_busXlen_widthAdapter_io_up_d_valid;
  wire       [2:0]    system_mainBus_to_system_peripheral_busXlen_widthAdapter_io_up_d_payload_opcode;
  wire       [2:0]    system_mainBus_to_system_peripheral_busXlen_widthAdapter_io_up_d_payload_param;
  wire       [5:0]    system_mainBus_to_system_peripheral_busXlen_widthAdapter_io_up_d_payload_source;
  wire       [2:0]    system_mainBus_to_system_peripheral_busXlen_widthAdapter_io_up_d_payload_size;
  wire                system_mainBus_to_system_peripheral_busXlen_widthAdapter_io_up_d_payload_denied;
  wire       [63:0]   system_mainBus_to_system_peripheral_busXlen_widthAdapter_io_up_d_payload_data;
  wire                system_mainBus_to_system_peripheral_busXlen_widthAdapter_io_up_d_payload_corrupt;
  wire                system_mainBus_to_system_peripheral_busXlen_widthAdapter_io_down_a_valid;
  wire       [2:0]    system_mainBus_to_system_peripheral_busXlen_widthAdapter_io_down_a_payload_opcode;
  wire       [2:0]    system_mainBus_to_system_peripheral_busXlen_widthAdapter_io_down_a_payload_param;
  wire       [5:0]    system_mainBus_to_system_peripheral_busXlen_widthAdapter_io_down_a_payload_source;
  wire       [28:0]   system_mainBus_to_system_peripheral_busXlen_widthAdapter_io_down_a_payload_address;
  wire       [2:0]    system_mainBus_to_system_peripheral_busXlen_widthAdapter_io_down_a_payload_size;
  wire       [3:0]    system_mainBus_to_system_peripheral_busXlen_widthAdapter_io_down_a_payload_mask;
  wire       [31:0]   system_mainBus_to_system_peripheral_busXlen_widthAdapter_io_down_a_payload_data;
  wire                system_mainBus_to_system_peripheral_busXlen_widthAdapter_io_down_a_payload_corrupt;
  wire                system_mainBus_to_system_peripheral_busXlen_widthAdapter_io_down_d_ready;
  wire                system_peripheral_bus32_decoder_core_io_up_a_ready;
  wire                system_peripheral_bus32_decoder_core_io_up_d_valid;
  wire       [2:0]    system_peripheral_bus32_decoder_core_io_up_d_payload_opcode;
  wire       [2:0]    system_peripheral_bus32_decoder_core_io_up_d_payload_param;
  wire       [5:0]    system_peripheral_bus32_decoder_core_io_up_d_payload_source;
  wire       [1:0]    system_peripheral_bus32_decoder_core_io_up_d_payload_size;
  wire                system_peripheral_bus32_decoder_core_io_up_d_payload_denied;
  wire       [31:0]   system_peripheral_bus32_decoder_core_io_up_d_payload_data;
  wire                system_peripheral_bus32_decoder_core_io_up_d_payload_corrupt;
  wire                system_peripheral_bus32_decoder_core_io_downs_0_a_valid;
  wire       [2:0]    system_peripheral_bus32_decoder_core_io_downs_0_a_payload_opcode;
  wire       [2:0]    system_peripheral_bus32_decoder_core_io_downs_0_a_payload_param;
  wire       [5:0]    system_peripheral_bus32_decoder_core_io_downs_0_a_payload_source;
  wire       [21:0]   system_peripheral_bus32_decoder_core_io_downs_0_a_payload_address;
  wire       [1:0]    system_peripheral_bus32_decoder_core_io_downs_0_a_payload_size;
  wire       [3:0]    system_peripheral_bus32_decoder_core_io_downs_0_a_payload_mask;
  wire       [31:0]   system_peripheral_bus32_decoder_core_io_downs_0_a_payload_data;
  wire                system_peripheral_bus32_decoder_core_io_downs_0_a_payload_corrupt;
  wire                system_peripheral_bus32_decoder_core_io_downs_0_d_ready;
  wire                system_peripheral_bus32_decoder_core_io_downs_1_a_valid;
  wire       [2:0]    system_peripheral_bus32_decoder_core_io_downs_1_a_payload_opcode;
  wire       [2:0]    system_peripheral_bus32_decoder_core_io_downs_1_a_payload_param;
  wire       [5:0]    system_peripheral_bus32_decoder_core_io_downs_1_a_payload_source;
  wire       [7:0]    system_peripheral_bus32_decoder_core_io_downs_1_a_payload_address;
  wire       [1:0]    system_peripheral_bus32_decoder_core_io_downs_1_a_payload_size;
  wire       [3:0]    system_peripheral_bus32_decoder_core_io_downs_1_a_payload_mask;
  wire       [31:0]   system_peripheral_bus32_decoder_core_io_downs_1_a_payload_data;
  wire                system_peripheral_bus32_decoder_core_io_downs_1_a_payload_corrupt;
  wire                system_peripheral_bus32_decoder_core_io_downs_1_d_ready;
  wire                system_peripheral_bus32_decoder_core_io_downs_2_a_valid;
  wire       [2:0]    system_peripheral_bus32_decoder_core_io_downs_2_a_payload_opcode;
  wire       [2:0]    system_peripheral_bus32_decoder_core_io_downs_2_a_payload_param;
  wire       [5:0]    system_peripheral_bus32_decoder_core_io_downs_2_a_payload_source;
  wire       [11:0]   system_peripheral_bus32_decoder_core_io_downs_2_a_payload_address;
  wire       [1:0]    system_peripheral_bus32_decoder_core_io_downs_2_a_payload_size;
  wire       [3:0]    system_peripheral_bus32_decoder_core_io_downs_2_a_payload_mask;
  wire       [31:0]   system_peripheral_bus32_decoder_core_io_downs_2_a_payload_data;
  wire                system_peripheral_bus32_decoder_core_io_downs_2_a_payload_corrupt;
  wire                system_peripheral_bus32_decoder_core_io_downs_2_d_ready;
  wire                socCtrl_debug_reset;
  wire                socCtrl_system_reset;
  wire                system_cpu_priv_mti_flag;
  wire                system_cpu_priv_msi_flag;
  wire                system_cpu_priv_mei_flag;
  wire                system_cpu_priv_stoptime;
  wire       [63:0]   system_cpu_priv_rdtime;
  wire       [63:0]   system_peripheral_clint_time;
  wire                system_peripheral_uart_interrupt_flag;
  wire                system_peripheral_plic_from_system_peripheral_uart_interrupt_flag;
  wire                system_peripheral_demo_interrupt_flag;
  wire                system_peripheral_plic_from_system_peripheral_demo_interrupt_flag;
  wire                system_peripheral_plic_to_system_cpu_priv_mei_flag;
  reg                 system_cpu_priv_stoptime_regNext;
  reg        [63:0]   _zz_system_cpu_priv_rdtime;
  wire                socCtrl_debug_fiber_aggregator_reset;
  reg        [6:0]    socCtrl_debug_fiber_holder_counter;
  wire                socCtrl_debug_fiber_holder_reset;
  wire                when_CrossClock_l341;
  wire                socCtrl_system_fiber_aggregator_reset;
  reg        [6:0]    socCtrl_system_fiber_holder_counter;
  wire                socCtrl_system_fiber_holder_reset;
  wire                when_CrossClock_l341_1;
  wire                system_cpu_priv_mti_thread_gateways_0_flag;
  wire                system_cpu_priv_msi_thread_gateways_0_flag;
  wire                system_cpu_priv_mei_thread_gateways_0_flag;
  wire                system_peripheral_plic_from_system_peripheral_uart_interrupt_thread_gateways_0_flag;
  wire                system_peripheral_plic_from_system_peripheral_demo_interrupt_thread_gateways_0_flag;
  wire                system_cpu_iBus_bus_a_valid;
  wire                system_cpu_iBus_bus_a_ready;
  wire       [2:0]    system_cpu_iBus_bus_a_payload_opcode;
  wire       [2:0]    system_cpu_iBus_bus_a_payload_param;
  wire       [2:0]    system_cpu_iBus_bus_a_payload_source;
  wire       [31:0]   system_cpu_iBus_bus_a_payload_address;
  wire       [2:0]    system_cpu_iBus_bus_a_payload_size;
  wire                system_cpu_iBus_bus_d_valid;
  wire                system_cpu_iBus_bus_d_ready;
  wire       [2:0]    system_cpu_iBus_bus_d_payload_opcode;
  wire       [2:0]    system_cpu_iBus_bus_d_payload_param;
  wire       [2:0]    system_cpu_iBus_bus_d_payload_source;
  wire       [2:0]    system_cpu_iBus_bus_d_payload_size;
  wire                system_cpu_iBus_bus_d_payload_denied;
  wire       [63:0]   system_cpu_iBus_bus_d_payload_data;
  wire                system_cpu_iBus_bus_d_payload_corrupt;
  wire                system_cpu_iBus_noDecoder_toDown_a_valid;
  wire                system_cpu_iBus_noDecoder_toDown_a_ready;
  wire       [2:0]    system_cpu_iBus_noDecoder_toDown_a_payload_opcode;
  wire       [2:0]    system_cpu_iBus_noDecoder_toDown_a_payload_param;
  wire       [2:0]    system_cpu_iBus_noDecoder_toDown_a_payload_source;
  wire       [31:0]   system_cpu_iBus_noDecoder_toDown_a_payload_address;
  wire       [2:0]    system_cpu_iBus_noDecoder_toDown_a_payload_size;
  wire                system_cpu_iBus_noDecoder_toDown_d_valid;
  wire                system_cpu_iBus_noDecoder_toDown_d_ready;
  wire       [2:0]    system_cpu_iBus_noDecoder_toDown_d_payload_opcode;
  wire       [2:0]    system_cpu_iBus_noDecoder_toDown_d_payload_param;
  wire       [2:0]    system_cpu_iBus_noDecoder_toDown_d_payload_source;
  wire       [2:0]    system_cpu_iBus_noDecoder_toDown_d_payload_size;
  wire                system_cpu_iBus_noDecoder_toDown_d_payload_denied;
  wire       [63:0]   system_cpu_iBus_noDecoder_toDown_d_payload_data;
  wire                system_cpu_iBus_noDecoder_toDown_d_payload_corrupt;
  wire                system_cpu_dBus_bus_a_valid;
  wire                system_cpu_dBus_bus_a_ready;
  wire       [2:0]    system_cpu_dBus_bus_a_payload_opcode;
  wire       [2:0]    system_cpu_dBus_bus_a_payload_param;
  wire       [31:0]   system_cpu_dBus_bus_a_payload_address;
  wire       [1:0]    system_cpu_dBus_bus_a_payload_size;
  wire       [3:0]    system_cpu_dBus_bus_a_payload_mask;
  wire       [31:0]   system_cpu_dBus_bus_a_payload_data;
  wire                system_cpu_dBus_bus_a_payload_corrupt;
  wire                system_cpu_dBus_bus_d_valid;
  wire                system_cpu_dBus_bus_d_ready;
  wire       [2:0]    system_cpu_dBus_bus_d_payload_opcode;
  wire       [2:0]    system_cpu_dBus_bus_d_payload_param;
  wire       [1:0]    system_cpu_dBus_bus_d_payload_size;
  wire                system_cpu_dBus_bus_d_payload_denied;
  wire       [31:0]   system_cpu_dBus_bus_d_payload_data;
  wire                system_cpu_dBus_bus_d_payload_corrupt;
  wire                system_cpu_dBus_noDecoder_toDown_a_valid;
  wire                system_cpu_dBus_noDecoder_toDown_a_ready;
  wire       [2:0]    system_cpu_dBus_noDecoder_toDown_a_payload_opcode;
  wire       [2:0]    system_cpu_dBus_noDecoder_toDown_a_payload_param;
  wire       [31:0]   system_cpu_dBus_noDecoder_toDown_a_payload_address;
  wire       [1:0]    system_cpu_dBus_noDecoder_toDown_a_payload_size;
  wire       [3:0]    system_cpu_dBus_noDecoder_toDown_a_payload_mask;
  wire       [31:0]   system_cpu_dBus_noDecoder_toDown_a_payload_data;
  wire                system_cpu_dBus_noDecoder_toDown_a_payload_corrupt;
  wire                system_cpu_dBus_noDecoder_toDown_d_valid;
  wire                system_cpu_dBus_noDecoder_toDown_d_ready;
  wire       [2:0]    system_cpu_dBus_noDecoder_toDown_d_payload_opcode;
  wire       [2:0]    system_cpu_dBus_noDecoder_toDown_d_payload_param;
  wire       [1:0]    system_cpu_dBus_noDecoder_toDown_d_payload_size;
  wire                system_cpu_dBus_noDecoder_toDown_d_payload_denied;
  wire       [31:0]   system_cpu_dBus_noDecoder_toDown_d_payload_data;
  wire                system_cpu_dBus_noDecoder_toDown_d_payload_corrupt;
  wire                system_cpu_dBus_bus_a_s2mPipe_valid;
  wire                system_cpu_dBus_bus_a_s2mPipe_ready;
  wire       [2:0]    system_cpu_dBus_bus_a_s2mPipe_payload_opcode;
  wire       [2:0]    system_cpu_dBus_bus_a_s2mPipe_payload_param;
  wire       [31:0]   system_cpu_dBus_bus_a_s2mPipe_payload_address;
  wire       [1:0]    system_cpu_dBus_bus_a_s2mPipe_payload_size;
  wire       [3:0]    system_cpu_dBus_bus_a_s2mPipe_payload_mask;
  wire       [31:0]   system_cpu_dBus_bus_a_s2mPipe_payload_data;
  wire                system_cpu_dBus_bus_a_s2mPipe_payload_corrupt;
  reg                 system_cpu_dBus_bus_a_rValidN;
  reg        [2:0]    system_cpu_dBus_bus_a_rData_opcode;
  reg        [2:0]    system_cpu_dBus_bus_a_rData_param;
  reg        [31:0]   system_cpu_dBus_bus_a_rData_address;
  reg        [1:0]    system_cpu_dBus_bus_a_rData_size;
  reg        [3:0]    system_cpu_dBus_bus_a_rData_mask;
  reg        [31:0]   system_cpu_dBus_bus_a_rData_data;
  reg                 system_cpu_dBus_bus_a_rData_corrupt;
  wire       [2:0]    _zz_system_cpu_dBus_bus_a_s2mPipe_payload_opcode;
  wire                system_cpu_dBus_noDecoder_toDown_d_combStage_valid;
  wire                system_cpu_dBus_noDecoder_toDown_d_combStage_ready;
  wire       [2:0]    system_cpu_dBus_noDecoder_toDown_d_combStage_payload_opcode;
  wire       [2:0]    system_cpu_dBus_noDecoder_toDown_d_combStage_payload_param;
  wire       [1:0]    system_cpu_dBus_noDecoder_toDown_d_combStage_payload_size;
  wire                system_cpu_dBus_noDecoder_toDown_d_combStage_payload_denied;
  wire       [31:0]   system_cpu_dBus_noDecoder_toDown_d_combStage_payload_data;
  wire                system_cpu_dBus_noDecoder_toDown_d_combStage_payload_corrupt;
  wire                system_cpu_lsuL1Bus_bus_a_valid;
  wire                system_cpu_lsuL1Bus_bus_a_ready;
  wire       [2:0]    system_cpu_lsuL1Bus_bus_a_payload_opcode;
  wire       [2:0]    system_cpu_lsuL1Bus_bus_a_payload_param;
  wire       [3:0]    system_cpu_lsuL1Bus_bus_a_payload_source;
  wire       [31:0]   system_cpu_lsuL1Bus_bus_a_payload_address;
  wire       [2:0]    system_cpu_lsuL1Bus_bus_a_payload_size;
  wire       [7:0]    system_cpu_lsuL1Bus_bus_a_payload_mask;
  wire       [63:0]   system_cpu_lsuL1Bus_bus_a_payload_data;
  wire                system_cpu_lsuL1Bus_bus_a_payload_corrupt;
  wire                system_cpu_lsuL1Bus_bus_d_valid;
  wire                system_cpu_lsuL1Bus_bus_d_ready;
  wire       [2:0]    system_cpu_lsuL1Bus_bus_d_payload_opcode;
  wire       [2:0]    system_cpu_lsuL1Bus_bus_d_payload_param;
  wire       [3:0]    system_cpu_lsuL1Bus_bus_d_payload_source;
  wire       [2:0]    system_cpu_lsuL1Bus_bus_d_payload_size;
  wire                system_cpu_lsuL1Bus_bus_d_payload_denied;
  wire       [63:0]   system_cpu_lsuL1Bus_bus_d_payload_data;
  wire                system_cpu_lsuL1Bus_bus_d_payload_corrupt;
  wire                system_cpu_lsuL1Bus_noDecoder_toDown_a_valid;
  wire                system_cpu_lsuL1Bus_noDecoder_toDown_a_ready;
  wire       [2:0]    system_cpu_lsuL1Bus_noDecoder_toDown_a_payload_opcode;
  wire       [2:0]    system_cpu_lsuL1Bus_noDecoder_toDown_a_payload_param;
  wire       [3:0]    system_cpu_lsuL1Bus_noDecoder_toDown_a_payload_source;
  wire       [31:0]   system_cpu_lsuL1Bus_noDecoder_toDown_a_payload_address;
  wire       [2:0]    system_cpu_lsuL1Bus_noDecoder_toDown_a_payload_size;
  wire       [7:0]    system_cpu_lsuL1Bus_noDecoder_toDown_a_payload_mask;
  wire       [63:0]   system_cpu_lsuL1Bus_noDecoder_toDown_a_payload_data;
  wire                system_cpu_lsuL1Bus_noDecoder_toDown_a_payload_corrupt;
  wire                system_cpu_lsuL1Bus_noDecoder_toDown_d_valid;
  wire                system_cpu_lsuL1Bus_noDecoder_toDown_d_ready;
  wire       [2:0]    system_cpu_lsuL1Bus_noDecoder_toDown_d_payload_opcode;
  wire       [2:0]    system_cpu_lsuL1Bus_noDecoder_toDown_d_payload_param;
  wire       [3:0]    system_cpu_lsuL1Bus_noDecoder_toDown_d_payload_source;
  wire       [2:0]    system_cpu_lsuL1Bus_noDecoder_toDown_d_payload_size;
  wire                system_cpu_lsuL1Bus_noDecoder_toDown_d_payload_denied;
  wire       [63:0]   system_cpu_lsuL1Bus_noDecoder_toDown_d_payload_data;
  wire                system_cpu_lsuL1Bus_noDecoder_toDown_d_payload_corrupt;
  wire                system_mainBus_bus_a_valid;
  wire                system_mainBus_bus_a_ready;
  wire       [2:0]    system_mainBus_bus_a_payload_opcode;
  wire       [2:0]    system_mainBus_bus_a_payload_param;
  wire       [5:0]    system_mainBus_bus_a_payload_source;
  wire       [31:0]   system_mainBus_bus_a_payload_address;
  wire       [2:0]    system_mainBus_bus_a_payload_size;
  wire       [7:0]    system_mainBus_bus_a_payload_mask;
  wire       [63:0]   system_mainBus_bus_a_payload_data;
  wire                system_mainBus_bus_a_payload_corrupt;
  wire                system_mainBus_bus_d_valid;
  wire                system_mainBus_bus_d_ready;
  wire       [2:0]    system_mainBus_bus_d_payload_opcode;
  wire       [2:0]    system_mainBus_bus_d_payload_param;
  wire       [5:0]    system_mainBus_bus_d_payload_source;
  wire       [2:0]    system_mainBus_bus_d_payload_size;
  wire                system_mainBus_bus_d_payload_denied;
  wire       [63:0]   system_mainBus_bus_d_payload_data;
  wire                system_mainBus_bus_d_payload_corrupt;
  wire                system_cpu_iBus_to_system_mainBus_down_bus_a_valid;
  wire                system_cpu_iBus_to_system_mainBus_down_bus_a_ready;
  wire       [2:0]    system_cpu_iBus_to_system_mainBus_down_bus_a_payload_opcode;
  wire       [2:0]    system_cpu_iBus_to_system_mainBus_down_bus_a_payload_param;
  wire       [2:0]    system_cpu_iBus_to_system_mainBus_down_bus_a_payload_source;
  wire       [31:0]   system_cpu_iBus_to_system_mainBus_down_bus_a_payload_address;
  wire       [2:0]    system_cpu_iBus_to_system_mainBus_down_bus_a_payload_size;
  wire                system_cpu_iBus_to_system_mainBus_down_bus_d_valid;
  wire                system_cpu_iBus_to_system_mainBus_down_bus_d_ready;
  wire       [2:0]    system_cpu_iBus_to_system_mainBus_down_bus_d_payload_opcode;
  wire       [2:0]    system_cpu_iBus_to_system_mainBus_down_bus_d_payload_param;
  wire       [2:0]    system_cpu_iBus_to_system_mainBus_down_bus_d_payload_source;
  wire       [2:0]    system_cpu_iBus_to_system_mainBus_down_bus_d_payload_size;
  wire                system_cpu_iBus_to_system_mainBus_down_bus_d_payload_denied;
  wire       [63:0]   system_cpu_iBus_to_system_mainBus_down_bus_d_payload_data;
  wire                system_cpu_iBus_to_system_mainBus_down_bus_d_payload_corrupt;
  wire                system_cpu_dBus_to_system_mainBus_down_bus_a_valid;
  wire                system_cpu_dBus_to_system_mainBus_down_bus_a_ready;
  wire       [2:0]    system_cpu_dBus_to_system_mainBus_down_bus_a_payload_opcode;
  wire       [2:0]    system_cpu_dBus_to_system_mainBus_down_bus_a_payload_param;
  wire       [31:0]   system_cpu_dBus_to_system_mainBus_down_bus_a_payload_address;
  wire       [1:0]    system_cpu_dBus_to_system_mainBus_down_bus_a_payload_size;
  wire       [7:0]    system_cpu_dBus_to_system_mainBus_down_bus_a_payload_mask;
  wire       [63:0]   system_cpu_dBus_to_system_mainBus_down_bus_a_payload_data;
  wire                system_cpu_dBus_to_system_mainBus_down_bus_a_payload_corrupt;
  wire                system_cpu_dBus_to_system_mainBus_down_bus_d_valid;
  wire                system_cpu_dBus_to_system_mainBus_down_bus_d_ready;
  wire       [2:0]    system_cpu_dBus_to_system_mainBus_down_bus_d_payload_opcode;
  wire       [2:0]    system_cpu_dBus_to_system_mainBus_down_bus_d_payload_param;
  wire       [1:0]    system_cpu_dBus_to_system_mainBus_down_bus_d_payload_size;
  wire                system_cpu_dBus_to_system_mainBus_down_bus_d_payload_denied;
  wire       [63:0]   system_cpu_dBus_to_system_mainBus_down_bus_d_payload_data;
  wire                system_cpu_dBus_to_system_mainBus_down_bus_d_payload_corrupt;
  wire                system_cpu_lsuL1Bus_to_system_mainBus_down_bus_a_valid;
  wire                system_cpu_lsuL1Bus_to_system_mainBus_down_bus_a_ready;
  wire       [2:0]    system_cpu_lsuL1Bus_to_system_mainBus_down_bus_a_payload_opcode;
  wire       [2:0]    system_cpu_lsuL1Bus_to_system_mainBus_down_bus_a_payload_param;
  wire       [3:0]    system_cpu_lsuL1Bus_to_system_mainBus_down_bus_a_payload_source;
  wire       [31:0]   system_cpu_lsuL1Bus_to_system_mainBus_down_bus_a_payload_address;
  wire       [2:0]    system_cpu_lsuL1Bus_to_system_mainBus_down_bus_a_payload_size;
  wire       [7:0]    system_cpu_lsuL1Bus_to_system_mainBus_down_bus_a_payload_mask;
  wire       [63:0]   system_cpu_lsuL1Bus_to_system_mainBus_down_bus_a_payload_data;
  wire                system_cpu_lsuL1Bus_to_system_mainBus_down_bus_a_payload_corrupt;
  wire                system_cpu_lsuL1Bus_to_system_mainBus_down_bus_d_valid;
  wire                system_cpu_lsuL1Bus_to_system_mainBus_down_bus_d_ready;
  wire       [2:0]    system_cpu_lsuL1Bus_to_system_mainBus_down_bus_d_payload_opcode;
  wire       [2:0]    system_cpu_lsuL1Bus_to_system_mainBus_down_bus_d_payload_param;
  wire       [3:0]    system_cpu_lsuL1Bus_to_system_mainBus_down_bus_d_payload_source;
  wire       [2:0]    system_cpu_lsuL1Bus_to_system_mainBus_down_bus_d_payload_size;
  wire                system_cpu_lsuL1Bus_to_system_mainBus_down_bus_d_payload_denied;
  wire       [63:0]   system_cpu_lsuL1Bus_to_system_mainBus_down_bus_d_payload_data;
  wire                system_cpu_lsuL1Bus_to_system_mainBus_down_bus_d_payload_corrupt;
  wire                system_ram_up_bus_a_valid;
  wire                system_ram_up_bus_a_ready;
  wire       [2:0]    system_ram_up_bus_a_payload_opcode;
  wire       [2:0]    system_ram_up_bus_a_payload_param;
  wire       [5:0]    system_ram_up_bus_a_payload_source;
  wire       [15:0]   system_ram_up_bus_a_payload_address;
  wire       [2:0]    system_ram_up_bus_a_payload_size;
  wire       [7:0]    system_ram_up_bus_a_payload_mask;
  wire       [63:0]   system_ram_up_bus_a_payload_data;
  wire                system_ram_up_bus_a_payload_corrupt;
  wire                system_ram_up_bus_d_valid;
  wire                system_ram_up_bus_d_ready;
  wire       [2:0]    system_ram_up_bus_d_payload_opcode;
  wire       [2:0]    system_ram_up_bus_d_payload_param;
  wire       [5:0]    system_ram_up_bus_d_payload_source;
  wire       [2:0]    system_ram_up_bus_d_payload_size;
  wire                system_ram_up_bus_d_payload_denied;
  wire       [63:0]   system_ram_up_bus_d_payload_data;
  wire                system_ram_up_bus_d_payload_corrupt;
  wire                system_mainBus_to_system_ram_up_down_bus_a_valid;
  wire                system_mainBus_to_system_ram_up_down_bus_a_ready;
  wire       [2:0]    system_mainBus_to_system_ram_up_down_bus_a_payload_opcode;
  wire       [2:0]    system_mainBus_to_system_ram_up_down_bus_a_payload_param;
  wire       [5:0]    system_mainBus_to_system_ram_up_down_bus_a_payload_source;
  wire       [15:0]   system_mainBus_to_system_ram_up_down_bus_a_payload_address;
  wire       [2:0]    system_mainBus_to_system_ram_up_down_bus_a_payload_size;
  wire       [7:0]    system_mainBus_to_system_ram_up_down_bus_a_payload_mask;
  wire       [63:0]   system_mainBus_to_system_ram_up_down_bus_a_payload_data;
  wire                system_mainBus_to_system_ram_up_down_bus_a_payload_corrupt;
  wire                system_mainBus_to_system_ram_up_down_bus_d_valid;
  wire                system_mainBus_to_system_ram_up_down_bus_d_ready;
  wire       [2:0]    system_mainBus_to_system_ram_up_down_bus_d_payload_opcode;
  wire       [2:0]    system_mainBus_to_system_ram_up_down_bus_d_payload_param;
  wire       [5:0]    system_mainBus_to_system_ram_up_down_bus_d_payload_source;
  wire       [2:0]    system_mainBus_to_system_ram_up_down_bus_d_payload_size;
  wire                system_mainBus_to_system_ram_up_down_bus_d_payload_denied;
  wire       [63:0]   system_mainBus_to_system_ram_up_down_bus_d_payload_data;
  wire                system_mainBus_to_system_ram_up_down_bus_d_payload_corrupt;
  wire                system_peripheral_busXlen_bus_a_valid;
  wire                system_peripheral_busXlen_bus_a_ready;
  wire       [2:0]    system_peripheral_busXlen_bus_a_payload_opcode;
  wire       [2:0]    system_peripheral_busXlen_bus_a_payload_param;
  wire       [5:0]    system_peripheral_busXlen_bus_a_payload_source;
  wire       [28:0]   system_peripheral_busXlen_bus_a_payload_address;
  wire       [2:0]    system_peripheral_busXlen_bus_a_payload_size;
  wire       [3:0]    system_peripheral_busXlen_bus_a_payload_mask;
  wire       [31:0]   system_peripheral_busXlen_bus_a_payload_data;
  wire                system_peripheral_busXlen_bus_a_payload_corrupt;
  wire                system_peripheral_busXlen_bus_d_valid;
  wire                system_peripheral_busXlen_bus_d_ready;
  wire       [2:0]    system_peripheral_busXlen_bus_d_payload_opcode;
  wire       [2:0]    system_peripheral_busXlen_bus_d_payload_param;
  wire       [5:0]    system_peripheral_busXlen_bus_d_payload_source;
  wire       [2:0]    system_peripheral_busXlen_bus_d_payload_size;
  wire                system_peripheral_busXlen_bus_d_payload_denied;
  wire       [31:0]   system_peripheral_busXlen_bus_d_payload_data;
  wire                system_peripheral_busXlen_bus_d_payload_corrupt;
  wire                system_mainBus_to_system_peripheral_busXlen_down_bus_a_valid;
  wire                system_mainBus_to_system_peripheral_busXlen_down_bus_a_ready;
  wire       [2:0]    system_mainBus_to_system_peripheral_busXlen_down_bus_a_payload_opcode;
  wire       [2:0]    system_mainBus_to_system_peripheral_busXlen_down_bus_a_payload_param;
  wire       [5:0]    system_mainBus_to_system_peripheral_busXlen_down_bus_a_payload_source;
  wire       [28:0]   system_mainBus_to_system_peripheral_busXlen_down_bus_a_payload_address;
  wire       [2:0]    system_mainBus_to_system_peripheral_busXlen_down_bus_a_payload_size;
  wire       [3:0]    system_mainBus_to_system_peripheral_busXlen_down_bus_a_payload_mask;
  wire       [31:0]   system_mainBus_to_system_peripheral_busXlen_down_bus_a_payload_data;
  wire                system_mainBus_to_system_peripheral_busXlen_down_bus_a_payload_corrupt;
  wire                system_mainBus_to_system_peripheral_busXlen_down_bus_d_valid;
  wire                system_mainBus_to_system_peripheral_busXlen_down_bus_d_ready;
  wire       [2:0]    system_mainBus_to_system_peripheral_busXlen_down_bus_d_payload_opcode;
  wire       [2:0]    system_mainBus_to_system_peripheral_busXlen_down_bus_d_payload_param;
  wire       [5:0]    system_mainBus_to_system_peripheral_busXlen_down_bus_d_payload_source;
  wire       [2:0]    system_mainBus_to_system_peripheral_busXlen_down_bus_d_payload_size;
  wire                system_mainBus_to_system_peripheral_busXlen_down_bus_d_payload_denied;
  wire       [31:0]   system_mainBus_to_system_peripheral_busXlen_down_bus_d_payload_data;
  wire                system_mainBus_to_system_peripheral_busXlen_down_bus_d_payload_corrupt;
  wire                system_mainBus_to_system_peripheral_busXlen_down_bus_a_halfPipe_valid;
  wire                system_mainBus_to_system_peripheral_busXlen_down_bus_a_halfPipe_ready;
  wire       [2:0]    system_mainBus_to_system_peripheral_busXlen_down_bus_a_halfPipe_payload_opcode;
  wire       [2:0]    system_mainBus_to_system_peripheral_busXlen_down_bus_a_halfPipe_payload_param;
  wire       [5:0]    system_mainBus_to_system_peripheral_busXlen_down_bus_a_halfPipe_payload_source;
  wire       [28:0]   system_mainBus_to_system_peripheral_busXlen_down_bus_a_halfPipe_payload_address;
  wire       [2:0]    system_mainBus_to_system_peripheral_busXlen_down_bus_a_halfPipe_payload_size;
  wire       [3:0]    system_mainBus_to_system_peripheral_busXlen_down_bus_a_halfPipe_payload_mask;
  wire       [31:0]   system_mainBus_to_system_peripheral_busXlen_down_bus_a_halfPipe_payload_data;
  wire                system_mainBus_to_system_peripheral_busXlen_down_bus_a_halfPipe_payload_corrupt;
  reg                 system_mainBus_to_system_peripheral_busXlen_down_bus_a_rValid;
  wire                system_mainBus_to_system_peripheral_busXlen_down_bus_a_halfPipe_fire;
  reg        [2:0]    system_mainBus_to_system_peripheral_busXlen_down_bus_a_rData_opcode;
  reg        [2:0]    system_mainBus_to_system_peripheral_busXlen_down_bus_a_rData_param;
  reg        [5:0]    system_mainBus_to_system_peripheral_busXlen_down_bus_a_rData_source;
  reg        [28:0]   system_mainBus_to_system_peripheral_busXlen_down_bus_a_rData_address;
  reg        [2:0]    system_mainBus_to_system_peripheral_busXlen_down_bus_a_rData_size;
  reg        [3:0]    system_mainBus_to_system_peripheral_busXlen_down_bus_a_rData_mask;
  reg        [31:0]   system_mainBus_to_system_peripheral_busXlen_down_bus_a_rData_data;
  reg                 system_mainBus_to_system_peripheral_busXlen_down_bus_a_rData_corrupt;
  wire                system_peripheral_busXlen_bus_d_halfPipe_valid;
  wire                system_peripheral_busXlen_bus_d_halfPipe_ready;
  wire       [2:0]    system_peripheral_busXlen_bus_d_halfPipe_payload_opcode;
  wire       [2:0]    system_peripheral_busXlen_bus_d_halfPipe_payload_param;
  wire       [5:0]    system_peripheral_busXlen_bus_d_halfPipe_payload_source;
  wire       [2:0]    system_peripheral_busXlen_bus_d_halfPipe_payload_size;
  wire                system_peripheral_busXlen_bus_d_halfPipe_payload_denied;
  wire       [31:0]   system_peripheral_busXlen_bus_d_halfPipe_payload_data;
  wire                system_peripheral_busXlen_bus_d_halfPipe_payload_corrupt;
  reg                 system_peripheral_busXlen_bus_d_rValid;
  wire                system_peripheral_busXlen_bus_d_halfPipe_fire;
  reg        [2:0]    system_peripheral_busXlen_bus_d_rData_opcode;
  reg        [2:0]    system_peripheral_busXlen_bus_d_rData_param;
  reg        [5:0]    system_peripheral_busXlen_bus_d_rData_source;
  reg        [2:0]    system_peripheral_busXlen_bus_d_rData_size;
  reg                 system_peripheral_busXlen_bus_d_rData_denied;
  reg        [31:0]   system_peripheral_busXlen_bus_d_rData_data;
  reg                 system_peripheral_busXlen_bus_d_rData_corrupt;
  wire                system_cpu_iBus_to_system_mainBus_up_bus_a_valid;
  wire                system_cpu_iBus_to_system_mainBus_up_bus_a_ready;
  wire       [2:0]    system_cpu_iBus_to_system_mainBus_up_bus_a_payload_opcode;
  wire       [2:0]    system_cpu_iBus_to_system_mainBus_up_bus_a_payload_param;
  wire       [2:0]    system_cpu_iBus_to_system_mainBus_up_bus_a_payload_source;
  wire       [31:0]   system_cpu_iBus_to_system_mainBus_up_bus_a_payload_address;
  wire       [2:0]    system_cpu_iBus_to_system_mainBus_up_bus_a_payload_size;
  wire                system_cpu_iBus_to_system_mainBus_up_bus_d_valid;
  wire                system_cpu_iBus_to_system_mainBus_up_bus_d_ready;
  wire       [2:0]    system_cpu_iBus_to_system_mainBus_up_bus_d_payload_opcode;
  wire       [2:0]    system_cpu_iBus_to_system_mainBus_up_bus_d_payload_param;
  wire       [2:0]    system_cpu_iBus_to_system_mainBus_up_bus_d_payload_source;
  wire       [2:0]    system_cpu_iBus_to_system_mainBus_up_bus_d_payload_size;
  wire                system_cpu_iBus_to_system_mainBus_up_bus_d_payload_denied;
  wire       [63:0]   system_cpu_iBus_to_system_mainBus_up_bus_d_payload_data;
  wire                system_cpu_iBus_to_system_mainBus_up_bus_d_payload_corrupt;
  wire                system_cpu_dBus_to_system_mainBus_up_bus_a_valid;
  wire                system_cpu_dBus_to_system_mainBus_up_bus_a_ready;
  wire       [2:0]    system_cpu_dBus_to_system_mainBus_up_bus_a_payload_opcode;
  wire       [2:0]    system_cpu_dBus_to_system_mainBus_up_bus_a_payload_param;
  wire       [31:0]   system_cpu_dBus_to_system_mainBus_up_bus_a_payload_address;
  wire       [1:0]    system_cpu_dBus_to_system_mainBus_up_bus_a_payload_size;
  wire       [3:0]    system_cpu_dBus_to_system_mainBus_up_bus_a_payload_mask;
  wire       [31:0]   system_cpu_dBus_to_system_mainBus_up_bus_a_payload_data;
  wire                system_cpu_dBus_to_system_mainBus_up_bus_a_payload_corrupt;
  wire                system_cpu_dBus_to_system_mainBus_up_bus_d_valid;
  wire                system_cpu_dBus_to_system_mainBus_up_bus_d_ready;
  wire       [2:0]    system_cpu_dBus_to_system_mainBus_up_bus_d_payload_opcode;
  wire       [2:0]    system_cpu_dBus_to_system_mainBus_up_bus_d_payload_param;
  wire       [1:0]    system_cpu_dBus_to_system_mainBus_up_bus_d_payload_size;
  wire                system_cpu_dBus_to_system_mainBus_up_bus_d_payload_denied;
  wire       [31:0]   system_cpu_dBus_to_system_mainBus_up_bus_d_payload_data;
  wire                system_cpu_dBus_to_system_mainBus_up_bus_d_payload_corrupt;
  wire                system_cpu_lsuL1Bus_to_system_mainBus_up_bus_a_valid;
  wire                system_cpu_lsuL1Bus_to_system_mainBus_up_bus_a_ready;
  wire       [2:0]    system_cpu_lsuL1Bus_to_system_mainBus_up_bus_a_payload_opcode;
  wire       [2:0]    system_cpu_lsuL1Bus_to_system_mainBus_up_bus_a_payload_param;
  wire       [3:0]    system_cpu_lsuL1Bus_to_system_mainBus_up_bus_a_payload_source;
  wire       [31:0]   system_cpu_lsuL1Bus_to_system_mainBus_up_bus_a_payload_address;
  wire       [2:0]    system_cpu_lsuL1Bus_to_system_mainBus_up_bus_a_payload_size;
  wire       [7:0]    system_cpu_lsuL1Bus_to_system_mainBus_up_bus_a_payload_mask;
  wire       [63:0]   system_cpu_lsuL1Bus_to_system_mainBus_up_bus_a_payload_data;
  wire                system_cpu_lsuL1Bus_to_system_mainBus_up_bus_a_payload_corrupt;
  wire                system_cpu_lsuL1Bus_to_system_mainBus_up_bus_d_valid;
  wire                system_cpu_lsuL1Bus_to_system_mainBus_up_bus_d_ready;
  wire       [2:0]    system_cpu_lsuL1Bus_to_system_mainBus_up_bus_d_payload_opcode;
  wire       [2:0]    system_cpu_lsuL1Bus_to_system_mainBus_up_bus_d_payload_param;
  wire       [3:0]    system_cpu_lsuL1Bus_to_system_mainBus_up_bus_d_payload_source;
  wire       [2:0]    system_cpu_lsuL1Bus_to_system_mainBus_up_bus_d_payload_size;
  wire                system_cpu_lsuL1Bus_to_system_mainBus_up_bus_d_payload_denied;
  wire       [63:0]   system_cpu_lsuL1Bus_to_system_mainBus_up_bus_d_payload_data;
  wire                system_cpu_lsuL1Bus_to_system_mainBus_up_bus_d_payload_corrupt;
  wire                system_peripheral_bus32_bus_a_valid;
  wire                system_peripheral_bus32_bus_a_ready;
  wire       [2:0]    system_peripheral_bus32_bus_a_payload_opcode;
  wire       [2:0]    system_peripheral_bus32_bus_a_payload_param;
  wire       [5:0]    system_peripheral_bus32_bus_a_payload_source;
  wire       [28:0]   system_peripheral_bus32_bus_a_payload_address;
  wire       [1:0]    system_peripheral_bus32_bus_a_payload_size;
  wire       [3:0]    system_peripheral_bus32_bus_a_payload_mask;
  wire       [31:0]   system_peripheral_bus32_bus_a_payload_data;
  wire                system_peripheral_bus32_bus_a_payload_corrupt;
  wire                system_peripheral_bus32_bus_d_valid;
  wire                system_peripheral_bus32_bus_d_ready;
  wire       [2:0]    system_peripheral_bus32_bus_d_payload_opcode;
  wire       [2:0]    system_peripheral_bus32_bus_d_payload_param;
  wire       [5:0]    system_peripheral_bus32_bus_d_payload_source;
  wire       [1:0]    system_peripheral_bus32_bus_d_payload_size;
  wire                system_peripheral_bus32_bus_d_payload_denied;
  wire       [31:0]   system_peripheral_bus32_bus_d_payload_data;
  wire                system_peripheral_bus32_bus_d_payload_corrupt;
  wire                system_peripheral_busXlen_to_system_peripheral_bus32_down_bus_a_valid;
  wire                system_peripheral_busXlen_to_system_peripheral_bus32_down_bus_a_ready;
  wire       [2:0]    system_peripheral_busXlen_to_system_peripheral_bus32_down_bus_a_payload_opcode;
  wire       [2:0]    system_peripheral_busXlen_to_system_peripheral_bus32_down_bus_a_payload_param;
  wire       [5:0]    system_peripheral_busXlen_to_system_peripheral_bus32_down_bus_a_payload_source;
  wire       [28:0]   system_peripheral_busXlen_to_system_peripheral_bus32_down_bus_a_payload_address;
  wire       [1:0]    system_peripheral_busXlen_to_system_peripheral_bus32_down_bus_a_payload_size;
  wire       [3:0]    system_peripheral_busXlen_to_system_peripheral_bus32_down_bus_a_payload_mask;
  wire       [31:0]   system_peripheral_busXlen_to_system_peripheral_bus32_down_bus_a_payload_data;
  wire                system_peripheral_busXlen_to_system_peripheral_bus32_down_bus_a_payload_corrupt;
  wire                system_peripheral_busXlen_to_system_peripheral_bus32_down_bus_d_valid;
  wire                system_peripheral_busXlen_to_system_peripheral_bus32_down_bus_d_ready;
  wire       [2:0]    system_peripheral_busXlen_to_system_peripheral_bus32_down_bus_d_payload_opcode;
  wire       [2:0]    system_peripheral_busXlen_to_system_peripheral_bus32_down_bus_d_payload_param;
  wire       [5:0]    system_peripheral_busXlen_to_system_peripheral_bus32_down_bus_d_payload_source;
  wire       [1:0]    system_peripheral_busXlen_to_system_peripheral_bus32_down_bus_d_payload_size;
  wire                system_peripheral_busXlen_to_system_peripheral_bus32_down_bus_d_payload_denied;
  wire       [31:0]   system_peripheral_busXlen_to_system_peripheral_bus32_down_bus_d_payload_data;
  wire                system_peripheral_busXlen_to_system_peripheral_bus32_down_bus_d_payload_corrupt;
  wire                system_peripheral_clint_node_bus_a_valid;
  wire                system_peripheral_clint_node_bus_a_ready;
  wire       [2:0]    system_peripheral_clint_node_bus_a_payload_opcode;
  wire       [2:0]    system_peripheral_clint_node_bus_a_payload_param;
  wire       [5:0]    system_peripheral_clint_node_bus_a_payload_source;
  wire       [15:0]   system_peripheral_clint_node_bus_a_payload_address;
  wire       [2:0]    system_peripheral_clint_node_bus_a_payload_size;
  wire       [3:0]    system_peripheral_clint_node_bus_a_payload_mask;
  wire       [31:0]   system_peripheral_clint_node_bus_a_payload_data;
  wire                system_peripheral_clint_node_bus_a_payload_corrupt;
  wire                system_peripheral_clint_node_bus_d_valid;
  wire                system_peripheral_clint_node_bus_d_ready;
  wire       [2:0]    system_peripheral_clint_node_bus_d_payload_opcode;
  wire       [2:0]    system_peripheral_clint_node_bus_d_payload_param;
  wire       [5:0]    system_peripheral_clint_node_bus_d_payload_source;
  wire       [2:0]    system_peripheral_clint_node_bus_d_payload_size;
  wire                system_peripheral_clint_node_bus_d_payload_denied;
  wire       [31:0]   system_peripheral_clint_node_bus_d_payload_data;
  wire                system_peripheral_clint_node_bus_d_payload_corrupt;
  wire                system_peripheral_busXlen_to_system_peripheral_clint_node_down_bus_a_valid;
  wire                system_peripheral_busXlen_to_system_peripheral_clint_node_down_bus_a_ready;
  wire       [2:0]    system_peripheral_busXlen_to_system_peripheral_clint_node_down_bus_a_payload_opcode;
  wire       [2:0]    system_peripheral_busXlen_to_system_peripheral_clint_node_down_bus_a_payload_param;
  wire       [5:0]    system_peripheral_busXlen_to_system_peripheral_clint_node_down_bus_a_payload_source;
  wire       [15:0]   system_peripheral_busXlen_to_system_peripheral_clint_node_down_bus_a_payload_address;
  wire       [2:0]    system_peripheral_busXlen_to_system_peripheral_clint_node_down_bus_a_payload_size;
  wire       [3:0]    system_peripheral_busXlen_to_system_peripheral_clint_node_down_bus_a_payload_mask;
  wire       [31:0]   system_peripheral_busXlen_to_system_peripheral_clint_node_down_bus_a_payload_data;
  wire                system_peripheral_busXlen_to_system_peripheral_clint_node_down_bus_a_payload_corrupt;
  wire                system_peripheral_busXlen_to_system_peripheral_clint_node_down_bus_d_valid;
  wire                system_peripheral_busXlen_to_system_peripheral_clint_node_down_bus_d_ready;
  wire       [2:0]    system_peripheral_busXlen_to_system_peripheral_clint_node_down_bus_d_payload_opcode;
  wire       [2:0]    system_peripheral_busXlen_to_system_peripheral_clint_node_down_bus_d_payload_param;
  wire       [5:0]    system_peripheral_busXlen_to_system_peripheral_clint_node_down_bus_d_payload_source;
  wire       [2:0]    system_peripheral_busXlen_to_system_peripheral_clint_node_down_bus_d_payload_size;
  wire                system_peripheral_busXlen_to_system_peripheral_clint_node_down_bus_d_payload_denied;
  wire       [31:0]   system_peripheral_busXlen_to_system_peripheral_clint_node_down_bus_d_payload_data;
  wire                system_peripheral_busXlen_to_system_peripheral_clint_node_down_bus_d_payload_corrupt;
  wire                system_peripheral_plic_node_bus_a_valid;
  wire                system_peripheral_plic_node_bus_a_ready;
  wire       [2:0]    system_peripheral_plic_node_bus_a_payload_opcode;
  wire       [2:0]    system_peripheral_plic_node_bus_a_payload_param;
  wire       [5:0]    system_peripheral_plic_node_bus_a_payload_source;
  wire       [21:0]   system_peripheral_plic_node_bus_a_payload_address;
  wire       [1:0]    system_peripheral_plic_node_bus_a_payload_size;
  wire       [3:0]    system_peripheral_plic_node_bus_a_payload_mask;
  wire       [31:0]   system_peripheral_plic_node_bus_a_payload_data;
  wire                system_peripheral_plic_node_bus_a_payload_corrupt;
  wire                system_peripheral_plic_node_bus_d_valid;
  wire                system_peripheral_plic_node_bus_d_ready;
  wire       [2:0]    system_peripheral_plic_node_bus_d_payload_opcode;
  wire       [2:0]    system_peripheral_plic_node_bus_d_payload_param;
  wire       [5:0]    system_peripheral_plic_node_bus_d_payload_source;
  wire       [1:0]    system_peripheral_plic_node_bus_d_payload_size;
  wire                system_peripheral_plic_node_bus_d_payload_denied;
  wire       [31:0]   system_peripheral_plic_node_bus_d_payload_data;
  wire                system_peripheral_plic_node_bus_d_payload_corrupt;
  wire                system_peripheral_bus32_to_system_peripheral_plic_node_down_bus_a_valid;
  wire                system_peripheral_bus32_to_system_peripheral_plic_node_down_bus_a_ready;
  wire       [2:0]    system_peripheral_bus32_to_system_peripheral_plic_node_down_bus_a_payload_opcode;
  wire       [2:0]    system_peripheral_bus32_to_system_peripheral_plic_node_down_bus_a_payload_param;
  wire       [5:0]    system_peripheral_bus32_to_system_peripheral_plic_node_down_bus_a_payload_source;
  wire       [21:0]   system_peripheral_bus32_to_system_peripheral_plic_node_down_bus_a_payload_address;
  wire       [1:0]    system_peripheral_bus32_to_system_peripheral_plic_node_down_bus_a_payload_size;
  wire       [3:0]    system_peripheral_bus32_to_system_peripheral_plic_node_down_bus_a_payload_mask;
  wire       [31:0]   system_peripheral_bus32_to_system_peripheral_plic_node_down_bus_a_payload_data;
  wire                system_peripheral_bus32_to_system_peripheral_plic_node_down_bus_a_payload_corrupt;
  wire                system_peripheral_bus32_to_system_peripheral_plic_node_down_bus_d_valid;
  wire                system_peripheral_bus32_to_system_peripheral_plic_node_down_bus_d_ready;
  wire       [2:0]    system_peripheral_bus32_to_system_peripheral_plic_node_down_bus_d_payload_opcode;
  wire       [2:0]    system_peripheral_bus32_to_system_peripheral_plic_node_down_bus_d_payload_param;
  wire       [5:0]    system_peripheral_bus32_to_system_peripheral_plic_node_down_bus_d_payload_source;
  wire       [1:0]    system_peripheral_bus32_to_system_peripheral_plic_node_down_bus_d_payload_size;
  wire                system_peripheral_bus32_to_system_peripheral_plic_node_down_bus_d_payload_denied;
  wire       [31:0]   system_peripheral_bus32_to_system_peripheral_plic_node_down_bus_d_payload_data;
  wire                system_peripheral_bus32_to_system_peripheral_plic_node_down_bus_d_payload_corrupt;
  wire                system_peripheral_uart_node_bus_a_valid;
  wire                system_peripheral_uart_node_bus_a_ready;
  wire       [2:0]    system_peripheral_uart_node_bus_a_payload_opcode;
  wire       [2:0]    system_peripheral_uart_node_bus_a_payload_param;
  wire       [5:0]    system_peripheral_uart_node_bus_a_payload_source;
  wire       [7:0]    system_peripheral_uart_node_bus_a_payload_address;
  wire       [1:0]    system_peripheral_uart_node_bus_a_payload_size;
  wire       [3:0]    system_peripheral_uart_node_bus_a_payload_mask;
  wire       [31:0]   system_peripheral_uart_node_bus_a_payload_data;
  wire                system_peripheral_uart_node_bus_a_payload_corrupt;
  wire                system_peripheral_uart_node_bus_d_valid;
  wire                system_peripheral_uart_node_bus_d_ready;
  wire       [2:0]    system_peripheral_uart_node_bus_d_payload_opcode;
  wire       [2:0]    system_peripheral_uart_node_bus_d_payload_param;
  wire       [5:0]    system_peripheral_uart_node_bus_d_payload_source;
  wire       [1:0]    system_peripheral_uart_node_bus_d_payload_size;
  wire                system_peripheral_uart_node_bus_d_payload_denied;
  wire       [31:0]   system_peripheral_uart_node_bus_d_payload_data;
  wire                system_peripheral_uart_node_bus_d_payload_corrupt;
  wire                system_peripheral_bus32_to_system_peripheral_uart_node_down_bus_a_valid;
  wire                system_peripheral_bus32_to_system_peripheral_uart_node_down_bus_a_ready;
  wire       [2:0]    system_peripheral_bus32_to_system_peripheral_uart_node_down_bus_a_payload_opcode;
  wire       [2:0]    system_peripheral_bus32_to_system_peripheral_uart_node_down_bus_a_payload_param;
  wire       [5:0]    system_peripheral_bus32_to_system_peripheral_uart_node_down_bus_a_payload_source;
  wire       [7:0]    system_peripheral_bus32_to_system_peripheral_uart_node_down_bus_a_payload_address;
  wire       [1:0]    system_peripheral_bus32_to_system_peripheral_uart_node_down_bus_a_payload_size;
  wire       [3:0]    system_peripheral_bus32_to_system_peripheral_uart_node_down_bus_a_payload_mask;
  wire       [31:0]   system_peripheral_bus32_to_system_peripheral_uart_node_down_bus_a_payload_data;
  wire                system_peripheral_bus32_to_system_peripheral_uart_node_down_bus_a_payload_corrupt;
  wire                system_peripheral_bus32_to_system_peripheral_uart_node_down_bus_d_valid;
  wire                system_peripheral_bus32_to_system_peripheral_uart_node_down_bus_d_ready;
  wire       [2:0]    system_peripheral_bus32_to_system_peripheral_uart_node_down_bus_d_payload_opcode;
  wire       [2:0]    system_peripheral_bus32_to_system_peripheral_uart_node_down_bus_d_payload_param;
  wire       [5:0]    system_peripheral_bus32_to_system_peripheral_uart_node_down_bus_d_payload_source;
  wire       [1:0]    system_peripheral_bus32_to_system_peripheral_uart_node_down_bus_d_payload_size;
  wire                system_peripheral_bus32_to_system_peripheral_uart_node_down_bus_d_payload_denied;
  wire       [31:0]   system_peripheral_bus32_to_system_peripheral_uart_node_down_bus_d_payload_data;
  wire                system_peripheral_bus32_to_system_peripheral_uart_node_down_bus_d_payload_corrupt;
  wire                system_peripheral_demo_node_bus_a_valid;
  wire                system_peripheral_demo_node_bus_a_ready;
  wire       [2:0]    system_peripheral_demo_node_bus_a_payload_opcode;
  wire       [2:0]    system_peripheral_demo_node_bus_a_payload_param;
  wire       [5:0]    system_peripheral_demo_node_bus_a_payload_source;
  wire       [11:0]   system_peripheral_demo_node_bus_a_payload_address;
  wire       [1:0]    system_peripheral_demo_node_bus_a_payload_size;
  wire       [3:0]    system_peripheral_demo_node_bus_a_payload_mask;
  wire       [31:0]   system_peripheral_demo_node_bus_a_payload_data;
  wire                system_peripheral_demo_node_bus_a_payload_corrupt;
  wire                system_peripheral_demo_node_bus_d_valid;
  wire                system_peripheral_demo_node_bus_d_ready;
  wire       [2:0]    system_peripheral_demo_node_bus_d_payload_opcode;
  wire       [2:0]    system_peripheral_demo_node_bus_d_payload_param;
  wire       [5:0]    system_peripheral_demo_node_bus_d_payload_source;
  wire       [1:0]    system_peripheral_demo_node_bus_d_payload_size;
  wire                system_peripheral_demo_node_bus_d_payload_denied;
  wire       [31:0]   system_peripheral_demo_node_bus_d_payload_data;
  wire                system_peripheral_demo_node_bus_d_payload_corrupt;
  wire                system_peripheral_bus32_to_system_peripheral_demo_node_down_bus_a_valid;
  wire                system_peripheral_bus32_to_system_peripheral_demo_node_down_bus_a_ready;
  wire       [2:0]    system_peripheral_bus32_to_system_peripheral_demo_node_down_bus_a_payload_opcode;
  wire       [2:0]    system_peripheral_bus32_to_system_peripheral_demo_node_down_bus_a_payload_param;
  wire       [5:0]    system_peripheral_bus32_to_system_peripheral_demo_node_down_bus_a_payload_source;
  wire       [11:0]   system_peripheral_bus32_to_system_peripheral_demo_node_down_bus_a_payload_address;
  wire       [1:0]    system_peripheral_bus32_to_system_peripheral_demo_node_down_bus_a_payload_size;
  wire       [3:0]    system_peripheral_bus32_to_system_peripheral_demo_node_down_bus_a_payload_mask;
  wire       [31:0]   system_peripheral_bus32_to_system_peripheral_demo_node_down_bus_a_payload_data;
  wire                system_peripheral_bus32_to_system_peripheral_demo_node_down_bus_a_payload_corrupt;
  wire                system_peripheral_bus32_to_system_peripheral_demo_node_down_bus_d_valid;
  wire                system_peripheral_bus32_to_system_peripheral_demo_node_down_bus_d_ready;
  wire       [2:0]    system_peripheral_bus32_to_system_peripheral_demo_node_down_bus_d_payload_opcode;
  wire       [2:0]    system_peripheral_bus32_to_system_peripheral_demo_node_down_bus_d_payload_param;
  wire       [5:0]    system_peripheral_bus32_to_system_peripheral_demo_node_down_bus_d_payload_source;
  wire       [1:0]    system_peripheral_bus32_to_system_peripheral_demo_node_down_bus_d_payload_size;
  wire                system_peripheral_bus32_to_system_peripheral_demo_node_down_bus_d_payload_denied;
  wire       [31:0]   system_peripheral_bus32_to_system_peripheral_demo_node_down_bus_d_payload_data;
  wire                system_peripheral_bus32_to_system_peripheral_demo_node_down_bus_d_payload_corrupt;
  wire                system_peripheral_busXlen_to_system_peripheral_bus32_up_bus_a_valid;
  wire                system_peripheral_busXlen_to_system_peripheral_bus32_up_bus_a_ready;
  wire       [2:0]    system_peripheral_busXlen_to_system_peripheral_bus32_up_bus_a_payload_opcode;
  wire       [2:0]    system_peripheral_busXlen_to_system_peripheral_bus32_up_bus_a_payload_param;
  wire       [5:0]    system_peripheral_busXlen_to_system_peripheral_bus32_up_bus_a_payload_source;
  wire       [28:0]   system_peripheral_busXlen_to_system_peripheral_bus32_up_bus_a_payload_address;
  wire       [1:0]    system_peripheral_busXlen_to_system_peripheral_bus32_up_bus_a_payload_size;
  wire       [3:0]    system_peripheral_busXlen_to_system_peripheral_bus32_up_bus_a_payload_mask;
  wire       [31:0]   system_peripheral_busXlen_to_system_peripheral_bus32_up_bus_a_payload_data;
  wire                system_peripheral_busXlen_to_system_peripheral_bus32_up_bus_a_payload_corrupt;
  wire                system_peripheral_busXlen_to_system_peripheral_bus32_up_bus_d_valid;
  wire                system_peripheral_busXlen_to_system_peripheral_bus32_up_bus_d_ready;
  wire       [2:0]    system_peripheral_busXlen_to_system_peripheral_bus32_up_bus_d_payload_opcode;
  wire       [2:0]    system_peripheral_busXlen_to_system_peripheral_bus32_up_bus_d_payload_param;
  wire       [5:0]    system_peripheral_busXlen_to_system_peripheral_bus32_up_bus_d_payload_source;
  wire       [1:0]    system_peripheral_busXlen_to_system_peripheral_bus32_up_bus_d_payload_size;
  wire                system_peripheral_busXlen_to_system_peripheral_bus32_up_bus_d_payload_denied;
  wire       [31:0]   system_peripheral_busXlen_to_system_peripheral_bus32_up_bus_d_payload_data;
  wire                system_peripheral_busXlen_to_system_peripheral_bus32_up_bus_d_payload_corrupt;
  wire                system_peripheral_busXlen_to_system_peripheral_clint_node_up_bus_a_valid;
  wire                system_peripheral_busXlen_to_system_peripheral_clint_node_up_bus_a_ready;
  wire       [2:0]    system_peripheral_busXlen_to_system_peripheral_clint_node_up_bus_a_payload_opcode;
  wire       [2:0]    system_peripheral_busXlen_to_system_peripheral_clint_node_up_bus_a_payload_param;
  wire       [5:0]    system_peripheral_busXlen_to_system_peripheral_clint_node_up_bus_a_payload_source;
  wire       [15:0]   system_peripheral_busXlen_to_system_peripheral_clint_node_up_bus_a_payload_address;
  wire       [2:0]    system_peripheral_busXlen_to_system_peripheral_clint_node_up_bus_a_payload_size;
  wire       [3:0]    system_peripheral_busXlen_to_system_peripheral_clint_node_up_bus_a_payload_mask;
  wire       [31:0]   system_peripheral_busXlen_to_system_peripheral_clint_node_up_bus_a_payload_data;
  wire                system_peripheral_busXlen_to_system_peripheral_clint_node_up_bus_a_payload_corrupt;
  wire                system_peripheral_busXlen_to_system_peripheral_clint_node_up_bus_d_valid;
  wire                system_peripheral_busXlen_to_system_peripheral_clint_node_up_bus_d_ready;
  wire       [2:0]    system_peripheral_busXlen_to_system_peripheral_clint_node_up_bus_d_payload_opcode;
  wire       [2:0]    system_peripheral_busXlen_to_system_peripheral_clint_node_up_bus_d_payload_param;
  wire       [5:0]    system_peripheral_busXlen_to_system_peripheral_clint_node_up_bus_d_payload_source;
  wire       [2:0]    system_peripheral_busXlen_to_system_peripheral_clint_node_up_bus_d_payload_size;
  wire                system_peripheral_busXlen_to_system_peripheral_clint_node_up_bus_d_payload_denied;
  wire       [31:0]   system_peripheral_busXlen_to_system_peripheral_clint_node_up_bus_d_payload_data;
  wire                system_peripheral_busXlen_to_system_peripheral_clint_node_up_bus_d_payload_corrupt;
  wire                system_mainBus_to_system_ram_up_up_bus_a_valid;
  wire                system_mainBus_to_system_ram_up_up_bus_a_ready;
  wire       [2:0]    system_mainBus_to_system_ram_up_up_bus_a_payload_opcode;
  wire       [2:0]    system_mainBus_to_system_ram_up_up_bus_a_payload_param;
  wire       [5:0]    system_mainBus_to_system_ram_up_up_bus_a_payload_source;
  wire       [15:0]   system_mainBus_to_system_ram_up_up_bus_a_payload_address;
  wire       [2:0]    system_mainBus_to_system_ram_up_up_bus_a_payload_size;
  wire       [7:0]    system_mainBus_to_system_ram_up_up_bus_a_payload_mask;
  wire       [63:0]   system_mainBus_to_system_ram_up_up_bus_a_payload_data;
  wire                system_mainBus_to_system_ram_up_up_bus_a_payload_corrupt;
  wire                system_mainBus_to_system_ram_up_up_bus_d_valid;
  wire                system_mainBus_to_system_ram_up_up_bus_d_ready;
  wire       [2:0]    system_mainBus_to_system_ram_up_up_bus_d_payload_opcode;
  wire       [2:0]    system_mainBus_to_system_ram_up_up_bus_d_payload_param;
  wire       [5:0]    system_mainBus_to_system_ram_up_up_bus_d_payload_source;
  wire       [2:0]    system_mainBus_to_system_ram_up_up_bus_d_payload_size;
  wire                system_mainBus_to_system_ram_up_up_bus_d_payload_denied;
  wire       [63:0]   system_mainBus_to_system_ram_up_up_bus_d_payload_data;
  wire                system_mainBus_to_system_ram_up_up_bus_d_payload_corrupt;
  wire                system_mainBus_to_system_peripheral_busXlen_up_bus_a_valid;
  wire                system_mainBus_to_system_peripheral_busXlen_up_bus_a_ready;
  wire       [2:0]    system_mainBus_to_system_peripheral_busXlen_up_bus_a_payload_opcode;
  wire       [2:0]    system_mainBus_to_system_peripheral_busXlen_up_bus_a_payload_param;
  wire       [5:0]    system_mainBus_to_system_peripheral_busXlen_up_bus_a_payload_source;
  wire       [28:0]   system_mainBus_to_system_peripheral_busXlen_up_bus_a_payload_address;
  wire       [2:0]    system_mainBus_to_system_peripheral_busXlen_up_bus_a_payload_size;
  wire       [7:0]    system_mainBus_to_system_peripheral_busXlen_up_bus_a_payload_mask;
  wire       [63:0]   system_mainBus_to_system_peripheral_busXlen_up_bus_a_payload_data;
  wire                system_mainBus_to_system_peripheral_busXlen_up_bus_a_payload_corrupt;
  wire                system_mainBus_to_system_peripheral_busXlen_up_bus_d_valid;
  wire                system_mainBus_to_system_peripheral_busXlen_up_bus_d_ready;
  wire       [2:0]    system_mainBus_to_system_peripheral_busXlen_up_bus_d_payload_opcode;
  wire       [2:0]    system_mainBus_to_system_peripheral_busXlen_up_bus_d_payload_param;
  wire       [5:0]    system_mainBus_to_system_peripheral_busXlen_up_bus_d_payload_source;
  wire       [2:0]    system_mainBus_to_system_peripheral_busXlen_up_bus_d_payload_size;
  wire                system_mainBus_to_system_peripheral_busXlen_up_bus_d_payload_denied;
  wire       [63:0]   system_mainBus_to_system_peripheral_busXlen_up_bus_d_payload_data;
  wire                system_mainBus_to_system_peripheral_busXlen_up_bus_d_payload_corrupt;
  wire                system_peripheral_bus32_to_system_peripheral_plic_node_up_bus_a_valid;
  wire                system_peripheral_bus32_to_system_peripheral_plic_node_up_bus_a_ready;
  wire       [2:0]    system_peripheral_bus32_to_system_peripheral_plic_node_up_bus_a_payload_opcode;
  wire       [2:0]    system_peripheral_bus32_to_system_peripheral_plic_node_up_bus_a_payload_param;
  wire       [5:0]    system_peripheral_bus32_to_system_peripheral_plic_node_up_bus_a_payload_source;
  wire       [21:0]   system_peripheral_bus32_to_system_peripheral_plic_node_up_bus_a_payload_address;
  wire       [1:0]    system_peripheral_bus32_to_system_peripheral_plic_node_up_bus_a_payload_size;
  wire       [3:0]    system_peripheral_bus32_to_system_peripheral_plic_node_up_bus_a_payload_mask;
  wire       [31:0]   system_peripheral_bus32_to_system_peripheral_plic_node_up_bus_a_payload_data;
  wire                system_peripheral_bus32_to_system_peripheral_plic_node_up_bus_a_payload_corrupt;
  wire                system_peripheral_bus32_to_system_peripheral_plic_node_up_bus_d_valid;
  wire                system_peripheral_bus32_to_system_peripheral_plic_node_up_bus_d_ready;
  wire       [2:0]    system_peripheral_bus32_to_system_peripheral_plic_node_up_bus_d_payload_opcode;
  wire       [2:0]    system_peripheral_bus32_to_system_peripheral_plic_node_up_bus_d_payload_param;
  wire       [5:0]    system_peripheral_bus32_to_system_peripheral_plic_node_up_bus_d_payload_source;
  wire       [1:0]    system_peripheral_bus32_to_system_peripheral_plic_node_up_bus_d_payload_size;
  wire                system_peripheral_bus32_to_system_peripheral_plic_node_up_bus_d_payload_denied;
  wire       [31:0]   system_peripheral_bus32_to_system_peripheral_plic_node_up_bus_d_payload_data;
  wire                system_peripheral_bus32_to_system_peripheral_plic_node_up_bus_d_payload_corrupt;
  wire                system_peripheral_bus32_to_system_peripheral_uart_node_up_bus_a_valid;
  wire                system_peripheral_bus32_to_system_peripheral_uart_node_up_bus_a_ready;
  wire       [2:0]    system_peripheral_bus32_to_system_peripheral_uart_node_up_bus_a_payload_opcode;
  wire       [2:0]    system_peripheral_bus32_to_system_peripheral_uart_node_up_bus_a_payload_param;
  wire       [5:0]    system_peripheral_bus32_to_system_peripheral_uart_node_up_bus_a_payload_source;
  wire       [7:0]    system_peripheral_bus32_to_system_peripheral_uart_node_up_bus_a_payload_address;
  wire       [1:0]    system_peripheral_bus32_to_system_peripheral_uart_node_up_bus_a_payload_size;
  wire       [3:0]    system_peripheral_bus32_to_system_peripheral_uart_node_up_bus_a_payload_mask;
  wire       [31:0]   system_peripheral_bus32_to_system_peripheral_uart_node_up_bus_a_payload_data;
  wire                system_peripheral_bus32_to_system_peripheral_uart_node_up_bus_a_payload_corrupt;
  wire                system_peripheral_bus32_to_system_peripheral_uart_node_up_bus_d_valid;
  wire                system_peripheral_bus32_to_system_peripheral_uart_node_up_bus_d_ready;
  wire       [2:0]    system_peripheral_bus32_to_system_peripheral_uart_node_up_bus_d_payload_opcode;
  wire       [2:0]    system_peripheral_bus32_to_system_peripheral_uart_node_up_bus_d_payload_param;
  wire       [5:0]    system_peripheral_bus32_to_system_peripheral_uart_node_up_bus_d_payload_source;
  wire       [1:0]    system_peripheral_bus32_to_system_peripheral_uart_node_up_bus_d_payload_size;
  wire                system_peripheral_bus32_to_system_peripheral_uart_node_up_bus_d_payload_denied;
  wire       [31:0]   system_peripheral_bus32_to_system_peripheral_uart_node_up_bus_d_payload_data;
  wire                system_peripheral_bus32_to_system_peripheral_uart_node_up_bus_d_payload_corrupt;
  wire                system_peripheral_bus32_to_system_peripheral_demo_node_up_bus_a_valid;
  wire                system_peripheral_bus32_to_system_peripheral_demo_node_up_bus_a_ready;
  wire       [2:0]    system_peripheral_bus32_to_system_peripheral_demo_node_up_bus_a_payload_opcode;
  wire       [2:0]    system_peripheral_bus32_to_system_peripheral_demo_node_up_bus_a_payload_param;
  wire       [5:0]    system_peripheral_bus32_to_system_peripheral_demo_node_up_bus_a_payload_source;
  wire       [11:0]   system_peripheral_bus32_to_system_peripheral_demo_node_up_bus_a_payload_address;
  wire       [1:0]    system_peripheral_bus32_to_system_peripheral_demo_node_up_bus_a_payload_size;
  wire       [3:0]    system_peripheral_bus32_to_system_peripheral_demo_node_up_bus_a_payload_mask;
  wire       [31:0]   system_peripheral_bus32_to_system_peripheral_demo_node_up_bus_a_payload_data;
  wire                system_peripheral_bus32_to_system_peripheral_demo_node_up_bus_a_payload_corrupt;
  wire                system_peripheral_bus32_to_system_peripheral_demo_node_up_bus_d_valid;
  wire                system_peripheral_bus32_to_system_peripheral_demo_node_up_bus_d_ready;
  wire       [2:0]    system_peripheral_bus32_to_system_peripheral_demo_node_up_bus_d_payload_opcode;
  wire       [2:0]    system_peripheral_bus32_to_system_peripheral_demo_node_up_bus_d_payload_param;
  wire       [5:0]    system_peripheral_bus32_to_system_peripheral_demo_node_up_bus_d_payload_source;
  wire       [1:0]    system_peripheral_bus32_to_system_peripheral_demo_node_up_bus_d_payload_size;
  wire                system_peripheral_bus32_to_system_peripheral_demo_node_up_bus_d_payload_denied;
  wire       [31:0]   system_peripheral_bus32_to_system_peripheral_demo_node_up_bus_d_payload_data;
  wire                system_peripheral_bus32_to_system_peripheral_demo_node_up_bus_d_payload_corrupt;
  `ifndef SYNTHESIS
  reg [127:0] system_cpu_iBus_bus_a_payload_opcode_string;
  reg [119:0] system_cpu_iBus_bus_d_payload_opcode_string;
  reg [127:0] system_cpu_iBus_noDecoder_toDown_a_payload_opcode_string;
  reg [119:0] system_cpu_iBus_noDecoder_toDown_d_payload_opcode_string;
  reg [127:0] system_cpu_dBus_bus_a_payload_opcode_string;
  reg [119:0] system_cpu_dBus_bus_d_payload_opcode_string;
  reg [127:0] system_cpu_dBus_noDecoder_toDown_a_payload_opcode_string;
  reg [119:0] system_cpu_dBus_noDecoder_toDown_d_payload_opcode_string;
  reg [127:0] system_cpu_dBus_bus_a_s2mPipe_payload_opcode_string;
  reg [127:0] system_cpu_dBus_bus_a_rData_opcode_string;
  reg [127:0] _zz_system_cpu_dBus_bus_a_s2mPipe_payload_opcode_string;
  reg [119:0] system_cpu_dBus_noDecoder_toDown_d_combStage_payload_opcode_string;
  reg [127:0] system_cpu_lsuL1Bus_bus_a_payload_opcode_string;
  reg [119:0] system_cpu_lsuL1Bus_bus_d_payload_opcode_string;
  reg [127:0] system_cpu_lsuL1Bus_noDecoder_toDown_a_payload_opcode_string;
  reg [119:0] system_cpu_lsuL1Bus_noDecoder_toDown_d_payload_opcode_string;
  reg [127:0] system_mainBus_bus_a_payload_opcode_string;
  reg [119:0] system_mainBus_bus_d_payload_opcode_string;
  reg [127:0] system_cpu_iBus_to_system_mainBus_down_bus_a_payload_opcode_string;
  reg [119:0] system_cpu_iBus_to_system_mainBus_down_bus_d_payload_opcode_string;
  reg [127:0] system_cpu_dBus_to_system_mainBus_down_bus_a_payload_opcode_string;
  reg [119:0] system_cpu_dBus_to_system_mainBus_down_bus_d_payload_opcode_string;
  reg [127:0] system_cpu_lsuL1Bus_to_system_mainBus_down_bus_a_payload_opcode_string;
  reg [119:0] system_cpu_lsuL1Bus_to_system_mainBus_down_bus_d_payload_opcode_string;
  reg [127:0] system_ram_up_bus_a_payload_opcode_string;
  reg [119:0] system_ram_up_bus_d_payload_opcode_string;
  reg [127:0] system_mainBus_to_system_ram_up_down_bus_a_payload_opcode_string;
  reg [119:0] system_mainBus_to_system_ram_up_down_bus_d_payload_opcode_string;
  reg [127:0] system_peripheral_busXlen_bus_a_payload_opcode_string;
  reg [119:0] system_peripheral_busXlen_bus_d_payload_opcode_string;
  reg [127:0] system_mainBus_to_system_peripheral_busXlen_down_bus_a_payload_opcode_string;
  reg [119:0] system_mainBus_to_system_peripheral_busXlen_down_bus_d_payload_opcode_string;
  reg [127:0] system_mainBus_to_system_peripheral_busXlen_down_bus_a_halfPipe_payload_opcode_string;
  reg [127:0] system_mainBus_to_system_peripheral_busXlen_down_bus_a_rData_opcode_string;
  reg [119:0] system_peripheral_busXlen_bus_d_halfPipe_payload_opcode_string;
  reg [119:0] system_peripheral_busXlen_bus_d_rData_opcode_string;
  reg [127:0] system_cpu_iBus_to_system_mainBus_up_bus_a_payload_opcode_string;
  reg [119:0] system_cpu_iBus_to_system_mainBus_up_bus_d_payload_opcode_string;
  reg [127:0] system_cpu_dBus_to_system_mainBus_up_bus_a_payload_opcode_string;
  reg [119:0] system_cpu_dBus_to_system_mainBus_up_bus_d_payload_opcode_string;
  reg [127:0] system_cpu_lsuL1Bus_to_system_mainBus_up_bus_a_payload_opcode_string;
  reg [119:0] system_cpu_lsuL1Bus_to_system_mainBus_up_bus_d_payload_opcode_string;
  reg [127:0] system_peripheral_bus32_bus_a_payload_opcode_string;
  reg [119:0] system_peripheral_bus32_bus_d_payload_opcode_string;
  reg [127:0] system_peripheral_busXlen_to_system_peripheral_bus32_down_bus_a_payload_opcode_string;
  reg [119:0] system_peripheral_busXlen_to_system_peripheral_bus32_down_bus_d_payload_opcode_string;
  reg [127:0] system_peripheral_clint_node_bus_a_payload_opcode_string;
  reg [119:0] system_peripheral_clint_node_bus_d_payload_opcode_string;
  reg [127:0] system_peripheral_busXlen_to_system_peripheral_clint_node_down_bus_a_payload_opcode_string;
  reg [119:0] system_peripheral_busXlen_to_system_peripheral_clint_node_down_bus_d_payload_opcode_string;
  reg [127:0] system_peripheral_plic_node_bus_a_payload_opcode_string;
  reg [119:0] system_peripheral_plic_node_bus_d_payload_opcode_string;
  reg [127:0] system_peripheral_bus32_to_system_peripheral_plic_node_down_bus_a_payload_opcode_string;
  reg [119:0] system_peripheral_bus32_to_system_peripheral_plic_node_down_bus_d_payload_opcode_string;
  reg [127:0] system_peripheral_uart_node_bus_a_payload_opcode_string;
  reg [119:0] system_peripheral_uart_node_bus_d_payload_opcode_string;
  reg [127:0] system_peripheral_bus32_to_system_peripheral_uart_node_down_bus_a_payload_opcode_string;
  reg [119:0] system_peripheral_bus32_to_system_peripheral_uart_node_down_bus_d_payload_opcode_string;
  reg [127:0] system_peripheral_demo_node_bus_a_payload_opcode_string;
  reg [119:0] system_peripheral_demo_node_bus_d_payload_opcode_string;
  reg [127:0] system_peripheral_bus32_to_system_peripheral_demo_node_down_bus_a_payload_opcode_string;
  reg [119:0] system_peripheral_bus32_to_system_peripheral_demo_node_down_bus_d_payload_opcode_string;
  reg [127:0] system_peripheral_busXlen_to_system_peripheral_bus32_up_bus_a_payload_opcode_string;
  reg [119:0] system_peripheral_busXlen_to_system_peripheral_bus32_up_bus_d_payload_opcode_string;
  reg [127:0] system_peripheral_busXlen_to_system_peripheral_clint_node_up_bus_a_payload_opcode_string;
  reg [119:0] system_peripheral_busXlen_to_system_peripheral_clint_node_up_bus_d_payload_opcode_string;
  reg [127:0] system_mainBus_to_system_ram_up_up_bus_a_payload_opcode_string;
  reg [119:0] system_mainBus_to_system_ram_up_up_bus_d_payload_opcode_string;
  reg [127:0] system_mainBus_to_system_peripheral_busXlen_up_bus_a_payload_opcode_string;
  reg [119:0] system_mainBus_to_system_peripheral_busXlen_up_bus_d_payload_opcode_string;
  reg [127:0] system_peripheral_bus32_to_system_peripheral_plic_node_up_bus_a_payload_opcode_string;
  reg [119:0] system_peripheral_bus32_to_system_peripheral_plic_node_up_bus_d_payload_opcode_string;
  reg [127:0] system_peripheral_bus32_to_system_peripheral_uart_node_up_bus_a_payload_opcode_string;
  reg [119:0] system_peripheral_bus32_to_system_peripheral_uart_node_up_bus_d_payload_opcode_string;
  reg [127:0] system_peripheral_bus32_to_system_peripheral_demo_node_up_bus_a_payload_opcode_string;
  reg [119:0] system_peripheral_bus32_to_system_peripheral_demo_node_up_bus_d_payload_opcode_string;
  `endif


  pango_replica_core system_cpu_logic_core (
    .PrivilegedPlugin_logic_rdtime                         (system_cpu_priv_rdtime[63:0]                                                     ), //i
    .PrivilegedPlugin_logic_harts_0_int_m_timer            (system_cpu_priv_mti_flag                                                         ), //i
    .PrivilegedPlugin_logic_harts_0_int_m_software         (system_cpu_priv_msi_flag                                                         ), //i
    .PrivilegedPlugin_logic_harts_0_int_m_external         (system_cpu_priv_mei_flag                                                         ), //i
    .FetchL1TileLinkPlugin_logic_down_a_valid              (system_cpu_logic_core_FetchL1TileLinkPlugin_logic_down_a_valid                   ), //o
    .FetchL1TileLinkPlugin_logic_down_a_ready              (system_cpu_iBus_bus_a_ready                                                      ), //i
    .FetchL1TileLinkPlugin_logic_down_a_payload_opcode     (system_cpu_logic_core_FetchL1TileLinkPlugin_logic_down_a_payload_opcode[2:0]     ), //o
    .FetchL1TileLinkPlugin_logic_down_a_payload_param      (system_cpu_logic_core_FetchL1TileLinkPlugin_logic_down_a_payload_param[2:0]      ), //o
    .FetchL1TileLinkPlugin_logic_down_a_payload_source     (system_cpu_logic_core_FetchL1TileLinkPlugin_logic_down_a_payload_source[2:0]     ), //o
    .FetchL1TileLinkPlugin_logic_down_a_payload_address    (system_cpu_logic_core_FetchL1TileLinkPlugin_logic_down_a_payload_address[31:0]   ), //o
    .FetchL1TileLinkPlugin_logic_down_a_payload_size       (system_cpu_logic_core_FetchL1TileLinkPlugin_logic_down_a_payload_size[2:0]       ), //o
    .FetchL1TileLinkPlugin_logic_down_d_valid              (system_cpu_iBus_bus_d_valid                                                      ), //i
    .FetchL1TileLinkPlugin_logic_down_d_ready              (system_cpu_logic_core_FetchL1TileLinkPlugin_logic_down_d_ready                   ), //o
    .FetchL1TileLinkPlugin_logic_down_d_payload_opcode     (system_cpu_iBus_bus_d_payload_opcode[2:0]                                        ), //i
    .FetchL1TileLinkPlugin_logic_down_d_payload_param      (system_cpu_iBus_bus_d_payload_param[2:0]                                         ), //i
    .FetchL1TileLinkPlugin_logic_down_d_payload_source     (system_cpu_iBus_bus_d_payload_source[2:0]                                        ), //i
    .FetchL1TileLinkPlugin_logic_down_d_payload_size       (system_cpu_iBus_bus_d_payload_size[2:0]                                          ), //i
    .FetchL1TileLinkPlugin_logic_down_d_payload_denied     (system_cpu_iBus_bus_d_payload_denied                                             ), //i
    .FetchL1TileLinkPlugin_logic_down_d_payload_data       (system_cpu_iBus_bus_d_payload_data[63:0]                                         ), //i
    .FetchL1TileLinkPlugin_logic_down_d_payload_corrupt    (system_cpu_iBus_bus_d_payload_corrupt                                            ), //i
    .LsuL1TileLinkPlugin_logic_down_a_valid                (system_cpu_logic_core_LsuL1TileLinkPlugin_logic_down_a_valid                     ), //o
    .LsuL1TileLinkPlugin_logic_down_a_ready                (system_cpu_lsuL1Bus_bus_a_ready                                                  ), //i
    .LsuL1TileLinkPlugin_logic_down_a_payload_opcode       (system_cpu_logic_core_LsuL1TileLinkPlugin_logic_down_a_payload_opcode[2:0]       ), //o
    .LsuL1TileLinkPlugin_logic_down_a_payload_param        (system_cpu_logic_core_LsuL1TileLinkPlugin_logic_down_a_payload_param[2:0]        ), //o
    .LsuL1TileLinkPlugin_logic_down_a_payload_source       (system_cpu_logic_core_LsuL1TileLinkPlugin_logic_down_a_payload_source[3:0]       ), //o
    .LsuL1TileLinkPlugin_logic_down_a_payload_address      (system_cpu_logic_core_LsuL1TileLinkPlugin_logic_down_a_payload_address[31:0]     ), //o
    .LsuL1TileLinkPlugin_logic_down_a_payload_size         (system_cpu_logic_core_LsuL1TileLinkPlugin_logic_down_a_payload_size[2:0]         ), //o
    .LsuL1TileLinkPlugin_logic_down_a_payload_mask         (system_cpu_logic_core_LsuL1TileLinkPlugin_logic_down_a_payload_mask[7:0]         ), //o
    .LsuL1TileLinkPlugin_logic_down_a_payload_data         (system_cpu_logic_core_LsuL1TileLinkPlugin_logic_down_a_payload_data[63:0]        ), //o
    .LsuL1TileLinkPlugin_logic_down_a_payload_corrupt      (system_cpu_logic_core_LsuL1TileLinkPlugin_logic_down_a_payload_corrupt           ), //o
    .LsuL1TileLinkPlugin_logic_down_d_valid                (system_cpu_lsuL1Bus_bus_d_valid                                                  ), //i
    .LsuL1TileLinkPlugin_logic_down_d_ready                (system_cpu_logic_core_LsuL1TileLinkPlugin_logic_down_d_ready                     ), //o
    .LsuL1TileLinkPlugin_logic_down_d_payload_opcode       (system_cpu_lsuL1Bus_bus_d_payload_opcode[2:0]                                    ), //i
    .LsuL1TileLinkPlugin_logic_down_d_payload_param        (system_cpu_lsuL1Bus_bus_d_payload_param[2:0]                                     ), //i
    .LsuL1TileLinkPlugin_logic_down_d_payload_source       (system_cpu_lsuL1Bus_bus_d_payload_source[3:0]                                    ), //i
    .LsuL1TileLinkPlugin_logic_down_d_payload_size         (system_cpu_lsuL1Bus_bus_d_payload_size[2:0]                                      ), //i
    .LsuL1TileLinkPlugin_logic_down_d_payload_denied       (system_cpu_lsuL1Bus_bus_d_payload_denied                                         ), //i
    .LsuL1TileLinkPlugin_logic_down_d_payload_data         (system_cpu_lsuL1Bus_bus_d_payload_data[63:0]                                     ), //i
    .LsuL1TileLinkPlugin_logic_down_d_payload_corrupt      (system_cpu_lsuL1Bus_bus_d_payload_corrupt                                        ), //i
    .LsuTileLinkPlugin_logic_bridge_down_a_valid           (system_cpu_logic_core_LsuTileLinkPlugin_logic_bridge_down_a_valid                ), //o
    .LsuTileLinkPlugin_logic_bridge_down_a_ready           (system_cpu_dBus_bus_a_ready                                                      ), //i
    .LsuTileLinkPlugin_logic_bridge_down_a_payload_opcode  (system_cpu_logic_core_LsuTileLinkPlugin_logic_bridge_down_a_payload_opcode[2:0]  ), //o
    .LsuTileLinkPlugin_logic_bridge_down_a_payload_param   (system_cpu_logic_core_LsuTileLinkPlugin_logic_bridge_down_a_payload_param[2:0]   ), //o
    .LsuTileLinkPlugin_logic_bridge_down_a_payload_address (system_cpu_logic_core_LsuTileLinkPlugin_logic_bridge_down_a_payload_address[31:0]), //o
    .LsuTileLinkPlugin_logic_bridge_down_a_payload_size    (system_cpu_logic_core_LsuTileLinkPlugin_logic_bridge_down_a_payload_size[1:0]    ), //o
    .LsuTileLinkPlugin_logic_bridge_down_a_payload_mask    (system_cpu_logic_core_LsuTileLinkPlugin_logic_bridge_down_a_payload_mask[3:0]    ), //o
    .LsuTileLinkPlugin_logic_bridge_down_a_payload_data    (system_cpu_logic_core_LsuTileLinkPlugin_logic_bridge_down_a_payload_data[31:0]   ), //o
    .LsuTileLinkPlugin_logic_bridge_down_a_payload_corrupt (system_cpu_logic_core_LsuTileLinkPlugin_logic_bridge_down_a_payload_corrupt      ), //o
    .LsuTileLinkPlugin_logic_bridge_down_d_valid           (system_cpu_dBus_bus_d_valid                                                      ), //i
    .LsuTileLinkPlugin_logic_bridge_down_d_ready           (system_cpu_logic_core_LsuTileLinkPlugin_logic_bridge_down_d_ready                ), //o
    .LsuTileLinkPlugin_logic_bridge_down_d_payload_opcode  (system_cpu_dBus_bus_d_payload_opcode[2:0]                                        ), //i
    .LsuTileLinkPlugin_logic_bridge_down_d_payload_param   (system_cpu_dBus_bus_d_payload_param[2:0]                                         ), //i
    .LsuTileLinkPlugin_logic_bridge_down_d_payload_size    (system_cpu_dBus_bus_d_payload_size[1:0]                                          ), //i
    .LsuTileLinkPlugin_logic_bridge_down_d_payload_denied  (system_cpu_dBus_bus_d_payload_denied                                             ), //i
    .LsuTileLinkPlugin_logic_bridge_down_d_payload_data    (system_cpu_dBus_bus_d_payload_data[31:0]                                         ), //i
    .LsuTileLinkPlugin_logic_bridge_down_d_payload_corrupt (system_cpu_dBus_bus_d_payload_corrupt                                            ), //i
    .socCtrl_systemClk                                     (socCtrl_systemClk                                                                ), //i
    .socCtrl_system_reset                                  (socCtrl_system_reset                                                             )  //i
  );
  (* keep_hierarchy = "TRUE" *) BufferCC_2 socCtrl_debug_fiber_aggregator_asyncBuffers_0 (
    .io_dataIn          (1'b0                                                    ), //i
    .io_dataOut         (socCtrl_debug_fiber_aggregator_asyncBuffers_0_io_dataOut), //o
    .socCtrl_systemClk  (socCtrl_systemClk                                       ), //i
    .socCtrl_asyncReset (socCtrl_asyncReset                                      )  //i
  );
  (* keep_hierarchy = "TRUE" *) BufferCC_3 socCtrl_debug_fiber_buffer (
    .io_dataIn                        (1'b0                                 ), //i
    .io_dataOut                       (socCtrl_debug_fiber_buffer_io_dataOut), //o
    .socCtrl_systemClk                (socCtrl_systemClk                    ), //i
    .socCtrl_debug_fiber_holder_reset (socCtrl_debug_fiber_holder_reset     )  //i
  );
  (* keep_hierarchy = "TRUE" *) BufferCC_4 socCtrl_system_fiber_aggregator_asyncBuffers_0 (
    .io_dataIn           (1'b0                                                     ), //i
    .io_dataOut          (socCtrl_system_fiber_aggregator_asyncBuffers_0_io_dataOut), //o
    .socCtrl_systemClk   (socCtrl_systemClk                                        ), //i
    .socCtrl_debug_reset (socCtrl_debug_reset                                      )  //i
  );
  (* keep_hierarchy = "TRUE" *) BufferCC_5 socCtrl_system_fiber_buffer (
    .io_dataIn                         (1'b0                                  ), //i
    .io_dataOut                        (socCtrl_system_fiber_buffer_io_dataOut), //o
    .socCtrl_systemClk                 (socCtrl_systemClk                     ), //i
    .socCtrl_system_fiber_holder_reset (socCtrl_system_fiber_holder_reset     )  //i
  );
  Arbiter system_mainBus_arbiter_core (
    .io_ups_0_a_valid           (system_cpu_iBus_to_system_mainBus_down_bus_a_valid                    ), //i
    .io_ups_0_a_ready           (system_mainBus_arbiter_core_io_ups_0_a_ready                          ), //o
    .io_ups_0_a_payload_opcode  (system_cpu_iBus_to_system_mainBus_down_bus_a_payload_opcode[2:0]      ), //i
    .io_ups_0_a_payload_param   (system_cpu_iBus_to_system_mainBus_down_bus_a_payload_param[2:0]       ), //i
    .io_ups_0_a_payload_source  (system_cpu_iBus_to_system_mainBus_down_bus_a_payload_source[2:0]      ), //i
    .io_ups_0_a_payload_address (system_cpu_iBus_to_system_mainBus_down_bus_a_payload_address[31:0]    ), //i
    .io_ups_0_a_payload_size    (system_cpu_iBus_to_system_mainBus_down_bus_a_payload_size[2:0]        ), //i
    .io_ups_0_d_valid           (system_mainBus_arbiter_core_io_ups_0_d_valid                          ), //o
    .io_ups_0_d_ready           (system_cpu_iBus_to_system_mainBus_down_bus_d_ready                    ), //i
    .io_ups_0_d_payload_opcode  (system_mainBus_arbiter_core_io_ups_0_d_payload_opcode[2:0]            ), //o
    .io_ups_0_d_payload_param   (system_mainBus_arbiter_core_io_ups_0_d_payload_param[2:0]             ), //o
    .io_ups_0_d_payload_source  (system_mainBus_arbiter_core_io_ups_0_d_payload_source[2:0]            ), //o
    .io_ups_0_d_payload_size    (system_mainBus_arbiter_core_io_ups_0_d_payload_size[2:0]              ), //o
    .io_ups_0_d_payload_denied  (system_mainBus_arbiter_core_io_ups_0_d_payload_denied                 ), //o
    .io_ups_0_d_payload_data    (system_mainBus_arbiter_core_io_ups_0_d_payload_data[63:0]             ), //o
    .io_ups_0_d_payload_corrupt (system_mainBus_arbiter_core_io_ups_0_d_payload_corrupt                ), //o
    .io_ups_1_a_valid           (system_cpu_dBus_to_system_mainBus_down_bus_a_valid                    ), //i
    .io_ups_1_a_ready           (system_mainBus_arbiter_core_io_ups_1_a_ready                          ), //o
    .io_ups_1_a_payload_opcode  (system_cpu_dBus_to_system_mainBus_down_bus_a_payload_opcode[2:0]      ), //i
    .io_ups_1_a_payload_param   (system_cpu_dBus_to_system_mainBus_down_bus_a_payload_param[2:0]       ), //i
    .io_ups_1_a_payload_address (system_cpu_dBus_to_system_mainBus_down_bus_a_payload_address[31:0]    ), //i
    .io_ups_1_a_payload_size    (system_cpu_dBus_to_system_mainBus_down_bus_a_payload_size[1:0]        ), //i
    .io_ups_1_a_payload_mask    (system_cpu_dBus_to_system_mainBus_down_bus_a_payload_mask[7:0]        ), //i
    .io_ups_1_a_payload_data    (system_cpu_dBus_to_system_mainBus_down_bus_a_payload_data[63:0]       ), //i
    .io_ups_1_a_payload_corrupt (system_cpu_dBus_to_system_mainBus_down_bus_a_payload_corrupt          ), //i
    .io_ups_1_d_valid           (system_mainBus_arbiter_core_io_ups_1_d_valid                          ), //o
    .io_ups_1_d_ready           (system_cpu_dBus_to_system_mainBus_down_bus_d_ready                    ), //i
    .io_ups_1_d_payload_opcode  (system_mainBus_arbiter_core_io_ups_1_d_payload_opcode[2:0]            ), //o
    .io_ups_1_d_payload_param   (system_mainBus_arbiter_core_io_ups_1_d_payload_param[2:0]             ), //o
    .io_ups_1_d_payload_size    (system_mainBus_arbiter_core_io_ups_1_d_payload_size[1:0]              ), //o
    .io_ups_1_d_payload_denied  (system_mainBus_arbiter_core_io_ups_1_d_payload_denied                 ), //o
    .io_ups_1_d_payload_data    (system_mainBus_arbiter_core_io_ups_1_d_payload_data[63:0]             ), //o
    .io_ups_1_d_payload_corrupt (system_mainBus_arbiter_core_io_ups_1_d_payload_corrupt                ), //o
    .io_ups_2_a_valid           (system_cpu_lsuL1Bus_to_system_mainBus_down_bus_a_valid                ), //i
    .io_ups_2_a_ready           (system_mainBus_arbiter_core_io_ups_2_a_ready                          ), //o
    .io_ups_2_a_payload_opcode  (system_cpu_lsuL1Bus_to_system_mainBus_down_bus_a_payload_opcode[2:0]  ), //i
    .io_ups_2_a_payload_param   (system_cpu_lsuL1Bus_to_system_mainBus_down_bus_a_payload_param[2:0]   ), //i
    .io_ups_2_a_payload_source  (system_cpu_lsuL1Bus_to_system_mainBus_down_bus_a_payload_source[3:0]  ), //i
    .io_ups_2_a_payload_address (system_cpu_lsuL1Bus_to_system_mainBus_down_bus_a_payload_address[31:0]), //i
    .io_ups_2_a_payload_size    (system_cpu_lsuL1Bus_to_system_mainBus_down_bus_a_payload_size[2:0]    ), //i
    .io_ups_2_a_payload_mask    (system_cpu_lsuL1Bus_to_system_mainBus_down_bus_a_payload_mask[7:0]    ), //i
    .io_ups_2_a_payload_data    (system_cpu_lsuL1Bus_to_system_mainBus_down_bus_a_payload_data[63:0]   ), //i
    .io_ups_2_a_payload_corrupt (system_cpu_lsuL1Bus_to_system_mainBus_down_bus_a_payload_corrupt      ), //i
    .io_ups_2_d_valid           (system_mainBus_arbiter_core_io_ups_2_d_valid                          ), //o
    .io_ups_2_d_ready           (system_cpu_lsuL1Bus_to_system_mainBus_down_bus_d_ready                ), //i
    .io_ups_2_d_payload_opcode  (system_mainBus_arbiter_core_io_ups_2_d_payload_opcode[2:0]            ), //o
    .io_ups_2_d_payload_param   (system_mainBus_arbiter_core_io_ups_2_d_payload_param[2:0]             ), //o
    .io_ups_2_d_payload_source  (system_mainBus_arbiter_core_io_ups_2_d_payload_source[3:0]            ), //o
    .io_ups_2_d_payload_size    (system_mainBus_arbiter_core_io_ups_2_d_payload_size[2:0]              ), //o
    .io_ups_2_d_payload_denied  (system_mainBus_arbiter_core_io_ups_2_d_payload_denied                 ), //o
    .io_ups_2_d_payload_data    (system_mainBus_arbiter_core_io_ups_2_d_payload_data[63:0]             ), //o
    .io_ups_2_d_payload_corrupt (system_mainBus_arbiter_core_io_ups_2_d_payload_corrupt                ), //o
    .io_down_a_valid            (system_mainBus_arbiter_core_io_down_a_valid                           ), //o
    .io_down_a_ready            (system_mainBus_bus_a_ready                                            ), //i
    .io_down_a_payload_opcode   (system_mainBus_arbiter_core_io_down_a_payload_opcode[2:0]             ), //o
    .io_down_a_payload_param    (system_mainBus_arbiter_core_io_down_a_payload_param[2:0]              ), //o
    .io_down_a_payload_source   (system_mainBus_arbiter_core_io_down_a_payload_source[5:0]             ), //o
    .io_down_a_payload_address  (system_mainBus_arbiter_core_io_down_a_payload_address[31:0]           ), //o
    .io_down_a_payload_size     (system_mainBus_arbiter_core_io_down_a_payload_size[2:0]               ), //o
    .io_down_a_payload_mask     (system_mainBus_arbiter_core_io_down_a_payload_mask[7:0]               ), //o
    .io_down_a_payload_data     (system_mainBus_arbiter_core_io_down_a_payload_data[63:0]              ), //o
    .io_down_a_payload_corrupt  (system_mainBus_arbiter_core_io_down_a_payload_corrupt                 ), //o
    .io_down_d_valid            (system_mainBus_bus_d_valid                                            ), //i
    .io_down_d_ready            (system_mainBus_arbiter_core_io_down_d_ready                           ), //o
    .io_down_d_payload_opcode   (system_mainBus_bus_d_payload_opcode[2:0]                              ), //i
    .io_down_d_payload_param    (system_mainBus_bus_d_payload_param[2:0]                               ), //i
    .io_down_d_payload_source   (system_mainBus_bus_d_payload_source[5:0]                              ), //i
    .io_down_d_payload_size     (system_mainBus_bus_d_payload_size[2:0]                                ), //i
    .io_down_d_payload_denied   (system_mainBus_bus_d_payload_denied                                   ), //i
    .io_down_d_payload_data     (system_mainBus_bus_d_payload_data[63:0]                               ), //i
    .io_down_d_payload_corrupt  (system_mainBus_bus_d_payload_corrupt                                  ), //i
    .socCtrl_systemClk          (socCtrl_systemClk                                                     ), //i
    .socCtrl_system_reset       (socCtrl_system_reset                                                  )  //i
  );
  Ram system_ram_thread_logic (
    .io_up_a_valid           (system_ram_up_bus_a_valid                          ), //i
    .io_up_a_ready           (system_ram_thread_logic_io_up_a_ready              ), //o
    .io_up_a_payload_opcode  (system_ram_up_bus_a_payload_opcode[2:0]            ), //i
    .io_up_a_payload_param   (system_ram_up_bus_a_payload_param[2:0]             ), //i
    .io_up_a_payload_source  (system_ram_up_bus_a_payload_source[5:0]            ), //i
    .io_up_a_payload_address (system_ram_up_bus_a_payload_address[15:0]          ), //i
    .io_up_a_payload_size    (system_ram_up_bus_a_payload_size[2:0]              ), //i
    .io_up_a_payload_mask    (system_ram_up_bus_a_payload_mask[7:0]              ), //i
    .io_up_a_payload_data    (system_ram_up_bus_a_payload_data[63:0]             ), //i
    .io_up_a_payload_corrupt (system_ram_up_bus_a_payload_corrupt                ), //i
    .io_up_d_valid           (system_ram_thread_logic_io_up_d_valid              ), //o
    .io_up_d_ready           (system_ram_up_bus_d_ready                          ), //i
    .io_up_d_payload_opcode  (system_ram_thread_logic_io_up_d_payload_opcode[2:0]), //o
    .io_up_d_payload_param   (system_ram_thread_logic_io_up_d_payload_param[2:0] ), //o
    .io_up_d_payload_source  (system_ram_thread_logic_io_up_d_payload_source[5:0]), //o
    .io_up_d_payload_size    (system_ram_thread_logic_io_up_d_payload_size[2:0]  ), //o
    .io_up_d_payload_denied  (system_ram_thread_logic_io_up_d_payload_denied     ), //o
    .io_up_d_payload_data    (system_ram_thread_logic_io_up_d_payload_data[63:0] ), //o
    .io_up_d_payload_corrupt (system_ram_thread_logic_io_up_d_payload_corrupt    ), //o
    .socCtrl_systemClk       (socCtrl_systemClk                                  ), //i
    .socCtrl_system_reset    (socCtrl_system_reset                               )  //i
  );
  WidthAdapter system_cpu_dBus_to_system_mainBus_widthAdapter (
    .io_up_a_valid             (system_cpu_dBus_to_system_mainBus_up_bus_a_valid                              ), //i
    .io_up_a_ready             (system_cpu_dBus_to_system_mainBus_widthAdapter_io_up_a_ready                  ), //o
    .io_up_a_payload_opcode    (system_cpu_dBus_to_system_mainBus_up_bus_a_payload_opcode[2:0]                ), //i
    .io_up_a_payload_param     (system_cpu_dBus_to_system_mainBus_up_bus_a_payload_param[2:0]                 ), //i
    .io_up_a_payload_address   (system_cpu_dBus_to_system_mainBus_up_bus_a_payload_address[31:0]              ), //i
    .io_up_a_payload_size      (system_cpu_dBus_to_system_mainBus_up_bus_a_payload_size[1:0]                  ), //i
    .io_up_a_payload_mask      (system_cpu_dBus_to_system_mainBus_up_bus_a_payload_mask[3:0]                  ), //i
    .io_up_a_payload_data      (system_cpu_dBus_to_system_mainBus_up_bus_a_payload_data[31:0]                 ), //i
    .io_up_a_payload_corrupt   (system_cpu_dBus_to_system_mainBus_up_bus_a_payload_corrupt                    ), //i
    .io_up_d_valid             (system_cpu_dBus_to_system_mainBus_widthAdapter_io_up_d_valid                  ), //o
    .io_up_d_ready             (system_cpu_dBus_to_system_mainBus_up_bus_d_ready                              ), //i
    .io_up_d_payload_opcode    (system_cpu_dBus_to_system_mainBus_widthAdapter_io_up_d_payload_opcode[2:0]    ), //o
    .io_up_d_payload_param     (system_cpu_dBus_to_system_mainBus_widthAdapter_io_up_d_payload_param[2:0]     ), //o
    .io_up_d_payload_size      (system_cpu_dBus_to_system_mainBus_widthAdapter_io_up_d_payload_size[1:0]      ), //o
    .io_up_d_payload_denied    (system_cpu_dBus_to_system_mainBus_widthAdapter_io_up_d_payload_denied         ), //o
    .io_up_d_payload_data      (system_cpu_dBus_to_system_mainBus_widthAdapter_io_up_d_payload_data[31:0]     ), //o
    .io_up_d_payload_corrupt   (system_cpu_dBus_to_system_mainBus_widthAdapter_io_up_d_payload_corrupt        ), //o
    .io_down_a_valid           (system_cpu_dBus_to_system_mainBus_widthAdapter_io_down_a_valid                ), //o
    .io_down_a_ready           (system_cpu_dBus_to_system_mainBus_down_bus_a_ready                            ), //i
    .io_down_a_payload_opcode  (system_cpu_dBus_to_system_mainBus_widthAdapter_io_down_a_payload_opcode[2:0]  ), //o
    .io_down_a_payload_param   (system_cpu_dBus_to_system_mainBus_widthAdapter_io_down_a_payload_param[2:0]   ), //o
    .io_down_a_payload_address (system_cpu_dBus_to_system_mainBus_widthAdapter_io_down_a_payload_address[31:0]), //o
    .io_down_a_payload_size    (system_cpu_dBus_to_system_mainBus_widthAdapter_io_down_a_payload_size[1:0]    ), //o
    .io_down_a_payload_mask    (system_cpu_dBus_to_system_mainBus_widthAdapter_io_down_a_payload_mask[7:0]    ), //o
    .io_down_a_payload_data    (system_cpu_dBus_to_system_mainBus_widthAdapter_io_down_a_payload_data[63:0]   ), //o
    .io_down_a_payload_corrupt (system_cpu_dBus_to_system_mainBus_widthAdapter_io_down_a_payload_corrupt      ), //o
    .io_down_d_valid           (system_cpu_dBus_to_system_mainBus_down_bus_d_valid                            ), //i
    .io_down_d_ready           (system_cpu_dBus_to_system_mainBus_widthAdapter_io_down_d_ready                ), //o
    .io_down_d_payload_opcode  (system_cpu_dBus_to_system_mainBus_down_bus_d_payload_opcode[2:0]              ), //i
    .io_down_d_payload_param   (system_cpu_dBus_to_system_mainBus_down_bus_d_payload_param[2:0]               ), //i
    .io_down_d_payload_size    (system_cpu_dBus_to_system_mainBus_down_bus_d_payload_size[1:0]                ), //i
    .io_down_d_payload_denied  (system_cpu_dBus_to_system_mainBus_down_bus_d_payload_denied                   ), //i
    .io_down_d_payload_data    (system_cpu_dBus_to_system_mainBus_down_bus_d_payload_data[63:0]               ), //i
    .io_down_d_payload_corrupt (system_cpu_dBus_to_system_mainBus_down_bus_d_payload_corrupt                  ), //i
    .socCtrl_systemClk         (socCtrl_systemClk                                                             ), //i
    .socCtrl_system_reset      (socCtrl_system_reset                                                          )  //i
  );
  TilelinkClint system_peripheral_clint_thread_core (
    .io_bus_a_valid           (system_peripheral_clint_node_bus_a_valid                        ), //i
    .io_bus_a_ready           (system_peripheral_clint_thread_core_io_bus_a_ready              ), //o
    .io_bus_a_payload_opcode  (system_peripheral_clint_node_bus_a_payload_opcode[2:0]          ), //i
    .io_bus_a_payload_param   (system_peripheral_clint_node_bus_a_payload_param[2:0]           ), //i
    .io_bus_a_payload_source  (system_peripheral_clint_node_bus_a_payload_source[5:0]          ), //i
    .io_bus_a_payload_address (system_peripheral_clint_node_bus_a_payload_address[15:0]        ), //i
    .io_bus_a_payload_size    (system_peripheral_clint_node_bus_a_payload_size[2:0]            ), //i
    .io_bus_a_payload_mask    (system_peripheral_clint_node_bus_a_payload_mask[3:0]            ), //i
    .io_bus_a_payload_data    (system_peripheral_clint_node_bus_a_payload_data[31:0]           ), //i
    .io_bus_a_payload_corrupt (system_peripheral_clint_node_bus_a_payload_corrupt              ), //i
    .io_bus_d_valid           (system_peripheral_clint_thread_core_io_bus_d_valid              ), //o
    .io_bus_d_ready           (system_peripheral_clint_node_bus_d_ready                        ), //i
    .io_bus_d_payload_opcode  (system_peripheral_clint_thread_core_io_bus_d_payload_opcode[2:0]), //o
    .io_bus_d_payload_param   (system_peripheral_clint_thread_core_io_bus_d_payload_param[2:0] ), //o
    .io_bus_d_payload_source  (system_peripheral_clint_thread_core_io_bus_d_payload_source[5:0]), //o
    .io_bus_d_payload_size    (system_peripheral_clint_thread_core_io_bus_d_payload_size[2:0]  ), //o
    .io_bus_d_payload_denied  (system_peripheral_clint_thread_core_io_bus_d_payload_denied     ), //o
    .io_bus_d_payload_data    (system_peripheral_clint_thread_core_io_bus_d_payload_data[31:0] ), //o
    .io_bus_d_payload_corrupt (system_peripheral_clint_thread_core_io_bus_d_payload_corrupt    ), //o
    .io_timerInterrupt        (system_peripheral_clint_thread_core_io_timerInterrupt           ), //o
    .io_softwareInterrupt     (system_peripheral_clint_thread_core_io_softwareInterrupt        ), //o
    .io_time                  (system_peripheral_clint_thread_core_io_time[63:0]               ), //o
    .io_stop                  (system_peripheral_clint_thread_core_io_stop                     ), //i
    .socCtrl_systemClk        (socCtrl_systemClk                                               ), //i
    .socCtrl_system_reset     (socCtrl_system_reset                                            )  //i
  );
  Decoder system_peripheral_busXlen_decoder_core (
    .io_up_a_valid                (system_peripheral_busXlen_bus_a_valid                                                 ), //i
    .io_up_a_ready                (system_peripheral_busXlen_decoder_core_io_up_a_ready                                  ), //o
    .io_up_a_payload_opcode       (system_peripheral_busXlen_bus_a_payload_opcode[2:0]                                   ), //i
    .io_up_a_payload_param        (system_peripheral_busXlen_bus_a_payload_param[2:0]                                    ), //i
    .io_up_a_payload_source       (system_peripheral_busXlen_bus_a_payload_source[5:0]                                   ), //i
    .io_up_a_payload_address      (system_peripheral_busXlen_bus_a_payload_address[28:0]                                 ), //i
    .io_up_a_payload_size         (system_peripheral_busXlen_bus_a_payload_size[2:0]                                     ), //i
    .io_up_a_payload_mask         (system_peripheral_busXlen_bus_a_payload_mask[3:0]                                     ), //i
    .io_up_a_payload_data         (system_peripheral_busXlen_bus_a_payload_data[31:0]                                    ), //i
    .io_up_a_payload_corrupt      (system_peripheral_busXlen_bus_a_payload_corrupt                                       ), //i
    .io_up_d_valid                (system_peripheral_busXlen_decoder_core_io_up_d_valid                                  ), //o
    .io_up_d_ready                (system_peripheral_busXlen_bus_d_ready                                                 ), //i
    .io_up_d_payload_opcode       (system_peripheral_busXlen_decoder_core_io_up_d_payload_opcode[2:0]                    ), //o
    .io_up_d_payload_param        (system_peripheral_busXlen_decoder_core_io_up_d_payload_param[2:0]                     ), //o
    .io_up_d_payload_source       (system_peripheral_busXlen_decoder_core_io_up_d_payload_source[5:0]                    ), //o
    .io_up_d_payload_size         (system_peripheral_busXlen_decoder_core_io_up_d_payload_size[2:0]                      ), //o
    .io_up_d_payload_denied       (system_peripheral_busXlen_decoder_core_io_up_d_payload_denied                         ), //o
    .io_up_d_payload_data         (system_peripheral_busXlen_decoder_core_io_up_d_payload_data[31:0]                     ), //o
    .io_up_d_payload_corrupt      (system_peripheral_busXlen_decoder_core_io_up_d_payload_corrupt                        ), //o
    .io_downs_0_a_valid           (system_peripheral_busXlen_decoder_core_io_downs_0_a_valid                             ), //o
    .io_downs_0_a_ready           (system_peripheral_busXlen_to_system_peripheral_bus32_up_bus_a_ready                   ), //i
    .io_downs_0_a_payload_opcode  (system_peripheral_busXlen_decoder_core_io_downs_0_a_payload_opcode[2:0]               ), //o
    .io_downs_0_a_payload_param   (system_peripheral_busXlen_decoder_core_io_downs_0_a_payload_param[2:0]                ), //o
    .io_downs_0_a_payload_source  (system_peripheral_busXlen_decoder_core_io_downs_0_a_payload_source[5:0]               ), //o
    .io_downs_0_a_payload_address (system_peripheral_busXlen_decoder_core_io_downs_0_a_payload_address[28:0]             ), //o
    .io_downs_0_a_payload_size    (system_peripheral_busXlen_decoder_core_io_downs_0_a_payload_size[1:0]                 ), //o
    .io_downs_0_a_payload_mask    (system_peripheral_busXlen_decoder_core_io_downs_0_a_payload_mask[3:0]                 ), //o
    .io_downs_0_a_payload_data    (system_peripheral_busXlen_decoder_core_io_downs_0_a_payload_data[31:0]                ), //o
    .io_downs_0_a_payload_corrupt (system_peripheral_busXlen_decoder_core_io_downs_0_a_payload_corrupt                   ), //o
    .io_downs_0_d_valid           (system_peripheral_busXlen_to_system_peripheral_bus32_up_bus_d_valid                   ), //i
    .io_downs_0_d_ready           (system_peripheral_busXlen_decoder_core_io_downs_0_d_ready                             ), //o
    .io_downs_0_d_payload_opcode  (system_peripheral_busXlen_to_system_peripheral_bus32_up_bus_d_payload_opcode[2:0]     ), //i
    .io_downs_0_d_payload_param   (system_peripheral_busXlen_to_system_peripheral_bus32_up_bus_d_payload_param[2:0]      ), //i
    .io_downs_0_d_payload_source  (system_peripheral_busXlen_to_system_peripheral_bus32_up_bus_d_payload_source[5:0]     ), //i
    .io_downs_0_d_payload_size    (system_peripheral_busXlen_to_system_peripheral_bus32_up_bus_d_payload_size[1:0]       ), //i
    .io_downs_0_d_payload_denied  (system_peripheral_busXlen_to_system_peripheral_bus32_up_bus_d_payload_denied          ), //i
    .io_downs_0_d_payload_data    (system_peripheral_busXlen_to_system_peripheral_bus32_up_bus_d_payload_data[31:0]      ), //i
    .io_downs_0_d_payload_corrupt (system_peripheral_busXlen_to_system_peripheral_bus32_up_bus_d_payload_corrupt         ), //i
    .io_downs_1_a_valid           (system_peripheral_busXlen_decoder_core_io_downs_1_a_valid                             ), //o
    .io_downs_1_a_ready           (system_peripheral_busXlen_to_system_peripheral_clint_node_up_bus_a_ready              ), //i
    .io_downs_1_a_payload_opcode  (system_peripheral_busXlen_decoder_core_io_downs_1_a_payload_opcode[2:0]               ), //o
    .io_downs_1_a_payload_param   (system_peripheral_busXlen_decoder_core_io_downs_1_a_payload_param[2:0]                ), //o
    .io_downs_1_a_payload_source  (system_peripheral_busXlen_decoder_core_io_downs_1_a_payload_source[5:0]               ), //o
    .io_downs_1_a_payload_address (system_peripheral_busXlen_decoder_core_io_downs_1_a_payload_address[15:0]             ), //o
    .io_downs_1_a_payload_size    (system_peripheral_busXlen_decoder_core_io_downs_1_a_payload_size[2:0]                 ), //o
    .io_downs_1_a_payload_mask    (system_peripheral_busXlen_decoder_core_io_downs_1_a_payload_mask[3:0]                 ), //o
    .io_downs_1_a_payload_data    (system_peripheral_busXlen_decoder_core_io_downs_1_a_payload_data[31:0]                ), //o
    .io_downs_1_a_payload_corrupt (system_peripheral_busXlen_decoder_core_io_downs_1_a_payload_corrupt                   ), //o
    .io_downs_1_d_valid           (system_peripheral_busXlen_to_system_peripheral_clint_node_up_bus_d_valid              ), //i
    .io_downs_1_d_ready           (system_peripheral_busXlen_decoder_core_io_downs_1_d_ready                             ), //o
    .io_downs_1_d_payload_opcode  (system_peripheral_busXlen_to_system_peripheral_clint_node_up_bus_d_payload_opcode[2:0]), //i
    .io_downs_1_d_payload_param   (system_peripheral_busXlen_to_system_peripheral_clint_node_up_bus_d_payload_param[2:0] ), //i
    .io_downs_1_d_payload_source  (system_peripheral_busXlen_to_system_peripheral_clint_node_up_bus_d_payload_source[5:0]), //i
    .io_downs_1_d_payload_size    (system_peripheral_busXlen_to_system_peripheral_clint_node_up_bus_d_payload_size[2:0]  ), //i
    .io_downs_1_d_payload_denied  (system_peripheral_busXlen_to_system_peripheral_clint_node_up_bus_d_payload_denied     ), //i
    .io_downs_1_d_payload_data    (system_peripheral_busXlen_to_system_peripheral_clint_node_up_bus_d_payload_data[31:0] ), //i
    .io_downs_1_d_payload_corrupt (system_peripheral_busXlen_to_system_peripheral_clint_node_up_bus_d_payload_corrupt    ), //i
    .socCtrl_systemClk            (socCtrl_systemClk                                                                     ), //i
    .socCtrl_system_reset         (socCtrl_system_reset                                                                  )  //i
  );
  Decoder_1 system_mainBus_decoder_core (
    .io_up_a_valid                (system_mainBus_bus_a_valid                                              ), //i
    .io_up_a_ready                (system_mainBus_decoder_core_io_up_a_ready                               ), //o
    .io_up_a_payload_opcode       (system_mainBus_bus_a_payload_opcode[2:0]                                ), //i
    .io_up_a_payload_param        (system_mainBus_bus_a_payload_param[2:0]                                 ), //i
    .io_up_a_payload_source       (system_mainBus_bus_a_payload_source[5:0]                                ), //i
    .io_up_a_payload_address      (system_mainBus_bus_a_payload_address[31:0]                              ), //i
    .io_up_a_payload_size         (system_mainBus_bus_a_payload_size[2:0]                                  ), //i
    .io_up_a_payload_mask         (system_mainBus_bus_a_payload_mask[7:0]                                  ), //i
    .io_up_a_payload_data         (system_mainBus_bus_a_payload_data[63:0]                                 ), //i
    .io_up_a_payload_corrupt      (system_mainBus_bus_a_payload_corrupt                                    ), //i
    .io_up_d_valid                (system_mainBus_decoder_core_io_up_d_valid                               ), //o
    .io_up_d_ready                (system_mainBus_bus_d_ready                                              ), //i
    .io_up_d_payload_opcode       (system_mainBus_decoder_core_io_up_d_payload_opcode[2:0]                 ), //o
    .io_up_d_payload_param        (system_mainBus_decoder_core_io_up_d_payload_param[2:0]                  ), //o
    .io_up_d_payload_source       (system_mainBus_decoder_core_io_up_d_payload_source[5:0]                 ), //o
    .io_up_d_payload_size         (system_mainBus_decoder_core_io_up_d_payload_size[2:0]                   ), //o
    .io_up_d_payload_denied       (system_mainBus_decoder_core_io_up_d_payload_denied                      ), //o
    .io_up_d_payload_data         (system_mainBus_decoder_core_io_up_d_payload_data[63:0]                  ), //o
    .io_up_d_payload_corrupt      (system_mainBus_decoder_core_io_up_d_payload_corrupt                     ), //o
    .io_downs_0_a_valid           (system_mainBus_decoder_core_io_downs_0_a_valid                          ), //o
    .io_downs_0_a_ready           (system_mainBus_to_system_ram_up_up_bus_a_ready                          ), //i
    .io_downs_0_a_payload_opcode  (system_mainBus_decoder_core_io_downs_0_a_payload_opcode[2:0]            ), //o
    .io_downs_0_a_payload_param   (system_mainBus_decoder_core_io_downs_0_a_payload_param[2:0]             ), //o
    .io_downs_0_a_payload_source  (system_mainBus_decoder_core_io_downs_0_a_payload_source[5:0]            ), //o
    .io_downs_0_a_payload_address (system_mainBus_decoder_core_io_downs_0_a_payload_address[15:0]          ), //o
    .io_downs_0_a_payload_size    (system_mainBus_decoder_core_io_downs_0_a_payload_size[2:0]              ), //o
    .io_downs_0_a_payload_mask    (system_mainBus_decoder_core_io_downs_0_a_payload_mask[7:0]              ), //o
    .io_downs_0_a_payload_data    (system_mainBus_decoder_core_io_downs_0_a_payload_data[63:0]             ), //o
    .io_downs_0_a_payload_corrupt (system_mainBus_decoder_core_io_downs_0_a_payload_corrupt                ), //o
    .io_downs_0_d_valid           (system_mainBus_to_system_ram_up_up_bus_d_valid                          ), //i
    .io_downs_0_d_ready           (system_mainBus_decoder_core_io_downs_0_d_ready                          ), //o
    .io_downs_0_d_payload_opcode  (system_mainBus_to_system_ram_up_up_bus_d_payload_opcode[2:0]            ), //i
    .io_downs_0_d_payload_param   (system_mainBus_to_system_ram_up_up_bus_d_payload_param[2:0]             ), //i
    .io_downs_0_d_payload_source  (system_mainBus_to_system_ram_up_up_bus_d_payload_source[5:0]            ), //i
    .io_downs_0_d_payload_size    (system_mainBus_to_system_ram_up_up_bus_d_payload_size[2:0]              ), //i
    .io_downs_0_d_payload_denied  (system_mainBus_to_system_ram_up_up_bus_d_payload_denied                 ), //i
    .io_downs_0_d_payload_data    (system_mainBus_to_system_ram_up_up_bus_d_payload_data[63:0]             ), //i
    .io_downs_0_d_payload_corrupt (system_mainBus_to_system_ram_up_up_bus_d_payload_corrupt                ), //i
    .io_downs_1_a_valid           (system_mainBus_decoder_core_io_downs_1_a_valid                          ), //o
    .io_downs_1_a_ready           (system_mainBus_to_system_peripheral_busXlen_up_bus_a_ready              ), //i
    .io_downs_1_a_payload_opcode  (system_mainBus_decoder_core_io_downs_1_a_payload_opcode[2:0]            ), //o
    .io_downs_1_a_payload_param   (system_mainBus_decoder_core_io_downs_1_a_payload_param[2:0]             ), //o
    .io_downs_1_a_payload_source  (system_mainBus_decoder_core_io_downs_1_a_payload_source[5:0]            ), //o
    .io_downs_1_a_payload_address (system_mainBus_decoder_core_io_downs_1_a_payload_address[28:0]          ), //o
    .io_downs_1_a_payload_size    (system_mainBus_decoder_core_io_downs_1_a_payload_size[2:0]              ), //o
    .io_downs_1_a_payload_mask    (system_mainBus_decoder_core_io_downs_1_a_payload_mask[7:0]              ), //o
    .io_downs_1_a_payload_data    (system_mainBus_decoder_core_io_downs_1_a_payload_data[63:0]             ), //o
    .io_downs_1_a_payload_corrupt (system_mainBus_decoder_core_io_downs_1_a_payload_corrupt                ), //o
    .io_downs_1_d_valid           (system_mainBus_to_system_peripheral_busXlen_up_bus_d_valid              ), //i
    .io_downs_1_d_ready           (system_mainBus_decoder_core_io_downs_1_d_ready                          ), //o
    .io_downs_1_d_payload_opcode  (system_mainBus_to_system_peripheral_busXlen_up_bus_d_payload_opcode[2:0]), //i
    .io_downs_1_d_payload_param   (system_mainBus_to_system_peripheral_busXlen_up_bus_d_payload_param[2:0] ), //i
    .io_downs_1_d_payload_source  (system_mainBus_to_system_peripheral_busXlen_up_bus_d_payload_source[5:0]), //i
    .io_downs_1_d_payload_size    (system_mainBus_to_system_peripheral_busXlen_up_bus_d_payload_size[2:0]  ), //i
    .io_downs_1_d_payload_denied  (system_mainBus_to_system_peripheral_busXlen_up_bus_d_payload_denied     ), //i
    .io_downs_1_d_payload_data    (system_mainBus_to_system_peripheral_busXlen_up_bus_d_payload_data[63:0] ), //i
    .io_downs_1_d_payload_corrupt (system_mainBus_to_system_peripheral_busXlen_up_bus_d_payload_corrupt    ), //i
    .socCtrl_systemClk            (socCtrl_systemClk                                                       ), //i
    .socCtrl_system_reset         (socCtrl_system_reset                                                    )  //i
  );
  TilelinkPlic system_peripheral_plic_thread_logic (
    .io_bus_a_valid           (system_peripheral_plic_node_bus_a_valid                         ), //i
    .io_bus_a_ready           (system_peripheral_plic_thread_logic_io_bus_a_ready              ), //o
    .io_bus_a_payload_opcode  (system_peripheral_plic_node_bus_a_payload_opcode[2:0]           ), //i
    .io_bus_a_payload_param   (system_peripheral_plic_node_bus_a_payload_param[2:0]            ), //i
    .io_bus_a_payload_source  (system_peripheral_plic_node_bus_a_payload_source[5:0]           ), //i
    .io_bus_a_payload_address (system_peripheral_plic_node_bus_a_payload_address[21:0]         ), //i
    .io_bus_a_payload_size    (system_peripheral_plic_node_bus_a_payload_size[1:0]             ), //i
    .io_bus_a_payload_mask    (system_peripheral_plic_node_bus_a_payload_mask[3:0]             ), //i
    .io_bus_a_payload_data    (system_peripheral_plic_node_bus_a_payload_data[31:0]            ), //i
    .io_bus_a_payload_corrupt (system_peripheral_plic_node_bus_a_payload_corrupt               ), //i
    .io_bus_d_valid           (system_peripheral_plic_thread_logic_io_bus_d_valid              ), //o
    .io_bus_d_ready           (system_peripheral_plic_node_bus_d_ready                         ), //i
    .io_bus_d_payload_opcode  (system_peripheral_plic_thread_logic_io_bus_d_payload_opcode[2:0]), //o
    .io_bus_d_payload_param   (system_peripheral_plic_thread_logic_io_bus_d_payload_param[2:0] ), //o
    .io_bus_d_payload_source  (system_peripheral_plic_thread_logic_io_bus_d_payload_source[5:0]), //o
    .io_bus_d_payload_size    (system_peripheral_plic_thread_logic_io_bus_d_payload_size[1:0]  ), //o
    .io_bus_d_payload_denied  (system_peripheral_plic_thread_logic_io_bus_d_payload_denied     ), //o
    .io_bus_d_payload_data    (system_peripheral_plic_thread_logic_io_bus_d_payload_data[31:0] ), //o
    .io_bus_d_payload_corrupt (system_peripheral_plic_thread_logic_io_bus_d_payload_corrupt    ), //o
    .io_sources               (system_peripheral_plic_thread_logic_io_sources[1:0]             ), //i
    .io_targets               (system_peripheral_plic_thread_logic_io_targets                  ), //o
    .socCtrl_systemClk        (socCtrl_systemClk                                               ), //i
    .socCtrl_system_reset     (socCtrl_system_reset                                            )  //i
  );
  TilelinkUartCtrl system_peripheral_uart_logic_core (
    .io_bus_a_valid           (system_peripheral_uart_node_bus_a_valid                       ), //i
    .io_bus_a_ready           (system_peripheral_uart_logic_core_io_bus_a_ready              ), //o
    .io_bus_a_payload_opcode  (system_peripheral_uart_node_bus_a_payload_opcode[2:0]         ), //i
    .io_bus_a_payload_param   (system_peripheral_uart_node_bus_a_payload_param[2:0]          ), //i
    .io_bus_a_payload_source  (system_peripheral_uart_node_bus_a_payload_source[5:0]         ), //i
    .io_bus_a_payload_address (system_peripheral_uart_node_bus_a_payload_address[7:0]        ), //i
    .io_bus_a_payload_size    (system_peripheral_uart_node_bus_a_payload_size[1:0]           ), //i
    .io_bus_a_payload_mask    (system_peripheral_uart_node_bus_a_payload_mask[3:0]           ), //i
    .io_bus_a_payload_data    (system_peripheral_uart_node_bus_a_payload_data[31:0]          ), //i
    .io_bus_a_payload_corrupt (system_peripheral_uart_node_bus_a_payload_corrupt             ), //i
    .io_bus_d_valid           (system_peripheral_uart_logic_core_io_bus_d_valid              ), //o
    .io_bus_d_ready           (system_peripheral_uart_node_bus_d_ready                       ), //i
    .io_bus_d_payload_opcode  (system_peripheral_uart_logic_core_io_bus_d_payload_opcode[2:0]), //o
    .io_bus_d_payload_param   (system_peripheral_uart_logic_core_io_bus_d_payload_param[2:0] ), //o
    .io_bus_d_payload_source  (system_peripheral_uart_logic_core_io_bus_d_payload_source[5:0]), //o
    .io_bus_d_payload_size    (system_peripheral_uart_logic_core_io_bus_d_payload_size[1:0]  ), //o
    .io_bus_d_payload_denied  (system_peripheral_uart_logic_core_io_bus_d_payload_denied     ), //o
    .io_bus_d_payload_data    (system_peripheral_uart_logic_core_io_bus_d_payload_data[31:0] ), //o
    .io_bus_d_payload_corrupt (system_peripheral_uart_logic_core_io_bus_d_payload_corrupt    ), //o
    .io_uart_txd              (system_peripheral_uart_logic_core_io_uart_txd                 ), //o
    .io_uart_rxd              (system_peripheral_uart_logic_uart_rxd                         ), //i
    .io_interrupt             (system_peripheral_uart_logic_core_io_interrupt                ), //o
    .socCtrl_systemClk        (socCtrl_systemClk                                             ), //i
    .socCtrl_system_reset     (socCtrl_system_reset                                          )  //i
  );
  PeripheralDemo system_peripheral_demo_logic_core (
    .io_bus_a_valid           (system_peripheral_demo_node_bus_a_valid                       ), //i
    .io_bus_a_ready           (system_peripheral_demo_logic_core_io_bus_a_ready              ), //o
    .io_bus_a_payload_opcode  (system_peripheral_demo_node_bus_a_payload_opcode[2:0]         ), //i
    .io_bus_a_payload_param   (system_peripheral_demo_node_bus_a_payload_param[2:0]          ), //i
    .io_bus_a_payload_source  (system_peripheral_demo_node_bus_a_payload_source[5:0]         ), //i
    .io_bus_a_payload_address (system_peripheral_demo_node_bus_a_payload_address[11:0]       ), //i
    .io_bus_a_payload_size    (system_peripheral_demo_node_bus_a_payload_size[1:0]           ), //i
    .io_bus_a_payload_mask    (system_peripheral_demo_node_bus_a_payload_mask[3:0]           ), //i
    .io_bus_a_payload_data    (system_peripheral_demo_node_bus_a_payload_data[31:0]          ), //i
    .io_bus_a_payload_corrupt (system_peripheral_demo_node_bus_a_payload_corrupt             ), //i
    .io_bus_d_valid           (system_peripheral_demo_logic_core_io_bus_d_valid              ), //o
    .io_bus_d_ready           (system_peripheral_demo_node_bus_d_ready                       ), //i
    .io_bus_d_payload_opcode  (system_peripheral_demo_logic_core_io_bus_d_payload_opcode[2:0]), //o
    .io_bus_d_payload_param   (system_peripheral_demo_logic_core_io_bus_d_payload_param[2:0] ), //o
    .io_bus_d_payload_source  (system_peripheral_demo_logic_core_io_bus_d_payload_source[5:0]), //o
    .io_bus_d_payload_size    (system_peripheral_demo_logic_core_io_bus_d_payload_size[1:0]  ), //o
    .io_bus_d_payload_denied  (system_peripheral_demo_logic_core_io_bus_d_payload_denied     ), //o
    .io_bus_d_payload_data    (system_peripheral_demo_logic_core_io_bus_d_payload_data[31:0] ), //o
    .io_bus_d_payload_corrupt (system_peripheral_demo_logic_core_io_bus_d_payload_corrupt    ), //o
    .io_leds                  (system_peripheral_demo_logic_core_io_leds[7:0]                ), //o
    .io_buttons               (system_peripheral_demo_logic_buttons                          ), //i
    .io_interrupt             (system_peripheral_demo_logic_core_io_interrupt                ), //o
    .socCtrl_systemClk        (socCtrl_systemClk                                             ), //i
    .socCtrl_system_reset     (socCtrl_system_reset                                          )  //i
  );
  WidthAdapter_1 system_mainBus_to_system_peripheral_busXlen_widthAdapter (
    .io_up_a_valid             (system_mainBus_to_system_peripheral_busXlen_up_bus_a_valid                              ), //i
    .io_up_a_ready             (system_mainBus_to_system_peripheral_busXlen_widthAdapter_io_up_a_ready                  ), //o
    .io_up_a_payload_opcode    (system_mainBus_to_system_peripheral_busXlen_up_bus_a_payload_opcode[2:0]                ), //i
    .io_up_a_payload_param     (system_mainBus_to_system_peripheral_busXlen_up_bus_a_payload_param[2:0]                 ), //i
    .io_up_a_payload_source    (system_mainBus_to_system_peripheral_busXlen_up_bus_a_payload_source[5:0]                ), //i
    .io_up_a_payload_address   (system_mainBus_to_system_peripheral_busXlen_up_bus_a_payload_address[28:0]              ), //i
    .io_up_a_payload_size      (system_mainBus_to_system_peripheral_busXlen_up_bus_a_payload_size[2:0]                  ), //i
    .io_up_a_payload_mask      (system_mainBus_to_system_peripheral_busXlen_up_bus_a_payload_mask[7:0]                  ), //i
    .io_up_a_payload_data      (system_mainBus_to_system_peripheral_busXlen_up_bus_a_payload_data[63:0]                 ), //i
    .io_up_a_payload_corrupt   (system_mainBus_to_system_peripheral_busXlen_up_bus_a_payload_corrupt                    ), //i
    .io_up_d_valid             (system_mainBus_to_system_peripheral_busXlen_widthAdapter_io_up_d_valid                  ), //o
    .io_up_d_ready             (system_mainBus_to_system_peripheral_busXlen_up_bus_d_ready                              ), //i
    .io_up_d_payload_opcode    (system_mainBus_to_system_peripheral_busXlen_widthAdapter_io_up_d_payload_opcode[2:0]    ), //o
    .io_up_d_payload_param     (system_mainBus_to_system_peripheral_busXlen_widthAdapter_io_up_d_payload_param[2:0]     ), //o
    .io_up_d_payload_source    (system_mainBus_to_system_peripheral_busXlen_widthAdapter_io_up_d_payload_source[5:0]    ), //o
    .io_up_d_payload_size      (system_mainBus_to_system_peripheral_busXlen_widthAdapter_io_up_d_payload_size[2:0]      ), //o
    .io_up_d_payload_denied    (system_mainBus_to_system_peripheral_busXlen_widthAdapter_io_up_d_payload_denied         ), //o
    .io_up_d_payload_data      (system_mainBus_to_system_peripheral_busXlen_widthAdapter_io_up_d_payload_data[63:0]     ), //o
    .io_up_d_payload_corrupt   (system_mainBus_to_system_peripheral_busXlen_widthAdapter_io_up_d_payload_corrupt        ), //o
    .io_down_a_valid           (system_mainBus_to_system_peripheral_busXlen_widthAdapter_io_down_a_valid                ), //o
    .io_down_a_ready           (system_mainBus_to_system_peripheral_busXlen_down_bus_a_ready                            ), //i
    .io_down_a_payload_opcode  (system_mainBus_to_system_peripheral_busXlen_widthAdapter_io_down_a_payload_opcode[2:0]  ), //o
    .io_down_a_payload_param   (system_mainBus_to_system_peripheral_busXlen_widthAdapter_io_down_a_payload_param[2:0]   ), //o
    .io_down_a_payload_source  (system_mainBus_to_system_peripheral_busXlen_widthAdapter_io_down_a_payload_source[5:0]  ), //o
    .io_down_a_payload_address (system_mainBus_to_system_peripheral_busXlen_widthAdapter_io_down_a_payload_address[28:0]), //o
    .io_down_a_payload_size    (system_mainBus_to_system_peripheral_busXlen_widthAdapter_io_down_a_payload_size[2:0]    ), //o
    .io_down_a_payload_mask    (system_mainBus_to_system_peripheral_busXlen_widthAdapter_io_down_a_payload_mask[3:0]    ), //o
    .io_down_a_payload_data    (system_mainBus_to_system_peripheral_busXlen_widthAdapter_io_down_a_payload_data[31:0]   ), //o
    .io_down_a_payload_corrupt (system_mainBus_to_system_peripheral_busXlen_widthAdapter_io_down_a_payload_corrupt      ), //o
    .io_down_d_valid           (system_mainBus_to_system_peripheral_busXlen_down_bus_d_valid                            ), //i
    .io_down_d_ready           (system_mainBus_to_system_peripheral_busXlen_widthAdapter_io_down_d_ready                ), //o
    .io_down_d_payload_opcode  (system_mainBus_to_system_peripheral_busXlen_down_bus_d_payload_opcode[2:0]              ), //i
    .io_down_d_payload_param   (system_mainBus_to_system_peripheral_busXlen_down_bus_d_payload_param[2:0]               ), //i
    .io_down_d_payload_source  (system_mainBus_to_system_peripheral_busXlen_down_bus_d_payload_source[5:0]              ), //i
    .io_down_d_payload_size    (system_mainBus_to_system_peripheral_busXlen_down_bus_d_payload_size[2:0]                ), //i
    .io_down_d_payload_denied  (system_mainBus_to_system_peripheral_busXlen_down_bus_d_payload_denied                   ), //i
    .io_down_d_payload_data    (system_mainBus_to_system_peripheral_busXlen_down_bus_d_payload_data[31:0]               ), //i
    .io_down_d_payload_corrupt (system_mainBus_to_system_peripheral_busXlen_down_bus_d_payload_corrupt                  ), //i
    .socCtrl_systemClk         (socCtrl_systemClk                                                                       ), //i
    .socCtrl_system_reset      (socCtrl_system_reset                                                                    )  //i
  );
  Decoder_2 system_peripheral_bus32_decoder_core (
    .io_up_a_valid                (system_peripheral_bus32_bus_a_valid                                                ), //i
    .io_up_a_ready                (system_peripheral_bus32_decoder_core_io_up_a_ready                                 ), //o
    .io_up_a_payload_opcode       (system_peripheral_bus32_bus_a_payload_opcode[2:0]                                  ), //i
    .io_up_a_payload_param        (system_peripheral_bus32_bus_a_payload_param[2:0]                                   ), //i
    .io_up_a_payload_source       (system_peripheral_bus32_bus_a_payload_source[5:0]                                  ), //i
    .io_up_a_payload_address      (system_peripheral_bus32_bus_a_payload_address[28:0]                                ), //i
    .io_up_a_payload_size         (system_peripheral_bus32_bus_a_payload_size[1:0]                                    ), //i
    .io_up_a_payload_mask         (system_peripheral_bus32_bus_a_payload_mask[3:0]                                    ), //i
    .io_up_a_payload_data         (system_peripheral_bus32_bus_a_payload_data[31:0]                                   ), //i
    .io_up_a_payload_corrupt      (system_peripheral_bus32_bus_a_payload_corrupt                                      ), //i
    .io_up_d_valid                (system_peripheral_bus32_decoder_core_io_up_d_valid                                 ), //o
    .io_up_d_ready                (system_peripheral_bus32_bus_d_ready                                                ), //i
    .io_up_d_payload_opcode       (system_peripheral_bus32_decoder_core_io_up_d_payload_opcode[2:0]                   ), //o
    .io_up_d_payload_param        (system_peripheral_bus32_decoder_core_io_up_d_payload_param[2:0]                    ), //o
    .io_up_d_payload_source       (system_peripheral_bus32_decoder_core_io_up_d_payload_source[5:0]                   ), //o
    .io_up_d_payload_size         (system_peripheral_bus32_decoder_core_io_up_d_payload_size[1:0]                     ), //o
    .io_up_d_payload_denied       (system_peripheral_bus32_decoder_core_io_up_d_payload_denied                        ), //o
    .io_up_d_payload_data         (system_peripheral_bus32_decoder_core_io_up_d_payload_data[31:0]                    ), //o
    .io_up_d_payload_corrupt      (system_peripheral_bus32_decoder_core_io_up_d_payload_corrupt                       ), //o
    .io_downs_0_a_valid           (system_peripheral_bus32_decoder_core_io_downs_0_a_valid                            ), //o
    .io_downs_0_a_ready           (system_peripheral_bus32_to_system_peripheral_plic_node_up_bus_a_ready              ), //i
    .io_downs_0_a_payload_opcode  (system_peripheral_bus32_decoder_core_io_downs_0_a_payload_opcode[2:0]              ), //o
    .io_downs_0_a_payload_param   (system_peripheral_bus32_decoder_core_io_downs_0_a_payload_param[2:0]               ), //o
    .io_downs_0_a_payload_source  (system_peripheral_bus32_decoder_core_io_downs_0_a_payload_source[5:0]              ), //o
    .io_downs_0_a_payload_address (system_peripheral_bus32_decoder_core_io_downs_0_a_payload_address[21:0]            ), //o
    .io_downs_0_a_payload_size    (system_peripheral_bus32_decoder_core_io_downs_0_a_payload_size[1:0]                ), //o
    .io_downs_0_a_payload_mask    (system_peripheral_bus32_decoder_core_io_downs_0_a_payload_mask[3:0]                ), //o
    .io_downs_0_a_payload_data    (system_peripheral_bus32_decoder_core_io_downs_0_a_payload_data[31:0]               ), //o
    .io_downs_0_a_payload_corrupt (system_peripheral_bus32_decoder_core_io_downs_0_a_payload_corrupt                  ), //o
    .io_downs_0_d_valid           (system_peripheral_bus32_to_system_peripheral_plic_node_up_bus_d_valid              ), //i
    .io_downs_0_d_ready           (system_peripheral_bus32_decoder_core_io_downs_0_d_ready                            ), //o
    .io_downs_0_d_payload_opcode  (system_peripheral_bus32_to_system_peripheral_plic_node_up_bus_d_payload_opcode[2:0]), //i
    .io_downs_0_d_payload_param   (system_peripheral_bus32_to_system_peripheral_plic_node_up_bus_d_payload_param[2:0] ), //i
    .io_downs_0_d_payload_source  (system_peripheral_bus32_to_system_peripheral_plic_node_up_bus_d_payload_source[5:0]), //i
    .io_downs_0_d_payload_size    (system_peripheral_bus32_to_system_peripheral_plic_node_up_bus_d_payload_size[1:0]  ), //i
    .io_downs_0_d_payload_denied  (system_peripheral_bus32_to_system_peripheral_plic_node_up_bus_d_payload_denied     ), //i
    .io_downs_0_d_payload_data    (system_peripheral_bus32_to_system_peripheral_plic_node_up_bus_d_payload_data[31:0] ), //i
    .io_downs_0_d_payload_corrupt (system_peripheral_bus32_to_system_peripheral_plic_node_up_bus_d_payload_corrupt    ), //i
    .io_downs_1_a_valid           (system_peripheral_bus32_decoder_core_io_downs_1_a_valid                            ), //o
    .io_downs_1_a_ready           (system_peripheral_bus32_to_system_peripheral_uart_node_up_bus_a_ready              ), //i
    .io_downs_1_a_payload_opcode  (system_peripheral_bus32_decoder_core_io_downs_1_a_payload_opcode[2:0]              ), //o
    .io_downs_1_a_payload_param   (system_peripheral_bus32_decoder_core_io_downs_1_a_payload_param[2:0]               ), //o
    .io_downs_1_a_payload_source  (system_peripheral_bus32_decoder_core_io_downs_1_a_payload_source[5:0]              ), //o
    .io_downs_1_a_payload_address (system_peripheral_bus32_decoder_core_io_downs_1_a_payload_address[7:0]             ), //o
    .io_downs_1_a_payload_size    (system_peripheral_bus32_decoder_core_io_downs_1_a_payload_size[1:0]                ), //o
    .io_downs_1_a_payload_mask    (system_peripheral_bus32_decoder_core_io_downs_1_a_payload_mask[3:0]                ), //o
    .io_downs_1_a_payload_data    (system_peripheral_bus32_decoder_core_io_downs_1_a_payload_data[31:0]               ), //o
    .io_downs_1_a_payload_corrupt (system_peripheral_bus32_decoder_core_io_downs_1_a_payload_corrupt                  ), //o
    .io_downs_1_d_valid           (system_peripheral_bus32_to_system_peripheral_uart_node_up_bus_d_valid              ), //i
    .io_downs_1_d_ready           (system_peripheral_bus32_decoder_core_io_downs_1_d_ready                            ), //o
    .io_downs_1_d_payload_opcode  (system_peripheral_bus32_to_system_peripheral_uart_node_up_bus_d_payload_opcode[2:0]), //i
    .io_downs_1_d_payload_param   (system_peripheral_bus32_to_system_peripheral_uart_node_up_bus_d_payload_param[2:0] ), //i
    .io_downs_1_d_payload_source  (system_peripheral_bus32_to_system_peripheral_uart_node_up_bus_d_payload_source[5:0]), //i
    .io_downs_1_d_payload_size    (system_peripheral_bus32_to_system_peripheral_uart_node_up_bus_d_payload_size[1:0]  ), //i
    .io_downs_1_d_payload_denied  (system_peripheral_bus32_to_system_peripheral_uart_node_up_bus_d_payload_denied     ), //i
    .io_downs_1_d_payload_data    (system_peripheral_bus32_to_system_peripheral_uart_node_up_bus_d_payload_data[31:0] ), //i
    .io_downs_1_d_payload_corrupt (system_peripheral_bus32_to_system_peripheral_uart_node_up_bus_d_payload_corrupt    ), //i
    .io_downs_2_a_valid           (system_peripheral_bus32_decoder_core_io_downs_2_a_valid                            ), //o
    .io_downs_2_a_ready           (system_peripheral_bus32_to_system_peripheral_demo_node_up_bus_a_ready              ), //i
    .io_downs_2_a_payload_opcode  (system_peripheral_bus32_decoder_core_io_downs_2_a_payload_opcode[2:0]              ), //o
    .io_downs_2_a_payload_param   (system_peripheral_bus32_decoder_core_io_downs_2_a_payload_param[2:0]               ), //o
    .io_downs_2_a_payload_source  (system_peripheral_bus32_decoder_core_io_downs_2_a_payload_source[5:0]              ), //o
    .io_downs_2_a_payload_address (system_peripheral_bus32_decoder_core_io_downs_2_a_payload_address[11:0]            ), //o
    .io_downs_2_a_payload_size    (system_peripheral_bus32_decoder_core_io_downs_2_a_payload_size[1:0]                ), //o
    .io_downs_2_a_payload_mask    (system_peripheral_bus32_decoder_core_io_downs_2_a_payload_mask[3:0]                ), //o
    .io_downs_2_a_payload_data    (system_peripheral_bus32_decoder_core_io_downs_2_a_payload_data[31:0]               ), //o
    .io_downs_2_a_payload_corrupt (system_peripheral_bus32_decoder_core_io_downs_2_a_payload_corrupt                  ), //o
    .io_downs_2_d_valid           (system_peripheral_bus32_to_system_peripheral_demo_node_up_bus_d_valid              ), //i
    .io_downs_2_d_ready           (system_peripheral_bus32_decoder_core_io_downs_2_d_ready                            ), //o
    .io_downs_2_d_payload_opcode  (system_peripheral_bus32_to_system_peripheral_demo_node_up_bus_d_payload_opcode[2:0]), //i
    .io_downs_2_d_payload_param   (system_peripheral_bus32_to_system_peripheral_demo_node_up_bus_d_payload_param[2:0] ), //i
    .io_downs_2_d_payload_source  (system_peripheral_bus32_to_system_peripheral_demo_node_up_bus_d_payload_source[5:0]), //i
    .io_downs_2_d_payload_size    (system_peripheral_bus32_to_system_peripheral_demo_node_up_bus_d_payload_size[1:0]  ), //i
    .io_downs_2_d_payload_denied  (system_peripheral_bus32_to_system_peripheral_demo_node_up_bus_d_payload_denied     ), //i
    .io_downs_2_d_payload_data    (system_peripheral_bus32_to_system_peripheral_demo_node_up_bus_d_payload_data[31:0] ), //i
    .io_downs_2_d_payload_corrupt (system_peripheral_bus32_to_system_peripheral_demo_node_up_bus_d_payload_corrupt    ), //i
    .socCtrl_systemClk            (socCtrl_systemClk                                                                  ), //i
    .socCtrl_system_reset         (socCtrl_system_reset                                                               )  //i
  );
  `ifndef SYNTHESIS
  always @(*) begin
    case(system_cpu_iBus_bus_a_payload_opcode)
      A_PUT_FULL_DATA : system_cpu_iBus_bus_a_payload_opcode_string = "PUT_FULL_DATA   ";
      A_PUT_PARTIAL_DATA : system_cpu_iBus_bus_a_payload_opcode_string = "PUT_PARTIAL_DATA";
      A_ARITHMETIC_DATA : system_cpu_iBus_bus_a_payload_opcode_string = "ARITHMETIC_DATA ";
      A_LOGICAL_DATA : system_cpu_iBus_bus_a_payload_opcode_string = "LOGICAL_DATA    ";
      A_GET : system_cpu_iBus_bus_a_payload_opcode_string = "GET             ";
      A_ACQUIRE_BLOCK : system_cpu_iBus_bus_a_payload_opcode_string = "ACQUIRE_BLOCK   ";
      A_ACQUIRE_PERM : system_cpu_iBus_bus_a_payload_opcode_string = "ACQUIRE_PERM    ";
      default : system_cpu_iBus_bus_a_payload_opcode_string = "????????????????";
    endcase
  end
  always @(*) begin
    case(system_cpu_iBus_bus_d_payload_opcode)
      D_ACCESS_ACK : system_cpu_iBus_bus_d_payload_opcode_string = "ACCESS_ACK     ";
      D_ACCESS_ACK_DATA : system_cpu_iBus_bus_d_payload_opcode_string = "ACCESS_ACK_DATA";
      D_GRANT : system_cpu_iBus_bus_d_payload_opcode_string = "GRANT          ";
      D_GRANT_DATA : system_cpu_iBus_bus_d_payload_opcode_string = "GRANT_DATA     ";
      D_RELEASE_ACK : system_cpu_iBus_bus_d_payload_opcode_string = "RELEASE_ACK    ";
      default : system_cpu_iBus_bus_d_payload_opcode_string = "???????????????";
    endcase
  end
  always @(*) begin
    case(system_cpu_iBus_noDecoder_toDown_a_payload_opcode)
      A_PUT_FULL_DATA : system_cpu_iBus_noDecoder_toDown_a_payload_opcode_string = "PUT_FULL_DATA   ";
      A_PUT_PARTIAL_DATA : system_cpu_iBus_noDecoder_toDown_a_payload_opcode_string = "PUT_PARTIAL_DATA";
      A_ARITHMETIC_DATA : system_cpu_iBus_noDecoder_toDown_a_payload_opcode_string = "ARITHMETIC_DATA ";
      A_LOGICAL_DATA : system_cpu_iBus_noDecoder_toDown_a_payload_opcode_string = "LOGICAL_DATA    ";
      A_GET : system_cpu_iBus_noDecoder_toDown_a_payload_opcode_string = "GET             ";
      A_ACQUIRE_BLOCK : system_cpu_iBus_noDecoder_toDown_a_payload_opcode_string = "ACQUIRE_BLOCK   ";
      A_ACQUIRE_PERM : system_cpu_iBus_noDecoder_toDown_a_payload_opcode_string = "ACQUIRE_PERM    ";
      default : system_cpu_iBus_noDecoder_toDown_a_payload_opcode_string = "????????????????";
    endcase
  end
  always @(*) begin
    case(system_cpu_iBus_noDecoder_toDown_d_payload_opcode)
      D_ACCESS_ACK : system_cpu_iBus_noDecoder_toDown_d_payload_opcode_string = "ACCESS_ACK     ";
      D_ACCESS_ACK_DATA : system_cpu_iBus_noDecoder_toDown_d_payload_opcode_string = "ACCESS_ACK_DATA";
      D_GRANT : system_cpu_iBus_noDecoder_toDown_d_payload_opcode_string = "GRANT          ";
      D_GRANT_DATA : system_cpu_iBus_noDecoder_toDown_d_payload_opcode_string = "GRANT_DATA     ";
      D_RELEASE_ACK : system_cpu_iBus_noDecoder_toDown_d_payload_opcode_string = "RELEASE_ACK    ";
      default : system_cpu_iBus_noDecoder_toDown_d_payload_opcode_string = "???????????????";
    endcase
  end
  always @(*) begin
    case(system_cpu_dBus_bus_a_payload_opcode)
      A_PUT_FULL_DATA : system_cpu_dBus_bus_a_payload_opcode_string = "PUT_FULL_DATA   ";
      A_PUT_PARTIAL_DATA : system_cpu_dBus_bus_a_payload_opcode_string = "PUT_PARTIAL_DATA";
      A_ARITHMETIC_DATA : system_cpu_dBus_bus_a_payload_opcode_string = "ARITHMETIC_DATA ";
      A_LOGICAL_DATA : system_cpu_dBus_bus_a_payload_opcode_string = "LOGICAL_DATA    ";
      A_GET : system_cpu_dBus_bus_a_payload_opcode_string = "GET             ";
      A_ACQUIRE_BLOCK : system_cpu_dBus_bus_a_payload_opcode_string = "ACQUIRE_BLOCK   ";
      A_ACQUIRE_PERM : system_cpu_dBus_bus_a_payload_opcode_string = "ACQUIRE_PERM    ";
      default : system_cpu_dBus_bus_a_payload_opcode_string = "????????????????";
    endcase
  end
  always @(*) begin
    case(system_cpu_dBus_bus_d_payload_opcode)
      D_ACCESS_ACK : system_cpu_dBus_bus_d_payload_opcode_string = "ACCESS_ACK     ";
      D_ACCESS_ACK_DATA : system_cpu_dBus_bus_d_payload_opcode_string = "ACCESS_ACK_DATA";
      D_GRANT : system_cpu_dBus_bus_d_payload_opcode_string = "GRANT          ";
      D_GRANT_DATA : system_cpu_dBus_bus_d_payload_opcode_string = "GRANT_DATA     ";
      D_RELEASE_ACK : system_cpu_dBus_bus_d_payload_opcode_string = "RELEASE_ACK    ";
      default : system_cpu_dBus_bus_d_payload_opcode_string = "???????????????";
    endcase
  end
  always @(*) begin
    case(system_cpu_dBus_noDecoder_toDown_a_payload_opcode)
      A_PUT_FULL_DATA : system_cpu_dBus_noDecoder_toDown_a_payload_opcode_string = "PUT_FULL_DATA   ";
      A_PUT_PARTIAL_DATA : system_cpu_dBus_noDecoder_toDown_a_payload_opcode_string = "PUT_PARTIAL_DATA";
      A_ARITHMETIC_DATA : system_cpu_dBus_noDecoder_toDown_a_payload_opcode_string = "ARITHMETIC_DATA ";
      A_LOGICAL_DATA : system_cpu_dBus_noDecoder_toDown_a_payload_opcode_string = "LOGICAL_DATA    ";
      A_GET : system_cpu_dBus_noDecoder_toDown_a_payload_opcode_string = "GET             ";
      A_ACQUIRE_BLOCK : system_cpu_dBus_noDecoder_toDown_a_payload_opcode_string = "ACQUIRE_BLOCK   ";
      A_ACQUIRE_PERM : system_cpu_dBus_noDecoder_toDown_a_payload_opcode_string = "ACQUIRE_PERM    ";
      default : system_cpu_dBus_noDecoder_toDown_a_payload_opcode_string = "????????????????";
    endcase
  end
  always @(*) begin
    case(system_cpu_dBus_noDecoder_toDown_d_payload_opcode)
      D_ACCESS_ACK : system_cpu_dBus_noDecoder_toDown_d_payload_opcode_string = "ACCESS_ACK     ";
      D_ACCESS_ACK_DATA : system_cpu_dBus_noDecoder_toDown_d_payload_opcode_string = "ACCESS_ACK_DATA";
      D_GRANT : system_cpu_dBus_noDecoder_toDown_d_payload_opcode_string = "GRANT          ";
      D_GRANT_DATA : system_cpu_dBus_noDecoder_toDown_d_payload_opcode_string = "GRANT_DATA     ";
      D_RELEASE_ACK : system_cpu_dBus_noDecoder_toDown_d_payload_opcode_string = "RELEASE_ACK    ";
      default : system_cpu_dBus_noDecoder_toDown_d_payload_opcode_string = "???????????????";
    endcase
  end
  always @(*) begin
    case(system_cpu_dBus_bus_a_s2mPipe_payload_opcode)
      A_PUT_FULL_DATA : system_cpu_dBus_bus_a_s2mPipe_payload_opcode_string = "PUT_FULL_DATA   ";
      A_PUT_PARTIAL_DATA : system_cpu_dBus_bus_a_s2mPipe_payload_opcode_string = "PUT_PARTIAL_DATA";
      A_ARITHMETIC_DATA : system_cpu_dBus_bus_a_s2mPipe_payload_opcode_string = "ARITHMETIC_DATA ";
      A_LOGICAL_DATA : system_cpu_dBus_bus_a_s2mPipe_payload_opcode_string = "LOGICAL_DATA    ";
      A_GET : system_cpu_dBus_bus_a_s2mPipe_payload_opcode_string = "GET             ";
      A_ACQUIRE_BLOCK : system_cpu_dBus_bus_a_s2mPipe_payload_opcode_string = "ACQUIRE_BLOCK   ";
      A_ACQUIRE_PERM : system_cpu_dBus_bus_a_s2mPipe_payload_opcode_string = "ACQUIRE_PERM    ";
      default : system_cpu_dBus_bus_a_s2mPipe_payload_opcode_string = "????????????????";
    endcase
  end
  always @(*) begin
    case(system_cpu_dBus_bus_a_rData_opcode)
      A_PUT_FULL_DATA : system_cpu_dBus_bus_a_rData_opcode_string = "PUT_FULL_DATA   ";
      A_PUT_PARTIAL_DATA : system_cpu_dBus_bus_a_rData_opcode_string = "PUT_PARTIAL_DATA";
      A_ARITHMETIC_DATA : system_cpu_dBus_bus_a_rData_opcode_string = "ARITHMETIC_DATA ";
      A_LOGICAL_DATA : system_cpu_dBus_bus_a_rData_opcode_string = "LOGICAL_DATA    ";
      A_GET : system_cpu_dBus_bus_a_rData_opcode_string = "GET             ";
      A_ACQUIRE_BLOCK : system_cpu_dBus_bus_a_rData_opcode_string = "ACQUIRE_BLOCK   ";
      A_ACQUIRE_PERM : system_cpu_dBus_bus_a_rData_opcode_string = "ACQUIRE_PERM    ";
      default : system_cpu_dBus_bus_a_rData_opcode_string = "????????????????";
    endcase
  end
  always @(*) begin
    case(_zz_system_cpu_dBus_bus_a_s2mPipe_payload_opcode)
      A_PUT_FULL_DATA : _zz_system_cpu_dBus_bus_a_s2mPipe_payload_opcode_string = "PUT_FULL_DATA   ";
      A_PUT_PARTIAL_DATA : _zz_system_cpu_dBus_bus_a_s2mPipe_payload_opcode_string = "PUT_PARTIAL_DATA";
      A_ARITHMETIC_DATA : _zz_system_cpu_dBus_bus_a_s2mPipe_payload_opcode_string = "ARITHMETIC_DATA ";
      A_LOGICAL_DATA : _zz_system_cpu_dBus_bus_a_s2mPipe_payload_opcode_string = "LOGICAL_DATA    ";
      A_GET : _zz_system_cpu_dBus_bus_a_s2mPipe_payload_opcode_string = "GET             ";
      A_ACQUIRE_BLOCK : _zz_system_cpu_dBus_bus_a_s2mPipe_payload_opcode_string = "ACQUIRE_BLOCK   ";
      A_ACQUIRE_PERM : _zz_system_cpu_dBus_bus_a_s2mPipe_payload_opcode_string = "ACQUIRE_PERM    ";
      default : _zz_system_cpu_dBus_bus_a_s2mPipe_payload_opcode_string = "????????????????";
    endcase
  end
  always @(*) begin
    case(system_cpu_dBus_noDecoder_toDown_d_combStage_payload_opcode)
      D_ACCESS_ACK : system_cpu_dBus_noDecoder_toDown_d_combStage_payload_opcode_string = "ACCESS_ACK     ";
      D_ACCESS_ACK_DATA : system_cpu_dBus_noDecoder_toDown_d_combStage_payload_opcode_string = "ACCESS_ACK_DATA";
      D_GRANT : system_cpu_dBus_noDecoder_toDown_d_combStage_payload_opcode_string = "GRANT          ";
      D_GRANT_DATA : system_cpu_dBus_noDecoder_toDown_d_combStage_payload_opcode_string = "GRANT_DATA     ";
      D_RELEASE_ACK : system_cpu_dBus_noDecoder_toDown_d_combStage_payload_opcode_string = "RELEASE_ACK    ";
      default : system_cpu_dBus_noDecoder_toDown_d_combStage_payload_opcode_string = "???????????????";
    endcase
  end
  always @(*) begin
    case(system_cpu_lsuL1Bus_bus_a_payload_opcode)
      A_PUT_FULL_DATA : system_cpu_lsuL1Bus_bus_a_payload_opcode_string = "PUT_FULL_DATA   ";
      A_PUT_PARTIAL_DATA : system_cpu_lsuL1Bus_bus_a_payload_opcode_string = "PUT_PARTIAL_DATA";
      A_ARITHMETIC_DATA : system_cpu_lsuL1Bus_bus_a_payload_opcode_string = "ARITHMETIC_DATA ";
      A_LOGICAL_DATA : system_cpu_lsuL1Bus_bus_a_payload_opcode_string = "LOGICAL_DATA    ";
      A_GET : system_cpu_lsuL1Bus_bus_a_payload_opcode_string = "GET             ";
      A_ACQUIRE_BLOCK : system_cpu_lsuL1Bus_bus_a_payload_opcode_string = "ACQUIRE_BLOCK   ";
      A_ACQUIRE_PERM : system_cpu_lsuL1Bus_bus_a_payload_opcode_string = "ACQUIRE_PERM    ";
      default : system_cpu_lsuL1Bus_bus_a_payload_opcode_string = "????????????????";
    endcase
  end
  always @(*) begin
    case(system_cpu_lsuL1Bus_bus_d_payload_opcode)
      D_ACCESS_ACK : system_cpu_lsuL1Bus_bus_d_payload_opcode_string = "ACCESS_ACK     ";
      D_ACCESS_ACK_DATA : system_cpu_lsuL1Bus_bus_d_payload_opcode_string = "ACCESS_ACK_DATA";
      D_GRANT : system_cpu_lsuL1Bus_bus_d_payload_opcode_string = "GRANT          ";
      D_GRANT_DATA : system_cpu_lsuL1Bus_bus_d_payload_opcode_string = "GRANT_DATA     ";
      D_RELEASE_ACK : system_cpu_lsuL1Bus_bus_d_payload_opcode_string = "RELEASE_ACK    ";
      default : system_cpu_lsuL1Bus_bus_d_payload_opcode_string = "???????????????";
    endcase
  end
  always @(*) begin
    case(system_cpu_lsuL1Bus_noDecoder_toDown_a_payload_opcode)
      A_PUT_FULL_DATA : system_cpu_lsuL1Bus_noDecoder_toDown_a_payload_opcode_string = "PUT_FULL_DATA   ";
      A_PUT_PARTIAL_DATA : system_cpu_lsuL1Bus_noDecoder_toDown_a_payload_opcode_string = "PUT_PARTIAL_DATA";
      A_ARITHMETIC_DATA : system_cpu_lsuL1Bus_noDecoder_toDown_a_payload_opcode_string = "ARITHMETIC_DATA ";
      A_LOGICAL_DATA : system_cpu_lsuL1Bus_noDecoder_toDown_a_payload_opcode_string = "LOGICAL_DATA    ";
      A_GET : system_cpu_lsuL1Bus_noDecoder_toDown_a_payload_opcode_string = "GET             ";
      A_ACQUIRE_BLOCK : system_cpu_lsuL1Bus_noDecoder_toDown_a_payload_opcode_string = "ACQUIRE_BLOCK   ";
      A_ACQUIRE_PERM : system_cpu_lsuL1Bus_noDecoder_toDown_a_payload_opcode_string = "ACQUIRE_PERM    ";
      default : system_cpu_lsuL1Bus_noDecoder_toDown_a_payload_opcode_string = "????????????????";
    endcase
  end
  always @(*) begin
    case(system_cpu_lsuL1Bus_noDecoder_toDown_d_payload_opcode)
      D_ACCESS_ACK : system_cpu_lsuL1Bus_noDecoder_toDown_d_payload_opcode_string = "ACCESS_ACK     ";
      D_ACCESS_ACK_DATA : system_cpu_lsuL1Bus_noDecoder_toDown_d_payload_opcode_string = "ACCESS_ACK_DATA";
      D_GRANT : system_cpu_lsuL1Bus_noDecoder_toDown_d_payload_opcode_string = "GRANT          ";
      D_GRANT_DATA : system_cpu_lsuL1Bus_noDecoder_toDown_d_payload_opcode_string = "GRANT_DATA     ";
      D_RELEASE_ACK : system_cpu_lsuL1Bus_noDecoder_toDown_d_payload_opcode_string = "RELEASE_ACK    ";
      default : system_cpu_lsuL1Bus_noDecoder_toDown_d_payload_opcode_string = "???????????????";
    endcase
  end
  always @(*) begin
    case(system_mainBus_bus_a_payload_opcode)
      A_PUT_FULL_DATA : system_mainBus_bus_a_payload_opcode_string = "PUT_FULL_DATA   ";
      A_PUT_PARTIAL_DATA : system_mainBus_bus_a_payload_opcode_string = "PUT_PARTIAL_DATA";
      A_ARITHMETIC_DATA : system_mainBus_bus_a_payload_opcode_string = "ARITHMETIC_DATA ";
      A_LOGICAL_DATA : system_mainBus_bus_a_payload_opcode_string = "LOGICAL_DATA    ";
      A_GET : system_mainBus_bus_a_payload_opcode_string = "GET             ";
      A_ACQUIRE_BLOCK : system_mainBus_bus_a_payload_opcode_string = "ACQUIRE_BLOCK   ";
      A_ACQUIRE_PERM : system_mainBus_bus_a_payload_opcode_string = "ACQUIRE_PERM    ";
      default : system_mainBus_bus_a_payload_opcode_string = "????????????????";
    endcase
  end
  always @(*) begin
    case(system_mainBus_bus_d_payload_opcode)
      D_ACCESS_ACK : system_mainBus_bus_d_payload_opcode_string = "ACCESS_ACK     ";
      D_ACCESS_ACK_DATA : system_mainBus_bus_d_payload_opcode_string = "ACCESS_ACK_DATA";
      D_GRANT : system_mainBus_bus_d_payload_opcode_string = "GRANT          ";
      D_GRANT_DATA : system_mainBus_bus_d_payload_opcode_string = "GRANT_DATA     ";
      D_RELEASE_ACK : system_mainBus_bus_d_payload_opcode_string = "RELEASE_ACK    ";
      default : system_mainBus_bus_d_payload_opcode_string = "???????????????";
    endcase
  end
  always @(*) begin
    case(system_cpu_iBus_to_system_mainBus_down_bus_a_payload_opcode)
      A_PUT_FULL_DATA : system_cpu_iBus_to_system_mainBus_down_bus_a_payload_opcode_string = "PUT_FULL_DATA   ";
      A_PUT_PARTIAL_DATA : system_cpu_iBus_to_system_mainBus_down_bus_a_payload_opcode_string = "PUT_PARTIAL_DATA";
      A_ARITHMETIC_DATA : system_cpu_iBus_to_system_mainBus_down_bus_a_payload_opcode_string = "ARITHMETIC_DATA ";
      A_LOGICAL_DATA : system_cpu_iBus_to_system_mainBus_down_bus_a_payload_opcode_string = "LOGICAL_DATA    ";
      A_GET : system_cpu_iBus_to_system_mainBus_down_bus_a_payload_opcode_string = "GET             ";
      A_ACQUIRE_BLOCK : system_cpu_iBus_to_system_mainBus_down_bus_a_payload_opcode_string = "ACQUIRE_BLOCK   ";
      A_ACQUIRE_PERM : system_cpu_iBus_to_system_mainBus_down_bus_a_payload_opcode_string = "ACQUIRE_PERM    ";
      default : system_cpu_iBus_to_system_mainBus_down_bus_a_payload_opcode_string = "????????????????";
    endcase
  end
  always @(*) begin
    case(system_cpu_iBus_to_system_mainBus_down_bus_d_payload_opcode)
      D_ACCESS_ACK : system_cpu_iBus_to_system_mainBus_down_bus_d_payload_opcode_string = "ACCESS_ACK     ";
      D_ACCESS_ACK_DATA : system_cpu_iBus_to_system_mainBus_down_bus_d_payload_opcode_string = "ACCESS_ACK_DATA";
      D_GRANT : system_cpu_iBus_to_system_mainBus_down_bus_d_payload_opcode_string = "GRANT          ";
      D_GRANT_DATA : system_cpu_iBus_to_system_mainBus_down_bus_d_payload_opcode_string = "GRANT_DATA     ";
      D_RELEASE_ACK : system_cpu_iBus_to_system_mainBus_down_bus_d_payload_opcode_string = "RELEASE_ACK    ";
      default : system_cpu_iBus_to_system_mainBus_down_bus_d_payload_opcode_string = "???????????????";
    endcase
  end
  always @(*) begin
    case(system_cpu_dBus_to_system_mainBus_down_bus_a_payload_opcode)
      A_PUT_FULL_DATA : system_cpu_dBus_to_system_mainBus_down_bus_a_payload_opcode_string = "PUT_FULL_DATA   ";
      A_PUT_PARTIAL_DATA : system_cpu_dBus_to_system_mainBus_down_bus_a_payload_opcode_string = "PUT_PARTIAL_DATA";
      A_ARITHMETIC_DATA : system_cpu_dBus_to_system_mainBus_down_bus_a_payload_opcode_string = "ARITHMETIC_DATA ";
      A_LOGICAL_DATA : system_cpu_dBus_to_system_mainBus_down_bus_a_payload_opcode_string = "LOGICAL_DATA    ";
      A_GET : system_cpu_dBus_to_system_mainBus_down_bus_a_payload_opcode_string = "GET             ";
      A_ACQUIRE_BLOCK : system_cpu_dBus_to_system_mainBus_down_bus_a_payload_opcode_string = "ACQUIRE_BLOCK   ";
      A_ACQUIRE_PERM : system_cpu_dBus_to_system_mainBus_down_bus_a_payload_opcode_string = "ACQUIRE_PERM    ";
      default : system_cpu_dBus_to_system_mainBus_down_bus_a_payload_opcode_string = "????????????????";
    endcase
  end
  always @(*) begin
    case(system_cpu_dBus_to_system_mainBus_down_bus_d_payload_opcode)
      D_ACCESS_ACK : system_cpu_dBus_to_system_mainBus_down_bus_d_payload_opcode_string = "ACCESS_ACK     ";
      D_ACCESS_ACK_DATA : system_cpu_dBus_to_system_mainBus_down_bus_d_payload_opcode_string = "ACCESS_ACK_DATA";
      D_GRANT : system_cpu_dBus_to_system_mainBus_down_bus_d_payload_opcode_string = "GRANT          ";
      D_GRANT_DATA : system_cpu_dBus_to_system_mainBus_down_bus_d_payload_opcode_string = "GRANT_DATA     ";
      D_RELEASE_ACK : system_cpu_dBus_to_system_mainBus_down_bus_d_payload_opcode_string = "RELEASE_ACK    ";
      default : system_cpu_dBus_to_system_mainBus_down_bus_d_payload_opcode_string = "???????????????";
    endcase
  end
  always @(*) begin
    case(system_cpu_lsuL1Bus_to_system_mainBus_down_bus_a_payload_opcode)
      A_PUT_FULL_DATA : system_cpu_lsuL1Bus_to_system_mainBus_down_bus_a_payload_opcode_string = "PUT_FULL_DATA   ";
      A_PUT_PARTIAL_DATA : system_cpu_lsuL1Bus_to_system_mainBus_down_bus_a_payload_opcode_string = "PUT_PARTIAL_DATA";
      A_ARITHMETIC_DATA : system_cpu_lsuL1Bus_to_system_mainBus_down_bus_a_payload_opcode_string = "ARITHMETIC_DATA ";
      A_LOGICAL_DATA : system_cpu_lsuL1Bus_to_system_mainBus_down_bus_a_payload_opcode_string = "LOGICAL_DATA    ";
      A_GET : system_cpu_lsuL1Bus_to_system_mainBus_down_bus_a_payload_opcode_string = "GET             ";
      A_ACQUIRE_BLOCK : system_cpu_lsuL1Bus_to_system_mainBus_down_bus_a_payload_opcode_string = "ACQUIRE_BLOCK   ";
      A_ACQUIRE_PERM : system_cpu_lsuL1Bus_to_system_mainBus_down_bus_a_payload_opcode_string = "ACQUIRE_PERM    ";
      default : system_cpu_lsuL1Bus_to_system_mainBus_down_bus_a_payload_opcode_string = "????????????????";
    endcase
  end
  always @(*) begin
    case(system_cpu_lsuL1Bus_to_system_mainBus_down_bus_d_payload_opcode)
      D_ACCESS_ACK : system_cpu_lsuL1Bus_to_system_mainBus_down_bus_d_payload_opcode_string = "ACCESS_ACK     ";
      D_ACCESS_ACK_DATA : system_cpu_lsuL1Bus_to_system_mainBus_down_bus_d_payload_opcode_string = "ACCESS_ACK_DATA";
      D_GRANT : system_cpu_lsuL1Bus_to_system_mainBus_down_bus_d_payload_opcode_string = "GRANT          ";
      D_GRANT_DATA : system_cpu_lsuL1Bus_to_system_mainBus_down_bus_d_payload_opcode_string = "GRANT_DATA     ";
      D_RELEASE_ACK : system_cpu_lsuL1Bus_to_system_mainBus_down_bus_d_payload_opcode_string = "RELEASE_ACK    ";
      default : system_cpu_lsuL1Bus_to_system_mainBus_down_bus_d_payload_opcode_string = "???????????????";
    endcase
  end
  always @(*) begin
    case(system_ram_up_bus_a_payload_opcode)
      A_PUT_FULL_DATA : system_ram_up_bus_a_payload_opcode_string = "PUT_FULL_DATA   ";
      A_PUT_PARTIAL_DATA : system_ram_up_bus_a_payload_opcode_string = "PUT_PARTIAL_DATA";
      A_ARITHMETIC_DATA : system_ram_up_bus_a_payload_opcode_string = "ARITHMETIC_DATA ";
      A_LOGICAL_DATA : system_ram_up_bus_a_payload_opcode_string = "LOGICAL_DATA    ";
      A_GET : system_ram_up_bus_a_payload_opcode_string = "GET             ";
      A_ACQUIRE_BLOCK : system_ram_up_bus_a_payload_opcode_string = "ACQUIRE_BLOCK   ";
      A_ACQUIRE_PERM : system_ram_up_bus_a_payload_opcode_string = "ACQUIRE_PERM    ";
      default : system_ram_up_bus_a_payload_opcode_string = "????????????????";
    endcase
  end
  always @(*) begin
    case(system_ram_up_bus_d_payload_opcode)
      D_ACCESS_ACK : system_ram_up_bus_d_payload_opcode_string = "ACCESS_ACK     ";
      D_ACCESS_ACK_DATA : system_ram_up_bus_d_payload_opcode_string = "ACCESS_ACK_DATA";
      D_GRANT : system_ram_up_bus_d_payload_opcode_string = "GRANT          ";
      D_GRANT_DATA : system_ram_up_bus_d_payload_opcode_string = "GRANT_DATA     ";
      D_RELEASE_ACK : system_ram_up_bus_d_payload_opcode_string = "RELEASE_ACK    ";
      default : system_ram_up_bus_d_payload_opcode_string = "???????????????";
    endcase
  end
  always @(*) begin
    case(system_mainBus_to_system_ram_up_down_bus_a_payload_opcode)
      A_PUT_FULL_DATA : system_mainBus_to_system_ram_up_down_bus_a_payload_opcode_string = "PUT_FULL_DATA   ";
      A_PUT_PARTIAL_DATA : system_mainBus_to_system_ram_up_down_bus_a_payload_opcode_string = "PUT_PARTIAL_DATA";
      A_ARITHMETIC_DATA : system_mainBus_to_system_ram_up_down_bus_a_payload_opcode_string = "ARITHMETIC_DATA ";
      A_LOGICAL_DATA : system_mainBus_to_system_ram_up_down_bus_a_payload_opcode_string = "LOGICAL_DATA    ";
      A_GET : system_mainBus_to_system_ram_up_down_bus_a_payload_opcode_string = "GET             ";
      A_ACQUIRE_BLOCK : system_mainBus_to_system_ram_up_down_bus_a_payload_opcode_string = "ACQUIRE_BLOCK   ";
      A_ACQUIRE_PERM : system_mainBus_to_system_ram_up_down_bus_a_payload_opcode_string = "ACQUIRE_PERM    ";
      default : system_mainBus_to_system_ram_up_down_bus_a_payload_opcode_string = "????????????????";
    endcase
  end
  always @(*) begin
    case(system_mainBus_to_system_ram_up_down_bus_d_payload_opcode)
      D_ACCESS_ACK : system_mainBus_to_system_ram_up_down_bus_d_payload_opcode_string = "ACCESS_ACK     ";
      D_ACCESS_ACK_DATA : system_mainBus_to_system_ram_up_down_bus_d_payload_opcode_string = "ACCESS_ACK_DATA";
      D_GRANT : system_mainBus_to_system_ram_up_down_bus_d_payload_opcode_string = "GRANT          ";
      D_GRANT_DATA : system_mainBus_to_system_ram_up_down_bus_d_payload_opcode_string = "GRANT_DATA     ";
      D_RELEASE_ACK : system_mainBus_to_system_ram_up_down_bus_d_payload_opcode_string = "RELEASE_ACK    ";
      default : system_mainBus_to_system_ram_up_down_bus_d_payload_opcode_string = "???????????????";
    endcase
  end
  always @(*) begin
    case(system_peripheral_busXlen_bus_a_payload_opcode)
      A_PUT_FULL_DATA : system_peripheral_busXlen_bus_a_payload_opcode_string = "PUT_FULL_DATA   ";
      A_PUT_PARTIAL_DATA : system_peripheral_busXlen_bus_a_payload_opcode_string = "PUT_PARTIAL_DATA";
      A_ARITHMETIC_DATA : system_peripheral_busXlen_bus_a_payload_opcode_string = "ARITHMETIC_DATA ";
      A_LOGICAL_DATA : system_peripheral_busXlen_bus_a_payload_opcode_string = "LOGICAL_DATA    ";
      A_GET : system_peripheral_busXlen_bus_a_payload_opcode_string = "GET             ";
      A_ACQUIRE_BLOCK : system_peripheral_busXlen_bus_a_payload_opcode_string = "ACQUIRE_BLOCK   ";
      A_ACQUIRE_PERM : system_peripheral_busXlen_bus_a_payload_opcode_string = "ACQUIRE_PERM    ";
      default : system_peripheral_busXlen_bus_a_payload_opcode_string = "????????????????";
    endcase
  end
  always @(*) begin
    case(system_peripheral_busXlen_bus_d_payload_opcode)
      D_ACCESS_ACK : system_peripheral_busXlen_bus_d_payload_opcode_string = "ACCESS_ACK     ";
      D_ACCESS_ACK_DATA : system_peripheral_busXlen_bus_d_payload_opcode_string = "ACCESS_ACK_DATA";
      D_GRANT : system_peripheral_busXlen_bus_d_payload_opcode_string = "GRANT          ";
      D_GRANT_DATA : system_peripheral_busXlen_bus_d_payload_opcode_string = "GRANT_DATA     ";
      D_RELEASE_ACK : system_peripheral_busXlen_bus_d_payload_opcode_string = "RELEASE_ACK    ";
      default : system_peripheral_busXlen_bus_d_payload_opcode_string = "???????????????";
    endcase
  end
  always @(*) begin
    case(system_mainBus_to_system_peripheral_busXlen_down_bus_a_payload_opcode)
      A_PUT_FULL_DATA : system_mainBus_to_system_peripheral_busXlen_down_bus_a_payload_opcode_string = "PUT_FULL_DATA   ";
      A_PUT_PARTIAL_DATA : system_mainBus_to_system_peripheral_busXlen_down_bus_a_payload_opcode_string = "PUT_PARTIAL_DATA";
      A_ARITHMETIC_DATA : system_mainBus_to_system_peripheral_busXlen_down_bus_a_payload_opcode_string = "ARITHMETIC_DATA ";
      A_LOGICAL_DATA : system_mainBus_to_system_peripheral_busXlen_down_bus_a_payload_opcode_string = "LOGICAL_DATA    ";
      A_GET : system_mainBus_to_system_peripheral_busXlen_down_bus_a_payload_opcode_string = "GET             ";
      A_ACQUIRE_BLOCK : system_mainBus_to_system_peripheral_busXlen_down_bus_a_payload_opcode_string = "ACQUIRE_BLOCK   ";
      A_ACQUIRE_PERM : system_mainBus_to_system_peripheral_busXlen_down_bus_a_payload_opcode_string = "ACQUIRE_PERM    ";
      default : system_mainBus_to_system_peripheral_busXlen_down_bus_a_payload_opcode_string = "????????????????";
    endcase
  end
  always @(*) begin
    case(system_mainBus_to_system_peripheral_busXlen_down_bus_d_payload_opcode)
      D_ACCESS_ACK : system_mainBus_to_system_peripheral_busXlen_down_bus_d_payload_opcode_string = "ACCESS_ACK     ";
      D_ACCESS_ACK_DATA : system_mainBus_to_system_peripheral_busXlen_down_bus_d_payload_opcode_string = "ACCESS_ACK_DATA";
      D_GRANT : system_mainBus_to_system_peripheral_busXlen_down_bus_d_payload_opcode_string = "GRANT          ";
      D_GRANT_DATA : system_mainBus_to_system_peripheral_busXlen_down_bus_d_payload_opcode_string = "GRANT_DATA     ";
      D_RELEASE_ACK : system_mainBus_to_system_peripheral_busXlen_down_bus_d_payload_opcode_string = "RELEASE_ACK    ";
      default : system_mainBus_to_system_peripheral_busXlen_down_bus_d_payload_opcode_string = "???????????????";
    endcase
  end
  always @(*) begin
    case(system_mainBus_to_system_peripheral_busXlen_down_bus_a_halfPipe_payload_opcode)
      A_PUT_FULL_DATA : system_mainBus_to_system_peripheral_busXlen_down_bus_a_halfPipe_payload_opcode_string = "PUT_FULL_DATA   ";
      A_PUT_PARTIAL_DATA : system_mainBus_to_system_peripheral_busXlen_down_bus_a_halfPipe_payload_opcode_string = "PUT_PARTIAL_DATA";
      A_ARITHMETIC_DATA : system_mainBus_to_system_peripheral_busXlen_down_bus_a_halfPipe_payload_opcode_string = "ARITHMETIC_DATA ";
      A_LOGICAL_DATA : system_mainBus_to_system_peripheral_busXlen_down_bus_a_halfPipe_payload_opcode_string = "LOGICAL_DATA    ";
      A_GET : system_mainBus_to_system_peripheral_busXlen_down_bus_a_halfPipe_payload_opcode_string = "GET             ";
      A_ACQUIRE_BLOCK : system_mainBus_to_system_peripheral_busXlen_down_bus_a_halfPipe_payload_opcode_string = "ACQUIRE_BLOCK   ";
      A_ACQUIRE_PERM : system_mainBus_to_system_peripheral_busXlen_down_bus_a_halfPipe_payload_opcode_string = "ACQUIRE_PERM    ";
      default : system_mainBus_to_system_peripheral_busXlen_down_bus_a_halfPipe_payload_opcode_string = "????????????????";
    endcase
  end
  always @(*) begin
    case(system_mainBus_to_system_peripheral_busXlen_down_bus_a_rData_opcode)
      A_PUT_FULL_DATA : system_mainBus_to_system_peripheral_busXlen_down_bus_a_rData_opcode_string = "PUT_FULL_DATA   ";
      A_PUT_PARTIAL_DATA : system_mainBus_to_system_peripheral_busXlen_down_bus_a_rData_opcode_string = "PUT_PARTIAL_DATA";
      A_ARITHMETIC_DATA : system_mainBus_to_system_peripheral_busXlen_down_bus_a_rData_opcode_string = "ARITHMETIC_DATA ";
      A_LOGICAL_DATA : system_mainBus_to_system_peripheral_busXlen_down_bus_a_rData_opcode_string = "LOGICAL_DATA    ";
      A_GET : system_mainBus_to_system_peripheral_busXlen_down_bus_a_rData_opcode_string = "GET             ";
      A_ACQUIRE_BLOCK : system_mainBus_to_system_peripheral_busXlen_down_bus_a_rData_opcode_string = "ACQUIRE_BLOCK   ";
      A_ACQUIRE_PERM : system_mainBus_to_system_peripheral_busXlen_down_bus_a_rData_opcode_string = "ACQUIRE_PERM    ";
      default : system_mainBus_to_system_peripheral_busXlen_down_bus_a_rData_opcode_string = "????????????????";
    endcase
  end
  always @(*) begin
    case(system_peripheral_busXlen_bus_d_halfPipe_payload_opcode)
      D_ACCESS_ACK : system_peripheral_busXlen_bus_d_halfPipe_payload_opcode_string = "ACCESS_ACK     ";
      D_ACCESS_ACK_DATA : system_peripheral_busXlen_bus_d_halfPipe_payload_opcode_string = "ACCESS_ACK_DATA";
      D_GRANT : system_peripheral_busXlen_bus_d_halfPipe_payload_opcode_string = "GRANT          ";
      D_GRANT_DATA : system_peripheral_busXlen_bus_d_halfPipe_payload_opcode_string = "GRANT_DATA     ";
      D_RELEASE_ACK : system_peripheral_busXlen_bus_d_halfPipe_payload_opcode_string = "RELEASE_ACK    ";
      default : system_peripheral_busXlen_bus_d_halfPipe_payload_opcode_string = "???????????????";
    endcase
  end
  always @(*) begin
    case(system_peripheral_busXlen_bus_d_rData_opcode)
      D_ACCESS_ACK : system_peripheral_busXlen_bus_d_rData_opcode_string = "ACCESS_ACK     ";
      D_ACCESS_ACK_DATA : system_peripheral_busXlen_bus_d_rData_opcode_string = "ACCESS_ACK_DATA";
      D_GRANT : system_peripheral_busXlen_bus_d_rData_opcode_string = "GRANT          ";
      D_GRANT_DATA : system_peripheral_busXlen_bus_d_rData_opcode_string = "GRANT_DATA     ";
      D_RELEASE_ACK : system_peripheral_busXlen_bus_d_rData_opcode_string = "RELEASE_ACK    ";
      default : system_peripheral_busXlen_bus_d_rData_opcode_string = "???????????????";
    endcase
  end
  always @(*) begin
    case(system_cpu_iBus_to_system_mainBus_up_bus_a_payload_opcode)
      A_PUT_FULL_DATA : system_cpu_iBus_to_system_mainBus_up_bus_a_payload_opcode_string = "PUT_FULL_DATA   ";
      A_PUT_PARTIAL_DATA : system_cpu_iBus_to_system_mainBus_up_bus_a_payload_opcode_string = "PUT_PARTIAL_DATA";
      A_ARITHMETIC_DATA : system_cpu_iBus_to_system_mainBus_up_bus_a_payload_opcode_string = "ARITHMETIC_DATA ";
      A_LOGICAL_DATA : system_cpu_iBus_to_system_mainBus_up_bus_a_payload_opcode_string = "LOGICAL_DATA    ";
      A_GET : system_cpu_iBus_to_system_mainBus_up_bus_a_payload_opcode_string = "GET             ";
      A_ACQUIRE_BLOCK : system_cpu_iBus_to_system_mainBus_up_bus_a_payload_opcode_string = "ACQUIRE_BLOCK   ";
      A_ACQUIRE_PERM : system_cpu_iBus_to_system_mainBus_up_bus_a_payload_opcode_string = "ACQUIRE_PERM    ";
      default : system_cpu_iBus_to_system_mainBus_up_bus_a_payload_opcode_string = "????????????????";
    endcase
  end
  always @(*) begin
    case(system_cpu_iBus_to_system_mainBus_up_bus_d_payload_opcode)
      D_ACCESS_ACK : system_cpu_iBus_to_system_mainBus_up_bus_d_payload_opcode_string = "ACCESS_ACK     ";
      D_ACCESS_ACK_DATA : system_cpu_iBus_to_system_mainBus_up_bus_d_payload_opcode_string = "ACCESS_ACK_DATA";
      D_GRANT : system_cpu_iBus_to_system_mainBus_up_bus_d_payload_opcode_string = "GRANT          ";
      D_GRANT_DATA : system_cpu_iBus_to_system_mainBus_up_bus_d_payload_opcode_string = "GRANT_DATA     ";
      D_RELEASE_ACK : system_cpu_iBus_to_system_mainBus_up_bus_d_payload_opcode_string = "RELEASE_ACK    ";
      default : system_cpu_iBus_to_system_mainBus_up_bus_d_payload_opcode_string = "???????????????";
    endcase
  end
  always @(*) begin
    case(system_cpu_dBus_to_system_mainBus_up_bus_a_payload_opcode)
      A_PUT_FULL_DATA : system_cpu_dBus_to_system_mainBus_up_bus_a_payload_opcode_string = "PUT_FULL_DATA   ";
      A_PUT_PARTIAL_DATA : system_cpu_dBus_to_system_mainBus_up_bus_a_payload_opcode_string = "PUT_PARTIAL_DATA";
      A_ARITHMETIC_DATA : system_cpu_dBus_to_system_mainBus_up_bus_a_payload_opcode_string = "ARITHMETIC_DATA ";
      A_LOGICAL_DATA : system_cpu_dBus_to_system_mainBus_up_bus_a_payload_opcode_string = "LOGICAL_DATA    ";
      A_GET : system_cpu_dBus_to_system_mainBus_up_bus_a_payload_opcode_string = "GET             ";
      A_ACQUIRE_BLOCK : system_cpu_dBus_to_system_mainBus_up_bus_a_payload_opcode_string = "ACQUIRE_BLOCK   ";
      A_ACQUIRE_PERM : system_cpu_dBus_to_system_mainBus_up_bus_a_payload_opcode_string = "ACQUIRE_PERM    ";
      default : system_cpu_dBus_to_system_mainBus_up_bus_a_payload_opcode_string = "????????????????";
    endcase
  end
  always @(*) begin
    case(system_cpu_dBus_to_system_mainBus_up_bus_d_payload_opcode)
      D_ACCESS_ACK : system_cpu_dBus_to_system_mainBus_up_bus_d_payload_opcode_string = "ACCESS_ACK     ";
      D_ACCESS_ACK_DATA : system_cpu_dBus_to_system_mainBus_up_bus_d_payload_opcode_string = "ACCESS_ACK_DATA";
      D_GRANT : system_cpu_dBus_to_system_mainBus_up_bus_d_payload_opcode_string = "GRANT          ";
      D_GRANT_DATA : system_cpu_dBus_to_system_mainBus_up_bus_d_payload_opcode_string = "GRANT_DATA     ";
      D_RELEASE_ACK : system_cpu_dBus_to_system_mainBus_up_bus_d_payload_opcode_string = "RELEASE_ACK    ";
      default : system_cpu_dBus_to_system_mainBus_up_bus_d_payload_opcode_string = "???????????????";
    endcase
  end
  always @(*) begin
    case(system_cpu_lsuL1Bus_to_system_mainBus_up_bus_a_payload_opcode)
      A_PUT_FULL_DATA : system_cpu_lsuL1Bus_to_system_mainBus_up_bus_a_payload_opcode_string = "PUT_FULL_DATA   ";
      A_PUT_PARTIAL_DATA : system_cpu_lsuL1Bus_to_system_mainBus_up_bus_a_payload_opcode_string = "PUT_PARTIAL_DATA";
      A_ARITHMETIC_DATA : system_cpu_lsuL1Bus_to_system_mainBus_up_bus_a_payload_opcode_string = "ARITHMETIC_DATA ";
      A_LOGICAL_DATA : system_cpu_lsuL1Bus_to_system_mainBus_up_bus_a_payload_opcode_string = "LOGICAL_DATA    ";
      A_GET : system_cpu_lsuL1Bus_to_system_mainBus_up_bus_a_payload_opcode_string = "GET             ";
      A_ACQUIRE_BLOCK : system_cpu_lsuL1Bus_to_system_mainBus_up_bus_a_payload_opcode_string = "ACQUIRE_BLOCK   ";
      A_ACQUIRE_PERM : system_cpu_lsuL1Bus_to_system_mainBus_up_bus_a_payload_opcode_string = "ACQUIRE_PERM    ";
      default : system_cpu_lsuL1Bus_to_system_mainBus_up_bus_a_payload_opcode_string = "????????????????";
    endcase
  end
  always @(*) begin
    case(system_cpu_lsuL1Bus_to_system_mainBus_up_bus_d_payload_opcode)
      D_ACCESS_ACK : system_cpu_lsuL1Bus_to_system_mainBus_up_bus_d_payload_opcode_string = "ACCESS_ACK     ";
      D_ACCESS_ACK_DATA : system_cpu_lsuL1Bus_to_system_mainBus_up_bus_d_payload_opcode_string = "ACCESS_ACK_DATA";
      D_GRANT : system_cpu_lsuL1Bus_to_system_mainBus_up_bus_d_payload_opcode_string = "GRANT          ";
      D_GRANT_DATA : system_cpu_lsuL1Bus_to_system_mainBus_up_bus_d_payload_opcode_string = "GRANT_DATA     ";
      D_RELEASE_ACK : system_cpu_lsuL1Bus_to_system_mainBus_up_bus_d_payload_opcode_string = "RELEASE_ACK    ";
      default : system_cpu_lsuL1Bus_to_system_mainBus_up_bus_d_payload_opcode_string = "???????????????";
    endcase
  end
  always @(*) begin
    case(system_peripheral_bus32_bus_a_payload_opcode)
      A_PUT_FULL_DATA : system_peripheral_bus32_bus_a_payload_opcode_string = "PUT_FULL_DATA   ";
      A_PUT_PARTIAL_DATA : system_peripheral_bus32_bus_a_payload_opcode_string = "PUT_PARTIAL_DATA";
      A_ARITHMETIC_DATA : system_peripheral_bus32_bus_a_payload_opcode_string = "ARITHMETIC_DATA ";
      A_LOGICAL_DATA : system_peripheral_bus32_bus_a_payload_opcode_string = "LOGICAL_DATA    ";
      A_GET : system_peripheral_bus32_bus_a_payload_opcode_string = "GET             ";
      A_ACQUIRE_BLOCK : system_peripheral_bus32_bus_a_payload_opcode_string = "ACQUIRE_BLOCK   ";
      A_ACQUIRE_PERM : system_peripheral_bus32_bus_a_payload_opcode_string = "ACQUIRE_PERM    ";
      default : system_peripheral_bus32_bus_a_payload_opcode_string = "????????????????";
    endcase
  end
  always @(*) begin
    case(system_peripheral_bus32_bus_d_payload_opcode)
      D_ACCESS_ACK : system_peripheral_bus32_bus_d_payload_opcode_string = "ACCESS_ACK     ";
      D_ACCESS_ACK_DATA : system_peripheral_bus32_bus_d_payload_opcode_string = "ACCESS_ACK_DATA";
      D_GRANT : system_peripheral_bus32_bus_d_payload_opcode_string = "GRANT          ";
      D_GRANT_DATA : system_peripheral_bus32_bus_d_payload_opcode_string = "GRANT_DATA     ";
      D_RELEASE_ACK : system_peripheral_bus32_bus_d_payload_opcode_string = "RELEASE_ACK    ";
      default : system_peripheral_bus32_bus_d_payload_opcode_string = "???????????????";
    endcase
  end
  always @(*) begin
    case(system_peripheral_busXlen_to_system_peripheral_bus32_down_bus_a_payload_opcode)
      A_PUT_FULL_DATA : system_peripheral_busXlen_to_system_peripheral_bus32_down_bus_a_payload_opcode_string = "PUT_FULL_DATA   ";
      A_PUT_PARTIAL_DATA : system_peripheral_busXlen_to_system_peripheral_bus32_down_bus_a_payload_opcode_string = "PUT_PARTIAL_DATA";
      A_ARITHMETIC_DATA : system_peripheral_busXlen_to_system_peripheral_bus32_down_bus_a_payload_opcode_string = "ARITHMETIC_DATA ";
      A_LOGICAL_DATA : system_peripheral_busXlen_to_system_peripheral_bus32_down_bus_a_payload_opcode_string = "LOGICAL_DATA    ";
      A_GET : system_peripheral_busXlen_to_system_peripheral_bus32_down_bus_a_payload_opcode_string = "GET             ";
      A_ACQUIRE_BLOCK : system_peripheral_busXlen_to_system_peripheral_bus32_down_bus_a_payload_opcode_string = "ACQUIRE_BLOCK   ";
      A_ACQUIRE_PERM : system_peripheral_busXlen_to_system_peripheral_bus32_down_bus_a_payload_opcode_string = "ACQUIRE_PERM    ";
      default : system_peripheral_busXlen_to_system_peripheral_bus32_down_bus_a_payload_opcode_string = "????????????????";
    endcase
  end
  always @(*) begin
    case(system_peripheral_busXlen_to_system_peripheral_bus32_down_bus_d_payload_opcode)
      D_ACCESS_ACK : system_peripheral_busXlen_to_system_peripheral_bus32_down_bus_d_payload_opcode_string = "ACCESS_ACK     ";
      D_ACCESS_ACK_DATA : system_peripheral_busXlen_to_system_peripheral_bus32_down_bus_d_payload_opcode_string = "ACCESS_ACK_DATA";
      D_GRANT : system_peripheral_busXlen_to_system_peripheral_bus32_down_bus_d_payload_opcode_string = "GRANT          ";
      D_GRANT_DATA : system_peripheral_busXlen_to_system_peripheral_bus32_down_bus_d_payload_opcode_string = "GRANT_DATA     ";
      D_RELEASE_ACK : system_peripheral_busXlen_to_system_peripheral_bus32_down_bus_d_payload_opcode_string = "RELEASE_ACK    ";
      default : system_peripheral_busXlen_to_system_peripheral_bus32_down_bus_d_payload_opcode_string = "???????????????";
    endcase
  end
  always @(*) begin
    case(system_peripheral_clint_node_bus_a_payload_opcode)
      A_PUT_FULL_DATA : system_peripheral_clint_node_bus_a_payload_opcode_string = "PUT_FULL_DATA   ";
      A_PUT_PARTIAL_DATA : system_peripheral_clint_node_bus_a_payload_opcode_string = "PUT_PARTIAL_DATA";
      A_ARITHMETIC_DATA : system_peripheral_clint_node_bus_a_payload_opcode_string = "ARITHMETIC_DATA ";
      A_LOGICAL_DATA : system_peripheral_clint_node_bus_a_payload_opcode_string = "LOGICAL_DATA    ";
      A_GET : system_peripheral_clint_node_bus_a_payload_opcode_string = "GET             ";
      A_ACQUIRE_BLOCK : system_peripheral_clint_node_bus_a_payload_opcode_string = "ACQUIRE_BLOCK   ";
      A_ACQUIRE_PERM : system_peripheral_clint_node_bus_a_payload_opcode_string = "ACQUIRE_PERM    ";
      default : system_peripheral_clint_node_bus_a_payload_opcode_string = "????????????????";
    endcase
  end
  always @(*) begin
    case(system_peripheral_clint_node_bus_d_payload_opcode)
      D_ACCESS_ACK : system_peripheral_clint_node_bus_d_payload_opcode_string = "ACCESS_ACK     ";
      D_ACCESS_ACK_DATA : system_peripheral_clint_node_bus_d_payload_opcode_string = "ACCESS_ACK_DATA";
      D_GRANT : system_peripheral_clint_node_bus_d_payload_opcode_string = "GRANT          ";
      D_GRANT_DATA : system_peripheral_clint_node_bus_d_payload_opcode_string = "GRANT_DATA     ";
      D_RELEASE_ACK : system_peripheral_clint_node_bus_d_payload_opcode_string = "RELEASE_ACK    ";
      default : system_peripheral_clint_node_bus_d_payload_opcode_string = "???????????????";
    endcase
  end
  always @(*) begin
    case(system_peripheral_busXlen_to_system_peripheral_clint_node_down_bus_a_payload_opcode)
      A_PUT_FULL_DATA : system_peripheral_busXlen_to_system_peripheral_clint_node_down_bus_a_payload_opcode_string = "PUT_FULL_DATA   ";
      A_PUT_PARTIAL_DATA : system_peripheral_busXlen_to_system_peripheral_clint_node_down_bus_a_payload_opcode_string = "PUT_PARTIAL_DATA";
      A_ARITHMETIC_DATA : system_peripheral_busXlen_to_system_peripheral_clint_node_down_bus_a_payload_opcode_string = "ARITHMETIC_DATA ";
      A_LOGICAL_DATA : system_peripheral_busXlen_to_system_peripheral_clint_node_down_bus_a_payload_opcode_string = "LOGICAL_DATA    ";
      A_GET : system_peripheral_busXlen_to_system_peripheral_clint_node_down_bus_a_payload_opcode_string = "GET             ";
      A_ACQUIRE_BLOCK : system_peripheral_busXlen_to_system_peripheral_clint_node_down_bus_a_payload_opcode_string = "ACQUIRE_BLOCK   ";
      A_ACQUIRE_PERM : system_peripheral_busXlen_to_system_peripheral_clint_node_down_bus_a_payload_opcode_string = "ACQUIRE_PERM    ";
      default : system_peripheral_busXlen_to_system_peripheral_clint_node_down_bus_a_payload_opcode_string = "????????????????";
    endcase
  end
  always @(*) begin
    case(system_peripheral_busXlen_to_system_peripheral_clint_node_down_bus_d_payload_opcode)
      D_ACCESS_ACK : system_peripheral_busXlen_to_system_peripheral_clint_node_down_bus_d_payload_opcode_string = "ACCESS_ACK     ";
      D_ACCESS_ACK_DATA : system_peripheral_busXlen_to_system_peripheral_clint_node_down_bus_d_payload_opcode_string = "ACCESS_ACK_DATA";
      D_GRANT : system_peripheral_busXlen_to_system_peripheral_clint_node_down_bus_d_payload_opcode_string = "GRANT          ";
      D_GRANT_DATA : system_peripheral_busXlen_to_system_peripheral_clint_node_down_bus_d_payload_opcode_string = "GRANT_DATA     ";
      D_RELEASE_ACK : system_peripheral_busXlen_to_system_peripheral_clint_node_down_bus_d_payload_opcode_string = "RELEASE_ACK    ";
      default : system_peripheral_busXlen_to_system_peripheral_clint_node_down_bus_d_payload_opcode_string = "???????????????";
    endcase
  end
  always @(*) begin
    case(system_peripheral_plic_node_bus_a_payload_opcode)
      A_PUT_FULL_DATA : system_peripheral_plic_node_bus_a_payload_opcode_string = "PUT_FULL_DATA   ";
      A_PUT_PARTIAL_DATA : system_peripheral_plic_node_bus_a_payload_opcode_string = "PUT_PARTIAL_DATA";
      A_ARITHMETIC_DATA : system_peripheral_plic_node_bus_a_payload_opcode_string = "ARITHMETIC_DATA ";
      A_LOGICAL_DATA : system_peripheral_plic_node_bus_a_payload_opcode_string = "LOGICAL_DATA    ";
      A_GET : system_peripheral_plic_node_bus_a_payload_opcode_string = "GET             ";
      A_ACQUIRE_BLOCK : system_peripheral_plic_node_bus_a_payload_opcode_string = "ACQUIRE_BLOCK   ";
      A_ACQUIRE_PERM : system_peripheral_plic_node_bus_a_payload_opcode_string = "ACQUIRE_PERM    ";
      default : system_peripheral_plic_node_bus_a_payload_opcode_string = "????????????????";
    endcase
  end
  always @(*) begin
    case(system_peripheral_plic_node_bus_d_payload_opcode)
      D_ACCESS_ACK : system_peripheral_plic_node_bus_d_payload_opcode_string = "ACCESS_ACK     ";
      D_ACCESS_ACK_DATA : system_peripheral_plic_node_bus_d_payload_opcode_string = "ACCESS_ACK_DATA";
      D_GRANT : system_peripheral_plic_node_bus_d_payload_opcode_string = "GRANT          ";
      D_GRANT_DATA : system_peripheral_plic_node_bus_d_payload_opcode_string = "GRANT_DATA     ";
      D_RELEASE_ACK : system_peripheral_plic_node_bus_d_payload_opcode_string = "RELEASE_ACK    ";
      default : system_peripheral_plic_node_bus_d_payload_opcode_string = "???????????????";
    endcase
  end
  always @(*) begin
    case(system_peripheral_bus32_to_system_peripheral_plic_node_down_bus_a_payload_opcode)
      A_PUT_FULL_DATA : system_peripheral_bus32_to_system_peripheral_plic_node_down_bus_a_payload_opcode_string = "PUT_FULL_DATA   ";
      A_PUT_PARTIAL_DATA : system_peripheral_bus32_to_system_peripheral_plic_node_down_bus_a_payload_opcode_string = "PUT_PARTIAL_DATA";
      A_ARITHMETIC_DATA : system_peripheral_bus32_to_system_peripheral_plic_node_down_bus_a_payload_opcode_string = "ARITHMETIC_DATA ";
      A_LOGICAL_DATA : system_peripheral_bus32_to_system_peripheral_plic_node_down_bus_a_payload_opcode_string = "LOGICAL_DATA    ";
      A_GET : system_peripheral_bus32_to_system_peripheral_plic_node_down_bus_a_payload_opcode_string = "GET             ";
      A_ACQUIRE_BLOCK : system_peripheral_bus32_to_system_peripheral_plic_node_down_bus_a_payload_opcode_string = "ACQUIRE_BLOCK   ";
      A_ACQUIRE_PERM : system_peripheral_bus32_to_system_peripheral_plic_node_down_bus_a_payload_opcode_string = "ACQUIRE_PERM    ";
      default : system_peripheral_bus32_to_system_peripheral_plic_node_down_bus_a_payload_opcode_string = "????????????????";
    endcase
  end
  always @(*) begin
    case(system_peripheral_bus32_to_system_peripheral_plic_node_down_bus_d_payload_opcode)
      D_ACCESS_ACK : system_peripheral_bus32_to_system_peripheral_plic_node_down_bus_d_payload_opcode_string = "ACCESS_ACK     ";
      D_ACCESS_ACK_DATA : system_peripheral_bus32_to_system_peripheral_plic_node_down_bus_d_payload_opcode_string = "ACCESS_ACK_DATA";
      D_GRANT : system_peripheral_bus32_to_system_peripheral_plic_node_down_bus_d_payload_opcode_string = "GRANT          ";
      D_GRANT_DATA : system_peripheral_bus32_to_system_peripheral_plic_node_down_bus_d_payload_opcode_string = "GRANT_DATA     ";
      D_RELEASE_ACK : system_peripheral_bus32_to_system_peripheral_plic_node_down_bus_d_payload_opcode_string = "RELEASE_ACK    ";
      default : system_peripheral_bus32_to_system_peripheral_plic_node_down_bus_d_payload_opcode_string = "???????????????";
    endcase
  end
  always @(*) begin
    case(system_peripheral_uart_node_bus_a_payload_opcode)
      A_PUT_FULL_DATA : system_peripheral_uart_node_bus_a_payload_opcode_string = "PUT_FULL_DATA   ";
      A_PUT_PARTIAL_DATA : system_peripheral_uart_node_bus_a_payload_opcode_string = "PUT_PARTIAL_DATA";
      A_ARITHMETIC_DATA : system_peripheral_uart_node_bus_a_payload_opcode_string = "ARITHMETIC_DATA ";
      A_LOGICAL_DATA : system_peripheral_uart_node_bus_a_payload_opcode_string = "LOGICAL_DATA    ";
      A_GET : system_peripheral_uart_node_bus_a_payload_opcode_string = "GET             ";
      A_ACQUIRE_BLOCK : system_peripheral_uart_node_bus_a_payload_opcode_string = "ACQUIRE_BLOCK   ";
      A_ACQUIRE_PERM : system_peripheral_uart_node_bus_a_payload_opcode_string = "ACQUIRE_PERM    ";
      default : system_peripheral_uart_node_bus_a_payload_opcode_string = "????????????????";
    endcase
  end
  always @(*) begin
    case(system_peripheral_uart_node_bus_d_payload_opcode)
      D_ACCESS_ACK : system_peripheral_uart_node_bus_d_payload_opcode_string = "ACCESS_ACK     ";
      D_ACCESS_ACK_DATA : system_peripheral_uart_node_bus_d_payload_opcode_string = "ACCESS_ACK_DATA";
      D_GRANT : system_peripheral_uart_node_bus_d_payload_opcode_string = "GRANT          ";
      D_GRANT_DATA : system_peripheral_uart_node_bus_d_payload_opcode_string = "GRANT_DATA     ";
      D_RELEASE_ACK : system_peripheral_uart_node_bus_d_payload_opcode_string = "RELEASE_ACK    ";
      default : system_peripheral_uart_node_bus_d_payload_opcode_string = "???????????????";
    endcase
  end
  always @(*) begin
    case(system_peripheral_bus32_to_system_peripheral_uart_node_down_bus_a_payload_opcode)
      A_PUT_FULL_DATA : system_peripheral_bus32_to_system_peripheral_uart_node_down_bus_a_payload_opcode_string = "PUT_FULL_DATA   ";
      A_PUT_PARTIAL_DATA : system_peripheral_bus32_to_system_peripheral_uart_node_down_bus_a_payload_opcode_string = "PUT_PARTIAL_DATA";
      A_ARITHMETIC_DATA : system_peripheral_bus32_to_system_peripheral_uart_node_down_bus_a_payload_opcode_string = "ARITHMETIC_DATA ";
      A_LOGICAL_DATA : system_peripheral_bus32_to_system_peripheral_uart_node_down_bus_a_payload_opcode_string = "LOGICAL_DATA    ";
      A_GET : system_peripheral_bus32_to_system_peripheral_uart_node_down_bus_a_payload_opcode_string = "GET             ";
      A_ACQUIRE_BLOCK : system_peripheral_bus32_to_system_peripheral_uart_node_down_bus_a_payload_opcode_string = "ACQUIRE_BLOCK   ";
      A_ACQUIRE_PERM : system_peripheral_bus32_to_system_peripheral_uart_node_down_bus_a_payload_opcode_string = "ACQUIRE_PERM    ";
      default : system_peripheral_bus32_to_system_peripheral_uart_node_down_bus_a_payload_opcode_string = "????????????????";
    endcase
  end
  always @(*) begin
    case(system_peripheral_bus32_to_system_peripheral_uart_node_down_bus_d_payload_opcode)
      D_ACCESS_ACK : system_peripheral_bus32_to_system_peripheral_uart_node_down_bus_d_payload_opcode_string = "ACCESS_ACK     ";
      D_ACCESS_ACK_DATA : system_peripheral_bus32_to_system_peripheral_uart_node_down_bus_d_payload_opcode_string = "ACCESS_ACK_DATA";
      D_GRANT : system_peripheral_bus32_to_system_peripheral_uart_node_down_bus_d_payload_opcode_string = "GRANT          ";
      D_GRANT_DATA : system_peripheral_bus32_to_system_peripheral_uart_node_down_bus_d_payload_opcode_string = "GRANT_DATA     ";
      D_RELEASE_ACK : system_peripheral_bus32_to_system_peripheral_uart_node_down_bus_d_payload_opcode_string = "RELEASE_ACK    ";
      default : system_peripheral_bus32_to_system_peripheral_uart_node_down_bus_d_payload_opcode_string = "???????????????";
    endcase
  end
  always @(*) begin
    case(system_peripheral_demo_node_bus_a_payload_opcode)
      A_PUT_FULL_DATA : system_peripheral_demo_node_bus_a_payload_opcode_string = "PUT_FULL_DATA   ";
      A_PUT_PARTIAL_DATA : system_peripheral_demo_node_bus_a_payload_opcode_string = "PUT_PARTIAL_DATA";
      A_ARITHMETIC_DATA : system_peripheral_demo_node_bus_a_payload_opcode_string = "ARITHMETIC_DATA ";
      A_LOGICAL_DATA : system_peripheral_demo_node_bus_a_payload_opcode_string = "LOGICAL_DATA    ";
      A_GET : system_peripheral_demo_node_bus_a_payload_opcode_string = "GET             ";
      A_ACQUIRE_BLOCK : system_peripheral_demo_node_bus_a_payload_opcode_string = "ACQUIRE_BLOCK   ";
      A_ACQUIRE_PERM : system_peripheral_demo_node_bus_a_payload_opcode_string = "ACQUIRE_PERM    ";
      default : system_peripheral_demo_node_bus_a_payload_opcode_string = "????????????????";
    endcase
  end
  always @(*) begin
    case(system_peripheral_demo_node_bus_d_payload_opcode)
      D_ACCESS_ACK : system_peripheral_demo_node_bus_d_payload_opcode_string = "ACCESS_ACK     ";
      D_ACCESS_ACK_DATA : system_peripheral_demo_node_bus_d_payload_opcode_string = "ACCESS_ACK_DATA";
      D_GRANT : system_peripheral_demo_node_bus_d_payload_opcode_string = "GRANT          ";
      D_GRANT_DATA : system_peripheral_demo_node_bus_d_payload_opcode_string = "GRANT_DATA     ";
      D_RELEASE_ACK : system_peripheral_demo_node_bus_d_payload_opcode_string = "RELEASE_ACK    ";
      default : system_peripheral_demo_node_bus_d_payload_opcode_string = "???????????????";
    endcase
  end
  always @(*) begin
    case(system_peripheral_bus32_to_system_peripheral_demo_node_down_bus_a_payload_opcode)
      A_PUT_FULL_DATA : system_peripheral_bus32_to_system_peripheral_demo_node_down_bus_a_payload_opcode_string = "PUT_FULL_DATA   ";
      A_PUT_PARTIAL_DATA : system_peripheral_bus32_to_system_peripheral_demo_node_down_bus_a_payload_opcode_string = "PUT_PARTIAL_DATA";
      A_ARITHMETIC_DATA : system_peripheral_bus32_to_system_peripheral_demo_node_down_bus_a_payload_opcode_string = "ARITHMETIC_DATA ";
      A_LOGICAL_DATA : system_peripheral_bus32_to_system_peripheral_demo_node_down_bus_a_payload_opcode_string = "LOGICAL_DATA    ";
      A_GET : system_peripheral_bus32_to_system_peripheral_demo_node_down_bus_a_payload_opcode_string = "GET             ";
      A_ACQUIRE_BLOCK : system_peripheral_bus32_to_system_peripheral_demo_node_down_bus_a_payload_opcode_string = "ACQUIRE_BLOCK   ";
      A_ACQUIRE_PERM : system_peripheral_bus32_to_system_peripheral_demo_node_down_bus_a_payload_opcode_string = "ACQUIRE_PERM    ";
      default : system_peripheral_bus32_to_system_peripheral_demo_node_down_bus_a_payload_opcode_string = "????????????????";
    endcase
  end
  always @(*) begin
    case(system_peripheral_bus32_to_system_peripheral_demo_node_down_bus_d_payload_opcode)
      D_ACCESS_ACK : system_peripheral_bus32_to_system_peripheral_demo_node_down_bus_d_payload_opcode_string = "ACCESS_ACK     ";
      D_ACCESS_ACK_DATA : system_peripheral_bus32_to_system_peripheral_demo_node_down_bus_d_payload_opcode_string = "ACCESS_ACK_DATA";
      D_GRANT : system_peripheral_bus32_to_system_peripheral_demo_node_down_bus_d_payload_opcode_string = "GRANT          ";
      D_GRANT_DATA : system_peripheral_bus32_to_system_peripheral_demo_node_down_bus_d_payload_opcode_string = "GRANT_DATA     ";
      D_RELEASE_ACK : system_peripheral_bus32_to_system_peripheral_demo_node_down_bus_d_payload_opcode_string = "RELEASE_ACK    ";
      default : system_peripheral_bus32_to_system_peripheral_demo_node_down_bus_d_payload_opcode_string = "???????????????";
    endcase
  end
  always @(*) begin
    case(system_peripheral_busXlen_to_system_peripheral_bus32_up_bus_a_payload_opcode)
      A_PUT_FULL_DATA : system_peripheral_busXlen_to_system_peripheral_bus32_up_bus_a_payload_opcode_string = "PUT_FULL_DATA   ";
      A_PUT_PARTIAL_DATA : system_peripheral_busXlen_to_system_peripheral_bus32_up_bus_a_payload_opcode_string = "PUT_PARTIAL_DATA";
      A_ARITHMETIC_DATA : system_peripheral_busXlen_to_system_peripheral_bus32_up_bus_a_payload_opcode_string = "ARITHMETIC_DATA ";
      A_LOGICAL_DATA : system_peripheral_busXlen_to_system_peripheral_bus32_up_bus_a_payload_opcode_string = "LOGICAL_DATA    ";
      A_GET : system_peripheral_busXlen_to_system_peripheral_bus32_up_bus_a_payload_opcode_string = "GET             ";
      A_ACQUIRE_BLOCK : system_peripheral_busXlen_to_system_peripheral_bus32_up_bus_a_payload_opcode_string = "ACQUIRE_BLOCK   ";
      A_ACQUIRE_PERM : system_peripheral_busXlen_to_system_peripheral_bus32_up_bus_a_payload_opcode_string = "ACQUIRE_PERM    ";
      default : system_peripheral_busXlen_to_system_peripheral_bus32_up_bus_a_payload_opcode_string = "????????????????";
    endcase
  end
  always @(*) begin
    case(system_peripheral_busXlen_to_system_peripheral_bus32_up_bus_d_payload_opcode)
      D_ACCESS_ACK : system_peripheral_busXlen_to_system_peripheral_bus32_up_bus_d_payload_opcode_string = "ACCESS_ACK     ";
      D_ACCESS_ACK_DATA : system_peripheral_busXlen_to_system_peripheral_bus32_up_bus_d_payload_opcode_string = "ACCESS_ACK_DATA";
      D_GRANT : system_peripheral_busXlen_to_system_peripheral_bus32_up_bus_d_payload_opcode_string = "GRANT          ";
      D_GRANT_DATA : system_peripheral_busXlen_to_system_peripheral_bus32_up_bus_d_payload_opcode_string = "GRANT_DATA     ";
      D_RELEASE_ACK : system_peripheral_busXlen_to_system_peripheral_bus32_up_bus_d_payload_opcode_string = "RELEASE_ACK    ";
      default : system_peripheral_busXlen_to_system_peripheral_bus32_up_bus_d_payload_opcode_string = "???????????????";
    endcase
  end
  always @(*) begin
    case(system_peripheral_busXlen_to_system_peripheral_clint_node_up_bus_a_payload_opcode)
      A_PUT_FULL_DATA : system_peripheral_busXlen_to_system_peripheral_clint_node_up_bus_a_payload_opcode_string = "PUT_FULL_DATA   ";
      A_PUT_PARTIAL_DATA : system_peripheral_busXlen_to_system_peripheral_clint_node_up_bus_a_payload_opcode_string = "PUT_PARTIAL_DATA";
      A_ARITHMETIC_DATA : system_peripheral_busXlen_to_system_peripheral_clint_node_up_bus_a_payload_opcode_string = "ARITHMETIC_DATA ";
      A_LOGICAL_DATA : system_peripheral_busXlen_to_system_peripheral_clint_node_up_bus_a_payload_opcode_string = "LOGICAL_DATA    ";
      A_GET : system_peripheral_busXlen_to_system_peripheral_clint_node_up_bus_a_payload_opcode_string = "GET             ";
      A_ACQUIRE_BLOCK : system_peripheral_busXlen_to_system_peripheral_clint_node_up_bus_a_payload_opcode_string = "ACQUIRE_BLOCK   ";
      A_ACQUIRE_PERM : system_peripheral_busXlen_to_system_peripheral_clint_node_up_bus_a_payload_opcode_string = "ACQUIRE_PERM    ";
      default : system_peripheral_busXlen_to_system_peripheral_clint_node_up_bus_a_payload_opcode_string = "????????????????";
    endcase
  end
  always @(*) begin
    case(system_peripheral_busXlen_to_system_peripheral_clint_node_up_bus_d_payload_opcode)
      D_ACCESS_ACK : system_peripheral_busXlen_to_system_peripheral_clint_node_up_bus_d_payload_opcode_string = "ACCESS_ACK     ";
      D_ACCESS_ACK_DATA : system_peripheral_busXlen_to_system_peripheral_clint_node_up_bus_d_payload_opcode_string = "ACCESS_ACK_DATA";
      D_GRANT : system_peripheral_busXlen_to_system_peripheral_clint_node_up_bus_d_payload_opcode_string = "GRANT          ";
      D_GRANT_DATA : system_peripheral_busXlen_to_system_peripheral_clint_node_up_bus_d_payload_opcode_string = "GRANT_DATA     ";
      D_RELEASE_ACK : system_peripheral_busXlen_to_system_peripheral_clint_node_up_bus_d_payload_opcode_string = "RELEASE_ACK    ";
      default : system_peripheral_busXlen_to_system_peripheral_clint_node_up_bus_d_payload_opcode_string = "???????????????";
    endcase
  end
  always @(*) begin
    case(system_mainBus_to_system_ram_up_up_bus_a_payload_opcode)
      A_PUT_FULL_DATA : system_mainBus_to_system_ram_up_up_bus_a_payload_opcode_string = "PUT_FULL_DATA   ";
      A_PUT_PARTIAL_DATA : system_mainBus_to_system_ram_up_up_bus_a_payload_opcode_string = "PUT_PARTIAL_DATA";
      A_ARITHMETIC_DATA : system_mainBus_to_system_ram_up_up_bus_a_payload_opcode_string = "ARITHMETIC_DATA ";
      A_LOGICAL_DATA : system_mainBus_to_system_ram_up_up_bus_a_payload_opcode_string = "LOGICAL_DATA    ";
      A_GET : system_mainBus_to_system_ram_up_up_bus_a_payload_opcode_string = "GET             ";
      A_ACQUIRE_BLOCK : system_mainBus_to_system_ram_up_up_bus_a_payload_opcode_string = "ACQUIRE_BLOCK   ";
      A_ACQUIRE_PERM : system_mainBus_to_system_ram_up_up_bus_a_payload_opcode_string = "ACQUIRE_PERM    ";
      default : system_mainBus_to_system_ram_up_up_bus_a_payload_opcode_string = "????????????????";
    endcase
  end
  always @(*) begin
    case(system_mainBus_to_system_ram_up_up_bus_d_payload_opcode)
      D_ACCESS_ACK : system_mainBus_to_system_ram_up_up_bus_d_payload_opcode_string = "ACCESS_ACK     ";
      D_ACCESS_ACK_DATA : system_mainBus_to_system_ram_up_up_bus_d_payload_opcode_string = "ACCESS_ACK_DATA";
      D_GRANT : system_mainBus_to_system_ram_up_up_bus_d_payload_opcode_string = "GRANT          ";
      D_GRANT_DATA : system_mainBus_to_system_ram_up_up_bus_d_payload_opcode_string = "GRANT_DATA     ";
      D_RELEASE_ACK : system_mainBus_to_system_ram_up_up_bus_d_payload_opcode_string = "RELEASE_ACK    ";
      default : system_mainBus_to_system_ram_up_up_bus_d_payload_opcode_string = "???????????????";
    endcase
  end
  always @(*) begin
    case(system_mainBus_to_system_peripheral_busXlen_up_bus_a_payload_opcode)
      A_PUT_FULL_DATA : system_mainBus_to_system_peripheral_busXlen_up_bus_a_payload_opcode_string = "PUT_FULL_DATA   ";
      A_PUT_PARTIAL_DATA : system_mainBus_to_system_peripheral_busXlen_up_bus_a_payload_opcode_string = "PUT_PARTIAL_DATA";
      A_ARITHMETIC_DATA : system_mainBus_to_system_peripheral_busXlen_up_bus_a_payload_opcode_string = "ARITHMETIC_DATA ";
      A_LOGICAL_DATA : system_mainBus_to_system_peripheral_busXlen_up_bus_a_payload_opcode_string = "LOGICAL_DATA    ";
      A_GET : system_mainBus_to_system_peripheral_busXlen_up_bus_a_payload_opcode_string = "GET             ";
      A_ACQUIRE_BLOCK : system_mainBus_to_system_peripheral_busXlen_up_bus_a_payload_opcode_string = "ACQUIRE_BLOCK   ";
      A_ACQUIRE_PERM : system_mainBus_to_system_peripheral_busXlen_up_bus_a_payload_opcode_string = "ACQUIRE_PERM    ";
      default : system_mainBus_to_system_peripheral_busXlen_up_bus_a_payload_opcode_string = "????????????????";
    endcase
  end
  always @(*) begin
    case(system_mainBus_to_system_peripheral_busXlen_up_bus_d_payload_opcode)
      D_ACCESS_ACK : system_mainBus_to_system_peripheral_busXlen_up_bus_d_payload_opcode_string = "ACCESS_ACK     ";
      D_ACCESS_ACK_DATA : system_mainBus_to_system_peripheral_busXlen_up_bus_d_payload_opcode_string = "ACCESS_ACK_DATA";
      D_GRANT : system_mainBus_to_system_peripheral_busXlen_up_bus_d_payload_opcode_string = "GRANT          ";
      D_GRANT_DATA : system_mainBus_to_system_peripheral_busXlen_up_bus_d_payload_opcode_string = "GRANT_DATA     ";
      D_RELEASE_ACK : system_mainBus_to_system_peripheral_busXlen_up_bus_d_payload_opcode_string = "RELEASE_ACK    ";
      default : system_mainBus_to_system_peripheral_busXlen_up_bus_d_payload_opcode_string = "???????????????";
    endcase
  end
  always @(*) begin
    case(system_peripheral_bus32_to_system_peripheral_plic_node_up_bus_a_payload_opcode)
      A_PUT_FULL_DATA : system_peripheral_bus32_to_system_peripheral_plic_node_up_bus_a_payload_opcode_string = "PUT_FULL_DATA   ";
      A_PUT_PARTIAL_DATA : system_peripheral_bus32_to_system_peripheral_plic_node_up_bus_a_payload_opcode_string = "PUT_PARTIAL_DATA";
      A_ARITHMETIC_DATA : system_peripheral_bus32_to_system_peripheral_plic_node_up_bus_a_payload_opcode_string = "ARITHMETIC_DATA ";
      A_LOGICAL_DATA : system_peripheral_bus32_to_system_peripheral_plic_node_up_bus_a_payload_opcode_string = "LOGICAL_DATA    ";
      A_GET : system_peripheral_bus32_to_system_peripheral_plic_node_up_bus_a_payload_opcode_string = "GET             ";
      A_ACQUIRE_BLOCK : system_peripheral_bus32_to_system_peripheral_plic_node_up_bus_a_payload_opcode_string = "ACQUIRE_BLOCK   ";
      A_ACQUIRE_PERM : system_peripheral_bus32_to_system_peripheral_plic_node_up_bus_a_payload_opcode_string = "ACQUIRE_PERM    ";
      default : system_peripheral_bus32_to_system_peripheral_plic_node_up_bus_a_payload_opcode_string = "????????????????";
    endcase
  end
  always @(*) begin
    case(system_peripheral_bus32_to_system_peripheral_plic_node_up_bus_d_payload_opcode)
      D_ACCESS_ACK : system_peripheral_bus32_to_system_peripheral_plic_node_up_bus_d_payload_opcode_string = "ACCESS_ACK     ";
      D_ACCESS_ACK_DATA : system_peripheral_bus32_to_system_peripheral_plic_node_up_bus_d_payload_opcode_string = "ACCESS_ACK_DATA";
      D_GRANT : system_peripheral_bus32_to_system_peripheral_plic_node_up_bus_d_payload_opcode_string = "GRANT          ";
      D_GRANT_DATA : system_peripheral_bus32_to_system_peripheral_plic_node_up_bus_d_payload_opcode_string = "GRANT_DATA     ";
      D_RELEASE_ACK : system_peripheral_bus32_to_system_peripheral_plic_node_up_bus_d_payload_opcode_string = "RELEASE_ACK    ";
      default : system_peripheral_bus32_to_system_peripheral_plic_node_up_bus_d_payload_opcode_string = "???????????????";
    endcase
  end
  always @(*) begin
    case(system_peripheral_bus32_to_system_peripheral_uart_node_up_bus_a_payload_opcode)
      A_PUT_FULL_DATA : system_peripheral_bus32_to_system_peripheral_uart_node_up_bus_a_payload_opcode_string = "PUT_FULL_DATA   ";
      A_PUT_PARTIAL_DATA : system_peripheral_bus32_to_system_peripheral_uart_node_up_bus_a_payload_opcode_string = "PUT_PARTIAL_DATA";
      A_ARITHMETIC_DATA : system_peripheral_bus32_to_system_peripheral_uart_node_up_bus_a_payload_opcode_string = "ARITHMETIC_DATA ";
      A_LOGICAL_DATA : system_peripheral_bus32_to_system_peripheral_uart_node_up_bus_a_payload_opcode_string = "LOGICAL_DATA    ";
      A_GET : system_peripheral_bus32_to_system_peripheral_uart_node_up_bus_a_payload_opcode_string = "GET             ";
      A_ACQUIRE_BLOCK : system_peripheral_bus32_to_system_peripheral_uart_node_up_bus_a_payload_opcode_string = "ACQUIRE_BLOCK   ";
      A_ACQUIRE_PERM : system_peripheral_bus32_to_system_peripheral_uart_node_up_bus_a_payload_opcode_string = "ACQUIRE_PERM    ";
      default : system_peripheral_bus32_to_system_peripheral_uart_node_up_bus_a_payload_opcode_string = "????????????????";
    endcase
  end
  always @(*) begin
    case(system_peripheral_bus32_to_system_peripheral_uart_node_up_bus_d_payload_opcode)
      D_ACCESS_ACK : system_peripheral_bus32_to_system_peripheral_uart_node_up_bus_d_payload_opcode_string = "ACCESS_ACK     ";
      D_ACCESS_ACK_DATA : system_peripheral_bus32_to_system_peripheral_uart_node_up_bus_d_payload_opcode_string = "ACCESS_ACK_DATA";
      D_GRANT : system_peripheral_bus32_to_system_peripheral_uart_node_up_bus_d_payload_opcode_string = "GRANT          ";
      D_GRANT_DATA : system_peripheral_bus32_to_system_peripheral_uart_node_up_bus_d_payload_opcode_string = "GRANT_DATA     ";
      D_RELEASE_ACK : system_peripheral_bus32_to_system_peripheral_uart_node_up_bus_d_payload_opcode_string = "RELEASE_ACK    ";
      default : system_peripheral_bus32_to_system_peripheral_uart_node_up_bus_d_payload_opcode_string = "???????????????";
    endcase
  end
  always @(*) begin
    case(system_peripheral_bus32_to_system_peripheral_demo_node_up_bus_a_payload_opcode)
      A_PUT_FULL_DATA : system_peripheral_bus32_to_system_peripheral_demo_node_up_bus_a_payload_opcode_string = "PUT_FULL_DATA   ";
      A_PUT_PARTIAL_DATA : system_peripheral_bus32_to_system_peripheral_demo_node_up_bus_a_payload_opcode_string = "PUT_PARTIAL_DATA";
      A_ARITHMETIC_DATA : system_peripheral_bus32_to_system_peripheral_demo_node_up_bus_a_payload_opcode_string = "ARITHMETIC_DATA ";
      A_LOGICAL_DATA : system_peripheral_bus32_to_system_peripheral_demo_node_up_bus_a_payload_opcode_string = "LOGICAL_DATA    ";
      A_GET : system_peripheral_bus32_to_system_peripheral_demo_node_up_bus_a_payload_opcode_string = "GET             ";
      A_ACQUIRE_BLOCK : system_peripheral_bus32_to_system_peripheral_demo_node_up_bus_a_payload_opcode_string = "ACQUIRE_BLOCK   ";
      A_ACQUIRE_PERM : system_peripheral_bus32_to_system_peripheral_demo_node_up_bus_a_payload_opcode_string = "ACQUIRE_PERM    ";
      default : system_peripheral_bus32_to_system_peripheral_demo_node_up_bus_a_payload_opcode_string = "????????????????";
    endcase
  end
  always @(*) begin
    case(system_peripheral_bus32_to_system_peripheral_demo_node_up_bus_d_payload_opcode)
      D_ACCESS_ACK : system_peripheral_bus32_to_system_peripheral_demo_node_up_bus_d_payload_opcode_string = "ACCESS_ACK     ";
      D_ACCESS_ACK_DATA : system_peripheral_bus32_to_system_peripheral_demo_node_up_bus_d_payload_opcode_string = "ACCESS_ACK_DATA";
      D_GRANT : system_peripheral_bus32_to_system_peripheral_demo_node_up_bus_d_payload_opcode_string = "GRANT          ";
      D_GRANT_DATA : system_peripheral_bus32_to_system_peripheral_demo_node_up_bus_d_payload_opcode_string = "GRANT_DATA     ";
      D_RELEASE_ACK : system_peripheral_bus32_to_system_peripheral_demo_node_up_bus_d_payload_opcode_string = "RELEASE_ACK    ";
      default : system_peripheral_bus32_to_system_peripheral_demo_node_up_bus_d_payload_opcode_string = "???????????????";
    endcase
  end
  `endif

  assign system_cpu_priv_rdtime = _zz_system_cpu_priv_rdtime;
  assign socCtrl_debug_fiber_aggregator_reset = (|socCtrl_debug_fiber_aggregator_asyncBuffers_0_io_dataOut);
  assign socCtrl_debug_fiber_holder_reset = ((socCtrl_debug_fiber_holder_counter != 7'h40) ^ 1'b0);
  assign when_CrossClock_l341 = (socCtrl_debug_fiber_holder_reset == 1'b1);
  assign socCtrl_debug_reset = socCtrl_debug_fiber_buffer_io_dataOut;
  assign socCtrl_system_fiber_aggregator_reset = (|socCtrl_system_fiber_aggregator_asyncBuffers_0_io_dataOut);
  assign socCtrl_system_fiber_holder_reset = ((socCtrl_system_fiber_holder_counter != 7'h40) ^ 1'b0);
  assign when_CrossClock_l341_1 = (socCtrl_system_fiber_holder_reset == 1'b1);
  assign socCtrl_system_reset = socCtrl_system_fiber_buffer_io_dataOut;
  assign system_cpu_priv_mti_thread_gateways_0_flag = system_peripheral_clint_thread_core_io_timerInterrupt[0];
  assign system_cpu_priv_mti_flag = (|system_cpu_priv_mti_thread_gateways_0_flag);
  assign system_cpu_priv_msi_thread_gateways_0_flag = system_peripheral_clint_thread_core_io_softwareInterrupt[0];
  assign system_cpu_priv_msi_flag = (|system_cpu_priv_msi_thread_gateways_0_flag);
  assign system_cpu_priv_mei_thread_gateways_0_flag = system_peripheral_plic_to_system_cpu_priv_mei_flag;
  assign system_cpu_priv_mei_flag = (|system_cpu_priv_mei_thread_gateways_0_flag);
  assign system_peripheral_plic_from_system_peripheral_uart_interrupt_thread_gateways_0_flag = system_peripheral_uart_interrupt_flag;
  assign system_peripheral_plic_from_system_peripheral_uart_interrupt_flag = (|system_peripheral_plic_from_system_peripheral_uart_interrupt_thread_gateways_0_flag);
  assign system_peripheral_plic_from_system_peripheral_demo_interrupt_thread_gateways_0_flag = system_peripheral_demo_interrupt_flag;
  assign system_peripheral_plic_from_system_peripheral_demo_interrupt_flag = (|system_peripheral_plic_from_system_peripheral_demo_interrupt_thread_gateways_0_flag);
  assign system_cpu_iBus_noDecoder_toDown_a_valid = system_cpu_iBus_bus_a_valid;
  assign system_cpu_iBus_bus_a_ready = system_cpu_iBus_noDecoder_toDown_a_ready;
  assign system_cpu_iBus_noDecoder_toDown_a_payload_opcode = system_cpu_iBus_bus_a_payload_opcode;
  assign system_cpu_iBus_noDecoder_toDown_a_payload_param = system_cpu_iBus_bus_a_payload_param;
  assign system_cpu_iBus_noDecoder_toDown_a_payload_source = system_cpu_iBus_bus_a_payload_source;
  assign system_cpu_iBus_noDecoder_toDown_a_payload_address = system_cpu_iBus_bus_a_payload_address;
  assign system_cpu_iBus_noDecoder_toDown_a_payload_size = system_cpu_iBus_bus_a_payload_size;
  assign system_cpu_iBus_bus_d_valid = system_cpu_iBus_noDecoder_toDown_d_valid;
  assign system_cpu_iBus_noDecoder_toDown_d_ready = system_cpu_iBus_bus_d_ready;
  assign system_cpu_iBus_bus_d_payload_opcode = system_cpu_iBus_noDecoder_toDown_d_payload_opcode;
  assign system_cpu_iBus_bus_d_payload_param = system_cpu_iBus_noDecoder_toDown_d_payload_param;
  assign system_cpu_iBus_bus_d_payload_source = system_cpu_iBus_noDecoder_toDown_d_payload_source;
  assign system_cpu_iBus_bus_d_payload_size = system_cpu_iBus_noDecoder_toDown_d_payload_size;
  assign system_cpu_iBus_bus_d_payload_denied = system_cpu_iBus_noDecoder_toDown_d_payload_denied;
  assign system_cpu_iBus_bus_d_payload_data = system_cpu_iBus_noDecoder_toDown_d_payload_data;
  assign system_cpu_iBus_bus_d_payload_corrupt = system_cpu_iBus_noDecoder_toDown_d_payload_corrupt;
  assign system_cpu_dBus_bus_a_ready = system_cpu_dBus_bus_a_rValidN;
  assign system_cpu_dBus_bus_a_s2mPipe_valid = (system_cpu_dBus_bus_a_valid || (! system_cpu_dBus_bus_a_rValidN));
  assign _zz_system_cpu_dBus_bus_a_s2mPipe_payload_opcode = (system_cpu_dBus_bus_a_rValidN ? system_cpu_dBus_bus_a_payload_opcode : system_cpu_dBus_bus_a_rData_opcode);
  assign system_cpu_dBus_bus_a_s2mPipe_payload_opcode = _zz_system_cpu_dBus_bus_a_s2mPipe_payload_opcode;
  assign system_cpu_dBus_bus_a_s2mPipe_payload_param = (system_cpu_dBus_bus_a_rValidN ? system_cpu_dBus_bus_a_payload_param : system_cpu_dBus_bus_a_rData_param);
  assign system_cpu_dBus_bus_a_s2mPipe_payload_address = (system_cpu_dBus_bus_a_rValidN ? system_cpu_dBus_bus_a_payload_address : system_cpu_dBus_bus_a_rData_address);
  assign system_cpu_dBus_bus_a_s2mPipe_payload_size = (system_cpu_dBus_bus_a_rValidN ? system_cpu_dBus_bus_a_payload_size : system_cpu_dBus_bus_a_rData_size);
  assign system_cpu_dBus_bus_a_s2mPipe_payload_mask = (system_cpu_dBus_bus_a_rValidN ? system_cpu_dBus_bus_a_payload_mask : system_cpu_dBus_bus_a_rData_mask);
  assign system_cpu_dBus_bus_a_s2mPipe_payload_data = (system_cpu_dBus_bus_a_rValidN ? system_cpu_dBus_bus_a_payload_data : system_cpu_dBus_bus_a_rData_data);
  assign system_cpu_dBus_bus_a_s2mPipe_payload_corrupt = (system_cpu_dBus_bus_a_rValidN ? system_cpu_dBus_bus_a_payload_corrupt : system_cpu_dBus_bus_a_rData_corrupt);
  assign system_cpu_dBus_noDecoder_toDown_a_valid = system_cpu_dBus_bus_a_s2mPipe_valid;
  assign system_cpu_dBus_bus_a_s2mPipe_ready = system_cpu_dBus_noDecoder_toDown_a_ready;
  assign system_cpu_dBus_noDecoder_toDown_a_payload_opcode = system_cpu_dBus_bus_a_s2mPipe_payload_opcode;
  assign system_cpu_dBus_noDecoder_toDown_a_payload_param = system_cpu_dBus_bus_a_s2mPipe_payload_param;
  assign system_cpu_dBus_noDecoder_toDown_a_payload_address = system_cpu_dBus_bus_a_s2mPipe_payload_address;
  assign system_cpu_dBus_noDecoder_toDown_a_payload_size = system_cpu_dBus_bus_a_s2mPipe_payload_size;
  assign system_cpu_dBus_noDecoder_toDown_a_payload_mask = system_cpu_dBus_bus_a_s2mPipe_payload_mask;
  assign system_cpu_dBus_noDecoder_toDown_a_payload_data = system_cpu_dBus_bus_a_s2mPipe_payload_data;
  assign system_cpu_dBus_noDecoder_toDown_a_payload_corrupt = system_cpu_dBus_bus_a_s2mPipe_payload_corrupt;
  assign system_cpu_dBus_noDecoder_toDown_d_combStage_valid = system_cpu_dBus_noDecoder_toDown_d_valid;
  assign system_cpu_dBus_noDecoder_toDown_d_ready = system_cpu_dBus_noDecoder_toDown_d_combStage_ready;
  assign system_cpu_dBus_noDecoder_toDown_d_combStage_payload_opcode = system_cpu_dBus_noDecoder_toDown_d_payload_opcode;
  assign system_cpu_dBus_noDecoder_toDown_d_combStage_payload_param = system_cpu_dBus_noDecoder_toDown_d_payload_param;
  assign system_cpu_dBus_noDecoder_toDown_d_combStage_payload_size = system_cpu_dBus_noDecoder_toDown_d_payload_size;
  assign system_cpu_dBus_noDecoder_toDown_d_combStage_payload_denied = system_cpu_dBus_noDecoder_toDown_d_payload_denied;
  assign system_cpu_dBus_noDecoder_toDown_d_combStage_payload_data = system_cpu_dBus_noDecoder_toDown_d_payload_data;
  assign system_cpu_dBus_noDecoder_toDown_d_combStage_payload_corrupt = system_cpu_dBus_noDecoder_toDown_d_payload_corrupt;
  assign system_cpu_dBus_bus_d_valid = system_cpu_dBus_noDecoder_toDown_d_combStage_valid;
  assign system_cpu_dBus_noDecoder_toDown_d_combStage_ready = system_cpu_dBus_bus_d_ready;
  assign system_cpu_dBus_bus_d_payload_opcode = system_cpu_dBus_noDecoder_toDown_d_combStage_payload_opcode;
  assign system_cpu_dBus_bus_d_payload_param = system_cpu_dBus_noDecoder_toDown_d_combStage_payload_param;
  assign system_cpu_dBus_bus_d_payload_size = system_cpu_dBus_noDecoder_toDown_d_combStage_payload_size;
  assign system_cpu_dBus_bus_d_payload_denied = system_cpu_dBus_noDecoder_toDown_d_combStage_payload_denied;
  assign system_cpu_dBus_bus_d_payload_data = system_cpu_dBus_noDecoder_toDown_d_combStage_payload_data;
  assign system_cpu_dBus_bus_d_payload_corrupt = system_cpu_dBus_noDecoder_toDown_d_combStage_payload_corrupt;
  assign system_cpu_lsuL1Bus_noDecoder_toDown_a_valid = system_cpu_lsuL1Bus_bus_a_valid;
  assign system_cpu_lsuL1Bus_bus_a_ready = system_cpu_lsuL1Bus_noDecoder_toDown_a_ready;
  assign system_cpu_lsuL1Bus_noDecoder_toDown_a_payload_opcode = system_cpu_lsuL1Bus_bus_a_payload_opcode;
  assign system_cpu_lsuL1Bus_noDecoder_toDown_a_payload_param = system_cpu_lsuL1Bus_bus_a_payload_param;
  assign system_cpu_lsuL1Bus_noDecoder_toDown_a_payload_source = system_cpu_lsuL1Bus_bus_a_payload_source;
  assign system_cpu_lsuL1Bus_noDecoder_toDown_a_payload_address = system_cpu_lsuL1Bus_bus_a_payload_address;
  assign system_cpu_lsuL1Bus_noDecoder_toDown_a_payload_size = system_cpu_lsuL1Bus_bus_a_payload_size;
  assign system_cpu_lsuL1Bus_noDecoder_toDown_a_payload_mask = system_cpu_lsuL1Bus_bus_a_payload_mask;
  assign system_cpu_lsuL1Bus_noDecoder_toDown_a_payload_data = system_cpu_lsuL1Bus_bus_a_payload_data;
  assign system_cpu_lsuL1Bus_noDecoder_toDown_a_payload_corrupt = system_cpu_lsuL1Bus_bus_a_payload_corrupt;
  assign system_cpu_lsuL1Bus_bus_d_valid = system_cpu_lsuL1Bus_noDecoder_toDown_d_valid;
  assign system_cpu_lsuL1Bus_noDecoder_toDown_d_ready = system_cpu_lsuL1Bus_bus_d_ready;
  assign system_cpu_lsuL1Bus_bus_d_payload_opcode = system_cpu_lsuL1Bus_noDecoder_toDown_d_payload_opcode;
  assign system_cpu_lsuL1Bus_bus_d_payload_param = system_cpu_lsuL1Bus_noDecoder_toDown_d_payload_param;
  assign system_cpu_lsuL1Bus_bus_d_payload_source = system_cpu_lsuL1Bus_noDecoder_toDown_d_payload_source;
  assign system_cpu_lsuL1Bus_bus_d_payload_size = system_cpu_lsuL1Bus_noDecoder_toDown_d_payload_size;
  assign system_cpu_lsuL1Bus_bus_d_payload_denied = system_cpu_lsuL1Bus_noDecoder_toDown_d_payload_denied;
  assign system_cpu_lsuL1Bus_bus_d_payload_data = system_cpu_lsuL1Bus_noDecoder_toDown_d_payload_data;
  assign system_cpu_lsuL1Bus_bus_d_payload_corrupt = system_cpu_lsuL1Bus_noDecoder_toDown_d_payload_corrupt;
  assign system_cpu_iBus_bus_a_valid = system_cpu_logic_core_FetchL1TileLinkPlugin_logic_down_a_valid;
  assign system_cpu_iBus_bus_a_payload_opcode = system_cpu_logic_core_FetchL1TileLinkPlugin_logic_down_a_payload_opcode;
  assign system_cpu_iBus_bus_a_payload_param = system_cpu_logic_core_FetchL1TileLinkPlugin_logic_down_a_payload_param;
  assign system_cpu_iBus_bus_a_payload_source = system_cpu_logic_core_FetchL1TileLinkPlugin_logic_down_a_payload_source;
  assign system_cpu_iBus_bus_a_payload_address = system_cpu_logic_core_FetchL1TileLinkPlugin_logic_down_a_payload_address;
  assign system_cpu_iBus_bus_a_payload_size = system_cpu_logic_core_FetchL1TileLinkPlugin_logic_down_a_payload_size;
  assign system_cpu_iBus_bus_d_ready = system_cpu_logic_core_FetchL1TileLinkPlugin_logic_down_d_ready;
  assign system_cpu_iBus_to_system_mainBus_down_bus_a_ready = system_mainBus_arbiter_core_io_ups_0_a_ready;
  assign system_cpu_iBus_to_system_mainBus_down_bus_d_valid = system_mainBus_arbiter_core_io_ups_0_d_valid;
  assign system_cpu_iBus_to_system_mainBus_down_bus_d_payload_opcode = system_mainBus_arbiter_core_io_ups_0_d_payload_opcode;
  assign system_cpu_iBus_to_system_mainBus_down_bus_d_payload_param = system_mainBus_arbiter_core_io_ups_0_d_payload_param;
  assign system_cpu_iBus_to_system_mainBus_down_bus_d_payload_source = system_mainBus_arbiter_core_io_ups_0_d_payload_source;
  assign system_cpu_iBus_to_system_mainBus_down_bus_d_payload_size = system_mainBus_arbiter_core_io_ups_0_d_payload_size;
  assign system_cpu_iBus_to_system_mainBus_down_bus_d_payload_denied = system_mainBus_arbiter_core_io_ups_0_d_payload_denied;
  assign system_cpu_iBus_to_system_mainBus_down_bus_d_payload_data = system_mainBus_arbiter_core_io_ups_0_d_payload_data;
  assign system_cpu_iBus_to_system_mainBus_down_bus_d_payload_corrupt = system_mainBus_arbiter_core_io_ups_0_d_payload_corrupt;
  assign system_cpu_dBus_to_system_mainBus_down_bus_a_ready = system_mainBus_arbiter_core_io_ups_1_a_ready;
  assign system_cpu_dBus_to_system_mainBus_down_bus_d_valid = system_mainBus_arbiter_core_io_ups_1_d_valid;
  assign system_cpu_dBus_to_system_mainBus_down_bus_d_payload_opcode = system_mainBus_arbiter_core_io_ups_1_d_payload_opcode;
  assign system_cpu_dBus_to_system_mainBus_down_bus_d_payload_param = system_mainBus_arbiter_core_io_ups_1_d_payload_param;
  assign system_cpu_dBus_to_system_mainBus_down_bus_d_payload_size = system_mainBus_arbiter_core_io_ups_1_d_payload_size;
  assign system_cpu_dBus_to_system_mainBus_down_bus_d_payload_denied = system_mainBus_arbiter_core_io_ups_1_d_payload_denied;
  assign system_cpu_dBus_to_system_mainBus_down_bus_d_payload_data = system_mainBus_arbiter_core_io_ups_1_d_payload_data;
  assign system_cpu_dBus_to_system_mainBus_down_bus_d_payload_corrupt = system_mainBus_arbiter_core_io_ups_1_d_payload_corrupt;
  assign system_cpu_lsuL1Bus_to_system_mainBus_down_bus_a_ready = system_mainBus_arbiter_core_io_ups_2_a_ready;
  assign system_cpu_lsuL1Bus_to_system_mainBus_down_bus_d_valid = system_mainBus_arbiter_core_io_ups_2_d_valid;
  assign system_cpu_lsuL1Bus_to_system_mainBus_down_bus_d_payload_opcode = system_mainBus_arbiter_core_io_ups_2_d_payload_opcode;
  assign system_cpu_lsuL1Bus_to_system_mainBus_down_bus_d_payload_param = system_mainBus_arbiter_core_io_ups_2_d_payload_param;
  assign system_cpu_lsuL1Bus_to_system_mainBus_down_bus_d_payload_source = system_mainBus_arbiter_core_io_ups_2_d_payload_source;
  assign system_cpu_lsuL1Bus_to_system_mainBus_down_bus_d_payload_size = system_mainBus_arbiter_core_io_ups_2_d_payload_size;
  assign system_cpu_lsuL1Bus_to_system_mainBus_down_bus_d_payload_denied = system_mainBus_arbiter_core_io_ups_2_d_payload_denied;
  assign system_cpu_lsuL1Bus_to_system_mainBus_down_bus_d_payload_data = system_mainBus_arbiter_core_io_ups_2_d_payload_data;
  assign system_cpu_lsuL1Bus_to_system_mainBus_down_bus_d_payload_corrupt = system_mainBus_arbiter_core_io_ups_2_d_payload_corrupt;
  assign system_mainBus_bus_a_valid = system_mainBus_arbiter_core_io_down_a_valid;
  assign system_mainBus_bus_a_payload_opcode = system_mainBus_arbiter_core_io_down_a_payload_opcode;
  assign system_mainBus_bus_a_payload_param = system_mainBus_arbiter_core_io_down_a_payload_param;
  assign system_mainBus_bus_a_payload_source = system_mainBus_arbiter_core_io_down_a_payload_source;
  assign system_mainBus_bus_a_payload_address = system_mainBus_arbiter_core_io_down_a_payload_address;
  assign system_mainBus_bus_a_payload_size = system_mainBus_arbiter_core_io_down_a_payload_size;
  assign system_mainBus_bus_a_payload_mask = system_mainBus_arbiter_core_io_down_a_payload_mask;
  assign system_mainBus_bus_a_payload_data = system_mainBus_arbiter_core_io_down_a_payload_data;
  assign system_mainBus_bus_a_payload_corrupt = system_mainBus_arbiter_core_io_down_a_payload_corrupt;
  assign system_mainBus_bus_d_ready = system_mainBus_arbiter_core_io_down_d_ready;
  assign system_cpu_lsuL1Bus_bus_a_valid = system_cpu_logic_core_LsuL1TileLinkPlugin_logic_down_a_valid;
  assign system_cpu_lsuL1Bus_bus_a_payload_opcode = system_cpu_logic_core_LsuL1TileLinkPlugin_logic_down_a_payload_opcode;
  assign system_cpu_lsuL1Bus_bus_a_payload_param = system_cpu_logic_core_LsuL1TileLinkPlugin_logic_down_a_payload_param;
  assign system_cpu_lsuL1Bus_bus_a_payload_source = system_cpu_logic_core_LsuL1TileLinkPlugin_logic_down_a_payload_source;
  assign system_cpu_lsuL1Bus_bus_a_payload_address = system_cpu_logic_core_LsuL1TileLinkPlugin_logic_down_a_payload_address;
  assign system_cpu_lsuL1Bus_bus_a_payload_size = system_cpu_logic_core_LsuL1TileLinkPlugin_logic_down_a_payload_size;
  assign system_cpu_lsuL1Bus_bus_a_payload_mask = system_cpu_logic_core_LsuL1TileLinkPlugin_logic_down_a_payload_mask;
  assign system_cpu_lsuL1Bus_bus_a_payload_data = system_cpu_logic_core_LsuL1TileLinkPlugin_logic_down_a_payload_data;
  assign system_cpu_lsuL1Bus_bus_a_payload_corrupt = system_cpu_logic_core_LsuL1TileLinkPlugin_logic_down_a_payload_corrupt;
  assign system_cpu_lsuL1Bus_bus_d_ready = system_cpu_logic_core_LsuL1TileLinkPlugin_logic_down_d_ready;
  assign system_ram_up_bus_a_valid = system_mainBus_to_system_ram_up_down_bus_a_valid;
  assign system_mainBus_to_system_ram_up_down_bus_a_ready = system_ram_up_bus_a_ready;
  assign system_ram_up_bus_a_payload_opcode = system_mainBus_to_system_ram_up_down_bus_a_payload_opcode;
  assign system_ram_up_bus_a_payload_param = system_mainBus_to_system_ram_up_down_bus_a_payload_param;
  assign system_ram_up_bus_a_payload_source = system_mainBus_to_system_ram_up_down_bus_a_payload_source;
  assign system_ram_up_bus_a_payload_address = system_mainBus_to_system_ram_up_down_bus_a_payload_address;
  assign system_ram_up_bus_a_payload_size = system_mainBus_to_system_ram_up_down_bus_a_payload_size;
  assign system_ram_up_bus_a_payload_mask = system_mainBus_to_system_ram_up_down_bus_a_payload_mask;
  assign system_ram_up_bus_a_payload_data = system_mainBus_to_system_ram_up_down_bus_a_payload_data;
  assign system_ram_up_bus_a_payload_corrupt = system_mainBus_to_system_ram_up_down_bus_a_payload_corrupt;
  assign system_mainBus_to_system_ram_up_down_bus_d_valid = system_ram_up_bus_d_valid;
  assign system_ram_up_bus_d_ready = system_mainBus_to_system_ram_up_down_bus_d_ready;
  assign system_mainBus_to_system_ram_up_down_bus_d_payload_opcode = system_ram_up_bus_d_payload_opcode;
  assign system_mainBus_to_system_ram_up_down_bus_d_payload_param = system_ram_up_bus_d_payload_param;
  assign system_mainBus_to_system_ram_up_down_bus_d_payload_source = system_ram_up_bus_d_payload_source;
  assign system_mainBus_to_system_ram_up_down_bus_d_payload_size = system_ram_up_bus_d_payload_size;
  assign system_mainBus_to_system_ram_up_down_bus_d_payload_denied = system_ram_up_bus_d_payload_denied;
  assign system_mainBus_to_system_ram_up_down_bus_d_payload_data = system_ram_up_bus_d_payload_data;
  assign system_mainBus_to_system_ram_up_down_bus_d_payload_corrupt = system_ram_up_bus_d_payload_corrupt;
  assign system_mainBus_to_system_peripheral_busXlen_down_bus_a_halfPipe_fire = (system_mainBus_to_system_peripheral_busXlen_down_bus_a_halfPipe_valid && system_mainBus_to_system_peripheral_busXlen_down_bus_a_halfPipe_ready);
  assign system_mainBus_to_system_peripheral_busXlen_down_bus_a_ready = (! system_mainBus_to_system_peripheral_busXlen_down_bus_a_rValid);
  assign system_mainBus_to_system_peripheral_busXlen_down_bus_a_halfPipe_valid = system_mainBus_to_system_peripheral_busXlen_down_bus_a_rValid;
  assign system_mainBus_to_system_peripheral_busXlen_down_bus_a_halfPipe_payload_opcode = system_mainBus_to_system_peripheral_busXlen_down_bus_a_rData_opcode;
  assign system_mainBus_to_system_peripheral_busXlen_down_bus_a_halfPipe_payload_param = system_mainBus_to_system_peripheral_busXlen_down_bus_a_rData_param;
  assign system_mainBus_to_system_peripheral_busXlen_down_bus_a_halfPipe_payload_source = system_mainBus_to_system_peripheral_busXlen_down_bus_a_rData_source;
  assign system_mainBus_to_system_peripheral_busXlen_down_bus_a_halfPipe_payload_address = system_mainBus_to_system_peripheral_busXlen_down_bus_a_rData_address;
  assign system_mainBus_to_system_peripheral_busXlen_down_bus_a_halfPipe_payload_size = system_mainBus_to_system_peripheral_busXlen_down_bus_a_rData_size;
  assign system_mainBus_to_system_peripheral_busXlen_down_bus_a_halfPipe_payload_mask = system_mainBus_to_system_peripheral_busXlen_down_bus_a_rData_mask;
  assign system_mainBus_to_system_peripheral_busXlen_down_bus_a_halfPipe_payload_data = system_mainBus_to_system_peripheral_busXlen_down_bus_a_rData_data;
  assign system_mainBus_to_system_peripheral_busXlen_down_bus_a_halfPipe_payload_corrupt = system_mainBus_to_system_peripheral_busXlen_down_bus_a_rData_corrupt;
  assign system_peripheral_busXlen_bus_a_valid = system_mainBus_to_system_peripheral_busXlen_down_bus_a_halfPipe_valid;
  assign system_mainBus_to_system_peripheral_busXlen_down_bus_a_halfPipe_ready = system_peripheral_busXlen_bus_a_ready;
  assign system_peripheral_busXlen_bus_a_payload_opcode = system_mainBus_to_system_peripheral_busXlen_down_bus_a_halfPipe_payload_opcode;
  assign system_peripheral_busXlen_bus_a_payload_param = system_mainBus_to_system_peripheral_busXlen_down_bus_a_halfPipe_payload_param;
  assign system_peripheral_busXlen_bus_a_payload_source = system_mainBus_to_system_peripheral_busXlen_down_bus_a_halfPipe_payload_source;
  assign system_peripheral_busXlen_bus_a_payload_address = system_mainBus_to_system_peripheral_busXlen_down_bus_a_halfPipe_payload_address;
  assign system_peripheral_busXlen_bus_a_payload_size = system_mainBus_to_system_peripheral_busXlen_down_bus_a_halfPipe_payload_size;
  assign system_peripheral_busXlen_bus_a_payload_mask = system_mainBus_to_system_peripheral_busXlen_down_bus_a_halfPipe_payload_mask;
  assign system_peripheral_busXlen_bus_a_payload_data = system_mainBus_to_system_peripheral_busXlen_down_bus_a_halfPipe_payload_data;
  assign system_peripheral_busXlen_bus_a_payload_corrupt = system_mainBus_to_system_peripheral_busXlen_down_bus_a_halfPipe_payload_corrupt;
  assign system_peripheral_busXlen_bus_d_halfPipe_fire = (system_peripheral_busXlen_bus_d_halfPipe_valid && system_peripheral_busXlen_bus_d_halfPipe_ready);
  assign system_peripheral_busXlen_bus_d_ready = (! system_peripheral_busXlen_bus_d_rValid);
  assign system_peripheral_busXlen_bus_d_halfPipe_valid = system_peripheral_busXlen_bus_d_rValid;
  assign system_peripheral_busXlen_bus_d_halfPipe_payload_opcode = system_peripheral_busXlen_bus_d_rData_opcode;
  assign system_peripheral_busXlen_bus_d_halfPipe_payload_param = system_peripheral_busXlen_bus_d_rData_param;
  assign system_peripheral_busXlen_bus_d_halfPipe_payload_source = system_peripheral_busXlen_bus_d_rData_source;
  assign system_peripheral_busXlen_bus_d_halfPipe_payload_size = system_peripheral_busXlen_bus_d_rData_size;
  assign system_peripheral_busXlen_bus_d_halfPipe_payload_denied = system_peripheral_busXlen_bus_d_rData_denied;
  assign system_peripheral_busXlen_bus_d_halfPipe_payload_data = system_peripheral_busXlen_bus_d_rData_data;
  assign system_peripheral_busXlen_bus_d_halfPipe_payload_corrupt = system_peripheral_busXlen_bus_d_rData_corrupt;
  assign system_mainBus_to_system_peripheral_busXlen_down_bus_d_valid = system_peripheral_busXlen_bus_d_halfPipe_valid;
  assign system_peripheral_busXlen_bus_d_halfPipe_ready = system_mainBus_to_system_peripheral_busXlen_down_bus_d_ready;
  assign system_mainBus_to_system_peripheral_busXlen_down_bus_d_payload_opcode = system_peripheral_busXlen_bus_d_halfPipe_payload_opcode;
  assign system_mainBus_to_system_peripheral_busXlen_down_bus_d_payload_param = system_peripheral_busXlen_bus_d_halfPipe_payload_param;
  assign system_mainBus_to_system_peripheral_busXlen_down_bus_d_payload_source = system_peripheral_busXlen_bus_d_halfPipe_payload_source;
  assign system_mainBus_to_system_peripheral_busXlen_down_bus_d_payload_size = system_peripheral_busXlen_bus_d_halfPipe_payload_size;
  assign system_mainBus_to_system_peripheral_busXlen_down_bus_d_payload_denied = system_peripheral_busXlen_bus_d_halfPipe_payload_denied;
  assign system_mainBus_to_system_peripheral_busXlen_down_bus_d_payload_data = system_peripheral_busXlen_bus_d_halfPipe_payload_data;
  assign system_mainBus_to_system_peripheral_busXlen_down_bus_d_payload_corrupt = system_peripheral_busXlen_bus_d_halfPipe_payload_corrupt;
  assign system_cpu_iBus_to_system_mainBus_up_bus_a_valid = system_cpu_iBus_noDecoder_toDown_a_valid;
  assign system_cpu_iBus_noDecoder_toDown_a_ready = system_cpu_iBus_to_system_mainBus_up_bus_a_ready;
  assign system_cpu_iBus_to_system_mainBus_up_bus_a_payload_opcode = system_cpu_iBus_noDecoder_toDown_a_payload_opcode;
  assign system_cpu_iBus_to_system_mainBus_up_bus_a_payload_param = system_cpu_iBus_noDecoder_toDown_a_payload_param;
  assign system_cpu_iBus_to_system_mainBus_up_bus_a_payload_source = system_cpu_iBus_noDecoder_toDown_a_payload_source;
  assign system_cpu_iBus_noDecoder_toDown_d_valid = system_cpu_iBus_to_system_mainBus_up_bus_d_valid;
  assign system_cpu_iBus_to_system_mainBus_up_bus_d_ready = system_cpu_iBus_noDecoder_toDown_d_ready;
  assign system_cpu_iBus_noDecoder_toDown_d_payload_opcode = system_cpu_iBus_to_system_mainBus_up_bus_d_payload_opcode;
  assign system_cpu_iBus_noDecoder_toDown_d_payload_param = system_cpu_iBus_to_system_mainBus_up_bus_d_payload_param;
  assign system_cpu_iBus_noDecoder_toDown_d_payload_source = system_cpu_iBus_to_system_mainBus_up_bus_d_payload_source;
  assign system_cpu_iBus_noDecoder_toDown_d_payload_denied = system_cpu_iBus_to_system_mainBus_up_bus_d_payload_denied;
  assign system_cpu_iBus_noDecoder_toDown_d_payload_data = system_cpu_iBus_to_system_mainBus_up_bus_d_payload_data;
  assign system_cpu_iBus_noDecoder_toDown_d_payload_corrupt = system_cpu_iBus_to_system_mainBus_up_bus_d_payload_corrupt;
  assign system_cpu_iBus_to_system_mainBus_up_bus_a_payload_size = system_cpu_iBus_noDecoder_toDown_a_payload_size;
  assign system_cpu_iBus_noDecoder_toDown_d_payload_size = system_cpu_iBus_to_system_mainBus_up_bus_d_payload_size;
  assign system_cpu_iBus_to_system_mainBus_up_bus_a_payload_address = system_cpu_iBus_noDecoder_toDown_a_payload_address;
  assign system_cpu_dBus_to_system_mainBus_up_bus_a_valid = system_cpu_dBus_noDecoder_toDown_a_valid;
  assign system_cpu_dBus_noDecoder_toDown_a_ready = system_cpu_dBus_to_system_mainBus_up_bus_a_ready;
  assign system_cpu_dBus_to_system_mainBus_up_bus_a_payload_opcode = system_cpu_dBus_noDecoder_toDown_a_payload_opcode;
  assign system_cpu_dBus_to_system_mainBus_up_bus_a_payload_param = system_cpu_dBus_noDecoder_toDown_a_payload_param;
  assign system_cpu_dBus_to_system_mainBus_up_bus_a_payload_mask = system_cpu_dBus_noDecoder_toDown_a_payload_mask;
  assign system_cpu_dBus_to_system_mainBus_up_bus_a_payload_data = system_cpu_dBus_noDecoder_toDown_a_payload_data;
  assign system_cpu_dBus_to_system_mainBus_up_bus_a_payload_corrupt = system_cpu_dBus_noDecoder_toDown_a_payload_corrupt;
  assign system_cpu_dBus_noDecoder_toDown_d_valid = system_cpu_dBus_to_system_mainBus_up_bus_d_valid;
  assign system_cpu_dBus_to_system_mainBus_up_bus_d_ready = system_cpu_dBus_noDecoder_toDown_d_ready;
  assign system_cpu_dBus_noDecoder_toDown_d_payload_opcode = system_cpu_dBus_to_system_mainBus_up_bus_d_payload_opcode;
  assign system_cpu_dBus_noDecoder_toDown_d_payload_param = system_cpu_dBus_to_system_mainBus_up_bus_d_payload_param;
  assign system_cpu_dBus_noDecoder_toDown_d_payload_denied = system_cpu_dBus_to_system_mainBus_up_bus_d_payload_denied;
  assign system_cpu_dBus_noDecoder_toDown_d_payload_data = system_cpu_dBus_to_system_mainBus_up_bus_d_payload_data;
  assign system_cpu_dBus_noDecoder_toDown_d_payload_corrupt = system_cpu_dBus_to_system_mainBus_up_bus_d_payload_corrupt;
  assign system_cpu_dBus_to_system_mainBus_up_bus_a_payload_size = system_cpu_dBus_noDecoder_toDown_a_payload_size;
  assign system_cpu_dBus_noDecoder_toDown_d_payload_size = system_cpu_dBus_to_system_mainBus_up_bus_d_payload_size;
  assign system_cpu_dBus_to_system_mainBus_up_bus_a_payload_address = system_cpu_dBus_noDecoder_toDown_a_payload_address;
  assign system_cpu_lsuL1Bus_to_system_mainBus_up_bus_a_valid = system_cpu_lsuL1Bus_noDecoder_toDown_a_valid;
  assign system_cpu_lsuL1Bus_noDecoder_toDown_a_ready = system_cpu_lsuL1Bus_to_system_mainBus_up_bus_a_ready;
  assign system_cpu_lsuL1Bus_to_system_mainBus_up_bus_a_payload_opcode = system_cpu_lsuL1Bus_noDecoder_toDown_a_payload_opcode;
  assign system_cpu_lsuL1Bus_to_system_mainBus_up_bus_a_payload_param = system_cpu_lsuL1Bus_noDecoder_toDown_a_payload_param;
  assign system_cpu_lsuL1Bus_to_system_mainBus_up_bus_a_payload_source = system_cpu_lsuL1Bus_noDecoder_toDown_a_payload_source;
  assign system_cpu_lsuL1Bus_to_system_mainBus_up_bus_a_payload_mask = system_cpu_lsuL1Bus_noDecoder_toDown_a_payload_mask;
  assign system_cpu_lsuL1Bus_to_system_mainBus_up_bus_a_payload_data = system_cpu_lsuL1Bus_noDecoder_toDown_a_payload_data;
  assign system_cpu_lsuL1Bus_to_system_mainBus_up_bus_a_payload_corrupt = system_cpu_lsuL1Bus_noDecoder_toDown_a_payload_corrupt;
  assign system_cpu_lsuL1Bus_noDecoder_toDown_d_valid = system_cpu_lsuL1Bus_to_system_mainBus_up_bus_d_valid;
  assign system_cpu_lsuL1Bus_to_system_mainBus_up_bus_d_ready = system_cpu_lsuL1Bus_noDecoder_toDown_d_ready;
  assign system_cpu_lsuL1Bus_noDecoder_toDown_d_payload_opcode = system_cpu_lsuL1Bus_to_system_mainBus_up_bus_d_payload_opcode;
  assign system_cpu_lsuL1Bus_noDecoder_toDown_d_payload_param = system_cpu_lsuL1Bus_to_system_mainBus_up_bus_d_payload_param;
  assign system_cpu_lsuL1Bus_noDecoder_toDown_d_payload_source = system_cpu_lsuL1Bus_to_system_mainBus_up_bus_d_payload_source;
  assign system_cpu_lsuL1Bus_noDecoder_toDown_d_payload_denied = system_cpu_lsuL1Bus_to_system_mainBus_up_bus_d_payload_denied;
  assign system_cpu_lsuL1Bus_noDecoder_toDown_d_payload_data = system_cpu_lsuL1Bus_to_system_mainBus_up_bus_d_payload_data;
  assign system_cpu_lsuL1Bus_noDecoder_toDown_d_payload_corrupt = system_cpu_lsuL1Bus_to_system_mainBus_up_bus_d_payload_corrupt;
  assign system_cpu_lsuL1Bus_to_system_mainBus_up_bus_a_payload_size = system_cpu_lsuL1Bus_noDecoder_toDown_a_payload_size;
  assign system_cpu_lsuL1Bus_noDecoder_toDown_d_payload_size = system_cpu_lsuL1Bus_to_system_mainBus_up_bus_d_payload_size;
  assign system_cpu_lsuL1Bus_to_system_mainBus_up_bus_a_payload_address = system_cpu_lsuL1Bus_noDecoder_toDown_a_payload_address;
  assign system_cpu_dBus_bus_a_valid = system_cpu_logic_core_LsuTileLinkPlugin_logic_bridge_down_a_valid;
  assign system_cpu_dBus_bus_a_payload_opcode = system_cpu_logic_core_LsuTileLinkPlugin_logic_bridge_down_a_payload_opcode;
  assign system_cpu_dBus_bus_a_payload_param = system_cpu_logic_core_LsuTileLinkPlugin_logic_bridge_down_a_payload_param;
  assign system_cpu_dBus_bus_a_payload_address = system_cpu_logic_core_LsuTileLinkPlugin_logic_bridge_down_a_payload_address;
  assign system_cpu_dBus_bus_a_payload_size = system_cpu_logic_core_LsuTileLinkPlugin_logic_bridge_down_a_payload_size;
  assign system_cpu_dBus_bus_a_payload_mask = system_cpu_logic_core_LsuTileLinkPlugin_logic_bridge_down_a_payload_mask;
  assign system_cpu_dBus_bus_a_payload_data = system_cpu_logic_core_LsuTileLinkPlugin_logic_bridge_down_a_payload_data;
  assign system_cpu_dBus_bus_a_payload_corrupt = system_cpu_logic_core_LsuTileLinkPlugin_logic_bridge_down_a_payload_corrupt;
  assign system_cpu_dBus_bus_d_ready = system_cpu_logic_core_LsuTileLinkPlugin_logic_bridge_down_d_ready;
  assign system_ram_up_bus_a_ready = system_ram_thread_logic_io_up_a_ready;
  assign system_ram_up_bus_d_valid = system_ram_thread_logic_io_up_d_valid;
  assign system_ram_up_bus_d_payload_opcode = system_ram_thread_logic_io_up_d_payload_opcode;
  assign system_ram_up_bus_d_payload_param = system_ram_thread_logic_io_up_d_payload_param;
  assign system_ram_up_bus_d_payload_source = system_ram_thread_logic_io_up_d_payload_source;
  assign system_ram_up_bus_d_payload_size = system_ram_thread_logic_io_up_d_payload_size;
  assign system_ram_up_bus_d_payload_denied = system_ram_thread_logic_io_up_d_payload_denied;
  assign system_ram_up_bus_d_payload_data = system_ram_thread_logic_io_up_d_payload_data;
  assign system_ram_up_bus_d_payload_corrupt = system_ram_thread_logic_io_up_d_payload_corrupt;
  assign system_cpu_iBus_to_system_mainBus_down_bus_a_valid = system_cpu_iBus_to_system_mainBus_up_bus_a_valid;
  assign system_cpu_iBus_to_system_mainBus_up_bus_a_ready = system_cpu_iBus_to_system_mainBus_down_bus_a_ready;
  assign system_cpu_iBus_to_system_mainBus_down_bus_a_payload_opcode = system_cpu_iBus_to_system_mainBus_up_bus_a_payload_opcode;
  assign system_cpu_iBus_to_system_mainBus_down_bus_a_payload_param = system_cpu_iBus_to_system_mainBus_up_bus_a_payload_param;
  assign system_cpu_iBus_to_system_mainBus_down_bus_a_payload_source = system_cpu_iBus_to_system_mainBus_up_bus_a_payload_source;
  assign system_cpu_iBus_to_system_mainBus_down_bus_a_payload_address = system_cpu_iBus_to_system_mainBus_up_bus_a_payload_address;
  assign system_cpu_iBus_to_system_mainBus_down_bus_a_payload_size = system_cpu_iBus_to_system_mainBus_up_bus_a_payload_size;
  assign system_cpu_iBus_to_system_mainBus_up_bus_d_valid = system_cpu_iBus_to_system_mainBus_down_bus_d_valid;
  assign system_cpu_iBus_to_system_mainBus_down_bus_d_ready = system_cpu_iBus_to_system_mainBus_up_bus_d_ready;
  assign system_cpu_iBus_to_system_mainBus_up_bus_d_payload_opcode = system_cpu_iBus_to_system_mainBus_down_bus_d_payload_opcode;
  assign system_cpu_iBus_to_system_mainBus_up_bus_d_payload_param = system_cpu_iBus_to_system_mainBus_down_bus_d_payload_param;
  assign system_cpu_iBus_to_system_mainBus_up_bus_d_payload_source = system_cpu_iBus_to_system_mainBus_down_bus_d_payload_source;
  assign system_cpu_iBus_to_system_mainBus_up_bus_d_payload_size = system_cpu_iBus_to_system_mainBus_down_bus_d_payload_size;
  assign system_cpu_iBus_to_system_mainBus_up_bus_d_payload_denied = system_cpu_iBus_to_system_mainBus_down_bus_d_payload_denied;
  assign system_cpu_iBus_to_system_mainBus_up_bus_d_payload_data = system_cpu_iBus_to_system_mainBus_down_bus_d_payload_data;
  assign system_cpu_iBus_to_system_mainBus_up_bus_d_payload_corrupt = system_cpu_iBus_to_system_mainBus_down_bus_d_payload_corrupt;
  assign system_cpu_dBus_to_system_mainBus_up_bus_a_ready = system_cpu_dBus_to_system_mainBus_widthAdapter_io_up_a_ready;
  assign system_cpu_dBus_to_system_mainBus_up_bus_d_valid = system_cpu_dBus_to_system_mainBus_widthAdapter_io_up_d_valid;
  assign system_cpu_dBus_to_system_mainBus_up_bus_d_payload_opcode = system_cpu_dBus_to_system_mainBus_widthAdapter_io_up_d_payload_opcode;
  assign system_cpu_dBus_to_system_mainBus_up_bus_d_payload_param = system_cpu_dBus_to_system_mainBus_widthAdapter_io_up_d_payload_param;
  assign system_cpu_dBus_to_system_mainBus_up_bus_d_payload_size = system_cpu_dBus_to_system_mainBus_widthAdapter_io_up_d_payload_size;
  assign system_cpu_dBus_to_system_mainBus_up_bus_d_payload_denied = system_cpu_dBus_to_system_mainBus_widthAdapter_io_up_d_payload_denied;
  assign system_cpu_dBus_to_system_mainBus_up_bus_d_payload_data = system_cpu_dBus_to_system_mainBus_widthAdapter_io_up_d_payload_data;
  assign system_cpu_dBus_to_system_mainBus_up_bus_d_payload_corrupt = system_cpu_dBus_to_system_mainBus_widthAdapter_io_up_d_payload_corrupt;
  assign system_cpu_dBus_to_system_mainBus_down_bus_a_valid = system_cpu_dBus_to_system_mainBus_widthAdapter_io_down_a_valid;
  assign system_cpu_dBus_to_system_mainBus_down_bus_a_payload_opcode = system_cpu_dBus_to_system_mainBus_widthAdapter_io_down_a_payload_opcode;
  assign system_cpu_dBus_to_system_mainBus_down_bus_a_payload_param = system_cpu_dBus_to_system_mainBus_widthAdapter_io_down_a_payload_param;
  assign system_cpu_dBus_to_system_mainBus_down_bus_a_payload_address = system_cpu_dBus_to_system_mainBus_widthAdapter_io_down_a_payload_address;
  assign system_cpu_dBus_to_system_mainBus_down_bus_a_payload_size = system_cpu_dBus_to_system_mainBus_widthAdapter_io_down_a_payload_size;
  assign system_cpu_dBus_to_system_mainBus_down_bus_a_payload_mask = system_cpu_dBus_to_system_mainBus_widthAdapter_io_down_a_payload_mask;
  assign system_cpu_dBus_to_system_mainBus_down_bus_a_payload_data = system_cpu_dBus_to_system_mainBus_widthAdapter_io_down_a_payload_data;
  assign system_cpu_dBus_to_system_mainBus_down_bus_a_payload_corrupt = system_cpu_dBus_to_system_mainBus_widthAdapter_io_down_a_payload_corrupt;
  assign system_cpu_dBus_to_system_mainBus_down_bus_d_ready = system_cpu_dBus_to_system_mainBus_widthAdapter_io_down_d_ready;
  assign system_cpu_lsuL1Bus_to_system_mainBus_down_bus_a_valid = system_cpu_lsuL1Bus_to_system_mainBus_up_bus_a_valid;
  assign system_cpu_lsuL1Bus_to_system_mainBus_up_bus_a_ready = system_cpu_lsuL1Bus_to_system_mainBus_down_bus_a_ready;
  assign system_cpu_lsuL1Bus_to_system_mainBus_down_bus_a_payload_opcode = system_cpu_lsuL1Bus_to_system_mainBus_up_bus_a_payload_opcode;
  assign system_cpu_lsuL1Bus_to_system_mainBus_down_bus_a_payload_param = system_cpu_lsuL1Bus_to_system_mainBus_up_bus_a_payload_param;
  assign system_cpu_lsuL1Bus_to_system_mainBus_down_bus_a_payload_source = system_cpu_lsuL1Bus_to_system_mainBus_up_bus_a_payload_source;
  assign system_cpu_lsuL1Bus_to_system_mainBus_down_bus_a_payload_address = system_cpu_lsuL1Bus_to_system_mainBus_up_bus_a_payload_address;
  assign system_cpu_lsuL1Bus_to_system_mainBus_down_bus_a_payload_size = system_cpu_lsuL1Bus_to_system_mainBus_up_bus_a_payload_size;
  assign system_cpu_lsuL1Bus_to_system_mainBus_down_bus_a_payload_mask = system_cpu_lsuL1Bus_to_system_mainBus_up_bus_a_payload_mask;
  assign system_cpu_lsuL1Bus_to_system_mainBus_down_bus_a_payload_data = system_cpu_lsuL1Bus_to_system_mainBus_up_bus_a_payload_data;
  assign system_cpu_lsuL1Bus_to_system_mainBus_down_bus_a_payload_corrupt = system_cpu_lsuL1Bus_to_system_mainBus_up_bus_a_payload_corrupt;
  assign system_cpu_lsuL1Bus_to_system_mainBus_up_bus_d_valid = system_cpu_lsuL1Bus_to_system_mainBus_down_bus_d_valid;
  assign system_cpu_lsuL1Bus_to_system_mainBus_down_bus_d_ready = system_cpu_lsuL1Bus_to_system_mainBus_up_bus_d_ready;
  assign system_cpu_lsuL1Bus_to_system_mainBus_up_bus_d_payload_opcode = system_cpu_lsuL1Bus_to_system_mainBus_down_bus_d_payload_opcode;
  assign system_cpu_lsuL1Bus_to_system_mainBus_up_bus_d_payload_param = system_cpu_lsuL1Bus_to_system_mainBus_down_bus_d_payload_param;
  assign system_cpu_lsuL1Bus_to_system_mainBus_up_bus_d_payload_source = system_cpu_lsuL1Bus_to_system_mainBus_down_bus_d_payload_source;
  assign system_cpu_lsuL1Bus_to_system_mainBus_up_bus_d_payload_size = system_cpu_lsuL1Bus_to_system_mainBus_down_bus_d_payload_size;
  assign system_cpu_lsuL1Bus_to_system_mainBus_up_bus_d_payload_denied = system_cpu_lsuL1Bus_to_system_mainBus_down_bus_d_payload_denied;
  assign system_cpu_lsuL1Bus_to_system_mainBus_up_bus_d_payload_data = system_cpu_lsuL1Bus_to_system_mainBus_down_bus_d_payload_data;
  assign system_cpu_lsuL1Bus_to_system_mainBus_up_bus_d_payload_corrupt = system_cpu_lsuL1Bus_to_system_mainBus_down_bus_d_payload_corrupt;
  assign system_peripheral_bus32_bus_a_valid = system_peripheral_busXlen_to_system_peripheral_bus32_down_bus_a_valid;
  assign system_peripheral_busXlen_to_system_peripheral_bus32_down_bus_a_ready = system_peripheral_bus32_bus_a_ready;
  assign system_peripheral_bus32_bus_a_payload_opcode = system_peripheral_busXlen_to_system_peripheral_bus32_down_bus_a_payload_opcode;
  assign system_peripheral_bus32_bus_a_payload_param = system_peripheral_busXlen_to_system_peripheral_bus32_down_bus_a_payload_param;
  assign system_peripheral_bus32_bus_a_payload_source = system_peripheral_busXlen_to_system_peripheral_bus32_down_bus_a_payload_source;
  assign system_peripheral_bus32_bus_a_payload_address = system_peripheral_busXlen_to_system_peripheral_bus32_down_bus_a_payload_address;
  assign system_peripheral_bus32_bus_a_payload_size = system_peripheral_busXlen_to_system_peripheral_bus32_down_bus_a_payload_size;
  assign system_peripheral_bus32_bus_a_payload_mask = system_peripheral_busXlen_to_system_peripheral_bus32_down_bus_a_payload_mask;
  assign system_peripheral_bus32_bus_a_payload_data = system_peripheral_busXlen_to_system_peripheral_bus32_down_bus_a_payload_data;
  assign system_peripheral_bus32_bus_a_payload_corrupt = system_peripheral_busXlen_to_system_peripheral_bus32_down_bus_a_payload_corrupt;
  assign system_peripheral_busXlen_to_system_peripheral_bus32_down_bus_d_valid = system_peripheral_bus32_bus_d_valid;
  assign system_peripheral_bus32_bus_d_ready = system_peripheral_busXlen_to_system_peripheral_bus32_down_bus_d_ready;
  assign system_peripheral_busXlen_to_system_peripheral_bus32_down_bus_d_payload_opcode = system_peripheral_bus32_bus_d_payload_opcode;
  assign system_peripheral_busXlen_to_system_peripheral_bus32_down_bus_d_payload_param = system_peripheral_bus32_bus_d_payload_param;
  assign system_peripheral_busXlen_to_system_peripheral_bus32_down_bus_d_payload_source = system_peripheral_bus32_bus_d_payload_source;
  assign system_peripheral_busXlen_to_system_peripheral_bus32_down_bus_d_payload_size = system_peripheral_bus32_bus_d_payload_size;
  assign system_peripheral_busXlen_to_system_peripheral_bus32_down_bus_d_payload_denied = system_peripheral_bus32_bus_d_payload_denied;
  assign system_peripheral_busXlen_to_system_peripheral_bus32_down_bus_d_payload_data = system_peripheral_bus32_bus_d_payload_data;
  assign system_peripheral_busXlen_to_system_peripheral_bus32_down_bus_d_payload_corrupt = system_peripheral_bus32_bus_d_payload_corrupt;
  assign system_peripheral_clint_node_bus_a_valid = system_peripheral_busXlen_to_system_peripheral_clint_node_down_bus_a_valid;
  assign system_peripheral_busXlen_to_system_peripheral_clint_node_down_bus_a_ready = system_peripheral_clint_node_bus_a_ready;
  assign system_peripheral_clint_node_bus_a_payload_opcode = system_peripheral_busXlen_to_system_peripheral_clint_node_down_bus_a_payload_opcode;
  assign system_peripheral_clint_node_bus_a_payload_param = system_peripheral_busXlen_to_system_peripheral_clint_node_down_bus_a_payload_param;
  assign system_peripheral_clint_node_bus_a_payload_source = system_peripheral_busXlen_to_system_peripheral_clint_node_down_bus_a_payload_source;
  assign system_peripheral_clint_node_bus_a_payload_address = system_peripheral_busXlen_to_system_peripheral_clint_node_down_bus_a_payload_address;
  assign system_peripheral_clint_node_bus_a_payload_size = system_peripheral_busXlen_to_system_peripheral_clint_node_down_bus_a_payload_size;
  assign system_peripheral_clint_node_bus_a_payload_mask = system_peripheral_busXlen_to_system_peripheral_clint_node_down_bus_a_payload_mask;
  assign system_peripheral_clint_node_bus_a_payload_data = system_peripheral_busXlen_to_system_peripheral_clint_node_down_bus_a_payload_data;
  assign system_peripheral_clint_node_bus_a_payload_corrupt = system_peripheral_busXlen_to_system_peripheral_clint_node_down_bus_a_payload_corrupt;
  assign system_peripheral_busXlen_to_system_peripheral_clint_node_down_bus_d_valid = system_peripheral_clint_node_bus_d_valid;
  assign system_peripheral_clint_node_bus_d_ready = system_peripheral_busXlen_to_system_peripheral_clint_node_down_bus_d_ready;
  assign system_peripheral_busXlen_to_system_peripheral_clint_node_down_bus_d_payload_opcode = system_peripheral_clint_node_bus_d_payload_opcode;
  assign system_peripheral_busXlen_to_system_peripheral_clint_node_down_bus_d_payload_param = system_peripheral_clint_node_bus_d_payload_param;
  assign system_peripheral_busXlen_to_system_peripheral_clint_node_down_bus_d_payload_source = system_peripheral_clint_node_bus_d_payload_source;
  assign system_peripheral_busXlen_to_system_peripheral_clint_node_down_bus_d_payload_size = system_peripheral_clint_node_bus_d_payload_size;
  assign system_peripheral_busXlen_to_system_peripheral_clint_node_down_bus_d_payload_denied = system_peripheral_clint_node_bus_d_payload_denied;
  assign system_peripheral_busXlen_to_system_peripheral_clint_node_down_bus_d_payload_data = system_peripheral_clint_node_bus_d_payload_data;
  assign system_peripheral_busXlen_to_system_peripheral_clint_node_down_bus_d_payload_corrupt = system_peripheral_clint_node_bus_d_payload_corrupt;
  assign system_peripheral_clint_node_bus_a_ready = system_peripheral_clint_thread_core_io_bus_a_ready;
  assign system_peripheral_clint_node_bus_d_valid = system_peripheral_clint_thread_core_io_bus_d_valid;
  assign system_peripheral_clint_node_bus_d_payload_opcode = system_peripheral_clint_thread_core_io_bus_d_payload_opcode;
  assign system_peripheral_clint_node_bus_d_payload_param = system_peripheral_clint_thread_core_io_bus_d_payload_param;
  assign system_peripheral_clint_node_bus_d_payload_source = system_peripheral_clint_thread_core_io_bus_d_payload_source;
  assign system_peripheral_clint_node_bus_d_payload_size = system_peripheral_clint_thread_core_io_bus_d_payload_size;
  assign system_peripheral_clint_node_bus_d_payload_denied = system_peripheral_clint_thread_core_io_bus_d_payload_denied;
  assign system_peripheral_clint_node_bus_d_payload_data = system_peripheral_clint_thread_core_io_bus_d_payload_data;
  assign system_peripheral_clint_node_bus_d_payload_corrupt = system_peripheral_clint_thread_core_io_bus_d_payload_corrupt;
  assign system_peripheral_clint_thread_core_io_stop = (&system_cpu_priv_stoptime_regNext);
  assign system_peripheral_clint_time = system_peripheral_clint_thread_core_io_time;
  assign system_peripheral_plic_node_bus_a_valid = system_peripheral_bus32_to_system_peripheral_plic_node_down_bus_a_valid;
  assign system_peripheral_bus32_to_system_peripheral_plic_node_down_bus_a_ready = system_peripheral_plic_node_bus_a_ready;
  assign system_peripheral_plic_node_bus_a_payload_opcode = system_peripheral_bus32_to_system_peripheral_plic_node_down_bus_a_payload_opcode;
  assign system_peripheral_plic_node_bus_a_payload_param = system_peripheral_bus32_to_system_peripheral_plic_node_down_bus_a_payload_param;
  assign system_peripheral_plic_node_bus_a_payload_source = system_peripheral_bus32_to_system_peripheral_plic_node_down_bus_a_payload_source;
  assign system_peripheral_plic_node_bus_a_payload_address = system_peripheral_bus32_to_system_peripheral_plic_node_down_bus_a_payload_address;
  assign system_peripheral_plic_node_bus_a_payload_size = system_peripheral_bus32_to_system_peripheral_plic_node_down_bus_a_payload_size;
  assign system_peripheral_plic_node_bus_a_payload_mask = system_peripheral_bus32_to_system_peripheral_plic_node_down_bus_a_payload_mask;
  assign system_peripheral_plic_node_bus_a_payload_data = system_peripheral_bus32_to_system_peripheral_plic_node_down_bus_a_payload_data;
  assign system_peripheral_plic_node_bus_a_payload_corrupt = system_peripheral_bus32_to_system_peripheral_plic_node_down_bus_a_payload_corrupt;
  assign system_peripheral_bus32_to_system_peripheral_plic_node_down_bus_d_valid = system_peripheral_plic_node_bus_d_valid;
  assign system_peripheral_plic_node_bus_d_ready = system_peripheral_bus32_to_system_peripheral_plic_node_down_bus_d_ready;
  assign system_peripheral_bus32_to_system_peripheral_plic_node_down_bus_d_payload_opcode = system_peripheral_plic_node_bus_d_payload_opcode;
  assign system_peripheral_bus32_to_system_peripheral_plic_node_down_bus_d_payload_param = system_peripheral_plic_node_bus_d_payload_param;
  assign system_peripheral_bus32_to_system_peripheral_plic_node_down_bus_d_payload_source = system_peripheral_plic_node_bus_d_payload_source;
  assign system_peripheral_bus32_to_system_peripheral_plic_node_down_bus_d_payload_size = system_peripheral_plic_node_bus_d_payload_size;
  assign system_peripheral_bus32_to_system_peripheral_plic_node_down_bus_d_payload_denied = system_peripheral_plic_node_bus_d_payload_denied;
  assign system_peripheral_bus32_to_system_peripheral_plic_node_down_bus_d_payload_data = system_peripheral_plic_node_bus_d_payload_data;
  assign system_peripheral_bus32_to_system_peripheral_plic_node_down_bus_d_payload_corrupt = system_peripheral_plic_node_bus_d_payload_corrupt;
  assign system_peripheral_uart_node_bus_a_valid = system_peripheral_bus32_to_system_peripheral_uart_node_down_bus_a_valid;
  assign system_peripheral_bus32_to_system_peripheral_uart_node_down_bus_a_ready = system_peripheral_uart_node_bus_a_ready;
  assign system_peripheral_uart_node_bus_a_payload_opcode = system_peripheral_bus32_to_system_peripheral_uart_node_down_bus_a_payload_opcode;
  assign system_peripheral_uart_node_bus_a_payload_param = system_peripheral_bus32_to_system_peripheral_uart_node_down_bus_a_payload_param;
  assign system_peripheral_uart_node_bus_a_payload_source = system_peripheral_bus32_to_system_peripheral_uart_node_down_bus_a_payload_source;
  assign system_peripheral_uart_node_bus_a_payload_address = system_peripheral_bus32_to_system_peripheral_uart_node_down_bus_a_payload_address;
  assign system_peripheral_uart_node_bus_a_payload_size = system_peripheral_bus32_to_system_peripheral_uart_node_down_bus_a_payload_size;
  assign system_peripheral_uart_node_bus_a_payload_mask = system_peripheral_bus32_to_system_peripheral_uart_node_down_bus_a_payload_mask;
  assign system_peripheral_uart_node_bus_a_payload_data = system_peripheral_bus32_to_system_peripheral_uart_node_down_bus_a_payload_data;
  assign system_peripheral_uart_node_bus_a_payload_corrupt = system_peripheral_bus32_to_system_peripheral_uart_node_down_bus_a_payload_corrupt;
  assign system_peripheral_bus32_to_system_peripheral_uart_node_down_bus_d_valid = system_peripheral_uart_node_bus_d_valid;
  assign system_peripheral_uart_node_bus_d_ready = system_peripheral_bus32_to_system_peripheral_uart_node_down_bus_d_ready;
  assign system_peripheral_bus32_to_system_peripheral_uart_node_down_bus_d_payload_opcode = system_peripheral_uart_node_bus_d_payload_opcode;
  assign system_peripheral_bus32_to_system_peripheral_uart_node_down_bus_d_payload_param = system_peripheral_uart_node_bus_d_payload_param;
  assign system_peripheral_bus32_to_system_peripheral_uart_node_down_bus_d_payload_source = system_peripheral_uart_node_bus_d_payload_source;
  assign system_peripheral_bus32_to_system_peripheral_uart_node_down_bus_d_payload_size = system_peripheral_uart_node_bus_d_payload_size;
  assign system_peripheral_bus32_to_system_peripheral_uart_node_down_bus_d_payload_denied = system_peripheral_uart_node_bus_d_payload_denied;
  assign system_peripheral_bus32_to_system_peripheral_uart_node_down_bus_d_payload_data = system_peripheral_uart_node_bus_d_payload_data;
  assign system_peripheral_bus32_to_system_peripheral_uart_node_down_bus_d_payload_corrupt = system_peripheral_uart_node_bus_d_payload_corrupt;
  assign system_peripheral_demo_node_bus_a_valid = system_peripheral_bus32_to_system_peripheral_demo_node_down_bus_a_valid;
  assign system_peripheral_bus32_to_system_peripheral_demo_node_down_bus_a_ready = system_peripheral_demo_node_bus_a_ready;
  assign system_peripheral_demo_node_bus_a_payload_opcode = system_peripheral_bus32_to_system_peripheral_demo_node_down_bus_a_payload_opcode;
  assign system_peripheral_demo_node_bus_a_payload_param = system_peripheral_bus32_to_system_peripheral_demo_node_down_bus_a_payload_param;
  assign system_peripheral_demo_node_bus_a_payload_source = system_peripheral_bus32_to_system_peripheral_demo_node_down_bus_a_payload_source;
  assign system_peripheral_demo_node_bus_a_payload_address = system_peripheral_bus32_to_system_peripheral_demo_node_down_bus_a_payload_address;
  assign system_peripheral_demo_node_bus_a_payload_size = system_peripheral_bus32_to_system_peripheral_demo_node_down_bus_a_payload_size;
  assign system_peripheral_demo_node_bus_a_payload_mask = system_peripheral_bus32_to_system_peripheral_demo_node_down_bus_a_payload_mask;
  assign system_peripheral_demo_node_bus_a_payload_data = system_peripheral_bus32_to_system_peripheral_demo_node_down_bus_a_payload_data;
  assign system_peripheral_demo_node_bus_a_payload_corrupt = system_peripheral_bus32_to_system_peripheral_demo_node_down_bus_a_payload_corrupt;
  assign system_peripheral_bus32_to_system_peripheral_demo_node_down_bus_d_valid = system_peripheral_demo_node_bus_d_valid;
  assign system_peripheral_demo_node_bus_d_ready = system_peripheral_bus32_to_system_peripheral_demo_node_down_bus_d_ready;
  assign system_peripheral_bus32_to_system_peripheral_demo_node_down_bus_d_payload_opcode = system_peripheral_demo_node_bus_d_payload_opcode;
  assign system_peripheral_bus32_to_system_peripheral_demo_node_down_bus_d_payload_param = system_peripheral_demo_node_bus_d_payload_param;
  assign system_peripheral_bus32_to_system_peripheral_demo_node_down_bus_d_payload_source = system_peripheral_demo_node_bus_d_payload_source;
  assign system_peripheral_bus32_to_system_peripheral_demo_node_down_bus_d_payload_size = system_peripheral_demo_node_bus_d_payload_size;
  assign system_peripheral_bus32_to_system_peripheral_demo_node_down_bus_d_payload_denied = system_peripheral_demo_node_bus_d_payload_denied;
  assign system_peripheral_bus32_to_system_peripheral_demo_node_down_bus_d_payload_data = system_peripheral_demo_node_bus_d_payload_data;
  assign system_peripheral_bus32_to_system_peripheral_demo_node_down_bus_d_payload_corrupt = system_peripheral_demo_node_bus_d_payload_corrupt;
  assign system_peripheral_busXlen_to_system_peripheral_bus32_up_bus_a_valid = system_peripheral_busXlen_decoder_core_io_downs_0_a_valid;
  assign system_peripheral_busXlen_to_system_peripheral_bus32_up_bus_a_payload_opcode = system_peripheral_busXlen_decoder_core_io_downs_0_a_payload_opcode;
  assign system_peripheral_busXlen_to_system_peripheral_bus32_up_bus_a_payload_param = system_peripheral_busXlen_decoder_core_io_downs_0_a_payload_param;
  assign system_peripheral_busXlen_to_system_peripheral_bus32_up_bus_a_payload_source = system_peripheral_busXlen_decoder_core_io_downs_0_a_payload_source;
  assign system_peripheral_busXlen_to_system_peripheral_bus32_up_bus_a_payload_address = system_peripheral_busXlen_decoder_core_io_downs_0_a_payload_address;
  assign system_peripheral_busXlen_to_system_peripheral_bus32_up_bus_a_payload_size = system_peripheral_busXlen_decoder_core_io_downs_0_a_payload_size;
  assign system_peripheral_busXlen_to_system_peripheral_bus32_up_bus_a_payload_mask = system_peripheral_busXlen_decoder_core_io_downs_0_a_payload_mask;
  assign system_peripheral_busXlen_to_system_peripheral_bus32_up_bus_a_payload_data = system_peripheral_busXlen_decoder_core_io_downs_0_a_payload_data;
  assign system_peripheral_busXlen_to_system_peripheral_bus32_up_bus_a_payload_corrupt = system_peripheral_busXlen_decoder_core_io_downs_0_a_payload_corrupt;
  assign system_peripheral_busXlen_to_system_peripheral_bus32_up_bus_d_ready = system_peripheral_busXlen_decoder_core_io_downs_0_d_ready;
  assign system_peripheral_busXlen_to_system_peripheral_clint_node_up_bus_a_valid = system_peripheral_busXlen_decoder_core_io_downs_1_a_valid;
  assign system_peripheral_busXlen_to_system_peripheral_clint_node_up_bus_a_payload_opcode = system_peripheral_busXlen_decoder_core_io_downs_1_a_payload_opcode;
  assign system_peripheral_busXlen_to_system_peripheral_clint_node_up_bus_a_payload_param = system_peripheral_busXlen_decoder_core_io_downs_1_a_payload_param;
  assign system_peripheral_busXlen_to_system_peripheral_clint_node_up_bus_a_payload_source = system_peripheral_busXlen_decoder_core_io_downs_1_a_payload_source;
  assign system_peripheral_busXlen_to_system_peripheral_clint_node_up_bus_a_payload_address = system_peripheral_busXlen_decoder_core_io_downs_1_a_payload_address;
  assign system_peripheral_busXlen_to_system_peripheral_clint_node_up_bus_a_payload_size = system_peripheral_busXlen_decoder_core_io_downs_1_a_payload_size;
  assign system_peripheral_busXlen_to_system_peripheral_clint_node_up_bus_a_payload_mask = system_peripheral_busXlen_decoder_core_io_downs_1_a_payload_mask;
  assign system_peripheral_busXlen_to_system_peripheral_clint_node_up_bus_a_payload_data = system_peripheral_busXlen_decoder_core_io_downs_1_a_payload_data;
  assign system_peripheral_busXlen_to_system_peripheral_clint_node_up_bus_a_payload_corrupt = system_peripheral_busXlen_decoder_core_io_downs_1_a_payload_corrupt;
  assign system_peripheral_busXlen_to_system_peripheral_clint_node_up_bus_d_ready = system_peripheral_busXlen_decoder_core_io_downs_1_d_ready;
  assign system_peripheral_busXlen_bus_a_ready = system_peripheral_busXlen_decoder_core_io_up_a_ready;
  assign system_peripheral_busXlen_bus_d_valid = system_peripheral_busXlen_decoder_core_io_up_d_valid;
  assign system_peripheral_busXlen_bus_d_payload_opcode = system_peripheral_busXlen_decoder_core_io_up_d_payload_opcode;
  assign system_peripheral_busXlen_bus_d_payload_param = system_peripheral_busXlen_decoder_core_io_up_d_payload_param;
  assign system_peripheral_busXlen_bus_d_payload_source = system_peripheral_busXlen_decoder_core_io_up_d_payload_source;
  assign system_peripheral_busXlen_bus_d_payload_size = system_peripheral_busXlen_decoder_core_io_up_d_payload_size;
  assign system_peripheral_busXlen_bus_d_payload_denied = system_peripheral_busXlen_decoder_core_io_up_d_payload_denied;
  assign system_peripheral_busXlen_bus_d_payload_data = system_peripheral_busXlen_decoder_core_io_up_d_payload_data;
  assign system_peripheral_busXlen_bus_d_payload_corrupt = system_peripheral_busXlen_decoder_core_io_up_d_payload_corrupt;
  assign system_cpu_priv_stoptime = 1'b0;
  assign system_mainBus_to_system_ram_up_up_bus_a_valid = system_mainBus_decoder_core_io_downs_0_a_valid;
  assign system_mainBus_to_system_ram_up_up_bus_a_payload_opcode = system_mainBus_decoder_core_io_downs_0_a_payload_opcode;
  assign system_mainBus_to_system_ram_up_up_bus_a_payload_param = system_mainBus_decoder_core_io_downs_0_a_payload_param;
  assign system_mainBus_to_system_ram_up_up_bus_a_payload_source = system_mainBus_decoder_core_io_downs_0_a_payload_source;
  assign system_mainBus_to_system_ram_up_up_bus_a_payload_address = system_mainBus_decoder_core_io_downs_0_a_payload_address;
  assign system_mainBus_to_system_ram_up_up_bus_a_payload_size = system_mainBus_decoder_core_io_downs_0_a_payload_size;
  assign system_mainBus_to_system_ram_up_up_bus_a_payload_mask = system_mainBus_decoder_core_io_downs_0_a_payload_mask;
  assign system_mainBus_to_system_ram_up_up_bus_a_payload_data = system_mainBus_decoder_core_io_downs_0_a_payload_data;
  assign system_mainBus_to_system_ram_up_up_bus_a_payload_corrupt = system_mainBus_decoder_core_io_downs_0_a_payload_corrupt;
  assign system_mainBus_to_system_ram_up_up_bus_d_ready = system_mainBus_decoder_core_io_downs_0_d_ready;
  assign system_mainBus_to_system_peripheral_busXlen_up_bus_a_valid = system_mainBus_decoder_core_io_downs_1_a_valid;
  assign system_mainBus_to_system_peripheral_busXlen_up_bus_a_payload_opcode = system_mainBus_decoder_core_io_downs_1_a_payload_opcode;
  assign system_mainBus_to_system_peripheral_busXlen_up_bus_a_payload_param = system_mainBus_decoder_core_io_downs_1_a_payload_param;
  assign system_mainBus_to_system_peripheral_busXlen_up_bus_a_payload_source = system_mainBus_decoder_core_io_downs_1_a_payload_source;
  assign system_mainBus_to_system_peripheral_busXlen_up_bus_a_payload_address = system_mainBus_decoder_core_io_downs_1_a_payload_address;
  assign system_mainBus_to_system_peripheral_busXlen_up_bus_a_payload_size = system_mainBus_decoder_core_io_downs_1_a_payload_size;
  assign system_mainBus_to_system_peripheral_busXlen_up_bus_a_payload_mask = system_mainBus_decoder_core_io_downs_1_a_payload_mask;
  assign system_mainBus_to_system_peripheral_busXlen_up_bus_a_payload_data = system_mainBus_decoder_core_io_downs_1_a_payload_data;
  assign system_mainBus_to_system_peripheral_busXlen_up_bus_a_payload_corrupt = system_mainBus_decoder_core_io_downs_1_a_payload_corrupt;
  assign system_mainBus_to_system_peripheral_busXlen_up_bus_d_ready = system_mainBus_decoder_core_io_downs_1_d_ready;
  assign system_mainBus_bus_a_ready = system_mainBus_decoder_core_io_up_a_ready;
  assign system_mainBus_bus_d_valid = system_mainBus_decoder_core_io_up_d_valid;
  assign system_mainBus_bus_d_payload_opcode = system_mainBus_decoder_core_io_up_d_payload_opcode;
  assign system_mainBus_bus_d_payload_param = system_mainBus_decoder_core_io_up_d_payload_param;
  assign system_mainBus_bus_d_payload_source = system_mainBus_decoder_core_io_up_d_payload_source;
  assign system_mainBus_bus_d_payload_size = system_mainBus_decoder_core_io_up_d_payload_size;
  assign system_mainBus_bus_d_payload_denied = system_mainBus_decoder_core_io_up_d_payload_denied;
  assign system_mainBus_bus_d_payload_data = system_mainBus_decoder_core_io_up_d_payload_data;
  assign system_mainBus_bus_d_payload_corrupt = system_mainBus_decoder_core_io_up_d_payload_corrupt;
  assign system_peripheral_plic_node_bus_a_ready = system_peripheral_plic_thread_logic_io_bus_a_ready;
  assign system_peripheral_plic_node_bus_d_valid = system_peripheral_plic_thread_logic_io_bus_d_valid;
  assign system_peripheral_plic_node_bus_d_payload_opcode = system_peripheral_plic_thread_logic_io_bus_d_payload_opcode;
  assign system_peripheral_plic_node_bus_d_payload_param = system_peripheral_plic_thread_logic_io_bus_d_payload_param;
  assign system_peripheral_plic_node_bus_d_payload_source = system_peripheral_plic_thread_logic_io_bus_d_payload_source;
  assign system_peripheral_plic_node_bus_d_payload_size = system_peripheral_plic_thread_logic_io_bus_d_payload_size;
  assign system_peripheral_plic_node_bus_d_payload_denied = system_peripheral_plic_thread_logic_io_bus_d_payload_denied;
  assign system_peripheral_plic_node_bus_d_payload_data = system_peripheral_plic_thread_logic_io_bus_d_payload_data;
  assign system_peripheral_plic_node_bus_d_payload_corrupt = system_peripheral_plic_thread_logic_io_bus_d_payload_corrupt;
  always @(*) begin
    system_peripheral_plic_thread_logic_io_sources[0] = system_peripheral_plic_from_system_peripheral_uart_interrupt_flag;
    system_peripheral_plic_thread_logic_io_sources[1] = system_peripheral_plic_from_system_peripheral_demo_interrupt_flag;
  end

  assign system_peripheral_plic_to_system_cpu_priv_mei_flag = system_peripheral_plic_thread_logic_io_targets[0];
  assign system_peripheral_uart_node_bus_a_ready = system_peripheral_uart_logic_core_io_bus_a_ready;
  assign system_peripheral_uart_node_bus_d_valid = system_peripheral_uart_logic_core_io_bus_d_valid;
  assign system_peripheral_uart_node_bus_d_payload_opcode = system_peripheral_uart_logic_core_io_bus_d_payload_opcode;
  assign system_peripheral_uart_node_bus_d_payload_param = system_peripheral_uart_logic_core_io_bus_d_payload_param;
  assign system_peripheral_uart_node_bus_d_payload_source = system_peripheral_uart_logic_core_io_bus_d_payload_source;
  assign system_peripheral_uart_node_bus_d_payload_size = system_peripheral_uart_logic_core_io_bus_d_payload_size;
  assign system_peripheral_uart_node_bus_d_payload_denied = system_peripheral_uart_logic_core_io_bus_d_payload_denied;
  assign system_peripheral_uart_node_bus_d_payload_data = system_peripheral_uart_logic_core_io_bus_d_payload_data;
  assign system_peripheral_uart_node_bus_d_payload_corrupt = system_peripheral_uart_logic_core_io_bus_d_payload_corrupt;
  assign system_peripheral_uart_interrupt_flag = system_peripheral_uart_logic_core_io_interrupt;
  assign system_peripheral_uart_logic_uart_txd = system_peripheral_uart_logic_core_io_uart_txd;
  assign system_peripheral_demo_node_bus_a_ready = system_peripheral_demo_logic_core_io_bus_a_ready;
  assign system_peripheral_demo_node_bus_d_valid = system_peripheral_demo_logic_core_io_bus_d_valid;
  assign system_peripheral_demo_node_bus_d_payload_opcode = system_peripheral_demo_logic_core_io_bus_d_payload_opcode;
  assign system_peripheral_demo_node_bus_d_payload_param = system_peripheral_demo_logic_core_io_bus_d_payload_param;
  assign system_peripheral_demo_node_bus_d_payload_source = system_peripheral_demo_logic_core_io_bus_d_payload_source;
  assign system_peripheral_demo_node_bus_d_payload_size = system_peripheral_demo_logic_core_io_bus_d_payload_size;
  assign system_peripheral_demo_node_bus_d_payload_denied = system_peripheral_demo_logic_core_io_bus_d_payload_denied;
  assign system_peripheral_demo_node_bus_d_payload_data = system_peripheral_demo_logic_core_io_bus_d_payload_data;
  assign system_peripheral_demo_node_bus_d_payload_corrupt = system_peripheral_demo_logic_core_io_bus_d_payload_corrupt;
  assign system_peripheral_demo_interrupt_flag = system_peripheral_demo_logic_core_io_interrupt;
  assign system_peripheral_demo_logic_leds = system_peripheral_demo_logic_core_io_leds;
  assign system_peripheral_busXlen_to_system_peripheral_bus32_down_bus_a_valid = system_peripheral_busXlen_to_system_peripheral_bus32_up_bus_a_valid;
  assign system_peripheral_busXlen_to_system_peripheral_bus32_up_bus_a_ready = system_peripheral_busXlen_to_system_peripheral_bus32_down_bus_a_ready;
  assign system_peripheral_busXlen_to_system_peripheral_bus32_down_bus_a_payload_opcode = system_peripheral_busXlen_to_system_peripheral_bus32_up_bus_a_payload_opcode;
  assign system_peripheral_busXlen_to_system_peripheral_bus32_down_bus_a_payload_param = system_peripheral_busXlen_to_system_peripheral_bus32_up_bus_a_payload_param;
  assign system_peripheral_busXlen_to_system_peripheral_bus32_down_bus_a_payload_source = system_peripheral_busXlen_to_system_peripheral_bus32_up_bus_a_payload_source;
  assign system_peripheral_busXlen_to_system_peripheral_bus32_down_bus_a_payload_address = system_peripheral_busXlen_to_system_peripheral_bus32_up_bus_a_payload_address;
  assign system_peripheral_busXlen_to_system_peripheral_bus32_down_bus_a_payload_size = system_peripheral_busXlen_to_system_peripheral_bus32_up_bus_a_payload_size;
  assign system_peripheral_busXlen_to_system_peripheral_bus32_down_bus_a_payload_mask = system_peripheral_busXlen_to_system_peripheral_bus32_up_bus_a_payload_mask;
  assign system_peripheral_busXlen_to_system_peripheral_bus32_down_bus_a_payload_data = system_peripheral_busXlen_to_system_peripheral_bus32_up_bus_a_payload_data;
  assign system_peripheral_busXlen_to_system_peripheral_bus32_down_bus_a_payload_corrupt = system_peripheral_busXlen_to_system_peripheral_bus32_up_bus_a_payload_corrupt;
  assign system_peripheral_busXlen_to_system_peripheral_bus32_up_bus_d_valid = system_peripheral_busXlen_to_system_peripheral_bus32_down_bus_d_valid;
  assign system_peripheral_busXlen_to_system_peripheral_bus32_down_bus_d_ready = system_peripheral_busXlen_to_system_peripheral_bus32_up_bus_d_ready;
  assign system_peripheral_busXlen_to_system_peripheral_bus32_up_bus_d_payload_opcode = system_peripheral_busXlen_to_system_peripheral_bus32_down_bus_d_payload_opcode;
  assign system_peripheral_busXlen_to_system_peripheral_bus32_up_bus_d_payload_param = system_peripheral_busXlen_to_system_peripheral_bus32_down_bus_d_payload_param;
  assign system_peripheral_busXlen_to_system_peripheral_bus32_up_bus_d_payload_source = system_peripheral_busXlen_to_system_peripheral_bus32_down_bus_d_payload_source;
  assign system_peripheral_busXlen_to_system_peripheral_bus32_up_bus_d_payload_size = system_peripheral_busXlen_to_system_peripheral_bus32_down_bus_d_payload_size;
  assign system_peripheral_busXlen_to_system_peripheral_bus32_up_bus_d_payload_denied = system_peripheral_busXlen_to_system_peripheral_bus32_down_bus_d_payload_denied;
  assign system_peripheral_busXlen_to_system_peripheral_bus32_up_bus_d_payload_data = system_peripheral_busXlen_to_system_peripheral_bus32_down_bus_d_payload_data;
  assign system_peripheral_busXlen_to_system_peripheral_bus32_up_bus_d_payload_corrupt = system_peripheral_busXlen_to_system_peripheral_bus32_down_bus_d_payload_corrupt;
  assign system_peripheral_busXlen_to_system_peripheral_clint_node_down_bus_a_valid = system_peripheral_busXlen_to_system_peripheral_clint_node_up_bus_a_valid;
  assign system_peripheral_busXlen_to_system_peripheral_clint_node_up_bus_a_ready = system_peripheral_busXlen_to_system_peripheral_clint_node_down_bus_a_ready;
  assign system_peripheral_busXlen_to_system_peripheral_clint_node_down_bus_a_payload_opcode = system_peripheral_busXlen_to_system_peripheral_clint_node_up_bus_a_payload_opcode;
  assign system_peripheral_busXlen_to_system_peripheral_clint_node_down_bus_a_payload_param = system_peripheral_busXlen_to_system_peripheral_clint_node_up_bus_a_payload_param;
  assign system_peripheral_busXlen_to_system_peripheral_clint_node_down_bus_a_payload_source = system_peripheral_busXlen_to_system_peripheral_clint_node_up_bus_a_payload_source;
  assign system_peripheral_busXlen_to_system_peripheral_clint_node_down_bus_a_payload_address = system_peripheral_busXlen_to_system_peripheral_clint_node_up_bus_a_payload_address;
  assign system_peripheral_busXlen_to_system_peripheral_clint_node_down_bus_a_payload_size = system_peripheral_busXlen_to_system_peripheral_clint_node_up_bus_a_payload_size;
  assign system_peripheral_busXlen_to_system_peripheral_clint_node_down_bus_a_payload_mask = system_peripheral_busXlen_to_system_peripheral_clint_node_up_bus_a_payload_mask;
  assign system_peripheral_busXlen_to_system_peripheral_clint_node_down_bus_a_payload_data = system_peripheral_busXlen_to_system_peripheral_clint_node_up_bus_a_payload_data;
  assign system_peripheral_busXlen_to_system_peripheral_clint_node_down_bus_a_payload_corrupt = system_peripheral_busXlen_to_system_peripheral_clint_node_up_bus_a_payload_corrupt;
  assign system_peripheral_busXlen_to_system_peripheral_clint_node_up_bus_d_valid = system_peripheral_busXlen_to_system_peripheral_clint_node_down_bus_d_valid;
  assign system_peripheral_busXlen_to_system_peripheral_clint_node_down_bus_d_ready = system_peripheral_busXlen_to_system_peripheral_clint_node_up_bus_d_ready;
  assign system_peripheral_busXlen_to_system_peripheral_clint_node_up_bus_d_payload_opcode = system_peripheral_busXlen_to_system_peripheral_clint_node_down_bus_d_payload_opcode;
  assign system_peripheral_busXlen_to_system_peripheral_clint_node_up_bus_d_payload_param = system_peripheral_busXlen_to_system_peripheral_clint_node_down_bus_d_payload_param;
  assign system_peripheral_busXlen_to_system_peripheral_clint_node_up_bus_d_payload_source = system_peripheral_busXlen_to_system_peripheral_clint_node_down_bus_d_payload_source;
  assign system_peripheral_busXlen_to_system_peripheral_clint_node_up_bus_d_payload_size = system_peripheral_busXlen_to_system_peripheral_clint_node_down_bus_d_payload_size;
  assign system_peripheral_busXlen_to_system_peripheral_clint_node_up_bus_d_payload_denied = system_peripheral_busXlen_to_system_peripheral_clint_node_down_bus_d_payload_denied;
  assign system_peripheral_busXlen_to_system_peripheral_clint_node_up_bus_d_payload_data = system_peripheral_busXlen_to_system_peripheral_clint_node_down_bus_d_payload_data;
  assign system_peripheral_busXlen_to_system_peripheral_clint_node_up_bus_d_payload_corrupt = system_peripheral_busXlen_to_system_peripheral_clint_node_down_bus_d_payload_corrupt;
  assign system_mainBus_to_system_ram_up_down_bus_a_valid = system_mainBus_to_system_ram_up_up_bus_a_valid;
  assign system_mainBus_to_system_ram_up_up_bus_a_ready = system_mainBus_to_system_ram_up_down_bus_a_ready;
  assign system_mainBus_to_system_ram_up_down_bus_a_payload_opcode = system_mainBus_to_system_ram_up_up_bus_a_payload_opcode;
  assign system_mainBus_to_system_ram_up_down_bus_a_payload_param = system_mainBus_to_system_ram_up_up_bus_a_payload_param;
  assign system_mainBus_to_system_ram_up_down_bus_a_payload_source = system_mainBus_to_system_ram_up_up_bus_a_payload_source;
  assign system_mainBus_to_system_ram_up_down_bus_a_payload_address = system_mainBus_to_system_ram_up_up_bus_a_payload_address;
  assign system_mainBus_to_system_ram_up_down_bus_a_payload_size = system_mainBus_to_system_ram_up_up_bus_a_payload_size;
  assign system_mainBus_to_system_ram_up_down_bus_a_payload_mask = system_mainBus_to_system_ram_up_up_bus_a_payload_mask;
  assign system_mainBus_to_system_ram_up_down_bus_a_payload_data = system_mainBus_to_system_ram_up_up_bus_a_payload_data;
  assign system_mainBus_to_system_ram_up_down_bus_a_payload_corrupt = system_mainBus_to_system_ram_up_up_bus_a_payload_corrupt;
  assign system_mainBus_to_system_ram_up_up_bus_d_valid = system_mainBus_to_system_ram_up_down_bus_d_valid;
  assign system_mainBus_to_system_ram_up_down_bus_d_ready = system_mainBus_to_system_ram_up_up_bus_d_ready;
  assign system_mainBus_to_system_ram_up_up_bus_d_payload_opcode = system_mainBus_to_system_ram_up_down_bus_d_payload_opcode;
  assign system_mainBus_to_system_ram_up_up_bus_d_payload_param = system_mainBus_to_system_ram_up_down_bus_d_payload_param;
  assign system_mainBus_to_system_ram_up_up_bus_d_payload_source = system_mainBus_to_system_ram_up_down_bus_d_payload_source;
  assign system_mainBus_to_system_ram_up_up_bus_d_payload_size = system_mainBus_to_system_ram_up_down_bus_d_payload_size;
  assign system_mainBus_to_system_ram_up_up_bus_d_payload_denied = system_mainBus_to_system_ram_up_down_bus_d_payload_denied;
  assign system_mainBus_to_system_ram_up_up_bus_d_payload_data = system_mainBus_to_system_ram_up_down_bus_d_payload_data;
  assign system_mainBus_to_system_ram_up_up_bus_d_payload_corrupt = system_mainBus_to_system_ram_up_down_bus_d_payload_corrupt;
  assign system_mainBus_to_system_peripheral_busXlen_up_bus_a_ready = system_mainBus_to_system_peripheral_busXlen_widthAdapter_io_up_a_ready;
  assign system_mainBus_to_system_peripheral_busXlen_up_bus_d_valid = system_mainBus_to_system_peripheral_busXlen_widthAdapter_io_up_d_valid;
  assign system_mainBus_to_system_peripheral_busXlen_up_bus_d_payload_opcode = system_mainBus_to_system_peripheral_busXlen_widthAdapter_io_up_d_payload_opcode;
  assign system_mainBus_to_system_peripheral_busXlen_up_bus_d_payload_param = system_mainBus_to_system_peripheral_busXlen_widthAdapter_io_up_d_payload_param;
  assign system_mainBus_to_system_peripheral_busXlen_up_bus_d_payload_source = system_mainBus_to_system_peripheral_busXlen_widthAdapter_io_up_d_payload_source;
  assign system_mainBus_to_system_peripheral_busXlen_up_bus_d_payload_size = system_mainBus_to_system_peripheral_busXlen_widthAdapter_io_up_d_payload_size;
  assign system_mainBus_to_system_peripheral_busXlen_up_bus_d_payload_denied = system_mainBus_to_system_peripheral_busXlen_widthAdapter_io_up_d_payload_denied;
  assign system_mainBus_to_system_peripheral_busXlen_up_bus_d_payload_data = system_mainBus_to_system_peripheral_busXlen_widthAdapter_io_up_d_payload_data;
  assign system_mainBus_to_system_peripheral_busXlen_up_bus_d_payload_corrupt = system_mainBus_to_system_peripheral_busXlen_widthAdapter_io_up_d_payload_corrupt;
  assign system_mainBus_to_system_peripheral_busXlen_down_bus_a_valid = system_mainBus_to_system_peripheral_busXlen_widthAdapter_io_down_a_valid;
  assign system_mainBus_to_system_peripheral_busXlen_down_bus_a_payload_opcode = system_mainBus_to_system_peripheral_busXlen_widthAdapter_io_down_a_payload_opcode;
  assign system_mainBus_to_system_peripheral_busXlen_down_bus_a_payload_param = system_mainBus_to_system_peripheral_busXlen_widthAdapter_io_down_a_payload_param;
  assign system_mainBus_to_system_peripheral_busXlen_down_bus_a_payload_source = system_mainBus_to_system_peripheral_busXlen_widthAdapter_io_down_a_payload_source;
  assign system_mainBus_to_system_peripheral_busXlen_down_bus_a_payload_address = system_mainBus_to_system_peripheral_busXlen_widthAdapter_io_down_a_payload_address;
  assign system_mainBus_to_system_peripheral_busXlen_down_bus_a_payload_size = system_mainBus_to_system_peripheral_busXlen_widthAdapter_io_down_a_payload_size;
  assign system_mainBus_to_system_peripheral_busXlen_down_bus_a_payload_mask = system_mainBus_to_system_peripheral_busXlen_widthAdapter_io_down_a_payload_mask;
  assign system_mainBus_to_system_peripheral_busXlen_down_bus_a_payload_data = system_mainBus_to_system_peripheral_busXlen_widthAdapter_io_down_a_payload_data;
  assign system_mainBus_to_system_peripheral_busXlen_down_bus_a_payload_corrupt = system_mainBus_to_system_peripheral_busXlen_widthAdapter_io_down_a_payload_corrupt;
  assign system_mainBus_to_system_peripheral_busXlen_down_bus_d_ready = system_mainBus_to_system_peripheral_busXlen_widthAdapter_io_down_d_ready;
  assign system_peripheral_bus32_to_system_peripheral_plic_node_up_bus_a_valid = system_peripheral_bus32_decoder_core_io_downs_0_a_valid;
  assign system_peripheral_bus32_to_system_peripheral_plic_node_up_bus_a_payload_opcode = system_peripheral_bus32_decoder_core_io_downs_0_a_payload_opcode;
  assign system_peripheral_bus32_to_system_peripheral_plic_node_up_bus_a_payload_param = system_peripheral_bus32_decoder_core_io_downs_0_a_payload_param;
  assign system_peripheral_bus32_to_system_peripheral_plic_node_up_bus_a_payload_source = system_peripheral_bus32_decoder_core_io_downs_0_a_payload_source;
  assign system_peripheral_bus32_to_system_peripheral_plic_node_up_bus_a_payload_address = system_peripheral_bus32_decoder_core_io_downs_0_a_payload_address;
  assign system_peripheral_bus32_to_system_peripheral_plic_node_up_bus_a_payload_size = system_peripheral_bus32_decoder_core_io_downs_0_a_payload_size;
  assign system_peripheral_bus32_to_system_peripheral_plic_node_up_bus_a_payload_mask = system_peripheral_bus32_decoder_core_io_downs_0_a_payload_mask;
  assign system_peripheral_bus32_to_system_peripheral_plic_node_up_bus_a_payload_data = system_peripheral_bus32_decoder_core_io_downs_0_a_payload_data;
  assign system_peripheral_bus32_to_system_peripheral_plic_node_up_bus_a_payload_corrupt = system_peripheral_bus32_decoder_core_io_downs_0_a_payload_corrupt;
  assign system_peripheral_bus32_to_system_peripheral_plic_node_up_bus_d_ready = system_peripheral_bus32_decoder_core_io_downs_0_d_ready;
  assign system_peripheral_bus32_to_system_peripheral_uart_node_up_bus_a_valid = system_peripheral_bus32_decoder_core_io_downs_1_a_valid;
  assign system_peripheral_bus32_to_system_peripheral_uart_node_up_bus_a_payload_opcode = system_peripheral_bus32_decoder_core_io_downs_1_a_payload_opcode;
  assign system_peripheral_bus32_to_system_peripheral_uart_node_up_bus_a_payload_param = system_peripheral_bus32_decoder_core_io_downs_1_a_payload_param;
  assign system_peripheral_bus32_to_system_peripheral_uart_node_up_bus_a_payload_source = system_peripheral_bus32_decoder_core_io_downs_1_a_payload_source;
  assign system_peripheral_bus32_to_system_peripheral_uart_node_up_bus_a_payload_address = system_peripheral_bus32_decoder_core_io_downs_1_a_payload_address;
  assign system_peripheral_bus32_to_system_peripheral_uart_node_up_bus_a_payload_size = system_peripheral_bus32_decoder_core_io_downs_1_a_payload_size;
  assign system_peripheral_bus32_to_system_peripheral_uart_node_up_bus_a_payload_mask = system_peripheral_bus32_decoder_core_io_downs_1_a_payload_mask;
  assign system_peripheral_bus32_to_system_peripheral_uart_node_up_bus_a_payload_data = system_peripheral_bus32_decoder_core_io_downs_1_a_payload_data;
  assign system_peripheral_bus32_to_system_peripheral_uart_node_up_bus_a_payload_corrupt = system_peripheral_bus32_decoder_core_io_downs_1_a_payload_corrupt;
  assign system_peripheral_bus32_to_system_peripheral_uart_node_up_bus_d_ready = system_peripheral_bus32_decoder_core_io_downs_1_d_ready;
  assign system_peripheral_bus32_to_system_peripheral_demo_node_up_bus_a_valid = system_peripheral_bus32_decoder_core_io_downs_2_a_valid;
  assign system_peripheral_bus32_to_system_peripheral_demo_node_up_bus_a_payload_opcode = system_peripheral_bus32_decoder_core_io_downs_2_a_payload_opcode;
  assign system_peripheral_bus32_to_system_peripheral_demo_node_up_bus_a_payload_param = system_peripheral_bus32_decoder_core_io_downs_2_a_payload_param;
  assign system_peripheral_bus32_to_system_peripheral_demo_node_up_bus_a_payload_source = system_peripheral_bus32_decoder_core_io_downs_2_a_payload_source;
  assign system_peripheral_bus32_to_system_peripheral_demo_node_up_bus_a_payload_address = system_peripheral_bus32_decoder_core_io_downs_2_a_payload_address;
  assign system_peripheral_bus32_to_system_peripheral_demo_node_up_bus_a_payload_size = system_peripheral_bus32_decoder_core_io_downs_2_a_payload_size;
  assign system_peripheral_bus32_to_system_peripheral_demo_node_up_bus_a_payload_mask = system_peripheral_bus32_decoder_core_io_downs_2_a_payload_mask;
  assign system_peripheral_bus32_to_system_peripheral_demo_node_up_bus_a_payload_data = system_peripheral_bus32_decoder_core_io_downs_2_a_payload_data;
  assign system_peripheral_bus32_to_system_peripheral_demo_node_up_bus_a_payload_corrupt = system_peripheral_bus32_decoder_core_io_downs_2_a_payload_corrupt;
  assign system_peripheral_bus32_to_system_peripheral_demo_node_up_bus_d_ready = system_peripheral_bus32_decoder_core_io_downs_2_d_ready;
  assign system_peripheral_bus32_bus_a_ready = system_peripheral_bus32_decoder_core_io_up_a_ready;
  assign system_peripheral_bus32_bus_d_valid = system_peripheral_bus32_decoder_core_io_up_d_valid;
  assign system_peripheral_bus32_bus_d_payload_opcode = system_peripheral_bus32_decoder_core_io_up_d_payload_opcode;
  assign system_peripheral_bus32_bus_d_payload_param = system_peripheral_bus32_decoder_core_io_up_d_payload_param;
  assign system_peripheral_bus32_bus_d_payload_source = system_peripheral_bus32_decoder_core_io_up_d_payload_source;
  assign system_peripheral_bus32_bus_d_payload_size = system_peripheral_bus32_decoder_core_io_up_d_payload_size;
  assign system_peripheral_bus32_bus_d_payload_denied = system_peripheral_bus32_decoder_core_io_up_d_payload_denied;
  assign system_peripheral_bus32_bus_d_payload_data = system_peripheral_bus32_decoder_core_io_up_d_payload_data;
  assign system_peripheral_bus32_bus_d_payload_corrupt = system_peripheral_bus32_decoder_core_io_up_d_payload_corrupt;
  assign system_peripheral_bus32_to_system_peripheral_plic_node_down_bus_a_valid = system_peripheral_bus32_to_system_peripheral_plic_node_up_bus_a_valid;
  assign system_peripheral_bus32_to_system_peripheral_plic_node_up_bus_a_ready = system_peripheral_bus32_to_system_peripheral_plic_node_down_bus_a_ready;
  assign system_peripheral_bus32_to_system_peripheral_plic_node_down_bus_a_payload_opcode = system_peripheral_bus32_to_system_peripheral_plic_node_up_bus_a_payload_opcode;
  assign system_peripheral_bus32_to_system_peripheral_plic_node_down_bus_a_payload_param = system_peripheral_bus32_to_system_peripheral_plic_node_up_bus_a_payload_param;
  assign system_peripheral_bus32_to_system_peripheral_plic_node_down_bus_a_payload_source = system_peripheral_bus32_to_system_peripheral_plic_node_up_bus_a_payload_source;
  assign system_peripheral_bus32_to_system_peripheral_plic_node_down_bus_a_payload_address = system_peripheral_bus32_to_system_peripheral_plic_node_up_bus_a_payload_address;
  assign system_peripheral_bus32_to_system_peripheral_plic_node_down_bus_a_payload_size = system_peripheral_bus32_to_system_peripheral_plic_node_up_bus_a_payload_size;
  assign system_peripheral_bus32_to_system_peripheral_plic_node_down_bus_a_payload_mask = system_peripheral_bus32_to_system_peripheral_plic_node_up_bus_a_payload_mask;
  assign system_peripheral_bus32_to_system_peripheral_plic_node_down_bus_a_payload_data = system_peripheral_bus32_to_system_peripheral_plic_node_up_bus_a_payload_data;
  assign system_peripheral_bus32_to_system_peripheral_plic_node_down_bus_a_payload_corrupt = system_peripheral_bus32_to_system_peripheral_plic_node_up_bus_a_payload_corrupt;
  assign system_peripheral_bus32_to_system_peripheral_plic_node_up_bus_d_valid = system_peripheral_bus32_to_system_peripheral_plic_node_down_bus_d_valid;
  assign system_peripheral_bus32_to_system_peripheral_plic_node_down_bus_d_ready = system_peripheral_bus32_to_system_peripheral_plic_node_up_bus_d_ready;
  assign system_peripheral_bus32_to_system_peripheral_plic_node_up_bus_d_payload_opcode = system_peripheral_bus32_to_system_peripheral_plic_node_down_bus_d_payload_opcode;
  assign system_peripheral_bus32_to_system_peripheral_plic_node_up_bus_d_payload_param = system_peripheral_bus32_to_system_peripheral_plic_node_down_bus_d_payload_param;
  assign system_peripheral_bus32_to_system_peripheral_plic_node_up_bus_d_payload_source = system_peripheral_bus32_to_system_peripheral_plic_node_down_bus_d_payload_source;
  assign system_peripheral_bus32_to_system_peripheral_plic_node_up_bus_d_payload_size = system_peripheral_bus32_to_system_peripheral_plic_node_down_bus_d_payload_size;
  assign system_peripheral_bus32_to_system_peripheral_plic_node_up_bus_d_payload_denied = system_peripheral_bus32_to_system_peripheral_plic_node_down_bus_d_payload_denied;
  assign system_peripheral_bus32_to_system_peripheral_plic_node_up_bus_d_payload_data = system_peripheral_bus32_to_system_peripheral_plic_node_down_bus_d_payload_data;
  assign system_peripheral_bus32_to_system_peripheral_plic_node_up_bus_d_payload_corrupt = system_peripheral_bus32_to_system_peripheral_plic_node_down_bus_d_payload_corrupt;
  assign system_peripheral_bus32_to_system_peripheral_uart_node_down_bus_a_valid = system_peripheral_bus32_to_system_peripheral_uart_node_up_bus_a_valid;
  assign system_peripheral_bus32_to_system_peripheral_uart_node_up_bus_a_ready = system_peripheral_bus32_to_system_peripheral_uart_node_down_bus_a_ready;
  assign system_peripheral_bus32_to_system_peripheral_uart_node_down_bus_a_payload_opcode = system_peripheral_bus32_to_system_peripheral_uart_node_up_bus_a_payload_opcode;
  assign system_peripheral_bus32_to_system_peripheral_uart_node_down_bus_a_payload_param = system_peripheral_bus32_to_system_peripheral_uart_node_up_bus_a_payload_param;
  assign system_peripheral_bus32_to_system_peripheral_uart_node_down_bus_a_payload_source = system_peripheral_bus32_to_system_peripheral_uart_node_up_bus_a_payload_source;
  assign system_peripheral_bus32_to_system_peripheral_uart_node_down_bus_a_payload_address = system_peripheral_bus32_to_system_peripheral_uart_node_up_bus_a_payload_address;
  assign system_peripheral_bus32_to_system_peripheral_uart_node_down_bus_a_payload_size = system_peripheral_bus32_to_system_peripheral_uart_node_up_bus_a_payload_size;
  assign system_peripheral_bus32_to_system_peripheral_uart_node_down_bus_a_payload_mask = system_peripheral_bus32_to_system_peripheral_uart_node_up_bus_a_payload_mask;
  assign system_peripheral_bus32_to_system_peripheral_uart_node_down_bus_a_payload_data = system_peripheral_bus32_to_system_peripheral_uart_node_up_bus_a_payload_data;
  assign system_peripheral_bus32_to_system_peripheral_uart_node_down_bus_a_payload_corrupt = system_peripheral_bus32_to_system_peripheral_uart_node_up_bus_a_payload_corrupt;
  assign system_peripheral_bus32_to_system_peripheral_uart_node_up_bus_d_valid = system_peripheral_bus32_to_system_peripheral_uart_node_down_bus_d_valid;
  assign system_peripheral_bus32_to_system_peripheral_uart_node_down_bus_d_ready = system_peripheral_bus32_to_system_peripheral_uart_node_up_bus_d_ready;
  assign system_peripheral_bus32_to_system_peripheral_uart_node_up_bus_d_payload_opcode = system_peripheral_bus32_to_system_peripheral_uart_node_down_bus_d_payload_opcode;
  assign system_peripheral_bus32_to_system_peripheral_uart_node_up_bus_d_payload_param = system_peripheral_bus32_to_system_peripheral_uart_node_down_bus_d_payload_param;
  assign system_peripheral_bus32_to_system_peripheral_uart_node_up_bus_d_payload_source = system_peripheral_bus32_to_system_peripheral_uart_node_down_bus_d_payload_source;
  assign system_peripheral_bus32_to_system_peripheral_uart_node_up_bus_d_payload_size = system_peripheral_bus32_to_system_peripheral_uart_node_down_bus_d_payload_size;
  assign system_peripheral_bus32_to_system_peripheral_uart_node_up_bus_d_payload_denied = system_peripheral_bus32_to_system_peripheral_uart_node_down_bus_d_payload_denied;
  assign system_peripheral_bus32_to_system_peripheral_uart_node_up_bus_d_payload_data = system_peripheral_bus32_to_system_peripheral_uart_node_down_bus_d_payload_data;
  assign system_peripheral_bus32_to_system_peripheral_uart_node_up_bus_d_payload_corrupt = system_peripheral_bus32_to_system_peripheral_uart_node_down_bus_d_payload_corrupt;
  assign system_peripheral_bus32_to_system_peripheral_demo_node_down_bus_a_valid = system_peripheral_bus32_to_system_peripheral_demo_node_up_bus_a_valid;
  assign system_peripheral_bus32_to_system_peripheral_demo_node_up_bus_a_ready = system_peripheral_bus32_to_system_peripheral_demo_node_down_bus_a_ready;
  assign system_peripheral_bus32_to_system_peripheral_demo_node_down_bus_a_payload_opcode = system_peripheral_bus32_to_system_peripheral_demo_node_up_bus_a_payload_opcode;
  assign system_peripheral_bus32_to_system_peripheral_demo_node_down_bus_a_payload_param = system_peripheral_bus32_to_system_peripheral_demo_node_up_bus_a_payload_param;
  assign system_peripheral_bus32_to_system_peripheral_demo_node_down_bus_a_payload_source = system_peripheral_bus32_to_system_peripheral_demo_node_up_bus_a_payload_source;
  assign system_peripheral_bus32_to_system_peripheral_demo_node_down_bus_a_payload_address = system_peripheral_bus32_to_system_peripheral_demo_node_up_bus_a_payload_address;
  assign system_peripheral_bus32_to_system_peripheral_demo_node_down_bus_a_payload_size = system_peripheral_bus32_to_system_peripheral_demo_node_up_bus_a_payload_size;
  assign system_peripheral_bus32_to_system_peripheral_demo_node_down_bus_a_payload_mask = system_peripheral_bus32_to_system_peripheral_demo_node_up_bus_a_payload_mask;
  assign system_peripheral_bus32_to_system_peripheral_demo_node_down_bus_a_payload_data = system_peripheral_bus32_to_system_peripheral_demo_node_up_bus_a_payload_data;
  assign system_peripheral_bus32_to_system_peripheral_demo_node_down_bus_a_payload_corrupt = system_peripheral_bus32_to_system_peripheral_demo_node_up_bus_a_payload_corrupt;
  assign system_peripheral_bus32_to_system_peripheral_demo_node_up_bus_d_valid = system_peripheral_bus32_to_system_peripheral_demo_node_down_bus_d_valid;
  assign system_peripheral_bus32_to_system_peripheral_demo_node_down_bus_d_ready = system_peripheral_bus32_to_system_peripheral_demo_node_up_bus_d_ready;
  assign system_peripheral_bus32_to_system_peripheral_demo_node_up_bus_d_payload_opcode = system_peripheral_bus32_to_system_peripheral_demo_node_down_bus_d_payload_opcode;
  assign system_peripheral_bus32_to_system_peripheral_demo_node_up_bus_d_payload_param = system_peripheral_bus32_to_system_peripheral_demo_node_down_bus_d_payload_param;
  assign system_peripheral_bus32_to_system_peripheral_demo_node_up_bus_d_payload_source = system_peripheral_bus32_to_system_peripheral_demo_node_down_bus_d_payload_source;
  assign system_peripheral_bus32_to_system_peripheral_demo_node_up_bus_d_payload_size = system_peripheral_bus32_to_system_peripheral_demo_node_down_bus_d_payload_size;
  assign system_peripheral_bus32_to_system_peripheral_demo_node_up_bus_d_payload_denied = system_peripheral_bus32_to_system_peripheral_demo_node_down_bus_d_payload_denied;
  assign system_peripheral_bus32_to_system_peripheral_demo_node_up_bus_d_payload_data = system_peripheral_bus32_to_system_peripheral_demo_node_down_bus_d_payload_data;
  assign system_peripheral_bus32_to_system_peripheral_demo_node_up_bus_d_payload_corrupt = system_peripheral_bus32_to_system_peripheral_demo_node_down_bus_d_payload_corrupt;
  always @(posedge socCtrl_systemClk) begin
    system_cpu_priv_stoptime_regNext <= system_cpu_priv_stoptime;
    _zz_system_cpu_priv_rdtime <= system_peripheral_clint_time;
    if(system_cpu_dBus_bus_a_ready) begin
      system_cpu_dBus_bus_a_rData_opcode <= system_cpu_dBus_bus_a_payload_opcode;
      system_cpu_dBus_bus_a_rData_param <= system_cpu_dBus_bus_a_payload_param;
      system_cpu_dBus_bus_a_rData_address <= system_cpu_dBus_bus_a_payload_address;
      system_cpu_dBus_bus_a_rData_size <= system_cpu_dBus_bus_a_payload_size;
      system_cpu_dBus_bus_a_rData_mask <= system_cpu_dBus_bus_a_payload_mask;
      system_cpu_dBus_bus_a_rData_data <= system_cpu_dBus_bus_a_payload_data;
      system_cpu_dBus_bus_a_rData_corrupt <= system_cpu_dBus_bus_a_payload_corrupt;
    end
    if(system_mainBus_to_system_peripheral_busXlen_down_bus_a_ready) begin
      system_mainBus_to_system_peripheral_busXlen_down_bus_a_rData_opcode <= system_mainBus_to_system_peripheral_busXlen_down_bus_a_payload_opcode;
      system_mainBus_to_system_peripheral_busXlen_down_bus_a_rData_param <= system_mainBus_to_system_peripheral_busXlen_down_bus_a_payload_param;
      system_mainBus_to_system_peripheral_busXlen_down_bus_a_rData_source <= system_mainBus_to_system_peripheral_busXlen_down_bus_a_payload_source;
      system_mainBus_to_system_peripheral_busXlen_down_bus_a_rData_address <= system_mainBus_to_system_peripheral_busXlen_down_bus_a_payload_address;
      system_mainBus_to_system_peripheral_busXlen_down_bus_a_rData_size <= system_mainBus_to_system_peripheral_busXlen_down_bus_a_payload_size;
      system_mainBus_to_system_peripheral_busXlen_down_bus_a_rData_mask <= system_mainBus_to_system_peripheral_busXlen_down_bus_a_payload_mask;
      system_mainBus_to_system_peripheral_busXlen_down_bus_a_rData_data <= system_mainBus_to_system_peripheral_busXlen_down_bus_a_payload_data;
      system_mainBus_to_system_peripheral_busXlen_down_bus_a_rData_corrupt <= system_mainBus_to_system_peripheral_busXlen_down_bus_a_payload_corrupt;
    end
    if(system_peripheral_busXlen_bus_d_ready) begin
      system_peripheral_busXlen_bus_d_rData_opcode <= system_peripheral_busXlen_bus_d_payload_opcode;
      system_peripheral_busXlen_bus_d_rData_param <= system_peripheral_busXlen_bus_d_payload_param;
      system_peripheral_busXlen_bus_d_rData_source <= system_peripheral_busXlen_bus_d_payload_source;
      system_peripheral_busXlen_bus_d_rData_size <= system_peripheral_busXlen_bus_d_payload_size;
      system_peripheral_busXlen_bus_d_rData_denied <= system_peripheral_busXlen_bus_d_payload_denied;
      system_peripheral_busXlen_bus_d_rData_data <= system_peripheral_busXlen_bus_d_payload_data;
      system_peripheral_busXlen_bus_d_rData_corrupt <= system_peripheral_busXlen_bus_d_payload_corrupt;
    end
  end

  always @(posedge socCtrl_systemClk or posedge socCtrl_debug_fiber_aggregator_reset) begin
    if(socCtrl_debug_fiber_aggregator_reset) begin
      socCtrl_debug_fiber_holder_counter <= 7'h0;
    end else begin
      if(when_CrossClock_l341) begin
        socCtrl_debug_fiber_holder_counter <= (socCtrl_debug_fiber_holder_counter + 7'h01);
      end
    end
  end

  always @(posedge socCtrl_systemClk or posedge socCtrl_system_fiber_aggregator_reset) begin
    if(socCtrl_system_fiber_aggregator_reset) begin
      socCtrl_system_fiber_holder_counter <= 7'h0;
    end else begin
      if(when_CrossClock_l341_1) begin
        socCtrl_system_fiber_holder_counter <= (socCtrl_system_fiber_holder_counter + 7'h01);
      end
    end
  end

  always @(posedge socCtrl_systemClk or posedge socCtrl_system_reset) begin
    if(socCtrl_system_reset) begin
      system_cpu_dBus_bus_a_rValidN <= 1'b1;
      system_mainBus_to_system_peripheral_busXlen_down_bus_a_rValid <= 1'b0;
      system_peripheral_busXlen_bus_d_rValid <= 1'b0;
    end else begin
      if(system_cpu_dBus_bus_a_valid) begin
        system_cpu_dBus_bus_a_rValidN <= 1'b0;
      end
      if(system_cpu_dBus_bus_a_s2mPipe_ready) begin
        system_cpu_dBus_bus_a_rValidN <= 1'b1;
      end
      if(system_mainBus_to_system_peripheral_busXlen_down_bus_a_valid) begin
        system_mainBus_to_system_peripheral_busXlen_down_bus_a_rValid <= 1'b1;
      end
      if(system_mainBus_to_system_peripheral_busXlen_down_bus_a_halfPipe_fire) begin
        system_mainBus_to_system_peripheral_busXlen_down_bus_a_rValid <= 1'b0;
      end
      if(system_peripheral_busXlen_bus_d_valid) begin
        system_peripheral_busXlen_bus_d_rValid <= 1'b1;
      end
      if(system_peripheral_busXlen_bus_d_halfPipe_fire) begin
        system_peripheral_busXlen_bus_d_rValid <= 1'b0;
      end
    end
  end


endmodule
