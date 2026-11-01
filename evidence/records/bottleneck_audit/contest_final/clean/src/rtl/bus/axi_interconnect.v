//=============================================================================
// pangoriscv - RV32IM processor core + native AXI4 SoC (Pango PG2L100H @ 27 MHz)
// Module : axi_interconnect       File : rtl/bus/axi_interconnect.v
// Rev    : 1.0                    Date : 2026-10-13
// Author : pango_lpenghan
// Brief  : AXI4 interconnect: one master, four slaves, address decode, arbitration, ID tracking
//=============================================================================

// Port i occupies [i*WIDTH +: WIDTH]. One descriptor globally owns all channels.
module axi_interconnect #(
    parameter integer MASTERS=2,
    parameter integer SLAVES=2,
    parameter [SLAVES*32-1:0] BASE_ADDR={32'h10000000,32'h00000000},
    parameter [SLAVES*32-1:0] ADDR_SIZE={32'h00004000,32'h00004000},
    parameter integer WATCHDOG_CYCLES=0
) (
    input wire clk,rst_n,
    input wire [MASTERS-1:0] m_arvalid,output reg [MASTERS-1:0] m_arready,
    input wire [MASTERS*32-1:0] m_araddr,input wire [MASTERS*4-1:0] m_arid,
    input wire [MASTERS*8-1:0] m_arlen,input wire [MASTERS*3-1:0] m_arsize,
    input wire [MASTERS*2-1:0] m_arburst,input wire [MASTERS-1:0] m_arlock,
    input wire [MASTERS*4-1:0] m_arcache,input wire [MASTERS*3-1:0] m_arprot,
    input wire [MASTERS*4-1:0] m_arqos,
    output reg [MASTERS-1:0] m_rvalid,input wire [MASTERS-1:0] m_rready,
    output reg [MASTERS*32-1:0] m_rdata,output reg [MASTERS*4-1:0] m_rid,
    output reg [MASTERS*2-1:0] m_rresp,output reg [MASTERS-1:0] m_rlast,
    input wire [MASTERS-1:0] m_awvalid,output reg [MASTERS-1:0] m_awready,
    input wire [MASTERS*32-1:0] m_awaddr,input wire [MASTERS*4-1:0] m_awid,
    input wire [MASTERS*8-1:0] m_awlen,input wire [MASTERS*3-1:0] m_awsize,
    input wire [MASTERS*2-1:0] m_awburst,input wire [MASTERS-1:0] m_awlock,
    input wire [MASTERS*4-1:0] m_awcache,input wire [MASTERS*3-1:0] m_awprot,
    input wire [MASTERS*4-1:0] m_awqos,
    input wire [MASTERS-1:0] m_wvalid,output reg [MASTERS-1:0] m_wready,
    input wire [MASTERS*32-1:0] m_wdata,input wire [MASTERS*4-1:0] m_wstrb,
    input wire [MASTERS-1:0] m_wlast,
    output reg [MASTERS-1:0] m_bvalid,input wire [MASTERS-1:0] m_bready,
    output reg [MASTERS*4-1:0] m_bid,output reg [MASTERS*2-1:0] m_bresp,
    output reg [SLAVES-1:0] s_arvalid,input wire [SLAVES-1:0] s_arready,
    output reg [SLAVES*32-1:0] s_araddr,output reg [SLAVES*4-1:0] s_arid,
    output reg [SLAVES*8-1:0] s_arlen,output reg [SLAVES*3-1:0] s_arsize,
    output reg [SLAVES*2-1:0] s_arburst,output reg [SLAVES-1:0] s_arlock,
    output reg [SLAVES*4-1:0] s_arcache,output reg [SLAVES*3-1:0] s_arprot,
    output reg [SLAVES*4-1:0] s_arqos,
    input wire [SLAVES-1:0] s_rvalid,output reg [SLAVES-1:0] s_rready,
    input wire [SLAVES*32-1:0] s_rdata,input wire [SLAVES*4-1:0] s_rid,
    input wire [SLAVES*2-1:0] s_rresp,input wire [SLAVES-1:0] s_rlast,
    output reg [SLAVES-1:0] s_awvalid,input wire [SLAVES-1:0] s_awready,
    output reg [SLAVES*32-1:0] s_awaddr,output reg [SLAVES*4-1:0] s_awid,
    output reg [SLAVES*8-1:0] s_awlen,output reg [SLAVES*3-1:0] s_awsize,
    output reg [SLAVES*2-1:0] s_awburst,output reg [SLAVES-1:0] s_awlock,
    output reg [SLAVES*4-1:0] s_awcache,output reg [SLAVES*3-1:0] s_awprot,
    output reg [SLAVES*4-1:0] s_awqos,
    output reg [SLAVES-1:0] s_wvalid,input wire [SLAVES-1:0] s_wready,
    output reg [SLAVES*32-1:0] s_wdata,output reg [SLAVES*4-1:0] s_wstrb,
    output reg [SLAVES-1:0] s_wlast,
    input wire [SLAVES-1:0] s_bvalid,output reg [SLAVES-1:0] s_bready,
    input wire [SLAVES*4-1:0] s_bid,input wire [SLAVES*2-1:0] s_bresp,
    output reg protocol_fault
);
    localparam FREE=0,READ=1,WRITE=2,FAULT=3;
    reg [1:0] state;
    integer owner,target,rr,choice,k,candidate,decoded,idle_cycles;
    reg [31:0] addr;
    reg [3:0] id,cache,qos;
    reg [7:0] len;
    reg [2:0] size,prot;
    reg [1:0] burst;
    reg lock,address_sent;
    reg [8:0] beats_left;
    reg [8:0] write_left;
    wire er_arready,er_rvalid,er_rlast,er_awready,er_wready,er_bvalid,er_fault;
    wire [31:0] er_rdata;
    wire [3:0] er_rid,er_bid;
    wire [1:0] er_rresp,er_bresp;
    wire error_target=target==SLAVES;
    wire target_arready=error_target ? er_arready : s_arready[target];
    wire target_awready=error_target ? er_awready : s_awready[target];
    wire target_wready=error_target ? er_wready : s_wready[target];
    wire target_rvalid=error_target ? er_rvalid : s_rvalid[target];
    wire target_rlast=error_target ? er_rlast : s_rlast[target];
    wire [3:0] target_rid=error_target ? er_rid : s_rid[target*4+:4];
    wire [31:0] target_rdata=error_target ? er_rdata : s_rdata[target*32+:32];
    wire [1:0] target_rresp=error_target ? er_rresp : s_rresp[target*2+:2];
    wire target_bvalid=error_target ? er_bvalid : s_bvalid[target];
    wire [3:0] target_bid=error_target ? er_bid : s_bid[target*4+:4];
    wire [1:0] target_bresp=error_target ? er_bresp : s_bresp[target*2+:2];
    wire live=rst_n && !protocol_fault && !er_fault;
    wire ar_present=live && state==READ && !address_sent;
    wire aw_present=live && state==WRITE && !address_sent;
    wire w_present=live && state==WRITE && write_left!=0 && m_wvalid[owner];
    wire read_good=target_rid==id && target_rlast==(beats_left==1);
    wire write_good=m_wlast[owner]==(write_left==1);
    wire r_present=live && state==READ && address_sent && target_rvalid && read_good;
    wire b_present=live && state==WRITE && address_sent && write_left==0 &&
                   target_bvalid && target_bid==id;
    wire ar_fire=ar_present && target_arready;
    wire aw_fire=aw_present && target_awready;
    wire w_fire=w_present && target_wready && write_good;
    wire r_fire=r_present && m_rready[owner];
    wire b_fire=b_present && m_bready[owner];
    // Full-width half-open windows. Overlap is fail-closed to the error endpoint.
    function integer decode;
        input [31:0] address;
        integer i,hits,result;
        reg [32:0] finish;
        begin
            hits=0; result=SLAVES;
            for(i=0;i<SLAVES;i=i+1) begin
                finish={1'b0,BASE_ADDR[i*32+:32]}+{1'b0,ADDR_SIZE[i*32+:32]};
                if({1'b0,address}>={1'b0,BASE_ADDR[i*32+:32]} &&
                   {1'b0,address}<finish) begin hits=hits+1; result=i; end
            end
            decode=hits==1 ? result : SLAVES;
        end
    endfunction
    axi_error_slave #(.WATCHDOG_CYCLES(WATCHDOG_CYCLES)) error_slave(
        .clk(clk),.rst_n(rst_n),
        .s_arvalid(ar_present && error_target),.s_arready(er_arready),
        .s_araddr(addr),.s_arid(id),.s_arlen(len),.s_arsize(size),
        .s_arburst(burst),.s_arlock(lock),.s_arcache(cache),.s_arprot(prot),.s_arqos(qos),
        .s_rvalid(er_rvalid),.s_rready(r_present && error_target && m_rready[owner]),
        .s_rdata(er_rdata),.s_rid(er_rid),.s_rresp(er_rresp),.s_rlast(er_rlast),
        .s_awvalid(aw_present && error_target),.s_awready(er_awready),
        .s_awaddr(addr),.s_awid(id),.s_awlen(len),.s_awsize(size),
        .s_awburst(burst),.s_awlock(lock),.s_awcache(cache),.s_awprot(prot),.s_awqos(qos),
        .s_wvalid(w_present && error_target && write_good),.s_wready(er_wready),
        .s_wdata(m_wdata[owner*32+:32]),.s_wstrb(m_wstrb[owner*4+:4]),
        .s_wlast(m_wlast[owner]),.s_bvalid(er_bvalid),
        .s_bready(b_present && error_target && m_bready[owner]),
        .s_bid(er_bid),.s_bresp(er_bresp),.protocol_fault(er_fault)
    );
    always @* begin
        choice=-1;
        candidate=rr;
        // Rotating scan instead of (rr+k)%(2*MASTERS) and /2: modulo and
        // division were not constant-folded by the ADS/Synplify mapper
        // (bmsSMOD unmapped), so the round-robin walk is written with an
        // explicit wrap test and bit selects.
        for(k=0;k<2*MASTERS;k=k+1) begin
            if(choice==-1 && (candidate[0]==1'b0 ? m_arvalid[candidate>>1] :
                                                   m_awvalid[candidate>>1]))
                choice=candidate;
            candidate=(candidate>=2*MASTERS-1)?0:candidate+1;
        end
        m_arready=0; m_awready=0; m_wready=0;
        m_rvalid=0; m_rdata=0; m_rid=0; m_rresp=0; m_rlast=0;
        m_bvalid=0; m_bid=0; m_bresp=0;
        s_arvalid=0; s_araddr=0; s_arid=0; s_arlen=0; s_arsize=0;
        s_arburst=0; s_arlock=0; s_arcache=0; s_arprot=0; s_arqos=0; s_rready=0;
        s_awvalid=0; s_awaddr=0; s_awid=0; s_awlen=0; s_awsize=0;
        s_awburst=0; s_awlock=0; s_awcache=0; s_awprot=0; s_awqos=0;
        s_wvalid=0; s_wdata=0; s_wstrb=0; s_wlast=0; s_bready=0;
        if(live) begin
            if(state==FREE && choice>=0) begin
                if(choice[0]==1'b0) m_arready[choice>>1]=1;
                else m_awready[choice>>1]=1;
            end
            if(state==WRITE && write_left!=0 && write_good)
                m_wready[owner]=target_wready;
            m_rvalid[owner]=r_present;
            m_rdata[owner*32+:32]=target_rdata; m_rid[owner*4+:4]=target_rid;
            m_rresp[owner*2+:2]=target_rresp; m_rlast[owner]=target_rlast;
            m_bvalid[owner]=b_present;
            m_bid[owner*4+:4]=target_bid; m_bresp[owner*2+:2]=target_bresp;
            if(!error_target) begin
                s_arvalid[target]=ar_present; s_araddr[target*32+:32]=addr;
                s_arid[target*4+:4]=id; s_arlen[target*8+:8]=len;
                s_arsize[target*3+:3]=size; s_arburst[target*2+:2]=burst;
                s_arlock[target]=lock; s_arcache[target*4+:4]=cache;
                s_arprot[target*3+:3]=prot; s_arqos[target*4+:4]=qos;
                s_rready[target]=r_present && m_rready[owner];
                s_awvalid[target]=aw_present; s_awaddr[target*32+:32]=addr;
                s_awid[target*4+:4]=id; s_awlen[target*8+:8]=len;
                s_awsize[target*3+:3]=size; s_awburst[target*2+:2]=burst;
                s_awlock[target]=lock; s_awcache[target*4+:4]=cache;
                s_awprot[target*3+:3]=prot; s_awqos[target*4+:4]=qos;
                s_wvalid[target]=w_present && write_good;
                s_wdata[target*32+:32]=m_wdata[owner*32+:32];
                s_wstrb[target*4+:4]=m_wstrb[owner*4+:4]; s_wlast[target]=m_wlast[owner];
                s_bready[target]=b_present && m_bready[owner];
            end
        end
    end
    always @(posedge clk) begin
        if(!rst_n) begin
            state<=FREE; owner<=0; target<=0; rr<=0; addr<=0; id<=0; len<=0;
            size<=0; burst<=0; lock<=0; cache<=0; prot<=0; qos<=0;
            address_sent<=0; beats_left<=0; write_left<=0;
            protocol_fault<=0; idle_cycles<=0;
        end else if(!protocol_fault) begin
            if(state==FREE && choice>=0) begin
                owner<=choice>>1;
                rr<=(choice+1>=2*MASTERS)?0:(choice+1);
                address_sent<=0;
                if(choice[0]==1'b0) begin
                    state<=READ; addr<=m_araddr[(choice>>1)*32+:32];
                    target<=decode(m_araddr[(choice>>1)*32+:32]);
                    id<=m_arid[(choice>>1)*4+:4]; len<=m_arlen[(choice>>1)*8+:8];
                    beats_left<={1'b0,m_arlen[(choice>>1)*8+:8]}+9'd1;
                    size<=m_arsize[(choice>>1)*3+:3]; burst<=m_arburst[(choice>>1)*2+:2];
                    lock<=m_arlock[choice>>1]; cache<=m_arcache[(choice>>1)*4+:4];
                    prot<=m_arprot[(choice>>1)*3+:3]; qos<=m_arqos[(choice>>1)*4+:4];
                end else begin
                    state<=WRITE; addr<=m_awaddr[(choice>>1)*32+:32];
                    target<=decode(m_awaddr[(choice>>1)*32+:32]);
                    id<=m_awid[(choice>>1)*4+:4]; len<=m_awlen[(choice>>1)*8+:8];
                    write_left<={1'b0,m_awlen[(choice>>1)*8+:8]}+9'd1;
                    size<=m_awsize[(choice>>1)*3+:3]; burst<=m_awburst[(choice>>1)*2+:2];
                    lock<=m_awlock[choice>>1]; cache<=m_awcache[(choice>>1)*4+:4];
                    prot<=m_awprot[(choice>>1)*3+:3]; qos<=m_awqos[(choice>>1)*4+:4];
                end
            end
            if(ar_fire || aw_fire) address_sent<=1;
            if(w_fire) write_left<=write_left-1;
            if(r_fire) begin
                beats_left<=beats_left-1;
                if(beats_left==1) state<=FREE;
            end
            if(b_fire) state<=FREE;
            if(er_fault ||
               (state==READ && address_sent && target_rvalid && !read_good) ||
               (state==WRITE && write_left!=0 && m_wvalid[owner] && !write_good) ||
               (state==WRITE && target_bvalid &&
                (!address_sent || write_left!=0 || target_bid!=id))) begin
                protocol_fault<=1; state<=FAULT;
            end
            // Disabled by default. A system using this must bound every external stall.
            if(state!=FREE && !(ar_fire || aw_fire || w_fire || r_fire || b_fire)) begin
                if(WATCHDOG_CYCLES>0 && idle_cycles>=WATCHDOG_CYCLES-1) begin
                    protocol_fault<=1; state<=FAULT;
                end else if(WATCHDOG_CYCLES>0) idle_cycles<=idle_cycles+1;
            end else idle_cycles<=0;
        end
    end
endmodule
