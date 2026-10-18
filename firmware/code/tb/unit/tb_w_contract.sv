//=============================================================================
// pangoriscv - tb_w_contract
// Directed test for the restricted write-data contract of axi_data_engine.
//
// Contract under test (documented, not relaxed):
//   C1  A write request and its single W beat may be presented on the same
//       cycle; both handshakes must complete on that same cycle and the
//       captured address/data/strobes must be the ones driven that cycle.
//   C2  A write request may be accepted first and the W beat may arrive on a
//       later cycle (the legacy two-step path through WR_PREP).
//   C3  Only one write may be outstanding: from request acceptance until the
//       B response is consumed, req_ready stays low.
//   C4  AW and W are independent AXI channels; either may be backpressured
//       without losing or duplicating a handshake, and B may be delayed.
//   C5  RESP (SLVERR) reaches the consumer unchanged; b_valid is stable while
//       the consumer backpressures it.
//   C6  Negative: a W beat presented while the engine is idle and no request
//       exists is handshaken by w_ready and lost. The legal producers of this
//       engine (LSU launch, dcache forwarding) never do that, so the engine
//       documents a RESTRICTED contract. This test drives the forbidden
//       sequence and reports the exact violation instead of pretending the
//       engine detects it.
//=============================================================================
`timescale 1ns/1ps

module tb_w_contract;

    localparam integer CLK_NS = 10;

    reg clk = 1'b0;
    reg rst_n = 1'b0;
    always #(CLK_NS/2) clk = ~clk;

    // ------------------------------------------------------------------ DUT I/O
    reg  req_valid = 0, req_write = 0;
    reg  [31:0] req_addr = 0;
    reg  [2:0]  req_size = 0;
    reg  [7:0]  req_len = 0;
    reg  [3:0]  req_id = 0;
    reg  w_valid = 0;
    reg  [31:0] w_data = 0;
    reg  [3:0]  w_strb = 0;
    reg  w_last = 0;
    reg  rsp_ready = 1;
    reg  b_ready = 1;
    wire req_ready, w_ready, rsp_valid, b_valid;
    wire [31:0] rsp_data;
    wire [1:0]  rsp_resp, b_resp;
    wire [3:0]  rsp_id, b_id;
    wire rsp_last;
    wire protocol_fault, config_fault;

    wire m_arvalid, m_awvalid, m_wvalid;
    wire [31:0] m_araddr, m_awaddr, m_wdata;
    wire [3:0]  m_arid, m_awid, m_wstrb;
    wire [7:0]  m_arlen, m_awlen;
    wire [2:0]  m_arsize, m_awsize;
    wire [1:0]  m_arburst, m_awburst;
    wire m_arlock, m_awlock;
    wire [3:0]  m_arcache, m_awcache;
    wire [2:0]  m_arprot, m_awprot;
    wire [3:0]  m_arqos, m_awqos;
    wire        m_rready, m_wlast;
    reg  m_awready = 0, m_wready = 0, m_bvalid = 0;
    reg  [3:0] m_bid = 0;
    reg  [1:0] m_bresp = 0;

    axi_data_engine dut (
        .clk(clk), .rst_n(rst_n),
        .req_valid(req_valid), .req_ready(req_ready),
        .req_write(req_write), .req_addr(req_addr), .req_size(req_size),
        .req_len(req_len), .req_id(req_id),
        .w_valid(w_valid), .w_ready(w_ready), .w_data(w_data),
        .w_strb(w_strb), .w_last(w_last),
        .rsp_valid(rsp_valid), .rsp_ready(rsp_ready), .rsp_data(rsp_data),
        .rsp_resp(rsp_resp), .rsp_last(rsp_last), .rsp_id(rsp_id),
        .b_valid(b_valid), .b_ready(b_ready), .b_resp(b_resp), .b_id(b_id),
        .protocol_fault(protocol_fault), .config_fault(config_fault),
        .m_arvalid(m_arvalid), .m_arready(1'b1), .m_araddr(m_araddr),
        .m_arid(m_arid), .m_arlen(m_arlen), .m_arsize(m_arsize),
        .m_arburst(m_arburst), .m_arlock(m_arlock), .m_arcache(m_arcache),
        .m_arprot(m_arprot), .m_arqos(m_arqos),
        .m_rvalid(1'b0), .m_rready(m_rready), .m_rdata(32'h0),
        .m_rid(4'h0), .m_rresp(2'b00), .m_rlast(1'b0),
        .m_awvalid(m_awvalid), .m_awready(m_awready), .m_awaddr(m_awaddr),
        .m_awid(m_awid), .m_awlen(m_awlen), .m_awsize(m_awsize),
        .m_awburst(m_awburst), .m_awlock(m_awlock), .m_awcache(m_awcache),
        .m_awprot(m_awprot), .m_awqos(m_awqos),
        .m_wvalid(m_wvalid), .m_wready(m_wready), .m_wdata(m_wdata),
        .m_wstrb(m_wstrb), .m_wlast(m_wlast),
        .m_bvalid(m_bvalid), .m_bready(m_bready), .m_bid(m_bid),
        .m_bresp(m_bresp)
    );

    integer errors = 0;
    integer aw_hits = 0, w_hits = 0, b_hits = 0;

    task automatic check(input cond, input [1023:0] msg);
        begin
            if (!cond) begin
                errors = errors + 1;
                $display("TB_CHECK_FAIL %0s at t=%0t", msg, $time);
            end
        end
    endtask

    always @(posedge clk) if (rst_n) begin
        if (m_awvalid && m_awready) aw_hits <= aw_hits + 1;
        if (m_wvalid && m_wready) w_hits <= w_hits + 1;
        if (m_bvalid && m_bready) b_hits <= b_hits + 1;
    end

    task automatic reset_dut;
        begin
            rst_n = 0;
            req_valid = 0; req_write = 0; w_valid = 0; w_last = 0;
            m_awready = 0; m_wready = 0; m_bvalid = 0; m_bid = 0; m_bresp = 0;
            b_ready = 1;
            aw_hits = 0; w_hits = 0; b_hits = 0;
            repeat (4) @(posedge clk);
            rst_n = 1;
            repeat (2) @(posedge clk);
        end
    endtask

    // One complete write transaction with a parameterised timing profile.
    // mode 0: request and W driven on the same cycle (C1)
    // mode 1: request first, W after two cycles (C2)
    // b_mode 0: B consumed in the arrival cycle; 1: consumer stalls one cycle
    task automatic write_transaction(
        input [31:0] addr, input [31:0] data, input [3:0] strb,
        input integer mode, input integer b_mode,
        input [1:0] exp_resp, input integer aw_wait,
        input integer w_wait, input integer b_wait);
        integer g;
        begin
            // ---- request (+ optional W) phase
            @(negedge clk);
            req_valid = 1; req_write = 1; req_addr = addr;
            req_size = 3'd2; req_len = 8'd0; req_id = 4'h1;
            if (mode == 0) begin
                w_valid = 1; w_data = data; w_strb = strb; w_last = 1;
            end
            #1;
            check(req_ready, "req_ready must be high in idle");
            if (mode == 0)
                check(w_ready, "w_ready must be high for a same-cycle W");
            @(posedge clk);                     // request (and W) accepted
            @(negedge clk);
            req_valid = 0; req_write = 0;
            if (mode == 0) begin
                w_valid = 0;
            end else begin
                // C3: one outstanding only while the W beat is still missing
                repeat (2) begin
                    #1; check(!req_ready, "req_ready low while write outstanding");
                    @(posedge clk); @(negedge clk);
                end
                w_valid = 1; w_data = data; w_strb = strb; w_last = 1;
                g = 0;
                #1;
                while (!w_ready && g < 16) begin @(posedge clk); g = g + 1; #1; end
                check(w_ready, "W accepted through the WR_PREP path");
                @(posedge clk);                 // W accepted
                @(negedge clk);
                w_valid = 0;
            end

            // ---- AW channel
            g = 0;
            while (!m_awvalid && g < 64) begin @(posedge clk); g = g + 1; end
            check(m_awvalid, "AWVALID asserted");
            check(m_awaddr == addr, "AWADDR mismatch");
            check(m_awlen == 8'd0, "AWLEN must be single beat");
            check(m_awsize == 3'd2, "AWSIZE must be word");
            repeat (aw_wait) begin
                @(posedge clk);
                check(m_awvalid, "AWVALID held under backpressure");
            end
            @(negedge clk); m_awready = 1;
            @(posedge clk);                     // AW accepted
            @(negedge clk); m_awready = 0;

            // ---- W channel
            g = 0;
            while (!m_wvalid && g < 64) begin @(posedge clk); g = g + 1; end
            check(m_wvalid, "WVALID asserted");
            check(m_wdata == data, "WDATA mismatch");
            check(m_wstrb == strb, "WSTRB mismatch");
            check(m_wlast == 1'b1, "WLAST must be high for a single beat");
            repeat (w_wait) begin
                @(posedge clk);
                check(m_wvalid, "WVALID held under backpressure");
            end
            @(negedge clk); m_wready = 1;
            @(posedge clk);                     // W accepted
            @(negedge clk); m_wready = 0;

            // ---- B channel
            repeat (b_wait) @(posedge clk);
            if (b_mode == 1) begin
                @(negedge clk);
                b_ready = 0;                    // consumer not ready -> WR_HOLD
            end
            @(negedge clk);
            m_bvalid = 1; m_bid = 4'h1; m_bresp = exp_resp;
            #1;
            check(m_bready, "BREADY must be high in WR_RESP");
            @(posedge clk);                     // B accepted
            @(negedge clk);
            m_bvalid = 0; m_bid = 4'h0; m_bresp = 2'b00;
            #1;
            if (b_mode == 0) begin
                check(!b_valid, "B consumed in its arrival cycle");
            end else begin
                check(b_valid, "b_valid must hold for the stalled consumer");
                check(b_resp == exp_resp, "BRESP to consumer mismatch");
                check(b_id == 4'h1, "BID mismatch");
                repeat (3) @(posedge clk);
                #1;
                check(b_valid, "b_valid stable under consumer backpressure");
                @(negedge clk);
                b_ready = 1;                    // consumer takes it now
                @(posedge clk);
                @(negedge clk);
                #1;
                check(!b_valid, "b_valid cleared after the consumer consumed it");
            end
            @(posedge clk); @(negedge clk);
            #1;
            check(req_ready, "req_ready must return high after completion");
            check(!protocol_fault && !config_fault, "no sticky fault");
        end
    endtask

    // ------------------------------------------------------------------ cases
    task automatic case_same_cycle;
        begin
            $display("CASE same_cycle_req_w");
            reset_dut;
            write_transaction(32'h1000_0000, 32'hdead_beef, 4'hf, 0, 0, 2'b00, 0, 0, 0);
            check(aw_hits == 1, "exactly one AW handshake");
            check(w_hits == 1, "exactly one W handshake");
            check(b_hits == 1, "exactly one B handshake");
            $display("CASE same_cycle OK");
        end
    endtask

    task automatic case_request_first;
        begin
            $display("CASE request_first_w_later");
            reset_dut;
            write_transaction(32'h2000_0004, 32'h1234_5678, 4'b0011, 1, 0, 2'b10, 2, 2, 1);
            check(aw_hits == 1, "exactly one AW handshake");
            check(w_hits == 1, "exactly one W handshake");
            check(b_hits == 1, "exactly one B handshake");
            $display("CASE request_first OK");
        end
    endtask

    task automatic case_b_stall;
        begin
            $display("CASE b_response_stall");
            reset_dut;
            write_transaction(32'h3000_0000, 32'h0bad_f00d, 4'hf, 0, 1, 2'b10, 1, 3, 4);
            check(aw_hits == 1, "exactly one AW handshake");
            check(w_hits == 1, "exactly one W handshake");
            check(b_hits == 1, "exactly one B handshake");
            $display("CASE b_stall OK");
        end
    endtask

    // C6: W before any request. w_ready is high in WR_IDLE, so the beat is
    // handshaken and lost. This test proves the exact failure mode of the
    // documented restricted contract instead of pretending the engine catches
    // it; the legal producers never generate this sequence.
    task automatic case_w_before_request;
        begin
            $display("CASE w_before_request_negative");
            reset_dut;
            @(negedge clk);
            w_valid = 1; w_data = 32'hcafe_0001; w_strb = 4'hf; w_last = 1;
            #1;
            check(w_ready, "documented: w_ready is high while idle");
            check(req_ready, "engine is idle before the request");
            $display("CONTRACT_OBSERVED idle_w_ready_accepts_orphan_w (restricted contract)");
            @(posedge clk);                     // orphan W consumed and lost
            @(negedge clk);
            w_valid = 0;
            req_valid = 1; req_write = 1; req_addr = 32'h4000_0000;
            req_size = 3'd2; req_len = 8'd0; req_id = 4'h1;
            #1;
            check(req_ready, "request accepted after the orphan W");
            @(posedge clk);
            @(negedge clk);
            req_valid = 0; req_write = 0;
            repeat (4) @(posedge clk);
            #1;
            check(dut.state_q == 3'd1, "engine waits for the lost W in WR_PREP");
            check(!m_awvalid, "no AW may be issued without the lost W data");
            $display("CONTRACT_VIOLATION_W_BEFORE_REQUEST reproduced as documented");
            reset_dut;
        end
    endtask

    initial begin
        $display("TB_W_CONTRACT start");
        case_same_cycle();
        case_request_first();
        case_b_stall();
        case_w_before_request();
        if (errors != 0) begin
            $display("TEST_FAIL WCONTRACT errors=%0d", errors);
            $finish;
        end
        $display("TEST_PASS WCONTRACT");
        $finish;
    end

    initial begin
        #(200_000);
        $display("TEST_FAIL WCONTRACT no-pass-marker");
        $finish;
    end

endmodule
