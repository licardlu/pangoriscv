`timescale 1ns/1ps
module tb_snapshot_stream;
    reg clk=0,rstn=0; always #4.15 clk=~clk;
    reg [7:0] araddr=0,awaddr=0;
    reg arvalid=0,rready=0,awvalid=0,wvalid=0;
    reg [31:0] wdata=0;
    wire arready,rvalid,awready,wready,bvalid;
    wire [31:0] rdata,vid_data,vid_wr_data;
    wire [7:0] vid_addr,vid_wr_addr;
    wire vid_en,vid_wr_en;
    conv_engine_axil #(.BANDW(64),.WBANK(64),.TRM(2)) acc(
        .clk(clk),.rstn(rstn),.s_araddr(araddr),.s_arvalid(arvalid),
        .s_arready(arready),.s_rdata(rdata),.s_rvalid(rvalid),.s_rready(rready),
        .s_awaddr(awaddr),.s_awvalid(awvalid),.s_awready(awready),
        .s_wdata(wdata),.s_wvalid(wvalid),.s_wready(wready),.s_bready(1'b1),.s_bvalid(bvalid),
        .m_arready(1'b0),.m_rvalid(1'b0),.m_rdata(64'b0),.m_rresp(2'b0),
        .m_awready(1'b0),.m_wready(1'b0),.m_bvalid(1'b0),.m_bresp(2'b0),
        .vid_rd_en(vid_en),.vid_rd_addr(vid_addr),.vid_rd_data(vid_data),
        .vid_wr_en(vid_wr_en),.vid_wr_addr(vid_wr_addr),.vid_wr_data(vid_wr_data));
    video_ai_frontend frontend(
        .cpu_clk(clk),.cpu_rstn(rstn),.rd_en(vid_en),.rd_addr(vid_addr),.rd_data(vid_data),
        .wr_en(vid_wr_en),.wr_addr(vid_wr_addr),.wr_data(vid_wr_data),
        .cam_clk(clk),.cam_rstn(rstn),.cam_vs(1'b0),.cam_de(1'b0),.cam_pixel(16'b0),
        .pix_clk(clk),.pix_rstn(rstn),.pix_vs(1'b0),.pix_de(1'b0),.pix_in(16'b0),.pix_out());
    function [31:0] normalized(input integer p);
        integer r,g,b;
        begin
            r=(p>>11)&31;g=(p>>5)&63;b=p&31;
            r=(r<<3)|(r>>2);g=(g<<2)|(g>>4);b=(b<<3)|(b>>2);
            normalized=((r*127+127)/255)|(((g*127+127)/255)<<8)|(((b*127+127)/255)<<16);
        end
    endfunction
    task address(input integer value);
        begin
            @(negedge clk);awaddr=8'h78;wdata=value;awvalid=1;wvalid=1;
            @(posedge clk);while(!awready || !wready) @(posedge clk);
            @(negedge clk);awvalid=0;wvalid=0;
            wait(bvalid);@(negedge clk);repeat(3) @(negedge clk);
        end
    endtask
    task read_pixel(input [7:0] regaddr,input [31:0] expected,input integer stalls);
        reg [31:0] saved;
        begin
            @(negedge clk);araddr=regaddr;arvalid=1;rready=0;
            @(posedge clk);while(!arready) @(posedge clk);
            @(negedge clk);arvalid=0;
            wait(rvalid);saved=rdata;
            if(saved!==expected) $fatal(1,"pixel mismatch addr=%h expected=%h actual=%h",regaddr,expected,saved);
            repeat(stalls) begin
                @(negedge clk);
                if(!rvalid || rdata!==saved) $fatal(1,"RDATA changed under backpressure");
            end
            rready=1;@(negedge clk);rready=0;
        end
    endtask
    integer i,p;
    initial begin
        // Exhaust the hardware LUT over the entire input domain.
        for(p=0;p<65536;p=p+1)
            if({8'b0,frontend.q5(p[4:0]),frontend.q6(p[10:5]),frontend.q5(p[15:11])}!==normalized(p))
                $fatal(1,"normalization mismatch %h",p);
        for(i=0;i<57600;i=i+1) frontend.capture.memory[i]=(i*7919+13)&65535;
        repeat(5) @(negedge clk);rstn=1;
        address(0);
        for(i=0;i<320;i=i+1) read_pixel(8'hbc,normalized((i*7919+13)&65535),i%5);
        if(frontend.snapshot_address!=320) $fatal(1,"stream skipped/duplicated pixels");
        address(51);
        read_pixel(8'h7c,(51*7919+13)&65535,3);
        read_pixel(8'h7c,(51*7919+13)&65535,0);
        if(frontend.snapshot_address!=51) $fatal(1,"legacy read advanced pointer");
        read_pixel(8'hbc,normalized((51*7919+13)&65535),4);
        address(57599);
        read_pixel(8'hbc,normalized((57599*7919+13)&65535),0);
        read_pixel(8'hbc,0,4);read_pixel(8'hbc,0,0);
        if(frontend.snapshot_address!=57600) $fatal(1,"stream wrapped past end");
        $display("SNAPSHOT_STREAM_PASS 65536 colors, AXI backpressure, sequential reads, legacy and boundary");
        $finish;
    end
    initial begin #1000000;$fatal(1,"stream test timeout");end
endmodule
