"""Reuse the video/DDR integration with the locally generated Vexii CPU client."""
from pathlib import Path
from generate_camera_top import generate as camera_generate, replace_once
from generate_vexii_soc import ROOT, generate as soc_generate

OUT = ROOT / "gen/integration/vexii_camera"


def generate():
    soc_generate()
    camera_generate(OUT)
    path = OUT / "yolo_ai_client.v"
    source = path.read_text(encoding="utf-8")
    start = source.index("    pangoriscv_ai_soc #(")
    end = source.index("    // the accelerator never uses byte strobes", start)
    client = """
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

"""
    source = source[:start] + client + source[end:]
    # Keep all request/response FIFOs in reset until the CPU reset fiber has
    # completed. The DDR domain reset still comes from its own synchronizer.
    source = source.replace(".rstn(rstn)", ".rstn(cpu_rstn)")
    source = replace_once(source, ".arst_n(rstn)", ".arst_n(cpu_rstn)")
    path.write_text(source, encoding="utf-8")
    top = OUT / "yolo_camera_top.v"
    source = top.read_text(encoding="utf-8").replace(
        "/gen/integration/firmware/program.hex",
        "/gen/integration/vexii_firmware/program.hex")
    top.write_text(source, encoding="utf-8")
    print("VEXII_CAMERA_GENERATED; unverified candidate, CPU/accelerator at 27 MHz")
    return OUT


if __name__ == "__main__":
    generate()
