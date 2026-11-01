// core8_top -- resource probe for the 8-output x 8-lane MAC core only.
// Memory arrays are deliberately excluded: the full-tensor layer build put
// 39,936 LUTs into distributed RAM and did not fit the device (135 % LUT), so
// the realistic accelerator needs block RAM / DDR tiling for storage.  This
// probe answers the separate question "what does the arithmetic cost".
`timescale 1ns/1ps
module core8_top(
    input  wire       clk,
    input  wire       rstn,
    output reg  [7:0] sig
);
    // Keep every input toggling so no multiplier or accumulator can be
    // optimised away, but do not expose 1,100 bits of ports (the device runs
    // out of IO and the probe dies in DRC).
    reg [31:0] lfsr;
    reg [255:0] bias_bus, m_bus;
    reg [63:0]  a_bus;
    reg [511:0] w_bus;
    reg         start, valid;
    wire        y_valid;
    wire [63:0] y_bus;
    integer i;

    always @(posedge clk) begin
        if (!rstn) begin
            lfsr <= 32'h1;
            bias_bus <= 0; m_bus <= 0; a_bus <= 0; w_bus <= 0;
            start <= 1'b1; valid <= 1'b0; sig <= 0;
        end
        else begin
            lfsr <= {lfsr[30:0], lfsr[31] ^ lfsr[21] ^ lfsr[1] ^ lfsr[0]};
            for (i = 0; i < 256; i = i + 32)
                bias_bus[i +: 32] <= lfsr + i;
            for (i = 0; i < 256; i = i + 32)
                m_bus[i +: 32] <= {16'd0, lfsr[15:0]} + i;
            for (i = 0; i < 64; i = i + 8)
                a_bus[i +: 8] <= lfsr[((i / 8) % 4) * 8 +: 8];
            for (i = 0; i < 512; i = i + 8)
                w_bus[i +: 8] <= lfsr[((i / 8) % 4) * 8 +: 8];
            start <= (lfsr[7:0] == 8'h00);
            valid <= (lfsr[8:0] != 9'h1ff);
            if (y_valid) sig <= sig ^ y_bus[63:56] ^ y_bus[7:0];
        end
    end

    conv3x3_core #(.CIN(256), .COUT(8), .K(1), .ACT(2)) u_core (
        .clk(clk), .rstn(rstn), .start(start), .bias_bus(bias_bus),
        .m_bus(m_bus), .s_shift(5'd15), .valid(valid), .a_bus(a_bus),
        .w_bus(w_bus), .y_valid(y_valid), .y_bus(y_bus)
    );
endmodule
