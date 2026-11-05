`timescale 1ns/1ps
module tb_cdc_path;
    reg clk=0, dclk=0, rstn=0;
    always #5 clk=~clk;
    always #7 dclk=~dclk;
    reg [27:0] awaddr=0, araddr=0;
    reg awvalid=0, wvalid=0, arvalid=0, rready=0;
    wire awready,wready,arready,rvalid,rlast,wlast;
    reg [255:0] wdata=0;
    wire [255:0] rdata;
    wire reqvalid,reqfull,reqwrite,rspvalid,rspread,rsprdy;
    wire [31:0] reqaddr,reqstrb;
    wire [255:0] reqdata,rspdata;
    wire [27:0] dawaddr,daraddr;
    wire [3:0] dawlen,darlen;
    wire dawvalid,dwvalid,darvalid,drready;
    reg dawready=0,dwready=0,darready=0,dlast=0,drvalid=0;
    wire [255:0] dwdata;
    wire [31:0] dwstrb;
    reg [255:0] drdata=0;
    bridge_to_cdc glue(
        .clk(clk),.rstn(rstn),.br_awaddr(awaddr),.br_awvalid(awvalid),
        .br_awready(awready),.br_wdata(wdata),.br_wstrb(32'hffffffff),
        .br_wvalid(wvalid),.br_wready(wready),.br_wusero_last(wlast),
        .br_araddr(araddr),.br_arvalid(arvalid),.br_arready(arready),
        .br_rdata(rdata),.br_rvalid(rvalid),.br_rlast(rlast),.br_rready(rready),
        .c_req_valid(reqvalid),.c_req_full(reqfull),.c_req_write(reqwrite),
        .c_req_addr(reqaddr),.c_req_wdata(reqdata),.c_req_wstrb(reqstrb),
        .c_rsp_valid(rspvalid),.c_rsp_ready(rsprdy),.c_rsp_rdata(rspdata),
        .c_rsp_is_read(rspread));
    axi_cdc #(.DEPTH(4),.AW(2)) cdc(
        .clk_a(clk),.arst_n(rstn),.clk_b(dclk),.brst_n(rstn),
        .a_req_valid(reqvalid),.a_req_full(reqfull),.a_req_write(reqwrite),
        .a_req_addr(reqaddr),.a_req_wdata(reqdata),.a_req_wstrb(reqstrb),
        .a_rsp_valid(rspvalid),.a_rsp_ready(rsprdy),.a_rsp_rdata(rspdata),
        .a_rsp_is_read(rspread),.b_awaddr(dawaddr),.b_awlen(dawlen),
        .b_awvalid(dawvalid),.b_awready(dawready),.b_wdata(dwdata),
        .b_wstrb(dwstrb),.b_wvalid(dwvalid),.b_wready(dwready),
        .b_wusero_last(dlast),.b_araddr(daraddr),.b_arlen(darlen),
        .b_arvalid(darvalid),.b_arready(darready),.b_rdata(drdata),
        .b_rvalid(drvalid),.b_rlast(drvalid),.b_rready(drready));
    integer tick=0, writes=0, reads=0, responses=0, read_responses=0;
    reg gotaw=0,gotw=0,rdpending=0;
    reg [31:0] rdvalue;
    always @(posedge dclk) begin
        if(!rstn) begin
            tick<=0; dawready<=0; dwready<=0; darready<=0;
            dlast<=0;drvalid<=0;gotaw<=0;gotw<=0;rdpending<=0;
        end else begin
            tick<=tick+1;
            dawready<=!gotaw && tick%3==0;
            dwready<=!gotw && tick%3==1;
            darready<=!rdpending && !drvalid;
            dlast<=0;drvalid<=0; drdata<={8{32'hdeadbeef}};
            if(dawvalid && dawready) begin
                if(gotaw) $fatal(1,"duplicate native AW");
                gotaw<=1;
            end
            if(dwvalid && dwready) begin
                if(gotw) $fatal(1,"duplicate native W");
                gotw<=1;
            end
            if(gotaw && gotw) begin
                gotaw<=0;gotw<=0;dlast<=1;writes<=writes+1;
            end
            if(darvalid && darready) begin
                rdvalue<=daraddr;rdpending<=1;reads<=reads+1;
            end
            if(rdpending) begin
                drdata<={8{rdvalue}};drvalid<=1;rdpending<=0;
            end
        end
    end
    always @(posedge clk) if(rstn) begin
        if(wlast) responses<=responses+1;
        if(rvalid && rready) begin
            if(rdata!=={8{32'h1000+read_responses*8}} || !rlast)
                $fatal(1,"read %0d data %h",read_responses,rdata[31:0]);
            read_responses<=read_responses+1;
        end
    end
    task write_one(input integer index);
        begin
            @(negedge clk);awaddr=index*8;awvalid=1;
            do @(posedge clk); while(!awready);
            @(negedge clk);awvalid=0;
            repeat(index%3) @(negedge clk);
            wdata=index;wvalid=1;
            do @(posedge clk); while(!wready);
            @(negedge clk);wvalid=0;
        end
    endtask
    task read_one(input integer index);
        begin
            @(negedge clk);araddr=32'h1000+index*8;arvalid=1;
            do @(posedge clk); while(!arready);
            @(negedge clk);arvalid=0;
        end
    endtask
    integer wi,ri;
    initial begin
        repeat(5) @(negedge clk);rstn=1;
        fork
            for(wi=0;wi<20;wi=wi+1) write_one(wi);
            for(ri=0;ri<20;ri=ri+1) read_one(ri);
            begin
                repeat(300) @(negedge clk);
                forever begin
                    rready=1;repeat(4) @(negedge clk);
                    rready=0;repeat(7) @(negedge clk);
                end
            end
            begin
                wait(responses==20 && read_responses==20);
                repeat(40) @(negedge clk);
                if(writes!=20 || reads!=20 || responses!=20 || read_responses!=20)
                    $fatal(1,"request or response duplication");
                $display("CDC_PATH_PASS 20 writes + 20 reads, stalls, async clocks");
                $finish;
            end
        join
    end
    initial begin
        repeat(20000) @(posedge clk);
        $fatal(1,"CDC path timeout w=%0d r=%0d wrsp=%0d rrsp=%0d",
               writes,reads,responses,read_responses);
    end
endmodule
