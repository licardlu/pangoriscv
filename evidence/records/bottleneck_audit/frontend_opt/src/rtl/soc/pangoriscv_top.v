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
 // KEY0 asserts reset asynchronously. Every endpoint sees the same release.
 // Hold KEY0 during initial board bring-up; no power-on value is assumed.
 // The Synopsys/Pango attribute ASYNC_REG is not a legal attribute for Pango
 // ADS (compile log: "W: Sdm-2008: The attribute named ASYNC_REG is not legal,
 // then it has no effect, ignore its value"), and this board wrapper has a
 // single clock domain, so the synchronizer is kept structural instead:
 // syn_preserve is a documented Pango directive that stops sequential
 // optimization from folding the constant-1 stage away.
 reg [1:0] reset_sync /* synthesis syn_preserve = 1 */;
 always @(posedge clk or negedge rst_n) begin
  if (!rst_n) reset_sync<=2'b00;
  else reset_sync<={reset_sync[0],1'b1};
 end
 wire soc_rst_n=reset_sync[1];
 wire [31:0] gpio_ctrl,gpio_data;
 genvar i;
 generate for (i=0;i<8;i=i+1) begin : board_led
  assign led[i]=soc_rst_n && gpio_ctrl[2*i+:2]==2'b01 && gpio_data[i];
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
 always @(posedge clk) begin
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
  .clk(clk),.rst_n(soc_rst_n),
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
