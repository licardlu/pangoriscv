// -----------------------------------------------------------------------------
// tb_soc.v -- V2 双发射 SoC 整机仿真平台
//
// 职责:
//   1) 产生时钟/复位, 例化 pango_soc
//   2) 在 testbench 侧解码 UART TX 波形, 把固件打印的字符还原成文本
//      (同时写入 uart_rx.txt, 供 tools/core_replica/run_case.py 判定)
//   3) 超时保护 + 关键字收尾 + 双发射统计
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
                        // ★ 固件把 "\n" 展开成 "\r\r\n", 原来按 "SMOKE PASS\r\n"
                        //   (12 字符) 比对永远匹配不上, 只能等 maxchars 或超时。
                        //   改成 10 字符窗口, 同时认 CoreMark 的 BENCH_DONE。
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
                        if ({rx_tail[71:0], rx_byte} == "BENCH_DONE") begin
                            $display("[TB] BENCH_DONE seen at %0d cycles", cycles);
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
    reg timeout = 1'b0;

    always @(posedge clk) begin
        if (!rst) begin
            cycles = cycles + 1;
            if (cycles > MAX_CYCLES) begin
                timeout = 1'b1;
                $display("\n[TB] TIMEOUT after %0d cycles (chars=%0d uart_errors=%0d)",
                         cycles, rx_chars, rx_errors);
                report_and_finish;
            end
        end
    end

    // ------------------------------ 统计探针 --------------------------------
    integer c_commit = 0, c_pair = 0, c_stall = 0, c_freeze = 0;
    integer n_nohd = 0, n_short = 0, n_one_nx = 0, n_one_no = 0;
    integer n_mulbusy = 0, n_divbusy = 0, n_mulstart = 0, n_divstart = 0;
    integer dbg_trap = 0;
    integer dbg_ls = 0;
    integer dbg_ls2 = 0;
    reg [31:0] pc_hist [0:3];
    integer hi;

    always @(posedge clk) begin
        if (!rst) begin
            if (dut.u_cpu.commit_valid && dut.u_cpu.commit_pc >= 32'h8000_0180 &&
                dut.u_cpu.commit_pc <= 32'h8000_01A2)
                $display("S %h %h t6=%h", dut.u_cpu.commit_pc, dut.u_cpu.commit_instr,
                         dut.u_cpu.u_regfile.mem[31]);
            if (dut.u_cpu.commit_valid1 && dut.u_cpu.commit_pc1 >= 32'h8000_0180 &&
                dut.u_cpu.commit_pc1 <= 32'h8000_01A2)
                $display("S1 %h %h t6=%h", dut.u_cpu.commit_pc1, dut.u_cpu.commit_instr1,
                         dut.u_cpu.u_regfile.mem[31]);
            if (dut.u_cpu.commit_valid) begin
                c_commit = c_commit + 1;
                pc_hist[0] <= dut.u_cpu.commit_pc;
                pc_hist[1] <= pc_hist[0];
                pc_hist[2] <= pc_hist[1];
                pc_hist[3] <= pc_hist[2];
            end
            if (dut.u_cpu.commit_valid1) c_commit = c_commit + 1;
            if (dut.u_cpu.freeze)        c_freeze = c_freeze + 1;
            if (dut.u_cpu.u_mul.busy)    n_mulbusy = n_mulbusy + 1;
            if (dut.u_cpu.u_div.busy)    n_divbusy = n_divbusy + 1;
            if (dut.u_cpu.u_mul.start)   n_mulstart = n_mulstart + 1;
            if (dut.u_cpu.u_div.start)   n_divstart = n_divstart + 1;
            // 取指供给诊断: out_n==0 是"队头块没到"还是"16 字节窗口凑不齐";
            // out_n==1 时有下一块就说明"本可以发 2 条却没发".
            if (!dut.u_cpu.freeze && !dut.u_cpu.stall_all && !dut.u_cpu.any_redirect &&
                (dut.u_cpu.db_count == 3'd0)) begin
                if (dut.u_cpu.al_out_n == 2'd0)
                    if (!dut.u_cpu.u_aligner.head_ok) n_nohd  = n_nohd  + 1;
                    else                              n_short = n_short + 1;
                else if (dut.u_cpu.al_out_n == 2'd1) begin
                    if (dut.u_cpu.u_aligner.have_nxt) n_one_nx = n_one_nx + 1;
                    else                              n_one_no = n_one_no + 1;
                end
            end
            if (dut.u_cpu.u_csr.trap_en) begin
                if (dbg_trap < 4) begin
                    dbg_trap = dbg_trap + 1;
                    $display("TRAP c=%0d cause=%h epc=%h tval=%h",
                             cycles, dut.u_cpu.u_csr.trap_cause,
                             dut.u_cpu.u_csr.trap_epc, dut.u_cpu.u_csr.trap_tval);
                end
            end
        end
    end

    task report_and_finish;
        begin
            $display("\n[TB] cycles=%0d commit=%0d issue=%0d pair=%0d loadstall=%0d freeze=%0d chars=%0d uart_errors=%0d timeout=%0d",
                     cycles, c_commit,
                     dut.u_cpu.perf_issue, dut.u_cpu.perf_pair,
                     dut.u_cpu.perf_stall_load, c_freeze,
                     rx_chars, rx_errors, timeout);
            $display("[TB] mdu: mul_busy=%0d (%0d starts)  div_busy=%0d (%0d starts)",
                     n_mulbusy, n_mulstart, n_divbusy, n_divstart);
            $display("[TB] feed: nohead=%0d short=%0d one_nxt=%0d one_noNxt=%0d  (仅统计缓冲空时)",
                     n_nohd, n_short, n_one_nx, n_one_no);
            $display("[TB] redirect=%0d taken=%0d nofeed=%0d  (未归因空转 = cycles-issue-redirect-nofeed-stall-freeze)",
                     dut.u_cpu.perf_redirect, dut.u_cpu.perf_taken, dut.u_cpu.perf_nofeed);
            for (hi = 3; hi >= 0; hi = hi - 1)
                $display("[TB] recent commit pc[%0d]=%h", hi, pc_hist[hi]);
            $finish;
        end
    endtask
endmodule
