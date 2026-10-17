//=============================================================================
// pangoriscv - RV32IM processor core + native AXI4 SoC (Pango PG2L100H @ 27 MHz)
// Module : tb_ifu_contract     File : tb/unit/tb_ifu_contract.sv
// Rev    : 1.0                 Date : 2026-10-17
// Author : pango_lpenghan
// Brief  : Contract test for the T4 fetch unit (same-cycle "old response in,
//          new request out").  Written against the contract, not the RTL:
//
//   C2  a hit may be issued in the same cycle the previous response is accepted
//   C3  a queued entry always carries the PC/prediction of the request that
//       produced it (checked by echoing the request address back as data)
//   C5  the queue head and its result_* bus stay stable while fetch_ready is low
//   C6  the queue never exceeds DEPTH entries, and it does fill up to DEPTH
//   C7  redirect drops in-flight work and resumes at the new PC; a fault
//       response stops the stream instead of handing over to a younger request
//=============================================================================
`timescale 1ns/1ps
module tb_ifu_contract;

    reg clk = 0;
    always #5 clk = ~clk;

    reg rst_n = 0;
    reg enable = 1;
    reg redirect_valid = 0;
    reg [31:0] redirect_pc = 0;
    reg [31:0] fetch_pc = 32'h00000000;
    reg [31:0] predicted_next_pc = 32'h00000004;
    reg fetch_ready = 1;

    wire fetch_valid;
    wire [31:0] result_pc, result_inst, result_predicted_next_pc;
    wire result_fault;
    wire [4:0] result_fault_cause;
    wire [31:0] result_fault_tval;
    wire idle;
    wire eng_req_valid, eng_req_ready;
    wire [31:0] eng_req_addr;
    wire [2:0] eng_req_size;
    wire [7:0] eng_req_len;
    wire [3:0] eng_req_id;
    wire eng_rsp_valid;
    wire eng_rsp_ready;
    wire [31:0] eng_rsp_data;
    wire [1:0] eng_rsp_resp;
    wire [31:0] chain_c;
    reg  [31:0] chain_predict_next_pc;
    wire flush_lost;

    ifu_axi dut(
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

    // ---------------- engine model ----------------
    // One-cycle hit response: a request accepted at T is answered at T+1, so a
    // correctly pipelined chain can issue and consume in the same cycle.
    // The word returned echoes the request address, which lets the checker pair
    // every delivered instruction with the PC it was fetched from (C3).
    reg pv = 0;
    reg [31:0] pdata = 0;
    reg [1:0] presp = 2'b00;
    reg fault_zone = 0;          // when set, 0x800..0x8FF answers SLVERR

    assign eng_rsp_valid = pv;
    assign eng_rsp_data = pdata;
    assign eng_rsp_resp = presp;

    wire eng_accept = eng_req_valid && eng_req_ready;
    wire eng_consume = eng_rsp_valid && eng_rsp_ready;

    function [31:0] encode(input [31:0] a);
        encode = {16'h0, a[15:2], 2'b00};
    endfunction

    always @(posedge clk) begin
        if(!rst_n) begin
            pv <= 0; pdata <= 0; presp <= 2'b00;
        end else if(eng_consume) begin
            // Same-cycle: retire the old response and accept a new request.
            if(eng_accept) begin
                pv <= 1;
                pdata <= encode(eng_req_addr);
                presp <= (fault_zone && (eng_req_addr[11:8] == 4'h8)) ? 2'b10 : 2'b00;
            end else begin
                pv <= 0; presp <= 2'b00;
            end
        end else if(!pv && eng_accept) begin
            pv <= 1;
            pdata <= encode(eng_req_addr);
            presp <= (fault_zone && (eng_req_addr[11:8] == 4'h8)) ? 2'b10 : 2'b00;
        end
    end

    // Ready while idle, and also in the cycle the held response is leaving, so a
    // pipeline that retires and re-issues in the same cycle is never stalled.
    assign eng_req_ready = !pv || eng_rsp_ready;

    // ---------------- pipeline stub: architectural PC follows delivery ----
    always @(posedge clk) begin
        if(!rst_n) fetch_pc <= 32'h00000000;
        else if(redirect_valid) fetch_pc <= redirect_pc;
        else if(fetch_valid && fetch_ready && !result_fault) fetch_pc <= result_pc + 32'd4;
    end
    always @(*) begin
        predicted_next_pc = fetch_pc + 32'd4;
        chain_predict_next_pc = chain_c + 32'd4;
    end

    // ---------------- checkers ----------------
    integer delivered = 0;
    integer same_cycle = 0;        // C2 evidence: consume + issue in one cycle
    integer reqs = 0;
    integer max_count = 0;
    reg [31:0] exp_pc = 0;
    reg counting_seq = 1;          // sequential pairing enabled

    always @(posedge clk) begin
        if(rst_n) begin
            if(eng_consume && eng_accept) same_cycle = same_cycle + 1;
            if(eng_accept) reqs = reqs + 1;
            if(dut.count_q > 8) begin
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
                if(!result_fault && result_inst !== {16'h0, result_pc[15:2], 2'b00}) begin
                    $display("** Fatal: C3_PAIRING inst=%h pc=%h", result_inst, result_pc);
                    $fatal(1);
                end
                if(counting_seq) begin
                    if(result_pc !== exp_pc) begin
                        $display("** Fatal: C2_SEQUENCE exp=%h got=%h", exp_pc, result_pc);
                        $fatal(1);
                    end
                    exp_pc = exp_pc + 32'd4;
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

    reg [31:0] d_pc, d_inst;
    integer i, g;

    initial begin
        repeat(3) @(posedge clk);
        @(negedge clk); rst_n = 1;
        repeat(2) @(posedge clk);

        // ================= A1: C6 the queue fills to DEPTH and stops ========
        fetch_ready = 0;
        repeat(16) @(negedge clk);
        if(dut.count_q != 8) fail("C6_QUEUE_NOT_FULL");
        if(max_count != 8)   fail("C6_DEPTH_WRONG");

        // ================= A2: C2 throughput + C3 pairing =================
        fetch_ready = 1;
        repeat(120) @(negedge clk);      // sustained stream
        if(delivered < 100) fail("C2_THROUGHPUT");
        if(same_cycle < 90) fail("C2_NO_SAME_CYCLE_REPLACE");
        $display("INFO A delivered=%0d same_cycle=%0d reqs=%0d max_count=%0d",
                 delivered, same_cycle, reqs, max_count);

        // ================= B: C5 backpressure on the queue head =================
        @(negedge clk); fetch_ready = 0;
        g = 0;
        while(!fetch_valid) begin
            @(negedge clk); g = g + 1;
            if(g > 50) fail("C5_NO_HEAD");
        end
        d_pc = result_pc; d_inst = result_inst;
        for(i=0;i<6;i=i+1) begin
            @(negedge clk);
            if(!fetch_valid)   fail("C5_VALID_DROPPED");
            if(result_pc !== d_pc)   fail("C5_PC_MOVED");
            if(result_inst !== d_inst) fail("C5_INST_MOVED");
        end
        fetch_ready = 1;
        repeat(4) @(negedge clk);

        // ================= C: C7 redirect drops in-flight work =================
        // Stall the consumer so the queue fills and one request stays in flight,
        // then redirect.  Nothing from the old stream may be delivered after it.
        @(negedge clk); fetch_ready = 0;
        repeat(12) @(negedge clk);
        counting_seq = 0;
        @(negedge clk);
        redirect_pc = 32'h00000100;
        redirect_valid = 1;
        @(negedge clk);
        redirect_valid = 0;
        exp_pc = 32'h00000100;
        counting_seq = 1;
        @(negedge clk);
        if(dut.count_q != 0) fail("C7_QUEUE_NOT_FLUSHED");
        fetch_ready = 1;
        repeat(60) @(negedge clk);
        if(exp_pc < 32'h00000140) fail("C7_NO_RESUME");
        $display("INFO C resumed exp_pc=%h delivered=%0d", exp_pc, delivered);

        // ================= D: C7 fault response stops the stream =================
        fault_zone = 1;
        counting_seq = 0;
        @(negedge clk);
        redirect_pc = 32'h00000800;
        redirect_valid = 1;
        @(negedge clk);
        redirect_valid = 0;
        fetch_ready = 1;
        // wait for the fault instruction to be delivered
        g = 0;
        while(!(fetch_valid && result_fault)) begin
            @(negedge clk); g = g + 1;
            if(g > 60) fail("C7_NO_FAULT_DELIVERY");
        end
        if(result_pc !== 32'h00000800) fail("C7_FAULT_PC");
        @(negedge clk);
        // no younger request may be issued while the fault is pending
        reqs = 0;
        repeat(20) @(negedge clk);
        if(reqs != 0) begin
            $display("** Fatal: C7_STREAM_CONTINUED_AFTER_FAULT reqs=%0d", reqs);
            $fatal(1);
        end

        if(flush_lost !== 1'b0) fail("FLUSH_LOST_SET");

        $display("TEST_PASS IFU_CONTRACT delivered=%0d same_cycle=%0d max_count=%0d",
                 delivered, same_cycle, max_count);
        $finish;
    end

    initial begin
        #400000;
        $display("** Fatal: IFU_CONTRACT_TIMEOUT");
        $finish;
    end

endmodule
