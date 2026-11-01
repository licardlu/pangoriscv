`timescale 1ns/1ps
module tb_native_arbiter;
    reg clk=0,rstn=0;
    always #5 clk=~clk;
    reg [55:0] s_awaddr={28'h200,28'h100},s_araddr={28'h400,28'h300};
    reg [7:0] s_awlen={4'd0,4'd3},s_arlen={4'd0,4'd3};
    reg [7:0] s_awid=8'h10,s_arid=8'h10;
    reg [1:0] s_awvalid=0,s_arvalid=0;
    wire [1:0] s_awready,s_arready,s_wready,s_wlast,s_rvalid,s_rlast;
    reg [511:0] s_wdata={{8{32'h2222}},{8{32'h1111}}};
    reg [63:0] s_wstrb=64'hffffffffffffffff;
    wire [255:0] s_rdata;
    wire [3:0] s_rid;
    wire [27:0] m_awaddr,m_araddr;
    wire [3:0] m_awlen,m_arlen,m_awid,m_arid;
    wire m_awvalid,m_arvalid;
    reg m_awready=1,m_arready=1,m_wready=0,m_wlast=0;
    wire [255:0] m_wdata;
    wire [31:0] m_wstrb;
    reg [255:0] m_rdata=0;
    reg m_rvalid=0,m_rlast=0;
    reg [3:0] m_rid=0;
    ddr_native_arbiter dut(.*);
    integer wremaining=0,rremaining=0,wa=0,ra=0,w0=0,w1=0,r0=0,r1=0;
    reg [3:0] rid_hold;
    always @(posedge clk) if(rstn) begin
        if(s_awvalid[0] && s_awready[0]) s_awvalid[0]<=0;
        if(s_awvalid[1] && s_awready[1]) s_awvalid[1]<=0;
        if(s_arvalid[0] && s_arready[0]) s_arvalid[0]<=0;
        if(s_arvalid[1] && s_arready[1]) s_arvalid[1]<=0;
        if(m_awvalid && m_awready) begin
            if(wremaining) $fatal(1,"write owner changed inside burst");
            wremaining<=m_awlen+1;wa<=wa+1;
        end else if(wremaining) wremaining<=wremaining-1;
        m_wready<=wremaining>0;
        m_wlast<=wremaining==1;
        if(m_arvalid && m_arready) begin
            if(rremaining) $fatal(1,"read owner changed inside burst");
            rremaining<=m_arlen+1;rid_hold<=m_arid;ra<=ra+1;
        end else if(rremaining) rremaining<=rremaining-1;
        m_rvalid<=rremaining>0;m_rlast<=rremaining==1;m_rid<=rid_hold;
        if(s_wready[0]) begin
            if(m_wdata[31:0]!=32'h1111) $fatal(1,"write data routing 0");
            w0<=w0+1;
        end
        if(s_wready[1]) begin
            if(m_wdata[31:0]!=32'h2222) $fatal(1,"write data routing 1");
            w1<=w1+1;
        end
        if(s_rvalid[0]) begin
            if(s_rid!=0) $fatal(1,"read ID 0");r0<=r0+1;
        end
        if(s_rvalid[1]) begin
            if(s_rid!=1) $fatal(1,"read ID 1");r1<=r1+1;
        end
    end
    initial begin
        repeat(4) @(negedge clk);rstn=1;s_awvalid=3;s_arvalid=3;
        wait(wa==2 && ra==2 && w1==1 && r1==1);
        repeat(10) @(negedge clk);
        if(w0!=4 || w1!=1 || r0!=4 || r1!=1) $fatal(1,"burst counts");
        $display("NATIVE_ARBITER_PASS whole-burst ownership, both clients, IDs");
        $finish;
    end
    initial begin repeat(500) @(posedge clk);$fatal(1,"arbiter timeout");end
endmodule
