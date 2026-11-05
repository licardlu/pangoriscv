// yolo_soc_top -- board-level integration of the detector path.
//
//   clk_sys (74.33 MHz, from the existing PLL's clkout0)
//       pangoriscv_ai_soc      RV32IM core + interconnect + peripherals
//         +- slave window 7 (0x70000000) -> axi4_to_axil -> conv_engine_axil
//         +- accelerator DDR master (64-bit, single beat)
//             -> ddr_axi_bridge (64 -> 256)
//             -> bridge_to_cdc
//             -> axi_cdc (clk_sys -> DDR3 core_clk)
//             -> DDR3 IP's 256-bit AXI slave
//
// Why clkout0 and not a new PLL: the engine's netlist closes at an estimated
// 79 MHz, and this PLL already produces 74.33 MHz, which is inside that budget
// and needs no new IP.  9.68M cycles per frame at 74.33 MHz is 130 ms.
//
// Why axi_cdc exists at all: DDR3's AXI slave runs on the IP's own core_clk,
// which its internal PLL generates and which we cannot set to 74 MHz.  Without
// the crossing the whole design would be in a clock domain the engine cannot
// meet timing in.
//
// This is the static-image DDR bring-up top, not the camera/display top.
// C3/SPPF branches and detection heads execute in CPU firmware.
`timescale 1ns/1ps

module yolo_soc_top #(
    parameter PROGRAM_INIT_FILE = "",
    parameter DATA_INIT_FILE    = ""
)(
    input  wire        sys_clk,          // 27 MHz board oscillator, D18
    input  wire        clk_p,            // 125 MHz differential DDR3 reference
    input  wire        clk_n,
    output wire        uart_txd,         // C24
    input  wire        uart_rxd,         // B24, vendor pg2l100h remote-update FDC

    // ---- DDR3 physical interface ----
    output wire        mem_cs_n,
    output wire        mem_rst_n,
    output wire        mem_ck,
    output wire        mem_ck_n,
    output wire        mem_cke,
    output wire        mem_ras_n,
    output wire        mem_cas_n,
    output wire        mem_we_n,
    output wire        mem_odt,
    output wire [14:0] mem_a,
    output wire [2:0]  mem_ba,
    inout  wire [3:0]  mem_dqs,
    inout  wire [3:0]  mem_dqs_n,
    inout  wire [31:0] mem_dq,
    output wire [3:0]  mem_dm
);

    // ---- clock and reset ---------------------------------------------------
    wire clk_sys;
    wire pll_lock;
    wire ddr_init_done;
    wire core_clk;
    reg [1:0] sys_reset_sync=0, ddr_reset_sync=0;
    wire reset_ready=pll_lock && ddr_init_done;
    always @(posedge clk_sys or negedge reset_ready)
        if(!reset_ready) sys_reset_sync<=0;
        else sys_reset_sync<={sys_reset_sync[0],1'b1};
    always @(posedge core_clk or negedge reset_ready)
        if(!reset_ready) ddr_reset_sync<=0;
        else ddr_reset_sync<={ddr_reset_sync[0],1'b1};
    wire rstn=sys_reset_sync[1];

    pll u_pll (
        .clkout0(clk_sys),      // 74.33 MHz
        .clkout1(),
        .clkout2(),
        .clkin1(sys_clk),
        .lock(pll_lock)
    );

    // ---- accelerator DDR path, all in clk_sys ------------------------------
    wire [31:0]  acc_araddr, acc_awaddr;
    wire         acc_arvalid, acc_awvalid;
    wire         acc_arready, acc_awready;
    wire [7:0]   acc_arlen, acc_awlen;
    wire [63:0]  acc_rdata, acc_wdata;
    wire         acc_rvalid, acc_wvalid, acc_wlast;
    wire         acc_rready, acc_wready, acc_bready;
    wire [1:0]   acc_rresp, acc_bresp;
    wire         acc_bvalid;
    wire [4:0]   acc_dbg_st;
    wire         acc_dbg_anom;
    wire [31:0]  acc_dbg_snap;

    wire [27:0]  br_awaddr, br_araddr;
    wire [3:0]   br_awlen, br_arlen;
    wire         br_awvalid, br_arvalid;
    wire         br_awready, br_arready;
    wire [255:0] br_wdata, br_rdata;
    wire [31:0]  br_wstrb;
    wire         br_wvalid, br_wready, br_wusero_last;
    wire         br_rvalid, br_rlast, br_rready;

    pangoriscv_ai_soc #(
        .PROGRAM_INIT_FILE(PROGRAM_INIT_FILE),
        .DATA_INIT_FILE(DATA_INIT_FILE)
    ) u_soc (
        .clk(clk_sys), .rst_n(rstn),
        .uart_rx(uart_rxd), .uart_tx(uart_txd),
        .halt_req(1'b0),.trap_ready(1'b1),.trap_vector(32'd0),
        .irq_software(1'b0),.irq_timer(1'b0),.irq_external(1'b0),
        .debug_addr(5'd0),
        .vid_wr_en(),.vid_wr_addr(),.vid_wr_data(),.vid_rd_addr(),.vid_rd_data(32'd0),
        .gpio_input(2'b00), .gpio_ctrl(), .gpio_data(),
        .spi_miso(1'b0), .spi_mosi(), .spi_ss(), .spi_clk(),
        .ext_event(2'b00),
        .acc_araddr(acc_araddr), .acc_arvalid(acc_arvalid), .acc_arready(acc_arready),
        .acc_arlen(acc_arlen), .acc_rdata(acc_rdata), .acc_rvalid(acc_rvalid),
        .acc_rready(acc_rready), .acc_rresp(acc_rresp),
        .acc_awaddr(acc_awaddr), .acc_awvalid(acc_awvalid), .acc_awready(acc_awready),
        .acc_awlen(acc_awlen), .acc_wdata(acc_wdata), .acc_wvalid(acc_wvalid),
        .acc_wlast(acc_wlast), .acc_wready(acc_wready), .acc_bresp(acc_bresp),
        .acc_bvalid(acc_bvalid), .acc_bready(acc_bready),
        .acc_dbg_st(acc_dbg_st), .acc_dbg_anom(acc_dbg_anom),
        .acc_dbg_snap(acc_dbg_snap)
    );

    // the accelerator never uses byte strobes on its own port: it writes whole
    // 64-bit words (eight int8 channels), so the bridge's strobe input is all 1
    wire [27:0]  d_awaddr, d_araddr;
    wire         d_awvalid, d_arvalid, d_awready, d_arready;
    wire [255:0] d_wdata, d_rdata;
    wire [31:0]  d_wstrb;
    wire         d_wvalid, d_wready, d_wusero_last, d_rvalid, d_rlast, d_rready;

    ddr_axi_bridge u_bridge (
        .clk(clk_sys), .rstn(rstn),
        .s_awaddr(acc_awaddr), .s_awvalid(acc_awvalid), .s_awready(acc_awready),
        .s_wdata(acc_wdata), .s_wstrb(8'hFF), .s_wvalid(acc_wvalid),
        .s_wready(acc_wready), .s_bresp(acc_bresp), .s_bvalid(acc_bvalid),
        .s_bready(acc_bready),
        .s_araddr(acc_araddr), .s_arvalid(acc_arvalid), .s_arready(acc_arready),
        .s_rdata(acc_rdata), .s_rresp(acc_rresp), .s_rvalid(acc_rvalid),
        .s_rready(acc_rready),
        .m_awaddr(br_awaddr), .m_awlen(br_awlen), .m_awvalid(br_awvalid),
        .m_awready(br_awready), .m_wdata(br_wdata), .m_wstrb(br_wstrb),
        .m_wvalid(br_wvalid), .m_wready(br_wready),
        .m_wusero_last(br_wusero_last),
        .m_araddr(br_araddr), .m_arlen(br_arlen), .m_arvalid(br_arvalid),
        .m_arready(br_arready), .m_rdata(br_rdata), .m_rvalid(br_rvalid),
        .m_rlast(br_rlast), .m_rready(br_rready)
    );

    // ---- crossing into the DDR3 core clock --------------------------------
    wire         c_req_valid, c_req_full, c_req_write;
    wire [31:0]  c_req_addr;
    wire [255:0] c_req_wdata;
    wire [31:0]  c_req_wstrb;
    wire         c_rsp_valid, c_rsp_ready, c_rsp_is_read;
    wire [255:0] c_rsp_rdata;


    bridge_to_cdc u_glue (
        .clk(clk_sys), .rstn(rstn),
        .br_awaddr(br_awaddr), .br_awvalid(br_awvalid), .br_awready(br_awready),
        .br_wdata(br_wdata), .br_wstrb(br_wstrb), .br_wvalid(br_wvalid),
        .br_wready(br_wready), .br_wusero_last(br_wusero_last),
        .br_araddr(br_araddr), .br_arvalid(br_arvalid), .br_arready(br_arready),
        .br_rdata(br_rdata), .br_rvalid(br_rvalid), .br_rlast(br_rlast),
        .br_rready(br_rready),
        .c_req_valid(c_req_valid), .c_req_full(c_req_full),
        .c_req_write(c_req_write), .c_req_addr(c_req_addr),
        .c_req_wdata(c_req_wdata), .c_req_wstrb(c_req_wstrb),
        .c_rsp_valid(c_rsp_valid), .c_rsp_ready(c_rsp_ready),
        .c_rsp_rdata(c_rsp_rdata), .c_rsp_is_read(c_rsp_is_read)
    );

    wire [27:0]  d3_awaddr, d3_araddr;
    wire [3:0]   d3_awlen, d3_arlen;
    wire         d3_awvalid, d3_arvalid, d3_awready, d3_arready;
    wire [255:0] d3_wdata, d3_rdata;
    wire [31:0]  d3_wstrb;
    wire         d3_wvalid, d3_wready, d3_wusero_last, d3_rvalid, d3_rlast, d3_rready;

    axi_cdc u_cdc (
        .clk_a(clk_sys), .arst_n(rstn),
        .clk_b(core_clk), .brst_n(ddr_reset_sync[1]),
        .a_req_valid(c_req_valid), .a_req_full(c_req_full),
        .a_req_write(c_req_write), .a_req_addr(c_req_addr),
        .a_req_wdata(c_req_wdata), .a_req_wstrb(c_req_wstrb),
        .a_rsp_valid(c_rsp_valid), .a_rsp_ready(c_rsp_ready),
        .a_rsp_rdata(c_rsp_rdata), .a_rsp_is_read(c_rsp_is_read),
        .b_awaddr(d3_awaddr), .b_awlen(d3_awlen), .b_awvalid(d3_awvalid),
        .b_awready(d3_awready), .b_wdata(d3_wdata), .b_wstrb(d3_wstrb),
        .b_wvalid(d3_wvalid), .b_wready(d3_wready),
        .b_wusero_last(d3_wusero_last),
        .b_araddr(d3_araddr), .b_arlen(d3_arlen), .b_arvalid(d3_arvalid),
        .b_arready(d3_arready), .b_rdata(d3_rdata), .b_rvalid(d3_rvalid),
        .b_rlast(d3_rlast), .b_rready(d3_rready)
    );

    // ---- DDR3 hard memory controller ---------------------------------------
    wire clk_125M;
    GTP_INBUFGDS #(.IOSTANDARD("DEFAULT"), .TERM_DIFF("ON")) u_gtp (
        .O(clk_125M), .I(clk_p), .IB(clk_n)
    );

    ddr3_test u_ddr3_test_h (
        .ref_clk(clk_125M),
        .resetn(pll_lock),
        .core_clk(core_clk),
        .ddr_init_done(ddr_init_done),
        .pll_lock(), .phy_pll_lock(), .gpll_lock(), .rst_gpll_lock(),
        .ddrphy_cpd_lock(),
        .axi_awaddr(d3_awaddr), .axi_awuser_ap(1'b0), .axi_awuser_id(4'd0),
        .axi_awlen(d3_awlen), .axi_awready(d3_awready), .axi_awvalid(d3_awvalid),
        .axi_wdata(d3_wdata), .axi_wstrb(d3_wstrb), .axi_wready(d3_wready),
        .axi_wusero_id(), .axi_wusero_last(d3_wusero_last),
        .axi_araddr(d3_araddr), .axi_aruser_ap(1'b0), .axi_aruser_id(4'd0),
        .axi_arlen(d3_arlen), .axi_arready(d3_arready), .axi_arvalid(d3_arvalid),
        .axi_rdata(d3_rdata), .axi_rid(), .axi_rlast(d3_rlast),
        .axi_rvalid(d3_rvalid),
        .apb_clk(1'b0), .apb_rst_n(1'b1), .apb_sel(1'b0), .apb_enable(1'b0),
        .apb_addr(8'd0), .apb_write(1'b0), .apb_ready(), .apb_wdata(16'd0),
        .apb_rdata(),
        .mem_cs_n(mem_cs_n), .mem_rst_n(mem_rst_n), .mem_ck(mem_ck),
        .mem_ck_n(mem_ck_n), .mem_cke(mem_cke), .mem_ras_n(mem_ras_n),
        .mem_cas_n(mem_cas_n), .mem_we_n(mem_we_n), .mem_odt(mem_odt),
        .mem_a(mem_a), .mem_ba(mem_ba), .mem_dqs(mem_dqs),
        .mem_dqs_n(mem_dqs_n), .mem_dq(mem_dq), .mem_dm(mem_dm),
        .dbg_gate_start(1'b0), .dbg_cpd_start(1'b0), .dbg_ddrphy_rst_n(1'b1),
        .dbg_gpll_scan_rst(1'b0), .samp_position_dyn_adj(1'b0),
        .init_samp_position_even(32'd0), .init_samp_position_odd(32'd0),
        .wrcal_position_dyn_adj(1'b0), .init_wrcal_position(32'd0),
        .force_read_clk_ctrl(1'b0), .init_slip_step(16'd0),
        .init_read_clk_ctrl(12'd0), .debug_calib_ctrl(), .dbg_slice_status(),
        .dbg_slice_state(), .debug_data(), .dbg_dll_upd_state(),
        .debug_gpll_dps_phase(), .dbg_rst_dps_state(), .dbg_tran_err_rst_cnt(),
        .dbg_ddrphy_init_fail(), .debug_cpd_offset_adj(1'b0),
        .debug_cpd_offset_dir(1'b0), .debug_cpd_offset(10'd0),
        .debug_dps_cnt_dir0(), .debug_dps_cnt_dir1(), .ck_dly_en(1'b0),
        .init_ck_dly_step(8'd0), .ck_dly_set_bin(), .align_error(),
        .debug_rst_state(), .debug_cpd_state()
    );

endmodule
