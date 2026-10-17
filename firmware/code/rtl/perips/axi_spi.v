//=============================================================================
// pangoriscv - RV32IM processor core + native AXI4 SoC (Pango PG2L100H @ 27 MHz)
// Module : axi_spi                File : rtl/perips/axi_spi.v
// Rev    : 1.0                    Date : 2026-10-13
// Author : pango_lpenghan
// Brief  : AXI4 SPI master endpoint for the team SoC: a byte-wide register
//          window on top of the AXI register bridge plus a divide-by-(CTRL[15:8]
//          +1) shift engine that drives spi_clk/spi_mosi and samples spi_miso for
//          eight bits. CTRL selects clock polarity, clock phase and the chip
//          select level; the shift direction follows the data phase.
//=============================================================================

`include "native_axi_macros.vh"

// Register byte offsets: 0x0 control, 0x4 data, 0x8 busy.
module axi_spi #(
 parameter [31:0] BASE_ADDR=32'h50000000
)(
 input wire clk,rst_n,
 output reg spi_mosi,
 input wire spi_miso,
 output wire spi_ss,protocol_fault,
 output reg spi_clk,
 `AXI_SLAVE_PORTS(s,1)
);
 // One half of a bit cell lasts (divider + 1) clk periods. A transfer runs
 // seventeen half-cell edges: edges 1..16 toggle the clock and shift one bit,
 // edge 17 parks the clock on the idle level selected by CTRL[1]. The engine is
 // busy from the moment CTRL[0] is written until that final edge.
 localparam [4:0] EDGE_LAST = 5'd17;

 //------------------------------------------------------------ register window
 reg [31:0] ctrl_q,data_q;

 //-------------------------------------------------------------- shift engine
 reg [8:0]  tick_q;
 reg        run_q;
 reg        level_q;
 reg        done_q;
 reg [4:0]  edge_q;
 reg [7:0]  rdata_q;
 reg [3:0]  bitq_q;

 //-------------------------------------------------------------- bus plumbing
 wire [31:0] rd_off,wr_off,wr_data;
 wire [3:0]  wr_strb;
 wire rd_hit,wr_hit;
 wire [8:0]  span_q  = {1'b0,ctrl_q[15:8]};
 wire [31:0] byte_lane={{8{wr_strb[3]}},{8{wr_strb[2]}},{8{wr_strb[1]}},{8{wr_strb[0]}}};
 wire        busy    = run_q || ctrl_q[0] || done_q;
 wire [31:0] rd_mux  = rd_off==0 ? ctrl_q : rd_off==4 ? data_q :
                       rd_off==8 ? {31'b0,busy} : 32'd0;
 // CTRL and DATA are only writable while the engine is idle; the busy flag is
 // readable at 0x8 so firmware can poll instead of guessing.
 wire        wr_accept = (wr_off==0 || wr_off==4) && !busy;
 assign spi_ss = ~ctrl_q[3];

 axi_reg_slave #(.BASE_ADDR(BASE_ADDR)) port0(
  .clk(clk),.rst_n(rst_n),`AXI_CONNECT_ALL(s,s),
  .rd_offset(rd_off),.wr_offset(wr_off),.wr_data(wr_data),.wr_strb(wr_strb),
  .rd_event(rd_hit),.wr_event(wr_hit),.rd_data(rd_mux),.protocol_fault(protocol_fault),
  .rd_ok(rd_off==0 || rd_off==4 || rd_off==8),.wr_ok(wr_accept)
 );

 //------------------------------------------------------ control / data traffic
 // CTRL[0] is self-clearing: it starts a transfer and is dropped again in the
 // same block, so the engine sees a one-cycle start request. A finished
 // transfer overwrites DATA with the byte that was shifted in.
 always @(posedge clk) begin
  if (!rst_n) begin
   ctrl_q<=32'd0; data_q<=32'd0;
  end else begin
   ctrl_q[0]<=1'b0;
   if (wr_hit && wr_off==0) ctrl_q<=(ctrl_q & ~byte_lane)|(wr_data & byte_lane);
   if (wr_hit && wr_off==4) data_q<=(data_q & ~byte_lane)|(wr_data & byte_lane);
   if (done_q) data_q<={24'b0,rdata_q};
  end
 end

 // The run flag spans the whole transfer: it rises on the start request and
 // falls on the completion edge.
 always @(posedge clk) begin
  if (!rst_n) run_q<=1'b0;
  else if (ctrl_q[0]) run_q<=1'b1;
  else if (done_q) run_q<=1'b0;
 end

 // Half-cell prescaler, held at zero while the engine is idle.
 always @(posedge clk) begin
  if (!rst_n) tick_q<=9'd0;
  else if (run_q) begin
   if (tick_q==span_q) tick_q<=9'd0;
   else tick_q<=tick_q+9'd1;
  end else begin
   tick_q<=9'd0;
  end
 end

 // Edge strobe and edge index; the index wraps at EDGE_LAST and the strobe is
 // high for the single cycle in which a half cell boundary is reached.
 always @(posedge clk) begin
  if (!rst_n) begin edge_q<=5'd0; level_q<=1'b0; end
  else if (run_q) begin
   if (tick_q==span_q) begin
    if (edge_q==EDGE_LAST) begin
     edge_q<=5'd0;
     level_q<=1'b0;
    end else begin
     edge_q<=edge_q+5'd1;
     level_q<=1'b1;
    end
   end else begin
    level_q<=1'b0;
   end
  end else begin
   edge_q<=5'd0;
   level_q<=1'b0;
  end
 end

 //--------------------------------------------------------- clock and data path
 // Odd and even edges are the two halves of one bit cell; each of them toggles
 // spi_clk and performs the shift for its own half. CTRL[2] selects which half
 // drives MOSI and which half samples MISO. While the engine is idle the clock
 // parks on CTRL[1] and the first transmit bit is preloaded.
 always @(posedge clk) begin
  if (!rst_n) begin spi_clk<=1'b0; rdata_q<=8'd0; spi_mosi<=1'b0; bitq_q<=4'd0; end
  else if (run_q) begin
   if (level_q) begin
    case (edge_q)
     5'd1,5'd3,5'd5,5'd7,5'd9,5'd11,5'd13,5'd15: begin
      spi_clk<=~spi_clk;
      if (ctrl_q[2]) begin
       spi_mosi<=data_q[bitq_q];
       bitq_q<=bitq_q-4'd1;
      end else begin
       rdata_q<={rdata_q[6:0],spi_miso};
      end
     end
     5'd2,5'd4,5'd6,5'd8,5'd10,5'd12,5'd14,5'd16: begin
      spi_clk<=~spi_clk;
      if (ctrl_q[2]) begin
       rdata_q<={rdata_q[6:0],spi_miso};
      end else begin
       spi_mosi<=data_q[bitq_q];
       bitq_q<=bitq_q-4'd1;
      end
     end
     EDGE_LAST: spi_clk<=ctrl_q[1];
     default: ;
    endcase
   end
  end else begin
   spi_clk<=ctrl_q[1];
   if (!ctrl_q[2]) begin
    spi_mosi<=data_q[7];
    bitq_q<=4'h6;
   end else begin
    bitq_q<=4'h7;
   end
  end
 end

 // Completion: the run flag is still high in the cycle that reaches the final
 // edge, which is exactly the window used to hand the received byte over.
 always @(posedge clk) begin
  if (!rst_n) done_q<=1'b0;
  else done_q<=run_q && edge_q==EDGE_LAST;
 end
endmodule
