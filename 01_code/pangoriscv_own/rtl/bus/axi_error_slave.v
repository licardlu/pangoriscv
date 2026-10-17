//=============================================================================
// pangoriscv - RV32IM processor core + native AXI4 SoC (Pango PG2L100H @ 27 MHz)
// Module : axi_error_slave        File : rtl/bus/axi_error_slave.v
// Rev    : 1.0                    Date : 2026-10-13
// Author : pango_lpenghan
// Brief  : Error slave for unmapped addresses, answers DECERR
//=============================================================================

// Unmapped-access endpoint. AW and the first W beat have independent buffers.
module axi_error_slave #(
    parameter integer WATCHDOG_CYCLES=0
) (
    input wire clk,rst_n,
    input wire s_arvalid,output wire s_arready,
    input wire [31:0] s_araddr,input wire [3:0] s_arid,
    input wire [7:0] s_arlen,input wire [2:0] s_arsize,
    input wire [1:0] s_arburst,input wire s_arlock,
    input wire [3:0] s_arcache,input wire [2:0] s_arprot,input wire [3:0] s_arqos,
    output wire s_rvalid,input wire s_rready,
    output wire [31:0] s_rdata,output wire [3:0] s_rid,
    output wire [1:0] s_rresp,output wire s_rlast,
    input wire s_awvalid,output wire s_awready,
    input wire [31:0] s_awaddr,input wire [3:0] s_awid,
    input wire [7:0] s_awlen,input wire [2:0] s_awsize,
    input wire [1:0] s_awburst,input wire s_awlock,
    input wire [3:0] s_awcache,input wire [2:0] s_awprot,input wire [3:0] s_awqos,
    input wire s_wvalid,output wire s_wready,
    input wire [31:0] s_wdata,input wire [3:0] s_wstrb,input wire s_wlast,
    output wire s_bvalid,input wire s_bready,
    output wire [3:0] s_bid,output wire [1:0] s_bresp,
    output reg protocol_fault
);
    reg read_active,write_active,w_saved,w_last,b_pending;
    reg [3:0] read_id,write_id;
    reg [8:0] read_left,write_left;
    integer idle_cycles;
    wire consume_w=write_active && w_saved && !b_pending;
    assign s_arready=rst_n && !protocol_fault && !read_active;
    assign s_rvalid=rst_n && !protocol_fault && read_active;
    assign s_rdata=0;
    assign s_rid=read_id;
    assign s_rresp=2'b11;
    assign s_rlast=read_left==1;
    assign s_awready=rst_n && !protocol_fault && !write_active && !b_pending;
    assign s_wready=rst_n && !protocol_fault && !w_saved && !b_pending;
    assign s_bvalid=rst_n && !protocol_fault && b_pending;
    assign s_bid=write_id;
    assign s_bresp=2'b11;
    always @(posedge clk) begin
        if(!rst_n) begin
            read_active<=0; write_active<=0; w_saved<=0; w_last<=0;
            b_pending<=0; read_id<=0; write_id<=0; read_left<=0;
            write_left<=0; protocol_fault<=0; idle_cycles<=0;
        end else if(!protocol_fault) begin
            if(s_arvalid && s_arready) begin
                read_active<=1; read_id<=s_arid; read_left<={1'b0,s_arlen}+9'd1;
            end
            if(s_rvalid && s_rready) begin
                read_left<=read_left-1;
                if(read_left==1) read_active<=0;
            end
            if(s_awvalid && s_awready) begin
                write_active<=1; write_id<=s_awid; write_left<={1'b0,s_awlen}+9'd1;
            end
            if(s_wvalid && s_wready) begin w_saved<=1; w_last<=s_wlast; end
            if(consume_w) begin
                if(w_last!=(write_left==1)) protocol_fault<=1;
                else begin
                    w_saved<=0; write_left<=write_left-1;
                    if(write_left==1) b_pending<=1;
                end
            end
            if(s_bvalid && s_bready) begin b_pending<=0; write_active<=0; end
            // Optional integration watchdog: expiry latches fault, never invents a response.
            if(write_active && !b_pending && !consume_w &&
               !(s_wvalid && s_wready)) begin
                if(WATCHDOG_CYCLES>0 && idle_cycles>=WATCHDOG_CYCLES-1)
                    protocol_fault<=1;
                else if(WATCHDOG_CYCLES>0) idle_cycles<=idle_cycles+1;
            end else idle_cycles<=0;
        end
    end
endmodule
