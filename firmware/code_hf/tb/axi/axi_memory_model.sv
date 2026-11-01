//=============================================================================
// pangoriscv - RV32IM processor core + native AXI4 SoC (Pango PG2L100H @ 27 MHz)
// Module : axi_memory_model       File : tb/axi/axi_memory_model.sv
// Rev    : 1.0                    Date : 2026-10-13
// Author : pango_lpenghan
// Brief  : Verification-only AXI4 memory model: array-backed read/write with
//          configurable response latency
//=============================================================================

`timescale 1ns/1ps
// Verification-only interface. No existing CPU ports depend on this type.
interface axi_bus(input clk, input rst_n);
    logic [3:0] arid, awid, rid, bid;
    logic [31:0] araddr, awaddr, wdata, rdata;
    logic [7:0] arlen, awlen;
    logic [2:0] arsize, awsize, arprot, awprot;
    logic [1:0] arburst, awburst, rresp, bresp;
    logic arlock, awlock;
    logic [3:0] arcache, awcache, arqos, awqos, wstrb;
    logic arvalid, arready, awvalid, awready;
    logic wvalid, wready, wlast;
    logic rvalid, rready, rlast, bvalid, bready;
endinterface

module axi_memory_model(
    axi_bus bus,
    input ar_gate, aw_gate, w_gate, r_gate, b_gate, random_enable,
    output idle
);
    reg [7:0] memory [0:4095];
    reg read_live=0, aw_live=0, w_live=0, write_complete=0;
    reg [31:0] read_addr, write_addr, held_data;
    reg [3:0] read_id, write_id, held_strb;
    reg [2:0] read_size, write_size;
    reg [7:0] read_len, write_len;
    reg [1:0] read_response, write_response;
    reg held_last;
    integer read_beat=0, write_beat=0, index, lane, init_index, seed;
    reg [31:0] rng=1;

    function automatic [1:0] address_response(
        input [31:0] addr, input [7:0] len,
        input [2:0] size, input [1:0] burst, input lock);
        reg [32:0] end_addr;
        begin
            end_addr = {1'b0,addr} + (({25'b0,len}+1) << size) - 1;
            if (size>2 || len>15 || burst!=1 || lock ||
                ((addr & ((1 << size)-1)) != 0) ||
                end_addr[32] || addr[31:12] != end_addr[31:12])
                address_response=2; // Unsupported profile: SLVERR.
            else if (addr<32'h10000000 || end_addr>=33'h010001000)
                address_response=3;
            else address_response=0;
        end
    endfunction

    initial begin
        if (!$value$plusargs("SEED=%d",seed)) seed=1;
        rng=32'hace01234 ^ seed;
    end

    assign bus.arready = bus.rst_n && ar_gate && !read_live &&
        !aw_live && !w_live && !bus.bvalid &&
        !bus.awvalid && !bus.wvalid &&
        (!random_enable || rng[0]);
    assign bus.awready = bus.rst_n && aw_gate && !aw_live &&
        !read_live && !bus.bvalid && (!random_enable || rng[5]);
    assign bus.wready = bus.rst_n && w_gate && !w_live &&
        !read_live && !write_complete && !bus.bvalid &&
        (!random_enable || rng[11]);
    assign idle = !read_live && !aw_live && !w_live &&
                  !write_complete && !bus.rvalid && !bus.bvalid;

    always @(posedge bus.clk) begin
        if (!bus.rst_n) begin
            read_live<=0; aw_live<=0; w_live<=0; write_complete<=0;
            bus.rvalid<=0; bus.bvalid<=0;
            bus.rid<=0; bus.rdata<=0; bus.rresp<=0; bus.rlast<=0;
            bus.bid<=0; bus.bresp<=0;
            read_beat<=0; write_beat<=0;
            for(init_index=0;init_index<4096;init_index=init_index+1)
                memory[init_index]<=0;
        end else begin
            rng<={rng[30:0],rng[31]^rng[21]^rng[1]^rng[0]};
            if (bus.arvalid && bus.arready) begin
                read_live<=1; read_addr<=bus.araddr; read_id<=bus.arid;
                read_len<=bus.arlen; read_size<=bus.arsize; read_beat<=0;
                read_response<=address_response(bus.araddr,bus.arlen,
                    bus.arsize,bus.arburst,bus.arlock);
            end
            if (read_live && !bus.rvalid && r_gate &&
                (!random_enable || rng[17])) begin
                index=((read_addr-32'h10000000)+(read_beat << read_size)) &
                      32'hfffffffc;
                bus.rdata<=0;
                if (read_response==0)
                    for(lane=0;lane<4;lane=lane+1)
                        bus.rdata[lane*8 +: 8]<=memory[index+lane];
                bus.rid<=read_id; bus.rresp<=read_response;
                bus.rlast<=(read_beat==read_len); bus.rvalid<=1;
            end
            if (bus.rvalid && bus.rready) begin
                bus.rvalid<=0;
                if (read_beat==read_len) read_live<=0;
                else read_beat<=read_beat+1;
            end
            if (bus.awvalid && bus.awready) begin
                aw_live<=1; write_addr<=bus.awaddr; write_id<=bus.awid;
                write_len<=bus.awlen; write_size<=bus.awsize; write_beat<=0;
                write_response<=address_response(bus.awaddr,bus.awlen,
                    bus.awsize,bus.awburst,bus.awlock);
            end
            if (bus.wvalid && bus.wready) begin
                w_live<=1; held_data<=bus.wdata;
                held_strb<=bus.wstrb; held_last<=bus.wlast;
            end
            if (aw_live && w_live && !write_complete) begin
                if (held_last !== (write_beat==write_len))
                    $fatal(1,"MODEL_WLAST beat=%0d len=%0d",write_beat,write_len);
                index=((write_addr-32'h10000000)+(write_beat << write_size)) &
                      32'hfffffffc;
                if (write_response==0)
                    for(lane=0;lane<4;lane=lane+1)
                        if(held_strb[lane]) memory[index+lane]<=held_data[lane*8 +: 8];
                w_live<=0;
                if(write_beat==write_len) write_complete<=1;
                else write_beat<=write_beat+1;
            end
            if(write_complete && !bus.bvalid && b_gate &&
               (!random_enable || rng[23])) begin
                bus.bid<=write_id; bus.bresp<=write_response; bus.bvalid<=1;
            end
            if(bus.bvalid && bus.bready) begin
                bus.bvalid<=0; aw_live<=0; write_complete<=0;
            end
        end
    end
endmodule
