`timescale 1ns/1ps
module tb_tilelink_uart_rx;
  reg clk = 0;
  reg reset = 1;
  reg a_valid = 0;
  reg d_ready = 0;
  reg [2:0] a_opcode = 0;
  reg [2:0] a_param = 0;
  reg [5:0] a_source = 0;
  reg [7:0] a_address = 0;
  reg [1:0] a_size = 2;
  reg [3:0] a_mask = 4'hf;
  reg [31:0] a_data = 0;
  reg a_corrupt = 0;
  wire a_ready, d_valid, d_denied, d_corrupt, uart_txd, interrupt;
  wire [2:0] d_opcode, d_param;
  wire [5:0] d_source;
  wire [1:0] d_size;
  wire [31:0] d_data;
  reg rxd = 1;
  integer bit_cycles = 864;
  integer i;

  always #5 clk = ~clk;

  TilelinkUartCtrl dut (
    .io_bus_a_valid(a_valid), .io_bus_a_ready(a_ready),
    .io_bus_a_payload_opcode(a_opcode), .io_bus_a_payload_param(a_param),
    .io_bus_a_payload_source(a_source), .io_bus_a_payload_address(a_address),
    .io_bus_a_payload_size(a_size), .io_bus_a_payload_mask(a_mask),
    .io_bus_a_payload_data(a_data), .io_bus_a_payload_corrupt(a_corrupt),
    .io_bus_d_valid(d_valid), .io_bus_d_ready(d_ready),
    .io_bus_d_payload_opcode(d_opcode), .io_bus_d_payload_param(d_param),
    .io_bus_d_payload_source(d_source), .io_bus_d_payload_size(d_size),
    .io_bus_d_payload_denied(d_denied), .io_bus_d_payload_data(d_data),
    .io_bus_d_payload_corrupt(d_corrupt), .io_uart_txd(uart_txd),
    .io_uart_rxd(rxd), .io_interrupt(interrupt),
    .socCtrl_systemClk(clk), .socCtrl_system_reset(reset)
  );

  task write_reg(input [7:0] address, input [31:0] value);
    begin
      @(negedge clk);
      a_address = address;
      a_data = value;
      a_opcode = 3'd0;
      a_valid = 1;
      do @(posedge clk); while (!a_ready);
      @(negedge clk);
      a_valid = 0;
      wait(d_valid);
      d_ready = 1;
      @(negedge clk);
      d_ready = 0;
    end
  endtask

  task read_reg(input [7:0] address, output [31:0] value);
    begin
      @(negedge clk);
      a_address = address;
      a_opcode = 3'd4;
      a_valid = 1;
      d_ready = 0;
      do @(posedge clk); while (!a_ready);
      @(negedge clk);
      a_valid = 0;
      wait(d_valid);
      value = d_data;
      d_ready = 1;
      @(negedge clk);
      d_ready = 0;
    end
  endtask

  task send_byte(input [7:0] value);
    integer k;
    begin
      @(negedge clk);
      rxd = 0;
      repeat (bit_cycles) @(negedge clk);
      for (k = 0; k < 8; k = k + 1) begin
        rxd = value[k];
        repeat (bit_cycles) @(negedge clk);
      end
      rxd = 1;
      repeat (bit_cycles) @(negedge clk);
    end
  endtask

  reg [31:0] value;
  initial begin
    if (!$value$plusargs("BIT_CYCLES=%d", bit_cycles))
      bit_cycles = 864;
    repeat (8) @(negedge clk);
    reset = 0;
    repeat (100) @(negedge clk);
    write_reg(8'h08, 32'd107);
    write_reg(8'h0c, 32'd7);
    send_byte(8'hA5);
    wait(dut.uartCtrl_1_io_read_queueWithOccupancy_io_occupancy != 0);
    read_reg(8'h00, value);
    $display("UART_BUS_READ value=%08x occupancy=%0d",
             value, dut.uartCtrl_1_io_read_queueWithOccupancy_io_occupancy);
    if (value[16] !== 1'b1 || value[7:0] !== 8'hA5)
      $fatal(1, "UART register read mismatch: %08x", value);
    $display("TILELINK_UART_RX_PASS bit_cycles=%0d", bit_cycles);
    $finish;
  end

  initial begin
    #1000000;
    $fatal(1, "UART wrapper timeout");
  end
endmodule
