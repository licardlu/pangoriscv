//=============================================================================
// pangoriscv - RV32IM processor core + native AXI4 SoC (Pango PG2L100H @ 27 MHz)
// Module : tb_isa_e2e             File : tb/integration/tb_isa_e2e.sv
// Rev    : 1.0                    Date : 2026-10-13
// Author : pango_lpenghan
// Brief  : End-to-end RV32IM regression harness: real SoC with simple AXI slaves,
//          flat instruction image loaded from +PROG/+DATA
//=============================================================================

// End-to-end RV32IM regression harness for the native AXI SoC.
//
// Instantiates the real pangoriscv_axi_soc with simple AXI slaves, loads one
// flat instruction image with +PROG/+DATA (at most 16384 bytes, as many as the
// program RAM holds), selects a case with +CASE, runs until the case's halt
// store appears, then dumps the architectural register file. The Python driver
// tools/run_isa_e2e.py compares those values against the case's expectations.
//
// The image is built from tests/isa_e2e/isa_e2e.S by that driver; nothing in
// this file modifies RTL, software or board constraints.

`include "native_axi_macros.vh"
`timescale 1ns/1ps

module tb_isa_e2e;

    localparam integer PROG_WORDS = 4096;
    localparam [31:0] DATA_BASE = 32'h10000000;
    localparam integer DATA_WORDS = 4096;
    localparam [31:0] HALT_ADDR = 32'h10000ff0;
    localparam [31:0] HALT_SIG  = 32'h5a5a1234;
    localparam integer HALT_WORD = 32'h0ff0 >> 2;
    localparam integer MAX_CYCLES = 400000;

    reg clk = 0;
    always #10 clk = ~clk;
    reg rst_n = 0;

    reg [31:0] prog [0:PROG_WORDS-1];
    reg [31:0] data [0:DATA_WORDS-1];

    integer test_case = 0;
    string prog_path;

    wire [31:0] gpio_ctrl, gpio_data;
    wire uart_tx;
    wire spi_mosi, spi_ss, spi_clk;
    wire trap_fire_d;
    wire [31:0] trap_cause_d, trap_pc_d, trap_tval_d;
    wire [63:0] retire_order_d;
    integer trap_seen = 0;

    pangoriscv_axi_soc soc (
        .clk(clk), .rst_n(rst_n),
        .uart_rx(1'b1), .uart_tx(uart_tx),
        .gpio_input(2'b00), .gpio_ctrl(gpio_ctrl), .gpio_data(gpio_data),
        .spi_miso(1'b1), .spi_mosi(spi_mosi), .spi_ss(spi_ss), .spi_clk(spi_clk),
        .ext_event(2'b00),
        .halt_req(1'b0), .halted(), .arch_next_pc(),
        .trap_ready(1'b1), .trap_vector(32'b0),
        .irq_software(1'b0), .irq_timer(1'b0), .irq_external(1'b0),
        .csr_mtvec(),
        .trap_fire(trap_fire_d), .trap_cause(trap_cause_d), .trap_pc(trap_pc_d), .trap_tval(trap_tval_d),
        .retire_fire(), .retire_order(retire_order_d), .retire_pc(), .retire_inst(),
        .rd_valid(), .rd(), .wdata(),
        .debug_addr(5'b0), .debug_data(), .protocol_fault()
    );

    // The SoC's slaves and fabric are internal; the program image is injected
    // directly into the RAM models while reset is held, and completion is
    // detected by watching the real RAM contents (no external AXI port exists).
    wire protocol_fault_d = soc.protocol_fault;
    reg  mem_check_seen = 0;

    integer mw;
    function [31:0] mem_read_data(input [31:0] addr);
        begin
            if(addr < PROG_WORDS*4)
                mem_read_data = prog[addr[13:2]];
            else if(addr >= DATA_BASE && addr < DATA_BASE+DATA_WORDS*4)
                mem_read_data = data[(addr-DATA_BASE)>>2];
            else
                mem_read_data = 32'hdeadbeef;
        end
    endfunction

    // -------------------------------------------------------- UART bit decode
    integer uart_bit_timer = 0;
    integer uart_bit_phase = -1;
    reg [7:0] uart_shift = 0;
    integer uart_chars = 0;

    // The UART divisor is 234 (the axi_uart reset value for the 27 MHz board clock), so
    // one simulated bit cell is 234 clk cycles; sample at half a cell after the start
    // edge and then once per cell. The simulation clock has no physical frequency, so
    // this models the divider, not a board frequency.
    always @(posedge clk) if(rst_n) begin
        if(uart_bit_phase < 0) begin
            if(!uart_tx) begin
                uart_bit_timer <= 117;
                uart_bit_phase <= 0;
            end
        end else if(uart_bit_timer > 0) begin
            uart_bit_timer <= uart_bit_timer - 1;
        end else if(uart_bit_phase == 0) begin
            if(uart_tx !== 1'b0) begin
                $display("UART_DECODE_ERROR: start bit not low");
                uart_bit_phase <= -1;
            end else begin
                uart_bit_timer <= 234;
                uart_bit_phase <= 1;
            end
        end else if(uart_bit_phase <= 8) begin
            uart_shift <= {uart_tx, uart_shift[7:1]};
            uart_bit_timer <= 234;
            uart_bit_phase <= uart_bit_phase + 1;
        end else begin
            uart_chars = uart_chars + 1;
            $display("UART_TX char='%c' (0x%02x)", uart_shift, uart_shift);
            uart_bit_phase <= -1;
        end
    end

    // -------------------------------------------------------------- sequences
    integer trace_n = 0;
    // Pair coverage: retire_count is 2 on the cycle both lanes leave EX.  Without
    // this, a "the pair formed" claim is unfalsifiable from the register dump --
    // a test that silently de-pairs would still pass (P37a).
    integer pair_n = 0;
    reg fire_d = 0;
    reg [63:0] ord_d = 0;
    always @(posedge clk) if(rst_n) begin
        // retire_order is the cumulative retire count and only updates at the
        // edge, so the delta seen one edge later is the previous edge's
        // retire_count: 2 means both lanes left EX together.
        if(fire_d && (retire_order_d - ord_d) == 64'd2) pair_n = pair_n + 1;
        fire_d <= soc.core.retire_fire;
        ord_d  <= retire_order_d;
    end
    always @(posedge clk) if(rst_n && soc.core.retire_fire) begin
        trace_n = trace_n + 1;
        if(trace_n <= 40)
            $display("E2E_RETIRE n=%0d pc=%08x inst=%08x rd=%0d we=%b wdata=%08x",
                     trace_n, soc.core.retire_pc, soc.core.retire_inst,
                     soc.core.rd, soc.core.rd_valid, soc.core.wdata);
    end

    integer i;
    reg sim_done = 0;
    reg [31:0] reg_snapshot;
    integer cycles;

    task dump_regs;
        begin
            for(i=0; i<32; i=i+1) begin
                reg_snapshot = soc.core.cpu.u_regs.rfile[i];
                $display("E2E_REG case=%0d x%0d=%08x", test_case, i, reg_snapshot);
            end
        end
    endtask

    initial begin
        if(!$value$plusargs("CASE=%d", test_case)) test_case = 0;
        if(!$value$plusargs("PROG=%s", prog_path)) begin
            $display("TEST_FAIL case=%0d missing +PROG", test_case);
            $finish;
        end
        rst_n = 0;
        mem_check_seen = 0;
        for(i=0;i<PROG_WORDS;i=i+1) prog[i] = 32'h00000013;
        for(i=0;i<DATA_WORDS;i=i+1) data[i] = 32'h00000000;
        $readmemh(prog_path, prog);
        // Inject the program image into the real SoC RAM while reset is held.
        for(i=0;i<PROG_WORDS;i=i+1) soc.program_ram.mem[i] = prog[i];
        for(i=0;i<DATA_WORDS;i=i+1) soc.data_ram.mem[i] = data[i];
        #100;
        rst_n = 1;
        repeat(4) @(posedge clk);

        for(cycles=0; cycles<MAX_CYCLES && !mem_check_seen; cycles=cycles+1) begin
            @(posedge clk);
            if(soc.data_ram.mem[HALT_WORD] == HALT_SIG)
                mem_check_seen = 1;
        end
        if(!mem_check_seen) begin
            $display("E2E_TIMEOUT case=%0d cycles=%0d arch_next_pc=%08x halted=%b",
                     test_case, MAX_CYCLES, soc.core.arch_next_pc, soc.core.halted);
            dump_regs;
            $display("TEST_FAIL case=%0d", test_case);
            sim_done = 1;
            $finish;
        end
        // Let the store drain, the pipeline settle, and any in-flight UART
        // transmission finish (one byte is ~10 bit cells) before sampling.
        repeat(10) @(posedge clk);
        repeat(12000) @(posedge clk);
        dump_regs;
        if(test_case == 13)
            $display("E2E_GPIO ctrl=%08x data=%08x", gpio_ctrl, gpio_data);
        if(test_case == 12)
            $display("E2E_UART chars=%0d", uart_chars);
        $display("TEST_PASS case=%0d traps=%0d pairs=%0d", test_case, trap_seen, pair_n);
        sim_done = 1;
        $finish;
    end

    always @(posedge clk) if(rst_n && trap_fire_d) begin
        trap_seen = trap_seen + 1;
        if(trap_seen <= 8)
            $display("E2E_TRAP n=%0d cause=%08x pc=%08x tval=%08x",
                     trap_seen, trap_cause_d, trap_pc_d, trap_tval_d);
    end

    initial begin
        #(MAX_CYCLES*20 + 500000);
        if(!sim_done) begin
            $display("E2E_WATCHDOG case=%0d", test_case);
            $display("TEST_FAIL case=%0d", test_case);
            $finish;
        end
    end

endmodule
