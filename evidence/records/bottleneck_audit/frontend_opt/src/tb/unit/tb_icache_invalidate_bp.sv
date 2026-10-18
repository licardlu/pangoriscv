//=============================================================================
// pangoriscv - phase1 acceptance extension test
// Module : tb_icache_invalidate_bp   File : tb/unit/tb_icache_invalidate_bp.sv
// Brief  : Two contract corners that the T4 candidate I-cache change newly
//          exposes, checked from external behaviour only:
//
//   A1  random downstream backpressure on the response channel.  A held
//       response may never drop or change its payload, and every response must
//       still belong to the request that was accepted (pairing monitor always
//       active) even while accepts and consumes overlap on the same edge.
//   A2  invalidate landing on the same-cycle hit/replace stream: the line must
//       not stay valid, the next lookup of that line must refill from memory,
//       and the hit answered in the invalidate cycle must stay data-correct.
//   A3  invalidate while a hit response is held by rsp_ready=0: the held
//       response must stay stable and data-correct, and the line must be
//       invalid afterwards (next lookup refills).
//=============================================================================
`timescale 1ns/1ps
module tb_icache_invalidate_bp;

    reg clk = 0;
    always #5 clk = ~clk;

    reg rst_n = 0;
    reg invalidate = 0;

    reg req_valid = 0;
    wire req_ready;
    reg [31:0] req_addr = 32'h00001000;
    reg [2:0] req_size = 3'd2;
    reg [7:0] req_len = 8'd7;
    reg [3:0] req_id = 4'd0;

    wire rsp_valid;
    reg rsp_ready = 1;
    wire [31:0] rsp_data;
    wire [1:0] rsp_resp;
    wire [3:0] rsp_id;
    wire protocol_fault, config_fault, miss_pulse, access_pulse;

    wire m_arvalid;
    wire m_arready = 1;
    wire [31:0] m_araddr;
    wire [3:0] m_arid;
    wire [7:0] m_arlen;
    wire [2:0] m_arsize;
    wire [1:0] m_arburst;
    wire m_arlock;
    wire [3:0] m_arcache;
    wire [2:0] m_arprot;
    wire [3:0] m_arqos;
    wire m_rvalid;
    wire m_rready;
    wire [31:0] m_rdata;
    wire [3:0] m_rid;
    wire [1:0] m_rresp;
    wire m_rlast;

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

    // ---------------- memory image + INCR AXI slave ----------------
    reg [31:0] mem [0:4095];
    integer i;
    initial for(i=0;i<4096;i=i+1) mem[i] = 32'hC0DE0000 + i;

    reg m_rvalid_r = 0, m_rlast_r = 0;
    reg [31:0] m_rdata_r = 0;
    reg [3:0] m_rid_r = 0;
    reg [1:0] m_rresp_r = 2'b00;
    assign m_rvalid = m_rvalid_r;
    assign m_rdata  = m_rdata_r;
    assign m_rid    = m_rid_r;
    assign m_rresp  = m_rresp_r;
    assign m_rlast  = m_rlast_r;

    integer bursts = 0;
    reg [7:0] beats_left = 0;
    reg [31:0] cur_addr = 0;
    reg [3:0] cur_id = 0;
    integer beat_of = 0;

    always @(posedge clk) begin
        if(!rst_n) begin
            bursts <= 0; m_rvalid_r <= 0; m_rlast_r <= 0; beats_left <= 0;
            m_rresp_r <= 2'b00; beat_of <= 0;
        end else if(m_arvalid && m_arready && !m_rvalid_r) begin
            bursts <= bursts + 1;
            beats_left <= m_arlen;
            cur_addr <= m_araddr;
            cur_id <= m_arid;
            m_rvalid_r <= 1; m_rlast_r <= (m_arlen == 8'd0);
            m_rdata_r <= mem[m_araddr[13:2]];
            m_rid_r <= m_arid;
            m_rresp_r <= 2'b00;
            beat_of <= 0;
        end else if(m_rvalid_r && m_rready) begin
            if(beats_left == 0) begin
                m_rvalid_r <= 0; m_rlast_r <= 0;
            end else begin
                beat_of <= beat_of + 1;
                m_rdata_r <= mem[cur_addr[13:2] + beat_of + 1];
                m_rid_r <= cur_id;
                m_rresp_r <= 2'b00;
                m_rvalid_r <= 1;
                m_rlast_r <= (beats_left == 1);
                beats_left <= beats_left - 1;
            end
        end
    end

    // ---------------- response pairing monitor (C3, always on) ----------------
    reg [31:0] expq [0:1023];
    integer qh = 0, qt = 0;
    integer rsp_cnt = 0;
    integer accepts = 0;

    always @(posedge clk) begin
        if(rst_n) begin
            if(req_valid && req_ready) begin
                expq[qt] = mem[req_addr[13:2]];
                qt = qt + 1;
                accepts = accepts + 1;
                if(qt - qh > 200) begin
                    $display("** Fatal: C3_PAIRING_OVERFLOW");
                    $fatal(1);
                end
            end
            if(rsp_valid && rsp_ready) begin
                if(qh == qt) begin
                    $display("** Fatal: C3_UNEXPECTED_RSP data=%h", rsp_data);
                    $fatal(1);
                end
                if(rsp_data !== expq[qh]) begin
                    $display("** Fatal: C3_RSP_DATA_MISMATCH got=%h exp=%h", rsp_data, expq[qh]);
                    $fatal(1);
                end
                qh = qh + 1;
                rsp_cnt = rsp_cnt + 1;
            end
        end
    end

    // ---------------- held-response stability monitor (C5 extended) ----------
    reg prev_held = 0;
    reg [31:0] held_data = 0;
    reg [1:0] held_resp = 0;
    always @(posedge clk) begin
        if(!rst_n) begin
            prev_held <= 0;
        end else if(rsp_valid && !rsp_ready) begin
            if(prev_held) begin
                if(rsp_data !== held_data) begin
                    $display("** Fatal: A1_DATA_MOVED_WHILE_HELD got=%h exp=%h", rsp_data, held_data);
                    $fatal(1);
                end
                if(rsp_resp !== held_resp) begin
                    $display("** Fatal: A1_RESP_MOVED_WHILE_HELD got=%b exp=%b", rsp_resp, held_resp);
                    $fatal(1);
                end
            end
            prev_held <= 1;
            held_data <= rsp_data;
            held_resp <= rsp_resp;
        end else begin
            prev_held <= 0;
        end
    end

    // ---------------- helpers ----------------
    task fail(input [255:0] what);
        begin
            $display("** Fatal: %0s (t=%0t)", what, $time);
            $fatal(1);
        end
    endtask

    task one(input [31:0] a, output [31:0] d);
        integer guard;
        begin
            @(negedge clk);
            req_valid = 1; req_addr = a;
            guard = 0;
            while(!req_ready) begin
                @(negedge clk);
                guard = guard + 1;
                if(guard > 400) fail("REQ_TIMEOUT");
            end
            @(negedge clk);
            req_valid = 0;
            guard = 0;
            while(!rsp_valid) begin
                @(negedge clk);
                guard = guard + 1;
                if(guard > 500) fail("RSP_TIMEOUT");
            end
            d = rsp_data;
            @(negedge clk);
        end
    endtask

    task drain;
        integer guard;
        begin
            guard = 0;
            while(rsp_valid || qh != qt) begin
                @(negedge clk);
                guard = guard + 1;
                if(guard > 1000) fail("DRAIN_TIMEOUT");
            end
        end
    endtask

    integer accepts_start = 0;
    integer bp_cycles = 0;
    integer bursts_before = 0;
    reg [31:0] d;
    reg [15:0] lfsr = 16'hACE1;
    integer guard;
    reg auto_addr = 1;

    // advance the hit address once per accepted request (A1 stream)
    always @(posedge clk) begin
        if(rst_n && auto_addr && req_valid && req_ready)
            req_addr <= 32'h00001000 + {3'b0, (req_addr[4:2] + 3'd1)} * 32'd4;
    end

    initial begin
        req_valid = 0; rsp_ready = 1; invalidate = 0; auto_addr = 1;
        repeat(4) @(posedge clk);
        @(negedge clk); rst_n = 1;
        repeat(2) @(posedge clk);

        // ---- warm the line used by A1/A2/A3 ----
        auto_addr = 0;
        one(32'h00001000, d);
        if(d !== mem[32'h1000>>2]) fail("WARM_DATA");
        auto_addr = 1;
        drain;
        if(protocol_fault !== 1'b0 || config_fault !== 1'b0) fail("PROTOCOL_FAULT_WARM");

        // ================= A1: random backpressure, pairing always checked ====
        accepts_start = accepts;
        bp_cycles = 0;
        @(negedge clk);
        req_valid = 1; rsp_ready = 1; auto_addr = 1;
        repeat(400) begin
            @(negedge clk);
            lfsr = {lfsr[14:0], lfsr[15] ^ lfsr[13]};
            if(rsp_valid && !rsp_ready) bp_cycles = bp_cycles + 1;
            rsp_ready = (lfsr[0] & lfsr[1]) | lfsr[3];
        end
        req_valid = 0; rsp_ready = 1;
        drain;
        if((accepts - accepts_start) < 200) fail("A1_THROUGHPUT");
        if(bp_cycles < 30) fail("A1_BACKPRESSURE_NOT_EXERCISED");
        if(rsp_cnt !== accepts) fail("A1_RSP_COUNT_MISMATCH");
        if(protocol_fault !== 1'b0 || config_fault !== 1'b0) fail("PROTOCOL_FAULT_A1");
        $display("INFO A1 accepts=%0d rsp=%0d bursts=%0d bp_cycles=%0d",
                 accepts - accepts_start, rsp_cnt, bursts, bp_cycles);

        // ================= A2: invalidate on the same-cycle replace path ======
        // The line is valid; stream hits with req_valid held so accepts overlap
        // the response state, then invalidate one cycle in the middle.
        bursts_before = bursts;
        auto_addr = 0;
        @(negedge clk);
        req_valid = 1; req_addr = 32'h00001004; rsp_ready = 1;
        repeat(6) @(negedge clk);
        invalidate = 1;
        @(negedge clk);
        invalidate = 0;
        repeat(6) @(negedge clk);
        req_valid = 0;
        drain;
        if(bursts == bursts_before) fail("A2_NO_REFILL_AFTER_INVALIDATE");
        if(protocol_fault !== 1'b0 || config_fault !== 1'b0) fail("PROTOCOL_FAULT_A2");

        // Explicit: invalidate a clean line, the next lookup must refill it.
        bursts_before = bursts;
        @(negedge clk); invalidate = 1;
        @(negedge clk); invalidate = 0;
        drain;
        one(32'h00001004, d);
        if(d !== mem[32'h1004>>2]) fail("A2_FILL_DATA");
        if(bursts != bursts_before + 1) fail("A2_SECOND_REFILL_MISSING");
        drain;

        // ================= A3: invalidate while a hit response is held ========
        @(negedge clk);
        req_valid = 1; req_addr = 32'h00001008; rsp_ready = 1;
        guard = 0;
        while(!req_ready) begin
            @(negedge clk); guard = guard + 1;
            if(guard > 100) fail("A3_REQ_TIMEOUT");
        end
        @(negedge clk);
        req_valid = 0; rsp_ready = 0;
        guard = 0;
        while(!rsp_valid) begin
            @(negedge clk); guard = guard + 1;
            if(guard > 100) fail("A3_RSP_TIMEOUT");
        end
        d = rsp_data;
        @(negedge clk);
        invalidate = 1;
        @(negedge clk);
        invalidate = 0;
        repeat(2) @(negedge clk);
        if(!rsp_valid) fail("A3_VALID_DROPPED_BY_INVALIDATE");
        if(rsp_data !== d) fail("A3_HELD_DATA_MOVED");
        rsp_ready = 1;
        drain;
        bursts_before = bursts;
        one(32'h00001008, d);
        if(d !== mem[32'h1008>>2]) fail("A3_REFILL_DATA");
        if(bursts != bursts_before + 1) fail("A3_NO_REFILL_AFTER_INVALIDATE");
        drain;
        if(protocol_fault !== 1'b0 || config_fault !== 1'b0) fail("PROTOCOL_FAULT_A3");

        $display("TEST_PASS ICACHE_INVALIDATE_BP accepts=%0d rsp=%0d bursts=%0d bp_cycles=%0d",
                 accepts, rsp_cnt, bursts, bp_cycles);
        $finish;
    end

    initial begin
        #400000;
        $display("** Fatal: ICACHE_INVALIDATE_BP_TIMEOUT");
        $finish;
    end

endmodule
