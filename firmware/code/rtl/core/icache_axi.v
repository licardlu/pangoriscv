//=============================================================================
// pangoriscv - RV32IM processor core + native AXI4 SoC (Pango PG2L100H @ 27 MHz)
// Module : icache_axi             File : rtl/core/icache_axi.v
// Rev    : 1.0                    Date : 2026-10-13
// Author : pango_lpenghan
// Brief  : 2-way set-associative I-cache (32 sets, 32 B line): hit answered in one cycle,
//          8-beat AXI4 burst line fill on miss
//=============================================================================

`include "axi_defs.vh"

// ---------------------------------------------------------------------------
// the caches/H1: two-way set-associative instruction cache.
//
// Geometry: 64 sets x 2 ways x 32 B lines = 4096 B.
//   tag       = addr[31:11]   (21 bits)
//   set index = addr[10:5]    (6 bits)
//   word      = addr[4:2]     (3 bits inside the 32 B line)
// Replacement: first invalid way, otherwise the 1-bit LRU victim.
//
// The engine-side interface is byte-for-byte the one axi_read_engine exposes,
// so this module can be dropped into pangoriscv_axi_top in its place. A lookup
// that misses issues ONE 8-beat INCR read (ARLEN=7, ARSIZE=2) on the AXI4 read
// channel and fills the whole line; the line is validated only after all eight
// beats came back OKAY with matching RID and a last-beat RLAST. A beat error, a
// lost RID, a short burst or an invalidation landing while the burst is in
// flight leaves the line invalid, so stale code can never be re-validated.
//
// Hit latency (T3/T9): a hit is answered on the accept edge -- the word RAM is
// read combinationally from the incoming request, so the engine sees rsp_valid
// one cycle after the request handshake.  A new lookup may be accepted on that
// same edge (the edge the response is taken), so a run of hits sustains ONE
// lookup per cycle; the older build parked in IC_RESP for an extra cycle and
// accepted only every other cycle (2 cycles per lookup, was 4 before T3).
// A miss keeps the original serialised AR/FILL/MISS_RD path.
//
// FENCE.I stays an illegal instruction (plan section 15 option), so the only
// invalidation sources are reset and the explicit `invalidate` pulse, which the
// SoC drives from the halt path: JTAG/down-loader writes followed by a resume
// therefore always see fresh code.
// ---------------------------------------------------------------------------
module icache_axi (
    input wire clk, rst_n,
    input wire invalidate,
    // engine-side lookup interface (identical to axi_read_engine)
    input wire req_valid,
    output wire req_ready,
    input wire [31:0] req_addr,
    input wire [2:0] req_size,
    input wire [7:0] req_len,
    input wire [3:0] req_id,
    output reg rsp_valid,
    input wire rsp_ready,
    output reg [31:0] rsp_data,
    // Second word of the requested 8 B pair.  rsp_pair=0 when the pair would
    // cross the 32 B line (word offset 7), in which case the IFU issues single.
    output reg [31:0] rsp_data_hi,
    output reg rsp_pair,
    // Combinational, valid while the request handshake is in progress: "the
    // response to THIS request will carry two words".  The IFU must know this
    // in the same cycle it raises the request, because it decides there whether
    // the prefetch pointer advances by 4 or by 8.  Both sides read the same
    // value on the same edge, so they cannot disagree.
    output wire req_pair_ahead,
    output reg [1:0] rsp_resp,
    output reg [3:0] rsp_id,
    output reg protocol_fault,
    output reg config_fault,
    // one-cycle performance pulses (used when PERF_ENABLE wires them up)
    output reg miss_pulse,
    output reg access_pulse,
    // AXI4 read master
    output wire m_arvalid,
    input wire m_arready,
    output wire [31:0] m_araddr,
    output wire [3:0] m_arid,
    output wire [7:0] m_arlen,
    output wire [2:0] m_arsize,
    output wire [1:0] m_arburst,
    output wire m_arlock,
    output wire [3:0] m_arcache,
    output wire [2:0] m_arprot,
    output wire [3:0] m_arqos,
    input wire m_rvalid,
    output wire m_rready,
    input wire [31:0] m_rdata,
    input wire [3:0] m_rid,
    input wire [1:0] m_rresp,
    input wire m_rlast
);
    // 4 KB variant: 64 sets x 2 ways x 32 B.  The 8 KB/128-set geometry is what
    // the dual-issue build used first, but the 25k-LUT design could not be
    // routed on this PDS flow; 4 KB recovers ~2.2k LUT / 2.6k FF.  Score trade-
    // off must be measured, not assumed (see evidence: P20 4 KB vs P21 8 KB).
    localparam SETS=64, WORDS=8, LINE_BEATS=8;  // 64 x 2 x 32 B = 4096 B
    localparam IC_IDLE=3'd0, IC_RESP=3'd1, IC_AR=3'd2,
               IC_FILL=3'd3, IC_MISS_RD=3'd4, IC_FAULT=3'd5;

    // Flat arrays: PDS parses these sources as Verilog, so no packed/unpacked
    // multidimensional memories are used here.
    //
    // T3/T10 two-word fetch: the line is split into an even-word bank and an
    // odd-word bank, one 32 b read port each.  A lookup at any word offset
    // w != 7 can therefore return words w and w+1 in one cycle:
    //   even bank index = {way,set,(w+1)>>1}, odd bank index = {way,set,w>>1}
    //   w even -> (even,odd);  w odd -> (odd,even)
    // The total bit count is unchanged (SETS*2*WORDS*32).
    //
    // P14 (2026-10-22): the way bit moved OUT of the data-array index.  Each
    // bank is split into a per-way half (even_w0/even_w1/odd_w0/odd_w1,
    // 256x32 each) so the hit lookup reads BOTH ways unconditionally and
    // `hit0` only selects the way at the output mux.  Before this, the index
    // carried `hit_way = f(tag compare)`, putting the tag LUTRAM read and its
    // comparison in SERIES with the data LUTRAM read -- exactly the tail of
    // the 24.65 ns critical path (p13seed7 .rtr: tag_mem DO -> hit0 -> _N82
    // fanout 159 -> odd_mem DO -> mux -> rsp_data_hi_q).  Tag compare and
    // data read now run in PARALLEL.  Zero CPI (same accept-edge response),
    // area-neutral (same total bits, same 2 read ports per logical array).
    // See docs/plan-score-5.2-120mhz-v9.md section 2 S1.
    reg [31:0] even_w0[0:SETS*(WORDS/2)-1];
    reg [31:0] even_w1[0:SETS*(WORDS/2)-1];
    reg [31:0] odd_w0 [0:SETS*(WORDS/2)-1];
    reg [31:0] odd_w1 [0:SETS*(WORDS/2)-1];
    reg [20:0] tag_mem  [0:SETS*2-1];         // {way,set}
    reg        valid_mem[0:SETS*2-1];         // {way,set}
    reg        lru_mem  [0:SETS-1];           // 1 = way1 is the LRU victim

    // ---- cross-line pair side arrays (plan v7 section 1) -------------------
    // Word offset 7 needs (word7 of line L, word0 of line L+32B).  The two words
    // live in two different sets, so the banked data array cannot serve them in
    // one cycle.  These two arrays hold {tag, word0} of whatever line sits in
    // way0/way1 of a set, indexed by that set alone: reading both gives the
    // linear successor of any line without a second port on the main array.
    // `succv0/succv1` mirror valid_mem for exactly those entries and are the
    // only part that has to be reset/invalidated, which a plain FF array can do
    // in one cycle (a distributed RAM cannot).
    reg [52:0] succ0_mem[0:SETS-1];           // {tag[20:0], word0[31:0]}
    reg [52:0] succ1_mem[0:SETS-1];
    reg        succv0[0:SETS-1];
    reg        succv1[0:SETS-1];
    reg [31:0] fill_w0_q;                      // beat 0 of the line being filled

    reg [2:0] state;
    reg [31:0] addr_q;
    reg [3:0] id_q;
    reg [5:0] set_q;
    reg [2:0] word_q;
    reg [20:0] tag_q;
    reg way_q;
    reg [9:0] rd_index_q;
    reg [31:0] rsp_data_q;
    reg [31:0] rsp_data_hi_q;
    reg        rsp_pair_q;
    reg [1:0] rsp_resp_q;
    reg [2:0] beat_q;
    reg fill_bad_q, fill_kill;
    reg [1:0] fill_resp_q;
    integer i;

    wire [5:0] req_set = req_addr[10:5];
    wire [20:0] req_tag = req_addr[31:11];
    wire hit0 = valid_mem[{1'b0,req_set}] && (tag_mem[{1'b0,req_set}]==req_tag);
    wire hit1 = valid_mem[{1'b1,req_set}] && (tag_mem[{1'b1,req_set}]==req_tag);
    wire miss_way = !valid_mem[{1'b0,req_set}] ? 1'b0 :
                    (!valid_mem[{1'b1,req_set}] ? 1'b1 : lru_mem[req_set]);
    // T3 fast hit path: both ways' word RAMs are read combinationally from the
    // incoming request (the way bit is NOT in the index -- see the P14 note on
    // the array declarations), so a hit can be answered on the accept edge
    // without waiting for the tag comparison to pick a way.  The address the
    // miss path uses later is still registered into rd_index_q.
    wire [2:0] hit_word_off = req_addr[4:2];
    wire [2:0] hit_e_off = (hit_word_off + 3'd1) >> 1;   // ceil(w/2)
    wire [2:0] hit_o_off = hit_word_off >> 1;            // floor(w/2)
    wire [7:0] hit_e_index = {req_addr[10:5], hit_e_off[1:0]};
    wire [7:0] hit_o_index = {req_addr[10:5], hit_o_off[1:0]};
    // Parallel per-way reads; the tag comparison only steers the output mux.
    wire [31:0] hit_even_w0 = even_w0[hit_e_index];
    wire [31:0] hit_even_w1 = even_w1[hit_e_index];
    wire [31:0] hit_odd_w0  = odd_w0 [hit_o_index];
    wire [31:0] hit_odd_w1  = odd_w1 [hit_o_index];
    wire [31:0] hit_even = hit0 ? hit_even_w0 : hit_even_w1;
    wire [31:0] hit_odd  = hit0 ? hit_odd_w0  : hit_odd_w1;
    wire [31:0] hit_word = hit_word_off[0] ? hit_odd  : hit_even;

    // Cross-line successor lookup.  nxt_set/nxt_tag describe the 32 B line that
    // starts 8 B after this request, i.e. exactly the line word 8 lives in.
    // The set index wraps inside the cache, so the tag has to take the carry.
    wire [5:0]  nxt_set  = req_addr[10:5] + 6'd1;
    wire [20:0] nxt_tag  = req_tag + {20'd0,(req_addr[10:5]=={6{1'b1}})};
    wire [52:0] succ0_w  = succ0_mem[nxt_set];
    wire [52:0] succ1_w  = succ1_mem[nxt_set];
    wire        succ_ok0 = succv0[nxt_set] && (succ0_w[52:32]==nxt_tag);
    wire        succ_ok1 = succv1[nxt_set] && (succ1_w[52:32]==nxt_tag);
    wire [31:0] succ_word0 = succ_ok1 ? succ1_w[31:0] : succ0_w[31:0];
    // A cross-line pair is only safe when the current line hits (otherwise the
    // miss path answers, and it returns a single word at offset 7) and the
    // successor line is resident with the expected tag.
    wire        xline_ok  = (hit_word_off==3'd7) && (hit0||hit1) && (succ_ok0||succ_ok1);
    wire        pair_now  = (hit_word_off!=3'd7) || xline_ok;
    assign      req_pair_ahead = pair_now;
    wire [31:0] hit_word_hi = (hit_word_off!=3'd7) ?
                              (hit_word_off[0] ? hit_even : hit_odd) : succ_word0;

    // The line address is {tag,set,5'b0}: the 32 B line the requested word is in.
    wire [31:0] line_addr = {tag_q, set_q, 5'b0};

    // Miss-path pair reconstruction.  rd_index_q is {set[6:0],way,word[2:0]}
    // for the delivered 8 KB geometry (SETS=128); keep the two bank indices
    // derived from it so a missed lookup also returns both words.
    wire [2:0]  rd_word   = rd_index_q[2:0];
    wire [5:0]  rd_set    = rd_index_q[9:4];
    wire        rd_way    = rd_index_q[3];
    wire [2:0]  rd_e_off  = (rd_word + 3'd1) >> 1;
    wire [2:0]  rd_o_off  = rd_word >> 1;
    wire        rd_pair   = (rd_word != 3'd7);
    wire [7:0]  rd_e_index = {rd_set, rd_e_off[1:0]};
    wire [7:0]  rd_o_index = {rd_set, rd_o_off[1:0]};
    // Miss-path replay: way is known here (it is in rd_index_q), so this read
    // selects its half directly -- it shares each half's second read port.
    wire [31:0] rd_even = rd_way ? even_w1[rd_e_index] : even_w0[rd_e_index];
    wire [31:0] rd_odd  = rd_way ? odd_w1 [rd_o_index] : odd_w0 [rd_o_index];
    wire [31:0] rd_word0 = rd_word[0] ? rd_odd : rd_even;
    wire [31:0] rd_word1 = rd_pair ? (rd_word[0] ? rd_even : rd_odd) : 32'd0;
    wire beat_bad = (m_rresp!=`AXI_RESP_OKAY);
    wire line_bad = fill_bad_q || beat_bad;

    // T9 back-to-back hit path: a lookup may also be accepted on the edge the
    // previous response is taken.  The output register is reloaded at that same
    // edge, so the response the engine is taking now is never disturbed; a run
    // of hits therefore sustains one lookup per cycle instead of one per two.
    wire rsp_leaving = (state==IC_RESP) && rsp_valid && rsp_ready;
    assign req_ready = rst_n && (state==IC_IDLE || rsp_leaving);
    assign m_arvalid = rst_n && state==IC_AR;
    assign m_araddr = line_addr;
    assign m_arid = id_q;
    assign m_arlen = 8'd7;                     // 8 beats == one 32 B line
    assign m_arsize = 3'd2;                    // 4 B per beat
    assign m_arburst = `AXI_BURST_INCR;
    assign m_arlock = 1'b0;
    assign m_arcache = 4'b0000;
    assign m_arprot = 3'b000;
    assign m_arqos = 4'b0000;
    assign m_rready = rst_n && state==IC_FILL;

    always @(posedge clk) begin
        if(!rst_n) begin
            state<=IC_IDLE;
            addr_q<=0; id_q<=0; set_q<=0; word_q<=0; tag_q<=0; way_q<=0;
            rd_index_q<=0; rsp_data_q<=0; rsp_data_hi_q<=0; rsp_pair_q<=0;
            rsp_resp_q<=0; beat_q<=0;
            fill_bad_q<=0; fill_kill<=0; fill_resp_q<=0;
            rsp_valid<=0; rsp_data<=0; rsp_data_hi<=0; rsp_pair<=0; rsp_resp<=0; rsp_id<=0;
            protocol_fault<=0; config_fault<=0; miss_pulse<=0; access_pulse<=0;
            // Only the VALID bits are reset.  tag_mem is deliberately left
            // uninitialised: a distributed-RAM array cannot be cleared entry by
            // entry, and that per-entry clear was what kept the 128x21 tag array
            // (2,688 registers) out of LUTRAM -- the D-cache tag has always been
            // cleared only through valid_mem and infers as ram64x1d.  Correctness
            // is unchanged: a line is only a hit when valid_mem is set, and valid
            // is only set on the fill edge that also writes its tag.
            for(i=0;i<SETS*2;i=i+1) valid_mem[i]<=0;
            for(i=0;i<SETS;i=i+1) lru_mem[i]<=0;
            for(i=0;i<SETS;i=i+1) begin succv0[i]<=0; succv1[i]<=0; end
            fill_w0_q<=0;
        end else begin
            miss_pulse<=0;
            access_pulse<=0;
            rsp_valid<=0;
            if(invalidate) begin
                for(i=0;i<SETS*2;i=i+1) valid_mem[i]<=0;
                // The side arrays keep their data (a distributed RAM cannot be
                // cleared entry by entry) and are invalidated through these two
                // FF arrays, which do clear in one cycle.  `invalidate` is a
                // level in this SoC (halt/download/resume), so a level clear is
                // enough: it is still high on every cycle a fill could race it.
                for(i=0;i<SETS;i=i+1) begin succv0[i]<=0; succv1[i]<=0; end
                // A burst in flight must not re-validate the line it is filling.
                if(state==IC_AR || state==IC_FILL) fill_kill<=1;
            end
            case(state)
                IC_IDLE, IC_RESP: begin
                    // Parked with a response: keep re-asserting it until the
                    // engine takes it.  One lookup produces exactly one engine
                    // response because the register drops on the handshake edge.
                    if(state==IC_RESP && !(rsp_valid && rsp_ready)) begin
                        rsp_valid<=1;
                        rsp_data<=rsp_data_q;
                        rsp_data_hi<=rsp_data_hi_q;
                        rsp_pair<=rsp_pair_q;
                        rsp_resp<=rsp_resp_q;
                        rsp_id<=id_q;
                    end
                    // Request acceptance.  req_ready is high in IC_IDLE, and in
                    // IC_RESP only on the edge the pending response leaves, so
                    // this branch never overwrites a response still on the wire.
                    if(req_valid && req_ready) begin
                        addr_q<=req_addr;
                        id_q<=req_id;
                        set_q<=req_addr[10:5];
                        word_q<=req_addr[4:2];
                        tag_q<=req_addr[31:11];
                        if(hit0 || hit1) begin
                            access_pulse<=1;
                            way_q<=hit0 ? 1'b0 : 1'b1;
                            lru_mem[req_addr[10:5]]<=hit0 ? 1'b1 : 1'b0;
                            // Fast hit: answer on the accept edge (engine sees the
                            // response one cycle after req_valid/req_ready). Both the
                            // holding register and the output register are loaded so
                            // the IC_RESP hold path stays correct if rsp_ready is late.
                            rsp_data_q<=hit_word;
                            rsp_data_hi_q<=hit_word_hi;
                            rsp_pair_q<=pair_now;
                            rsp_resp_q<=`AXI_RESP_OKAY;
                            rsp_valid<=1;
                            rsp_data<=hit_word;
                            rsp_data_hi<=hit_word_hi;
                            rsp_pair<=pair_now;
                            rsp_resp<=`AXI_RESP_OKAY;
                            rsp_id<=req_id;
                            state<=IC_RESP;
                        end else begin
                            miss_pulse<=1;
                            way_q<=miss_way;
                            beat_q<=0;
                            fill_bad_q<=0;
                            fill_resp_q<=0;
                            fill_kill<=0;
                            // A response taken on this edge must not repeat.
                            rsp_valid<=0;
                            state<=IC_AR;
                        end
                    end else if(state==IC_RESP && rsp_valid && rsp_ready) begin
                        state<=IC_IDLE;
                    end
                end
                IC_AR: if(m_arvalid && m_arready) state<=IC_FILL;
                IC_FILL: if(m_rvalid) begin
                    if(m_rid!=id_q) begin
                        // Lost framing is a protocol fault, never a data beat.
                        protocol_fault<=1;
                        state<=IC_FAULT;
                    end else begin
                        if(beat_bad) begin
                            fill_bad_q<=1;
                            fill_resp_q<=m_rresp;
                        end
                        if(!fill_kill) begin
                            // Fill writes route by way_q into the per-way halves
                            // (P14 split -- see the array declarations).
                            if(!beat_q[0]) begin
                                if(!way_q) even_w0[{set_q,beat_q[2:1]}]<=m_rdata;
                                else       even_w1[{set_q,beat_q[2:1]}]<=m_rdata;
                            end else begin
                                if(!way_q) odd_w0 [{set_q,beat_q[2:1]}]<=m_rdata;
                                else       odd_w1 [{set_q,beat_q[2:1]}]<=m_rdata;
                            end
                            // Beat 0 is this line's word 0 -- the very word a
                            // cross-line pair needs as its second half.
                            if(beat_q==3'd0) fill_w0_q<=m_rdata;
                        end
                        if(m_rlast) begin
                            if(beat_q!=3'd7) begin
                                protocol_fault<=1;
                                state<=IC_FAULT;
                            end else begin
                                if(!fill_kill && !line_bad) begin
                                    tag_mem[{way_q,set_q}]<=tag_q;
                                    valid_mem[{way_q,set_q}]<=1'b1;
                                    // Publish {tag, word0} for this {set,way} so
                                    // the line BEFORE it can answer a
                                    // cross-line pair out of the side array.
                                    if(!way_q) begin
                                        succ0_mem[set_q]<={tag_q,fill_w0_q};
                                        succv0[set_q]<=1'b1;
                                    end else begin
                                        succ1_mem[set_q]<={tag_q,fill_w0_q};
                                        succv1[set_q]<=1'b1;
                                    end
                                end
                                lru_mem[set_q]<=~way_q;
                                // A failed beat is returned to the IFU as a fetch
                                // fault; the line stays invalid.
                                if(line_bad) rsp_resp_q<=(beat_bad ? m_rresp : fill_resp_q);
                                else rsp_resp_q<=`AXI_RESP_OKAY;
                                rd_index_q<={set_q,way_q,word_q};
                                state<=IC_MISS_RD;
                            end
                        end else begin
                            beat_q<=beat_q+3'd1;
                        end
                    end
                end
                IC_MISS_RD: begin
                    rsp_data_q   <= rd_word0;
                    rsp_data_hi_q<= rd_word1;
                    rsp_pair_q   <= rd_pair;
                    state<=IC_RESP;
                end
                IC_FAULT: state<=IC_FAULT;
                default: begin
                    protocol_fault<=1;
                    state<=IC_FAULT;
                end
            endcase
        end
    end
endmodule

