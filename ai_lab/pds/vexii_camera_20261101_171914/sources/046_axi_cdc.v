// async_fifo -- Gray-pointer dual-clock FIFO, the building block of axi_cdc.
//
// Everything here is the textbook pattern: write-side binary counter, read-side
// binary counter, both exported as Gray code and re-synchronised into the other
// domain through two flops.  FULL is computed from the Gray difference so a
// pointer that is mid-transition never reads as "not full" for one cycle.
`timescale 1ns/1ps

module async_fifo #(
    parameter integer DW    = 32,
    parameter integer DEPTH = 16,
    parameter integer AW    = 4          // log2(DEPTH)
)(
    input  wire          wclk,
    input  wire          wrst_n,
    input  wire          we,
    input  wire [DW-1:0] wdata,
    output wire          full,

    input  wire          rclk,
    input  wire          rrst_n,
    input  wire          re,
    output wire [DW-1:0] rdata,
    output wire          empty
);
    reg [DW-1:0] mem [0:DEPTH-1];

    reg [AW:0] wp_bin, rp_bin;
    reg [AW:0] wp_gray, rp_gray;
    reg [AW:0] rp_gray_w1, rp_gray_w2;     // read pointer synced into wclk
    reg [AW:0] wp_gray_r1, wp_gray_r2;     // write pointer synced into rclk

    function [AW:0] b2g;
        input [AW:0] b;
        begin b2g = (b >> 1) ^ b; end
    endfunction

    // full: the write pointer is exactly one DEPTH ahead of the read pointer,
    // which in Gray code means the two MSBs differ and the rest matches
    wire [AW:0] rp_gray_w2_xor = rp_gray_w2 ^ {2'b11, {AW-1{1'b0}}};
    assign full  = (wp_gray == rp_gray_w2_xor);
    assign empty = (rp_gray == wp_gray_r2);

    always @(posedge wclk) begin
        if (!wrst_n) begin
            wp_bin <= 0; wp_gray <= 0;
            rp_gray_w1 <= 0; rp_gray_w2 <= 0;
        end
        else begin
            rp_gray_w1 <= rp_gray;
            rp_gray_w2 <= rp_gray_w1;
            if (we && !full) begin
                mem[wp_bin[AW-1:0]] <= wdata;
                wp_bin  <= wp_bin + 1'b1;
                wp_gray <= b2g(wp_bin + 1'b1);
            end
        end
    end

    // show-ahead read: the consumer sees the head as soon as !empty, and `re`
    // only advances the pointer.  The alternative (register rdata on re) would
    // hand the consumer the *previous* entry on the first beat of every burst.
    assign rdata = mem[rp_bin[AW-1:0]];

    always @(posedge rclk) begin
        if (!rrst_n) begin
            rp_bin <= 0; rp_gray <= 0;
            wp_gray_r1 <= 0; wp_gray_r2 <= 0;
        end
        else begin
            wp_gray_r1 <= wp_gray;
            wp_gray_r2 <= wp_gray_r1;
            if (re && !empty) begin
                rp_bin  <= rp_bin + 1'b1;
                rp_gray <= b2g(rp_bin + 1'b1);
            end
        end
    end
endmodule


// axi_cdc -- single-beat AXI across two unrelated clocks.
//
// The accelerator side of the SoC runs at 66.7 MHz (that is what the engine's
// netlist closes at); the DDR3 IP's AXI slave runs on the IP's own core_clk,
// which its internal PLL generates and which is NOT a frequency we can choose.
// So the crossing is mandatory, not optional.
//
// Both directions are one async FIFO each.  Requests carry {we, addr, data,
// strb}; responses carry {is_read, rdata}.  Depth 16 lets the 66.7 MHz side run
// ahead of DDR latency instead of paying the synchronisation cost per word --
// a naive request/acknowledge toggle would cap throughput around 50 MB/s, which
// is slower than the 12.58 MB/frame budget allows.
module axi_cdc #(
    parameter integer DEPTH = 16,
    parameter integer AW    = 4
)(
    input  wire        clk_a,       // accelerator / CPU clock
    input  wire        arst_n,
    input  wire        clk_b,       // DDR3 core_clk
    input  wire        brst_n,

    // ---- request side, one beat at a time ----
    input  wire        a_req_valid,
    output wire        a_req_full,
    input  wire        a_req_write,
    input  wire [31:0] a_req_addr,
    input  wire [255:0] a_req_wdata,
    input  wire [31:0] a_req_wstrb,

    // ---- response side ----
    output wire        a_rsp_valid,
    input  wire        a_rsp_ready,
    output wire [255:0] a_rsp_rdata,
    output wire        a_rsp_is_read,

    // ---- DDR3 AXI, clk_b ----
    output reg  [27:0] b_awaddr,
    output reg  [3:0]  b_awlen,
    output reg         b_awvalid,
    input  wire        b_awready,
    output reg  [255:0] b_wdata,
    output reg  [31:0] b_wstrb,
    output reg         b_wvalid,
    input  wire        b_wready,
    input  wire        b_wusero_last,

    output reg  [27:0] b_araddr,
    output reg  [3:0]  b_arlen,
    output reg         b_arvalid,
    input  wire        b_arready,
    input  wire [255:0] b_rdata,
    input  wire        b_rvalid,
    input  wire        b_rlast,
    output reg         b_rready
);

    // ---- request FIFO ------------------------------------------------------
    // packed: {we, addr[31:0], wdata[255:0], wstrb[31:0]} = 1+32+256+32 = 321
    wire [320:0] req_packed;
    assign req_packed = {a_req_write, a_req_addr, a_req_wdata, a_req_wstrb};

    wire         q_empty;
    wire [320:0] q_data;
    wire         q_re;

    async_fifo #(.DW(321), .DEPTH(DEPTH), .AW(AW)) u_req (
        .wclk(clk_a), .wrst_n(arst_n),
        .we(a_req_valid && !a_req_full), .wdata(req_packed), .full(a_req_full),
        .rclk(clk_b), .rrst_n(brst_n),
        .re(q_re), .rdata(q_data), .empty(q_empty)
    );

    wire        q_we    = q_data[320];
    wire [31:0] q_addr  = q_data[319:288];
    wire [255:0] q_wdata = q_data[287:32];
    wire [31:0] q_wstrb = q_data[31:0];

    // ---- response FIFO -----------------------------------------------------
    wire [256:0] rsp_packed;
    wire         rsp_we;
    wire         rsp_full;
    wire         rsp_empty;
    wire         rsp_re;
    wire [256:0] rsp_data;

    async_fifo #(.DW(257), .DEPTH(DEPTH), .AW(AW)) u_rsp (
        .wclk(clk_b), .wrst_n(brst_n),
        .we(rsp_we && !rsp_full), .wdata(rsp_packed), .full(rsp_full),
        .rclk(clk_a), .rrst_n(arst_n),
        .re(rsp_re), .rdata(rsp_data), .empty(rsp_empty)
    );

    assign a_rsp_valid   = !rsp_empty;
    assign a_rsp_rdata   = rsp_data[255:0];
    assign a_rsp_is_read = rsp_data[256];
    assign rsp_re=arst_n && a_rsp_valid && a_rsp_ready;

    // ---- clk_b: issue one single-beat AXI transaction per FIFO entry -------
    localparam [2:0] B_IDLE = 3'd0, B_RD_REQ = 3'd1, B_RD_DATA = 3'd2,
                     B_WR = 3'd3, B_WR_FIN = 3'd4, B_RSP = 3'd5;
    reg [2:0] bst;
    reg       cur_is_read;
    reg [255:0] response_data;
    reg write_complete;

    assign rsp_packed = {cur_is_read, response_data};
    assign rsp_we=brst_n && bst==B_RSP;
    assign q_re=brst_n && bst==B_IDLE && !q_empty && !rsp_full;

    always @(posedge clk_b) begin
        if (!brst_n) begin
            bst <= B_IDLE;
            b_awaddr <= 0; b_awlen <= 0; b_awvalid <= 0;
            b_wdata <= 0; b_wstrb <= 0; b_wvalid <= 0;
            b_araddr <= 0; b_arlen <= 0; b_arvalid <= 0; b_rready <= 0;
            cur_is_read <= 1'b0;response_data<=0;write_complete<=0;
        end
        else begin

            case (bst)
            B_IDLE: begin
                if (q_re) begin
                    cur_is_read <= !q_we;
                    write_complete<=0;
`ifdef CDC_TRACE
                    $display("CDC start t=%0t q_we=%b addr=%08x q_empty=%b", $time, q_we, q_addr, q_empty);
