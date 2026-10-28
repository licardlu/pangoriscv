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
// The hierarchical probes below reach into soc.core.data_cache, which only exists
// when CACHE_ENABLE is defined.  vlog compiles each source file as its own
// compilation unit here, so the macro does not carry over from the RTL files:
// include the same configuration header the RTL uses, so the guards below track
// the real build instead of silently disabling themselves.
`include "soc_config.vh"
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
`ifdef IVL_ZERO_INIT
        // The board powers up with every BRAM word at its init value (0).  A
        // Verilog `reg` array starts at X instead, so any fetch or load from a
        // word the hex file does not cover drags X into the pipeline and the
        // run locks up on `fetch_valid=x`.  Zeroing first makes the simulator
        // model the FPGA rather than the language default.
        begin : zero_init
            integer zi;
            for (zi=0; zi<8192; zi=zi+1) soc.program_ram.mem[zi] = 32'h0;
            for (zi=0; zi<4096; zi=zi+1) soc.data_ram.mem[zi] = 32'h0;
        end
`endif
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
    integer pair_retired=0;
    always @(posedge clk) if(rst_n) begin
        cycles=cycles+1;
        if(retire_fire) begin
            retired=retired+((soc.core.cpu.ex_valid_h)?2:1);
            if(soc.core.cpu.ex_valid_h) pair_retired=pair_retired+1;
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
        // Periodic snapshots are behind TB_PROGRESS: their $display can interleave
        // with the firmware's UART report and destroy the `Total ticks` line,
        // which IS the score.  A/B runs therefore run without them.
`ifdef TB_PROGRESS
        if(cycles%500000==0) begin
            $display("PROGRESS cycles=%0d retires=%0d traps=%0d faults=%0d uart_chars=%0d pc=%08x arch_next_pc=%08x halted=%b last_retire_cycle=%0d uart_ctrl=%08x uart_status=%08x uart_tx=%b",
                     cycles,retired,traps,faults,chars,retire_pc,arch_next_pc,halted,last_retire_cycle,
                     soc.uart_inst.ctrl_q,soc.uart_inst.stat_q,uart_tx);
        end
`endif
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
`ifdef TB_PROGRESS
        if(cycles!=0 && cycles%500000==0) begin
            $display("LIVE cycle=%0d retires=%0d arch_next_pc=%08x pc=%08x if_idle=%b lsu_state=%0d op_valid=%b done_valid=%b halted=%b",
                cycles,retired,arch_next_pc,retire_pc,
                soc.core.if_idle, soc.core.lsu.state,
                soc.core.op_valid, soc.core.done_valid, halted);
        end
