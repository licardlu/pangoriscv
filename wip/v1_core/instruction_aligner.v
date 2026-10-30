// -----------------------------------------------------------------------------
// core_instruction_aligner.v -- 取指块缓冲 + RVC 切分
//
// 为什么取指地址要按"块"递增而不是按指令长度:
//   取指是 地址 -> 数据 -> 下一个地址 的串行环。若下一条地址要靠本条指令长度
//   才能算, 数据没回来之前发不出下一次读, 每两条指令白丢一拍。
//   块地址按 1 递增 (与指令长度无关), 取指就能持续流水, 对齐器再从块内切指令。
//
// 为什么是 4 深队列而不是 cur/nxt 两格:
//   32 位指令每条占满一个 4 字节块, 要跑满 1 IPC 就必须每拍取一块。
//   两级缓冲在"读延迟 1 拍 + 只允许一个在途"时只能做到 0.5 块/拍, 实测 IPC 被
//   压到 0.33。改成 4 深队列 + 每拍可发新请求后, 供块速率回到 1 块/拍。
//
// 任何指令都不跨块: 32 位指令 4 字节对齐, 16 位指令 2 字节对齐, 块宽 4 字节。
// -----------------------------------------------------------------------------

module core_instruction_aligner (
    input  wire        clk,
    input  wire        rst,

    input  wire [31:0] pc,
    input  wire        consume,
    input  wire [31:0] pc_next,
    input  wire        redirect,
    input  wire [31:0] redirect_pc,

    output wire [31:0] instr32,
    output wire [31:0] instr_raw,
    output wire        instr_rvc,
    output wire        instr_illegal,
    output wire        valid,

    output wire [31:0] mem_addr,
    output wire        mem_req,
    input  wire        mem_ready,
    input  wire        mem_rvalid,      // 上一拍 A 口真的给了取指 (没被 store 抢)
    input  wire [31:0] mem_rdata
);
    // ------------------------------ 取指队列 ---------------------------------
    reg [31:0] fb_data [0:3];
    reg [13:0] fb_tag  [0:3];
    reg [1:0]  rd, wr;
    reg [2:0]  cnt;

    reg [13:0] fpc;          // 下一个要取的块号
    reg [13:0] pend_tag;
    reg        pend_vld;

    wire [13:0] want_tag  = pc[15:2];
    wire [13:0] redir_tag = redirect_pc[15:2];

    wire [13:0] head_tag = fb_tag[rd];
    wire        hit      = (cnt != 3'd0) && (head_tag == want_tag);
    // 队列为空但正好有一笔刚好落在本块的取指数据回来: 直接旁路, 省两拍
    wire        bypass   = (cnt == 3'd0) && pend_vld && mem_rvalid && (pend_tag == want_tag);
    wire        hit_eff  = hit || bypass;

    // ------------------------------ 块内切指令 -------------------------------
    // 关键: 有 C 扩展时, 32 位指令允许从 2 字节边界开始 (RVC 与 32 位指令可任意
    // 混排), 所以 offset=2 的 32 位指令会跨到下一个取指块。这里用队列里的下一块
    // 拼出完整指令; 下一块还没到时拉低 valid 等它。
    wire [31:0] blk   = bypass ? mem_rdata : fb_data[rd];
    wire [31:0] blk_n = fb_data[rd + 2'd1];

    wire [15:0] hw   = pc[1] ? blk[31:16] : blk[15:0];
    wire        is32 = (hw[1:0] == 2'b11);
    wire        cross_blk = pc[1] & is32;
    // 跨块拼接必须确认"下一格确实是下一个块"。少了这个判断, 队列里那格若不是
    // 连续的下一块, 拼出来的就是别的地址的数据, 会静默产生非法指令。
    wire        have_nxt  = (cnt >= 3'd2) &&
                            (fb_tag[rd + 2'd1] == (head_tag + 14'd1));

    wire [31:0] instr_word = pc[1] ? {blk_n[15:0], blk[31:16]} : blk;

    wire        valid_i = hit_eff && (~cross_blk | have_nxt);
    wire        clear_fifo = ~hit_eff;      // 头部块与 pc 对不上, 只能重取
    wire        wait_nxt   = cross_blk & ~have_nxt;   // 只差下一块, 等它到, 不清队列

    assign valid = valid_i;

    wire [31:0] rvc32;
    wire        rvc_bad;

    core_rvc_decoder u_rvc (
        .inst    (hw),
        .instr32 (rvc32),
        .illegal (rvc_bad)
    );

    assign instr32       = is32 ? instr_word : rvc32;
    assign instr_raw     = is32 ? instr_word : {16'd0, hw};
    assign instr_rvc     = ~is32;
    assign instr_illegal = is32 ? 1'b0 : rvc_bad;

    // ------------------------------ 取指请求 ---------------------------------
    // 取指响应无效 = 上一拍 A 口被 store 抢走。此时数据属于别的地址, 必须丢弃,
    // 并用同一个块号重发。这样 store 可以无条件优先使用 A 口, 取指永不被污染。
    wire        retry     = pend_vld & ~mem_rvalid;
    wire [2:0]  inflight  = cnt + {2'd0, pend_vld};
    wire        issue     = retry || (inflight < 3'd3) || clear_fifo || redirect;
    wire [13:0] issue_tag = redirect  ? redir_tag
                          : clear_fifo ? want_tag
                          : retry      ? pend_tag
                          :              fpc;

    assign mem_addr = {issue_tag, 2'b00};
    assign mem_req  = issue;

    wire take    = consume && valid_i;
    wire [13:0] nxt_want = pc_next[15:2];
    wire        do_pop   = take && (cnt != 3'd0) && (nxt_want != head_tag);
    wire        do_push  = pend_vld;

    wire unused_wait = wait_nxt;

    always @(posedge clk) begin
        if (rst) begin
            rd <= 2'd0; wr <= 2'd0; cnt <= 3'd0;
            fpc <= 14'd0; pend_tag <= 14'd0; pend_vld <= 1'b0;
        end else if (redirect || clear_fifo) begin
            // 队列内容与 pc 不再连续: 整体作废, 立刻重取
            rd  <= 2'd0;
            wr  <= 2'd0;
            cnt <= 3'd0;
            fpc <= issue_tag + 14'd1;
            pend_tag <= issue_tag;
            pend_vld <= mem_ready;
        end else begin
            if (do_push && mem_rvalid) begin
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

            // 新请求 (放在最后, 覆盖上面的 pend_vld 赋值)
            if (issue && mem_ready) begin
                pend_tag <= issue_tag;
                pend_vld <= 1'b1;
                if (!retry) fpc <= issue_tag + 14'd1;
            end else begin
                pend_vld <= 1'b0;
            end
        end
    end
endmodule
