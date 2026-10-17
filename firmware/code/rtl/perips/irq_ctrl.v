//=============================================================================
// pangoriscv - RV32IM processor core + native AXI4 SoC (Pango PG2L100H @ 27 MHz)
// Module : irq_ctrl               File : rtl/perips/irq_ctrl.v
// Rev    : 1.0                    Date : 2026-10-13
// Author : pango_lpenghan
// Brief  : Interrupt controller: software/timer/external sources gathered to the CSR block
//=============================================================================

`include "native_axi_macros.vh"
module irq_ctrl #(
 parameter [31:0] BASE_ADDR=32'h60003000
)(
 input wire clk,rst_n,
 input wire [1:0] ext_event,
 output wire irq_software,irq_external,protocol_fault,
 `AXI_SLAVE_PORTS(s,1)
);
 wire [31:0] ro,wo,wd;
 wire [3:0] ws;
 wire re,we;
 reg sw_pending;
 reg [1:0] ext_pending,ext_enable,sync0,sync1,previous;
 wire [1:0] rising=sync1 & ~previous;
 wire [31:0] rd=ro==0 ? {31'b0,sw_pending} :
  ro==4 ? {30'b0,ext_pending} : ro==8 ? {30'b0,ext_enable} : 0;
 assign irq_software=sw_pending;
 assign irq_external=|(ext_pending & ext_enable);
 axi_reg_slave #(.BASE_ADDR(BASE_ADDR)) endpoint(
  .clk(clk),.rst_n(rst_n),`AXI_CONNECT_ALL(s,s),
  .rd_offset(ro),.wr_offset(wo),.wr_data(wd),.wr_strb(ws),
  .rd_event(re),.wr_event(we),.rd_data(rd),.protocol_fault(protocol_fault),
  .rd_ok(ro==0 || ro==4 || ro==8),.wr_ok(wo==0 || wo==4 || wo==8)
 );
 always @(posedge clk) begin
  if (!rst_n) begin
   sw_pending<=0; ext_pending<=0; ext_enable<=0;
   sync0<=0; sync1<=0; previous<=0;
  end else begin
   sync0<=ext_event; sync1<=sync0; previous<=sync1;
   if (we && wo==0 && ws[0]) sw_pending<=wd[0];
   if (we && wo==8 && ws[0]) ext_enable<=wd[1:0];
   ext_pending<=(ext_pending &
    ~((we && wo==4 && ws[0]) ? wd[1:0] : 2'b00)) | rising;
  end
 end
endmodule
