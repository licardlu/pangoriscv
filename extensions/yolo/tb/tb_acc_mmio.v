`timescale 1ns/1ps
module tb_acc_mmio;
    reg clk=0, rstn=0;
    always #5 clk=~clk;
    reg [7:0] awaddr=0, araddr=0;
    reg awvalid=0, wvalid=0, bready=0, arvalid=0, rready=0;
    reg [31:0] wdata=0;
    wire awready,wready,bvalid,arready,rvalid;
    wire [1:0] bresp,rresp;
    wire [31:0] rdata;
    wire [31:0] ma,wa;
    wire av,rr,wav,wv,wl,br;
    wire [7:0] al,wal;
    wire [63:0] wd;
    reg arv=0, wrv=0, bv=0;
    reg [63:0] mem=0;
    reg [63:0] incoming=0;
    reg got_a=0,got_w=0;
    integer writes=0, delay_b=0;
    wire [4:0] dbg;
    wire anom;
    wire [31:0] snap;
    conv_engine_axil #(.BANDW(64),.WBANK(64),.TRM(2)) dut(
        .clk(clk),.rstn(rstn),
        .s_awaddr(awaddr),.s_awvalid(awvalid),.s_awready(awready),
        .s_wdata(wdata),.s_wvalid(wvalid),.s_wready(wready),
        .s_bresp(bresp),.s_bvalid(bvalid),.s_bready(bready),
        .s_araddr(araddr),.s_arvalid(arvalid),.s_arready(arready),
        .s_rdata(rdata),.s_rresp(rresp),.s_rvalid(rvalid),.s_rready(rready),
        .m_araddr(ma),.m_arvalid(av),.m_arready(1'b1),.m_arlen(al),
        .m_rdata(mem),.m_rvalid(arv),.m_rready(rr),.m_rresp(2'b00),
        .m_awaddr(wa),.m_awvalid(wav),.m_awready(1'b1),.m_awlen(wal),
        .m_wdata(wd),.m_wvalid(wv),.m_wlast(wl),.m_wready(1'b1),
        .m_bresp(2'b00),.m_bvalid(bv),.m_bready(br),
        .dbg_st(dbg),.dbg_anom(anom),.dbg_snap(snap));
    always @(posedge clk) begin
        if (av) begin
            if(ma!==32'h100) $fatal(1,"wrong host read byte address %h",ma);
            arv<=1;
        end
        if(arv && rr) arv<=0;
        if(wav) begin
            if(wa!==32'h100) $fatal(1,"wrong host write byte address %h",wa);
            got_a<=1;
        end
        if(wv) begin got_w<=1; incoming<=wd; end
        if(got_a && got_w && delay_b==0 && !bv) begin
            writes<=writes+1;
            mem<=incoming;
            got_a<=0; got_w<=0; delay_b<=5;
        end
        if(delay_b>0) begin
            delay_b<=delay_b-1;
            if(delay_b==1) bv<=1;
        end
        if(bv && br) bv<=0;
    end
    task write_reg;
        input [7:0] addr;
        input [31:0] value;
        input integer data_first;
        begin
            @(negedge clk);
            if(data_first!=0) begin
                wdata=value; wvalid=1;
                do @(posedge clk); while(!wready);
                @(negedge clk); wvalid=0;
                repeat(2) @(negedge clk);
                awaddr=addr; awvalid=1;
                do @(posedge clk); while(!awready);
                @(negedge clk); awvalid=0;
            end else begin
                awaddr=addr; awvalid=1;
                do @(posedge clk); while(!awready);
                @(negedge clk); awvalid=0;
                repeat(2) @(negedge clk);
                wdata=value; wvalid=1;
                do @(posedge clk); while(!wready);
                @(negedge clk); wvalid=0;
            end
            bready=1;
            do @(posedge clk); while(!bvalid);
            if(bresp!=0) $fatal(1,"MMIO response error");
            @(negedge clk); bready=0;
        end
    endtask
    task read_reg;
        input [7:0] addr;
        output [31:0] value;
        begin
            @(negedge clk); araddr=addr; arvalid=1;
            do @(posedge clk); while(!arready);
            @(negedge clk); arvalid=0;
            wait(rvalid);
            value=rdata;
            repeat(3) begin
                @(negedge clk);
                if(!rvalid || rdata!==value) $fatal(1,"read changed under backpressure");
            end
            rready=1; @(posedge clk); @(negedge clk); rready=0;
        end
    endtask
    reg [31:0] value;
    initial begin
        repeat(5) @(negedge clk); rstn=1;
        write_reg(8'h54,32'h100,1);
        write_reg(8'h58,32'h01234567,0);
        write_reg(8'h5c,32'h89abcdef,1);
        repeat(40) @(negedge clk);
        if(writes!=1 || mem!==64'h89abcdef01234567)
            $fatal(1,"load repeated or lost writes=%0d mem=%h",writes,mem);
        write_reg(8'h60,32'h100,0);
        write_reg(8'h64,1,1);
        repeat(20) @(negedge clk);
        read_reg(8'h68,value);
        if(value!==32'h01234567) $fatal(1,"DDR read low got=%h",value);
        read_reg(8'h6c,value);
        if(value!==32'h89abcdef) $fatal(1,"DDR read high");
        $display("MMIO_PASS independent AW/W, one-shot load, DDR readback, R backpressure");
        $finish;
    end
    initial begin #200000; $fatal(1,"MMIO timeout"); end
endmodule
