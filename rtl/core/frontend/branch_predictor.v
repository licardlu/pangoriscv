// -----------------------------------------------------------------------------
// core_branch_predictor.v -- 分支目标缓冲 + 方向计数器 + 返回地址栈 (P10 第一版)
//
// 参考设计有 BTB(256×51×2 路) + RAS(4) + GShare(4096×8, hist 12)。本版只做前两样,
// GShare 留到下一轮 —— 理由和目前的差异登记在 docs/architecture/replica-differences.md。
//
// 为什么先做 BTB:
//   现在的代价是"每次成立的分支都要等它走到 EX 才重定向", 前端被冲刷再重填。
//   BTB 让取指级就知道"这个 pc 是跳转、跳到哪", 把重定向提前 2 拍。
//
// 表结构 (128 项, 直接映射):
//   index = pc[8:2]     (低 7 位)
//   tag   = {pc[15:9], pc[1]}  (8 位)
//
// ★ tag 必须带上 pc[1]: RV32C 允许指令从 2 字节边界开始, 同一个 4 字节字里
//   可能装两条 16 位指令。只用 pc[15:9] 做 tag 时 0x1bc(c.jal) 和 0x1be(li)
//   的 index 与 tag 完全相同 —— 实测导致"在 li 上预测跳到 c.jal 的目标",
//   程序直接跑飞。32 位指令的 pc[1] 恒 0, 加这一位不影响它们。
//   target: 存 pc[15:0]。代码镜像固定在 0x8000_0000 起的 64 KiB,
//           所以高位恒为 0x8000; 训练时若发现目标不在该区间就不建表项
//           (宁可少预测, 也不能跳错地方)。
//   方向: 每项一个 2 位饱和计数器, 高位置位才预测"跳"。
//
// 训练点: EX 级解析出 taken/target 的那一拍 (upd_en)。我们的分支在 EX 按程序顺序
//   逐条解析, 所以训练是"退休式"的, 不存在乱序污染; 误预测只会让表晚一拍更新。
//
// RAS: 8 项。call = jal/jalr 且 rd ∈ {x1, x5}; ret = jalr 且 rd==x0 且 rs1 ∈ {x1, x5}。
//   栈在 EX 训练点压/弹, 与"预测时读栈顶"配合。**已知限制**: 误预测或多重在途分支
//   会让栈指针漂移, 参考设计有专门的恢复逻辑, 本版没有 —— 记在差异表里。
//
// 读是组合的 (al_pc -> pred_taken/pred_target), 直接驱动对齐器的 pc_q 跳转;
// 表本身是 FF + 128:1 选择, 不含乘法/比较链。
// -----------------------------------------------------------------------------
module core_branch_predictor (
    input  wire        clk,
    input  wire        rst,

    // ------------------------------ 查表 (组合) ------------------------------
    input  wire [31:0] lookup_pc,
    output wire        pred_taken,
    output wire [31:0] pred_target,

    // ------------------------------ 训练 (EX 解析点) -------------------------
    input  wire        upd_en,          // 本拍有分支/跳转在 EX 定案
    input  wire [31:0] upd_pc,
    input  wire        upd_taken,       // 真的跳了 (含 jal/jalr)
    input  wire [31:0] upd_target,      // 实际目标
    input  wire        upd_is_call,
    input  wire        upd_is_ret,
    input  wire [31:0] upd_link,        // 返回地址 = 该指令的 pc + 长度 (RVC 是 +2)

    // ------------------------------ 统计 -------------------------------------
    output reg  [31:0] perf_pred        // 预测"跳"的次数 (命中数由上层统计)
);
    localparam N     = 128;
    localparam AW    = 7;               // 2^7 = 128
    localparam IMG_HI = 16'h8000;       // 代码镜像高 16 位

    // ★ 整张表合并成一条 28 位宽的表, 并**明确要求综合成 distributed RAM**。
    //   原来写成 5 张独立的 FF 表 (tag/tgt/ctr/vld/ret), 实测 128x27 全落成触发器:
    //     FF 3,595 -> 7,199 (+3,604), LUT +1,597,
    //     而且 btb_tgt 的 128:1 组合读 mux 直接进了关键路径
    //     (WNS -1.660 -> -2.578, 推算 100.4 -> 91.9 MHz)。
    //   器件有 19,900 个 distributed RAM 空着, 这张表本来就是"小表 + 异步读",
    //   天生该进 LUTRAM。
    //
    //   ★ 为了能被识别成 LUTRAM: 不要写 for 循环复位 (那会逼出触发器),
    //     靠 LUTRAM 上电为 0 —— vld 位为 0 就等于"没有表项", 恰好是想要的状态。
    //
    //   字段: {vld, tag[7:0], ret, ctr[1:0], tgt[15:0]}
    localparam EW = 28;
    (* ram_style = "distributed", syn_ramstyle = "distributed" *)
    reg [EW-1:0] btb [0:N-1];

    // 初值用 initial (LUTRAM 的 INIT 支持这个), 不要写在复位分支里 ——
    // 复位分支里的 for 循环会逼着综合器把表做成触发器。
    integer i;
    initial begin
        for (i = 0; i < N; i = i + 1) btb[i] = {EW{1'b0}};
    end

    // ------------------------------ 返回地址栈 -------------------------------
    localparam RAS_N = 8;
    reg [31:0] ras [0:RAS_N-1];
    reg [2:0]  ras_sp;                  // 指向下一个空位 (0 = 空)
    wire [31:0] ras_top = ras[ras_sp - 3'd1];

    // ------------------------------ 查表 (异步读) ----------------------------
    wire [AW-1:0] lidx = lookup_pc[AW+1:2];
    wire [7:0]    ltag = {lookup_pc[15:9], lookup_pc[1]};

    wire [EW-1:0] ent   = btb[lidx];
    wire          e_vld = ent[27];
    wire [7:0]    e_tag = ent[26:19];
    wire          e_ret = ent[18];
    wire [1:0]    e_ctr = ent[17:16];
    wire [15:0]   e_tgt = ent[15:0];

    wire hit = e_vld && (e_tag == ltag) && (lookup_pc[31:16] == IMG_HI);

    assign pred_taken  = hit && e_ctr[1] && (ras_sp != 3'd0 || !e_ret);
    assign pred_target = e_ret ? ras_top : {IMG_HI, e_tgt};

    // ------------------------------ 训练 -------------------------------------
    wire [AW-1:0] uidx = upd_pc[AW+1:2];
    wire          uok  = upd_en && (upd_pc[31:16] == IMG_HI);

    wire [EW-1:0] uent   = btb[uidx];          // 第二个异步读口 (LUTRAM 支持)
    wire [1:0]    u_ctr  = uent[17:16];
    wire [1:0]    u_inc  = (u_ctr == 2'd3) ? 2'd3 : u_ctr + 2'd1;
    wire [1:0]    u_dec  = (u_ctr == 2'd0) ? 2'd0 : u_ctr - 2'd1;

    always @(posedge clk) begin
        if (rst) begin
            ras_sp    <= 3'd0;
            perf_pred <= 32'd0;
        end else begin
            if (pred_taken) perf_pred <= perf_pred + 32'd1;

            if (uok && upd_taken && (upd_target[31:16] == IMG_HI)) begin
                // 建表 / 更新目标, 计数器加一 (饱和)
                btb[uidx] <= {1'b1, {upd_pc[15:9], upd_pc[1]}, upd_is_ret,
                              u_inc, upd_target[15:0]};
            end else if (uok && !upd_taken && (u_ctr != 2'd0)) begin
                // 预测落空: 计数器减一 (饱和), 其余字段不动
                btb[uidx] <= {uent[27:16], u_dec, uent[15:0]};
            end

            // RAS: 压栈 / 弹栈 (与训练同拍)
            if (uok && upd_is_call) begin
                ras[ras_sp] <= upd_link;         // 必须用真实长度: c.jal 是 pc+2
                if (ras_sp != RAS_N[2:0] - 3'd1) ras_sp <= ras_sp + 3'd1;
            end else if (uok && upd_is_ret) begin
                if (ras_sp != 3'd0) ras_sp <= ras_sp - 3'd1;
            end
        end
    end
endmodule
