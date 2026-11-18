// Explicit 8x8 signed multiplier/accumulator array. Resource reports alone do
// not establish throughput: mapping may use DSPs, LUTs, or remove unused logic.
// Functional and netlist timing checks are separate acceptance conditions.
//
// Structure
// ---------
//   acc[oc][lane] += a[lane] * w[oc][lane]        every cycle `valid` is high
// Per-lane accumulators avoid an 8-input adder tree on the accumulate path:
// the critical path is one multiplier plus one 32-bit add, and the 8-way
// reduction happens once per output pixel in the epilogue instead of once per
// K-slice.
//
// The epilogue expression assumes L=8. Its mapped timing must be measured.
`timescale 1ns/1ps

module mac_array #(
    parameter integer L = 8,        // activation lanes = taps consumed per cycle
    parameter integer C = 8         // output channels computed in parallel
)(
    input  wire                clk,
    input  wire                rstn,

    input  wire                clear,      // synchronous: load bias, zero the rest
    input  wire                valid,      // one K-slice this cycle
    input  wire [C*32-1:0]     bias_bus,   // per output channel, int32
    input  wire [L*8-1:0]      a_bus,      // L int8 activations
    input  wire [C*L*8-1:0]    w_bus,      // C x L int8 weights

    output wire [C*32-1:0]     sum_bus     // C int32 partial sums (combinational)
);

    // Flat storage: element (oc, lane) lives at oc*L + lane.  Declared at module
    // scope because PDS rejects declarations inside procedural blocks
    // (Verilog-4109) and flat indexing keeps the generate blocks trivial.
    reg signed [31:0] acc [0:C*L-1];

    genvar go, gl;

    generate
        for (go = 0; go < C; go = go + 1) begin : g_oc
            for (gl = 0; gl < L; gl = gl + 1) begin : g_lane
                wire signed [7:0]  av = a_bus[gl*8 +: 8];
                wire signed [7:0]  wv = w_bus[(go*L + gl)*8 +: 8];
                wire signed [15:0] pv = av * wv;   // 8x8 signed -> 16 bit, 1 APM

                always @(posedge clk) begin
                    if (!rstn)
                        acc[go*L + gl] <= 32'sd0;
                    else if (clear)
                        acc[go*L + gl] <= (gl == 0) ? $signed(bias_bus[go*32 +: 32])
                                                    : 32'sd0;
                    else if (valid)
                        acc[go*L + gl] <= acc[go*L + gl] + {{16{pv[15]}}, pv};
                end
            end
        end
    endgenerate

    // Epilogue reduction: L values per output channel, once per pixel.
    generate
        for (go = 0; go < C; go = go + 1) begin : g_red
            wire signed [31:0] s = acc[go*L + 0] + acc[go*L + 1]
                                 + acc[go*L + 2] + acc[go*L + 3]
                                 + acc[go*L + 4] + acc[go*L + 5]
                                 + acc[go*L + 6] + acc[go*L + 7];
            assign sum_bus[go*32 +: 32] = s;
        end
    endgenerate

endmodule
