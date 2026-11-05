// conv_rt_top -- resource/timing probe for conv_band_rt.  Bases are tied off and
// the read data comes from an LFSR so every array and multiplier keeps toggling
// while only a narrow signature leaves the chip (the device has 300 IO).
`timescale 1ns/1ps
module conv_rt_top(
    input  wire        clk,
    input  wire        rstn,
    output reg  [31:0] sig
);
    reg  [31:0] lfsr;
    reg         start;
    reg  [63:0] rd_data;
    wire [63:0] wr_data;
    reg         rd_valid, wr_ack;
    wire [31:0] wr_addr;
    wire [31:0] rd_addr;
    wire        rd_req, wr_req;
    wire        busy, done, err;
    wire [31:0] cycles;
    wire [4:0]  dbg_st;
    wire        dbg_anom;
    wire [31:0] dbg_snap;

    always @(posedge clk) begin
        if (!rstn) begin
            lfsr <= 32'h1; start <= 1'b0; rd_valid <= 0; rd_data <= 0;
            wr_ack <= 0; sig <= 0;
        end
        else begin
            lfsr <= {lfsr[30:0], lfsr[31] ^ lfsr[21] ^ lfsr[1] ^ lfsr[0]};
            start <= (lfsr[3:0] == 4'h1);
            rd_valid <= rd_req;
            rd_data  <= {lfsr, ~lfsr};
            wr_ack   <= wr_req;
            sig <= sig ^ wr_data[31:0] ^ wr_data[63:32] ^ wr_addr ^ rd_addr
                       ^ (done ? cycles : 32'd0) ^ {27'd0, dbg_st};
        end
    end

    conv_band_rt #(.BANDW(7168), .WBANK(576), .TRM(8)) u (
        .clk(clk), .rstn(rstn), .start(start), .busy(busy), .done(done),
        .err(err), .cycles(cycles),
        .p_cin(16'd32), .p_cout(16'd32), .p_in_w(16'd40), .p_in_h(16'd40),
        .p_out_w(16'd40), .p_out_h(16'd40), .p_k(8'd3), .p_stride(8'd1),
        .p_pad(8'd1), .p_act(2'd2), .p_tr(8'd8), .p_shift(5'd15),
        .a_base(32'h0000_0000), .w_base(32'h0001_0000), .q_base(32'h0001_3000),
        .t_base(32'h0001_4000), .y_base(32'h0001_5000),
        .dbg_st(dbg_st), .dbg_anom(dbg_anom), .dbg_snap(dbg_snap),
        .rd_addr(rd_addr), .rd_req(rd_req), .rd_data(rd_data),
        .rd_valid(rd_valid), .rd_err(1'b0),
        .wr_addr(wr_addr), .wr_data(wr_data), .wr_req(wr_req),
        .wr_ack(wr_ack), .wr_err(1'b0)
    );
endmodule
