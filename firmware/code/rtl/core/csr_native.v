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
 // P50 split 2 (second attempt): commit address, value-read address and the
 // ID-stage legality address are SEPARATE ports.
 //
 // They used to be one `addr`, muxed as `w_valid && w_csr ? w_csr_addr :
 // id_csr_addr`, which put the WB-valid flop at the head of a cone running
 //   w_valid -> CSR read mux -> wb_value -> RF write port
 //           -> RF same-cycle write-through -> rf_d0 -> forward -> alu_a,
 // i.e. 5.30 ns of the 19.23 ns routed critical path (plan v19 section 10
 // segment 2).
 //
 // The value must be sampled one cycle before commit *and* `rd` and the
 // read-modify-write base must be the same sample, so this only works together
 // with `serial_q` being extended by one cycle (see rv32_top): without that the
 // next CSR instruction reaches M2 on the very cycle the previous one commits,
 // and `csrrs x3,mscratch,x0` behind `csrrw x2,mscratch,x1` reads 0 instead of
 // 0xffffffff (ISA case 6, measured twice).
 input wire [11:0] addr,     // commit (write) address
 input wire [11:0] raddr,    // value-read address  (M2)
 input wire [11:0] iaddr,    // legality-check address (ID)
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

 // ---------------------------------------------------------------------------
 // mcycle/minstret are 64 b and mcycle increments on EVERY cycle, so a plain
 // `mcycle + 64'd1` is a 64-deep carry chain sitting in the same cycle as the
 // pipeline.  Same treatment as perf_regs: 16 b quarters, carry taken from the
 // registers, so the four adders run in parallel and the longest chain is 16.
 // Value and cycle count are unchanged -- this is not a pipeline stage.
 // ---------------------------------------------------------------------------
 function [63:0] inc64;
   input [63:0] v;
   reg c1,c2,c3;
   begin
     c1 = (v[15:0]  == 16'hFFFF);
     c2 = c1 && (v[31:16] == 16'hFFFF);
     c3 = c2 && (v[47:32] == 16'hFFFF);
     inc64 = { v[63:48] + {15'd0,c3}, v[47:32] + {15'd0,c2},
               v[31:16] + {15'd0,c1}, v[15:0]  + 16'd1 };
   end
 endfunction
 // minstret adds 0..2, not 1: keep the same granularity, take the quarter carry
 // out of a 17 b sum instead of the "all ones" test.
 function [63:0] inc64_n;
   input [63:0] v;
   input [1:0]  n;
   reg [16:0] s0;
   reg c1,c2,c3;
   begin
     s0 = {1'b0, v[15:0]} + {15'd0, n};
     c1 = s0[16];
     c2 = c1 && (v[31:16] == 16'hFFFF);
     c3 = c2 && (v[47:32] == 16'hFFFF);
     inc64_n = { v[63:48] + {15'd0,c3}, v[47:32] + {15'd0,c2},
                 v[31:16] + {15'd0,c1}, s0[15:0] };
   end
 endfunction

 always @(*) begin
   read_data=0;
   case(raddr)
   12'h300: read_data=status;
   12'h301: read_data=32'h40001100;
   12'h304: read_data=mie;
   12'h305: read_data=mtvec;
   12'h340: read_data=mscratch;
   12'h341: read_data=mepc;
   12'h342: read_data=mcause;
   12'h343: read_data=mtval;
   12'h344: read_data=pending;
   12'hb00,12'hc00: read_data=mcycle[31:0];
   12'hb80,12'hc80: read_data=mcycle[63:32];
   12'hb02,12'hc02: read_data=minstret[31:0];
   12'hb82,12'hc82: read_data=minstret[63:32];
   12'hf14: read_data=0;
    default: read_data=0;
   endcase
 end
 // Legality is an ID-stage question: it is registered into `rr_csr_illegal` on
 // the ID->RR edge, so it decodes `iaddr` and nothing else.  It used to share
 // the read always block, which is why the read address could not move.
 wire ro_csr = (iaddr==12'h301) || (iaddr==12'h344) ||
               (iaddr==12'hc00) || (iaddr==12'hc80) ||
               (iaddr==12'hc02) || (iaddr==12'hc82) || (iaddr==12'hf14);
 wire addr_known =
      (iaddr==12'h300) || (iaddr==12'h301) || (iaddr==12'h304) || (iaddr==12'h305) ||
      (iaddr==12'h340) || (iaddr==12'h341) || (iaddr==12'h342) || (iaddr==12'h343) ||
      (iaddr==12'h344) || (iaddr==12'hb00) || (iaddr==12'hc00) || (iaddr==12'hb80) ||
      (iaddr==12'hc80) || (iaddr==12'hb02) || (iaddr==12'hc02) || (iaddr==12'hb82) ||
      (iaddr==12'hc82) || (iaddr==12'hf14);
 always @(*)
   illegal = !addr_known || (write_intent && ro_csr);
 // This pre-trap state also drives interrupt eligibility and the redirect vector.
 always @(*) begin
   ns=status; ne=mie; nv=mtvec; nsc=mscratch; np=mepc; nc=mcause; nt=mtval;
   ncy=inc64(mcycle); ni=inc64_n(minstret,retire_count);
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
