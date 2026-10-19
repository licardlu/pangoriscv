//=============================================================================
// pangoriscv - RV32IM processor core + native AXI4 SoC (Pango PG2L100H @ 27 MHz)
// Module : dcache_axi             File : rtl/core/dcache_axi.v
// Rev    : 1.0                    Date : 2026-10-13
// Author : pango_lpenghan
// Brief  : 2-way set-associative D-cache (32 sets, 32 B line): write-through line fill,
//          store merging and fault handling
//=============================================================================

`include "axi_defs.vh"

// ---------------------------------------------------------------------------
// the caches two-way set-associative data cache in front of the native AXI4 data
// engine (master port 1).  Drop-in replacement for `axi_data_engine`: the
// request/response/beat ports are identical, so `lsu_axi` and the interconnect
// wiring in `pangoriscv_axi_top.v` stay untouched.
//
// Geometry and policy (contest plan section 15 / T09, mirrored by icache_axi.v):
//   * SETS=32 sets, WAYS=2 ways, 8 words = 32 B per line, 2048 B total
//   * tag = addr[31:10], set = addr[9:5], offset = addr[4:0], word = addr[4:2]
//   * one LRU bit per set, invalid ways are filled first
//   * write-through, no write allocate:
//       read miss    -> one 8-beat INCR refill (ARLEN=7); the line is validated
//                       only when every beat arrived without an error response
//       write hit    -> one single-beat AXI write; the cached word is merged
//                       only after a successful B response (write-through)
//       write miss   -> one single-beat AXI write, no refill (no allocation)
//   * MMIO / non-cacheable space (addr >= CACHED_LIMIT) bypasses the arrays
//     completely, and a failed store invalidates the line it targeted
//
// The AXI read channel is driven by this module's own AR/R engine because
// `axi_read_engine` rejects bursts longer than `AXI_ENGINE_MAX_LEN (0)`; the
// single-beat write channel (AW/W/B) is delegated to an inner axi_data_engine,
// so the store framing and its error checks stay in one reviewed place.
// ---------------------------------------------------------------------------
module dcache_axi #(
    parameter integer SETS = 32,
    parameter integer WAYS = 2,
    parameter [31:0]  CACHED_LIMIT = 32'h2000_0000,
    // Data-RAM aperture: 16 KiB at 0x1000_0000 (axi_ram WORDS=4096).
    // Stores inside it can never fail, so they may be answered before B
    // returns.  Outside it -- the 0x1000_4000..0x1FFF_FFFF hole -- a store
    // can be answered DECERR, and that must reach the CPU as a store access
    // fault, so it must NOT take the early path (independent review R01).
    parameter [31:0]  DATA_RAM_LIMIT = 32'h1000_4000
)(
    input wire clk, rst_n,
    // LSU-facing request interface (identical to axi_data_engine)
    input  wire        req_valid,
    output wire        req_ready,
    input  wire        req_write,
    input  wire [31:0] req_addr,
    input  wire [2:0]  req_size,
    input  wire [7:0]  req_len,
    input  wire [3:0]  req_id,
    input  wire        w_valid,
    output wire        w_ready,
    input  wire [31:0] w_data,
    input  wire [3:0]  w_strb,
    input  wire        w_last,
    output wire        rsp_valid,
    input  wire        rsp_ready,
    output wire [31:0] rsp_data,
    output wire [1:0]  rsp_resp,
    output wire        rsp_last,
    output wire [3:0]  rsp_id,
    output wire        b_valid,
    input  wire        b_ready,
    output wire [1:0]  b_resp,
    output wire [3:0]  b_id,
    output wire        protocol_fault,
    output wire        config_fault,
    // one-cycle lookup-miss indicator for perf_regs
    output wire        miss_event,

    // AXI4 master port
    output wire        m_arvalid,
    input  wire        m_arready,
    output wire [31:0] m_araddr,
    output wire [3:0]  m_arid,
    output wire [7:0]  m_arlen,
    output wire [2:0]  m_arsize,
    output wire [1:0]  m_arburst,
    output wire        m_arlock,
    output wire [3:0]  m_arcache,
    output wire [2:0]  m_arprot,
    output wire [3:0]  m_arqos,
    input  wire        m_rvalid,
    output wire        m_rready,
    input  wire [31:0] m_rdata,
    input  wire [3:0]  m_rid,
    input  wire [1:0]  m_rresp,
    input  wire        m_rlast,
    output wire        m_awvalid,
    input  wire        m_awready,
    output wire [31:0] m_awaddr,
    output wire [3:0]  m_awid,
    output wire [7:0]  m_awlen,
    output wire [2:0]  m_awsize,
    output wire [1:0]  m_awburst,
    output wire        m_awlock,
    output wire [3:0]  m_awcache,
    output wire [2:0]  m_awprot,
    output wire [3:0]  m_awqos,
    output wire        m_wvalid,
    input  wire        m_wready,
    output wire [31:0] m_wdata,
    output wire [3:0]  m_wstrb,
    output wire        m_wlast,
    input  wire        m_bvalid,
    output wire        m_bready,
    input  wire [3:0]  m_bid,
    input  wire [1:0]  m_bresp
);
    localparam integer LINE_WORDS = 8;                 // 32 B / 4 B
    localparam [7:0]   REFILL_LEN = LINE_WORDS - 1;    // ARLEN=7 -> 8 beats
    // Address slicing derived from SETS so the cache is resized by parameter
    // alone (optimization plan P2.2). At SETS=32 this reproduces the previous
    // hard-coded split exactly: tag=addr[31:10], set=addr[9:5], word=addr[4:2].
    localparam integer IDXW = $clog2(SETS);            // 5 for 32 sets
    localparam integer TAGW = 32 - 5 - IDXW;           // 22 for 32 sets

    localparam ST_IDLE      = 4'd0,
               ST_HIT       = 4'd1,
               ST_RD_AR     = 4'd2,
               ST_RD_DATA   = 4'd3,
               ST_WR_REQ    = 4'd4,
               ST_WR_RESP   = 4'd5,
               ST_WR_HOLD   = 4'd6,
               ST_BYP_RESP  = 4'd7,
               ST_FAULT     = 4'd8,
               // Background drain of a write's B response (optimization P2').
               ST_WR_DRAIN  = 4'd9;

    reg [3:0]  state_q;
    reg [TAGW-1:0] tag_q;
    reg [IDXW-1:0] set_q;
    // Physical duplicate of set_q, used only as the write address of the line
    // RAMs (tag/data/valid/lru).  Both registers load the same value on the
    // same clock edge, so behaviour is identical; the split exists so that the
    // placer can put this copy next to the distributed-RAM write ports and
    // close the hold path PDS reported in an early build on
    // soc/core/data_cache/set_q[4] -> tag_mem_*/ram64x1d/WADDR[4] (-0.027 ns).
    reg [IDXW-1:0] set_wr_q;
    reg [2:0]  word_q;
    reg [3:0]  id_q;
    reg        cached_q;
    // Optimization P2': a store to the on-chip data RAM window can never fail, so
    // its B response does not have to gate the CPU. Early release applies only
    // there; every other address keeps the synchronous wait so that a store fault
    // stays precise (ISA e2e case 11).
    reg        early_q;           // this write may be released before B
    reg        drain_q;           // a released write still owes an AXI B
    reg        b_seen_q;          // B was already handed over by the write engine
    reg        wreq_q;            // our AW still owes to the engine
    reg        wsent_q;           // our AW was accepted: the next W beat is ours
    reg        hit_q;
    reg        hit_way_q;
    reg        fill_way_q;
    reg [2:0]  beat_q;            // refill beat counter
    reg        rd_refill_q;       // current read is a line refill
    reg        rd_err_q;          // an R beat carried an error response
    reg [31:0] ar_addr_q;
    reg [7:0]  ar_len_q;
    reg [3:0]  ar_id_q;
    reg        read_protocol_fault_q;
    reg [31:0] wdata_q;
    reg [3:0]  wstrb_q;
    reg [1:0]  resp_q;
    reg [31:0] rdata_q;
    reg [1:0]  rresp_q;

    // ---- storage -----------------------------------------------------------
    reg [TAGW-1:0] tag_mem   [0:SETS*WAYS-1];
    reg [31:0] data_mem  [0:SETS*WAYS*LINE_WORDS-1];
    reg        valid_mem [0:SETS*WAYS-1];
    reg        lru_mem   [0:SETS-1];

    function integer widx;   // (way, set) -> line slot
        input integer w;
        input integer s;
        begin
            widx = w*SETS + s;
        end
    endfunction
    function integer didx;   // (way, set, word) -> data word slot
        input integer w;
        input integer s;
        input integer k;
        begin
            didx = (w*SETS + s)*LINE_WORDS + k;
        end
    endfunction

    // ---- combinational lookup for the incoming request ---------------------
    wire [TAGW-1:0] req_tag  = req_addr[31:5+IDXW];
    wire [IDXW-1:0] req_set  = req_addr[5+IDXW-1:5];
    wire [2:0]      req_word = req_addr[4:2];
    wire req_in_cache = (req_addr < CACHED_LIMIT);
    wire hit0 = valid_mem[widx(0,req_set)] && (tag_mem[widx(0,req_set)]==req_tag);
    wire hit1 = valid_mem[widx(1,req_set)] && (tag_mem[widx(1,req_set)]==req_tag);
    wire hit_any = hit0 | hit1;
    wire hit_way = hit1;                       // way 0 wins if both match

    wire        eng_w_valid = rst_n && wsent_q;

    // ---- inner write engine (AW/W/B framing, error checks) -----------------
    wire        i_req_ready, i_w_ready, i_b_valid;
    wire [1:0]  i_b_resp;
    wire [3:0]  i_b_id;
    wire        i_protocol_fault, i_config_fault;
    reg         i_req_valid_r;
    reg         i_req_write_r;
    reg  [31:0] i_req_addr_r;
    reg  [2:0]  i_req_size_r;
    reg  [7:0]  i_req_len_r;
    reg  [3:0]  i_req_id_r;
    // The engine-facing B ready: while the CPU response is held it is gated by the
    // CPU taking it; in the background drain state the CPU has already been served,
    // so B must be accepted unconditionally or the handshake would hang.
    wire        i_b_ready   = (state_q==ST_WR_DRAIN) ||
                              ((state_q==ST_WR_HOLD) && b_ready);

    // P11: present the write request to the inner engine on the ACCEPT edge, so it
    // can latch the address immediately and accept the W beat one cycle sooner.
    // The registered i_req_*_r remain as the fallback/keep-alive (the engine only
    // looks at req_valid in WR_IDLE, so the extra pulse is harmless).
    wire i_write_accept = rst_n && (state_q==ST_IDLE) && req_valid && req_ready && req_write;
    wire        i_req_valid = i_req_valid_r || i_write_accept || wreq_q;
    wire [31:0] i_req_addr  = i_write_accept ? req_addr    : i_req_addr_r;
    wire [2:0]  i_req_size  = i_write_accept ? req_size     : i_req_size_r;
    wire [7:0]  i_req_len   = i_write_accept ? 8'd0         : i_req_len_r;
    wire [3:0]  i_req_id    = i_write_accept ? req_id       : i_req_id_r;
    wire        i_req_write = i_write_accept ? 1'b1         : i_req_write_r;

    axi_data_engine inner (
        .clk(clk), .rst_n(rst_n),
        .req_valid(i_req_valid), .req_ready(i_req_ready), .req_write(i_req_write),
        .req_addr(i_req_addr), .req_size(i_req_size), .req_len(i_req_len),
        .req_id(i_req_id),
        .w_valid(eng_w_valid), .w_ready(i_w_ready), .w_data(wdata_q), .w_strb(wstrb_q),
        .w_last(w_last),
        .rsp_valid(), .rsp_ready(1'b0), .rsp_data(), .rsp_resp(), .rsp_last(),
        .rsp_id(),
        .b_valid(i_b_valid), .b_ready(i_b_ready), .b_resp(i_b_resp), .b_id(i_b_id),
        .protocol_fault(i_protocol_fault), .config_fault(i_config_fault),
        // read channel is unused here: this module drives AR/R itself
        .m_arvalid(), .m_arready(1'b0), .m_araddr(), .m_arid(), .m_arlen(),
        .m_arsize(), .m_arburst(), .m_arlock(), .m_arcache(), .m_arprot(),
        .m_arqos(), .m_rvalid(1'b0), .m_rready(), .m_rdata(32'd0), .m_rid(4'd0),
        .m_rresp(2'b00), .m_rlast(1'b0),
        .m_awvalid(m_awvalid), .m_awready(m_awready), .m_awaddr(m_awaddr),
        .m_awid(m_awid), .m_awlen(m_awlen), .m_awsize(m_awsize),
        .m_awburst(m_awburst), .m_awlock(m_awlock), .m_awcache(m_awcache),
        .m_awprot(m_awprot), .m_awqos(m_awqos),
        .m_wvalid(m_wvalid), .m_wready(m_wready), .m_wdata(m_wdata),
        .m_wstrb(m_wstrb), .m_wlast(m_wlast),
        .m_bvalid(m_bvalid), .m_bready(m_bready), .m_bid(m_bid), .m_bresp(m_bresp)
    );

    // ---- own AR/R read engine ---------------------------------------------
    assign m_arvalid = rst_n && (state_q==ST_RD_AR);
    assign m_araddr  = ar_addr_q;
    assign m_arid    = ar_id_q;
    assign m_arlen   = ar_len_q;
    // Cached line refills are always full-word beats.  A non-cached (MMIO) read
// must carry the actual access size: presenting a byte/halfword read as a
// 32-bit word makes the slave answer SLVERR (independent review R02).
assign m_arsize  = cached_q ? 3'd2 : i_req_size_r;
    assign m_arburst = `AXI_BURST_INCR;
    assign m_arlock  = 1'b0;
    assign m_arcache = 4'b0000;
    assign m_arprot  = 3'b000;
    assign m_arqos   = 4'b0000;
    assign m_rready  = rst_n && (state_q==ST_RD_DATA);

    assign protocol_fault = read_protocol_fault_q || i_protocol_fault;
    assign config_fault   = i_config_fault;
    // P13: a read HIT needs nothing but the tag/data RAM, so it can also be served
    // while the write machine occupies the cache (ST_WR_HOLD / ST_WR_DRAIN).  The
    // cache is then unavailable to the CPU only for genuine read misses, which is
    // what the LSU's "engine busy" fallback was really paying for.
    wire read_hit_now = req_valid && !req_write && req_in_cache && hit_any;
    assign req_ready = rst_n && !protocol_fault && !config_fault &&
                       ((state_q==ST_IDLE) ||
                        ((state_q==ST_WR_HOLD || state_q==ST_WR_DRAIN) && read_hit_now));
    assign w_ready   = i_w_ready;              // inner engine latches in WR_PREP

    // P10: answer a cache READ hit on the ACCEPT edge.  The tag comparison already
    // runs combinationally on req_addr, so the line's data word can be read from
    // that same address in the same cycle.  The engine then sees rsp_valid on the
    // very edge its request was taken, and a load retires without paying the accept
    // cycle.  When the consumer is not ready, the original registered ST_HIT path
    // still holds the response (the state simply parks there instead).
    // Writes are excluded: a store gets its completion from the B response, and
    // answering one here would retire it while ST_WR_REQ still owns the engine.
    wire accept_hit = rst_n && req_valid && req_ready && !req_write &&
                      req_in_cache && hit_any;
    wire [31:0] accept_word = data_mem[didx(hit_way,req_set,req_addr[4:2])];

    assign rsp_valid = rst_n && ((state_q==ST_HIT) || (state_q==ST_BYP_RESP) || accept_hit);
    assign rsp_data  = (state_q==ST_BYP_RESP) ? rdata_q
                     : accept_hit            ? accept_word
                     : data_mem[didx(hit_q ? hit_way_q : fill_way_q,set_q,word_q)];
    assign rsp_resp  = (state_q==ST_BYP_RESP) ? rresp_q
                     : accept_hit            ? 2'b00 : resp_q;
    assign rsp_last  = 1'b1;
    assign rsp_id    = accept_hit ? req_id : id_q;

    // P14: report the early-release OKAY on the very edge the W beat is taken, so
    // the CPU's store completes one cycle sooner.  P13 already lets read hits
    // through during the write states, so the cache no longer loses that cycle.
    // The write-through merge then has to use the RAW w_data/w_strb, because
    // wdata_q/wstrb_q are only latched on that edge.
    wire early_now = rst_n && (state_q==ST_WR_REQ) && early_q && w_valid && w_ready;
    wire [31:0] strb_mask_now = {{8{w_strb[3]}},{8{w_strb[2]}},
                                 {8{w_strb[1]}},{8{w_strb[0]}}};
    wire [31:0] merged_now = (data_mem[didx(hit_way_q,set_wr_q,word_q)] & ~strb_mask_now) |
                             (w_data & strb_mask_now);

    wire [31:0] strb_mask_acc = {{8{w_strb[3]}},{8{w_strb[2]}},
                                 {8{w_strb[1]}},{8{w_strb[0]}}};
    wire [31:0] merged_accept = (data_mem[didx(hit_way,req_set,req_word)] & ~strb_mask_acc) |
                                (w_data & strb_mask_acc);
    wire early_req = (req_addr >= 32'h1000_0000) && (req_addr < DATA_RAM_LIMIT);
    wire accept_early = rst_n && (state_q==ST_IDLE) && req_valid && req_ready &&
                        req_write && early_req;

    assign b_valid = rst_n && ((state_q==ST_WR_HOLD) || early_now || accept_early);
    assign b_resp  = (early_now || accept_early) ? `AXI_RESP_OKAY : resp_q;
    assign b_id    = id_q;
    assign miss_event = rst_n && (state_q==ST_IDLE) && req_valid && req_ready &&
                        !req_write && req_in_cache && !hit_any;

    // byte-lane merge for a write hit (write-through: applies after a good B)
    wire [31:0] strb_mask = {{8{wstrb_q[3]}},{8{wstrb_q[2]}},
                             {8{wstrb_q[1]}},{8{wstrb_q[0]}}};
    wire [31:0] merged_word = (data_mem[didx(hit_way_q,set_q,word_q)] & ~strb_mask) |
                              (wdata_q & strb_mask);

    integer s, w;
    always @(posedge clk) begin
        if (!rst_n) begin
            state_q     <= ST_IDLE;
            tag_q       <= {TAGW{1'b0}};
            set_q       <= {IDXW{1'b0}};
            set_wr_q    <= {IDXW{1'b0}};
            word_q      <= 3'd0;
            id_q        <= 4'd0;
            cached_q    <= 1'b0;
            early_q     <= 1'b0;
            drain_q     <= 1'b0;
            b_seen_q    <= 1'b0;
            wreq_q      <= 1'b0;
            wsent_q     <= 1'b0;
            hit_q       <= 1'b0;
            hit_way_q   <= 1'b0;
            fill_way_q  <= 1'b0;
            beat_q      <= 3'd0;
            rd_refill_q <= 1'b0;
            rd_err_q    <= 1'b0;
            ar_addr_q   <= 32'd0;
            ar_len_q    <= 8'd0;
            ar_id_q     <= 4'd0;
            read_protocol_fault_q <= 1'b0;
            wdata_q     <= 32'd0;
            wstrb_q     <= 4'd0;
            resp_q      <= 2'd0;
            rdata_q     <= 32'd0;
            rresp_q     <= 2'd0;
            i_req_valid_r <= 1'b0;
            i_req_write_r <= 1'b0;
            i_req_addr_r  <= 32'd0;
            i_req_size_r  <= 3'd0;
            i_req_len_r   <= 8'd0;
            i_req_id_r    <= 4'd0;
            for (s=0;s<SETS;s=s+1) begin
                lru_mem[s] <= 1'b0;
                for (w=0;w<WAYS;w=w+1) valid_mem[widx(w,s)] <= 1'b0;
            end
        end else begin
            i_req_valid_r <= 1'b0;              // requests are single-cycle
            case (state_q)
                // ------------------------------------------------------ IDLE
                ST_IDLE: if (req_valid && req_ready) begin
                    tag_q     <= req_tag;
                    set_q     <= req_set;
                    set_wr_q  <= req_set;
                    word_q    <= req_word;
                    id_q      <= req_id;
                    cached_q  <= req_in_cache;
                    // latch the access size for the AR/AW framing: the read path
                    // needs it for MMIO byte/halfword reads (review R02)
                    i_req_size_r <= req_size;
                    early_q   <= (req_addr >= 32'h1000_0000) && (req_addr < DATA_RAM_LIMIT);
                    hit_q     <= hit_any;
                    hit_way_q <= hit_way;
                    if (req_write) begin
                        // write-through, no write allocate on a miss
                        i_req_valid_r <= 1'b1;
                        i_req_write_r <= 1'b1;
                        i_req_addr_r  <= req_addr;
                        i_req_size_r  <= req_size;
                        i_req_len_r   <= 8'd0;
                        i_req_id_r    <= req_id;
                        wdata_q <= w_data;
                        wstrb_q <= w_strb;
                        wreq_q  <= 1'b1;
                        if (req_in_cache && hit_any)
                            data_mem[didx(hit_way,req_set,req_word)] <= merged_accept;
                        if (early_req) begin
                            resp_q   <= `AXI_RESP_OKAY;
                            drain_q  <= 1'b1;
                            b_seen_q <= 1'b0;
                            state_q  <= (i_b_valid) ? ST_IDLE : ST_WR_DRAIN;
                        end else begin
                            state_q  <= ST_WR_RESP;
                        end
                    end else if (req_in_cache && hit_any) begin
                        resp_q  <= 2'b00;
                        // P10: if the engine takes the response on this very edge,
                        // do NOT park in ST_HIT -- that would present the same
                        // response a second time.  Going straight back to ST_IDLE
                        // keeps exactly one response per lookup.
                        //
                        // P16 fix (independent-review R03): the fast path leaves
                        // through ST_IDLE and therefore never executes the LRU
                        // update that lives in ST_HIT, so nearly every hit used to
                        // leave the replacement policy untouched.  Update it here
                        // as well; ST_HIT keeps its identical update for the
                        // back-pressured path (writing the same value twice is
                        // harmless).
                        lru_mem[req_set] <= hit_way ? 1'b0 : 1'b1;
                        state_q <= rsp_ready ? ST_IDLE : ST_HIT;
                    end else begin
                        // line refill (cacheable) or a single bypass beat (MMIO)
                        rd_refill_q <= req_in_cache;
                        beat_q      <= 3'd0;
                        rd_err_q    <= 1'b0;
                        ar_id_q     <= req_id;
                        if (req_in_cache) begin
                            fill_way_q <= lru_mem[req_set];
                            ar_addr_q  <= {req_addr[31:5],5'b0};
                            ar_len_q   <= REFILL_LEN;
                            // a line under refill is never valid
                            valid_mem[widx(lru_mem[req_set],req_set)] <= 1'b0;
                        end else begin
                            ar_addr_q  <= req_addr;
                            ar_len_q   <= 8'd0;
                        end
                        state_q <= ST_RD_AR;
                    end
                end

                // ------------------------------------------------------- HIT
                ST_HIT: begin
                    resp_q <= 2'b00;
                    // the way that answered is now the most recently used one
                    lru_mem[set_wr_q] <= hit_q ? ~hit_way_q : ~fill_way_q;
                    if (rsp_valid && rsp_ready) state_q <= ST_IDLE;
                end

                // -------------------------------------------------- read burst
                ST_RD_AR: if (m_arready) state_q <= ST_RD_DATA;
                ST_RD_DATA: if (m_rvalid) begin
                    if (m_rid != ar_id_q) read_protocol_fault_q <= 1'b1;
                    if (m_rresp != 2'b00) rd_err_q <= 1'b1;
                    if (rd_refill_q) begin
                        data_mem[didx(fill_way_q,set_wr_q,beat_q)] <= m_rdata;
                        if (m_rlast || beat_q==LINE_WORDS-1) begin
                            if (!rd_err_q && m_rresp==2'b00) begin
                                valid_mem[widx(fill_way_q,set_wr_q)] <= 1'b1;
                                tag_mem[widx(fill_way_q,set_wr_q)]   <= tag_q;
                                lru_mem[set_wr_q] <= ~fill_way_q;
                                resp_q <= 2'b00;
                            end else begin
                                valid_mem[widx(fill_way_q,set_wr_q)] <= 1'b0;
                                resp_q <= 2'b10;     // propagate the refill error
                            end
                            state_q <= ST_HIT;       // serve the requested word
                        end else begin
                            beat_q <= beat_q + 3'd1;
                        end
                    end else begin
                        rdata_q <= m_rdata;
                        rresp_q <= m_rresp;
                        state_q <= ST_BYP_RESP;
                    end
                end

                // --------------------------------------------------- write path
                ST_WR_REQ: if (w_valid && w_ready) begin
                    wdata_q <= w_data;
                    wstrb_q <= w_strb;
                    if (early_q) begin
                        // Data-RAM store: answer now, drain B in the background.
                        resp_q   <= `AXI_RESP_OKAY;
                        drain_q  <= 1'b1;
                        b_seen_q <= 1'b0;   // B belongs to the write starting now
                        if (b_ready) begin
                            // P14: the CPU takes the OKAY on this very edge, so
                            // there is nothing left to hold -- apply the merge from
                            // the RAW beat and let the drain finish in background.
                            if (cached_q && hit_q)
                                data_mem[didx(hit_way_q,set_wr_q,word_q)] <= merged_now;
                            state_q <= (i_b_valid) ? ST_IDLE : ST_WR_DRAIN;
                        end else begin
                            // CPU not ready: park and keep the registered OKAY
                            // (merge applied when leaving ST_WR_HOLD).
                            state_q <= ST_WR_HOLD;
                        end
                    end else begin
                        state_q <= ST_WR_RESP;
                    end
                end
                ST_WR_RESP: if (i_b_valid) begin
                    resp_q <= i_b_resp;
                    if (i_b_resp==2'b00) begin
                        // write-through: the cached copy is merged after a good B
                        if (cached_q && hit_q)
                            data_mem[didx(hit_way_q,set_wr_q,word_q)] <= merged_word;
                    end else begin
                        // a failed store must not leave a usable line behind
                        if (cached_q && hit_q) valid_mem[widx(hit_way_q,set_wr_q)] <= 1'b0;
                    end
                    state_q <= ST_WR_HOLD;
                end
                ST_WR_HOLD: if (b_valid && b_ready) begin
                    if (drain_q) begin
                        // released write: apply the write-through merge, then let
                        // the B handshake finish in the background
                        if (cached_q && hit_q)
                            data_mem[didx(hit_way_q,set_wr_q,word_q)] <= merged_word;
                        // B may already have been handed over while the response was
                        // being held; only enter the drain state if it has not.
                        state_q <= (b_seen_q || i_b_valid) ? ST_IDLE : ST_WR_DRAIN;
                    end else begin
                        state_q <= ST_IDLE;
                    end
                end
                // Background drain: no new request is served here, but the CPU has
                // already been released, so this overlaps with non-memory work.
                ST_WR_DRAIN: if (i_b_valid) begin
                    if ((i_b_resp!==2'b00) && cached_q && hit_q)
                        valid_mem[widx(hit_way_q,set_wr_q)] <= 1'b0;
                    drain_q <= 1'b0;
                    state_q <= ST_IDLE;
                end

                // ------------------------------------------ non-cacheable read
                ST_BYP_RESP: if (rsp_valid && rsp_ready) state_q <= ST_IDLE;

                ST_FAULT: ;
                default: state_q <= ST_FAULT;
            endcase
            // Latch "the write engine already handed B over". Without this the
            // background drain could wait for a response that was consumed while
            // the CPU response was being held (observed as an early deadlock).
            if (i_b_valid) b_seen_q <= 1'b1;
            if (i_req_valid && i_req_ready) begin
                wreq_q  <= 1'b0;
                wsent_q <= 1'b1;
            end else if (wsent_q && i_w_ready) begin
                wsent_q <= 1'b0;
            end
        end
    end
endmodule
