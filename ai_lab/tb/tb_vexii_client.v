`timescale 1ns/1ps
module tb_vexii_client;
    reg clk=0,ddr_clk=0,rstn=0,ddr_rstn=0;
    always #5 clk=~clk;
    always #3.2 ddr_clk=~ddr_clk;
    wire [27:0] awaddr,araddr;
    wire [3:0] awlen,arlen;
    wire awvalid,arvalid,wvalid,rready;
    wire [255:0] wdata;
    wire [31:0] wstrb;
    wire video_write;
    wire [7:0] video_address;
    wire [31:0] video_data;
    reg [255:0] memory[0:31];
    reg write_active=0,rvalid=0,wlast=0;
    reg [27:0] write_address=0;
    reg [255:0] rdata=0;
    integer i,byte_index,reads=0,writes=0;
    wire awready=ddr_rstn && !write_active;
    wire wready=ddr_rstn && write_active;
    wire arready=ddr_rstn && !rvalid;

    yolo_ai_client dut(
        .clk_sys(clk),.core_clk(ddr_clk),.rstn(rstn),.ddr_rstn(ddr_rstn),
        .uart_rxd(1'b1),.uart_txd(),
        .vid_wr_en(video_write),.vid_wr_addr(video_address),
        .vid_wr_data(video_data),.vid_rd_addr(),.vid_rd_data(32'b0),
        .d3_awaddr(awaddr),.d3_awlen(awlen),.d3_awvalid(awvalid),
        .d3_awready(awready),.d3_wdata(wdata),.d3_wstrb(wstrb),
        .d3_wvalid(wvalid),.d3_wready(wready),.d3_wusero_last(wlast),
        .d3_araddr(araddr),.d3_arlen(arlen),.d3_arvalid(arvalid),
        .d3_arready(arready),.d3_rdata(rdata),.d3_rvalid(rvalid),
        .d3_rlast(rvalid),.d3_rready(rready));

    always @(posedge ddr_clk) begin
        if(!ddr_rstn) begin
            write_active<=0;rvalid<=0;wlast<=0;
        end else begin
            wlast<=0;
            if(awvalid && awready) begin
                if(awlen!=0 || awaddr[2:0] || awaddr>=256)
                    $fatal(1,"bad native write address %h",awaddr);
                write_address<=awaddr;write_active<=1;
            end
            if(wvalid && wready) begin
                for(byte_index=0;byte_index<32;byte_index=byte_index+1)
                    if(wstrb[byte_index])
                        memory[write_address>>3][byte_index*8+:8]<=wdata[byte_index*8+:8];
                writes<=writes+1;write_active<=0;wlast<=1;
            end
            if(arvalid && arready) begin
                if(arlen!=0 || araddr[2:0] || araddr>=256)
                    $fatal(1,"bad native read address %h",araddr);
                rdata<=memory[araddr>>3];rvalid<=1;reads<=reads+1;
            end else if(rvalid && rready) rvalid<=0;
        end
    end

    always @(posedge clk) if(rstn && video_write && video_address==8'hfc) begin
        if(video_data!=32'h600d || writes!=1 || reads<5)
            $fatal(1,"client check failed marker=%h reads=%0d writes=%0d",
                   video_data,reads,writes);
        if(memory[24][63:0]!==64'h0c0b0a0908070605 ||
           memory[24][255:64]!=={24{8'ha5}})
            $fatal(1,"native memory or byte strobes mismatch %h",memory[24]);
        $display("VEXII_CLIENT_PASS CPU/conv/64-to-256/async CDC/native DDR/write strobes");
        $finish;
    end

    initial begin
        for(i=0;i<32;i=i+1) memory[i]=0;
        memory[0][63:0]=64'h0807060504030201;
        for(i=0;i<8;i=i+1) memory[8+i/4][(i%4)*64+:64]=1;
        for(i=0;i<4;i=i+1) begin
            memory[16+i/4][(i%4)*64+:64]={32'(2*i+5),32'(2*i+4)};
            memory[17+i/4][(i%4)*64+:64]=64'h0000800000008000;
        end
        memory[24]={32{8'ha5}};
        repeat(180) @(negedge clk);
        ddr_rstn=1;
        repeat(5) @(negedge clk);
        rstn=1;
    end
    initial begin
        #2000000;
        $fatal(1,"Vexii client timeout reads=%0d writes=%0d",reads,writes);
    end
endmodule
