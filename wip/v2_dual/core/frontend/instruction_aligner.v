// -----------------------------------------------------------------------------
// core_instruction_aligner.v -- 64 位取指块 + 双指令对齐 (V2)
//
// 为什么取指块从 32 位改成 64 位:
//   双发射要每拍喂两条指令。32 位块一拍只给 4 字节, 两条 32 位指令要 8 字节,
//   供给永远只有 1 条/拍, 后面配得再宽也没用。参考设计取指也是 64 位。
//   改成 64 位块后, 一拍能切出 2 条 32 位指令或 4 条 RVC。
//
// 为什么块地址按 1 递增而不是按指令长度:
//   取指是 "地址 -> 数据 -> 下一地址" 的串行环。块地址与指令长度无关, 才能持续
//   流水; 指令边界由对齐器从块内切。
//
// 为什么需要 16 字节窗口:
//   RVC 允许 32 位指令从 2 字节边界开始 (pc[2:0]=2), 两条 32 位指令共 10 字节,
//   可能跨到第 2 个块。所以窗口 = {blk[rd+1], blk[rd]} 共 16 字节, 按 pc[2:0]
//   右移后至少还剩 9 字节, 足够两条指令。跨块时必须校验下一块的 tag 连续,
//   否则会把别的地址的数据当指令 (V1 踩过, 见 mistakes 记录)。
//
// 输出: 每拍 0/1/2 条, 由上层给出的 space (缓冲剩余空间) 限制。
// -----------------------------------------------------------------------------
`include "core_config.vh"

module core_instruction_aligner (
    input  wire        clk,
    input  wire        rst,

    input  wire        redirect,
    input  wire [31:0] redirect_pc,
    input  wire [2:0]  space,           // 下游缓冲剩余空间 0..4

    output wire [31:0] cur_pc,          // 下一条要输出的指令地址 (中断取 epc 用)
    output wire [1:0]  out_n,           // 本拍输出条数

    output wire [31:0] o0_pc,
    output wire [31:0] o0_instr,
    output wire [31:0] o0_raw,
    output wire        o0_rvc,
    output wire        o0_ill,

    output wire [31:0] o1_pc,
    output wire [31:0] o1_instr,
    output wire [31:0] o1_raw,
    output wire        o1_rvc,
    output wire        o1_ill,

    output wire [31:0] mem_addr,
    output wire        mem_req,
    input  wire        mem_ready,
    input  wire        mem_rvalid,      // 上一拍 A 口真的给了取指 (没被 store 抢)
    input  wire [63:0] mem_rdata
);
    // ------------------------------ 取指块队列 -------------------------------
    reg [63:0] fb_data [0:3];
    reg [12:0] fb_tag  [0:3];
    reg [1:0]  rd, wr;
    reg [2:0]  cnt;

    reg [12:0] fpc;                     // 下一个要取的块号
    reg [12:0] pend_tag;
    reg        pend_vld;

    reg [31:0] pc_q;

    wire [12:0] want_tag  = pc_q[15:3];
    wire [2:0]  off       = pc_q[2:0];
    wire [12:0] redir_tag = redirect_pc[15:3];

    wire        head_ok  = (cnt != 3'd0) && (fb_tag[rd] == want_tag);
    wire        have_nxt = (cnt >= 3'd2) && (fb_tag[rd + 2'd1] == (fb_tag[rd] + 13'd1));

    // ------------------------------ 16 字节窗口 ------------------------------
    wire [63:0]  blk0 = fb_data[rd];
    wire [63:0]  blk1 = fb_data[rd + 2'd1];
    wire [127:0] win  = {blk1, blk0} >> {off, 3'b000};

    wire [4:0] avail = have_nxt ? (5'd16 - {2'd0, off}) : (5'd8 - {2'd0, off});

    // ------------------------------ 第 1 条 ----------------------------------
    wire [15:0] hw0     = win[15:0];
    wire        is32_0  = (hw0[1:0] == 2'b11);
    wire [2:0]  len0    = is32_0 ? 3'd4 : 3'd2;   // 必须 3 位: 2 位放不下 4

    wire [31:0] rvc0_32;
    wire        rvc0_bad;

    core_rvc_decoder u_rvc0 (
        .inst    (hw0),
        .instr32 (rvc0_32),
        .illegal (rvc0_bad)
    );

    // ------------------------------ 第 2 条 ----------------------------------
    wire [127:0] win1   = win >> {len0, 3'b000};
    wire [15:0]  hw1    = win1[15:0];
    wire         is32_1 = (hw1[1:0] == 2'b11);
    wire [2:0]   len1   = is32_1 ? 3'd4 : 3'd2;

    wire [31:0] rvc1_32;
    wire        rvc1_bad;

    core_rvc_decoder u_rvc1 (
        .inst    (hw1),
        .instr32 (rvc1_32),
        .illegal (rvc1_bad)
    );

    wire ok0 = head_ok && (avail >= {2'd0, len0});
    wire ok1 = ok0     && (avail >= ({2'd0, len0} + {2'd0, len1}));

    assign out_n = (space == 3'd0) ? 2'd0
                 : (ok1 && (space >= 3'd2)) ? 2'd2
                 : ok0 ? 2'd1
                 :       2'd0;

    assign cur_pc = pc_q;

    assign o0_pc    = pc_q;
    assign o0_instr = is32_0 ? win[31:0] : rvc0_32;
    assign o0_raw   = is32_0 ? win[31:0] : {16'd0, hw0};
    assign o0_rvc   = ~is32_0;
    assign o0_ill   = is32_0 ? 1'b0 : rvc0_bad;

    assign o1_pc    = pc_q + {29'd0, len0};
    assign o1_instr = is32_1 ? win1[31:0] : rvc1_32;
    assign o1_raw   = is32_1 ? win1[31:0] : {16'd0, hw1};
    assign o1_rvc   = ~is32_1;
    assign o1_ill   = is32_1 ? 1'b0 : rvc1_bad;

    // ------------------------------ pc 推进 ----------------------------------
    wire [31:0] pc_after = pc_q + {29'd0, len0} +
                           ((out_n == 2'd2) ? {29'd0, len1} : 32'd0);
    wire        advance  = (out_n != 2'd0);

    // 一次最多消费 10 字节, 因此最多跨 1 个块
    wire [12:0] nxt_tag = pc_after[15:3];
    wire        do_pop  = advance && (cnt != 3'd0) && (nxt_tag != want_tag);

    // ------------------------------ 取指请求 ---------------------------------
    // 取指响应无效 = 上一拍 A 口被 store 抢走。数据属于别的地址, 必须丢弃重发。
    wire        retry      = pend_vld & ~mem_rvalid;
    wire        pend_want  = pend_vld & (pend_tag == want_tag);
    wire        need_head  = ~head_ok & ~pend_want;
    wire        clear_fifo = need_head & (cnt != 3'd0);

    wire [2:0]  inflight   = cnt + {2'd0, pend_vld};
    wire        issue      = retry || clear_fifo || redirect || (inflight < 3'd3);
    wire [12:0] issue_tag  = redirect   ? redir_tag
                           : clear_fifo ? want_tag
                           : retry      ? pend_tag
                           :              fpc;

    assign mem_addr = {issue_tag, 3'b000};
    assign mem_req  = issue;

    wire do_push = pend_vld;

    always @(posedge clk) begin
        if (rst) begin
            rd <= 2'd0; wr <= 2'd0; cnt <= 3'd0;
            fpc <= 13'd0; pend_tag <= 13'd0; pend_vld <= 1'b0;
            pc_q <= `CFG_RESET_VECTOR;
        end else if (redirect) begin
            rd  <= 2'd0;
            wr  <= 2'd0;
            cnt <= 3'd0;
            fpc <= redir_tag + 13'd1;
            pend_tag <= redir_tag;
            pend_vld <= mem_ready;
            pc_q <= redirect_pc;
        end else if (clear_fifo) begin
            rd  <= 2'd0;
            wr  <= 2'd0;
            cnt <= 3'd0;
            fpc <= want_tag + 13'd1;
            pend_tag <= want_tag;
            pend_vld <= mem_ready;
        end else begin
            if (advance) pc_q <= pc_after;

            if (do_push && mem_rvalid && ((cnt - {2'd0, do_pop}) < 3'd4)) begin
                fb_data[wr] <= mem_rdata;
                fb_tag[wr]  <= pend_tag;
                wr <= wr + 2'd1;
            end

            if (do_pop) rd <= rd + 2'd1;

            case ({do_push & mem_rvalid, do_pop})
                2'b10:   cnt <= cnt + 3'd1;
                2'b01:   cnt <= cnt - 3'd1;
                default: cnt <= cnt;
            endcase

            if (issue && mem_ready) begin
                pend_tag <= issue_tag;
                pend_vld <= 1'b1;
                if (!retry) fpc <= issue_tag + 13'd1;
            end else begin
                pend_vld <= 1'b0;
            end
        end
    end
endmodule
