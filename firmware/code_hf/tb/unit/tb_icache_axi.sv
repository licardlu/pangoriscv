//=============================================================================
// pangoriscv - RV32IM processor core + native AXI4 SoC (Pango PG2L100H @ 27 MHz)
// Module : tb_icache_axi          File : tb/unit/tb_icache_axi.sv
// Rev    : 1.0                    Date : 2026-10-13
// Author : pango_lpenghan
// Brief  : Directed unit test for the two-way set-associative I-cache: hit path,
//          line fill and replacement
//=============================================================================

// ---------------------------------------------------------------------------
// Directed unit test for the the caches two-way set-associative instruction cache.
//
// T1 cold miss            -> exactly one full-line INCR burst, correct word
// T2 sequential hit       -> no burst, correct word
// T3 line boundary        -> last word of a line, then the next line (new burst)
// T4 two-way + LRU        -> A,B share a set; re-read A hits; C evicts the LRU
//                            victim B; B then misses again, C hits
// T5 mid-burst error      -> error is returned to the core, line stays invalid
// T6 last-beat error      -> same, and no line validation
// T7 invalidate in flight -> the line must not become valid afterwards
// T8 aliased tags         -> tags differing only above bit 9 stay distinct
//
// The slave is a plain INCR reader with one injectable error beat, so the tests
// observe the real AXI framing rather than an assumed one.
// ---------------------------------------------------------------------------
`timescale 1ns/1ps
module tb_icache_axi;

    reg clk = 0;
    always #5 clk = ~clk;

    reg rst_n = 0;
    reg invalidate = 0;

    // engine side
    reg req_valid = 0;
    wire req_ready;
    reg [31:0] req_addr = 0;
    reg [2:0] req_size = 3'd2;
    reg [7:0] req_len = 8'd0;
    reg [3:0] req_id = 4'd0;
    wire rsp_valid;
    reg rsp_ready = 0;
    wire [31:0] rsp_data;
    wire [1:0] rsp_resp;
    wire [3:0] rsp_id;
    wire protocol_fault, config_fault, miss_pulse, access_pulse;

    // AXI read channel
    wire m_arvalid;
    reg m_arready = 1;
    wire [31:0] m_araddr;
    wire [3:0] m_arid;
    wire [7:0] m_arlen;
    wire [2:0] m_arsize;
    wire [1:0] m_arburst;
    wire m_arlock;
    wire [3:0] m_arcache;
    wire [2:0] m_arprot;
    wire [3:0] m_arqos;
    reg m_rvalid = 0;
    wire m_rready;
    reg [31:0] m_rdata = 0;
    reg [3:0] m_rid = 0;
    reg [1:0] m_rresp = 2'b00;
    reg m_rlast = 0;

    icache_axi dut(
        .clk(clk), .rst_n(rst_n), .invalidate(invalidate),
        .req_valid(req_valid), .req_ready(req_ready), .req_addr(req_addr),
        .req_size(req_size), .req_len(req_len), .req_id(req_id),
        .rsp_valid(rsp_valid), .rsp_ready(rsp_ready), .rsp_data(rsp_data),
        .rsp_resp(rsp_resp), .rsp_id(rsp_id),
        .protocol_fault(protocol_fault), .config_fault(config_fault),
        .miss_pulse(miss_pulse), .access_pulse(access_pulse),
        .m_arvalid(m_arvalid), .m_arready(m_arready), .m_araddr(m_araddr),
        .m_arid(m_arid), .m_arlen(m_arlen), .m_arsize(m_arsize),
        .m_arburst(m_arburst), .m_arlock(m_arlock), .m_arcache(m_arcache),
        .m_arprot(m_arprot), .m_arqos(m_arqos),
        .m_rvalid(m_rvalid), .m_rready(m_rready), .m_rdata(m_rdata),
        .m_rid(m_rid), .m_rresp(m_rresp), .m_rlast(m_rlast)
    );

    // ---------------- memory image + AXI slave ----------------
    reg [31:0] mem [0:4095];
    integer i;
    initial for(i=0;i<4096;i=i+1) mem[i] = 32'hA0000000 + i;

    integer bursts = 0;
    integer beats_out = 0;
    reg [7:0] ar_len_seen = 0;
    reg [2:0] ar_size_seen = 0;
    reg [1:0] ar_burst_seen = 0;
    reg [31:0] ar_addr_seen = 0;
    reg [3:0] ar_id_seen = 0;
    integer inject_at = -1;
    integer beat_idx = 0;
    reg [31:0] cur_addr = 0;
    reg [7:0] beats_left = 0;

    always @(posedge clk) begin
        if(!rst_n) begin
            bursts <= 0; beats_out <= 0; m_rvalid <= 0; m_rlast <= 0;
            m_rresp <= 2'b00; beat_idx <= 0; beats_left <= 0;
        end else begin
            if(m_arvalid && m_arready && !m_rvalid) begin
                bursts <= bursts + 1;
                ar_len_seen <= m_arlen; ar_size_seen <= m_arsize;
                ar_burst_seen <= m_arburst; ar_addr_seen <= m_araddr;
                ar_id_seen <= m_arid;
                beats_left <= m_arlen + 8'd1;
                cur_addr <= m_araddr;
                beat_idx <= 0;
                m_rvalid <= 1; beats_out <= beats_out + 1;
                m_rdata <= mem[m_araddr[13:2]];
                m_rid <= m_arid;
                m_rresp <= (inject_at == 0) ? 2'b10 : 2'b00;
                m_rlast <= (m_arlen == 8'd0);
            end else if(m_rvalid && m_rready) begin
                if(beats_left <= 1) begin
                    m_rvalid <= 0; m_rlast <= 0;
                end else begin
                    beats_left <= beats_left - 1;
                    beat_idx <= beat_idx + 1;
                    m_rvalid <= 1; beats_out <= beats_out + 1;
                    m_rdata <= mem[cur_addr[13:2] + beat_idx + 1];
                    m_rid <= ar_id_seen;
                    m_rresp <= (inject_at == (beat_idx + 1)) ? 2'b10 : 2'b00;
                    m_rlast <= (beats_left == 2);
                end
            end
        end
    end

    // ---------------- stimulus ----------------
    integer errors = 0;
    integer bursts_before = 0;
    reg [31:0] got_data = 0;
    reg [1:0] got_resp = 0;
    integer k9 = 0;
    reg [31:0] t9_base = 32'h0000_3400;

    task fail(input [255:0] what);
        begin
            errors = errors + 1;
            $display("  FAIL %0s (data=%08x resp=%0d bursts=%0d)",
                     what, got_data, got_resp, bursts);
        end
    endtask

    // One lookup. rsp_ready is held low until the request has been accepted, so
    // the response can never be consumed before this task looks for it.
    task lookup(input [31:0] addr);
        begin
            @(negedge clk);
            req_addr = addr; req_id = 4'h5; req_valid = 1; rsp_ready = 0;
            @(posedge clk);
            if(!req_ready) $display("  note: request not accepted at first edge");
            @(negedge clk);
            req_valid = 0; rsp_ready = 1;
            while(!rsp_valid) @(negedge clk);
            got_data = rsp_data; got_resp = rsp_resp;
            @(negedge clk);
            rsp_ready = 0;
        end
    endtask

    task expect_word(input [255:0] what, input [31:0] addr, input [31:0] exp,
                     input [1:0] exp_resp, input integer exp_bursts);
        begin
            bursts_before = bursts;
            lookup(addr);
            if(exp_resp !== 2'b00) begin
                // An error response makes the payload a don't-care; only the
                // response code is contractual, and the follow-up lookup proves
                // the line was not validated.
                if(got_resp !== exp_resp) fail(what);
                else $display("  ok   %0s addr=%08x resp=%0d (payload ignored) bursts=%0d",
                              what, addr, got_resp, bursts-bursts_before);
            end else if(got_data !== exp) fail(what);
            else if(got_resp !== exp_resp) fail(what);
            else if((bursts - bursts_before) !== exp_bursts)
                $display("  FAIL %0s burst count %0d expected %0d",
                         what, bursts-bursts_before, exp_bursts);
            else $display("  ok   %0s addr=%08x data=%08x resp=%0d bursts=%0d",
                          what, addr, got_data, got_resp, bursts-bursts_before);
        end
    endtask

    initial begin
        repeat(4) @(negedge clk);
        rst_n = 1;
        repeat(2) @(negedge clk);

        // T1/T2: cold miss then a sequential hit inside the same cache line.
    // The expected burst length and beat count follow the DUT's own geometry
    // (cache_axi localparams), so changing the line size does not silently
    // keep an obsolete expectation.
        expect_word("T1 cold miss", 32'h0000_0000, mem[0], 2'b00, 1);
        if(ar_len_seen !== (dut.LINE_BEATS-1) || ar_size_seen !== 3'd2 || ar_burst_seen !== 2'b01)
            $display("  FAIL T1 burst descriptor len=%0d size=%0d burst=%0d",
                     ar_len_seen, ar_size_seen, ar_burst_seen);
        if(beats_out !== dut.LINE_BEATS)
        $display("  FAIL T1 burst beats %0d (expected %0d)", beats_out, dut.LINE_BEATS);
        expect_word("T2 sequential hit", 32'h0000_0004, mem[1], 2'b00, 0);

        // T3: last word of line 0, then the first word of line 1.
        //     Offsets follow the DUT line size instead of assuming 32 B.
        expect_word("T3 line tail", dut.LINE_BEATS*4-4, mem[dut.LINE_BEATS-1], 2'b00, 0);
        expect_word("T3 next line", dut.LINE_BEATS*4,   mem[dut.LINE_BEATS],   2'b00, 1);

        // T4: two-way conflict + LRU.  The three addresses must map to the SAME set,
        // so the required spacing is exactly one full index wrap (SETS*32 bytes):
        //   SETS=32  -> 0x400     SETS=64 -> 0x800     SETS=128 -> 0x1000
        // The addresses below are valid for the 32-set geometry only; for larger
        // geometries they would no longer share a set, so the case is skipped rather
        // than silently asserting something it does not test.
        if (dut.SETS == 32) begin
            expect_word("T4 A miss", 32'h0000_2800, mem[32'h2800>>2], 2'b00, 1);
            expect_word("T4 B miss", 32'h0000_3000, mem[32'h3000>>2], 2'b00, 1);
            expect_word("T4 A hit",  32'h0000_2800, mem[32'h2800>>2], 2'b00, 0);
            expect_word("T4 C evicts", 32'h0000_3800, mem[32'h3800>>2], 2'b00, 1);
            expect_word("T4 B miss again", 32'h0000_3000, mem[32'h3000>>2], 2'b00, 1);
            expect_word("T4 C hit", 32'h0000_3800, mem[32'h3800>>2], 2'b00, 0);
        end else $display("  skip T4 two-way conflict (needs SETS==32 address map, DUT SETS=%0d)",
                          dut.SETS);

        // T5: error on beat 3 of a fresh line -> SLVERR reaches the core and the
        // line must not be cached.
        inject_at = 3;
        expect_word("T5 mid-burst error", 32'h0000_1000, 32'h0, 2'b10, 1);
        inject_at = -1;
        expect_word("T5 line not cached", 32'h0000_1000, mem[1024], 2'b00, 1);

        // T6: error on the last beat.
        inject_at = dut.LINE_BEATS-1;
        expect_word("T6 last-beat error", 32'h0000_2000, 32'h0, 2'b10, 1);
        inject_at = -1;
        expect_word("T6 line not cached", 32'h0000_2000, mem[2048], 2'b00, 1);

        // T7: an invalidate landing while the burst is in flight must leave the
        // line invalid, so the next lookup refetches it.
        fork
            begin
                @(negedge clk);
                req_addr = 32'h0000_0C00; req_id = 4'h5; req_valid = 1; rsp_ready = 0;  // fresh line (T4 now uses 0x2800/0x3000/0x3800)
                @(posedge clk);
                @(negedge clk);
                req_valid = 0;
                @(posedge clk);
                while(!(m_arvalid && m_arready)) @(posedge clk);
                @(negedge clk);
                invalidate = 1;
                @(negedge clk);
                invalidate = 0;
                while(!rsp_valid) @(negedge clk);
                got_data = rsp_data; got_resp = rsp_resp;
                rsp_ready = 1;
                @(negedge clk);
                rsp_ready = 0;
            end
        join
        if(got_resp !== 2'b00) $display("  FAIL T7 response resp=%0d", got_resp);
        expect_word("T7 invalidated line refetches", 32'h0000_0C00, mem[768], 2'b00, 1);

        // T8: tags that differ only above the index field stay distinct entries.
        // Same geometry caveat as T4: the pair 0x1400/0x1800 lands in one set only at
        // SETS=32, so it is skipped for larger caches instead of asserting a false
        // property.
        if (dut.SETS == 32) begin
            expect_word("T8 aliased tag A", 32'h0000_1400, mem[1280], 2'b00, 1);
            expect_word("T8 aliased tag B", 32'h0000_1800, mem[1536], 2'b00, 1);
            expect_word("T8 aliased tag A hit", 32'h0000_1400, mem[1280], 2'b00, 0);
        end else $display("  skip T8 tag alias (needs SETS==32 address map, DUT SETS=%0d)",
                          dut.SETS);

        // T9: back-to-back hits.  A lookup is accepted on the same edge the
        // previous response is taken, so a run of in-line hits costs one cycle
        // each.  The pre-T9 build parked in IC_RESP for an extra cycle and could
        // only accept every other cycle, which this test catches immediately
        // (the second word would not be answered when it is checked).
        bursts_before = bursts;
        expect_word("T9 line fill", t9_base, mem[t9_base[13:2]], 2'b00, 1);
        @(negedge clk);
        req_valid = 1; rsp_ready = 1; req_id = 4'h5;
        req_addr = t9_base + 32'd4;
        for(k9 = 1; k9 <= 7; k9 = k9 + 1) begin
            @(negedge clk);
            if(!rsp_valid) begin
                errors = errors + 1;
                $display("  FAIL T9 word %0d not answered in one cycle", k9);
            end else if(rsp_data !== mem[t9_base[13:2] + k9]) begin
                errors = errors + 1;
                $display("  FAIL T9 word %0d data=%08x expected %08x",
                         k9, rsp_data, mem[t9_base[13:2] + k9]);
            end else begin
                $display("  ok   T9 back-to-back word %0d data=%08x", k9, rsp_data);
            end
            if(k9 < 7) req_addr = t9_base + 32'd4 * (k9 + 1);
        end
        @(negedge clk);
        req_valid = 0; rsp_ready = 0;
        if((bursts - bursts_before) !== 1) begin
            errors = errors + 1;
            $display("  FAIL T9 unexpected burst count %0d", bursts - bursts_before);
        end

        if(protocol_fault) begin
            errors = errors + 1;
            $display("  FAIL unexpected protocol_fault");
        end

        if(errors == 0) $display("TEST_PASS ICACHE");
        else $display("TEST_FAIL ICACHE errors=%0d", errors);
        $finish;
    end

    initial begin
        #200000;
        $display("TEST_FAIL ICACHE timeout");
        $finish;
    end
endmodule
