// tb_ddr_bridge -- checks the two things that are easy to get wrong and hard to
// notice: which 32-byte line a 64-bit word belongs to, and which byte lanes the
// strobes select.  The DDR model below stores 32-byte beats and applies WSTRB
// byte by byte, so a lane error shows up as shifted data rather than passing.
//
// It also counts DDR read beats, which is the only way to tell whether the
// per-line read cache is doing anything: four sequential word reads must cost
// one DDR beat, not four.
`timescale 1ns/1ps

module tb_ddr_bridge;

    reg clk = 0, rstn = 0;
    always #5 clk = ~clk;

    // ---- accelerator side (64-bit, single beat) ----
    reg  [31:0] s_awaddr = 0;
    reg         s_awvalid = 0;
    wire        s_awready;
    reg  [63:0] s_wdata = 0;
    reg  [7:0]  s_wstrb = 8'hFF;
    reg         s_wvalid = 0;
    wire        s_wready;
    wire [1:0]  s_bresp;
    wire        s_bvalid;
    reg         s_bready = 0;
    reg  [31:0] s_araddr = 0;
    reg         s_arvalid = 0;
    wire        s_arready;
    wire [63:0] s_rdata;
    wire [1:0]  s_rresp;
    wire        s_rvalid;
    reg         s_rready = 0;

    // ---- DDR side (256-bit) ----
    wire [27:0]  m_awaddr;
    wire [3:0]   m_awlen;
    wire         m_awvalid;
    reg          m_awready;
    wire [255:0] m_wdata;
    wire [31:0]  m_wstrb;
    wire         m_wvalid;
    reg          m_wready;
    reg          m_wusero_last;
    wire [27:0]  m_araddr;
    wire [3:0]   m_arlen;
    wire         m_arvalid;
    reg          m_arready;
    reg  [255:0] m_rdata;
    reg          m_rvalid;
    reg          m_rlast;
    wire         m_rready;

    ddr_axi_bridge dut (
        .clk(clk), .rstn(rstn),
        .s_awaddr(s_awaddr), .s_awvalid(s_awvalid), .s_awready(s_awready),
        .s_wdata(s_wdata), .s_wstrb(s_wstrb), .s_wvalid(s_wvalid),
        .s_wready(s_wready), .s_bresp(s_bresp), .s_bvalid(s_bvalid),
        .s_bready(s_bready),
        .s_araddr(s_araddr), .s_arvalid(s_arvalid), .s_arready(s_arready),
        .s_rdata(s_rdata), .s_rresp(s_rresp), .s_rvalid(s_rvalid),
        .s_rready(s_rready),
        .m_awaddr(m_awaddr), .m_awlen(m_awlen), .m_awvalid(m_awvalid),
        .m_awready(m_awready), .m_wdata(m_wdata), .m_wstrb(m_wstrb),
        .m_wvalid(m_wvalid), .m_wready(m_wready),
        .m_wusero_last(m_wusero_last),
        .m_araddr(m_araddr), .m_arlen(m_arlen), .m_arvalid(m_arvalid),
        .m_arready(m_arready), .m_rdata(m_rdata), .m_rvalid(m_rvalid),
        .m_rlast(m_rlast), .m_rready(m_rready)
    );

    // ---- DDR model: 32-byte beats, byte strobes, word-addressed -----------
    localparam integer NL = 1024;           // 32 KiB of lines
    reg [7:0] ddr [0:NL*32-1];
    integer i, k;
    integer wr_beats = 0, rd_beats = 0;
    reg [255:0] rd_word;

    initial for (k = 0; k < NL*32; k = k + 1) ddr[k] = 8'h00;

    // write: take one beat, apply strobes to the 32-byte line
    reg model_aw = 0, model_w = 0;
    reg [27:0] model_addr;
    reg [255:0] model_data;
    reg [31:0] model_strb;
    integer tick=0;
    always @(posedge clk) begin
        if (!rstn) begin
            m_awready <= 1'b1; m_wready <= 1'b1;
            m_wusero_last <= 1'b0; model_aw <= 0; model_w <= 0;
            tick <= 0;
        end
        else begin
            m_wusero_last <= 1'b0;
            tick <= tick+1;
            m_awready <= !model_aw && (tick%4==0);
            m_wready <= !model_w && (tick%4==2);
            if(m_awvalid && m_awready) begin
                if(model_aw) $fatal(1,"Duplicate downstream AW");
                model_addr <= m_awaddr; model_aw <= 1;
            end
            if(m_wvalid && m_wready) begin
                if(model_w) $fatal(1,"Duplicate downstream W");
                model_data <= m_wdata; model_strb <= m_wstrb; model_w <= 1;
            end
            if (model_aw && model_w) begin
                for (i = 0; i < 32; i = i + 1)
                    if (model_strb[i])
                        ddr[model_addr*4 + i] <= model_data[i*8 +: 8];
                model_aw <= 0; model_w <= 0;
                wr_beats = wr_beats + 1;
                m_wusero_last <= 1'b1;
            end
        end
    end

    // read: one beat, two cycles of latency
    reg [1:0] rlat = 0;
    always @(posedge clk) begin
        if (!rstn) begin
            m_arready <= 1'b1; m_rvalid <= 1'b0; m_rlast <= 1'b0;
            rlat <= 0;
        end
        else begin
            m_rvalid <= 1'b0;
            m_rlast  <= 1'b0;
            if (m_arvalid && m_arready) begin
                rd_word <= {ddr[m_araddr*4 + 31], ddr[m_araddr*4 + 30],
                            ddr[m_araddr*4 + 29], ddr[m_araddr*4 + 28],
                            ddr[m_araddr*4 + 27], ddr[m_araddr*4 + 26],
                            ddr[m_araddr*4 + 25], ddr[m_araddr*4 + 24],
                            ddr[m_araddr*4 + 23], ddr[m_araddr*4 + 22],
                            ddr[m_araddr*4 + 21], ddr[m_araddr*4 + 20],
                            ddr[m_araddr*4 + 19], ddr[m_araddr*4 + 18],
                            ddr[m_araddr*4 + 17], ddr[m_araddr*4 + 16],
                            ddr[m_araddr*4 + 15], ddr[m_araddr*4 + 14],
                            ddr[m_araddr*4 + 13], ddr[m_araddr*4 + 12],
                            ddr[m_araddr*4 + 11], ddr[m_araddr*4 + 10],
                            ddr[m_araddr*4 + 9],  ddr[m_araddr*4 + 8],
                            ddr[m_araddr*4 + 7],  ddr[m_araddr*4 + 6],
                            ddr[m_araddr*4 + 5],  ddr[m_araddr*4 + 4],
                            ddr[m_araddr*4 + 3],  ddr[m_araddr*4 + 2],
                            ddr[m_araddr*4 + 1],  ddr[m_araddr*4 + 0]};
                rlat <= 2'd2;
                m_arready <= 1'b0;
                rd_beats = rd_beats + 1;
            end
            if (rlat != 0) begin
                rlat <= rlat - 2'd1;
                if (rlat == 2'd1) begin
                    m_rvalid <= 1'b1; m_rlast <= 1'b1;
                    m_rdata  <= rd_word;
                    m_arready <= 1'b1;
                end
            end
        end
    end

    // ---- stimulus -------------------------------------------------------
    task wr(input [31:0] a, input [63:0] d);
        begin
            @(negedge clk);
            s_awaddr = a; s_awvalid = 1;
            do @(posedge clk); while(!s_awready);
            @(negedge clk); s_awvalid=0;
            repeat(2) @(negedge clk);
            s_wdata=d; s_wstrb=8'hff; s_wvalid=1;
            do @(posedge clk); while(!s_wready);
            @(negedge clk); s_wvalid=0;
            wait(s_bvalid);
            repeat(3) begin
                @(negedge clk);
                if(!s_bvalid || s_bresp!=0) $fatal(1,"B not held");
            end
            s_bready=1;
            @(posedge clk);
            @(negedge clk); s_bready=0;
        end
    endtask

    task rd(input [31:0] a, output [63:0] d);
        begin
            @(negedge clk); s_araddr=a; s_arvalid=1;
            do @(posedge clk); while(!s_arready);
            @(negedge clk); s_arvalid=0; s_araddr=32'h7ff0;
            wait(s_rvalid);
            d = s_rdata;
            repeat(3) begin
                @(negedge clk);
                if(!s_rvalid || s_rdata!==d) $fatal(1,"R not held");
            end
            s_rready=1;
            @(posedge clk);
            @(negedge clk); s_rready=0;
        end
    endtask

    integer errors = 0;
    reg [63:0] v;

    initial begin
        repeat (4) @(posedge clk);
        rstn = 1;
        repeat (2) @(posedge clk);

        // four words inside one 32-byte line, then one word in the next line
        wr(32'h0000_1000, 64'h1122_3344_5566_7788);
        wr(32'h0000_1008, 64'h99AA_BBCC_DDEE_FF00);
        wr(32'h0000_1010, 64'h0123_4567_89AB_CDEF);
        wr(32'h0000_1018, 64'hFEDC_BA98_7654_3210);
        wr(32'h0000_1020, 64'hA5A5_5A5A_A5A5_5A5A);

        // the byte lanes must be exactly where the strobes said
        if (ddr[(32'h1000 >> 5)*32 + 0] !== 8'h88) begin
            $display("LANE byte0 = %02x exp 88", ddr[(32'h1000>>5)*32 + 0]);
            errors = errors + 1;
        end
        if (ddr[(32'h1000 >> 5)*32 + 8] !== 8'h00) begin
            $display("LANE byte8 = %02x exp 00", ddr[(32'h1000>>5)*32 + 8]);
            errors = errors + 1;
        end
        if (ddr[(32'h1008 >> 5)*32 + 8] !== 8'h00) begin
            $display("LINE2 byte8 = %02x exp 00 (word 2 goes to lane 1)", ddr[(32'h1008>>5)*32 + 8]);
            errors = errors + 1;
        end
        if (ddr[(32'h1008 >> 5)*32 + 15] !== 8'h99) begin
            $display("LANE2 byte15 = %02x exp 99", ddr[(32'h1008>>5)*32 + 15]);
            errors = errors + 1;
        end

        rd(32'h0000_1000, v);
        if (v !== 64'h1122_3344_5566_7788) begin
            $display("RD 0x1000 = %016x", v); errors = errors + 1;
        end
        rd(32'h0000_1008, v);
        if (v !== 64'h99AA_BBCC_DDEE_FF00) begin
            $display("RD 0x1008 = %016x", v); errors = errors + 1;
        end
        rd(32'h0000_1018, v);
        if (v !== 64'hFEDC_BA98_7654_3210) begin
            $display("RD 0x1018 = %016x", v); errors = errors + 1;
        end
        rd(32'h0000_1020, v);
        if (v !== 64'hA5A5_5A5A_A5A5_5A5A) begin
            $display("RD 0x1020 = %016x", v); errors = errors + 1;
        end

        // four reads spread over two lines must cost two DDR beats, not four
        if (rd_beats != 2) begin
            $display("READ BEATS = %0d, expected 2 (line cache not working)", rd_beats);
            errors = errors + 1;
        end
        if (wr_beats != 5) begin
            $display("WRITE BEATS = %0d, expected 5", wr_beats);
            errors = errors + 1;
        end

        // Cached data must not survive a CPU/software write to that line.
        wr(32'h1020,64'h0123456789abcdef);
        rd(32'h1020,v);
        if(v!==64'h0123456789abcdef) $fatal(1,"Stale cache after write");

        if (errors == 0)
            $display("DDR-BRIDGE-PASS  5 writes, 4 reads, %0d read beats, %0d write beats",
                     rd_beats, wr_beats);
        else
            $fatal(1,"DDR-BRIDGE-FAIL  %0d errors", errors);
        $finish;
    end

    initial begin
        repeat (20000) @(posedge clk);
        $fatal(1,"DDR bridge TIMEOUT");
    end

endmodule
