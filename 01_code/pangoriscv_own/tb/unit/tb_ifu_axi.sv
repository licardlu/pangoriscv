//=============================================================================
// pangoriscv - RV32IM processor core + native AXI4 SoC (Pango PG2L100H @ 27 MHz)
// Module : tb_ifu_axi             File : tb/unit/tb_ifu_axi.sv
// Rev    : 1.0                    Date : 2026-10-13
// Author : pango_lpenghan
// Brief  : Unit test for the fetch queue (T1) with a deterministic engine model
//=============================================================================

`timescale 1ns/1ps
// ---------------------------------------------------------------------------
// tb_ifu_axi -- unit-level fetch-queue contract (T1) with a deterministic
// engine model.  Randomised delays and the real AXI read engine are covered by
// tb/axi/tb_ifu_axi_engine.sv; this test pins the structural guarantees:
//   * prefetch fills exactly DEPTH entries and then stops (no runaway);
//   * identity of every delivered entry (pc / inst / prediction);
//   * a redirect drops the whole speculative queue -- nothing from the old
//     stream is ever delivered;
//   * local faults (misaligned, outside the executable window) are delivered
//     without issuing any engine request, and stop further prefetch;
//   * disable drains the unit and raises idle (the halt handshake needs it);
//   * the defensive head-mismatch flush stays unused (flush_lost == 0).
// ---------------------------------------------------------------------------
module tb_ifu_axi;
    localparam integer DEPTH=8;
    localparam integer LAT=3;
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
    reg eng_req_ready=1,eng_rsp_valid=0;
    reg [31:0] rsp_data=0;
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

    integer reqs=0,answered=0,results=0;
    reg [31:0] pend_addr=0;
    reg pend=0;
    integer wait_cnt=0;

    // Single-outstanding engine model: accepts a request, answers LAT cycles
    // later with a payload derived from the request address.
    always @(posedge clk) begin
        if(!rst_n) begin
            pend<=0; eng_rsp_valid<=0; wait_cnt<=0; reqs=0; answered=0;
        end else if(eng_rsp_valid) begin
            if(eng_rsp_ready) begin eng_rsp_valid<=0; pend<=0; answered=answered+1; end
        end else if(eng_req_valid&&eng_req_ready) begin
            if(pend) $fatal(1,"IFU_TWO_REQUESTS_OUTSTANDING");
            if(eng_req_size!==3'd2||eng_req_len!==8'd0||eng_req_id!==4'd0)
                $fatal(1,"IFU_REQ_ATTR size=%0d len=%0d id=%0d",
                       eng_req_size,eng_req_len,eng_req_id);
            reqs=reqs+1; pend_addr<=eng_req_addr; pend<=1; wait_cnt<=LAT;
        end else if(pend) begin
            if(wait_cnt>0) wait_cnt<=wait_cnt-1;
            else begin eng_rsp_valid<=1; rsp_data<=pend_addr+32'h00100093; end
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
            // was just consumed on that same edge.
            nxt=result_predicted_next_pc;
            fetch_ready=1;
            @(posedge clk);
            fetch_pc=nxt;
            @(negedge clk);
            fetch_ready=0;
            results=results+1;
        end
    endtask

    integer i;
    integer reqs_at_fault;
    initial begin
        repeat(3) @(negedge clk); rst_n=1; @(negedge clk);

        // (1) Fill: exactly DEPTH entries, then the unit must stop asking.
        fetch_pc=32'h20; enable=1;
        repeat(80) @(negedge clk);
        if(reqs!=DEPTH) $fatal(1,"IFU_PREFETCH_DEPTH reqs=%0d",reqs);
        if(eng_req_valid) $fatal(1,"IFU_PREFETCH_NOT_STOPPED");
        if(idle) $fatal(1,"IFU_FULL_QUEUE_REPORTS_IDLE");

        // (2) Drain: sequential identity, one entry per consumption.
        for(i=0;i<DEPTH;i=i+1) consume(32'h20+32'(i)*32'd4,0,0);

        // (3) A redirect in the middle of an active stream drops everything
        //     queued along the old path.
        repeat(40) @(negedge clk);
        redirect_to(32'h400);
        consume(32'h400,0,0);
        consume(32'h404,0,0);

        // (4) Outside the executable window: fault, no engine request.
        reqs_at_fault=reqs;
        redirect_to(32'h20000000);
        consume(32'h20000000,1,5'd1);
        repeat(10) @(negedge clk);
        if(reqs!=reqs_at_fault) $fatal(1,"IFU_NONEXEC_REQUESTED reqs=%0d",reqs);
        if(eng_req_valid) $fatal(1,"IFU_PREFETCH_AFTER_FAULT");

        // (5) Misaligned PC: fault with cause 0, still no engine request.
        redirect_to(32'h2);
        consume(32'h2,1,5'd0);
        repeat(10) @(negedge clk);
        if(reqs!=reqs_at_fault) $fatal(1,"IFU_MISALIGNED_REQUESTED reqs=%0d",reqs);

        // (6) Disable drains the queue and reports idle (halt handshake).
        redirect_to(32'h80);
        consume(32'h80,0,0);
        enable=0;
        repeat(20) @(negedge clk);
        if(!idle||fetch_valid||eng_req_valid) $fatal(1,"IFU_DISABLE_DRAIN");
        if(answered!=reqs) $fatal(1,"IFU_LOST_TRANSACTION answered=%0d reqs=%0d",answered,reqs);
        if(flush_lost) $fatal(1,"IFU_FLUSH_LOST_FINAL");
        if(results!=13) $fatal(1,"IFU_DELIVERIES %0d",results);
        $display("TEST_PASS IFU_QUEUE reqs=%0d answered=%0d delivered=%0d",reqs,answered,results);
        $finish;
    end
    initial begin #200000; $fatal(1,"IFU timeout"); end
endmodule
