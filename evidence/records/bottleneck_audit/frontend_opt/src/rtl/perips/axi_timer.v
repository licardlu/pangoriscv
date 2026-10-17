//=============================================================================
// pangoriscv - RV32IM processor core + native AXI4 SoC (Pango PG2L100H @ 27 MHz)
// Module : axi_timer              File : rtl/perips/axi_timer.v
// Rev    : 1.0                    Date : 2026-10-13
// Author : pango_lpenghan
// Brief  : AXI4 timer: 27 MHz counter with compare interrupt
//=============================================================================

`include "native_axi_macros.vh"
module axi_timer #(
 parameter [31:0] BASE_ADDR=32'h20000000
)(
 input wire clk,rst_n,
 output wire int_sig_o,protocol_fault,
 `AXI_SLAVE_PORTS(s,1)
);
 wire [31:0] ro,wo,wd;
 wire [3:0] ws;
 wire re,we;
 reg [31:0] timer_ctrl,timer_count,timer_value;
 wire [31:0] mask={{8{ws[3]}},{8{ws[2]}},{8{ws[1]}},{8{ws[0]}}};
 wire [31:0] rd=ro==0 ? timer_ctrl : ro==4 ? timer_count :
  ro==8 ? timer_value : 0;
 wire expired=timer_ctrl[0] && timer_count>=timer_value;
 assign int_sig_o=timer_ctrl[2] && timer_ctrl[1];
 axi_reg_slave #(.BASE_ADDR(BASE_ADDR)) endpoint(
  .clk(clk),.rst_n(rst_n),`AXI_CONNECT_ALL(s,s),
  .rd_offset(ro),.wr_offset(wo),.wr_data(wd),.wr_strb(ws),
  .rd_event(re),.wr_event(we),.rd_data(rd),.protocol_fault(protocol_fault),
  .rd_ok(ro==0 || ro==4 || ro==8),.wr_ok(wo==0 || wo==8)
 );
 always @(posedge clk) begin
  if (!rst_n) begin
   timer_ctrl<=0; timer_count<=0; timer_value<=0;
  end else begin
   if (timer_ctrl[0] && !expired) timer_count<=timer_count+1'b1;
   else timer_count<=0;
   if (we && wo==0) begin
    timer_ctrl<=(timer_ctrl & ~mask)|(wd & mask);
    timer_ctrl[2]<=timer_ctrl[2] & ~(wd[2] && ws[0]);
   end
   if (we && wo==8) timer_value<=(timer_value & ~mask)|(wd & mask);
   if (expired) begin timer_ctrl[0]<=0; timer_ctrl[2]<=1; end
  end
 end
endmodule
