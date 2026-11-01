//=============================================================================
// pangoriscv - RV32IM processor core + native AXI4 SoC (Pango PG2L100H @ 27 MHz)
// Module : tb_perf_regs           File : tb/unit/tb_perf_regs.sv
// Rev    : 1.0                    Date : 2026-10-13
// Author : pango_lpenghan
// Brief  : Unit test for the performance counter registers at 0x60002000
//=============================================================================

// Unit test for rtl/perips/perf_regs.v -- the the caches and predictor performance snapshot
// registers at 0x60002000 (plan spec section 6).
//
// The testbench models the AXI master (single-beat accesses only, matching
// axi_reg_slave) and injects the event taps directly, so every counter has an
// exact expected value.  It also checks the two things the on-board the caches gate
// depends on: a snapshot is copied in one cycle and stays stable while the live
// counters keep moving, and every 8-beat refill produces eight R handshakes.
`timescale 1ns/1ps
`include "native_axi_macros.vh"
module tb_perf_regs;
 localparam [31:0] BASE = 32'h6000_2000;

 reg clk = 1'b0;
 reg rst_n = 1'b0;
 always #5 clk = ~clk;

 // AXI master side (one port, packed endpoint 0).
 reg s_arvalid;
 wire s_arready;
 reg [31:0] s_araddr;
 reg [3:0] s_arid;
 reg [7:0] s_arlen;
 reg [2:0] s_arsize;
 reg [1:0] s_arburst;
 reg s_arlock;
 reg [3:0] s_arcache;
 reg [2:0] s_arprot;
 reg [3:0] s_arqos;
 wire s_rvalid;
 reg s_rready;
 wire [31:0] s_rdata;
 wire [3:0] s_rid;
 wire [1:0] s_rresp;
 wire s_rlast;
 reg s_awvalid;
 wire s_awready;
 reg [31:0] s_awaddr;
 reg [3:0] s_awid;
 reg [7:0] s_awlen;
 reg [2:0] s_awsize;
 reg [1:0] s_awburst;
 reg s_awlock;
 reg [3:0] s_awcache;
 reg [2:0] s_awprot;
 reg [3:0] s_awqos;
 reg s_wvalid;
 wire s_wready;
 reg [31:0] s_wdata;
 reg [3:0] s_wstrb;
 reg s_wlast;
 wire s_bvalid;
 reg s_bready;
 wire [3:0] s_bid;
 wire [1:0] s_bresp;

 // Event taps.
 reg retire_fire;
 reg [31:0] retire_inst;
 reg pred_miss;
 reg i_miss, d_miss, if_wait, lsu_wait;
 reg i_ar_fire, i_r_fire, i_rlast;
 reg [7:0] i_arlen;
 reg d_ar_fire, d_r_fire, d_rlast;
 reg [7:0] d_arlen;
 reg d_aw_fire, d_w_fire, d_b_fire;

 wire protocol_fault;

 perf_regs #(.BASE_ADDR(BASE)) dut(
  .clk(clk), .rst_n(rst_n),
  .retire_fire(retire_fire), .retire_inst(retire_inst), .pred_miss(pred_miss),
  .i_miss(i_miss), .d_miss(d_miss), .if_wait(if_wait), .lsu_wait(lsu_wait),
  .i_ar_fire(i_ar_fire), .i_arlen(i_arlen), .i_r_fire(i_r_fire), .i_rlast(i_rlast),
  .d_ar_fire(d_ar_fire), .d_arlen(d_arlen), .d_r_fire(d_r_fire), .d_rlast(d_rlast),
  .d_aw_fire(d_aw_fire), .d_w_fire(d_w_fire), .d_b_fire(d_b_fire),
  .protocol_fault(protocol_fault),
  `AXI_CONNECT_ALL(s,s)
 );

 integer errors = 0;
 integer i;
 reg [31:0] rd_val;
 reg [1:0] rd_resp;
 reg [1:0] wr_resp;

 task fail(input [1023:0] what, input [31:0] got, input [31:0] exp);
 begin
  errors = errors + 1;
  $display("FAIL %0s got=%08x exp=%08x", what, got, exp);
 end
 endtask

 task check(input [1023:0] what, input [31:0] got, input [31:0] exp);
 begin
  if (got !== exp) fail(what, got, exp);
  else $display("ok %0s = %08x", what, got);
 end
 endtask

 // Single-beat read of one register.
 task axi_read(input [31:0] addr);
 begin
  @(negedge clk);
  s_araddr = addr; s_arid = 4'd3; s_arlen = 8'd0; s_arsize = 3'd2;
  s_arburst = 2'd1; s_arlock = 1'b0; s_arcache = 4'd0; s_arprot = 3'd0;
  s_arqos = 4'd0; s_arvalid = 1'b1;
  @(posedge clk);                 // AR accepted
  @(negedge clk); s_arvalid = 1'b0;
  s_rready = 1'b1;
  while (!s_rvalid) @(negedge clk);
  rd_val = s_rdata; rd_resp = s_rresp;
  @(negedge clk); s_rready = 1'b0;
 end
 endtask

 // Single-beat write, returns the BRESP in wr_resp.
 task axi_write(input [31:0] addr, input [31:0] data, input [3:0] strb);
 begin
  @(negedge clk);
  s_awaddr = addr; s_awid = 4'd5; s_awlen = 8'd0; s_awsize = 3'd2;
  s_awburst = 2'd1; s_awlock = 1'b0; s_awcache = 4'd0; s_awprot = 3'd0;
  s_awqos = 4'd0; s_awvalid = 1'b1;
  s_wdata = data; s_wstrb = strb; s_wlast = 1'b1; s_wvalid = 1'b1;
  s_bready = 1'b1;
  while (!(s_awready && s_wready)) @(negedge clk);
  @(posedge clk);                 // AW and W accepted
  @(negedge clk); s_awvalid = 1'b0; s_wvalid = 1'b0;
  while (!s_bvalid) @(negedge clk);
  wr_resp = s_bresp;
  @(negedge clk); s_bready = 1'b0;
 end
 endtask

 // Holds the current tap values for exactly n counted clock edges.
 task tap_cycles(input integer n);
 integer k;
 begin
  for (k = 0; k < n; k = k + 1) @(posedge clk);
 end
 endtask

 task clear_taps;
 begin
  retire_fire = 1'b0; retire_inst = 32'h0000_0013; pred_miss = 1'b0;
  i_miss = 1'b0; d_miss = 1'b0; if_wait = 1'b0; lsu_wait = 1'b0;
  i_ar_fire = 1'b0; i_arlen = 8'd0; i_r_fire = 1'b0; i_rlast = 1'b0;
  d_ar_fire = 1'b0; d_arlen = 8'd0; d_r_fire = 1'b0; d_rlast = 1'b0;
  d_aw_fire = 1'b0; d_w_fire = 1'b0; d_b_fire = 1'b0;
 end
 endtask

 initial begin
  s_arvalid = 1'b0; s_araddr = 32'h0; s_arid = 4'd0; s_arlen = 8'd0;
  s_arsize = 3'd2; s_arburst = 2'd1; s_arlock = 1'b0; s_arcache = 4'd0;
  s_arprot = 3'd0; s_arqos = 4'd0;
  s_rready = 1'b0;
  s_awvalid = 1'b0; s_awaddr = 32'h0; s_awid = 4'd0; s_awlen = 8'd0;
  s_awsize = 3'd2; s_awburst = 2'd1; s_awlock = 1'b0; s_awcache = 4'd0;
  s_awprot = 3'd0; s_awqos = 4'd0;
  s_wvalid = 1'b0; s_wdata = 32'h0; s_wstrb = 4'h0; s_wlast = 1'b0;
  s_bready = 1'b0;
  clear_taps;

  rst_n = 1'b0;
  tap_cycles(4);
  rst_n = 1'b1;
  tap_cycles(2);

  // ---- P1: before any SNAP every read returns the (empty) snapshot bank ----
  axi_read(BASE + 32'h04);
  check("P1 STATUS value", rd_val, 32'd0);
  check("P1 STATUS resp", {30'd0, rd_resp}, 32'd0);
  axi_read(BASE + 32'h10);
  check("P1 CYCLE_LO before snap", rd_val, 32'd0);
  axi_read(BASE + 32'h50);
  check("P1 I_AR before snap", rd_val, 32'd0);

  // ---- P2: inject a known event mix, then snapshot it ----
  @(negedge clk); i_ar_fire = 1'b1; i_arlen = 8'd7;
  tap_cycles(3);
  @(negedge clk); i_arlen = 8'd0;
  tap_cycles(1);
  @(negedge clk); i_ar_fire = 1'b0;

  @(negedge clk); i_r_fire = 1'b1; i_rlast = 1'b0;
  tap_cycles(7);
  @(negedge clk); i_rlast = 1'b1;
  tap_cycles(1);
  @(negedge clk); i_rlast = 1'b0;
  tap_cycles(7);
  @(negedge clk); i_rlast = 1'b1;
  tap_cycles(1);
  @(negedge clk); i_r_fire = 1'b0; i_rlast = 1'b0;

  @(negedge clk); d_ar_fire = 1'b1; d_arlen = 8'd7;
  tap_cycles(2);
  @(negedge clk); d_ar_fire = 1'b0; d_arlen = 8'd0;
  @(negedge clk); d_r_fire = 1'b1;
  tap_cycles(16);
  @(negedge clk); d_rlast = 1'b1;
  tap_cycles(1);
  @(negedge clk); d_r_fire = 1'b0; d_rlast = 1'b0;
  @(negedge clk); d_aw_fire = 1'b1; d_w_fire = 1'b1; d_b_fire = 1'b1;
  tap_cycles(5);
  @(negedge clk); d_aw_fire = 1'b0; d_w_fire = 1'b0; d_b_fire = 1'b0;

  @(negedge clk); retire_fire = 1'b1; retire_inst = 32'h0000_0063;  // BEQ
  tap_cycles(3);
  @(negedge clk); retire_inst = 32'h0000_0013;                      // ADDI
  tap_cycles(1);
  @(negedge clk); retire_inst = 32'h0000_006f;                      // JAL
  tap_cycles(1);
  @(negedge clk); retire_inst = 32'h0000_0067;                      // JALR
  tap_cycles(1);
  @(negedge clk); retire_inst = 32'h0000_2063;                      // reserved funct3
  tap_cycles(1);
  @(negedge clk); retire_fire = 1'b0;

  @(negedge clk); i_miss = 1'b1; tap_cycles(2); @(negedge clk); i_miss = 1'b0;
  @(negedge clk); d_miss = 1'b1; tap_cycles(3); @(negedge clk); d_miss = 1'b0;
  @(negedge clk); if_wait = 1'b1; tap_cycles(5); @(negedge clk); if_wait = 1'b0;
  @(negedge clk); lsu_wait = 1'b1; tap_cycles(7); @(negedge clk); lsu_wait = 1'b0;
  @(negedge clk); pred_miss = 1'b1; tap_cycles(2); @(negedge clk); pred_miss = 1'b0;

  axi_write(BASE + 32'h00, 32'h0000_0001, 4'h1);   // SNAP
  check("P2 SNAP BRESP", {30'd0, wr_resp}, 32'd0);

  axi_read(BASE + 32'h04);
  check("P2 STATUS snapshot_valid", rd_val, 32'd1);
  axi_read(BASE + 32'h50);
  check("P2 I_AR", rd_val, 32'd4);
  axi_read(BASE + 32'h54);
  check("P2 I_AR_LEN7", rd_val, 32'd3);
  axi_read(BASE + 32'h58);
  check("P2 I_R_BEAT", rd_val, 32'd16);
  axi_read(BASE + 32'h5C);
  check("P2 I_R_LAST", rd_val, 32'd2);
  axi_read(BASE + 32'h60);
  check("P2 D_AR", rd_val, 32'd2);
  axi_read(BASE + 32'h64);
  check("P2 D_AR_LEN7", rd_val, 32'd2);
  axi_read(BASE + 32'h68);
  check("P2 D_R_BEAT", rd_val, 32'd16);
  axi_read(BASE + 32'h6C);
  check("P2 D_R_LAST", rd_val, 32'd1);
  axi_read(BASE + 32'h70);
  check("P2 D_AW", rd_val, 32'd5);
  axi_read(BASE + 32'h74);
  check("P2 D_W_BEAT", rd_val, 32'd5);
  axi_read(BASE + 32'h78);
  check("P2 D_B", rd_val, 32'd5);
  axi_read(BASE + 32'h18);
  check("P2 INSTRET", rd_val, 32'd7);
  axi_read(BASE + 32'h40);
  check("P2 RET_CF", rd_val, 32'd5);
  axi_read(BASE + 32'h30);
  check("P2 I_MISS", rd_val, 32'd2);
  axi_read(BASE + 32'h38);
  check("P2 D_MISS", rd_val, 32'd3);
  axi_read(BASE + 32'h20);
  check("P2 IF_WAIT", rd_val, 32'd5);
  axi_read(BASE + 32'h28);
  check("P2 LSU_WAIT", rd_val, 32'd7);
  axi_read(BASE + 32'h48);
  check("P2 MISPRED", rd_val, 32'd2);
  axi_read(BASE + 32'h14);
  check("P2 CYCLE_HI", rd_val, 32'd0);
  axi_read(BASE + 32'h10);
  if (rd_val === 32'd0) fail("P2 CYCLE_LO nonzero", rd_val, 32'd1);
  else $display("ok P2 CYCLE_LO = %08x", rd_val);

  // ---- P3: the snapshot is frozen while the live counters keep moving ----
  @(negedge clk); d_b_fire = 1'b1; i_ar_fire = 1'b1; i_arlen = 8'd7;
  tap_cycles(4);
  @(negedge clk); d_b_fire = 1'b0; i_ar_fire = 1'b0; i_arlen = 8'd0;
  axi_read(BASE + 32'h78);
  check("P3 D_B still frozen", rd_val, 32'd5);
  axi_read(BASE + 32'h54);
  check("P3 I_AR_LEN7 still frozen", rd_val, 32'd3);

  // ---- P4: CLEAR zeroes the live and the snapshot bank ----
  axi_write(BASE + 32'h00, 32'h0000_0002, 4'h1);   // CLEAR
  check("P4 CLEAR BRESP", {30'd0, wr_resp}, 32'd0);
  axi_read(BASE + 32'h04);
  check("P4 STATUS after clear", rd_val, 32'd0);
  axi_read(BASE + 32'h50);
  check("P4 I_AR after clear", rd_val, 32'd0);
  axi_read(BASE + 32'h10);
  check("P4 CYCLE_LO after clear", rd_val, 32'd0);
  axi_write(BASE + 32'h00, 32'h0000_0001, 4'h1);   // SNAP again
  axi_read(BASE + 32'h54);
  check("P4 I_AR_LEN7 after clear", rd_val, 32'd0);

  // ---- P5: decode errors answer SLVERR, legal accesses OKAY ----
  axi_read(BASE + 32'h80);
  check("P5 unimplemented read resp", {30'd0, rd_resp}, 32'd2);
  axi_read(BASE + 32'h1000);
  check("P5 outside window read resp", {30'd0, rd_resp}, 32'd2);
  axi_write(BASE + 32'h00, 32'h0000_0001, 4'h0);   // no WSTRB on byte 0
  check("P5 CTRL write without WSTRB resp", {30'd0, wr_resp}, 32'd2);
  axi_write(BASE + 32'h00, 32'h0000_0003, 4'h1);   // SNAP+CLEAR
  check("P5 SNAP+CLEAR resp", {30'd0, wr_resp}, 32'd2);
  axi_write(BASE + 32'h10, 32'h0000_0000, 4'hf);   // counter write
  check("P5 counter write resp", {30'd0, wr_resp}, 32'd2);
  axi_write(BASE + 32'h00, 32'h0000_0001, 4'h1);
  check("P5 SNAP resp", {30'd0, wr_resp}, 32'd0);
  axi_read(BASE + 32'h04);
  check("P5 STATUS resp", {30'd0, rd_resp}, 32'd0);
  check("P5 protocol_fault", {31'd0, protocol_fault}, 32'd0);

  if (errors == 0) $display("TEST_PASS PERF");
  else $display("TEST_FAIL PERF errors=%0d", errors);
  $finish;
 end

 initial begin
  #400000;
  $display("FAIL PERF timeout");
  $finish;
 end
endmodule
