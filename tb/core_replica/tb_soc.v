// -----------------------------------------------------------------------------
// tb_soc.v -- V1 单通道 SoC 的整机仿真平台
//
// 职责:
//   1) 产生时钟/复位, 例化 pango_soc
//   2) 在 testbench 侧解码 UART TX 波形, 把固件打印的字符还原成文本
//      (同时写入 uart_rx.txt, 供 tools/core_replica/run_case.py 判定)
//   3) 超时保护 + 关键字收尾
//
// 判定口径按计划 9.1: 不能只看一个 banner。必须同时满足
//   - 抓到 "SMOKE PASS" (或 CoreMark 的官方验证文本)
//   - 没有 TIMEOUT
//   - 进程退出码由 run 脚本检查
// -----------------------------------------------------------------------------
`timescale 1ns/1ps

module tb_soc;
    reg clk = 1'b0;
    reg rst = 1'b1;

    wire       uart_tx;
    reg        uart_rx = 1'b1;
    wire [7:0] led;

    pango_soc dut (
        .clk     (clk),
        .rst     (rst),
        .uart_tx (uart_tx),
        .uart_rx (uart_rx),
        .led     (led),
        .btn     (1'b1)
    );

    always #5 clk = ~clk;      // 100 MHz 仿真时钟; UART 分频自洽, 与真实频率无关

    initial begin
        rst = 1'b1;
        repeat (20) @(posedge clk);
        rst = 1'b0;
    end

    integer cycles = 0;
    integer MAX_CYCLES = 4000000;
    integer c_commit = 0;
    reg     timeout = 1'b0;

    // ------------------------------ UART 接收 --------------------------------
    localparam integer BIT_CLKS = 8 * (130 + 1);
    localparam integer HALF     = BIT_CLKS / 2;

    localparam integer S_IDLE = 0, S_START = 1, S_DATA = 2, S_STOP = 3;

    integer   st      = S_IDLE;
    integer   cnt     = 0;
    integer   bidx    = 0;
    reg [7:0] rx_byte = 8'd0;
    integer   rx_chars  = 0;
    integer   rx_errors = 0;
    reg [79:0] rx_tail  = 80'd0;      // 最近 10 个字符, 最新在低位
    integer   rx_fd     = 0;
    integer   max_chars = 0;

    task report_and_finish;
        begin
            $display("\n[TB] cycles=%0d commit=%0d chars=%0d uart_errors=%0d timeout=%0d",
                     cycles, c_commit, rx_chars, rx_errors, timeout);
            $finish;
        end
    endtask

    initial begin
        rx_fd = $fopen("uart_rx.txt", "w");
        $value$plusargs("maxchars=%d", max_chars);
        $value$plusargs("maxcycles=%d", MAX_CYCLES);
    end

    always @(posedge clk) begin
        if (rst) begin
            st  <= S_IDLE;
            cnt <= 0;
            bidx <= 0;
        end else begin
            case (st)
            S_IDLE: begin
                if (uart_tx == 1'b0) begin
                    st  <= S_START;
                    cnt <= 0;
                end
            end
            S_START: begin
                cnt <= cnt + 1;
                if (cnt == HALF - 1) begin
                    cnt <= 0;
                    if (uart_tx == 1'b0) begin
                        st   <= S_DATA;
                        bidx <= 0;
                    end else begin
                        st <= S_IDLE;
                    end
                end
            end
            S_DATA: begin
                cnt <= cnt + 1;
                if (cnt == BIT_CLKS - 1) begin
                    cnt <= 0;
                    rx_byte[bidx] <= uart_tx;
                    if (bidx == 7) st <= S_STOP;
                    else           bidx <= bidx + 1;
                end
            end
            S_STOP: begin
                cnt <= cnt + 1;
                if (cnt == BIT_CLKS - 1) begin
                    cnt <= 0;
                    st  <= S_IDLE;
                    if (uart_tx == 1'b1) begin
                        rx_chars <= rx_chars + 1;
                        $fwrite(rx_fd, "%c", rx_byte);
                        $fflush(rx_fd);
                        rx_tail <= {rx_tail[71:0], rx_byte};
                        // 固件把 "\n" 展开成 "\r\r\n", 按 12 字符比对永远不中,
                        // 只能等 maxchars 或超时。改 10 字符窗口 + 认 BENCH_DONE。
                        if ({rx_tail[71:0], rx_byte} == "BENCH_DONE") begin
                            $display("[TB] BENCH_DONE seen at %0d cycles", cycles);
                            report_and_finish;
                        end
                        if ({rx_tail[63:0], rx_byte} == "PAIR FAIL") begin  // 9 字符标记
                            $display("[TB] PAIR FAIL marker seen at %0d cycles", cycles);
                            report_and_finish;
                        end
                        if ({rx_tail[63:0], rx_byte} == "SMOKE FAIL") begin // 10 字符
                            $display("[TB] SMOKE FAIL marker seen at %0d cycles", cycles);
                            report_and_finish;
                        end
                        if ({rx_tail[63:0], rx_byte} == "PAIR PASS") begin // 9 字符标记
                            $display("[TB] PAIR PASS marker seen at %0d cycles", cycles);
                            report_and_finish;
                        end
                        if ({rx_tail[71:0], rx_byte} == "SMOKE PASS") begin
                            $display("[TB] PASS marker seen at %0d cycles", cycles);
                            report_and_finish;
                        end
                        if (max_chars > 0 && rx_chars + 1 >= max_chars) begin
                            $display("[TB] char budget reached at %0d cycles", cycles);
                            report_and_finish;
                        end
                    end else begin
                        rx_errors <= rx_errors + 1;
                    end
                end
            end
            endcase
        end
    end

    // ------------------------------ 运行控制 --------------------------------
    always @(posedge clk) begin
        if (!rst) begin
            cycles = cycles + 1;
            if (dut.u_cpu.commit_valid) c_commit = c_commit + 1;
            if (cycles > MAX_CYCLES) begin
                timeout = 1'b1;
                $display("\n[TB] TIMEOUT after %0d cycles (chars=%0d uart_errors=%0d)",
                         cycles, rx_chars, rx_errors);
                report_and_finish;
            end
        end
    end
endmodule
