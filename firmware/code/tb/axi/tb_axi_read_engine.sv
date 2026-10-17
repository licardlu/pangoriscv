//=============================================================================
// pangoriscv - RV32IM processor core + native AXI4 SoC (Pango PG2L100H @ 27 MHz)
// Module : tb_axi_read_engine     File : tb/axi/tb_axi_read_engine.sv
// Rev    : 1.0                    Date : 2026-10-13
// Author : pango_lpenghan
// Brief  : Randomised testbench for the AXI4 read engine, shared with the data
//          engine stimulus
//=============================================================================

`timescale 1ns/1ps
// Shared stimulus exercises the read engine directly and through the data engine.
module engine_test #(parameter DATA_ENGINE=0);
    reg clk=0;
    always #5 clk=~clk;
    reg rst_n=0;
    reg req_valid=0, req_write=0;
    wire req_ready;
    reg [31:0] req_addr=0;
    reg [2:0] req_size=2;
    reg [7:0] req_len=0;
    reg [3:0] req_id=0;
    reg w_valid=0, w_last=1;
    wire w_ready;
    reg [31:0] w_data=0;
    reg [3:0] w_strb=0;
    wire rsp_valid, rsp_last;
    reg rsp_ready=0;
    wire [31:0] rsp_data;
    wire [1:0] rsp_resp;
    wire [3:0] rsp_id;
    wire b_valid;
    reg b_ready=0;
    wire [1:0] b_resp;
    wire [3:0] b_id;
    wire protocol_fault, config_fault;
    wire m_arvalid, m_arlock;
    reg m_arready=0;
    wire [31:0] m_araddr;
    wire [3:0] m_arid, m_arcache, m_arqos;
    wire [7:0] m_arlen;
    wire [2:0] m_arsize, m_arprot;
    wire [1:0] m_arburst;
    reg m_rvalid=0, m_rlast=1;
    wire m_rready;
    reg [31:0] m_rdata=0;
    reg [3:0] m_rid=0;
    reg [1:0] m_rresp=0;
    wire m_awvalid, m_awlock, m_wvalid, m_wlast, m_bready;
    reg m_awready=0, m_wready=0, m_bvalid=0;
    wire [31:0] m_awaddr, m_wdata;
    wire [3:0] m_awid, m_awcache, m_awqos, m_wstrb;
    wire [7:0] m_awlen;
    wire [2:0] m_awsize, m_awprot;
    wire [1:0] m_awburst;
    reg [3:0] m_bid=0;
    reg [1:0] m_bresp=0;

    generate if(DATA_ENGINE) begin: data_dut
        axi_data_engine dut(.*);
    end else begin: read_dut
        axi_read_engine dut(
            .clk(clk), .rst_n(rst_n), .req_valid(req_valid), .req_ready(req_ready),
            .req_addr(req_addr), .req_size(req_size), .req_len(req_len), .req_id(req_id),
            .rsp_valid(rsp_valid), .rsp_ready(rsp_ready), .rsp_data(rsp_data),
            .rsp_resp(rsp_resp), .rsp_last(rsp_last), .rsp_id(rsp_id),
            .protocol_fault(protocol_fault), .config_fault(config_fault),
            .m_arvalid(m_arvalid), .m_arready(m_arready), .m_araddr(m_araddr),
            .m_arid(m_arid), .m_arlen(m_arlen), .m_arsize(m_arsize),
            .m_arburst(m_arburst), .m_arlock(m_arlock), .m_arcache(m_arcache),
            .m_arprot(m_arprot), .m_arqos(m_arqos),
            .m_rvalid(m_rvalid), .m_rready(m_rready), .m_rdata(m_rdata),
            .m_rid(m_rid), .m_rresp(m_rresp), .m_rlast(m_rlast));
        assign w_ready=0;
        assign b_valid=0;
        assign b_resp=0;
        assign b_id=0;
        assign m_awvalid=0;
        assign m_awaddr=0;
        assign m_awid=0;
        assign m_awlen=0;
        assign m_awsize=0;
        assign m_awburst=0;
        assign m_awlock=0;
        assign m_awcache=0;
        assign m_awprot=0;
        assign m_awqos=0;
        assign m_wvalid=0;
        assign m_wdata=0;
        assign m_wstrb=0;
        assign m_wlast=0;
        assign m_bready=0;
    end endgenerate

    integer ar_count=0, r_count=0, aw_count=0, w_count=0, b_count=0;
    integer rsp_count=0, done_count=0, req_count=0;
    integer seed, rng, unused, i, n, fault_kind=0;
    reg [31:0] expected_data;
    reg [3:0] expected_id;
    reg [1:0] expected_resp;
    wire [60:0] ar_payload={m_araddr,m_arid,m_arlen,m_arsize,m_arburst,
        m_arlock,m_arcache,m_arprot,m_arqos};
    wire [60:0] aw_payload={m_awaddr,m_awid,m_awlen,m_awsize,m_awburst,
        m_awlock,m_awcache,m_awprot,m_awqos};
    engine_stability #(61) ar_check(clk,rst_n,m_arvalid,m_arready,ar_payload);
    engine_stability #(61) aw_check(clk,rst_n,m_awvalid,m_awready,aw_payload);
    engine_stability #(37) w_check(clk,rst_n,m_wvalid,m_wready,{m_wdata,m_wstrb,m_wlast});
    engine_stability #(39) r_check(clk,rst_n,m_rvalid,m_rready,{m_rdata,m_rid,m_rresp,m_rlast});
    engine_stability #(6) b_check(clk,rst_n,m_bvalid,m_bready,{m_bid,m_bresp});
    engine_stability #(39) rsp_check(clk,rst_n,rsp_valid,rsp_ready,{rsp_data,rsp_id,rsp_resp,rsp_last});
    engine_stability #(6) done_check(clk,rst_n,b_valid,b_ready,{b_id,b_resp});

    always @(posedge clk) begin
        if (!rst_n) begin
            if(req_ready || w_ready || rsp_valid || b_valid || m_arvalid ||
               m_awvalid || m_wvalid || m_rready || m_bready)
                $fatal(1,"RESET_GATING");
            ar_count=0; r_count=0; aw_count=0; w_count=0; b_count=0;
            rsp_count=0; done_count=0; req_count=0;
        end else begin
            if(req_valid && req_ready) req_count=req_count+1;
            if(m_arvalid && m_arready) ar_count=ar_count+1;
            if(m_rvalid && m_rready) r_count=r_count+1;
            if(m_awvalid && m_awready) aw_count=aw_count+1;
            if(m_wvalid && m_wready) w_count=w_count+1;
            if(m_bvalid && m_bready) b_count=b_count+1;
            if(rsp_valid && rsp_ready) begin
                rsp_count=rsp_count+1;
                if(rsp_data!==expected_data || rsp_id!==expected_id ||
                   rsp_resp!==expected_resp || rsp_last!==1)
                    $fatal(1,"READ_RESULT");
            end
            if(b_valid && b_ready) begin
                done_count=done_count+1;
                if(b_id!==expected_id || b_resp!==expected_resp)
                    $fatal(1,"WRITE_RESULT");
            end
        end
    end

    function integer delay32;
        begin delay32=$unsigned($random(rng)) % 32; end
    endfunction
    task tick(input integer count);
        repeat(count) @(negedge clk);
    endtask
    task request(input bit wr, input [31:0] address, input [2:0] size,
                 input [7:0] length, input [3:0] id);
        begin
            while(!req_ready) @(negedge clk);
            req_write=wr; req_addr=address; req_size=size; req_len=length; req_id=id;
            req_valid=1;
            @(negedge clk);
            req_valid=0;
            // Deliberately invalidate source fields after the internal handshake.
            req_addr=32'hdeadbeef; req_size=7; req_len=255; req_id=15; req_write=!wr;
        end
    endtask
    task reset_dut;
        begin
            rst_n=0; req_valid=0; w_valid=0; m_rvalid=0; m_bvalid=0;
            m_arready=0; m_awready=0; m_wready=0; rsp_ready=0; b_ready=0;
            tick(3); rst_n=1; tick(1);
            if(protocol_fault || config_fault || !req_ready) $fatal(1,"RESET_RECOVERY");
        end
    endtask

    task read_one(input integer ar_wait, input integer r_wait,
                  input integer hold_wait, input [1:0] response, input [3:0] id);
        reg [31:0] address;
        integer old_ar, old_rsp;
        begin
            old_ar=ar_count; old_rsp=rsp_count;
            address=32'h10000000 + (old_ar*4);
            expected_data=32'hcafed000+old_ar; expected_id=id; expected_resp=response;
            request(0,address,old_ar%3,0,id);
            tick(ar_wait);
            if(!m_arvalid || m_araddr!==address || m_arid!==id || m_arlen!==0 ||
               m_arsize!==(old_ar%3) || m_arburst!==1 || m_arlock!==0 || m_arcache!==0 ||
               m_arprot!==0 || m_arqos!==0)
                $fatal(1,"AR_FIELDS");
            m_arready=1; tick(1); m_arready=0;
            tick(r_wait);
            m_rdata=expected_data; m_rid=id; m_rresp=response; m_rlast=1; m_rvalid=1;
            while(!m_rready) tick(1);
            tick(1); m_rvalid=0; m_rdata=0; m_rresp=0; m_rid=0;
            if(!rsp_valid) $fatal(1,"READ_RETURN_MISSING");
            tick(hold_wait);
            if(req_ready || ar_count!=old_ar+1 || rsp_count!=old_rsp)
                $fatal(1,"READ_OWNERSHIP");
            rsp_ready=1; tick(1); rsp_ready=0; tick(1);
            if(rsp_count!=old_rsp+1 || rsp_valid || !req_ready)
                $fatal(1,"READ_COMPLETION_COUNT");
        end
    endtask

    task write_one(input integer aw_wait, input integer w_wait,
                   input integer b_wait, input integer hold_wait,
                   input bit aw_depends_w, input [1:0] response, input [3:0] id);
        reg [31:0] address, value;
        integer old_aw, old_w, old_b, old_done, elapsed;
        begin
            old_aw=aw_count; old_w=w_count; old_b=b_count; old_done=done_count;
            address=32'h20000000+4*old_aw; value=32'h12345000+old_aw;
            expected_id=id; expected_resp=response;
            request(1,address,old_aw%3,0,id);
            tick(delay32());
            while(!w_ready) tick(1);
            w_data=value; w_strb=4'b0101; w_last=1; w_valid=1;
            tick(1); w_valid=0; w_data=32'hffffffff; w_strb=0; w_last=0;
            elapsed=0;
            while(aw_count==old_aw || w_count==old_w) begin
                if(aw_count==old_aw) begin
                    if(!m_awvalid || m_awaddr!==address || m_awid!==id ||
                       m_awlen!==0 || m_awsize!==(old_aw%3) || m_awburst!==1 ||
                       m_awlock!==0 || m_awcache!==0 || m_awprot!==0 || m_awqos!==0)
                        $fatal(1,"AW_FIELDS");
                    m_awready=(elapsed>=aw_wait) && (!aw_depends_w || m_wvalid);
                end else m_awready=0;
                if(w_count==old_w) begin
                    if(!m_wvalid || m_wdata!==value || m_wstrb!==4'b0101 || !m_wlast)
                        $fatal(1,"W_FIELDS");
                    m_wready=(elapsed>=w_wait);
                end else m_wready=0;
                if(b_valid || req_ready) $fatal(1,"EARLY_STORE_COMPLETION");
                tick(1); elapsed=elapsed+1;
            end
            m_awready=0; m_wready=0;
            tick(b_wait);
            m_bid=id; m_bresp=response; m_bvalid=1;
            while(!m_bready) tick(1);
            tick(1); m_bvalid=0; m_bid=0; m_bresp=0;
            if(!b_valid) $fatal(1,"WRITE_RETURN_MISSING");
            tick(hold_wait);
            if(done_count!=old_done || req_ready) $fatal(1,"WRITE_OWNERSHIP");
            b_ready=1; tick(1); b_ready=0; tick(1);
            if(done_count!=old_done+1 || aw_count!=old_aw+1 || w_count!=old_w+1 ||
               b_count!=old_b+1 || b_valid || !req_ready)
                $fatal(1,"WRITE_COMPLETION_COUNT");
        end
    endtask

    // Both endpoints are reset together: no claim that a local reset cancels AXI.
    task coordinated_reset_phases;
        integer phase;
        begin
            for(phase=0;phase<3;phase=phase+1) begin
                request(0,32'h1000,2,0,3);
                if(phase>=1) begin
                    m_arready=1; tick(1); m_arready=0;
                end
                if(phase>=2) begin
                    m_rvalid=1; m_rid=3; m_rlast=1; m_rresp=0;
                    tick(1); m_rvalid=0;
                    if(!rsp_valid) $fatal(1,"RESET_READ_PHASE");
                end
                reset_dut();
            end
            if(DATA_ENGINE) begin
                for(phase=0;phase<6;phase=phase+1) begin
                    request(1,32'h1000,2,0,3);
                    if(phase>=1) begin
                        w_valid=1; w_data=32'h9876; w_strb=15; w_last=1;
                        tick(1); w_valid=0;
                    end
                    if(phase==2) begin
                        m_awready=1; tick(1); m_awready=0;
                    end
                    if(phase==3) begin
                        m_wready=1; tick(1); m_wready=0;
                    end
                    if(phase>=4) begin
                        m_awready=1; m_wready=1; tick(1);
                        m_awready=0; m_wready=0;
                    end
                    if(phase>=5) begin
                        m_bvalid=1; m_bid=3; m_bresp=0; tick(1); m_bvalid=0;
                        if(!b_valid) $fatal(1,"RESET_WRITE_PHASE");
                    end
                    reset_dut();
                end
            end
        end
    endtask

    task fault_test;
        begin
            case(fault_kind)
                1: request(0,32'h1000,2,1,3);
                2: request(0,32'h1000,3,0,3);
                3,4: begin
                    request(0,32'h1000,2,0,3);
                    m_arready=1; tick(1); m_arready=0;
                    m_rvalid=1; m_rdata=32'h1234; m_rid=(fault_kind==3 ? 4 : 3);
                    m_rlast=(fault_kind!=4); tick(1); m_rvalid=0;
                end
                5,6,7,8: begin
                    request(1,32'h1000,(fault_kind==8 ? 3 : 2),(fault_kind==7 ? 1 : 0),3);
                    if(fault_kind==5 || fault_kind==6) begin
                        w_valid=1; w_data=32'h5678; w_strb=15; w_last=(fault_kind!=6);
                        tick(1); w_valid=0;
                        if(fault_kind==5) begin
                            m_awready=1; m_wready=1; tick(1);
                            m_awready=0; m_wready=0;
                            m_bvalid=1; m_bid=4; m_bresp=0; tick(1); m_bvalid=0;
                        end
                    end
                end
                default: $fatal(1,"UNKNOWN_FAULT_CASE");
            endcase
`ifdef SYNTHESIS
            tick(1);
            if((fault_kind==1 || fault_kind==2 || fault_kind==7 || fault_kind==8) ?
               !config_fault : !protocol_fault) $fatal(1,"FAULT_NOT_STICKY");
            req_valid=1; req_len=0; req_size=2; rsp_ready=1; b_ready=1;
            repeat(7) begin
                tick(1);
                if(req_ready || rsp_valid || b_valid || m_arvalid || m_awvalid ||
                   m_wvalid || m_rready || m_bready || w_ready)
                    $fatal(1,"FAULT_FAKE_COMPLETION");
            end
            reset_dut();
            $display("TEST_PASS ENGINE_FAULT_HARDWARE data=%0d case=%0d",DATA_ENGINE,fault_kind);
            $finish;
