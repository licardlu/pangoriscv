//=============================================================================
// bottleneck_audit Phase 2 - LSU control-overhead trace testbench
// File : tb/phase2/tb_lsu_trace.sv
//
// READ-ONLY instrumentation of the unmodified candidate RTL.  Every number is
// obtained from hierarchical probes (+acc) of the design; no RTL file is edited
// and no existing testbench is modified.
//
// Outputs (paths from plusargs):
//   +TXN_CSV=<file>    one row per LSU memory transaction, with the cycle stamp
//                      of every handshake and the per-transaction state
//                      decomposition (LSU / D-cache / inner write engine).
//   +CYCLE_CSV=<file>  one row per cycle (gated by +CYCLE_GATE):
//                      iv   = inside the CoreMark rdcycle..rdcycle interval
//                      meas = inside a measured microbench phase
//                      all  = every cycle after reset release
//   +CYCLE_GATE=iv|meas|all
//   +MODE=coremark|micro   (termination policy)
//   +PROG= +DATA= +MAX_CYCLES= +DRAIN_AFTER_STOP=
//
// The +acc elaboration flag is required (see phase2_diag_trace.md appendix).
//=============================================================================
`timescale 1ns/1ps

module tb_lsu_trace;

parameter integer BAUD_DIV       = 234;
parameter integer MAX_CYCLES     = 4000000;
parameter integer CLK_PERIOD_NS  = 1;
parameter integer DRAIN_CYCLES   = 2000;

reg clk=0;
always #(CLK_PERIOD_NS/2.0) clk=~clk;

reg rst_n=0;
reg uart_rx=1, spi_miso=1;
reg [1:0] gpio_input=0, ext_event=0;
wire uart_tx, spi_mosi, spi_ss, spi_clk;
wire [31:0] gpio_ctrl, gpio_data;
wire halt_req=0, trap_ready=1, irq_software=0, irq_timer=0, irq_external=0;
reg [4:0] debug_addr=0;
wire halted;
wire [31:0] arch_next_pc, trap_cause, trap_pc, trap_tval, csr_mtvec;
wire trap_fire, retire_fire, rd_valid, protocol_fault;
wire [63:0] retire_order;
wire [31:0] retire_pc, retire_inst, wdata, debug_data;
wire [4:0] rd;

pangoriscv_axi_soc #(
    .PROGRAM_INIT_FILE(""), .DATA_INIT_FILE(""),
    .READ_DELAY(0), .WRITE_DELAY(0)
) soc (
    .clk(clk), .rst_n(rst_n), .uart_rx(uart_rx), .uart_tx(uart_tx),
    .gpio_input(gpio_input), .gpio_ctrl(gpio_ctrl), .gpio_data(gpio_data),
    .spi_miso(spi_miso), .spi_mosi(spi_mosi), .spi_ss(spi_ss), .spi_clk(spi_clk),
    .ext_event(ext_event), .halt_req(halt_req), .trap_ready(trap_ready),
    .irq_software(irq_software), .irq_timer(irq_timer), .irq_external(irq_external),
    .halted(halted), .arch_next_pc(arch_next_pc), .trap_cause(trap_cause),
    .trap_pc(trap_pc), .trap_tval(trap_tval), .csr_mtvec(csr_mtvec),
    .trap_fire(trap_fire), .retire_fire(retire_fire), .retire_order(retire_order),
    .retire_pc(retire_pc), .retire_inst(retire_inst), .rd_valid(rd_valid), .rd(rd),
    .wdata(wdata), .debug_addr(debug_addr), .debug_data(debug_data),
    .protocol_fault(protocol_fault)
);

// ---- encodings (lsu_axi.v:31-32, dcache_axi.v:112-120, axi_data_engine.v:75-76)
localparam L_EMPTY=0, L_REQUEST=1, L_WRITE_DATA=2, L_READ_WAIT=3,
           L_WRITE_WAIT=4, L_COMPLETE=5;
localparam ST_IDLE=0, ST_HIT=1, ST_RD_AR=2, ST_RD_DATA=3, ST_WR_REQ=4,
           ST_WR_RESP=5, ST_WR_HOLD=6, ST_BYP_RESP=7, ST_FAULT=8;
localparam W_IDLE=0, W_PREP=1, W_SEND=2, W_RESP=3, W_HOLD=4, W_FAULT=5;

// ---- probes (read-only hierarchical references) ----------------------------
wire [2:0] lsu_state   = soc.core.lsu.state;
wire [3:0] dc_state    = soc.core.data_cache.state_q;
wire [2:0] inner_state = soc.core.data_cache.inner.state_q;

wire lsu_op_valid  = soc.core.lsu.op_valid;
wire lsu_op_ready  = soc.core.lsu.op_ready;
wire lsu_is_store  = soc.core.lsu.is_store;
wire lsu_done_v    = soc.core.lsu.done_valid;
wire lsu_done_r    = soc.core.lsu.done_ready;
wire eng_req_v     = soc.core.lsu.eng_req_valid;
wire eng_req_r     = soc.core.lsu.eng_req_ready;
wire eng_w_v       = soc.core.lsu.eng_w_valid;
wire eng_w_r       = soc.core.lsu.eng_w_ready;
wire eng_rsp_v     = soc.core.lsu.eng_rsp_valid;
wire eng_rsp_r     = soc.core.lsu.eng_rsp_ready;
wire eng_b_v       = soc.core.lsu.eng_b_valid;
wire eng_b_r       = soc.core.lsu.eng_b_ready;

wire d_ar_v = soc.core.m_arvalid[1];
wire d_ar_r = soc.core.m_arready[1];
wire d_r_v  = soc.core.m_rvalid[1];
wire d_r_r  = soc.core.m_rready[1];
wire d_r_last = soc.core.m_rlast[1];
wire d_aw_v = soc.core.m_awvalid[1];
wire d_aw_r = soc.core.m_awready[1];
wire d_w_v  = soc.core.m_wvalid[1];
wire d_w_r  = soc.core.m_wready[1];
wire d_b_v  = soc.core.m_bvalid[1];
wire d_b_r  = soc.core.m_bready[1];

wire ev_accept = lsu_op_valid && lsu_op_ready;
wire ev_done   = lsu_done_v && lsu_done_r;
wire ev_req    = eng_req_v && eng_req_r;
wire ev_weng   = eng_w_v && eng_w_r;
wire ev_rsp    = eng_rsp_v && eng_rsp_r;
wire ev_beng   = eng_b_v && eng_b_r;
wire ev_dar    = d_ar_v && d_ar_r;
wire ev_dr     = d_r_v && d_r_r;
wire ev_drl    = ev_dr && d_r_last;
wire ev_daw    = d_aw_v && d_aw_r;
wire ev_dw     = d_w_v && d_w_r;
wire ev_db     = d_b_v && d_b_r;

wire cpu_ex_valid = soc.core.cpu.ex_valid;
wire cpu_ex_done  = soc.core.cpu.ex_done;
wire cpu_is_mem   = soc.core.cpu.is_memory;
wire cpu_is_st    = soc.core.cpu.is_store;
wire cpu_is_div   = soc.core.cpu.is_div;
wire cpu_issued   = soc.core.cpu.issued;
wire cpu_div_busy = soc.core.cpu.u_div_adapter.raw_busy;

// ---- run state --------------------------------------------------------------
integer cycles=0, retired=0, traps=0, faults=0, chars=0;
integer nrdc=0;                       // number of retired rdcycle (0xc00) ops
reg have_start=0, have_stop=0;
integer t_start=0, t_stop=0;
wire in_iv = have_start && !have_stop;

integer cyc_fd=0, txn_fd=0, csv_gate=0, mode_micro=0, verbose=0;
integer max_cycles=MAX_CYCLES, drain=DRAIN_CYCLES;
reg micro_done=0, report_seen=0;
string prog_file, data_file, cycle_csv, txn_csv, mode_s, gate_s;

// ---- transaction under trace ------------------------------------------------
integer txn_open=0, txn_idx=0;
integer t_is_store, t_kind, t_cached, t_addr, t_size, t_pc;
integer t_iv, t_phase, t_meas, t_nrdc_acc;
integer t_accept, t_req, t_ar, t_rfirst, t_rlast, t_weng, t_aw, t_waxi, t_baxi;
integer t_rsp, t_beng, t_done;
integer t_dcfirst, t_dcmiss, t_hit;
integer t_req_seen, t_cap_pending;
integer n_rbeats;
integer lc[0:5], dcc[0:8], inc[0:5];
integer b_reqwait, b_wdatawait, b_rwait, b_wwait;
integer d_wrreq, d_wrreq_dead, d_wrresp, d_wrhold, d_rdar, d_rddata, d_rddata_nor;
integer d_hitcyc, d_idlecyc;

// ---- CoreMark-interval counters --------------------------------------------
integer iv_cycles=0, iv_retire=0;
integer iv_ld=0, iv_st=0, iv_div=0, iv_ex=0, iv_fe=0;
integer iv_ph_ld[0:5], iv_ph_st[0:5];
integer iv_dc_ld[0:8], iv_dc_st[0:8];
integer iv_in_ld[0:5], iv_in_st[0:5];
integer iv_lsu_idle=0, iv_lsu_busy=0;
integer iv_reqwait=0, iv_wdatawait=0, iv_rwait=0, iv_wwait=0;
integer iv_dwrreq=0, iv_dwrreq_dead=0, iv_dwrresp=0, iv_dwrhold=0;
integer iv_drdar=0, iv_drddata=0, iv_drddata_nor=0, iv_dchit=0, iv_dcidle=0;
integer iv_d_ar=0, iv_d_r=0, iv_d_aw=0, iv_d_w=0, iv_d_b=0;
integer iv_i_ar=0, iv_i_r=0;
integer iv_acc_ld=0, iv_acc_st=0, iv_dc_req=0, iv_dc_miss=0, iv_dc_byp=0;
integer iv_done_stall=0;
integer tot_accept_ld=0, tot_accept_st=0, tot_txn=0, tot_txn_iv=0;
integer dwrreq_dead_tot=0;

integer i, sum, k;

initial begin
    if (!$value$plusargs("PROG=%s", prog_file))  prog_file="program.hex";
    if (!$value$plusargs("DATA=%s", data_file))  data_file="data.hex";
    if (!$value$plusargs("MAX_CYCLES=%d", max_cycles)) max_cycles=MAX_CYCLES;
    if (!$value$plusargs("DRAIN_AFTER_STOP=%d", drain)) drain=DRAIN_CYCLES;
    if ($value$plusargs("MODE=%s", mode_s)) mode_micro = (mode_s=="micro");
    mode_s = mode_micro ? "micro" : "coremark";
    if ($value$plusargs("VERBOSE=%d", verbose)) ;
    if ($value$plusargs("CYCLE_GATE=%s", gate_s)) begin
        if (gate_s=="meas") csv_gate=1;
        else if (gate_s=="all") csv_gate=2;
        else csv_gate=0;
    end
    $readmemh(prog_file, soc.program_ram.mem);
    $readmemh(data_file, soc.data_ram.mem);
    $display("AUDIT2_IMAGE prog=%s data=%s max_cycles=%0d mode=%s csv_gate=%0d",
             prog_file, data_file, max_cycles, mode_s, csv_gate);

    if ($value$plusargs("CYCLE_CSV=%s", cycle_csv)) begin
        cyc_fd = $fopen(cycle_csv, "w");
        if (cyc_fd==0) $display("AUDIT2_WARN cannot open cycle csv %s", cycle_csv);
        else $fwrite(cyc_fd, "cyc,nrdc,iv,lsu,dc,inner,exv,exd,ismem,isst,opv,opr,issued,donv,donr,ereqv,ereqr,ewv,ewr,erspv,erspr,ebv,ebr,darv,darr,drv,drr,drl,dawv,dawr,dwv,dwr,dbv,dbr,dcmiss,dcreqv,dcreqr\n");
    end
    if (!$value$plusargs("TXN_CSV=%s", txn_csv)) txn_csv="phase2_txn.csv";
    txn_fd = $fopen(txn_csv, "w");
    if (txn_fd==0) $display("AUDIT2_WARN cannot open txn csv %s", txn_csv);
    else $fwrite(txn_fd, "idx,is_store,kind,cached,addr,size,pc,iv,phase,meas,nrdc,accept,dcfirst,treq,tar,trfirst,trlast,nrbeats,tweng,taw,twaxi,tbaxi,trsp,tbeng,tdone,lat,done_stall,lc0,lc1,lc2,lc3,lc4,lc5,dc0,dc1,dc2,dc3,dc4,dc5,dc6,dc7,dc8,in0,in1,in2,in3,in4,in5,breqwait,bwdatawait,brwait,bwwait,dwrreq,dwrreqdead,dwrresp,dwrhold,drdar,drddata,drddata_nor,dchit,didle,dcmiss\n");

    for (i=0;i<6;i=i+1) begin iv_ph_ld[i]=0; iv_ph_st[i]=0; iv_in_ld[i]=0; iv_in_st[i]=0; end
    for (i=0;i<9;i=i+1) begin iv_dc_ld[i]=0; iv_dc_st[i]=0; end

    repeat (20) @(negedge clk);
    rst_n = 1;

    fork
        begin wait (cycles >= max_cycles); end
        begin wait (mode_micro ? micro_done : have_stop);
              repeat (drain) @(posedge clk); end
    join_any
    repeat (50) @(posedge clk);

    $display("");
    $display("AUDIT2_SUMMARY cycles=%0d retires=%0d traps=%0d faults=%0d chars=%0d",
             cycles, retired, traps, faults, chars);
    $display("AUDIT2_WINDOW have_start=%0d have_stop=%0d t_start=%0d t_stop=%0d span=%0d",
             have_start, have_stop, t_start, t_stop, t_stop-t_start);
    $display("AUDIT2_TXN total=%0d iv=%0d accept_ld=%0d accept_st=%0d",
             tot_txn, tot_txn_iv, tot_accept_ld, tot_accept_st);
    $display("AUDIT2_AXI d_ar=%0d d_r=%0d d_aw=%0d d_w=%0d d_b=%0d i_ar=%0d i_r=%0d",
             iv_d_ar, iv_d_r, iv_d_aw, iv_d_w, iv_d_b, iv_i_ar, iv_i_r);
    $display("AUDIT2_MEM dc_req=%0d dc_miss=%0d dc_bypass=%0d dwrreq_dead_tot=%0d done_stall_iv=%0d",
             iv_dc_req, iv_dc_miss, iv_dc_byp, dwrreq_dead_tot, iv_done_stall);

    if (!(have_start && have_stop)) begin
        $display("AUDIT2_WARN no complete rdcycle..rdcycle interval (start=%0d stop=%0d)",
                 have_start, have_stop);
    end else begin
        $display("");
        $display("AUDIT2_INTERVAL cycles=%0d retires=%0d ipc=%f", iv_cycles, iv_retire,
                 iv_retire*1.0/(iv_cycles==0?1:iv_cycles));
        sum = iv_retire + iv_ld + iv_st + iv_div + iv_ex + iv_fe;
        $display("AUDIT2_CLASS retire=%0d lsu_load=%0d lsu_store=%0d div=%0d ex_other=%0d frontend_idle=%0d sum=%0d cycles=%0d",
                 iv_retire, iv_ld, iv_st, iv_div, iv_ex, iv_fe, sum, iv_cycles);
        if (sum != iv_cycles)
            $fatal(1, "ASSERT_FAIL class partition sum=%0d != iv_cycles=%0d", sum, iv_cycles);

        sum = iv_ph_ld[0]+iv_ph_ld[1]+iv_ph_ld[2]+iv_ph_ld[3]+iv_ph_ld[4]+iv_ph_ld[5];
        $display("AUDIT2_LSU_STATE_LOAD empty=%0d request=%0d write_data=%0d read_wait=%0d write_wait=%0d complete=%0d sum=%0d vs lsu_load=%0d",
                 iv_ph_ld[0],iv_ph_ld[1],iv_ph_ld[2],iv_ph_ld[3],iv_ph_ld[4],iv_ph_ld[5],
                 sum, iv_ld);
        if (sum != iv_ld) $fatal(1,"ASSERT_FAIL load LSU state split");
        sum = iv_ph_st[0]+iv_ph_st[1]+iv_ph_st[2]+iv_ph_st[3]+iv_ph_st[4]+iv_ph_st[5];
        $display("AUDIT2_LSU_STATE_STORE empty=%0d request=%0d write_data=%0d read_wait=%0d write_wait=%0d complete=%0d sum=%0d vs lsu_store=%0d",
                 iv_ph_st[0],iv_ph_st[1],iv_ph_st[2],iv_ph_st[3],iv_ph_st[4],iv_ph_st[5],
                 sum, iv_st);
        if (sum != iv_st) $fatal(1,"ASSERT_FAIL store LSU state split");

        sum = iv_dc_ld[0]+iv_dc_ld[1]+iv_dc_ld[2]+iv_dc_ld[3]+iv_dc_ld[4]+
              iv_dc_ld[5]+iv_dc_ld[6]+iv_dc_ld[7]+iv_dc_ld[8];
        $display("AUDIT2_DC_STATE_LOAD idle=%0d hit=%0d rd_ar=%0d rd_data=%0d wr_req=%0d wr_resp=%0d wr_hold=%0d byp=%0d fault=%0d sum=%0d vs lsu_load=%0d",
                 iv_dc_ld[0],iv_dc_ld[1],iv_dc_ld[2],iv_dc_ld[3],iv_dc_ld[4],
                 iv_dc_ld[5],iv_dc_ld[6],iv_dc_ld[7],iv_dc_ld[8], sum, iv_ld);
        if (sum != iv_ld) $fatal(1,"ASSERT_FAIL load dcache state split");
        sum = iv_dc_st[0]+iv_dc_st[1]+iv_dc_st[2]+iv_dc_st[3]+iv_dc_st[4]+
              iv_dc_st[5]+iv_dc_st[6]+iv_dc_st[7]+iv_dc_st[8];
        $display("AUDIT2_DC_STATE_STORE idle=%0d hit=%0d rd_ar=%0d rd_data=%0d wr_req=%0d wr_resp=%0d wr_hold=%0d byp=%0d fault=%0d sum=%0d vs lsu_store=%0d",
                 iv_dc_st[0],iv_dc_st[1],iv_dc_st[2],iv_dc_st[3],iv_dc_st[4],
                 iv_dc_st[5],iv_dc_st[6],iv_dc_st[7],iv_dc_st[8], sum, iv_st);
        if (sum != iv_st) $fatal(1,"ASSERT_FAIL store dcache state split");

        sum = iv_in_ld[0]+iv_in_ld[1]+iv_in_ld[2]+iv_in_ld[3]+iv_in_ld[4]+iv_in_ld[5];
        $display("AUDIT2_INNER_STATE_LOAD idle=%0d prep=%0d send=%0d resp=%0d hold=%0d fault=%0d sum=%0d",
                 iv_in_ld[0],iv_in_ld[1],iv_in_ld[2],iv_in_ld[3],iv_in_ld[4],iv_in_ld[5],sum);
        sum = iv_in_st[0]+iv_in_st[1]+iv_in_st[2]+iv_in_st[3]+iv_in_st[4]+iv_in_st[5];
        $display("AUDIT2_INNER_STATE_STORE idle=%0d prep=%0d send=%0d resp=%0d hold=%0d fault=%0d sum=%0d",
                 iv_in_st[0],iv_in_st[1],iv_in_st[2],iv_in_st[3],iv_in_st[4],iv_in_st[5],sum);

        $display("AUDIT2_LSU_IDLE state_empty=%0d state_busy=%0d sum=%0d vs cycles=%0d",
                 iv_lsu_idle, iv_lsu_busy, iv_lsu_idle+iv_lsu_busy, iv_cycles);
        if ((iv_lsu_idle+iv_lsu_busy) != iv_cycles)
            $fatal(1,"ASSERT_FAIL LSU idle/busy split");
        $display("AUDIT2_BUBBLE_CYC req_wait_no_ready=%0d wdata_wait_no_ready=%0d rwait_no_rsp=%0d wwait_no_b=%0d",
                 iv_reqwait, iv_wdatawait, iv_rwait, iv_wwait);
        $display("AUDIT2_BUBBLE_DC wr_req=%0d wr_req_dead=%0d wr_resp=%0d wr_hold=%0d rd_ar=%0d rd_data=%0d rd_data_no_r=%0d hit=%0d idle=%0d",
                 iv_dwrreq, iv_dwrreq_dead, iv_dwrresp, iv_dwrhold, iv_drdar,
                 iv_drddata, iv_drddata_nor, iv_dchit, iv_dcidle);
    end

    $display("");
    if (txn_fd!=0) $fclose(txn_fd);
    if (cyc_fd!=0) $fclose(cyc_fd);
    $finish;
end

// ---------------------------------------------------------------------------
// CSV row writer for the completed transaction
// ---------------------------------------------------------------------------
task automatic write_txn_row;
    integer j;
    integer kind_l;
    begin
        if (!t_req_seen) kind_l = 3;
        else if (!t_cached) kind_l = 2;
        else if (t_hit) kind_l = 0;
        else kind_l = 1;
        if (txn_fd==0) begin
            if (verbose) $display("AUDIT2_TXN_DROP idx=%0d", txn_idx);
        end else begin
            $fwrite(txn_fd,"%0d,%0d,%0d,%0d,%08x,%0d,%08x,%0d,%0d,%0d,%0d,%0d,%0d,%0d,",
                txn_idx, t_is_store, kind_l, t_cached, t_addr, t_size, t_pc,
                t_iv, t_phase, t_meas, t_nrdc_acc, t_accept, t_dcfirst, t_req);
            $fwrite(txn_fd,"%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,",
                t_ar, t_rfirst, t_rlast, n_rbeats, t_weng, t_aw, t_waxi,
                t_baxi, t_rsp, t_beng, t_done, t_done-t_accept, 0);
            for (j=0;j<6;j=j+1) $fwrite(txn_fd,"%0d,", lc[j]);
            for (j=0;j<9;j=j+1) $fwrite(txn_fd,"%0d,", dcc[j]);
            for (j=0;j<6;j=j+1) $fwrite(txn_fd,"%0d,", inc[j]);
            $fwrite(txn_fd,"%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d\n",
                b_reqwait, b_wdatawait, b_rwait, b_wwait,
                d_wrreq, d_wrreq_dead, d_wrresp, d_wrhold,
                d_rdar, d_rddata, d_rddata_nor, d_hitcyc, d_idlecyc, t_dcmiss);
        end
    end
endtask

// ---------------------------------------------------------------------------
// main per-cycle instrumentation
// ---------------------------------------------------------------------------
wire is_rdcycle = retire_fire && (retire_inst[6:0]==7'h73) &&
                  (retire_inst[14:12]!=3'b000) && (retire_inst[14:12]!=3'b100) &&
                  (retire_inst[31:20]==12'hC00);

wire csv_on = (cyc_fd!=0) &&
              ((csv_gate==2) || (csv_gate==0 && in_iv) ||
               (csv_gate==1 && ((nrdc%2)==1)));

integer last_retire_cycle=0;

always @(posedge clk) if (rst_n) begin
    cycles = cycles + 1;

    // ---------------- per-cycle CSV -----------------------------------------
    if (csv_on) begin
        $fwrite(cyc_fd,"%0d,%0d,%0d,%0d,%0d,%0d,",
            cycles, nrdc, in_iv, lsu_state, dc_state, inner_state);
        $fwrite(cyc_fd,"%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,",
            cpu_ex_valid, cpu_ex_done, cpu_is_mem, cpu_is_st,
            lsu_op_valid, lsu_op_ready, cpu_issued, lsu_done_v, lsu_done_r);
        $fwrite(cyc_fd,"%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,",
            eng_req_v, eng_req_r, eng_w_v, eng_w_r, eng_rsp_v, eng_rsp_r,
            eng_b_v, eng_b_r);
        $fwrite(cyc_fd,"%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d\n",
            d_ar_v, d_ar_r, d_r_v, d_r_r, d_r_last, d_aw_v, d_aw_r,
            d_w_v, d_w_r, d_b_v, d_b_r,
            soc.core.data_cache.miss_event, soc.core.data_cache.req_valid,
            soc.core.data_cache.req_ready);
        if (cycles%200000==0) $fflush(cyc_fd);
    end

    // ---------------- interval (CoreMark) per-cycle accounting --------------
    if (in_iv) begin
        iv_cycles = iv_cycles + 1;
        if (retire_fire) iv_retire = iv_retire + 1;

        if (cpu_ex_valid && !cpu_ex_done) begin
            if (cpu_is_mem) begin
                if (cpu_is_st) begin
                    iv_st = iv_st + 1;
                    iv_ph_st[lsu_state] = iv_ph_st[lsu_state] + 1;
                    iv_dc_st[dc_state]  = iv_dc_st[dc_state] + 1;
                    iv_in_st[inner_state] = iv_in_st[inner_state] + 1;
                end else begin
                    iv_ld = iv_ld + 1;
                    iv_ph_ld[lsu_state] = iv_ph_ld[lsu_state] + 1;
                    iv_dc_ld[dc_state]  = iv_dc_ld[dc_state] + 1;
                    iv_in_ld[inner_state] = iv_in_ld[inner_state] + 1;
                end
            end else if (cpu_is_div && cpu_div_busy) iv_div = iv_div + 1;
            else iv_ex = iv_ex + 1;
        end else if (!retire_fire) iv_fe = iv_fe + 1;

        if (lsu_state==L_EMPTY) iv_lsu_idle = iv_lsu_idle + 1;
        else                    iv_lsu_busy = iv_lsu_busy + 1;

        if (lsu_state==L_REQUEST   && !eng_req_r) iv_reqwait = iv_reqwait + 1;
        if (lsu_state==L_WRITE_DATA&& !eng_w_r)   iv_wdatawait = iv_wdatawait + 1;
        if (lsu_state==L_READ_WAIT && !eng_rsp_v) iv_rwait = iv_rwait + 1;
        if (lsu_state==L_WRITE_WAIT&& !eng_b_v)   iv_wwait = iv_wwait + 1;

        if (dc_state==ST_WR_REQ) begin
            iv_dwrreq = iv_dwrreq + 1;
            if (!soc.core.data_cache.w_ready) iv_dwrreq_dead = iv_dwrreq_dead + 1;
        end
        if (dc_state==ST_WR_RESP) iv_dwrresp = iv_dwrresp + 1;
        if (dc_state==ST_WR_HOLD) iv_dwrhold = iv_dwrhold + 1;
        if (dc_state==ST_RD_AR)   iv_drdar   = iv_drdar + 1;
        if (dc_state==ST_RD_DATA) begin
            iv_drddata = iv_drddata + 1;
            if (!d_r_v) iv_drddata_nor = iv_drddata_nor + 1;
        end
        if (dc_state==ST_HIT)     iv_dchit = iv_dchit + 1;
        if (dc_state==ST_IDLE)    iv_dcidle = iv_dcidle + 1;

        if (ev_dar) iv_d_ar = iv_d_ar + 1;
        if (ev_dr)  iv_d_r  = iv_d_r  + 1;
        if (ev_daw) iv_d_aw = iv_d_aw + 1;
        if (ev_dw)  iv_d_w  = iv_d_w  + 1;
        if (ev_db)  iv_d_b  = iv_d_b  + 1;
        if (soc.core.m_arvalid[0] && soc.core.m_arready[0]) iv_i_ar = iv_i_ar + 1;
        if (soc.core.m_rvalid[0]  && soc.core.m_rready[0])  iv_i_r  = iv_i_r  + 1;

        if (lsu_done_v && !lsu_done_r) iv_done_stall = iv_done_stall + 1;

        if (ev_accept) begin
            if (lsu_is_store) iv_acc_st = iv_acc_st + 1;
            else              iv_acc_ld = iv_acc_ld + 1;
        end
        if (ev_req) begin
            iv_dc_req = iv_dc_req + 1;
            if (soc.core.data_cache.miss_event) iv_dc_miss = iv_dc_miss + 1;
            if (!soc.core.data_cache.req_in_cache) iv_dc_byp = iv_dc_byp + 1;
        end
    end

    // ---------------- LSU transaction tracing --------------------------------
    if (txn_open && ev_done) begin
        t_done = cycles;
        write_txn_row();
        txn_open = 0;
        tot_txn = tot_txn + 1;
        if (t_iv) tot_txn_iv = tot_txn_iv + 1;
    end else if (txn_open) begin
        if (lsu_state<=5) lc[lsu_state] = lc[lsu_state] + 1;
        if (dc_state<=8)  dcc[dc_state] = dcc[dc_state] + 1;
        if (inner_state<=5) inc[inner_state] = inc[inner_state] + 1;

        if (lsu_state==L_REQUEST    && !eng_req_r) b_reqwait = b_reqwait + 1;
        if (lsu_state==L_WRITE_DATA && !eng_w_r)   b_wdatawait = b_wdatawait + 1;
        if (lsu_state==L_READ_WAIT  && !eng_rsp_v) b_rwait = b_rwait + 1;
        if (lsu_state==L_WRITE_WAIT && !eng_b_v)   b_wwait = b_wwait + 1;

        if (dc_state==ST_WR_REQ) begin
            d_wrreq = d_wrreq + 1;
            if (!soc.core.data_cache.w_ready) begin
                d_wrreq_dead = d_wrreq_dead + 1;
                dwrreq_dead_tot = dwrreq_dead_tot + 1;
            end
        end
        if (dc_state==ST_WR_RESP) d_wrresp = d_wrresp + 1;
        if (dc_state==ST_WR_HOLD) d_wrhold = d_wrhold + 1;
        if (dc_state==ST_RD_AR)   d_rdar   = d_rdar + 1;
        if (dc_state==ST_RD_DATA) begin
            d_rddata = d_rddata + 1;
            if (!d_r_v) d_rddata_nor = d_rddata_nor + 1;
        end
        if (dc_state==ST_HIT)  d_hitcyc = d_hitcyc + 1;
        if (dc_state==ST_IDLE) d_idlecyc = d_idlecyc + 1;

        if (soc.core.data_cache.miss_event) t_dcmiss = t_dcmiss + 1;
        if (t_cap_pending) begin
            t_hit      = soc.core.data_cache.hit_q;
            t_cached   = soc.core.data_cache.cached_q;
            t_dcfirst  = dc_state;
            t_cap_pending = 0;
        end
        if (!t_req_seen && ev_req) begin
            t_req = cycles; t_req_seen = 1; t_cap_pending = 1;
        end
        if (ev_dar && t_ar<0)     t_ar     = cycles;
        if (ev_dr) begin
            n_rbeats = n_rbeats + 1;
            if (t_rfirst<0) t_rfirst = cycles;
            if (ev_drl)     t_rlast  = cycles;
        end
        if (ev_weng && t_weng<0) t_weng = cycles;
        if (ev_daw  && t_aw<0)   t_aw   = cycles;
        if (ev_dw   && t_waxi<0) t_waxi = cycles;
        if (ev_db   && t_baxi<0) t_baxi = cycles;
        if (ev_rsp  && t_rsp<0)  t_rsp  = cycles;
        if (ev_beng && t_beng<0) t_beng = cycles;
    end

    if (!txn_open && ev_accept) begin
        txn_open = 1;
        txn_idx = txn_idx + 1;
        t_is_store = lsu_is_store;
        t_kind = 3; t_cached = 0; t_hit = 0;
        t_addr = soc.core.lsu.address;
        t_size = soc.core.lsu.access_size;
        t_pc   = soc.core.lsu.op_pc;
        t_iv   = in_iv;
        t_phase = nrdc/2;
        t_meas  = nrdc%2;
        t_nrdc_acc = nrdc;
        t_accept = cycles;
        t_req=-1; t_ar=-1; t_rfirst=-1; t_rlast=-1; t_weng=-1; t_aw=-1;
        t_waxi=-1; t_baxi=-1; t_rsp=-1; t_beng=-1; t_done=-1;
        t_dcfirst=-1; t_dcmiss=0; t_req_seen=0; t_cap_pending=0; n_rbeats=0;
        for (k=0;k<6;k=k+1) lc[k]=0;
        for (k=0;k<9;k=k+1) dcc[k]=0;
        for (k=0;k<6;k=k+1) inc[k]=0;
        b_reqwait=0; b_wdatawait=0; b_rwait=0; b_wwait=0;
        d_wrreq=0; d_wrreq_dead=0; d_wrresp=0; d_wrhold=0;
        d_rdar=0; d_rddata=0; d_rddata_nor=0; d_hitcyc=0; d_idlecyc=0;
        // the accept cycle itself is an LSU-stall cycle in state EMPTY
        lc[L_EMPTY] = lc[L_EMPTY] + 1;
        if (dc_state<=8) dcc[dc_state] = dcc[dc_state] + 1;
        if (inner_state<=5) inc[inner_state] = inc[inner_state] + 1;
        if (lsu_is_store) tot_accept_st = tot_accept_st + 1;
        else              tot_accept_ld = tot_accept_ld + 1;
    end

    // ---------------- retirement / window boundaries ------------------------
    if (retire_fire) begin
        retired = retired + 1;
        last_retire_cycle = cycles;
    end
    if (trap_fire) begin
        traps = traps + 1;
        if (traps<8) $display("TRAP cycle=%0d cause=%0d pc=%08x tval=%08x",
                              cycles, trap_cause, trap_pc, trap_tval);
    end
    if (protocol_fault) begin
        faults = faults + 1;
        if (faults<8) $display("BUS_FAULT cycle=%0d", cycles);
    end

    if (is_rdcycle) begin
        $display("AUDIT2_RDCLK n=%0d cycle=%0d phase=%0d meas=%0d pc=%08x",
                 nrdc+1, cycles, nrdc/2, nrdc%2, retire_pc);
        nrdc = nrdc + 1;
        if (!have_start) begin
            have_start = 1; t_start = cycles;
            $display("AUDIT2_START cycle=%0d", cycles);
        end else if (!have_stop) begin
            have_stop = 1; t_stop = cycles;
            $display("AUDIT2_STOP cycle=%0d span=%0d", cycles, cycles-t_start);
        end
    end

    if ((cycles-last_retire_cycle) > 400000 && cycles > 400000) begin
        $display("AUDIT2_FAIL no retirement for 400000 cycles (cycles=%0d pc=%08x)",
                 cycles, retire_pc);
        $fatal(1,"retirement stalled");
    end
    if (verbose && cycles%200000==0)
        $display("AUDIT2_PROGRESS cycles=%0d retires=%0d pc=%08x", cycles, retired, retire_pc);
end

// ---------------------------------------------------------------------------
// UART TX decoder: detects "MICROBENCH done" and CoreMark report strings
// ---------------------------------------------------------------------------
reg [15:0] div_cnt=0;
reg [3:0]  bit_idx=0;
reg [7:0]  sh=0;
reg        busy=0;
reg        tx_q=1;
reg [8*20-1:0] match_reg=0;

always @(posedge clk) begin
    tx_q <= uart_tx;
    if (!busy) begin
        if (tx_q && !uart_tx) begin
            busy<=1; div_cnt<=(BAUD_DIV/2); bit_idx<=0; sh<=0;
        end
    end else begin
        if (div_cnt==0) begin
            if (bit_idx==0) begin
                bit_idx<=1; div_cnt<=BAUD_DIV-1;
            end else if (bit_idx<=8) begin
                sh[bit_idx-1] = uart_tx;
                if (bit_idx==8) begin
                    chars = chars + 1;
                    $write("%c", sh[7:0]);
                    match_reg = {match_reg[8*19-1:0], sh[7:0]};
                    if (!micro_done && (match_reg[8*15-1:0] === "MICROBENCH done")) begin
                        micro_done = 1;
                        $display("\nAUDIT2_MICRO_DONE cycle=%0d", cycles);
                    end
                    if (!report_seen &&
                        (match_reg[8*17-1:0] === "Correct operation" ||
                         match_reg[8*15-1:0] === "Errors detected")) begin
                        report_seen = 1;
                        $display("\nAUDIT2_REPORT_SEEN cycle=%0d", cycles);
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

endmodule
