//=============================================================================
// pangoriscv - RV32IM processor core + native AXI4 SoC (Pango PG2L100H @ 27 MHz)
// Module : tb_icache_contract     File : tb/unit/tb_icache_contract.sv
// Rev    : 1.1                    Date : 2026-10-17
// Author : pango_lpenghan
// Brief  : Contract test for the T4 I-cache handshake (same-cycle replace on a
//          hit: req_ready may rise in IC_RESP while the current response is
//          consumed).  Written before the RTL change is accepted; it pins only
//          externally visible behaviour.
//
// Contract items exercised here (see results/frontend_contract.md):
//   C1  a hit may be accepted in the same cycle the previous response leaves,
//       so a pre-warmed linear stream sustains one accept per cycle
//   C3  a response always belongs to the request that was accepted (data = mem)
//   C4  hit -> miss -> hit: the miss still blocks, and hits resume afterwards
//   C5  with rsp_ready low, rsp_valid and rsp_data must stay stable
//   C7  invalidate during a fill: the line must not become valid afterwards
//=============================================================================
`timescale 1ns/1ps
module tb_icache_contract;

    reg clk = 0;
    always #5 clk = ~clk;

    reg rst_n = 0;
    reg invalidate = 0;

    reg req_valid = 0;
    wire req_ready;
    reg [31:0] req_addr = 0;
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
    reg [7:0] beats_left = 0;      // beats still to present AFTER the current one
    reg [31:0] cur_addr = 0;
    reg [3:0] cur_id = 0;
    integer beat_of = 0;           // index of the currently presented beat

    always @(posedge clk) begin
        if(!rst_n) begin
            bursts <= 0; m_rvalid_r <= 0; m_rlast_r <= 0; beats_left <= 0;
            m_rresp_r <= 2'b00; beat_of <= 0;
        end else if(m_arvalid && m_arready && !m_rvalid_r) begin
            bursts <= bursts + 1;
            beats_left <= m_arlen;                 // ARLEN+1 beats, first one now
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

    // ---------------- response pairing monitor (C3) ----------------
    // Every accepted request produces exactly one response, in order.  The
    // expected word is captured at the accept edge from the accepted address,
    // so this check is independent of how the driver paces things.
    reg [31:0] expq [0:255];
    integer qh = 0, qt = 0;
    integer rsp_cnt = 0;

    always @(posedge clk) begin
        if(rst_n) begin
            if(req_valid && req_ready) begin
                expq[qt] = mem[req_addr[13:2]];
                qt = qt + 1;
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

    // wait until no response is pending and the queue is drained
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

    // ---------------- contract measurements ----------------
    integer accepts = 0;
    integer clocks = 0;
    integer bursts_before = 0;
    reg [31:0] d;

    initial begin
        req_valid = 0; rsp_ready = 1; invalidate = 0;
        repeat(4) @(posedge clk);
        @(negedge clk); rst_n = 1;
        repeat(2) @(posedge clk);

        // ---- warm two lines (0x1000, 0x1020): the stream below is all hits
        one(32'h00001000, d);
        if(d !== mem[32'h1000>>2]) fail("WARM_DATA_A");
        one(32'h00001020, d);
        if(d !== mem[32'h1020>>2]) fail("WARM_DATA_B");
        drain;

        // ---- C1 (throughput) + C3 (pairing, checked by the monitor)
        //      Hold one pre-warmed hit address with rsp_ready high: after the
        //      pipeline fills, req_ready must be high every cycle, i.e. one
        //      accept per clock.
        @(negedge clk);
        req_valid = 1; rsp_ready = 1; req_addr = 32'h00001004;
        accepts = 0;
        repeat(20) begin
            @(negedge clk);
            if(req_ready) accepts = accepts + 1;
        end
        req_valid = 0;
        drain;
        if(accepts < 18) fail("C1_NOT_ONE_PER_CLOCK");

        // ---- C5 (backpressure): request a hit, then hold rsp_ready low
        @(negedge clk);
        req_valid = 1; req_addr = 32'h00001008; rsp_ready = 0;
        while(!req_ready) @(negedge clk);
        @(negedge clk); req_valid = 0;
        while(!rsp_valid) @(negedge clk);
        d = rsp_data;
        repeat(4) begin
            @(negedge clk);
            if(!rsp_valid)     fail("C5_VALID_DROPPED");
            if(rsp_data !== d) fail("C5_DATA_MOVED");
        end
        rsp_ready = 1;
        drain;

        // ---- C4 (hit -> miss -> hit): the unwarmed line must still block on a
        //      fill, then hits resume immediately.
        bursts_before = bursts;
        one(32'h00002000, d);
        if(d !== mem[32'h2000>>2]) fail("C4_FILL_DATA");
        if(bursts != bursts_before + 1) fail("C4_NO_FILL_BURST");
        one(32'h00002004, d);
        if(d !== mem[32'h2004>>2]) fail("C4_HIT_AFTER_FILL");
        drain;

        // ---- C7 (invalidate in flight): the interrupted line must not become
        //      valid, so re-reading it starts a new fill.
        @(negedge clk);
        req_valid = 1; req_addr = 32'h00003000;
        while(!req_ready) @(negedge clk);
        @(negedge clk); req_valid = 0;
        while(!m_rvalid) @(negedge clk);
        invalidate = 1;
        @(negedge clk);
        invalidate = 0;
        drain;
        bursts_before = bursts;
        one(32'h00003000, d);
        if(bursts != bursts_before + 1) fail("C7_LINE_VALIDATED_AFTER_INVALIDATE");

        $display("TEST_PASS ICACHE_CONTRACT accepts=%0d rsp=%0d bursts=%0d", accepts, rsp_cnt, bursts);
        $finish;
    end

    initial begin
        #400000;
        $display("** Fatal: ICACHE_CONTRACT_TIMEOUT");
        $finish;
    end

endmodule
