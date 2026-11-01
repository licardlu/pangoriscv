//=============================================================================
// pangoriscv - RV32IM processor core + native AXI4 SoC (Pango PG2L100H @ 27 MHz)
// Module : pangoriscv_axi_soc     File : rtl/soc/pangoriscv_axi_soc.v
// Rev    : 1.0                    Date : 2026-10-13
// Author : pango_lpenghan
// Brief  : SoC integration: core, interconnect, peripherals, reset synchroniser
//=============================================================================

`include "native_axi_macros.vh"
// ModelSim compiles each file as its own compilation unit, so the feature
// switches must be visible in every file that tests them (PDS also reads
// pangoriscv_axi_top.v first, but relying on that order would make the two
// flows disagree).
`include "soc_config.vh"
module pangoriscv_axi_soc #(
 parameter PROGRAM_INIT_FILE="",
 parameter DATA_INIT_FILE="",
 parameter integer READ_DELAY=0,
 parameter integer WRITE_DELAY=0
)(
 input wire clk,rst_n,
 input wire uart_rx,
 output wire uart_tx,
 input wire [1:0] gpio_input,
 output wire [31:0] gpio_ctrl,gpio_data,
 input wire spi_miso,
 output wire spi_mosi,spi_ss,spi_clk,
 input wire [1:0] ext_event,
 `CPU_STATUS_PORTS
);
 `AXI_WIRES(m,2)
`ifdef PERF_ENABLE
 `AXI_WIRES(s,8)
`else
 `AXI_WIRES(s,7)
`endif
`ifdef PERF_ENABLE
 // Slave 7 is the performance snapshot window at 0x60002000 (plan spec section 6).
 // It is compiled in only for instrumentation builds: the reference configuration
 // stays at seven slaves so the frozen default netlist is unchanged when it is off.
 localparam integer SLAVE_COUNT=8;
 localparam [32*8-1:0] SLAVE_BASE={32'h60002000,32'h60003000,32'h50000000,
  32'h40000000,32'h30000000,32'h20000000,32'h10000000,32'h00000000};
 localparam [32*8-1:0] SLAVE_SIZE={32'h1000,32'h1000,32'h1000,32'h1000,
  32'h1000,32'h1000,32'h4000,32'h8000};
 wire perf_fault;
 wire perf_i_miss,perf_d_miss,perf_if_wait,perf_lsu_wait,perf_pred_miss;
`else
 localparam integer SLAVE_COUNT=7;
 localparam [32*7-1:0] SLAVE_BASE={32'h60003000,32'h50000000,32'h40000000,
  32'h30000000,32'h20000000,32'h10000000,32'h00000000};
 localparam [32*7-1:0] SLAVE_SIZE={32'h1000,32'h1000,32'h1000,32'h1000,
  32'h1000,32'h4000,32'h8000};
`endif
 wire cpu_fault,interconnect_fault;
 wire [1:0] ram_fault;
 wire [4:0] peripheral_fault;
 wire local_irq_software,local_irq_timer,local_irq_external;
 wire fabric_fault=interconnect_fault || |ram_fault || |peripheral_fault
`ifdef PERF_ENABLE
  || perf_fault
`endif
  ;
 assign protocol_fault=cpu_fault || fabric_fault;
 pangoriscv_axi_top core(.clk(clk),.rst_n(rst_n),
  .fabric_fault(fabric_fault),.protocol_fault(cpu_fault),
`ifdef PERF_ENABLE
  .perf_i_miss(perf_i_miss),.perf_d_miss(perf_d_miss),
  .perf_if_wait(perf_if_wait),.perf_lsu_wait(perf_lsu_wait),
  .perf_pred_miss(perf_pred_miss),
`endif
  `CPU_STATUS_CONNECT_LOCAL_IRQ,`AXI_CONNECT_ALL(m,m)
 );
 axi_interconnect #(.MASTERS(2),.SLAVES(SLAVE_COUNT),
  .BASE_ADDR(SLAVE_BASE),.ADDR_SIZE(SLAVE_SIZE)) fabric(
  .clk(clk),.rst_n(rst_n),.protocol_fault(interconnect_fault),
  `AXI_CONNECT_ALL(m,m),`AXI_CONNECT_ALL(s,s)
 );
 axi_ram #(.BASE_ADDR(32'h00000000),.WORDS(8192),
  .INIT_FILE(PROGRAM_INIT_FILE),.READ_DELAY(READ_DELAY),
  .WRITE_DELAY(WRITE_DELAY),.WRITE_ENABLE(0)) program_ram(
  .clk(clk),.rst_n(rst_n),.protocol_fault(ram_fault[0]),
  `AXI_READ_CONNECT(s,s,0),`AXI_WRITE_CONNECT(s,s,0)
 );
 axi_ram #(.BASE_ADDR(32'h10000000),.WORDS(4096),
  .INIT_FILE(DATA_INIT_FILE),.READ_DELAY(READ_DELAY),
  .WRITE_DELAY(WRITE_DELAY)) data_ram(
  .clk(clk),.rst_n(rst_n),.protocol_fault(ram_fault[1]),
  `AXI_READ_CONNECT(s,s,1),`AXI_WRITE_CONNECT(s,s,1)
 );
 axi_timer timer_inst(.clk(clk),.rst_n(rst_n),.int_sig_o(local_irq_timer),
  .protocol_fault(peripheral_fault[0]),
  `AXI_READ_CONNECT(s,s,2),`AXI_WRITE_CONNECT(s,s,2));
 axi_uart uart_inst(.clk(clk),.rst_n(rst_n),.rx_pin(uart_rx),.tx_pin(uart_tx),
  .protocol_fault(peripheral_fault[1]),
  `AXI_READ_CONNECT(s,s,3),`AXI_WRITE_CONNECT(s,s,3));
 axi_gpio gpio_inst(.clk(clk),.rst_n(rst_n),.io_pin(gpio_input),
  .reg_ctrl(gpio_ctrl),.reg_data(gpio_data),.protocol_fault(peripheral_fault[2]),
  `AXI_READ_CONNECT(s,s,4),`AXI_WRITE_CONNECT(s,s,4));
 axi_spi spi_inst(.clk(clk),.rst_n(rst_n),.spi_miso(spi_miso),
  .spi_mosi(spi_mosi),.spi_ss(spi_ss),.spi_clk(spi_clk),
  .protocol_fault(peripheral_fault[3]),
  `AXI_READ_CONNECT(s,s,5),`AXI_WRITE_CONNECT(s,s,5));
 irq_ctrl irq_inst(.clk(clk),.rst_n(rst_n),.ext_event(ext_event),
  .irq_software(local_irq_software),.irq_external(local_irq_external),
  .protocol_fault(peripheral_fault[4]),
  `AXI_READ_CONNECT(s,s,6),`AXI_WRITE_CONNECT(s,s,6));
