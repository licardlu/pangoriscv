"""Reuse the video/DDR integration with the locally generated Vexii CPU client."""
import json
from pathlib import Path
from generate_camera_top import generate as camera_generate, replace_once
from generate_vexii_soc import CPU, ROOT, generate as soc_generate

OUT = ROOT / "gen/integration/vexii_camera"


def generate(cpu_hz=27000000, out=None):
    if cpu_hz not in (27000000, 37125000, 81000000, 93461538, 120461538):
        raise ValueError("Unsupported AI clock")
    out = Path(out) if out is not None else OUT
    soc_generate()
    camera_generate(out)
    path = out / "yolo_ai_client.v"
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
    top = out / "yolo_camera_top.v"
    source = top.read_text(encoding="utf-8").replace(
        "/gen/integration/firmware/program.hex",
        "/gen/integration/vexii_firmware/program.hex")
    if cpu_hz != 27000000:
        if cpu_hz == 37125000:
            clock = """
    reg ai_clk_div=0;
    always @(posedge pix_clk or negedge locked)
        if(!locked) ai_clk_div<=0; else ai_clk_div<=!ai_clk_div;
    wire ai_clk;
    GTP_CLKBUFG ai_clock_global(.CLKIN(ai_clk_div),.CLKOUT(ai_clk));
"""
            source = replace_once(source, "wire ai_ready=locked && ddr_init_done;",
                                  clock + "\n    wire ai_ready=locked && ddr_init_done;")
            constraints = """
create_generated_clock -name {ai_clk} -source [get_pins {u_pll/u_gpll/CLKOUT0}] \
    [get_pins {ai_clock_global/CLKOUT}] -divide_by 2
"""
        else:
            # Reuse the final CPU package's 27*58/13 PPLL, not a fabric clock.
            pll = (CPU / "rtl/board/pango_pll.sv").read_text(encoding="utf-8")
            pll = replace_once(pll, "module pango_pll(", "module ai_perf_pll(")
            ratio_f, ratio_0 = {
                81000000: (45, 15),
                93461538: (45, 13),
                120461538: (58, 13),
            }[cpu_hz]
            pll = replace_once(pll, ".STATIC_RATIOF(58)", f".STATIC_RATIOF({ratio_f})")
            pll = replace_once(pll, ".STATIC_DUTYF(58)", f".STATIC_DUTYF({ratio_f})")
            pll = replace_once(pll, ".STATIC_RATIO0(13)", f".STATIC_RATIO0({ratio_0})")
            pll = replace_once(pll, ".STATIC_DUTY0(13)", f".STATIC_DUTY0({ratio_0})")
            (out / "ai_perf_pll.v").write_text(pll, encoding="utf-8")
            clock = """
    wire ai_clk,ai_pll_locked;
    ai_perf_pll ai_clock_pll(.clk(sys_clk),.rst_n(locked),
                            .core_clk(ai_clk),.locked(ai_pll_locked));
"""
            source = replace_once(source, "wire ai_ready=locked && ddr_init_done;",
                                  clock + "\n    wire ai_ready=locked && ai_pll_locked && ddr_init_done;")
            # Match the 37 ns sys_clk constraint used by PDS; its effective
            # nominal frequency is 27.027 MHz for PLL timing propagation.
            period = 37.0 * ratio_0 / ratio_f
            constraints = f"""
# The independent AI PPLL has no phase relationship to the video GPLL.
create_clock -name {{ai_clk}} [get_pins {{ai_clock_pll/u_ppll:CLKOUT0}}] \
    -period {{{period:.4f}}} -waveform {{0.000 {period / 2:.4f}}}
"""
        source = replace_once(source, "always @(posedge sys_clk or negedge ai_ready)",
                              "always @(posedge ai_clk or negedge ai_ready)")
        source = replace_once(source, ".clk_sys(sys_clk)", ".clk_sys(ai_clk)")
        source = replace_once(source, ".cpu_clk(sys_clk)", ".cpu_clk(ai_clk)")
        fdc = out / "camera.fdc"
        if cpu_hz == 37125000:
            constraints += """
# The AI master reaches the DDR controller only through bridge_to_cdc/axi_cdc
# asynchronous FIFOs. Keep the camera PLL and DDR PHY domains independent.
"""
        if cpu_hz in (81000000, 93461538, 120461538):
            constraints += """
set_clock_groups -name ai_to_video_async -asynchronous \
    -group [get_clocks {ai_clk}] \
    -group [get_clocks sys_clk -include_generated_clocks] \
    -group [get_clocks {dvp1 dvp1_pixel dvp2 dvp2_pixel}]
set_clock_groups -name ai_to_ddr_async -asynchronous \
    -group [get_clocks {ai_clk}] \
    -group [get_clocks ref_clk -include_generated_clocks]
"""
        else:
            constraints += """
set_clock_groups -name ai_to_ddr_async -asynchronous \
    -group [get_clocks {ai_clk}] \
    -group [get_clocks ref_clk -include_generated_clocks]
"""
        fdc.write_text(fdc.read_text(encoding="utf-8") + constraints, encoding="utf-8")
    top.write_text(source, encoding="utf-8")
    provenance = out / "provenance.json"
    metadata = json.loads(provenance.read_text(encoding="utf-8"))
    metadata["cpu_hz"] = cpu_hz
    provenance.write_text(json.dumps(metadata, indent=2), encoding="utf-8")
    print(f"VEXII_CAMERA_GENERATED; unverified candidate, CPU/accelerator at {cpu_hz} Hz")
    return out


if __name__ == "__main__":
    generate()
