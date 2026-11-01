// mac_array_top -- resource/timing probe for rtl/mac_array.v.
//
// mac_array exposes C*32 + C*L*8 + L*8 = 1092 bits of ports, which exceeds the
// device IO budget (300) and dies in DRC-0018 during dev_map.  Same workaround
// as core8_top: drive everything from an internal LFSR so every multiplier and
// accumulator keeps toggling, and expose a single narrow signature output.
//
// The point of this probe is the APM count: mac_array must report
// Total APMs == C*L == 64.  Anything less means synthesis shared multipliers
// again, which silently divides throughput by the sharing factor.
`timescale 1ns/1ps

module mac_array_top(
    input  wire       clk,
    input  wire       rstn,
    output reg  [31:0] sig
);

    localparam integer L = 8;
    localparam integer C = 8;

    reg [31:0]          lfsr;
    reg [C*32-1:0]      bias_bus;
    reg [L*8-1:0]       a_bus;
    reg [C*L*8-1:0]     w_bus;
    reg                 clear, valid;
    wire [C*32-1:0]     sum_bus;
    integer i;

    always @(posedge clk) begin
        if (!rstn) begin
            lfsr     <= 32'h1;
            bias_bus <= 0;
            a_bus    <= 0;
            w_bus    <= 0;
            clear    <= 1'b1;
            valid    <= 1'b0;
            sig      <= 32'd0;
        end
        else begin
            lfsr <= {lfsr[30:0], lfsr[31] ^ lfsr[21] ^ lfsr[1] ^ lfsr[0]};

            for (i = 0; i < C*32; i = i + 32)
                bias_bus[i +: 32] <= lfsr + i;
            for (i = 0; i < L*8; i = i + 8)
                a_bus[i +: 8] <= lfsr[((i / 8) % 4) * 8 +: 8];
            for (i = 0; i < C*L*8; i = i + 8)
                w_bus[i +: 8] <= lfsr[((i / 8) % 4) * 8 +: 8];

            clear <= (lfsr[9:2] == 8'h00);
            valid <= (lfsr[9:2] != 8'hff);
            sig   <= sig ^ sum_bus[31:0] ^ sum_bus[C*32-1 -: 32];
        end
    end

    mac_array #(.L(L), .C(C)) u_mac (
        .clk(clk), .rstn(rstn), .clear(clear), .valid(valid),
        .bias_bus(bias_bus), .a_bus(a_bus), .w_bus(w_bus), .sum_bus(sum_bus));

endmodule
