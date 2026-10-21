`timescale 1ns/1ps
module tb_ifu_response_bypass;
 reg clk=0; always #5 clk=~clk;
 reg rst_n=0,enable=0,redirect_valid=0,fetch_ready=0,fetch_ready2=0;
 reg [31:0] fetch_pc=32'h20;
 wire [31:0] predicted_next_pc=fetch_pc+4;
 wire [31:0] chain_c,chain_c2;
 wire [31:0] chain_predict_next_pc=chain_c+4,chain_predict_next_pc2=chain_c2+4;
 wire fetch_valid,result_pair,result_fault,result_fault_hi,idle,flush_lost;
 wire [31:0] result_pc,result_inst,result_pc_hi,result_inst_hi;
 wire [31:0] result_predicted_next_pc,result_predicted_next_pc_hi;
 wire [31:0] result_fault_tval,result_fault_tval_hi;
 wire [4:0] result_fault_cause,result_fault_cause_hi;
 reg eng_req_ready=0,eng_rsp_valid=0,eng_rsp_pair=1;
 wire eng_req_valid,eng_rsp_ready;
 wire [31:0] eng_req_addr;
 wire [2:0] eng_req_size;
 wire [7:0] eng_req_len;
 wire [3:0] eng_req_id;
 reg [31:0] eng_rsp_data=0,eng_rsp_data_hi=0;
 reg [1:0] eng_rsp_resp=0;
 ifu_axi dut(.*);
 integer accepted=0,delivered=0;
 always @(posedge clk) if(rst_n) begin
   if(eng_req_valid && eng_req_ready) accepted<=accepted+1;
   if(fetch_valid && fetch_ready) delivered<=delivered+(fetch_ready2 && result_pair ? 2 : 1);
 end
 task request(input [31:0] pc);
   integer n;
   begin
     @(negedge clk); eng_req_ready=1; n=0;
     while(!eng_req_valid) begin @(negedge clk); n=n+1; if(n>20) $fatal(1,"request timeout"); end
     if(eng_req_addr!==pc) $fatal(1,"request pc got=%h want=%h",eng_req_addr,pc);
     @(negedge clk); eng_req_ready=0;
   end
 endtask
 task response(input [31:0] pc,input bit pair_word);
   begin
     eng_rsp_data=pc^32'h12340000; eng_rsp_data_hi=(pc+4)^32'h12340000;
     eng_rsp_pair=pair_word; eng_rsp_valid=1; #1;
   end
 endtask
 task redirect(input [31:0] pc);
   begin
     @(negedge clk); redirect_valid=1; fetch_pc=pc;
     @(negedge clk); redirect_valid=0;
   end
 endtask
 task check_word(input [31:0] pc);
   begin
     if(!fetch_valid || result_pc!==pc || result_inst!==(pc^32'h12340000))
       $fatal(1,"bad delivery valid=%b pc=%h inst=%h want=%h",fetch_valid,result_pc,result_inst,pc);
   end
 endtask
 initial begin
   repeat(3) @(negedge clk); rst_n=1; enable=1;
   // Both words can be consumed on the response edge, with no queue bubble.
   request('h20); fetch_ready=1; fetch_ready2=1; response('h20,1);
   check_word('h20);
   if(!result_pair || result_pc_hi!=='h24 || result_inst_hi!==('h24^32'h12340000)) $fatal(1,"pair payload");
   @(negedge clk); eng_rsp_valid=0; fetch_ready=0; fetch_ready2=0; fetch_pc='h28;
   // Accept word0 only; word1 must survive in the queue with its own PC.
   request('h28); fetch_ready=1; response('h28,1); check_word('h28);
   @(negedge clk); eng_rsp_valid=0; fetch_ready=0; fetch_pc='h2c; #1; check_word('h2c);
   repeat(3) begin @(negedge clk); check_word('h2c); end
   fetch_ready=1;
   @(negedge clk); fetch_ready=0; fetch_pc='h30;
   // Backpressure at the response edge must retain the entire pair.
   request('h30); response('h30,1); check_word('h30);
   @(negedge clk); eng_rsp_valid=0; #1; check_word('h30);
   fetch_ready=1; fetch_ready2=1;
   @(negedge clk); fetch_ready=0; fetch_ready2=0; fetch_pc='h38;
   // A flushed outstanding response cannot enter via the bypass.
   request('h38); redirect('h80); response('h38,1);
   if(fetch_valid) $fatal(1,"stale bypass escaped");
   @(negedge clk); eng_rsp_valid=0;
   request('h80); fetch_ready=1; response('h80,0); check_word('h80);
   @(negedge clk); eng_rsp_valid=0; fetch_ready=0; fetch_pc='h84;
   // A real response fault retains the fault PC and blocks speculative supply.
   request('h84); eng_rsp_resp=2; response('h84,0);
   if(!fetch_valid || !result_fault || result_fault_cause!==1 || result_fault_tval!=='h84)
     $fatal(1,"fault bypass metadata");
   @(negedge clk); eng_rsp_valid=0; eng_rsp_resp=0;
   if(!fetch_valid || !result_fault) $fatal(1,"backpressured fault lost");
   enable=0;
   repeat(3) @(negedge clk);
   if(!idle || flush_lost || accepted!=6 || delivered!=7) $fatal(1,"accounting accepted=%0d delivered=%0d",accepted,delivered);
   $display("TEST_PASS IFU_RESPONSE_BYPASS accepted=%0d delivered=%0d",accepted,delivered);
   $finish;
 end
 initial begin #20000; $fatal(1,"timeout"); end
endmodule
