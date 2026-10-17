//=============================================================================
// bottleneck_audit - CoreMark interval instrumentation testbench
// File : tb_coremark_audit.sv
// Brief: runs the native AXI SoC on a CoreMark image and classifies every cycle
//        of the CoreMark timing region into mutually exclusive buckets.
//
// This testbench is READ-ONLY with respect to the RTL: every metric is obtained
// through hierarchical probes of the unmodified design.  The only added logic is
// inside this file, so the measured hardware is bit-identical to the released
// sources (see results/baseline_tree_sha256.tsv).
//
// Region definition
//   The firmware reads the cycle CSR twice (core_portme.c start_time/stop_time).
//   The TB watches the retiring instruction stream for those two CSR reads
//   (opcode 0x73, csrr from 0xC00) and snapshots every counter at the first one
//   (T_START) and at the second one (T_STOP).  Interval counters are the deltas.
//
// Cycle classification (mutually exclusive, priority order, every cycle of the
// interval lands in exactly one bucket):
//   1 RETIRE     : retire_fire in this cycle
//   2 LSU_STALL  : !retire, EX holds an instruction, LSU has a memory op outstanding
//   3 DIV_STALL  : !retire, EX holds an instruction, divider running
//   4 EX_STALL   : !retire, EX holds an instruction, neither of the above (hazard)
//   5 STARVE     : !retire, EX empty (front-end cannot supply / flush / redirect)
//=============================================================================
`timescale 1ns/1ps

module tb_coremark_audit;

parameter integer BAUD_DIV      = 234;     // 27 MHz / 115384 baud
parameter integer MAX_CYCLES    = 4000000;
parameter integer CLK_PERIOD_NS = 1;

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
wire [31:0] fetch_pc, request_pc, predict_next_pc;
wire        fetch_valid, fetch_ready, redirect_valid;

string prog_file, data_file;
integer max_cycles = MAX_CYCLES;

pangoriscv_axi_soc #(.PROGRAM_INIT_FILE(""),.DATA_INIT_FILE(""),.READ_DELAY(0),.WRITE_DELAY(0)) soc(
    .clk(clk),.rst_n(rst_n),.uart_rx(uart_rx),.uart_tx(uart_tx),
    .gpio_input(gpio_input),.gpio_ctrl(gpio_ctrl),.gpio_data(gpio_data),
    .spi_miso(spi_miso),.spi_mosi(spi_mosi),.spi_ss(spi_ss),.spi_clk(spi_clk),
    .ext_event(ext_event),.halt_req(halt_req),.trap_ready(trap_ready),
    .irq_software(irq_software),.irq_timer(irq_timer),.irq_external(irq_external),
    .halted(halted),.arch_next_pc(arch_next_pc),.trap_cause(trap_cause),
    .trap_pc(trap_pc),.trap_tval(trap_tval),.csr_mtvec(csr_mtvec),
    .trap_fire(trap_fire),.retire_fire(retire_fire),.retire_order(retire_order),
    .retire_pc(retire_pc),.retire_inst(retire_inst),.rd_valid(rd_valid),.rd(rd),
    .wdata(wdata),.debug_addr(debug_addr),.debug_data(debug_data),
    .protocol_fault(protocol_fault)
);

// ---- image load -------------------------------------------------------------
initial begin
    if (!$value$plusargs("PROG=%s", prog_file)) prog_file="program.hex";
    if (!$value$plusargs("DATA=%s", data_file)) data_file="data.hex";
    if (!$value$plusargs("MAX_CYCLES=%d", max_cycles)) max_cycles=MAX_CYCLES;
    $readmemh(prog_file, soc.program_ram.mem);
    $readmemh(data_file, soc.data_ram.mem);
    $display("AUDIT_IMAGE prog=%s data=%s max_cycles=%0d", prog_file, data_file, max_cycles);
end

// ---- run-wide counters ------------------------------------------------------
integer cycles=0, retired=0, traps=0, faults=0, chars=0;
integer ctrl_retired=0, mispred_retired=0;

// raw (possibly overlapping) event counters
integer ev_ifwait=0, ev_lsuwait=0, ev_imiss=0, ev_dmiss=0, ev_predmiss=0;
integer ev_i_ar=0, ev_i_r=0, ev_d_ar=0, ev_d_r=0, ev_d_aw=0, ev_d_w=0, ev_d_b=0;
integer ev_redirect=0, ev_fetch=0, ev_issue=0, ev_rsp=0;

// mutually exclusive classification (priority order)
integer cls_retire=0, cls_lsu=0, cls_div=0, cls_ex=0, cls_starve=0;

// secondary event counters used by the report
integer ev_load=0, ev_store=0, ev_muldiv=0, ev_mult=0;
integer ev_iqueue_full=0, ev_iqueue_empty=0;
// interval-only probes added for the bottleneck audit (module level, read only)
integer iv_load=0, iv_store=0;
integer iv_cd_req=0, iv_cd_miss=0, iv_cd_ar=0, iv_cd_r=0, iv_cd_byp=0;
integer iv_ci_req=0, iv_ci_miss=0, iv_ci_ar=0, iv_ci_r=0;
integer iv_redir=0, iv_ls_req=0, iv_flush_lost=0;

// histograms
integer h_occ[0:9];        // fetch queue occupancy 0..8,9=full-and-more
integer h_igap[0:31];      // gap between consecutive I-cache request accepts
integer h_ilat[0:31];      // I-cache request accept -> response cycles
integer h_llat[0:63];      // LSU op accept -> done_valid cycles
integer h_rec[0:127];      // redirect -> next retire latency
integer i;
initial for(i=0;i<10;i=i+1) h_occ[i]=0;
initial for(i=0;i<32;i=i+1) begin h_igap[i]=0; h_ilat[i]=0; end
initial for(i=0;i<64;i=i+1) h_llat[i]=0;
initial for(i=0;i<128;i=i+1) h_rec[i]=0;

// ---- snapshot machinery -----------------------------------------------------
// 24 counters are snapshotted at T_START / T_STOP.
integer s_start[0:23], s_stop[0:23];
reg     have_start=0, have_stop=0;
integer t_start=0, t_stop=0;
integer snap_now=0;

task automatic take_snapshot(output integer dst[0:23]);
    begin
        dst[0]=cycles;       dst[1]=retired;
        dst[2]=ev_ifwait;    dst[3]=ev_lsuwait;
        dst[4]=ev_imiss;     dst[5]=ev_dmiss;
        dst[6]=ctrl_retired; dst[7]=mispred_retired;
        dst[8]=ev_i_ar;      dst[9]=ev_i_r;
        dst[10]=ev_d_ar;     dst[11]=ev_d_r;
        dst[12]=ev_d_aw;     dst[13]=ev_d_w;
        dst[14]=ev_d_b;      dst[15]=ev_redirect;
        dst[16]=cls_retire;  dst[17]=cls_lsu;
        dst[18]=cls_div;     dst[19]=cls_ex;
        dst[20]=cls_starve;  dst[21]=ev_fetch;
        dst[22]=ev_issue;    dst[23]=ev_rsp;
    end
endtask

// CSR cycle read: opcode 0x73, funct3!=0,!=4, imm12 == 0xC00
wire is_rdcycle = retire_fire && (retire_inst[6:0]==7'h73) &&
                  (retire_inst[14:12]!=3'b000) && (retire_inst[14:12]!=3'b100) &&
                  (retire_inst[31:20]==12'hC00);

// ---- I-cache request/response tracking -------------------------------------
reg        pending_ireq=0;
integer    last_issue_cycle=-1;
integer    ireq_cycle=0;
integer    lsu_start_cycle=0, lsu_tracking=0;
integer    last_retire_cycle=0, redirect_cycle=0, redirect_pending=0;

always @(posedge clk) if(rst_n) begin
    cycles = cycles + 1;

    // ---- raw events ---------------------------------------------------------
    if(retire_fire) begin
        retired = retired + 1;
        last_retire_cycle = cycles;
        if((retire_inst[6:0]==7'h63 && retire_inst[14:12]!=3'b010
                                    && retire_inst[14:12]!=3'b011)
           || retire_inst[6:0]==7'h6f
           || (retire_inst[6:0]==7'h67 && retire_inst[14:12]==3'b000))
            ctrl_retired = ctrl_retired + 1;
        if(soc.core.cpu.pred_miss) mispred_retired = mispred_retired + 1;
        if(redirect_pending) begin
            if(cycles-redirect_cycle < 127) h_rec[cycles-redirect_cycle] = h_rec[cycles-redirect_cycle] + 1;
            else h_rec[127] = h_rec[127] + 1;
            redirect_pending = 0;
        end
    end
    if(soc.core.cpu.ex_valid && soc.core.cpu.ex_done && !soc.core.cpu.ex_fault) ; // retire is identical
    if(soc.core.cpu.pred_miss) ev_predmiss = ev_predmiss + 1;
    if(soc.core.fetch_enable && soc.core.fetch_ready && !soc.core.fetch_valid) ev_ifwait = ev_ifwait + 1;
    if(soc.core.cpu.op_valid && !soc.core.cpu.done_valid) ev_lsuwait = ev_lsuwait + 1;
    `ifdef CACHE_ENABLE
    if(soc.core.instruction_cache.miss_pulse) ev_imiss = ev_imiss + 1;
    `endif
    `ifdef CACHE_ENABLE
    if(soc.core.data_cache.miss_event) ev_dmiss = ev_dmiss + 1;
    `endif

    if(soc.core.m_arvalid[0] && soc.core.m_arready[0]) ev_i_ar = ev_i_ar + 1;
    if(soc.core.m_rvalid[0]  && soc.core.m_rready[0])  ev_i_r  = ev_i_r  + 1;
    if(soc.core.m_arvalid[1] && soc.core.m_arready[1]) ev_d_ar = ev_d_ar + 1;
    if(soc.core.m_rvalid[1]  && soc.core.m_rready[1])  ev_d_r  = ev_d_r  + 1;
    if(soc.core.m_awvalid[1] && soc.core.m_awready[1]) ev_d_aw = ev_d_aw + 1;
    if(soc.core.m_wvalid[1]  && soc.core.m_wready[1])  ev_d_w  = ev_d_w  + 1;
    if(soc.core.m_bvalid[1]  && soc.core.m_bready[1])  ev_d_b  = ev_d_b  + 1;

    if(soc.core.redirect_valid) begin
        ev_redirect = ev_redirect + 1;
        redirect_pending = 1;
        redirect_cycle = cycles;
    end
    if(fetch_valid && fetch_ready) ev_fetch = ev_fetch + 1;
    if(soc.core.ifu.eng_req_valid && soc.core.ifu.eng_req_ready) ev_issue = ev_issue + 1;
    if(soc.core.ifu.eng_rsp_valid && soc.core.ifu.eng_rsp_ready) begin
        ev_rsp = ev_rsp + 1;
        if(pending_ireq) begin
            if(cycles-ireq_cycle < 31) h_ilat[cycles-ireq_cycle] = h_ilat[cycles-ireq_cycle] + 1;
            else h_ilat[31] = h_ilat[31] + 1;
            pending_ireq = 0;
        end
    end
    if(soc.core.ifu.eng_req_valid && soc.core.ifu.eng_req_ready) begin
        if(last_issue_cycle >= 0) begin
            if(cycles-last_issue_cycle < 31) h_igap[cycles-last_issue_cycle] = h_igap[cycles-last_issue_cycle] + 1;
            else h_igap[31] = h_igap[31] + 1;
        end
        last_issue_cycle = cycles;
        pending_ireq = 1;
        ireq_cycle = cycles;
    end

    // fetch queue occupancy
    if(soc.core.ifu.count_q >= 9) h_occ[9] = h_occ[9] + 1;
    else h_occ[soc.core.ifu.count_q] = h_occ[soc.core.ifu.count_q] + 1;
    if(soc.core.ifu.full)  ev_iqueue_full  = ev_iqueue_full + 1;
    if(soc.core.ifu.empty) ev_iqueue_empty = ev_iqueue_empty + 1;

    // LSU op tracking
    if(soc.core.cpu.op_valid && soc.core.cpu.op_ready) begin
        lsu_tracking = 1;
        lsu_start_cycle = cycles;
        if(soc.core.cpu.is_store) ev_store = ev_store + 1;
        else ev_load = ev_load + 1;
    end
    if(lsu_tracking && soc.core.cpu.issued && soc.core.cpu.done_valid) begin
        if(cycles-lsu_start_cycle < 63) h_llat[cycles-lsu_start_cycle] = h_llat[cycles-lsu_start_cycle] + 1;
        else h_llat[63] = h_llat[63] + 1;
        lsu_tracking = 0;
    end

    // M-extension issue count
    if(soc.core.cpu.ex_valid && soc.core.cpu.is_div) ev_muldiv = ev_muldiv + 1;

    // ---- interval-only module level probes ---------------------------------
    if(have_start && !have_stop) begin
        if(soc.core.cpu.op_valid && soc.core.cpu.op_ready) begin
            if(soc.core.cpu.is_store) iv_store = iv_store + 1;
            else                      iv_load  = iv_load  + 1;
        end
        if(soc.core.redirect_valid) iv_redir = iv_redir + 1;
`ifdef CACHE_ENABLE
        if(soc.core.instruction_cache.req_valid && soc.core.instruction_cache.req_ready)
            iv_ci_req = iv_ci_req + 1;
        if(soc.core.instruction_cache.miss_pulse) iv_ci_miss = iv_ci_miss + 1;
        if(soc.core.instruction_cache.m_arvalid && soc.core.instruction_cache.m_arready)
            iv_ci_ar = iv_ci_ar + 1;
        if(soc.core.instruction_cache.m_rvalid && soc.core.instruction_cache.m_rready)
            iv_ci_r = iv_ci_r + 1;
        if(soc.core.data_cache.req_valid && soc.core.data_cache.req_ready)
            iv_cd_req = iv_cd_req + 1;
        if(soc.core.data_cache.miss_event) iv_cd_miss = iv_cd_miss + 1;
        if(soc.core.data_cache.m_arvalid && soc.core.data_cache.m_arready) begin
            iv_cd_ar = iv_cd_ar + 1;
            if(soc.core.data_cache.m_arlen == 8'd0) iv_cd_byp = iv_cd_byp + 1;
        end
        if(soc.core.data_cache.m_rvalid && soc.core.data_cache.m_rready)
            iv_cd_r = iv_cd_r + 1;
`endif
        if(soc.core.lsu.eng_req_valid && soc.core.lsu.eng_req_ready)
            iv_ls_req = iv_ls_req + 1;
        if(soc.core.ifu.flush_lost) iv_flush_lost = iv_flush_lost + 1;
    end

    // ---- mutually exclusive classification ---------------------------------
    if(retire_fire)                                   cls_retire = cls_retire + 1;
    else if(soc.core.cpu.ex_valid && !soc.core.cpu.ex_done) begin
        if(soc.core.cpu.is_memory)                cls_lsu    = cls_lsu + 1;
        else if(soc.core.cpu.u_div_adapter.raw_busy)    cls_div    = cls_div + 1;
        else                                          cls_ex     = cls_ex + 1;
    end else                                          cls_starve = cls_starve + 1;

    // ---- interval snapshots ------------------------------------------------
    if(is_rdcycle && !have_start) begin
        take_snapshot(s_start);
        have_start = 1; t_start = cycles;
        $display("AUDIT_START cycle=%0d retire_pc=%08x retire_inst=%08x", cycles, retire_pc, retire_inst);
    end else if(is_rdcycle && have_start && !have_stop) begin
        take_snapshot(s_stop);
        have_stop = 1; t_stop = cycles;
        $display("AUDIT_STOP  cycle=%0d retire_pc=%08x retire_inst=%08x delta=%0d",
                 cycles, retire_pc, retire_inst, cycles-t_start);
    end

    if(trap_fire) begin
        traps = traps + 1;
        if(traps<8) $display("TRAP cycle=%0d cause=%0d pc=%08x tval=%08x", cycles, trap_cause, trap_pc, trap_tval);
    end
    if(protocol_fault) begin
        faults = faults + 1;
        if(faults<8) $display("BUS_FAULT cycle=%0d", cycles);
    end
    if(cycles-last_retire_cycle > 300000 && cycles > 300000) begin
        $display("AUDIT_FAIL stalled: no retirement for 300000 cycles (retires=%0d pc=%08x)", retired, retire_pc);
        $fatal(1,"retirement stalled");
    end
    if(cycles%500000==0)
        $display("PROGRESS cycles=%0d retires=%0d ipc=%f chars=%0d pc=%08x",
                 cycles, retired, retired*1.0/cycles, chars, retire_pc);
end

// ---- UART TX decoder --------------------------------------------------------
reg [15:0] div_cnt=0;
reg [3:0]  bit_idx=0;
reg [7:0]  sh=0;
reg        busy=0;
reg        tx_q=1;
reg [8*20-1:0] match_reg = 0;
reg        report_seen = 0;
integer    report_cycle = 0;

always @(posedge clk) begin
    tx_q <= uart_tx;
    if(!busy) begin
        if(tx_q && !uart_tx) begin
            busy<=1; div_cnt<=(BAUD_DIV/2); bit_idx<=0; sh<=0;
        end
    end else begin
        if(div_cnt==0) begin
            if(bit_idx==0) begin
                bit_idx<=1; div_cnt<=BAUD_DIV-1;
            end else if(bit_idx<=8) begin
                sh[bit_idx-1] = uart_tx;
                if(bit_idx==8) begin
                    chars=chars+1;
                    $write("%c", sh[7:0]);
                    match_reg = {match_reg[8*19-1:0], sh[7:0]};
                    if(!report_seen &&
                       (match_reg[8*17-1:0] === "Correct operation" ||
                        match_reg[8*15-1:0] === "Errors detected")) begin
                        report_seen = 1;
                        report_cycle = cycles;
                    end
                    bit_idx<=9; div_cnt<=BAUD_DIV-1;
                end else begin
                    bit_idx<=bit_idx+1; div_cnt<=BAUD_DIV-1;
                end
            end else begin
                busy<=0; bit_idx<=0;
            end
        end else div_cnt<=div_cnt-1;
    end
end

// ---- termination and report -------------------------------------------------
integer k, tot;
initial begin
    repeat(20) @(negedge clk);
    rst_n=1;
    fork
        begin wait(cycles>=max_cycles); end
        begin
            wait(report_seen);
            repeat(4000) @(posedge clk);
        end
        begin
            wait(have_stop);
            repeat(30000) @(posedge clk);
        end
    join_any
    if(!have_stop) $display("AUDIT_WARN coremark stop point never seen (cycle cap reached)");
    repeat(1000) @(posedge clk);

    $display("");
    $display("AUDIT_SUMMARY cycles=%0d retires=%0d ipc=%f traps=%0d faults=%0d chars=%0d report_seen=%0d",
             cycles, retired, retired*1.0/(cycles==0?1:cycles), traps, faults, chars, report_seen);
    $display("AUDIT_RAW ifwait=%0d lsuwait=%0d imiss=%0d dmiss=%0d predmiss=%0d ctrl=%0d redirect=%0d fetch=%0d issue=%0d rsp=%0d",
             ev_ifwait, ev_lsuwait, ev_imiss, ev_dmiss, ev_predmiss, ctrl_retired,
             ev_redirect, ev_fetch, ev_issue, ev_rsp);
    $display("AUDIT_AXI i_ar=%0d i_r=%0d d_ar=%0d d_r=%0d d_aw=%0d d_w=%0d d_b=%0d",
             ev_i_ar, ev_i_r, ev_d_ar, ev_d_r, ev_d_aw, ev_d_w, ev_d_b);
    $display("AUDIT_CLASS retires=%0d lsu=%0d div=%0d ex=%0d starve=%0d (sum=%0d vs cycles=%0d)",
             cls_retire, cls_lsu, cls_div, cls_ex, cls_starve,
             cls_retire+cls_lsu+cls_div+cls_ex+cls_starve, cycles);
    $display("AUDIT_MEM load=%0d store=%0d mdiv_issue=%0d", ev_load, ev_store, ev_muldiv);

    if(have_start && have_stop) begin
        $display("");
        $display("AUDIT_INTERVAL t_start=%0d t_stop=%0d span=%0d", t_start, t_stop, t_stop-t_start);
        $display("AUDIT_INT cycles=%0d retires=%0d ipc=%f",
                 s_stop[0]-s_start[0], s_stop[1]-s_start[1],
                 (s_stop[1]-s_start[1])*1.0/((s_stop[0]-s_start[0])==0?1:(s_stop[0]-s_start[0])));
        $display("AUDIT_INT_RAW ifwait=%0d lsuwait=%0d imiss=%0d dmiss=%0d predmiss=%0d ctrl=%0d redirect=%0d fetch=%0d issue=%0d rsp=%0d",
                 s_stop[2]-s_start[2], s_stop[3]-s_start[3], s_stop[4]-s_start[4],
                 s_stop[5]-s_start[5], s_stop[7]-s_start[7], s_stop[6]-s_start[6],
                 s_stop[15]-s_start[15], s_stop[21]-s_start[21],
                 s_stop[22]-s_start[22], s_stop[23]-s_start[23]);
        $display("AUDIT_INT_AXI i_ar=%0d i_r=%0d d_ar=%0d d_r=%0d d_aw=%0d d_w=%0d d_b=%0d",
                 s_stop[8]-s_start[8], s_stop[9]-s_start[9], s_stop[10]-s_start[10],
                 s_stop[11]-s_start[11], s_stop[12]-s_start[12],
                 s_stop[13]-s_start[13], s_stop[14]-s_start[14]);
        $display("AUDIT_INT_CLASS retires=%0d lsu=%0d div=%0d ex=%0d starve=%0d (sum=%0d)",
                 s_stop[16]-s_start[16], s_stop[17]-s_start[17], s_stop[18]-s_start[18],
                 s_stop[19]-s_start[19], s_stop[20]-s_start[20],
                 (s_stop[16]-s_start[16])+(s_stop[17]-s_start[17])+(s_stop[18]-s_start[18])
                +(s_stop[19]-s_start[19])+(s_stop[20]-s_start[20]));
        $display("AUDIT_INT_MEM load=%0d store=%0d redirect=%0d flush_lost=%0d",
                 iv_load, iv_store, iv_redir, iv_flush_lost);
        $display("AUDIT_INT_CACHE icache req=%0d miss=%0d ar=%0d r=%0d | dcache req=%0d miss=%0d ar=%0d single=%0d r=%0d | lsu_req=%0d",
                 iv_ci_req, iv_ci_miss, iv_ci_ar, iv_ci_r,
                 iv_cd_req, iv_cd_miss, iv_cd_ar, iv_cd_byp, iv_cd_r, iv_ls_req);
    end else begin
        $display("AUDIT_ERROR cycle CSR reads not both observed (start=%0d stop=%0d)", have_start, have_stop);
    end

    $display("");
    $display("AUDIT_HIST_IQUEUE " );
    for(k=0;k<10;k=k+1) $display("AUDIT_OCC occ=%0d cycles=%0d", k, h_occ[k]);
    $display("AUDIT_HIST_IGAP");
    tot=0; for(k=0;k<32;k=k+1) tot=tot+h_igap[k];
    for(k=0;k<32;k=k+1) if(h_igap[k]!=0) $display("AUDIT_IGAP gap=%0d n=%0d", k, h_igap[k]);
    $display("AUDIT_IGAP_TOTAL n=%0d", tot);
    $display("AUDIT_HIST_ILAT");
    for(k=0;k<32;k=k+1) if(h_ilat[k]!=0) $display("AUDIT_ILAT lat=%0d n=%0d", k, h_ilat[k]);
    $display("AUDIT_HIST_LLAT");
    for(k=0;k<64;k=k+1) if(h_llat[k]!=0) $display("AUDIT_LLAT lat=%0d n=%0d", k, h_llat[k]);
    $display("AUDIT_HIST_REC");
    for(k=0;k<128;k=k+1) if(h_rec[k]!=0) $display("AUDIT_REC lat=%0d n=%0d", k, h_rec[k]);

    $display("");
    if(report_seen) $display("TEST_PASS T_COREMARK_AUDIT retires=%0d cycles=%0d", retired, cycles);
    else            $display("TEST_FAIL T_COREMARK_AUDIT retires=%0d cycles=%0d", retired, cycles);
    $finish;
end

endmodule
