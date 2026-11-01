`timescale 1ns/1ps
module tb_predictor_hash;
  reg [31:0] pc;
  reg [11:0] history;
  wire [11:0] lookup_hash, learn_hash;
  reg [11:0] expected, reversed;
  integer i,j,k;
  extracted_hash dut(pc,history,lookup_hash,learn_hash);
  initial begin
    for(i=0;i<4096;i=i+1) begin
      pc=32'h80000000 | (i<<3);
      for(j=0;j<128;j=j+1) begin
        history=(j*37) & 4095;
        for(k=0;k<12;k=k+1) reversed[11-k]=pc[k+3];
        expected=reversed^(history&12'h3ff);
        #1;
        if(lookup_hash!==expected || learn_hash!==expected)
          $fatal(1,"hash mismatch pc=%08x hist=%03x lookup=%03x learn=%03x expected=%03x",pc,history,lookup_hash,learn_hash,expected);
      end
    end
    $display("TEST_PASS hash_contract 524288 vectors"); $finish;
  end
endmodule
