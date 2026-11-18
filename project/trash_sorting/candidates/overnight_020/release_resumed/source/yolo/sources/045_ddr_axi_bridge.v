// Single outstanding request per direction. Native DDR completion means the
// controller consumed the write, not nonvolatile durability or ECC acceptance.
// The word-address convention is configurable and still requires board BIST.
`timescale 1ns/1ps
module ddr_axi_bridge #(
    parameter integer DDR_ADDR_SHIFT = 2
) (
    input wire clk, rstn,
    input wire [31:0] s_awaddr,
    input wire s_awvalid,
    output wire s_awready,
    input wire [63:0] s_wdata,
    input wire [7:0] s_wstrb,
    input wire s_wvalid,
    output wire s_wready,
    output reg [1:0] s_bresp,
    output reg s_bvalid,
    input wire s_bready,
    input wire [31:0] s_araddr,
    input wire s_arvalid,
    output wire s_arready,
    output reg [63:0] s_rdata,
    output reg [1:0] s_rresp,
    output reg s_rvalid,
    input wire s_rready,
    output reg [27:0] m_awaddr,
    output wire [3:0] m_awlen,
    output reg m_awvalid,
    input wire m_awready,
    output reg [255:0] m_wdata,
    output reg [31:0] m_wstrb,
    output reg m_wvalid,
    input wire m_wready, m_wusero_last,
    output reg [27:0] m_araddr,
    output wire [3:0] m_arlen,
    output reg m_arvalid,
    input wire m_arready,
    input wire [255:0] m_rdata,
    input wire m_rvalid, m_rlast,
    output wire m_rready
);
    reg aw_have, w_have, write_active, completion_seen;
    reg [31:0] aw_hold;
    reg [63:0] w_hold;
    reg [7:0] strb_hold;
    wire write_accept = s_awvalid && s_awready;
    assign s_awready = rstn && !aw_have && !write_active && !s_bvalid;
    assign s_wready = rstn && !w_have && !write_active && !s_bvalid;
    assign m_awlen = 0;
    assign m_arlen = 0;

    always @(posedge clk) begin
        if(!rstn) begin
            aw_have<=0; w_have<=0; write_active<=0; completion_seen<=0;
            aw_hold<=0; w_hold<=0; strb_hold<=0;
            s_bresp<=0; s_bvalid<=0;
            m_awaddr<=0; m_awvalid<=0; m_wvalid<=0;
            m_wdata<=0; m_wstrb<=0;
        end else begin
            if(s_bvalid && s_bready) s_bvalid<=0;
            if(write_accept) begin aw_hold<=s_awaddr; aw_have<=1; end
            if(s_wvalid && s_wready) begin
                w_hold<=s_wdata; strb_hold<=s_wstrb; w_have<=1;
            end
            if(aw_have && w_have && !write_active && !s_bvalid) begin
                aw_have<=0; w_have<=0;
                if(aw_hold[2:0]!=0 || (aw_hold>>DDR_ADDR_SHIFT)>28'hfffffff) begin
                    s_bvalid<=1; s_bresp<=2'b10;
                end else begin
                    m_awaddr<=({aw_hold[31:5],5'b0}>>DDR_ADDR_SHIFT);
                    m_wdata<={4{w_hold}};
                    m_wstrb<={24'd0,strb_hold} << {aw_hold[4:3],3'b000};
                    m_awvalid<=1; m_wvalid<=1;
                    write_active<=1; completion_seen<=0; s_bresp<=0;
                end
            end
            if(m_awvalid && m_awready) m_awvalid<=0;
            if(m_wvalid && m_wready) m_wvalid<=0;
            if(write_active) begin
                if(m_wusero_last) completion_seen<=1;
                if((completion_seen || m_wusero_last) &&
                   (!m_awvalid || m_awready) && (!m_wvalid || m_wready)) begin
                    write_active<=0;
                    s_bvalid<=1; s_bresp<=0;
                end
            end
        end
    end

    // Reads never use a live source address after acceptance. Disable cache
    // fills while a write is pending, so a concurrent fetch cannot resurrect
    // pre-write data. A new AW invalidates the whole small line cache.
    reg read_active, cache_valid;
    reg [26:0] requested_line, cache_line;
    reg [1:0] requested_lane;
    reg [255:0] cache_data;
    assign s_arready=rstn && !read_active && !s_rvalid;
    assign m_rready=read_active && !m_arvalid;
    always @(posedge clk) begin
        if(!rstn) begin
            read_active<=0; cache_valid<=0; requested_line<=0;
            requested_lane<=0; cache_line<=0; cache_data<=0;
            m_araddr<=0; m_arvalid<=0;
            s_rdata<=0; s_rresp<=0; s_rvalid<=0;
        end else begin
            if(s_rvalid && s_rready) s_rvalid<=0;
            if(m_arvalid && m_arready) m_arvalid<=0;
            if(s_arvalid && s_arready) begin
                requested_line<=s_araddr[31:5]; requested_lane<=s_araddr[4:3];
                s_rresp<=0;
                if(s_araddr[2:0]!=0 || (s_araddr>>DDR_ADDR_SHIFT)>28'hfffffff) begin
                    s_rvalid<=1; s_rresp<=2'b10; s_rdata<=0;
                end else if(cache_valid && cache_line==s_araddr[31:5] &&
                            !write_accept && !aw_have && !write_active) begin
                    s_rdata<=cache_data[s_araddr[4:3]*64+:64]; s_rvalid<=1;
                end else begin
                    m_araddr<=({s_araddr[31:5],5'b0}>>DDR_ADDR_SHIFT);
                    m_arvalid<=1; read_active<=1;
                end
            end
            if(m_rvalid && m_rready) begin
                cache_data<=m_rdata; cache_line<=requested_line;
                cache_valid<=!aw_have && !write_active && !write_accept;
                s_rdata<=m_rdata[requested_lane*64+:64];
                s_rresp<=m_rlast ? 2'b00 : 2'b10;
                s_rvalid<=1; read_active<=0;
            end
            if(write_accept) cache_valid<=0;
        end
    end
endmodule
