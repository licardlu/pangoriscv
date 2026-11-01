//=============================================================================
// pangoriscv - RV32IM processor core + native AXI4 SoC (Pango PG2L100H @ 27 MHz)
// Module : axi_data_engine        File : rtl/core/axi_data_engine.v
// Rev    : 1.0                    Date : 2026-10-13
// Author : pango_lpenghan
// Brief  : AXI4 write engine (AW/W/B channels): bursts, write strobes, error responses
//=============================================================================

`include "axi_defs.vh"

module axi_data_engine (
    input wire clk, rst_n,
    input wire req_valid,
    output wire req_ready,
    input wire req_write,
    input wire [31:0] req_addr,
    input wire [2:0] req_size,
    input wire [7:0] req_len,
    input wire [3:0] req_id,
    input wire w_valid,
    output wire w_ready,
    input wire [31:0] w_data,
    input wire [3:0] w_strb,
    input wire w_last,
    output wire rsp_valid,
    input wire rsp_ready,
    output wire [31:0] rsp_data,
    output wire [1:0] rsp_resp,
    output wire rsp_last,
    output wire [3:0] rsp_id,
    output wire b_valid,
    input wire b_ready,
    output wire [1:0] b_resp,
    output wire [3:0] b_id,
    output wire protocol_fault, config_fault,

    output wire m_arvalid,
    input wire m_arready,
    output wire [31:0] m_araddr,
    output wire [3:0] m_arid,
    output wire [7:0] m_arlen,
    output wire [2:0] m_arsize,
    output wire [1:0] m_arburst,
    output wire m_arlock,
    output wire [3:0] m_arcache,
    output wire [2:0] m_arprot,
    output wire [3:0] m_arqos,
    input wire m_rvalid,
    output wire m_rready,
    input wire [31:0] m_rdata,
    input wire [3:0] m_rid,
    input wire [1:0] m_rresp,
    input wire m_rlast,
    output wire m_awvalid,
    input wire m_awready,
    output wire [31:0] m_awaddr,
    output wire [3:0] m_awid,
    output wire [7:0] m_awlen,
    output wire [2:0] m_awsize,
    output wire [1:0] m_awburst,
    output wire m_awlock,
    output wire [3:0] m_awcache,
    output wire [2:0] m_awprot,
    output wire [3:0] m_awqos,
    output wire m_wvalid,
    input wire m_wready,
    output wire [31:0] m_wdata,
    output wire [3:0] m_wstrb,
    output wire m_wlast,
    input wire m_bvalid,
    output wire m_bready,
    input wire [3:0] m_bid,
    input wire [1:0] m_bresp
);
    localparam WR_IDLE=3'd0, WR_PREP=3'd1, WR_SEND=3'd2,
               WR_RESP=3'd3, WR_HOLD=3'd4, WR_FAULT=3'd5;
    reg [2:0] state_q;
    reg [31:0] addr_q, data_q;
    reg [2:0] size_q;
    reg [7:0] len_q;
    reg [3:0] id_q, strb_q;
    reg [1:0] resp_q;
    reg aw_pending_q, w_pending_q;
    reg write_protocol_fault_q, write_config_fault_q;
    wire read_ready, read_protocol_fault, read_config_fault;
    wire read_req_valid = req_valid && !req_write && state_q==WR_IDLE &&
                          !protocol_fault && !config_fault;
    wire aw_fire = m_awvalid && m_awready;
    wire w_fire = m_wvalid && m_wready;
    wire aw_complete_now = !aw_pending_q || aw_fire;
    wire w_complete_now = !w_pending_q || w_fire;

    assign protocol_fault = read_protocol_fault || write_protocol_fault_q;
    assign config_fault = read_config_fault || write_config_fault_q;
    assign req_ready = rst_n && state_q==WR_IDLE && read_ready &&
                       !protocol_fault && !config_fault;
    // candidate A: accept the write data on the same cycle as the request
    // (w_ready in WR_IDLE); WR_PREP stays as the legacy two-cycle fallback.
    // Sticky fault states keep both ready signals low (dead engine).
    assign w_ready = rst_n && (state_q==WR_IDLE || state_q==WR_PREP) &&
                     !protocol_fault && !config_fault;
    assign m_awvalid = rst_n && state_q==WR_SEND && aw_pending_q;
    assign m_awaddr = addr_q;
    assign m_awid = id_q;
    assign m_awlen = len_q;
    assign m_awsize = size_q;
    assign m_awburst = `AXI_BURST_INCR;
    assign m_awlock = 1'b0;
    assign m_awcache = 4'b0000;
    assign m_awprot = 3'b000;
    assign m_awqos = 4'b0000;
    assign m_wvalid = rst_n && state_q==WR_SEND && w_pending_q;
    assign m_wdata = data_q;
    assign m_wstrb = strb_q;
    assign m_wlast = 1'b1;
    assign m_bready = rst_n && state_q==WR_RESP;
    // candidate A: the B response may be consumed on the same cycle it is
    // received from the AXI port; WR_HOLD is the stall-safe fallback
    wire b_arrived = m_bvalid && (m_bid==id_q);
    assign b_valid = rst_n && ((state_q==WR_HOLD) ||
                               (state_q==WR_RESP && b_arrived));
    assign b_resp = (state_q==WR_RESP) ? m_bresp : resp_q;
    assign b_id = id_q;

    axi_read_engine read_engine (
        .clk(clk), .rst_n(rst_n), .req_valid(read_req_valid), .req_ready(read_ready),
        .req_addr(req_addr), .req_size(req_size), .req_len(req_len), .req_id(req_id),
        .rsp_valid(rsp_valid), .rsp_ready(rsp_ready), .rsp_data(rsp_data),
        .rsp_resp(rsp_resp), .rsp_last(rsp_last), .rsp_id(rsp_id),
        .protocol_fault(read_protocol_fault), .config_fault(read_config_fault),
        .m_arvalid(m_arvalid), .m_arready(m_arready), .m_araddr(m_araddr),
        .m_arid(m_arid), .m_arlen(m_arlen), .m_arsize(m_arsize),
        .m_arburst(m_arburst), .m_arlock(m_arlock), .m_arcache(m_arcache),
        .m_arprot(m_arprot), .m_arqos(m_arqos),
        .m_rvalid(m_rvalid), .m_rready(m_rready), .m_rdata(m_rdata),
        .m_rid(m_rid), .m_rresp(m_rresp), .m_rlast(m_rlast)
    );

    always @(posedge clk) begin
        if(!rst_n) begin
            state_q<=WR_IDLE;
            addr_q<=0; size_q<=0; len_q<=0; id_q<=0;
            data_q<=0; strb_q<=0; resp_q<=0;
            aw_pending_q<=0; w_pending_q<=0;
            write_protocol_fault_q<=0; write_config_fault_q<=0;
        end else begin
            case(state_q)
                WR_IDLE: if(req_valid && req_ready && req_write) begin
                    if(req_len!=`AXI_ENGINE_MAX_LEN || req_size>`AXI_ENGINE_MAX_SIZE) begin
                        write_config_fault_q<=1;
                        state_q<=WR_FAULT;
