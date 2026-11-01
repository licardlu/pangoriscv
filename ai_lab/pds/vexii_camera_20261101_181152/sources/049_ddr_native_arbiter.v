// Two clients of the vendor native DDR port. Ownership lasts through the final
// returned beat, not just the address handshake. Read and write arbitrate
// independently; each direction permits one outstanding native burst.
`timescale 1ns/1ps
module ddr_native_arbiter(
    input wire clk,rstn,
    input wire [55:0] s_awaddr,s_araddr,
    input wire [7:0] s_awlen,s_arlen,
    input wire [7:0] s_awid,s_arid,
    input wire [1:0] s_awvalid,s_arvalid,
    output wire [1:0] s_awready,s_arready,
    input wire [511:0] s_wdata,
    input wire [63:0] s_wstrb,
    output wire [1:0] s_wready,s_wlast,
    output wire [255:0] s_rdata,
    output wire [1:0] s_rvalid,s_rlast,
    output wire [3:0] s_rid,
    output wire [27:0] m_awaddr,m_araddr,
    output wire [3:0] m_awlen,m_arlen,m_awid,m_arid,
    output wire m_awvalid,m_arvalid,
    input wire m_awready,m_arready,
    output wire [255:0] m_wdata,
    output wire [31:0] m_wstrb,
    input wire m_wready,m_wlast,
    input wire [255:0] m_rdata,
    input wire m_rvalid,m_rlast,
    input wire [3:0] m_rid
);
    reg wbusy,rbusy,wowner,rowner,wsent,rsent,wprefer,rprefer;
    assign m_awaddr=s_awaddr[wowner*28+:28];
    assign m_awlen=s_awlen[wowner*4+:4];
    assign m_awid=s_awid[wowner*4+:4];
    assign m_awvalid=wbusy && !wsent && s_awvalid[wowner];
    assign m_wdata=s_wdata[wowner*256+:256];
    assign m_wstrb=s_wstrb[wowner*32+:32];
    assign s_awready=wbusy && !wsent ? ({1'b0,m_awready}<<wowner) : 2'b0;
    assign s_wready=wbusy ? ({1'b0,m_wready}<<wowner) : 2'b0;
    assign s_wlast=wbusy ? ({1'b0,m_wlast}<<wowner) : 2'b0;
    assign m_araddr=s_araddr[rowner*28+:28];
    assign m_arlen=s_arlen[rowner*4+:4];
    assign m_arid=s_arid[rowner*4+:4];
    assign m_arvalid=rbusy && !rsent && s_arvalid[rowner];
    assign s_arready=rbusy && !rsent ? ({1'b0,m_arready}<<rowner) : 2'b0;
    assign s_rdata=m_rdata;
    assign s_rid=m_rid;
    assign s_rvalid=rbusy ? ({1'b0,m_rvalid}<<rowner) : 2'b0;
    assign s_rlast=rbusy ? ({1'b0,m_rlast}<<rowner) : 2'b0;
    always @(posedge clk) begin
        if(!rstn) begin
            wbusy<=0;rbusy<=0;wowner<=0;rowner<=0;
            wsent<=0;rsent<=0;wprefer<=0;rprefer<=0;
        end else begin
            if(!wbusy && |s_awvalid) begin
                wowner<=s_awvalid[wprefer] ? wprefer : !wprefer;
                wbusy<=1;wsent<=0;
            end
            if(m_awvalid && m_awready) wsent<=1;
            if(wbusy && (wsent || (m_awvalid && m_awready)) && m_wlast) begin
                wbusy<=0;wprefer<=!wowner;
            end
            if(!rbusy && |s_arvalid) begin
                rowner<=s_arvalid[rprefer] ? rprefer : !rprefer;
                rbusy<=1;rsent<=0;
            end
            if(m_arvalid && m_arready) rsent<=1;
            if(rbusy && (rsent || (m_arvalid && m_arready)) && m_rvalid && m_rlast) begin
                rbusy<=0;rprefer<=!rowner;
            end
        end
    end
endmodule
