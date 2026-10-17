//=============================================================================
// pangoriscv - RV32IM processor core + native AXI4 SoC (Pango PG2L100H @ 27 MHz)
// Module : tb_ifu_axi_engine      File : tb/axi/tb_ifu_axi_engine.sv
// Rev    : 1.0                    Date : 2026-10-13
// Author : pango_lpenghan
// Brief  : Fetch-queue contract of ifu_axi against the real AXI read engine, with
//          randomised ready/data delays driven by +SEED
//=============================================================================

`timescale 1ns/1ps
// ---------------------------------------------------------------------------
// tb_ifu_axi_engine -- fetch-queue contract of ifu_axi against the real AXI
// read engine, with randomised ready/data delays driven by +SEED.
//
// Covered contract (T1 queue):
//   * one engine transaction at a time; AR identity fields stay fixed;
//   * the queue fills up to DEPTH entries while the pipeline never accepts and
//     then stops requesting (no unbounded prefetch);
//   * every delivered instruction is exactly the one the architectural PC asks
//     for, in order, carrying the prediction captured at request time;
//   * a redirect anywhere drops the whole speculative queue plus the response
//     still in flight: nothing from the old stream is ever delivered;
//   * a local fault (misaligned or outside the executable window) is delivered
//     without any AXI request; an engine response fault is delivered with
//     cause=1 and stops further prefetch;
//   * no work while disabled; a disabled unit drains and reports idle.
// ---------------------------------------------------------------------------
module tb_ifu_axi_engine;
    reg clk=0;
    always #5 clk=~clk;
    reg rst_n=0,enable=0,redirect_valid=0,fetch_ready=0;
    reg [31:0] fetch_pc=32'h20;
    // The predictor under test: a stride-8 stream, so the prediction a slot was
    // created with is verifiable at delivery time.
    wire [31:0] predicted_next_pc=fetch_pc+32'd8;
    wire [31:0] chain_c,chain_predict_next_pc;
    assign chain_predict_next_pc=chain_c+32'd8;
    wire fetch_valid,result_fault,idle,flush_lost;
    wire [31:0] result_pc,result_inst,result_predicted_next_pc,result_fault_tval;
    wire [4:0] result_fault_cause;
    wire eng_req_valid,eng_req_ready,eng_rsp_valid,eng_rsp_ready;
    wire [31:0] eng_req_addr,eng_rsp_data;
    wire [2:0] eng_req_size;
    wire [7:0] eng_req_len;
    wire [3:0] eng_req_id,eng_rsp_id;
    wire [1:0] eng_rsp_resp;
    wire eng_rsp_last,protocol_fault,config_fault;
    wire m_arvalid,m_arlock,m_rready;
    reg m_arready=0,m_rvalid=0,m_rlast=1;
    wire [31:0] m_araddr;
    reg [31:0] m_rdata=0;
    wire [3:0] m_arid,m_arcache,m_arqos;
    reg [3:0] m_rid=0;
    wire [7:0] m_arlen;
    wire [2:0] m_arsize,m_arprot;
    wire [1:0] m_arburst;
    reg [1:0] m_rresp=0;
    ifu_axi #(.DEPTH(8)) ifu(.*);
    axi_read_engine engine(
        .clk(clk),.rst_n(rst_n),.req_valid(eng_req_valid),.req_ready(eng_req_ready),
        .req_addr(eng_req_addr),.req_size(eng_req_size),.req_len(eng_req_len),.req_id(eng_req_id),
        .rsp_valid(eng_rsp_valid),.rsp_ready(eng_rsp_ready),.rsp_data(eng_rsp_data),
        .rsp_resp(eng_rsp_resp),.rsp_last(eng_rsp_last),.rsp_id(eng_rsp_id),
        .protocol_fault(protocol_fault),.config_fault(config_fault),
        .m_arvalid(m_arvalid),.m_arready(m_arready),.m_araddr(m_araddr),
        .m_arid(m_arid),.m_arlen(m_arlen),.m_arsize(m_arsize),
        .m_arburst(m_arburst),.m_arlock(m_arlock),.m_arcache(m_arcache),
        .m_arprot(m_arprot),.m_arqos(m_arqos),
        .m_rvalid(m_rvalid),.m_rready(m_rready),.m_rdata(m_rdata),
        .m_rid(m_rid),.m_rresp(m_rresp),.m_rlast(m_rlast));

    integer reqs=0,ars=0,rs=0,engine_results=0,deliveries=0,seed,rng;
    integer stale_credit=0;
    reg [31:0] exp_ar_pc=32'h20;
    reg check_stream=0;
    reg transaction_live=0;
    reg held=0;
    reg [133:0] held_payload;
    wire [133:0] fetch_payload={result_pc,result_inst,result_predicted_next_pc,
        result_fault,result_fault_cause,result_fault_tval};

    function integer delay32;
        begin delay32=$unsigned($random(rng))%32; end
    endfunction
    task tick(input integer count);
        repeat(count) @(negedge clk);
    endtask

    // Delivery identity: a normal slot must carry the instruction and the
    // prediction the fetch stream implies; a fault slot only has to carry the
    // right PC and be flagged (its data and prediction are meaningless).
    task deliver_check;
        begin
            if(result_pc!==fetch_pc)
                $fatal(1,"IFU_DELIVER_PC got=%h exp=%h",result_pc,fetch_pc);
            if(!result_fault) begin
                if(result_inst!==(result_pc+32'h00100093))
                    $fatal(1,"IFU_DELIVER_INST inst=%h pc=%h",result_inst,result_pc);
                if(result_predicted_next_pc!==(result_pc+32'd8))
                    $fatal(1,"IFU_DELIVER_PRED pred=%h pc=%h",
                           result_predicted_next_pc,result_pc);
            end
            deliveries=deliveries+1;
        end
    endtask

    ifu_engine_stability #(61) ar_check(clk,rst_n,m_arvalid,m_arready,
        {m_araddr,m_arid,m_arlen,m_arsize,m_arburst,m_arlock,m_arcache,m_arprot,m_arqos});
    ifu_engine_stability #(39) r_check(clk,rst_n,m_rvalid,m_rready,
        {m_rdata,m_rid,m_rresp,m_rlast});
    ifu_engine_stability #(39) eng_check(clk,rst_n,eng_rsp_valid,eng_rsp_ready,
        {eng_rsp_data,eng_rsp_id,eng_rsp_resp,eng_rsp_last});

    always @(posedge clk) begin
        if(!rst_n) begin
            held<=0; transaction_live=0;
        end else begin
            // A delivered slot may never change while the pipeline holds it.
            // A redirect is exempt: it flushes whatever the pipeline held, so
            // fetch_valid is allowed to drop (and the new head may differ).
            if(held && enable && !redirect_valid &&
               (!fetch_valid || fetch_payload!==held_payload))
                $fatal(1,"IFU_RESULT_CHANGED_WHILE_HELD");
            held<=fetch_valid && !fetch_ready;
            held_payload<=fetch_payload;
            if(eng_req_valid && eng_req_ready) begin
                if(transaction_live) $fatal(1,"IFU_MULTIPLE_ENGINE_OWNERS");
                if(eng_req_size!==2 || eng_req_len!==0 || eng_req_id!==0)
                    $fatal(1,"IFU_REQ_IDENTITY_FIELDS");
                transaction_live=1; reqs=reqs+1;
            end
            if(m_arvalid && m_arready) begin
                if(!transaction_live || m_arid!==0 || m_arlen!==0 || m_arsize!==2 ||
                   m_arburst!==1 || m_arlock!==0 || m_arcache!==0 || m_arprot!==0 ||
                   m_arqos!==0)
                    $fatal(1,"IFU_AR_IDENTITY_FIELDS");
                ars=ars+1;
            end
            if(m_rvalid && m_rready) rs=rs+1;
            if(eng_rsp_valid && eng_rsp_ready) begin
                if(!transaction_live) $fatal(1,"IFU_ORPHAN_ENGINE_RESULT");
                transaction_live=0; engine_results=engine_results+1;
            end
            if(!enable && (eng_req_valid || fetch_valid))
                $fatal(1,"IFU_WORK_WHILE_DISABLED");
            if(redirect_valid && (eng_req_valid || fetch_valid))
                $fatal(1,"IFU_WORK_ON_REDIRECT");
            if(fetch_valid && fetch_ready) deliver_check();
            if(protocol_fault || config_fault) $fatal(1,"IFU_ENGINE_FAULT");
            if(flush_lost) $fatal(1,"IFU_HEAD_MISMATCH_FLUSH");
        end
    end

    // ---- engine servicing ---------------------------------------------------
    // Complete one request/response pair.  The address is checked against the
    // fetch stream only while check_stream is set (never around a redirect).
    task service_req;
        reg [31:0] a; reg [31:0] d;
        begin
            while(!m_arvalid) tick(1);
            a=m_araddr;
            if(check_stream) begin
                if(a!==exp_ar_pc) begin
                    if(stale_credit>0) stale_credit=stale_credit-1;
                    else $fatal(1,"IFU_AR_STREAM got=%h exp=%h",a,exp_ar_pc);
                end else exp_ar_pc=exp_ar_pc+32'd8;
            end
            tick(delay32());
            m_arready=1; tick(1); m_arready=0;
            while(!m_rready) tick(1);
            d=(a&32'h3fff)+32'h00100093;
            tick(delay32());
            m_rdata=d; m_rresp=0; m_rid=0; m_rlast=1; m_rvalid=1;
            tick(1); m_rvalid=0; m_rdata=0;
            tick(1);
        end
    endtask
    // Response with a bus error: the delivered slot must carry fault cause 1.
    task service_req_err;
        reg [31:0] a;
        begin
            while(!m_arvalid) tick(1);
            a=m_araddr;
            if(check_stream && a===exp_ar_pc) exp_ar_pc=exp_ar_pc+32'd8;
            tick(delay32());
            m_arready=1; tick(1); m_arready=0;
            while(!m_rready) tick(1);
            m_rdata=32'habcd1234; m_rresp=2; m_rid=0; m_rlast=1; m_rvalid=1;
            tick(1); m_rvalid=0; m_rdata=0; m_rresp=0;
            tick(1);
        end
    endtask
    // Finish whatever the engine still owns, without stream checks: the address
    // may legitimately belong to the pre-redirect stream.  Covers both "AR not
    // accepted yet" and "waiting for R".
    task drain_stale_txn;
        begin
            check_stream=0;
            if(m_arvalid) begin
                tick(delay32());
                m_arready=1; tick(1); m_arready=0;
            end
            while(!m_rready) tick(1);
            tick(delay32());
            m_rdata=32'hdeadbeef; m_rresp=0; m_rid=0; m_rlast=1; m_rvalid=1;
            tick(1); m_rvalid=0; m_rdata=0;
            tick(1);
        end
    endtask
    task redirect_to(input [31:0] pc);
        begin
            redirect_valid=1; fetch_pc=pc; enable=1;
            tick(1); redirect_valid=0;
            held=0; held_payload=0;
            if(transaction_live) drain_stale_txn();
            exp_ar_pc=pc; check_stream=1;
        end
    endtask
    // Consume one slot the way pc_reg does: hold it, then accept it.
    task consume;
        reg [31:0] nxt;
        begin
            while(!fetch_valid) tick(1);
            if(result_pc!==fetch_pc) $fatal(1,"IFU_CONSUME_PC got=%h exp=%h",result_pc,fetch_pc);
            repeat(3) begin
                if(!fetch_valid || result_pc!==fetch_pc)
                    $fatal(1,"IFU_SLOT_UNSTABLE");
                if(!result_fault && result_inst!==(fetch_pc+32'h00100093))
                    $fatal(1,"IFU_SLOT_DATA_UNSTABLE");
                tick(1);
            end
            nxt=result_predicted_next_pc;
            fetch_ready=1; tick(1); fetch_ready=0;
            fetch_pc=nxt;
            tick(1);
        end
    endtask
    task drain_disabled;
        begin
            enable=0; check_stream=0;
            tick(2);
            if(transaction_live) drain_stale_txn();
            tick(5);
            if(!idle || fetch_valid || transaction_live || !eng_req_ready)
                $fatal(1,"IFU_DISABLED_DRAIN");
        end
    endtask

    integer k;
    initial begin
        if(!$value$plusargs("SEED=%d",seed)) seed=1;
        rng=seed;
        tick(3); rst_n=1; tick(1);

        // (1) Fill the queue with no consumer: DEPTH requests, then stop.
        enable=1; fetch_pc=32'h20; check_stream=1; exp_ar_pc=32'h20;
        for(k=0;k<8;k=k+1) service_req();
        tick(4);
        if(eng_req_valid || m_arvalid) $fatal(1,"IFU_QUEUE_FULL_STILL_REQUESTING");
        if(idle) $fatal(1,"IFU_QUEUE_FULL_REPORTS_IDLE");

        // (2) The consumer drains three slots while the rest stay queued.
        for(k=0;k<3;k=k+1) consume();
        if(!fetch_valid) $fatal(1,"IFU_QUEUE_NOT_AHEAD");

        // (3) A redirect in the middle drops the whole speculative queue.
        redirect_to(32'h400);
        tick(2);
        if(fetch_valid && result_pc<32'h400) $fatal(1,"IFU_STALE_SLOT_AFTER_REDIRECT");
        for(k=0;k<8;k=k+1) service_req();
        for(k=0;k<8;k=k+1) consume();
        if(idle) $fatal(1,"IFU_NOT_IDLE_WHILE_ENABLED");

        // (4) Engine response fault: delivered with cause=1, then no prefetch.
        redirect_to(32'h500);
        service_req_err();
        tick(2);
        if(!fetch_valid || result_pc!==32'h500 || !result_fault ||
           result_fault_cause!==1 || result_fault_tval!==32'h500)
            $fatal(1,"IFU_RSP_FAULT_SLOT pc=%h fault=%b cause=%0d",
                   result_pc,result_fault,result_fault_cause);
        tick(3);
        if(eng_req_valid) $fatal(1,"IFU_PREFETCH_AFTER_FAULT");
        consume();

        // (5) Local fault: misaligned PC, no AXI request at all.
        redirect_to(32'h22);
        tick(3);
        if(!fetch_valid || result_pc!==32'h22 || !result_fault ||
           result_fault_cause!==0 || result_fault_tval!==32'h22)
            $fatal(1,"IFU_LOCAL_FAULT_SLOT pc=%h fault=%b cause=%0d",
                   result_pc,result_fault,result_fault_cause);
        consume();

        // (6) Outside the executable window: fault, still no request.
        redirect_to(32'h50000000);
        tick(3);
        if(!fetch_valid || !result_fault || result_fault_cause!==1)
            $fatal(1,"IFU_NONEXEC_FAULT_SLOT pc=%h cause=%0d",result_pc,result_fault_cause);
        consume();

        // (7) Halt with a request in flight: drain, report idle, stay quiet.
        redirect_to(32'h600);
        service_req();
        drain_disabled();
        fetch_pc=32'h700; check_stream=0; tick(5);
        if(!idle || fetch_valid || eng_req_valid) $fatal(1,"IFU_QUIET_WHILE_DISABLED");

        // (8) Resume from the new architectural PC.
        enable=1; check_stream=1; exp_ar_pc=32'h700;
        for(k=0;k<3;k=k+1) service_req();
        for(k=0;k<3;k=k+1) consume();
        drain_disabled();

        if(reqs!=ars || ars!=rs || rs!=engine_results)
            $fatal(1,"IFU_COUNTS req=%0d AR=%0d R=%0d engine=%0d",reqs,ars,rs,engine_results);
        if(deliveries!=17) $fatal(1,"IFU_DELIVERIES %0d",deliveries);
        $display("TEST_PASS IFU_REAL_ENGINE seed=%0d req=%0d AR=%0d R=%0d delivered=%0d",
                 seed,reqs,ars,rs,deliveries);
        $finish;
    end
    initial begin #2000000; $fatal(1,"IFU_ENGINE_TIMEOUT"); end
endmodule

module ifu_engine_stability #(parameter W=32)(
    input wire clk,rst_n,valid,ready,input wire [W-1:0] payload
);
    reg blocked=0;
    reg [W-1:0] saved;
    always @(posedge clk) begin
        if(!rst_n) blocked<=0;
        else begin
            if(blocked && (valid!==1 || payload!==saved))
                $fatal(1,"IFU_ENGINE_CHANNEL_CHANGED_WHILE_BLOCKED");
            blocked<=valid && !ready;
            saved<=payload;
        end
    end
endmodule
