// conv_engine_top -- resource and timing probe for conv_band_engine.
//
// The engine's own ports sum to ~364 bits, over the device's 300 IO, so it
// cannot be mapped directly (DRC-0018).  This wrapper ties the four base
// addresses to constants, drives read data from an internal LFSR and answers
// every write with an immediate ack, so every array and every multiplier keeps
// being exercised while only a narrow signature leaves the chip.
//
// What this build is expected to answer:
//   * do the band buffer and the eight weight banks infer as DRM (not LUTRAM)
//   * APM count, LUT/FF
//   * whether the 64 MAC/cycle datapath closes at the 10 ns constraint
// It is NOT the deployment top; the AXI wrapper comes later.
`timescale 1ns/1ps

module conv_engine_top(
    input  wire        clk,
    input  wire        rstn,
    output reg  [31:0] sig
);

    reg  [31:0] lfsr;
    reg         start;
    reg  [63:0] rd_data;
    reg         rd_valid;
    reg         rd_err;
    reg         wr_ack;
    wire        busy, done, err;
    wire [31:0] cycles;
    wire [31:0] rd_addr;
    wire        rd_req;
    wire [63:0] wr_data;
    wire [31:0] wr_addr;
    wire        wr_req;

    // one-cycle read latency with LFSR data: same shape as the DDR model the
    // engine was verified against
    always @(posedge clk) begin
        if (!rstn) begin
            lfsr     <= 32'h1;
            start    <= 1'b0;
            rd_valid <= 1'b0;
            rd_data  <= 64'd0;
            rd_err   <= 1'b0;
            wr_ack   <= 1'b0;
            sig      <= 32'd0;
        end
        else begin
            lfsr     <= {lfsr[30:0], lfsr[31] ^ lfsr[21] ^ lfsr[1] ^ lfsr[0]};
            rd_valid <= rd_req;
            rd_data  <= {lfsr, ~lfsr};
            rd_err   <= 1'b0;
            wr_ack   <= wr_req;
            start    <= (lfsr[7:0] == 8'h01);
            // Every engine output must reach an observable sink: the first
            // build reported 279 LUT / 0 APM / 0 DRM because wr_data, wr_addr
            // and rd_addr only drove local wires, so the whole datapath was
            // declared dangling and deleted.
            sig <= sig ^ (done ? cycles : 32'd0)
                       ^ wr_data[31:0] ^ wr_data[63:32]
                       ^ wr_addr ^ rd_addr ^ {31'd0, wr_req};
        end
    end

    conv_band_engine #(
        .CINPAD(32), .COUT(32), .IN_W(40), .IN_H(40),
        .K(3), .STRIDE(1), .ACT(1), .TR(8), .PADP(1), .SHIFT(15)
    ) u_eng (
        .clk(clk), .rstn(rstn), .start(start), .busy(busy), .done(done),
        .err(err), .cycles(cycles),
        .a_base(32'h0000_0000), .w_base(32'h0001_0000),
        .q_base(32'h0001_3000), .y_base(32'h0001_4000),
        .rd_addr(rd_addr), .rd_req(rd_req), .rd_data(rd_data),
        .rd_valid(rd_valid), .rd_err(rd_err),
        .wr_addr(wr_addr), .wr_data(wr_data), .wr_req(wr_req),
        .wr_ack(wr_ack), .wr_err(1'b0)
    );

endmodule
