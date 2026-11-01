// conv3x3_core -- single-layer integer convolution engine, Lite-A datapath.
//
// One output pixel at a time. The K dimension (CIN*9 taps) is streamed as
// slices of 8; each cycle COUT output channels accumulate 8 products each, so
// the array is COUT x 8 lanes. Weights are stationary for the whole layer: the
// caller supplies them alongside the activations, which is exactly the pairing
// the vector generator produces.
//
// The epilogue is the part that must match the software bit for bit:
//     y = (acc * M) >> S       round-half-away-from-zero
//     y = clip(y, -128, 127)
//     y = y >> 3 if y < 0      arithmetic shift = floor
`timescale 1ns/1ps

module conv3x3_core #(
    parameter integer CIN  = 8,
    parameter integer COUT = 8,
    parameter integer K    = 3,      // kernel width/height (YOLOv5n layer 0 uses 6)
    parameter integer ACT  = 1       // 0 = none, 1 = leaky, 2 = SiLU int8 LUT
)(
    input  wire                clk,
    input  wire                rstn,

    input  wire                start,       // pulse: load bias/M, begin a pixel
    input  wire [COUT*32-1:0]  bias_bus,    // per output channel, int32
    input  wire [COUT*32-1:0]  m_bus,       // per output channel, int32
    input  wire [4:0]          s_shift,

    input  wire                valid,       // one K-slice this cycle
    input  wire [63:0]         a_bus,       // 8 int8 activations
    input  wire [COUT*64-1:0]  w_bus,       // COUT x 8 int8 weights

    output reg                 y_valid,
    output reg  [COUT*8-1:0]   y_bus
);

    localparam integer KS  = (CIN * K * K + 7) / 8;   // K-slices per output pixel
    localparam         IDLE = 2'd0;
    localparam         ACC  = 2'd1;
    localparam         EPI  = 2'd2;

    reg signed [31:0] acc [0:COUT-1];
    reg signed [31:0] m_r [0:COUT-1];
    reg        [4:0]  s_r;
    reg        [1:0]  st;
    integer           kc;
    integer           i;

    // 8-lane dot product for one output channel
    function signed [31:0] mac8;
        input integer        oc;
        input [63:0]         a;
        input [COUT*64-1:0]  w;
        integer              kk;
        reg signed [31:0]    s;
        begin
            s = 32'sd0;
            for (kk = 0; kk < 8; kk = kk + 1)
                s = s + $signed(a[kk*8 +: 8]) * $signed(w[(oc*8+kk)*8 +: 8]);
            mac8 = s;
        end
    endfunction

    always @(posedge clk) begin
        if (!rstn) begin
            st      <= IDLE;
            kc      <= 0;
            s_r     <= 5'd15;
            y_valid <= 1'b0;
            y_bus   <= {COUT*8{1'b0}};
            for (i = 0; i < COUT; i = i + 1) begin
                acc[i] <= 32'sd0;
                m_r[i] <= 32'sd0;
            end
        end
        else begin
            y_valid <= 1'b0;
            case (st)
                IDLE: begin
                    kc <= 0;
                    if (start) begin
                        s_r <= s_shift;
                        for (i = 0; i < COUT; i = i + 1) begin
                            acc[i] <= $signed(bias_bus[i*32 +: 32]);
                            m_r[i] <= $signed(m_bus[i*32 +: 32]);
                        end
                        st <= ACC;
                    end
                end
                ACC: begin
                    if (valid) begin
                        for (i = 0; i < COUT; i = i + 1)
                            acc[i] <= acc[i] + mac8(i, a_bus, w_bus);
                        if (kc == KS - 1)
                            st <= EPI;
                        else
                            kc <= kc + 1;
                    end
                end
                EPI: begin
                    y_bus   <= y_comb;
                    y_valid <= 1'b1;
                    st      <= IDLE;
                end
                default: st <= IDLE;
            endcase
        end
    end

    // ---- epilogue ---------------------------------------------------------
    wire [COUT*8-1:0] y_comb;

    genvar gi;
    generate
        for (gi = 0; gi < COUT; gi = gi + 1) begin : g_epi
            wire signed [63:0] prod = $signed(acc[gi]) * $signed(m_r[gi]);
            wire signed [63:0] half = (s_r == 5'd0) ? 64'sd0
                                    : (prod < 0) ? -(64'sd1 <<< (s_r - 5'd1))
                                                 :  (64'sd1 <<< (s_r - 5'd1));
            wire signed [63:0] rnd  = prod + half;
            wire signed [63:0] sh   = (s_r == 5'd0) ? rnd : (rnd >>> s_r);
            wire signed [63:0] cl   = (sh > 64'sd127)  ? 64'sd127
                                    : (sh < -64'sd128) ? -64'sd128 : sh;
            // keep the 8-bit host explicit: a mixed signed/unsigned ternary
            // let the shift widen to the 5-bit s_r width and zeroed the sign bits
            wire signed [7:0]  cl8  = cl[7:0];
            wire signed [7:0]  lk   = (cl8 < 0) ? (cl8 >>> 3) : cl8;
            wire        [7:0]  s8;
            silu_lut8 u_silu (.q(cl8), .y(s8));
            assign y_comb[gi*8 +: 8] = (ACT == 0) ? cl8 :
                                       (ACT == 2) ? s8  : lk;
        end
    endgenerate

endmodule
