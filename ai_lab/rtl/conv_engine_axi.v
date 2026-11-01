// conv_engine_axi -- AXI4 wrapper that turns conv_band_engine into a bus slave
// the RISC-V core can drive.
//
// Two things this module adds over the engine:
//
//   * a read master: the engine asks for one 64-bit word at a time
//     (rd_addr/rd_req -> rd_data/rd_valid); each request becomes one single-beat
//     AXI4 read.  Single-beat keeps the first board bring-up debuggable; bursts
//     are a bandwidth optimisation, not a correctness requirement.
//   * a write master with the completion rule proven in T18: `done` is only
//     raised after every write has been answered by BRESP and all of them were
//     OKAY.  Last-beat-accepted is not completion.
//
// The control side is a plain register file at a fixed base (sw/acc_regs.h):
// writing CTRL.start kicks one layer described by the address registers.
`timescale 1ns/1ps

module conv_engine_axi #(
    parameter integer CINPAD = 32,
    parameter integer COUT   = 32,
    parameter integer IN_W   = 40,
    parameter integer IN_H   = 40,
    parameter integer K      = 3,
    parameter integer STRIDE = 1,
    parameter integer ACT    = 1,
    parameter integer TR     = 8,
    parameter integer PADP   = 1,
    parameter integer SHIFT  = 15
)(
    input  wire        clk,
    input  wire        rstn,

    // ---- AXI4-Lite slave: control / status ----
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

    // ---- AXI4 master: DDR ----
    output reg  [31:0] m_araddr,
    output reg         m_arvalid,
    input  wire        m_arready,
    output wire [7:0]  m_arlen,
    input  wire [63:0] m_rdata,
    input  wire        m_rvalid,
    output reg         m_rready,
    input  wire [1:0]  m_rresp,

    output reg  [31:0] m_awaddr,
    output reg         m_awvalid,
    input  wire        m_awready,
    output wire [7:0]  m_awlen,
    output reg  [63:0] m_wdata,
    output reg         m_wvalid,
    output wire        m_wlast,
    input  wire        m_wready,
    input  wire [1:0]  m_bresp,
    input  wire        m_bvalid,
    output reg         m_bready
);

    assign m_arlen = 8'd0;
    assign m_awlen = 8'd0;
    assign m_wlast = 1'b1;          // single beat: WLAST on the only beat

    // ---- engine ----------------------------------------------------------
    reg         go;
    wire        busy, eng_done, eng_err;
    wire [31:0] cycles;

    reg  [31:0] r_a, r_w, r_q, r_y, r_t;

    wire [31:0] e_rd_addr;
    wire        e_rd_req;
    reg  [63:0] e_rd_data;
    reg         e_rd_valid;
    reg         e_rd_err;

    wire [31:0] e_wr_addr;
    wire [63:0] e_wr_data;
    wire        e_wr_req;
    reg         e_wr_ack;
    reg         e_wr_err;

    conv_band_engine #(
        .CINPAD(CINPAD), .COUT(COUT), .IN_W(IN_W), .IN_H(IN_H), .K(K),
        .STRIDE(STRIDE), .ACT(ACT), .TR(TR), .PADP(PADP), .SHIFT(SHIFT)
    ) u_eng (
        .clk(clk), .rstn(rstn), .start(go), .busy(busy), .done(eng_done),
        .err(eng_err), .cycles(cycles),
        .a_base(r_a), .w_base(r_w), .q_base(r_q), .t_base(r_t), .y_base(r_y),
        .rd_addr(e_rd_addr), .rd_req(e_rd_req), .rd_data(e_rd_data),
        .rd_valid(e_rd_valid), .rd_err(e_rd_err),
        .wr_addr(e_wr_addr), .wr_data(e_wr_data), .wr_req(e_wr_req),
        .wr_ack(e_wr_ack), .wr_err(e_wr_err)
    );

    // ---- read master -----------------------------------------------------
    localparam [2:0] R_IDLE = 3'd0, R_REQ = 3'd1, R_WAIT = 3'd2, R_DATA = 3'd3;
    reg [2:0] rst_r;
    reg       rd_pending;

    always @(posedge clk) begin
        if (!rstn) begin
            rst_r <= R_IDLE;
            m_araddr <= 32'd0; m_arvalid <= 1'b0; m_rready <= 1'b0;
            e_rd_data <= 64'd0; e_rd_valid <= 1'b0; e_rd_err <= 1'b0;
            rd_pending <= 1'b0;
        end
        else begin
            e_rd_valid <= 1'b0;
            e_rd_err   <= 1'b0;

            case (rst_r)
            R_IDLE: begin
                // word address -> byte address
                if (e_rd_req) begin
                    m_araddr  <= {e_rd_addr[28:0], 3'b000};
                    m_arvalid <= 1'b1;
                    m_rready  <= 1'b1;
                    rd_pending <= 1'b1;
                    rst_r <= R_REQ;
                end
            end
            R_REQ: begin
                if (m_arvalid && m_arready) begin
                    m_arvalid <= 1'b0;
                    rst_r <= R_DATA;
                end
            end
            R_DATA: begin
                if (m_rvalid) begin
                    e_rd_data  <= m_rdata;
                    e_rd_valid <= 1'b1;
                    if (m_rresp != 2'b00) e_rd_err <= 1'b1;
                    m_rready   <= 1'b0;
                    rd_pending <= 1'b0;
                    rst_r <= R_IDLE;
                end
            end
            default: rst_r <= R_IDLE;
            endcase

            // a request that arrives while a read is in flight is held by the
            // engine (it waits for valid), so a new request can only appear
            // after R_IDLE; no queue is needed for the verified access pattern.
        end
    end

    // ---- write master ----------------------------------------------------
    localparam [2:0] W_IDLE = 3'd0, W_AW = 3'd1, W_DATA = 3'd2, W_RESP = 3'd3;
    reg [2:0] wst;
    reg       b_ok, b_bad;

    always @(posedge clk) begin
        if (!rstn) begin
            wst <= W_IDLE;
            m_awaddr <= 32'd0; m_awvalid <= 1'b0;
            m_wdata  <= 64'd0; m_wvalid  <= 1'b0;
            m_bready <= 1'b0;
            e_wr_ack <= 1'b0; e_wr_err <= 1'b0;
            b_ok <= 1'b0; b_bad <= 1'b0;
        end
        else begin
            e_wr_ack <= 1'b0;
            e_wr_err <= 1'b0;

            case (wst)
            W_IDLE: begin
                if (e_wr_req) begin
                    m_awaddr  <= {e_wr_addr[28:0], 3'b000};
                    m_wdata   <= e_wr_data;
                    m_awvalid <= 1'b1;
                    m_wvalid  <= 1'b1;
                    m_bready  <= 1'b1;
                    wst <= W_AW;
                end
            end
            W_AW: begin
                if (m_awvalid && m_awready) m_awvalid <= 1'b0;
                if (m_wvalid && m_wready)   m_wvalid  <= 1'b0;
                if (!m_awvalid && !m_wvalid) wst <= W_RESP;
            end
            W_RESP: begin
                if (m_bvalid) begin
                    m_bready <= 1'b0;
                    if (m_bresp == 2'b00) begin
                        b_ok <= 1'b1;
                        e_wr_ack <= 1'b1;      // only now is the write durable
                    end
                    else begin
                        b_bad <= 1'b1;
                        e_wr_err <= 1'b1;
                        e_wr_ack <= 1'b1;      // release the engine, but flagged
                    end
                    wst <= W_IDLE;
                end
            end
            default: wst <= W_IDLE;
            endcase
        end
    end

    // ---- control / status ------------------------------------------------
    reg [31:0] s_rdata_r;
    reg        s_bvalid_r, s_rvalid_r;
    reg        done_r, err_r;
    reg        kick;

    assign s_awready = 1'b1;
    assign s_wready  = 1'b1;
    assign s_arready = 1'b1;
    assign s_bresp   = 2'b00;
    assign s_rresp   = 2'b00;
    assign s_bvalid  = s_bvalid_r;
    assign s_rvalid  = s_rvalid_r;
    assign s_rdata   = s_rdata_r;

    wire start_ack = kick && (busy || eng_done);

    always @(posedge clk) begin
        if (!rstn) begin
            r_a <= 0; r_w <= 0; r_q <= 0; r_y <= 0; r_t <= 0;
            kick <= 1'b0; go <= 1'b0;
            s_bvalid_r <= 1'b0; s_rvalid_r <= 1'b0; s_rdata_r <= 32'd0;
            done_r <= 1'b0; err_r <= 1'b0;
        end
        else begin
            go <= 1'b0;

            if (s_awvalid && s_awready) begin
                case (s_awaddr[7:2])
                    6'd0: kick <= s_wdata[0];
                    6'd2: r_a  <= s_wdata;
                    6'd3: r_w  <= s_wdata;
                    6'd4: r_y  <= s_wdata;
                    6'd7: r_q  <= s_wdata;
                    6'd8: r_t  <= s_wdata;
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
                    6'd5: s_rdata_r <= cycles;
                    6'd6: s_rdata_r <= 32'h0001_0000;
                    default: s_rdata_r <= 32'd0;
                endcase
                s_rvalid_r <= 1'b1;
            end
            else if (s_rvalid_r && s_rready)
                s_rvalid_r <= 1'b0;

            // ---- engine command and completion ----
            if (kick && !busy && !go) begin
                done_r <= 1'b0;
                err_r  <= 1'b0;
                b_ok   <= 1'b0;
                b_bad  <= 1'b0;
                go     <= 1'b1;
            end

            if (eng_done) begin
                done_r <= 1'b1;
                if (eng_err || b_bad) err_r <= 1'b1;
            end
            if (eng_err) err_r <= 1'b1;
        end
    end

endmodule
