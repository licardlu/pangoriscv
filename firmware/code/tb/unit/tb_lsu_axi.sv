//=============================================================================
// pangoriscv - RV32IM processor core + native AXI4 SoC (Pango PG2L100H @ 27 MHz)
// Module : tb_lsu_axi             File : tb/unit/tb_lsu_axi.sv
// Rev    : 1.1 (phase-2 lsu_opt)  Date : 2026-10-18
// Author : pango_lpenghan
// Brief  : Unit test for the load/store unit AXI4 read and write transactions
//
// Rev 1.1 keeps every check of rev 1.0 (request ownership/backpressure, store
// lane encoding, response/completion stability, fault propagation, side-effect
// counts) and adapts the fixed timing to the phase-2 "launch on accept"
// protocol: the request (and the W data for a store) is now driven on the cycle
// the op is accepted, so the backpressure check is that no request/W appears
// while the downstream is not ready, and the ownership check samples the
// accepted cycle.
//=============================================================================

`timescale 1ns/1ps
module tb_lsu_axi;
    reg clk=0; always #5 clk=~clk;
    reg rst_n=0,op_valid=0,is_store=0,load_unsigned=0,done_ready=0;
    reg [31:0] address=0,store_value=32'h12345680,op_pc=0;
    reg [2:0] access_size=0;
    reg [4:0] op_rd=0;
    wire op_ready,done_valid,fault,idle;
    wire [31:0] load_value,fault_addr;
    wire eng_req_valid,eng_req_write,eng_w_valid,eng_w_last;
    wire [31:0] eng_req_addr,eng_w_data;
    wire [2:0] eng_req_size;
    wire [7:0] eng_req_len;
    wire [3:0] eng_req_id,eng_w_strb;
    reg eng_req_ready=0,eng_w_ready=0,eng_rsp_valid=0,eng_b_valid=0;
    wire eng_rsp_ready,eng_b_ready;
    reg [31:0] eng_rsp_data=32'h807fff01;
    reg [1:0] eng_rsp_resp=0,eng_b_resp=0;
    integer requests=0,writes=0,completions=0;
    lsu_axi dut(.*);
    always @(posedge clk) if(rst_n) begin
        if(eng_req_valid && eng_req_ready) requests++;
        if(eng_w_valid && eng_w_ready) writes++;
        if(done_valid && done_ready) completions++;
    end
    // present an op while the downstream is NOT ready: nothing may be issued
    task setup_op(input bit st,input [31:0] addr,input [2:0] sz,input bit uns);
        @(negedge clk); is_store=st; address=addr; access_size=sz;
        load_unsigned=uns; op_valid=1;
        repeat(5) begin
            @(negedge clk);
            if(op_ready || eng_req_valid || eng_w_valid || done_valid)
                $fatal(1,"op issued while downstream not ready");
        end
    endtask
    // downstream ready: request and (for a store) W must be accepted together
    task accept_op(input bit st,input [31:0] addr,input [2:0] sz,
                   input [31:0] data,input [3:0] strb);
        eng_req_ready=1; eng_w_ready=st;
        #1;
        if(!op_ready) $fatal(1,"op_ready low with downstream ready");
        if(!eng_req_valid || eng_req_addr!==addr || eng_req_size!==sz ||
           eng_req_write!==st || eng_req_len!==0 || eng_req_id!==1 || done_valid)
            $fatal(1,"request ownership at launch addr=%08x sz=%0d",addr,sz);
        if(st && (!eng_w_valid || eng_w_data!==data || eng_w_strb!==strb ||
                  !eng_w_last))
            $fatal(1,"store lanes at launch data=%08x strb=%b",eng_w_data,eng_w_strb);
        if(!st && eng_w_valid) $fatal(1,"load must not drive W");
        @(posedge clk); #1;
        if(eng_req_valid) $fatal(1,"request re-asserted after accept");
        if(eng_w_valid) $fatal(1,"W re-asserted after accept");
        @(negedge clk);
        op_valid=0; is_store=0; address=32'hdeadbeef; access_size=7;
        eng_req_ready=0; eng_w_ready=0;
    endtask
    task complete(input bit err,input [31:0] val,input [31:0] addr);
        wait(done_valid);
        repeat(4) begin
            @(negedge clk);
            if(!done_valid || fault!==err || load_value!==val || fault_addr!==addr ||
               op_ready || eng_req_valid || eng_w_valid)
                $fatal(1,"completion stability val=%08x expected=%08x",load_value,val);
        end
        done_ready=1; @(negedge clk); done_ready=0;
        if(!idle) $fatal(1,"completion not released");
    endtask
    task load_case(input [31:0] addr,input [2:0] sz,input bit uns,
                   input [1:0] resp,input [31:0] val);
        setup_op(0,addr,sz,uns); accept_op(0,addr,sz,0,0);
        repeat(3) begin
            @(negedge clk);
            if(done_valid || !eng_rsp_ready) $fatal(1,"load completed before R");
        end
        eng_rsp_resp=resp; eng_rsp_valid=1;
        @(negedge clk); eng_rsp_valid=0;
        complete(resp!=0,val,addr);
    endtask
    task store_case(input [31:0] addr,input [2:0] sz,input [3:0] strb,
                    input [31:0] data,input [1:0] resp);
        setup_op(1,addr,sz,0); accept_op(1,addr,sz,data,strb);
        repeat(3) begin
            @(negedge clk);
            if(done_valid || !eng_b_ready) $fatal(1,"store completed before B");
        end
        eng_b_resp=resp; eng_b_valid=1;
        @(negedge clk); eng_b_valid=0;
        complete(resp!=0,0,addr);
    endtask
    // unaligned/oversized access: accepted and faulted without any AXI request
    task bad_case(input bit st,input [31:0] addr,input [2:0] sz);
        @(negedge clk); is_store=st; address=addr; access_size=sz;
        load_unsigned=0; op_valid=1;
        #1;
        if(!op_ready) $fatal(1,"bad access not accepted");
        if(eng_req_valid || eng_w_valid) $fatal(1,"AXI request for a faulted access");
        @(posedge clk); #1;
        @(negedge clk); op_valid=0;
        complete(1,0,addr);
    endtask
    initial begin
        repeat(3) @(negedge clk); rst_n=1;
        load_case(2,0,0,0,32'h7f);
        load_case(3,0,0,0,32'hffffff80);
        load_case(3,0,1,0,32'h80);
        load_case(0,1,0,0,32'hffffff01);
        load_case(0,1,1,0,32'hff01);
        load_case(0,2,0,0,32'h807fff01);
        load_case(0,2,0,2,0);
        store_case(1,0,4'b0010,32'h34568000,0);
        store_case(2,1,4'b1100,32'h56800000,0);
        store_case(0,2,4'b1111,32'h12345680,2);
        bad_case(0,1,2);
        bad_case(1,1,1);
        bad_case(1,0,3);
        if(requests!=10 || writes!=3 || completions!=13)
            $fatal(1,"LSU side effect counts");
        $display("TEST_PASS LSU requests=%0d writes=%0d completions=%0d",
                 requests,writes,completions); $finish;
    end
    initial begin #30000; $fatal(1,"LSU timeout"); end
endmodule
