// Generated client: CPU clock is supplied by the integration top.
module yolo_ai_client #(
    parameter PROGRAM_INIT_FILE="",DATA_INIT_FILE=""
) (
    input wire clk_sys,core_clk,rstn,ddr_rstn,uart_rxd,
    output wire uart_txd,vid_wr_en,
    output wire [7:0] vid_wr_addr,vid_rd_addr,
    output wire [31:0] vid_wr_data,
    input wire [31:0] vid_rd_data,
    output wire [27:0] d3_awaddr,d3_araddr,
    output wire [3:0] d3_awlen,d3_arlen,
    output wire d3_awvalid,d3_arvalid,
    input wire d3_awready,d3_arready,
    output wire [255:0] d3_wdata,
    output wire [31:0] d3_wstrb,
    output wire d3_wvalid,d3_rready,
    input wire d3_wready,d3_wusero_last,d3_rvalid,d3_rlast,
    input wire [255:0] d3_rdata
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


    wire [31:0] awaddr,wdata,araddr,rdata;
    wire [3:0] wstrb;
    wire awvalid,wvalid,arvalid,bready,rready;
    wire awready,wready,arready,bvalid,rvalid,cpu_rstn;
    wire [1:0] bresp,rresp;
    vexii_ai_soc cpu(
        .socCtrl_systemClk(clk_sys),.socCtrl_asyncReset(!rstn),
        .system_peripheral_uart_logic_uart_rxd(uart_rxd),
        .system_peripheral_uart_logic_uart_txd(uart_txd),
        .system_peripheral_demo_logic_leds(),
        .system_peripheral_demo_logic_buttons(1'b0),
        .ai_awaddr(awaddr),.ai_wdata(wdata),.ai_araddr(araddr),
        .ai_wstrb(wstrb),.ai_awvalid(awvalid),.ai_wvalid(wvalid),
        .ai_arvalid(arvalid),.ai_bready(bready),.ai_rready(rready),
        .ai_awready(awready),.ai_wready(wready),.ai_arready(arready),
        .ai_bvalid(bvalid),.ai_rvalid(rvalid),.ai_bresp(bresp),
        .ai_rresp(rresp),.ai_rdata(rdata),.ai_resetn(cpu_rstn));
    conv_engine_axil #(.BANDW(7168),.WBANK(576),.TRM(8)) acc(
        .clk(clk_sys),.rstn(cpu_rstn),
        .s_awaddr(awaddr[7:0]),.s_awvalid(awvalid),.s_awready(awready),
        .s_wdata(wdata),.s_wvalid(wvalid),.s_wready(wready),
        .s_bresp(bresp),.s_bvalid(bvalid),.s_bready(bready),
        .s_araddr(araddr[7:0]),.s_arvalid(arvalid),.s_arready(arready),
        .s_rdata(rdata),.s_rresp(rresp),.s_rvalid(rvalid),.s_rready(rready),
        .m_araddr(acc_araddr),.m_arvalid(acc_arvalid),.m_arready(acc_arready),
        .m_arlen(acc_arlen),.m_rdata(acc_rdata),.m_rvalid(acc_rvalid),
        .m_rready(acc_rready),.m_rresp(acc_rresp),
        .m_awaddr(acc_awaddr),.m_awvalid(acc_awvalid),.m_awready(acc_awready),
        .m_awlen(acc_awlen),.m_wdata(acc_wdata),.m_wvalid(acc_wvalid),
        .m_wlast(acc_wlast),.m_wready(acc_wready),.m_bresp(acc_bresp),
        .m_bvalid(acc_bvalid),.m_bready(acc_bready),
        .vid_wr_en(vid_wr_en),.vid_wr_addr(vid_wr_addr),
        .vid_wr_data(vid_wr_data),.vid_rd_addr(vid_rd_addr),
        .vid_rd_data(vid_rd_data),.dbg_st(acc_dbg_st),
        .dbg_anom(acc_dbg_anom),.dbg_snap(acc_dbg_snap));

    // the accelerator never uses byte strobes on its own port: it writes whole
    // 64-bit words (eight int8 channels), so the bridge's strobe input is all 1
    wire [27:0]  d_awaddr, d_araddr;
    wire         d_awvalid, d_arvalid, d_awready, d_arready;
    wire [255:0] d_wdata, d_rdata;
    wire [31:0]  d_wstrb;
    wire         d_wvalid, d_wready, d_wusero_last, d_rvalid, d_rlast, d_rready;

    ddr_axi_bridge u_bridge (
        .clk(clk_sys), .rstn(cpu_rstn),
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
        .clk(clk_sys), .rstn(cpu_rstn),
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

    axi_cdc u_cdc (
        .clk_a(clk_sys), .arst_n(cpu_rstn),
        .clk_b(core_clk), .brst_n(ddr_rstn),
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


endmodule
