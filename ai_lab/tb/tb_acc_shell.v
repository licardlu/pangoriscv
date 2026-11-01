// tb_acc_shell -- the closed loop the whole project hangs on:
//   CPU writes parameters -> shell reads input+weights from "DDR" -> conv runs
//   -> result written back -> all B responses OK -> CPU reads it and compares.
//
// The memory model is byte-per-word during bring-up, matching the shell's
// 4-byte stride. It returns an error B when inject_err is set, so the failure
// path is exercised too.
`timescale 1ns/1ps

module tb_acc_shell;

    parameter integer CIN  = 8;
    parameter integer COUT = 8;
    parameter integer W    = 8;
    parameter integer H    = 8;
    localparam integer INSZ = W * H * CIN;
    localparam integer WSZ  = COUT * CIN * 9;
    localparam integer OSZ  = W * H * COUT;

    localparam [31:0] A_SRC_IN = 32'h0000_0000;
    localparam [31:0] A_SRC_W  = 32'h0000_0800;
    // The weight region spans words [A_SRC_W/4 , A_SRC_W/4 + WSZ).  Bias and M
    // must sit clear of it: placing them at 0x0C00/0x0E00 silently overwrote
    // 16 weight bytes and corrupted 109 outputs.
    localparam [31:0] A_SRC_B  = 32'h0000_2000;
    localparam [31:0] A_SRC_M  = 32'h0000_2400;
    localparam [31:0] A_DST    = 32'h0000_3000;

    reg clk = 0, rstn = 0;
    always #5 clk = ~clk;

    // ---- AXI-Lite slave side (drive by the "CPU") ----
    reg  [7:0]  s_awaddr = 0;
    reg         s_awvalid = 0;
    reg  [31:0] s_wdata = 0;
    reg         s_wvalid = 0;
    wire        s_awready, s_wready, s_bvalid, s_rvalid;
    wire [1:0]  s_bresp, s_rresp;
    wire [31:0] s_rdata;
    reg         s_bready = 1, s_rready = 1;
    reg  [7:0]  s_araddr = 0;
    reg         s_arvalid = 0;

    // ---- AXI master side (memory model) ----
    wire [31:0] m_araddr, m_awaddr, m_wdata;
    wire        m_arvalid, m_awvalid, m_wvalid, m_wlast, m_bready, m_rready;
    wire [7:0]  m_arlen, m_awlen;
    reg  [31:0] m_rdata = 0;
    reg         m_rvalid = 0;
    reg  [1:0]  m_rresp = 0, m_bresp = 0;
    reg         m_bvalid = 0;
    wire        m_arready, m_awready, m_wready;
    assign m_arready = 1'b1;
    assign m_awready = 1'b1;
    assign m_wready  = 1'b1;

    wire busy, done, err;

    acc_shell #(.CIN(CIN), .COUT(COUT), .W(W), .H(H)) dut (
        .clk(clk), .rstn(rstn),
        .s_awaddr(s_awaddr), .s_awvalid(s_awvalid), .s_awready(s_awready),
        .s_wdata(s_wdata), .s_wvalid(s_wvalid), .s_wready(s_wready),
        .s_bresp(s_bresp), .s_bvalid(s_bvalid), .s_bready(s_bready),
        .s_araddr(s_araddr), .s_arvalid(s_arvalid), .s_arready(s_arready),
        .s_rdata(s_rdata), .s_rresp(s_rresp), .s_rvalid(s_rvalid), .s_rready(s_rready),
        .m_araddr(m_araddr), .m_arvalid(m_arvalid), .m_arready(m_arready), .m_arlen(m_arlen),
        .m_rdata(m_rdata), .m_rvalid(m_rvalid), .m_rready(m_rready), .m_rresp(m_rresp),
        .m_awaddr(m_awaddr), .m_awvalid(m_awvalid), .m_awready(m_awready), .m_awlen(m_awlen),
        .m_wdata(m_wdata), .m_wvalid(m_wvalid), .m_wlast(m_wlast), .m_wready(m_wready),
        .m_bresp(m_bresp), .m_bvalid(m_bvalid), .m_bready(m_bready),
        .busy(busy), .done(done), .err(err)
    );

    // ---- memory model ----
    reg [31:0] mem [0:8191];
    reg        inject_err = 0;
    reg        err_sent = 0;

    always @(posedge clk) begin
        m_rvalid <= 1'b0;
        if (m_arvalid && m_arready) begin
            m_rdata  <= mem[m_araddr[14:2]];
            m_rresp  <= 2'b00;
            m_rvalid <= 1'b1;
        end
        if (m_awvalid && m_awready && m_wvalid && m_wready) begin
            mem[m_awaddr[14:2]] <= {24'd0, m_wdata[7:0]};
            m_bvalid <= 1'b1;
            if (inject_err && !err_sent) begin
                m_bresp  <= 2'b10;       // SLVERR
                err_sent <= 1'b1;
            end
            else
                m_bresp <= 2'b00;
        end
        else if (m_bvalid && m_bready)
            m_bvalid <= 1'b0;
    end

    // ---- CPU helpers ----
    task axil_w(input [7:0] a, input [31:0] d);
        begin
            @(negedge clk); s_awaddr = a; s_wdata = d; s_awvalid = 1; s_wvalid = 1;
            @(negedge clk); s_awvalid = 0; s_wvalid = 0;
            @(negedge clk);
        end
    endtask

    task axil_r(input [7:0] a, output [31:0] d);
        begin
            @(negedge clk); s_araddr = a; s_arvalid = 1;
            @(negedge clk); s_arvalid = 0;
            while (!s_rvalid) @(negedge clk);
            d = s_rdata;
            @(negedge clk);
        end
    endtask

    integer f, i, v, errors, checked, guard;
    reg [7:0] gold;
    reg [31:0] st;

    task run_once(input do_inject, output ok, output saw_err);
        begin
            inject_err = do_inject; err_sent = 0;
            axil_w(8'h08, A_SRC_IN);
            axil_w(8'h0C, A_SRC_W);
            axil_w(8'h18, A_SRC_B);
            axil_w(8'h1C, A_SRC_M);
            axil_w(8'h10, A_DST);
            axil_w(8'h00, 32'd1);
            guard = 0;
            st = 0;
            while (!st[1] && !st[2] && guard < 200000) begin
                axil_r(8'h04, st);
                guard = guard + 1;
            end
            ok      = st[1];
            saw_err = st[2];
        end
    endtask

    initial begin
        // A missing vector file must fail the test.  Treating fscanf(0) as a
        // stream of X values previously let the test print "verified" with no
        // input, weights or golden reference loaded at all.
        f = $fopen("layer/in.hex", "r");
        if (f == 0) $fatal(1, "cannot open layer/in.hex; run from conv_int8/");
        for (i = 0; i < INSZ; i = i + 1) begin
            $fscanf(f, "%h", v);
            mem[(A_SRC_IN >> 2) + i] = {24'd0, v[7:0]};
        end
        $fclose(f);
        f = $fopen("layer/w.hex", "r");
        if (f == 0) $fatal(1, "cannot open layer/w.hex; run from conv_int8/");
        for (i = 0; i < WSZ; i = i + 1) begin
            $fscanf(f, "%h", v);
            mem[(A_SRC_W >> 2) + i] = {24'd0, v[7:0]};
        end
        $fclose(f);
        f = $fopen("layer/bias.hex", "r");
        if (f == 0) $fatal(1, "cannot open layer/bias.hex; run from conv_int8/");
        for (i = 0; i < COUT; i = i + 1) begin
            $fscanf(f, "%h", v);
            mem[(A_SRC_B >> 2) + i] = v;
        end
        $fclose(f);
        f = $fopen("layer/m.hex", "r");
        if (f == 0) $fatal(1, "cannot open layer/m.hex; run from conv_int8/");
        for (i = 0; i < COUT; i = i + 1) begin
            $fscanf(f, "%h", v);
            mem[(A_SRC_M >> 2) + i] = v;
        end
        $fclose(f);

        rstn = 0;
        repeat (3) @(negedge clk);
        rstn = 1;
        @(negedge clk);

        errors = 0;
        run_once(1'b0, st, v);
        if (!st) begin
            $display("FAIL: closed loop never reported done");
            errors = errors + 1;
        end
        else begin
            $display("closed loop finished, done=1 err=%0d", v);
            // read the result back the way the CPU would, and compare
            f = $fopen("layer/gold.hex", "r");
            if (f == 0) $fatal(1, "cannot open layer/gold.hex; run from conv_int8/");
            checked = 0;
            for (i = 0; i < OSZ; i = i + 1) begin
                $fscanf(f, "%h", gold);
                if (mem[(A_DST >> 2) + i][7:0] !== gold) begin
                    if (errors < 8)
                        $display("MISMATCH ddr[%0d]: got %02h want %02h",
                                 i, mem[(A_DST >> 2) + i][7:0], gold);
                    errors = errors + 1;
                end
                checked = checked + 1;
            end
            $fclose(f);
            if (errors == 0)
                $display("PASS: %0d bytes written back through AXI and verified", checked);
        end

        // isolate transport vs arithmetic: did the tensors actually land in the
        // layer's internal RAMs byte for byte?
        begin : chk_load
            integer e_in, e_w, e_out;
            e_in = 0; e_w = 0; e_out = 0;
            f = $fopen("layer/in.hex", "r");
            for (i = 0; i < INSZ; i = i + 1) begin
                $fscanf(f, "%h", v);
                if (dut.u_layer.in_ram[i] !== v[7:0]) e_in = e_in + 1;
            end
            $fclose(f);
            f = $fopen("layer/w.hex", "r");
            for (i = 0; i < WSZ; i = i + 1) begin
                $fscanf(f, "%h", v);
                if (dut.u_layer.w_ram[i] !== v[7:0]) begin
                    if (e_w < 20)
                        $display("  w_ram[%0d] (oc=%0d k=%0d) got %02h want %02h",
                                 i, i/(CIN*9), i%(CIN*9), dut.u_layer.w_ram[i], v[7:0]);
                    e_w = e_w + 1;
                end
            end
            $fclose(f);
            f = $fopen("layer/gold.hex", "r");
            for (i = 0; i < OSZ; i = i + 1) begin
                $fscanf(f, "%h", v);
                if (dut.u_layer.out_ram[i] !== v[7:0]) e_out = e_out + 1;
            end
            $fclose(f);
            $display("LOAD-CHECK  in_ram bad=%0d/%0d  w_ram bad=%0d/%0d  out_ram bad=%0d/%0d",
                     e_in, INSZ, e_w, WSZ, e_out, OSZ);
            // A load mismatch means the transport or the layer RAM contract is
            // broken even if the write-back bytes happen to look plausible.
            errors = errors + e_in + e_w + e_out;
        end

        // error path: a failing B must raise err and must not raise done
        run_once(1'b1, st, v);
        if (st) begin
            $display("FAIL: done must not rise when a B response failed");
            errors = errors + 1;
        end
        else if (!v) begin
            $display("FAIL: err must rise on a non-OKAY B response");
            errors = errors + 1;
        end
        else
            $display("PASS: failing B sets err and blocks done");

        if (errors == 0)
            $display("RESULT: closed loop verified");
        else
            $display("RESULT: %0d failures", errors);
        $finish;
    end

    initial begin
        #5000000;
        $display("FAIL: global timeout");
        $finish;
    end

endmodule
