// tb_axi_cdc -- two unrelated clocks (10 ns and 7 ns), a word-addressed
// 32-byte DDR model on the fast side, and a handful of single-beat reads and
// writes on the slow side.  The point is not that data moves; it is that it
// moves with no dropped, duplicated or reordered beats across the crossing.
`timescale 1ns/1ps

module tb_axi_cdc;

    reg clk_a = 0;
    always #5 clk_a = ~clk_a;
    reg clk_b = 0;
    always #3.5 clk_b = ~clk_b;

    reg arst_n = 0, brst_n = 0;

    reg         a_req_valid = 0;
    wire        a_req_full;
    reg         a_req_write = 0;
    reg  [31:0] a_req_addr = 0;
    reg  [255:0] a_req_wdata = 0;
    reg  [31:0] a_req_wstrb = 0;
    wire        a_rsp_valid;
    reg         a_rsp_ready = 0;
    wire [255:0] a_rsp_rdata;
    wire        a_rsp_is_read;

    wire [27:0]  b_awaddr;
    wire [3:0]   b_awlen;
    wire         b_awvalid;
    reg          b_awready;
    wire [255:0] b_wdata;
    wire [31:0]  b_wstrb;
    wire         b_wvalid;
    reg          b_wready;
    reg          b_wusero_last;
    wire [27:0]  b_araddr;
    wire [3:0]   b_arlen;
    wire         b_arvalid;
    reg          b_arready;
    reg  [255:0] b_rdata;
    reg          b_rvalid;
    reg          b_rlast;
    wire         b_rready;

    axi_cdc dut (
        .clk_a(clk_a), .arst_n(arst_n), .clk_b(clk_b), .brst_n(brst_n),
        .a_req_valid(a_req_valid), .a_req_full(a_req_full),
        .a_req_write(a_req_write), .a_req_addr(a_req_addr),
        .a_req_wdata(a_req_wdata), .a_req_wstrb(a_req_wstrb),
        .a_rsp_valid(a_rsp_valid), .a_rsp_ready(a_rsp_ready),
        .a_rsp_rdata(a_rsp_rdata), .a_rsp_is_read(a_rsp_is_read),
        .b_awaddr(b_awaddr), .b_awlen(b_awlen), .b_awvalid(b_awvalid),
        .b_awready(b_awready), .b_wdata(b_wdata), .b_wstrb(b_wstrb),
        .b_wvalid(b_wvalid), .b_wready(b_wready),
        .b_wusero_last(b_wusero_last),
        .b_araddr(b_araddr), .b_arlen(b_arlen), .b_arvalid(b_arvalid),
        .b_arready(b_arready), .b_rdata(b_rdata), .b_rvalid(b_rvalid),
        .b_rlast(b_rlast), .b_rready(b_rready)
    );

    // ---- DDR model: 32-byte lines, word addressed, strobed ----------------
    localparam integer NL = 256;
    reg [7:0] ddr [0:NL*32-1];
    integer i, k;
    reg wbusy = 0;
    initial for (k = 0; k < NL*32; k = k + 1) ddr[k] = 0;

    always @(posedge clk_b) begin
        if (!brst_n) begin
            b_awready <= 1'b1; b_wready <= 1'b1; wbusy <= 1'b0;
            b_wusero_last <= 1'b0;
        end
        else begin
            b_wusero_last <= 1'b0;
            b_awready <= !wbusy; b_wready <= !wbusy;
            if (b_awvalid && b_awready && b_wvalid && b_wready) begin
                for (i = 0; i < 32; i = i + 1)
                    if (b_wstrb[i]) ddr[b_awaddr*4 + i] <= b_wdata[i*8 +: 8];
                wbusy <= 1'b1;
            end
            else if (wbusy) begin
                wbusy <= 1'b0;
                b_wusero_last <= 1'b1;
            end
        end
    end

    reg [1:0] rlat = 0;
    always @(posedge clk_b) begin
        if (!brst_n) begin
            b_arready <= 1'b1; b_rvalid <= 1'b0; b_rlast <= 1'b0;
            rlat <= 0;
        end
        else begin
            b_rvalid <= 1'b0; b_rlast <= 1'b0;
            if (b_arvalid && b_arready) begin
                for (i = 0; i < 32; i = i + 1)
                    b_rdata[i*8 +: 8] <= ddr[b_araddr*4 + i];
                rlat <= 2'd2;
                b_arready <= 1'b0;
            end
            if (rlat != 0) begin
                rlat <= rlat - 2'd1;
                if (rlat == 2'd1) begin
                    b_rvalid <= 1'b1; b_rlast <= 1'b1;
                    b_arready <= 1'b1;
                end
            end
        end
    end

    // ---- stimulus --------------------------------------------------------
    integer errors = 0;
    integer n_rd = 0, n_wr = 0;

    task req(input wr, input [31:0] addr, input [255:0] d);
        begin
            @(posedge clk_a);
            while (a_req_full) @(posedge clk_a);
            a_req_write <= wr;
            a_req_addr  <= addr;
            a_req_wdata <= d;
            a_req_wstrb <= 32'hFFFF_FFFF;
            a_req_valid <= 1'b1;
            @(posedge clk_a);
            while (a_req_full) @(posedge clk_a);
            a_req_valid <= 1'b0;
        end
    endtask

    task take_rsp(output [255:0] d, output is_read);
        begin
            a_rsp_ready <= 1'b1;
            @(posedge clk_a);
            while (!a_rsp_valid) @(posedge clk_a);
            d = a_rsp_rdata;
            is_read = a_rsp_is_read;
            $display("RSP t=%0t is_read=%b data=%016x", $time, a_rsp_is_read, a_rsp_rdata[63:0]);
            if (is_read) n_rd = n_rd + 1; else n_wr = n_wr + 1;
            @(posedge clk_a);
            a_rsp_ready <= 1'b0;
        end
    endtask

    reg [255:0] v;
    reg isr;

    initial begin
        repeat (4) @(posedge clk_a);
        arst_n = 1; brst_n = 1;
        repeat (4) @(posedge clk_a);

        // two writes to the same 32-byte line, then read both back
        req(1'b1, 32'h0000_0100, 256'h00112233445566778899AABBCCDDEEFF);
        req(1'b1, 32'h0000_0108, 256'hFFEEDDCCBBAA99887766554433221100);
        req(1'b0, 32'h0000_0100, 256'd0);
        req(1'b0, 32'h0000_0108, 256'd0);

        repeat (4) take_rsp(v, isr);
        if (v[255:0] !== 256'hFFEEDDCCBBAA99887766554433221100) begin
            $display("READBACK last = %064x", v); errors = errors + 1;
        end
        if (n_rd != 2 || n_wr != 2) begin
            $display("COUNT rd=%0d wr=%0d, expected 2/2", n_rd, n_wr);
            errors = errors + 1;
        end
        if (ddr[32'h400] !== 8'hFF) begin
            $display("DDR[0x400] = %02x, expected ff", ddr[32'h400]);
            errors = errors + 1;
        end
        if (ddr[32'h420] !== 8'h00) begin
            $display("DDR[0x420] = %02x, expected 00", ddr[32'h420]);
            errors = errors + 1;
        end

        if (errors == 0)
            $display("AXI-CDC-PASS  2 writes, 2 reads, across 10 ns / 7 ns clocks");
        else
            $display("AXI-CDC-FAIL  %0d errors", errors);
        $finish;
    end

    initial begin
        repeat (20000) @(posedge clk_a);
        $display("TIMEOUT rd=%0d wr=%0d", n_rd, n_wr);
        $finish;
    end

endmodule
