// acc_shell -- minimal closed loop: CPU writes parameters, the shell pulls the
// input tensor and weights out of DDR, runs conv3x3_layer, writes the result
// back, and only then reports done.
//
// The shell does not touch the arithmetic; it only moves bytes, so the verified
// datapath stays verified while the transport is brought up.
//
// Completion rule: done rises only after every write has been answered by a B
// response and all of them were OKAY; any non-OKAY B sets err and blocks done.
//
// AXI is single-beat (arlen/awlen = 0) on purpose -- correctness first.
// Address stride is 4 bytes per element (one element per word) during bring-up.
// Packing four int8 per word is a later optimisation; it changes bandwidth, not
// the result.
`timescale 1ns/1ps

module acc_shell #(
    parameter integer CIN    = 8,
    parameter integer COUT   = 8,
    parameter integer W      = 8,
    parameter integer H      = 8,
    parameter integer K      = 3,
    parameter integer STRIDE = 1,
    parameter integer ACT    = 1
)(
    input  wire        clk,
    input  wire        rstn,

    // ---- AXI4-Lite slave: CPU control ----
    input  wire [7:0]  s_awaddr,
    input  wire        s_awvalid,
    output wire        s_awready,
    input  wire [31:0] s_wdata,
    input  wire        s_wvalid,
    output wire        s_wready,
    output wire [1:0]  s_bresp,
    output wire        s_bvalid,
    input  wire        s_bready,
    input  wire [7:0]  s_araddr,
    input  wire        s_arvalid,
    output wire        s_arready,
    output wire [31:0] s_rdata,
    output wire [1:0]  s_rresp,
    output wire        s_rvalid,
    input  wire        s_rready,

    // ---- AXI4 master: DDR (single beat) ----
    output wire [31:0] m_araddr,
    output wire        m_arvalid,
    input  wire        m_arready,
    output wire [7:0]  m_arlen,
    input  wire [31:0] m_rdata,
    input  wire        m_rvalid,
    output wire        m_rready,
    input  wire [1:0]  m_rresp,
    output wire [31:0] m_awaddr,
    output wire        m_awvalid,
    input  wire        m_awready,
    output wire [7:0]  m_awlen,
    output wire [31:0] m_wdata,
    output wire        m_wvalid,
    output wire        m_wlast,
    input  wire        m_wready,
    input  wire [1:0]  m_bresp,
    input  wire        m_bvalid,
    output wire        m_bready,

    output wire        busy,
    output wire        done,
    output wire        err
);

    localparam integer PAD  = K / 2;
    localparam integer OW   = (W + 2 * PAD - K) / STRIDE + 1;
    localparam integer OH   = (H + 2 * PAD - K) / STRIDE + 1;
    localparam integer INSZ = W * H * CIN;
    localparam integer WSZ  = COUT * CIN * K * K;
    localparam integer OSZ  = OW * OH * COUT;

    // ---- layer ----
    wire        layer_busy, layer_done;
    wire [31:0] layer_cycles;
    wire [7:0]  layer_rd;
    reg         layer_go;
    reg         ld_en;
    reg  [1:0]  ld_sel;
    reg  [31:0] ld_addr;
    reg  [31:0] ld_data32;
    reg  [7:0]  ld_data;
    reg  [31:0] rd_addr;


    conv3x3_layer #(.CIN(CIN), .COUT(COUT), .W(W), .H(H), .K(K),
                    .STRIDE(STRIDE), .ACT(ACT)) u_layer (
        .clk(clk), .rstn(rstn), .start(layer_go), .s_shift(5'd15),
        .ld_en(ld_en), .ld_sel(ld_sel), .ld_addr(ld_addr), .ld_data(ld_data),
        .ld_data32(ld_data32),
        .rd_addr(rd_addr), .rd_data(layer_rd),
        .busy(layer_busy), .done(layer_done), .cycles(layer_cycles)
    );

    // ---- control registers ----
    reg [31:0] r_src_in, r_src_w, r_src_b, r_src_m, r_dst, r_cycles;
    reg        kick;                 // CPU wrote CTRL.start
    reg        done_r, err_r;

    reg [31:0] s_rdata_r;
    reg        s_bvalid_r, s_rvalid_r;

    // the FSM consumes `kick`; without this handshake the level would restart
    // the accelerator forever after the first command
    wire start_ack = kick && (tst == T_IDLE || tst == T_DONE);

    assign s_awready = 1'b1;
    assign s_wready  = 1'b1;
    assign s_arready = 1'b1;
    assign s_bresp   = 2'b00;
    assign s_rresp   = 2'b00;
    assign s_bvalid  = s_bvalid_r;
    assign s_rvalid  = s_rvalid_r;
    assign s_rdata   = s_rdata_r;

    always @(posedge clk) begin
        if (!rstn) begin
            r_src_in <= 0; r_src_w <= 0; r_src_b <= 0; r_src_m <= 0;
            r_dst <= 0;
            // done_r / err_r / r_cycles belong to the FSM block only: PDS
            // rejects one variable driven from two always blocks (Verilog-4086).
            kick <= 1'b0;
            s_bvalid_r <= 1'b0; s_rvalid_r <= 1'b0; s_rdata_r <= 0;
        end
        else begin
            if (s_awvalid && s_awready) begin
                case (s_awaddr[7:2])
                    6'd0: kick     <= s_wdata[0];
                    6'd2: r_src_in <= s_wdata;
                    6'd3: r_src_w  <= s_wdata;
                    6'd4: r_dst    <= s_wdata;
                    6'd6: r_src_b  <= s_wdata;
                    6'd7: r_src_m  <= s_wdata;
                    default: ;
                endcase
                s_bvalid_r <= 1'b1;
            end
            else if (s_bvalid_r && s_bready)
                s_bvalid_r <= 1'b0;

            if (!(s_awvalid && s_awready) && start_ack)
                kick <= 1'b0;

            if (s_arvalid && s_arready) begin
                case (s_araddr[7:2])
                    6'd1: s_rdata_r <= {29'd0, err_r, done_r, busy};
                    6'd5: s_rdata_r <= r_cycles;
                    default: s_rdata_r <= 32'd0;
                endcase
                s_rvalid_r <= 1'b1;
            end
            else if (s_rvalid_r && s_rready)
                s_rvalid_r <= 1'b0;
        end
    end

    // ---- write tracker ----
    wire        trk_busy, trk_done, trk_err;
    reg         trk_start;
    wire [7:0]  trk_aw, trk_b;

    assign m_bready = 1'b1;

    axi_wr_tracker u_trk (
        .clk(clk), .rstn(rstn), .start(trk_start),
        .awvalid(m_awvalid), .awready(m_awready),
        .wvalid(m_wvalid), .wlast(m_wlast), .wready(m_wready),
        .bresp(m_bresp), .bvalid(m_bvalid), .bready(m_bready),
        .busy(trk_busy), .done(trk_done), .err(trk_err),
        .aw_cnt_o(trk_aw), .b_cnt_o(trk_b)
    );

    // ---- master channels ----
    reg [31:0] m_araddr_r, m_awaddr_r, m_wdata_r;
    reg        m_arvalid_r, m_awvalid_r, m_wvalid_r;

    assign m_araddr  = m_araddr_r;
    assign m_arvalid = m_arvalid_r;
    assign m_arlen   = 8'd0;
    assign m_rready  = 1'b1;
    assign m_awaddr  = m_awaddr_r;
    assign m_awvalid = m_awvalid_r;
    assign m_awlen   = 8'd0;
    assign m_wdata   = m_wdata_r;
    assign m_wvalid  = m_wvalid_r;
    assign m_wlast   = m_wvalid_r;

    // ---- FSM ----
    localparam [3:0] T_IDLE = 4'd0, T_LDIN = 4'd1, T_LDW = 4'd2, T_RUN = 4'd3,
                     T_STSET = 4'd4, T_STPUSH = 4'd5, T_WB = 4'd6, T_DONE = 4'd7,
                     T_LDB = 4'd8, T_LDM = 4'd9;

    reg [3:0] tst;
    integer   idx;

    always @(posedge clk) begin
        if (!rstn) begin
            tst <= T_IDLE; idx <= 0;
            m_araddr_r <= 0; m_arvalid_r <= 0;
            m_awaddr_r <= 0; m_awvalid_r <= 0;
            m_wdata_r  <= 0; m_wvalid_r  <= 0;
            ld_en <= 0; ld_sel <= 0; ld_addr <= 0; ld_data <= 0; ld_data32 <= 0;
            rd_addr <= 0; trk_start <= 0; layer_go <= 0;
            done_r <= 0; err_r <= 0; r_cycles <= 0;
        end
        else begin
            trk_start <= 1'b0;
            layer_go  <= 1'b0;
            ld_en     <= 1'b0;

            case (tst)
                T_IDLE: begin
                    if (kick) begin
                        done_r <= 1'b0; err_r <= 1'b0;
                        idx <= 0;
                        m_araddr_r  <= r_src_in;
                        m_arvalid_r <= 1'b1;
                        tst <= T_LDIN;
                    end
                end

                T_LDIN: begin
                    if (m_arvalid_r && m_arready)
                        m_arvalid_r <= 1'b0;
                    if (m_rvalid) begin
                        if (m_rresp != 2'b00) err_r <= 1'b1;
                        ld_en   <= 1'b1;
                        ld_sel  <= 1'b0;
                        ld_addr <= idx;
                        ld_data <= m_rdata[7:0];
                        if (idx == INSZ - 1) begin
                            idx <= 0;
                            m_araddr_r  <= r_src_w;
                            m_arvalid_r <= 1'b1;
                            tst <= T_LDW;
                        end
                        else begin
                            idx <= idx + 1;
                            m_araddr_r <= r_src_in + ((idx + 1) << 2);
                            m_arvalid_r <= 1'b1;
                        end
                    end
                end

                T_LDW: begin
                    if (m_arvalid_r && m_arready)
                        m_arvalid_r <= 1'b0;
                    if (m_rvalid) begin
                        if (m_rresp != 2'b00) err_r <= 1'b1;
                        ld_en   <= 1'b1;
                        ld_sel  <= 1'b1;
                        ld_addr <= idx;
                        ld_data <= m_rdata[7:0];
                        if (idx == WSZ - 1) begin
                            idx <= 0;
                            m_araddr_r  <= r_src_b;
                            m_arvalid_r <= 1'b1;
                            tst <= T_LDB;
                        end
                        else begin
                            idx <= idx + 1;
                            m_araddr_r  <= r_src_w + ((idx + 1) << 2);
                            m_arvalid_r <= 1'b1;
                        end
                    end
                end

                // bias and per-channel multiplier come from DDR too: they are
                // part of the layer blob, not build-time constants
                T_LDB: begin
                    if (m_arvalid_r && m_arready)
                        m_arvalid_r <= 1'b0;
                    if (m_rvalid) begin
                        if (m_rresp != 2'b00) err_r <= 1'b1;
                        ld_en     <= 1'b1;
                        ld_sel    <= 2'd2;
                        ld_addr   <= idx;
                        ld_data32 <= m_rdata;
                        if (idx == COUT - 1) begin
                            idx <= 0;
                            m_araddr_r  <= r_src_m;
                            m_arvalid_r <= 1'b1;
                            tst <= T_LDM;
                        end
                        else begin
                            idx <= idx + 1;
                            m_araddr_r  <= r_src_b + ((idx + 1) << 2);
                            m_arvalid_r <= 1'b1;
                        end
                    end
                end

                T_LDM: begin
                    if (m_arvalid_r && m_arready)
                        m_arvalid_r <= 1'b0;
                    if (m_rvalid) begin
                        if (m_rresp != 2'b00) err_r <= 1'b1;
                        ld_en     <= 1'b1;
                        ld_sel    <= 2'd3;
                        ld_addr   <= idx;
                        ld_data32 <= m_rdata;
                        if (idx == COUT - 1) begin
                            idx <= 0;
                            layer_go <= 1'b1;
                            tst <= T_RUN;
                        end
                        else begin
                            idx <= idx + 1;
                            m_araddr_r  <= r_src_m + ((idx + 1) << 2);
                            m_arvalid_r <= 1'b1;
                        end
                    end
                end

                T_RUN: begin
                    if (layer_done) begin
                        r_cycles  <= layer_cycles;
                        rd_addr   <= 0;
                        trk_start <= 1'b1;
                        idx       <= 0;
                        tst       <= T_STSET;
                    end
                end

                // present address + data for byte idx; the RAM read is
                // combinational so rd_addr must settle one cycle before the
                // data is pushed, hence the separate set/push states
                T_STSET: begin
                    rd_addr <= idx;
                    tst     <= T_STPUSH;
                end

                T_STPUSH: begin
                    m_awaddr_r  <= r_dst + (idx << 2);
                    m_wdata_r   <= {24'd0, layer_rd};
                    m_awvalid_r <= 1'b1;
                    m_wvalid_r  <= 1'b1;
                    if (m_awvalid_r && m_awready && m_wvalid_r && m_wready) begin
                        m_awvalid_r <= 1'b0;
                        m_wvalid_r  <= 1'b0;
                        if (idx == OSZ - 1) begin
                            idx <= 0;
                            tst <= T_WB;
                        end
                        else begin
                            idx <= idx + 1;
                            tst <= T_STSET;
                        end
                    end
                end

                T_WB: begin
                    if (trk_err) begin
                        err_r <= 1'b1;
                        tst   <= T_DONE;
                    end
                    else if (trk_done) begin
                        done_r <= 1'b1;
                        tst    <= T_DONE;
                    end
                end

                T_DONE: begin
                    if (kick) begin
                        done_r <= 1'b0; err_r <= 1'b0;
                        idx <= 0;
                        m_araddr_r  <= r_src_in;
                        m_arvalid_r <= 1'b1;
                        tst <= T_LDIN;
                    end
                end

                default: tst <= T_IDLE;
            endcase
        end
    end

    assign busy = (tst != T_IDLE) && (tst != T_DONE);
    assign done = done_r;
    assign err  = err_r;

endmodule