`ifndef SYNTHESIS
                        $fatal(1,"ENGINE_CONFIG_LEN_SIZE");
`endif
                    end else begin
                        addr_q<=req_addr; size_q<=req_size; len_q<=req_len; id_q<=req_id;
                        if(w_valid && w_ready) begin
                            // write data arrived with the request (candidate A)
                            if(!w_last) begin
                                write_protocol_fault_q<=1;
                                state_q<=WR_FAULT;
`ifndef SYNTHESIS
                                $fatal(1,"ENGINE_W_LAST");
`endif
                            end else begin
                                data_q<=w_data; strb_q<=w_strb;
                                aw_pending_q<=1; w_pending_q<=1;
                                state_q<=WR_SEND;
                            end
                        end else begin
                            state_q<=WR_PREP;
                        end
                    end
                end
                WR_PREP: if(w_valid && w_ready) begin
                    if(!w_last) begin
                        write_protocol_fault_q<=1;
                        state_q<=WR_FAULT;
`ifndef SYNTHESIS
                        $fatal(1,"ENGINE_W_LAST");
`endif
                    end else begin
                        data_q<=w_data; strb_q<=w_strb;
                        aw_pending_q<=1; w_pending_q<=1;
                        state_q<=WR_SEND;
                    end
                end
                WR_SEND: begin
                    if(aw_fire) aw_pending_q<=0;
                    if(w_fire) w_pending_q<=0;
                    if(aw_complete_now && w_complete_now) state_q<=WR_RESP;
                end
                WR_RESP: if(m_bvalid && m_bready) begin
                    if(m_bid!=id_q) begin
                        write_protocol_fault_q<=1;
                        state_q<=WR_FAULT;
`ifndef SYNTHESIS
                        $fatal(1,"ENGINE_B_ID");
`endif
                    end else begin
                        resp_q<=m_bresp;
                        // consumer ready in this cycle -> skip WR_HOLD
                        state_q<= b_ready ? WR_IDLE : WR_HOLD;
                    end
                end
                WR_HOLD: if(b_valid && b_ready) state_q<=WR_IDLE;
                WR_FAULT: state_q<=WR_FAULT;
                default: begin
                    write_protocol_fault_q<=1;
                    state_q<=WR_FAULT;
                end
            endcase
        end
    end
endmodule
