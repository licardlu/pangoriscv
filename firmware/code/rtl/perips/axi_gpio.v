//=============================================================================
// pangoriscv - RV32IM processor core + native AXI4 SoC (Pango PG2L100H @ 27 MHz)
// Module : axi_gpio               File : rtl/perips/axi_gpio.v
// Rev    : 1.0                    Date : 2026-10-13
// Author : pango_lpenghan
// Brief  : AXI4 GPIO: two bidirectional pins, wired to KEY0 and led[1] on the board
//=============================================================================

`include "native_axi_macros.vh"
module axi_gpio #(
 parameter [31:0] BASE_ADDR=32'h40000000
)(
 input wire clk,rst_n,
 input wire [1:0] io_pin,
 output reg [31:0] reg_ctrl,reg_data,
 output wire protocol_fault,
 `AXI_SLAVE_PORTS(s,1)
);
 wire [31:0] ro,wo,wd;
 wire [3:0] ws;
 wire re,we;
 reg [1:0] sync0,sync1;
 wire [31:0] mask={{8{ws[3]}},{8{ws[2]}},{8{ws[1]}},{8{ws[0]}}};
 wire [31:0] rd=ro==0 ? reg_ctrl : ro==4 ? reg_data : 0;
 axi_reg_slave #(.BASE_ADDR(BASE_ADDR)) endpoint(
  .clk(clk),.rst_n(rst_n),`AXI_CONNECT_ALL(s,s),
  .rd_offset(ro),.wr_offset(wo),.wr_data(wd),.wr_strb(ws),
  .rd_event(re),.wr_event(we),.rd_data(rd),.protocol_fault(protocol_fault),
  .rd_ok(ro==0 || ro==4),.wr_ok(wo==0 || wo==4)
 );
 always @(posedge clk) begin
  if (!rst_n) begin
   sync0<=0; sync1<=0; reg_ctrl<=0; reg_data<=0;
  end else begin
   sync0<=io_pin; sync1<=sync0;
   if (we && wo==0) reg_ctrl<=(reg_ctrl & ~mask)|(wd & mask);
   if (we && wo==4) reg_data<=(reg_data & ~mask)|(wd & mask);
   if (reg_ctrl[1:0]==2) reg_data[0]<=sync1[0];
   if (reg_ctrl[3:2]==2) reg_data[1]<=sync1[1];
  end
 end
endmodule
