`timescale 1ns/1ps
module result_event_cdc_tb;
    parameter real S_HALF=6.734, D_HALF=18.519;
    reg sclk=0,dclk=0,srst=1,drst=1,event_in=0;
    reg [8:0] payload_in=0;
    wire overflow,event_out;
    wire [8:0] payload_out;
    integer sent=0,received=0,n;
    reg checking=1;
    reg [8:0] expected[0:255];
    result_event_cdc dut(.*);
    always #(S_HALF) sclk=~sclk;
    initial begin #3; forever #(D_HALF) dclk=~dclk; end
    always @(posedge dclk) begin
        #0.001;
        if(!drst && checking && event_out) begin
            if(received>=sent || payload_out!==expected[received])
                $fatal(1,"CDC lost, duplicated, reordered or tore payload: received=%0d sent=%0d value=%h",received,sent,payload_out);
            received=received+1;
        end
    end
    task send(input [8:0] data);
        begin
            @(negedge sclk);
            expected[sent]=data;sent=sent+1;
            payload_in=data;event_in=1;
            @(negedge sclk);event_in=0;
            // Input is free to change immediately; receiver must see held data.
            payload_in=~data;
        end
    endtask
    task settle;
        begin
            repeat(70) @(posedge sclk);
            repeat(70) @(posedge dclk);
            if(received!=sent || overflow)
                $fatal(1,"CDC delivery failed: %0d/%0d overflow=%b",received,sent,overflow);
        end
    endtask
    initial begin
        repeat(8) @(negedge sclk);srst=0;
        repeat(8) @(negedge dclk);drst=0;
        // All four class IDs, valid/invalid and changing upper payload bits.
        for(n=0;n<100;n=n+1) begin send((n*53)^9'h100);settle;end
        // Back-to-back pair exercises the pending slot.
        send(9'h100);send(9'h003);settle;
        checking=0;
        // Deliberately violate producer-rate contract: overflow must latch.
        @(negedge sclk);event_in=1;
        repeat(8) begin @(negedge sclk);payload_in=payload_in+1'b1;end
        event_in=0;
        if(!overflow) $fatal(1,"CDC overload silently dropped an event");
        srst=1;drst=1;
        repeat(8) @(negedge sclk);
        repeat(8) @(negedge dclk);
        sent=0;received=0;srst=0;drst=0;checking=1;
        settle;send(9'h102);settle;
        $display("TEST_PASS result_event_cdc asynchronous delivery, pending, overflow, reset");
        $finish;
    end
    initial begin #2000000; $fatal(1,"CDC timeout"); end
endmodule
