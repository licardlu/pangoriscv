//=============================================================================
// pangoriscv - RV32IM processor core + native AXI4 SoC (Pango PG2L100H @ 27 MHz)
// Module : perf_regs              File : rtl/perips/perf_regs.v
// Rev    : 1.0                    Date : 2026-10-13
// Author : pango_lpenghan
// Brief  : Performance counters: cycle, instret, fetch wait, memory wait, cache misses, mispredicts
//=============================================================================

`include "native_axi_macros.vh"
// ---------------------------------------------------------------------------
// perf_regs -- performance snapshot registers (plan spec section 6).
//
// Word offsets from BASE_ADDR (4 KiB window, single-beat accesses only):
//   0x00  CTRL      W: bit0 SNAP, bit1 CLEAR.  WSTRB[0]=1 required.
//                      SNAP copies every counter into the snapshot bank in one
//                      cycle; CLEAR zeroes the live and snapshot banks.
//                      CLEAR has priority over the same-cycle increments, and
//                      SNAP+CLEAR at once is rejected (SLVERR).
//                   R: 32'b0
//   0x04  STATUS    R: bit0 snapshot_valid (counters have been sampled)
//   0x10/0x14  CYCLE        [31:0]/[63:32] clock cycles
//   0x18/0x1C  INSTRET      retired instructions
//   0x20/0x24  IF_WAIT      cycles with the IF stage ready but no fetch result
//   0x28/0x2C  LSU_WAIT     cycles with an accepted load/store awaiting a result
//   0x30/0x34  I_MISS       I-Cache lookup misses
//   0x38/0x3C  D_MISS       D-Cache lookup misses
//   0x40/0x44  RET_CF       retired branches + JAL + JALR
//   0x48/0x4C  MISPRED      removed younger-path predictions (0 until the predictor)
//   0x50  I_AR        0x54  I_AR_LEN7  I-Cache read bursts / 8-beat refills
//   0x58  I_R_BEAT    0x5C  I_R_LAST   I-Cache R beats / completed read bursts
//   0x60  D_AR        0x64  D_AR_LEN7  D-Cache read bursts / 8-beat refills
//   0x68  D_R_BEAT    0x6C  D_R_LAST   D-Cache R beats / completed read bursts
//   0x70  D_AW        0x74  D_W_BEAT   D-Cache write commands / W beats
//   0x78  D_B                      D-Cache B responses (write completion)
//
// Every read returns the SNAPSHOT bank, not the live counters: software must
// write CTRL.SNAP before reading, otherwise reads return 0 and STATUS reads 0.
// That is what makes a 64-bit counter pair coherent.  The 0x50..0x78 AXI
// activity counters are a 32-bit extension kept in the same snapshot bank; they
// are the on-board evidence for the the caches "ARLEN=7 plus 8 R handshakes" gate.
// IF_WAIT and LSU_WAIT are overlapping stall views, they are not additive.
// ---------------------------------------------------------------------------
module perf_regs #(
 parameter [31:0] BASE_ADDR = 32'h6000_2000
)(
 input wire clk,
 input wire rst_n,
 // Event taps.
 input wire retire_fire,
 input wire [31:0] retire_inst,
 input wire pred_miss,
 input wire i_miss,
 input wire d_miss,
 input wire if_wait,
 input wire lsu_wait,
 input wire i_ar_fire,
 input wire [7:0] i_arlen,
 input wire i_r_fire,
 input wire i_rlast,
 input wire d_ar_fire,
 input wire [7:0] d_arlen,
 input wire d_r_fire,
 input wire d_rlast,
 input wire d_aw_fire,
 input wire d_w_fire,
 input wire d_b_fire,
 output wire protocol_fault,
 `AXI_SLAVE_PORTS(s,1)
);
 localparam [31:0] R_CTRL     = 32'h00;
 localparam [31:0] R_STATUS   = 32'h04;
 localparam [31:0] R_CYCLE_LO = 32'h10;
 localparam [31:0] R_CYCLE_HI = 32'h14;
 localparam [31:0] R_INST_LO  = 32'h18;
 localparam [31:0] R_INST_HI  = 32'h1C;
 localparam [31:0] R_IFW_LO   = 32'h20;
 localparam [31:0] R_IFW_HI   = 32'h24;
 localparam [31:0] R_LSUW_LO  = 32'h28;
 localparam [31:0] R_LSUW_HI  = 32'h2C;
 localparam [31:0] R_IMS_LO   = 32'h30;
 localparam [31:0] R_IMS_HI   = 32'h34;
 localparam [31:0] R_DMS_LO   = 32'h38;
 localparam [31:0] R_DMS_HI   = 32'h3C;
 localparam [31:0] R_CF_LO    = 32'h40;
 localparam [31:0] R_CF_HI    = 32'h44;
 localparam [31:0] R_MP_LO    = 32'h48;
 localparam [31:0] R_MP_HI    = 32'h4C;
 localparam [31:0] R_EXT_BASE = 32'h50;

 // Counter indices in the 64-bit bank.
 localparam integer C_CYCLE = 0;
 localparam integer C_INST  = 1;
 localparam integer C_IFW   = 2;
 localparam integer C_LSUW  = 3;
 localparam integer C_IMS   = 4;
 localparam integer C_DMS   = 5;
 localparam integer C_CF    = 6;
 localparam integer C_MP    = 7;
 // Counter indices in the 32-bit AXI activity bank.
 localparam integer X_I_AR   = 0;
 localparam integer X_I_AR7  = 1;
 localparam integer X_I_RB   = 2;
 localparam integer X_I_RL   = 3;
 localparam integer X_D_AR   = 4;
 localparam integer X_D_AR7  = 5;
 localparam integer X_D_RB   = 6;
 localparam integer X_D_RL   = 7;
 localparam integer X_D_AW   = 8;
 localparam integer X_D_WB   = 9;
 localparam integer X_D_B    = 10;

 wire [31:0] ro, wo, wd;
 wire [3:0] ws;
 wire re, we;
 wire [31:0] rd_data_w;
 wire rd_ok_w, wr_ok_w;
 reg [31:0] rd_mux;
 reg rd_hit;

 reg [63:0] cnt [0:7];
 reg [63:0] snap [0:7];
 reg [31:0] ext [0:10];
 reg [31:0] esnap [0:10];
 reg snap_valid;

 // Retired control flow: branches (no invalid funct3), JAL and JALR.
 wire [6:0] opc = retire_inst[6:0];
 wire [2:0] fn3 = retire_inst[14:12];
 wire is_branch = (opc == 7'b1100011) && (fn3 != 3'b010) && (fn3 != 3'b011);
 wire is_jal    = (opc == 7'b1101111);
 wire is_jalr   = (opc == 7'b1100111) && (fn3 == 3'b000);
 wire is_cf     = is_branch || is_jal || is_jalr;

 wire at_ctrl   = (wo == R_CTRL);
 wire ctrl_ok   = at_ctrl && ws[0] && (wd[1:0] != 2'b11);
 wire snap_req  = we && ctrl_ok && wd[0];
 wire clear_req = we && ctrl_ok && wd[1];

 assign rd_ok_w = rd_hit;
 assign wr_ok_w = ctrl_ok;

 always @* begin
  rd_hit = 1'b1;
  case (ro)
   R_CTRL:     rd_mux = 32'h0;
   R_STATUS:   rd_mux = {31'b0, snap_valid};
   R_CYCLE_LO: rd_mux = snap[C_CYCLE][31:0];
   R_CYCLE_HI: rd_mux = snap[C_CYCLE][63:32];
   R_INST_LO:  rd_mux = snap[C_INST][31:0];
   R_INST_HI:  rd_mux = snap[C_INST][63:32];
   R_IFW_LO:   rd_mux = snap[C_IFW][31:0];
   R_IFW_HI:   rd_mux = snap[C_IFW][63:32];
   R_LSUW_LO:  rd_mux = snap[C_LSUW][31:0];
   R_LSUW_HI:  rd_mux = snap[C_LSUW][63:32];
   R_IMS_LO:   rd_mux = snap[C_IMS][31:0];
   R_IMS_HI:   rd_mux = snap[C_IMS][63:32];
   R_DMS_LO:   rd_mux = snap[C_DMS][31:0];
   R_DMS_HI:   rd_mux = snap[C_DMS][63:32];
   R_CF_LO:    rd_mux = snap[C_CF][31:0];
   R_CF_HI:    rd_mux = snap[C_CF][63:32];
   R_MP_LO:    rd_mux = snap[C_MP][31:0];
   R_MP_HI:    rd_mux = snap[C_MP][63:32];
   R_EXT_BASE + 32'h00: rd_mux = esnap[X_I_AR];
   R_EXT_BASE + 32'h04: rd_mux = esnap[X_I_AR7];
   R_EXT_BASE + 32'h08: rd_mux = esnap[X_I_RB];
   R_EXT_BASE + 32'h0C: rd_mux = esnap[X_I_RL];
   R_EXT_BASE + 32'h10: rd_mux = esnap[X_D_AR];
   R_EXT_BASE + 32'h14: rd_mux = esnap[X_D_AR7];
   R_EXT_BASE + 32'h18: rd_mux = esnap[X_D_RB];
   R_EXT_BASE + 32'h1C: rd_mux = esnap[X_D_RL];
   R_EXT_BASE + 32'h20: rd_mux = esnap[X_D_AW];
   R_EXT_BASE + 32'h24: rd_mux = esnap[X_D_WB];
   R_EXT_BASE + 32'h28: rd_mux = esnap[X_D_B];
   default: begin rd_mux = 32'h0; rd_hit = 1'b0; end
  endcase
 end

 axi_reg_slave #(.BASE_ADDR(BASE_ADDR)) endpoint(
  .clk(clk),
  .rst_n(rst_n),
  `AXI_CONNECT_ALL(s,s),
  .rd_offset(ro),
  .wr_offset(wo),
  .wr_data(wd),
  .wr_strb(ws),
  .rd_event(re),
  .wr_event(we),
  .rd_data(rd_data_w),
  .rd_ok(rd_ok_w),
  .wr_ok(wr_ok_w),
  .protocol_fault(protocol_fault)
 );
 assign rd_data_w = rd_mux;

integer i;

// ---------------------------------------------------------------------------
// Increment helpers.  `cnt[i] + 64'd1` and `ext[i] + 32'd1` look free but they
// are the widest carry chains in the SoC: on `p7_path40b` (40 MHz constraint,
// fully routed) the #2 and #3 critical paths both ended in `perf_inst/cnt[2][56]`
// at 30.2 ns -- the same as the real datapath, from a counter nobody reads in
// the time-critical loop.
//
// The fix is structural, not a constraint: split the adder into 16-bit quarters
// and take each inter-quarter carry from the REGISTERED value.  The four
// adders then run in parallel off the flops, the longest chain is 16 deep, and
// the carry is a two-level AND of already-settled bits.  Functionally identical
// -- same value, same cycle, no extra flop.
// ---------------------------------------------------------------------------
function [63:0] inc64;
    input [63:0] v;
    reg c1, c2, c3;
    begin
        c1 = (v[15:0]  == 16'hFFFF);
        c2 = c1 && (v[31:16] == 16'hFFFF);
        c3 = c2 && (v[47:32] == 16'hFFFF);
        inc64 = { v[63:48] + {15'd0, c3},
                  v[47:32] + {15'd0, c2},
                  v[31:16] + {15'd0, c1},
                  v[15:0]  + 16'd1 };
    end
endfunction

function [31:0] inc32;
    input [31:0] v;
    reg c1;
    begin
        c1 = (v[15:0] == 16'hFFFF);
        inc32 = { v[31:16] + {15'd0, c1}, v[15:0] + 16'd1 };
    end
endfunction

always @(posedge clk) begin
  if (!rst_n) begin
   for (i = 0; i < 8; i = i + 1) begin
    cnt[i] <= 64'd0;
    snap[i] <= 64'd0;
   end
   for (i = 0; i < 11; i = i + 1) begin
    ext[i] <= 32'd0;
    esnap[i] <= 32'd0;
   end
   snap_valid <= 1'b0;
  end else if (clear_req) begin
   for (i = 0; i < 8; i = i + 1) begin
    cnt[i] <= 64'd0;
    snap[i] <= 64'd0;
   end
   for (i = 0; i < 11; i = i + 1) begin
    ext[i] <= 32'd0;
    esnap[i] <= 32'd0;
   end
   snap_valid <= 1'b0;
  end else begin
   cnt[C_CYCLE] <= inc64(cnt[C_CYCLE]);
   if (retire_fire) cnt[C_INST] <= inc64(cnt[C_INST]);
   if (if_wait)     cnt[C_IFW]  <= inc64(cnt[C_IFW]);
   if (lsu_wait)    cnt[C_LSUW] <= inc64(cnt[C_LSUW]);
   if (i_miss)      cnt[C_IMS]  <= inc64(cnt[C_IMS]);
   if (d_miss)      cnt[C_DMS]  <= inc64(cnt[C_DMS]);
   if (retire_fire && is_cf) cnt[C_CF] <= inc64(cnt[C_CF]);
   if (pred_miss)   cnt[C_MP]   <= inc64(cnt[C_MP]);

   if (i_ar_fire) ext[X_I_AR] <= inc32(ext[X_I_AR]);
   if (i_ar_fire && (i_arlen == 8'd7)) ext[X_I_AR7] <= inc32(ext[X_I_AR7]);
   if (i_r_fire)  ext[X_I_RB] <= inc32(ext[X_I_RB]);
   if (i_r_fire && i_rlast) ext[X_I_RL] <= inc32(ext[X_I_RL]);
   if (d_ar_fire) ext[X_D_AR] <= inc32(ext[X_D_AR]);
   if (d_ar_fire && (d_arlen == 8'd7)) ext[X_D_AR7] <= inc32(ext[X_D_AR7]);
   if (d_r_fire)  ext[X_D_RB] <= inc32(ext[X_D_RB]);
   if (d_r_fire && d_rlast) ext[X_D_RL] <= inc32(ext[X_D_RL]);
   if (d_aw_fire) ext[X_D_AW] <= inc32(ext[X_D_AW]);
   if (d_w_fire)  ext[X_D_WB] <= inc32(ext[X_D_WB]);
   if (d_b_fire)  ext[X_D_B]  <= inc32(ext[X_D_B]);

   if (snap_req) begin
    for (i = 0; i < 8; i = i + 1) snap[i] <= cnt[i];
    for (i = 0; i < 11; i = i + 1) esnap[i] <= ext[i];
    snap_valid <= 1'b1;
   end
  end
 end
endmodule