`else
            tick(3); $fatal(1,"EXPECTED_ENGINE_FATAL_MISSING");
`endif
        end
    endtask

    initial begin
        if(!$value$plusargs("SEED=%d",seed)) seed=1;
        unused=$value$plusargs("FAULT=%d",fault_kind);
        rng=seed;
        reset_dut();
        if(fault_kind!=0) fault_test();
        coordinated_reset_phases();
        read_one(10,0,7,0,0);
        read_one(0,31,7,2,1);
        read_one(31,0,31,3,15);
        if(DATA_ENGINE) begin
            write_one(0,5,0,7,0,0,1);
            write_one(5,0,1,7,0,0,2);
            write_one(0,5,0,7,1,2,3);
            write_one(31,31,31,31,0,3,15);
        end
        for(i=0;i<32;i=i+1) begin
            read_one(delay32(),delay32(),delay32(),i%4,i%16);
            if(DATA_ENGINE) write_one(delay32(),delay32(),delay32(),delay32(),0,i%4,i%16);
        end
        tick(8);
        if(ar_count!=r_count || r_count!=rsp_count || aw_count!=w_count ||
           w_count!=b_count || b_count!=done_count || req_count!=rsp_count+done_count ||
           protocol_fault || config_fault)
            $fatal(1,"FINAL_COUNTS");
        $display("TEST_PASS ENGINE data=%0d seed=%0d AR=%0d R=%0d AW=%0d W=%0d B=%0d",
                 DATA_ENGINE,seed,ar_count,r_count,aw_count,w_count,b_count);
        $finish;
    end
    initial begin #2000000; $fatal(1,"ENGINE_TIMEOUT seed=%0d",seed); end
endmodule

module engine_stability #(parameter W=32)(
    input wire clk,rst_n,valid,ready, input wire [W-1:0] payload
);
    reg blocked=0;
    reg [W-1:0] saved;
    always @(posedge clk) begin
        if(!rst_n) blocked<=0;
        else begin
            if(blocked && (valid!==1 || payload!==saved))
                $fatal(1,"ENGINE_CHANNEL_CHANGED_WHILE_BLOCKED");
            blocked<=valid && !ready;
            saved<=payload;
        end
    end
endmodule

module tb_axi_read_engine;
    engine_test #(0) test();
endmodule
