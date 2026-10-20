//=============================================================================
// pangoriscv - RV32IM processor core + native AXI4 SoC (Pango PG2L100H @ 27 MHz)
// Module : tb_dcache_axi          File : tb/unit/tb_dcache_axi.sv
// Rev    : 1.0                    Date : 2026-10-13
// Author : pango_lpenghan
// Brief  : Directed unit test for the two-way set-associative D-cache: miss fill,
//          store merging and write-back
//=============================================================================

// ---------------------------------------------------------------------------
// Directed unit test for the the caches two-way set-associative data cache.
//
// D1 cold read miss        -> exactly one ARLEN=7 INCR burst, correct word
// D2 sequential hit        -> no burst, correct word
// D3 write hit             -> one single-beat AW/W/B, memory written through,
//                             and the cached line serves the merged word
// D4 byte-strobe write hit -> the merge keeps the neighbouring bytes
// D5 write miss            -> one single-beat write and *no* refill (no
//                             write allocate); a later read misses and refetches
// D6 two-way + LRU         -> A,B share a set; A hits; C evicts the LRU B;
//                             B misses again, C hits
// D7 refill error          -> SLVERR reaches the core, line stays invalid
// D8 store error           -> SLVERR reaches the core, memory unchanged, and
//                             the cached line is invalidated (next read misses)
// D9 MMIO bypass           -> non-cacheable reads/writes never allocate and
//                             never disturb the cached copies
// E1 posted store queue    -> three back-to-back data-RAM stores are all
//                             accepted before the first B returns
// E2 queue order           -> every queued store lands in memory, in order
// E3 merge on accept       -> a load HIT already sees the merged word while the
//                             write is still queued
// E4 miss ordering         -> a read MISS is not accepted while writes are
//                             queued or draining
// E5 halt drain            -> dc_idle stays low until the queue is empty
//
// The slave is a plain INCR reader plus a single-beat writer with injectable
// RRESP/BRESP errors, so the tests observe the real AXI framing.
// ---------------------------------------------------------------------------
`timescale 1ns/1ps
module tb_dcache_axi;

    reg clk = 0;
    always #5 clk = ~clk;

    reg rst_n = 0;

    // LSU-facing side
    reg req_valid = 0;
    wire req_ready;
    reg req_write = 0;
    reg [31:0] req_addr = 0;
    reg [2:0] req_size = 3'd2;
    reg [7:0] req_len = 8'd0;
    reg [3:0] req_id = 4'd0;
    reg w_valid = 0;
    wire w_ready;
    reg [31:0] w_data = 0;
    reg [3:0] w_strb = 4'hF;
    reg w_last = 1;
    wire rsp_valid;
    reg rsp_ready = 0;
    wire [31:0] rsp_data;
    wire [1:0] rsp_resp;
    wire rsp_last;
    wire [3:0] rsp_id;
    wire b_valid;
    reg b_ready = 0;
    wire [1:0] b_resp;
    wire [3:0] b_id;
    wire protocol_fault, config_fault, miss_event;
    wire dc_idle;

    // AXI master side
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

    wire m_awvalid;
    reg m_awready = 1;
    wire [31:0] m_awaddr;
    wire [3:0] m_awid;
    wire [7:0] m_awlen;
    wire [2:0] m_awsize;
    wire [1:0] m_awburst;
    wire m_awlock;
    wire [3:0] m_awcache;
    wire [2:0] m_awprot;
    wire [3:0] m_awqos;
    wire m_wvalid;
    reg m_wready = 1;
    wire [31:0] m_wdata;
    wire [3:0] m_wstrb;
    wire m_wlast;
    reg m_bvalid = 0;
    wire m_bready;
    reg [3:0] m_bid = 0;
    reg [1:0] m_bresp = 2'b00;

    dcache_axi dut(
        .clk(clk), .rst_n(rst_n),
        .req_valid(req_valid), .req_ready(req_ready), .req_write(req_write),
        .req_addr(req_addr), .req_size(req_size), .req_len(req_len), .req_id(req_id),
        .w_valid(w_valid), .w_ready(w_ready), .w_data(w_data), .w_strb(w_strb),
        .w_last(w_last),
        .rsp_valid(rsp_valid), .rsp_ready(rsp_ready), .rsp_data(rsp_data),
        .rsp_resp(rsp_resp), .rsp_last(rsp_last), .rsp_id(rsp_id),
        .b_valid(b_valid), .b_ready(b_ready), .b_resp(b_resp), .b_id(b_id),
        .protocol_fault(protocol_fault), .config_fault(config_fault),
        .miss_event(miss_event),
        .dc_idle(dc_idle),
        .m_arvalid(m_arvalid), .m_arready(m_arready), .m_araddr(m_araddr),
        .m_arid(m_arid), .m_arlen(m_arlen), .m_arsize(m_arsize),
        .m_arburst(m_arburst), .m_arlock(m_arlock), .m_arcache(m_arcache),
        .m_arprot(m_arprot), .m_arqos(m_arqos),
        .m_rvalid(m_rvalid), .m_rready(m_rready), .m_rdata(m_rdata),
        .m_rid(m_rid), .m_rresp(m_rresp), .m_rlast(m_rlast),
        .m_awvalid(m_awvalid), .m_awready(m_awready), .m_awaddr(m_awaddr),
        .m_awid(m_awid), .m_awlen(m_awlen), .m_awsize(m_awsize),
        .m_awburst(m_awburst), .m_awlock(m_awlock), .m_awcache(m_awcache),
        .m_awprot(m_awprot), .m_awqos(m_awqos),
        .m_wvalid(m_wvalid), .m_wready(m_wready), .m_wdata(m_wdata),
        .m_wstrb(m_wstrb), .m_wlast(m_wlast),
        .m_bvalid(m_bvalid), .m_bready(m_bready), .m_bid(m_bid), .m_bresp(m_bresp)
    );

    // ---------------- memory image ----------------
    reg [31:0] mem [0:4095];
    integer i;
    initial for(i=0;i<4096;i=i+1) mem[i] = 32'hB0000000 + i;

    // ---------------- AXI read slave (INCR bursts) ----------------
    integer ar_bursts = 0;
    integer beats_out = 0;
    reg [7:0] ar_len_seen = 0;
    reg [2:0] ar_size_seen = 0;
    reg [1:0] ar_burst_seen = 0;
    reg [31:0] ar_addr_seen = 0;
    integer inject_at = -1;               // read beat index that returns SLVERR
    integer beat_idx = 0;
    reg [31:0] cur_addr = 0;
    reg [7:0] beats_left = 0;

    always @(posedge clk) begin
        if(!rst_n) begin
            ar_bursts <= 0; beats_out <= 0; m_rvalid <= 0; m_rlast <= 0;
            m_rresp <= 2'b00; beat_idx <= 0; beats_left <= 0;
            ar_len_seen <= 0; ar_size_seen <= 0; ar_burst_seen <= 0;
        end else begin
            if(m_arvalid && m_arready && !m_rvalid) begin
                ar_bursts <= ar_bursts + 1;
                ar_len_seen <= m_arlen; ar_size_seen <= m_arsize;
                ar_burst_seen <= m_arburst; ar_addr_seen <= m_araddr;
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
                    m_rresp <= (inject_at == (beat_idx + 1)) ? 2'b10 : 2'b00;
                    m_rlast <= (beats_left == 2);
                end
            end
        end
    end

    // ---------------- AXI write slave (single beat + B) ----------------
    integer aw_writes = 0;
    integer w_beats = 0;
    reg inject_b = 0;                     // 1 -> BRESP=SLVERR, memory untouched
    reg aw_seen = 0, w_seen = 0, b_pending = 0, applied = 0;
    reg [31:0] aw_addr_l = 0;
    reg [31:0] w_data_l = 0;
    reg [3:0]  w_strb_l = 0;
    reg [7:0]  aw_len_seen = 0;
    reg [3:0]  aw_id_l = 0;
    reg        w_last_seen = 0;
    integer k;

    function [31:0] apply_strb;
        input [31:0] oldw;
        input [31:0] neww;
        input [3:0]  strb;
        integer b;
        begin
            apply_strb = oldw;
            for(b=0;b<4;b=b+1)
                if(strb[b]) apply_strb[8*b +: 8] = neww[8*b +: 8];
        end
    endfunction

    always @(posedge clk) begin
        if(!rst_n) begin
            aw_writes <= 0; w_beats <= 0; aw_seen <= 0; w_seen <= 0;
            b_pending <= 0; applied <= 0; m_bvalid <= 0; m_bresp <= 2'b00;
            w_last_seen <= 0; aw_len_seen <= 0;
        end else begin
            if(m_awvalid && m_awready) begin
                aw_writes <= aw_writes + 1;
                aw_seen <= 1;
                aw_addr_l <= m_awaddr;
                aw_len_seen <= m_awlen;
                aw_id_l <= m_awid;
            end
            if(m_wvalid && m_wready) begin
                w_beats <= w_beats + 1;
                w_seen <= 1;
                w_data_l <= m_wdata;
                w_strb_l <= m_wstrb;
                w_last_seen <= m_wlast;
            end
            // commit the store once both halves arrived (order independent)
            if(aw_seen && w_seen && !applied) begin
                applied <= 1;
                if(!inject_b)
                    mem[aw_addr_l[13:2]] <= apply_strb(mem[aw_addr_l[13:2]],
                                                       w_data_l, w_strb_l);
                m_bvalid <= 1;
                m_bid <= aw_id_l;
                m_bresp <= inject_b ? 2'b10 : 2'b00;
                b_pending <= 1;
            end else if(m_bvalid && m_bready) begin
                m_bvalid <= 0;
                aw_seen <= 0; w_seen <= 0; applied <= 0; b_pending <= 0;
            end
        end
    end

    // ---------------- stimulus ----------------
    integer errors = 0;
    integer b0 = 0, w0 = 0;
    reg [31:0] got_data = 0;
    reg [1:0]  got_resp = 0;
    reg [31:0] exp_now = 0;

    task fail(input [255:0] what);
        begin
            errors = errors + 1;
            $display("  FAIL %0s (data=%08x resp=%0d bursts=%0d writes=%0d)",
                     what, got_data, got_resp, ar_bursts, aw_writes);
        end
    endtask

    task rd(input [255:0] what, input [31:0] addr, input [31:0] exp,
            input [1:0] exp_resp, input integer exp_bursts);
        begin
            b0 = ar_bursts;
            @(negedge clk);
            req_addr = addr; req_write = 0; req_size = 3'd2; req_len = 8'd0;
            req_id = 4'h7; req_valid = 1; rsp_ready = 0;
            // A request is only taken when req_ready is high.  The old version
            // dropped req_valid after one edge regardless, so a request issued
            // while the cache was still busy was silently lost and the task hung
            // (review 2026-10-18: this is why D3 timed out from D2's tail).
            while(!req_ready) @(negedge clk);
            @(posedge clk);
            @(negedge clk);
            req_valid = 0; rsp_ready = 1;
            while(!rsp_valid) @(negedge clk);
            got_data = rsp_data; got_resp = rsp_resp;
            @(negedge clk);
            rsp_ready = 0;
            if(exp_resp !== 2'b00) begin
                if(got_resp !== exp_resp) fail(what);
                else if((ar_bursts - b0) !== exp_bursts)
                    $display("  FAIL %0s burst count %0d expected %0d",
                             what, ar_bursts - b0, exp_bursts);
                else $display("  ok   %0s addr=%08x resp=%0d (payload ignored) bursts=%0d",
                              what, addr, got_resp, ar_bursts - b0);
            end else if(got_data !== exp) fail(what);
            else if(got_resp !== exp_resp) fail(what);
            else if((ar_bursts - b0) !== exp_bursts)
                $display("  FAIL %0s burst count %0d expected %0d",
                         what, ar_bursts - b0, exp_bursts);
            else $display("  ok   %0s addr=%08x data=%08x resp=%0d bursts=%0d",
                          what, addr, got_data, got_resp, ar_bursts - b0);
        end
    endtask

    // A store driven the way lsu_axi actually drives one (optimization P34 test
    // bring-up).  The LSU presents the W beat ON THE ACCEPT EDGE -- wdata_on_iss
    // in lsu_axi.v -- and never waits for w_ready on that path, because the cache
    // latches w_data/w_strb into wdata_q itself.  The previous version of this
    // task asserted w_valid one cycle AFTER the accept and then waited for
    // w_ready, which no store can ever satisfy: the inner write engine takes its
    // W beat from the cache, not from the testbench.  That is why D3 timed out
    // (docs/plan-3.5-3.8.md 4.10).  b_ready is high from the accept edge so an
    // early release (data-RAM window) is taken there; otherwise the cache parks
    // in ST_WR_HOLD and hands the response over when it arrives.
    task wr(input [255:0] what, input [31:0] addr, input [31:0] data,
            input [3:0] strb, input [1:0] exp_bresp, input integer exp_writes);
        begin
            w0 = aw_writes;
            @(negedge clk);
            req_addr = addr; req_write = 1; req_size = 3'd2; req_len = 8'd0;
            req_id = 4'h3; req_valid = 1;
            w_data = data; w_strb = strb; w_last = 1; w_valid = 1;
            b_ready = 1;
            #1;
            while(!req_ready) begin          // see the note in rd()
                @(negedge clk); #1;
            end
            @(posedge clk);                  // accept edge
            @(negedge clk);
            req_valid = 0; w_valid = 0;
            #1;
            while(!b_valid) begin
                @(negedge clk); #1;
            end
            got_resp = b_resp;
            @(negedge clk);
            b_ready = 0;
            if(got_resp !== exp_bresp) fail(what);
            else if((aw_writes - w0) !== exp_writes)
                $display("  FAIL %0s write count %0d expected %0d",
                         what, aw_writes - w0, exp_writes);
            else $display("  ok   %0s addr=%08x strb=%b bresp=%0d writes=%0d",
                          what, addr, strb, got_resp, aw_writes - w0);
        end
    endtask

    // One store, presented the way lsu_axi fast-issue does it: request AND W beat
    // on the same edge, b_ready high.  Nothing is waited for, so a run of calls
    // exercises "can the cache take another store while the previous one drains".
    // `accepted` is the handshake on that edge; `bseen`/`bresp` are the early
    // release the CPU would see in the same cycle.
    task automatic store_beat(input [31:0] addr, input [31:0] data, input [3:0] strb,
                              output accepted, output bseen, output [1:0] bresp);
        begin
            req_addr = addr; req_write = 1; req_size = 3'd2; req_len = 8'd0;
            req_id = 4'h3; req_valid = 1;
            w_data = data; w_strb = strb; w_last = 1; w_valid = 1;
            b_ready = 1;
            #1;                        // let the combinational req_ready settle
            accepted = req_ready;
            bseen    = b_valid;
            bresp    = b_resp;
            @(posedge clk);
            @(negedge clk);
            req_valid = 0; w_valid = 0; b_ready = 0;
        end
    endtask

    reg st_acc0, st_acc1, st_acc2, st_b0, st_b1, st_b2, rd_acc;
    reg [1:0] st_r0, st_r1, st_r2;
    integer w_base = 0;
    integer dw = 0;

    initial begin
        repeat(4) @(negedge clk);
        rst_n = 1;
        repeat(2) @(negedge clk);

        // ---------------- G1: set 0 (addr[9:5]==0) -------------------------
        // D1/D2: cold miss then a sequential hit inside the same 32 B line.
        rd("D1 cold miss", 32'h0000_0000, mem[0], 2'b00, 1);
        if(ar_len_seen !== 8'd7 || ar_size_seen !== 3'd2 || ar_burst_seen !== 2'b01)
            $display("  FAIL D1 burst descriptor len=%0d size=%0d burst=%0d",
                     ar_len_seen, ar_size_seen, ar_burst_seen);
        if(beats_out !== 8) $display("  FAIL D1 burst beats %0d", beats_out);
        rd("D2 sequential hit", 32'h0000_0004, mem[1], 2'b00, 0);

        // D3: write hit -> write-through and the line holds the new word.
        wr("D3 write hit", 32'h0000_0000, 32'hDEADBEEF, 4'hF, 2'b00, 1);
        if(aw_len_seen !== 8'd0) $display("  FAIL D3 awlen=%0d", aw_len_seen);
        if(!w_last_seen) $display("  FAIL D3 wlast not asserted");
        if(mem[0] !== 32'hDEADBEEF) $display("  FAIL D3 memory not written: %08x", mem[0]);
        rd("D3 cached merge", 32'h0000_0000, 32'hDEADBEEF, 2'b00, 0);

        // D4: byte-lane store into a cached line keeps the other bytes.
        wr("D4 byte write hit", 32'h0000_0004, 32'h00003300, 4'b0010, 2'b00, 1);
        if(mem[1] !== 32'hB0003301)
            $display("  FAIL D4 neighbouring bytes lost: %08x", mem[1]);
        rd("D4 merged bytes", 32'h0000_0004, 32'hB0003301, 2'b00, 0);

        // ---------------- G2: set 1 (addr[9:5]==1) -------------------------
        // D5: write miss -> single write, no refill, no allocation.
        wr("D5 write miss", 32'h0000_0020, 32'h11223344, 4'hF, 2'b00, 1);
        exp_now = apply_strb(mem[8], 32'h11223344, 4'hF);
        if(mem[8] !== exp_now) $display("  FAIL D5 memory not written: %08x", mem[8]);
        rd("D5 no allocate, refetch", 32'h0000_0020, exp_now, 2'b00, 1);

        // D6: two-way conflict + LRU inside set 1.
        rd("D6 A hit", 32'h0000_0020, exp_now, 2'b00, 0);
        rd("D6 B miss", 32'h0000_0420, mem[264], 2'b00, 1);
        rd("D6 A hit again", 32'h0000_0020, exp_now, 2'b00, 0);
        rd("D6 C evicts B", 32'h0000_0820, mem[520], 2'b00, 1);
        rd("D6 B miss again", 32'h0000_0420, mem[264], 2'b00, 1);
        rd("D6 C hit", 32'h0000_0820, mem[520], 2'b00, 0);

        // ---------------- G3: set 2 (addr[9:5]==2) -------------------------
        // D7: mid-burst read error -> SLVERR reaches the core, no validation.
        inject_at = 3;
        rd("D7 refill error", 32'h0000_0040, 32'h0, 2'b10, 1);
        inject_at = -1;
        rd("D7 line not cached", 32'h0000_0040, mem[16], 2'b00, 1);

        // D8: store error -> SLVERR, memory untouched, line invalidated.
        rd("D8 prime line", 32'h0000_1040, mem[1040], 2'b00, 1);
        inject_b = 1;
        wr("D8 store error", 32'h0000_1040, 32'hCAFEBABE, 4'hF, 2'b10, 1);
        inject_b = 0;
        if(mem[1040] !== (32'hB0000000 + 1040))
            $display("  FAIL D8 failed store reached memory: %08x", mem[1040]);
        rd("D8 line invalidated", 32'h0000_1040, mem[1040], 2'b00, 1);

        // ---------------- G4: MMIO bypass ----------------------------------
        rd("D9 mmio read", 32'h2000_0000, mem[0], 2'b00, 1);
        rd("D9 mmio read again", 32'h2000_0000, mem[0], 2'b00, 1);
        wr("D9 mmio write", 32'h2000_0000, 32'h12345678, 4'hF, 2'b00, 1);
        if(mem[0] !== 32'h12345678)
            $display("  FAIL D9 mmio memory not written: %08x", mem[0]);
        // the cached copy of 0x000 must be untouched by the MMIO window
        rd("D9 cache untouched", 32'h0000_0000, 32'hDEADBEEF, 2'b00, 0);

        // ---------------- G5: posted store queue (P34) ----------------------
        // Data-RAM stores (0x1000_0000..0x1000_3FFF) are answered before the AXI
        // B returns.  With a one-entry post buffer only ONE extra store fits while
        // the previous one drains; the queue must absorb a short run.
        w_base = aw_writes;
        // E1: three back-to-back stores, none of them waiting for a B.
        store_beat(32'h1000_0000, 32'h1111_0000, 4'hF, st_acc0, st_b0, st_r0);
        store_beat(32'h1000_0004, 32'h2222_0004, 4'hF, st_acc1, st_b1, st_r1);
        store_beat(32'h1000_0008, 32'h3333_0008, 4'hF, st_acc2, st_b2, st_r2);
        if(!st_acc0 || !st_acc1) begin
            errors = errors + 1;
            $display("  FAIL E1 first/second store refused (%b/%b)", st_acc0, st_acc1);
        end else if(!st_acc2) begin
            errors = errors + 1;
            $display("  FAIL E1 third back-to-back store refused: queue depth is still 1");
        end else if(!st_b0 || st_r0 !== 2'b00) begin
            errors = errors + 1;
            $display("  FAIL E1 store0 not answered early (bseen=%b bresp=%b)", st_b0, st_r0);
        end else $display("  ok   E1 three back-to-back data-RAM stores accepted");

        // E5a: idle must stay low while the writes are still outstanding.
        if(dc_idle) begin
            errors = errors + 1;
            $display("  FAIL E5a dc_idle high with queued writes");
        end

        // E2: every queued write reaches memory, in program order.
        dw = 0;
        while(!dc_idle && dw < 400) begin @(negedge clk); dw = dw + 1; end
        if(!dc_idle)
            $display("  E2_STUCK state=%0d q=%0d drain=%b wsent=%b wreq=%b ireqr=%b",
                     dut.state_q, dut.q_count_q, dut.drain_q, dut.wsent_q,
                     dut.wreq_q, dut.i_req_valid_r);
        if(st_acc2) begin
            if(mem[0] !== 32'h1111_0000 || mem[1] !== 32'h2222_0004 ||
               mem[2] !== 32'h3333_0008) begin
                errors = errors + 1;
                $display("  FAIL E2 queued writes landed as %08x/%08x/%08x",
                         mem[0], mem[1], mem[2]);
            end else if((aw_writes - w_base) !== 3) begin
                errors = errors + 1;
                $display("  FAIL E2 write count %0d expected 3", aw_writes - w_base);
            end else $display("  ok   E2 all three queued writes landed in order");
        end

        // E5b: idle only after the queue drained.
        if(!dc_idle) begin
            errors = errors + 1;
            $display("  FAIL E5b dc_idle low after the queue drained");
        end

        // E3: the write merge happens on the ACCEPT edge, so a load that HITS the
        // same line must already see the new word while the write is queued.
        rd("E3 prime line", 32'h1000_0100, mem[64], 2'b00, 1);
        store_beat(32'h1000_0100, 32'hAABBCCDD, 4'hF, st_acc0, st_b0, st_r0);
        rd("E3 merged while queued", 32'h1000_0100, 32'hAABBCCDD, 2'b00, 0);

        // E4: a read MISS must not overtake queued / draining writes.
        store_beat(32'h1000_0040, 32'h5555_0040, 4'hF, st_acc0, st_b0, st_r0);
        store_beat(32'h1000_0044, 32'h6666_0044, 4'hF, st_acc1, st_b1, st_r1);
        req_addr = 32'h1000_0800; req_write = 0; req_size = 3'd2; req_len = 8'd0;
        req_id = 4'h5; req_valid = 1;
        #1;
        rd_acc = req_ready;
        req_valid = 0;
        if(rd_acc) begin
            errors = errors + 1;
            $display("  FAIL E4 read miss accepted while writes were queued");
        end else $display("  ok   E4 read miss held off until the queue drains");
        while(!dc_idle) @(negedge clk);
        if(mem[16] !== 32'h5555_0040 || mem[17] !== 32'h6666_0044) begin
            errors = errors + 1;
            $display("  FAIL E4 queued writes lost: %08x/%08x", mem[16], mem[17]);
        end

        if(protocol_fault) begin
            errors = errors + 1;
            $display("  FAIL unexpected protocol_fault");
        end
        if(config_fault) begin
            errors = errors + 1;
            $display("  FAIL unexpected config_fault");
        end

        if(errors == 0) $display("TEST_PASS DCACHE");
        else $display("TEST_FAIL DCACHE errors=%0d", errors);
        $finish;
    end

    // cached value of 0x000 after D3 (the D9 MMIO write must not change it)
    function [31:0] exp_now_exp;
        begin
            exp_now_exp = apply_strb(32'hB0000000, 32'hDEADBEEF, 4'hF);
        end
    endfunction

    initial begin
        #200000;
        $display("TEST_FAIL DCACHE timeout");
        $finish;
    end
endmodule
