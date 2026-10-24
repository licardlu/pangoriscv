//=============================================================================
// pangoriscv - RV32IM processor core + native AXI4 SoC (Pango PG2L100H @ 27 MHz)
// Module : pangoriscv             File : rtl/core/pangoriscv.v
// Rev    : 1.1                    Date : 2026-10-19
// Author : pango_lpenghan
// Brief  : Processor core top: fetch/decode/execute/retire with predict and
//          redirect interfaces; dual issue with one LSU shared by either slot
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
 wire dep0,dep1,dep0_raw;
 wire d0_late;
 reg x0_late,e0_late,xh_late;
 wire [31:0] ex1_r1,ex1_r2;
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
 wire [31:0] xi,xp,xr1,xr2,xcaddr,xcr,xo1,xo2,xj1,xj2,xt,xpred;
 wire [31:0] xi_h,xp_h,xr1_h,xr2_h,xcaddr_h,xcr_h,xo1_h,xo2_h,xj1_h,xj2_h,xt_h,xpred_h;
 wire xwe,xcwe,xfault,xillegal,xu1,xu2;
 wire xwe_h,xcweh,xfault_h,xillegal_h,xu1_h,xu2_h;
 wire [4:0] xrd,xcause,xrd_h,xcause_h;
 wire x_valid,x_valid_h,back0_ready,back1_ready;
 wire x_advance=back0_ready && back1_ready && !redirect_valid;
 wire [31:0] x_alu_result,x_alu_target;
 wire x_alu_taken;
 wire x_is_mul=(xi[6:0]==7'h33 && xi[31:25]==7'h01 && !xi[14]);
 wire x_mul_signed_a=(xi[14:12]==3'b001 || xi[14:12]==3'b010);
 wire x_mul_signed_b=(xi[14:12]==3'b001);
 wire signed [32:0] x_mul_a={x_mul_signed_a && xr1[31],xr1};
 wire signed [32:0] x_mul_b={x_mul_signed_b && xr2[31],xr2};
 wire signed [65:0] x_mul_product=x_mul_a*x_mul_b;
 reg [63:0] mul_product;
 always @(posedge clk) begin
   if(!rst_n) mul_product<=64'd0;
   else if(x_valid && x_advance && x_is_mul) mul_product<=x_mul_product[63:0];
 end
 reg [31:0] early_result,alu_target;
 wire [31:0] late_result,alu_result;
 assign alu_result=e0_late ? late_result : early_result;
 reg alu_taken;
 wire [31:0] alu_result_h,alu_target_h;
 wire alu_taken_h;
 wire [31:0] x_alu_result_h,x_alu_target_h;
 wire x_alu_taken_h;
 wire x_h_early=x_valid_h && !xh_late &&
       ((xi_h[6:0]==7'h33 && xi_h[31:25]!=7'h01) || xi_h[6:0]==7'h13 ||
        xi_h[6:0]==7'h37 || xi_h[6:0]==7'h17 || xi_h[6:0]==7'h63 || xi_h[6:0]==7'h6f) &&
       !(x_valid && xwe && depends_on(xi_h,xrd));
 reg h_early;
 reg [31:0] early_result_h,early_target_h;
 reg early_taken_h;
 wire [31:0] late_result_h,late_target_h;
 wire late_taken_h;
 assign alu_result_h=h_early ? early_result_h : late_result_h;
 assign alu_target_h=h_early ? early_target_h : late_target_h;
 assign alu_taken_h=h_early ? early_taken_h : late_taken_h;
 always @(posedge clk) begin
   if(!rst_n) begin
     h_early<=0; early_result_h<=0; early_target_h<=0; early_taken_h<=0;
   end else if(x_valid_h && x_advance) begin
     h_early<=x_h_early; early_result_h<=x_alu_result_h;
     early_target_h<=x_alu_target_h; early_taken_h<=x_alu_taken_h;
   end
 end
 // X0 -> X1 result boundary: payload and result advance on the same handshake.
 always @(posedge clk) begin
   if(!rst_n) begin early_result<=0; alu_target<=0; alu_taken<=0; e0_late<=0; end
   else if(x_valid && x_advance) begin
     early_result<=x_alu_result; alu_target<=x_alu_target; alu_taken<=x_alu_taken; e0_late<=x0_late;
   end
 end
 wire is_load=(ei[6:0]==7'h03);
 wire is_store0=(ei[6:0]==7'h23);
 wire is_memory=is_load || is_store0;
 wire is_load_h=(ei_h[6:0]==7'h03);
 wire is_store_h=(ei_h[6:0]==7'h23);
 wire is_memory_h=is_load_h || is_store_h;
 // The two slots keep program order. Only the LSU owner is multiplexed;
 // instructions are never swapped between physical lanes.
 wire mem_sel_h=ex_valid_h && is_memory_h;
 assign is_store=mem_sel_h ? is_store_h : is_store0;
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
 wire is_mul=(ei[6:0]==7'h33 && ei[31:25]==7'h01 && !ei[14]);
 wire [31:0] mul_result=(ei[14:12]==3'b000) ? mul_product[31:0] : mul_product[63:32];
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
 wire misaligned_target_h=alu_taken_h && |alu_target_h[1:0];
 wire local_fault_h=efault_h || eillegal_h || misaligned_target_h ||
                    (is_memory_h && misaligned_data);
 wire memory_fault_h=is_memory_h && mem_issued && done_valid && fault;
 wire ex_fault_h=local_fault_h || memory_fault_h;
 wire ex_done_h=local_fault_h || !is_memory_h || (mem_issued && done_valid);
 // Memory/ALU fall through; branch/JAL use their resolved successor.
 wire [31:0] actual_next_pc_h=alu_taken_h ? alu_target_h : ep_h+32'd4;

 // ---- Dual issue: adjacent instructions, at most one memory operation ----
 wire [6:0] op0=dinst[6:0], op1=dinsth[6:0];
 wire alu0=(op0==7'h33 && dinst[31:25]!=7'h01) || op0==7'h13 || op0==7'h37 || op0==7'h17;
 wire alu1=(op1==7'h33 && dinsth[31:25]!=7'h01) || op1==7'h13 || op1==7'h37 || op1==7'h17;
 // The second slot may also be a branch or JAL. JALR remains excluded by
 // id_alu's decode contract even though lane-1 target faults are now precise.
 wire ctrl1=(op1==7'h63) || (op1==7'h6f);
 wire ctrl0=(op0==7'h63) || (op0==7'h6f) || (op0==7'h67);
 // Either slot may own the single LSU. Lane-1 memory requires an older ALU,
 // so there is no unresolved older branch, CSR or divide before its request.
 wire mem0=(op0==7'h03) || (op0==7'h23);
 wire mem1=(op1==7'h03) || (op1==7'h23);
 // Same-packet ALU RAW is resolved from the registered older X0 result.
 // Load RAW cannot pair. WAR is safe because both sources latch together;
 // WAW is safe because the younger write and bypass have priority.
 wire pair_ok=id_valid && id_valid_h &&
              (ctrl0 ? (dpch==ipred) : (dpch==dpc+32'd4)) &&
              (((alu0 || mem0) && (alu1 || ctrl1)) || (alu0 && mem1) || (ctrl0 && alu1)) &&
              (!ctrl0 || !dwe || !depends_on(dinsth,drd)) &&
              !dillegal && !dillegalh &&
              !dcwe && !dcweh &&
              !ifault && !ifaulth &&
              (!mem0 || !dwe || !depends_on(dinsth,drd)) &&
              (!d0_late || !dwe || !depends_on(dinsth,drd));

 // id_ex drives in_ready (slot can take an instruction: empty or leaving).
 wire ex0_ready,ex1_ready;
 assign id_ready0=ex0_ready && ex1_ready && !block_entry && !dep0;
 assign id_ready1=id_ready0 && pair_ok;
 // Keep the old hierarchical observability name used by the CoreMark testbench.
 wire id_ready=id_ready0;

 // Hold the packet until both slots finish. This keeps the older result
 // available for lane-1 address/store-data forwarding throughout an LSU wait,
 // and prevents an interrupt from splitting a packet with a visible store.
 // On a younger fault only the normal older prefix retires, on the trap edge.
 // A predicted target can share a packet with its older control transfer.
 // Wrong-path ALU work has no side effects and must never retire or trap.
 wire older_control=ei[6:0]==7'h63 || ei[6:0]==7'h6f || ei[6:0]==7'h67;
 wire young_path_ok=!ex_valid || !older_control || actual_next_pc==ep_h;
 wire retire0=ex_valid && ex_done && !ex_fault && !halted &&
              (!ex_valid_h || !young_path_ok || (ex_done_h && (!ex_fault_h || trap_ready)));
 wire retire1=ex_valid_h && young_path_ok && ex_done_h && !ex_fault_h && !halted &&
              (!ex_valid || retire0);
 wire trap0=ex_valid && ex_done && ex_fault;
 wire trap1=ex_valid_h && young_path_ok && ex_done_h && ex_fault_h &&
            (!ex_valid || (ex_done && !ex_fault));
 assign ex_leave0=retire0 || (trap_fire && trap0);
 // An older trap kills the younger slot even when it is not itself faulty.
 assign ex_leave_h=retire1 || (retire0 && !young_path_ok) || (trap_fire && (trap0 || trap1));
 wire ex_leave_any=ex_leave0 || ex_leave_h;
 wire ex_valid_any=ex_valid || ex_valid_h;
 wire ex_fault_any=trap0 || trap1;
 wire retire_any=retire0 || retire1;
 wire trap_any=trap0 || trap1;
 assign retire_fire=retire_any;
 wire [31:0] last_next=retire1 ? actual_next_pc_h : actual_next_pc;
 wire [31:0] last_pred=retire1 ? epred_h : epred;
 wire [1:0] retire_count={1'b0,retire0}+{1'b0,retire1};

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
 wire train_sel_h=retire1 && pred_is_ctrl_h;
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
 wire [31:0] mem_inst=mem_sel_h ? ei_h : ei;
 wire [31:0] mem_base=mem_sel_h ? ex1_r1 : er1;
 wire [31:0] mem_offset=is_store ?
                {{20{mem_inst[31]}},mem_inst[31:25],mem_inst[11:7]} :
                {{20{mem_inst[31]}},mem_inst[31:20]};
 // The memory address is already registered whenever its sources were ready
 // in X0; only an inter/intra-packet dependent younger memory uses X1 AGU.
 reg [31:0] mem_address0_q,mem_address1_q;
 reg mem_address1_early_q;
 wire [31:0] x_imm0=xi[6:0]==7'h23 ? {{20{xi[31]}},xi[31:25],xi[11:7]} : {{20{xi[31]}},xi[31:20]};
 wire [31:0] x_imm1=xi_h[6:0]==7'h23 ? {{20{xi_h[31]}},xi_h[31:25],xi_h[11:7]} : {{20{xi_h[31]}},xi_h[31:20]};
 always @(posedge clk) begin
   if(!rst_n) begin mem_address0_q<=0; mem_address1_q<=0; mem_address1_early_q<=0; end
   else if(x_valid && x_advance) begin
     mem_address0_q<=xr1+x_imm0;
     mem_address1_q<=xr1_h+x_imm1;
     mem_address1_early_q<=!xh_late && !(xwe && xrd!=0 && reads_rs1(xi_h) && xi_h[19:15]==xrd);
   end
 end
 assign address=mem_sel_h ? (mem_address1_early_q ? mem_address1_q : mem_base+mem_offset) : mem_address0_q;
 assign access_size={1'b0,mem_inst[13:12]};
 assign load_unsigned=mem_inst[14];
 assign store_value=mem_sel_h ? ex1_r2 : er2;
 assign op_pc=mem_sel_h ? ep_h : ep;
 assign op_rd=mem_sel_h ? erd_h : erd;
 // Check only local faults here. Gating a request on a bus-response fault
 // would feed a same-cycle cache response back into its own request-valid.
 assign op_valid=rst_n && !halted && !issued &&
                 (mem_sel_h ? (!efault_h && !eillegal_h && !misaligned_data &&
                               (!ex_valid || (!efault && !eillegal))) :
                              (ex_valid && is_memory && !efault && !eillegal && !misaligned_data));
 assign done_ready=mem_issued &&
                   (mem_sel_h ? ex_leave_h : (ex_leave0 && is_memory));
 assign div_req_valid=rst_n && ex_valid && is_div && !issued && !local_fault;
 assign div_rsp_ready=ex_leave0 && is_div && issued;
 assign wdata=is_csr ? csr_old : is_load ? load_value : is_div ? div_result :
              is_mul ? mul_result : alu_result;
 assign rd=erd; assign rd_valid=retire0 && ewe && erd!=0;
 assign rd_h=erd_h; assign rd_valid_h=retire1 && ewe_h && erd_h!=0;
 assign wdata_h=is_load_h ? load_value : alu_result_h;
 assign retire_pc=ep; assign retire_inst=ei;
 wire synchronous_trap=trap0 || trap1;
 assign trap_pc=trap0 ? ep : trap1 ? ep_h : retire_fire ? last_next : arch_next_pc;
 wire [31:0] trap_cause0=
                    efault ? {27'd0,ecause} : effective_illegal ? 32'd2 :
                    is_ebreak ? 32'd3 : is_ecall ? 32'd11 : misaligned_target ? 32'd0 :
                    misaligned_data ? (is_store0?32'd6:32'd4) : (is_store0?32'd7:32'd5);
 wire [31:0] trap_cause1=
                    efault_h ? {27'd0,ecause_h} : eillegal_h ? 32'd2 :
                    misaligned_target_h ? 32'd0 :
                    misaligned_data ? (is_store_h?32'd6:32'd4) : (is_store_h?32'd7:32'd5);
 assign trap_cause=trap0 ? trap_cause0 : trap1 ? trap_cause1 : irq_cause;
 wire [31:0] trap_tval0=efault ? et :
                   effective_illegal ? ei : (is_ecall || is_ebreak) ? 32'd0 : misaligned_target ? alu_target :
                   misaligned_data ? address : fault_addr;
 wire [31:0] trap_tval1=efault_h ? et_h : eillegal_h ? ei_h :
                    misaligned_target_h ? alu_target_h : misaligned_data ? address : fault_addr;
 assign trap_tval=trap0 ? trap_tval0 : trap1 ? trap_tval1 : 32'd0;
 // Halt discards young work. Resume fetches from the saved architectural boundary.
 wire resume=halted && !halt_req;
 assign redirect_valid=trap_fire || (retire_fire && last_next!=last_pred) || resume;
 assign redirect_pc=trap_fire ? csr_mtvec : resume ? arch_next_pc : last_next;
 csr_native u_csr(.clk(clk),.rst_n(rst_n),.addr(ei[31:20]),
   .write_intent(csr_intent),.commit(retire0 && csr_intent),
   .retire(retire_any),.retire_count(retire_count),
   .mret_fire(retire0 && is_mret),
   .trap_enter(trap_fire),.write_data(csr_write),.trap_pc(trap_pc),
   .trap_cause(trap_cause),.trap_tval(trap_tval),
   .irq_software(irq_software),.irq_timer(irq_timer),.irq_external(irq_external),
   .read_data(csr_old),.illegal(csr_illegal),.vector(csr_mtvec),
   .mepc_value(csr_epc),.irq_pending(irq_pending),.irq_cause(irq_cause));
 always @(posedge clk) begin
   if(!rst_n || ex_leave_any) issued<=0;
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
 // Real architectural sources, distinct from ID operand-selector flags.
 function reads_rs1;
   input [31:0] ins;
   begin
     case(ins[6:0])
       7'h33,7'h13,7'h03,7'h23,7'h63,7'h67: reads_rs1=1'b1;
       7'h73: reads_rs1=(ins[14:12]!=0 && !ins[14]);
       default: reads_rs1=1'b0;
     endcase
   end
 endfunction
 function reads_rs2;
   input [31:0] ins;
   begin reads_rs2=(ins[6:0]==7'h33 || ins[6:0]==7'h23 || ins[6:0]==7'h63); end
 endfunction
 function depends_on;
   input [31:0] ins;
   input [4:0] dest;
   begin depends_on=(dest!=0) &&
       ((reads_rs1(ins) && ins[19:15]==dest) ||
        (reads_rs2(ins) && ins[24:20]==dest)); end
 endfunction
 wire x0_forwardable=x_valid && !x0_late && xwe && !xfault && !xillegal &&
       ((xi[6:0]==7'h33 && xi[31:25]!=7'h01) || xi[6:0]==7'h13 ||
        xi[6:0]==7'h37 || xi[6:0]==7'h17);
 wire x0_forwardable_h=x_h_early && xwe_h && !xfault_h && !xillegal_h;
 // Resolve each true source against its youngest in-flight producer. An older
 // pending load does not block a value overwritten by a newer ready ALU.
 wire [27:0] hazard_producers={x_valid_h && xwe_h,xrd_h,x0_forwardable_h,
                              x_valid && xwe,xrd,x0_forwardable,
                              ex_valid_h && ewe_h,erd_h,retire1,
                              ex_valid && ewe,erd,retire0};
 function source_blocked;
   input [4:0] src;
   input [27:0] producers;
   begin
     if(src==0) source_blocked=0;
     else if(producers[27] && producers[26:22]==src) source_blocked=!producers[21];
     else if(producers[20] && producers[19:15]==src) source_blocked=!producers[14];
     else if(producers[13] && producers[12:8]==src) source_blocked=!producers[7];
     else if(producers[6] && producers[5:1]==src) source_blocked=!producers[0];
     else source_blocked=0;
   end
 endfunction
 assign dep0_raw=(reads_rs1(dinst) && source_blocked(dinst[19:15],hazard_producers)) ||
             (reads_rs2(dinst) && source_blocked(dinst[24:20],hazard_producers));
 assign d0_late=alu0 && dep0_raw;
 assign dep0=dep0_raw && !alu0;
 always @(posedge clk) begin
   if(!rst_n || redirect_valid) begin x0_late<=0; xh_late<=0; end
   else begin
     if(id_valid && id_ready0) x0_late<=d0_late;
     if(id_ready1) xh_late<=dep1;
   end
 end
 // Only late ALU operands are refreshed here. This is a producer ALU ->
 // operand register path, never producer ALU -> consumer ALU in one cycle.
 wire [31:0] late_r1=(retire1 && ewe_h && erd_h!=0 && erd_h==xi[19:15]) ? wdata_h :
                     (retire0 && ewe && erd!=0 && erd==xi[19:15]) ? wdata : xr1;
 wire [31:0] late_r2=(retire1 && ewe_h && erd_h!=0 && erd_h==xi[24:20]) ? wdata_h :
                     (retire0 && ewe && erd!=0 && erd==xi[24:20]) ? wdata : xr2;
 wire [31:0] x0_r1=x0_late ? late_r1 : xr1;
 wire [31:0] x0_r2=x0_late ? late_r2 : xr2;
 wire [31:0] x0_o1=(x0_late && reads_rs1(xi)) ? late_r1 : xo1;
 wire [31:0] x0_o2=(x0_late && reads_rs2(xi)) ? late_r2 : xo2;
 wire [31:0] late_r1h=(retire1 && ewe_h && erd_h!=0 && erd_h==xi_h[19:15]) ? wdata_h :
                      (retire0 && ewe && erd!=0 && erd==xi_h[19:15]) ? wdata : xr1_h;
 wire [31:0] late_r2h=(retire1 && ewe_h && erd_h!=0 && erd_h==xi_h[24:20]) ? wdata_h :
                      (retire0 && ewe && erd!=0 && erd==xi_h[24:20]) ? wdata : xr2_h;
 wire [31:0] x0_r1h=xh_late ? late_r1h : xr1_h;
 wire [31:0] x0_r2h=xh_late ? late_r2h : xr2_h;
 wire [31:0] x0_o1h=(xh_late && reads_rs1(xi_h)) ? late_r1h : xo1_h;
 wire [31:0] x0_o2h=(xh_late && reads_rs2(xi_h) && xi_h[6:0]!=7'h23) ? late_r2h : xo2_h;
 assign dep1=(reads_rs1(dinsth) && source_blocked(dinsth[19:15],hazard_producers)) ||
             (reads_rs2(dinsth) && source_blocked(dinsth[24:20],hazard_producers));
 // EX -> ID forwarding.  The register file's same-cycle write-through alone is
 // not enough: the ID/EX latch samples the combinational read on the same edge
 // the producer retires, so it can capture the pre-write value.  Select the EX
 // result explicitly (lane 1 is younger and wins on a same-register collision).
 wire [31:0] rv1f = (x0_forwardable_h && xrd_h!=0 && xrd_h==rs1) ? x_alu_result_h :
                    (x0_forwardable && xrd!=0 && xrd==rs1) ? x_alu_result :
                    (retire1 && ewe_h && erd_h!=0 && erd_h==rs1) ? wdata_h :
                    (retire0 && ewe   && erd!=0   && erd==rs1)   ? wdata : rv1;
 wire [31:0] rv2f = (x0_forwardable_h && xrd_h!=0 && xrd_h==rs2) ? x_alu_result_h :
                    (x0_forwardable && xrd!=0 && xrd==rs2) ? x_alu_result :
                    (retire1 && ewe_h && erd_h!=0 && erd_h==rs2) ? wdata_h :
                    (retire0 && ewe   && erd!=0   && erd==rs2)   ? wdata : rv2;
 wire [31:0] rv1hf= (x0_forwardable_h && xrd_h!=0 && xrd_h==rs1h) ? x_alu_result_h :
                    (x0_forwardable && xrd!=0 && xrd==rs1h) ? x_alu_result :
                    (retire1 && ewe_h && erd_h!=0 && erd_h==rs1h) ? wdata_h :
                    (retire0 && ewe   && erd!=0   && erd==rs1h)   ? wdata : rv1h;
 wire [31:0] rv2hf= (x0_forwardable_h && xrd_h!=0 && xrd_h==rs2h) ? x_alu_result_h :
                    (x0_forwardable && xrd!=0 && xrd==rs2h) ? x_alu_result :
                    (retire1 && ewe_h && erd_h!=0 && erd_h==rs2h) ? wdata_h :
                    (retire0 && ewe   && erd!=0   && erd==rs2h)   ? wdata : rv2h;
 // Registered X0 -> X1 forwarding inside one issue pair. The older result
 // is held alongside the X1 packet, including throughout a memory wait.
 // Only lane 0 ALU
 // class qualifies: `alu0` excludes loads/stores (whose result is not the ALU
 // output) and the M extension (multi-cycle, see the pair_ok term).
 // Every condition below is decoded from the EX-stage instructions (ei / ei_h).
 // The ID-stage aliases (alu0, mem0, op1, rs1h...) describe the packet that has
 // already moved on, and using them silently forwards the wrong operand (that bug
 // cost two debug rounds; see mistakes-log 13.6).
 wire [6:0] ex0_op = ei[6:0];
 wire [6:0] ex1_op = ei_h[6:0];
 wire ex0_alu_cls = (ex0_op==7'h33 && ei[31:25]!=7'h01) || ex0_op==7'h13 ||
                    ex0_op==7'h37 || ex0_op==7'h17;
 // Forwarding is data-only. Qualifying it with ex_fault would create a loop
 // through the forwarded memory address and local misalignment detection.
 // Faults instead suppress the LSU request and architectural write enables.
 wire fwd0_alu = ex_valid && ex_valid_h && ex0_alu_cls && ewe && erd!=5'd0;
 // The register operand reaches the ALU through TWO ports: `op1_i/op2_i` (already
 // selected between register and immediate by ID) and `reg1_rdata_i/reg2_rdata_i`
 // (used directly by the shift results).  Both have to be patched, and the
 // selection has to know whether the slot really reads a register:
 //   * op1/reg1 only when the instruction consumes rs1 (`du1h`) -- otherwise
 //     lui/auipc would have their immediate replaced by lane 0's result;
 //   * op2/reg2 only for R-type and branch, the two forms whose second operand is
 //     rs2 -- an I-type's second operand is an immediate (use the opcode).
 //     A store forwards rs2 into data only; op2 keeps the address immediate.
 // NOTE: the register NUMBERS must come from the EX-stage instruction (`ei_h`),
 // not from rs1h/rs2h -- those belong to the ID stage, which by then already holds
 // the NEXT packet (first attempt forwarded against the wrong numbers and left the
 // operand at X).  Whether a slot reads rs1/rs2 is decoded from its opcode:
 // 0x33/0x63/0x23 read both, 0x13/0x03 read rs1, 0x37/0x17/0x6f none.
 wire [4:0] ex1_rs1 = ei_h[19:15];
 wire [4:0] ex1_rs2 = ei_h[24:20];
 reg fwd0_r1_q,fwd0_r2_q;
 always @(posedge clk) begin
   if(!rst_n) begin fwd0_r1_q<=0; fwd0_r2_q<=0; end
   else if(x_valid && x_advance) begin
     fwd0_r1_q<=x_valid_h && xwe && xrd!=0 && reads_rs1(xi_h) && xrd==xi_h[19:15] &&
                ((xi[6:0]==7'h33 && xi[31:25]!=7'h01) || xi[6:0]==7'h13 || xi[6:0]==7'h37 || xi[6:0]==7'h17);
     fwd0_r2_q<=x_valid_h && xwe && xrd!=0 && reads_rs2(xi_h) && xrd==xi_h[24:20] &&
                ((xi[6:0]==7'h33 && xi[31:25]!=7'h01) || xi[6:0]==7'h13 || xi[6:0]==7'h37 || xi[6:0]==7'h17);
   end
 end
 wire fwd0_r1=fwd0_r1_q;
 wire fwd0_r2=fwd0_r2_q;
 assign ex1_r1 = fwd0_r1 ? alu_result : er1_h;
 assign ex1_r2 = fwd0_r2 ? alu_result : er2_h;
 wire [31:0] ex1_o1 = fwd0_r1 ? alu_result : eo1_h;
 // A store's rs2 is data, while its ALU operand 2 remains an immediate.
 wire [31:0] ex1_o2 = (fwd0_r2 && ex1_op!=7'h23) ? alu_result : eo2_h;
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
 id_ex #(.FLUSH_ENABLE(1)) u_id_ex(.clk(clk),.rst_n(rst_n),.flush(redirect_valid),.in_valid(id_valid && id_ready0),
   .in_ready(ex0_ready),.out_valid(x_valid),.out_ready(x_advance),
   .inst_i(dinst),.inst_addr_i(dpc),.reg_we_i(dwe),.reg_waddr_i(drd),
   .reg1_rdata_i(dr1),.reg2_rdata_i(dr2),.csr_we_i(dcwe),.csr_waddr_i(dcw),
   .csr_rdata_i(dcr),.op1_i(do1),.op2_i(do2),.op1_jump_i(dj1),.op2_jump_i(dj2),
   .fault_i(ifault),.fault_cause_i(icause),.fault_tval_i(it),.predicted_next_pc_i(ipred),
   .illegal_i(dillegal),.uses_rs1_i(du1),.uses_rs2_i(du2),
   .inst_o(xi),.inst_addr_o(xp),.reg_we_o(xwe),.reg_waddr_o(xrd),
   .reg1_rdata_o(xr1),.reg2_rdata_o(xr2),.csr_we_o(xcwe),.csr_waddr_o(xcaddr),
   .csr_rdata_o(xcr),.op1_o(xo1),.op2_o(xo2),.op1_jump_o(xj1),.op2_jump_o(xj2),
   .fault_o(xfault),.fault_cause_o(xcause),.fault_tval_o(xt),.predicted_next_pc_o(xpred),
   .illegal_o(xillegal),.uses_rs1_o(xu1),.uses_rs2_o(xu2));
 id_ex #(.FLUSH_ENABLE(1)) u_id_ex_h(.clk(clk),.rst_n(rst_n),.flush(redirect_valid),.in_valid(id_ready1),
   .in_ready(ex1_ready),.out_valid(x_valid_h),.out_ready(x_advance),
   .inst_i(dinsth),.inst_addr_i(dpch),.reg_we_i(dweh),.reg_waddr_i(drdh),
   .reg1_rdata_i(dr1h),.reg2_rdata_i(dr2h),.csr_we_i(dcweh),.csr_waddr_i(dcwh),
   .csr_rdata_i(dcrh),.op1_i(do1h),.op2_i(do2h),.op1_jump_i(dj1h),.op2_jump_i(dj2h),
   .fault_i(ifaulth),.fault_cause_i(icauseh),.fault_tval_i(ith),.predicted_next_pc_i(ipredh),
   .illegal_i(dillegalh),.uses_rs1_i(du1h),.uses_rs2_i(du2h),
   .inst_o(xi_h),.inst_addr_o(xp_h),.reg_we_o(xwe_h),.reg_waddr_o(xrd_h),
   .reg1_rdata_o(xr1_h),.reg2_rdata_o(xr2_h),.csr_we_o(xcweh),.csr_waddr_o(xcaddr_h),
   .csr_rdata_o(xcr_h),.op1_o(xo1_h),.op2_o(xo2_h),.op1_jump_o(xj1_h),.op2_jump_o(xj2_h),
   .fault_o(xfault_h),.fault_cause_o(xcause_h),.fault_tval_o(xt_h),.predicted_next_pc_o(xpred_h),
   .illegal_o(xillegal_h),.uses_rs1_o(xu1_h),.uses_rs2_o(xu2_h));
 // X1 holds the oldest packet; its own redirect must not erase its event.
 id_ex u_x0_x1(.clk(clk),.rst_n(rst_n),.flush(1'b0),.in_valid(x_valid && back1_ready && !redirect_valid),
   .in_ready(back0_ready),.out_valid(ex_valid),.out_ready(ex_leave0),
   .inst_i(xi),.inst_addr_i(xp),.reg_we_i(xwe),.reg_waddr_i(xrd),
   .reg1_rdata_i(x0_r1),.reg2_rdata_i(x0_r2),.csr_we_i(xcwe),.csr_waddr_i(xcaddr),
   .csr_rdata_i(xcr),.op1_i(x0_o1),.op2_i(x0_o2),.op1_jump_i(xj1),.op2_jump_i(xj2),
   .fault_i(xfault),.fault_cause_i(xcause),.fault_tval_i(xt),.predicted_next_pc_i(xpred),
   .illegal_i(xillegal),.uses_rs1_i(xu1),.uses_rs2_i(xu2),
   .inst_o(ei),.inst_addr_o(ep),.reg_we_o(ewe),.reg_waddr_o(erd),
   .reg1_rdata_o(er1),.reg2_rdata_o(er2),.csr_we_o(ecwe),.csr_waddr_o(ecaddr),
   .csr_rdata_o(ecr),.op1_o(eo1),.op2_o(eo2),.op1_jump_o(ej1),.op2_jump_o(ej2),
   .fault_o(efault),.fault_cause_o(ecause),.fault_tval_o(et),.predicted_next_pc_o(epred),
   .illegal_o(eillegal),.uses_rs1_o(eu1),.uses_rs2_o(eu2));
 id_ex u_x0_x1_h(.clk(clk),.rst_n(rst_n),.flush(1'b0),.in_valid(x_valid_h && back0_ready && !redirect_valid),
   .in_ready(back1_ready),.out_valid(ex_valid_h),.out_ready(ex_leave_h),
   .inst_i(xi_h),.inst_addr_i(xp_h),.reg_we_i(xwe_h),.reg_waddr_i(xrd_h),
   .reg1_rdata_i(x0_r1h),.reg2_rdata_i(x0_r2h),.csr_we_i(xcweh),.csr_waddr_i(xcaddr_h),
   .csr_rdata_i(xcr_h),.op1_i(x0_o1h),.op2_i(x0_o2h),.op1_jump_i(xj1_h),.op2_jump_i(xj2_h),
   .fault_i(xfault_h),.fault_cause_i(xcause_h),.fault_tval_i(xt_h),.predicted_next_pc_i(xpred_h),
   .illegal_i(xillegal_h),.uses_rs1_i(xu1_h),.uses_rs2_i(xu2_h),
   .inst_o(ei_h),.inst_addr_o(ep_h),.reg_we_o(ewe_h),.reg_waddr_o(erd_h),
   .reg1_rdata_o(er1_h),.reg2_rdata_o(er2_h),.csr_we_o(ecweh),.csr_waddr_o(ecaddr_h),
   .csr_rdata_o(ecr_h),.op1_o(eo1_h),.op2_o(eo2_h),.op1_jump_o(ej1_h),.op2_jump_o(ej2_h),
   .fault_o(efault_h),.fault_cause_o(ecause_h),.fault_tval_o(et_h),.predicted_next_pc_o(epred_h),
   .illegal_o(eillegal_h),.uses_rs1_o(eu1_h),.uses_rs2_o(eu2_h));
 ex #(.MUL_ENABLE(0)) u_ex(.rst(rst_n),.inst_i(xillegal || xfault ? 32'h13 : xi),.inst_addr_i(xp),
   .reg_we_i(xwe),.reg_waddr_i(xrd),.reg1_rdata_i(xr1),.reg2_rdata_i(xr2),
   .csr_we_i(1'b0),.csr_waddr_i(xcaddr),.csr_rdata_i(xcr),
   .int_assert_i(1'b0),.int_addr_i(32'd0),.op1_i(xo1),.op2_i(xo2),
   .op1_jump_i(xj1),.op2_jump_i(xj2),.mem_rdata_i(32'd0),
   .div_ready_i(1'b0),.div_result_i(32'd0),.div_busy_i(1'b0),.div_reg_waddr_i(5'd0),
   .reg_wdata_o(x_alu_result),.jump_flag_o(x_alu_taken),.jump_addr_o(x_alu_target),
   .mem_wdata_o(),.mem_raddr_o(),.mem_waddr_o(),.mem_we_o(),.mem_req_o(),
   .reg_we_o(),.reg_waddr_o(),.csr_wdata_o(),.csr_we_o(),.csr_waddr_o(),
   .div_start_o(),.div_dividend_o(),.div_divisor_o(),.div_op_o(),.div_reg_waddr_o(),
   .hold_flag_o());
 // Independent young work executes in parallel in X0. Dependent work keeps
 // the late X1 path; there is no same-cycle lane0 -> lane1 ALU chain.
 ex_alu u_ex_late(.rst(rst_n),.inst_i(ei),.inst_addr_i(ep),
   .reg1_rdata_i(er1),.reg2_rdata_i(er2),.op1_i(eo1),.op2_i(eo2),
   .op1_jump_i(ej1),.op2_jump_i(ej2),
   .reg_wdata_o(late_result),.jump_flag_o(),.jump_addr_o());
 ex_alu u_ex_h_early(.rst(rst_n),.inst_i(xi_h),.inst_addr_i(xp_h),
   .reg1_rdata_i(xr1_h),.reg2_rdata_i(xr2_h),
   .op1_i(xo1_h),.op2_i(xo2_h),.op1_jump_i(xj1_h),.op2_jump_i(xj2_h),
   .reg_wdata_o(x_alu_result_h),.jump_flag_o(x_alu_taken_h),.jump_addr_o(x_alu_target_h));
 ex_alu u_ex_h(.rst(rst_n),.inst_i(ei_h),.inst_addr_i(ep_h),
   .reg1_rdata_i(ex1_r1),.reg2_rdata_i(ex1_r2),
   .op1_i(ex1_o1),.op2_i(ex1_o2),
   .op1_jump_i(ej1_h),.op2_jump_i(ej2_h),
   .reg_wdata_o(late_result_h),.jump_flag_o(late_taken_h),.jump_addr_o(late_target_h));
 div_adapter u_div_adapter(.clk(clk),.rst_n(rst_n),.req_valid(div_req_valid),
   .req_ready(div_req_ready),.dividend(er1),.divisor(er2),.op(ei[14:12]),
   .rsp_valid(div_rsp_valid),.rsp_ready(div_rsp_ready),.rsp_data(div_result));
 wire retire_ctrl_fire;
 // IRQ is sampled at the oldest X1 boundary. X0 is speculative and is killed
 // by the resulting redirect; including its flush-masked valid here would
 // create a combinational IRQ -> flush -> valid -> IRQ feedback loop.
 retire_ctrl u_retire_ctrl(.clk(clk),.rst_n(rst_n),.ex_valid(ex_valid_any),
   .ex_done(retire_any || trap_any),.ex_fault(ex_fault_any),.trap_ready(trap_ready),
   .irq_pending(irq_pending),.actual_next_pc(last_next),.trap_vector(csr_mtvec),
   .halt_req(halt_req),.fetch_idle(fetch_idle && !x_valid && !x_valid_h),.data_idle(data_idle),
   .retire_fire(retire_ctrl_fire),.trap_fire(trap_fire),.ex_leave(ex_leave),
   .retire_order(retire_order),.arch_next_pc(arch_next_pc),
   .halt_pending(halt_pending),.halted(halted),.retire_count(retire_count));
endmodule
