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
// Geometry (plan section 15): 32 sets x 2 ways x 32 B lines = 2048 B.
//   tag       = addr[31:10]   (22 bits)
//   set index = addr[9:5]     (5 bits)
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
    localparam SETS=32, WORDS=8, LINE_BEATS=8;
    localparam IC_IDLE=3'd0, IC_RESP=3'd1, IC_AR=3'd2,
               IC_FILL=3'd3, IC_MISS_RD=3'd4, IC_FAULT=3'd5;

    // Flat arrays: PDS parses these sources as Verilog, so no packed/unpacked
    // multidimensional memories are used here.
    reg [31:0] data_mem [0:SETS*2*WORDS-1];   // {set,way,word}
    reg [21:0] tag_mem  [0:SETS*2-1];         // {way,set}
    reg        valid_mem[0:SETS*2-1];         // {way,set}
    reg        lru_mem  [0:SETS-1];           // 1 = way1 is the LRU victim

    reg [2:0] state;
    reg [31:0] addr_q;
    reg [3:0] id_q;
    reg [4:0] set_q;
    reg [2:0] word_q;
    reg [21:0] tag_q;
    reg way_q;
    reg [8:0] rd_index_q;
    reg [31:0] rsp_data_q;
    reg [1:0] rsp_resp_q;
    reg [2:0] beat_q;
    reg fill_bad_q, fill_kill;
    reg [1:0] fill_resp_q;
    integer i;

    wire [4:0] req_set = req_addr[9:5];
    wire [21:0] req_tag = req_addr[31:10];
    wire hit0 = valid_mem[{1'b0,req_set}] && (tag_mem[{1'b0,req_set}]==req_tag);
    wire hit1 = valid_mem[{1'b1,req_set}] && (tag_mem[{1'b1,req_set}]==req_tag);
    wire miss_way = !valid_mem[{1'b0,req_set}] ? 1'b0 :
                    (!valid_mem[{1'b1,req_set}] ? 1'b1 : lru_mem[req_set]);
    // T3 fast hit path: the word RAM is read combinationally from the incoming
    // request, so a hit can be answered on the accept edge instead of going
    // through a separate read state. The address the miss path uses later is
    // still registered into rd_index_q.
    wire [8:0] hit_index = {req_addr[9:5], hit0 ? 1'b0 : 1'b1, req_addr[4:2]};
    wire [31:0] hit_word = data_mem[hit_index];
    // The line address is {tag,set,5'b0}: the 32 B line the requested word is in.
    wire [31:0] line_addr = {tag_q, set_q, 5'b0};
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
            rd_index_q<=0; rsp_data_q<=0; rsp_resp_q<=0; beat_q<=0;
            fill_bad_q<=0; fill_kill<=0; fill_resp_q<=0;
            rsp_valid<=0; rsp_data<=0; rsp_resp<=0; rsp_id<=0;
            protocol_fault<=0; config_fault<=0; miss_pulse<=0; access_pulse<=0;
            for(i=0;i<SETS*2;i=i+1) begin
                valid_mem[i]<=0;
                tag_mem[i]<=0;
            end
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
                        rsp_resp<=rsp_resp_q;
                        rsp_id<=id_q;
                    end
                    // Request acceptance.  req_ready is high in IC_IDLE, and in
                    // IC_RESP only on the edge the pending response leaves, so
                    // this branch never overwrites a response still on the wire.
                    if(req_valid && req_ready) begin
                        addr_q<=req_addr;
                        id_q<=req_id;
                        set_q<=req_addr[9:5];
                        word_q<=req_addr[4:2];
                        tag_q<=req_addr[31:10];
                        if(hit0 || hit1) begin
                            access_pulse<=1;
                            way_q<=hit0 ? 1'b0 : 1'b1;
                            lru_mem[req_addr[9:5]]<=hit0 ? 1'b1 : 1'b0;
                            // Fast hit: answer on the accept edge (engine sees the
                            // response one cycle after req_valid/req_ready). Both the
                            // holding register and the output register are loaded so
                            // the IC_RESP hold path stays correct if rsp_ready is late.
                            rsp_data_q<=hit_word;
                            rsp_resp_q<=`AXI_RESP_OKAY;
                            rsp_valid<=1;
                            rsp_data<=hit_word;
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
                        if(!fill_kill) data_mem[{set_q,way_q,beat_q}]<=m_rdata;
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
                    rsp_data_q<= data_mem[rd_index_q];
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
