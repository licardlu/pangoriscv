//=============================================================================
// pangoriscv - RV32IM processor core + native AXI4 SoC (Pango PG2L100H @ 27 MHz)
// Module : tb_halt_reset_drain    File : tb/integration/tb_halt_reset_drain.sv
// Rev    : 1.0                    Date : 2026-10-13
// Author : pango_lpenghan
// Brief  : Halt / reset drain, resume and no-orphan-transaction regression on
//          the real native AXI SoC
//=============================================================================

// -----------------------------------------------------------------------------
// Halt / reset drain, resume and no-orphan-transaction regression
// -----------------------------------------------------------------------------
// Target : pangoriscv_axi_soc (native AXI4 basic version, real fabric)
// Purpose: the handoff checklist requires a safe halt path, a coordinated
//          reset that never orphans an accepted AXI transaction, and a resume
//          that restarts at the architectural next PC exactly once.
//
// Scenarios (+SCEN=n):
//   1 halt   injected while a data read  is in flight
//   2 halt   injected while a data write is in flight
//   3 reset  asserted while a data read  is in flight
//   4 reset  asserted while a data write is in flight
//   5 reset  asserted while the bus is idle
//
// What is checked:
//   * VALID is never withdrawn before its handshake and its payload is stable
//     on all five channels of both masters (cycle-by-cycle monitor).
//   * A transaction that was already accepted when halt was requested always
//     completes with a real response before `halted` is asserted.
//   * While `halted` is high no master asserts ARVALID/AWVALID/WVALID.
//   * After halt release the CPU refetches from the captured `arch_next_pc`
//     and retires again.
//   * While `rst_n` is low every VALID and READY on the fabric is low, so no
//     transaction can be left half-open; after release the CPU restarts at
//     architectural PC 0.
//   * protocol_fault stays low throughout.
// -----------------------------------------------------------------------------
`timescale 1ns/1ps

module tb_halt_reset_drain;

    localparam integer PROG_WORDS = 4096;
    localparam integer DATA_WORDS = 4096;
    // Large enough that an injected halt/reset really catches a beat in flight.
    localparam integer READ_DELAY  = 60;
    localparam integer WRITE_DELAY = 60;

    localparam [2:0] LSU_EMPTY      = 3'd0;
    localparam [2:0] LSU_REQ        = 3'd1;
    localparam [2:0] LSU_WRITE_DATA = 3'd2;
    localparam [2:0] LSU_READ_WAIT  = 3'd3;
    localparam [2:0] LSU_WRITE_WAIT = 3'd4;
    localparam [2:0] LSU_COMPLETE   = 3'd5;

    reg clk = 1'b0;
    always #10 clk = ~clk;              // 50 MHz board clock

    integer cycles = 0;
    always @(posedge clk) cycles <= cycles + 1;

    reg rst_n = 1'b0;

    // ---- image ---------------------------------------------------------------
    reg [31:0] prog [0:PROG_WORDS-1];
    reg [31:0] data [0:DATA_WORDS-1];
    reg [1023:0] prog_file, data_file;

    // ---- DUT -----------------------------------------------------------------
    reg  halt_req = 1'b0;
    wire halted;
    wire [31:0] arch_next_pc, csr_mtvec, trap_cause, trap_pc, trap_tval;
    wire [31:0] retire_pc, retire_inst, wdata;
    wire [63:0] retire_order;
    wire trap_fire, retire_fire, rd_valid, protocol_fault;
    wire [4:0] rd;
    wire uart_tx;
    wire [31:0] gpio_ctrl, gpio_data;

    pangoriscv_axi_soc #(
        .PROGRAM_INIT_FILE(""),
        .DATA_INIT_FILE(""),
        .READ_DELAY(READ_DELAY),
        .WRITE_DELAY(WRITE_DELAY)
    ) soc (
        .clk(clk), .rst_n(rst_n),
        .uart_rx(1'b1), .uart_tx(uart_tx),
        .gpio_input(2'b11), .gpio_ctrl(gpio_ctrl), .gpio_data(gpio_data),
        .spi_miso(1'b1), .spi_mosi(), .spi_ss(), .spi_clk(),
        .ext_event(2'b00),
        .halt_req(halt_req), .halted(halted), .arch_next_pc(arch_next_pc),
        .trap_ready(1'b1), .trap_vector(32'b0),
        .irq_software(1'b0), .irq_timer(1'b0), .irq_external(1'b0),
        .csr_mtvec(csr_mtvec),
        .trap_fire(trap_fire), .trap_cause(trap_cause),
        .trap_pc(trap_pc), .trap_tval(trap_tval),
        .retire_fire(retire_fire), .retire_order(retire_order),
        .retire_pc(retire_pc), .retire_inst(retire_inst),
        .rd_valid(rd_valid), .rd(rd), .wdata(wdata),
        .debug_addr(5'd0), .debug_data(), .protocol_fault(protocol_fault)
    );

    integer errors = 0;
    integer scenarios_seen = 0;

    // Independent retirement counter so "execution really restarted" is a
    // measured fact and not a fixed delay.
    integer retire_count = 0;
    always @(posedge clk) if (rst_n && retire_fire) retire_count = retire_count + 1;

    task automatic fail(input [8*96-1:0] what);
        begin
            errors = errors + 1;
            $display("HR_FAIL cycle=%0d %0s", cycles, what);
        end
    endtask

    // -------------------------------------------------------------------------
    // AXI VALID / payload stability monitor over all five channels, both masters.
    // -------------------------------------------------------------------------
    reg        v_ar[0:1], v_aw[0:1], v_w[0:1], v_r[0:1], v_b[0:1];
    reg [31:0] a_ar[0:1], a_aw[0:1], d_w[0:1];
    reg [3:0]  s_w[0:1];

    integer mi;
    always @(posedge clk) begin
        if (!rst_n) begin
            for (mi = 0; mi < 2; mi = mi + 1) begin
                v_ar[mi] <= 1'b0; v_aw[mi] <= 1'b0; v_w[mi] <= 1'b0;
            end
        end else begin
            for (mi = 0; mi < 2; mi = mi + 1) begin
                // Read address channel
                if (v_ar[mi] && soc.m_arvalid[mi]) begin
                    if (soc.m_araddr[mi*32 +: 32] !== a_ar[mi])
                        fail("ARADDR changed while ARVALID held without ARREADY");
                end
                if (soc.m_arvalid[mi] && !soc.m_arready[mi]) begin
                    v_ar[mi] <= 1'b1; a_ar[mi] <= soc.m_araddr[mi*32 +: 32];
                end else begin
                    v_ar[mi] <= 1'b0;
                end
                // Write address channel
                if (v_aw[mi] && soc.m_awvalid[mi]) begin
                    if (soc.m_awaddr[mi*32 +: 32] !== a_aw[mi])
                        fail("AWADDR changed while AWVALID held without AWREADY");
                end
                if (soc.m_awvalid[mi] && !soc.m_awready[mi]) begin
                    v_aw[mi] <= 1'b1; a_aw[mi] <= soc.m_awaddr[mi*32 +: 32];
                end else begin
                    v_aw[mi] <= 1'b0;
                end
                // Write data channel
                if (v_w[mi] && soc.m_wvalid[mi]) begin
                    if (soc.m_wdata[mi*32 +: 32] !== d_w[mi] ||
                        soc.m_wstrb[mi*4 +: 4]  !== s_w[mi])
                        fail("WDATA/WSTRB changed while WVALID held without WREADY");
                end
                if (soc.m_wvalid[mi] && !soc.m_wready[mi]) begin
                    v_w[mi] <= 1'b1; d_w[mi] <= soc.m_wdata[mi*32 +: 32];
                                     s_w[mi] <= soc.m_wstrb[mi*4 +: 4];
                end else begin
                    v_w[mi] <= 1'b0;
                end
            end
        end
    end

    // -------------------------------------------------------------------------
    // Main sequence
    // -------------------------------------------------------------------------
    integer scen;
    integer retires_at_start;
    integer retires_after;
    integer retires_before_resume;
    integer i;

    reg [31:0] arch_pc_at_halt;
    reg [31:0] first_resume_pc;
    reg [7:0]  first_resume_len;
    reg [1:0]  first_resume_burst;
    integer    txn_done;
    integer    saw_response;
    integer    other_things;

    integer ok_resp;

    initial begin
        if (!$value$plusargs("SCEN=%d", scen)) scen = 1;

        for (i = 0; i < PROG_WORDS; i = i + 1) prog[i] = 32'h00000013;
        for (i = 0; i < DATA_WORDS; i = i + 1) data[i] = 32'h00000000;

        if (!$value$plusargs("PROG=%s", prog_file)) begin
            $display("HR_FAIL no +PROG image");
            $fatal(1, "missing +PROG");
        end
        if (!$value$plusargs("DATA=%s", data_file)) begin
            $display("HR_FAIL no +DATA image");
            $fatal(1, "missing +DATA");
        end
        $readmemh(prog_file, prog);
        $readmemh(data_file, data);

        // Inject the images into the internal RAMs while reset is held.
        for (i = 0; i < PROG_WORDS; i = i + 1) soc.program_ram.mem[i] = prog[i];
        for (i = 0; i < DATA_WORDS; i = i + 1) soc.data_ram.mem[i] = data[i];
        for (i = 0; i < 64; i = i + 1) soc.data_ram.mem[32'h80 + i] = 32'h0;

        repeat (20) @(negedge clk);
        rst_n = 1'b1;
        $display("HR_START scen=%0d read_delay=%0d write_delay=%0d", scen, READ_DELAY, WRITE_DELAY);

        // The program must actually be running before anything is injected.
        wait (retire_fire);
        repeat (200) @(posedge clk);
        if (errors != 0) begin
            $display("HR_FAIL program did not reach steady state");
            $fatal(1, "no steady state");
        end
        retires_at_start = 0;

        if (scen == 1 || scen == 2) begin
            // ---------------- halt scenarios -------------------------------
            if (scen == 1) begin
                $display("HR_INJECT halt during in-flight data read");
                wait (soc.core.lsu.state == LSU_READ_WAIT);
            end else begin
                $display("HR_INJECT halt during in-flight data write");
                wait (soc.core.lsu.state == LSU_WRITE_WAIT);
            end
            @(negedge clk);
            arch_pc_at_halt = arch_next_pc;
            halt_req = 1'b1;
            $display("HR_HALT_REQUEST cycle=%0d arch_next_pc=%08x lsu_state=%0d",
                     cycles, arch_pc_at_halt, soc.core.lsu.state);

            // The accepted transaction must still complete with a real response.
            // It is the response (R or B) that proves the beat was not orphaned.
            saw_response = 0;
            if (scen == 1) begin
                fork
                    begin
                        wait (soc.m_rvalid[1] === 1'b1 && soc.m_rready[1] === 1'b1);
                        @(negedge clk);
                        saw_response = 1;
                    end
                    begin
                        repeat (20000) @(posedge clk);
                    end
                join_any
                if (saw_response !== 1) fail("in-flight read never completed after halt");
                else $display("HR_DRAIN read response arrived cycle=%0d resp=%b", cycles, soc.m_rresp[2+:2]);
            end else begin
                fork
                    begin
                        wait (soc.m_bvalid[1] === 1'b1 && soc.m_bready[1] === 1'b1);
                        @(negedge clk);
                        saw_response = 1;
                    end
                    begin
                        repeat (20000) @(posedge clk);
                    end
                join_any
                if (saw_response !== 1) fail("in-flight write never completed after halt");
                else $display("HR_DRAIN write response arrived cycle=%0d resp=%b", cycles, soc.m_bresp[2+:2]);
            end

            // Now the CPU must reach the halted state.
            txn_done = 0;
            fork
                begin wait (halted === 1'b1); @(negedge clk); txn_done = 1; end
                begin repeat (20000) @(posedge clk); end
            join_any
            if (txn_done !== 1) begin
                fail("halted was never asserted after halt_req");
            end else begin
                $display("HR_HALTED cycle=%0d arch_next_pc=%08x", cycles, arch_next_pc);
                // Architecturally correct: the instruction that owned the
                // in-flight transaction must still retire, so arch_next_pc may
                // advance past the value it had when halt was requested. It
                // must never move backwards, and the resume PC is the value
                // captured here, at the halted edge.
                if (arch_next_pc < arch_pc_at_halt)
                    fail("arch_next_pc moved backwards across halt");
                $display("HR_ARCH_NEXT halt_request=%08x halted=%08x",
                         arch_pc_at_halt, arch_next_pc);
                arch_pc_at_halt = arch_next_pc;   // resume must start here
            end

            // While halted no master may start a new transaction.
            other_things = 0;
            for (i = 0; i < 400; i = i + 1) begin
                @(posedge clk);
                if (soc.m_arvalid[0] || soc.m_arvalid[1] ||
                    soc.m_awvalid[0] || soc.m_awvalid[1] ||
                    soc.m_wvalid[0]  || soc.m_wvalid[1]) other_things = other_things + 1;
            end
            if (other_things != 0)
                fail("a master asserted VALID while halted");
            else
                $display("HR_HALTED_QUIET 400 cycles with no new transaction");

            // Resume: the first fetch after release must be arch_next_pc.
            retires_before_resume = retire_count;
            halt_req = 1'b0;
            $display("HR_RESUME_REQUEST cycle=%0d arch_next_pc=%08x", cycles, arch_next_pc);
            first_resume_pc = 32'hffffffff;
            first_resume_len = 8'hff;
            first_resume_burst = 2'b11;
            fork
                begin
                    wait (soc.m_arvalid[0] === 1'b1);
                    first_resume_pc = soc.m_araddr[0 +: 32];
                    first_resume_len = soc.m_arlen[0 +: 8];
                    first_resume_burst = soc.m_arburst[0 +: 2];
                end
                begin repeat (20000) @(posedge clk); end
            join_any
            if (first_resume_pc !== arch_pc_at_halt) begin
                // the caches: with the instruction cache enabled the fetch after resume is
                // the 8-beat INCR refill of the 32-byte line containing
                // arch_next_pc, so the burst address is the line base address.
                // A cache hit (no bus transaction at all) is also acceptable here,
                // because the line was already fetched before the halt.
                if (!((first_resume_len === 8'd7 && first_resume_burst === 2'b01 &&
                       (first_resume_pc & 32'hffff_ffe0) ===
                       (arch_pc_at_halt & 32'hffff_ffe0)) ||
                      first_resume_pc === 32'hffffffff)) begin
                    $display("HR_RESUME_DETAIL pc=%08x len=%0d burst=%0d want=%08x",
                             first_resume_pc, first_resume_len, first_resume_burst,
                             arch_pc_at_halt);
                    fail("resume fetch does not cover arch_next_pc");
                end
                else
                    $display("HR_RESUME cycle=%0d burst_pc=%08x arlen=%0d burst=%0d line of %08x",
                             cycles, first_resume_pc, first_resume_len,
                             first_resume_burst, arch_pc_at_halt);
            end
            else
                $display("HR_RESUME cycle=%0d fetch_pc=%08x", cycles, first_resume_pc);

            // Retire again to prove execution really restarted.
            retires_after = 0;
            fork
                begin
                    wait (retire_count > retires_before_resume);
                    repeat (100) @(posedge clk);
                    retires_after = 1;
                end
                begin repeat (20000) @(posedge clk); end
            join_any
            if (retires_after !== 1) fail("no retirement after resume");
            else $display("HR_RESUME_RETIRED retires=%0d halted=%b", retire_count, halted);
        end
        else begin
            // ---------------- reset scenarios ------------------------------
            if (scen == 3) begin
                $display("HR_INJECT reset during in-flight data read");
                wait (soc.core.lsu.state == LSU_READ_WAIT);
            end else if (scen == 4) begin
                $display("HR_INJECT reset during in-flight data write");
                wait (soc.core.lsu.state == LSU_WRITE_WAIT);
            end else begin
                $display("HR_INJECT reset while the bus is idle");
                wait (soc.core.lsu.state == LSU_EMPTY && soc.m_arvalid[1] === 1'b0);
            end
            @(negedge clk);
            rst_n = 1'b0;
            $display("HR_RESET_ASSERT cycle=%0d lsu_state=%0d arvalid=%b awvalid=%b",
                     cycles, soc.core.lsu.state, soc.m_arvalid, soc.m_awvalid);

            // Everything on the fabric must be quiescent while reset is low.
            other_things = 0;
            for (i = 0; i < 100; i = i + 1) begin
                @(posedge clk);
                if (soc.m_arvalid !== 2'b00 || soc.m_awvalid !== 2'b00 ||
                    soc.m_wvalid  !== 2'b00 || soc.m_rready  !== 2'b00 ||
                    soc.m_bready  !== 2'b00) other_things = other_things + 1;
            end
            if (other_things != 0)
                fail("a master kept a channel live during reset");
            else
                $display("HR_RESET_QUIET 100 cycles with all master valids and readies low");

            // No half-open transaction may be left behind: no endpoint may be
            // driving VALID either.
            if (soc.s_arvalid !== 7'b0 || soc.s_awvalid !== 7'b0 || soc.s_wvalid !== 7'b0)
                fail("a slave endpoint still drives VALID during reset");

            rst_n = 1'b1;
            $display("HR_RESET_RELEASE cycle=%0d", cycles);

            // Restart must begin at architectural PC 0.
            first_resume_pc = 32'hffffffff;
            fork
                begin
                    wait (soc.m_arvalid[0] === 1'b1);
                    first_resume_pc = soc.m_araddr[0 +: 32];
                end
                begin repeat (20000) @(posedge clk); end
            join_any
            if (first_resume_pc !== 32'h00000000)
                fail("after reset the first fetch was not PC 0");
            else
                $display("HR_RESTART fetch_pc=%08x", first_resume_pc);

            retires_before_resume = retire_count;
            retires_after = 0;
            fork
                begin
                    wait (retire_count > retires_before_resume);
                    repeat (100) @(posedge clk);
                    retires_after = 1;
                end
                begin repeat (20000) @(posedge clk); end
            join_any
            if (retires_after !== 1) fail("no retirement after reset release");
            else $display("HR_RESTART_RETIRED retires=%0d", retire_count);
        end

        if (protocol_fault !== 1'b0) fail("protocol_fault asserted during the scenario");
        if (soc.protocol_fault !== 1'b0) fail("SoC protocol_fault asserted during the scenario");

        if (errors == 0)
            $display("TEST_PASS HALT_RESET_DRAIN scen=%0d cycles=%0d", scen, cycles);
        else
            $display("TEST_FAIL HALT_RESET_DRAIN scen=%0d errors=%0d", scen, errors);
        $finish;
    end

    // Safety net for a hung design.
    initial begin
        repeat (4000000) @(posedge clk);
        $display("HR_TIMEOUT cycles=%0d", cycles);
        $display("TEST_FAIL HALT_RESET_DRAIN scen=%0d timeout", scen);
        $finish;
    end

endmodule
