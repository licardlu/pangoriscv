// tb_conv3x3_layer -- whole-tensor comparison for one real Lite-A layer.
//
// Preloads the input and weight tensors over the byte-wide load port, runs the
// layer once, then reads the output tensor back and compares every byte with
// the integer reference.  This is the check that catches dropped rows, repeated
// rows, and padding errors, which a per-pixel core test cannot see.
`timescale 1ns/1ps

module tb_conv3x3_layer;

    parameter integer CIN  = 8;
    parameter integer COUT = 16;
    parameter integer W    = 64;
    parameter integer H    = 64;
    localparam integer INSZ = W * H * CIN;
    localparam integer WSZ  = COUT * CIN * 9;
    localparam integer OSZ  = W * H * COUT;

    reg         clk = 0;
    reg         rstn = 0;
    reg         start = 0;
    reg  [COUT*32-1:0] bias_bus = 0;
    reg  [COUT*32-1:0] m_bus = 0;
    reg  [4:0]  s_shift = 5'd15;
    reg         ld_en = 0;
    reg         ld_sel = 0;
    reg  [31:0] ld_addr = 0;
    reg  [7:0]  ld_data = 0;
    reg  [31:0] rd_addr = 0;
    wire [7:0]  rd_data;
    wire        busy, done;
    wire [31:0] cycles;

    conv3x3_layer #(.CIN(CIN), .COUT(COUT), .W(W), .H(H)) dut (
        .clk(clk), .rstn(rstn), .start(start),
        .bias_bus(bias_bus), .m_bus(m_bus), .s_shift(s_shift),
        .ld_en(ld_en), .ld_sel(ld_sel), .ld_addr(ld_addr), .ld_data(ld_data),
        .rd_addr(rd_addr), .rd_data(rd_data),
        .busy(busy), .done(done), .cycles(cycles)
    );

    always #5 clk = ~clk;

    integer f, i, v, cin_f, cout_f, w_f, h_f, s_f;
    integer errors, checked, timeout;
    reg [7:0] gold;

    initial begin
        f = $fopen("layer/cfg.txt", "r");
        if (f == 0) begin
            $display("FATAL: layer/cfg.txt missing (run gen_layer_vectors.py)");
            $finish;
        end
        $fscanf(f, "%d %d %d %d %d", cin_f, cout_f, w_f, h_f, s_f);
        $fclose(f);
        if (cin_f != CIN || cout_f != COUT || w_f != W || h_f != H) begin
            $display("FATAL: vector shape %0dx%0d cin=%0d cout=%0d does not match RTL",
                     h_f, w_f, cin_f, cout_f);
            $finish;
        end

        f = $fopen("layer/bias.txt", "r");
        for (i = 0; i < COUT; i = i + 1) begin
            $fscanf(f, "%d", v);
            bias_bus[i*32 +: 32] = v[31:0];
        end
        $fclose(f);
        f = $fopen("layer/m.txt", "r");
        for (i = 0; i < COUT; i = i + 1) begin
            $fscanf(f, "%d", v);
            m_bus[i*32 +: 32] = v[31:0];
        end
        $fclose(f);
        s_shift = s_f[4:0];

        rstn = 0;
        repeat (3) @(negedge clk);
        rstn = 1;

        // ---- preload input tensor -----------------------------------------
        f = $fopen("layer/in.hex", "r");
        for (i = 0; i < INSZ; i = i + 1) begin
            $fscanf(f, "%h", v);
            @(negedge clk);
            ld_en = 1; ld_sel = 0; ld_addr = i; ld_data = v[7:0];
        end
        $fclose(f);

        // ---- preload weights ----------------------------------------------
        f = $fopen("layer/w.hex", "r");
        for (i = 0; i < WSZ; i = i + 1) begin
            $fscanf(f, "%h", v);
            @(negedge clk);
            ld_en = 1; ld_sel = 1; ld_addr = i; ld_data = v[7:0];
        end
        $fclose(f);
        @(negedge clk);
        ld_en = 0;

        // ---- run ------------------------------------------------------------
        @(negedge clk);
        start = 1;
        @(negedge clk);
        start = 0;

        timeout = 0;
        while (done !== 1'b1 && timeout < 900000) begin
            @(negedge clk);
            timeout = timeout + 1;
        end
        if (done !== 1'b1) begin
            $display("FATAL: layer did not finish (timeout)");
            $finish;
        end
        $display("layer done: %0d cycles for %0d pixels (%0d MACs/cycle effective)",
                 cycles, W*H, (W*H*COUT*CIN*9)/(cycles+1));

        // ---- compare --------------------------------------------------------
        f = $fopen("layer/gold.hex", "r");
        errors = 0; checked = 0;
        for (i = 0; i < OSZ; i = i + 1) begin
            $fscanf(f, "%h", gold);
            rd_addr = i;
            #1;
            checked = checked + 1;
            if (rd_data !== gold) begin
                if (errors < 10)
                    $display("MISMATCH out[%0d] (y=%0d x=%0d oc=%0d): got %02h want %02h",
                             i, i/(W*COUT), (i/COUT)%W, i%COUT, rd_data, gold);
                errors = errors + 1;
            end
        end
        $fclose(f);

        if (errors == 0)
            $display("PASS: whole layer, %0d bytes identical to the integer reference", checked);
        else
            $display("FAIL: %0d of %0d bytes differ", errors, checked);
        $finish;
    end

endmodule
