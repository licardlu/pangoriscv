// -----------------------------------------------------------------------------
// core_multiplier.v -- RV32M 乘法 (MUL/MULH/MULHU/MULHSU)
//
// 流水级: 3 级 (S0 操作数 / S1 四个 16x16 部分积 / S2 合成+符号修正)。
//   原来 S2 与 S3 是分开的 (部分和一级、合成一级), 停顿 3 拍; 合并后停 2 拍。
//   合并是否安全要看 S2 的路径 (加法器 -> 加法器 -> 减法器 -> mux), 实测见
//   docs/verification/pds-status.md run-020。
//
// 为什么不是 1 拍:  PDS 实测关键路径就是本模块。
//   原始实现把 32x32 写成一个表达式, PDS 用 3 级 APM 级联实现, 关键路径
//   旁路选择 -> APM -> APM -> APM -> 寄存器 = 13.873 ns (目标 8.301, WNS -4.386)。
//   参考设计的 MulPlugin 同样是多拍: relaxedMulInputs=false 只约束操作数取样时刻,
//   并不要求单拍出结果。所以这里改成:
//     S0: 寄存操作数            (路径: 旁路 mux -> FF)
//     S1: 4 个 16x16 无符号乘   (路径: FF -> 单个 APM -> FF)
//     S2: 低位部分和            (路径: FF -> 加法器 -> FF)
//     S3: 64 位合成 + 符号修正  (路径: FF -> 加法器/mux -> FF)
//
// 只用无符号 16x16 部分积推导全部四种结果 (省一半 APM):
//   uu = p3<<32 + (p1+p2)<<16 + p0
//   ss = uu - (a31 ? b<<32 : 0) - (b31 ? a<<32 : 0)      (mod 2^64)
//   su = uu - (a31 ? b<<32 : 0)
// -----------------------------------------------------------------------------
module core_multiplier (
    input  wire        clk,
    input  wire        rst,
    input  wire        start,
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [2:0]  op,           // 0=MUL 1=MULH 2=MULHSU 3=MULHU
    output wire        busy,
    output wire        done,
    output wire [31:0] result
);
    reg [31:0] a_q, b_q;
    reg [2:0]  op_q;
    reg        v0;

    reg [31:0] p0, p1, p2, p3;
    reg [31:0] a_s1, b_s1;
    reg [2:0]  op_s1;
    reg        v1;

    reg [31:0] result_r;
    reg        v2;

    assign busy   = v0 | v1;          // 在途 2 拍 (原来 3 拍)
    assign done   = v2;
    assign result = result_r;

    // ---- S2 组合部分: 部分和 -> 64 位合成 -> 符号修正 (合并后的那一级) ----
    //   uu = p3<<32 + (p1+p2)<<16 + p0     (与原来的 hi/lo/mid 写法等价)
    wire [32:0] mid_c = {1'b0, p1} + {1'b0, p2};
    wire [63:0] uu    = {p3, p0} + ({31'd0, mid_c} << 16);

    wire [63:0] a_ext = {{32{a_s1[31]}}, a_s1};
    wire [63:0] b_ext = {{32{b_s1[31]}}, b_s1};

    wire [63:0] corr_a = a_s1[31] ? (b_ext << 32) : 64'd0;
    wire [63:0] corr_b = b_s1[31] ? (a_ext << 32) : 64'd0;
    wire [63:0] ss = uu - corr_a - corr_b;
    wire [63:0] su = uu - corr_a;

    always @(posedge clk) begin
        if (rst) begin
            a_q <= 32'd0; b_q <= 32'd0; op_q <= 3'd0; v0 <= 1'b0;
            p0 <= 32'd0; p1 <= 32'd0; p2 <= 32'd0; p3 <= 32'd0;
            a_s1 <= 32'd0; b_s1 <= 32'd0; op_s1 <= 3'd0; v1 <= 1'b0;
            result_r <= 32'd0; v2 <= 1'b0;
        end else begin
            v0 <= start;
            if (start) begin
                a_q  <= a;
                b_q  <= b;
                op_q <= op;
            end

            v1 <= v0;
            if (v0) begin
                p0 <= a_q[15:0]  * b_q[15:0];
                p1 <= a_q[15:0]  * b_q[31:16];
                p2 <= a_q[31:16] * b_q[15:0];
                p3 <= a_q[31:16] * b_q[31:16];
                a_s1 <= a_q;
                b_s1 <= b_q;
                op_s1 <= op_q;
            end

            // S2: 部分和 + 合成 + 符号修正, 一拍做完
            v2 <= v1;
            if (v1) begin
                case (op_s1)
                    3'd0:    result_r <= uu[31:0];      // MUL
                    3'd1:    result_r <= ss[63:32];     // MULH
                    3'd2:    result_r <= su[63:32];     // MULHSU
                    default: result_r <= uu[63:32];     // MULHU
                endcase
            end
        end
    end
endmodule
