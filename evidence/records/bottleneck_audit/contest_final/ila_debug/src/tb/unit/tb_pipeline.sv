//=============================================================================
// pangoriscv - RV32IM processor core + native AXI4 SoC (Pango PG2L100H @ 27 MHz)
// Module : tb_pipeline            File : tb/unit/tb_pipeline.sv
// Rev    : 1.0                    Date : 2026-10-13
// Author : pango_lpenghan
// Brief  : Operation-interface CPU pipeline regression (N03_PIPELINE)
//=============================================================================

`timescale 1ns/1ps
module tb_pipeline;
    reg clk=0; always #5 clk=~clk;
    reg rst_n=0, fetch_valid=0, fetch_fault=0, halt_req=0;
    reg [31:0] fetch_pc=0, fetch_inst=0, fetch_predicted_next_pc=0;
    wire fetch_ready, redirect_valid, halted, op_valid, done_ready, halt_pending;
    wire [31:0] redirect_pc, arch_next_pc, request_pc, csr_mtvec;
    wire is_store, load_unsigned;
    wire [31:0] address, store_value, op_pc;
    wire [2:0] access_size;
    wire [4:0] op_rd;
    reg done_valid=0, fault=0, op_ready=1, trap_ready=1;
    reg [31:0] load_value=21, fault_addr=0;
    wire retire_fire, trap_fire, rd_valid;
    wire [63:0] retire_order;
    wire [31:0] retire_pc, retire_inst, wdata, trap_pc, trap_tval;
    wire [4:0] rd, trap_cause;
    reg [4:0] debug_addr=0; wire [31:0] debug_data;
    integer retired=0, traps=0, operations=0, stores=0, countdown=-1;
    integer expected_count=0, checked=0;
    reg [31:0] expected_pc[0:255], expected_inst[0:255], expected_value[0:255];
    reg [4:0] expected_rd[0:255];
    reg expected_write[0:255];
    integer expected_traps=0;
    integer redirect_traps=0, redirect_retires=0, redirect_resumes=0;
    reg [4:0] expected_cause=0;
    reg [31:0] expected_tval=0, expected_trap_pc=0;
    pangoriscv dut(
        .clk(clk),.rst_n(rst_n),.fetch_valid(fetch_valid),.fetch_ready(fetch_ready),
        .fetch_pc(fetch_pc),.fetch_inst(fetch_inst),.fetch_fault(fetch_fault),
        .fetch_fault_cause(5'd1),.fetch_fault_tval(fetch_pc),
        .fetch_predicted_next_pc(fetch_predicted_next_pc),.request_pc(request_pc),
        .redirect_valid(redirect_valid),.redirect_pc(redirect_pc),
        .halt_req(halt_req),.fetch_idle(1'b1),.data_idle(!done_valid && countdown<0),
        .halted(halted),.halt_pending(halt_pending),.arch_next_pc(arch_next_pc),
        .op_valid(op_valid),.op_ready(op_ready),.is_store(is_store),
        .address(address),.store_value(store_value),.access_size(access_size),
        .load_unsigned(load_unsigned),.op_pc(op_pc),.op_rd(op_rd),
        .done_valid(done_valid),.done_ready(done_ready),.load_value(load_value),
        .fault(fault),.fault_addr(fault_addr),.trap_ready(trap_ready),.trap_vector(32'h800),
        .irq_software(1'b0),.irq_timer(1'b0),.irq_external(1'b0),.csr_mtvec(csr_mtvec),
        .retire_fire(retire_fire),.retire_order(retire_order),.retire_pc(retire_pc),
        .retire_inst(retire_inst),.rd_valid(rd_valid),.rd(rd),.wdata(wdata),
        .trap_fire(trap_fire),.trap_pc(trap_pc),.trap_cause(trap_cause),
        .trap_tval(trap_tval),.debug_addr(debug_addr),.debug_data(debug_data));
    function [31:0] addi(input [4:0] d,s,input integer imm);
        addi={imm[11:0],s,3'b000,d,7'h13};
    endfunction
    function [31:0] rr(input [4:0] d,a,b,input [2:0] f,input [6:0] f7);
        rr={f7,b,a,f,d,7'h33};
    endfunction
    task expect_retire(input [31:0] pc,inst,input bit we,input [4:0] d,input [31:0] value);
        expected_pc[expected_count]=pc; expected_inst[expected_count]=inst;
        expected_write[expected_count]=we; expected_rd[expected_count]=d;
        expected_value[expected_count]=value; expected_count++;
    endtask
    task send(input [31:0] pc,inst);
        @(negedge clk); fetch_valid=1; fetch_pc=pc; fetch_inst=inst;
        fetch_predicted_next_pc=pc+4;
        do @(posedge clk); while(!fetch_ready);
        @(negedge clk); fetch_valid=0;
    endtask
    task insn(input [31:0] pc,inst,input bit we,input [4:0] d,input [31:0] value);
        expect_retire(pc,inst,we,d,value); send(pc,inst);
    endtask
    task drain;
        wait(checked==expected_count); repeat(3) @(negedge clk);
    endtask
    task expect_trap(input [31:0] pc,inst,input [4:0] cause,input [31:0] tval);
        drain(); expected_traps++; expected_cause=cause;
        expected_trap_pc=pc; expected_tval=tval;
        send(pc,inst); wait(traps==expected_traps); repeat(2) @(negedge clk);
    endtask
    always @(posedge clk) if(rst_n) begin
        if(trap_fire) begin
            // The core redirects through the architectural mtvec CSR rather than
            // the direct trap_vector input, so the expected target is whatever
            // software programmed into mtvec.
            if(!redirect_valid || redirect_pc!==csr_mtvec)
                $fatal(1,"trap redirect missing or wrong target");
            redirect_traps++;
        end else if(retire_fire && dut.actual_next_pc!=dut.epred) begin
            if(!redirect_valid || redirect_pc!==dut.actual_next_pc)
                $fatal(1,"retirement correction missing or wrong target");
            redirect_retires++;
        end else if(halted && !halt_req) begin
            if(!redirect_valid || redirect_pc!==arch_next_pc)
                $fatal(1,"resume redirect missing or wrong target");
            redirect_resumes++;
        end else if(redirect_valid) begin
            $fatal(1,"unexpected pipeline redirect");
        end
        if(op_valid && op_ready) begin
            if(countdown>=0 || done_valid) $fatal(1,"duplicate LSU issue");
            operations++; if(is_store) begin
                stores++;
                if(store_value!==21 || address!==4) $fatal(1,"load/store dependency");
            end
            countdown<=20;
        end
        if(countdown>0) countdown<=countdown-1;
        if(countdown==0) begin done_valid<=1; countdown<=-1; end
        if(done_valid && done_ready) done_valid<=0;
        if(retire_fire) begin
            $display("RETIRE order=%0d pc=%08x inst=%08x rd_valid=%b rd=%0d value=%08x mem_addr=%08x",
                retire_order,retire_pc,retire_inst,rd_valid,rd,wdata,address);
            if(checked>=expected_count) $fatal(1,"unexpected/duplicate retirement");
            if(retire_order!==checked || retire_pc!==expected_pc[checked] ||
                retire_inst!==expected_inst[checked] || rd_valid!==expected_write[checked])
                $fatal(1,"retire identity %0d",checked);
            if(rd_valid && (rd!==expected_rd[checked] || wdata!==expected_value[checked]))
                $fatal(1,"retire value %0d expected %08x got %08x",checked,expected_value[checked],wdata);
            checked++; retired++;
        end
        if(trap_fire) begin
            traps++;
            $display("TRAP pc=%08x cause=%0d tval=%08x",trap_pc,trap_cause,trap_tval);
            if(traps!==expected_traps || trap_pc!==expected_trap_pc ||
                trap_cause!==expected_cause || trap_tval!==expected_tval || rd_valid)
                $fatal(1,"trap identity");
        end
    end
    initial begin
        repeat(3) @(negedge clk); rst_n=1;
        insn(0,addi(1,0,5),1,1,5);
        insn(4,addi(2,1,3),1,2,8);
        insn(8,rr(3,1,2,0,0),1,3,13);
        insn(12,addi(0,0,99),0,0,0);
        insn(16,addi(4,0,1),1,4,1);
        insn(20,32'h00002503,1,10,21);
        insn(24,rr(11,10,10,0,0),1,11,42);
        insn(28,32'h00a02223,0,0,0);
        insn(32,addi(5,0,1),1,5,1);
        insn(36,addi(5,5,2),1,5,3);
        insn(40,addi(5,5,4),1,5,7);
        insn(44,rr(6,3,1,4,1),1,6,2);
        insn(48,addi(7,6,3),1,7,5);
        drain();
        // A taken branch retires while flushing a younger fault.
        expect_retire(52,32'h00000463,0,0,0);
        force dut.ex_done=0;
        send(52,32'h00000463);
        fetch_fault=1;
        send(56,32'hffffffff);
        if(!dut.id_valid || !dut.ifault) $fatal(1,"young fault was not queued");
        fetch_fault=0;
        release dut.ex_done;
        drain();
        if(arch_next_pc!==60) $fatal(1,"branch architectural PC");
        insn(60,addi(8,0,257),1,8,257);
        insn(64,32'h000404e7,1,9,68); drain();
        if(arch_next_pc!==256) $fatal(1,"JALR bit zero");
        // Program mtvec the way software must; the reset value is zero and the
        // direct trap_vector port does not select the trap entry point.
        // lui x31,1 -> x31=0x1000 ; csrrw x0,mtvec,x31 -> mtvec=0x1000.
        insn(236,32'h00001fb7,1,31,32'h1000);
        insn(240,32'h305f9073,0,0,0); drain();
        if(csr_mtvec!==32'h1000) $fatal(1,"mtvec was not programmed");
        insn(256,addi(8,0,258),1,8,258);
        expect_trap(260,32'h000404e7,0,258);
        debug_addr=9; #1; if(debug_data!==68) $fatal(1,"fault wrote link");
        insn(264,32'h00208163,0,0,0); // beq x1,x2,+2: not taken
        insn(268,32'h00109513,1,10,10);
        expect_trap(272,32'h02109513,2,32'h02109513);
        expect_trap(276,32'h00000001,2,1);
        expect_trap(280,32'h0000100f,2,32'h0000100f);
        expect_trap(284,32'h00202503,4,2);
        expect_trap(288,32'h00a02123,6,2);
        // Signed high products exercise the preserved multiply algorithm.
        insn(292,32'h800005b7,1,11,32'h80000000);
        insn(296,addi(12,0,-1),1,12,32'hffffffff);
        insn(300,rr(13,11,12,1,1),1,13,0);
        insn(304,rr(14,11,12,2,1),1,14,32'h80000000);
        insn(308,rr(15,11,12,3,1),1,15,32'h7fffffff);
        drain();
        // Halt while the divider owns EX; it must finish exactly once.
        insn(312,rr(16,3,1,4,1),1,16,2);
        wait(dut.ex_valid); @(negedge clk); halt_req=1;
        wait(halted); repeat(6) @(negedge clk);
        if(checked!==expected_count || arch_next_pc!==316) $fatal(1,"halt boundary");
        halt_req=0; repeat(3) @(negedge clk);
        insn(316,addi(17,16,1),1,17,3); drain();
        fetch_fault=1;
        expect_trap(320,32'h13,1,320);
        fetch_fault=0;
        // An unaccepted old load must remain stable and drain despite halt.
        op_ready=0;
        insn(324,32'h00002503,1,10,21);
        wait(op_valid); @(negedge clk); halt_req=1;
        repeat(6) begin
            @(negedge clk);
            if(!op_valid || address!==0 || op_pc!==324 ||
               op_rd!==10 || is_store || access_size!==2 ||
               done_ready || retire_fire) $fatal(1,"stalled operation changed");
        end
        op_ready=1;
        wait(halted); repeat(3) @(negedge clk);
        if(arch_next_pc!==328) $fatal(1,"halt did not drain load");
        halt_req=0; repeat(3) @(negedge clk);
        // Both bus error kinds hold EX and the response until trap acceptance.
        for(integer k=0;k<2;k++) begin
            drain(); trap_ready=0; fault=1; fault_addr=k?4:0;
            expected_traps++; expected_cause=k?7:5;
            expected_trap_pc=328+k*4; expected_tval=fault_addr;
            send(expected_trap_pc,k?32'h00a02223:32'h00002503);
            wait(done_valid);
            repeat(6) begin
                @(negedge clk);
                if(done_ready || retire_fire || rd_valid || trap_fire ||
                   trap_pc!==expected_trap_pc || trap_cause!==expected_cause ||
                   trap_tval!==expected_tval)
                    $fatal(1,"pending bus trap changed or committed");
            end
            trap_ready=1; wait(traps==expected_traps);
            @(negedge clk); fault=0;
        end
        repeat(4) @(negedge clk);
        if(operations!=5 || stores!=2 || traps!=9) $fatal(1,"side-effect counts");
        if(redirect_traps!=9 || redirect_retires!=2 || redirect_resumes!=2)
            $fatal(1,"redirect coverage counts");
        $display("TEST_PASS N03_PIPELINE retires=%0d traps=%0d operations=%0d",retired,traps,operations);
        $finish;
    end
    initial begin #30000; $fatal(1,"pipeline timeout"); end
endmodule
