//=============================================================================
// pangoriscv - RV32IM processor core + native AXI4 SoC (Pango PG2L100H @ 27 MHz)
// Module : pangoriscv             File : rtl/core/pangoriscv.v
// Rev    : 1.1                    Date : 2026-10-19
// Author : pango_lpenghan
// Brief  : Processor core top: fetch/decode/execute/retire with predict and
//          redirect interfaces; two ALU-class issue slots (D1 superscalar)
//=============================================================================

`include "defines.v"
`include "soc_config.vh"
module pangoriscv(
 input wire clk,rst_n,
 input wire fetch_valid,output wire fetch_ready,output wire fetch_ready2,
 input wire [31:0] fetch_pc,fetch_inst,
 input wire [31:0] fetch_pc_hi,fetch_inst_hi,
 input wire fetch_fault,input wire [4:0] fetch_fault_cause,
 input wire [31:0] fetch_fault_tval,
 input wire fetch_fault_hi,input wire [4:0] fetch_fault_cause_hi,
 input wire [31:0] fetch_fault_tval_hi,
 input wire [31:0] fetch_predicted_next_pc,
 input wire [31:0] fetch_predicted_next_pc_hi,
 input wire fetch_pair,
 output wire [31:0] request_pc,
 output wire [31:0] predict_next_pc,output wire pred_miss,
 output wire redirect_valid,output wire [31:0] redirect_pc,
 input wire halt_req,fetch_idle,data_idle,
 output wire halted,halt_pending,output wire [31:0] arch_next_pc,
 output wire op_valid,input wire op_ready,output wire is_store,
 output wire [31:0] address,store_value,op_pc,output wire [2:0] access_size,
 output wire load_unsigned,output wire [4:0] op_rd,
 input wire done_valid,output wire done_ready,input wire [31:0] load_value,
 input wire fault,input wire [31:0] fault_addr,input wire trap_ready,
 input wire [31:0] trap_vector,output wire retire_fire,
 output wire [63:0] retire_order,output wire [31:0] retire_pc,retire_inst,
 output wire rd_valid,output wire [4:0] rd,output wire [31:0] wdata,
 output wire rd_valid_h,output wire [4:0] rd_h,output wire [31:0] wdata_h,
 input wire irq_software,irq_timer,irq_external,output wire [31:0] csr_mtvec,
 output wire trap_fire,output wire [31:0] trap_pc,output wire [31:0] trap_cause,
 output wire [31:0] trap_tval,input wire [4:0] debug_addr,
 output wire [31:0] debug_data,
 // ---- T1 fetch chain: the IFU prefetches along the predicted path -------
 input  wire [31:0] chain_c,
 output wire [31:0] chain_predict_next_pc,
 input  wire [31:0] chain_c2,
 output wire [31:0] chain_predict_next_pc2
);
 wire young_flush,block_entry;
 wire id_valid,id_valid_h,id_ready0,id_ready1;
 wire ex_valid,ex_valid_h,ex_leave,ex_leave0,ex_leave_h;
 wire [31:0] ip,ii,it,ipred,iph,iih,ith,ipredh;
 wire ifault,ifaulth; wire [4:0] icause,icauseh;
 wire [4:0] rs1,rs2,rs1h,rs2h,drd,drdh;
 wire [31:0] rv1,rv2,rv1h,rv2h;
 wire [31:0] dinst,dpc,dr1,dr2,dcaddr,dcr,dcw,do1,do2,dj1,dj2;
 wire [31:0] dinsth,dpch,dr1h,dr2h,dcaddrh,dcrh,dcwh,do1h,do2h,dj1h,dj2h;
 wire dwe,dcwe,dillegal,du1,du2,dweh,dcweh,dillegalh,du1h,du2h;
 wire [31:0] ei,ep,er1,er2,ecaddr,ecr,eo1,eo2,ej1,ej2,et,epred;
 wire [31:0] ei_h,ep_h,er1_h,er2_h,ecaddr_h,ecr_h,eo1_h,eo2_h,ej1_h,ej2_h,et_h,epred_h;
 wire ewe,ecwe,efault,eillegal,eu1,eu2;
 wire ewe_h,ecweh,efault_h,eillegal_h,eu1_h,eu2_h;
 wire [4:0] erd,ecause,erd_h,ecause_h;
 wire [31:0] alu_result,alu_target,alu_result_h,alu_target_h;
 wire alu_taken,alu_taken_h;
 wire is_load=(ei[6:0]==7'h03);
 assign is_store=(ei[6:0]==7'h23);
 wire is_memory=is_load || is_store;
 wire is_csr=ei[6:0]==7'h73 && ei[14:12]!=0 && ei[14:12]!=4;
 wire is_mret=ei==32'h30200073;
 wire is_ecall=ei==32'h00000073;
 wire is_ebreak=ei==32'h00100073;
 wire [31:0] csr_old,csr_write,csr_operand,csr_epc;
 wire csr_illegal,irq_pending;
 wire [31:0] irq_cause;
 wire csr_intent=is_csr && ((ei[13:12]==1) || (ei[19:15]!=0));
 assign csr_operand=ei[14] ? {27'd0,ei[19:15]} : er1;
 assign csr_write=ei[13:12]==1 ? csr_operand :
                  ei[13:12]==2 ? csr_old | csr_operand : csr_old & ~csr_operand;
 wire effective_illegal=eillegal || (is_csr && csr_illegal);
 wire is_div=(ei[6:0]==7'h33 && ei[31:25]==7'h01 && ei[14]);
 wire [31:0] div_result;
 wire div_req_ready,div_rsp_valid,div_req_valid,div_rsp_ready;
 reg issued;
 wire misaligned_data=(access_size==1 && address[0]) ||
                      (access_size==2 && |address[1:0]);
 wire misaligned_target=alu_taken && |alu_target[1:0];
 wire local_fault=efault || effective_illegal || is_ecall || is_ebreak || misaligned_target ||
                  (is_memory && misaligned_data);
 wire mem_issued=issued || (op_valid && op_ready);
 wire memory_fault=is_memory && mem_issued && done_valid && fault;
 wire ex_fault=local_fault || memory_fault;
 wire ex_done=local_fault || (is_memory ? (mem_issued && done_valid) :
                      is_div ? (issued && div_rsp_valid) : 1'b1);
 wire [31:0] actual_next_pc=is_mret ? csr_epc : alu_taken ? alu_target : ep+32'd4;
 // Lane 1 can only be an ALU op or a branch/JAL in D2, so its architectural
 // next PC is its branch target or PC+4.
 wire [31:0] actual_next_pc_h=alu_taken_h ? alu_target_h : ep_h+32'd4;

 // ---- D1 pairing: both slots are pure ALU-class, adjacent, no RAW/WAW -----
 wire [6:0] op0=dinst[6:0], op1=dinsth[6:0];
 wire alu0=(op0==7'h33 && dinst[31:25]!=7'h01) || op0==7'h13 || op0==7'h37 || op0==7'h17;
 wire alu1=(op1==7'h33 && dinsth[31:25]!=7'h01) || op1==7'h13 || op1==7'h37 || op1==7'h17;
 // D2: the second slot may be a taken-control instruction (conditional branch
 // or JAL).  JALR is excluded on purpose: its target can be misaligned and the
 // slot-1 trap path is not implemented yet.
 wire ctrl1=(op1==7'h63) || (op1==7'h6f);
 // D3: slot 0 may also be the pair's single memory operation.  Slot 1 remains
 // ALU/branch only, so the LSU still sees at most one request per cycle.
 wire mem0=(op0==7'h03) || (op0==7'h23);
 wire pair_ok=id_valid && id_valid_h &&
              (dpch==dpc+32'd4) &&
              (alu0 || mem0) && (alu1 || ctrl1) &&
              !dillegal && !dillegalh &&
              !dcwe && !dcweh &&
              !ifault && !ifaulth &&
              (drd==5'd0 || (drd!=rs1h && drd!=rs2h)) &&
              (drdh==5'd0 || (drdh!=rs1 && drdh!=rs2)) &&
              (drd==5'd0 || drdh==5'd0 || drd!=drdh);

 // id_ex drives in_ready (slot can take an instruction: empty or leaving).
 wire ex0_ready,ex1_ready;
 assign id_ready0=ex0_ready && !block_entry;
 assign id_ready1=ex0_ready && ex1_ready && pair_ok && !block_entry;
 // Keep the old hierarchical observability name used by the CoreMark testbench.
 wire id_ready=id_ready0;

 wire ex_fault_h=efault_h || eillegal_h;
 wire retire0=ex_valid && ex_done && !ex_fault;
 // In-order commit: lane 1 may retire only on the cycle lane 0 retires (or
 // when lane 0 is empty).  D3's lane 0 can be a multi-cycle load/store, so a
 // free-running lane-1 retire would commit the younger instruction first.
 wire retire1=ex_valid_h && !ex_fault_h && !ex_fault && (!ex_valid || retire0);
 wire trap0=ex_valid && ex_done && ex_fault;
 wire trap1=ex_valid_h && ex_fault_h && !ex_fault && (!ex_valid || retire0);
 assign ex_leave0=retire0 || trap0;
 assign ex_leave_h=retire1 || trap1;
 wire ex_leave_any=ex_leave0 || ex_leave_h;
 wire ex_valid_any=ex_valid || ex_valid_h;
 wire ex_fault_any=trap0 || trap1;
 wire retire_any=retire0 || retire1;
 wire trap_any=trap0 || trap1;
 assign retire_fire=retire_any;
 wire [31:0] last_next=ex_valid_h ? actual_next_pc_h : actual_next_pc;
 wire [31:0] last_pred=ex_valid_h ? epred_h : epred;
 wire [1:0] retire_count=retire_fire ? (retire1?2'd2:2'd1) : 2'd0;

 // ---- the predictor dynamic branch prediction ----------------------------
 wire pred_is_branch=(ei[6:0]==7'h63);
 wire pred_is_jal=(ei[6:0]==7'h6f);
 wire pred_is_jalr=(ei[6:0]==7'h67) && (ei[14:12]==3'b000);
 wire pred_train_control=pred_is_branch || pred_is_jal || pred_is_jalr;
 wire pred_train_uncond=pred_is_jal || pred_is_jalr;
 wire pred_train_taken=(actual_next_pc!=(ep+32'd4));
 // D2: the control transfer may sit in lane 1.  At most one lane can be a
 // control instruction (lane 0 must be ALU for a pair), so select lane 1 when
 // it is control, otherwise lane 0.
 wire pred_is_ctrl_h=(ei_h[6:0]==7'h63) || (ei_h[6:0]==7'h6f) ||
                     ((ei_h[6:0]==7'h67) && (ei_h[14:12]==3'b000));
 wire train_sel_h=ex_valid_h && pred_is_ctrl_h;
 wire [31:0] train_pc=train_sel_h ? ep_h : ep;
 wire train_control=train_sel_h ? 1'b1 : pred_train_control;
 wire train_uncond=train_sel_h ? ((ei_h[6:0]==7'h6f) ||
                                 ((ei_h[6:0]==7'h67)&&(ei_h[14:12]==3'b000)))
                               : pred_train_uncond;
 wire train_taken=train_sel_h ? (actual_next_pc_h!=(ep_h+32'd4)) : pred_train_taken;
 wire [31:0] train_target=train_sel_h ? actual_next_pc_h : actual_next_pc;
 wire pred_take; wire [31:0] pred_target;
 wire chain_take; wire [31:0] chain_target;
 wire chain_take2; wire [31:0] chain_target2;
`ifdef PREDICT_ENABLE
 branch_predictor u_branch_predictor(.clk(clk),.rst_n(rst_n),
   .fetch_pc(request_pc),.predict_taken(pred_take),.predict_target(pred_target),
   .fetch_pc2(chain_c),.predict_taken2(chain_take),.predict_target2(chain_target),
   .fetch_pc3(chain_c2),.predict_taken3(chain_take2),.predict_target3(chain_target2),
   .train_valid(retire_fire),.train_pc(train_pc),.train_control(train_control),
   .train_uncond(train_uncond),.train_taken(train_taken),
   .train_target(train_target));
 assign predict_next_pc=pred_take ? pred_target : request_pc+32'd4;
 assign chain_predict_next_pc=chain_take ? chain_target : chain_c+32'd4;
 assign chain_predict_next_pc2=chain_take2 ? chain_target2 : chain_c2+32'd4;
`else
 assign pred_take=1'b0;
 assign pred_target=32'd0;
 assign chain_take=1'b0;
 assign chain_target=32'd0;
 assign chain_take2=1'b0;
 assign chain_target2=32'd0;
 assign predict_next_pc=request_pc+32'd4;
 assign chain_predict_next_pc=chain_c+32'd4;
 assign chain_predict_next_pc2=chain_c2+32'd4;
`endif
 assign pred_miss=retire_fire && (last_next!=last_pred);
 assign address=er1+(is_store ? {{20{ei[31]}},ei[31:25],ei[11:7]} :
                                {{20{ei[31]}},ei[31:20]});
 assign access_size={1'b0,ei[13:12]};
 assign load_unsigned=ei[14];
 assign store_value=er2;
 assign op_pc=ep; assign op_rd=erd;
 assign op_valid=rst_n && ex_valid && is_memory && !issued && !local_fault;
 assign done_ready=ex_leave0 && is_memory && mem_issued;
 assign div_req_valid=rst_n && ex_valid && is_div && !issued && !local_fault;
 assign div_rsp_ready=ex_leave0 && is_div && issued;
 assign wdata=is_csr ? csr_old : is_load ? load_value : is_div ? div_result : alu_result;
 assign rd=erd; assign rd_valid=retire0 && ewe && erd!=0;
 assign rd_h=erd_h; assign rd_valid_h=retire1 && ewe_h && erd_h!=0;
 assign wdata_h=alu_result_h;
 assign retire_pc=ep; assign retire_inst=ei;
 wire synchronous_trap=ex_valid && ex_done && ex_fault;
 assign trap_pc=synchronous_trap ? ep : retire_fire ? last_next : arch_next_pc;
 assign trap_cause=!synchronous_trap ? irq_cause :
                    efault ? {27'd0,ecause} : effective_illegal ? 32'd2 :
                    is_ebreak ? 32'd3 : is_ecall ? 32'd11 : misaligned_target ? 32'd0 :
                    misaligned_data ? (is_store?32'd6:32'd4) : (is_store?32'd7:32'd5);
 assign trap_tval=!synchronous_trap ? 32'd0 : efault ? et :
                   effective_illegal ? ei : (is_ecall || is_ebreak) ? 32'd0 : misaligned_target ? alu_target :
                   misaligned_data ? address : fault_addr;
 // Halt discards young work. Resume fetches from the saved architectural boundary.
 wire resume=halted && !halt_req;
 assign redirect_valid=trap_fire || (retire_fire && last_next!=last_pred) || resume;
 assign redirect_pc=trap_fire ? csr_mtvec : resume ? arch_next_pc : last_next;
 csr_native u_csr(.clk(clk),.rst_n(rst_n),.addr(ei[31:20]),
   .write_intent(csr_intent),.commit(retire0 && csr_intent),
   .retire(retire0),.retire_count(retire_count),
   .mret_fire(retire0 && is_mret),
   .trap_enter(trap_fire),.write_data(csr_write),.trap_pc(trap_pc),
   .trap_cause(trap_cause),.trap_tval(trap_tval),
   .irq_software(irq_software),.irq_timer(irq_timer),.irq_external(irq_external),
   .read_data(csr_old),.illegal(csr_illegal),.vector(csr_mtvec),
   .mepc_value(csr_epc),.irq_pending(irq_pending),.irq_cause(irq_cause));
 always @(posedge clk) begin
   if(!rst_n || ex_leave0) issued<=0;
   else if((op_valid && op_ready) || (div_req_valid && div_req_ready)) issued<=1;
 end
 ctrl u_ctrl(.rst_n(rst_n),.redirect_valid(redirect_valid),.halt_pending(halt_pending),
   .halt_req(halt_req),.halted(halted),.young_flush(young_flush),.block_entry(block_entry));
 // The PC advances by the *packet* successor: when the IF/ID accepted both
 // words of an 8 B fetch, the architectural next PC is the second word's
 // prediction (its target if taken, otherwise PC+8).  When only one word fit in
 // the IF/ID the IFU keeps the second and the PC advances by the first word's
 // prediction.
 wire [31:0] fetch_next_pc=(fetch_pair && fetch_ready2) ?
                           fetch_predicted_next_pc_hi : fetch_predicted_next_pc;
 pc_reg u_pc_reg(.clk(clk),.rst_n(rst_n),.redirect_valid(redirect_valid),
   .redirect_pc(redirect_pc),.if_to_id_fire(fetch_valid && fetch_ready),
   .predicted_next_pc(fetch_next_pc),.pc_o(request_pc));
 if_id u_if_id(.clk(clk),.rst_n(rst_n),.flush(young_flush),
   .in_valid(fetch_valid),.in_pair(fetch_pair),
   .in_ready(fetch_ready),.in_ready2(fetch_ready2),
   .pc_i(fetch_pc),.inst_i(fetch_inst),.pc_hi_i(fetch_pc_hi),.inst_hi_i(fetch_inst_hi),
   .fault_i(fetch_fault),.fault_cause_i(fetch_fault_cause),.fault_tval_i(fetch_fault_tval),
   .predicted_next_pc_i(fetch_predicted_next_pc),
   .fault_hi_i(fetch_fault_hi),.fault_cause_hi_i(fetch_fault_cause_hi),
   .fault_tval_hi_i(fetch_fault_tval_hi),.predicted_next_pc_hi_i(fetch_predicted_next_pc_hi),
   .out_valid0(id_valid),.out_valid1(id_valid_h),
   .out_ready0(id_ready0),.out_ready1(id_ready1),
   .pc_o(ip),.inst_o(ii),.fault_o(ifault),.fault_cause_o(icause),
   .fault_tval_o(it),.predicted_next_pc_o(ipred),
   .pc_hi_o(iph),.inst_hi_o(iih),.fault_hi_o(ifaulth),.fault_cause_hi_o(icauseh),
   .fault_tval_hi_o(ith),.predicted_next_pc_hi_o(ipredh));
 // EX -> ID forwarding.  The register file's same-cycle write-through alone is
 // not enough: the ID/EX latch samples the combinational read on the same edge
 // the producer retires, so it can capture the pre-write value.  Select the EX
 // result explicitly (lane 1 is younger and wins on a same-register collision).
 wire [31:0] rv1f = (retire1 && ewe_h && erd_h!=0 && erd_h==rs1) ? alu_result_h :
                    (retire0 && ewe   && erd!=0   && erd==rs1)   ? wdata : rv1;
 wire [31:0] rv2f = (retire1 && ewe_h && erd_h!=0 && erd_h==rs2) ? alu_result_h :
                    (retire0 && ewe   && erd!=0   && erd==rs2)   ? wdata : rv2;
 wire [31:0] rv1hf= (retire1 && ewe_h && erd_h!=0 && erd_h==rs1h) ? alu_result_h :
                    (retire0 && ewe   && erd!=0   && erd==rs1h)   ? wdata : rv1h;
 wire [31:0] rv2hf= (retire1 && ewe_h && erd_h!=0 && erd_h==rs2h) ? alu_result_h :
                    (retire0 && ewe   && erd!=0   && erd==rs2h)   ? wdata : rv2h;
 regs u_regs(.clk(clk),.rst(rst_n),.we_i(rd_valid),.waddr_i(rd),.wdata_i(wdata),
   .we2_i(rd_valid_h),.waddr2_i(rd_h),.wdata2_i(wdata_h),
   .raddr1_i(rs1),.raddr2_i(rs2),.rdata1_o(rv1),.rdata2_o(rv2),
   .raddr3_i(rs1h),.raddr4_i(rs2h),.rdata3_o(rv1h),.rdata4_o(rv2h),
   .jtag_we_i(1'b0),.jtag_addr_i(debug_addr),.jtag_data_i(32'd0),.jtag_data_o(debug_data));
 id u_id(.rst(rst_n),.inst_i(ii),.inst_addr_i(ip),.reg1_rdata_i(rv1f),
   .reg2_rdata_i(rv2f),.csr_rdata_i(32'd0),.ex_jump_flag_i(1'b0),
   .reg1_raddr_o(rs1),.reg2_raddr_o(rs2),.inst_o(dinst),.inst_addr_o(dpc),
   .reg1_rdata_o(dr1),.reg2_rdata_o(dr2),.reg_we_o(dwe),.reg_waddr_o(drd),
   .csr_raddr_o(dcaddr),.csr_we_o(dcwe),.csr_rdata_o(dcr),.csr_waddr_o(dcw),
   .op1_o(do1),.op2_o(do2),.op1_jump_o(dj1),.op2_jump_o(dj2),
   .illegal_o(dillegal),.uses_rs1_o(du1),.uses_rs2_o(du2));
 id_alu u_id_h(.rst(rst_n),.inst_i(iih),.inst_addr_i(iph),.reg1_rdata_i(rv1hf),
   .reg2_rdata_i(rv2hf),
   .reg1_raddr_o(rs1h),.reg2_raddr_o(rs2h),.inst_o(dinsth),.inst_addr_o(dpch),
   .reg1_rdata_o(dr1h),.reg2_rdata_o(dr2h),.reg_we_o(dweh),.reg_waddr_o(drdh),
   .csr_we_o(dcweh),.csr_rdata_o(dcrh),.csr_waddr_o(dcwh),
   .op1_o(do1h),.op2_o(do2h),.op1_jump_o(dj1h),.op2_jump_o(dj2h),
   .illegal_o(dillegalh),.uses_rs1_o(du1h),.uses_rs2_o(du2h));
 id_ex u_id_ex(.clk(clk),.rst_n(rst_n),.in_valid(id_valid && !block_entry),
   .in_ready(ex0_ready),.out_valid(ex_valid),.out_ready(ex_leave0),
   .inst_i(dinst),.inst_addr_i(dpc),.reg_we_i(dwe),.reg_waddr_i(drd),
   .reg1_rdata_i(dr1),.reg2_rdata_i(dr2),.csr_we_i(dcwe),.csr_waddr_i(dcw),
   .csr_rdata_i(dcr),.op1_i(do1),.op2_i(do2),.op1_jump_i(dj1),.op2_jump_i(dj2),
   .fault_i(ifault),.fault_cause_i(icause),.fault_tval_i(it),.predicted_next_pc_i(ipred),
   .illegal_i(dillegal),.uses_rs1_i(du1),.uses_rs2_i(du2),
   .inst_o(ei),.inst_addr_o(ep),.reg_we_o(ewe),.reg_waddr_o(erd),
   .reg1_rdata_o(er1),.reg2_rdata_o(er2),.csr_we_o(ecwe),.csr_waddr_o(ecaddr),
   .csr_rdata_o(ecr),.op1_o(eo1),.op2_o(eo2),.op1_jump_o(ej1),.op2_jump_o(ej2),
   .fault_o(efault),.fault_cause_o(ecause),.fault_tval_o(et),.predicted_next_pc_o(epred),
   .illegal_o(eillegal),.uses_rs1_o(eu1),.uses_rs2_o(eu2));
 id_ex u_id_ex_h(.clk(clk),.rst_n(rst_n),.in_valid(id_ready1),
   .in_ready(ex1_ready),.out_valid(ex_valid_h),.out_ready(ex_leave_h),
   .inst_i(dinsth),.inst_addr_i(dpch),.reg_we_i(dweh),.reg_waddr_i(drdh),
   .reg1_rdata_i(dr1h),.reg2_rdata_i(dr2h),.csr_we_i(dcweh),.csr_waddr_i(dcwh),
   .csr_rdata_i(dcrh),.op1_i(do1h),.op2_i(do2h),.op1_jump_i(dj1h),.op2_jump_i(dj2h),
   .fault_i(ifaulth),.fault_cause_i(icauseh),.fault_tval_i(ith),.predicted_next_pc_i(ipredh),
   .illegal_i(dillegalh),.uses_rs1_i(du1h),.uses_rs2_i(du2h),
   .inst_o(ei_h),.inst_addr_o(ep_h),.reg_we_o(ewe_h),.reg_waddr_o(erd_h),
   .reg1_rdata_o(er1_h),.reg2_rdata_o(er2_h),.csr_we_o(ecweh),.csr_waddr_o(ecaddr_h),
   .csr_rdata_o(ecr_h),.op1_o(eo1_h),.op2_o(eo2_h),.op1_jump_o(ej1_h),.op2_jump_o(ej2_h),
   .fault_o(efault_h),.fault_cause_o(ecause_h),.fault_tval_o(et_h),.predicted_next_pc_o(epred_h),
   .illegal_o(eillegal_h),.uses_rs1_o(eu1_h),.uses_rs2_o(eu2_h));
 ex u_ex(.rst(rst_n),.inst_i(eillegal || efault ? 32'h13 : ei),.inst_addr_i(ep),
   .reg_we_i(ewe),.reg_waddr_i(erd),.reg1_rdata_i(er1),.reg2_rdata_i(er2),
   .csr_we_i(1'b0),.csr_waddr_i(ecaddr),.csr_rdata_i(ecr),
   .int_assert_i(1'b0),.int_addr_i(32'd0),.op1_i(eo1),.op2_i(eo2),
   .op1_jump_i(ej1),.op2_jump_i(ej2),.mem_rdata_i(32'd0),
   .div_ready_i(1'b0),.div_result_i(32'd0),.div_busy_i(1'b0),.div_reg_waddr_i(5'd0),
   .reg_wdata_o(alu_result),.jump_flag_o(alu_taken),.jump_addr_o(alu_target),
   .mem_wdata_o(),.mem_raddr_o(),.mem_waddr_o(),.mem_we_o(),.mem_req_o(),
   .reg_we_o(),.reg_waddr_o(),.csr_wdata_o(),.csr_we_o(),.csr_waddr_o(),
   .div_start_o(),.div_dividend_o(),.div_divisor_o(),.div_op_o(),.div_reg_waddr_o(),
   .hold_flag_o());
 ex_alu u_ex_h(.rst(rst_n),.inst_i(ei_h),.inst_addr_i(ep_h),
   .reg1_rdata_i(er1_h),.reg2_rdata_i(er2_h),
   .op1_i(eo1_h),.op2_i(eo2_h),
   .op1_jump_i(ej1_h),.op2_jump_i(ej2_h),
   .reg_wdata_o(alu_result_h),.jump_flag_o(alu_taken_h),.jump_addr_o(alu_target_h));
 div_adapter u_div_adapter(.clk(clk),.rst_n(rst_n),.req_valid(div_req_valid),
   .req_ready(div_req_ready),.dividend(er1),.divisor(er2),.op(ei[14:12]),
   .rsp_valid(div_rsp_valid),.rsp_ready(div_rsp_ready),.rsp_data(div_result));
 wire retire_ctrl_fire;
 retire_ctrl u_retire_ctrl(.clk(clk),.rst_n(rst_n),.ex_valid(ex_valid_any),
   .ex_done(retire_any || trap_any),.ex_fault(ex_fault_any),.trap_ready(trap_ready),
   .irq_pending(irq_pending),.actual_next_pc(last_next),.trap_vector(csr_mtvec),
   .halt_req(halt_req),.fetch_idle(fetch_idle),.data_idle(data_idle),
   .retire_fire(retire_ctrl_fire),.trap_fire(trap_fire),.ex_leave(ex_leave),
   .retire_order(retire_order),.arch_next_pc(arch_next_pc),
   .halt_pending(halt_pending),.halted(halted),.retire_count(retire_count));
endmodule
