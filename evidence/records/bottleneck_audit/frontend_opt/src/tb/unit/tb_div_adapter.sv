//=============================================================================
// pangoriscv - RV32IM processor core + native AXI4 SoC (Pango PG2L100H @ 27 MHz)
// Module : tb_div_adapter         File : tb/unit/tb_div_adapter.sv
// Rev    : 1.0                    Date : 2026-10-13
// Author : pango_lpenghan
// Brief  : Unit test for the divider handshake adapter (start/done sequencing)
//=============================================================================

`timescale 1ns/1ps
module tb_div_adapter;
    reg clk=0,rst_n=0,qv=0,rr=0;
    reg [31:0] a=0,b=0;
    reg [2:0] op=0;
    wire qr,rv; wire [31:0] data;
    integer req_count=0,rsp_count=0;
    always @(posedge clk) begin
        if(rst_n && qv && qr) req_count=req_count+1;
        if(rst_n && rv && rr) rsp_count=rsp_count+1;
    end
    always #5 clk=~clk;
    div_adapter dut(.clk(clk),.rst_n(rst_n),.req_valid(qv),.req_ready(qr),
        .dividend(a),.divisor(b),.op(op),.rsp_valid(rv),.rsp_ready(rr),.rsp_data(data));
    task check_div(input [31:0] x,y,input [2:0] fn,input [31:0] expected);
        integer n,requests_before,responses_before;
        begin
            requests_before=req_count; responses_before=rsp_count;
            @(negedge clk); a=x;b=y;op=fn;qv=1;
            if(qr!==1) $fatal(1,"request not ready");
            @(posedge clk); #1;
            if(qr!==0) $fatal(1,"request accepted twice");
            @(negedge clk); a=32'h12345678;b=7;op=3'b111;
            n=0;
            while(rv!==1 && n<100) begin @(posedge clk);#1;n=n+1;end
            if(rv!==1 || data!==expected) $fatal(1,"bad division");
            repeat(7) begin
                @(posedge clk);#1;
                if(rv!==1 || data!==expected || qr!==0) $fatal(1,"lost result");
            end
            if(req_count!==requests_before+1) $fatal(1,"repeated request acceptance");
            @(negedge clk);qv=0;rr=1;
            @(posedge clk);#1;
            @(negedge clk);rr=0;
            repeat(3) begin @(posedge clk);#1;if(rv!==0) $fatal(1,"duplicate result");end
            if(req_count!==requests_before+1 || rsp_count!==responses_before+1)
                $fatal(1,"division handshake count");
        end
    endtask
    task check_immediate_response;
        integer n,requests_before,responses_before;
        begin
            requests_before=req_count; responses_before=rsp_count;
            @(negedge clk);a=100;b=4;op=3'b101;qv=1;rr=1;
            @(posedge clk);#1;
            @(negedge clk);qv=0;
            n=0;
            while(rv!==1 && n<100) begin @(posedge clk);#1;n=n+1;end
            if(rv!==1 || data!==25) $fatal(1,"immediate response value");
            @(posedge clk);#1;
            if(rv!==0 || rsp_count!==responses_before+1 ||
               req_count!==requests_before+1) $fatal(1,"immediate response count");
            repeat(5) begin @(posedge clk);#1;
                if(rv!==0 || rsp_count!==responses_before+1) $fatal(1,"immediate duplicate");
            end
            @(negedge clk);rr=0;
        end
    endtask
    task check_reset_cancel(input held_response);
        integer n,requests_before,responses_before;
        begin
            requests_before=req_count; responses_before=rsp_count;
            @(negedge clk);a=123;b=7;op=3'b100;qv=1;rr=0;
            @(posedge clk);#1;
            @(negedge clk);qv=0;
            if(held_response) begin
                n=0;
                while(rv!==1 && n<100) begin @(posedge clk);#1;n=n+1;end
                if(rv!==1 || data!==17) $fatal(1,"reset held response missing");
                repeat(3) begin @(posedge clk);#1;
                    if(rv!==1 || data!==17) $fatal(1,"reset held response lost");
                end
            end else begin
                repeat(3) begin @(posedge clk);#1;end
                if(rv!==0 || qr!==0) $fatal(1,"reset target not active");
            end
            @(negedge clk);rst_n=0;rr=1;
            #1;if(qr!==0 || rv!==0) $fatal(1,"reset handshake visible");
            repeat(2) begin @(posedge clk);#1;
                if(data!==0 || rv!==0) $fatal(1,"reset failed to clear response");
            end
            @(negedge clk);rst_n=1;
            repeat(45) begin @(posedge clk);#1;
                if(rv!==0 || qr!==1) $fatal(1,"stale response after reset");
            end
            if(req_count!==requests_before+1 || rsp_count!==responses_before)
                $fatal(1,"reset cancellation handshake count");
            @(negedge clk);rr=0;
            check_div(33,4,3'b101,8);
        end
    endtask
    initial begin #200000;$fatal(1,"TIMEOUT DIV");end
    initial begin
        repeat(5) @(posedge clk);
        #1;
        if(qr!==0 || rv!==0 || data!==0) $fatal(1,"reset state");
        @(negedge clk);rst_n=1;
        check_div(20,3,3'b100,6);
        check_div(32'hFFFFFFEC,3,3'b100,32'hFFFFFFFA);
        check_div(32'hFFFFFFEC,3,3'b110,32'hFFFFFFFE);
        check_div(32'hFFFFFFFF,2,3'b101,32'h7FFFFFFF);
        check_div(32'hFFFFFFFF,2,3'b111,1);
        check_div(9,0,3'b100,32'hFFFFFFFF);
        check_div(9,0,3'b110,9);
        check_div(32'h80000000,32'hFFFFFFFF,3'b100,32'h80000000);
        check_div(32'h80000000,32'hFFFFFFFF,3'b110,0);
        check_immediate_response();
        check_reset_cancel(0);
        check_reset_cancel(1);
        if(req_count!==14 || rsp_count!==12) $fatal(1,"total handshake count");
        $display("TEST_PASS N03_DIV");$finish;
    end
endmodule