`endif
                    if (q_we) begin
                        b_awaddr  <= q_addr[27:0];
                        b_awlen   <= 4'd0;
                        b_wdata   <= q_wdata;
                        b_wstrb   <= q_wstrb;
                        b_awvalid <= 1'b1;
                        b_wvalid  <= 1'b1;
                        bst       <= B_WR;
                    end
                    else begin
                        b_araddr  <= q_addr[27:0];
                        b_arlen   <= 4'd0;
                        b_arvalid <= 1'b1;
                        b_rready  <= 1'b1;
                        bst       <= B_RD_REQ;
                    end
                end
            end

            B_RD_REQ: begin
                if (b_arready) begin
                    b_arvalid <= 1'b0;
                    bst       <= B_RD_DATA;
                end
            end

            B_RD_DATA: begin
                if (b_rvalid) begin
                    b_rready <= 1'b0;
                    response_data<=b_rdata;
`ifdef CDC_TRACE
                    $display("CDC read-done t=%0t", $time);
`endif
                    bst      <= B_RSP;
                end
            end

            B_WR: begin
                if (b_awready) b_awvalid <= 1'b0;
                if (b_wready)  b_wvalid  <= 1'b0;
                if(b_wusero_last) write_complete<=1;
                if ((!b_awvalid || b_awready) && (!b_wvalid || b_wready))
                    bst <= B_WR_FIN;
            end

            B_WR_FIN: begin
                if (b_wusero_last || write_complete) begin
                    response_data<=0;
                    bst<=B_RSP;
                end
            end
            B_RSP: if(!rsp_full) bst<=B_IDLE;
            default: bst<=B_IDLE;
            endcase
        end
    end
endmodule
