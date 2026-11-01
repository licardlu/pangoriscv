// postop_engine -- the non-convolution operators YOLOv5n needs.
//
// Four ops on a channel-last [y][x][c] tensor with C a multiple of 8, moving one
// 8-byte channel vector per output step:
//
//   MAXPOOL  k x k, stride 1 or 2   (SPPF k=5 s=1, stem k=2 s=2)
//   UPSAMPLE nearest 2x             (PAN neck)
//   CONCAT   two inputs along c     (C3 blocks, SPPF output)
//   ADD      elementwise saturating (C3 bottlenecks)
//
// Doing these on the CPU would cost more than the convolutions: one byte touched
// per byte of tensor with no reuse.  A small engine keeps the CPU for scheduling.
//
// Structure: one "advance" point.  Every state either issues a read, folds a
// returned read into the result, or writes the result, and then calls the same
// advance logic.  There is exactly one place where cv/col/row move forward, which
// is what made the convolution engine's loop bugs visible in the first place.
//
// Read port: one 64-bit word per request, one outstanding, as conv_band_engine.
// Write port: one 64-bit word per output vector, acked.
`timescale 1ns/1ps

module postop_engine #(
    parameter integer C      = 8,
    parameter integer IN_W   = 40,
    parameter integer IN_H   = 40,
    parameter integer K      = 5,
    parameter integer STRIDE = 1,
    parameter integer OP     = 0        // 0 MAXPOOL, 1 UPSAMPLE, 2 CONCAT, 3 ADD
)(
    input  wire        clk,
    input  wire        rstn,
    input  wire        start,
    output reg         busy,
    output reg         done,
    output reg         err,
    output reg  [31:0] cycles,

    input  wire [31:0] a_base,
    input  wire [31:0] b_base,
    input  wire [31:0] y_base,
    input  wire [31:0] ca,          // CONCAT: channels taken from a

    output reg  [31:0] rd_addr,
    output reg         rd_req,
    input  wire [63:0] rd_data,
    input  wire        rd_valid,
    input  wire        rd_err,

    output reg  [31:0] wr_addr,
    output reg  [63:0] wr_data,
    output reg         wr_req,
    input  wire        wr_ack,
    input  wire        wr_err
);

    localparam integer PAD = K / 2;
    localparam integer OW  = (OP == 1) ? (IN_W * 2) : ((IN_W + 2 * PAD - K) / STRIDE + 1);
    localparam integer OH  = (OP == 1) ? (IN_H * 2) : ((IN_H + 2 * PAD - K) / STRIDE + 1);
    localparam integer CV  = C / 8;
    localparam integer NSUB = (OP == 0) ? (K * K) : (OP == 3) ? 2 : 1;

    localparam [2:0] S_IDLE = 3'd0, S_A = 3'd1, S_RD = 3'd2, S_RDW = 3'd3,
                     S_W = 3'd4, S_WA = 3'd5, S_DONE = 3'd6;

    reg [2:0]  st;
    reg [31:0] row, col, cv, sub;
    reg [63:0] best, acc;
    reg [63:0] yv;

    wire [31:0] out_pix = row * OW + col;

    // source pixel for the current sub-index
    wire signed [31:0] sr = (OP == 0) ? (row * STRIDE + (sub / K) - PAD)
                                      : row;
    wire signed [31:0] sc = (OP == 0) ? (col * STRIDE + (sub % K) - PAD)
                                      : col;
    wire inb = (sr >= 0) && (sr < IN_H) && (sc >= 0) && (sc < IN_W);

    // CONCAT: vectors below ca/8 come from a, the rest from b
    wire bside = (OP == 2) && (cv >= (ca / 8));

    wire [31:0] up_pix  = (row / 2) * IN_W + (col / 2);
    wire [31:0] rd_vec  = (OP == 1) ? (up_pix * CV + cv)
                     : (OP == 1) ? 0
                     : (((sr * IN_W) + sc) * CV + cv);

    genvar gi;
    wire [63:0] mx, sm;
    generate
        for (gi = 0; gi < 8; gi = gi + 1) begin : g_lane
            wire signed [7:0] p = best[gi*8 +: 8];
            wire signed [7:0] q = rd_data[gi*8 +: 8];
            assign mx[gi*8 +: 8] = ($signed(p) > $signed(q)) ? p : q;

            wire signed [8:0] t = $signed(acc[gi*8 +: 8]) + $signed(q);
            assign sm[gi*8 +: 8] = (t > 9'sd127)  ? 8'sd127
                                : (t < -9'sd128) ? -8'sd128 : t[7:0];
        end
    endgenerate

    // ---- advance: the single place indices move --------------------------
    task adv;
        begin
            if (cv == CV - 1) begin
                cv <= 0;
                if (col == OW - 1) begin
                    col <= 0;
                    if (row == OH - 1) begin
                        busy <= 1'b0;
                        done <= 1'b1;
                        st   <= S_DONE;
                    end
                    else begin
                        row <= row + 1;
                        sub <= 0;
                        st  <= S_A;
                    end
                end
                else begin
                    col <= col + 1;
                    sub <= 0;
                    st  <= S_A;
                end
            end
            else begin
                cv  <= cv + 1;
                sub <= 0;
                st  <= S_A;
            end
        end
    endtask

    always @(posedge clk) begin
        if (!rstn) begin
            st <= S_IDLE; busy <= 1'b0; done <= 1'b0; err <= 1'b0; cycles <= 0;
            rd_addr <= 0; rd_req <= 0; wr_addr <= 0; wr_data <= 0; wr_req <= 0;
            row <= 0; col <= 0; cv <= 0; sub <= 0;
            best <= 64'h8080808080808080; acc <= 0; yv <= 0;
        end
        else begin
            rd_req <= 1'b0;
            wr_req <= 1'b0;
            if (busy && st != S_DONE)
                cycles <= cycles + 32'd1;

            case (st)
            S_IDLE: begin
                done <= 1'b0;
                if (start) begin
                    busy <= 1'b1; cycles <= 0; err <= 1'b0;
                    row <= 0; col <= 0; cv <= 0; sub <= 0;
                    best <= 64'h8080808080808080;
                    acc  <= 64'd0;
                    st   <= S_A;
                end
            end

            // decide: read another operand, or write the result
            S_A: begin
                if (OP == 0 && !inb) begin
                    // padding tap: contributes -128, no read needed
                    if (sub == NSUB - 1) begin yv <= best; st <= S_W; end
                    else begin sub <= sub + 1; st <= S_A; end
                end
                else begin
                    rd_addr <= (((OP == 2 && bside) || (OP == 3 && sub == 1))
                                ? (b_base >> 3) : (a_base >> 3))
                             + (((OP == 2 && bside)
                                 ? (out_pix * ((C - ca) / 8) + (cv - (ca / 8)))
                                 : rd_vec));
                    rd_req <= 1'b1;
                    st     <= S_RD;
                end
            end

            S_RD: st <= S_RDW;

            S_RDW: begin
                if (rd_err) err <= 1'b1;
                if (rd_valid) begin
                    if (OP == 0) begin
                        best <= mx;
                        if (sub == NSUB - 1) begin
                            yv <= mx;      // mx, not best: best updates on this edge
                            st <= S_W;
                        end
                        else begin sub <= sub + 1; st <= S_A; end
                    end
                    else if (OP == 3) begin
                        if (sub == 0) begin
                            acc <= rd_data;
                            sub <= 1;
                            st  <= S_A;
                        end
                        else begin
                            yv <= sm;
                            st <= S_W;
                        end
                    end
                    else begin
                        yv <= rd_data;
                        st <= S_W;
                    end
                end
            end

            S_W: begin
                wr_addr <= (y_base >> 3) + (out_pix * CV + cv);
                wr_data <= yv;
                wr_req  <= 1'b1;
                st      <= S_WA;
                if (OP == 0) best <= 64'h8080808080808080;
                if (OP == 3) acc  <= 64'd0;
            end

            S_WA: begin
                if (wr_err) err <= 1'b1;
                if (wr_ack) adv;
            end

            S_DONE: begin
                if (!start) done <= 1'b0;
            end

            default: st <= S_IDLE;
            endcase
        end
    end

endmodule
