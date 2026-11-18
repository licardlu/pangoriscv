// bridge_to_cdc -- glue between the 256-bit AXI that ddr_axi_bridge produces
// and the request/response FIFOs that axi_cdc expects.
//
// Both sides are single-beat, so there is no burst bookkeeping: an address+data
// pair becomes one request entry, and a response entry becomes either a read
// beat (RLAST) or a write-complete pulse (m_wusero_last).  Ordering is preserved
// because the CDC FIFO is a single queue for both directions, which is exactly
// what a shared DDR needs when reads and writes interleave.
`timescale 1ns/1ps

module bridge_to_cdc (
    input  wire         clk,
    input  wire         rstn,

    // ---- from ddr_axi_bridge (AXI master, 256-bit) ----
    input  wire [27:0]  br_awaddr,
    input  wire         br_awvalid,
    output wire         br_awready,
    input  wire [255:0] br_wdata,
    input  wire [31:0]  br_wstrb,
    input  wire         br_wvalid,
    output wire         br_wready,
    output reg          br_wusero_last,
    input  wire [27:0]  br_araddr,
    input  wire         br_arvalid,
    output wire         br_arready,
    output reg  [255:0] br_rdata,
    output reg          br_rvalid,
    output reg          br_rlast,
    input  wire         br_rready,

    // ---- to axi_cdc ----
    output wire         c_req_valid,
    input  wire         c_req_full,
    output wire         c_req_write,
    output wire [31:0]  c_req_addr,
    output wire [255:0] c_req_wdata,
    output wire [31:0]  c_req_wstrb,
    input  wire         c_rsp_valid,
    output wire         c_rsp_ready,
    input  wire [255:0] c_rsp_rdata,
    input  wire         c_rsp_is_read
);

    reg aw_have,w_have;
    reg [27:0] aw_hold;
    reg [255:0] data_hold;
    reg [31:0] strb_hold;
    wire pair_ready=aw_have && w_have;
    // Request VALID and payload reach the FIFO on the same edge. A registered
    // one-cycle pulse can be lost if FULL rises between admission and enqueue.
    assign c_req_valid=rstn && (pair_ready || br_arvalid);
    assign c_req_write=pair_ready;
    assign c_req_addr=pair_ready ? {4'd0,aw_hold} : {4'd0,br_araddr};
    assign c_req_wdata=data_hold;
    assign c_req_wstrb=strb_hold;
    assign br_awready=rstn && !aw_have;
    assign br_wready=rstn && !w_have;
    assign br_arready=rstn && !pair_ready && !c_req_full;
    assign c_rsp_ready=rstn && (!c_rsp_is_read || !br_rvalid || br_rready);

    always @(posedge clk) begin
        if (!rstn) begin
            aw_have<=0;w_have<=0;aw_hold<=0;data_hold<=0;strb_hold<=0;
            br_wusero_last <= 1'b0;
            br_rdata <= 0; br_rvalid <= 1'b0; br_rlast <= 1'b0;
        end
        else begin
            br_wusero_last <= 1'b0;
            if(br_awvalid && br_awready) begin
                aw_have<=1;aw_hold<=br_awaddr;
            end
            if(br_wvalid && br_wready) begin
                w_have<=1;data_hold<=br_wdata;strb_hold<=br_wstrb;
            end
            if(pair_ready && !c_req_full) begin aw_have<=0;w_have<=0;end
            if(br_rvalid && br_rready) begin br_rvalid<=0;br_rlast<=0;end
            if (c_rsp_valid && c_rsp_ready) begin
                if (c_rsp_is_read) begin
                    br_rdata  <= c_rsp_rdata;
                    br_rvalid <= 1'b1;
                    br_rlast  <= 1'b1;
                end
                else
                    br_wusero_last <= 1'b1;
            end
        end
    end
endmodule
