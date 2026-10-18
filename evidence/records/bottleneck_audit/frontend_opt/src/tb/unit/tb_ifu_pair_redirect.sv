//=============================================================================
// pangoriscv - phase1 acceptance extension test
// Module : tb_ifu_pair_redirect   File : tb/unit/tb_ifu_pair_redirect.sv
// Brief  : Directed corner tests for the T4 IFU (same-cycle old-response-in /
//          new-request-out).  Written against the external behaviour only.
//
//   T1  sustained stream: the engine model retires a response and accepts the
//       next request on the same edge (C2).  The prediction port is driven with
//       a NON-trivial function pred(pc) (skips a word on every 0x10 boundary),
//       so every delivered entry must carry the PC+predictor pair of the
//       request that produced it (C3 pairing, not just sequential +4).
//   T2  redirect in the SAME cycle an old response handshakes (T2a) and
//       redirect while an old response is still in flight (T2b): the old
//       response must be swallowed, no old-stream entry may be delivered, and
//       delivery restarts at redirect_pc.
//   T3  wrong-path fetch fault suppression: an old-path SLVERR response that
//       arrives after the redirect (T3a) or in the redirect cycle (T3b) must
//       never be delivered as a fetch fault.
//   T4  disable (halt family) while a request is in flight: queue drains,
//       idle rises, no transaction is orphaned, resume starts exactly at the
//       same architectural PC.
//   T5  queue full / empty and slot reservation: fill to DEPTH and stop,
//       resume with continuous consume without overflow, and hold the queue
//       head stable under fetch_ready backpressure.
//=============================================================================
`timescale 1ns/1ps
module tb_ifu_pair_redirect;

    localparam integer DEPTH = 8;

    reg clk = 0;
    always #5 clk = ~clk;

    reg rst_n = 0;
    reg enable = 0;
    reg redirect_valid = 0;
    reg [31:0] redirect_pc = 0;
    reg [31:0] fetch_pc = 0;
    reg fetch_ready = 0;

    wire fetch_valid, result_fault, idle, flush_lost;
    wire [31:0] result_pc, result_inst, result_predicted_next_pc, result_fault_tval;
    wire [4:0] result_fault_cause;

    wire eng_req_valid, eng_req_ready, eng_rsp_valid, eng_rsp_ready;
    wire [31:0] eng_req_addr, eng_rsp_data;
    wire [2:0] eng_req_size;
    wire [7:0] eng_req_len;
    wire [3:0] eng_req_id;
    wire [1:0] eng_rsp_resp;

    wire [31:0] chain_c;
    wire [31:0] predicted_next_pc;
    wire [31:0] chain_predict_next_pc;

    // Distictive but deterministic prediction: skip one word whenever bit4 is
    // set while bit5 is clear.  The sequential +4 assumption of the older
    // testbench would fail on such a stream.
    function [31:0] pred(input [31:0] a);
        pred = (a[4] && !a[5]) ? (a + 32'd8) : (a + 32'd4);
    endfunction

    assign predicted_next_pc = pred(fetch_pc);
    assign chain_predict_next_pc = pred(chain_c);

    ifu_axi #(.DEPTH(DEPTH)) dut(
        .clk(clk), .rst_n(rst_n), .enable(enable), .redirect_valid(redirect_valid),
        .fetch_pc(fetch_pc), .predicted_next_pc(predicted_next_pc),
        .fetch_valid(fetch_valid), .fetch_ready(fetch_ready),
        .result_pc(result_pc), .result_inst(result_inst),
        .result_predicted_next_pc(result_predicted_next_pc),
        .result_fault(result_fault), .result_fault_cause(result_fault_cause),
        .result_fault_tval(result_fault_tval), .idle(idle),
        .eng_req_valid(eng_req_valid), .eng_req_ready(eng_req_ready),
        .eng_req_addr(eng_req_addr), .eng_req_size(eng_req_size),
        .eng_req_len(eng_req_len), .eng_req_id(eng_req_id),
        .eng_rsp_valid(eng_rsp_valid), .eng_rsp_ready(eng_rsp_ready),
        .eng_rsp_data(eng_rsp_data), .eng_rsp_resp(eng_rsp_resp),
        .chain_c(chain_c), .chain_predict_next_pc(chain_predict_next_pc),
        .flush_lost(flush_lost)
    );

    // ---------------- one-outstanding engine model ----------------
    // The model holds one transaction at a time.  On the edge its response is
    // consumed it may latch the request issued on that very edge (same-cycle
    // replace).  The response data echoes the address so pc/inst pairing is
    // checked independently from the queue bookkeeping.
    reg pv = 0;
    reg [31:0] pdata = 0;
    reg [1:0] presp = 2'b00;
    reg pend = 0;
    reg [2:0] wait_cnt = 0;
    reg [31:0] pend_addr = 0;
    reg [2:0] lat = 3'd1;
    reg fault_zone = 0;

    assign eng_req_ready = 1'b1;
    assign eng_rsp_valid = pv;
    assign eng_rsp_data = pdata;
    assign eng_rsp_resp = presp;

    integer reqs = 0;
    integer answered = 0;
    integer same_cycle = 0;

    always @(posedge clk) begin
        if(!rst_n) begin
            pv <= 0; pdata <= 0; presp <= 0; pend <= 0; wait_cnt <= 0;
            reqs = 0; answered = 0; same_cycle = 0;
        end else if(pv && eng_rsp_ready) begin
            answered = answered + 1;
            pv <= 0;
            if(eng_req_valid) begin
                same_cycle = same_cycle + 1;
                if(eng_req_size !== 3'd2 || eng_req_len !== 8'd0 || eng_req_id !== 4'd0) begin
                    $display("** Fatal: IFU_REQ_ATTR size=%0d len=%0d id=%0d",
                             eng_req_size, eng_req_len, eng_req_id);
                    $fatal(1);
                end
                reqs = reqs + 1;
                pend_addr <= eng_req_addr;
                pend <= 1;
                wait_cnt <= lat;
            end else begin
                pend <= 0;
            end
        end else if(eng_req_valid) begin
            if(pend) begin
                $display("** Fatal: IFU_TWO_REQUESTS_OUTSTANDING");
                $fatal(1);
            end
            if(eng_req_size !== 3'd2 || eng_req_len !== 8'd0 || eng_req_id !== 4'd0) begin
                $display("** Fatal: IFU_REQ_ATTR size=%0d len=%0d id=%0d",
                         eng_req_size, eng_req_len, eng_req_id);
                $fatal(1);
            end
            reqs = reqs + 1;
            pend_addr <= eng_req_addr;
            pend <= 1;
            wait_cnt <= lat;
        end else if(pend && !pv) begin
            if(wait_cnt > 0) begin
                wait_cnt <= wait_cnt - 3'd1;
            end else begin
                pv <= 1;
                pdata <= pend_addr + 32'h00100093;
                presp <= (fault_zone && (pend_addr[11:8] == 4'h8)) ? 2'b10 : 2'b00;
            end
        end
    end

    // ---------------- architectural PC stub + checkers ----------------
    always @(posedge clk) begin
        if(!rst_n) fetch_pc <= 32'h0;
        else if(redirect_valid) fetch_pc <= redirect_pc;
        else if(fetch_valid && fetch_ready) fetch_pc <= result_predicted_next_pc;
    end

    integer delivered = 0;
    integer faults_delivered = 0;
    integer max_count = 0;
    reg [31:0] exp_pc = 0;

    always @(posedge clk) begin
        if(rst_n) begin
            if(dut.count_q > DEPTH) begin
                $display("** Fatal: C6_QUEUE_OVERFLOW count=%0d (t=%0t)", dut.count_q, $time);
                $fatal(1);
            end
            if(dut.count_q > max_count) max_count = dut.count_q;
            if(fetch_valid && fetch_ready) begin
                delivered = delivered + 1;
                if(result_pc[1:0] !== 2'b00) begin
                    $display("** Fatal: C3_UNALIGNED_DELIVERY pc=%h", result_pc);
                    $fatal(1);
                end
                if(result_fault) begin
                    faults_delivered = faults_delivered + 1;
                    if(result_pc !== exp_pc) begin
                        $display("** Fatal: C7_FAULT_PC got=%h exp=%h", result_pc, exp_pc);
                        $fatal(1);
                    end
                end else begin
                    if(result_inst !== (result_pc + 32'h00100093)) begin
                        $display("** Fatal: C3_INST_PAIR inst=%h pc=%h", result_inst, result_pc);
                        $fatal(1);
                    end
                    if(result_predicted_next_pc !== pred(result_pc)) begin
                        $display("** Fatal: C3_PRED_PAIR pred=%h exp=%h pc=%h",
                                 result_predicted_next_pc, pred(result_pc), result_pc);
                        $fatal(1);
                    end
                    if(result_pc !== exp_pc) begin
                        $display("** Fatal: C2_SEQUENCE exp=%h got=%h", exp_pc, result_pc);
                        $fatal(1);
                    end
                    exp_pc <= pred(result_pc);
                end
            end
        end
    end

    task fail(input [255:0] what);
        begin
            $display("** Fatal: %0s (t=%0t)", what, $time);
            $fatal(1);
        end
    endtask

    // Call at a negedge: assert redirect and set the expected resume PC.
    task redirect_now(input [31:0] pc);
        begin
            redirect_valid = 1'b1;
            redirect_pc = pc;
            exp_pc = pc;
        end
    endtask

    task redirect_done;
        begin
            @(negedge clk);
            redirect_valid = 1'b0;
        end
    endtask

    integer g;
    integer delivered_mark;
    integer faults_before;
    reg [31:0] old_pc, pc_at_disable, d_pc, d_inst, d_pred;
    reg [7:0] head_mark;

    initial begin
        rst_n = 0; enable = 0; redirect_valid = 0; fetch_ready = 1;
        fetch_pc = 0; redirect_pc = 0; lat = 3'd1; fault_zone = 0;
        repeat(4) @(posedge clk);
        @(negedge clk); rst_n = 1; enable = 1;
        repeat(2) @(posedge clk);

        // ================= T1: sustained same-cycle handover + pairing =======
        repeat(500) @(posedge clk);
        $display("INFO T1 same_cycle=%0d reqs=%0d rsp=%0d delivered=%0d max_q=%0d",
                 same_cycle, reqs, answered, delivered, max_count);
        if(delivered < 120) fail("T1_THROUGHPUT");
        if(same_cycle < 40) fail("T1_NO_SAME_CYCLE_HANDOVER");
        if(flush_lost !== 1'b0) fail("T1_FLUSH_LOST");

        // ================= T2a: redirect in the same cycle as old response ===
        @(negedge clk);
        g = 0;
        while(!(pv === 1'b1 && eng_rsp_ready === 1'b1)) begin
            @(negedge clk); g = g + 1;
            if(g > 2000) fail("T2A_NO_RESP_TO_REDIRECT");
        end
        old_pc = dut.req_pc_q;
        redirect_now(32'h00002000);
        redirect_done;
        if(dut.count_q !== 0) fail("T2A_QUEUE_NOT_FLUSHED");
        delivered_mark = delivered;
        repeat(200) @(posedge clk);
        if(delivered <= delivered_mark + 20) fail("T2A_NO_RESUME");
        if(exp_pc < 32'h00002040) fail("T2A_RESUME_PC");
        if(flush_lost !== 1'b0) fail("T2A_FLUSH_LOST");
        $display("INFO T2a old_pc=%h resume_pc=%h delivered=%0d", old_pc, exp_pc, delivered);

        // ================= T2b: redirect while old response is in flight =====
        lat = 3'd5;
        @(negedge clk);
        g = 0;
        while(!(dut.state === 1'b1 && pv === 1'b0)) begin
            @(negedge clk); g = g + 1;
            if(g > 4000) fail("T2B_NO_INFLIGHT_REQUEST");
        end
        old_pc = dut.req_pc_q;
        redirect_now(32'h00002200);
        redirect_done;
        delivered_mark = delivered;
        repeat(300) @(posedge clk);
        if(delivered <= delivered_mark + 20) fail("T2B_NO_RESUME");
        if(flush_lost !== 1'b0) fail("T2B_FLUSH_LOST");
        if(dut.stop_q !== 1'b0) fail("T2B_STALE_SET_STOP");
        if(exp_pc < 32'h00002240) fail("T2B_RESUME_PC");
        $display("INFO T2b old_pc=%h resume_pc=%h delivered=%0d", old_pc, exp_pc, delivered);

        // ================= T3a: wrong-path SLVERR arriving after redirect =====
        lat = 3'd4; fault_zone = 1;
        @(negedge clk);
        redirect_now(32'h000017F0);
        redirect_done;
        g = 0;
        while(!(dut.state === 1'b1 && dut.req_pc_q === 32'h00001800)) begin
            @(negedge clk); g = g + 1;
            if(g > 6000) fail("T3A_NO_FAULT_REQUEST_INFLIGHT");
        end
        faults_before = faults_delivered;
        redirect_now(32'h00002400);
        redirect_done;
        delivered_mark = delivered;
        repeat(300) @(posedge clk);
        if(faults_delivered !== faults_before) fail("T3A_WRONG_PATH_FAULT_DELIVERED");
        if(delivered <= delivered_mark + 20) fail("T3A_NO_RESUME");
        if(exp_pc < 32'h00002440) fail("T3A_RESUME_PC");
        if(dut.stop_q !== 1'b0) fail("T3A_WRONG_PATH_FAULT_STOPPED_STREAM");
        if(flush_lost !== 1'b0) fail("T3A_FLUSH_LOST");
        $display("INFO T3a faults=%0d resume_pc=%h", faults_delivered, exp_pc);

        // ================= T3b: redirect in the same cycle as SLVERR =========
        lat = 3'd1;
        @(negedge clk);
        redirect_now(32'h00001840);
        redirect_done;
        g = 0;
        while(!(dut.state === 1'b1 && dut.req_pc_q === 32'h00001840)) begin
            @(negedge clk); g = g + 1;
            if(g > 6000) fail("T3B_NO_FAULT_REQUEST");
        end
        g = 0;
        while(!(pv === 1'b1 && eng_rsp_ready === 1'b1)) begin
            @(negedge clk); g = g + 1;
            if(g > 400) fail("T3B_NO_FAULT_RESPONSE");
        end
        faults_before = faults_delivered;
        delivered_mark = delivered;
        redirect_now(32'h00002600);
        redirect_done;
        repeat(300) @(posedge clk);
        if(faults_delivered !== faults_before) fail("T3B_WRONG_PATH_FAULT_DELIVERED_SAME_CYCLE");
        if(delivered <= delivered_mark + 20) fail("T3B_NO_RESUME");
        if(exp_pc < 32'h00002640) fail("T3B_RESUME_PC");
        if(dut.stop_q !== 1'b0) fail("T3B_WRONG_PATH_FAULT_STOPPED_STREAM");
        if(flush_lost !== 1'b0) fail("T3B_FLUSH_LOST");
        $display("INFO T3b faults=%0d resume_pc=%h", faults_delivered, exp_pc);

        // ================= T4: disable (halt) with a request in flight ========
        fault_zone = 0; lat = 3'd4;
        @(negedge clk);
        g = 0;
        while(!(dut.state === 1'b1 && pv === 1'b0)) begin
            @(negedge clk); g = g + 1;
            if(g > 4000) fail("T4_NO_INFLIGHT_REQUEST");
        end
        pc_at_disable = fetch_pc;
        enable = 1'b0;
        repeat(40) @(posedge clk);
        if(fetch_valid !== 1'b0) fail("T4_FETCH_VALID_WHILE_DISABLED");
        if(idle !== 1'b1) fail("T4_NOT_IDLE_AFTER_DISABLE");
        if(dut.count_q !== 0) fail("T4_QUEUE_NOT_EMPTY_AFTER_DISABLE");
        if(eng_req_valid !== 1'b0) fail("T4_REQUEST_WHILE_DISABLED");
        delivered_mark = delivered;
        repeat(20) @(posedge clk);
        if(delivered !== delivered_mark) fail("T4_DELIVERY_WHILE_DISABLED");
        exp_pc = pc_at_disable;
        enable = 1'b1;
        repeat(150) @(posedge clk);
        if(delivered <= delivered_mark + 10) fail("T4_NO_RESUME");
        if(flush_lost !== 1'b0) fail("T4_FLUSH_LOST");
        $display("INFO T4 pc_at_disable=%h delivered=%0d", pc_at_disable, delivered);

        // ================= T5: queue full / empty + slot reservation ==========
        @(negedge clk); rst_n = 0; enable = 0; fetch_ready = 0;
        repeat(4) @(posedge clk);
        @(negedge clk); rst_n = 1; fetch_pc = 32'h0; exp_pc = 32'h0;
        repeat(2) @(posedge clk);
        enable = 1;
        repeat(80) @(posedge clk);
        if(dut.count_q !== DEPTH) fail("T5_QUEUE_NOT_FULL");
        if(eng_req_valid !== 1'b0) fail("T5_STILL_REQUESTS_WHEN_FULL");
        if(idle !== 1'b0) fail("T5_FULL_REPORTS_IDLE");
        delivered_mark = delivered;
        fetch_ready = 1;
        repeat(100) @(posedge clk);
        if(delivered <= delivered_mark + DEPTH) fail("T5_DRAIN_DELIVERIES");
        // Head stability under fetch_ready backpressure mid-stream.
        fetch_ready = 0;
        @(negedge clk);
        g = 0;
        while(!(fetch_valid && !fetch_ready)) begin
            @(negedge clk); g = g + 1;
            if(g > 300) fail("T5_C5_NO_HEAD");
        end
        d_pc = result_pc; d_inst = result_inst; d_pred = result_predicted_next_pc;
        head_mark = dut.head_q;
        for(g = 0; g < 10; g = g + 1) begin
            @(negedge clk);
            if(!fetch_valid) fail("T5_C5_VALID_DROPPED");
            if(result_pc !== d_pc) fail("T5_C5_PC_MOVED");
            if(result_inst !== d_inst) fail("T5_C5_INST_MOVED");
            if(result_predicted_next_pc !== d_pred) fail("T5_C5_PRED_MOVED");
            if(dut.head_q !== head_mark) fail("T5_C5_PTR_MOVED");
        end
        fetch_ready = 1;
        repeat(80) @(posedge clk);
        if(flush_lost !== 1'b0) fail("T5_FLUSH_LOST");
        $display("INFO T5 max_q=%0d count=%0d delivered=%0d", max_count, dut.count_q, delivered);

        $display("TEST_PASS IFU_PAIR_REDIRECT delivered=%0d same_cycle=%0d reqs=%0d faults=%0d",
                 delivered, same_cycle, reqs, faults_delivered);
        $finish;
    end

    initial begin
        #2000000;
        $display("** Fatal: IFU_PAIR_REDIRECT_TIMEOUT");
        $finish;
    end

endmodule
