//=============================================================================
// pangoriscv - RV32IM processor core + native AXI4 SoC (Pango PG2L100H @ 27 MHz)
// Module : native_axi_macros      File : rtl/core/native_axi_macros.vh
// Rev    : 1.0                    Date : 2026-10-13
// Author : pango_lpenghan
// Brief  : Port-list and handshake macros shared by the AXI4 peripherals
//=============================================================================

`ifndef NATIVE_AXI_MACROS_VH
`define NATIVE_AXI_MACROS_VH
`define AXI_SLAVE_PORTS(P,N) \
 input wire [N-1:0] P``_arvalid, output wire [N-1:0] P``_arready, \
 input wire [N*32-1:0] P``_araddr, input wire [N*4-1:0] P``_arid, \
 input wire [N*8-1:0] P``_arlen, input wire [N*3-1:0] P``_arsize, \
 input wire [N*2-1:0] P``_arburst, input wire [N-1:0] P``_arlock, \
 input wire [N*4-1:0] P``_arcache, input wire [N*3-1:0] P``_arprot, \
 input wire [N*4-1:0] P``_arqos, output wire [N-1:0] P``_rvalid, \
 input wire [N-1:0] P``_rready, output wire [N*32-1:0] P``_rdata, \
 output wire [N*4-1:0] P``_rid, output wire [N*2-1:0] P``_rresp, \
 output wire [N-1:0] P``_rlast, input wire [N-1:0] P``_awvalid, \
 output wire [N-1:0] P``_awready, input wire [N*32-1:0] P``_awaddr, \
 input wire [N*4-1:0] P``_awid, input wire [N*8-1:0] P``_awlen, \
 input wire [N*3-1:0] P``_awsize, input wire [N*2-1:0] P``_awburst, \
 input wire [N-1:0] P``_awlock, input wire [N*4-1:0] P``_awcache, \
 input wire [N*3-1:0] P``_awprot, input wire [N*4-1:0] P``_awqos, \
 input wire [N-1:0] P``_wvalid, output wire [N-1:0] P``_wready, \
 input wire [N*32-1:0] P``_wdata, input wire [N*4-1:0] P``_wstrb, \
 input wire [N-1:0] P``_wlast, output wire [N-1:0] P``_bvalid, \
 input wire [N-1:0] P``_bready, output wire [N*4-1:0] P``_bid, \
 output wire [N*2-1:0] P``_bresp
// Packed endpoint i occupies [i*WIDTH +: WIDTH].
`define AXI_MASTER_PORTS(P,N) \
 output wire [N-1:0] P``_arvalid, input wire [N-1:0] P``_arready, \
 output wire [N*32-1:0] P``_araddr, output wire [N*4-1:0] P``_arid, \
 output wire [N*8-1:0] P``_arlen, output wire [N*3-1:0] P``_arsize, \
 output wire [N*2-1:0] P``_arburst, output wire [N-1:0] P``_arlock, \
 output wire [N*4-1:0] P``_arcache, output wire [N*3-1:0] P``_arprot, \
 output wire [N*4-1:0] P``_arqos, input wire [N-1:0] P``_rvalid, \
 output wire [N-1:0] P``_rready, input wire [N*32-1:0] P``_rdata, \
 input wire [N*4-1:0] P``_rid, input wire [N*2-1:0] P``_rresp, \
 input wire [N-1:0] P``_rlast, output wire [N-1:0] P``_awvalid, \
 input wire [N-1:0] P``_awready, output wire [N*32-1:0] P``_awaddr, \
 output wire [N*4-1:0] P``_awid, output wire [N*8-1:0] P``_awlen, \
 output wire [N*3-1:0] P``_awsize, output wire [N*2-1:0] P``_awburst, \
 output wire [N-1:0] P``_awlock, output wire [N*4-1:0] P``_awcache, \
 output wire [N*3-1:0] P``_awprot, output wire [N*4-1:0] P``_awqos, \
 output wire [N-1:0] P``_wvalid, input wire [N-1:0] P``_wready, \
 output wire [N*32-1:0] P``_wdata, output wire [N*4-1:0] P``_wstrb, \
 output wire [N-1:0] P``_wlast, input wire [N-1:0] P``_bvalid, \
 output wire [N-1:0] P``_bready, input wire [N*4-1:0] P``_bid, \
 input wire [N*2-1:0] P``_bresp
`define AXI_WIRES(P,N) \
 wire [N-1:0] P``_arvalid,P``_arready,P``_arlock,P``_rvalid,P``_rready,P``_rlast; \
 wire [N-1:0] P``_awvalid,P``_awready,P``_awlock,P``_wvalid,P``_wready,P``_wlast,P``_bvalid,P``_bready; \
 wire [N*32-1:0] P``_araddr,P``_rdata,P``_awaddr,P``_wdata; \
 wire [N*4-1:0] P``_arid,P``_arcache,P``_arqos,P``_rid,P``_awid,P``_awcache,P``_awqos,P``_wstrb,P``_bid; \
 wire [N*8-1:0] P``_arlen,P``_awlen; \
 wire [N*3-1:0] P``_arsize,P``_arprot,P``_awsize,P``_awprot; \
 wire [N*2-1:0] P``_arburst,P``_rresp,P``_awburst,P``_bresp;
`define AXI_READ_CONNECT(P,B,I) \
 .P``_arvalid(B``_arvalid[I]),.P``_arready(B``_arready[I]), \
 .P``_araddr(B``_araddr[I*32+:32]),.P``_arid(B``_arid[I*4+:4]), \
 .P``_arlen(B``_arlen[I*8+:8]),.P``_arsize(B``_arsize[I*3+:3]), \
 .P``_arburst(B``_arburst[I*2+:2]),.P``_arlock(B``_arlock[I]), \
 .P``_arcache(B``_arcache[I*4+:4]),.P``_arprot(B``_arprot[I*3+:3]), \
 .P``_arqos(B``_arqos[I*4+:4]),.P``_rvalid(B``_rvalid[I]), \
 .P``_rready(B``_rready[I]),.P``_rdata(B``_rdata[I*32+:32]), \
 .P``_rid(B``_rid[I*4+:4]),.P``_rresp(B``_rresp[I*2+:2]),.P``_rlast(B``_rlast[I])
