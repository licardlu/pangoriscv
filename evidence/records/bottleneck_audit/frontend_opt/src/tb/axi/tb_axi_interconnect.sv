//=============================================================================
// pangoriscv - RV32IM processor core + native AXI4 SoC (Pango PG2L100H @ 27 MHz)
// Module : tb_axi_interconnect    File : tb/axi/tb_axi_interconnect.sv
// Rev    : 1.0                    Date : 2026-10-13
// Author : pango_lpenghan
// Brief  : Directed testbench for the native AXI4 interconnect: address decode,
//          arbitration and ID tracking
//=============================================================================

`timescale 1ns/1ps
module tb_axi_interconnect;
    reg clk=0; always #5 clk=~clk;
    reg rst_n=0;
    reg [1:0] m_arvalid=0,m_awvalid=0,m_wvalid=0,m_rready=0,m_bready=0;
    wire [1:0] m_arready,m_awready,m_wready,m_rvalid,m_rlast,m_bvalid;
    reg [63:0] m_araddr=0,m_awaddr=0,m_wdata=0;
    reg [7:0] m_arid=8'h10,m_awid=8'h10,m_arcache=0,m_arqos=0,
              m_awcache=0,m_awqos=0,m_wstrb=8'hff;
    reg [15:0] m_arlen=0,m_awlen=0;
    reg [5:0] m_arsize={3'd2,3'd2},m_awsize={3'd2,3'd2},m_arprot=0,m_awprot=0;
    reg [3:0] m_arburst=4'b0101,m_awburst=4'b0101;
    reg [1:0] m_arlock=0,m_awlock=0,m_wlast=0;
    wire [63:0] m_rdata;
    wire [7:0] m_rid,m_bid;
    wire [3:0] m_rresp,m_bresp;
    wire [1:0] s_arvalid,s_awvalid,s_wvalid,s_arlock,s_awlock,s_wlast,s_rready,s_bready;
    wire [63:0] s_araddr,s_awaddr,s_wdata;
    wire [7:0] s_arid,s_awid,s_arcache,s_awcache,s_arqos,s_awqos,s_wstrb;
    wire [15:0] s_arlen,s_awlen;
    wire [5:0] s_arsize,s_awsize,s_arprot,s_awprot;
    wire [3:0] s_arburst,s_awburst;
    reg [1:0] s_arready=0,s_awready=0,s_wready=0,s_rvalid=0,s_rlast=0,s_bvalid=0;
    reg [63:0] s_rdata=0;
    reg [7:0] s_rid=0,s_bid=0;
    reg [3:0] s_rresp=0,s_bresp=0;
    wire protocol_fault;
    axi_interconnect dut(.*);
    integer seed=1,random_state,delay_override=0,stall_count=0;
    integer reads=0,writes=0,rbeats=0,wbeats=0,mutations=0,checks=0;
    integer mode=0; // 1: bad RID, 2: bad RLAST, 3: bad BID
    reg force_aw_wait_w=0,middle_error=0;
    reg [1:0] read_busy=0,aw_saved=0,write_complete=0;
    integer rd_count[0:1],rd_total[0:1],wr_count[0:1],wr_total[0:1];
    reg [31:0] rd_addr[0:1],wr_addr[0:1];
    reg [3:0] rd_id[0:1],wr_id[0:1];
    reg [31:0] memory[0:1][0:4095];
    reg [31:0] pending_data[0:1][0:255];
    reg [3:0] pending_strb[0:1][0:255];
    integer i,j,t,word_index;
    function integer random_wait;
        begin random_wait=($random(random_state)&32'h7fffffff)%4; end
    endfunction
    function [31:0] base;
        input integer port;
        begin base=port==0 ? 0 : 32'h10000000; end
    endfunction
    task fail;
        input [255:0] text;
        begin $display("TEST_FAIL %0s seed=%0d time=%0t",text,seed,$time); $fatal(1); end
    endtask
    task check;
        input condition; input [255:0] text;
        begin checks=checks+1; if(!condition) fail(text); end
    endtask
    // Registered VALID/payload are never altered before their handshake.
    always @(posedge clk) begin
        if(!rst_n) begin
            s_arready<=0; s_awready<=0; s_wready<=0;
            s_rvalid<=0; s_bvalid<=0; read_busy<=0; aw_saved<=0;
            write_complete<=0; stall_count<=0;
            for(t=0;t<2;t=t+1) begin rd_count[t]=0; wr_count[t]=0; end
        end else begin
            stall_count<=stall_count+1;
            for(t=0;t<2;t=t+1) begin
                s_arready[t]<=!read_busy[t] &&
                    (delay_override==0 ? random_wait()==0 : stall_count>=delay_override);
                s_awready[t]<=!aw_saved[t] &&
                    (force_aw_wait_w ? s_wvalid[t] :
                     (delay_override==0 ? random_wait()==0 : stall_count>=delay_override));
                s_wready[t]<=!write_complete[t] && random_wait()==0;
                if(s_arvalid[t] && s_arready[t]) begin
                    check(!read_busy[t],"duplicate AR");
                    read_busy[t]<=1; rd_count[t]=0;
                    rd_total[t]=s_arlen[t*8+:8]+1;
                    rd_addr[t]=s_araddr[t*32+:32]; rd_id[t]=s_arid[t*4+:4];
                    reads=reads+1; s_arready[t]<=0;
                end
                if(s_rvalid[t] && s_rready[t]) begin
                    s_rvalid[t]<=0; rd_count[t]=rd_count[t]+1; rbeats=rbeats+1;
                    if(rd_count[t]==rd_total[t]) read_busy[t]<=0;
                end
                if(read_busy[t] && !s_rvalid[t] && random_wait()==0) begin
                    s_rvalid[t]<=1;
                    word_index=((rd_addr[t]-base(t))>>2)+rd_count[t];
                    s_rdata[t*32+:32]<=memory[t][word_index];
                    s_rid[t*4+:4]<=mode==1 ? rd_id[t]^4'h8 : rd_id[t];
                    s_rlast[t]<=mode==2 ? 1'b1 : rd_count[t]==rd_total[t]-1;
                    s_rresp[t*2+:2]<=middle_error && rd_count[t]==1 ? 2'b10 : 0;
                end
                if(s_awvalid[t] && s_awready[t]) begin
                    check(!aw_saved[t],"duplicate AW");
                    aw_saved[t]<=1; wr_addr[t]=s_awaddr[t*32+:32];
                    wr_id[t]=s_awid[t*4+:4]; wr_total[t]=s_awlen[t*8+:8]+1;
                    writes=writes+1; s_awready[t]<=0;
                end
                if(s_wvalid[t] && s_wready[t]) begin
                    pending_data[t][wr_count[t]]=s_wdata[t*32+:32];
                    pending_strb[t][wr_count[t]]=s_wstrb[t*4+:4];
                    wr_count[t]=wr_count[t]+1; wbeats=wbeats+1;
                    if(s_wlast[t]) write_complete[t]<=1;
                end
                if(aw_saved[t] && write_complete[t] && !s_bvalid[t] && random_wait()==0) begin
                    check(wr_count[t]==wr_total[t],"wrong write count");
                    for(i=0;i<wr_total[t];i=i+1) begin
                        word_index=((wr_addr[t]-base(t))>>2)+i;
                        for(j=0;j<4;j=j+1)
                            if(pending_strb[t][i][j])
                                memory[t][word_index][j*8+:8]=pending_data[t][i][j*8+:8];
                        mutations=mutations+1;
                    end
                    s_bvalid[t]<=1; s_bid[t*4+:4]<=mode==3 ? wr_id[t]^4'h8 : wr_id[t];
                    s_bresp[t*2+:2]<=0;
                end
                if(s_bvalid[t] && s_bready[t]) begin
                    s_bvalid[t]<=0; aw_saved[t]<=0; write_complete[t]<=0; wr_count[t]=0;
                end
            end
        end
    end
    task reset_bus;
        begin
            @(negedge clk); rst_n=0; m_arvalid=0; m_awvalid=0; m_wvalid=0;
            m_rready=0; m_bready=0;
            repeat(3) begin
                @(negedge clk);
                check(m_arready==0 && m_awready==0 && m_wready==0 &&
                      m_rvalid==0 && m_bvalid==0 && s_arvalid==0 &&
                      s_awvalid==0 && s_wvalid==0,"reset gating");
            end
            rst_n=1; repeat(2) @(negedge clk);
        end
    endtask
    task send_ar;
        input integer port; input [31:0] address; input integer beats;
        begin
            @(negedge clk); m_araddr[port*32+:32]=address;
            m_arlen[port*8+:8]=beats-1; m_arvalid[port]=1;
            do @(posedge clk); while(!m_arready[port]);
            @(negedge clk); m_arvalid[port]=0;
        end
    endtask
    task receive_read;
        input integer port; input [31:0] address; input integer beats;
        input integer error_access; input integer hold_cycles;
        integer n,target_port; reg [31:0] expected;
        begin
            repeat(hold_cycles) @(negedge clk);
            n=0;
            while(n<beats) begin
                @(negedge clk); m_rready[port]=random_wait()==0;
                @(posedge clk);
                if(m_rvalid[port] && m_rready[port]) begin
                    check(m_rid[port*4+:4]==port,"read owner ID");
                    check(m_rlast[port]==(n==beats-1),"read last");
                    if(error_access) begin
                        check(m_rresp[port*2+:2]==3 && m_rdata[port*32+:32]==0,
                              "DECERR read");
                    end else begin
                        target_port=address>=32'h10000000;
                        expected=memory[target_port][((address-base(target_port))>>2)+n];
                        check(m_rdata[port*32+:32]==expected,"read value target");
                        check(m_rresp[port*2+:2]==(middle_error && n==1 ? 2 : 0),
                              "read response");
                    end
                    n=n+1;
                end
            end
            @(negedge clk); m_rready[port]=0;
        end
    endtask
    task send_aw;
        input integer port; input [31:0] address; input integer beats;
        begin
            @(negedge clk); m_awaddr[port*32+:32]=address;
            m_awlen[port*8+:8]=beats-1; m_awvalid[port]=1;
            do @(posedge clk); while(!m_awready[port]);
            @(negedge clk); m_awvalid[port]=0;
        end
    endtask
    task send_w;
        input integer port; input integer beats; input integer wait_cycles;
        integer n;
        begin
            repeat(wait_cycles) @(negedge clk);
            for(n=0;n<beats;n=n+1) begin
                @(negedge clk); m_wvalid[port]=1;
                m_wdata[port*32+:32]=32'habc00000+port*256+n;
                m_wlast[port]=n==beats-1;
                do @(posedge clk); while(!m_wready[port]);
                @(negedge clk); m_wvalid[port]=0;
                repeat(random_wait()) @(negedge clk);
            end
        end
    endtask
    task receive_b;
        input integer port; input integer error_access; input integer hold_cycles;
        begin
            repeat(hold_cycles) @(negedge clk);
            do begin
                @(negedge clk); m_bready[port]=random_wait()==0;
                @(posedge clk);
            end while(!(m_bvalid[port] && m_bready[port]));
            check(m_bid[port*4+:4]==port,"write owner ID");
            check(m_bresp[port*2+:2]==(error_access ? 3 : 0),"write response");
            @(negedge clk); m_bready[port]=0;
        end
    endtask
    task read_access;
        input integer port; input [31:0] address; input integer beats;
        input integer error_access;
        begin send_ar(port,address,beats); receive_read(port,address,beats,error_access,8); end
    endtask
    task write_access;
        input integer port; input [31:0] address; input integer beats;
        input integer error_access; input integer w_first;
        begin
            fork
                begin if(w_first) repeat(8) @(negedge clk); send_aw(port,address,beats); end
                send_w(port,beats,w_first ? 0 : 8);
            join
            receive_b(port,error_access,8);
        end
    endtask
    integer initial_mutations,initial_reads,initial_writes,iteration;
    reg [31:0] address;
    initial begin
        if(!$value$plusargs("SEED=%d",seed)) seed=1;
        random_state=seed;
        for(i=0;i<2;i=i+1)
            for(j=0;j<4096;j=j+1) memory[i][j]=32'h10000000+i*65536+j;
        reset_bus();
        // Four address candidates, with the first descriptor stalled for 20 clocks.
        delay_override=20; initial_reads=reads; initial_writes=writes;
        fork
            read_access(0,32'h20,8,0);
            write_access(1,32'h10000040,8,0,1);
        join
        check(reads==initial_reads+1 && writes==initial_writes+1,"contention exact count");
        delay_override=0;
        force_aw_wait_w=1;
        write_access(1,32'h10000080,1,0,0);
        force_aw_wait_w=0;
        read_access(0,32'h10000080,1,0);
        // A nonfinal SLVERR cannot release the read owner.
        middle_error=1;
        fork
            read_access(0,32'h40,8,0);
            begin repeat(8) @(negedge clk); write_access(1,32'h100000c0,1,0,0); end
        join
        middle_error=0;
        initial_mutations=mutations;
        write_access(1,32'h4000,1,1,0);
        write_access(1,32'h20000000,8,1,1);
        read_access(0,32'h10004000,1,1);
        read_access(1,32'h80000000,8,1);
        check(mutations==initial_mutations,"unmapped no mutation");
        for(iteration=0;iteration<16;iteration=iteration+1) begin
            address=(iteration%2 ? 32'h10000000 : 0)+32'h100+iteration*32;
            write_access(1,address,iteration%3==0 ? 8 : 1,0,iteration%2);
            read_access(iteration%2,address,iteration%3==0 ? 8 : 1,0);
        end
        check(!protocol_fault,"nominal protocol fault");
        // Malformed inputs must latch fault and must not fabricate completion.
        mode=1; send_ar(0,0,1);
        repeat(50) @(negedge clk);
        check(protocol_fault && m_rvalid==0 && m_bvalid==0,"bad RID fail closed");
        reset_bus(); mode=2; send_ar(0,0,8);
        repeat(50) @(negedge clk);
        check(protocol_fault && m_rvalid==0,"early RLAST fail closed");
        reset_bus(); mode=3;
        fork send_aw(1,32'h10000000,1); send_w(1,1,0); join
        repeat(60) @(negedge clk);
        check(protocol_fault && m_bvalid==0,"bad BID fail closed");
        reset_bus(); mode=0;
        send_aw(1,32'h10000000,8);
        @(negedge clk); m_wvalid[1]=1; m_wlast[1]=1;
        repeat(4) @(negedge clk);
        check(protocol_fault && m_bvalid==0 && m_wready==0,"early WLAST fail closed");
        reset_bus();
        read_access(0,32'h4000,8,1);
        check(!protocol_fault,"reset recovery");
        $display("TEST_PASS seed=%0d checks=%0d reads=%0d writes=%0d rbeats=%0d wbeats=%0d mutations=%0d",
                 seed,checks,reads,writes,rbeats,wbeats,mutations);
        $finish;
    end
    initial begin #2000000; fail("TIMEOUT"); end
endmodule
