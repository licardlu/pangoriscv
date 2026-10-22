//=============================================================================
// pangoriscv - RV32IM processor core + native AXI4 SoC (Pango PG2L100H @ 27 MHz)
// Module : pangoriscv_top         File : rtl/soc/pangoriscv_top.v
// Rev    : 1.0                    Date : 2026-10-13
// Author : pango_lpenghan
// Brief  : FPGA top level: clock, reset, pins, BRAM init, ILA observation points
//=============================================================================

module pangoriscv_top #(
 parameter PROGRAM_INIT_FILE="program.hex",
 parameter DATA_INIT_FILE="data.hex"
)(
 input wire clk,
 input wire rst_n,
 input wire key,
 input wire uart_rx,
 output wire uart_tx,
 output wire [7:0] led
);
 // PG2L100H PPLL legal range: VCO 1330..2133 MHz, PFD >=19 MHz.
 // 27 * 56 = 1512 MHz VCO; /42 = 36 MHz core clock.  THIS IS THE DELIVERY SETTING:
 // it must stay equal to the bitstream in bitstream/ (pangoriscv_board36_i2000.sbit).
 //
 // If you are about to change this to chase a higher frequency, read plan v10
 // section 9 first.  Measured 2026-10-22: placement closes at 45 MHz (+1.30 ns at
 // 22.22 ns) and at 50 MHz (+1.04 ns at 20 ns), but DETAILED ROUTING does not
 // converge at either -- unrouted nets fall monotonically and then flatten around
 // 9-11 k (18,470@5 -> 10,369@21 -> 9,237@26 for 45 MHz), the congestion
 // fingerprint of mistakes-log 48, at ~40-90 s per iteration.  36 MHz still routes
 // in ~285 iterations.  So 36 MHz is the highest *routable* point found so far,
 // not the highest timing point.  Reverting the PLL here keeps the repo able to
 // reproduce the delivered bitstream -- do not leave it at an unrouted frequency.
 //
 // Exact-integer-MHz PLL family for future attempts (VCO = 27*F must be in range):
 //   45.000 = 27*50/30, 50.000 = 27*50/27, 42.000 = 27*56/36.
 //   120.000 is NOT reachable (needs F/M = 40/9 -> VCO 1080 or 2160, both illegal).
 // Analysis builds only: STATIC_RATIO0(12)/STATIC_DUTY0(12) = 126 MHz.
 // Use the same clock for CPU, fabric, peripherals and observation counters.
 wire core_clk,pll_locked;
 GTP_PPLL #(
  .CLKIN_FREQ(27.0),.LOCK_MODE(0),
  .STATIC_RATIOI(1),.STATIC_RATIOM(1),.STATIC_RATIOF(56),
  .STATIC_RATIO0(42),.STATIC_DUTY0(42),.STATIC_DUTYF(56),
  .STATIC_RATIO1(56),.STATIC_DUTY1(56),
  .STATIC_RATIO2(56),.STATIC_DUTY2(56),
  .STATIC_RATIO3(56),.STATIC_DUTY3(56),
  .STATIC_RATIO4(56),.STATIC_DUTY4(56),
  .STATIC_RATIOPHY(56),.STATIC_DUTYPHY(56),
  .INTERNAL_FB("CLKOUTF"),.EXTERNAL_FB("DISABLE"),.BANDWIDTH("OPTIMIZED")
 ) u_core_pll(
  .CLKIN1(clk),.CLKIN2(1'b0),.CLKIN_SEL(1'b0),.CLKFB(1'b0),
  .CLKOUT0(core_clk),.LOCK(pll_locked),.RST(!rst_n),.PLL_PWD(1'b0),
  .CLKOUT0_SYN(1'b0),.CLKOUT1_SYN(1'b0),.CLKOUT2_SYN(1'b0),
  .CLKOUT3_SYN(1'b0),.CLKOUT4_SYN(1'b0),.CLKOUTPHY_SYN(1'b0),.CLKOUTF_SYN(1'b0),
  .APB_CLK(1'b0),.APB_RST_N(1'b0),.APB_ADDR(5'd0),
  .APB_SEL(1'b0),.APB_EN(1'b0),.APB_WRITE(1'b0),.APB_WDATA(16'd0)
 );
 wire reset_release=rst_n && pll_locked;
 // KEY0 asserts reset asynchronously. Every endpoint sees the same release.
 // Hold KEY0 during initial board bring-up; no power-on value is assumed.
 // The Synopsys/Pango attribute ASYNC_REG is not a legal attribute for Pango
 // ADS (compile log: "W: Sdm-2008: The attribute named ASYNC_REG is not legal,
 // then it has no effect, ignore its value"), and this board wrapper has a
 // single clock domain, so the synchronizer is kept structural instead:
 // syn_preserve is a documented Pango directive that stops sequential
 // optimization from folding the constant-1 stage away.
 reg [1:0] reset_sync /* synthesis syn_preserve = 1 */;
 always @(posedge core_clk or negedge reset_release) begin
  if (!reset_release) reset_sync<=2'b00;
  else reset_sync<={reset_sync[0],1'b1};
 end
 wire soc_rst_n=reset_sync[1];
 wire [31:0] gpio_ctrl,gpio_data;
 genvar i;
 generate for (i=0;i<8;i=i+1) begin : board_led
  // No soc_rst_n term: gpio_ctrl/gpio_data are reset to 0 by axi_gpio, so the pin
  // is already low during reset, and the redundant gate only added a
  // reset_sync -> led path that kept showing up as a marginal IO hold
  // (docs/plan-efficiency.md section 10).
  assign led[i]=gpio_ctrl[2*i+:2]==2'b01 && gpio_data[i];
 end endgenerate

 // ---------------------------------------------------------------------
 // On-chip logic analyzer observation points.
 //
 // The board pinout is fixed, so the architecture-internal events needed for
 // the contest's "ILA waveform of CoreMark key algorithms" evidence are kept
 // as named internal nets instead of new top-level pins. PDS instruments
 // internal nets by name, so the nets must survive optimization.
 //
 // Do NOT use the attribute form `(* keep = "true" *)` here. Pango ADS
 // translates it to PAP_KEEP and then rejects the value (compile log:
 // "I: Convert attribute name from keep to PAP_KEEP" followed by
 // "W: The value of attribute PAP_KEEP is invalid, ignore it"), and a first
 // implementation with that form dropped every net except 4 of them from
 // synthesize/pangoriscv_top_syn.vm. The documented Synplify directives are
 // the comment pragmas below (see syn/doc/fpga_attribute_reference.pdf):
 //   syn_keep      - preserves a combinational net as a keep buffer
 //   syn_preserve  - prevents sequential optimization of a register
 // The probe list and the trigger recipe are in platform/pango_native/README.md.
 // ---------------------------------------------------------------------
 wire        obs_retire_fire      /* synthesis syn_keep = 1 */;
 wire [63:0] obs_retire_order     /* synthesis syn_keep = 1 */;
 wire [31:0] obs_retire_pc        /* synthesis syn_keep = 1 */;
 wire [31:0] obs_retire_inst      /* synthesis syn_keep = 1 */;
 wire        obs_rd_valid         /* synthesis syn_keep = 1 */;
 wire [4:0]  obs_rd               /* synthesis syn_keep = 1 */;
 wire [31:0] obs_wdata            /* synthesis syn_keep = 1 */;
 wire        obs_trap_fire        /* synthesis syn_keep = 1 */;
 wire [31:0] obs_trap_cause       /* synthesis syn_keep = 1 */;
 wire [31:0] obs_trap_pc          /* synthesis syn_keep = 1 */;
 wire [31:0] obs_trap_tval        /* synthesis syn_keep = 1 */;
 wire        obs_halted           /* synthesis syn_keep = 1 */;
 wire [31:0] obs_arch_next_pc     /* synthesis syn_keep = 1 */;
 wire        obs_protocol_fault   /* synthesis syn_keep = 1 */;
 wire [31:0] obs_csr_mtvec        /* synthesis syn_keep = 1 */;
 wire [31:0] obs_uart_tx          /* synthesis syn_keep = 1 */;
 // Free-running activity counters: cheap ILA trigger/qualifier conditions.
 // These are dead-end registers, so they need syn_preserve as well.
 reg [31:0] obs_retire_count /* synthesis syn_keep = 1, syn_preserve = 1 */;
 reg [31:0] obs_trap_count   /* synthesis syn_keep = 1, syn_preserve = 1 */;
 always @(posedge core_clk) begin
  if(!soc_rst_n) begin
   obs_retire_count<=32'd0;
   obs_trap_count<=32'd0;
  end else begin
   if(obs_retire_fire) obs_retire_count<=obs_retire_count+32'd1;
   if(obs_trap_fire)   obs_trap_count<=obs_trap_count+32'd1;
  end
 end

 pangoriscv_axi_soc #(
  .PROGRAM_INIT_FILE(PROGRAM_INIT_FILE),.DATA_INIT_FILE(DATA_INIT_FILE)
 ) soc(
  .clk(core_clk),.rst_n(soc_rst_n),
  .uart_rx(uart_rx),.uart_tx(uart_tx),
  .gpio_input({1'b1,key}),.gpio_ctrl(gpio_ctrl),.gpio_data(gpio_data),
  .spi_miso(1'b1),.spi_mosi(),.spi_ss(),.spi_clk(),
  // IRQ controller synchronizes inputs. KEY1 press is rising event bit 0.
  .ext_event({1'b0,~key}),
  .halt_req(1'b0),.halted(obs_halted),.arch_next_pc(obs_arch_next_pc),
  .trap_ready(1'b1),.trap_vector(32'b0),
  .irq_software(1'b0),.irq_timer(1'b0),.irq_external(1'b0),.csr_mtvec(obs_csr_mtvec),
  .trap_fire(obs_trap_fire),.trap_cause(obs_trap_cause),
  .trap_pc(obs_trap_pc),.trap_tval(obs_trap_tval),
  .retire_fire(obs_retire_fire),.retire_order(obs_retire_order),
  .retire_pc(obs_retire_pc),.retire_inst(obs_retire_inst),
  .rd_valid(obs_rd_valid),.rd(obs_rd),.wdata(obs_wdata),
  .debug_addr(5'b0),.debug_data(),.protocol_fault(obs_protocol_fault)
 );
 assign obs_uart_tx=uart_tx;
endmodule
