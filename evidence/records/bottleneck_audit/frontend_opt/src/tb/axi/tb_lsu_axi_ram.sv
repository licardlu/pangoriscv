//=============================================================================
// pangoriscv - RV32IM processor core + native AXI4 SoC (Pango PG2L100H @ 27 MHz)
// Module : tb_lsu_axi_ram         File : tb/axi/tb_lsu_axi_ram.sv
// Rev    : 1.0                    Date : 2026-10-13
// Author : pango_lpenghan
// Brief  : Load/store unit to AXI RAM accept path: real transactions through the bus
//=============================================================================

`timescale 1ns/1ps
module tb_lsu_axi_ram;
    reg clk=0; always #5 clk=~clk;
    reg rst_n=0,op_valid=0,is_store=0,load_unsigned=0,done_ready=0;
    reg [31:0] address=0,store_value=0,op_pc=0;
    reg [2:0] access_size=0;
    reg [4:0] op_rd=0;
    wire op_ready,done_valid,fault,idle;
    wire [31:0] load_value,fault_addr;
    wire eng_req_valid,eng_req_ready,eng_req_write,eng_w_valid,eng_w_ready,eng_w_last;
    wire [31:0] eng_req_addr,eng_w_data,eng_rsp_data;
    wire [2:0] eng_req_size;
    wire [7:0] eng_req_len;
    wire [3:0] eng_req_id,eng_w_strb,eng_rsp_id,eng_b_id;
    wire eng_rsp_valid,eng_rsp_ready,eng_b_valid,eng_b_ready,eng_rsp_last;
    wire [1:0] eng_rsp_resp,eng_b_resp;
    wire protocol_fault,config_fault,ram_protocol_fault;
    wire arvalid,arready,awvalid,awready,wvalid,wready,rvalid,rready,bvalid,bready;
    wire [31:0] araddr,awaddr,wdata,rdata;
    wire [3:0] arid,awid,wstrb,rid,bid,arcache,awcache,arqos,awqos;
    wire [7:0] arlen,awlen;
    wire [2:0] arsize,awsize,arprot,awprot;
    wire [1:0] arburst,awburst,rresp,bresp;
    wire arlock,awlock,wlast,rlast;
    lsu_axi lsu(.*);
    axi_data_engine engine(
        .clk(clk),.rst_n(rst_n),
        .req_valid(eng_req_valid),.req_ready(eng_req_ready),.req_write(eng_req_write),
        .req_addr(eng_req_addr),.req_size(eng_req_size),.req_len(eng_req_len),.req_id(eng_req_id),
        .w_valid(eng_w_valid),.w_ready(eng_w_ready),.w_data(eng_w_data),
        .w_strb(eng_w_strb),.w_last(eng_w_last),
        .rsp_valid(eng_rsp_valid),.rsp_ready(eng_rsp_ready),.rsp_data(eng_rsp_data),
        .rsp_resp(eng_rsp_resp),.rsp_last(eng_rsp_last),.rsp_id(eng_rsp_id),
        .b_valid(eng_b_valid),.b_ready(eng_b_ready),.b_resp(eng_b_resp),.b_id(eng_b_id),
        .protocol_fault(protocol_fault),.config_fault(config_fault),
        .m_arvalid(arvalid),.m_arready(arready),.m_araddr(araddr),.m_arid(arid),
        .m_arlen(arlen),.m_arsize(arsize),.m_arburst(arburst),.m_arlock(arlock),
        .m_arcache(arcache),.m_arprot(arprot),.m_arqos(arqos),
        .m_awvalid(awvalid),.m_awready(awready),.m_awaddr(awaddr),.m_awid(awid),
        .m_awlen(awlen),.m_awsize(awsize),.m_awburst(awburst),.m_awlock(awlock),
        .m_awcache(awcache),.m_awprot(awprot),.m_awqos(awqos),
        .m_wvalid(wvalid),.m_wready(wready),.m_wdata(wdata),.m_wstrb(wstrb),.m_wlast(wlast),
        .m_rvalid(rvalid),.m_rready(rready),.m_rdata(rdata),.m_rid(rid),
        .m_rresp(rresp),.m_rlast(rlast),
        .m_bvalid(bvalid),.m_bready(bready),.m_bid(bid),.m_bresp(bresp));
    axi_ram #(.READ_DELAY(20),.WRITE_DELAY(30)) ram(
        .clk(clk),.rst_n(rst_n),.protocol_fault(ram_protocol_fault),
        .s_arvalid(arvalid),.s_arready(arready),.s_araddr(araddr),.s_arid(arid),
        .s_arlen(arlen),.s_arsize(arsize),.s_arburst(arburst),.s_arlock(arlock),
        .s_arcache(arcache),.s_arprot(arprot),.s_arqos(arqos),
        .s_awvalid(awvalid),.s_awready(awready),.s_awaddr(awaddr),.s_awid(awid),
        .s_awlen(awlen),.s_awsize(awsize),.s_awburst(awburst),.s_awlock(awlock),
        .s_awcache(awcache),.s_awprot(awprot),.s_awqos(awqos),
        .s_wvalid(wvalid),.s_wready(wready),.s_wdata(wdata),.s_wstrb(wstrb),.s_wlast(wlast),
        .s_rvalid(rvalid),.s_rready(rready),.s_rdata(rdata),.s_rid(rid),
        .s_rresp(rresp),.s_rlast(rlast),
        .s_bvalid(bvalid),.s_bready(bready),.s_bid(bid),.s_bresp(bresp));
    integer requests=0,aws=0,ws=0,bs=0,ars=0,rs=0,completions=0,writes=0;
    integer cycles=0,last_ar=0,last_aw=0,seed,random_state,bus_before;
    reg [31:0] add_model;
    always @(posedge clk) if(rst_n) begin
        cycles++;
        if(eng_req_valid&&eng_req_ready) requests++;
        if(arvalid&&arready) begin ars++; last_ar=cycles; end
        if(awvalid&&awready) begin aws++; last_aw=cycles; end
        if(wvalid&&wready) ws++;
        if(rvalid&&rready) begin
            rs++; if(cycles-last_ar<20) $fatal(1,"R latency missing");
        end
        if(bvalid&&bready) begin
            bs++; if(cycles-last_aw<30) $fatal(1,"B latency missing");
        end
        if(ram.write_event) writes++;
        if(done_valid&&done_ready) completions++;
        if(protocol_fault||config_fault||ram_protocol_fault) $fatal(1,"bus fault");
    end
    task operation(input bit st,input [31:0] addr,input [2:0] sz,
                   input bit uns,input [31:0] value,input bit err,input [31:0] expected);
        begin
            @(negedge clk);
            is_store=st; address=addr; access_size=sz; load_unsigned=uns;
            store_value=value; op_valid=1;
            do @(posedge clk); while(!op_ready);
            @(negedge clk); op_valid=0;
            address=32'hdeadbeef; access_size=7; store_value=32'habcdabcd;
            wait(done_valid);
            repeat(4+$urandom(random_state)%8) begin
                @(negedge clk);
                if(!done_valid || fault!==err || fault_addr!==addr ||
                   load_value!==expected || op_ready)
                    $fatal(1,"LSU completion addr=%08x val=%08x exp=%08x fault=%b",
                           addr,load_value,expected,fault);
            end
            done_ready=1; @(negedge clk); done_ready=0;
        end
    endtask
    initial begin
        if(!$value$plusargs("SEED=%d",seed)) seed=1;
        random_state=seed;
        repeat(3) @(negedge clk); rst_n=1;
        operation(1,32'h10000000,2,0,5,0,0);
        operation(0,32'h10000000,2,0,0,0,5);
        add_model=load_value+load_value;
        if(add_model!=10) $fatal(1,"software add model");
        operation(1,32'h10000001,0,0,32'hff,0,0);
        operation(0,32'h10000001,0,1,0,0,255);
        operation(0,32'h10000000,2,0,0,0,32'h0000ff05);
        operation(0,32'h10004000,2,0,0,1,0);
        operation(1,32'h10004000,2,0,0,1,0);
        operation(0,32'h10000000,2,0,0,0,32'h0000ff05);
        bus_before=requests;
        operation(0,32'h10000001,2,0,0,1,0);
        operation(1,32'h10000001,1,0,0,1,0);
        operation(0,32'h10000000,3,0,0,1,0);
        if(requests!=bus_before) $fatal(1,"alignment fault emitted bus request");
        if(requests!=8 || aws!=3 || ws!=3 || bs!=3 || ars!=5 || rs!=5 ||
           writes!=2 || completions!=11)
            $fatal(1,"LSU_RAM exactly-once counts");
        $display("TEST_PASS LSU_RAM seed=%0d requests=%0d AW=%0d W=%0d B=%0d AR=%0d R=%0d writes=%0d completions=%0d",
                 seed,requests,aws,ws,bs,ars,rs,writes,completions);
        $finish;
    end
    initial begin #50000; $fatal(1,"LSU_RAM timeout"); end
endmodule
