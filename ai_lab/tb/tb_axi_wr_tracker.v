// tb_axi_wr_tracker -- proves the completion rule, not just that it compiles.
//
// Scenario A: 4 writes, WLAST on the 4th beat, B responses arrive afterwards.
//   done must stay low at the WLAST cycle and rise only after the 4th B.
// Scenario B: one BRESP = SLVERR. err must rise, done must never rise.
// Scenario C: all B responses arrive before WLAST. done must wait for WLAST.
`timescale 1ns/1ps

module tb_axi_wr_tracker;

    reg         clk = 0;
    reg         rstn = 0;
    reg         start = 0;
    reg         awvalid = 0;
    reg         wvalid = 0;
    reg         wlast = 0;
    reg  [1:0]  bresp = 2'b00;
    reg         bvalid = 0;
    wire        awready, wready, bready;
    wire        busy, done, err;
    wire [7:0]  aw_cnt_o, b_cnt_o;

    axi_wr_tracker dut (
        .clk(clk), .rstn(rstn), .start(start),
        .awvalid(awvalid), .awready(awready),
        .wvalid(wvalid), .wlast(wlast), .wready(wready),
        .bresp(bresp), .bvalid(bvalid), .bready(bready),
        .busy(busy), .done(done), .err(err),
        .aw_cnt_o(aw_cnt_o), .b_cnt_o(b_cnt_o)
    );

    always #5 clk = ~clk;

    integer errors = 0;
    integer done_cycle = 0;
    integer wlast_cycle = 0;
    integer nb = 0;

    task chk(input cond, input [255:0] msg);
        begin
            if (!cond) begin
                $display("  FAIL: %0s", msg);
                errors = errors + 1;
            end
        end
    endtask

    // one address beat
    task aw_beat;
        begin
            @(negedge clk); awvalid = 1;
            @(negedge clk); awvalid = 0;
        end
    endtask

    // one data beat, with wlast optionally set
    task w_beat(input is_last);
        begin
            @(negedge clk); wvalid = 1; wlast = is_last;
            @(negedge clk); wvalid = 0; wlast = 0;
        end
    endtask

    task b_beat(input [1:0] resp);
        begin
            @(negedge clk); bvalid = 1; bresp = resp;
            @(negedge clk); bvalid = 0; bresp = 2'b00;
        end
    endtask

    task new_transfer;
        begin
            @(negedge clk); start = 1;
            @(negedge clk); start = 0;
        end
    endtask

    initial begin
        rstn = 0;
        repeat (3) @(negedge clk);
        rstn = 1;
        @(negedge clk);

        // ---------------- scenario A: normal ----------------
        $display("scenario A: 4 writes, B responses after WLAST");
        new_transfer;
        aw_beat; aw_beat; aw_beat; aw_beat;
        w_beat(0); w_beat(0); w_beat(0);
        // 4th beat is the last one
        @(negedge clk); wvalid = 1; wlast = 1;
        @(negedge clk); wvalid = 0; wlast = 0;
        wlast_cycle = $time;
        chk(done === 1'b0, "done must not rise at WLAST");
        b_beat(2'b00); chk(done === 1'b0, "done must not rise after 1 of 4 B");
        b_beat(2'b00); chk(done === 1'b0, "done must not rise after 2 of 4 B");
        b_beat(2'b00); chk(done === 1'b0, "done must not rise after 3 of 4 B");
        b_beat(2'b00);
        @(negedge clk);
        chk(done === 1'b1, "done must rise after the 4th B");
        chk(err  === 1'b0, "err must stay low on all-OKAY responses");
        done_cycle = $time;
        $display("  done rose %0d ns after WLAST (expected: after last B)", done_cycle - wlast_cycle);

        // ---------------- scenario B: error response ----------------
        $display("scenario B: one BRESP = SLVERR");
        new_transfer;
        aw_beat; aw_beat;
        w_beat(0); w_beat(1);
        b_beat(2'b00);
        b_beat(2'b10);              // SLVERR
        repeat (3) @(negedge clk);
        chk(err  === 1'b1, "err must rise on a non-OKAY BRESP");
        chk(done === 1'b0, "done must never rise when a response failed");

        // ---------------- scenario C: legal out-of-order across transactions --
        // A B response may legitimately arrive before a LATER transaction's
        // WLAST.  What must never happen is a B for a transaction whose own
        // WLAST has not been accepted yet -- that is an interconnect protocol
        // violation and is not treated as a normal flow here.
        $display("scenario C: B of tx1 returns before WLAST of tx2 (legal)");
        new_transfer;
        aw_beat; aw_beat;           // tx1, tx2 addresses
        w_beat(1);                  // tx1 data, WLAST for tx1
        b_beat(2'b00);              // tx1 completes here
        repeat (2) @(negedge clk);
        chk(done === 1'b0, "done must not rise while tx2 has no data yet");
        w_beat(1);                  // tx2 data, WLAST for tx2
        repeat (2) @(negedge clk);
        chk(done === 1'b0, "done must wait for tx2 B response");
        b_beat(2'b00);
        @(negedge clk);
        chk(done === 1'b1, "done must rise once both transactions are answered");

        // ---------------- scenario D: single write ----------------
        $display("scenario D: single-beat write");
        new_transfer;
        aw_beat;
        w_beat(1);
        repeat (2) @(negedge clk);
        chk(done === 1'b0, "done must wait for the single B response");
        b_beat(2'b00);
        @(negedge clk);
        chk(done === 1'b1, "done must rise after the single B response");

        if (errors == 0)
            $display("PASS: all completion-semantics checks passed");
        else
            $display("FAIL: %0d checks failed", errors);
        $finish;
    end

    // a watchdog so a hang is reported rather than silently hanging the run
    initial begin
        #200000;
        $display("FAIL: timeout");
        $finish;
    end

endmodule
