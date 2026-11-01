`timescale 1ns/1ps
module tb_gate_smoke;
  reg clk=0, reset=1;
  reg grs_n=0;
  always #4.1507024265 clk=~clk;
  initial begin #100;grs_n=1;repeat(20)@(negedge clk);reset=0;end
  GTP_GRS GRS_INST(.GRS_N(grs_n));
  wire reference_tx,replica_tx;
  wire [7:0] reference_led,replica_led;
  MicroSoc reference_dut(.socCtrl_systemClk(clk),.socCtrl_asyncReset(reset),
    .system_peripheral_uart_logic_uart_txd(reference_tx),.system_peripheral_uart_logic_uart_rxd(1'b1),
    .system_peripheral_demo_logic_leds(reference_led),.system_peripheral_demo_logic_buttons(1'b0));
  MicroSoc replica_dut(.socCtrl_systemClk(clk),.socCtrl_asyncReset(reset),
    .system_peripheral_uart_logic_uart_txd(replica_tx),.system_peripheral_uart_logic_uart_rxd(1'b1),
    .system_peripheral_demo_logic_leds(replica_led),.system_peripheral_demo_logic_buttons(1'b0));
  integer cycles=0,edges=0,max_cycles=200000;
  initial if($value$plusargs("MAX_CYCLES=%d",max_cycles))begin end
  always @(negedge replica_tx)edges=edges+1;
  always @(negedge clk)begin
    cycles=cycles+1;
    if(cycles>100 && {reference_tx,reference_led} !== {replica_tx,replica_led})
      $fatal(1,"post-synthesis SoC output mismatch cycle=%d reference=%h got=%h",cycles,{reference_tx,reference_led},{replica_tx,replica_led});
    if(cycles%50000==0)$display("GATE_PROGRESS cycles=%d uart_edges=%d",cycles,edges);
    if(cycles==max_cycles)begin
      if(edges<10)$fatal(1,"No UART activity from synthesized netlist");
      $display("TEST_PASS gate_external_lockstep cycles=%d uart_edges=%d",cycles,edges);
      $finish;
    end
  end
endmodule
config gate_smoke_config;
  design work.tb_gate_smoke;
  default liblist work pango;
  instance tb_gate_smoke.reference_dut liblist reference;
  instance tb_gate_smoke.replica_dut liblist gate pango;
endconfig
