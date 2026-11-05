// conv_band_rt -- same datapath as conv_band_engine, but every shape parameter
// comes from a register instead of being fixed at elaboration.
//
// Why this exists: one bitstream has to run all 60 convolution layers of the
// model, and their shapes differ (k = 1/3/6, cin = 8..512, 13x13..320x320).
// A build-time parameter set can only ever run one of them.
//
// What changed relative to conv_band_engine (which stays as the verified
// reference):
//   * cin/cout/in_w/in_h/out_w/out_h/k/stride/pad/tr/shift are inputs
//   * the buffers are sized for the worst layer; a layer that fits in less
//     simply uses the front of them
//   * addresses are no longer computed from products of runtime values in the
//     inner loop.  They advance by precomputed deltas, because three chained
//     runtime multiplies do not close at 100 MHz:
//         d_kx   = cin
//         d_ky   = WPADX * cin
//         d_col  = stride * cin
//         d_row  = stride * WPADX * cin
//     The deltas cost a few setup cycles once per layer.
//   * tr is bounded by whichever of BANDCAP or the row count runs out first
//
// Everything else -- the address/accumulate phase relationship, the per-layer
// activation table, the byte-exact requantisation -- is identical, so the
// vectors that verify conv_band_engine must also verify this one.
`timescale 1ns/1ps

module conv_band_rt #(
    parameter integer BANDW = 7168,    // band buffer, 64-bit words (56 KiB)
    parameter integer WBANK = 576,      // words per weight bank (K*K*CSL max)
    parameter integer TRM   = 8
)(
    input  wire        clk,
    input  wire        rstn,
    input  wire        start,
    output reg         busy,
    output reg         done,
    output reg         err,
    output reg  [31:0] cycles,

    input  wire [15:0] p_cin,       // channels actually present (multiple of 8)
    input  wire [15:0] p_cout,
    input  wire [15:0] p_in_w,
    input  wire [15:0] p_in_h,
    input  wire [15:0] p_out_w,
    input  wire [15:0] p_out_h,
    input  wire [7:0]  p_k,
    input  wire [7:0]  p_stride,
    input  wire [7:0]  p_pad,
    input  wire [1:0]  p_act,       // 0 none, 1 leaky, 2 table
    input  wire [7:0]  p_tr,
    input  wire [4:0]  p_shift,

    input  wire [31:0] a_base,
    input  wire [31:0] w_base,
    input  wire [31:0] q_base,
    input  wire [31:0] t_base,
    input  wire [31:0] y_base,

    output reg  [31:0] rd_addr,
    output reg         rd_req,
    input  wire [63:0] rd_data,
    input  wire        rd_valid,
    input  wire        rd_err,

    // debug: st and a latched snapshot of an impossible condition
    output wire [4:0]  dbg_st,
    output wire        dbg_anom,
    output wire [31:0] dbg_snap,

    output reg  [31:0] wr_addr,
    output reg  [63:0] wr_data,
    output reg         wr_req,
    input  wire        wr_ack,
    input  wire        wr_err
);

    localparam [4:0] S_IDLE = 5'd0,  S_PREP = 5'd1, S_Q = 5'd2,  S_QW = 5'd3,
                     S_FILL = 5'd4,  S_FILLW = 5'd5,
                     S_WLD  = 5'd6,  S_WLDW = 5'd7,
                     S_RUN  = 5'd8,  S_EPI = 5'd9, S_EPI2 = 5'd10,
                     S_EPI3 = 5'd11, S_WR = 5'd12, S_WRA = 5'd13,
                     S_CLR  = 5'd14, S_NEXT = 5'd15, S_DONE = 5'd16,
                     S_BST  = 5'd17, S_TQ = 5'd18, S_TQW = 5'd19,
                     S_EPI4 = 5'd20, S_EPI5 = 5'd21, S_EPI6 = 5'd22;

    // ---- shape registers, loaded from the ports at start ----
    reg [15:0] r_cin, r_cout, r_inw, r_inh, r_outw, r_outh;
    reg [7:0]  r_k, r_stride, r_pad, r_tr;
    reg [4:0]  r_shift;
    reg [1:0]  r_act;

    reg [31:0] csl, k2, nsl, nt, wpadx, brow, qw;
    reg [31:0] d_kx, d_ky, d_col, d_row, d_row_bk, m_stridx, wtot, d_kx_km1;
    reg [31:0] tstride;
    // incremental address registers: the fill cursor walks consecutive words, so
    // its buffer index and source address both just increment; the write address
    // advances by nt per column and by out_w*nt per row
    reg [31:0] fptr, fsrc, fsrc_row;
    reg [31:0] d_frow, d_wrow, d_band, d_srow, srow_addr;
    reg [31:0] wrow_band, wrow_base, wcol_off;
    reg [31:0] wtile_off, wboff;
    reg [31:0] rows_done;
    reg [31:0] brow_w, bneed;   // band footprint, checked against BANDW
    // row of the input tensor that the current band starts on; signed because
    // the first band starts at -pad
    reg signed [31:0] src_row;

    // ---- storage ----
    // The band buffer is the largest single block in the design (96 KiB at the
    // planned size).  As one array it becomes ~22 DRMs joined together, and a
    // monolith that size is a routing obstacle: placement reported 22%
    // utilisation yet the router could not finish.  Splitting it into four
    // interleaved banks lets the placer spread them; the mapping is
    //   word index i  ->  bank i[1:0], offset i>>2
    // which is invisible to everything above this line.
    localparam integer BDEP = BANDW/4;
    reg [63:0] bb0 [0:BDEP-1];
    reg [63:0] bb1 [0:BDEP-1];
    reg [63:0] bb2 [0:BDEP-1];
    reg [63:0] bb3 [0:BDEP-1];
    reg [63:0] bband_q;
    reg        bwe;             // single write port into the banks
    reg [31:0] bwa;
    reg [63:0] bwd;
    reg [63:0] wb0 [0:WBANK-1];
    reg [63:0] wb1 [0:WBANK-1];
    reg [63:0] wb2 [0:WBANK-1];
    reg [63:0] wb3 [0:WBANK-1];
    reg [63:0] wb4 [0:WBANK-1];
    reg [63:0] wb5 [0:WBANK-1];
    reg [63:0] wb6 [0:WBANK-1];
    reg [63:0] wb7 [0:WBANK-1];
    reg [63:0] wq0, wq1, wq2, wq3, wq4, wq5, wq6, wq7;

    // bias/M for the tile being computed.  Keeping the whole cout-sized tables
    // on chip cost 2 x 512 x 32 FFs plus two 512:1 read muxes -- together the
    // largest single LUT consumer in the design, and the reason placement
    // reached 59% and routing would not converge.  A tile only ever needs eight
    // of each, so they are fetched per tile instead: eight 64-bit words.
    reg [31:0] b_tile [0:7];
    reg [31:0] m_tile [0:7];
    reg [7:0]  atab   [0:255];

    // ---- addressing registers (advance by deltas) ----
    reg [31:0] pix_base;    // row*stride*wpadx*cin + col*stride*cin
    reg [31:0] tap_base;    // kyi*d_ky + kxi*d_kx
    reg [31:0] wt_base;     // (kyi*k + kxi)*csl

    // ---- counters / state ----
    reg [4:0]  st;
    reg [31:0] profix, pxy, pcs;      // prep helper counters
    reg [31:0] band_i, fr, fx, fcs;
    reg [31:0] wld_o, wld_w;
    reg [31:0] row, col, ti;
    reg [31:0] kyi, kxi, csi;
    reg [31:0] issue, q_i, qt_i;
    reg        mac_clear, mac_valid;

    reg [8*32-1:0] sum_lat;
    reg [8*64-1:0] pr_lat;
    reg [63:0]     y_lat;

    // combinatorial address for the synchronous reads
    wire [31:0] act_off = pix_base + tap_base + (csi << 3);
    wire [31:0] w_off   = wt_base + csi;

    // address combinational, data registered (the template proven to map to
    // GTP_DRM18K_E1 and the only one that keeps the pipelines aligned)
    wire [31:0] rwi = act_off >> 3;
    wire [63:0] bq_mux = (rwi[1:0] == 2'd0) ? bb0[rwi[31:2]]
                       : (rwi[1:0] == 2'd1) ? bb1[rwi[31:2]]
                       : (rwi[1:0] == 2'd2) ? bb2[rwi[31:2]]
                                            : bb3[rwi[31:2]];

    always @(posedge clk) begin
        if (bwe) begin
            case (bwa[1:0])
                2'd0: bb0[bwa[31:2]] <= bwd;
                2'd1: bb1[bwa[31:2]] <= bwd;
                2'd2: bb2[bwa[31:2]] <= bwd;
                default: bb3[bwa[31:2]] <= bwd;
            endcase
        end
    end

    always @(posedge clk) begin
        bband_q <= bq_mux;
        wq0 <= wb0[w_off];
        wq1 <= wb1[w_off];
        wq2 <= wb2[w_off];
        wq3 <= wb3[w_off];
        wq4 <= wb4[w_off];
        wq5 <= wb5[w_off];
        wq6 <= wb6[w_off];
        wq7 <= wb7[w_off];
    end

    // ---- MAC array and epilogue (identical to conv_band_engine) ----
    wire [8*64-1:0] mac_w;
    wire [8*32-1:0] mac_sum;
    wire [8*32-1:0] bias_tile;

    genvar gl;
    generate
        for (gl = 0; gl < 8; gl = gl + 1) begin : g_wb
            assign mac_w[(0*8+gl)*8 +: 8] = wq0[gl*8 +: 8];
            assign mac_w[(1*8+gl)*8 +: 8] = wq1[gl*8 +: 8];
            assign mac_w[(2*8+gl)*8 +: 8] = wq2[gl*8 +: 8];
            assign mac_w[(3*8+gl)*8 +: 8] = wq3[gl*8 +: 8];
            assign mac_w[(4*8+gl)*8 +: 8] = wq4[gl*8 +: 8];
            assign mac_w[(5*8+gl)*8 +: 8] = wq5[gl*8 +: 8];
            assign mac_w[(6*8+gl)*8 +: 8] = wq6[gl*8 +: 8];
            assign mac_w[(7*8+gl)*8 +: 8] = wq7[gl*8 +: 8];
            assign bias_tile[gl*32 +: 32] = b_tile[gl];
        end
    endgenerate

    mac_array #(.L(8), .C(8)) u_mac (
        .clk(clk), .rstn(rstn), .clear(mac_clear), .valid(mac_valid),
        .bias_bus(bias_tile), .a_bus(bband_q), .w_bus(mac_w),
        .sum_bus(mac_sum));

    wire [7:0] epi_y [0:7];
    wire [63:0] y_word;

    generate
        for (gl = 0; gl < 8; gl = gl + 1) begin : g_epi
            wire signed [7:0] c8;
            requant_q15 quantize(.clk(clk),
                .product(pr_lat[gl*64 +: 64]),.value(c8));
            wire signed [7:0]  lk  = (c8 < 0) ? (c8 >>> 3) : c8;
            wire [7:0] idx = c8 + 8'd128;
            wire [7:0] s8  = atab[idx];
            assign epi_y[gl] = (r_act == 2'd0) ? c8 : (r_act == 2'd2) ? s8 : lk;
            assign y_word[gl*8 +: 8] = epi_y[gl];
        end
    endgenerate

    integer ia;
    reg [4:0] bad_st;

    // "busy but idle" is not a legal condition; latch what happened just before
    reg [7:0]  anom_cnt;
    reg [31:0] snap;
    reg        anom_r;
    assign dbg_st   = st;
    assign dbg_anom = anom_r;
    assign dbg_snap = snap;

    // advance one band-relative position of the fill cursor
    task fill_adv;
        begin
            if (fcs == csl - 1) begin
                fcs <= 0;
                if (fx == wpadx - 1) begin
                    fx <= 0;
                    fr <= fr + 1;
                    fsrc     <= fsrc_row + d_frow;
                    fsrc_row <= fsrc_row + d_frow;
                end
                else
                    fx <= fx + 1;
            end
            else
                fcs <= fcs + 1;
        end
    endtask

    // row0 of this band in the input tensor is src_row; it advances by
    // tr*stride per band instead of being recomputed from band_i
    wire signed [31:0] cur_row = src_row + $signed({1'b0, fr[30:0]});
    wire signed [31:0] in_h_s  = $signed({16'd0, r_inh});

    always @(posedge clk) begin
        if (!rstn) begin
            st <= S_IDLE; busy <= 1'b0; done <= 1'b0; err <= 1'b0; cycles <= 0;
            rd_addr <= 0; rd_req <= 0; wr_addr <= 0; wr_data <= 0; wr_req <= 0;
            r_cin <= 0; r_cout <= 0; r_inw <= 0; r_inh <= 0; r_outw <= 0; r_outh <= 0;
            r_k <= 3; r_stride <= 1; r_pad <= 1; r_tr <= 1; r_shift <= 15; r_act <= 0;
            csl <= 0; k2 <= 0; nsl <= 0; nt <= 0; wpadx <= 0; brow <= 0; qw <= 0;
            tstride <= 0;
            d_kx <= 0; d_ky <= 0; d_col <= 0; d_row <= 0; d_row_bk <= 0;
            m_stridx <= 0; wtot <= 0; d_kx_km1 <= 0;
            pix_base <= 0; tap_base <= 0; wt_base <= 0;
            fptr <= 0; fsrc <= 0; fsrc_row <= 0;
            d_band <= 0; d_srow <= 0; srow_addr <= 0;
            wrow_band <= 0; wrow_base <= 0; wcol_off <= 0;
            brow_w <= 0; bneed <= 0;
            wtile_off <= 0; wboff <= 0; rows_done <= 0;
            src_row <= 0;
            band_i <= 0; fr <= 0; fx <= 0; fcs <= 0; wld_o <= 0; wld_w <= 0;
            row <= 0; col <= 0; ti <= 0; kyi <= 0; kxi <= 0; csi <= 0; issue <= 0;
            q_i <= 0; qt_i <= 0; profix <= 0; pxy <= 0; pcs <= 0;
            mac_clear <= 0; mac_valid <= 0; sum_lat <= 0; pr_lat <= 0; y_lat <= 0;
            bwe <= 0; bwa <= 0; bwd <= 0;
            bad_st <= 0; anom_cnt <= 0; anom_r <= 0; snap <= 0;
        end
        else begin
            mac_clear <= 1'b0;
            rd_req    <= 1'b0;
            wr_req    <= 1'b0;
            bwe       <= 1'b0;
            if (busy && st != S_DONE)
                cycles <= cycles + 32'd1;

            // the condition that has now cost two debugging rounds
            if (busy && st == S_IDLE) begin
                if (anom_cnt == 8'd0) anom_r <= 1'b1;
                anom_cnt <= anom_cnt + 8'd1;
                if (anom_cnt == 8'd7) begin
                    snap <= {band_i[3:0], q_i[5:0], fr[5:0], fx[5:0],
                             kyi[3:0], kxi[3:0], csi[3:0], ti[3:0]};
                    anom_r <= 1'b1;
                end
            end
            else
                anom_cnt <= 0;

            case (st)
            S_IDLE: begin
                done <= 1'b0;
                if (start) begin
                    busy <= 1'b1; cycles <= 0; err <= 1'b0;
                    r_cin <= p_cin; r_cout <= p_cout;
                    r_inw <= p_in_w; r_inh <= p_in_h;
                    r_outw <= p_out_w; r_outh <= p_out_h;
                    r_k <= p_k; r_stride <= p_stride; r_pad <= p_pad;
                    r_act <= p_act; r_shift <= p_shift;
                    r_tr <= (p_tr == 0) ? 8'd1 : p_tr;
                    profix <= 0;
                    st <= S_PREP;
                end
            end

            // derive the layer geometry and the address deltas; the multiplies
            // are serialised over a few cycles on purpose
            S_PREP: begin
                case (profix)
                32'd0: begin
                    k2   <= {{16{1'b0}}, r_k} * {{16{1'b0}}, r_k};
                    csl  <= {16'd0, r_cin} >> 3;
                    wpadx <= {16'd0, r_inw} + {15'd0, r_pad, 1'b0};
                    profix <= 1;
                end
                32'd1: begin
                    // k2 and csl have landed
                    nsl  <= k2 * csl;
                    nt   <= ({16'd0, r_cout} + 32'd7) >> 3;
                    m_stridx <= {{24{1'b0}}, r_stride} * wpadx;
                    profix <= 2;
                end
                32'd2: begin
                    qw   <= {16'd0, r_cout} >> 1;
                    brow <= {{24{1'b0}}, r_tr} * {{24{1'b0}}, r_stride}
                            + {{24{1'b0}}, r_k} - {{24{1'b0}}, r_stride};
                    d_kx <= {16'd0, r_cin};
                    d_ky <= wpadx * {16'd0, r_cin};
                    profix <= 3;
                end
                32'd3: begin
                    // d_col is stride*cin; d_row is stride*wpadx*cin
                    d_col    <= {{24{1'b0}}, r_stride} * {16'd0, r_cin};
                    d_row    <= m_stridx * {16'd0, r_cin};
                    wtot     <= k2 * csl;
                    d_kx_km1 <= {{24{1'b0}}, r_cin} * ({{24{1'b0}}, r_k} - 32'd1);
                    d_frow   <= {16'd0, r_inw} * csl;
                    d_wrow   <= {16'd0, r_outw} * nt;
                    tstride  <= {{24{1'b0}}, r_tr} * {{24{1'b0}}, r_stride};
                    brow_w   <= brow * wpadx;
                    profix   <= 4;
                end
                default: begin
                    // second-order deltas, one multiply each, still before any
                    // traffic so the cost is a handful of cycles per layer
                    d_row_bk  <= d_row - d_col * ({16'd0, r_outw} - 32'd1);
                    d_band    <= d_wrow * {{24{1'b0}}, r_tr};
                    d_srow    <= tstride * d_frow;
                    bneed     <= brow_w * csl;
                    srow_addr <= (a_base >> 3) - ({16'd0, r_pad} * d_frow);
                    q_i   <= 0;
                    st    <= S_Q;
                end
                endcase
            end

            // the 256-byte activation table; bias and M are per tile now.
            // The footprint check lives here because this is the first cycle in
            // which bneed is valid and no traffic has started yet: a tr that
            // overflows the band buffer would otherwise fetch outside the band
            // and produce a wrong result with no error at all.
            S_Q: begin
                if (bneed > BANDW || wtot > WBANK || r_tr > TRM ||
                    r_cin == 0 || r_cin[2:0] != 0 ||
                    r_cout == 0 || r_cout[2:0] != 0 ||
                    r_inw == 0 || r_inh == 0 || r_outw == 0 || r_outh == 0 ||
                    (r_k != 1 && r_k != 3 && r_k != 6) ||
                    (r_stride != 1 && r_stride != 2) || r_shift != 15 ||
                    a_base[2:0] != 0 || w_base[2:0] != 0 ||
                    q_base[2:0] != 0 || t_base[2:0] != 0 || y_base[2:0] != 0) begin
                    busy <= 1'b0; done <= 1'b1; err <= 1'b1;
                    st   <= S_DONE;
                end
                else begin
                    rd_addr <= (t_base >> 3) + q_i;
                    rd_req  <= 1'b1;
                    st      <= S_QW;
                end
            end
            S_QW: begin
                if (rd_valid) begin
                    if (rd_err) err <= 1'b1;
                    for (ia = 0; ia < 8; ia = ia + 1)
                        atab[(q_i << 3) + ia] <= rd_data[ia*8 +: 8];
                    if (q_i == 31) begin
                        q_i <= 0; fr <= 0; fx <= 0; fcs <= 0;
                        band_i <= 0; ti <= 0; fptr <= 0;
                        wrow_band <= (y_base >> 3); wrow_base <= 0; wcol_off <= 0;
                        wtile_off <= 0; wboff <= 0; rows_done <= 0;
                        src_row   <= 32'sd0 - $signed({16'd0, r_pad});
                        st <= S_BST;
                    end
                    else begin
                        q_i <= q_i + 1;
                        st  <= S_Q;
                    end
                end
            end

            // bias[8] and M[8] for tile ti: four words each, laid out as
            // int32 bias[cout] then int32 M[cout].  qt_i counts 0..7.
            S_TQ: begin
                rd_addr <= (qt_i < 32'd4)
                         ? ((q_base >> 3) + (ti << 2) + qt_i)
                         : ((q_base >> 3) + qw + (ti << 2) + (qt_i - 32'd4));
                rd_req  <= 1'b1;
                st      <= S_TQW;
            end
            S_TQW: begin
                if (rd_valid) begin
                    if (rd_err) err <= 1'b1;
                    if (qt_i < 32'd4) begin
                        b_tile[qt_i << 1]       <= rd_data[31:0];
                        b_tile[(qt_i << 1) + 1] <= rd_data[63:32];
                    end
                    else begin
                        m_tile[(qt_i - 32'd4) << 1]       <= rd_data[31:0];
                        m_tile[((qt_i - 32'd4) << 1) + 1] <= rd_data[63:32];
                    end
                    if (qt_i == 32'd7) begin
                        qt_i <= 0;
                        st   <= S_WLD;
                    end
                    else begin
                        qt_i <= qt_i + 1;
                        st   <= S_TQ;
                    end
                end
            end

            // band fill
            // first word of a band: src_row may be negative (top padding), so
            // the base is a signed product taken once per band, not per word
            S_BST: begin
                fsrc      <= srow_addr;
                fsrc_row  <= srow_addr;
                fptr      <= 0;
                wrow_base <= wrow_band;
                wcol_off  <= 0;
                st        <= S_FILL;
            end

            S_FILL: begin
                if (fr < brow) begin
                    // cur_row is signed: the first band starts above the tensor
                    // (row -pad) and the last one ends below it.  Both are
                    // padding and must be written as zero, not fetched.
                    if ((cur_row >= 32'sd0) && (cur_row < in_h_s) &&
                        (fx >= r_pad) && ((fx - r_pad) < r_inw)) begin
                        rd_addr <= fsrc;
                        rd_req  <= 1'b1;
                        st      <= S_FILLW;
                    end
                    else begin
                        bwe  <= 1'b1; bwa <= fptr; bwd <= 64'd0;
                        fptr <= fptr + 1;
                        fill_adv;
                    end
                end
                else begin
                    fr <= 0; fx <= 0; fcs <= 0;
                    ti <= 0; wld_o <= 0; wld_w <= 0; qt_i <= 0;
                    st <= S_TQ;
                end
            end
            S_FILLW: begin
                if (rd_valid) begin
                    if (rd_err) err <= 1'b1;
                    bwe  <= 1'b1; bwa <= fptr; bwd <= rd_data;
                    fptr <= fptr + 1;
                    fsrc <= fsrc + 1;      // valid positions are consecutive
                    st <= S_FILL;
                    fill_adv;
                end
            end

            // weight load for one 8-channel tile: WBANK words per bank, but a
            // layer may need fewer (k*k*csl)
            S_WLD: begin
                if (wld_w < wtot) begin
                    rd_addr <= (w_base >> 3) + wtile_off + wboff + wld_w;
                    rd_req  <= 1'b1;
                    st      <= S_WLDW;
                end
                else begin
                    row <= 0; col <= 0;
                    kyi <= 0; kxi <= 0; csi <= 0; issue <= 0;
                    pix_base <= 0; tap_base <= 0; wt_base <= 0;
                    wrow_base <= wrow_band; wcol_off <= 0;
                    mac_clear <= 1'b1;
                    st <= S_RUN;
                end
            end
            S_WLDW: begin
                if (rd_valid) begin
                    if (rd_err) err <= 1'b1;
                    case (wld_o)
                        0: wb0[wld_w] <= rd_data;
                        1: wb1[wld_w] <= rd_data;
                        2: wb2[wld_w] <= rd_data;
                        3: wb3[wld_w] <= rd_data;
                        4: wb4[wld_w] <= rd_data;
                        5: wb5[wld_w] <= rd_data;
                        6: wb6[wld_w] <= rd_data;
                        default: wb7[wld_w] <= rd_data;
                    endcase
                    st <= S_WLD;
                    if (wld_w == wtot - 1) begin
                        wld_w <= 0;
                        if (wld_o == 7) begin
                            wld_o <= 0;
                            row <= 0; col <= 0;
                            kyi <= 0; kxi <= 0; csi <= 0; issue <= 0;
                            pix_base <= 0; tap_base <= 0; wt_base <= 0;
                            wrow_base <= wrow_band; wcol_off <= 0;
                            mac_clear <= 1'b1;
                            st <= S_RUN;
                        end
                        else begin
                            wld_o <= wld_o + 1;
                            wboff <= wboff + wtot;
                        end
                    end
                    else
                        wld_w <= wld_w + 1;
                end
            end

            // compute one pixel: address stage and accumulate stage one cycle apart
            S_RUN: begin
                if (issue < nsl) begin
                    issue <= issue + 1;
                    if (csi == csl - 1) begin
                        csi <= 0;
                        wt_base <= wt_base + csl;
                        if (kxi == r_k - 1) begin
                            kxi <= 0;
                            kyi <= kyi + 1;
                            tap_base <= tap_base + d_ky - d_kx_km1;
                        end
                        else begin
                            kxi <= kxi + 1;
                            tap_base <= tap_base + d_kx;
                        end
                    end
                    else
                        csi <= csi + 1;
                end

                if (issue == nsl) begin
                    mac_valid <= 1'b0;
                    st        <= S_EPI;
                end
                else
                    mac_valid <= 1'b1;
            end

            S_EPI: begin
                mac_valid <= 1'b0;
                sum_lat   <= mac_sum;
                st        <= S_EPI2;
            end

            S_EPI2: begin
                for (ia = 0; ia < 8; ia = ia + 1)
                    pr_lat[ia*64 +: 64] <= $signed(sum_lat[ia*32 +: 32])
                                         * $signed(m_tile[ia]);
                st <= S_EPI3;
            end

            S_EPI3: begin
                // Three Q15 registers: magnitude, rounded magnitude, clip.
                st <= S_EPI4;
            end
            S_EPI4: st <= S_EPI5;
            S_EPI5: st <= S_EPI6;
            S_EPI6: begin
                y_lat <= y_word;
                st    <= S_WR;
            end

            S_WR: begin
                wr_addr <= wrow_base + wcol_off + ti;
                wr_data <= y_lat;
                wr_req  <= 1'b1;
                st      <= S_WRA;
            end

            S_WRA: begin
                if (wr_ack) begin
                    wr_req <= 1'b0;
                    if (wr_err) err <= 1'b1;
                    if (col < r_outw - 1) begin
                        col <= col + 1;
                        pix_base <= pix_base + d_col;
                        wcol_off <= wcol_off + nt;
                        st <= S_CLR;
                    end
                    else if ((row < r_tr - 1) && ((rows_done + row) < r_outh - 1)) begin
                        col <= 0;
                        row <= row + 1;
                        pix_base  <= pix_base + d_row_bk;
                        wcol_off  <= 0;
                        wrow_base <= wrow_base + d_wrow;
                        st <= S_CLR;
                    end
                    else if (ti < nt - 1) begin
                        col <= 0; row <= 0; ti <= ti + 1;
                        wld_o <= 0; wld_w <= 0;
                        pix_base  <= 0;
                        wtile_off <= wtile_off + (wtot << 3);
                        wboff     <= 0;
                        wrow_base <= wrow_band;
                        wcol_off  <= 0;
                        qt_i      <= 0;
                        st <= S_TQ;
                    end
                    else begin
                        col <= 0; row <= 0;
                        band_i <= band_i + 1;
                        // rows written so far; S_NEXT decides on this value, so
                        // it has to be updated here rather than there (updating
                        // it after the test let one extra band run)
                        rows_done <= rows_done + r_tr;
                        st <= S_NEXT;
                    end
                end
            end

            S_CLR: begin
                mac_clear <= 1'b1;
                kyi <= 0; kxi <= 0; csi <= 0; issue <= 0;
                tap_base <= 0; wt_base <= 0;
                st  <= S_RUN;
            end

            S_NEXT: begin
                if (rows_done >= r_outh) begin
                    busy <= 1'b0; done <= 1'b1;
                    st   <= S_DONE;
                end
                else begin
                    fr <= 0; fx <= 0; fcs <= 0;
                    ti <= 0; wld_o <= 0; wld_w <= 0;
                    src_row   <= src_row + tstride;
                    srow_addr <= srow_addr + d_srow;
                    wrow_band <= wrow_band + d_band;
                    wtile_off <= 0; wboff <= 0;
                    st <= S_BST;
                end
            end

            S_DONE: begin
                if (!start) begin
                    done <= 1'b0;
                    st   <= S_IDLE;
                end
            end

            default: begin
                bad_st <= st;
                err    <= 1'b1;
                st     <= S_IDLE;
            end
            endcase
        end
    end

endmodule
