// conv_engine_axil -- AXI4-Lite register file + AXI4 master DMA around
// conv_band_rt, i.e. the block the RISC-V core actually talks to.
//
// conv_engine_axi wraps the *fixed-shape* engine, whose geometry is baked in at
// elaboration.  With conv_band_rt the geometry arrives over the bus instead, so
// this wrapper carries the full register map from sw/acc_regs.h and nothing
// else changes: the read/write masters below are the ones already proven
// against a DDR model in tb_engine_axi.v, including the completion rule that
// `done` waits for every BRESP.
//
// Why a register file rather than a descriptor sequencer: an earlier acc_seq.v
// tried to walk a descriptor array in hardware, had multiple drivers, and was
// deleted.  One layer costs hundreds of thousands of cycles, so ~20 register
// writes per layer from the CPU is free.
`timescale 1ns/1ps

module conv_engine_axil #(
    parameter integer BANDW = 7168,    // band buffer, 64-bit words (56 KiB)
    parameter integer WBANK = 576,      // words per weight bank
    parameter integer TRM   = 8
)(
    input  wire        clk,
    input  wire        rstn,
    output reg         vid_wr_en,
    output reg [7:0]   vid_wr_addr,
    output reg [31:0]  vid_wr_data,
    output wire [7:0]  vid_rd_addr,
    output wire        vid_rd_en,
    input wire [31:0]  vid_rd_data,

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
    output reg         m_bready,

    output wire [4:0]  dbg_st,
    output wire        dbg_anom,
    output wire [31:0] dbg_snap
);

    assign m_arlen = 8'd0;
    assign m_awlen = 8'd0;
    assign m_wlast = 1'b1;          // single beat: WLAST on the only beat
    assign vid_rd_addr=s_araddr;
    assign vid_rd_en=s_arvalid && s_arready;

    // ---- configuration registers ----------------------------------------
    reg [15:0] r_cin, r_cout, r_inw, r_inh, r_outw, r_outh;
    reg [7:0]  r_k, r_stride, r_pad, r_act, r_tr;
    reg [4:0]  r_shift;
    reg [31:0] r_a, r_w, r_q, r_t, r_y;
    reg        go;

    // ---- load window: lets the CPU push the model into DDR ----------------
    // The CPU has no DDR master of its own (its masters only see the on-chip
    // RAM and peripherals), but the accelerator already owns one.  While a
    // layer is not running that master is idle, so three registers are enough
    // to stream a model image in: set ADDR, then write LO and HI for each
    // 64-bit word; ADDR auto-increments by 8.
    reg [31:0] ld_addr;          // next address, auto-increments by 8
    reg [31:0] ld_waddr;         // address of the word being written
    reg [31:0] ld_lo;
    reg [31:0] ld_hi;
    reg        ld_kick;          // one-cycle pulse after HI is written
    reg        ld_busy;
    reg [31:0] host_addr;
    reg        host_kick, host_busy, host_done, host_error;
    reg [63:0] host_data;
    reg        read_host;
    // ---- bulk window -------------------------------------------------------
    // Same DDR master, but the address walks itself and no per-word request is
    // needed: LO/HI write the next 64-bit word, RLO/RHI read the next one.
    // The A channel stalls while the previous DDR write is unacknowledged, so
    // the CPU never has to poll between words.  The single-word window above
    // keeps working unchanged.
    reg [31:0] bk_waddr, bk_raddr;
    reg [31:0] bk_lo;
    reg [15:0] bk_wlen;
    reg        bk_kick_r, bk_read, bk_ready, bk_err;
    reg        bk_write_seen;
    // Stable snapshot for the two-register AXI-Lite readout.  The DDR
    // response and the AXI-Lite RLO/RHI requests are independent clocked
    // transactions; do not expose the live synchronously-updated bk_word.
    reg [63:0] bk_rsp_word;
    // Bulk read status is owned by the read-master block. The register
    // interface communicates cursor reset/consume events as one-cycle pulses.
    reg        bk_reset_r, bk_consume_r;
    reg        run_active;
    reg        bulk_rd_pending;
    reg        bulk_rd_pending_hi;

    wire       busy, eng_done, eng_err;
    wire [31:0] cycles;

    wire [31:0] e_rd_addr;
    wire        e_rd_req;
    reg  [63:0] e_rd_data;
    reg         e_rd_valid;
    reg         e_rd_err;

    wire [31:0] eng_wr_addr;
    wire [63:0] eng_wr_data;
    wire        eng_wr_req;
    reg         e_wr_ack;
    reg         e_wr_err;

    // One DDR write port, two producers.  They cannot collide: the load window
    // is only used while the engine is idle (LAYER start is what makes it
    // busy), and the engine cannot assert wr_req outside a run.
    // Host addresses are bytes; the convolution engine exposes 64-bit words.
    wire [31:0] e_wr_addr = ld_kick ? ld_waddr :
                                     {eng_wr_addr[28:0],3'b000};
    wire [63:0] e_wr_data = ld_kick ? {ld_hi, ld_lo} : eng_wr_data;
    wire        e_wr_req  = ld_kick | eng_wr_req;

    conv_band_rt #(.BANDW(BANDW), .WBANK(WBANK), .TRM(TRM)) u_eng (
        .clk(clk), .rstn(rstn), .start(go), .busy(busy),
        .done(eng_done), .err(eng_err), .cycles(cycles),
        .p_cin(r_cin), .p_cout(r_cout),
        .p_in_w(r_inw), .p_in_h(r_inh),
        .p_out_w(r_outw), .p_out_h(r_outh),
        .p_k(r_k), .p_stride(r_stride), .p_pad(r_pad),
        .p_act(r_act[1:0]), .p_tr(r_tr), .p_shift(r_shift),
        .a_base(r_a), .w_base(r_w), .q_base(r_q), .t_base(r_t), .y_base(r_y),
        .rd_addr(e_rd_addr), .rd_req(e_rd_req), .rd_data(e_rd_data),
        .rd_valid(e_rd_valid), .rd_err(e_rd_err),
        .wr_addr(eng_wr_addr), .wr_data(eng_wr_data), .wr_req(eng_wr_req),
        .wr_ack(e_wr_ack), .wr_err(e_wr_err),
        .dbg_st(dbg_st), .dbg_anom(dbg_anom), .dbg_snap(dbg_snap)
    );

    // ---- read master -----------------------------------------------------
    localparam [2:0] R_IDLE = 3'd0, R_REQ = 3'd1, R_DATA = 3'd2;
    reg [2:0] rst_r;

    always @(posedge clk) begin
        if (!rstn) begin
            rst_r <= R_IDLE;
            m_araddr <= 32'd0; m_arvalid <= 1'b0; m_rready <= 1'b0;
            e_rd_data <= 64'd0; e_rd_valid <= 1'b0; e_rd_err <= 1'b0;
            read_host <= 1'b0;
            host_data <= 64'd0;
            host_done <= 1'b0;
            host_error <= 1'b0;
            bk_read <= 1'b0; bk_ready <= 1'b0; bk_err <= 1'b0;
            bk_rsp_word <= 64'd0;
        end
        else begin
            e_rd_valid <= 1'b0;
            e_rd_err   <= 1'b0;

            if (bk_reset_r) begin
                bk_read <= 1'b0;
                bk_ready <= 1'b0;
                bk_err <= 1'b0;
                bk_rsp_word <= 64'd0;
            end else case (rst_r)
            R_IDLE: begin
                if (e_rd_req || host_kick || bk_kick_r) begin
                    read_host <= host_kick;
                    bk_read   <= bk_kick_r && !host_kick;
                    if (bk_kick_r) bk_ready <= 1'b0;
                    if (host_kick) begin
                        host_done <= 1'b0;
                        host_error <= 1'b0;
                    end
                    m_araddr  <= bk_kick_r ? bk_raddr :
                                 host_kick ? host_addr :
                                 {e_rd_addr[28:0], 3'b000};   // word -> byte
                    m_arvalid <= 1'b1;
                    m_rready  <= 1'b0;
                    rst_r     <= R_REQ;
                end
            end
            R_REQ: begin
                if (m_arvalid && m_arready) begin
                    m_arvalid <= 1'b0;
                    m_rready <= 1'b1;
                    rst_r     <= R_DATA;
                end
            end
            default: begin
                if (m_rvalid) begin
                    if (bk_read) begin
                        bk_rsp_word <= m_rdata;
                        bk_ready <= 1'b1;
                        bk_err   <= (m_rresp != 2'b00);
                        // bk_read denotes an outstanding bulk prefetch, not
                        // the lifetime of the bulk cursor.  Clear it once
                        // the response is captured so a later STATUS poll
                        // can arm the next word.
                        bk_read  <= 1'b0;
                    end else if (read_host) begin
                        host_data <= m_rdata;
                        host_done <= 1'b1;
                        host_error <= (m_rresp != 2'b00);
                    end else begin
                        e_rd_data  <= m_rdata;
                        e_rd_valid <= 1'b1;
                        if (m_rresp != 2'b00) e_rd_err <= 1'b1;
                    end
                    m_rready   <= 1'b0;
                    rst_r      <= R_IDLE;
                end
            end
            endcase
            if (bk_consume_r) bk_ready <= 1'b0;

            // A new request can only appear after R_IDLE: the engine waits for
            // rd_valid before it issues another one, so no queue is needed.
        end
    end

    // ---- write master ----------------------------------------------------
    localparam [2:0] W_IDLE = 3'd0, W_AW = 3'd1, W_RESP = 3'd2;
    reg [2:0] wst;
    reg       b_bad;
    reg       clr_bad;              // single-cycle pulse from the control side

    always @(posedge clk) begin
        if (!rstn) begin
            wst <= W_IDLE;
            m_awaddr <= 32'd0; m_awvalid <= 1'b0;
            m_wdata  <= 64'd0; m_wvalid  <= 1'b0;
            m_bready <= 1'b0;
            e_wr_ack <= 1'b0; e_wr_err <= 1'b0;
            b_bad <= 1'b0;
        end
        else begin
            e_wr_ack <= 1'b0;
            e_wr_err <= 1'b0;
            // b_bad is only ever assigned here; an earlier version also cleared
            // it from the control block, which made it a two-driver register
            if (clr_bad) b_bad <= 1'b0;

            case (wst)
            W_IDLE: begin
                if (e_wr_req) begin
                    m_awaddr  <= e_wr_addr;
                    m_wdata   <= e_wr_data;
                    m_awvalid <= 1'b1;
                    m_wvalid  <= 1'b1;
                    m_bready  <= 1'b0;
                    wst       <= W_AW;
                end
            end
            W_AW: begin
                if (m_awvalid && m_awready) m_awvalid <= 1'b0;
                if (m_wvalid && m_wready)   m_wvalid  <= 1'b0;
                if (!m_awvalid && !m_wvalid) begin
                    m_bready <= 1'b1;
                    wst <= W_RESP;
                end
            end
            default: begin
                if (m_bvalid) begin
                    m_bready <= 1'b0;
                    // the only place a write becomes durable: BRESP
                    if (m_bresp == 2'b00) e_wr_ack <= 1'b1;
                    else begin
                        b_bad    <= 1'b1;
                        e_wr_err <= 1'b1;
                    end
                    wst <= W_IDLE;
                end
            end
            endcase
        end
    end

    // ---- AXI4-Lite register file -----------------------------------------
    // AW and W are independent channels. Join one buffered item from each,
    // and retain the response until the master accepts it.
    reg [5:0]  aw_idx;
    reg aw_have, w_have;
    reg [31:0] w_hold;
    reg        s_bvalid_r, s_rvalid_r;
    wire [5:0] wr_idx = aw_idx;
    wire commit = aw_have && w_have && !s_bvalid_r;
    wire unavailable = busy || run_active || go || ld_busy || ld_kick ||
                       host_busy || host_kick || (wst != W_IDLE) ||
                       (rst_r != R_IDLE);
    reg [1:0] bresp_r;
    reg [31:0] s_rdata_r;
    reg        done_r, err_r;

    assign s_awready = !aw_have && !s_bvalid_r && !ld_busy && !ld_kick;
    assign s_wready  = !w_have && !s_bvalid_r && !ld_busy && !ld_kick;
    // Keep ARREADY independent of DDR response timing.  If a bulk word is
    // not ready yet, the address is remembered and the R response is emitted
    // once the prefetch completes.  This obeys AXI-Lite's requirement that a
    // master may hold ARVALID until a stable READY handshake.
    assign s_arready = !s_rvalid_r && !bulk_rd_pending && !bk_reset_r;
    assign s_bresp   = bresp_r;
    assign s_rresp   = 2'b00;
    assign s_bvalid  = s_bvalid_r;
    assign s_rvalid  = s_rvalid_r;
    assign s_rdata   = s_rdata_r;

    always @(posedge clk) begin
        if (!rstn) begin
            aw_idx <= 6'd0;
            vid_wr_en<=0;vid_wr_addr<=0;vid_wr_data<=0;
            aw_have <= 1'b0; w_have <= 1'b0; w_hold <= 0; bresp_r <= 0;
            host_addr <= 0; host_kick <= 0; host_busy <= 0; run_active <= 0;
            r_cin <= 16'd0; r_cout <= 16'd0; r_inw <= 16'd0; r_inh <= 16'd0;
            r_outw <= 16'd0; r_outh <= 16'd0;
            r_k <= 8'd3; r_stride <= 8'd1; r_pad <= 8'd1;
            r_act <= 8'd0; r_tr <= 8'd1; r_shift <= 5'd15;
            r_a <= 0; r_w <= 0; r_q <= 0; r_t <= 0; r_y <= 0;
            go <= 1'b0;
            clr_bad <= 1'b0;
            ld_kick <= 1'b0;
            ld_addr <= 32'd0; ld_waddr <= 32'd0; ld_lo <= 32'd0; ld_hi <= 32'd0;
            ld_kick <= 1'b0; ld_busy <= 1'b0;
            bk_kick_r <= 1'b0;
            bk_reset_r <= 1'b0; bk_consume_r <= 1'b0;
            bk_write_seen <= 1'b0;
            bk_waddr <= 32'd0; bk_raddr <= 32'd0; bk_lo <= 32'd0;
            bk_wlen <= 16'd0;
            bulk_rd_pending <= 1'b0;
            bulk_rd_pending_hi <= 1'b0;
            s_bvalid_r <= 1'b0; s_rvalid_r <= 1'b0; s_rdata_r <= 32'd0;
            done_r <= 1'b0; err_r <= 1'b0;
        end
        else begin
            go <= 1'b0;
            ld_kick <= 1'b0;
            bk_kick_r <= 1'b0;
            bk_reset_r <= 1'b0;
            bk_consume_r <= 1'b0;
            // A bulk read may stall the A channel before any data is ready, so
            // the prefetch cannot be armed from the response case: arm it here,
            // where it is evaluated every cycle.
            if(s_arvalid && s_araddr[7:2]==6'd43 && !bk_ready && !bk_read &&
               rst_r==R_IDLE && !busy && !run_active) bk_kick_r <= 1'b1;
            clr_bad <= 1'b0;
            host_kick <= 1'b0;
            vid_wr_en<=0;

            if (s_awvalid && s_awready) begin
                aw_idx <= s_awaddr[7:2];
                aw_have <= 1'b1;
            end
            if (s_wvalid && s_wready) begin
                w_hold <= s_wdata;
                w_have <= 1'b1;
            end

            if (commit) begin
                aw_have <= 1'b0;
                w_have <= 1'b0;
                bresp_r <= 2'b00;
                s_bvalid_r <= 1'b1;
                if (unavailable) begin
                    bresp_r <= 2'b10;
                end else begin
                case (wr_idx)
                6'd0:  ;                                   // CTRL, handled below
                6'd4:  r_cin    <= w_hold[15:0];
                6'd5:  r_cout   <= w_hold[15:0];
                6'd6:  r_inw    <= w_hold[15:0];
                6'd7:  r_inh    <= w_hold[15:0];
                6'd8:  r_outw   <= w_hold[15:0];
                6'd9:  r_outh   <= w_hold[15:0];
                6'd10: r_k      <= w_hold[7:0];
                6'd11: r_stride <= w_hold[7:0];
                6'd12: r_pad    <= w_hold[7:0];
                6'd13: r_act    <= w_hold[1:0];
                6'd14: r_tr     <= w_hold[7:0];
                6'd15: r_shift  <= w_hold[4:0];
                6'd16: r_a      <= w_hold;
                6'd17: r_w      <= w_hold;
                6'd18: r_q      <= w_hold;
                6'd19: r_t      <= w_hold;
                6'd20: r_y      <= w_hold;
                6'd21: ld_addr  <= w_hold;
                6'd22: ld_lo    <= w_hold;
                6'd23: begin                                // ACC_LOAD_HI
                           ld_hi   <= w_hold;
                           ld_waddr<= ld_addr;
                           ld_addr <= ld_addr + 32'd8;
                           ld_kick <= 1'b1;
                       end
                6'd24: host_addr <= w_hold;
                6'd25: if(w_hold[0]) begin host_kick <= 1; host_busy <= 1; end
                6'd40: begin                       // BULK_ADDR: arm both pointers
                           bk_waddr <= w_hold; bk_raddr <= w_hold;
                           bk_wlen  <= 16'd0;  bk_reset_r <= 1'b1;
                           bk_write_seen <= 1'b0;
                           clr_bad <= 1'b1;
                       end
                6'd41: bk_lo <= w_hold;            // BULK_LO
                6'd42: begin                       // BULK_HI commits the word
                           ld_lo   <= bk_lo;
                           ld_hi   <= w_hold;
                           ld_waddr<= bk_waddr;
                           ld_kick <= 1'b1;
                           bk_write_seen <= 1'b1;
                           bk_waddr<= bk_waddr + 32'd8;
                           if(bk_wlen!=16'hffff) bk_wlen <= bk_wlen + 16'd1;
                       end
                default: if(wr_idx>=29) begin
                    vid_wr_en<=1;vid_wr_addr<={wr_idx,2'b00};vid_wr_data<=w_hold;
                end
                endcase
                // START is a level that is consumed once the engine takes it,
                // so a master that keeps CTRL asserted cannot retrigger.
                if (wr_idx == 6'd0 && w_hold[0]) begin
                    go <= 1'b1;
                    run_active <= 1'b1;
                    done_r <= 1'b0;
                    err_r <= 1'b0;
                end
                end
            end
            else if (s_bvalid_r && s_bready)
                s_bvalid_r <= 1'b0;

            if (s_arvalid && s_arready) begin
                case (s_araddr[7:2])
                6'd1: s_rdata_r <= {29'd0, err_r, done_r, unavailable};
                6'd2: s_rdata_r <= cycles;
                6'd3: s_rdata_r <= 32'h0001_0000;
                6'd25: s_rdata_r <= {29'd0,host_error,host_done,host_busy};
                6'd26: s_rdata_r <= host_data[31:0];
                6'd27: s_rdata_r <= host_data[63:32];
                6'd28: s_rdata_r <= {30'd0,b_bad,ld_busy || ld_kick};
                6'd43: begin                       // BULK_RLO
                           if (bk_ready)
                               s_rdata_r <= bk_rsp_word[31:0];
                           else begin
                               bulk_rd_pending <= 1'b1;
                               bulk_rd_pending_hi <= 1'b0;
                               if (!bk_read && rst_r==R_IDLE &&
                                   !busy && !run_active)
                                   bk_kick_r <= 1'b1;
                           end
                       end
                6'd44: begin                       // BULK_RHI: word consumed
                           if (bk_ready) begin
                               s_rdata_r <= bk_rsp_word[63:32];
                               bk_raddr  <= bk_raddr + 32'd8;
                               bk_consume_r <= 1'b1;
                           end else begin
                               bulk_rd_pending <= 1'b1;
                               bulk_rd_pending_hi <= 1'b1;
                               if (!bk_read && rst_r==R_IDLE &&
                                   !busy && !run_active)
                                   bk_kick_r <= 1'b1;
                           end
                       end
                6'd45: begin
                           s_rdata_r <= {bk_err || b_bad,bk_ready,ld_busy||ld_kick,
                                         13'd0,bk_wlen};
                           // Status polling is also a legal way to request
                           // the first read.  Unlike BULK_ADDR this cannot
                           // collide with a write stream: a writer does not
                           // need to poll until all WHI commits are done.
                           if(!bk_write_seen && !bk_ready && !bk_read &&
                              rst_r==R_IDLE &&
                              !busy && !run_active)
                               bk_kick_r <= 1'b1;
                        end
                default: s_rdata_r <= s_araddr[7:2]>=29 ? vid_rd_data : 32'd0;
                endcase
                if (!((s_araddr[7:2]==6'd43 || s_araddr[7:2]==6'd44) &&
                      !bk_ready))
                    s_rvalid_r <= 1'b1;
            end
            else if (s_rvalid_r && s_rready)
                s_rvalid_r <= 1'b0;

            if (bulk_rd_pending && bk_ready && !s_rvalid_r) begin
                s_rdata_r <= bulk_rd_pending_hi ? bk_rsp_word[63:32] :
                                                     bk_rsp_word[31:0];
                s_rvalid_r <= 1'b1;
                bulk_rd_pending <= 1'b0;
                if (bulk_rd_pending_hi) begin
                    bk_raddr <= bk_raddr + 32'd8;
                    bk_consume_r <= 1'b1;
                end
            end

            // clear sticky status when a new layer starts.  This runs after the
            // eng_err assignment below on purpose: the engine still holds the
            // previous layer's err for one cycle after start, and without the
            // ordering a fresh layer would latch the old error.
            if (go && !busy) begin
                done_r  <= 1'b0;
                err_r   <= 1'b0;
                clr_bad <= 1'b1;
            end
            // the load window drives the engine's write port while the engine
            // itself is idle; both can never be active in the same cycle.
            // ld_kick is cleared at the top of this block, not here: a default
            // assignment after the register-write case silently cancelled every
            // kick, so nothing was ever written.
            if (ld_kick)
                ld_busy <= 1'b1;
            if (ld_busy && (e_wr_ack || e_wr_err))
                ld_busy <= 1'b0;
            if (host_busy && read_host && m_rvalid && m_rready)
                host_busy <= 1'b0;

            if (run_active && !go && eng_done) begin
                done_r <= 1'b1;
                run_active <= 1'b0;
            end
            if ((run_active && !go && eng_err) || b_bad) begin
                err_r <= 1'b1;
                done_r <= 1'b0;
                run_active <= 1'b0;
            end
        end
    end

endmodule
