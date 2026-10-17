//=============================================================================
// pangoriscv - RV32IM processor core + native AXI4 SoC (Pango PG2L100H @ 27 MHz)
// Module : ifu_axi                File : rtl/core/ifu_axi.v
// Rev    : 1.0                    Date : 2026-10-13
// Author : pango_lpenghan
// Brief  : Fetch unit: 8-entry instruction queue, predicted-chain prefetch, redirect flush
//=============================================================================

// ---------------------------------------------------------------------------
// ifu_axi -- instruction fetch with a decoupled fetch queue (T1).
//
// Structure
//   * one-outstanding engine handshake: the I-cache only accepts a request in
//     IC_IDLE, so a second outstanding request would buy nothing;
//   * a DEPTH-entry instruction queue sits between the engine and the pipeline;
//   * a self-driven prefetch chain: the unit asks the branch predictor's second
//     lookup port for the successor of the PC it is about to request, so a
//     predicted-taken branch keeps the queue filling along the predicted path.
//
// Why the queue: the previous version held the fetched instruction in a single
// reserved slot until the pipeline consumed it (EMPTY -> WAIT_DATA -> HOLD ->
// EMPTY), so every pipeline stall also stopped fetching.  Measured on the full-feature
// board probe, if_wait (80 962 cycles) was fourteen times lsu_wait (5 963).
//
// Safety: the queue head is delivered only when it is exactly the instruction
// the architectural PC points at (head_pc == fetch_pc); a redirect -- including
// the halt family -- flushes the queue and drops the response still in flight.
// Speculative entries can therefore never reach the pipeline, and the
// architectural result stays identical to a predict-not-taken build.
// ---------------------------------------------------------------------------
module ifu_axi #(
    parameter [31:0] EXEC_BASE=32'h00000000,
    parameter [31:0] EXEC_BYTES=32'h00004000,
    parameter integer DEPTH=8
)(
    input wire clk,rst_n,enable,redirect_valid,
    input wire [31:0] fetch_pc,predicted_next_pc,
    output wire fetch_valid,input wire fetch_ready,
    output wire [31:0] result_pc,result_inst,result_predicted_next_pc,
    output wire result_fault,output wire [4:0] result_fault_cause,
    output wire [31:0] result_fault_tval,
    output wire idle,
    output wire eng_req_valid,input wire eng_req_ready,
    output wire [31:0] eng_req_addr,output wire [2:0] eng_req_size,
    output wire [7:0] eng_req_len,output wire [3:0] eng_req_id,
    input wire eng_rsp_valid,output wire eng_rsp_ready,
    input wire [31:0] eng_rsp_data,input wire [1:0] eng_rsp_resp,
    // ---- T1 prefetch chain ------------------------------------------------
    // chain_c holds the PC of the next request; the predictor's second lookup
    // port answers with that PC's predicted successor.
    output wire [31:0] chain_c,
    input wire [31:0] chain_predict_next_pc,
    // Sticky debug tap: set when the head did not match the architectural PC
    // and the queue had to be dropped defensively (should never happen).
    output wire flush_lost
);
    localparam integer AW=$clog2(DEPTH);
    localparam S_IDLE=1'b0,S_WAIT=1'b1;

    reg state;
    reg [31:0] req_pc_q,req_pred_q,next_pc_q;
    reg stale_q,stop_q,lost_q;
    reg [AW:0] count_q;
    reg [AW-1:0] head_q,tail_q;
    reg [31:0] q_pc[0:DEPTH-1],q_inst[0:DEPTH-1],q_pred[0:DEPTH-1];
    reg q_fault[0:DEPTH-1];
    reg [4:0] q_cause[0:DEPTH-1];

    wire empty=(count_q==0);
    wire full=(count_q==DEPTH);
    wire [31:0] head_pc=q_pc[head_q];

    // Nothing queued and no request in flight: the architectural PC is the one
    // to fetch.  Requesting through fetch_ptr (instead of next_pc_q) closes the
    // one-cycle window right after a redirect in which next_pc_q still held a
    // stale chain PC while the queue had just been flushed.
    wire transparent=empty&&(state==S_IDLE);
    wire [31:0] fetch_ptr=transparent?fetch_pc:next_pc_q;
    assign chain_c=fetch_ptr;
    assign flush_lost=lost_q;

    wire exec_ok=(fetch_ptr>=EXEC_BASE)&&((fetch_ptr-EXEC_BASE)<EXEC_BYTES);
    wire local_fault=|fetch_ptr[1:0]||!exec_ok;

    // An unwired second port ($z/$x) degrades to sequential prefetch instead of
    // a bogus address, so a testbench that ties off the optional prediction
    // ports keeps a well defined fetch stream.
    wire pred_unknown=(^predicted_next_pc)===1'bx;
    wire chain_unknown=(^chain_predict_next_pc)===1'bx;
    wire [31:0] chain_next=(fetch_ptr==fetch_pc&&!pred_unknown)?predicted_next_pc:
                           (!chain_unknown?chain_predict_next_pc:fetch_ptr+32'd4);

    // A head that is not the instruction the pipeline asks for can never be
    // delivered: drop the queue and re-fetch from the real PC.
    wire head_lost=!empty&&!redirect_valid&&(state==S_IDLE)&&(head_pc!=fetch_pc);

    assign idle=(state==S_IDLE)&&empty;
    assign eng_req_valid=rst_n&&enable&&!redirect_valid&&!stop_q&&!full&&
                         (state==S_IDLE)&&!local_fault;
    assign eng_req_addr=fetch_ptr;
    assign eng_req_size=2;
    assign eng_req_len=0;
    assign eng_req_id=0;
    assign eng_rsp_ready=rst_n&&(state==S_WAIT);

    wire head_match=!empty&&(head_pc==fetch_pc);
    assign fetch_valid=rst_n&&enable&&!redirect_valid&&head_match&&!stale_q;
    assign result_pc=head_pc;
    assign result_inst=q_inst[head_q];
    assign result_predicted_next_pc=q_pred[head_q];
    assign result_fault=q_fault[head_q];
    assign result_fault_cause=q_cause[head_q];
    assign result_fault_tval=head_pc;

    wire deq=fetch_valid&&fetch_ready;
    wire issue=eng_req_valid&&eng_req_ready;
    wire rsp=eng_rsp_valid&&eng_rsp_ready;
    wire rsp_push=rsp&&!stale_q;
    wire local_push=rst_n&&enable&&!redirect_valid&&!stop_q&&!full&&
                    (state==S_IDLE)&&local_fault;
    wire push=rsp_push||local_push;

    always @(posedge clk) begin
        if(!rst_n) begin
            state<=S_IDLE; req_pc_q<=0; req_pred_q<=0; next_pc_q<=0;
            stale_q<=0; stop_q<=0; lost_q<=0;
            count_q<=0; head_q<=0; tail_q<=0;
        end else if(redirect_valid||!enable) begin
            // Everything younger than the redirect is dropped; a response still
            // in flight is either swallowed now or marked stale.  Disabling the
            // unit (halt family) takes the same path: the halt handshake waits
            // for idle, and a queue left behind would keep idle low forever.
            count_q<=0; head_q<=0; tail_q<=0; stop_q<=0;
            if(state==S_WAIT) begin
                if(rsp) begin state<=S_IDLE; stale_q<=0; end
                else stale_q<=1;
            end
        end else if(head_lost) begin
            lost_q<=1; count_q<=0; head_q<=0; tail_q<=0; stop_q<=0;
            stale_q<=1'b0; next_pc_q<=fetch_pc;
        end else begin
            if(rsp_push) begin
                q_pc[tail_q]<=req_pc_q;
                q_inst[tail_q]<=eng_rsp_data;
                q_pred[tail_q]<=req_pred_q;
                q_fault[tail_q]<=(eng_rsp_resp!=0);
                q_cause[tail_q]<=5'd1;
                if(eng_rsp_resp!=0) stop_q<=1;
            end else if(local_push) begin
                q_pc[tail_q]<=fetch_ptr;
                q_inst[tail_q]<=32'd0;
                q_pred[tail_q]<=chain_next;
                q_fault[tail_q]<=1'b1;
                q_cause[tail_q]<=|fetch_ptr[1:0]?5'd0:5'd1;
                stop_q<=1;
            end
            if(deq) head_q<=head_q+1'b1;
            if(push) tail_q<=tail_q+1'b1;
            count_q<=count_q+(push?1'b1:1'b0)-(deq?1'b1:1'b0);
            if(issue) begin
                req_pc_q<=fetch_ptr;
                req_pred_q<=chain_next;
                next_pc_q<=chain_next;
                state<=S_WAIT;
            end else if(rsp) begin
                // Do NOT touch next_pc_q here: the prefetch chain must keep
                // walking along the predicted path.  Resynchronising with the
                // architectural PC is the job of the transparent case below,
                // which only applies once the queue is empty again.
                state<=S_IDLE; stale_q<=0;
            end else if(transparent) begin
                next_pc_q<=fetch_pc;
            end
        end
    end
endmodule