`endif
        // First bus faults: which access failed, so a trap loop can be attributed.
        // P9: a completion is now reported on the engine RESPONSE edge, which is
        // READ_WAIT (3) for loads and WRITE_WAIT (4) for stores; COMPLETE (5) only
        // holds it when the consumer stalls. Probe all three, or this diagnostic
        // line would go silent after the change.
        if((soc.core.lsu.state==3'd3 || soc.core.lsu.state==3'd4 ||
            soc.core.lsu.state==3'd5) && soc.core.lsu.done_valid && soc.core.lsu.fault) begin
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
`ifdef CACHE_ENABLE
    always @(posedge clk) if(rst_n) begin
        if(soc.core.data_cache.state_q==4'd4) st_wr_req =st_wr_req +1;
        if(soc.core.data_cache.state_q==4'd5) st_wr_resp=st_wr_resp+1;
        if(soc.core.data_cache.state_q==4'd6) st_wr_hold=st_wr_hold+1;
    end
`endif

    // ---- D-Cache refill cost (optimization plan P14) ---------------------------
    // LSU rdwait is ~11.6% of all cycles, yet d_miss is only ~0.3% of loads.  That
    // arithmetic does not close, so count the two sides separately BEFORE touching
    // any RTL: how many operations enter READ_WAIT at all, and how many cycles the
    // line refill (ST_RD_AR + ST_RD_DATA) itself occupies.
    integer dc_idle=0, dc_hit=0, dc_rdar=0, dc_rddata=0, dc_byp=0, dc_drain=0;
    integer rdwait_entries=0, refills=0;
    // Bucket every load by address region so a "18% of loads are uncached" reading
    // can be pinned to a region instead of guessed at.
    integer ld_lo=0, ld_data=0, ld_hi=0;
    integer sl_lo=0, sl_data=0, sl_hi=0;
    integer nh_lo=0, nh_data=0, nh_hi=0;
    // Mispredict mix: a return-address stack only helps if returns are a large
    // share of the mispredictions.  Bucket by the retiring opcode.
    integer misp_ret=0, misp_jal=0, misp_br=0, misp_other=0;
    always @(posedge clk) if(rst_n && !report_seen) begin
        if(retire_fire && soc.core.pred_miss) begin
            if(retire_inst[6:0]==7'h67)      misp_ret  =misp_ret  +1;   // jalr (returns)
            else if(retire_inst[6:0]==7'h6f) misp_jal  =misp_jal  +1;   // jal
            else if(retire_inst[6:0]==7'h63) misp_br   =misp_br   +1;   // branches
            else                             misp_other=misp_other+1;
        end
    end
    // split the >=0x2000_0000 load traffic per 0x1000_0000 region
    integer hi2=0, hi3=0, hi4=0, hi5=0, hi6=0;
    always @(posedge clk) if(rst_n) begin
        if(soc.core.lsu.state==3'd0 && soc.core.op_valid && soc.core.op_ready &&
           !soc.core.lsu.is_store && soc.core.lsu.address>=32'h2000_0000) begin
            if(soc.core.lsu.address<32'h3000_0000) hi2=hi2+1;
            else if(soc.core.lsu.address<32'h4000_0000) hi3=hi3+1;
            else if(soc.core.lsu.address<32'h5000_0000) hi4=hi4+1;
            else if(soc.core.lsu.address<32'h6000_0000) hi5=hi5+1;
            else begin
                hi6=hi6+1;
            end
        end
    end
    reg lsu_was_rdwait=0;
    reg [3:0] prev_dc_state=4'd0;
    // NOTE: soc.core.data_cache only exists when CACHE_ENABLE is defined, and
    // tools/run_coremark_ab.py deliberately also builds a cache_off side.  Every
    // probe that reaches into the cache is therefore `ifdef CACHE_ENABLE; the
    // counters stay 0 in the cache_off build and the $display lines still work.
    //
    // The gate is !report_seen, which fires on the report's LAST line, so these
    // counters still include the report printing (the UART busy-wait). Use the
    // SCORE_WINDOW line -- snapshotted at the first TXDATA write -- for a clean
    // score-window decomposition.
`ifdef CACHE_ENABLE
    always @(posedge clk) if(rst_n && !report_seen) begin
        case(soc.core.data_cache.state_q)
            4'd0: dc_idle  =dc_idle  +1;
            4'd1: dc_hit   =dc_hit   +1;
            4'd2: dc_rdar  =dc_rdar  +1;
            4'd3: dc_rddata=dc_rddata+1;
            4'd7: dc_byp   =dc_byp   +1;
            4'd9: dc_drain =dc_drain +1;
        endcase
        // a line refill (cacheable miss) is ST_RD_AR -> ST_RD_DATA
        if(soc.core.data_cache.state_q==4'd3 && prev_dc_state==4'd2) refills=refills+1;
        prev_dc_state = soc.core.data_cache.state_q;
    end
`endif
    always @(posedge clk) if(rst_n && !report_seen) begin
        // accepted memory op: bucket loads and stores by region
        if(soc.core.lsu.state==3'd0 && soc.core.op_valid && soc.core.op_ready) begin
            if(soc.core.lsu.is_store) begin
                if(soc.core.lsu.address<32'h1000_0000)      sl_lo  =sl_lo  +1;
                else if(soc.core.lsu.address<32'h2000_0000) sl_data=sl_data+1;
                else                                       sl_hi  =sl_hi  +1;
            end else begin
                if(soc.core.lsu.address<32'h1000_0000)      ld_lo  =ld_lo  +1;
                else if(soc.core.lsu.address<32'h2000_0000) ld_data=ld_data+1;
                else                                       ld_hi  =ld_hi  +1;
            end
        end
        if(soc.core.lsu.state==3'd3 && !lsu_was_rdwait) begin
            rdwait_entries=rdwait_entries+1;
            if(soc.core.lsu.address_q<32'h1000_0000)      nh_lo  =nh_lo  +1;
            else if(soc.core.lsu.address_q<32'h2000_0000) nh_data=nh_data+1;
            else                                          nh_hi  =nh_hi  +1;
        end
        lsu_was_rdwait = (soc.core.lsu.state==3'd3);
    end

    // ---- LSU path decomposition (optimization plan P8) ------------------------
    // A load currently walks EMPTY -> REQUEST -> READ_WAIT -> COMPLETE.  The
    // REQUEST state exists only to register the address before asking the
    // engine, so it costs one cycle per memory operation.  Counting cycles per
    // LSU state checks the claim "REQUEST cycles ~= memory operations" BEFORE
    // the RTL is touched.  Testbench-only hierarchical probes, like STORE_PATH.
    integer l_emp=0, l_req=0, l_wdat=0, l_rdwait=0, l_wrwait=0, l_comp=0;
    // Who is waiting in the REQUEST fallback?  That state only exists because the
    // cache refused the request that cycle, so splitting it by operation class
    // says whether a store queue would actually pay for itself.
    integer l_req_st=0, l_req_ld=0, l_wdat_st=0;
    // Where do the ~43 cycles of an I-Cache miss go?  If most of it is the AR
    // round trip, an early-restart scheme would not help; if it is the 8-beat
    // fill, it would.  Measure before designing anything.
    integer ic_idle=0, ic_aresp=0, ic_ar=0, ic_fill=0, ic_mrd=0, ic_resp=0, ic_fault=0;
`ifdef CACHE_ENABLE
    always @(posedge clk) if(rst_n && !report_seen) begin
        case(soc.core.instruction_cache.state)
            3'd0: ic_idle =ic_idle +1;
            3'd1: ic_resp =ic_resp +1;
            3'd2: ic_ar   =ic_ar   +1;
            3'd3: ic_fill =ic_fill +1;
            3'd4: ic_mrd  =ic_mrd  +1;
            3'd5: ic_fault=ic_fault+1;
        endcase
    end
`endif
    always @(posedge clk) if(rst_n && !report_seen) begin
        if(soc.core.lsu.state==3'd1) begin
            if(soc.core.lsu.is_store) l_req_st=l_req_st+1; else l_req_ld=l_req_ld+1;
        end
        if(soc.core.lsu.state==3'd2 && soc.core.lsu.is_store) l_wdat_st=l_wdat_st+1;
    end
    always @(posedge clk) if(rst_n && !report_seen) begin
        case(soc.core.lsu.state)
            3'd0: l_emp   =l_emp   +1;
            3'd1: l_req   =l_req   +1;
            3'd2: l_wdat  =l_wdat  +1;
            3'd3: l_rdwait=l_rdwait+1;
            3'd4: l_wrwait=l_wrwait+1;
            3'd5: l_comp  =l_comp  +1;
        endcase
    end

    // ---- EX occupancy decomposition (optimization plan P1) --------------------
    // perf_regs' LSU_WAIT only counts the pre-issue window (op_valid drops once
    // `issued` is set), so the AXI round trip after a load/store leaves is not
    // visible there. These testbench-only counters split EX occupancy instead.
    // They are hierarchical probes: no RTL change, no image change.
    integer ex_busy=0, ex_mem_post=0, ex_div_busy=0, lsu_nonidle=0;
    // Split EX occupancy by what is parked there.  `ex_busy` alone cannot tell a
    // load-use hazard from a store waiting for B, and the next step depends on
    // which one it is.  Also count ID back-pressure and non-retiring cycles.
    integer exb_load=0, exb_store=0, exb_other=0, id_stall=0, no_retire=0, retire_cyc=0;
    always @(posedge clk) if(rst_n && !report_seen) begin
        if(soc.core.cpu.ex_valid && !soc.core.cpu.ex_leave) begin
            if(soc.core.cpu.is_memory && !soc.core.cpu.is_store) exb_load =exb_load +1;
            else if(soc.core.cpu.is_memory)                      exb_store=exb_store+1;
            else                                                 exb_other=exb_other+1;
        end
        if(soc.core.cpu.id_valid && !soc.core.cpu.id_ready) id_stall=id_stall+1;
        if(retire_fire) retire_cyc=retire_cyc+1; else no_retire=no_retire+1;
    end
    // ---- redirect recovery latency ------------------------------------------
    // 137,933 mispredictions cannot explain 711k empty-EX cycles on their own; the
    // interesting number is how long the front end needs to deliver the first
    // instruction after a redirect.  Measured (not estimated) so the next front-end
    // change is chosen from data.
    integer rd_n=0, rd_lat=0;
    reg     rd_pend=0;
    integer rd_t0=0;
    always @(posedge clk) if(rst_n && !report_seen) begin
        if(soc.core.cpu.redirect_valid) begin
            rd_pend <= 1; rd_t0 = cycles;
        end else if(rd_pend && soc.core.cpu.fetch_valid && soc.core.cpu.fetch_ready) begin
            rd_lat = rd_lat + (cycles - rd_t0);
            rd_n   = rd_n + 1;
            rd_pend <= 0;
        end
    end
    // Snapshot at the FIRST UART TXDATA write: CoreMark prints its report only
    // after stop_time(), so that write marks the end of the scored window.
    // Everything afterwards (the report's busy-wait polling on 0x3000_0000) must
    // not be attributed to the benchmark.
    integer sw_cycles=0, sw_retires=0, sw_load=0, sw_store=0, sw_other=0;
    integer sw_idstall=0, sw_noretire=0, sw_done=0;
    always @(posedge clk) if(rst_n && !sw_done &&
                             soc.uart_inst.wr_hit && soc.uart_inst.wr_off==12) begin
        sw_cycles=cycles; sw_retires=retired;
        sw_load=exb_load; sw_store=exb_store; sw_other=exb_other;
        sw_idstall=id_stall; sw_noretire=no_retire;
        sw_done=1;
    end
    // ---- D1 (plan v6 section 4): SCORE-WINDOW-ONLY attribution ----------------
    // Every counter above except the SCORE_WINDOW snapshot is gated on
    // `!report_seen`, i.e. it also measures the CoreMark *report printing*, where
    // the CPU spins on the UART status register.  That spin is 122,461 uncached
    // MMIO reads at ~4.6 cycles each = 0.58 M cycles which are NOT in the score
    // window (ADDR_REGION ld_hi=122,461, nonhit_hi=122,461).  Reading the
    // whole-program counters as "the window's bottleneck" points the next
    // optimization at the printer.  These probes are gated on `!sw_done`, so
    // their buckets ADD UP to the window's cycle count.
    integer w_mem=0, w_div=0, w_trap=0, w_stall=0, w_hold=0;
    integer w_sgl_br=0, w_sgl_jal=0, w_sgl_jalr=0, w_sgl_mem=0, w_sgl_alu=0;
    integer w_sgl_btaken=0;      // single-issue cycle whose lane 0 was a taken branch
    integer w_sgl_nopair=0, w_sgl_memmem=0, w_sgl_lduse=0, w_sgl_mduse=0,
            w_sgl_alone=0, w_sgl_l1bad=0, w_sgl_ffault=0, w_sgl_other=0,
            w_sgl_br_nopair=0;
    integer w_fpair=0, w_fsingle=0;   // fetch handshakes with / without a pair
    integer w_a_pair=0, w_a_single=0, w_a_ref=0, w_miss=0;
    integer w_starve_stale=0, w_starve_inflight=0, w_starve_mismatch=0, w_starve_empty=0;
    integer w_r_lduse=0, w_r_mduse=0, w_r_memmem=0, w_r_alone=0,
            w_r_jalr=0, w_r_ser=0, w_r_l1bad=0, w_r_othr=0;
    integer w_none_starve=0, w_none_other=0;
    integer w_pair=0, w_single=0, w_none=0, w_redir=0;
    integer w_lsu_req=0, w_lsu_rdwait=0, w_lsu_wrwait=0;
    integer w_reqld=0, w_reqst=0;
    integer w_ld_idle=0, w_ld_rdar=0, w_ld_rddata=0, w_ld_hold=0, w_ld_byp=0,
            w_ld_drain=0, w_ld_post=0, w_ld_oth=0;
    integer w_st_idle=0, w_st_wrreq=0, w_st_wrresp=0, w_st_hold=0,
            w_st_drain=0, w_st_post=0, w_st_oth=0;
    integer w_dc_drain=0, w_dc_rdar=0, w_dc_rddata=0, w_dc_idle=0;
    always @(posedge clk) if(rst_n && !sw_done) begin
        if(soc.core.cpu.mem_wait)  w_mem   = w_mem   + 1;
        if(soc.core.cpu.div_wait)  w_div   = w_div   + 1;
        if(soc.core.cpu.trap_wait) w_trap  = w_trap  + 1;
        if(soc.core.cpu.stall)     w_stall = w_stall + 1;
        if(soc.core.cpu.hold_ex)   w_hold  = w_hold  + 1;
        if(soc.core.cpu.redirect_valid) w_redir = w_redir + 1;
        if(soc.core.cpu.fetch_valid && soc.core.cpu.fetch_ready)
            if(soc.core.cpu.fetch_pair) w_fpair = w_fpair + 1;
            else                        w_fsingle = w_fsingle + 1;
        // Aligned view: `pair_ok` and `fetch_pair` are the two terms of the SAME
        // accept edge, so this bucket is exact (the RR-stage buckets above are
        // one cycle behind: `id_valid` is the ID->RR register).
        if(soc.core.cpu.fetch_valid && soc.core.cpu.fetch_ready) begin
            if(!soc.core.cpu.fetch_pair) w_a_single = w_a_single + 1;
            else if(soc.core.cpu.pair_ok) w_a_pair = w_a_pair + 1;
            else begin
                w_a_ref = w_a_ref + 1;
                if(soc.core.cpu.packet_load_use)                  w_r_lduse = w_r_lduse + 1;
                else if(soc.core.cpu.packet_md_use)               w_r_mduse = w_r_mduse + 1;
                else if(soc.core.cpu.lane0_mem && soc.core.cpu.lane1_mem) w_r_memmem = w_r_memmem + 1;
                else if(soc.core.cpu.lane0_issue_alone) begin
                    w_r_alone = w_r_alone + 1;
                    if(soc.core.cpu.dec_jalr)  w_r_jalr = w_r_jalr + 1;
                    if(soc.core.cpu.dec_serial)w_r_ser  = w_r_ser  + 1;
                end
                else if(!soc.core.cpu.lane1_ok)                   w_r_l1bad = w_r_l1bad + 1;
                else                                              w_r_othr  = w_r_othr + 1;
            end
        end
        if(soc.core.pred_miss) w_miss = w_miss + 1;
        // Starvation split: the IFU refuses to ask for the redirect target while
        // it still owes a response to the stream it just flushed
        // (`eng_req_valid && (stale_cnt_q==0)`).  If that gate is what the 0.3 M
        // starve cycles sit in, the fix is "issue the target immediately and
        // drop the stale response when it lands"; if not, the fix is elsewhere.
        if(soc.core.fetch_ready && !soc.core.fetch_valid) begin
            if(soc.core.ifu.stale_cnt_q != 0)      w_starve_stale = w_starve_stale + 1;
            else if(soc.core.ifu.ocnt_q != 0)      w_starve_inflight = w_starve_inflight + 1;
            else if(soc.core.ifu.count_q != 0)     w_starve_mismatch = w_starve_mismatch + 1;
            else                                   w_starve_empty = w_starve_empty + 1;
        end
        if(soc.core.cpu.id_valid && soc.core.cpu.id_valid_h) w_pair = w_pair + 1;        else if(soc.core.cpu.id_valid) begin
            w_single = w_single + 1;
            // Why is lane 1 missing?  A control transfer in lane 0 ends the
            // packet by construction; anything else means the fetch stream only
            // had one instruction to give.
            if(soc.core.cpu.id_br)       w_sgl_br  = w_sgl_br  + 1;
            else if(soc.core.cpu.id_jal) w_sgl_jal = w_sgl_jal + 1;
            else if(soc.core.cpu.id_jalr)w_sgl_jalr= w_sgl_jalr+ 1;
            else if(soc.core.cpu.id_load || soc.core.cpu.id_store) w_sgl_mem = w_sgl_mem + 1;
            else                         w_sgl_alu = w_sgl_alu + 1;
            // Second level: WHICH rule left lane 1 empty.  `pair_ok` is a chain of
            // AND terms; bucketing the first false one is what tells "the fetch
            // stream only had one word" apart from "we refused the pair".
            if(!soc.core.cpu.fetch_pair)                        w_sgl_nopair = w_sgl_nopair + 1;
            else if(soc.core.cpu.lane0_mem && soc.core.cpu.lane1_mem) w_sgl_memmem = w_sgl_memmem + 1;
            else if(soc.core.cpu.packet_load_use)               w_sgl_lduse  = w_sgl_lduse  + 1;
            else if(soc.core.cpu.packet_md_use)                 w_sgl_mduse  = w_sgl_mduse  + 1;
            else if(soc.core.cpu.lane0_issue_alone)             w_sgl_alone  = w_sgl_alone  + 1;
            else if(!soc.core.cpu.lane1_ok)                     w_sgl_l1bad  = w_sgl_l1bad  + 1;
            else if(soc.core.cpu.fetch_fault || soc.core.cpu.fetch_fault_hi) w_sgl_ffault = w_sgl_ffault + 1;
            else                                                w_sgl_other  = w_sgl_other  + 1;
            if(!soc.core.cpu.fetch_pair && soc.core.cpu.id_br)  w_sgl_br_nopair = w_sgl_br_nopair + 1;
            if(soc.core.cpu.id_br && (soc.core.cpu.id_pred != soc.core.cpu.id_pc + 32'd4))
                w_sgl_btaken = w_sgl_btaken + 1;
        end else begin
            w_none = w_none + 1;
            if(!soc.core.fetch_valid) w_none_starve = w_none_starve + 1;
            else                      w_none_other  = w_none_other  + 1;
        end
        case(soc.core.lsu.state)
            3'd1: w_lsu_req   = w_lsu_req   + 1;
            3'd3: w_lsu_rdwait= w_lsu_rdwait+ 1;
            3'd4: w_lsu_wrwait= w_lsu_wrwait+ 1;
        endcase
        // Who refuses the request?  The LSU parks in REQUEST for one cycle per
        // memory op even when the cache takes it on that edge, so only the
        // second and later cycles are a real refusal -- but the split by cache
        // state is what decides whether the fix is "decouple the drain" or
        // "deeper store queue".
        if(soc.core.lsu.state==3'd1) begin
            if(soc.core.lsu.is_store) begin
                w_reqst = w_reqst + 1;
                case(soc.core.data_cache.state_q)
                    4'd0: w_st_idle = w_st_idle + 1;
                    4'd4: w_st_wrreq= w_st_wrreq+ 1;
                    4'd5: w_st_wrresp=w_st_wrresp+1;
                    4'd6: w_st_hold = w_st_hold + 1;
                    4'd9: w_st_drain= w_st_drain+ 1;
                    4'd10:w_st_post = w_st_post + 1;
                    default: w_st_oth = w_st_oth + 1;
                endcase
            end else begin
                w_reqld = w_reqld + 1;
                case(soc.core.data_cache.state_q)
                    4'd0: w_ld_idle = w_ld_idle + 1;
                    4'd2: w_ld_rdar = w_ld_rdar + 1;
                    4'd3: w_ld_rddata=w_ld_rddata+1;
                    4'd6: w_ld_hold = w_ld_hold + 1;
                    4'd7: w_ld_byp  = w_ld_byp  + 1;
                    4'd9: w_ld_drain= w_ld_drain+ 1;
                    4'd10:w_ld_post = w_ld_post + 1;
                    default: w_ld_oth = w_ld_oth + 1;
                endcase
            end
        end
`ifdef CACHE_ENABLE
        case(soc.core.data_cache.state_q)
            4'd0: w_dc_idle  = w_dc_idle  + 1;
            4'd2: w_dc_rdar  = w_dc_rdar  + 1;
            4'd3: w_dc_rddata= w_dc_rddata+ 1;
            4'd9: w_dc_drain = w_dc_drain + 1;
        endcase
`endif
    end

    // ---- D6: WHY DOES THE FRONT END HAND OVER ONLY ONE WORD? -----------------
    // `WIN_ACCEPT single=494,108` costs 494 kcycles today and 247 kcycles even
    // if every one of them could be paired, so this is the largest single lever
    // left.  Three mutually exclusive explanations, three different fixes:
    //   (a) the pair would cross the 32 B line  -> `!eng_rsp_pair` in bypass, or
    //       a head whose offset is 7 in the queue.  Fix = second-line lookup.
    //   (b) the queue simply holds one entry    -> `count_q<=1`.  Fix = let the
    //       request pipeline run further ahead.
    //   (c) queued, two entries, but the second is not the head's predicted
    //       successor                          -> the prefetch chain broke.
    // Bucket by PC word offset as well: a stream that stays 8 B aligned never
    // visits offset 7, so a tall bucket at 7 means (a) and a flat histogram
    // means (b)/(c).
    integer w_np_off0=0,w_np_off1=0,w_np_off2=0,w_np_off3=0,
            w_np_off4=0,w_np_off5=0,w_np_off6=0,w_np_off7=0;
    integer w_np_byp=0, w_np_queued=0, w_np_cnt_le1=0, w_np_cnt_gt1=0;
    // Second LSU port: which lane wants memory.  (load,store) is cheapest to fix
    // (the store only needs a queue slot), (load,load) needs a real dual port.
    integer w_mm_ll=0, w_mm_ls=0, w_mm_sl=0, w_mm_ss=0;
    // `l1bad` = lane 1 is an instruction this machine deliberately refuses to
    // pair.  A second multiplier fixes only the first bucket.
    integer w_l1_mul=0, w_l1_div=0, w_l1_jalr=0, w_l1_csr=0,
            w_l1_ctl=0, w_l1_ill=0, w_l1_misc=0;
    // `none other` = the front end HAS an instruction but the pipeline retires
    // nothing.  Split by the core's own stall sources.
    integer w_no_mem=0, w_no_div=0, w_no_trap=0, w_no_redir=0, w_no_hold=0, w_no_oth=0;
    always @(posedge clk) if(rst_n && !sw_done) begin
        if(soc.core.cpu.fetch_valid && soc.core.cpu.fetch_ready &&
           !soc.core.cpu.fetch_pair) begin
            case(soc.core.cpu.fetch_pc[4:2])
                3'd0: w_np_off0 = w_np_off0 + 1;
                3'd1: w_np_off1 = w_np_off1 + 1;
                3'd2: w_np_off2 = w_np_off2 + 1;
                3'd3: w_np_off3 = w_np_off3 + 1;
                3'd4: w_np_off4 = w_np_off4 + 1;
                3'd5: w_np_off5 = w_np_off5 + 1;
                3'd6: w_np_off6 = w_np_off6 + 1;
                default: w_np_off7 = w_np_off7 + 1;
            endcase
            if(soc.core.ifu.response_bypass) w_np_byp = w_np_byp + 1;
            else                             w_np_queued = w_np_queued + 1;
            if(soc.core.ifu.count_q <= 1)    w_np_cnt_le1 = w_np_cnt_le1 + 1;
            else                             w_np_cnt_gt1 = w_np_cnt_gt1 + 1;
        end
        if(soc.core.cpu.fetch_valid && soc.core.cpu.fetch_ready &&
           soc.core.cpu.fetch_pair && !soc.core.cpu.pair_ok &&
           soc.core.cpu.lane0_mem && soc.core.cpu.lane1_mem) begin
            if(soc.core.cpu.dec_load  && soc.core.cpu.dec_load_h)  w_mm_ll = w_mm_ll + 1;
            else if(soc.core.cpu.dec_load)                         w_mm_ls = w_mm_ls + 1;
            else if(soc.core.cpu.dec_load_h)                       w_mm_sl = w_mm_sl + 1;
            else                                                   w_mm_ss = w_mm_ss + 1;
        end
        if(soc.core.cpu.fetch_valid && soc.core.cpu.fetch_ready &&
           soc.core.cpu.fetch_pair && !soc.core.cpu.pair_ok &&
           !soc.core.cpu.lane1_ok) begin
            if(soc.core.cpu.dec_mul_h)      w_l1_mul  = w_l1_mul  + 1;
            else if(soc.core.cpu.dec_div_h) w_l1_div  = w_l1_div  + 1;
            else if(soc.core.cpu.dec_jalr_h)w_l1_jalr = w_l1_jalr + 1;
            else if(soc.core.cpu.dec_csr_h) w_l1_csr  = w_l1_csr  + 1;
            else if(soc.core.cpu.dec_br_h||soc.core.cpu.dec_jal_h) w_l1_ctl = w_l1_ctl + 1;
            else if(soc.core.cpu.dec_illegal_h) w_l1_ill = w_l1_ill + 1;
            else                            w_l1_misc = w_l1_misc + 1;
        end
        if(!soc.core.cpu.id_valid && soc.core.fetch_valid) begin
            if(soc.core.cpu.mem_wait)        w_no_mem   = w_no_mem   + 1;
            else if(soc.core.cpu.div_wait)   w_no_div   = w_no_div   + 1;
            else if(soc.core.cpu.trap_wait)  w_no_trap  = w_no_trap  + 1;
            else if(soc.core.cpu.redirect_valid) w_no_redir = w_no_redir + 1;
            else if(soc.core.cpu.hold_ex)    w_no_hold  = w_no_hold  + 1;
            else                             w_no_oth   = w_no_oth   + 1;
        end
    end

    // ---- PAIR / FETCH supply decomposition (performance workstream) ------------
    // Dual issue exists (D1/D2/D3) but IPC sits at ~1.0, so either the fetch
    // stream rarely offers an adjacent pair, or the pairing rules refuse it, or
    // the EX slots cannot take it.  Classify every cycle of the score window so
    // the next RTL change is chosen from data, not from reading the rules.
    // All of these are testbench-only hierarchical probes: no RTL change.
    integer pw_pair_take=0, pw_pair_alu=0, pw_pair_mem=0;
    integer pw_ex0_busy=0, pw_ex1_busy=0;
    integer pw_rej=0, pw_r_notadj=0, pw_r_l0=0, pw_r_l1=0, pw_r_csr=0,
            pw_r_fault=0, pw_r_raw=0, pw_r_waw=0;
    integer pw_single=0, pw_none=0, pw_starve=0, pw_backpress=0;
    integer pw_l1_alu=0, pw_l1_br=0, pw_l1_jal=0, pw_l1_other=0;
    integer pw_ret_cyc=0, pw_ret1_cyc=0, pw_no_ret=0;
    // Control transfers that can never be paired today: JALR (returns) and, in
    // lane 0, any branch/JAL (lane 0 must be ALU or memory).
    integer pw_ctrl_solo=0, pw_jalr_solo=0;
    // Fetch queue residency: how full is the IFU queue when the pipeline asks?
    integer pw_occ0=0, pw_occ1=0, pw_occ2p=0;
    always @(posedge clk) if(rst_n && !sw_done) begin
        if(soc.core.cpu.id_valid && soc.core.cpu.id_valid_h) begin
            if(soc.core.cpu.id_ready1) begin
                pw_pair_take=pw_pair_take+1;
                if(soc.core.cpu.is_memory) pw_pair_mem=pw_pair_mem+1;
                else                       pw_pair_alu=pw_pair_alu+1;
            end else if(!soc.core.cpu.ex0_ready) begin
                pw_ex0_busy=pw_ex0_busy+1;
            end else if(!soc.core.cpu.ex1_ready) begin
                pw_ex1_busy=pw_ex1_busy+1;
            end else if(soc.core.cpu.block_entry) begin
                pw_ex0_busy=pw_ex0_busy+1;
            end else begin
                // pair_ok is false: classify the FIRST blocking rule, in the same
                // priority the RTL uses, so the buckets add up.
                pw_rej=pw_rej+1;
                if(soc.core.cpu.dpch!=soc.core.cpu.dpc+32'd4)      pw_r_notadj=pw_r_notadj+1;
                else if(!((soc.core.cpu.alu0||soc.core.cpu.mem0))) pw_r_l0=pw_r_l0+1;
                else if(!((soc.core.cpu.alu1||soc.core.cpu.ctrl1)))pw_r_l1=pw_r_l1+1;
                else if(soc.core.cpu.dcwe||soc.core.cpu.dcweh)     pw_r_csr=pw_r_csr+1;
                else if(soc.core.cpu.ifault||soc.core.cpu.ifaulth||
                        soc.core.cpu.dillegal||soc.core.cpu.dillegalh) pw_r_fault=pw_r_fault+1;
                else if(soc.core.cpu.drd!=5'd0 && soc.core.cpu.drd!=5'd0 &&
                        soc.core.cpu.drd==soc.core.cpu.drdh)       pw_r_waw=pw_r_waw+1;
                else                                                pw_r_raw=pw_r_raw+1;
            end
        end else if(soc.core.cpu.id_valid) begin
            pw_single=pw_single+1;
        end else begin
            pw_none=pw_none+1;
        end
        if(soc.core.fetch_ready && !soc.core.fetch_valid) pw_starve=pw_starve+1;
        if(soc.core.fetch_valid && !soc.core.fetch_ready) pw_backpress=pw_backpress+1;
        if(soc.core.ifu.count_q==0)      pw_occ0=pw_occ0+1;
        else if(soc.core.ifu.count_q==1) pw_occ1=pw_occ1+1;
        else                             pw_occ2p=pw_occ2p+1;
        if(retire_fire) begin
            pw_ret_cyc=pw_ret_cyc+1;
            if(soc.core.cpu.ex_valid_h) begin
                pw_ret1_cyc=pw_ret1_cyc+1;
                case(soc.core.cpu.ei_h[6:0])
                    7'h33,7'h13,7'h37,7'h17: pw_l1_alu=pw_l1_alu+1;
                    7'h63:                   pw_l1_br =pw_l1_br +1;
                    7'h6f:                   pw_l1_jal=pw_l1_jal+1;
                    default:                 pw_l1_other=pw_l1_other+1;
                endcase
            end
            if(soc.core.cpu.pred_train_control) pw_ctrl_solo=pw_ctrl_solo+1;
            if(soc.core.cpu.pred_is_jalr)       pw_jalr_solo=pw_jalr_solo+1;
        end else pw_no_ret=pw_no_ret+1;
    end
    integer mem_ops=0, mem_ld=0, mem_st=0;
    // Queue occupancy / operation counters (P34 sizing evidence).
    integer qocc [0:8];
    integer qpush=0, qpop=0, qk=0;
    initial for(qk=0; qk<9; qk=qk+1) qocc[qk]=0;
`ifdef CACHE_ENABLE
    always @(posedge clk) if(rst_n && !sw_done) begin
        qocc[soc.core.data_cache.q_count_q] = qocc[soc.core.data_cache.q_count_q] + 1;
        if(soc.core.data_cache.q_push) qpush = qpush + 1;
        if(soc.core.data_cache.q_pop)  qpop  = qpop  + 1;
    end
`endif
    // ---- STORE SCOREBOARD (P34 bring-up, temporary) ---------------------------
    // Ground truth for the posted-store queue: every store the CPU hands to the
    // D-Cache must appear on the AXI write channel exactly once, in order, with
    // the same address, strobe and data.  A mismatch names the address instead of
    // leaving "CoreMark diverged" to guesswork.
    reg [31:0] sc_addr [0:1023];
    reg [31:0] sc_data [0:1023];
    reg [3:0]  sc_strb [0:1023];
    integer sc_wr=0, sc_rd=0, sc_err=0;
    reg [31:0] sc_aw_addr=0;
`ifdef CACHE_ENABLE
    function [31:0] sc_mask;
        input [3:0] s;
        begin
            sc_mask = {{8{s[3]}},{8{s[2]}},{8{s[1]}},{8{s[0]}}};
        end
    endfunction
    always @(posedge clk) if(rst_n) begin
        if(soc.core.data_cache.req_valid && soc.core.data_cache.req_ready &&
           soc.core.data_cache.req_write) begin
            sc_addr[sc_wr[9:0]] = soc.core.data_cache.req_addr;
            sc_data[sc_wr[9:0]] = soc.core.data_cache.w_data & sc_mask(soc.core.data_cache.w_strb);
            sc_strb[sc_wr[9:0]] = soc.core.data_cache.w_strb;
            sc_wr = sc_wr + 1;
        end
        if(soc.core.data_cache.m_awvalid && soc.core.data_cache.m_awready)
            sc_aw_addr = soc.core.data_cache.m_awaddr;
        if(soc.core.data_cache.m_wvalid && soc.core.data_cache.m_wready) begin
            if(sc_rd < sc_wr) begin
                if(sc_err < 6) begin
                    if(sc_addr[sc_rd[9:0]] !== sc_aw_addr ||
                       sc_strb[sc_rd[9:0]] !== soc.core.data_cache.m_wstrb ||
                       sc_data[sc_rd[9:0]] !== (soc.core.data_cache.m_wdata &
                                                sc_mask(soc.core.data_cache.m_wstrb))) begin
                        sc_err = sc_err + 1;
                        $display("SC_MISMATCH idx=%0d exp_addr=%08x act_addr=%08x exp_data=%08x act_data=%08x exp_strb=%b act_strb=%b",
                                 sc_rd, sc_addr[sc_rd[9:0]], sc_aw_addr,
                                 sc_data[sc_rd[9:0]], soc.core.data_cache.m_wdata,
                                 sc_strb[sc_rd[9:0]], soc.core.data_cache.m_wstrb);
                    end
                end
                sc_rd = sc_rd + 1;
            end else if(sc_err < 6) begin
                sc_err = sc_err + 1;
                $display("SC_EXTRA_WRITE addr=%08x data=%08x strb=%b (no matching CPU store)",
                         sc_aw_addr, soc.core.data_cache.m_wdata, soc.core.data_cache.m_wstrb);
            end
        end
    end
`endif
    // ---- STORE ACCEPTANCE decomposition (performance workstream) --------------
    // A data-RAM store is answered early (posted) only if the cache can take it.
    // req_ready is gated by the cache state and by the single-entry posted buffer,
    // so a refused store parks the LSU in REQUEST.  Bucket every refused store by
    // the cache state that refused it: "buffer depth" and "state window" need
    // different fixes, and guessing which one costs a P&R run each time.
`ifdef CACHE_ENABLE
    integer st_refuse=0, rq_st_wrreq=0, rq_st_wrresp=0, rq_st_drain_full=0,
            rq_st_drain_free=0, rq_st_post=0, rq_st_rd=0, rq_st_hit=0, rq_st_other=0;
    integer st_refuse_hit=0, st_refuse_miss=0;
    always @(posedge clk) if(rst_n && !sw_done) begin
        // The CPU accepts the store on its own edge (op_valid && op_ready) and
        // *then* parks in REQUEST while the cache refuses eng_req_ready, so the
        // refusal window is "REQUEST state, store, engine not ready" -- op_valid
        // has already dropped (issued=1) and must not be used here.
        if(soc.core.lsu.state==3'd1 && soc.core.lsu.is_store &&
           !soc.core.lsu.eng_req_ready) begin
            st_refuse=st_refuse+1;
            if(soc.core.data_cache.state_q==4'd4)      rq_st_wrreq=rq_st_wrreq+1;
            else if(soc.core.data_cache.state_q==4'd5) rq_st_wrresp=rq_st_wrresp+1;
            else if(soc.core.data_cache.state_q==4'd9)
                if(soc.core.data_cache.q_full)         rq_st_drain_full=rq_st_drain_full+1;
                else                                   rq_st_drain_free=rq_st_drain_free+1;
            else if(soc.core.data_cache.state_q==4'd10) rq_st_post=rq_st_post+1;
            else if(soc.core.data_cache.state_q==4'd2||
                    soc.core.data_cache.state_q==4'd3)  rq_st_rd=rq_st_rd+1;
            else if(soc.core.data_cache.state_q==4'd1||
                    soc.core.data_cache.state_q==4'd6)  rq_st_hit=rq_st_hit+1;
            else                                        rq_st_other=rq_st_other+1;
            if(soc.core.lsu.address>=32'h1000_0000 &&
               soc.core.lsu.address<32'h1000_4000)      st_refuse_hit=st_refuse_hit+1;
            else                                        st_refuse_miss=st_refuse_miss+1;
        end
    end
`endif
    // ---- STORE BURST DEMAND (P34 depth sizing) --------------------------------
    // How deep does the posted-store queue have to be?  Measured on the DEMAND
    // side -- consecutive RETIRED stores with no intervening other instruction --
    // because the supply side is already distorted by today's one-entry buffer
    // (a refused store breaks any "accepted back to back" run).
    integer sb_hist [0:9];      // index 0 unused; 9 = "9 or more"
    integer sb_run=0, sb_max=0, sb_runs=0, sb_stores=0, sb_k=0;
    initial for(sb_k=0; sb_k<10; sb_k=sb_k+1) sb_hist[sb_k]=0;
    task automatic sb_close_run;
        begin
            if(sb_run!=0) begin
                if(sb_run>9) sb_hist[9]=sb_hist[9]+1; else sb_hist[sb_run]=sb_hist[sb_run]+1;
                if(sb_run>sb_max) sb_max=sb_run;
                sb_runs=sb_runs+1;
                sb_run=0;
            end
        end
    endtask
    always @(posedge clk) if(rst_n) begin
        if(retire_fire) begin
            if(soc.core.cpu.ei[6:0]==7'h23) begin
                sb_run=sb_run+1;
                sb_stores=sb_stores+1;
            end else sb_close_run;
        end
    end
    always @(posedge clk) if(rst_n && sw_done && sb_run!=0) sb_close_run;
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
        $display("CORE_SUMMARY cycles=%0d retires=%0d traps=%0d faults=%0d uart_chars=%0d txd_writes=%0d ctrl=%0d mispred=%0d pair=%0d", cycles, retired, traps, faults, chars, txd_writes, ctrl_retired, mispred_retired, pair_retired);
        $display("EX_OCCUPANCY ex_busy=%0d ex_mem_post=%0d ex_div_busy=%0d lsu_nonidle=%0d", ex_busy, ex_mem_post, ex_div_busy, lsu_nonidle);
        $display("EX_SPLIT load=%0d store=%0d other=%0d id_stall=%0d no_retire=%0d retire_cyc=%0d",
                 exb_load, exb_store, exb_other, id_stall, no_retire, retire_cyc);
        $display("PAIR_STATS take=%0d (alu=%0d mem=%0d) ret_cyc=%0d ret1_cyc=%0d no_ret=%0d single=%0d none=%0d",
                 pw_pair_take, pw_pair_alu, pw_pair_mem, pw_ret_cyc, pw_ret1_cyc,
                 pw_no_ret, pw_single, pw_none);
        $display("PAIR_BLOCK ex0_busy=%0d ex1_busy=%0d reject=%0d [notadj=%0d l0=%0d l1=%0d csr=%0d fault=%0d raw=%0d waw=%0d]",
                 pw_ex0_busy, pw_ex1_busy, pw_rej, pw_r_notadj, pw_r_l0, pw_r_l1,
                 pw_r_csr, pw_r_fault, pw_r_raw, pw_r_waw);
        $display("FETCH_SUPPLY starve=%0d backpress=%0d occ0=%0d occ1=%0d occ2p=%0d",
                 pw_starve, pw_backpress, pw_occ0, pw_occ1, pw_occ2p);
        $display("LANE1_MIX alu=%0d br=%0d jal=%0d other=%0d ctrl_solo=%0d jalr_solo=%0d",
                 pw_l1_alu, pw_l1_br, pw_l1_jal, pw_l1_other, pw_ctrl_solo, pw_jalr_solo);
        $display("ST_REFUSE total=%0d (data_ram=%0d other=%0d) wrreq=%0d wrresp=%0d drain_full=%0d drain_free=%0d post=%0d rd=%0d hit=%0d other_state=%0d",
                 st_refuse, st_refuse_hit, st_refuse_miss, rq_st_wrreq, rq_st_wrresp,
                 rq_st_drain_full, rq_st_drain_free, rq_st_post, rq_st_rd,
                 rq_st_hit, rq_st_other);
        sb_close_run;
        $display("STORE_BURST stores=%0d runs=%0d max=%0d hist=%0d/%0d/%0d/%0d/%0d/%0d/%0d/%0d/%0d",
                 sb_stores, sb_runs, sb_max,
                 sb_hist[1],sb_hist[2],sb_hist[3],sb_hist[4],sb_hist[5],
                 sb_hist[6],sb_hist[7],sb_hist[8],sb_hist[9]);
        $display("STORE_SCOREBOARD pushed=%0d popped=%0d mismatches=%0d", sc_wr, sc_rd, sc_err);
        $display("STQ_OCC push=%0d pop=%0d occ=%0d/%0d/%0d/%0d/%0d",
                 qpush, qpop, qocc[0],qocc[1],qocc[2],qocc[3],qocc[4]);
        $display("SCORE_WINDOW cycles=%0d retires=%0d no_retire=%0d load=%0d store=%0d other=%0d id_stall=%0d",
                 sw_cycles, sw_retires, sw_noretire, sw_load, sw_store, sw_other, sw_idstall);
        $display("WIN_ISSUE pair=%0d single=%0d none=%0d (starve=%0d other=%0d) redir=%0d",
                 w_pair, w_single, w_none, w_none_starve, w_none_other, w_redir);
        $display("WIN_SINGLE br=%0d (taken=%0d) jal=%0d jalr=%0d mem=%0d alu=%0d",
                 w_sgl_br, w_sgl_btaken, w_sgl_jal, w_sgl_jalr, w_sgl_mem, w_sgl_alu);
        $display("WIN_SGL_WHY nopair=%0d (br_nopair=%0d) memmem=%0d lduse=%0d mduse=%0d alone=%0d l1bad=%0d ffault=%0d other=%0d",
                 w_sgl_nopair, w_sgl_br_nopair, w_sgl_memmem, w_sgl_lduse, w_sgl_mduse,
                 w_sgl_alone, w_sgl_l1bad, w_sgl_ffault, w_sgl_other);
        $display("WIN_FETCH handshake_pair=%0d handshake_single=%0d", w_fpair, w_fsingle);
        $display("WIN_STARVE stale=%0d inflight=%0d mismatch=%0d empty=%0d",
                 w_starve_stale, w_starve_inflight, w_starve_mismatch, w_starve_empty);
        $display("WIN_ACCEPT pair=%0d single=%0d refused_pair=%0d [lduse=%0d mduse=%0d memmem=%0d alone=%0d (jalr=%0d serial=%0d) l1bad=%0d other=%0d] mispred=%0d",
                 w_a_pair, w_a_single, w_a_ref, w_r_lduse, w_r_mduse, w_r_memmem,
                 w_r_alone, w_r_jalr, w_r_ser, w_r_l1bad, w_r_othr, w_miss);
        $display("WIN_STALL mem=%0d div=%0d trap=%0d stall=%0d hold_ex=%0d", 
                 w_mem, w_div, w_trap, w_stall, w_hold);
        $display("WIN_NOISSUE mem=%0d div=%0d trap=%0d redir=%0d hold=%0d other=%0d",
                 w_no_mem, w_no_div, w_no_trap, w_no_redir, w_no_hold, w_no_oth);
        $display("WIN_NOPAIR off=%0d/%0d/%0d/%0d/%0d/%0d/%0d/%0d byp=%0d queued=%0d cnt<=1=%0d cnt>1=%0d",
                 w_np_off0,w_np_off1,w_np_off2,w_np_off3,w_np_off4,w_np_off5,
                 w_np_off6,w_np_off7, w_np_byp, w_np_queued, w_np_cnt_le1, w_np_cnt_gt1);
        $display("WIN_MEMMEM ll=%0d ls=%0d sl=%0d ss=%0d", w_mm_ll, w_mm_ls, w_mm_sl, w_mm_ss);
        $display("WIN_L1BAD mul=%0d div=%0d jalr=%0d csr=%0d ctl_msa=%0d ill=%0d misc=%0d",
                 w_l1_mul, w_l1_div, w_l1_jalr, w_l1_csr, w_l1_ctl, w_l1_ill, w_l1_misc);
        $display("WIN_LSU request=%0d rdwait=%0d wrwait=%0d", w_lsu_req, w_lsu_rdwait, w_lsu_wrwait);
        $display("WIN_REQREF ld=%0d [idle=%0d rdar=%0d rddata=%0d hold=%0d byp=%0d drain=%0d post=%0d] st=%0d [idle=%0d wrreq=%0d wrresp=%0d hold=%0d drain=%0d post=%0d]",
                 w_reqld, w_ld_idle, w_ld_rdar, w_ld_rddata, w_ld_hold, w_ld_byp,
                 w_ld_drain, w_ld_post, w_reqst, w_st_idle, w_st_wrreq, w_st_wrresp,
                 w_st_hold, w_st_drain, w_st_post);
`ifdef CACHE_ENABLE
        $display("WIN_DC idle=%0d rdar=%0d rddata=%0d drain=%0d", w_dc_idle, w_dc_rdar, w_dc_rddata, w_dc_drain);
`endif
        $display("MEM_OPS ops=%0d ld=%0d st=%0d  axi_d_ar=%0d axi_d_aw=%0d", mem_ops, mem_ld, mem_st, d_ar, d_aw);
        $display("STORE_PATH st_wr_req=%0d st_wr_resp=%0d st_wr_hold=%0d st_total=%0d", st_wr_req, st_wr_resp, st_wr_hold, st_wr_req+st_wr_resp+st_wr_hold);
        $display("LSU_PATH empty=%0d request=%0d wdata=%0d rdwait=%0d wrwait=%0d complete=%0d", l_emp, l_req, l_wdat, l_rdwait, l_wrwait, l_comp);
        $display("LSU_REQ_SPLIT request_store=%0d request_load=%0d wdata_store=%0d", l_req_st, l_req_ld, l_wdat_st);
        $display("ICACHE_PATH idle=%0d ar=%0d fill=%0d missrd=%0d resp=%0d fault=%0d", ic_idle, ic_ar, ic_fill, ic_mrd, ic_resp, ic_fault);
        $display("DCACHE_PATH idle=%0d hit=%0d rdar=%0d rddata=%0d byp=%0d drain=%0d rdwait_entries=%0d refills=%0d",
                 dc_idle, dc_hit, dc_rdar, dc_rddata, dc_byp, dc_drain, rdwait_entries, refills);
        $display("ADDR_REGION ld_lo=%0d ld_data=%0d ld_hi=%0d st_lo=%0d st_data=%0d st_hi=%0d nonhit_lo=%0d nonhit_data=%0d nonhit_hi=%0d",
                 ld_lo, ld_data, ld_hi, sl_lo, sl_data, sl_hi, nh_lo, nh_data, nh_hi);
        $display("HI_SPLIT hi2=%0d hi3=%0d hi4=%0d hi5=%0d hi6=%0d", hi2, hi3, hi4, hi5, hi6);
        $display("MISPRED_MIX ret=%0d jal=%0d br=%0d other=%0d", misp_ret, misp_jal, misp_br, misp_other);
        $display("REDIRECT n=%0d lat_total=%0d lat_avg_x10=%0d", rd_n, rd_lat,
                 rd_n ? (rd_lat*10/rd_n) : 0);
        if(txd_writes!=0 && chars==0) begin
            $display("TEST_FAIL UART_LOOPBACK no decoded byte although %0d TXDATA writes reached the UART",txd_writes);
            $fatal(1,"uat tx broken");
        end
        $display("TEST_PASS T_COREMARK_BOUNDED retires=%0d traps=%0d cycles=%0d txd_writes=%0d",retired,traps,cycles,txd_writes);
        $finish;
    end
`ifdef IVL_PROBE
    integer pr_lo=0, pr_hi=0;
    initial begin
        if(!$value$plusargs("PROBE_LO=%d", pr_lo)) pr_lo=7090;
        if(!$value$plusargs("PROBE_HI=%d", pr_hi)) pr_hi=7200;
    end
    always @(posedge clk) if (rst_n && cycles>=pr_lo && cycles<=pr_hi)
        $display("PROBE c=%0d pc=%08x rr_v=%b hold=%b ser=%b halt=%b div_q=%b memq=%b exmem=%b opv=%b opr=%b fv=%b fr=%b redir=%b wv=%b anext=%08x uctrl=%08x ustat=%08x",
                 cycles, retire_pc, soc.core.cpu.rr_valid, soc.core.cpu.hold_ex,
                 soc.core.cpu.serial_q, soc.core.cpu.halted_q, soc.core.cpu.div_issued_q,
                 soc.core.cpu.mem_issued_q, soc.core.cpu.ex_is_mem, soc.core.cpu.op_valid,
                 soc.core.cpu.op_ready, soc.core.cpu.fetch_valid, soc.core.cpu.fetch_ready, soc.core.cpu.redirect_any,
                 soc.core.cpu.w_valid, arch_next_pc, soc.uart_inst.ctrl_q, soc.uart_inst.stat_q);
    always @(posedge clk) if (rst_n && cycles>=pr_lo && cycles<=pr_hi)
        $display("P2 c=%0d rr_inst=%08x rr_pred=%08x rr_pred_h=%08x id_pred=%08x id_pred_h=%08x pcq=%08x headpc=%08x stale=%b ocnt=%b cnt=%b redirect_valid=%b trap_go=%b brmiss=%b brmiss_h=%b resume=%b",
                 cycles, soc.core.cpu.rr_inst, soc.core.cpu.rr_pred, soc.core.cpu.rr_pred_h,
                 soc.core.cpu.id_pred, soc.core.cpu.id_pred_h, soc.core.cpu.pc_q,
                 soc.core.ifu.head_pc, soc.core.ifu.stale_cnt_q, soc.core.ifu.ocnt_q,
                 soc.core.ifu.count_q, soc.core.ifu.redirect_valid, soc.core.cpu.trap_go,
                 soc.core.cpu.br_miss, soc.core.cpu.br_miss_h, soc.core.cpu.resume);
    always @(posedge clk) if (rst_n && cycles>=pr_lo && cycles<=pr_hi)
        $display("P3 c=%0d inst1=%08x addr=%08x exv=%08x mv=%08x wv=%08x wbv=%08x wrd=%0d wwe=%b rfd0=%08x rfd1=%08x f1=%08x f2=%08x",
                 cycles, soc.core.cpu.rr_inst, soc.core.cpu.mem_addr, soc.core.cpu.ex_value,
                 soc.core.cpu.m_value, soc.core.cpu.w_value, soc.core.cpu.wb_value,
                 soc.core.cpu.w_rd, soc.core.cpu.w_we, soc.core.cpu.rf_d0,
                 soc.core.cpu.rf_d1, soc.core.cpu.fwd1, soc.core.cpu.fwd2);
    always @(posedge clk) if (rst_n && cycles>=pr_lo && cycles<=pr_hi)
        $display("P4 c=%0d lv=%08x dv=%b rsp=%b adr=%08x st=%b f=%b lsrsp=%08x lsu_v=%b lsu_r=%b",
                 cycles, soc.core.load_value, soc.core.done_valid, soc.core.cpu.mem_rsp,
                 soc.core.address, soc.core.is_store, soc.core.fault, soc.core.ls_rsp_data,
                 soc.core.cpu.issue_mem, soc.core.op_ready);
    integer ld_n=0, ld_bad=0, ld_few=0;
    always @(posedge clk) if (rst_n && soc.core.done_valid && !soc.core.is_store) begin
        ld_n = ld_n + 1;
        if ($isunknown(soc.core.load_value)) ld_bad = ld_bad + 1;
        else if (ld_few < 6) begin
            ld_few = ld_few + 1;
            $display("LDOK c=%0d pc=%08x val=%08x", cycles, soc.core.op_pc, soc.core.load_value);
        end
    end
    final $display("LDSTAT loads=%0d x_loads=%0d", ld_n, ld_bad);
`endif
endmodule
