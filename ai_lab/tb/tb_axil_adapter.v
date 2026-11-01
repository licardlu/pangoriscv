`timescale 1ns/1ps
module tb_axil_adapter;
    reg clk=0,rstn=0;
    always #5 clk=~clk;
    reg a_awvalid=0,a_wvalid=0,a_wlast=1,a_bready=0;
    wire a_awready,a_wready,a_bvalid;
    reg [31:0] a_awaddr=0,a_wdata=0;
    reg [7:0] a_awlen=0;
    reg [3:0] a_wstrb=15;
    wire [1:0] a_bresp;
    reg a_arvalid=0,a_rready=0;
    wire a_arready,a_rvalid,a_rlast;
    reg [31:0] a_araddr=0;
    reg [7:0] a_arlen=0;
    wire [31:0] a_rdata;
    wire [1:0] a_rresp;
    wire [7:0] s_awaddr,s_araddr;
    wire s_awvalid,s_wvalid,s_bready,s_arvalid,s_rready;
    wire [31:0] s_wdata;
    reg s_awready=0,s_wready=0,s_bvalid=0,s_arready=0,s_rvalid=0;
    reg [1:0] s_bresp=0,s_rresp=0;
    reg [31:0] s_rdata=0;
    axi4_to_axil dut(.*);
    integer tick=0,awcount=0,wcount=0,arcount=0;
    reg ah=0,wh=0;
    always @(posedge clk) if(rstn) begin
        tick<=tick+1;
        s_awready<=!ah && tick%4==0;
        s_wready<=!wh && tick%4==2;
        s_arready<=!s_rvalid && tick%3==0;
        if(s_awvalid && s_awready) begin
            if(s_awaddr!=8'h40) $fatal(1,"AW address");
            ah<=1;awcount<=awcount+1;
        end
        if(s_wvalid && s_wready) begin
            if(s_wdata!=32'h12345678) $fatal(1,"W data");
            wh<=1;wcount<=wcount+1;
        end
        if(ah && wh) s_bvalid<=1;
        if(s_bvalid && s_bready) begin s_bvalid<=0;ah<=0;wh<=0;end
        if(s_arvalid && s_arready) begin
            s_rvalid<=1;s_rdata<=32'h87654321;arcount<=arcount+1;
        end
        if(s_rvalid && s_rready) s_rvalid<=0;
    end
    task aw(input [7:0] length);
        begin
            @(negedge clk);a_awvalid=1;a_awaddr=32'h70000040;a_awlen=length;
            do @(posedge clk);while(!a_awready);
            @(negedge clk);a_awvalid=0;
        end
    endtask
    task w;
        begin
            @(negedge clk);a_wvalid=1;a_wdata=32'h12345678;
            do @(posedge clk);while(!a_wready);
            @(negedge clk);a_wvalid=0;
        end
    endtask
    task b(input [1:0] expected);
        begin
            wait(a_bvalid);
            repeat(5) begin
                @(negedge clk);
                if(!a_bvalid || a_bresp!=expected) $fatal(1,"B stall/response");
            end
            a_bready=1;@(negedge clk);a_bready=0;
        end
    endtask
    integer i;
    initial begin
        repeat(4) @(negedge clk);rstn=1;
        w();aw(0);b(0); // W before AW
        aw(0);w();b(0);
        a_wstrb=3;w();aw(0);b(2);a_wstrb=15;
        @(negedge clk);a_arvalid=1;a_araddr=32'h70000004;
        do @(posedge clk);while(!a_arready);
        @(negedge clk);a_arvalid=0;a_araddr=0;
        wait(a_rvalid);
        repeat(5) begin
            @(negedge clk);
            if(!a_rvalid || a_rdata!=32'h87654321 || !a_rlast)
                $fatal(1,"R stall");
        end
        a_rready=1;@(negedge clk);a_rready=0;
        if(awcount!=2 || wcount!=2 || arcount!=1) $fatal(1,"forward counts");
        @(negedge clk);a_arvalid=1;a_arlen=2;
        do @(posedge clk);while(!a_arready);
        @(negedge clk);a_arvalid=0;
        for(i=0;i<3;i=i+1) begin
            wait(a_rvalid);
            if(a_rresp!=2 || a_rlast!=(i==2)) $fatal(1,"burst reject");
            @(negedge clk);a_rready=1;@(negedge clk);a_rready=0;
        end
        if(arcount!=1) $fatal(1,"unsupported burst reached registers");
        $display("AXIL_ADAPTER_PASS independent channels, backpressure, rejects");
        $finish;
    end
    initial begin repeat(5000) @(posedge clk);$fatal(1,"adapter timeout");end
endmodule
