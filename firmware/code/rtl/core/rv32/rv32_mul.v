//=============================================================================
// pangoriscv - rv32 core
// Module : rv32_mul               File : rtl/core/rv32/rv32_mul.v
// Rev    : 1.2                    Date : 2026-10-21
// Brief  : 32x32 multiply, combinational, one shared 33x33 signed array
//=============================================================================

// The delivered core multiplied combinationally with absolute values, four
// cascaded APM blocks and a 64-bit negate: 6.3 ns of the 32.573 ns critical path
// (plan v2 section 1.2).  That cost came from placement, not from the multiply
// itself: it sat between the ALU result and the *next* instruction's ALU operand
// mux, so one instruction's multiply had to finish inside another's execute
// stage.
//
// Here the product is consumed only inside the execute stage and its result is
// registered at the EX/M1 boundary, so nothing downstream depends on it
// combinationally.  One signed 33x33 array covers all four M-extension
// multiplies: extending both operands to 33 bits (sign or zero) makes the
// signed product equal to the unsigned one whenever both are non-negative, and
// the 66-bit result holds every case without a bias correction.
module rv32_mul(
    input  wire [2:0]  op,
    input  wire [31:0] a,
    input  wire [31:0] b,
    output wire [31:0] y
);
    localparam [2:0] MUL_MUL = 3'd0, MUL_H = 3'd1, MUL_HSU = 3'd2, MUL_HU = 3'd3;

    // mulhu: both unsigned.  mulhsu: a signed, b unsigned.  mul/mulh: both signed.
    wire signed [32:0] a_x = (op == MUL_HU) ? {1'b0, a} : {a[31], a};
    wire signed [32:0] b_x = (op == MUL_HU || op == MUL_HSU) ? {1'b0, b} : {b[31], b};
    wire signed [65:0] prod = a_x * b_x;

    assign y = (op == MUL_MUL) ? prod[31:0] : prod[63:32];
endmodule
