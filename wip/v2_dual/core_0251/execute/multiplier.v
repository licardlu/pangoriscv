// -----------------------------------------------------------------------------
// core_multiplier.v -- RV32M 乘法 (MUL/MULH/MULHU/MULHSU)
//
// 为什么是 4 拍流水而不是 1 拍:  PDS 实测关键路径就是本模块。
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

    reg [32:0] mid;
    reg [31:0] lo, hi;
    reg [31:0] a_s2, b_s2;
    reg [2:0]  op_s2;
    reg        v2;

    reg [31:0] result_r;
    reg        v3;

    assign busy   = v0 | v1 | v2;     // 在途 (不含输出拍)
    assign done   = v3;
    assign result = result_r;

    wire [63:0] uu = {hi, lo} + ({31'd0, mid} << 16);

    wire [63:0] a_ext = {{32{a_s2[31]}}, a_s2};
    wire [63:0] b_ext = {{32{b_s2[31]}}, b_s2};

    wire [63:0] corr_a = a_s2[31] ? (b_ext << 32) : 64'd0;
    wire [63:0] corr_b = b_s2[31] ? (a_ext << 32) : 64'd0;
    wire [63:0] ss = uu - corr_a - corr_b;
    wire [63:0] su = uu - corr_a;

    always @(posedge clk) begin
        if (rst) begin
            a_q <= 32'd0; b_q <= 32'd0; op_q <= 3'd0; v0 <= 1'b0;
            p0 <= 32'd0; p1 <= 32'd0; p2 <= 32'd0; p3 <= 32'd0;
            a_s1 <= 32'd0; b_s1 <= 32'd0; op_s1 <= 3'd0; v1 <= 1'b0;
            mid <= 33'd0; lo <= 32'd0; hi <= 32'd0;
            a_s2 <= 32'd0; b_s2 <= 32'd0; op_s2 <= 3'd0; v2 <= 1'b0;
            result_r <= 32'd0; v3 <= 1'b0;
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

            v2 <= v1;
            if (v1) begin
                mid <= {1'b0, p1} + {1'b0, p2};
                lo  <= p0;
                hi  <= p3;
                a_s2 <= a_s1;
                b_s2 <= b_s1;
                op_s2 <= op_s1;
            end

            v3 <= v2;
            if (v2) begin
                case (op_s2)
                    3'd0:    result_r <= uu[31:0];
                    3'd1:    result_r <= ss[63:32];
                    3'd2:    result_r <= su[63:32];
                    default: result_r <= uu[63:32];
                endcase
            end
        end
    end
endmodule
