//=============================================================================
// pangoriscv - RV32IM processor core + native AXI4 SoC (Pango PG2L100H @ 27 MHz)
// Module : ifu_axi                File : rtl/core/ifu_axi.v
// Rev    : 1.2                    Date : 2026-10-19
// Author : pango_lpenghan
// Brief  : Fetch unit: 16-entry instruction queue, two outstanding engine
//          requests, two-word (8 B) fetch, predicted-chain prefetch, redirect flush
//=============================================================================

// ---------------------------------------------------------------------------
// ifu_axi -- instruction fetch with a decoupled fetch queue (T1/T9) and a
//            two-word pair mode for superscalar issue (T10).
//
// Structure
//   * TWO outstanding engine requests: the PC of every accepted request is kept
//     in a two-deep FIFO (slot 0 = oldest) and a response is paired with the
//     slot-0 PC, so the engine can be fed on consecutive cycles.
//   * a DEPTH-entry instruction queue sits between the engine and the pipeline.
//     A queue slot is reserved BEFORE a request is issued
//     (count_q + 2*ocnt_q + 2 <= DEPTH), which is what makes an unconditional
//     eng_rsp_ready safe: the unit never has to back-pressure a response it
//     already asked for, so an instruction can never be dropped for lack of
//     room.  Each request reserves TWO slots because the cache returns an 8 B
//     pair whenever the lookup does not end at word offset 7.
//   * a self-driven prefetch chain: the predictor's port 2 answers with the
//     successor of the PC being requested and port 3 with the successor of
//     PC+4, so the pair's true successor (including a taken branch in slot 1)
//     is known before the next request is issued.
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
    parameter [31:0] EXEC_BYTES=32'h00008000,
    // Queue depth.  Area workstream M4a: 16 -> 8.  The queue carries five
    // 32-bit arrays plus per-entry flags, so every entry is ~165 FF; the
    // outstanding-request accounting already bounds prefetch by DEPTH-2, so a
    // shallower queue only shortens the prefetch runway.  The unit tests have
    // always driven this module at DEPTH=8, so 8 is the tested configuration.
    // See docs/architecture/module-area-plan.md M4a.
    parameter integer DEPTH=8
)(
    input wire clk,rst_n,enable,redirect_valid,
    input wire [31:0] fetch_pc,predicted_next_pc,
    output wire fetch_valid,input wire fetch_ready,input wire fetch_ready2,
    output wire [31:0] result_pc,result_inst,
    output wire [31:0] result_pc_hi,result_inst_hi,
    output wire result_pair,
    output wire [31:0] result_predicted_next_pc,
    output wire [31:0] result_predicted_next_pc_hi,
    output wire result_fault,output wire [4:0] result_fault_cause,
    output wire [31:0] result_fault_tval,
    output wire result_fault_hi,output wire [4:0] result_fault_cause_hi,
    output wire [31:0] result_fault_tval_hi,
    output wire idle,
    output wire eng_req_valid,input wire eng_req_ready,
    output wire [31:0] eng_req_addr,output wire [2:0] eng_req_size,
    output wire [7:0] eng_req_len,output wire [3:0] eng_req_id,
    input wire eng_rsp_valid,output wire eng_rsp_ready,
    input wire [31:0] eng_rsp_data,input wire [31:0] eng_rsp_data_hi,
    input wire eng_rsp_pair,input wire [1:0] eng_rsp_resp,
    // ---- T1/T10 prefetch chain --------------------------------------------
    // chain_c holds the PC of the next request; chain_c2 is chain_c+4 (the
    // second word of the same 8 B packet).  The predictor answers both.
    output wire [31:0] chain_c,
    input wire [31:0] chain_predict_next_pc,
    output wire [31:0] chain_c2,
    input wire [31:0] chain_predict_next_pc2,
    // Sticky debug tap: set when the head did not match the architectural PC
    // and the queue had to be dropped defensively (should never happen).
    output wire flush_lost
);
    localparam integer AW=$clog2(DEPTH);

    // ---- outstanding-request PC FIFO (slot 0 = oldest) ---------------------
    reg [31:0] pcf0_q,pcf1_q;
    reg [31:0] pdf0_q,pdf1_q;          // prediction of the first word
    reg [31:0] pdf0_q2,pdf1_q2;        // prediction of the second word (PC+4)
    reg [1:0] ocnt_q;                 // 0..2 accepted requests not yet answered
    // Responses still owed for a flushed stream.  Every one of them is
    // swallowed, so no late response is ever paired with a fresh PC.
    reg [2:0] stale_cnt_q;
    reg [31:0] next_pc_q;
    reg stop_q,lost_q;
    reg [AW:0] count_q;
    reg [AW-1:0] head_q,tail_q;
    reg [31:0] q_pc[0:DEPTH-1],q_inst[0:DEPTH-1],q_pred[0:DEPTH-1];
    reg [31:0] q_inst_hi[0:DEPTH-1],q_pred_hi[0:DEPTH-1];
    reg q_pair[0:DEPTH-1];
    reg q_fault[0:DEPTH-1];
    reg [4:0] q_cause[0:DEPTH-1];

    wire empty=(count_q==0);
    wire full=(count_q==DEPTH);
    wire [31:0] head_pc=q_pc[head_q];

    // Slots already promised: two per request still in flight.  A new request
    // is only raised while the reservation still leaves room for its pair.
    wire [AW+2:0] reserved={2'b00,count_q}+{1'b0,2'b00,ocnt_q,1'b0};

    // Nothing queued, nothing in flight, nothing owed: the architectural PC is
    // the one to fetch.  Requesting through fetch_ptr (instead of next_pc_q)
    // closes the one-cycle window right after a redirect in which next_pc_q
    // still held a stale chain PC while the queue had just been flushed.
    wire transparent=empty&&(ocnt_q==0)&&(stale_cnt_q==0);
    wire [31:0] fetch_ptr=transparent?fetch_pc:next_pc_q;
    assign chain_c=fetch_ptr;
    assign chain_c2=fetch_ptr+32'd4;
    assign flush_lost=lost_q;

    wire exec_ok=(fetch_ptr>=EXEC_BASE)&&((fetch_ptr-EXEC_BASE)<EXEC_BYTES);
    wire local_fault=|fetch_ptr[1:0]||!exec_ok;

    // An unwired second port ($z/$x) degrades to sequential prefetch instead of
    // a bogus address, so a testbench that ties off the optional prediction
    // ports keeps a well defined fetch stream.
    wire pred_unknown=(^predicted_next_pc)===1'bx;
    wire chain_unknown=(^chain_predict_next_pc)===1'bx;
    wire chain2_unknown=(^chain_predict_next_pc2)===1'bx;
    wire [31:0] chain_next=(fetch_ptr==fetch_pc&&!pred_unknown)?predicted_next_pc:
                           (!chain_unknown?chain_predict_next_pc:fetch_ptr+32'd4);
    // Successor of the *second* word (PC+4): its own predicted target when
    // taken, otherwise PC+8.  Only meaningful while chain_c2 == fetch_ptr+4.
    wire [31:0] chain2_next=(!chain2_unknown)?chain_predict_next_pc2:fetch_ptr+32'd8;

    // A pair can only be fetched when the requested word does not end the line.
    wire expect_pair=!local_fault&&(fetch_ptr[4:2]!=3'd7);
    wire first_taken=(chain_next!=fetch_ptr+32'd4);
    wire [31:0] packet_next=first_taken?chain_next:
                            (chain2_next != fetch_ptr+32'd8) ? chain2_next : fetch_ptr+32'd8;

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
                         (stale_cnt_q==0)&&(reserved<=(DEPTH-2))&&
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
    assign result_pair=q_pair[head_q];
    assign result_pc_hi=head_pc+32'd4;
    assign result_inst_hi=q_inst_hi[head_q];
    assign result_predicted_next_pc=q_pred[head_q];
    assign result_predicted_next_pc_hi=q_pred_hi[head_q];
    assign result_fault=q_fault[head_q];
    assign result_fault_cause=q_cause[head_q];
    assign result_fault_tval=head_pc;
    assign result_fault_hi=q_fault[head_q];
    assign result_fault_cause_hi=q_cause[head_q];
    assign result_fault_tval_hi=head_pc+32'd4;

    // Consumer can take two only when it says so and the head really is a pair.
    wire take2=fetch_valid&&result_pair&&fetch_ready2;
    wire take1=fetch_valid&&fetch_ready&&!take2;
    wire [1:0] deq_cnt=take2?2'd2:(take1?2'd1:2'd0);
    wire deq=(deq_cnt!=0);

    wire issue=eng_req_valid&&eng_req_ready;
    wire rsp_push=rsp_owned&&(stale_cnt_q==0);
    // The second word is only architectural when the first was predicted
    // fall-through; a predicted-taken first word makes it wrong-path.
    wire push2=rsp_push&&eng_rsp_pair&&(pdf0_q==pcf0_q+32'd4);
    wire local_push=rst_n&&enable&&!redirect_valid&&!stop_q&&
                    (reserved<=(DEPTH-2))&&
                    (ocnt_q==0)&&(stale_cnt_q==0)&&local_fault;
    wire [1:0] push_cnt=push2?2'd2:((rsp_push||local_push)?2'd1:2'd0);
    wire push=(push_cnt!=0);

    always @(posedge clk) begin
        if(!rst_n) begin
            pcf0_q<=0; pcf1_q<=0; pdf0_q<=0; pdf1_q<=0; pdf0_q2<=0; pdf1_q2<=0;
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

            // ---- push (one or two instructions) ----------------------------
            if(rsp_push) begin
                q_pc[tail_q]<=pcf0_q;
                q_inst[tail_q]<=eng_rsp_data;
                q_pred[tail_q]<=pdf0_q;
                q_inst_hi[tail_q]<=push2?eng_rsp_data_hi:32'd0;
                q_pred_hi[tail_q]<=push2?pdf0_q2:32'd0;
                q_pair[tail_q]<=push2;
                q_fault[tail_q]<=(eng_rsp_resp!=0);
                q_cause[tail_q]<=5'd1;
                if(push2) begin
                    q_pc[tail_q+1'b1]<=pcf0_q+32'd4;
                    q_inst[tail_q+1'b1]<=eng_rsp_data_hi;
                    q_pred[tail_q+1'b1]<=pdf0_q2;
                    q_inst_hi[tail_q+1'b1]<=32'd0;
                    q_pred_hi[tail_q+1'b1]<=32'd0;
                    q_pair[tail_q+1'b1]<=1'b0;
                    q_fault[tail_q+1'b1]<=(eng_rsp_resp!=0);
                    q_cause[tail_q+1'b1]<=5'd1;
                end
                if(eng_rsp_resp!=0) stop_q<=1;
            end else if(local_push) begin
                q_pc[tail_q]<=fetch_ptr;
                q_inst[tail_q]<=32'd0;
                q_pred[tail_q]<=chain_next;
                q_inst_hi[tail_q]<=32'd0;
                q_pred_hi[tail_q]<=32'd0;
                q_pair[tail_q]<=1'b0;
                q_fault[tail_q]<=1'b1;
                q_cause[tail_q]<=|fetch_ptr[1:0]?5'd0:5'd1;
                stop_q<=1;
            end
            if(deq) head_q<=head_q+deq_cnt;
            tail_q<=tail_q+{1'b0,push_cnt};
            count_q<=count_q+{1'b0,push_cnt}-{1'b0,deq_cnt};

            // ---- outstanding-request bookkeeping ---------------------------
            // The oldest entry leaves first, then the newly issued request is
            // registered.  When it lands in slot 0 the later assignment wins,
            // so a pop and a push on the same edge leave exactly one entry.
            if(rsp_owned) begin
                pcf0_q<=pcf1_q;
                pdf0_q<=pdf1_q;
                pdf0_q2<=pdf1_q2;
            end
            if(issue) begin
                case(ocnt_after_pop)
                    2'd0: begin
                        pcf0_q<=fetch_ptr; pdf0_q<=chain_next; pdf0_q2<=chain2_next;
                    end
                    default: begin
                        pcf1_q<=fetch_ptr; pdf1_q<=chain_next; pdf1_q2<=chain2_next;
                    end
                endcase
                ocnt_q<=ocnt_after_pop+2'd1;
                next_pc_q<=expect_pair?packet_next:chain_next;
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
