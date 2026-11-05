`timescale 1ns/1ps
module tb_uart_rx_rate;
  reg clk = 0;
  reg reset = 1;
  reg rxd = 1;
  wire txd;
  wire read_valid;
  wire [7:0] read_payload;
  reg read_ready = 0;
  wire read_error;
  wire read_break;
  integer cycles = 0;
  integer got = 0;
  integer bit_cycles = 864;

  always #5 clk = ~clk;
  always @(posedge clk) begin
    cycles <= cycles + 1;
    if (read_valid) begin
      $display("RX_VALID cycle=%0d data=%02x error=%b", cycles,
               read_payload, read_error);
      if (read_payload !== 8'hA5)
        $fatal(1, "UART payload mismatch: %h", read_payload);
      got <= got + 1;
    end
  end

  UartCtrl dut (
    .io_config_frame_dataLength(3'd7),
    .io_config_frame_stop(1'b0),
    .io_config_frame_parity(2'd0),
    .io_config_clockDivider(20'd107),
    .io_write_valid(1'b0),
    .io_write_ready(),
    .io_write_payload(8'd0),
    .io_read_valid(read_valid),
    .io_read_ready(read_ready),
    .io_read_payload(read_payload),
    .io_uart_txd(txd),
    .io_uart_rxd(rxd),
    .io_readError(read_error),
    .io_writeBreak(1'b0),
    .io_readBreak(read_break),
    .socCtrl_systemClk(clk),
    .socCtrl_system_reset(reset)
  );

  task send_byte(input [7:0] value);
    integer k;
    begin
      @(negedge clk);
      rxd = 1'b0;
      repeat (bit_cycles) @(negedge clk);
      for (k = 0; k < 8; k = k + 1) begin
        rxd = value[k];
        repeat (bit_cycles) @(negedge clk);
      end
      rxd = 1'b1;
      repeat (bit_cycles) @(negedge clk);
    end
  endtask

  initial begin
    if (!$value$plusargs("BIT_CYCLES=%d", bit_cycles))
      bit_cycles = 864;
    repeat (8) @(negedge clk);
    reset = 0;
    repeat (1000) @(negedge clk);
    send_byte(8'hA5);
    repeat (2000) @(negedge clk);
    if (got != 1)
      $fatal(1, "UART byte not received, got=%0d", got);
    $display("UART_RX_RATE_PASS bit_cycles=%0d", bit_cycles);
    $finish;
  end
endmodule
