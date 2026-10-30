// -----------------------------------------------------------------------------
// core_divider.v -- RV32M 除法/余数 (DIV/DIVU/REM/REMU)
//
// 参考实现用 DivPlugin + DivRadix(radix=4), 即每拍产生 2 位商。
// V1 先用 radix-2 恢复余数法 (每拍 1 位), 首次上板优先保正确性;
// 这是已登记的差异 (docs/architecture/replica-differences.md D-07)。
//
// 状态机: IDLE -> BUSY(32 拍) -> FIN(寄存结果) -> RES(拉 done) -> IDLE
//   done 必须和 result 同拍有效。早先把 result 在 done 那一拍才寄存, 结果是
//   每条除法都拿到上一条的值 —— 这是本模块最容易被忽略的时序合同。
//
// 除在被启动那一拍采样 a/b/op 外, 全程只用寄存后的副本:
//   流水线在除法期间是冻结的, 但 IF/ID 仍停在下一条指令上, 寄存器堆输出会被
//   下一条指令的读地址持续刷新。若这里直接用端口上的 a/b, 中途就会被改掉。
//
// RISC-V 语义要点 (全部实现):
//   - 除零: 商 = -1 (0xFFFFFFFF), 余数 = 被除数
//   - 溢出 (INT_MIN / -1): 商 = INT_MIN, 余数 = 0
//   - 商的符号 = 被除数符号 ^ 除数符号; 余数的符号 = 被除数符号
// -----------------------------------------------------------------------------
module core_divider (
    input  wire        clk,
    input  wire        rst,
    input  wire        start,
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [2:0]  op,        // 4=DIV 5=DIVU 6=REM 7=REMU
    output wire        busy,
    output wire        done,
    output reg  [31:0] result
);
    localparam ST_IDLE = 2'd0;
    localparam ST_BUSY = 2'd1;
    localparam ST_FIN  = 2'd2;
    localparam ST_RES  = 2'd3;

    reg [1:0]  state;
    reg [32:0] rem;
    reg [31:0] quo;
    reg [31:0] dsr;
    reg [31:0] a_q;
    reg [5:0]  cnt;

    reg q_neg, r_neg, is_rem, dz, ovf;

    wire        a_neg = a[31];
    wire        b_neg = b[31];
    wire [31:0] a_abs = a_neg ? (~a + 32'd1) : a;
    wire [31:0] b_abs = b_neg ? (~b + 32'd1) : b;

    assign busy = (state != ST_IDLE);
    assign done = (state == ST_RES);

    always @(posedge clk) begin
        if (rst) begin
            state   <= ST_IDLE;
            rem     <= 33'd0;
            quo     <= 32'd0;
            dsr     <= 32'd0;
            a_q     <= 32'd0;
            cnt     <= 6'd0;
            q_neg   <= 1'b0;
            r_neg   <= 1'b0;
            is_rem  <= 1'b0;
            dz      <= 1'b0;
            ovf     <= 1'b0;
            result  <= 32'd0;
        end else begin
            case (state)
                ST_IDLE: begin
                    if (start) begin
                        is_rem  <= op[1];
                        dz      <= (b == 32'd0);
                        ovf     <= (!op[0]) && (a == 32'h8000_0000) && (b == 32'hFFFF_FFFF);
                        q_neg   <= (!op[0]) && (a_neg ^ b_neg);
                        r_neg   <= (!op[0]) && a_neg;
                        rem     <= 33'd0;
                        quo     <= op[0] ? a      : a_abs;
                        dsr     <= op[0] ? b      : b_abs;
                        a_q     <= a;
                        cnt     <= 6'd32;
                        state   <= ST_BUSY;
                    end
                end
                ST_BUSY: begin
                    if ({rem[31:0], quo[31]} >= {1'b0, dsr}) begin
                        rem <= {rem[31:0], quo[31]} - {1'b0, dsr};
                        quo <= {quo[30:0], 1'b1};
                    end else begin
                        rem <= {rem[31:0], quo[31]};
                        quo <= {quo[30:0], 1'b0};
                    end
                    if (cnt == 6'd1) state <= ST_FIN;
                    else             cnt   <= cnt - 6'd1;
                end
                ST_FIN: begin
                    if (is_rem) begin
                        result <= dz  ? a_q
                                : ovf ? 32'd0
                                : (r_neg ? (~rem[31:0] + 32'd1) : rem[31:0]);
                    end else begin
                        result <= dz  ? 32'hFFFF_FFFF
                                : ovf ? 32'h8000_0000
                                : (q_neg ? (~quo + 32'd1) : quo);
                    end
                    state <= ST_RES;
                end
                ST_RES: begin
                    state <= ST_IDLE;
                end
                default: state <= ST_IDLE;
            endcase
        end
    end
endmodule