`ifdef PERF_ENABLE
 // T1a (plan v7 section 2): every event tap passes through one FF before it can
 // reach a counter enable.  The taps are combinational views of the core's own
 // control path -- `if_wait = fetch_enable && fetch_ready && !fetch_valid` hangs
 // off the branch-mispredict cone, and each 64 b counter's CE sits behind a
 // 16-stage CECO carry chain -- so the unregistered form WAS the tail of the
 // worst placed path (p7_path40b: br_miss -> perf_if_wait -> cnt[2][*]/CECO x16,
 // 2.18 ns of pure counter carry plus 1.7 ns of br_miss fanout).
 //
 // This costs one FF per tap and one cycle of skew on a *measurement* counter
 // only: the score comes from mcycle/minstret inside csr_native.v, which are not
 // touched.  Every tap goes through the same stage, so no two counters disagree.
 reg p_i_miss_q,p_d_miss_q,p_if_wait_q,p_lsu_wait_q,p_pred_miss_q;
 reg p_i_ar_q,p_i_r_q,p_i_rlast_q,p_d_ar_q,p_d_r_q,p_d_rlast_q;
 reg p_d_aw_q,p_d_w_q,p_d_b_q;
 reg [7:0] p_i_arlen_q,p_d_arlen_q;
 wire p_i_ar_w = m_arvalid[0] && m_arready[0];
 wire p_i_r_w  = m_rvalid[0]  && m_rready[0];
 wire p_d_ar_w = m_arvalid[1] && m_arready[1];
 wire p_d_r_w  = m_rvalid[1]  && m_rready[1];
 wire p_d_aw_w = m_awvalid[1] && m_awready[1];
 wire p_d_w_w  = m_wvalid[1]  && m_wready[1];
 wire p_d_b_w  = m_bvalid[1]  && m_bready[1];
 always @(posedge clk) begin
   if(!rst_n) begin
     p_i_miss_q<=0; p_d_miss_q<=0; p_if_wait_q<=0; p_lsu_wait_q<=0;
     p_pred_miss_q<=0; p_i_ar_q<=0; p_i_r_q<=0; p_i_rlast_q<=0;
     p_d_ar_q<=0; p_d_r_q<=0; p_d_rlast_q<=0; p_d_aw_q<=0; p_d_w_q<=0;
     p_d_b_q<=0; p_i_arlen_q<=0; p_d_arlen_q<=0;
   end else begin
     p_i_miss_q<=perf_i_miss;   p_d_miss_q<=perf_d_miss;
     p_if_wait_q<=perf_if_wait; p_lsu_wait_q<=perf_lsu_wait;
     p_pred_miss_q<=perf_pred_miss;
     p_i_ar_q<=p_i_ar_w; p_i_arlen_q<=m_arlen[0+:8];
     p_i_r_q<=p_i_r_w;   p_i_rlast_q<=m_rlast[0];
     p_d_ar_q<=p_d_ar_w; p_d_arlen_q<=m_arlen[8+:8];
     p_d_r_q<=p_d_r_w;   p_d_rlast_q<=m_rlast[1];
     p_d_aw_q<=p_d_aw_w; p_d_w_q<=p_d_w_w; p_d_b_q<=p_d_b_w;
   end
 end
 // The AXI activity taps watch the CPU side of the interconnect (m_*), so they
 // count exactly the bursts the caches issue.  pred_miss reports the dynamic
 // predictor's misses when PREDICT_ENABLE is set and the static not-taken
 // reference otherwise (see rtl/core/pangoriscv.v).
 perf_regs perf_inst(.clk(clk),.rst_n(rst_n),
  .retire_fire(retire_fire),.retire_inst(retire_inst),.pred_miss(p_pred_miss_q),
  .i_miss(p_i_miss_q),.d_miss(p_d_miss_q),
  .if_wait(p_if_wait_q),.lsu_wait(p_lsu_wait_q),
  .i_ar_fire(p_i_ar_q),.i_arlen(p_i_arlen_q),
  .i_r_fire(p_i_r_q),.i_rlast(p_i_rlast_q),
  .d_ar_fire(p_d_ar_q),.d_arlen(p_d_arlen_q),
  .d_r_fire(p_d_r_q),.d_rlast(p_d_rlast_q),
  .d_aw_fire(p_d_aw_q),.d_w_fire(p_d_w_q),.d_b_fire(p_d_b_q),
  .protocol_fault(perf_fault),
  `AXI_READ_CONNECT(s,s,7),`AXI_WRITE_CONNECT(s,s,7)
 );
`endif
endmodule
