// conv3x3_top -- self-contained harness around conv3x3_core.
//
// The core has ~600 bits of stimulus ports, far more than the package can bond
// out, so this wrapper drives it from an internal LFSR and exposes only the
// clock, reset and the output byte.  Everything is observable at y0, so the
// datapath cannot be optimised away.
//
// IMPORTANT: weights must differ per output channel.  An earlier version fed
// the same 64-bit word to every channel, which made all COUT accumulators
// identical; synthesis then collapsed the array to a single 8-tap dot product
// and reported 8 APM / 263 LUT -- a fiction.  Each channel now gets its own
// scramble so the array is genuinely COUT x 8 lanes.
`timescale 1ns/1ps

module conv3x3_top(
    input  wire       clk,
    input  wire       rstn,
    output wire [7:0] y0
);

    localparam integer CIN  = 8;
    localparam integer COUT = 8;
    localparam integer KS   = (CIN * 9) / 8;

    reg  [15:0] lfsr;
    reg  [7:0]  cyc;
    reg         start;
    reg         valid;
    reg  [63:0] a_bus;
    wire [COUT*64-1:0] w_bus;
    wire [COUT*8-1:0]  y_bus;
    wire        y_valid;

    wire [63:0] noise = {lfsr, lfsr[15:8], lfsr[7:0], ~lfsr[15:8],
                         lfsr[3:0], lfsr[11:4], ~lfsr[7:0], lfsr[9:2]};

    // per-channel weight scramble: keeps the COUT accumulators independent
    genvar gi;
    generate
        for (gi = 0; gi < COUT; gi = gi + 1) begin : g_w
            assign w_bus[gi*64 +: 64] = noise ^ {8{(gi * 8'd37 + 8'd11)}};
        end
    endgenerate

    always @(posedge clk) begin
        if (!rstn) begin
            lfsr  <= 16'hACE1;
            cyc   <= 8'd0;
            start <= 1'b0;
            valid <= 1'b0;
            a_bus <= 64'd0;
        end
        else begin
            lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};

            if (cyc == 8'd0) begin
                start <= 1'b1;
                valid <= 1'b0;
            end
            else if (cyc <= KS) begin
                start <= 1'b0;
                valid <= 1'b1;
            end
            else begin
                start <= 1'b0;
                valid <= 1'b0;
            end

            if (cyc >= KS + 8)
                cyc <= 8'd0;
            else
                cyc <= cyc + 8'd1;

            a_bus <= noise;
        end
    end

    conv3x3_core #(.CIN(CIN), .COUT(COUT)) u_core (
        .clk(clk), .rstn(rstn),
        .start(start),
        .bias_bus({COUT{32'sd17}}),
        .m_bus({COUT{32'sd4096}}),
        .s_shift(5'd15),
        .valid(valid), .a_bus(a_bus), .w_bus(w_bus),
        .y_valid(y_valid), .y_bus(y_bus)
    );

    // Every output channel must stay observable.  Wiring only byte 0 to the pin
    // let synthesis delete channels 1..7 and report 8 APM for a 64-lane array.
    reg [7:0] yred;
    integer ci;
    always @(*) begin
        yred = 8'd0;
        for (ci = 0; ci < COUT; ci = ci + 1)
            yred = yred ^ y_bus[ci*8 +: 8];
    end

    // y_valid is folded into bit 0 so the pulse is observable but costs no pin
    assign y0 = yred | {7'd0, y_valid};

endmodule
