"""Mechanically derive a local camera integration; never edit the video base.

Every replacement is counted. Changes in the upstream template fail closed.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re

import tool_paths

ROOT=Path(__file__).resolve().parents[1]
# 上游视频模板（hdmi1080p）。可用 VIDEO_SRC 环境变量或 --video 指定；
# 本交付包未附带该目录，generate() 会给出明确错误。
VIDEO=tool_paths.video_src(required=False)


def replace_once(text,old,new):
    if text.count(old)!=1:
        raise ValueError(f"Template changed: expected one {old[:70]!r}")
    return text.replace(old,new,1)


def generate(out=None):
    if not VIDEO.is_dir():
        raise RuntimeError(
            f"视频模板目录不可用: {VIDEO}。设置 VIDEO_SRC 或 --video 指向 hdmi1080p")
    out=Path(out) if out is not None else ROOT/"gen/integration/camera"
    out.mkdir(parents=True,exist_ok=True)
    source=(ROOT/"rtl/yolo_soc_top.v").read_text(encoding="utf-8")
    body=source[source.index("    // ---- accelerator DDR path"):
                source.index("    // ---- DDR3 hard memory controller")]
    body=replace_once(body,
        ".vid_wr_en(),.vid_wr_addr(),.vid_wr_data(),.vid_rd_addr(),.vid_rd_data(32'd0)",
        ".vid_wr_en(vid_wr_en),.vid_wr_addr(vid_wr_addr),.vid_wr_data(vid_wr_data),"
        ".vid_rd_addr(vid_rd_addr),.vid_rd_data(vid_rd_data)")
    body=replace_once(body,".brst_n(ddr_reset_sync[1])",".brst_n(ddr_rstn)")
    # The native interface signals are ports in this reusable client.
    start=body.index("    wire [27:0]  d3_awaddr")
    end=body.index("    axi_cdc u_cdc",start)
    body=body[:start]+body[end:]
    header="""// Generated client: CPU clock is supplied by the integration top.
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
"""
    (out/"yolo_ai_client.v").write_text(header+body+"\nendmodule\n",encoding="utf-8")
    original=(VIDEO/"source/rtl/hdmi_ddr_ov5640_top.v").read_text(encoding="utf-8")
    text=replace_once(original,"module hdmi_ddr_ov5640_top#(","module yolo_camera_top#(")
    text=replace_once(text,"input                                sys_clk",
                      "input wire uart_rxd,\n\tinput                                sys_clk")
    text=replace_once(text,"wire        sel_cmos1 = cam1_ok;","wire        sel_cmos1 = 1'b1;")
    text=replace_once(text,
        "assign     pclk_in_test    =    sel_cmos1 ? cmos1_pclk_16bit : cmos2_pclk_16bit ;",
        "// The snapshot RAM spans clock regions; the DVP divider alone is regional.\n"
        "GTP_CLKBUFG camera_pixel_global(.CLKIN(cmos1_pclk_16bit),"
        ".CLKOUT(pclk_in_test));")
    text=replace_once(text,".txd      (  uart_txd       )",".txd      (                  )")
    text=replace_once(text,"wire [15:0] disp_px;","wire [15:0] disp_px;\n     wire [15:0] osd_px;")
    for component,hi,lo in (("r","15:11","15:13"),("g","10:5","10:9"),("b","4:0","4:2")):
        text=replace_once(text,f"{component}_out<={{disp_px[{hi}],disp_px[{lo}]}};",
                          f"{component}_out<={{osd_px[{hi}],osd_px[{lo}]}};")
    # Only rewire the real DDR IP, not the frame-buffer client or commented IP.
    start=text.index("ddr3_test u_ddr3_test_h(")
    end=text.index(");",start)+2
    instance=text[start:end]
    reset_token=".resetn                    (rstn_out"
    if instance.count(reset_token)!=1:
        raise ValueError("DDR reset port template changed")
    instance=instance.replace(reset_token,
                              ".resetn                    (ddr_resetn_ref",1)
    signals=("awaddr","awuser_id","awlen","awready","awvalid","wdata","wstrb","wready",
             "wusero_last","araddr","aruser_id","arlen","arready","arvalid",
             "rdata","rid","rlast","rvalid")
    for name in signals:
        pattern=r"(\.axi_"+name+r"\s*\()\s*axi_"+name+r"\s*(\))"
        instance,count=re.subn(pattern,rf"\g<1>native_{name}\g<2>",instance)
        if count!=1:
            raise ValueError(f"DDR port template changed: {name} ({count})")
    text=text[:start]+"reg [1:0] ddr_ref_rst;\nwire ddr_resetn_ref;\n"+instance+text[end:]
    extra="""
    // Synchronize DDR reset release to the differential reference clock.
    // This removes the cfg_clk->DDR PHY recovery path while retaining
    // asynchronous assertion during PLL/reset loss.
    always @(posedge clk_125Mhz or negedge rstn_out)
        if(!rstn_out) ddr_ref_rst <= 2'b00;
        else ddr_ref_rst <= {ddr_ref_rst[0],1'b1};
    assign ddr_resetn_ref = ddr_ref_rst[1];

    // CPU/accelerator use the existing 27 MHz source for conservative bring-up.
    // Teammate CPU optimizations are not overwritten or assumed to meet 74 MHz.
    wire ai_ready=locked && ddr_init_done;
    reg [1:0] ai_reset=0,ddr_reset=0,cam_reset=0,pix_reset=0;
    always @(posedge sys_clk or negedge ai_ready)
        if(!ai_ready) ai_reset<=0;else ai_reset<={ai_reset[0],1'b1};
    always @(posedge core_clk or negedge ai_ready)
        if(!ai_ready) ddr_reset<=0;else ddr_reset<={ddr_reset[0],1'b1};
    always @(posedge pclk_in_test or negedge ai_ready)
        if(!ai_ready) cam_reset<=0;else cam_reset<={cam_reset[0],1'b1};
    always @(posedge pix_clk or negedge ai_ready)
        if(!ai_ready) pix_reset<=0;else pix_reset<={pix_reset[0],1'b1};
    wire vid_wr_en;
    wire [7:0] vid_wr_addr,vid_rd_addr;
    wire [31:0] vid_wr_data,vid_rd_data;
    wire [27:0] ai_awaddr,ai_araddr;
    wire [3:0] ai_awlen,ai_arlen;
    wire ai_awvalid,ai_awready,ai_wvalid,ai_wready,ai_wlast;
    wire ai_arvalid,ai_arready,ai_rvalid,ai_rlast,ai_rready;
    wire [255:0] ai_wdata,shared_rdata;
    wire [31:0] ai_wstrb;
    yolo_ai_client #(
        .PROGRAM_INIT_FILE("@PROGRAM_HEX@")
    ) ai(
        .clk_sys(sys_clk),.core_clk(core_clk),.rstn(ai_reset[1]),.ddr_rstn(ddr_reset[1]),
        .uart_rxd(uart_rxd),.uart_txd(uart_txd),
        .vid_wr_en(vid_wr_en),.vid_wr_addr(vid_wr_addr),.vid_wr_data(vid_wr_data),
        .vid_rd_addr(vid_rd_addr),.vid_rd_data(vid_rd_data),
        .d3_awaddr(ai_awaddr),.d3_awlen(ai_awlen),.d3_awvalid(ai_awvalid),
        .d3_awready(ai_awready),.d3_wdata(ai_wdata),.d3_wstrb(ai_wstrb),
        .d3_wvalid(ai_wvalid),.d3_wready(ai_wready),.d3_wusero_last(ai_wlast),
        .d3_araddr(ai_araddr),.d3_arlen(ai_arlen),.d3_arvalid(ai_arvalid),
        .d3_arready(ai_arready),.d3_rdata(shared_rdata),.d3_rvalid(ai_rvalid),
        .d3_rlast(ai_rlast),.d3_rready(ai_rready));
    video_ai_frontend #(.OSD_TEXT(1),.OSD_BORDER(4)) frontend(
        .cpu_clk(sys_clk),.cpu_rstn(ai_reset[1]),
        .wr_en(vid_wr_en),.wr_addr(vid_wr_addr),.wr_data(vid_wr_data),
        .rd_addr(vid_rd_addr),.rd_data(vid_rd_data),
        .cam_clk(pclk_in_test),.cam_rstn(cam_reset[1]),
        .cam_vs(vs_in_test),.cam_de(de_in_test),.cam_pixel(i_rgb565),
        .pix_clk(pix_clk),.pix_rstn(pix_reset[1]),.pix_vs(vs_o),.pix_de(de_o),
        .pix_in(disp_px),.pix_out(osd_px));
    wire [27:0] native_awaddr,native_araddr;
    wire [3:0] native_awlen,native_arlen,native_awuser_id,native_aruser_id,native_rid;
    wire native_awvalid,native_arvalid,native_awready,native_arready;
    wire [255:0] native_wdata,native_rdata;
    wire [31:0] native_wstrb;
    wire native_wready,native_wusero_last,native_rvalid,native_rlast;
    wire [1:0] arb_awready,arb_arready,arb_wready,arb_wlast,arb_rvalid,arb_rlast;
    wire [3:0] shared_rid;
    // Video ping-pong buffers occupy byte 0x08000000..0x09ffffff.
    // The unmodified video client otherwise collides with model byte 0x01000000.
    ddr_native_arbiter arbiter(
        .clk(core_clk),.rstn(ddr_reset[1]),
        .s_awaddr({ai_awaddr,axi_awaddr+28'h02000000}),
        .s_araddr({ai_araddr,axi_araddr+28'h02000000}),
        .s_awlen({ai_awlen,axi_awlen}),.s_arlen({ai_arlen,axi_arlen}),
        .s_awid({4'd1,axi_awuser_id}),.s_arid({4'd1,axi_aruser_id}),
        .s_awvalid({ai_awvalid,axi_awvalid}),.s_arvalid({ai_arvalid,axi_arvalid}),
        .s_awready(arb_awready),.s_arready(arb_arready),
        .s_wdata({ai_wdata,axi_wdata}),.s_wstrb({ai_wstrb,axi_wstrb}),
        .s_wready(arb_wready),.s_wlast(arb_wlast),
        .s_rdata(shared_rdata),.s_rid(shared_rid),
        .s_rvalid(arb_rvalid),.s_rlast(arb_rlast),
        .m_awaddr(native_awaddr),.m_awlen(native_awlen),.m_awid(native_awuser_id),
        .m_awvalid(native_awvalid),.m_awready(native_awready),
        .m_wdata(native_wdata),.m_wstrb(native_wstrb),.m_wready(native_wready),
        .m_wlast(native_wusero_last),
        .m_araddr(native_araddr),.m_arlen(native_arlen),.m_arid(native_aruser_id),
        .m_arvalid(native_arvalid),.m_arready(native_arready),
        .m_rdata(native_rdata),.m_rvalid(native_rvalid),.m_rlast(native_rlast),
        .m_rid(native_rid));
    assign {ai_awready,axi_awready}=arb_awready;
    assign {ai_arready,axi_arready}=arb_arready;
    assign {ai_wready,axi_wready}=arb_wready;
    assign {ai_wlast,axi_wusero_last}=arb_wlast;
    assign {ai_rvalid,axi_rvalid}=arb_rvalid;
    assign {ai_rlast,axi_rlast}=arb_rlast;
    assign axi_rdata=shared_rdata;
    assign axi_rid=shared_rid;
"""
    extra=extra.replace("@PROGRAM_HEX@",(ROOT/"gen/integration/firmware/program.hex").as_posix())
    # Source contains a commented alternate DDR module; append before the last endmodule.
    last=text.rfind("endmodule")
    text=text[:last]+extra+"\n"+text[last:]
    (out/"yolo_camera_top.v").write_text(text,encoding="utf-8")
    fdc=(VIDEO/"HDMI_DDR3_OV5640_test.fdc").read_text(encoding="utf-8")
    # The upstream FDC leaves the DVP roots unconstrained; PDS otherwise invents
    # a 1 MHz clock. 150 MHz is a conservative implementation budget, not a
    # claim about the measured sensor clock or external data setup/hold.
    for camera in (1,2):
        fdc+=(
            f"\ncreate_clock -name {{dvp{camera}}} "
            f"[get_ports {{cmos{camera}_pclk}}] -period {{6.667}} "
            "-waveform {0.000 3.333}\n"
            f"create_generated_clock -name {{dvp{camera}_pixel}} "
            f"-source [get_ports {{cmos{camera}_pclk}}] "
            f"[get_pins {{cmos{camera}_8_16bit/u_u_/CLKDIVOUT}}] -divide_by 2\n"
            f"set_clock_groups -name dvp{camera} -asynchronous "
            f"-group [get_clocks {{dvp{camera} dvp{camera}_pixel}}]\n")
    # The video PLL clocks and the DDR PHY clocks are independent domains.
    # The frame buffer contains explicit synchronizer stages; without this
    # declaration PDS times the raw pixel/DDR control nets as synchronous
    # paths and reports false multi-nanosecond violations.
    fdc += """
# Explicit CDC boundary: the camera/HDMI PLL and the DDR PHY are unrelated.
# PDS gives generated PLL clocks hierarchical names (for example
# sys_clk|u_pll/u_gpll/CLKOUT0_Inferred).  The supported way to select those
# names is to include generated clocks from their two root clocks.
set_clock_groups -name pll_to_ddr_async -asynchronous \
    -group [get_clocks sys_clk -include_generated_clocks] \
    -group [get_clocks ref_clk -include_generated_clocks]
"""
    fdc+="\n# Verified in vendor pg2l100h remote-update FDC\n"
    for key,value in (("DIRECTION","INPUT"),("LOC","B24"),("VCCIO","3.3"),
                      ("STANDARD","LVCMOS33"),("NONE","TRUE")):
        fdc+=f"define_attribute {{p:uart_rxd}} {{PAP_IO_{key}}} {{{value}}}\n"
    (out/"camera.fdc").write_text(fdc,encoding="utf-8")
    (out/"provenance.json").write_text(json.dumps(dict(
        upstream_video=str(VIDEO),video_top_sha256=hashlib.sha256(original.encode()).hexdigest(),
        cpu_hz=27000000,video_byte_base=0x08000000,
        board_verified=False),indent=2),encoding="utf-8")
    print("CAMERA_TOP_GENERATED local derivative; native DDR address convention awaits BIST")


if __name__=="__main__":
    parser=argparse.ArgumentParser()
    parser.add_argument("--video",type=Path,
                        help="hdmi1080p 模板目录；默认读 VIDEO_SRC")
    options=parser.parse_args()
    if options.video:
        VIDEO=tool_paths.video_src(options.video)
    generate()
