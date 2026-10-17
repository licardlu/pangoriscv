//=============================================================================
// pangoriscv - RV32IM processor core + native AXI4 SoC (Pango PG2L100H @ 27 MHz)
// Module : tb_coremark_uart       File : tb/integration/tb_coremark_uart.sv
// Rev    : 1.0                    Date : 2026-10-13
// Author : pango_lpenghan
// Brief  : End-to-end CoreMark firmware run on the native AXI SoC: image load,
//          UART decode, retire count, traps and bus faults
//=============================================================================

// End-to-end native-CPU run of the prebuilt CoreMark firmware image.
// Loads build/native_software/coremark/performance/{program,data}.hex into the
// native AXI SoC (program RAM is read-only, data RAM at 0x10000000), decodes the
// UART TX line and reports the byte stream, retirement count, traps and bus faults.
//
// This testbench is a VERIFICATION HARNESS. A run that prints CoreMark text proves
// functional execution of the real firmware; it does not by itself produce a valid
// contest score (see the +MAX_CYCLES budget and the report).
`timescale 1ns/1ps
module tb_coremark_uart;
    // Board clock is 27 MHz and the UART divisor is 234 (both the axi_uart reset value and
    // the value lib/uart.c writes from CPU_FREQ_HZ/115200), so 27e6/234 = 115384 baud.
    // The decoder self-test below runs while the SoC is in reset, when the divisor is the
    // reset value, so one constant covers both the self-test and firmware traffic.
    parameter integer BAUD_DIV      = 234;
    parameter integer MAX_CYCLES    = 2000000;  // override with +MAX_CYCLES=<n>
    parameter integer CLK_PERIOD_NS = 1;        // 1 ns = 1 GHz sim clock; SoC behaviour is cycle based

    reg clk=0; always #(CLK_PERIOD_NS/2.0) clk=~clk;
    reg rst_n=0;
    reg uart_rx=1, spi_miso=1;
    reg [1:0] gpio_input=0, ext_event=0;
    wire uart_tx,spi_mosi,spi_ss,spi_clk;
    wire [31:0] gpio_ctrl,gpio_data;
    wire halt_req=0, trap_ready=1, irq_software=0, irq_timer=0, irq_external=0;
    reg [4:0] debug_addr=0;
    wire halted;
    wire [31:0] arch_next_pc, trap_cause, trap_pc, trap_tval, csr_mtvec;
    wire trap_fire, retire_fire, rd_valid, protocol_fault;
    wire [63:0] retire_order;
    wire [31:0] retire_pc, retire_inst, wdata, debug_data;
    wire [4:0] rd;

    string prog_file, data_file;
    integer max_cycles;
    integer errors=0, retired=0, traps=0, faults=0, chars=0, cycles=0, lsu_faults=0, txd_writes=0, i=0, nonempty=0, uart_regw=0, uart_regr=0, d_ar=0, d_aw=0;

    pangoriscv_axi_soc #(.PROGRAM_INIT_FILE(""),.DATA_INIT_FILE(""),
                        .READ_DELAY(0),.WRITE_DELAY(0)) soc(
        .clk(clk),.rst_n(rst_n),.uart_rx(uart_rx),.uart_tx(uart_tx),
        .gpio_input(gpio_input),.gpio_ctrl(gpio_ctrl),.gpio_data(gpio_data),
        .spi_miso(spi_miso),.spi_mosi(spi_mosi),.spi_ss(spi_ss),.spi_clk(spi_clk),
        .ext_event(ext_event),
        .halt_req(halt_req),.halted(halted),.arch_next_pc(arch_next_pc),
        .trap_ready(trap_ready),.trap_vector(32'd0),
        .irq_software(irq_software),.irq_timer(irq_timer),.irq_external(irq_external),
        .csr_mtvec(csr_mtvec),
        .trap_fire(trap_fire),.trap_cause(trap_cause),.trap_pc(trap_pc),
        .trap_tval(trap_tval),.retire_fire(retire_fire),.retire_order(retire_order),
        .retire_pc(retire_pc),.retire_inst(retire_inst),.rd_valid(rd_valid),
        .rd(rd),.wdata(wdata),.debug_addr(debug_addr),.debug_data(debug_data),
        .protocol_fault(protocol_fault));

    // Data-master (port 1) AXI handshakes, probed on the SoC master wires.
    wire cpu_d_arvalid = soc.m_arvalid[1];
    wire cpu_d_arready = soc.m_arready[1];
    wire [31:0] cpu_d_araddr = soc.m_araddr[1*32 +: 32];
    wire cpu_d_awvalid = soc.m_awvalid[1];
    wire cpu_d_awready = soc.m_awready[1];
    wire [31:0] cpu_d_awaddr = soc.m_awaddr[1*32 +: 32];
    wire cpu_d_rvalid = soc.m_rvalid[1];
    wire cpu_d_rready = soc.m_rready[1];
    wire [31:0] cpu_d_rdata = soc.m_rdata[1*32 +: 32];
    wire cpu_d_rlast = soc.m_rlast[1];
    wire [1:0] cpu_d_rresp = soc.m_rresp[1*2 +: 2];
    wire cpu_d_wvalid = soc.m_wvalid[1];
    wire cpu_d_wready = soc.m_wready[1];
    wire [31:0] cpu_d_wdata = soc.m_wdata[1*32 +: 32];
    wire [3:0] cpu_d_wstrb = soc.m_wstrb[1*4 +: 4];
    wire cpu_d_bvalid = soc.m_bvalid[1];
    wire cpu_d_bready = soc.m_bready[1];
    wire [1:0] cpu_d_bresp = soc.m_bresp[1*2 +: 2];
    // Instruction master (port 0).
    wire cpu_i_arvalid = soc.m_arvalid[0];
    wire cpu_i_arready = soc.m_arready[0];
    wire [31:0] cpu_i_araddr = soc.m_araddr[0*32 +: 32];
    wire cpu_i_rvalid = soc.m_rvalid[0];
    wire cpu_i_rready = soc.m_rready[0];
    wire [31:0] cpu_i_rdata = soc.m_rdata[0*32 +: 32];
    wire cpu_i_rlast = soc.m_rlast[0];
    wire [1:0] cpu_i_rresp = soc.m_rresp[0*2 +: 2];

    // ---- image loading and plusargs -----------------------------------------
    initial begin
        if (!$value$plusargs("PROG=%s", prog_file)) prog_file="program.hex";
        if (!$value$plusargs("DATA=%s", data_file)) data_file="data.hex";
        if (!$value$plusargs("MAX_CYCLES=%d", max_cycles)) max_cycles=MAX_CYCLES;
        $readmemh(prog_file, soc.program_ram.mem);
        $readmemh(data_file, soc.data_ram.mem);
        $display("CORE_IMAGE prog=%s data=%s max_cycles=%0d", prog_file, data_file, max_cycles);
    end

    integer last_retire_cycle=0, stalls=0;
    integer prev_order=-1;
    // the caches and predictor branch statistics: retired control transfers and mispredictions.
    // soc.core.pred_miss is driven in every configuration (predict-not-taken
    // reference included), so default/cached static mispredictions are measurable here.
    integer ctrl_retired=0, mispred_retired=0;
    always @(posedge clk) if(rst_n) begin
        cycles=cycles+1;
        if(retire_fire) begin
            retired=retired+1;
            last_retire_cycle=cycles;
            if(retire_order[31:0]!==prev_order) prev_order=retire_order[31:0];
            // retired control transfers (same decode as rtl/perips/perf_regs.v)
            if((retire_inst[6:0]==7'h63 && retire_inst[14:12]!=3'b010
                                         && retire_inst[14:12]!=3'b011)
               || retire_inst[6:0]==7'h6f
               || (retire_inst[6:0]==7'h67 && retire_inst[14:12]==3'b000))
                ctrl_retired=ctrl_retired+1;
            if(soc.core.pred_miss) mispred_retired=mispred_retired+1;
        end
        if(cycles%500000==0) begin
            $display("PROGRESS cycles=%0d retires=%0d traps=%0d faults=%0d uart_chars=%0d pc=%08x arch_next_pc=%08x halted=%b last_retire_cycle=%0d uart_ctrl=%08x uart_status=%08x uart_tx=%b",
                     cycles,retired,traps,faults,chars,retire_pc,arch_next_pc,halted,last_retire_cycle,
                     soc.uart_inst.ctrl_q,soc.uart_inst.stat_q,uart_tx);
        end
        if(cycles-last_retire_cycle > 200000 && cycles>200000) begin
            $display("STALL_DETECT cycles=%0d last_retire_cycle=%0d retires=%0d arch_next_pc=%08x retire_pc=%08x uart_ctrl=%08x uart_baud=%08x uart_status=%08x",
                     cycles,last_retire_cycle,retired,arch_next_pc,retire_pc,soc.uart_inst.ctrl_q,soc.uart_inst.baud_q,soc.uart_inst.stat_q);
            $display("TEST_FAIL T_COREMARK_STALLED no retirement for 200000 cycles");
            $fatal(1,"retirement stalled");
        end
        if(trap_fire) begin
            traps=traps+1;
            if(traps<16)
                $display("TRAP cause=%0d pc=%08x tval=%08x order=%0d",trap_cause,trap_pc,trap_tval,retire_order);
        end
        if(protocol_fault) begin
            faults=faults+1;
            if(faults<8) $display("BUS_FAULT cycle=%0d",cycles);
        end
        // Liveness snapshot: shows whether the pipeline is still advancing.
        if(cycles!=0 && cycles%500000==0) begin
            $display("LIVE cycle=%0d retires=%0d arch_next_pc=%08x pc=%08x if_idle=%b lsu_state=%0d op_valid=%b done_valid=%b halted=%b",
                cycles,retired,arch_next_pc,retire_pc,
                soc.core.if_idle, soc.core.lsu.state,
                soc.core.op_valid, soc.core.done_valid, halted);
        end
        // First bus faults: which access failed, so a trap loop can be attributed.
        if(soc.core.lsu.state==3'd5 && soc.core.lsu.done_valid && soc.core.lsu.fault) begin
            lsu_faults=lsu_faults+1;
            if(lsu_faults<=12)
                $display("LSU_FAULT cycle=%0d addr=%08x store=%b size=%0d pc=%08x rd=%0d",
                         cycles,soc.core.lsu.fault_addr,soc.core.lsu.is_store,
                         soc.core.lsu.size_q,soc.core.lsu.pc_q,soc.core.lsu.rd_q);
        end
        if(soc.uart_inst.wr_hit) begin
            uart_regw=uart_regw+1;
            if(uart_regw<=12) $display("UART_REG_WRITE cycle=%0d off=%0d data=%08x",cycles,soc.uart_inst.wr_off,soc.uart_inst.wr_data);
        end
        if(soc.uart_inst.rd_hit) begin
            uart_regr=uart_regr+1;
            if(uart_regr<=12) $display("UART_REG_READ cycle=%0d off=%0d",cycles,soc.uart_inst.rd_off);
        end
        if(cpu_d_arvalid && cpu_d_arready) begin
            d_ar=d_ar+1;
            if(d_ar<=12) $display("D_AR cycle=%0d addr=%08x",cycles,cpu_d_araddr);
        end
        if(cpu_d_awvalid && cpu_d_awready) begin
            d_aw=d_aw+1;
            if(d_aw<=12) $display("D_AW cycle=%0d addr=%08x",cycles,cpu_d_awaddr);
        end
    end

    // Per-request latency counters: how long each AXI phase actually takes.
    always @(posedge clk) if(rst_n && cycles<=300) begin
        if(cpu_i_arvalid && cpu_i_arready) $display("I_AR cycle=%0d addr=%08x",cycles,cpu_i_araddr);
        if(cpu_i_rvalid && cpu_i_rready) $display("I_R  cycle=%0d data=%08x last=%b resp=%b",cycles,cpu_i_rdata,cpu_i_rlast,cpu_i_rresp);
        if(cpu_d_arvalid && cpu_d_arready) $display("D_AR cycle=%0d addr=%08x",cycles,cpu_d_araddr);
        if(cpu_d_rvalid && cpu_d_rready) $display("D_R  cycle=%0d data=%08x last=%b resp=%b",cycles,cpu_d_rdata,cpu_d_rlast,cpu_d_rresp);
        if(cpu_d_awvalid && cpu_d_awready) $display("D_AW cycle=%0d addr=%08x",cycles,cpu_d_awaddr);
        if(cpu_d_wvalid && cpu_d_wready) $display("D_W  cycle=%0d data=%08x strb=%b",cycles,cpu_d_wdata,cpu_d_wstrb);
        if(cpu_d_bvalid && cpu_d_bready) $display("D_B  cycle=%0d resp=%b",cycles,cpu_d_bresp);
    end

    // Retired-PC histogram over 256-byte regions: shows where the firmware spends
    // its time and whether it ever returns to the startup / UART / printf code.
    integer pc_hist[0:63];
    reg [31:0] first_pcs[0:7];
    integer pc_dbg=0;
    integer trace_fd;
    initial trace_fd=$fopen("retire_trace.txt","w");
    always @(posedge clk) if(rst_n && retire_fire) begin
        pc_hist[retire_pc[13:8]] = pc_hist[retire_pc[13:8]] + 1;
        if(pc_dbg<30000) begin
            first_pcs[pc_dbg] = retire_pc;
            if(trace_fd) $fwrite(trace_fd,"%0d %08x %08x\n",pc_dbg,retire_pc,retire_inst);
            pc_dbg=pc_dbg+1;
        end
    end

    // ---- UART TX decoder -----------------------------------------------------
    // Falling edge on uart_tx = start bit. Bit cells are then sampled at BAUD_DIV/2
    // after each boundary so decoding does not depend on observing the exact edge.
    reg [15:0] div_cnt=0;
    reg [3:0]  bit_idx=0;      // 0 = start bit cell
    reg [7:0]  sh=0;
    reg        busy=0;
    reg        tx_q=1;
    reg        tx_line_rx=1;   // decoder self-test source, selected by selfcheck_mode
    reg        selfcheck_mode;
    wire       decode_src = selfcheck_mode ? tx_line_rx : uart_tx;
    integer    selfcheck_chars=0;
    // Rolling matcher over the decoded stream so the run can stop once CoreMark
    // has printed its final report line instead of burning the whole cycle cap.
    reg [8*20-1:0] match_reg = 0;
    reg            report_seen = 0;
    reg [31:0]     report_cycle = 0;

    always @(posedge clk) begin
        tx_q <= decode_src;
        // No reset dependency: the self-test runs while the SoC is in reset.
        if(!busy) begin
            if(tx_q && !decode_src) begin
                busy<=1; div_cnt<=(BAUD_DIV/2); bit_idx<=0; sh<=0;
            end
        end else begin
            if(div_cnt==0) begin
                if(bit_idx==0) begin
                    if(decode_src!==1'b0) $display("UART_WARN start bit not low at sample");
                    bit_idx<=1; div_cnt<=BAUD_DIV-1;
                end else if(bit_idx<=8) begin
                    sh[bit_idx-1] = decode_src;     // blocking: complete sh is visible now
                    if(bit_idx==8) begin
                        chars=chars+1;
                        $write("%c", sh[7:0]);
                        match_reg = {match_reg[8*19-1:0], sh[7:0]};
                        // The final score line is only printed when the run is
                        // valid; the shorter tails cover both exit paths.
                        if(!report_seen &&
                           (match_reg[8*15-1:0] === "Errors detected" ||
                            match_reg[8*17-1:0] === "Correct operation" ||
                            match_reg[8*12-1:0] === "CoreMark 1.0")) begin
                            report_seen = 1;
                            report_cycle = cycles;
                        end
                        bit_idx<=9; div_cnt<=BAUD_DIV-1;
                    end else begin
                        bit_idx<=bit_idx+1; div_cnt<=BAUD_DIV-1;
                    end
                end else begin
                    if(decode_src!==1'b1) $display("UART_WARN stop bit not high");
                    busy<=0; bit_idx<=0;
                end
            end else div_cnt<=div_cnt-1;
        end
    end

    // Count TXDATA writes that actually reach the UART register file.
    always @(posedge clk) if(rst_n && soc.uart_inst.wr_hit && soc.uart_inst.wr_off==12) begin
        txd_writes=txd_writes+1;
        if(txd_writes<8)
            $display("UART_TXD_WRITE cycle=%0d data=%02x ctrl=%08x status=%08x",
                     cycles,soc.uart_inst.wr_data[7:0],soc.uart_inst.ctrl_q,soc.uart_inst.stat_q);
    end

    // Any write reaching any peripheral or RAM endpoint (to separate "CPU never
    // stored" from "UART register never written").
    integer any_writes=0;
    always @(posedge clk) if(rst_n && (soc.uart_inst.wr_hit || soc.gpio_inst.we || soc.timer_inst.we || soc.spi_inst.wr_hit)) begin
        any_writes=any_writes+1;
        if(any_writes<12)
            $display("PERIPH_WRITE cycle=%0d addr=%08x data=%08x strb=%b uart=%b gpio=%b timer=%b spi=%b",
                     cycles, soc.uart_inst.wr_hit?32'h30000000+soc.uart_inst.wr_off:
                               soc.gpio_inst.we?32'h40000000+soc.gpio_inst.wo:
                               soc.timer_inst.we?32'h20000000+soc.timer_inst.wo:
                               32'h50000000+soc.spi_inst.wr_off,
                     soc.uart_inst.wr_hit?soc.uart_inst.wr_data:
                               soc.gpio_inst.we?soc.gpio_inst.wd:
                               soc.timer_inst.we?soc.timer_inst.wd:soc.spi_inst.wr_data,
                     soc.uart_inst.wr_hit?soc.uart_inst.wr_strb:
                               soc.gpio_inst.we?soc.gpio_inst.ws:
                               soc.timer_inst.we?soc.timer_inst.ws:soc.spi_inst.wr_strb,
                     soc.uart_inst.wr_hit,soc.gpio_inst.we,soc.timer_inst.we,soc.spi_inst.wr_hit);
    end

    // Read/write activity at the LSU level and on the AXI write channel.
    integer lsu_stores=0;
    always @(posedge clk) if(rst_n && soc.core.lsu.op_valid && soc.core.lsu.op_ready && soc.core.lsu.is_store) begin
        lsu_stores=lsu_stores+1;
        if(lsu_stores<12)
            $display("LSU_STORE cycle=%0d addr=%08x size=%0d",cycles,soc.core.lsu.address,soc.core.lsu.access_size);
    end

    // Decoder self-test: drive one known byte (0x55) onto the decoded line before
    // the SoC is released, so "no characters" can be attributed to the UART/firmware
    // and not to this decoder.
    task automatic uart_selfcheck_send(input [7:0] value);
        integer k;
        begin
            tx_line_rx=0; @(posedge clk);                       // start bit
            repeat(BAUD_DIV) @(posedge clk);
            for(k=0;k<8;k=k+1) begin
                tx_line_rx=value[k]; repeat(BAUD_DIV) @(posedge clk);
            end
            tx_line_rx=1; repeat(BAUD_DIV) @(posedge clk);
        end
    endtask

    // ---- store-path decomposition (optimization plan P2') ---------------------
    // Where does a store's time go? dcache_axi parks in three write states:
    //   ST_WR_REQ  =4 : waiting for the AXI write engine to accept AW/W
    //   ST_WR_RESP =5 : waiting for the AXI B response
    //   ST_WR_HOLD =6 : holding the response until the CPU takes it
    // Counting cycles in each tells whether "not waiting for B" would buy anything.
    integer st_wr_req=0, st_wr_resp=0, st_wr_hold=0;
    always @(posedge clk) if(rst_n) begin
        if(soc.core.data_cache.state_q==4'd4) st_wr_req =st_wr_req +1;
        if(soc.core.data_cache.state_q==4'd5) st_wr_resp=st_wr_resp+1;
        if(soc.core.data_cache.state_q==4'd6) st_wr_hold=st_wr_hold+1;
    end

    // ---- EX occupancy decomposition (optimization plan P1) --------------------
    // perf_regs' LSU_WAIT only counts the pre-issue window (op_valid drops once
    // `issued` is set), so the AXI round trip after a load/store leaves is not
    // visible there. These testbench-only counters split EX occupancy instead.
    // They are hierarchical probes: no RTL change, no image change.
    integer ex_busy=0, ex_mem_post=0, ex_div_busy=0, lsu_nonidle=0;
    integer mem_ops=0, mem_ld=0, mem_st=0;
    always @(posedge clk) if(rst_n) begin
        if(soc.core.cpu.ex_valid && !soc.core.cpu.ex_leave) ex_busy=ex_busy+1;
        if(soc.core.cpu.ex_valid && soc.core.cpu.is_memory &&
           soc.core.cpu.issued && !soc.core.cpu.ex_leave) ex_mem_post=ex_mem_post+1;
        if(soc.core.cpu.ex_valid && soc.core.cpu.is_div &&
           !soc.core.cpu.ex_leave) ex_div_busy=ex_div_busy+1;
        if(soc.core.lsu.state!=3'd0) lsu_nonidle=lsu_nonidle+1;
        // accepted memory operations, split into loads and stores
        if(soc.core.cpu.op_valid && soc.core.cpu.op_ready) begin
            mem_ops=mem_ops+1;
            if(soc.core.cpu.is_store) mem_st=mem_st+1; else mem_ld=mem_ld+1;
        end
    end

    // ---- termination ---------------------------------------------------------
    initial begin
        selfcheck_mode=1; tx_line_rx=1;
        repeat(20) @(negedge clk);
        // Decoder self-test while the SoC is still in reset.
        uart_selfcheck_send(8'h55);
        if(chars==0) begin
            $display("TEST_FAIL UART_DECODER_SELFTEST no byte decoded");
            $fatal(1,"uart decoder self-test failed");
        end
        selfcheck_chars=chars; selfcheck_mode=0;
        $display("UART_SELFTEST decoded=%0d bytes (expect 1)",selfcheck_chars);
        chars=0;                              // only firmware traffic counts from here
        repeat(4) @(negedge clk);
        rst_n=1;
        fork
            begin wait(cycles>=max_cycles); end
            begin
                wait(report_seen);
                // Let the remaining report lines and the UART shift register drain.
                // One character is 10 bit cells x BAUD_DIV(234) = 2340 cycles, so the
                // original 12000 cycles covered only ~5 characters: that is why
                // "Correct operation validated." and the PERF_DUMP line printed by
                // core_portme.c after the report were being cut off. 250000 cycles
                // covers ~106 characters, enough for both tails with margin.
                repeat(250000) @(posedge clk);
            end
        join_any
        $display("");
        $display("CORE_REPORT_SEEN %0d report_cycle=%0d stop_cycle=%0d",report_seen,report_cycle,cycles);
        if(trace_fd) $fclose(trace_fd);
        $display("");
        $display("CORE_SUMMARY cycles=%0d retires=%0d traps=%0d faults=%0d uart_chars=%0d txd_writes=%0d ctrl=%0d mispred=%0d", cycles, retired, traps, faults, chars, txd_writes, ctrl_retired, mispred_retired);
        $display("EX_OCCUPANCY ex_busy=%0d ex_mem_post=%0d ex_div_busy=%0d lsu_nonidle=%0d", ex_busy, ex_mem_post, ex_div_busy, lsu_nonidle);
        $display("MEM_OPS ops=%0d ld=%0d st=%0d  axi_d_ar=%0d axi_d_aw=%0d", mem_ops, mem_ld, mem_st, d_ar, d_aw);
        $display("STORE_PATH st_wr_req=%0d st_wr_resp=%0d st_wr_hold=%0d st_total=%0d", st_wr_req, st_wr_resp, st_wr_hold, st_wr_req+st_wr_resp+st_wr_hold);
        if(txd_writes!=0 && chars==0) begin
            $display("TEST_FAIL UART_LOOPBACK no decoded byte although %0d TXDATA writes reached the UART",txd_writes);
            $fatal(1,"uat tx broken");
        end
        $display("TEST_PASS T_COREMARK_BOUNDED retires=%0d traps=%0d cycles=%0d txd_writes=%0d",retired,traps,cycles,txd_writes);
        $finish;
    end
endmodule
