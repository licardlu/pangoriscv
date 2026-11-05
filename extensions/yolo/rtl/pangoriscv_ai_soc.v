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
module pangoriscv_ai_soc #(
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
 // accelerator: AXI4-Lite register file is on the last slave window above;
 // these are its DDR master and its debug taps, for the top level
 output wire [31:0] acc_araddr,
 output wire        acc_arvalid,
 input  wire        acc_arready,
 output wire [7:0]  acc_arlen,
 input  wire [63:0] acc_rdata,
 input  wire        acc_rvalid,
 output wire        acc_rready,
 input  wire [1:0]  acc_rresp,
 output wire [31:0] acc_awaddr,
 output wire        acc_awvalid,
 input  wire        acc_awready,
 output wire [7:0]  acc_awlen,
 output wire [63:0] acc_wdata,
 output wire        acc_wvalid,
 output wire        acc_wlast,
 input  wire        acc_wready,
 input  wire [1:0]  acc_bresp,
 input  wire        acc_bvalid,
 output wire        acc_bready,
 output wire [4:0]  acc_dbg_st,
 output wire        acc_dbg_anom,
 output wire [31:0] acc_dbg_snap,
 output wire vid_wr_en,
 output wire [7:0] vid_wr_addr,vid_rd_addr,
 output wire [31:0] vid_wr_data,
 input wire [31:0] vid_rd_data,
 `CPU_STATUS_PORTS
);
 `AXI_WIRES(m,2)
`ifdef PERF_ENABLE
 `AXI_WIRES(s,9)
`else
 `AXI_WIRES(s,8)
