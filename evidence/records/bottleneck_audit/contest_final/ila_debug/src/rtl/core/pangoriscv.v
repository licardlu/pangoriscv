//=============================================================================
// pangoriscv - RV32IM processor core + native AXI4 SoC (Pango PG2L100H @ 27 MHz)
// Module : pangoriscv             File : rtl/core/pangoriscv.v
// Rev    : 1.0                    Date : 2026-10-13
// Author : pango_lpenghan
// Brief  : Processor core top: fetch/decode/execute/retire with predict and redirect interfaces
//=============================================================================

`include "defines.v"
`include "soc_config.vh"
module pangoriscv(
 input wire clk,rst_n,input wire fetch_valid,output wire fetch_ready,
 input wire [31:0] fetch_pc,fetch_inst,input wire fetch_fault,
 input wire [4:0] fetch_fault_cause,input wire [31:0] fetch_fault_tval,
 input wire [31:0] fetch_predicted_next_pc,output wire [31:0] request_pc,
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
 input wire irq_software,irq_timer,irq_external,output wire [31:0] csr_mtvec,
 output wire trap_fire,output wire [31:0] trap_pc,output wire [31:0] trap_cause,
 output wire [31:0] trap_tval,input wire [4:0] debug_addr,
 output wire [31:0] debug_data,
 // ---- T1 fetch chain: the IFU prefetches along the predicted path -------
 input  wire [31:0] chain_c,
 output wire [31:0] chain_predict_next_pc
);
 wire young_flush,block_entry;
 wire id_valid,id_ready,slot_ready,ex_valid,ex_leave;
 wire [31:0] ip,ii,it,ipred;
 wire ifault; wire [4:0] icause;
 wire [4:0] rs1,rs2,drd;
 wire [31:0] rv1,rv2,dinst,dpc,dr1,dr2,dcaddr,dcr,dcw,do1,do2,dj1,dj2;
 wire dwe,dcwe,dillegal,du1,du2;
 wire [31:0] ei,ep,er1,er2,ecaddr,ecr,eo1,eo2,ej1,ej2,et,epred;
 wire ewe,ecwe,efault,eillegal,eu1,eu2; wire [4:0] erd,ecause;
 wire [31:0] alu_result,alu_target;
 wire alu_taken;
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
 wire csr_intent=is_csr && ((ei[13:12]==1) || ei[19:15]!=0);
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
 wire memory_fault=is_memory && issued && done_valid && fault;
 wire ex_fault=local_fault || memory_fault;
 wire ex_done=local_fault || (is_memory ? (issued && done_valid) :
                       is_div ? (issued && div_rsp_valid) : 1'b1);
 wire [31:0] actual_next_pc=is_mret ? csr_epc : alu_taken ? alu_target : ep+32'd4;
 // ---- the predictor dynamic branch prediction (plan spec section 5) ----------------
 // The table is trained exactly once, at the architectural completion
 // boundary: retire_fire, with the retiring instruction's own PC (ep) and its
 // true next PC.  A flushed, trapped or halted instruction never asserts
 // retire_fire, so it can never train an entry.  A prediction may redirect the
 // fetch stage only; the architectural redirect at retire above keeps the
 // result identical to a predict-not-taken build.
 wire pred_is_branch=(ei[6:0]==7'h63);
 wire pred_is_jal=(ei[6:0]==7'h6f);
 wire pred_is_jalr=(ei[6:0]==7'h67) && (ei[14:12]==3'b000);
 wire pred_train_control=pred_is_branch || pred_is_jal || pred_is_jalr;
 wire pred_train_uncond=pred_is_jal || pred_is_jalr;
 wire pred_train_taken=(actual_next_pc!=(ep+32'd4));
 wire pred_take; wire [31:0] pred_target;
 wire chain_take; wire [31:0] chain_target;
`ifdef PREDICT_ENABLE
 branch_predictor u_branch_predictor(.clk(clk),.rst_n(rst_n),
   .fetch_pc(request_pc),.predict_taken(pred_take),.predict_target(pred_target),
   .fetch_pc2(chain_c),.predict_taken2(chain_take),.predict_target2(chain_target),
   .train_valid(retire_fire),.train_pc(ep),.train_control(pred_train_control),
   .train_uncond(pred_train_uncond),.train_taken(pred_train_taken),
   .train_target(actual_next_pc));
 assign predict_next_pc=pred_take ? pred_target : request_pc+32'd4;
 // The IFU's chain port sees exactly the same rule, so an instruction delivered
 // on the speculative path carries the prediction the pipeline would compute.
 assign chain_predict_next_pc=chain_take ? chain_target : chain_c+32'd4;
`else
 assign pred_take=1'b0;
 assign pred_target=32'd0;
 assign chain_take=1'b0;
 assign chain_target=32'd0;
 assign predict_next_pc=request_pc+32'd4;
 assign chain_predict_next_pc=chain_c+32'd4;
`endif
 // Mispredictions of whatever scheme drives predicted_next_pc: with
 // PREDICT_ENABLE that is the dynamic predictor, without it the static
 // not-taken reference the default/cached configurations report.
 assign pred_miss=retire_fire && (actual_next_pc!=epred);
 assign address=er1+(is_store ? {{20{ei[31]}},ei[31:25],ei[11:7]} :
                                {{20{ei[31]}},ei[31:20]});
 assign access_size={1'b0,ei[13:12]};
 assign load_unsigned=ei[14];
 assign store_value=er2;
 assign op_pc=ep; assign op_rd=erd;
 assign op_valid=rst_n && ex_valid && is_memory && !issued && !local_fault;
 assign done_ready=ex_leave && is_memory && issued;
 assign div_req_valid=rst_n && ex_valid && is_div && !issued && !local_fault;
 assign div_rsp_ready=ex_leave && is_div && issued;
 assign wdata=is_csr ? csr_old : is_load ? load_value : is_div ? div_result : alu_result;
 assign rd=erd; assign rd_valid=retire_fire && ewe && erd!=0;
 assign retire_pc=ep; assign retire_inst=ei;
 wire synchronous_trap=ex_valid && ex_done && ex_fault;
 assign trap_pc=synchronous_trap ? ep : retire_fire ? actual_next_pc : arch_next_pc;
 assign trap_cause=!synchronous_trap ? irq_cause :
                   efault ? {27'd0,ecause} : effective_illegal ? 32'd2 :
                   is_ebreak ? 32'd3 : is_ecall ? 32'd11 : misaligned_target ? 32'd0 :
                   misaligned_data ? (is_store?32'd6:32'd4) : (is_store?32'd7:32'd5);
 assign trap_tval=!synchronous_trap ? 32'd0 : efault ? et :
                  effective_illegal ? ei : (is_ecall || is_ebreak) ? 32'd0 : misaligned_target ? alu_target :
                  misaligned_data ? address : fault_addr;
 // Halt discards young work. Resume fetches from the saved architectural boundary.
 wire resume=halted && !halt_req;
 assign redirect_valid=trap_fire || (retire_fire && actual_next_pc!=epred) || resume;
 // trap_vector is retained only for port compatibility; architectural mtvec owns redirects.
 assign redirect_pc=trap_fire ? csr_mtvec : resume ? arch_next_pc : actual_next_pc;
 csr_native u_csr(.clk(clk),.rst_n(rst_n),.addr(ei[31:20]),
   .write_intent(csr_intent),.commit(retire_fire && csr_intent),
   .retire(retire_fire),.mret_fire(retire_fire && is_mret),
   .trap_enter(trap_fire),.write_data(csr_write),.trap_pc(trap_pc),
   .trap_cause(trap_cause),.trap_tval(trap_tval),
   .irq_software(irq_software),.irq_timer(irq_timer),.irq_external(irq_external),
   .read_data(csr_old),.illegal(csr_illegal),.vector(csr_mtvec),
   .mepc_value(csr_epc),.irq_pending(irq_pending),.irq_cause(irq_cause));
 assign id_ready=slot_ready && !block_entry;
 always @(posedge clk) begin
   if(!rst_n || ex_leave) issued<=0;
   else if((op_valid && op_ready) || (div_req_valid && div_req_ready)) issued<=1;
 end
 ctrl u_ctrl(.rst_n(rst_n),.redirect_valid(redirect_valid),.halt_pending(halt_pending),
   .halt_req(halt_req),.halted(halted),.young_flush(young_flush),.block_entry(block_entry));
 pc_reg u_pc_reg(.clk(clk),.rst_n(rst_n),.redirect_valid(redirect_valid),
   .redirect_pc(redirect_pc),.if_to_id_fire(fetch_valid && fetch_ready),
   .predicted_next_pc(fetch_predicted_next_pc),.pc_o(request_pc));
 if_id u_if_id(.clk(clk),.rst_n(rst_n),.flush(young_flush),
   .in_valid(fetch_valid),.in_ready(fetch_ready),.pc_i(fetch_pc),.inst_i(fetch_inst),
   .fault_i(fetch_fault),.fault_cause_i(fetch_fault_cause),.fault_tval_i(fetch_fault_tval),
   .predicted_next_pc_i(fetch_predicted_next_pc),.out_valid(id_valid),.out_ready(id_ready),
   .pc_o(ip),.inst_o(ii),.fault_o(ifault),.fault_cause_o(icause),
   .fault_tval_o(it),.predicted_next_pc_o(ipred));
 regs u_regs(.clk(clk),.rst(rst_n),.we_i(rd_valid),.waddr_i(rd),.wdata_i(wdata),
   .raddr1_i(rs1),.raddr2_i(rs2),.rdata1_o(rv1),.rdata2_o(rv2),
   .jtag_we_i(1'b0),.jtag_addr_i(debug_addr),.jtag_data_i(32'd0),.jtag_data_o(debug_data));
 id u_id(.rst(rst_n),.inst_i(ii),.inst_addr_i(ip),.reg1_rdata_i(rv1),
   .reg2_rdata_i(rv2),.csr_rdata_i(32'd0),.ex_jump_flag_i(1'b0),
   .reg1_raddr_o(rs1),.reg2_raddr_o(rs2),.inst_o(dinst),.inst_addr_o(dpc),
   .reg1_rdata_o(dr1),.reg2_rdata_o(dr2),.reg_we_o(dwe),.reg_waddr_o(drd),
   .csr_raddr_o(dcaddr),.csr_we_o(dcwe),.csr_rdata_o(dcr),.csr_waddr_o(dcw),
   .op1_o(do1),.op2_o(do2),.op1_jump_o(dj1),.op2_jump_o(dj2),
   .illegal_o(dillegal),.uses_rs1_o(du1),.uses_rs2_o(du2));
 id_ex u_id_ex(.clk(clk),.rst_n(rst_n),.in_valid(id_valid && !block_entry),
   .in_ready(slot_ready),.out_valid(ex_valid),.out_ready(ex_leave),
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
 div_adapter u_div_adapter(.clk(clk),.rst_n(rst_n),.req_valid(div_req_valid),
   .req_ready(div_req_ready),.dividend(er1),.divisor(er2),.op(ei[14:12]),
   .rsp_valid(div_rsp_valid),.rsp_ready(div_rsp_ready),.rsp_data(div_result));
 retire_ctrl u_retire_ctrl(.clk(clk),.rst_n(rst_n),.ex_valid(ex_valid),
   .ex_done(ex_done),.ex_fault(ex_fault),.trap_ready(trap_ready),.irq_pending(irq_pending),
   .actual_next_pc(actual_next_pc),.trap_vector(csr_mtvec),.halt_req(halt_req),
   .fetch_idle(fetch_idle),.data_idle(data_idle),
   .retire_fire(retire_fire),.trap_fire(trap_fire),.ex_leave(ex_leave),
   .retire_order(retire_order),.arch_next_pc(arch_next_pc),
   .halt_pending(halt_pending),.halted(halted));
endmodule
