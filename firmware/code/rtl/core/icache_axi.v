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
//   tag       = addr[31:SETW+5]  (TAGW bits, 20 for the 8 KB geometry)
//   set index = addr[SETW+4:5]   (SETW bits, 7 for the 8 KB geometry)
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
    // 8 KB: 128 sets x 2 ways x 32 B.  The 4 KB shrink was forced by the 25k-LUT
    // netlist that could not be routed; after E2 (17.5k LUT, 19% distributed RAM)
    // the 128-set geometry fits again, and P20/P21 measured 4 KB -> 8 KB at
    // +2.55% (2.8115 -> 2.8833 on the same 832-iteration image).
    // Widths are DERIVED from SETS so the two geometries cannot drift again.
    localparam SETS=128, WORDS=8, LINE_BEATS=8;  // 128 x 2 x 32 B = 8192 B
    localparam SETW = $clog2(SETS);              // set index bits
    localparam TAGW = 32 - SETW - 5;             // tag bits
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
    reg [31:0] even_mem[0:SETS*2*(WORDS/2)-1];
    reg [31:0] odd_mem [0:SETS*2*(WORDS/2)-1];
    reg [TAGW-1:0] tag_mem [0:SETS*2-1];      // {way,set}
    reg        valid_mem[0:SETS*2-1];         // {way,set}
    reg        lru_mem  [0:SETS-1];           // 1 = way1 is the LRU victim

    reg [2:0] state;
    reg [31:0] addr_q;
    reg [3:0] id_q;
    reg [SETW-1:0] set_q;
    reg [2:0] word_q;
    reg [TAGW-1:0] tag_q;
    reg way_q;
    reg [SETW+3:0] rd_index_q;
    reg [31:0] rsp_data_q;
    reg [31:0] rsp_data_hi_q;
    reg        rsp_pair_q;
    reg [1:0] rsp_resp_q;
    reg [2:0] beat_q;
    reg fill_bad_q, fill_kill;
    reg [1:0] fill_resp_q;
    integer i;

    wire [SETW-1:0] req_set = req_addr[SETW+4:5];
    wire [TAGW-1:0] req_tag = req_addr[31:SETW+5];
    wire hit0 = valid_mem[{1'b0,req_set}] && (tag_mem[{1'b0,req_set}]==req_tag);
    wire hit1 = valid_mem[{1'b1,req_set}] && (tag_mem[{1'b1,req_set}]==req_tag);
    wire miss_way = !valid_mem[{1'b0,req_set}] ? 1'b0 :
                    (!valid_mem[{1'b1,req_set}] ? 1'b1 : lru_mem[req_set]);
    // T3 fast hit path: the word RAM is read combinationally from the incoming
    // request, so a hit can be answered on the accept edge instead of going
    // through a separate read state. The address the miss path uses later is
    // still registered into rd_index_q.
    wire       hit_way  = hit0 ? 1'b0 : 1'b1;
    wire [2:0] hit_word_off = req_addr[4:2];
    wire [2:0] hit_e_off = (hit_word_off + 3'd1) >> 1;   // ceil(w/2)
    wire [2:0] hit_o_off = hit_word_off >> 1;            // floor(w/2)
    wire       hit_pair  = (hit_word_off != 3'd7);
    wire [SETW+2:0] hit_e_index = {req_addr[SETW+4:5], hit_way, hit_e_off[1:0]};
    wire [SETW+2:0] hit_o_index = {req_addr[SETW+4:5], hit_way, hit_o_off[1:0]};
    wire [31:0] hit_even = even_mem[hit_e_index];
    wire [31:0] hit_odd  = odd_mem [hit_o_index];
    wire [31:0] hit_word    = hit_word_off[0] ? hit_odd  : hit_even;
    wire [31:0] hit_word_hi = hit_pair ?
                              (hit_word_off[0] ? hit_even : hit_odd) : 32'd0;
    // The line address is {tag,set,5'b0}: the 32 B line the requested word is in.
    wire [31:0] line_addr = {tag_q, set_q, 5'b0};

    // Miss-path pair reconstruction.  rd_index_q is {set,way,word[2:0]}; the two
    // bank indices are derived from it so a missed lookup also returns both words.
    wire [2:0]  rd_word   = rd_index_q[2:0];
    wire [SETW-1:0] rd_set = rd_index_q[SETW+3:4];
    wire        rd_way    = rd_index_q[3];
    wire [2:0]  rd_e_off  = (rd_word + 3'd1) >> 1;
    wire [2:0]  rd_o_off  = rd_word >> 1;
    wire        rd_pair   = (rd_word != 3'd7);
    wire [SETW+2:0] rd_e_index = {rd_set, rd_way, rd_e_off[1:0]};
    wire [SETW+2:0] rd_o_index = {rd_set, rd_way, rd_o_off[1:0]};
    wire [31:0] rd_even = even_mem[rd_e_index];
    wire [31:0] rd_odd  = odd_mem [rd_o_index];
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
        end else begin
            miss_pulse<=0;
            access_pulse<=0;
            rsp_valid<=0;
            if(invalidate) begin
                for(i=0;i<SETS*2;i=i+1) valid_mem[i]<=0;
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
                        set_q<=req_addr[SETW+4:5];
                        word_q<=req_addr[4:2];
                        tag_q<=req_addr[31:SETW+5];
                        if(hit0 || hit1) begin
                            access_pulse<=1;
                            way_q<=hit0 ? 1'b0 : 1'b1;
                            lru_mem[req_addr[SETW+4:5]]<=hit0 ? 1'b1 : 1'b0;
                            // Fast hit: answer on the accept edge (engine sees the
                            // response one cycle after req_valid/req_ready). Both the
                            // holding register and the output register are loaded so
                            // the IC_RESP hold path stays correct if rsp_ready is late.
                            rsp_data_q<=hit_word;
                            rsp_data_hi_q<=hit_word_hi;
                            rsp_pair_q<=hit_pair;
                            rsp_resp_q<=`AXI_RESP_OKAY;
                            rsp_valid<=1;
                            rsp_data<=hit_word;
                            rsp_data_hi<=hit_word_hi;
                            rsp_pair<=hit_pair;
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
                            if(!beat_q[0]) even_mem[{set_q,way_q,beat_q[2:1]}]<=m_rdata;
                            else           odd_mem [{set_q,way_q,beat_q[2:1]}]<=m_rdata;
                        end
                        if(m_rlast) begin
                            if(beat_q!=3'd7) begin
                                protocol_fault<=1;
                                state<=IC_FAULT;
                            end else begin
                                if(!fill_kill && !line_bad) begin
                                    tag_mem[{way_q,set_q}]<=tag_q;
                                    valid_mem[{way_q,set_q}]<=1'b1;
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

