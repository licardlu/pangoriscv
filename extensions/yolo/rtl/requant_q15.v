// Saturating Q15 requantization. Three registered stages separate magnitude,
// rounding and clipping; the activation table remains in the caller.
`timescale 1ns/1ps
module requant_q15 (
    input wire clk,
    input wire signed [63:0] product,
    output reg [7:0] value
);
    reg [22:0] magnitude, rounded;
    reg negative_1, negative_2, overflow_1, overflow_2;
    always @(posedge clk) begin
        magnitude <= product[63] ? (~product[22:0] + 23'd1) : product[22:0];
        negative_1 <= product[63];
        overflow_1 <= product[63] ? !(&product[63:22]) : (|product[63:22]);
        rounded <= magnitude + 23'd16384;
        negative_2 <= negative_1;
        overflow_2 <= overflow_1;
        if (overflow_2)
            value <= negative_2 ? 8'h80 : 8'h7f;
        else if (!negative_2 && rounded[22:15] > 8'd127)
            value <= 8'h7f;
        else
            value <= negative_2 ? (8'd0 - rounded[22:15]) : rounded[22:15];
    end
endmodule
