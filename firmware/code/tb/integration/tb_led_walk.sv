//=============================================================================
// pangoriscv - RV32IM processor core + native AXI4 SoC (Pango PG2L100H @ 27 MHz)
// Module : tb_led_walk            File : tb/integration/tb_led_walk.sv
// Rev    : 1.0                    Date : 2026-10-13
// Author : pango_lpenghan
// Brief  : Pre-board check of the led_walk firmware: one-hot LED walk and UART output
//=============================================================================

// Pre-board verification of the led_walk firmware on the "pangoriscv AXI4" native SoC.
//
// WHAT IS PROVED
//   1. The eight board LEDs really walk one-hot (0x01,0x02,...,0x80 and repeat) when the
//      firmware stores to GPIO DATA, using the exact board LED equation from
//      rtl/soc/pangoriscv_top.v:29  led[i] = gpio_ctrl[2*i +: 2]==2'b01 && gpio_data[i].
//   2. The firmware's UART banner is really transmitted, decoded 8N1 from uart_tx.
//
// IMAGE UNDER TEST (simulation build, 1 ms LED step period - see the STEP_TICKS comment
// in tests/example/led_walk/main.c):
//   build/native_software/led_walk/validation/program.hex  -> program RAM (0x00000000)
//   build/native_software/led_walk/validation/data.hex     -> data RAM    (0x10000000)
// Both are loaded by rtl/perips/axi_ram.v through $readmemh at time 0, so the paths below
// MUST be absolute (the work library lives outside the repository).
//
// BOARD WRAPPER CONDITIONS MIRRORED (rtl/soc/pangoriscv_top.v)
//   uart_rx  = 1 (idle)          spi_miso = 1 (idle)
//   gpio_input = {1'b1, key}     key = 1 (released); a KEY press is a board reset event
//   ext_event  = {1'b0, ~key}    = 0 while the key is released
//   The SoC reset is driven directly: the top-level reset synchronizer in the board
//   wrapper is not part of the DUT, so rst_n is released after 10 clocks instead.
//
// CLOCK: 37.037 ns period = 27.000 MHz. Do NOT shorten it. The firmware's step period is
//   STEP_TICKS = CPU_FREQ_HZ/1000+1 = 27001 timer ticks and the UART divider is
//   27e6/115200 = 234 (both axi_uart's reset value and the value tests/example/lib/uart.c
//   writes). Speeding the clock up would break both the ms time base and the decoded text.
//
// TIME UNITS: every observer prints `%0d` of $time, never `%t`. With `timescale 1ns/1ps`
//   $time is the module time (ns), but Questa/ModelSim formats `%t` in the simulator's
//   minimum resolution (1 ps), i.e. 1000x the ns value, so a "t=... ns" label fed from %t
//   would be wrong by a factor of 1000. Cross-check available in the transcript: the cycle
//   counter is incremented per 37.037 ns clock, and t/37.037 must equal it.
//
// NO $dumpvars: the deliverable is this text transcript.
`timescale 1ns/1ps
module tb_led_walk;

    // ---- board clock / time base -------------------------------------------------
    localparam real CLK_PERIOD_NS = 37.037;      // 27 MHz
    localparam real F_CPU_HZ      = 27000000.0;
    localparam integer BAUD_DIV   = 234;         // 27e6/115200 -> 234 (a real cell is 235 clocks = 8.704 us; see the UART observer)
    localparam integer STOP_LED_CHANGES = 10;    // >= one full 8-step cycle
    // The images are the SIMULATION build: STEP_TICKS = 27e6/1000+1 = 27001 timer
    // ticks = 1.00004 ms per step, and the banner (58 chars at 115200 baud) ends at
    // ~5.29 ms. Measured LED changes: 0x01 at 5.216 ms, then one every ~1.0004 ms, so
    // #8 (0x80) is at 12.244 ms.
    //
    // main.c prints its per-cycle line AFTER the 8th step and BEFORE the next store:
    //   GPIO_DATA = 1<<led; delay; led++; if (led==8) { led=0; xprintf(...); }
    // so the 9th change (the wrap back to 0x01) cannot happen until that 44-byte line
    // ("led_walk: pangoriscv native AXI4 CPU, step 8\n") has been shifted out:
    //   12.244 + 1.000 (delay) + ~0.008 (xprintf) = 13.25 ms first byte,
    //   + 43 more byte cells * 0.086783 ms = 17.08 ms last byte
    //   => 0x01 at ~17.08 ms, 0x02 (the 10th change) at ~18.08 ms.
    // A 14.6 ms cap stopped the FIRST run 8 changes in, which was the tb's fault, not
    // the firmware's. The cap below is set above the 10th change; that 10th change
    // (0x02, i.e. repeat after the 0x80 -> 0x01 wrap) is the normal stop.
    // 20 ms hard cap, measured against the 1 ms/step image this TB is written for.
    // `parameter` so it can be tightened from the command line with
    //   vsim -c -gSTOP_TIME_NS=20000000.0 work.tb_led_walk
    // NOTE: overriding the wide string parameter below with -gIMG_DIR=... does NOT
    // work in ModelSim 2020.4 (it arrives as an empty string and $readmemh then fails
    // with `Failed to open readmem file ".hex"`). To exercise a different image,
    // build that variant into the hardcoded directory instead:
    //   python tools/build_native_software.py led_walk --mode validation --tag <t> \
    //       --define LED_WALK_STEP_MS=1 --toolchain-bin <riscv gcc bin>
    // and copy <t>/program.hex + <t>/data.hex over the two files in IMG_DIR
    // (the 250 ms board image rebuilds byte-identically from the same source).
    parameter real     STOP_TIME_NS     = 20000000.0; // 20 ms hard cap

    reg clk = 0;
    always #(CLK_PERIOD_NS/2.0) clk = ~clk;

    reg rst_n = 0;
    reg uart_rx = 1, spi_miso = 1;
    reg [1:0] key = 2'b11;                       // released (active-low KEY0/KEY1)

    // ---- observation nets --------------------------------------------------------
    wire uart_tx, spi_mosi, spi_ss, spi_clk;
    wire [31:0] gpio_ctrl, gpio_data;
    wire halt_req = 0, trap_ready = 1, irq_software = 0, irq_timer = 0, irq_external = 0;
    wire [4:0] debug_addr = 5'b0;
    wire halted;
    wire [31:0] arch_next_pc, trap_cause, trap_pc, trap_tval, csr_mtvec;
    wire trap_fire, retire_fire, rd_valid, protocol_fault;
    wire [63:0] retire_order;
    wire [31:0] retire_pc, retire_inst, wdata, debug_data;
    wire [4:0] rd;

    // IMG_DIR is relative to the directory the simulator is started in: run it from
    // this package root, after building the image with
    //   python tools/build_native_software.py led_walk
    // which writes build/native_software/led_walk/validation/{program,data}.hex .
    // Give the literal a full 1024 bits (128 characters): a narrow localparam silently
    // TRUNCATES a string literal, and $readmemh then fails with vsim-7.
    parameter [1023:0] IMG_DIR =
        "build/native_software/led_walk/validation/";

    pangoriscv_axi_soc #(
        .PROGRAM_INIT_FILE({IMG_DIR,"program.hex"}),
        .DATA_INIT_FILE   ({IMG_DIR,"data.hex"}),
        .READ_DELAY(0),
        .WRITE_DELAY(0)
    ) soc (
        .clk(clk), .rst_n(rst_n),
        .uart_rx(uart_rx), .uart_tx(uart_tx),
        .gpio_input(key), .gpio_ctrl(gpio_ctrl), .gpio_data(gpio_data),
        .spi_miso(spi_miso), .spi_mosi(spi_mosi), .spi_ss(spi_ss), .spi_clk(spi_clk),
        .ext_event({1'b0, ~key[0]}),
        .halt_req(halt_req), .halted(halted), .arch_next_pc(arch_next_pc),
        .trap_ready(trap_ready), .trap_vector(32'b0),
        .irq_software(irq_software), .irq_timer(irq_timer), .irq_external(irq_external),
        .csr_mtvec(csr_mtvec),
        .trap_fire(trap_fire), .trap_cause(trap_cause), .trap_pc(trap_pc),
        .trap_tval(trap_tval), .retire_fire(retire_fire), .retire_order(retire_order),
        .retire_pc(retire_pc), .retire_inst(retire_inst), .rd_valid(rd_valid),
        .rd(rd), .wdata(wdata), .debug_addr(debug_addr), .debug_data(debug_data),
        .protocol_fault(protocol_fault));

    // ---- run-time bookkeeping ----------------------------------------------------
    integer cycles = 0;
    integer led_changes = 0;
    integer chars = 0;
    reg started = 0;                             // set when rst_n is released
    always @(posedge clk) if (rst_n) cycles = cycles + 1;

    // ---- stall diagnostics -------------------------------------------------------
    // If the expected next LED change does not arrive, these show whether the core is
    // still retiring instructions and where it is spinning, or whether it trapped.
    integer retire_count = 0;
    reg [31:0] last_retire_pc = 32'h0;
    always @(posedge clk) if (retire_fire) begin
        retire_count = retire_count + 1;
        last_retire_pc = retire_pc;
    end
    always @(posedge clk) if (trap_fire && rst_n)
        $display("[TRAP] t=%0d ns (%0.4f ms) cause=0x%08x pc=0x%08x tval=0x%08x mtvec=0x%08x",
                 $time, $time/1000000.0, trap_cause, trap_pc, trap_tval, csr_mtvec);

    integer hb_ms = 0;
    initial begin
        @(posedge rst_n);
        forever begin
            #1000000;                                  // 1 ms of simulated time
            hb_ms = hb_ms + 1;
            $display("[HB] t=%0d ns (%0d ms) cycles=%0d retires=%0d last_pc=0x%08x next_pc=0x%08x halted=%b ctrl=0x%08x data=0x%08x led=0x%02x",
                     $time, hb_ms, cycles, retire_count, last_retire_pc, arch_next_pc,
                     halted, gpio_ctrl, gpio_data, led);
        end
    end

    // ---- LED observer: the byte the board LEDs would show ------------------------
    // rtl/soc/pangoriscv_top.v:29, with soc_rst_n = 1 after reset release here.
    wire [7:0] led;
    genvar gi;
    generate for (gi = 0; gi < 8; gi = gi + 1) begin : g_led
        assign led[gi] = rst_n && (gpio_ctrl[2*gi +: 2] == 2'b01) && gpio_data[gi];
    end endgenerate

    task automatic show_led(input [8*24-1:0] tag);
        begin
            $display("[LED] t=%0d ns (%0.4f ms, %0d cycles) ctrl=0x%08x data=0x%08x led=0x%02x  %0s",
                     $time, $time/1000000.0, cycles, gpio_ctrl, gpio_data, led, tag);
        end
    endtask

    reg [7:0] led_prev = 8'h00;
    reg [31:0] ctrl_prev = 32'hxxxxxxxx;
    always @(led or gpio_ctrl or gpio_data) begin
        if (led !== led_prev) begin
            led_prev = led;
            led_changes = led_changes + 1;
            show_led("LED_CHANGE");
            if (led_changes >= STOP_LED_CHANGES && started) begin
                $display("[STOP] %0d LED changes observed at t=%0d ns (%0.4f ms)",
                         led_changes, $time, $time/1000000.0);
                $finish;
            end
        end else if (gpio_ctrl !== ctrl_prev) begin
            ctrl_prev = gpio_ctrl;
            show_led("CTRL_ONLY");
        end
    end

    // ---- UART TX observer --------------------------------------------------------
    // ASSUMPTION: 8N1, no parity, 1 stop bit, LSB first.
    // BIT CELL (from rtl/perips/axi_uart.v:88-103): the TX state machine bumps
    // cycle_cnt every clock and acts when cycle_cnt == uart_baud[15:0], so a cell is
    // uart_baud[15:0] + 1 = 235 clocks = 8704 ns. uart_baud = 234 at reset
    // (axi_uart.v:30, comment: "27e6/115200 = 234.375 -> 234") and lib/uart.c writes the
    // same 234. Confirmed by measurement, not just by reading: consecutive edges of a
    // transmitted byte in the transcript are 8704 ns apart = 235.008 clocks.
    //
    // THE DECODER BELOW DELIBERATELY RUNS ONE CLOCK SHORT: it re-arms for BAUD_DIV = 234
    // clocks per cell rather than 235. It samples from the detected falling edge, so the
    // error accumulates to 9 clocks = 333 ns by the stop bit, against an 8704 ns cell
    // (3.8% of a cell) - harmless. Evidence that it is harmless: 102 bytes decoded with
    // zero start/stop-bit warnings, and the assembled ASCII lines read as real text.
    //
    // Do NOT read the byte-to-byte spacing as a bit cell: consecutive bytes are 2391
    // clocks apart = 10 cells + a ~41-clock gap, because the firmware polls tx ready and
    // issues a fresh AXI store between bytes. The gap is firmware behaviour, not baud.
    // Sample-and-hold from a mid-cell start would tolerate a much larger error than this.
    localparam integer BAUD_HALF = 117;          // half a cell, in clocks

    reg       txq = 1;
    reg       dbusy = 0;
    integer   dcount = 0;
    integer   dbit = 0;                          // 0=start cell, 1..8=data, 9=stop
    reg [7:0] dsh = 0;
    // Line assembly for the log: an explicit byte array indexed from 0, never a shift
    // register (shifting into a [8*80-1:0] vector puts the FIRST byte at the MSB, which
    // prints the line reversed).
    reg [7:0] line_mem [0:79];
    integer   line_len = 0;
    integer   li = 0;
    integer   rx_errors = 0;

    always @(posedge clk) begin
        txq <= uart_tx;
        if (!dbusy) begin
            if (txq && !uart_tx) begin           // falling edge = start bit
                dbusy <= 1; dcount <= BAUD_HALF; dbit <= 0; dsh <= 8'h00;
            end
        end else if (dcount == 0) begin
            case (dbit)
                0: begin
                    if (uart_tx !== 1'b0) begin
                        $display("[UART] t=%0d ns WARN start bit not low when sampled (tx=%b)",
                                 $time, uart_tx);
                        rx_errors = rx_errors + 1;
                    end
                    dbit <= 1; dcount <= BAUD_DIV - 1;
                end
                8: begin
                    dsh[7] = uart_tx;
                    dbit <= 9; dcount <= BAUD_DIV - 1;
                end
                9: begin
                    if (uart_tx !== 1'b1) begin
                        $display("[UART] t=%0d ns WARN stop bit not high (tx=%b) byte=0x%02x",
                                 $time, uart_tx, dsh);
                        rx_errors = rx_errors + 1;
                    end
                    chars = chars + 1;
                    $display("[UART] t=%0d ns (%0.4f ms, %0d cycles) BYTE %0d = 0x%02x '%s'",
                             $time, $time/1000000.0, cycles, chars, dsh,
                             (dsh >= 8'h20 && dsh < 8'h7f) ? dsh : 8'h2e);
                    // Append the character to the printable line so the banner text is
                    // readable directly in the transcript. Only the line_len bytes that
                    // were actually received are printed, so a short line is not padded
                    // with NULs from a fixed-width buffer.
                    line_mem[line_len] = dsh;
                    line_len = line_len + 1;
                    if (dsh == 8'h0a || line_len >= 79) begin
                        $write("[UART-LINE] \"");
                        for (li = 0; li < line_len; li = li + 1)
                            $write("%c", line_mem[li]);
                        $display("\"");
                        line_len = 0;
                    end
                    dbusy <= 0; dbit <= 0;
                end
                default: begin
                    dsh[dbit-1] = uart_tx;
                    dbit <= dbit + 1; dcount <= BAUD_DIV - 1;
                end
            endcase
        end else dcount <= dcount - 1;
    end

    // Raw uart_tx transitions (always printed): lets the byte stream be reconstructed
    // by hand if the decoder assumption above were wrong.
    reg tx_last = 1;
    always @(posedge clk) begin
        if (uart_tx !== tx_last) begin
            tx_last <= uart_tx;
            $display("[UART-RAW] t=%0d ns (%0.4f ms) uart_tx -> %b",
                     $time, $time/1000000.0, uart_tx);
        end
    end

    // ---- stimulus / termination --------------------------------------------------
    initial begin
        $display("==== tb_led_walk: 27 MHz (T=%0.3f ns), baud_div=%0d clocks per bit ====",
                 CLK_PERIOD_NS, BAUD_DIV);
        $display("==== images: %0s program.hex / data.hex ====", IMG_DIR);
        rst_n = 0; uart_rx = 1; spi_miso = 1; key = 2'b11;
        repeat (10) @(negedge clk);
        @(negedge clk) rst_n = 1;
        started = 1;
        $display("[RST] reset released at t=%0d ns", $time);
    end

    initial begin
        #(STOP_TIME_NS);
        $display("");
        $display("==== [TIME CAP] reached: t=%0d ns (%0.4f ms) cycles=%0d led_changes=%0d uart_chars=%0d ====",
                 $time, $time/1000000.0, cycles, led_changes, chars);
        $display("==== LED_RESULT changes=%0d (expected order 01 02 04 08 10 20 40 80 ...) ====",
                 led_changes);
        $finish;
    end
endmodule
