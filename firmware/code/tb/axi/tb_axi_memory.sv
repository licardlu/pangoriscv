//=============================================================================
// pangoriscv - RV32IM processor core + native AXI4 SoC (Pango PG2L100H @ 27 MHz)
// Module : tb_axi_memory          File : tb/axi/tb_axi_memory.sv
// Rev    : 1.0                    Date : 2026-10-13
// Author : pango_lpenghan
// Brief  : Directed testbench for the AXI4 memory endpoint
//=============================================================================

`timescale 1ns/1ps
module tb_axi_memory;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst_n = 0;
    axi_bus bus(clk, rst_n);
    reg ar_gate = 1, aw_gate = 1, w_gate = 1;
    reg r_gate = 1, b_gate = 1, random_enable = 0;
    reg allow_r = 0, allow_b = 0;
    wire idle, monitor_idle;
    integer seed = 1, inject = 0, cycles = 0;
    integer writes = 0, reads = 0, expected_writes = 0, expected_reads = 0;
    integer first_aw_cycle = -1, first_w_cycle = -1;
    reg [31:0] master_rng = 1;
    reg [7:0] expected [0:4095];
    integer i;

    axi_memory_model memory(bus, ar_gate, aw_gate, w_gate, r_gate,
                            b_gate, random_enable, idle);
    axi_monitor monitor(bus, monitor_idle);

    always @(posedge clk) begin
        cycles <= cycles + 1;
        if (cycles > 100000)
            $fatal(1, "TIMEOUT seed=%0d", seed);
        if (rst_n && bus.bvalid && bus.bready) writes <= writes + 1;
        if (rst_n && bus.rvalid && bus.rready && bus.rlast) reads <= reads + 1;
        if (rst_n && bus.awvalid && bus.awready && first_aw_cycle < 0)
            first_aw_cycle = cycles;
        if (rst_n && bus.wvalid && bus.wready && first_w_cycle < 0)
            first_w_cycle = cycles;
    end

    always @(negedge clk) begin
        if (rst_n) begin
            master_rng <= {master_rng[30:0],
                master_rng[31]^master_rng[21]^master_rng[1]^master_rng[0]};
            bus.rready <= allow_r && (!random_enable || master_rng[0]);
            bus.bready <= allow_b && (!random_enable || master_rng[3]);
        end
    end

    task send_aw(input [31:0] addr, input integer beats,
                 input [2:0] size, input [3:0] id, input integer delay_cycles);
        begin
            repeat(delay_cycles) @(negedge clk);
            @(negedge clk);
            bus.awaddr = addr; bus.awlen = beats-1;
            bus.awsize = size; bus.awid = id; bus.awvalid = 1;
            do @(posedge clk); while (!bus.awready);
            @(negedge clk); bus.awvalid = 0;
        end
    endtask

    task send_w(input [31:0] addr, input integer beats, input [2:0] size,
                input [3:0] strobes, input integer delay_cycles);
        integer beat, lane, index;
        reg [31:0] data;
        begin
            repeat(delay_cycles) @(negedge clk);
            for (beat=0; beat<beats; beat=beat+1) begin
                if (beat > 0) repeat((beat+seed)%4) @(negedge clk);
                @(negedge clk);
                data = 32'h12345678 ^ (beat * 32'h01020408);
                bus.wdata = data; bus.wstrb = strobes;
                bus.wlast = (beat == beats-1); bus.wvalid = 1;
                do @(posedge clk); while (!bus.wready);
                index = ((addr - 32'h10000000) + (beat << size)) & 32'hfffffffc;
                if (addr >= 32'h10000000 && addr < 32'h10001000)
                    for (lane=0; lane<4; lane=lane+1)
                        if (strobes[lane]) expected[index+lane] = data[lane*8 +: 8];
                @(negedge clk); bus.wvalid = 0;
            end
        end
    endtask

    task write_case(input [31:0] addr, input integer beats, input [2:0] size,
                    input [3:0] strobes, input integer ordering, input [1:0] response);
        begin
            expected_writes = expected_writes + 1;
            first_aw_cycle = -1; first_w_cycle = -1;
            allow_b = 0;
            fork
                send_aw(addr, beats, size, 4'h1, ordering == 2 ? 5 : 0);
                send_w(addr, beats, size, strobes, ordering == 1 ? 5 : 0);
            join
            if (!random_enable) begin
                if ((ordering == 0 && first_aw_cycle != first_w_cycle) ||
                    (ordering == 1 && first_w_cycle-first_aw_cycle != 5) ||
                    (ordering == 2 && first_aw_cycle-first_w_cycle != 5))
                    $fatal(1,"AW_W_ORDER seed=%0d order=%0d aw=%0d w=%0d",
                           seed,ordering,first_aw_cycle,first_w_cycle);
            end
            wait(bus.bvalid);
            repeat(7) @(negedge clk);
            allow_b = 1;
            do @(posedge clk); while (!(bus.bvalid && bus.bready));
            if (bus.bresp !== response || bus.bid !== 4'h1)
                $fatal(1, "B_CHECK seed=%0d addr=%h expected=%h actual=%h id=%h",
                       seed, addr, response, bus.bresp, bus.bid);
            @(negedge clk); allow_b = 0;
            wait(idle && monitor_idle);
        end
    endtask

    task read_case(input [31:0] addr, input integer beats,
                   input [2:0] size, input [1:0] response);
        integer beat, lane, index;
        reg [31:0] wanted;
        begin
            expected_reads = expected_reads + 1;
            allow_r = 0;
            @(negedge clk);
            bus.araddr=addr; bus.arlen=beats-1; bus.arsize=size;
            bus.arid=4'h0; bus.arvalid=1;
            do @(posedge clk); while (!bus.arready);
            @(negedge clk); bus.arvalid=0;
            wait(bus.rvalid);
            repeat(7) @(negedge clk);
            allow_r=1;
            for (beat=0; beat<beats; beat=beat+1) begin
                do @(posedge clk); while (!(bus.rvalid && bus.rready));
                if (bus.rresp !== response || bus.rid !== 0 ||
                    bus.rlast !== (beat == beats-1))
                    $fatal(1,"R_METADATA seed=%0d addr=%h beat=%0d resp=%h last=%b",
                           seed,addr,beat,bus.rresp,bus.rlast);
                if (response == 0) begin
                    index = ((addr - 32'h10000000) + (beat << size)) & 32'hfffffffc;
                    wanted=0;
                    for(lane=0;lane<4;lane=lane+1)
                        wanted[lane*8 +: 8]=expected[index+lane];
                    if (bus.rdata !== wanted)
                        $fatal(1,"SCOREBOARD seed=%0d addr=%h beat=%0d expected=%h actual=%h",
                               seed,addr,beat,wanted,bus.rdata);
                end
            end
            @(negedge clk); allow_r=0;
            wait(idle && monitor_idle);
        end
    endtask

    initial begin
        if (!$value$plusargs("SEED=%d",seed)) seed=1;
        if (!$value$plusargs("INJECT=%d",inject)) inject=0;
        master_rng = seed;
        for(i=0;i<4096;i=i+1) expected[i]=0;
        bus.arvalid=0; bus.awvalid=0; bus.wvalid=0; bus.rready=0; bus.bready=0;
        bus.araddr=0; bus.arid=0; bus.arlen=0; bus.arsize=2; bus.arburst=1;
        bus.arlock=0; bus.arcache=0; bus.arprot=3; bus.arqos=0;
        bus.awaddr=0; bus.awid=1; bus.awlen=0; bus.awsize=2; bus.awburst=1;
        bus.awlock=0; bus.awcache=0; bus.awprot=3; bus.awqos=0;
        bus.wdata=0; bus.wstrb=0; bus.wlast=0;
        repeat(6) @(negedge clk);
        rst_n=1;
        if (inject != 0) begin
            ar_gate=0;
            @(negedge clk); bus.arvalid=1; bus.araddr=32'h10000000;
            repeat(2) @(negedge clk);
            bus.araddr=32'h10000004;
            repeat(3) @(negedge clk);
            $fatal(1,"INJECTION_NOT_DETECTED seed=%0d",seed);
        end
        write_case(32'h10000000,1,2,4'hf,0,0);
        read_case(32'h10000000,1,2,0);
        write_case(32'h10000004,1,2,4'hf,1,0);
        write_case(32'h10000008,1,2,4'hf,2,0);
        write_case(32'h10000001,1,0,4'h2,0,0);
        read_case(32'h10000001,1,0,0);
        write_case(32'h10000002,1,1,4'hc,0,0);
        read_case(32'h10000002,1,1,0);
        random_enable=1;
        write_case(32'h10000100,8,2,4'hf,1,0);
        read_case(32'h10000100,8,2,0);
        write_case(32'h10000100,8,2,4'h5,2,0);
        read_case(32'h10000100,8,2,0);
        write_case(32'h90000000,1,2,4'hf,0,3);
        read_case(32'h90000000,1,2,3);
        write_case(32'h90000040,8,2,4'hf,2,3);
        read_case(32'h90000040,8,2,3);
        fork
            write_case(32'h10000200,8,2,4'hf,0,0);
            read_case(32'h10000000,1,2,0);
        join
        read_case(32'h10000200,8,2,0);
        repeat(4) @(negedge clk);
        if (!idle || !monitor_idle || writes != expected_writes || reads != expected_reads)
            $fatal(1,"DRAIN seed=%0d writes=%0d/%0d reads=%0d/%0d",
                   seed,writes,expected_writes,reads,expected_reads);
        $display("TEST_PASS T01 seed=%0d writes=%0d reads=%0d cycles=%0d",
                 seed,writes,reads,cycles);
        $finish;
    end
endmodule
