//=============================================================================
// pangoriscv - RV32IM processor core + native AXI4 SoC (Pango PG2L100H @ 27 MHz)
// Module : axi_read_engine        File : rtl/core/axi_read_engine.v
// Rev    : 1.0                    Date : 2026-10-13
// Author : pango_lpenghan
// Brief  : AXI4 read engine (AR/R channels): bursts and error responses
//=============================================================================

`include "axi_defs.vh"

module axi_read_engine (
    input wire clk, rst_n,
    input wire req_valid,
    output wire req_ready,
    input wire [31:0] req_addr,
    input wire [2:0] req_size,
    input wire [7:0] req_len,
    input wire [3:0] req_id,
    output wire rsp_valid,
    input wire rsp_ready,
    output wire [31:0] rsp_data,
    output wire [1:0] rsp_resp,
    output wire rsp_last,
    output wire [3:0] rsp_id,
    output reg protocol_fault,
    output reg config_fault,

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
    input wire m_rlast
);
    localparam RD_IDLE=3'd0, RD_ADDR=3'd1, RD_DATA=3'd2,
               RD_HOLD=3'd3, RD_FAULT=3'd4;
    reg [2:0] state_q;
    reg [31:0] addr_q, data_q;
    reg [2:0] size_q;
    reg [7:0] len_q;
    reg [3:0] id_q;
    reg [1:0] resp_q;
    reg last_q;

    assign req_ready = rst_n && state_q==RD_IDLE;
    assign m_arvalid = rst_n && state_q==RD_ADDR;
    assign m_araddr = addr_q;
    assign m_arid = id_q;
    assign m_arlen = len_q;
    assign m_arsize = size_q;
    assign m_arburst = `AXI_BURST_INCR;
    assign m_arlock = 1'b0;
    assign m_arcache = 4'b0000;
    assign m_arprot = 3'b000;
    assign m_arqos = 4'b0000;
    assign m_rready = rst_n && state_q==RD_DATA;
    assign rsp_valid = rst_n && state_q==RD_HOLD;
    assign rsp_data = data_q;
    assign rsp_resp = resp_q;
    assign rsp_last = last_q;
    assign rsp_id = id_q;

    always @(posedge clk) begin
        if(!rst_n) begin
            state_q<=RD_IDLE;
            addr_q<=0; size_q<=0; len_q<=0; id_q<=0;
            data_q<=0; resp_q<=0; last_q<=0;
            protocol_fault<=0; config_fault<=0;
        end else begin
            case(state_q)
                RD_IDLE: if(req_valid && req_ready) begin
                    if(req_len!=`AXI_ENGINE_MAX_LEN || req_size>`AXI_ENGINE_MAX_SIZE) begin
                        config_fault<=1;
                        state_q<=RD_FAULT;
`ifndef SYNTHESIS
                        $fatal(1,"ENGINE_CONFIG_LEN_SIZE");
`endif
                    end else begin
                        addr_q<=req_addr; size_q<=req_size; len_q<=req_len; id_q<=req_id;
                        state_q<=RD_ADDR;
                    end
                end
                RD_ADDR: if(m_arvalid && m_arready) state_q<=RD_DATA;
                RD_DATA: if(m_rvalid && m_rready) begin
                    if(m_rid!=id_q || !m_rlast) begin
                        // Lost framing is not an ordinary load error or a completion.
                        protocol_fault<=1;
                        state_q<=RD_FAULT;
`ifndef SYNTHESIS
                        $fatal(1,"ENGINE_R_ID_LAST");
`endif
                    end else begin
                        data_q<=m_rdata; resp_q<=m_rresp; last_q<=m_rlast;
                        state_q<=RD_HOLD;
                    end
                end
                RD_HOLD: if(rsp_valid && rsp_ready) state_q<=RD_IDLE;
                RD_FAULT: state_q<=RD_FAULT;
                default: begin
                    protocol_fault<=1;
                    state_q<=RD_FAULT;
                end
            endcase
        end
    end
endmodule
