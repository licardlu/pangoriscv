module pango_vexii_top(
  input wire clk, rst_n, key, uart_rx,
  output wire uart_tx, output wire [7:0] led
);
  wire core_clk, locked, reset;
  pango_pll u_core_pll(.clk(clk), .rst_n(rst_n), .core_clk(core_clk), .locked(locked));
  pango_reset u_reset(.clk(core_clk), .rst_n(rst_n), .locked(locked), .reset(reset));
  MicroSoc u_soc(.socCtrl_systemClk(core_clk), .socCtrl_asyncReset(reset),
    .system_peripheral_uart_logic_uart_txd(uart_tx), .system_peripheral_uart_logic_uart_rxd(uart_rx),
    .system_peripheral_demo_logic_leds(led), .system_peripheral_demo_logic_buttons(!key));
endmodule
