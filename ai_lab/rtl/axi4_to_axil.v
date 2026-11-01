// axi4_to_axil -- the CPU SoC's peripherals are full AXI4 (with ID, LEN, SIZE,
// BURST and QOS), while conv_engine_axil exposes a plain AXI4-Lite register
// file with an 8-bit address.  This is the thin adapter between them.
//
// The register file is 0x54 bytes, so a CPU access is always a single 32-bit
// beat: bursts are not needed and an arlen/awlen other than zero is a program
// error, which is reported as SLVERR rather than silently wrapping the address.
`timescale 1ns/1ps

module axi4_to_axil (
    input  wire        clk,
    input  wire        rstn,

    // ---- full AXI4 slave (the CPU interconnect side) ----
    input  wire        a_awvalid,
    output wire        a_awready,
    input  wire [31:0] a_awaddr,
    input  wire [7:0]  a_awlen,
    input  wire        a_wvalid,
    output wire        a_wready,
    input  wire [31:0] a_wdata,
    input  wire [3:0]  a_wstrb,
    input  wire        a_wlast,
    output reg         a_bvalid,
    input  wire        a_bready,
    output reg  [1:0]  a_bresp,
    input  wire        a_arvalid,
    output wire        a_arready,
    input  wire [31:0] a_araddr,
    input  wire [7:0]  a_arlen,
    output reg         a_rvalid,
    input  wire        a_rready,
    output reg  [31:0] a_rdata,
    output reg  [1:0]  a_rresp,
    output reg         a_rlast,

    // ---- AXI4-Lite master (the accelerator register file) ----
    output reg  [7:0]  s_awaddr,
    output reg         s_awvalid,
    input  wire        s_awready,
    output reg  [31:0] s_wdata,
    output reg         s_wvalid,
    input  wire        s_wready,
    input  wire [1:0]  s_bresp,
    input  wire        s_bvalid,
    output wire        s_bready,
    output reg  [7:0]  s_araddr,
    output reg         s_arvalid,
    input  wire        s_arready,
    input  wire [31:0] s_rdata,
    input  wire [1:0]  s_rresp,
    input  wire        s_rvalid,
    output wire        s_rready
);

    reg aw_have,w_have,write_active,write_bad;
    reg [31:0] aw_hold,w_hold;
    reg [7:0] aw_length;
    reg [8:0] w_count;
    assign a_awready=rstn && !aw_have && !write_active && !a_bvalid;
    assign a_wready=rstn && !w_have && !write_active && !a_bvalid;
    assign s_bready=write_active && !a_bvalid;
    always @(posedge clk) begin
        if(!rstn) begin
            aw_have<=0;w_have<=0;write_active<=0;write_bad<=0;
            aw_hold<=0;w_hold<=0;aw_length<=0;w_count<=0;
            s_awaddr<=0;s_awvalid<=0;s_wdata<=0;s_wvalid<=0;
            a_bvalid<=0;a_bresp<=0;
        end else begin
            if(a_bvalid && a_bready) a_bvalid<=0;
            if(a_awvalid && a_awready) begin
                aw_hold<=a_awaddr;aw_length<=a_awlen;aw_have<=1;
            end
            // Unsupported writes are drained to WLAST before returning error;
            // none of their beats may modify the register file.
            if(a_wvalid && a_wready) begin
                w_hold<=a_wdata;w_count<=w_count+1'b1;
                write_bad<=write_bad || a_wstrb!=4'hf || w_count!=0;
                if(a_wlast) w_have<=1;
            end
            if(aw_have && w_have && !write_active && !a_bvalid) begin
                aw_have<=0;w_have<=0;w_count<=0;write_bad<=0;
                if(write_bad || aw_length!=0 || aw_hold[1:0]!=0 ||
                   aw_hold[11:8]!=0 || w_count!=1) begin
                    a_bvalid<=1;a_bresp<=2'b10;
                end else begin
                    s_awaddr<=aw_hold[7:0];s_awvalid<=1;
                    s_wdata<=w_hold;s_wvalid<=1;write_active<=1;
                end
            end
            if(s_awvalid && s_awready) s_awvalid<=0;
            if(s_wvalid && s_wready) s_wvalid<=0;
            if(s_bvalid && s_bready) begin
                a_bvalid<=1;a_bresp<=s_bresp;write_active<=0;
            end
        end
    end

    reg read_active,read_reject;
    reg [7:0] remaining;
    assign a_arready=rstn && !read_active && !a_rvalid && !read_reject;
    assign s_rready=read_active && !a_rvalid;
    always @(posedge clk) begin
        if(!rstn) begin
            s_araddr<=0;s_arvalid<=0;a_rvalid<=0;a_rdata<=0;
            a_rresp<=0;a_rlast<=0;read_active<=0;read_reject<=0;remaining<=0;
        end else begin
            if(a_rvalid && a_rready) begin
                if(read_reject && remaining!=0) begin
                    remaining<=remaining-1'b1;
                    a_rlast<=remaining==1;
                end else begin a_rvalid<=0;read_reject<=0;end
            end
            if(a_arvalid && a_arready) begin
                if(a_arlen!=0 || a_araddr[1:0]!=0 || a_araddr[11:8]!=0) begin
                    read_reject<=1;remaining<=a_arlen;
                    a_rvalid<=1;a_rdata<=0;a_rresp<=2'b10;a_rlast<=a_arlen==0;
                end else begin
                    read_active<=1;s_araddr<=a_araddr[7:0];s_arvalid<=1;
                end
            end
            if(s_arvalid && s_arready) s_arvalid<=0;
            if(s_rvalid && s_rready) begin
                a_rvalid<=1;a_rdata<=s_rdata;a_rresp<=s_rresp;a_rlast<=1;
                read_active<=0;
            end
        end
    end
endmodule