`endif
 // Accelerator window: slave 7 (or 8 when PERF_ENABLE is on), at 0x70000000.
 // Added by the ai_lab integration; the original SoC keeps its seven windows.
`ifdef PERF_ENABLE
 // Slave 7 is the performance snapshot window at 0x60002000 (plan spec section 6).
 // It is compiled in only for instrumentation builds: the reference configuration
 // stays at seven slaves so the frozen default netlist is unchanged when it is off.
 localparam integer SLAVE_COUNT=9;
 localparam [32*9-1:0] SLAVE_BASE={32'h70000000,32'h60002000,32'h60003000,32'h50000000,
  32'h40000000,32'h30000000,32'h20000000,32'h10000000,32'h00000000};
 localparam [32*9-1:0] SLAVE_SIZE={32'h1000,32'h1000,32'h1000,32'h1000,
  32'h1000,32'h1000,32'h1000,32'h4000,32'h8000};
 wire perf_fault;
 wire perf_i_miss,perf_d_miss,perf_if_wait,perf_lsu_wait,perf_pred_miss;
`else
 localparam integer SLAVE_COUNT=8;
 localparam [32*8-1:0] SLAVE_BASE={32'h70000000,32'h60003000,32'h50000000,32'h40000000,
  32'h30000000,32'h20000000,32'h10000000,32'h00000000};
 localparam [32*8-1:0] SLAVE_SIZE={32'h1000,32'h1000,32'h1000,32'h1000,
  32'h1000,32'h1000,32'h4000,32'h8000};
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
 // ---- accelerator on the last slave window --------------------------------
 // conv_engine_axil is an AXI4-Lite device with an 8-bit register address; the
 // interconnect speaks full AXI4, hence the thin adapter.  The accelerator's
 // own DDR master leaves this module on dedicated ports so the top level can
 // route it through the width bridge and the clock-domain crossing.
 wire        acc_protocol_fault;
 wire [7:0]  x_awaddr;
 wire        x_awvalid, x_awready;
 wire [31:0] x_wdata;
 wire        x_wvalid, x_wready;
 wire [1:0]  x_bresp;
 wire        x_bvalid, x_bready;
 wire [7:0]  x_araddr;
 wire        x_arvalid, x_arready;
 wire [31:0] x_rdata;
 wire [1:0]  x_rresp;
 wire        x_rvalid, x_rready;

`ifdef PERF_ENABLE
 localparam integer ACC_SLAVE = 8;
`else
 localparam integer ACC_SLAVE = 7;
`endif

 // The full AXI fabric checks response IDs. AXI-Lite strips IDs, so retain
 // each one at admission until that direction's response is completed.
 reg [3:0] acc_read_id,acc_write_id;
 assign s_rid[ACC_SLAVE*4+:4]=acc_read_id;
 assign s_bid[ACC_SLAVE*4+:4]=acc_write_id;
 always @(posedge clk) begin
  if(!rst_n) begin acc_read_id<=0;acc_write_id<=0;end
  else begin
   if(s_arvalid[ACC_SLAVE] && s_arready[ACC_SLAVE])
    acc_read_id<=s_arid[ACC_SLAVE*4+:4];
   if(s_awvalid[ACC_SLAVE] && s_awready[ACC_SLAVE])
    acc_write_id<=s_awid[ACC_SLAVE*4+:4];
  end
 end
 axi4_to_axil u_acc_regs_adapt (
  .clk(clk), .rstn(rst_n),
  .a_awvalid(s_awvalid[ACC_SLAVE]), .a_awready(s_awready[ACC_SLAVE]),
  .a_awaddr(s_awaddr[ACC_SLAVE*32+:32]), .a_awlen(s_awlen[ACC_SLAVE*8+:8]),
  .a_wvalid(s_wvalid[ACC_SLAVE]), .a_wready(s_wready[ACC_SLAVE]),
  .a_wdata(s_wdata[ACC_SLAVE*32+:32]), .a_wstrb(s_wstrb[ACC_SLAVE*4+:4]),
  .a_wlast(s_wlast[ACC_SLAVE]),
  .a_bvalid(s_bvalid[ACC_SLAVE]), .a_bready(s_bready[ACC_SLAVE]),
  .a_bresp(s_bresp[ACC_SLAVE*2+:2]),
  .a_arvalid(s_arvalid[ACC_SLAVE]), .a_arready(s_arready[ACC_SLAVE]),
  .a_araddr(s_araddr[ACC_SLAVE*32+:32]), .a_arlen(s_arlen[ACC_SLAVE*8+:8]),
  .a_rvalid(s_rvalid[ACC_SLAVE]), .a_rready(s_rready[ACC_SLAVE]),
  .a_rdata(s_rdata[ACC_SLAVE*32+:32]), .a_rresp(s_rresp[ACC_SLAVE*2+:2]),
  .a_rlast(s_rlast[ACC_SLAVE]),
  .s_awaddr(x_awaddr), .s_awvalid(x_awvalid), .s_awready(x_awready),
  .s_wdata(x_wdata), .s_wvalid(x_wvalid), .s_wready(x_wready),
  .s_bresp(x_bresp), .s_bvalid(x_bvalid), .s_bready(x_bready),
  .s_araddr(x_araddr), .s_arvalid(x_arvalid), .s_arready(x_arready),
  .s_rdata(x_rdata), .s_rresp(x_rresp), .s_rvalid(x_rvalid), .s_rready(x_rready)
 );

 conv_engine_axil u_acc (
  .clk(clk), .rstn(rst_n),
  .vid_wr_en(vid_wr_en),.vid_wr_addr(vid_wr_addr),
  .vid_wr_data(vid_wr_data),.vid_rd_addr(vid_rd_addr),.vid_rd_data(vid_rd_data),
  .s_awaddr(x_awaddr), .s_awvalid(x_awvalid), .s_awready(x_awready),
  .s_wdata(x_wdata), .s_wvalid(x_wvalid), .s_wready(x_wready),
  .s_bresp(x_bresp), .s_bvalid(x_bvalid), .s_bready(x_bready),
  .s_araddr(x_araddr), .s_arvalid(x_arvalid), .s_arready(x_arready),
  .s_rdata(x_rdata), .s_rresp(x_rresp), .s_rvalid(x_rvalid), .s_rready(x_rready),
  .m_araddr(acc_araddr), .m_arvalid(acc_arvalid), .m_arready(acc_arready),
  .m_arlen(acc_arlen), .m_rdata(acc_rdata), .m_rvalid(acc_rvalid),
  .m_rready(acc_rready), .m_rresp(acc_rresp),
  .m_awaddr(acc_awaddr), .m_awvalid(acc_awvalid), .m_awready(acc_awready),
  .m_awlen(acc_awlen), .m_wdata(acc_wdata), .m_wvalid(acc_wvalid),
  .m_wlast(acc_wlast), .m_wready(acc_wready), .m_bresp(acc_bresp),
  .m_bvalid(acc_bvalid), .m_bready(acc_bready),
  .dbg_st(acc_dbg_st), .dbg_anom(acc_dbg_anom), .dbg_snap(acc_dbg_snap)
 );

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
