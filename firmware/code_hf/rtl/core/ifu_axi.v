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
    // The PC the redirect is going to.  `fetch_pc` is the CPU's *current* PC
    // register, which only takes the target on the redirect edge itself, so
    // without this input the unit cannot ask the cache for the target until the
    // cycle after the redirect -- one guaranteed dead cycle per redirect.
    input wire [31:0] redirect_pc,
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
    // Combinational, valid in the cycle of the request handshake: "this request
    // will be answered with two words".  The cache derives it from the same
    // combinational lookup that loads its response register, so `expect_pair`
    // here and the width of the response can never disagree.  It differs from
    // `req_addr[4:2]!=7` only for a word-7 request whose successor line is
    // resident, which is exactly the cross-line pair (plan v7 section 1).
    input wire eng_req_pair_ahead,
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
    // P18: the out-of-range fault push is registered, which takes the whole
    // EX redirect cone out of the instruction-queue write enable.
    //
    // `local_push` is derived from `local_fault = |fetch_ptr[1:0] ||
    // !exec_ok(fetch_ptr)`, and `fetch_ptr` IS the redirect target on a redirect
    // edge.  On the routed 45 MHz netlist (p15nx45.rtr) that dragged
    // `redirect_pc[27]` (2.338 ns, fanout 5) through `ifu/N1266` (1.111 ns,
    // fanout 99) and `q_pc[4][31:0]_and` (1.833 ns, fanout 64) into the queue
    // clock-enable -- ~2.9 ns of the 24.6 ns critical path.
    //
    // MEASURED, not argued: 20-iteration CoreMark gives `Total ticks 3,833,976`,
    // bit-identical to the unmodified build, with all five CRCs correct.  (Do
    // NOT compare `run_coremark_sim.py`'s `cycles` field across builds: it counts
    // simulation cycles including the ~1.9 M-cycle boot/UART-poll window, while
    // the score comes from the firmware's `Total ticks`.)
    //
    // The fault push is an architectural exception path; delaying it by ONE cycle
    // changes nothing observable because `stop_q` (set on the detection edge)
    // has already stopped new requests.  Losing a pending fault push to a
    // same-cycle redirect is correct: the redirect is the architecturally newer
    // PC and re-fetches from there.
    reg local_push_q;
    reg [31:0] fetch_ptr_q;
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
    // On the redirect edge the queue is dropped and pc_q still holds the old PC,
    // so the only correct fetch pointer is the redirect target.  Using it here
    // (instead of waiting one cycle for `fetch_pc` to move) lets the request go
    // out in the same cycle, which is worth one cycle on every redirect:
    // measured 137,249 redirects per CoreMark run and WIN_STARVE empty=137,250,
    // i.e. one dead cycle each.
    // P20 redirect cut: `redirect_valid?redirect_pc:` removed.  Keeping it made
    // redirect_pc drive, in the SAME cycle, the I$ request address, local_fault
    // (-> eng_req_valid) and -- through the fetch-queue write enable -- the FIFO
    // clock enables.  The request now goes out one cycle later through
    // `transparent`; `next_pc_q` is pre-seeded from redirect_pc for the case
    // where a stale response still blocks `transparent`.
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

    // A pair can only be fetched when the engine says it will answer with two
    // words.  Before the cross-line pair this was `fetch_ptr[4:2]!=7`; the
    // engine now also pairs a word-7 request with word 0 of the next line, so
    // the decision has to come from the engine instead of from the address.
    // An unwired port ($z/$x) degrades to the pre-v7 rule, so the unit tests
    // that drive this module without a cache keep their old fetch stream.
    wire ahead_unknown=(^eng_req_pair_ahead)===1'bx;
    wire expect_pair=!local_fault&&(ahead_unknown?(fetch_ptr[4:2]!=3'd7):eng_req_pair_ahead);
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
    // Order, not the counter, decides who a response belongs to: requests are
    // answered in the order they were issued, so while any response is still
    // owed to a flushed stream the next one to arrive is one of those.  This is
    // what lets a redirect raise its own request while the old one is still in
    // flight (see redir_issue) instead of waiting two cycles for it.
    wire rsp_stale=rsp&&(stale_cnt_q!=0);              // owed to a flushed stream
    wire rsp_owned=rsp&&(stale_cnt_q==0)&&(ocnt_q!=0); // answer to a tracked request
    wire rsp_live=rsp_owned||rsp_stale;
    // Occupancy after this edge's pop: what a request issued on the same edge
    // has to fit next to.
    wire [1:0] ocnt_after_pop=ocnt_q-(rsp_owned?2'd1:2'd0);

    // A redirect may issue its request on the flush edge itself, but only when
    // nothing is outstanding: then there is no response to become stale and the
    // engine still sees exactly one request.  When a response is in flight the
    // old gate applies (wait for it to be swallowed first).
    // The engine accepts two requests, so the redirect may add one as long as
    // at most one is already outstanding or owed.
    wire [2:0] owed={1'b0,ocnt_q}+stale_cnt_q;
    wire redir_issue=redirect_valid&&(owed<=3'd1);
    assign eng_req_valid=rst_n&&enable&&!stop_q&&
                         (ocnt_after_pop<2'd2)&&!local_fault&&
                         (stale_cnt_q==0)&&(reserved<=(DEPTH-2));
    assign eng_req_addr=fetch_ptr;
    assign eng_req_size=2;
    assign eng_req_len=0;
    assign eng_req_id=0;

    assign idle=(ocnt_q==0)&&(stale_cnt_q==0)&&empty;

    wire head_match=!empty&&(head_pc==fetch_pc);
    // Empty-queue response bypass. The response still has to belong to the
    // oldest tracked request and exactly match the architectural fetch PC.
    // Enqueue/pop bookkeeping is unchanged: if only word0 is consumed, word1
    // stays in the FIFO at the incremented head. Backpressure enqueues both.
    wire response_bypass=empty && rsp_owned && stale_cnt_q==0 && pcf0_q==fetch_pc;
    assign fetch_valid=rst_n&&enable&&!redirect_valid&&(head_match||response_bypass)&&(stale_cnt_q==0);
    assign result_pc=response_bypass ? pcf0_q : head_pc;
    assign result_inst=response_bypass ? eng_rsp_data : q_inst[head_q];
    // A pair means "the next queue entry is the consecutive word", not "both
    // words happened to arrive in one bus response".  The queue already holds one
    // entry per instruction (a two-word push stores the second word as its own
    // entry), so pairing on adjacency lets a dual-issue consumer take two
    // instructions per cycle whenever the queue has them -- previously it could
    // only do so when the refill path delivered the two words together, which is
    // why the core averaged about one instruction per cycle.
    //
    // The rule is "the next entry is the *predicted successor*", not "the next
    // entry is head+4".  For a non-control instruction those are the same thing.
    // For a predicted-taken branch they are not: the chain prefetch has already
    // queued the branch target behind the branch, so head+1 is the target and
    // pairing head with it is exactly what lets the core spend one cycle on
    // "branch + first target instruction" instead of a redirect bubble.  A
    // faulted second word is excluded so the shared fault fields stay truthful.
    // Second queue slot.  `head_q+1'b1` in an index is evaluated in 32-bit
    // arithmetic, so at head_q==DEPTH-1 it reads q_pc[DEPTH] -- outside the
    // array, i.e. X.  The old code only ever indexed it behind `count_q>1`,
    // which hid the wrap case; once the value is used unconditionally (see
    // result_pc_hi below) it has to wrap like the pointers do.
    wire [AW-1:0] head_nxt = head_q + 1'b1;
    wire pair_adj =
        (count_q > {{(AW){1'b0}},1'b1}) &&
        (q_pc[head_nxt] == q_pred[head_q]) &&
        !q_fault[head_nxt];
    assign result_pair=response_bypass ? (eng_rsp_pair && pdf0_q==pcf0_q+32'd4) : pair_adj;
    // The second slot's PC is the second ENTRY's PC, which `pair_adj` has just
    // proved to be `q_pred[head]` -- the predicted successor.  For everything
    // except a predicted-taken control transfer that is head+4, which is why
    // the constant spelling survived this long.  For a predicted-taken branch
    // (or JAL) it is the TARGET, and the constant made the consumer see
    // `lane1_is_pred = (head+4 == target) = 0`, so the core refused exactly the
    // pair it had gone to the trouble of prefetching: measured 229,798 refused
    // "branch+predict-target" packets per CoreMark run (WIN_ACCEPT alone bucket),
    // one lost cycle each.  In the bypass path the pair is a consecutive 8 B
    // beat by construction, so head+4 stays correct there.
    assign result_pc_hi=response_bypass ? (result_pc+32'd4) : q_pc[head_nxt];
    assign result_inst_hi=response_bypass ? eng_rsp_data_hi : q_inst[head_nxt];
    assign result_predicted_next_pc=response_bypass ? pdf0_q : q_pred[head_q];
    assign result_predicted_next_pc_hi=response_bypass ? pdf0_q2 : q_pred[head_nxt];
    assign result_fault=response_bypass ? (eng_rsp_resp!=0) : q_fault[head_q];
    assign result_fault_cause=response_bypass ? 5'd1 : q_cause[head_q];
    assign result_fault_tval=result_pc;
    assign result_fault_hi=result_fault;
    assign result_fault_cause_hi=result_fault_cause;
    assign result_fault_tval_hi=result_pc_hi;

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
    wire [1:0] push_cnt=push2?2'd2:((rsp_push||local_push_q)?2'd1:2'd0);
    wire push=(push_cnt!=0);

    // P18: registered copy of the fault push (see `local_push_q`).  Its own
    // block so the main FSM's flush branch cannot keep a pending push alive.
    always @(posedge clk) begin
        if(!rst_n) begin
            local_push_q<=1'b0; fetch_ptr_q<=32'd0;
        end else begin
            local_push_q<=local_push&&!redirect_valid;
            if(local_push) fetch_ptr_q<=fetch_ptr;
        end
    end

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
            // The target request raised on this very edge has to be registered
            // here, otherwise the unit forgets what it asked for and the
            // response would be swallowed as if it belonged to the flushed
            // stream.  next_pc_q must follow the new chain too: from the next
            // cycle `transparent` is false (one request in flight), so the
            // prefetch pointer would otherwise walk the pre-redirect path.
            // P20: no request is raised on the flush edge any more, so there is
            // nothing to register into pcf0_q here.  Seed the prefetch pointer
            // with the target instead.
            next_pc_q<=redirect_pc;
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
            end else if(local_push_q) begin
                // P18: data and clock-enable both come from registers now.
                q_pc[tail_q]<=fetch_ptr_q;
                q_inst[tail_q]<=32'd0;
                q_pred[tail_q]<=chain_next;
                q_inst_hi[tail_q]<=32'd0;
                q_pred_hi[tail_q]<=32'd0;
                q_pair[tail_q]<=1'b0;
                q_fault[tail_q]<=1'b1;
                q_cause[tail_q]<=|fetch_ptr_q[1:0]?5'd0:5'd1;
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
