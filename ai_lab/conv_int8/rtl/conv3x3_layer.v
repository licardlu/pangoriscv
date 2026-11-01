// conv3x3_layer -- one complete YOLO convolution layer with a KxK kernel, a
// stride, and a real SiLU epilogue.  Derived from the verified 3x3/stride-1
// version, which stays bit-exact for K=3 / STRIDE=1 / ACT=leaky.
//
// Why the generalisation exists: the first real YOLOv5n layer is 6x6 stride 2,
// not 3x3 stride 1.  Writing the accelerator around "3x3 only" and discovering
// that later would force a rewrite of the line buffer and the K-slice counter.
//
// Data layout (unchanged):
//   in_ram   [y][x][c]              W*H*CIN
//   w_ram    [oc][tap][c]           COUT*CIN*K*K      tap-major
//   out_ram  [y][x][oc]             OUTH*OUTW*COUT
//
// Padding follows YOLOv5's `autopad`: PAD = K/2, applied symmetrically in the
// index arithmetic (out-of-range rows/columns read as zero).
`timescale 1ns/1ps

module conv3x3_layer #(
    parameter integer CIN    = 8,
    parameter integer COUT   = 16,
    parameter integer W      = 64,
    parameter integer H      = 64,
    parameter integer K      = 3,
    parameter integer STRIDE = 1,
    parameter integer ACT    = 1       // 0 none, 1 leaky, 2 SiLU LUT
)(
    input  wire                clk,
    input  wire                rstn,

    input  wire                start,
    input  wire [4:0]          s_shift,

    // preload: sel 0 = input tensor, 1 = weights
    input  wire                ld_en,
    input  wire [1:0]          ld_sel,     // 0 input, 1 weights, 2 bias, 3 M
    input  wire [31:0]         ld_addr,
    input  wire [7:0]          ld_data,
    input  wire [31:0]         ld_data32,

    // result readout
    input  wire [31:0]         rd_addr,
    output wire [7:0]          rd_data,

    output reg                 busy,
    output reg                 done,
    output reg  [31:0]         cycles
);

    localparam integer PAD   = K / 2;
    localparam integer OUTW  = (W + 2 * PAD - K) / STRIDE + 1;
    localparam integer OUTH  = (H + 2 * PAD - K) / STRIDE + 1;
    localparam integer KS    = (CIN * K * K + 7) / 8;   // K-slices per pixel
    localparam integer NT    = (COUT + 7) / 8;          // output-channel tiles
    localparam integer RSZ   = W * CIN;                 // bytes per input row

    localparam [3:0] S_IDLE = 4'd0, S_FILL = 4'd1, S_CSTART = 4'd2, S_PIX = 4'd3,
                     S_WAIT = 4'd4, S_WR = 4'd5, S_SHIFT = 4'd6, S_DONE = 4'd7;

    reg [7:0] in_ram  [0:W*H*CIN-1];
    reg [7:0] w_ram   [0:COUT*CIN*K*K-1];
    reg [7:0] out_ram [0:OUTW*OUTH*COUT-1];
    reg [7:0] lb      [0:K*W*CIN-1];
    // Bias and per-channel multiplier live here rather than on a COUT*32-bit
    // port: a 4096-bit register in the shell made PDS tie the unused lanes to
    // GND and abort with a bogus multiple-driver error.
    reg [31:0] bias_ram [0:COUT-1];
    reg [31:0] m_ram    [0:COUT-1];

    always @(posedge clk) begin
        if (ld_en) begin
            if (ld_sel == 2'd0)      in_ram[ld_addr]   <= ld_data;
            else if (ld_sel == 2'd1) w_ram[ld_addr]    <= ld_data;
            else if (ld_sel == 2'd2) bias_ram[ld_addr] <= ld_data32;
            else                     m_ram[ld_addr]    <= ld_data32;
        end
    end

    assign rd_data = out_ram[rd_addr];

    // ---- counters ---------------------------------------------------------
    reg [3:0]  st;
    integer    fx, fy, tile, s_cnt, wo, gi_;
    integer    row_;
    integer    sr, sc;    // explicit row/column cursors: no divide/modulo by RSZ
    // PDS rejects declarations inside an unnamed always block (Verilog-4109),
    // so the loop indices live here.  Two separate sets avoid the shared
    // static-variable trap that broke the earlier per-block version.
    reg [31:0] a_ja, a_kka, a_sx;
    // K=1 (the layer verified this round) collapses the tap arithmetic to
    // constants.  The generic branch keeps divide/modulo for later K=3/6 work;
    // PDS only elaborates the branch selected by the constant parameter.
    wire [31:0] k_tap, k_cc;
    wire signed [31:0] k_dy, k_dx;
    generate
        if (K == 1) begin : g_k1
            assign k_tap = 32'd0;
            assign k_cc  = a_kka;
            assign k_dy  = 32'sd0;
            assign k_dx  = 32'sd0;
        end
        else begin : g_kgeneric
            assign k_tap = a_kka / CIN;
            assign k_cc  = a_kka % CIN;
            assign k_dy  = k_tap / K - PAD;
            assign k_dx  = k_tap % K - PAD;
        end
    endgenerate
    integer    w_oc, w_jb, w_kkb, w_oc_abs;

    // ---- core -------------------------------------------------------------
    reg  [63:0]        a_calc;
    reg  [8*64-1:0]    w_calc;
    wire [8*8-1:0]     y_core;
    wire               y_core_valid;
    reg  [63:0]        y_lat;
    wire               core_start = (st == S_CSTART);
    wire               core_valid = (st == S_PIX);

    // build one K-slice of activations.
    // Block-local integers are declared without initialisers: `int x = expr;`
    // inside an always block is a STATIC variable in Verilog, initialised once
    // at time zero, so the slice would never be recomputed.
    always @(*) begin
        a_calc = 64'd0;
        for (a_ja = 0; a_ja < 8; a_ja = a_ja + 1) begin
            a_kka = s_cnt * 8 + a_ja;
            a_sx  = fx * STRIDE + k_dx;
            if (a_kka < CIN * K * K && $signed(a_sx) >= 0 && $signed(a_sx) < W)
                a_calc[a_ja*8 +: 8] = lb[(k_dy + PAD) * RSZ + a_sx * CIN + k_cc];
        end
    end

    // build the matching weight slice for this tile
    always @(*) begin
        w_calc = 0;
        for (w_oc = 0; w_oc < 8; w_oc = w_oc + 1) begin
            w_oc_abs = tile * 8 + w_oc;
            for (w_jb = 0; w_jb < 8; w_jb = w_jb + 1) begin
                w_kkb = s_cnt * 8 + w_jb;
                if (w_kkb < CIN * K * K && w_oc_abs < COUT)
                    w_calc[(w_oc*8 + w_jb)*8 +: 8] = w_ram[w_oc_abs*CIN*K*K + w_kkb];
            end
        end
    end

    wire [8*32-1:0] bias_slice, m_slice;
    genvar gt;
    generate
        for (gt = 0; gt < 8; gt = gt + 1) begin : g_tile_param
            assign bias_slice[gt*32 +: 32] = bias_ram[tile*8 + gt];
            assign m_slice[gt*32 +: 32]    = m_ram[tile*8 + gt];
        end
    endgenerate

    conv3x3_core #(.CIN(CIN), .COUT(8), .K(K), .ACT(ACT)) u_core (
        .clk(clk), .rstn(rstn),
        .start(core_start),
        .bias_bus(bias_slice),
        .m_bus(m_slice),
        .s_shift(s_shift),
        .valid(core_valid), .a_bus(a_calc), .w_bus(w_calc),
        .y_valid(y_core_valid), .y_bus(y_core)
    );

    // ---- control ----------------------------------------------------------
    always @(posedge clk) begin
        if (!rstn) begin
            st     <= S_IDLE;
            busy   <= 1'b0;
            done   <= 1'b0;
            cycles <= 32'd0;
            fx <= 0; fy <= 0; tile <= 0; s_cnt <= 0; wo <= 0; gi_ <= 0;
            sr <= 0; sc <= 0;
        end
        else begin
            if (busy && st != S_DONE)
                cycles <= cycles + 32'd1;

            case (st)
                S_IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        busy   <= 1'b1;
                        cycles <= 32'd0;
                        fy     <= 0;
                        fx     <= 0;
                        tile   <= 0;
                        s_cnt  <= 0;
                        gi_    <= 0;
                        sr     <= 0;
                        sc     <= 0;
                        st     <= S_FILL;
                    end
                end

                // fill the K-row window for output row 0
                S_FILL: begin
                    row_ = -PAD + sr;
                    if (row_ >= 0 && row_ < H)
                        lb[sr * RSZ + sc] <= in_ram[row_ * RSZ + sc];
                    else
                        lb[sr * RSZ + sc] <= 8'd0;
                    if (sc == RSZ - 1) begin
                        sc <= 0;
                        if (sr == K - 1) begin
                            sr <= 0;
                            st <= S_CSTART;
                        end
                        else
                            sr <= sr + 1;
                    end
                    else
                        sc <= sc + 1;
                end

                S_CSTART: begin
                    s_cnt <= 0;
                    st    <= S_PIX;
                end

                S_PIX: begin
                    if (s_cnt == KS - 1)
                        st <= S_WAIT;
                    else
                        s_cnt <= s_cnt + 1;
                end

                S_WAIT: begin
                    if (y_core_valid) begin
                        y_lat <= y_core;
                        wo    <= 0;
                        st    <= S_WR;
                    end
                end

                S_WR: begin
                    out_ram[(fy * OUTW + fx) * COUT + tile * 8 + wo] <= y_lat[7:0];
                    if (wo == 8 - 1) begin
                        wo <= 0;
                        if (tile == NT - 1) begin
                            tile <= 0;
                            if (fx == OUTW - 1) begin
                                fx <= 0;
                                st <= S_SHIFT;
                            end
                            else begin
                                fx <= fx + 1;
                                st <= S_CSTART;
                            end
                        end
                        else begin
                            tile <= tile + 1;
                            st   <= S_CSTART;
                        end
                    end
                    else begin
                        // y_lat holds 8 bytes; hand them out low byte first
                        y_lat <= {y_lat[7:0], y_lat[63:8]};
                        wo    <= wo + 1;
                    end
                end

                // slide the window by STRIDE rows: the top K-STRIDE rows come
                // from the buffer, the STRIDE new rows come straight from
                // in_ram at absolute row (fy+1)*STRIDE - PAD + fr.
                S_SHIFT: begin
                    if (sr < K - STRIDE)
                        lb[sr * RSZ + sc] <= lb[(sr + STRIDE) * RSZ + sc];
                    else begin
                        row_ = (fy + 1) * STRIDE - PAD + sr;
                        if (row_ >= 0 && row_ < H)
                            lb[sr * RSZ + sc] <= in_ram[row_ * RSZ + sc];
                        else
                            lb[sr * RSZ + sc] <= 8'd0;
                    end
                    if (sc == RSZ - 1) begin
                        sc <= 0;
                        if (sr == K - 1) begin
                            sr <= 0;
                            fy <= fy + 1;
                            if (fy == OUTH - 1) begin
                                busy <= 1'b0;
                                done <= 1'b1;
                                st   <= S_DONE;
                            end
                            else
                                st <= S_CSTART;
                        end
                        else
                            sr <= sr + 1;
                    end
                    else
                        sc <= sc + 1;
                end

                S_DONE: begin
                    if (start) begin
                        done <= 1'b0;
                        busy <= 1'b1;
                        fy   <= 0; fx <= 0; tile <= 0; s_cnt <= 0; gi_ <= 0; sr <= 0; sc <= 0;
                        cycles <= 32'd0;
                        st   <= S_FILL;
                    end
                end

                default: st <= S_IDLE;
            endcase
        end
    end

endmodule
