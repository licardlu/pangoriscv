//=============================================================================
// pangoriscv - RV32IM processor core + native AXI4 SoC (Pango PG2L100H @ 27 MHz)
// Module : tb_branch_predictor    File : tb/unit/tb_branch_predictor.sv
// Rev    : 1.0                    Date : 2026-10-13
// Author : pango_lpenghan
// Brief  : Unit test for branch_predictor: 32-entry direct-mapped BTB with
//          2-bit saturating counters
//=============================================================================

// ---------------------------------------------------------------------------
// tb_branch_predictor -- unit test for rtl/core/branch_predictor.v (the predictor).
//
// Every check prints "ok" or "FAIL <text>"; the runner greps for a leading
// FAIL and for the final TEST_PASS/TEST_FAIL line.
// ---------------------------------------------------------------------------
`timescale 1ns/1ps

module tb_branch_predictor;
    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg [31:0] fetch_pc = 32'd0;
    // Second (prefetch-chain) lookup port used by the decoupled IFU.
    reg [31:0] fetch_pc2 = 32'd0;
    reg        train_valid = 1'b0;
    reg [31:0] train_pc = 32'd0;
    reg        train_control = 1'b0;
    reg        train_uncond = 1'b0;
    reg        train_taken = 1'b0;
    reg [31:0] train_target = 32'd0;
    wire       predict_taken;
    wire [31:0] predict_target;
    wire       predict_taken2;
    wire [31:0] predict_target2;

    integer errors = 0;
    integer checks = 0;

    branch_predictor dut (
        .clk(clk), .rst_n(rst_n),
        .fetch_pc(fetch_pc),
        .predict_taken(predict_taken), .predict_target(predict_target),
        .fetch_pc2(fetch_pc2),
        .predict_taken2(predict_taken2), .predict_target2(predict_target2),
        .train_valid(train_valid), .train_pc(train_pc),
        .train_control(train_control), .train_uncond(train_uncond),
        .train_taken(train_taken), .train_target(train_target)
    );

    always #5 clk = ~clk;

    task fail(input [8*48-1:0] what);
        begin
            errors = errors + 1;
            $display("FAIL %0s", what);
        end
    endtask

    task ok(input [8*48-1:0] what);
        begin
            checks = checks + 1;
            $display("ok   %0s", what);
        end
    endtask

    // one retire-qualified training event
    task train(input [31:0] pc, input ctl, input unc, input taken, input [31:0] tgt);
        begin
            @(negedge clk);
            train_pc = pc; train_control = ctl; train_uncond = unc;
            train_taken = taken; train_target = tgt; train_valid = 1'b1;
            @(posedge clk); #1;
            @(negedge clk);
            train_valid = 1'b0;
        end
    endtask

    task expect_pred(input [31:0] pc, input exp_taken, input [31:0] exp_tgt);
        begin
            fetch_pc = pc; #1;
            if (predict_taken !== exp_taken) begin
                $display("FAIL predict pc=%08x taken=%0b want=%0b", pc, predict_taken, exp_taken);
                errors = errors + 1;
            end else if (exp_taken && predict_target !== exp_tgt) begin
                $display("FAIL predict pc=%08x target=%08x want=%08x", pc, predict_target, exp_tgt);
                errors = errors + 1;
            end else begin
                checks = checks + 1;
                $display("ok   predict pc=%08x taken=%0b target=%08x", pc, predict_taken, predict_target);
            end
        end
    endtask

    // Same lookup on the second port; both ports must be independent.
    task expect_pred2(input [31:0] pc, input exp_taken, input [31:0] exp_tgt);
        begin
            fetch_pc2 = pc; #1;
            if (predict_taken2 !== exp_taken) begin
                $display("FAIL predict2 pc=%08x taken=%0b want=%0b", pc, predict_taken2, exp_taken);
                errors = errors + 1;
            end else if (exp_taken && predict_target2 !== exp_tgt) begin
                $display("FAIL predict2 pc=%08x target=%08x want=%08x", pc, predict_target2, exp_tgt);
                errors = errors + 1;
            end else begin
                checks = checks + 1;
                $display("ok   predict2 pc=%08x taken=%0b target=%08x", pc, predict_taken2, predict_target2);
            end
        end
    endtask

    initial begin
        repeat (3) @(negedge clk);
        rst_n = 1'b1;
        repeat (2) @(negedge clk);
        $display("--- P1 empty table predicts not taken");
        fetch_pc = 32'h0000_0100; #1;
        if (predict_taken !== 1'b0) fail("P1 empty table predicted taken");
        else ok("P1 empty table predicts not taken");

        $display("--- P2 JAL entry: taken with target, no index aliasing");
        train(32'h0000_0100, 1'b1, 1'b1, 1'b1, 32'h0000_0200);
        expect_pred(32'h0000_0100, 1'b1, 32'h0000_0200);   // index 0
        expect_pred(32'h0000_0104, 1'b0, 32'h0000_0000);   // index 1, untouched

        $display("--- P3 2-bit counter: weak not-taken until two taken events");
        train(32'h0000_0040, 1'b1, 1'b0, 1'b1, 32'h0000_0080);   // new  -> 10
        expect_pred(32'h0000_0040, 1'b1, 32'h0000_0080);
        train(32'h0000_0040, 1'b1, 1'b0, 1'b0, 32'h0000_0000);   // 10 -> 01
        expect_pred(32'h0000_0040, 1'b0, 32'h0000_0000);
        train(32'h0000_0040, 1'b1, 1'b0, 1'b0, 32'h0000_0000);   // 01 -> 00
        expect_pred(32'h0000_0040, 1'b0, 32'h0000_0000);
        train(32'h0000_0040, 1'b1, 1'b0, 1'b1, 32'h0000_0080);   // 00 -> 01
        expect_pred(32'h0000_0040, 1'b0, 32'h0000_0000);
        train(32'h0000_0040, 1'b1, 1'b0, 1'b1, 32'h0000_0080);   // 01 -> 10
        expect_pred(32'h0000_0040, 1'b1, 32'h0000_0080);

        $display("--- P4 same index, different tag: replace, never alias");
        train(32'h0000_0010, 1'b1, 1'b0, 1'b1, 32'h1111_0000);   // index 4
        expect_pred(32'h0000_0010, 1'b1, 32'h1111_0000);
        train(32'h0000_0110, 1'b1, 1'b0, 1'b1, 32'h2222_0000);   // index 4 as well
        expect_pred(32'h0000_0010, 1'b0, 32'h0000_0000);        // old tag must not survive
        expect_pred(32'h0000_0110, 1'b1, 32'h2222_0000);
        train(32'h0000_0010, 1'b1, 1'b0, 1'b1, 32'h3333_0000);   // and back again
        expect_pred(32'h0000_0010, 1'b1, 32'h3333_0000);
        expect_pred(32'h0000_0110, 1'b0, 32'h0000_0000);

        $display("--- P5 JALR target change is retrained");
        train(32'h0000_0200, 1'b1, 1'b1, 1'b1, 32'hAAAA_0000);
        expect_pred(32'h0000_0200, 1'b1, 32'hAAAA_0000);
        train(32'h0000_0200, 1'b1, 1'b1, 1'b1, 32'hBBBB_0000);
        expect_pred(32'h0000_0200, 1'b1, 32'hBBBB_0000);

        $display("--- P6 saturating counter does not wrap");
        train(32'h0000_0300, 1'b1, 1'b0, 1'b1, 32'h0000_0400);   // 10
        train(32'h0000_0300, 1'b1, 1'b0, 1'b1, 32'h0000_0400);   // 11
        train(32'h0000_0300, 1'b1, 1'b0, 1'b1, 32'h0000_0400);   // 11 (saturated)
        train(32'h0000_0300, 1'b1, 1'b0, 1'b1, 32'h0000_0400);   // 11
        train(32'h0000_0300, 1'b1, 1'b0, 1'b0, 32'h0000_0000);   // 11 -> 10
        expect_pred(32'h0000_0300, 1'b1, 32'h0000_0400);
        train(32'h0000_0300, 1'b1, 1'b0, 1'b0, 32'h0000_0000);   // 10 -> 01
        expect_pred(32'h0000_0300, 1'b0, 32'h0000_0000);

        $display("--- P7 a non-control retire never trains the table");
        train(32'h0000_0500, 1'b0, 1'b0, 1'b1, 32'h0000_0600);
        expect_pred(32'h0000_0500, 1'b0, 32'h0000_0000);

        $display("--- P8 reset empties the table again");
        @(negedge clk); rst_n = 1'b0; @(posedge clk); #1; @(negedge clk); rst_n = 1'b1;
        expect_pred(32'h0000_0100, 1'b0, 32'h0000_0000);
        expect_pred(32'h0000_0010, 1'b0, 32'h0000_0000);

        $display("--- P9 second lookup port (prefetch chain)");
        // The decoupled IFU looks up the next-to-prefetch PC while the
        // architectural PC is still being served by the first port, so both
        // ports must resolve independently against the same table.
        train(32'h0000_0100, 1'b1, 1'b1, 1'b1, 32'h0000_0200);   // index 0, unconditional
        train(32'h0000_0040, 1'b1, 1'b0, 1'b1, 32'h0000_0080);   // index 16, conditional taken
        expect_pred (32'h0000_0100, 1'b1, 32'h0000_0200);        // port 1 -> index 0
        expect_pred2(32'h0000_0040, 1'b1, 32'h0000_0080);        // port 2 -> index 16, port 1 untouched
        expect_pred2(32'h0000_0100, 1'b1, 32'h0000_0200);        // both ports may read one entry
        expect_pred (32'h0000_0040, 1'b1, 32'h0000_0080);        // port 1 -> index 16
        expect_pred2(32'h0000_0300, 1'b0, 32'h0000_0000);        // untrained entry on port 2
        expect_pred (32'h0000_0100, 1'b1, 32'h0000_0200);        // port 1 still resolves

        if (errors == 0) $display("TEST_PASS BRANCH_PREDICTOR checks=%0d", checks);
        else             $display("TEST_FAIL BRANCH_PREDICTOR errors=%0d checks=%0d", errors, checks);
        $finish;
    end

    initial begin
        #200000;
        $display("FAIL timeout");
        $display("TEST_FAIL BRANCH_PREDICTOR timeout");
        $finish;
    end
endmodule
