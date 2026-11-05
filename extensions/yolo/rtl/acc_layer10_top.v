// acc_layer10_top -- fixed-parameter wrapper so PDS can synthesise the real
// YOLOv5n layer-10 accelerator without a parameter-override mechanism.
// All AXI ports are brought to the top level so nothing is optimised away
// merely because it is unconnected.
`timescale 1ns/1ps
module acc_layer10_top(
    input  wire        clk,
    input  wire        rstn,

    input  wire [7:0]  s_awaddr,
    input  wire        s_awvalid,
    output wire        s_awready,
    input  wire [31:0] s_wdata,
    input  wire        s_wvalid,
    output wire        s_wready,
    output wire [1:0]  s_bresp,
    output wire        s_bvalid,
    input  wire        s_bready,
    input  wire [7:0]  s_araddr,
    input  wire        s_arvalid,
    output wire        s_arready,
    output wire [31:0] s_rdata,
    output wire [1:0]  s_rresp,
    output wire        s_rvalid,
    input  wire        s_rready,

    output wire [31:0] m_araddr,
    output wire        m_arvalid,
    input  wire        m_arready,
    output wire [7:0]  m_arlen,
    input  wire [31:0] m_rdata,
    input  wire        m_rvalid,
    output wire        m_rready,
    input  wire [1:0]  m_rresp,
    output wire [31:0] m_awaddr,
    output wire        m_awvalid,
    output wire [7:0]  m_awlen,
    output wire [31:0] m_wdata,
    output wire        m_wvalid,
    output wire        m_wlast,
    input  wire [1:0]  m_bresp,
    input  wire        m_bvalid,
    output wire        m_bready,

    output wire        busy,
    output wire        done,
    output wire        err
);
    acc_shell #(.CIN(256), .COUT(128), .W(10), .H(10),
                .K(1), .STRIDE(1), .ACT(2)) u_acc (
        .clk(clk), .rstn(rstn),
        .s_awaddr(s_awaddr), .s_awvalid(s_awvalid), .s_awready(s_awready),
        .s_wdata(s_wdata), .s_wvalid(s_wvalid), .s_wready(s_wready),
        .s_bresp(s_bresp), .s_bvalid(s_bvalid), .s_bready(s_bready),
        .s_araddr(s_araddr), .s_arvalid(s_arvalid), .s_arready(s_arready),
        .s_rdata(s_rdata), .s_rresp(s_rresp), .s_rvalid(s_rvalid), .s_rready(s_rready),
        .m_araddr(m_araddr), .m_arvalid(m_arvalid), .m_arready(m_arready), .m_arlen(m_arlen),
        .m_rdata(m_rdata), .m_rvalid(m_rvalid), .m_rready(m_rready), .m_rresp(m_rresp),
        .m_awaddr(m_awaddr), .m_awvalid(m_awvalid), .m_awready(1'b1), .m_awlen(m_awlen),
        .m_wdata(m_wdata), .m_wvalid(m_wvalid), .m_wlast(m_wlast), .m_wready(1'b1),
        .m_bresp(m_bresp), .m_bvalid(m_bvalid), .m_bready(m_bready),
        .busy(busy), .done(done), .err(err)
    );
endmodule
