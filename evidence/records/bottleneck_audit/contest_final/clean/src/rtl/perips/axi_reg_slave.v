//=============================================================================
// pangoriscv - RV32IM processor core + native AXI4 SoC (Pango PG2L100H @ 27 MHz)
// Module : axi_reg_slave          File : rtl/perips/axi_reg_slave.v
// Rev    : 1.0                    Date : 2026-10-13
// Author : pango_lpenghan
// Brief  : AXI4 register-slave framework for memory-mapped peripherals
//=============================================================================

`include "native_axi_macros.vh"
module axi_reg_slave #(
 parameter [31:0] BASE_ADDR=0,
 parameter integer WINDOW_BYTES=4096
)(
 input wire clk,rst_n,
 `AXI_SLAVE_PORTS(s,1),
 output wire [31:0] rd_offset,wr_offset,wr_data,
 output wire [3:0] wr_strb,
 output wire rd_event,wr_event,
 input wire [31:0] rd_data,
 input wire rd_ok,wr_ok,
 output reg protocol_fault
);
 reg rvalid,bvalid,aw_pending,w_pending;
 reg [31:0] rdata,awaddr,wdata;
 reg [3:0] rid,bid,awid,wstrb;
 reg [1:0] rresp,bresp;
 reg [7:0] rleft,awlen,windex;
 reg [2:0] awsize;
 reg [1:0] awburst;
 reg awlock,wlast;
 function legal_address;
  input [31:0] addr;
  input [2:0] size;
  input [1:0] burst;
  input locked;
  begin
   legal_address=addr>=BASE_ADDR &&
    ({1'b0,addr}+(33'd1<<size)) <= ({1'b0,BASE_ADDR}+WINDOW_BYTES) &&
    size<=2 && (burst==0 || burst==1) && !locked &&
    ((size==0) || (size==1 && !addr[0]) ||
     (size==2 && addr[1:0]==0));
  end
 endfunction
 wire read_legal=legal_address(s_araddr,s_arsize,s_arburst,s_arlock) &&
  s_arlen==0;
 wire [3:0] lane_mask=(awsize==0) ? (4'b0001<<awaddr[1:0]) :
  (awsize==1) ? (4'b0011<<awaddr[1:0]) : 4'b1111;
 wire write_legal=legal_address(awaddr,awsize,awburst,awlock) &&
  awlen==0 && wlast && ((wstrb & ~lane_mask)==0);
 wire live=rst_n && !protocol_fault;
 wire framing_ok=wlast==(windex==awlen);
 wire consume=live && aw_pending && w_pending && !bvalid;
 assign s_arready=live && !rvalid;
 assign s_rvalid=live && rvalid;
 assign s_rdata=rdata;
 assign s_rid=rid;
 assign s_rresp=rresp;
 assign s_rlast=(rleft==0);
 assign s_awready=live && !aw_pending && !bvalid;
 assign s_wready=live && !w_pending && !bvalid;
 assign s_bvalid=live && bvalid;
 assign s_bid=bid;
 assign s_bresp=bresp;
 assign rd_offset=(s_araddr-BASE_ADDR)&32'hfffffffc;
 assign wr_offset=(awaddr-BASE_ADDR)&32'hfffffffc;
 assign wr_data=wdata;
 assign wr_strb=wstrb;
 assign rd_event=s_arvalid && s_arready && read_legal && rd_ok;
 assign wr_event=consume && framing_ok && write_legal && wr_ok;
 always @(posedge clk) begin
  if (!rst_n) begin
   protocol_fault<=0;
   rvalid<=0; bvalid<=0; aw_pending<=0; w_pending<=0;
   rdata<=0; rid<=0; rresp<=0; rleft<=0;
   awaddr<=0; awid<=0; awlen<=0; awsize<=0;
   awburst<=0; awlock<=0; wdata<=0; wstrb<=0; wlast<=0;
   windex<=0; bid<=0; bresp<=0;
  end else begin
   if (s_arvalid && s_arready) begin
    rvalid<=1; rid<=s_arid; rleft<=s_arlen;
    rdata<=(read_legal && rd_ok) ? rd_data : 32'b0;
    rresp<=(read_legal && rd_ok) ? 2'b00 : 2'b10;
   end else if (rvalid && s_rready) begin
    if (rleft==0) rvalid<=0;
    else rleft<=rleft-1'b1;
   end
   if (s_awvalid && s_awready) begin
    aw_pending<=1; awaddr<=s_awaddr; awid<=s_awid;
    awlen<=s_awlen; awsize<=s_awsize;
    awburst<=s_awburst; awlock<=s_awlock; windex<=0;
   end
   if (s_wvalid && s_wready) begin
    w_pending<=1; wdata<=s_wdata; wstrb<=s_wstrb; wlast<=s_wlast;
   end
   // Unsupported bursts still consume exactly AWLEN+1 W beats.
   if (consume && !framing_ok) protocol_fault<=1;
   if (consume && framing_ok) begin
    w_pending<=0;
    if (windex==awlen) begin
     aw_pending<=0; bvalid<=1; bid<=awid;
     bresp<=(write_legal && wr_ok) ? 2'b00 : 2'b10;
    end else windex<=windex+1'b1;
   end
   if (bvalid && s_bready) bvalid<=0;
  end
 end
endmodule
