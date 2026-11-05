// mult_cal -- multiplier-density calibration probe.
//
// The MAC core report said 64 int8 multiply-accumulates cost only 8 APM, i.e.
// 8 MACs per APM.  That is a claim about how Pango packs 8-bit operands into
// the APM, and the whole accelerator architecture (how many lanes we can afford
// at 100 MHz) depends on it being true.  This probe puts N plain 8x8->32
// multipliers behind a register with no loop or function wrapper, so the area
// report can only be explained by operand packing inside the APM.
//
// Instantiate MULT_CAL_TOP with a fixed N per run; PDS needs one project per
// top module.
`timescale 1ns/1ps

module mult_cal #(
    parameter integer N = 64
)(
    input  wire              clk,
    input  wire [N*8-1:0]    a,
    input  wire [N*8-1:0]    b,
    output reg  [N*32-1:0]   y
);

    genvar gi;
    generate
        for (gi = 0; gi < N; gi = gi + 1) begin : g_mul
            wire signed [7:0]  av = a[gi*8 +: 8];
            wire signed [7:0]  bv = b[gi*8 +: 8];
            wire signed [31:0] p  = av * bv;
            always @(posedge clk) y[gi*32 +: 32] <= p;
        end
    endgenerate

endmodule


module mult_cal_64 (
    input  wire            clk,
    input  wire [511:0]    a,
    input  wire [511:0]    b,
    output wire [2047:0]   y
);
    mult_cal #(.N(64)) u (.clk(clk), .a(a), .b(b), .y(y));
endmodule


module mult_cal_128 (
    input  wire            clk,
    input  wire [1023:0]   a,
    input  wire [1023:0]   b,
    output wire [4095:0]   y
);
    mult_cal #(.N(128)) u (.clk(clk), .a(a), .b(b), .y(y));
endmodule


module mult_cal_256 (
    input  wire            clk,
    input  wire [2047:0]   a,
    input  wire [2047:0]   b,
    output wire [8191:0]   y
);
    mult_cal #(.N(256)) u (.clk(clk), .a(a), .b(b), .y(y));
endmodule
