//=============================================================================
// pangoriscv - RV32IM processor core + native AXI4 SoC (Pango PG2L100H @ 27 MHz)
// Module : tb_ifu_axi             File : tb/unit/tb_ifu_axi.sv
// Rev    : 1.1                    Date : 2026-10-18
// Author : pango_lpenghan
// Brief  : Unit test for the fetch queue (T1/T9) with a deterministic engine model
//=============================================================================

`timescale 1ns/1ps
// ---------------------------------------------------------------------------
// tb_ifu_axi -- unit-level fetch-queue contract (T1/T9) with a deterministic
// engine model.  Randomised delays and the real AXI read engine are covered by
// tb/axi/tb_ifu_axi_engine.sv; this test pins the structural guarantees:
//   * prefetch fills exactly DEPTH entries and then stops (no runaway);
//   * identity of every delivered entry (pc / inst / prediction);
//   * at most two engine requests in flight, and never three (T9 contract);
//   * a redirect drops the whole speculative queue -- nothing from the old
//     stream is ever delivered -- even when requests are still in flight, and
//     every response owed to the old stream is accounted for exactly once;
//   * with a one-cycle engine the unit accepts back-to-back, proving the
//     two-deep PC FIFO is actually used (a one-outstanding unit alternates);
//   * local faults (misaligned, outside the executable window) are delivered
//     without issuing any engine request, and stop further prefetch;
//   * disable drains the unit and raises idle (the halt handshake needs it);
//   * the defensive head-mismatch flush stays unused (flush_lost == 0).
// ---------------------------------------------------------------------------
module tb_ifu_axi;
    localparam integer DEPTH=8;
    reg clk=0; always #5 clk=~clk;
    reg rst_n=0,enable=0,redirect_valid=0,fetch_ready=0;
    reg [31:0] fetch_pc=32'h20;
    wire [31:0] predicted_next_pc=fetch_pc+32'd4;
    // The chain port is deliberately unwired: the unit must fall back to
    // sequential prefetch rather than request an x address.
    wire [31:0] chain_c,chain_predict_next_pc;
    wire fetch_valid,result_fault,idle,flush_lost;
    wire [31:0] result_pc,result_inst,result_predicted_next_pc,result_fault_tval;
    wire [4:0] result_fault_cause;
    wire eng_req_valid,eng_rsp_ready;
    reg eng_req_ready=1;
    wire eng_rsp_valid;
    wire [31:0] rsp_data;
    reg [1:0] eng_rsp_resp=0;
    wire [31:0] eng_req_addr;
    wire [2:0] eng_req_size;
    wire [7:0] eng_req_len;
    wire [3:0] eng_req_id;

    ifu_axi #(.DEPTH(DEPTH)) dut(
        .clk(clk),.rst_n(rst_n),.enable(enable),.redirect_valid(redirect_valid),
        .fetch_pc(fetch_pc),.predicted_next_pc(predicted_next_pc),
        .fetch_valid(fetch_valid),.fetch_ready(fetch_ready),
        .result_pc(result_pc),.result_inst(result_inst),
        .result_predicted_next_pc(result_predicted_next_pc),
        .result_fault(result_fault),.result_fault_cause(result_fault_cause),
        .result_fault_tval(result_fault_tval),.idle(idle),
        .eng_req_valid(eng_req_valid),.eng_req_ready(eng_req_ready),
        .eng_req_addr(eng_req_addr),.eng_req_size(eng_req_size),
        .eng_req_len(eng_req_len),.eng_req_id(eng_req_id),
        .eng_rsp_valid(eng_rsp_valid),.eng_rsp_ready(eng_rsp_ready),
        .eng_rsp_data(rsp_data),.eng_rsp_resp(eng_rsp_resp),
        .chain_c(chain_c),.chain_predict_next_pc(chain_predict_next_pc),
        .flush_lost(flush_lost));

    // ---- engine model -----------------------------------------------------
    // Accepts on any cycle (req_ready is tied high), keeps up to the two
    // requests the unit is allowed to hold in an in-order FIFO, and answers the
    // head `lat` cycles after its accept edge.  Out-of-order service is
    // impossible by construction, which is the contract the unit relies on.
    localparam integer MN=4;
    reg [31:0] mq_addr[0:MN-1];
    integer    mq_left[0:MN-1];
    integer    mq_w=0,mq_r=0,mq_n=0;
    integer    lat=3;               // cycles from accept edge to response
    integer    mi;                  // model-internal loop index (not shared with the TB)
    assign eng_rsp_valid = rst_n && (mq_n!=0) && (mq_left[mq_r]==0);
    assign rsp_data      = mq_addr[mq_r] + 32'h00100093;

    integer reqs=0,answered=0,results=0;
    // Back-to-back acceptance monitor: longest run of consecutive accept edges.
    reg     measuring=0;
    integer run=0,run_max=0;

    always @(posedge clk) begin
        if(!measuring) begin
            run<=0; run_max<=0;
        end else if(eng_req_valid && eng_req_ready) begin
            run<=run+1;
            if(run+1>run_max) run_max<=run+1;
        end else begin
            run<=0;
        end
    end

    always @(posedge clk) begin
        if(!rst_n) begin
            mq_w=0; mq_r=0; mq_n=0; reqs=0; answered=0;
        end else begin
            // (a) answer the head entry, strictly in order
            if((mq_n!=0) && (mq_left[mq_r]==0)) begin
                if(!eng_rsp_ready) $fatal(1,"IFU_BACKPRESSURED_A_RESPONSE");
                mq_r=(mq_r+1)%MN;
                mq_n=mq_n-1;
                answered=answered+1;
            end
            // (b) accept a new request
            if(eng_req_valid && eng_req_ready) begin
                if(mq_n==MN) $fatal(1,"IFU_ENGINE_MODEL_OVERFLOW");
                if(mq_n==2) $fatal(1,"IFU_THREE_REQUESTS_OUTSTANDING");
                if(eng_req_size!==3'd2||eng_req_len!==8'd0||eng_req_id!==4'd0)
                    $fatal(1,"IFU_REQ_ATTR size=%0d len=%0d id=%0d",
                           eng_req_size,eng_req_len,eng_req_id);
                mq_addr[mq_w]=eng_req_addr;
                mq_left[mq_w]=lat;
                mq_w=(mq_w+1)%MN;
                mq_n=mq_n+1;
                reqs=reqs+1;
            end
            // (c) age every outstanding entry
            for(mi=0;mi<MN;mi=mi+1)
                if(mq_left[mi]>0) mq_left[mi]=mq_left[mi]-1;
        end
    end

    task redirect_to(input [31:0] pc);
        begin
            @(negedge clk); fetch_pc=pc; enable=1; redirect_valid=1;
            @(negedge clk); redirect_valid=0;
        end
    endtask
    task consume(input [31:0] pc,input bit err,input [4:0] cause);
        reg [31:0] nxt;
        begin
            @(negedge clk);
            while(!fetch_valid) @(negedge clk);
            repeat(3) begin
                if(result_pc!==pc) $fatal(1,"IFU_PC got=%h exp=%h",result_pc,pc);
                if(result_fault!==err) $fatal(1,"IFU_FAULT_FLAG %b",result_fault);
                if(err) begin
                    if(result_fault_cause!==cause)
                        $fatal(1,"IFU_CAUSE got=%0d exp=%0d",result_fault_cause,cause);
                    if(result_fault_tval!==pc)
                        $fatal(1,"IFU_TVAL got=%h exp=%h",result_fault_tval,pc);
                end else begin
                    if(result_inst!==(pc+32'h00100093))
                        $fatal(1,"IFU_INST got=%h exp=%h",result_inst,pc+32'h00100093);
                    if(result_predicted_next_pc!==(pc+32'd4))
                        $fatal(1,"IFU_PRED got=%h exp=%h",result_predicted_next_pc,pc+32'd4);
                end
                if(flush_lost) $fatal(1,"IFU_FLUSH_LOST");
                @(negedge clk);
            end
            // Accept exactly like pc_reg does: the dequeue happens on the edge,
            // and the architectural PC takes the prediction of the entry that
            // was consumed on that same edge.
            nxt=result_predicted_next_pc;
            fetch_ready=1;
            @(posedge clk);
            fetch_pc=nxt;
            @(negedge clk);
            fetch_ready=0;
            results=results+1;
        end
    endtask

    integer i;                      // testbench loop index
    integer reqs_at_fault;
    initial begin
        repeat(3) @(negedge clk); rst_n=1; @(negedge clk);
        measuring=1;

        // (1) Fill: exactly DEPTH entries, then the unit must stop asking.
        fetch_pc=32'h20; enable=1;
        repeat(80) @(negedge clk);
        if(reqs!=DEPTH) $fatal(1,"IFU_PREFETCH_DEPTH reqs=%0d",reqs);
        if(eng_req_valid) $fatal(1,"IFU_PREFETCH_NOT_STOPPED");
        if(idle) $fatal(1,"IFU_FULL_QUEUE_REPORTS_IDLE");
        if(run_max<2) $fatal(1,"IFU_NO_TWO_OUTSTANDING run_max=%0d",run_max);

        // (2) Drain: sequential identity, one entry per consumption.
        for(i=0;i<DEPTH;i=i+1) consume(32'h20+32'(i)*32'd4,0,0);

        // (3) A redirect in the middle of an active stream drops everything
        //     queued along the old path.
        repeat(40) @(negedge clk);
        redirect_to(32'h400);
        consume(32'h400,0,0);
        consume(32'h404,0,0);

        // (4) Outside the executable window: fault, no engine request.  The
        //     snapshot is taken once the fault slot is delivered, so it cannot
        //     race with prefetch that is still draining from the old stream.
        redirect_to(32'h20000000);
        consume(32'h20000000,1,5'd1);
        reqs_at_fault=reqs;
        repeat(10) @(negedge clk);
        if(reqs!=reqs_at_fault) $fatal(1,"IFU_NONEXEC_REQUESTED reqs=%0d",reqs);
        if(eng_req_valid) $fatal(1,"IFU_PREFETCH_AFTER_FAULT");

        // (5) Misaligned PC: fault with cause 0, still no engine request.
        redirect_to(32'h2);
        consume(32'h2,1,5'd0);
        reqs_at_fault=reqs;
        repeat(10) @(negedge clk);
        if(reqs!=reqs_at_fault) $fatal(1,"IFU_MISALIGNED_REQUESTED reqs=%0d",reqs);

        // (6) Disable drains the queue and reports idle (halt handshake).
        redirect_to(32'h80);
        consume(32'h80,0,0);
        enable=0;
        repeat(20) @(negedge clk);
        if(!idle||fetch_valid||eng_req_valid) $fatal(1,"IFU_DISABLE_DRAIN");

        // (7) Redirect while requests are in flight (the same edge a response
        //     is taken, because the stream is one-per-cycle here).  Every owed
        //     response must be swallowed exactly once: no stale entry may be
        //     delivered and no transaction may be lost.
        redirect_to(32'h600);
        repeat(6) @(negedge clk);          // requests are in flight by now
        redirect_to(32'h800);              // overlaps a response edge
        consume(32'h800,0,0);
        consume(32'h804,0,0);

        // (8) Back-to-back: with a one-cycle engine the unit must ask on
        //     consecutive cycles.  A one-outstanding fetch unit can never get
        //     past a run of 1, so this is the T9 discriminator.
        lat=1;
        redirect_to(32'h900);
        run_max=0; run=0;
        repeat(60) @(negedge clk);
        if(run_max<4) $fatal(1,"IFU_EMPTY_BACK_TO_BACK run_max=%0d",run_max);

        enable=0;
        repeat(20) @(negedge clk);
        if(!idle||fetch_valid||eng_req_valid) $fatal(1,"IFU_DISABLE_DRAIN_FINAL");
        if(answered!=reqs) $fatal(1,"IFU_LOST_TRANSACTION answered=%0d reqs=%0d",answered,reqs);
        if(flush_lost) $fatal(1,"IFU_FLUSH_LOST_FINAL");
        if(results!=15) $fatal(1,"IFU_DELIVERIES %0d",results);
        $display("TEST_PASS IFU_QUEUE reqs=%0d answered=%0d delivered=%0d run_max=%0d",
                 reqs,answered,results,run_max);
        $finish;
    end
    initial begin #200000; $fatal(1,"IFU timeout"); end
endmodule
