// tb_conv3x3 -- drives conv3x3_core with vectors from gen_vectors.py and
// compares every output byte against the bit-exact reference.
`timescale 1ns/1ps

module tb_conv3x3;

    parameter integer CIN  = 8;
    parameter integer COUT = 8;
    localparam integer KS  = (CIN * 9) / 8;

    reg                 clk = 0;
    reg                 rstn = 0;
    reg                 start = 0;
    reg  [COUT*32-1:0]  bias_bus = 0;
    reg  [COUT*32-1:0]  m_bus = 0;
    reg  [4:0]          s_shift = 5'd15;
    reg                 valid = 0;
    reg  [63:0]         a_bus = 0;
    reg  [COUT*64-1:0]  w_bus = 0;
    wire                y_valid;
    wire [COUT*8-1:0]   y_bus;

    conv3x3_core #(.CIN(CIN), .COUT(COUT)) dut (
        .clk(clk), .rstn(rstn),
        .start(start), .bias_bus(bias_bus), .m_bus(m_bus), .s_shift(s_shift),
        .valid(valid), .a_bus(a_bus), .w_bus(w_bus),
        .y_valid(y_valid), .y_bus(y_bus)
    );

    always #5 clk = ~clk;

    integer fb, fm, fs, fg;
    integer cin_f, cout_f, s_f, npix, ks_f;
    integer i, p, k, errs, nbytes, to;
    integer bval, mval;
    reg [63:0]        a_tmp;
    reg [COUT*64-1:0] w_tmp;
    reg [COUT*8-1:0]  gold;
    reg [COUT*8-1:0]  seen;

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("tb_conv3x3.vcd");
            $dumpvars(0, tb_conv3x3);
        end

        fb = $fopen("vec/bias.txt", "r");
        fm = $fopen("vec/m.txt", "r");
        fs = $fopen("vec/stim.txt", "r");
        fg = $fopen("vec/gold.txt", "r");
        if (fb == 0 || fm == 0 || fs == 0 || fg == 0) begin
            $display("FATAL: cannot open vector files (run gen_vectors.py first)");
            $finish;
        end

        // cfg is read through a separate open
        begin : cfg_read
            integer fc;
            fc = $fopen("vec/cfg.txt", "r");
            $fscanf(fc, "%d %d %d %d %d", cin_f, cout_f, s_f, npix, ks_f);
            $fclose(fc);
            $display("cfg: CIN=%0d COUT=%0d S=%0d NPIX=%0d KS=%0d",
                     cin_f, cout_f, s_f, npix, ks_f);
            if (cin_f != CIN || cout_f != COUT) begin
                $display("FATAL: vector CIN/COUT does not match RTL parameters");
                $finish;
            end
        end

        for (i = 0; i < COUT; i = i + 1) begin
            $fscanf(fb, "%d", bval);
            bias_bus[i*32 +: 32] = bval[31:0];
        end
        for (i = 0; i < COUT; i = i + 1) begin
            $fscanf(fm, "%d", mval);
            m_bus[i*32 +: 32] = mval[31:0];
        end
        s_shift = s_f[4:0];

        rstn = 0;
        repeat (3) @(negedge clk);
        rstn = 1;
        @(negedge clk);

        errs   = 0;
        nbytes = 0;

        for (p = 0; p < npix; p = p + 1) begin
            // start pulse
            start = 1;
            @(negedge clk);
            start = 0;

            for (k = 0; k < KS; k = k + 1) begin
                $fscanf(fs, "%h %h", a_tmp, w_tmp);
                a_bus = a_tmp;
                w_bus = w_tmp;
                valid = 1;
                @(negedge clk);
            end
            valid = 0;

            // wait for the result, with a timeout so a hang is visible
            to = 0;
            while (y_valid !== 1'b1 && to < 50) begin
                @(negedge clk);
                to = to + 1;
            end
            if (y_valid !== 1'b1) begin
                $display("FATAL: pixel %0d timed out waiting for y_valid", p);
                errs = errs + 1;
            end

            $fscanf(fg, "%h", gold);
            seen = y_bus;
            if (seen !== gold) begin
                if (errs < 8)
                    $display("MISMATCH pixel %0d: got %0h expected %0h",
                             p, seen, gold);
                errs = errs + 1;
            end
            @(negedge clk);
        end

        $fclose(fb); $fclose(fm); $fclose(fs); $fclose(fg);

        nbytes = npix * COUT;
        if (errs == 0)
            $display("PASS: %0d pixels, %0d output bytes, all bit-exact", npix, nbytes);
        else
            $display("FAIL: %0d mismatched pixels out of %0d", errs, npix);
        $finish;
    end

endmodule
