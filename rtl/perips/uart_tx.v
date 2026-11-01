// -----------------------------------------------------------------------------
// core_uart_tx.v -- 8N1 发送器 + 32 深度发送队列
//
// 分频口径 (冻结自参考实际行为, 不要按"bit = clkdiv+1"改):
//   固件写 clkdiv=130 并注释 "120.461538 MHz / (131*8) = 114944 baud",
//   参考设计实测在 115200 8N1 下能完整输出 CoreMark 记录。
//   因此每位 = 8*(clkdiv+1) 个时钟。V1 沿用这一口径。
//
// 队列深度必须是 32, 不能缩:
//   固件的流控是  while ((status & 0x00ff0000) == 0) {}  然后写一个字节。
//   参考设计 status[21:16] = 32 - occupancy, 也就是"队列满时才返回 0"。
//   putc_ 每次调用只等这一个条件, 靠的是队列足够深能吸收一整行输出的突发。
//   实测 8 深队列在打印 "REPLICA_BOOT" 时就被写穿, 输出变成乱码 —— 32 深后正常。
//
// 状态寄存器 (0x04) 与参考 TilelinkUartCtrl 对齐:
//   [21:16] = 32 - occupancy
//   [15]    = 队列非空
// -----------------------------------------------------------------------------
module core_uart_tx (
    input  wire        clk,
    input  wire        rst,

    input  wire        wr_en,
    input  wire [7:0]  wr_data,
    input  wire        cfg_en,
    input  wire [19:0] cfg_div,

    output wire [31:0] status,
    output wire        txd
);
    // ------------------------------ 32 深发送队列 ----------------------------
    reg [7:0] fifo [0:31];
    reg [4:0] wr_ptr, rd_ptr;
    reg [5:0] count;
    reg       busy;

    wire push = wr_en & (count != 6'd32);
    wire pop  = (count != 6'd0) & ~busy;

    // ------------------------------ 波特率 -----------------------------------
    reg [19:0] div_q;
    wire [19:0] bit_clks = (div_q + 20'd1) << 3;

    // ------------------------------ 发送状态机 -------------------------------
    reg [9:0]  shifter;      // {stop, data[7:0], start}
    reg [3:0]  bit_idx;
    reg [19:0] clk_cnt;
    reg        txd_r;

    assign txd = txd_r;

    always @(posedge clk) begin
        if (rst) begin
            div_q   <= 20'd130;
            wr_ptr  <= 5'd0;
            rd_ptr  <= 5'd0;
            count   <= 6'd0;
            busy    <= 1'b0;
            shifter <= 10'h3FF;
            bit_idx <= 4'd0;
            clk_cnt <= 20'd0;
            txd_r   <= 1'b1;
        end else begin
            if (cfg_en) div_q <= cfg_div;

            if (push) begin
                fifo[wr_ptr] <= wr_data;
                wr_ptr <= wr_ptr + 5'd1;
            end

            if (pop) begin
                rd_ptr  <= rd_ptr + 5'd1;
                shifter <= {1'b1, fifo[rd_ptr], 1'b0};
                busy    <= 1'b1;
                bit_idx <= 4'd0;
                clk_cnt <= 20'd0;
                txd_r   <= 1'b0;
            end

            case ({push, pop})
                2'b10:   count <= count + 6'd1;
                2'b01:   count <= count - 6'd1;
                default: count <= count;
            endcase

            if (busy) begin
                if (clk_cnt + 20'd1 >= bit_clks) begin
                    clk_cnt <= 20'd0;
                    if (bit_idx == 4'd9) begin
                        busy  <= 1'b0;
                        txd_r <= 1'b1;
                    end else begin
                        bit_idx <= bit_idx + 4'd1;
                        txd_r   <= shifter[bit_idx + 4'd1];
                    end
                end else begin
                    clk_cnt <= clk_cnt + 20'd1;
                end
            end
        end
    end

    assign status = {10'd0, (6'd32 - count), (count != 6'd0), 15'd0};
endmodule
