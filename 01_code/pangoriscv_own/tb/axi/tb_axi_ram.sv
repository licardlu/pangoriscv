//=============================================================================
// pangoriscv - RV32IM processor core + native AXI4 SoC (Pango PG2L100H @ 27 MHz)
// Module : tb_axi_ram             File : tb/axi/tb_axi_ram.sv
// Rev    : 1.0                    Date : 2026-10-13
// Author : pango_lpenghan
// Brief  : Directed testbench for the on-chip AXI4 data RAM slave (axi_ram)
//=============================================================================

`timescale 1ns/1ps
module tb_axi_ram;
    reg clk=0; always #5 clk=~clk;
    reg rst_n=0;
    reg s_arvalid=0,s_awvalid=0,s_wvalid=0,s_rready=0,s_bready=0;
    wire s_arready,s_awready,s_wready,s_rvalid,s_bvalid,s_rlast;
    reg [31:0] s_araddr=0,s_awaddr=0,s_wdata=0;
    reg [3:0] s_arid=0,s_awid=0,s_wstrb=0;
    reg [7:0] s_arlen=0,s_awlen=0;
    reg [2:0] s_arsize=2,s_awsize=2;
    reg [1:0] s_arburst=1,s_awburst=1;
    reg s_arlock=0,s_awlock=0,s_wlast=1;
    reg [3:0] s_arcache=0,s_awcache=0,s_arqos=0,s_awqos=0;
    reg [2:0] s_arprot=0,s_awprot=0;
    wire [31:0] s_rdata;
    wire [3:0] s_rid,s_bid;
    wire [1:0] s_rresp,s_bresp;
    wire protocol_fault;
    axi_ram #(.INIT_FILE("ram_init.hex")) dut(.*);
    integer seed,random_state,n,ar_count=0,aw_count=0,w_count=0,r_count=0,b_count=0;
    integer write_count=0;
    reg [31:0] model[0:4095];
    function integer delay_cycles;
        delay_cycles=$urandom(random_state)%8;
    endfunction
    reg ar_stall=0,aw_stall=0,w_stall=0,r_stall=0,b_stall=0;
    reg [60:0] ar_old,aw_old;
    reg [36:0] w_old;
    reg [38:0] r_old;
    reg [5:0] b_old;
    // Every payload bit, including sidebands, must survive channel stalls.
    always @(posedge clk) begin
        if(!rst_n) begin
            ar_stall<=0; aw_stall<=0; w_stall<=0; r_stall<=0; b_stall<=0;
        end else begin
            if(s_rvalid && s_bvalid) $fatal(1,"read/write response overlap");
            if(ar_stall && (!s_arvalid ||
                {s_araddr,s_arid,s_arlen,s_arsize,s_arburst,s_arlock,
                 s_arcache,s_arprot,s_arqos}!==ar_old)) $fatal(1,"AR stability");
            if(aw_stall && (!s_awvalid ||
                {s_awaddr,s_awid,s_awlen,s_awsize,s_awburst,s_awlock,
                 s_awcache,s_awprot,s_awqos}!==aw_old)) $fatal(1,"AW stability");
            if(w_stall && (!s_wvalid || {s_wdata,s_wstrb,s_wlast}!==w_old))
                $fatal(1,"W stability");
            if(r_stall && (!s_rvalid || {s_rdata,s_rid,s_rresp,s_rlast}!==r_old))
                $fatal(1,"R stability");
            if(b_stall && (!s_bvalid || {s_bid,s_bresp}!==b_old))
                $fatal(1,"B stability");
            ar_stall<=s_arvalid&&!s_arready; aw_stall<=s_awvalid&&!s_awready;
            w_stall<=s_wvalid&&!s_wready; r_stall<=s_rvalid&&!s_rready;
            b_stall<=s_bvalid&&!s_bready;
            ar_old<={s_araddr,s_arid,s_arlen,s_arsize,s_arburst,s_arlock,
                     s_arcache,s_arprot,s_arqos};
            aw_old<={s_awaddr,s_awid,s_awlen,s_awsize,s_awburst,s_awlock,
                     s_awcache,s_awprot,s_awqos};
            w_old<={s_wdata,s_wstrb,s_wlast}; r_old<={s_rdata,s_rid,s_rresp,s_rlast};
            b_old<={s_bid,s_bresp};
            if(s_arvalid&&s_arready) ar_count++;
            if(s_awvalid&&s_awready) aw_count++;
            if(s_wvalid&&s_wready) w_count++;
            if(s_rvalid&&s_rready) r_count++;
            if(s_bvalid&&s_bready) b_count++;
            if(dut.write_event) write_count++;
        end
    end
    task send_aw;
        @(negedge clk); s_awvalid=1;
        do @(posedge clk); while(!s_awready);
        @(negedge clk); s_awvalid=0;
    endtask
    task send_w;
        @(negedge clk); s_wvalid=1;
        do @(posedge clk); while(!s_wready);
        @(negedge clk); s_wvalid=0;
    endtask
    task write_case(input [31:0] addr,input [2:0] size,input [31:0] data,
                    input [3:0] strb,input integer order,input [1:0] resp);
        integer before_w;
        begin
            before_w=write_count;
            @(negedge clk);
            s_awaddr=addr; s_awsize=size; s_wdata=data; s_wstrb=strb;
            s_awid=$urandom(random_state); s_bready=0;
            case(order)
                0: begin
                    send_aw();
                    repeat(5+delay_cycles()) @(negedge clk);
                    if(s_bvalid || write_count!=before_w) $fatal(1,"AW-only side effect");
                    send_w();
                end
                1: begin
                    send_w();
                    repeat(5+delay_cycles()) @(negedge clk);
                    if(s_bvalid || write_count!=before_w) $fatal(1,"W-only side effect");
                    send_aw();
                end
                default: fork send_aw(); send_w(); join
            endcase
            wait(s_bvalid);
            repeat(4+delay_cycles()) @(negedge clk);
            if(s_bresp!==resp || s_bid!==s_awid) $fatal(1,"B response");
            if(write_count!=before_w+(resp==0?1:0)) $fatal(1,"write event count");
            s_bready=1; @(negedge clk); s_bready=0;
            if(resp==0) begin
                for(integer lane=0;lane<4;lane++)
                    if(strb[lane]) model[(addr-32'h10000000)>>2][8*lane+:8]=data[8*lane+:8];
            end
            s_awlen=0; s_awburst=1; s_awlock=0; s_wlast=1;
        end
    endtask
    task read_case(input [31:0] addr,input [2:0] size,input [1:0] resp);
        begin
            @(negedge clk); s_araddr=addr; s_arsize=size;
            s_arid=$urandom(random_state); s_arvalid=1; s_rready=0;
            do @(posedge clk); while(!s_arready);
            @(negedge clk); s_arvalid=0;
            if(s_rvalid) $fatal(1,"read must be synchronous");
            wait(s_rvalid);
            repeat(4+delay_cycles()) @(negedge clk);
            if(s_rid!==s_arid || s_rresp!==resp || !s_rlast) $fatal(1,"R response");
            if(resp==0 && s_rdata!==model[(addr-32'h10000000)>>2])
                $fatal(1,"R data addr=%08x got=%08x expected=%08x",
                       addr,s_rdata,model[(addr-32'h10000000)>>2]);
            if(resp!=0 && s_rdata!==0) $fatal(1,"error leaked memory");
            s_rready=1; @(negedge clk); s_rready=0;
            s_arlen=0; s_arburst=1; s_arlock=0;
        end
    endtask
    initial begin
        if(!$value$plusargs("SEED=%d",seed)) seed=1;
        random_state=seed;
        for(integer k=0;k<4096;k++) model[k]=0;
        model[0]=32'h13579bdf; model[4095]=32'h2468ace0;
        repeat(3) @(negedge clk); rst_n=1;
        read_case(32'h10000000,2,0); read_case(32'h10003ffc,2,0);
        write_case(32'h10000000,2,32'h12345678,15,0,0);
        write_case(32'h10003ffc,2,32'habcdef98,15,1,0);
        read_case(32'h10000000,2,0); read_case(32'h10003ffc,2,0);
        // All input channels asserted during a held read must remain owned.
        @(negedge clk); s_araddr=32'h10000000; s_arsize=2; s_arvalid=1;
        do @(posedge clk); while(!s_arready);
        @(negedge clk); s_arvalid=0;
        wait(s_rvalid); @(negedge clk);
        s_araddr=32'h10003ffc; s_arid=3; s_arvalid=1;
        s_awaddr=32'h10000004; s_awid=4; s_awsize=2; s_awvalid=1;
        s_wdata=32'hfedcba98; s_wstrb=15; s_wlast=1; s_wvalid=1;
        repeat(7) begin
            @(negedge clk);
            if(s_arready || s_awready || s_wready) $fatal(1,"busy admission");
        end
        s_rready=1; @(negedge clk); s_rready=0;
        do @(posedge clk); while(!(s_arready && s_awready && s_wready));
        @(negedge clk); s_arvalid=0; s_awvalid=0; s_wvalid=0;
        wait(s_bvalid); repeat(5) @(negedge clk);
        if(s_bid!==4 || s_bresp!==0) $fatal(1,"queued write response");
        s_bready=1; @(negedge clk); s_bready=0;
        model[1]=32'hfedcba98;
        wait(s_rvalid); repeat(5) @(negedge clk);
        if(s_rid!==3 || s_rresp!==0 || s_rdata!==model[4095])
            $fatal(1,"queued read response");
        s_rready=1; @(negedge clk); s_rready=0;
        for(integer offset=0;offset<4;offset++) begin
            write_case(32'h10000000+offset,0,32'hffffffff,1<<offset,offset%3,0);
            read_case(32'h10000000+offset,0,0);
        end
        for(integer offset=0;offset<4;offset+=2) begin
            write_case(32'h10000000+offset,1,32'h89abcdef,3<<offset,offset,0);
            read_case(32'h10000000+offset,1,0);
        end
        for(integer k=0;k<60;k++) begin
            n=$urandom(random_state)%64;
            write_case(32'h10000000+4*n,2,$urandom(random_state),15,k%3,0);
            read_case(32'h10000000+4*n,2,0);
        end
        // Full address validation: above/below range and high-bit aliases.
        write_case(32'h10004000,2,0,15,0,2);
        write_case(32'h00000000,2,0,15,1,2);
        write_case(32'h20000000,2,0,15,2,2);
        write_case(32'h0ffffffc,2,0,15,0,2);
        read_case(32'h10004000,2,2); read_case(32'h00000000,2,2);
        read_case(32'h20000000,2,2); read_case(32'h0ffffffc,2,2);
        write_case(32'h10000001,2,0,15,1,2);
        write_case(32'h10000001,1,0,6,2,2);
        write_case(32'h10000000,3,0,15,0,2);
        write_case(32'h10000001,0,0,1,1,2);
        s_awburst=0; write_case(32'h10000000,2,0,15,0,2);
        s_awburst=2; write_case(32'h10000000,2,0,15,1,2);
        s_awlock=1; write_case(32'h10000000,2,0,15,2,2);
        read_case(32'h10000001,2,2); read_case(32'h10000001,1,2);
        read_case(32'h10000000,3,2);
        s_arburst=0; read_case(32'h10000000,2,2);
        s_arburst=2; read_case(32'h10000000,2,2);
        s_arlock=1; read_case(32'h10000000,2,2);
        // the caches change: an INCR read burst of up to eight beats is a supported
        // access now (the instruction cache refills 32 B lines with ARLEN=7), so
        // a known eight-word line is written first and then read back as one
        // burst: every beat must carry the written word and a true last signal.
        // ARBURST/ARLOCK are restored first: the negative cases above leave them
        // at WRAP/locked on purpose.
        s_arburst=1; s_arlock=0;
        for(integer w=0;w<8;w++) write_case(32'h10000000+4*w,2,32'hc0de0000+w,15,0,0);
        @(negedge clk); s_araddr=32'h10000000; s_arsize=2; s_arlen=7;
        s_arid=9; s_arvalid=1;
        do @(posedge clk); while(!s_arready);
        @(negedge clk); s_arvalid=0;
        for(integer beat=0;beat<8;beat++) begin
            wait(s_rvalid);
            repeat(3) @(negedge clk);
            if(s_rresp!==0 || s_rid!==9 || s_rlast!==(beat==7) || s_rdata!==(32'hc0de0000+beat))
                $fatal(1,"supported read burst framing beat=%0d resp=%0d id=%0d last=%0d data=%08x",
                       beat,s_rresp,s_rid,s_rlast,s_rdata);
            s_rready=1; @(negedge clk); s_rready=0;
        end
        // More than eight beats stays a framed error that still consumes the
        // descriptor's full beat count and never mutates memory.
        @(negedge clk); s_araddr=32'h10000000; s_arsize=2; s_arlen=8;
        s_arid=11; s_arvalid=1;
        do @(posedge clk); while(!s_arready);
        @(negedge clk); s_arvalid=0;
        for(integer beat=0;beat<9;beat++) begin
            wait(s_rvalid);
            repeat(3) @(negedge clk);
            if(s_rresp!==2 || s_rid!==11 || s_rlast!==(beat==8) || s_rdata!==0)
                $fatal(1,"over-long read burst framing");
            s_rready=1; @(negedge clk); s_rready=0;
        end
        s_arlen=0;
        @(negedge clk); s_awaddr=32'h10000000; s_awsize=2; s_awlen=3;
        s_awid=10; s_wdata=0; s_wstrb=15; s_wlast=0;
        send_w(); repeat(5) @(negedge clk);
        if(s_bvalid) $fatal(1,"burst W-first premature B");
        send_aw();
        for(integer beat=1;beat<4;beat++) begin
            s_wlast=(beat==3); send_w();
            if(beat<3 && s_bvalid) $fatal(1,"burst premature B");
        end
        wait(s_bvalid); repeat(4) @(negedge clk);
        if(s_bresp!==2 || s_bid!==10) $fatal(1,"unsupported write burst B");
        s_bready=1; @(negedge clk); s_bready=0; s_awlen=0;
        // Zero-strobe single beat succeeds without a RAM mutation event.
        n=write_count;
        @(negedge clk); s_awaddr=32'h10000000; s_awsize=2; s_wlast=1; s_wstrb=0;
        fork send_aw(); send_w(); join
        wait(s_bvalid); repeat(3) @(negedge clk);
        if(s_bresp!==0 || write_count!=n) $fatal(1,"zero strobe");
        s_bready=1; @(negedge clk); s_bready=0;
        read_case(32'h10000000,2,0); read_case(32'h10003ffc,2,0);
        // Coordinated endpoint reset clears channel ownership, not RAM contents.
        @(negedge clk); rst_n=0;
        repeat(3) @(negedge clk); rst_n=1;
        read_case(32'h10000000,2,0); read_case(32'h10003ffc,2,0);
        // ar_count counts descriptors, r_count counts beats: the 8-beat and the
        // 9-beat read bursts above contribute +7 and +8 beats respectively.
        if(ar_count+15!=r_count || aw_count!=b_count || w_count!=b_count+3)
            $fatal(1,"channel exactly-once counts");
        // Broken framing cannot produce a fake B or mutate memory.
        n=write_count;
        s_wlast=0; s_wstrb=15;
        fork send_aw(); send_w(); join
        repeat(10) @(negedge clk);
        if(!protocol_fault || s_bvalid || write_count!=n) $fatal(1,"WLAST fault");
        rst_n=0; repeat(3) @(negedge clk); rst_n=1; s_wlast=1;
        read_case(32'h10000000,2,0);
        $display("TEST_PASS RAM seed=%0d AR=%0d AW=%0d W=%0d R=%0d B=%0d writes=%0d",
                 seed,ar_count,aw_count,w_count,r_count,b_count,write_count);
        $finish;
    end
    initial begin #200000; $fatal(1,"RAM timeout"); end
endmodule
