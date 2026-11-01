// tb_band_engine -- byte-exact check of conv_band_engine against the Python
// integer reference.
//
// The testbench models DDR as a flat 64-bit word array with one-cycle read
// latency and an acknowledged write port, which is the contract the engine was
// written against.  Vectors and parameters come from
// scripts/gen_band_vectors.py; the expected output is computed there with the
// same rounding rule the RTL implements, so a mismatch is always an RTL bug.
//
// A missing vector file is fatal on purpose: an earlier suite printed "verified"
// when $fopen failed and reported success on zero comparisons.
`timescale 1ns/1ps

module tb_band_engine;

`include "tb_params.vh"

    reg clk = 0, rstn = 0;
    always #5 clk = ~clk;

    reg         start = 0;
    wire        busy, done, err;
    wire [31:0] cycles;

    wire [31:0] rd_addr_w;
    wire        rd_req_w;
    wire [63:0] rd_data_w;
    wire        rd_valid_w;
    wire        rd_err_w = 1'b0;

    wire [31:0] wr_addr_w;
    wire [63:0] wr_data_w;
    wire        wr_req_w;
    reg         wr_ack_w;

    conv_band_engine #(
        .CINPAD(P_CINPAD), .COUT(P_COUT), .IN_W(P_IN_W), .IN_H(P_IN_H),
        .K(P_K), .STRIDE(P_STRIDE), .ACT(P_ACT), .TR(P_TR), .PADP(P_PAD), .SHIFT(15)
    ) dut (
        .clk(clk), .rstn(rstn), .start(start), .busy(busy), .done(done),
        .err(err), .cycles(cycles),
        .a_base(P_A_BASE), .w_base(P_W_BASE), .q_base(P_Q_BASE), .t_base(P_T_BASE), .y_base(P_Y_BASE),
        .rd_addr(rd_addr_w), .rd_req(rd_req_w), .rd_data(rd_data_w),
        .rd_valid(rd_valid_w), .rd_err(rd_err_w),
        .wr_addr(wr_addr_w), .wr_data(wr_data_w), .wr_req(wr_req_w),
        .wr_ack(wr_ack_w), .wr_err(1'b0)
    );

    // ---- DDR model -------------------------------------------------------
    reg [63:0] mem [0:P_MEMW-1];
    reg [63:0] mem_dummy;
    integer k;
    integer maxwr = 0;
    integer minwr = 100000000;
    integer nwr = 0;
    reg        rd_valid_r;
    reg [63:0] rd_data_r;

    always @(posedge clk) begin
        rd_valid_r <= rd_req_w;
        rd_data_r  <= mem[rd_addr_w];
    end
    assign rd_data_w  = rd_data_r;
    assign rd_valid_w = rd_valid_r;

    always @(posedge clk) begin
        if (!rstn)
            wr_ack_w <= 1'b0;
        else begin
            wr_ack_w <= 1'b0;
            if (wr_req_w && !wr_ack_w) begin
                mem[wr_addr_w] <= wr_data_w;
                wr_ack_w <= 1'b1;
                nwr = nwr + 1;
                if (wr_addr_w > maxwr) maxwr = wr_addr_w;
                if (wr_addr_w < minwr) minwr = wr_addr_w;
            end
        end
    end

    // progress trace: a stuck FSM is the most likely failure, so show where
    integer pc = 0;
    reg one = 1'b0;
    always @(posedge clk) begin
        if (dut.st == 9 && !one) begin
            one <= 1'b1;
            $display("FIRSTWR y_lat=%016x y_word=%016x mac=%08x%08x bq=%016x wq0=%016x m0=%08x b0=%08x ti=%0d",
                     dut.y_lat, dut.y_word, dut.mac_sum[63:32], dut.mac_sum[31:0],
                     dut.bband_q, dut.wq0, dut.mval[0], dut.bias_r[0], dut.ti);
        end
    end
    always @(posedge clk) begin
        pc = pc + 1;
        if ((dut.st == 4 || dut.st == 3) && pc < 400)
            $display("FILL cyc=%0d st=%0d rreq=%b rval=%b raddr=%0d fr=%0d fx=%0d fcs=%0d",
                     cycles, dut.st, rd_req_w, rd_valid_w, rd_addr_w, dut.fr, dut.fx, dut.fcs);
        if (pc % 50000 == 0)
            $display("PROG cyc=%0d st=%0d start=%b rstn=%b busy=%b done=%b fr=%0d fx=%0d fcs=%0d wld=%0d/%0d ti=%0d r=%0d c=%0d iss=%0d k=%0d/%0d/%0d rreq=%b rval=%b",
                     cycles, dut.st, start, rstn, busy, done, dut.fr, dut.fx, dut.fcs, dut.wld_o, dut.wld_w,
                     dut.ti, dut.row, dut.col, dut.issue, dut.kyi, dut.kxi, dut.csi,
                     rd_req_w, rd_valid_w);
    end

    // ---- expected --------------------------------------------------------
    reg [63:0] exp_mem [0:P_NOUT-1];
    integer i;
    integer errors;
    reg [63:0] got;

    integer fd, rc;

    initial begin
        for (k = 0; k < P_MEMW; k = k + 1) mem[k] = 64'd0;
        for (k = 0; k < P_NOUT; k = k + 1) exp_mem[k] = 64'd0;

        // $readmemh is orders of magnitude faster than a $fscanf loop.  It is
        // only trusted after a non-zero check, because a silently failed load
        // leaves zeros and a zeros-vs-zeros comparison "passes".
        $readmemh(`DDR_FILE, mem);
        $readmemh(`EXP_FILE, exp_mem);
        if (mem[0] === 64'd0 && exp_mem[0] === 64'd0)
            $fatal(1, "vector load failed: both arrays are zero");
        if (exp_mem[0] === 64'hx && exp_mem[0] === 64'hx)
            $fatal(1, "expected array is X: load failed");

        $display("LOADED mem[0]=%016x exp[0]=%016x exp[last]=%016x",
                 mem[0], exp_mem[0], exp_mem[P_NOUT-1]);

        repeat (4) @(posedge clk);
        rstn  = 1;
        repeat (2) @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;

        // watch for the engine stalling without finishing
        fork : wait_done
            begin
                wait (done === 1'b1);
                disable wait_done;
            end
            begin
                repeat (P_OH * P_OW * P_COUT * 20 + 5000) @(posedge clk);
                $display("TIMEOUT: st=%0d qi=%0d ti=%0d fr=%0d fx=%0d band=%0d ti2=%0d row=%0d col=%0d iss=%0d wld=%0d/%0d bad=%0d cycles=%0d", dut.bad_st, dut.st, dut.q_i, dut.t_i, dut.fr, dut.fx, dut.band_i, dut.ti, dut.row, dut.col, dut.issue, dut.wld_o, dut.wld_w, dut.bad_st, cycles);
                errors = errors + 1;
                disable wait_done;
            end
        join

        errors = 0;
        if (err) begin
            $display("FAIL: engine asserted err");
            errors = errors + 1;
        end

        $display("WRITES n=%0d min=%0d max=%0d  y0=%0d mem[y0]=%016x mem[0]=%016x",
                 nwr, minwr, maxwr, P_Y_BASE >> 3, mem[P_Y_BASE >> 3], mem[0]);
        for (i = 0; i < P_NOUT; i = i + 1) begin
            got = mem[(P_Y_BASE >> 3) + i];
            if (got !== exp_mem[i]) begin
                errors = errors + 1;
                if (errors <= 8)
                    $display("MISMATCH word %0d: got %016x exp %016x", i, got, exp_mem[i]);
            end
        end

        if (errors == 0)
            $display("BAND-ENGINE-PASS  %0d words  cycles=%0d", P_NOUT, cycles);
        else
            $display("BAND-ENGINE-FAIL  %0d errors of %0d words", errors, P_NOUT);
        $finish;
    end

endmodule
