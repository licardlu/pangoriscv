//=============================================================================
// pangoriscv - RV32IM processor core + native AXI4 SoC (Pango PG2L100H @ 27 MHz)
// Module : tb_lsu_axi             File : tb/unit/tb_lsu_axi.sv
// Rev    : 1.0                    Date : 2026-10-13
// Author : pango_lpenghan
// Brief  : Unit test for the load/store unit AXI4 read and write transactions
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
        // P25: the store data accompanies the request, so count the W beat on the
        // accept edge instead of an eng_w_ready handshake in a later state.
        if(eng_req_valid && eng_req_ready && eng_req_write && eng_w_valid) writes++;
        if(done_valid && done_ready) completions++;
    end
    task launch(input bit st,input [31:0] addr,input [2:0] sz,input bit uns);
        @(negedge clk); is_store=st; address=addr; access_size=sz;
        load_unsigned=uns; op_valid=1;
        do @(posedge clk); while(!op_ready);
        @(negedge clk); op_valid=0; address=32'hdeadbeef; access_size=7;
    endtask
    task accept_request(input bit st,input [31:0] addr,input [2:0] sz);
        repeat(5) begin
            @(negedge clk);
            if(!eng_req_valid || eng_req_addr!==addr || eng_req_size!==sz ||
               eng_req_write!==st || eng_req_len!==0 || eng_req_id!==1 ||
               done_valid) $fatal(1,"request ownership/backpressure");
        end
        eng_req_ready=1; @(negedge clk); eng_req_ready=0;
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
        launch(0,addr,sz,uns); accept_request(0,addr,sz);
        repeat(20) @(negedge clk);
        if(done_valid || !eng_rsp_ready) $fatal(1,"load completed before R");
        eng_rsp_resp=resp; eng_rsp_valid=1;
        @(negedge clk); eng_rsp_valid=0;
        complete(resp!=0,val,addr);
    endtask
    // P25 contract: the store data is presented WITH the request, and the cache
    // answers on the accept edge because it can latch the data there.
    task store_case(input [31:0] addr,input [2:0] sz,input [3:0] strb,
                    input [31:0] data,input [1:0] resp);
        launch(1,addr,sz,0);
        repeat(3) begin
            @(negedge clk);
            if(!eng_req_valid || eng_req_addr!==addr || eng_req_size!==sz ||
               eng_req_write!==1'b1 || done_valid)
                $fatal(1,"store request ownership/backpressure");
            if(!eng_w_valid || eng_w_data!==data || eng_w_strb!==strb || !eng_w_last)
                $fatal(1,"store data must accompany the request");
        end
        if(!eng_b_ready) $fatal(1,"store must accept B on the accept edge");
        eng_req_ready=1; eng_b_valid=1; eng_b_resp=resp;
        @(negedge clk);
        eng_req_ready=0; eng_b_valid=0;
        complete(resp!=0,0,addr);
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
        for(integer k=0;k<3;k++) begin
            launch(k==1,k==2?0:1,k==2?3:2,0);
            complete(1,0,k==2?0:1);
        end
        if(requests!=10 || writes!=3 || completions!=13)
            $fatal(1,"LSU side effect counts");
        $display("TEST_PASS LSU requests=%0d writes=%0d completions=%0d",
                 requests,writes,completions); $finish;
    end
    initial begin #30000; $fatal(1,"LSU timeout"); end
endmodule
