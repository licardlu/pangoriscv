//=============================================================================
// pangoriscv - RV32IM processor core + native AXI4 SoC (Pango PG2L100H @ 27 MHz)
// Module : csr_native             File : rtl/core/csr_native.v
// Rev    : 1.0                    Date : 2026-10-13
// Author : pango_lpenghan
// Brief  : Machine-mode CSRs: mstatus/mtvec/mepc/mcause/mtval/mie/mip/mcycle/minstret
//=============================================================================

// M-only CSR state. Normal commit -> MRET -> trap is one atomic transition.
module csr_native(
 input wire clk,rst_n,
 input wire [11:0] addr,
 input wire write_intent,commit,retire,mret_fire,trap_enter,
 input wire [1:0] retire_count,
 input wire [31:0] write_data,trap_pc,trap_cause,trap_tval,
 input wire irq_software,irq_timer,irq_external,
 output reg [31:0] read_data,
 output reg illegal,
 output wire [31:0] vector,mepc_value,
 output wire irq_pending,output wire [31:0] irq_cause
);
 reg [31:0] status,mie,mtvec,mscratch,mepc,mcause,mtval;
 reg [63:0] mcycle,minstret;
 reg [31:0] ns,ne,nv,nsc,np,nc,nt;
 reg [63:0] ncy,ni;
 wire [31:0] pending={20'd0,irq_external,3'd0,irq_timer,3'd0,irq_software,3'd0};
 wire [31:0] eligible=ne & pending;
 assign vector=nv;
 assign mepc_value=mepc;
 assign irq_pending=ns[3] && |eligible;
 assign irq_cause=eligible[11] ? 32'h8000000b :
                  eligible[3] ? 32'h80000003 : 32'h80000007;
 reg readonly_csr;
 always @(*) begin
   read_data=0; illegal=0; readonly_csr=0;
   case(addr)
    12'h300: read_data=status;
    12'h301: begin read_data=32'h40001100; readonly_csr=1; end
    12'h304: read_data=mie;
    12'h305: read_data=mtvec;
    12'h340: read_data=mscratch;
    12'h341: read_data=mepc;
    12'h342: read_data=mcause;
    12'h343: read_data=mtval;
    12'h344: begin read_data=pending; readonly_csr=1; end
    12'hb00,12'hc00: begin read_data=mcycle[31:0]; readonly_csr=(addr==12'hc00); end
    12'hb80,12'hc80: begin read_data=mcycle[63:32]; readonly_csr=(addr==12'hc80); end
    12'hb02,12'hc02: begin read_data=minstret[31:0]; readonly_csr=(addr==12'hc02); end
    12'hb82,12'hc82: begin read_data=minstret[63:32]; readonly_csr=(addr==12'hc82); end
    12'hf14: begin read_data=0; readonly_csr=1; end
    default: illegal=1;
   endcase
   if(write_intent && readonly_csr) illegal=1;
 end
 // This pre-trap state also drives interrupt eligibility and the redirect vector.
 always @(*) begin
   ns=status; ne=mie; nv=mtvec; nsc=mscratch; np=mepc; nc=mcause; nt=mtval;
   ncy=mcycle+64'd1; ni=minstret+{62'd0,retire_count};
   if(commit) begin
    case(addr)
     12'h300: ns=(write_data & 32'h88) | 32'h1800;
     12'h304: ne=write_data & 32'h888;
     12'h305: nv={write_data[31:2],2'b00};
     12'h340: nsc=write_data;
     12'h341: np={write_data[31:2],2'b00};
     12'h342: nc=write_data;
     12'h343: nt=write_data;
     12'hb00: ncy={mcycle[63:32],write_data};
     12'hb80: ncy={write_data,mcycle[31:0]};
     12'hb02: ni={minstret[63:32],write_data};
     12'hb82: ni={write_data,minstret[31:0]};
     default: begin end
    endcase
   end
   if(mret_fire) begin ns[3]=ns[7]; ns[7]=1; ns[12:11]=2'b11; end
 end
 always @(posedge clk) begin
   if(!rst_n) begin
    status<=32'h1800; mie<=0; mtvec<=0; mscratch<=0;
    mepc<=0; mcause<=0; mtval<=0; mcycle<=0; minstret<=0;
   end else begin
    status<=ns; mie<=ne; mtvec<=nv; mscratch<=nsc;
    mepc<=np; mcause<=nc; mtval<=nt; mcycle<=ncy; minstret<=ni;
    if(trap_enter) begin
     // MIE<-0, MPIE<-old MIE, MPP<-M (2'b11). An M-only machine must never leave
     // MPP holding U: a later MRET would otherwise advertise a privilege level
     // that this core does not implement.
     status<=(ns & ~32'h1888) | (ns[3] ? 32'h0080 : 32'h0000) | 32'h1800;
     mepc<={trap_pc[31:2],2'b00}; mcause<=trap_cause; mtval<=trap_tval;
    end
   end
 end
endmodule