`define AXI_WRITE_CONNECT(P,B,I) \
 .P``_awvalid(B``_awvalid[I]),.P``_awready(B``_awready[I]), \
 .P``_awaddr(B``_awaddr[I*32+:32]),.P``_awid(B``_awid[I*4+:4]), \
 .P``_awlen(B``_awlen[I*8+:8]),.P``_awsize(B``_awsize[I*3+:3]), \
 .P``_awburst(B``_awburst[I*2+:2]),.P``_awlock(B``_awlock[I]), \
 .P``_awcache(B``_awcache[I*4+:4]),.P``_awprot(B``_awprot[I*3+:3]), \
 .P``_awqos(B``_awqos[I*4+:4]),.P``_wvalid(B``_wvalid[I]), \
 .P``_wready(B``_wready[I]),.P``_wdata(B``_wdata[I*32+:32]), \
 .P``_wstrb(B``_wstrb[I*4+:4]),.P``_wlast(B``_wlast[I]), \
 .P``_bvalid(B``_bvalid[I]),.P``_bready(B``_bready[I]), \
 .P``_bid(B``_bid[I*4+:4]),.P``_bresp(B``_bresp[I*2+:2])
`define AXI_CONNECT_ALL(P,B) \
 .P``_arvalid(B``_arvalid),.P``_arready(B``_arready),.P``_araddr(B``_araddr), \
 .P``_arid(B``_arid),.P``_arlen(B``_arlen),.P``_arsize(B``_arsize), \
 .P``_arburst(B``_arburst),.P``_arlock(B``_arlock),.P``_arcache(B``_arcache), \
 .P``_arprot(B``_arprot),.P``_arqos(B``_arqos),.P``_rvalid(B``_rvalid), \
 .P``_rready(B``_rready),.P``_rdata(B``_rdata),.P``_rid(B``_rid), \
 .P``_rresp(B``_rresp),.P``_rlast(B``_rlast),.P``_awvalid(B``_awvalid), \
 .P``_awready(B``_awready),.P``_awaddr(B``_awaddr),.P``_awid(B``_awid), \
 .P``_awlen(B``_awlen),.P``_awsize(B``_awsize),.P``_awburst(B``_awburst), \
 .P``_awlock(B``_awlock),.P``_awcache(B``_awcache),.P``_awprot(B``_awprot), \
 .P``_awqos(B``_awqos),.P``_wvalid(B``_wvalid),.P``_wready(B``_wready), \
 .P``_wdata(B``_wdata),.P``_wstrb(B``_wstrb),.P``_wlast(B``_wlast), \
 .P``_bvalid(B``_bvalid),.P``_bready(B``_bready),.P``_bid(B``_bid),.P``_bresp(B``_bresp)
`define CPU_STATUS_PORTS \
 input wire halt_req,output wire halted,output wire [31:0] arch_next_pc, \
 input wire trap_ready,input wire [31:0] trap_vector, \
 input wire irq_software,irq_timer,irq_external,output wire [31:0] csr_mtvec, \
 output wire trap_fire,output wire [31:0] trap_cause,output wire [31:0] trap_pc,trap_tval, \
 output wire retire_fire,output wire [63:0] retire_order, \
 output wire [31:0] retire_pc,retire_inst,output wire rd_valid, \
 output wire [4:0] rd,output wire [31:0] wdata, \
 input wire [4:0] debug_addr,output wire [31:0] debug_data,output wire protocol_fault
`define CPU_STATUS_CONNECT \
 .halt_req(halt_req),.halted(halted),.arch_next_pc(arch_next_pc), \
 .trap_ready(trap_ready),.trap_vector(trap_vector),.trap_fire(trap_fire), \
 .irq_software(irq_software),.irq_timer(irq_timer),.irq_external(irq_external),.csr_mtvec(csr_mtvec), \
 .trap_cause(trap_cause),.trap_pc(trap_pc),.trap_tval(trap_tval), \
 .retire_fire(retire_fire),.retire_order(retire_order),.retire_pc(retire_pc), \
 .retire_inst(retire_inst),.rd_valid(rd_valid),.rd(rd),.wdata(wdata), \
 .debug_addr(debug_addr),.debug_data(debug_data)
`define CPU_STATUS_CONNECT_LOCAL_IRQ \
 .halt_req(halt_req),.halted(halted),.arch_next_pc(arch_next_pc), \
 .trap_ready(trap_ready),.trap_vector(trap_vector),.trap_fire(trap_fire), \
 .irq_software(irq_software | local_irq_software), \
 .irq_timer(irq_timer | local_irq_timer), \
 .irq_external(irq_external | local_irq_external),.csr_mtvec(csr_mtvec), \
 .trap_cause(trap_cause),.trap_pc(trap_pc),.trap_tval(trap_tval), \
 .retire_fire(retire_fire),.retire_order(retire_order),.retire_pc(retire_pc), \
 .retire_inst(retire_inst),.rd_valid(rd_valid),.rd(rd),.wdata(wdata), \
 .debug_addr(debug_addr),.debug_data(debug_data)
`endif
