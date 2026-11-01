// tb_engine_axi -- end-to-end check of the AXI wrapper against a DDR model.
//
// The slave model below is deliberately independent of the engine: it is a
// plain single-beat AXI4 memory that answers reads with two cycles of latency
// and writes with a B response.  That is the contract the wrapper claims, so a
// pass here means the wrapper's read/write handshakes and its completion rule
// (done only after BRESP) actually hold, not just that the engine computes.
//
// The stimulus reaches the DUT the same way the CPU will: AXI4-Lite register
// writes for the four base addresses, then CTRL.start, then polling STATUS.
`timescale 1ns/1ps

module tb_engine_axi;

`include "tb_params.vh"

    reg clk = 0, rstn = 0;
    always #5 clk = ~clk;

    // ---- control side ----
    reg  [7:0]  s_awaddr = 0;
    reg         s_awvalid = 0;
    wire        s_awready;
    reg  [31:0] s_wdata = 0;
    reg         s_wvalid = 0;
    wire        s_wready;
    wire [1:0]  s_bresp;
    wire        s_bvalid;
    reg         s_bready = 0;
    reg  [7:0]  s_araddr = 0;
    reg         s_arvalid = 0;
    wire        s_arready;
    wire [31:0] s_rdata;
    wire [1:0]  s_rresp;
    wire        s_rvalid;
    reg         s_rready = 0;

    // ---- DDR side ----
    wire [31:0] m_araddr;
    wire        m_arvalid, m_arready;
    wire [7:0]  m_arlen;
    wire [63:0] m_rdata;
    wire        m_rvalid, m_rready;
    wire [1:0]  m_rresp;
    wire [31:0] m_awaddr;
    wire        m_awvalid, m_awready;
    wire [7:0]  m_awlen;
    wire [63:0] m_wdata;
    wire        m_wvalid, m_wlast, m_wready;
    wire [1:0]  m_bresp;
    wire        m_bvalid, m_bready;

    conv_engine_axi #(
        .CINPAD(P_CINPAD), .COUT(P_COUT), .IN_W(P_IN_W), .IN_H(P_IN_H),
        .K(P_K), .STRIDE(P_STRIDE), .ACT(P_ACT), .TR(P_TR),
        .PADP(P_PAD), .SHIFT(15)
    ) dut (
        .clk(clk), .rstn(rstn),
        .s_awaddr(s_awaddr), .s_awvalid(s_awvalid), .s_awready(s_awready),
        .s_wdata(s_wdata), .s_wvalid(s_wvalid), .s_wready(s_wready),
        .s_bresp(s_bresp), .s_bvalid(s_bvalid), .s_bready(s_bready),
        .s_araddr(s_araddr), .s_arvalid(s_arvalid), .s_arready(s_arready),
        .s_rdata(s_rdata), .s_rresp(s_rresp), .s_rvalid(s_rvalid), .s_rready(s_rready),
        .m_araddr(m_araddr), .m_arvalid(m_arvalid), .m_arready(m_arready),
        .m_arlen(m_arlen), .m_rdata(m_rdata), .m_rvalid(m_rvalid),
        .m_rready(m_rready), .m_rresp(m_rresp),
        .m_awaddr(m_awaddr), .m_awvalid(m_awvalid), .m_awready(m_awready),
        .m_awlen(m_awlen), .m_wdata(m_wdata), .m_wvalid(m_wvalid),
        .m_wlast(m_wlast), .m_wready(m_wready), .m_bresp(m_bresp),
        .m_bvalid(m_bvalid), .m_bready(m_bready)
    );

    // ---- AXI4 memory model ----------------------------------------------
    reg [63:0] mem [0:P_MEMW-1];
    reg [63:0] exp_mem [0:P_NOUT-1];

    integer k, fd, rc, i, errors;
    reg [63:0] got;
    integer nrd = 0, nwr = 0;

    // read channel: two cycles of latency, one outstanding
    reg        rd_pend;
    reg [1:0]  rd_cnt;
    reg [31:0] rd_addr_r;
    reg [64:0] r_pipe;          // {valid, data}
    assign m_arready = !rd_pend;
    assign m_rdata   = r_pipe[63:0];
    assign m_rvalid  = r_pipe[64];

    always @(posedge clk) begin
        if (!rstn) begin
            rd_pend <= 1'b0; rd_cnt <= 2'd0; rd_addr_r <= 32'd0; r_pipe <= 65'd0;
        end
        else begin
            if (m_rvalid && m_rready)
                r_pipe[64] <= 1'b0;

            if (m_arvalid && m_arready) begin
                rd_addr_r <= m_araddr;
                rd_cnt    <= 2'd0;
                rd_pend   <= 1'b1;
            end
            else if (rd_pend) begin
                if (rd_cnt == 2'd2) begin
                    r_pipe[63:0] <= mem[rd_addr_r[31:3]];
                    r_pipe[64]   <= 1'b1;
                    rd_pend      <= 1'b0;
                end
                else
                    rd_cnt <= rd_cnt + 2'd1;
            end
        end
    end
    assign m_rresp = 2'b00;

    // write channel: accept AW and W, commit, then answer B
    reg        aw_seen, w_seen;
    reg [31:0] aw_addr_r;
    reg [63:0] w_data_r;
    reg        b_pend;
    assign m_awready = !aw_seen;
    assign m_wready  = !w_seen;
    assign m_bvalid  = b_pend;
    assign m_bresp   = 2'b00;

    always @(posedge clk) begin
        if (!rstn) begin
            aw_seen <= 1'b0; w_seen <= 1'b0; aw_addr_r <= 0; w_data_r <= 0;
            b_pend <= 1'b0;
        end
        else begin
            if (m_awvalid && m_awready) begin
                aw_seen <= 1'b1; aw_addr_r <= m_awaddr;
            end
            if (m_wvalid && m_wready) begin
                w_seen <= 1'b1; w_data_r <= m_wdata;
            end
            if (aw_seen && w_seen && !b_pend) begin
                mem[aw_addr_r[31:3]] <= w_data_r;
                b_pend <= 1'b1;
                aw_seen <= 1'b0; w_seen <= 1'b0;
                nwr = nwr + 1;
            end
            if (b_pend && m_bready)
                b_pend <= 1'b0;
        end
    end

    // ---- control-side helpers -------------------------------------------
    task wr_reg;
        input [7:0]  a;
        input [31:0] d;
        begin
            @(posedge clk);
            s_awaddr <= a; s_wdata <= d; s_awvalid <= 1'b1; s_wvalid <= 1'b1;
            s_bready <= 1'b1;
            @(posedge clk);
            while (!s_bvalid) @(posedge clk);
            s_awvalid <= 1'b0; s_wvalid <= 1'b0;
            @(posedge clk);
            s_bready <= 1'b0;
        end
    endtask

    task rd_reg;
        input  [7:0]  a;
        output [31:0] d;
        begin
            @(posedge clk);
            s_araddr <= a; s_arvalid <= 1'b1; s_rready <= 1'b1;
            @(posedge clk);
            while (!s_rvalid) @(posedge clk);
            d = s_rdata;
            s_arvalid <= 1'b0;
            @(posedge clk);
            s_rready <= 1'b0;
        end
    endtask

    reg [31:0] st;

    initial begin
        for (k = 0; k < P_MEMW; k = k + 1) mem[k] = 64'd0;
        for (k = 0; k < P_NOUT; k = k + 1) exp_mem[k] = 64'd0;

        $readmemh(`DDR_FILE, mem);
        $readmemh(`EXP_FILE, exp_mem);
        if (mem[0] === 64'd0 && exp_mem[0] === 64'd0)
            $fatal(1, "vector load failed: both arrays are zero");

        repeat (4) @(posedge clk);
        rstn = 1;
        repeat (2) @(posedge clk);

        // the CPU's sequence: addresses, then start, then poll
        wr_reg(8'd8,  P_A_BASE);
        wr_reg(8'd12, P_W_BASE);
        wr_reg(8'd16, P_Y_BASE);
        wr_reg(8'd28, P_Q_BASE);
        wr_reg(8'd32, P_T_BASE);
        wr_reg(8'd0,  32'd1);

        st = 0;
        for (i = 0; i < 4000000 && !(st[1] || st[2]); i = i + 1)
            rd_reg(8'd4, st);

        errors = 0;
        if (st[2]) begin
            $display("FAIL: STATUS.err set, status=%08x", st);
            errors = errors + 1;
        end
        if (!st[1]) begin
            $display("TIMEOUT: done never asserted, status=%08x", st);
            errors = errors + 1;
        end

        for (i = 0; i < P_NOUT; i = i + 1) begin
            got = mem[(P_Y_BASE >> 3) + i];
            if (got !== exp_mem[i]) begin
                errors = errors + 1;
                if (errors <= 6)
                    $display("MISMATCH word %0d: got %016x exp %016x", i, got, exp_mem[i]);
            end
        end

        if (errors == 0)
            $display("AXI-ENGINE-PASS  %0d words, %0d writes, via AXI", P_NOUT, nwr);
        else
            $display("AXI-ENGINE-FAIL  %0d errors of %0d words", errors, P_NOUT);
        $finish;
    end

endmodule
