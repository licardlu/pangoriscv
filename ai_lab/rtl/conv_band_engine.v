// conv_band_engine -- DDR-backed tiled convolution layer.
//
// Replaces conv3x3_layer's whole-tensor-on-chip model, which synthesised to
// 90,151 LUT (135 %) because every tensor lived in an array with a
// combinational read.  Storage here is band-buffered and every array is
// synchronous-read, which rtl/dram_probe.v proved maps to GTP_DRM18K_E1 instead
// of distributed RAM.
//
// Schedule (same shape as scripts/tile_plan.py):
//
//   for band of TR output rows
//       fill band buffer with (TR*STRIDE + K - STRIDE) input rows, zero padded,
//       channels padded to a multiple of 8
//       for each 8-channel output tile
//           load that tile's weights: 8 banks x K*K*CSL words of 8 channels
//           for each output pixel in the band
//               for ky, kx, channel-slice: acc += dot8
//               requantise, activation, write 8 bytes back
//
// Array mapping: L = 8 lanes = the 8 channels of ONE pixel (channel-last layout,
// so one 64-bit read feeds all lanes), C = 8 output channels -> 64 MAC/cycle.
// Weights are held in eight 64-bit banks addressed together, so a K-slice costs
// one read of 64 bytes instead of 64 separate reads.
//
// Read pipelining: a synchronous read returns data the cycle after the address
// is presented, so the address stage and the accumulate stage are one cycle
// apart.  `issue` counts addresses presented; `mac_valid` is derived from it so
// the array consumes exactly NSLICE slices per pixel, never twice.
//
// Channel padding: layer 0 has CIN = 3.  The host packs every tensor with
// CINPAD = ceil(CIN/8)*8 zero-padded channels.  The cost is real and recorded,
// not hidden: layer 0 does 8/3 = 2.67x the multiply-accumulates it needs.
`timescale 1ns/1ps

module conv_band_engine #(
    parameter integer CINPAD = 8,
    parameter integer COUT   = 8,
    parameter integer IN_W   = 8,
    parameter integer IN_H   = 8,
    parameter integer K      = 3,
    parameter integer STRIDE = 1,
    parameter integer ACT    = 1,
    parameter integer TR     = 4,
    parameter integer PADP   = -1,      // <0 means K/2; YOLOv5 autopad differs for stride 2
    parameter integer SHIFT  = 15
)(
    input  wire        clk,
    input  wire        rstn,

    input  wire        start,
    output reg         busy,
    output reg         done,
    output reg         err,
    output reg  [31:0] cycles,

    input  wire [31:0] a_base,
    input  wire [31:0] w_base,
    input  wire [31:0] q_base,
    input  wire [31:0] t_base,      // 256-byte activation table, ACT==2 only
    input  wire [31:0] y_base,

    output reg  [31:0] rd_addr,
    output reg         rd_req,
    input  wire [63:0] rd_data,
    input  wire        rd_valid,
    input  wire        rd_err,

    output reg  [31:0] wr_addr,      // 64-bit word address
    output reg  [63:0] wr_data,      // one pixel's 8 output bytes for this tile
    output reg         wr_req,
    input  wire        wr_ack,
    input  wire        wr_err
);

    localparam integer PAD   = (PADP < 0) ? (K / 2) : PADP;
    localparam integer WPADX = IN_W + 2 * PAD;
    localparam integer OW    = (IN_W + 2 * PAD - K) / STRIDE + 1;
    localparam integer OH    = (IN_H + 2 * PAD - K) / STRIDE + 1;
    localparam integer BROW  = TR * STRIDE + K - STRIDE;
    localparam integer CSL   = CINPAD / 8;
    localparam integer K2    = K * K;
    localparam integer NSL   = K2 * CSL;
    localparam integer NT    = (COUT + 7) / 8;
    localparam integer BBUF  = BROW * WPADX * CINPAD;
    localparam integer WBUF  = K2 * CSL;
    localparam integer QW    = COUT / 2;

    localparam [4:0] S_IDLE = 4'd0,  S_Q = 4'd1,   S_QW   = 4'd2,
                     S_FILL = 4'd3,  S_FILLW = 4'd4,
                     S_WLD  = 4'd5,  S_WLDW = 4'd6,
                     S_RUN  = 4'd7,  S_EPI = 4'd8,  S_WR = 4'd9,
                     S_NEXT = 4'd10, S_DONE = 4'd11, S_CLR = 4'd12, S_WRA = 4'd13, S_EPI2 = 4'd14, S_EPI3 = 4'd15,
                     S_TAB = 4'd16, S_TABW = 4'd17;

    // ------------------------------------------------------------- storage
    reg [63:0] bband [0:(BBUF/8)-1];
    reg [63:0] bband_q;

    reg [63:0] wb0 [0:WBUF-1];
    reg [63:0] wb1 [0:WBUF-1];
    reg [63:0] wb2 [0:WBUF-1];
    reg [63:0] wb3 [0:WBUF-1];
    reg [63:0] wb4 [0:WBUF-1];
    reg [63:0] wb5 [0:WBUF-1];
    reg [63:0] wb6 [0:WBUF-1];
    reg [63:0] wb7 [0:WBUF-1];
    reg [63:0] wq0, wq1, wq2, wq3, wq4, wq5, wq6, wq7;

    reg [31:0] bias_r [0:COUT-1];
    reg [31:0] mval   [0:COUT-1];
    // Per-tile copies.  Reading mval[ti*8+gl] combinationally put a 32:1 mux in
    // front of the requant multiplier and that mux was the critical path.
    reg [31:0] b_tile [0:7];
    reg [31:0] m_tile [0:7];
    // Activation table loaded from DDR.  A build-time table bakes in one output
    // scale, but every layer has its own s_y, so the table has to travel with
    // the layer blob.  256 bytes, indexed by q+128.
    reg [7:0]  atab [0:255];

    // ------------------------------------------------------------- counters
    reg [4:0]  st;
    reg [31:0] band_i, ti;
    reg [31:0] fr, fx, fcs;
    reg [31:0] wld_o, wld_w;
    reg [31:0] row, col;
    reg [31:0] kyi, kxi, csi;
    reg [31:0] issue;
    reg [31:0] q_i;
    reg [31:0] t_i;
    reg        mac_clear, mac_valid;

    wire [31:0] band_src0 = band_i * TR * STRIDE - PAD;
    wire [31:0] band_out0 = band_i * TR;

    // fill cursors fr/fx/fcs walk row -> padded column -> channel slice

    wire [8*64-1:0] mac_w;
    wire [8*32-1:0] mac_sum;

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
        end
    endgenerate

    // bias for the current tile, packed 8 x 32 bit
    wire [8*32-1:0] bias_tile;
    generate
        for (gl = 0; gl < 8; gl = gl + 1) begin : g_bt
            assign bias_tile[gl*32 +: 32] = b_tile[gl];
        end
    endgenerate

    mac_array #(.L(8), .C(8)) u_mac (
        .clk(clk), .rstn(rstn),
        .clear(mac_clear), .valid(mac_valid),
        .bias_bus(bias_tile), .a_bus(bband_q), .w_bus(mac_w),
        .sum_bus(mac_sum));

    // ------------------------------------------------------------- epilogue
    // The accumulator -> adder tree -> 32x32 multiply -> round -> clip chain is
    // far too long for one 10 ns cycle (the first implementation closed at
    // 58 MHz).  It is split in two: the tree lands in sum_lat, and the requant
    // runs from that register on the following cycle.
    reg [8*32-1:0] sum_lat;
    reg [8*64-1:0] pr_lat;

    wire [7:0]  epi_y [0:7];
    wire [63:0] y_word;

    generate
        for (gl = 0; gl < 8; gl = gl + 1) begin : g_epi
            wire signed [63:0] pr  = $signed(pr_lat[gl*64 +: 64]);
            // round-half-away-from-zero, not round-half-up: adding half of the
            // divisor and then arithmetic-shifting floors toward -inf, which
            // rounds -0.75 to -1.0 (=-2 after the shift) instead of to -1.
            // Magnitude first, sign restored after, is the exact rule.
            wire        [63:0] mag = pr[63] ? (~pr + 64'd1) : pr;
            wire        [63:0] rnd = mag + (64'd1 <<< (SHIFT-1));
            wire        [63:0] qsh = rnd >> SHIFT;
            wire signed [63:0] sh  = pr[63] ? -$signed(qsh) : $signed(qsh);
            wire signed [63:0] cl = (sh > 64'sd127)  ? 64'sd127
                                  : (sh < -64'sd128) ? -64'sd128 : sh;
            wire signed [7:0]  c8 = cl[7:0];
            wire signed [7:0]  lk = (c8 < 0) ? (c8 >>> 3) : c8;
            wire [7:0] idx = c8 + 8'd128;
            wire [7:0] s8  = atab[idx];
            assign epi_y[gl] = (ACT == 0) ? c8 : (ACT == 2) ? s8 : lk;
            assign y_word[gl*8 +: 8] = epi_y[gl];
        end
    endgenerate

    reg [63:0] y_lat;

    integer ia;
    reg [4:0] bad_st;   // illegal state captured for diagnosis

    // ------------------------------------------------------------- datapath
    wire [31:0] act_off = ((row * STRIDE + kyi) * WPADX + (col * STRIDE + kxi)) * CINPAD + (csi * 8);
    wire [31:0] w_ofs   = (kyi * K + kxi) * CSL + csi;

    // Address is combinational, data is registered: that is the template
    // rtl/dram_probe.v proved maps to GTP_DRM18K_E1.  Keeping a separate
    // address register would put the data two cycles behind the counters while
    // the accumulator only waits one, which silently drops a K-slice.
    always @(posedge clk) begin
        bband_q <= bband[act_off[31:3]];
        wq0 <= wb0[w_ofs];
        wq1 <= wb1[w_ofs];
        wq2 <= wb2[w_ofs];
        wq3 <= wb3[w_ofs];
        wq4 <= wb4[w_ofs];
        wq5 <= wb5[w_ofs];
        wq6 <= wb6[w_ofs];
        wq7 <= wb7[w_ofs];
    end

    // ------------------------------------------------------------- control
    always @(posedge clk) begin
        if (!rstn) begin
            st <= S_IDLE; busy <= 1'b0; done <= 1'b0; err <= 1'b0; cycles <= 0;
            rd_addr <= 0; rd_req <= 0; wr_addr <= 0; wr_data <= 0; wr_req <= 0;
            band_i <= 0; fr <= 0; fx <= 0; fcs <= 0; ti <= 0; wld_o <= 0; wld_w <= 0;
            row <= 0; col <= 0; kyi <= 0; kxi <= 0; csi <= 0; issue <= 0;
            q_i <= 0; t_i <= 0; bad_st <= 5'd0;
            mac_clear <= 1'b0; mac_valid <= 1'b0;
            y_lat <= 0;
            for (ia = 0; ia < COUT; ia = ia + 1) begin
                bias_r[ia] <= 32'd0;
                mval[ia]   <= 32'd0;
            end
        end
        else begin
            mac_clear <= 1'b0;
            rd_req    <= 1'b0;
            wr_req    <= 1'b0;

            if (busy && st != S_DONE)
                cycles <= cycles + 32'd1;

            case (st)
            S_IDLE: begin
                done <= 1'b0;
                if (start) begin
                    busy <= 1'b1; cycles <= 0; err <= 1'b0;
                    band_i <= 0; fr <= 0; fx <= 0; fcs <= 0; ti <= 0; q_i <= 0; t_i <= 0;
                    st <= S_Q;
                end
            end

            // ---- quant params: COUT bias words then COUT M words, 2 per read
            S_Q: begin
                // words 0..2*QW-1 come from the quant blob, the next 32 from the
                // activation table: one address generator, no extra states
                rd_addr <= (q_i < 2*QW) ? ((q_base >> 3) + q_i)
                                        : ((t_base >> 3) + (q_i - 2*QW));
                rd_req  <= 1'b1;
                st      <= S_QW;
            end
            S_QW: begin
                if (rd_valid) begin
                    if (rd_err) err <= 1'b1;
                    if (q_i < QW) begin
                        bias_r[q_i*2]     <= rd_data[31:0];
                        bias_r[q_i*2 + 1] <= rd_data[63:32];
                    end
                    else if (q_i < 2*QW) begin
                        mval[(q_i - QW)*2]     <= rd_data[31:0];
                        mval[(q_i - QW)*2 + 1] <= rd_data[63:32];
                    end
                    else begin
                        for (ia = 0; ia < 8; ia = ia + 1)
                            atab[(q_i - 2*QW)*8 + ia] <= rd_data[ia*8 +: 8];
                    end
                    if (q_i == 2*QW + 31) begin
                        q_i <= 0; fr <= 0; fx <= 0; fcs <= 0;
                        st  <= S_FILL;
                    end
                    else begin
                        q_i <= q_i + 1;
                        st  <= S_Q;
                    end
                end
            end

            // ---- band fill
            // Counters instead of dividing fill_i: PDS does not accept an
            // inferred divider and the earlier layer module already had to
            // remove one for that reason.
            S_FILL: begin
                if (fr < BROW) begin
                    if (((band_src0 + fr) < IN_H) && (fx >= PAD) &&
                        ((fx - PAD) < IN_W)) begin
                        rd_addr <= (a_base >> 3)
                                 + (((band_src0 + fr) * IN_W + (fx - PAD)) * CSL)
                                 + fcs;
                        rd_req  <= 1'b1;
                        st      <= S_FILLW;
                    end
                    else begin
                        bband[(fr * WPADX + fx) * CSL + fcs] <= 64'd0;
                        if (fcs == CSL - 1) begin
                            fcs <= 0;
                            if (fx == WPADX - 1) begin
                                fx <= 0;
                                fr <= fr + 1;
                            end
                            else
                                fx <= fx + 1;
                        end
                        else
                            fcs <= fcs + 1;
                    end
                end
                else begin
                    fr <= 0; fx <= 0; fcs <= 0;
                    ti <= 0; wld_o <= 0; wld_w <= 0;
                    st <= S_WLD;
                end
            end
            S_FILLW: begin
                if (rd_valid) begin
                    if (rd_err) err <= 1'b1;
                    bband[(fr * WPADX + fx) * CSL + fcs] <= rd_data;
                    st <= S_FILL;       // go back and request the next word
                    if (fcs == CSL - 1) begin
                        fcs <= 0;
                        if (fx == WPADX - 1) begin
                            fx <= 0;
                            fr <= fr + 1;
                        end
                        else
                            fx <= fx + 1;
                    end
                    else
                        fcs <= fcs + 1;
                end
            end

            // ---- weight load, one output channel at a time into its bank
            S_WLD: begin
                if (wld_w < WBUF) begin
                    rd_addr <= (w_base >> 3) + (ti*8 + wld_o) * WBUF + wld_w;
                    rd_req  <= 1'b1;
                    st      <= S_WLDW;
                end
                else begin
                    row <= 0; col <= 0;
                    kyi <= 0; kxi <= 0; csi <= 0;
                    issue <= 0;
                    mac_clear <= 1'b1;
                    st <= S_RUN;
                end
            end
            S_WLDW: begin
                if (rd_valid) begin
                    if (rd_err) err <= 1'b1;
                    st <= S_WLD;        // request the next weight word
                    if (wld_w == 0) begin
                        b_tile[wld_o] <= bias_r[ti*8 + wld_o];
                        m_tile[wld_o] <= mval[ti*8 + wld_o];
                    end
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
                    // walk wld_w 0..WBUF-1 inside one bank, then step to the
                    // next output channel.  Advancing both at once wrote only
                    // the diagonal of each bank and left the rest X.
                    if (wld_w == WBUF - 1) begin
                        wld_w <= 0;
                        if (wld_o == 7) begin
                            wld_o <= 0;
                            row <= 0; col <= 0;
                            kyi <= 0; kxi <= 0; csi <= 0; issue <= 0;
                            mac_clear <= 1'b1;
                            st <= S_RUN;         // whole tile resident: compute
                        end
                        else
                            wld_o <= wld_o + 1;
                    end
                    else
                        wld_w <= wld_w + 1;
                end
            end

            // ---- compute one pixel
            // Two-cycle-per-slice is avoided by separating the address stage
            // (issue) from the accumulate stage (mac_valid) by exactly one
            // cycle: the address presented now is consumed next cycle.
            S_RUN: begin
                // Address stage and accumulate stage are exactly one cycle
                // apart: the address presented in cycle c returns data in
                // c+1, and `mac_valid` for c+1 is decided in c.  Getting this
                // off by one silently drops the first K-slice and doubles the
                // last, which is invisible when NSL == 1.
                if (issue < NSL) begin
                    issue <= issue + 1;
                    if (csi == CSL - 1) begin
                        csi <= 0;
                        if (kxi == K - 1) begin
                            kxi <= 0;
                            kyi <= kyi + 1;
                        end
                        else
                            kxi <= kxi + 1;
                    end
                    else
                        csi <= csi + 1;
                end

                if (issue == NSL) begin
                    mac_valid <= 1'b0;
                    st        <= S_EPI;
                end
                else
                    mac_valid <= 1'b1;
            end

            S_EPI: begin
                mac_valid <= 1'b0;
                sum_lat   <= mac_sum;    // every slice has landed
                st        <= S_EPI2;
            end

            S_EPI2: begin
                for (ia = 0; ia < 8; ia = ia + 1)
                    pr_lat[ia*64 +: 64] <= $signed(sum_lat[ia*32 +: 32])
                                         * $signed(m_tile[ia]);
                st <= S_EPI3;
            end

            S_EPI3: begin
                y_lat <= y_word;         // round / clip / activation
                st    <= S_WR;
            end

            // ---- one 64-bit beat per pixel, wait for the acknowledge
            S_WR: begin
                wr_addr <= (y_base >> 3) + (((band_out0 + row) * OW + col) * (COUT/8))
                         + ti;
                wr_data <= y_lat;
                wr_req  <= 1'b1;
                st      <= S_WRA;
            end

            S_WRA: begin
                if (wr_ack) begin
                    wr_req <= 1'b0;
                    if (wr_err) err <= 1'b1;
                    if (col < OW - 1) begin
                        col <= col + 1;
                        st  <= S_CLR;
                    end
                    else if ((row < TR - 1) && ((band_out0 + row) < OH - 1)) begin
                        col <= 0;
                        row <= row + 1;
                        st  <= S_CLR;
                    end
                    else if (ti < NT - 1) begin
                        col <= 0; row <= 0; ti <= ti + 1;
                        wld_o <= 0; wld_w <= 0;
                        st  <= S_WLD;
                    end
                    else begin
                        col <= 0; row <= 0;
                        band_i <= band_i + 1;
                        st <= S_NEXT;
                    end
                end
            end

            // clear the accumulator for the next pixel (bias is loaded by the
            // clear pulse, see mac_array)
            S_CLR: begin
                mac_clear <= 1'b1;
                kyi <= 0; kxi <= 0; csi <= 0; issue <= 0;
                st  <= S_RUN;
            end

            S_NEXT: begin
                if ((band_i) * TR >= OH) begin
                    busy <= 1'b0; done <= 1'b1;
                    st   <= S_DONE;
                end
                else begin
                    fr <= 0; fx <= 0; fcs <= 0; ti <= 0;
                    st <= S_FILL;
                end
            end

            S_DONE: begin
                if (!start) done <= 1'b0;
            end

            default: begin
                bad_st <= st;       // an uncovered state must never happen
                err    <= 1'b1;
                st     <= S_IDLE;
            end
            endcase
        end
    end

endmodule
