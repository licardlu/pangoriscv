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
    reg [95:0] rx_tail  = 96'd0;
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
                        rx_tail <= {rx_tail[87:0], rx_byte};
                        if ({rx_tail[87:0], rx_byte} == "SMOKE PASS\r\n") begin
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
            for (hi = 3; hi >= 0; hi = hi - 1)
                $display("[TB] recent commit pc[%0d]=%h", hi, pc_hist[hi]);
            $finish;
        end
    endtask
endmodule
