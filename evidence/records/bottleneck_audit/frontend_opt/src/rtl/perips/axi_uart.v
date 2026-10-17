//=============================================================================
// pangoriscv - RV32IM processor core + native AXI4 SoC (Pango PG2L100H @ 27 MHz)
// Module : axi_uart               File : rtl/perips/axi_uart.v
// Rev    : 1.0                    Date : 2026-10-13
// Author : pango_lpenghan
// Brief  : AXI4 UART endpoint for the team SoC: a byte-wide register window on
//          top of the AXI register bridge, a divider-paced 8N1 transmitter on
//          tx_pin and an oversampling 8N1 receiver on rx_pin. This is the print
//          channel used by the on-board self-test and benchmark images.
//=============================================================================

`include "native_axi_macros.vh"

// Register byte offsets: 0x0 control, 0x4 status, 0x8 baud divider, 0xC push a
// transmit byte, 0x10 received byte.
module axi_uart #(
 parameter [31:0] BASE_ADDR=32'h30000000
)(
 input wire clk,rst_n,
 output wire tx_pin,protocol_fault,
 input wire rx_pin,
 `AXI_SLAVE_PORTS(s,1)
);
 //-------------------------------------------------------------- sizing notes
 // One 8N1 bit cell lasts (divider + 1) clk periods. The board oscillator runs
 // at 27 MHz, so a 115200 baud cell is 27e6/115200 = 234.375 -> the reset
 // divider is 234 and firmware may replace it through the baud register. The
 // transmitter parks high while idle and pulls low for the start bit; the
 // receiver samples the incoming line at the middle of every following cell.
 localparam [15:0] BOOT_DIVIDER = 16'd234;

 // Transmitter phases, one-hot so the idle test stays a single bit compare.
 localparam [3:0] PH_IDLE    = 4'b0001;
 localparam [3:0] PH_START   = 4'b0010;
 localparam [3:0] PH_PAYLOAD = 4'b0100;
 localparam [3:0] PH_STOP    = 4'b1000;

 //------------------------------------------------------------ register window
 reg [31:0] ctrl_q,stat_q,baud_q,rxbyte_q;

 //------------------------------------------------------------ transmit engine
 reg [3:0]  ph_q;
 reg [3:0]  bit_q;
 reg [15:0] tick_q;
 reg [7:0]  byte_q;
 reg        push_q;      // one-cycle request latched from a register write
 reg        done_q;      // one-cycle completion pulse handed to the status file
 reg        line_q;      // registered tx_pin driver

 //------------------------------------------------------------- receive engine
 reg        pin_r0,pin_r1;
 reg        rx_run;
 reg        rx_level;
 reg [3:0]  rx_edge_q;
 reg [15:0] rx_span_q,rx_count_q;
 reg [7:0]  rx_bits_q;
 reg        rx_full,rx_full_d;

 //-------------------------------------------------------------- bus plumbing
 wire rx_fall=pin_r1 & ~pin_r0;
 wire [31:0] rd_off,wr_off,wr_data;
 wire [3:0]  wr_strb;
 wire rd_hit,wr_hit;
 wire [31:0] byte_lane={{8{wr_strb[3]}},{8{wr_strb[2]}},{8{wr_strb[1]}},{8{wr_strb[0]}}};
 wire [31:0] rd_mux=rd_off==0  ? ctrl_q   : rd_off==4 ? stat_q :
                    rd_off==8  ? baud_q   : rd_off==16 ? rxbyte_q : 32'd0;
 // A transmit push is taken only while the port is enabled and no earlier push
 // is still pending; the other three offsets are always writable.
 wire wr_accept=wr_off==0 || wr_off==4 || wr_off==8 ||
                (wr_off==12 && ctrl_q[0] && !stat_q[0]);
 assign tx_pin=line_q;

 axi_reg_slave #(.BASE_ADDR(BASE_ADDR)) port0(
  .clk(clk),.rst_n(rst_n),`AXI_CONNECT_ALL(s,s),
  .rd_offset(rd_off),.wr_offset(wr_off),.wr_data(wr_data),.wr_strb(wr_strb),
  .rd_event(rd_hit),.wr_event(wr_hit),.rd_data(rd_mux),.protocol_fault(protocol_fault),
  .rd_ok(rd_off==0 || rd_off==4 || rd_off==8 || rd_off==16),.wr_ok(wr_accept)
 );

 //------------------------------------------------------ control / status file
 // CTRL[0] enables the port and CTRL[1] enables the receiver. STATUS[0] tracks a
 // pending transmit byte and STATUS[1] reports a received one; a byte-lane-0
 // write clears the receive flag. The completion pulse clears STATUS[0] and the
 // write case below re-raises it when a new byte is pushed in the same cycle.
 always @(posedge clk) begin
  if (!rst_n) begin
   ctrl_q<=32'd0; stat_q<=32'd0; rxbyte_q<=32'd0;
   baud_q<={16'b0,BOOT_DIVIDER};
   push_q<=1'b0; byte_q<=8'd0; rx_full_d<=1'b0;
  end else begin
   push_q<=1'b0;
   rx_full_d<=rx_full;
   if (done_q) stat_q[0]<=1'b0;
   if (wr_hit) begin
    case (wr_off)
     0:  ctrl_q<=(ctrl_q & ~byte_lane)|(wr_data & byte_lane);
     4:  if (wr_strb[0]) stat_q[1]<=wr_data[1];
     8:  baud_q<=(baud_q & ~byte_lane)|(wr_data & byte_lane);
     12: if (wr_strb[0]) begin
          byte_q<=wr_data[7:0];
          stat_q[0]<=1'b1;
          push_q<=1'b1;
         end
     default: ;
    endcase
   end
   if (ctrl_q[1] && rx_full && !rx_full_d) begin
    stat_q[1]<=1'b1;
    rxbyte_q<={24'b0,rx_bits_q};
   end
  end
 end

 //------------------------------------------------------------ serial transmit
 // The bit clock only advances while a frame is in flight. Every phase boundary
 // lands on a full divider period, and the stop phase releases the completion
 // pulse in the same cycle in which the engine returns to idle.
 always @(posedge clk) begin
  if (!rst_n) begin
   ph_q<=PH_IDLE; bit_q<=4'd0; tick_q<=16'd0; done_q<=1'b0; line_q<=1'b0;
  end else begin
   if (ph_q==PH_IDLE) begin
    line_q<=1'b1;
    done_q<=1'b0;
    if (push_q) begin
     ph_q<=PH_START;
     bit_q<=4'd0;
     tick_q<=16'd0;
     line_q<=1'b0;
    end
   end else begin
    tick_q<=tick_q+16'd1;
    if (tick_q==baud_q[15:0]) begin
     tick_q<=16'd0;
     case (ph_q)
      PH_START: begin
       line_q<=byte_q[bit_q];
       ph_q<=PH_PAYLOAD;
       bit_q<=bit_q+4'd1;
      end
      PH_PAYLOAD: begin
       bit_q<=bit_q+4'd1;
       if (bit_q==4'd8) begin
        ph_q<=PH_STOP;
        line_q<=1'b1;
       end else begin
        line_q<=byte_q[bit_q];
       end
      end
      PH_STOP: begin
       line_q<=1'b1;
       ph_q<=PH_IDLE;
       done_q<=1'b1;
      end
      default: ;
     endcase
    end
   end
  end
 end

 //-------------------------------------------------------------- receive front
 // Two flops resynchronise the serial input; a falling edge on the synchronised
 // line marks the start of a frame.
 always @(posedge clk) begin
  if (!rst_n) begin pin_r0<=1'b0; pin_r1<=1'b0; end
  else begin pin_r0<=rx_pin; pin_r1<=pin_r0; end
 end

 // A frame spans ten sampling edges (0 holds the half-cell, 1..9 walk the bits)
 // and is abandoned whenever the receiver is disabled from the control register.
 always @(posedge clk) begin
  if (!rst_n) rx_run<=1'b0;
  else if (ctrl_q[1]) begin
   if (rx_fall) rx_run<=1'b1;
   else if (rx_edge_q==4'd9) rx_run<=1'b0;
  end else begin
   rx_run<=1'b0;
  end
 end

 // The first cell is only half a bit long because the incoming start edge is not
 // phase aligned; the half value is installed in the cycle the frame starts and
 // every later cell uses the full divider again.
 always @(posedge clk) begin
  if (!rst_n) rx_span_q<=16'd0;
  else if (rx_run && rx_edge_q==4'd0) rx_span_q<={1'b0,baud_q[15:1]};
  else rx_span_q<=baud_q[15:0];
 end

 always @(posedge clk) begin
  if (!rst_n) rx_count_q<=16'd0;
  else if (rx_run) begin
   if (rx_count_q==rx_span_q) rx_count_q<=16'd0;
   else rx_count_q<=rx_count_q+16'd1;
  end else begin
   rx_count_q<=16'd0;
  end
 end

 // The edge strobe is high for the single cycle in which the sampling counter
 // reaches the span, and the edge index advances with it.
 always @(posedge clk) begin
  if (!rst_n) begin rx_edge_q<=4'd0; rx_level<=1'b0; end
  else if (rx_run) begin
   if (rx_count_q==rx_span_q) begin
    if (rx_edge_q==4'd9) begin
     rx_edge_q<=4'd0;
     rx_level<=1'b0;
    end else begin
     rx_edge_q<=rx_edge_q+4'd1;
     rx_level<=1'b1;
    end
   end else begin
    rx_level<=1'b0;
   end
  end else begin
   rx_edge_q<=4'd0;
   rx_level<=1'b0;
  end
 end

 // Edges 2..9 carry data bits 0..7; the sampled level is accumulated into the
 // byte and the final edge raises the completion flag for the status file.
 always @(posedge clk) begin
  if (!rst_n) begin rx_bits_q<=8'd0; rx_full<=1'b0; end
  else if (rx_run) begin
   if (rx_level) begin
    case (rx_edge_q)
     4'd2,4'd3,4'd4,4'd5,4'd6,4'd7,4'd8,4'd9: begin
      rx_bits_q<=rx_bits_q | ({7'b0,pin_r1} << (rx_edge_q-4'd2));
      if (rx_edge_q==4'd9) rx_full<=1'b1;
     end
     default: ;
    endcase
   end
  end else begin
   rx_bits_q<=8'd0;
   rx_full<=1'b0;
  end
 end
endmodule
