//=============================================================================
// pangoriscv - RV32IM processor core + native AXI4 SoC (Pango PG2L100H @ 27 MHz)
// Module : ifu_axi                File : rtl/core/ifu_axi.v
// Rev    : 1.1                    Date : 2026-10-18
// Author : pango_lpenghan
// Brief  : Fetch unit: 8-entry instruction queue, two outstanding engine requests,
//          predicted-chain prefetch, redirect flush
//=============================================================================

// ---------------------------------------------------------------------------
// ifu_axi -- instruction fetch with a decoupled fetch queue (T1/T9).
//
// Structure
//   * TWO outstanding engine requests: the PC of every accepted request is kept
//     in a two-deep FIFO (slot 0 = oldest) and a response is paired with the
//     slot-0 PC, so the engine can be fed on consecutive cycles;
//   * a DEPTH-entry instruction queue sits between the engine and the pipeline.
//     A queue slot is reserved BEFORE a request is issued
//     (count_q + ocnt_q < DEPTH), which is what makes an unconditional
//     eng_rsp_ready safe: the unit never has to back-pressure a response it
//     already asked for, so an instruction can never be dropped for lack of
//     room;
//   * a self-driven prefetch chain: the unit asks the branch predictor's second
//     lookup port for the successor of the PC it is about to request, so a
//     predicted-taken branch keeps the queue filling along the predicted path.
//
// Why two outstanding requests (T9): the I-cache answers a hit one cycle after
// the accept edge and used to accept a new lookup only every other cycle, so a
// one-outstanding fetch unit could ask at most once per two cycles -- a hard
// 0.5 IPC fetch ceiling while the pipeline can retire one instruction per
// cycle.  With the two-deep PC FIFO the unit asks again on the very edge it
// consumes a response, which sustains one fetch per cycle.
//
// Safety: the queue head is delivered only when it is exactly the instruction
// the architectural PC points at (head_pc == fetch_pc); a redirect -- including
// the halt family -- flushes the queue and counts the still-owed responses in
// stale_cnt_q, so each one is swallowed exactly once instead of being paired
// with a post-redirect PC.  Speculative entries can therefore never reach the
// pipeline, and the architectural result stays identical to the baseline build.
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

    // ---- outstanding-request PC FIFO (slot 0 = oldest) ---------------------
    reg [31:0] pcf0_q,pcf1_q;
    reg [31:0] pdf0_q,pdf1_q;
    reg [1:0] ocnt_q;                 // 0..2 accepted requests not yet answered
    // Responses still owed for a flushed stream.  Every one of them is
    // swallowed, so no late response is ever paired with a fresh PC.
    reg [2:0] stale_cnt_q;
    reg [31:0] next_pc_q;
    reg stop_q,lost_q;
    reg [AW:0] count_q;
    reg [AW-1:0] head_q,tail_q;
    reg [31:0] q_pc[0:DEPTH-1],q_inst[0:DEPTH-1],q_pred[0:DEPTH-1];
    reg q_fault[0:DEPTH-1];
    reg [4:0] q_cause[0:DEPTH-1];

    wire empty=(count_q==0);
    wire full=(count_q==DEPTH);
    wire [31:0] head_pc=q_pc[head_q];

    // Slots already promised: one per queued entry plus one per request that is
    // still in flight.  A new request is only raised while this is below DEPTH,
    // so its response always finds room in the queue.
    wire [AW+2:0] reserved={2'b00,count_q}+{2'b00,ocnt_q};

    // Nothing queued, nothing in flight, nothing owed: the architectural PC is
    // the one to fetch.  Requesting through fetch_ptr (instead of next_pc_q)
    // closes the one-cycle window right after a redirect in which next_pc_q
    // still held a stale chain PC while the queue had just been flushed.
    wire transparent=empty&&(ocnt_q==0)&&(stale_cnt_q==0);
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
    // delivered: drop the queue and re-fetch from the real PC.  Only evaluated
    // with nothing in flight, because that is when the queue is whole.
    wire head_lost=!empty&&!redirect_valid&&(ocnt_q==0)&&(stale_cnt_q==0)&&
                   (head_pc!=fetch_pc);

    // Unconditional: a queue slot was reserved before the request went out, so
    // a response must always be taken.  Responses owed to a flushed stream are
    // counted out by stale_cnt_q instead of being back-pressured.
    assign eng_rsp_ready=rst_n;

    // ---- engine handshake bookkeeping --------------------------------------
    wire rsp=eng_rsp_valid&&eng_rsp_ready;
    wire rsp_owned=rsp&&(ocnt_q!=0);                    // answer to a tracked request
    wire rsp_stale=rsp&&(ocnt_q==0)&&(stale_cnt_q!=0);  // owed to a flushed stream
    wire rsp_live=rsp_owned||rsp_stale;
    // Occupancy after this edge's pop: what a request issued on the same edge
    // has to fit next to.
    wire [1:0] ocnt_after_pop=ocnt_q-(rsp_owned?2'd1:2'd0);

    assign eng_req_valid=rst_n&&enable&&!redirect_valid&&!stop_q&&
                         (stale_cnt_q==0)&&(reserved<DEPTH)&&
                         (ocnt_after_pop<2'd2)&&!local_fault;
    assign eng_req_addr=fetch_ptr;
    assign eng_req_size=2;
    assign eng_req_len=0;
    assign eng_req_id=0;

    assign idle=(ocnt_q==0)&&(stale_cnt_q==0)&&empty;

    wire head_match=!empty&&(head_pc==fetch_pc);
    assign fetch_valid=rst_n&&enable&&!redirect_valid&&head_match&&(stale_cnt_q==0);
    assign result_pc=head_pc;
    assign result_inst=q_inst[head_q];
    assign result_predicted_next_pc=q_pred[head_q];
    assign result_fault=q_fault[head_q];
    assign result_fault_cause=q_cause[head_q];
    assign result_fault_tval=head_pc;

    wire deq=fetch_valid&&fetch_ready;
    wire issue=eng_req_valid&&eng_req_ready;
    wire rsp_push=rsp_owned&&(stale_cnt_q==0);
    wire local_push=rst_n&&enable&&!redirect_valid&&!stop_q&&!full&&
                    (ocnt_q==0)&&(stale_cnt_q==0)&&local_fault;
    wire push=rsp_push||local_push;

    always @(posedge clk) begin
        if(!rst_n) begin
            pcf0_q<=0; pcf1_q<=0; pdf0_q<=0; pdf1_q<=0;
            ocnt_q<=0; stale_cnt_q<=0; next_pc_q<=0;
            stop_q<=0; lost_q<=0;
            count_q<=0; head_q<=0; tail_q<=0;
        end else if(redirect_valid||!enable) begin
            // Everything younger than the redirect is dropped; responses still
            // owed for the flushed stream are counted so each one is swallowed
            // exactly once.  Disabling the unit (halt family) takes the same
            // path: the halt handshake waits for idle, and a queue left behind
            // would keep idle low forever.
            count_q<=0; head_q<=0; tail_q<=0; stop_q<=0;
            pcf0_q<=0; pcf1_q<=0;
            ocnt_q<=0;
            stale_cnt_q<=stale_cnt_q+{1'b0,ocnt_q}-(rsp_live?3'd1:3'd0);
        end else if(head_lost) begin
            lost_q<=1; count_q<=0; head_q<=0; tail_q<=0; stop_q<=0;
            ocnt_q<=0; stale_cnt_q<=0; next_pc_q<=fetch_pc;
        end else begin
            if(rsp_stale) stale_cnt_q<=stale_cnt_q-3'd1;

            if(rsp_push) begin
                q_pc[tail_q]<=pcf0_q;
                q_inst[tail_q]<=eng_rsp_data;
                q_pred[tail_q]<=pdf0_q;
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

            // ---- outstanding-request bookkeeping ---------------------------
            // The oldest entry leaves first, then the newly issued request is
            // registered.  When it lands in slot 0 the later assignment wins,
            // so a pop and a push on the same edge leave exactly one entry.
            if(rsp_owned) begin
                pcf0_q<=pcf1_q;
                pdf0_q<=pdf1_q;
            end
            if(issue) begin
                case(ocnt_after_pop)
                    2'd0: begin pcf0_q<=fetch_ptr; pdf0_q<=chain_next; end
                    default: begin pcf1_q<=fetch_ptr; pdf1_q<=chain_next; end
                endcase
                ocnt_q<=ocnt_after_pop+2'd1;
                next_pc_q<=chain_next;
            end else if(rsp_owned) begin
                ocnt_q<=ocnt_q-2'd1;
            end

            // Do NOT resynchronise next_pc_q on a response: the prefetch chain
            // must keep walking along the predicted path.  The architectural PC
            // is picked up again once the unit is fully drained.
            if(transparent&&!issue) next_pc_q<=fetch_pc;
        end
    end
endmodule
