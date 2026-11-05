// axi_wr_tracker -- completion semantics for an AXI4 write stream.
//
// The rule this module exists to enforce:
//   done may only rise after WLAST has been accepted AND every write address
//   issued has been answered by a BRESP, and all of those responses were OKAY.
//
// Observing WLAST alone is not completion: at that instant the last data beat
// has merely been handed to the interconnect.  The transaction is not durable
// until its B response returns.  A non-OKAY BRESP must raise err and must not
// raise done.
//
// The tracker also handles responses that arrive out of order with respect to
// WLAST: done waits for the counts to match, whichever happens last.
`timescale 1ns/1ps

module axi_wr_tracker #(
    parameter integer CNT_W = 8
)(
    input  wire             clk,
    input  wire             rstn,
    input  wire             start,       // clears counters for a new transfer

    input  wire             awvalid,
    output wire             awready,
    input  wire             wvalid,
    input  wire             wlast,
    output wire             wready,
    input  wire [1:0]       bresp,       // 2'b00 = OKAY
    input  wire             bvalid,
    output wire             bready,

    output wire             busy,
    output reg              done,
    output reg              err,
    output wire [CNT_W-1:0] aw_cnt_o,
    output wire [CNT_W-1:0] b_cnt_o
);

    reg [CNT_W-1:0] aw_cnt;
    reg [CNT_W-1:0] b_cnt;
    reg             wlast_seen;

    assign awready = 1'b1;
    assign wready  = 1'b1;
    assign bready  = 1'b1;

    assign aw_cnt_o = aw_cnt;
    assign b_cnt_o  = b_cnt;

    wire aw_hit = awvalid && awready;
    wire w_hit  = wvalid  && wready;
    wire b_hit  = bvalid  && bready;

    always @(posedge clk) begin
        if (!rstn || start) begin
            aw_cnt     <= {CNT_W{1'b0}};
            b_cnt      <= {CNT_W{1'b0}};
            wlast_seen <= 1'b0;
            done       <= 1'b0;
            err        <= 1'b0;
        end
        else begin
            if (aw_hit && aw_cnt != {CNT_W{1'b1}})
                aw_cnt <= aw_cnt + 1'b1;

            if (b_hit) begin
                if (b_cnt != {CNT_W{1'b1}})
                    b_cnt <= b_cnt + 1'b1;
                if (bresp != 2'b00)
                    err <= 1'b1;
            end

            if (w_hit && wlast)
                wlast_seen <= 1'b1;

            // completion: every issued address has been answered, the last data
            // beat has been accepted, and no response reported an error
            if (wlast_seen && (b_cnt == aw_cnt) && (aw_cnt != {CNT_W{1'b0}}) && !err && !done)
                done <= 1'b1;
        end
    end

    assign busy = ((aw_cnt != {CNT_W{1'b0}}) || wlast_seen) && !done && !err;

endmodule
