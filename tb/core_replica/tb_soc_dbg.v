// -----------------------------------------------------------------------------
// tb_soc_dbg.v -- 调试用整机平台 (不参与门禁判定)
//
// 与 tb_soc_v2.v 的区别: 只加"对账"探针, 不改 DUT 行为和判定口径。
//
//   1) PC 连续性的流式断言: 按提交顺序 (同拍 lane0 先于 lane1) 检查
//      pc_next == pc_prev + len(prev)。第一个不连续点就是"指令丢失/重复/乱序"
//      发生的位置 —— V2 的 `mv t6,a6` 丢写现象本质上就是发射流错位一像素,
//      这一条断言能在第一处抓住, 不必等 printf 输出乱掉。
//   2) 指定寄存器 (默认 x31=t6) 的写回追踪: 打印 pc / rd / data / 写口,
//      用来核对"到底有没有写、写成了什么"。
//   3) 错误路径 (trap) 打印。
//
// 用法:
//   vsim -c -quiet work.tb_soc_dbg -do "run -all; quit -f" \
//        +maxchars=1400 +maxcycles=2000000 +watch=x31
// -----------------------------------------------------------------------------
`timescale 1ns/1ps

module tb_soc_dbg;
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

    always #5 clk = ~clk;

    initial begin
        rst = 1'b1;
        repeat (20) @(posedge clk);
        rst = 1'b0;
    end

    integer cycles = 0;
    integer MAX_CYCLES = 2000000;
    reg     timeout = 1'b0;

    // ------------------------------ UART 接收 --------------------------------
    localparam integer BIT_CLKS = 8 * (130 + 1);

    localparam S_IDLE = 0, S_START = 1, S_DATA = 2, S_STOP = 3;

    integer   st      = S_IDLE;
    integer   cnt     = 0;
    integer   bidx    = 0;
    reg [7:0] rx_byte = 8'd0;
    integer   rx_chars  = 0;
    integer   rx_errors = 0;
    integer   rx_fd     = 0;
    integer   max_chars = 0;

    initial begin
        rx_fd = $fopen("uart_rx_dbg.txt", "w");
        $value$plusargs("maxchars=%d", max_chars);
        $value$plusargs("maxcycles=%d", MAX_CYCLES);
        $value$plusargs("watch=%d", watch_rd);
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
                if (cnt == BIT_CLKS / 2) begin
                    cnt    <= 0;
                    bidx   <= 0;
                    rx_byte <= 8'd0;
                    st     <= S_DATA;
                end
            end
            S_DATA: begin
                cnt <= cnt + 1;
                if (cnt == BIT_CLKS - 1) begin
                    cnt      <= 0;
                    rx_byte  <= {uart_tx, rx_byte[7:1]};
                    bidx     <= bidx + 1;
                    if (bidx == 7) st <= S_STOP;
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
                        $display("[UART %0d] %c", cycles, rx_byte);
                    end else begin
                        rx_errors <= rx_errors + 1;
                    end
                end
            end
            endcase
        end
    end

    always @(posedge clk) begin
        if (!rst) begin
            cycles = cycles + 1;
            if (cycles > MAX_CYCLES) begin
                timeout = 1'b1;
                report_and_finish;
            end
        end
    end

    // =========================================================================
    // 1) PC 连续性对账
    // =========================================================================
    reg [31:0] exp_pc    = 32'd0;
    reg        exp_valid = 1'b0;
    integer    n_bad     = 0;
    integer    n_commit  = 0;

    function [31:0] ilen;
        input [31:0] ins;
        begin
            ilen = (ins[1:0] == 2'b11) ? 32'd4 : 32'd2;
        end
    endfunction

    // 上一拍的指令是不是控制流转移: 是的话 pc 不连续是合法的, 不报。
    reg [31:0] prev_instr = 32'd0;
    reg        prev_v     = 1'b0;

    function is_cf;
        input [31:0] ins;
        begin
            if (ins[1:0] != 2'b11) begin
                // RVC: Q1 的 001/101 (C.JAL/C.J) 与 110/111 (C.BEQZ/C.BNEZ),
                // Q2 的 100 且 rs2=0 (C.JR / C.JALR)
                if (ins[1:0] == 2'b01)
                    is_cf = (ins[15:13] == 3'b001) || (ins[15:13] == 3'b101) ||
                            (ins[15:13] == 3'b110) || (ins[15:13] == 3'b111);
                else
                    is_cf = (ins[15:13] == 3'b100) && (ins[6:2] == 5'd0);
            end else begin
                // JAL / JALR / BRANCH 三种 opcode
                is_cf = (ins[6:0] == 7'b1101111) || (ins[6:0] == 7'b1100111) ||
                        (ins[6:0] == 7'b1100011);
            end
        end
    endfunction

    task check_pc;
        input        v;
        input [31:0] pc;
        input [31:0] ins;
        input        lane;
        begin
            if (v) begin
                n_commit = n_commit + 1;
                if (exp_valid && (pc !== exp_pc) && !is_cf(prev_instr)) begin
                    if (n_bad < 12)
                        $display("[PCMISS] c=%0d lane=%0d pc=%h exp=%h prev=%h instr=%h",
                                 cycles, lane, pc, exp_pc, prev_instr, ins);
                    n_bad = n_bad + 1;
                end
                exp_pc     = pc + ilen(ins);
                exp_valid  = 1'b1;
                prev_instr = ins;
            end
        end
    endtask

    always @(posedge clk) begin
        if (!rst) begin
            check_pc(dut.u_cpu.commit_valid,  dut.u_cpu.commit_pc,  dut.u_cpu.commit_instr,  1'b0);
            check_pc(dut.u_cpu.commit_valid1, dut.u_cpu.commit_pc1, dut.u_cpu.commit_instr1, 1'b1);
        end
    end

    // =========================================================================
    // 1b) 架构轨迹落盘 (指令级对账用)
    //
    //     两遍跑同一份程序 (预测器开 / 关), 逐条比 (pc, instr, rd, we, wdata)。
    //     参考那遍已与真实板卡对齐过, 所以第一条分歧就是 bug 现场 —— 比看波形
    //     靠谱, 也比"猜是哪条指令"快。
    //
    //     +trace=<path>  : 输出文件
    //     +trace_n=<N>   : 最多记 N 条 (默认 0 = 不限)
    // =========================================================================
    // +fastuart: 把 UART 状态钉成"永远有空位"。
    // 固件的打印函数会轮询状态寄存器, 那是**随物理时间变化**的量, 两遍节奏
    // 不同必然读出不同值 -> 之后的指令流合法分叉, 对账就没法做了。
    // 钉住之后整个程序变成纯确定性的, 可以逐条比到结束。
    initial begin
        if ($test$plusargs("fastuart")) begin
            $display("[TRACE] fastuart: uart status 被钉死, 打印不再限速");
            force dut.u_uart.status = 32'h0001_0000;
        end
    end

    integer    tr_fd  = 0;
    integer    tr_n   = 0;
    integer    tr_max = 0;
    reg [1023:0] tr_path;

    initial begin
        if ($value$plusargs("trace=%s", tr_path)) begin
            tr_fd = $fopen(tr_path, "w");
            if (tr_fd == 0) $display("[TRACE] 打不开 %0s", tr_path);
            else            $display("[TRACE] -> %0s", tr_path);
        end
        if (!$value$plusargs("trace_n=%d", tr_max)) tr_max = 0;
        if ($test$plusargs("uartdbg")) uart_dbg = 1'b1;
    end

    always @(posedge clk) begin
        if (!rst && (tr_fd != 0) && ((tr_max == 0) || (tr_n < tr_max))) begin
            if (dut.u_cpu.commit_valid) begin
                $fwrite(tr_fd, "%0d %h %h %0d %0d %h\n", cycles,
                        dut.u_cpu.commit_pc, dut.u_cpu.commit_instr,
                        dut.u_cpu.commit_rd, dut.u_cpu.commit_we,
                        dut.u_cpu.commit_wdata);
                tr_n = tr_n + 1;
            end
            if (dut.u_cpu.commit_valid1) begin
                $fwrite(tr_fd, "%0d %h %h %0d %0d %h\n", cycles,
                        dut.u_cpu.commit_pc1, dut.u_cpu.commit_instr1,
                        dut.u_cpu.commit_rd1, dut.u_cpu.commit_we1,
                        dut.u_cpu.commit_wdata1);
                tr_n = tr_n + 1;
            end
        end
    end

    // =========================================================================
    // 2) 指定寄存器写回追踪 + 3) trap 打印
    // =========================================================================
    integer watch_rd = 31;
    integer n_watch  = 0;
    integer n_trap   = 0;
    integer n_pred   = 0;
    integer n_bupd   = 0;
    integer n_rdir   = 0;
    integer n_bad2   = 0;
    integer n_push   = 0;
    integer n_pop    = 0;
    integer idle     = 0;
    integer n_nohd   = 0;       // out_n=0 且队头块没到
    integer n_short  = 0;       // out_n=0 但队头在, 窗口不够
    integer n_one_nx = 0;       // 只发 1 条, 但有下一块 (本可以发 2)
    integer n_one_no = 0;       // 只发 1 条, 且没有下一块
    integer n_two    = 0;       // 发 2 条
    reg     uart_dbg = 1'b0;

    always @(posedge clk) begin
        if (!rst) begin
            // 写口在 memwb 级; 用"本拍将要写入"的值打印, 因此寄存器里还是旧值
            if (dut.u_cpu.memwb_v[0] && dut.u_cpu.memwb_rdweq[0] &&
                (dut.u_cpu.memwb_rdq[0] == watch_rd[4:0])) begin
                if (n_watch < 40) begin
                    $display("[W0] c=%0d pc=%h data=%h old=%h",
                             cycles, dut.u_cpu.memwb_pc[0], dut.u_cpu.memwb_data[0],
                             dut.u_cpu.u_regfile.mem[watch_rd[4:0]]);
                    n_watch = n_watch + 1;
                end
            end
            if (dut.u_cpu.memwb_v[1] && dut.u_cpu.memwb_rdweq[1] &&
                (dut.u_cpu.memwb_rdq[1] == watch_rd[4:0])) begin
                if (n_watch < 40) begin
                    $display("[W1] c=%0d pc=%h data=%h old=%h",
                             cycles, dut.u_cpu.memwb_pc[1], dut.u_cpu.memwb_data[1],
                             dut.u_cpu.u_regfile.mem[watch_rd[4:0]]);
                    n_watch = n_watch + 1;
                end
            end
            // pred_bad 探针: 预测跳但实际不跳 -> 拉回 pc+len
            if ((dut.u_cpu.x0_pred_fix || dut.u_cpu.x1_pred_fix) && (n_bad2 < 20)) begin
                n_bad2 = n_bad2 + 1;
                $display("[BAD] c=%0d pc0=%h rvc0=%b ptgt0=%h -> %h | pc1=%h rvc1=%b ptgt1=%h",
                         cycles, dut.u_cpu.idex_pc[0], dut.u_cpu.idex_rvcq[0],
                         dut.u_cpu.idex_predtgt[0], dut.u_cpu.x0_pc4,
                         dut.u_cpu.idex_pc[1], dut.u_cpu.idex_rvcq[1],
                         dut.u_cpu.idex_predtgt[1]);
            end
            // 指定 pc 的分支探针: 看 EX 实际拿到的操作数与判定
            if ((dut.u_cpu.idex_pc[0] == 32'h8000_3d9a) && dut.u_cpu.idex_v[0]) begin
                $display("[CFPROBE] c=%0d L0 pc=%h f3=%0d s1=%h s2=%h tk=%b tgt=%h pred=%b ptgt=%h",
                         cycles, dut.u_cpu.idex_pc[0], dut.u_cpu.idex_f3q[0],
                         dut.u_cpu.x_rs1[0], dut.u_cpu.x_rs2[0],
                         dut.u_cpu.br_tk[0], dut.u_cpu.br_tgt[0],
                         dut.u_cpu.idex_predq[0], dut.u_cpu.idex_predtgt[0]);
            end
            if ((dut.u_cpu.idex_pc[1] == 32'h8000_3d9a) && dut.u_cpu.idex_v[1]) begin
                $display("[CFPROBE] c=%0d L1 pc=%h f3=%0d s1=%h s2=%h tk=%b tgt=%h pred=%b ptgt=%h",
                         cycles, dut.u_cpu.idex_pc[1], dut.u_cpu.idex_f3q[1],
                         dut.u_cpu.x_rs1[1], dut.u_cpu.x_rs2[1],
                         dut.u_cpu.br_tk[1], dut.u_cpu.br_tgt[1],
                         dut.u_cpu.idex_predq[1], dut.u_cpu.idex_predtgt[1]);
            end
            // 对齐器逐拍: pc_q / 预测命中 / 输出条数 / 缓冲
            if (n_commit >= 402 && n_commit <= 408) begin
                $display("[ALN] c=%0d pcq=%h ptk=%b ptgt=%h out_n=%0d dbc=%0d q0=%h q1=%h pred=%b",
                         cycles, dut.u_cpu.al_cur_pc, dut.u_cpu.pred_taken,
                         dut.u_cpu.pred_target, dut.u_cpu.al_out_n,
                         dut.u_cpu.db_count, dut.u_cpu.db_q0_pc, dut.u_cpu.db_q1_pc,
                         dut.u_cpu.db_q0_pred);
            end
            // UART 内部状态: 卡住时看 count / busy
            if (dut.u_uart.push) begin
                n_push = n_push + 1;
                if (n_push > 40 && n_push < 52)
                    $display("[PUSH] c=%0d n=%0d wd=%h pc0=%h pc1=%h em_pc=%h em_wr=%b v0=%b mem_stall=%b",
                             cycles, n_push, dut.dmem_wdata,
                             dut.u_cpu.idex_pc[0], dut.u_cpu.idex_pc[1],
                             dut.u_cpu.exmem_pc[0], dut.u_cpu.exmem_mwrq[0],
                             dut.u_cpu.exmem_v[0], dut.u_cpu.stall_all);
            end
            if (dut.u_uart.pop)  n_pop  = n_pop  + 1;
            if (uart_dbg && (cycles % 20000) == 0) begin
                $display("[UARTST] c=%0d pc=%h st=%h cnt=%0d busy=%b div=%0d bitidx=%0d clkc=%0d push=%0d pop=%0d",
                         cycles, dut.u_cpu.idex_pc[0], dut.u_status,
                         dut.u_uart.count, dut.u_uart.busy, dut.u_uart.div_q,
                         dut.u_uart.bit_idx, dut.u_uart.clk_cnt,
                         n_push, n_pop);
            end
            // 窄窗口逐拍: 看 bgeu 在 EX 时到底拿的什么操作数
            if (n_commit >= 396 && n_commit <= 424) begin
                $display("[WIN] n=%0d c=%0d pc0=%h v0=%b tk0=%b br0=%b | pc1=%h v1=%b tk1=%b br1=%b s1=%h s2=%h | red=%b rpc=%h",
                         n_commit, cycles,
                         dut.u_cpu.idex_pc[0], dut.u_cpu.idex_v[0],
                         dut.u_cpu.br_tk[0], dut.u_cpu.idex_brq[0],
                         dut.u_cpu.idex_pc[1], dut.u_cpu.idex_v[1],
                         dut.u_cpu.br_tk[1], dut.u_cpu.idex_brq[1],
                         dut.u_cpu.x_rs1[1], dut.u_cpu.x_rs2[1],
                         dut.u_cpu.any_redirect, dut.u_cpu.redirect_pc);
            end
            // 取指供给诊断: out_n==0 到底是"队头块没到"还是"窗口凑不齐"
            if (!dut.u_cpu.freeze && !dut.u_cpu.stall_all && !dut.u_cpu.any_redirect) begin
                if (dut.u_cpu.al_out_n == 2'd0) begin
                    if (!dut.u_cpu.u_aligner.head_ok)      n_nohd = n_nohd + 1;
                    else                                   n_short = n_short + 1;
                end else if (dut.u_cpu.al_out_n == 2'd1) begin
                    if (dut.u_cpu.u_aligner.have_nxt)      n_one_nx = n_one_nx + 1;
                    else                                   n_one_no = n_one_no + 1;
                end else begin
                    n_two = n_two + 1;
                end
            end
            // 死锁检测: 连续 50000 拍没有退休 -> 打印前端内部状态
            if (dut.u_cpu.commit_valid || dut.u_cpu.commit_valid1) idle = 0;
            else if (idle < 50001) idle = idle + 1;
            if (idle == 50000) begin
                $display("[DEAD] c=%0d pcq=%h cnt=%0d rd=%0d head_ok=%b have_nxt=%b avail=%0d off=%0d ok0=%b out_n=%0d",
                         cycles, dut.u_cpu.al_cur_pc, dut.u_cpu.u_aligner.cnt,
                         dut.u_cpu.u_aligner.rd, dut.u_cpu.u_aligner.head_ok,
                         dut.u_cpu.u_aligner.have_nxt, dut.u_cpu.u_aligner.avail,
                         dut.u_cpu.u_aligner.off, dut.u_cpu.u_aligner.ok0,
                         dut.u_cpu.al_out_n);
                $display("[DEAD]   dbcnt=%0d q0=%h q1=%h pend_vld=%b pend_tag=%h fpc=%h want=%h issue=%b mem_ready=%b tb=%h,%h,%h,%h",
                         dut.u_cpu.db_count, dut.u_cpu.db_q0_pc, dut.u_cpu.db_q1_pc,
                         dut.u_cpu.u_aligner.pend_vld, dut.u_cpu.u_aligner.pend_tag,
                         dut.u_cpu.u_aligner.fpc, dut.u_cpu.u_aligner.want_tag,
                         dut.u_cpu.u_aligner.issue, dut.u_cpu.u_aligner.mem_ready,
                         dut.u_cpu.u_aligner.fb_tag[0], dut.u_cpu.u_aligner.fb_tag[1],
                         dut.u_cpu.u_aligner.fb_tag[2], dut.u_cpu.u_aligner.fb_tag[3]);
            end
            // 周期快照: 卡住时看它停在哪
            if ((cycles % 200000) == 0)
                $display("[SNAP] c=%0d pc=%h instr=%h", cycles,
                         dut.u_cpu.commit_pc, dut.u_cpu.commit_instr);
            // 重定向探针
            if (dut.u_cpu.any_redirect && (n_rdir < 30)) begin
                n_rdir = n_rdir + 1;
                $display("[RDIR] c=%0d pc0=%h bad0=%b ok0=%b tk0=%b pc1=%h bad1=%b -> %h",
                         cycles, dut.u_cpu.idex_pc[0], dut.u_cpu.x0_pred_fix,
                         dut.u_cpu.x0_pred_ok, dut.u_cpu.br_tk[0],
                         dut.u_cpu.idex_pc[1], dut.u_cpu.x1_pred_fix,
                         dut.u_cpu.redirect_pc);
            end
            // 训练探针
            if (dut.u_cpu.bupd_en && (n_bupd < 40)) begin
                n_bupd = n_bupd + 1;
                $display("[BUPD] c=%0d pc=%h tk=%b tgt=%h call=%b ret=%b link=%h",
                         cycles, dut.u_cpu.bupd_pc, dut.u_cpu.bupd_taken,
                         dut.u_cpu.bupd_target, dut.u_cpu.bupd_call,
                         dut.u_cpu.bupd_ret, dut.u_cpu.bupd_link);
            end
            // 预测跳转探针: 看它到底往哪跳
            if (dut.u_cpu.pred_taken && (dut.u_cpu.al_out_n != 2'd0) &&
                cycles > 300 && cycles < 460 && (n_pred < 60)) begin
                n_pred = n_pred + 1;
                $display("[PRED] c=%0d pc=%h -> %h", cycles,
                         dut.u_cpu.al_cur_pc, dut.u_cpu.pred_target);
            end
            if (dut.u_cpu.u_csr.trap_en) begin
                if (n_trap < 8) begin
                    $display("[TRAP] c=%0d cause=%h epc=%h tval=%h",
                             cycles, dut.u_cpu.u_csr.trap_cause,
                             dut.u_cpu.u_csr.trap_epc, dut.u_cpu.u_csr.trap_tval);
                    n_trap = n_trap + 1;
                end
            end
        end
    end

    task report_and_finish;
        begin
            $display("\n[TB] cycles=%0d commit=%0d pcmiss=%0d issue=%0d pair=%0d stall=%0d freeze=%0d chars=%0d uart_errors=%0d timeout=%0d",
                     cycles, n_commit, n_bad,
                     dut.u_cpu.perf_issue, dut.u_cpu.perf_pair,
                     dut.u_cpu.perf_stall_load, c_freeze,
                     rx_chars, rx_errors, timeout);
            $finish;
        end
    endtask

    integer c_freeze = 0;
    always @(posedge clk) if (!rst && dut.u_cpu.freeze) c_freeze = c_freeze + 1;

endmodule
