`timescale 1ns/1ps
module tb_shift_program;
  reg clk=0, reset=1;
  always #4.1507024265 clk=~clk;
  wire tx; wire [7:0] leds;
  MicroSoc dut(.socCtrl_systemClk(clk),.socCtrl_asyncReset(reset),
    .system_peripheral_uart_logic_uart_txd(tx),.system_peripheral_uart_logic_uart_rxd(1'b1),
    .system_peripheral_demo_logic_leds(leds),.system_peripheral_demo_logic_buttons(1'b0));
  initial begin repeat(20) @(negedge clk);reset=0;end
  integer cycles=0;
  always @(negedge clk) if(!reset) begin
    cycles=cycles+1;
    if(leds==8'hee) $fatal(1,"shift program mismatch");
    if(leds==8'ha5) begin $display("TEST_PASS shift_program cycles=%0d",cycles);$finish;end
    if(cycles>500000) $fatal(1,"TIMEOUT shift program");
  end
endmodule
