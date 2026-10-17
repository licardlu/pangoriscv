//=============================================================================
// tb_uart_run - minimal harness: run one bare metal image in the AXI SoC and
//               capture everything the program prints on the UART.
//
// It only observes the top level ports (clk / rst_n / uart_tx), so it works with
// any build configuration of the RTL and never touches internal signals.
//
// Plusargs: +PROG=<hex> +DATA=<hex> +MAX_CYCLES=<n> [+STOP="<text>"]
//=============================================================================
`timescale 1ns/1ps

module tb_uart_run;

  reg clk = 1'b0;
  reg rst_n = 1'b0;

  initial begin
    #200 rst_n = 1'b1;
  end

  always #18.518 clk = ~clk;           // ~27 MHz

  // ---- device under test ---------------------------------------------------
  wire uart_tx;
  wire [31:0] gpio_ctrl, gpio_data;
  wire spi_mosi, spi_ss, spi_clk;

  pangoriscv_axi_soc soc (
      .clk       (clk),
      .rst_n     (rst_n),
      .uart_rx   (1'b1),
      .uart_tx   (uart_tx),
      .gpio_input(2'b00),
      .gpio_ctrl (gpio_ctrl),
      .gpio_data (gpio_data),
      .spi_miso  (1'b0),
      .spi_mosi  (spi_mosi),
      .spi_ss    (spi_ss),
      .spi_clk   (spi_clk),
      .ext_event (2'b00),
      .halt_req  (1'b0)
  );

  // ---- image ---------------------------------------------------------------
  reg [1023:0] prog_path, data_path, stop_path;
  integer max_cycles;
  reg [8*128-1:0] stop_text;

  initial begin
    if (!$value$plusargs("PROG=%s", prog_path)) begin
      $display("FATAL no +PROG");
      $finish;
    end
    if (!$value$plusargs("DATA=%s", data_path)) begin
      $display("FATAL no +DATA");
      $finish;
    end
    if (!$value$plusargs("MAX_CYCLES=%d", max_cycles)) max_cycles = 2000000;
    if (!$value$plusargs("STOP=%s", stop_text)) stop_text = "done";
    $readmemh(prog_path, soc.program_ram.mem);
    $readmemh(data_path, soc.data_ram.mem);
    $display("TB image prog=%0s data=%0s max_cycles=%0d", prog_path, data_path, max_cycles);
  end

  // ---- UART receiver (8N1, divider 234) ------------------------------------
  localparam integer BAUD_DIV = 234;   // 27 MHz / 234 = 115384 Bd

  integer bit_cnt = 0;
  integer baud_cnt = 0;
  reg [7:0] rx_byte = 8'h00;
  reg rx_busy = 1'b0;
  reg uart_tx_q = 1'b1;

  integer nchars = 0;
  reg [7:0] text [0:65535];
  integer cycles = 0;
  reg seen_stop = 1'b0;

  always @(posedge clk) begin
    cycles <= cycles + 1;

    uart_tx_q <= uart_tx;

    if (!rx_busy) begin
      if (uart_tx_q && !uart_tx) begin    // start bit edge
        rx_busy  <= 1'b1;
        baud_cnt <= BAUD_DIV + BAUD_DIV / 2;  // 1.5 bit times: middle of data bit 0
        bit_cnt  <= 0;
      end
    end else begin
      if (baud_cnt == 0) begin
        baud_cnt <= BAUD_DIV - 1;
        if (bit_cnt < 8) begin
          rx_byte[bit_cnt] <= uart_tx;
          bit_cnt <= bit_cnt + 1;
        end else begin
          rx_busy <= 1'b0;                // stop bit
          text[nchars] <= rx_byte;
          nchars <= nchars + 1;
          if (rx_byte == 8'h0a) begin
            $write("%c", rx_byte);
          end else begin
            $write("%c", rx_byte);
          end
        end
      end else begin
        baud_cnt <= baud_cnt - 1;
      end
    end

    if (cycles >= max_cycles) begin
      $display("\nTB TIMEOUT after %0d cycles, %0d chars", cycles, nchars);
      dump_text(nchars);
      $finish;
    end
  end

  // ---- dump whatever the program printed ----------------------------------
  task dump_text(input integer n);
    integer i, row;
    begin
      $display("----- UART TEXT BEGIN (%0d chars) -----", n);
      $write("         ");
      for (i = 0; i < n; i = i + 1) begin
        if (text[i] >= 8'h20 && text[i] < 8'h7f) $write("%c", text[i]);
        else $write(".");
      end
      $display("");
      for (row = 0; row < (n + 15) / 16; row = row + 1) begin
        $write("  %04d:", row * 16);
        for (i = row * 16; i < (row + 1) * 16 && i < n; i = i + 1)
          $write(" %02x", text[i]);
        $display("");
      end
      $display("----- UART TEXT END -----");
    end
  endtask

endmodule