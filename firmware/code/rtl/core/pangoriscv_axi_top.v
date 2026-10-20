//=============================================================================
// pangoriscv - RV32IM processor core + native AXI4 SoC (Pango PG2L100H @ 27 MHz)
// Module : pangoriscv_axi_top     File : rtl/core/pangoriscv_axi_top.v
// Rev    : 1.0                    Date : 2026-10-13
// Author : pango_lpenghan
// Brief  : Core top with fetch/memory engines (or caches) integrated
//=============================================================================

`include "native_axi_macros.vh"
`include "soc_config.vh"
// Native AXI endpoints: packed port 0 is instruction (ID 0), port 1 data (ID 1).
// Instruction write channels are present but permanently inactive.
module pangoriscv_axi_top(
 input wire clk,rst_n,
 input wire fabric_fault,
 `CPU_STATUS_PORTS,
`ifdef PERF_ENABLE
 // Instrumentation taps consumed by rtl/perips/perf_regs.v (plan spec section 6).
 output wire perf_i_miss,
 output wire perf_d_miss,
 output wire perf_if_wait,
 output wire perf_lsu_wait,
 output wire perf_pred_miss,
`endif
 `AXI_MASTER_PORTS(m,2)
);
 wire if_idle,ls_idle,if_req_ready,ls_req_ready,if_engine_ready,ls_engine_ready;
 wire halt_pending;
 wire if_pf,if_cf,ls_pf,ls_cf;
 wire if_cache_miss,data_cache_miss,dc_idle;
 wire fetch_valid,fetch_ready,fetch_ready2,fetch_fault,fetch_fault_hi,fetch_pair,redirect_valid;
 wire [31:0] fetch_pc,fetch_inst,fetch_pred,fetch_tval,request_pc,redirect_pc;
 wire [31:0] fetch_pc_hi,fetch_inst_hi,fetch_pred_hi,fetch_tval_hi;
 wire [4:0] fetch_cause_hi;
 wire [31:0] predict_next_pc;
 wire [31:0] ifu_chain_c,ifu_chain_pred,ifu_chain_c2,ifu_chain_pred2;
 wire [31:0] if_rsp_data_hi;
 wire if_rsp_pair;
 wire ifu_flush_lost;
 wire pred_miss;
 wire [4:0] fetch_cause;
 wire op_valid,op_ready,is_store,load_unsigned,done_valid,done_ready,fault;
 wire [31:0] address,store_value,op_pc,load_value,fault_addr;
 wire [2:0] access_size;
 wire [4:0] op_rd;
 wire if_req_valid,if_rsp_valid,if_rsp_ready;
 wire [31:0] if_req_addr,if_rsp_data;
 wire [2:0] if_req_size;
 wire [7:0] if_req_len;
 wire [3:0] if_req_id;
 wire [1:0] if_rsp_resp;
 wire ls_req_valid,ls_req_write,ls_w_valid,ls_w_ready,ls_w_last;
 wire ls_rsp_valid,ls_rsp_ready,ls_b_valid,ls_b_ready;
 wire [31:0] ls_req_addr,ls_w_data,ls_rsp_data;
 wire [2:0] ls_req_size;
 wire [7:0] ls_req_len;
 wire [3:0] ls_req_id,ls_w_strb;
 wire [1:0] ls_rsp_resp,ls_b_resp;
 assign protocol_fault=fabric_fault || if_pf || if_cf || ls_pf || ls_cf;
 // A latched halt drains the current EX while discarding all younger fetches.
 wire fetch_enable=!halt_req && !halt_pending && !halted && !protocol_fault;
 assign if_req_ready=if_engine_ready && !protocol_fault;
 assign ls_req_ready=ls_engine_ready && !protocol_fault;
 wire cpu_op_ready=op_ready && !protocol_fault;
 pangoriscv cpu(
  .clk(clk),.rst_n(rst_n),`CPU_STATUS_CONNECT,.halt_pending(halt_pending),
  .fetch_valid(fetch_valid),.fetch_ready(fetch_ready),.fetch_ready2(fetch_ready2),
  .fetch_pc(fetch_pc),.fetch_inst(fetch_inst),
  .fetch_pc_hi(fetch_pc_hi),.fetch_inst_hi(fetch_inst_hi),.fetch_pair(fetch_pair),
  .fetch_fault(fetch_fault),.fetch_fault_cause(fetch_cause),
  .fetch_fault_tval(fetch_tval),.fetch_predicted_next_pc(fetch_pred),
  .fetch_fault_hi(fetch_fault_hi),.fetch_fault_cause_hi(fetch_cause_hi),
  .fetch_fault_tval_hi(fetch_tval_hi),.fetch_predicted_next_pc_hi(fetch_pred_hi),
  .request_pc(request_pc),.predict_next_pc(predict_next_pc),.pred_miss(pred_miss),
  .redirect_valid(redirect_valid),.redirect_pc(redirect_pc),
  .fetch_idle(if_idle && if_req_ready && !protocol_fault),
  .data_idle(ls_idle && ls_req_ready && dc_idle && !protocol_fault),
  .op_valid(op_valid),.op_ready(cpu_op_ready),.is_store(is_store),
  .address(address),.store_value(store_value),.op_pc(op_pc),
  .access_size(access_size),.load_unsigned(load_unsigned),.op_rd(op_rd),
  .done_valid(done_valid),.done_ready(done_ready),.load_value(load_value),
  .fault(fault),.fault_addr(fault_addr),
  .chain_c(ifu_chain_c),.chain_predict_next_pc(ifu_chain_pred),
  .chain_c2(ifu_chain_c2),.chain_predict_next_pc2(ifu_chain_pred2)
 );
 ifu_axi ifu(.clk(clk),.rst_n(rst_n),.enable(fetch_enable),
  .redirect_valid(redirect_valid || halt_req || halt_pending || halted || protocol_fault),
  .fetch_pc(request_pc),.predicted_next_pc(predict_next_pc),
  .chain_c(ifu_chain_c),.chain_predict_next_pc(ifu_chain_pred),
  .chain_c2(ifu_chain_c2),.chain_predict_next_pc2(ifu_chain_pred2),
  .flush_lost(ifu_flush_lost),
  .fetch_valid(fetch_valid),.fetch_ready(fetch_ready),.fetch_ready2(fetch_ready2),
  .result_pc(fetch_pc),.result_pc_hi(fetch_pc_hi),
  .result_inst(fetch_inst),.result_inst_hi(fetch_inst_hi),
  .result_pair(fetch_pair),.result_predicted_next_pc(fetch_pred),
  .result_predicted_next_pc_hi(fetch_pred_hi),
  .result_fault(fetch_fault),.result_fault_cause(fetch_cause),
  .result_fault_tval(fetch_tval),
  .result_fault_hi(fetch_fault_hi),.result_fault_cause_hi(fetch_cause_hi),
  .result_fault_tval_hi(fetch_tval_hi),.idle(if_idle),
  .eng_req_valid(if_req_valid),.eng_req_ready(if_req_ready),
  .eng_req_addr(if_req_addr),.eng_req_size(if_req_size),.eng_req_len(if_req_len),
  .eng_req_id(if_req_id),.eng_rsp_valid(if_rsp_valid),.eng_rsp_ready(if_rsp_ready),
  .eng_rsp_data(if_rsp_data),.eng_rsp_data_hi(if_rsp_data_hi),
  .eng_rsp_pair(if_rsp_pair),.eng_rsp_resp(if_rsp_resp)
 );
`ifdef CACHE_ENABLE
 // the caches/H1: the two-way set-associative I-cache takes the place of the single-beat
 // read engine, so a miss becomes one ARLEN=7 INCR burst on the instruction port.
 icache_axi instruction_cache(.clk(clk),.rst_n(rst_n),
  .invalidate(halt_req || halt_pending || halted || protocol_fault),
  .req_valid(if_req_valid && !protocol_fault),.req_ready(if_engine_ready),
  .req_addr(if_req_addr),.req_size(if_req_size),.req_len(if_req_len),.req_id(if_req_id),
  .rsp_valid(if_rsp_valid),.rsp_ready(if_rsp_ready),.rsp_data(if_rsp_data),
  .rsp_data_hi(if_rsp_data_hi),.rsp_pair(if_rsp_pair),
  .rsp_resp(if_rsp_resp),.rsp_id(),.protocol_fault(if_pf),.config_fault(if_cf),
  .miss_pulse(if_cache_miss),.access_pulse(),`AXI_READ_CONNECT(m,m,0)
 );
`else
 axi_read_engine instruction_engine(.clk(clk),.rst_n(rst_n),
  .req_valid(if_req_valid && !protocol_fault),.req_ready(if_engine_ready),
  .req_addr(if_req_addr),.req_size(if_req_size),.req_len(if_req_len),.req_id(if_req_id),
  .rsp_valid(if_rsp_valid),.rsp_ready(if_rsp_ready),.rsp_data(if_rsp_data),
  .rsp_resp(if_rsp_resp),.rsp_last(),.rsp_id(),
  .protocol_fault(if_pf),.config_fault(if_cf),`AXI_READ_CONNECT(m,m,0)
 );
 assign if_cache_miss=1'b0;
 assign if_rsp_data_hi=32'd0;
 assign if_rsp_pair=1'b0;
`endif
 lsu_axi lsu(.clk(clk),.rst_n(rst_n),
  .op_valid(op_valid && !protocol_fault),.op_ready(op_ready),.is_store(is_store),
  .address(address),.store_value(store_value),.op_pc(op_pc),.access_size(access_size),
  .load_unsigned(load_unsigned),.op_rd(op_rd),.done_valid(done_valid),
  .done_ready(done_ready),.load_value(load_value),.fault_addr(fault_addr),
  .fault(fault),.idle(ls_idle),.eng_req_valid(ls_req_valid),
  .eng_req_ready(ls_req_ready),.eng_req_write(ls_req_write),.eng_req_addr(ls_req_addr),
  .eng_req_size(ls_req_size),.eng_req_len(ls_req_len),.eng_req_id(ls_req_id),
  .eng_w_valid(ls_w_valid),.eng_w_ready(ls_w_ready),.eng_w_data(ls_w_data),
  .eng_w_strb(ls_w_strb),.eng_w_last(ls_w_last),.eng_rsp_valid(ls_rsp_valid),
  .eng_rsp_ready(ls_rsp_ready),.eng_rsp_data(ls_rsp_data),.eng_rsp_resp(ls_rsp_resp),
  .eng_b_valid(ls_b_valid),.eng_b_ready(ls_b_ready),.eng_b_resp(ls_b_resp)
 );
`ifdef CACHE_ENABLE
 // the caches/H1: the two-way set-associative D-cache fronts the data port. Stores stay
 // single-beat (write-through, no write allocate); a load that misses its line
 // becomes one ARLEN=7 INCR burst, exactly like the instruction side.
 dcache_axi data_cache(.clk(clk),.rst_n(rst_n),
  .req_valid(ls_req_valid && !protocol_fault),.req_ready(ls_engine_ready),
  .req_write(ls_req_write),.req_addr(ls_req_addr),.req_size(ls_req_size),
  .req_len(ls_req_len),.req_id(ls_req_id),.w_valid(ls_w_valid),
  .w_ready(ls_w_ready),.w_data(ls_w_data),.w_strb(ls_w_strb),.w_last(ls_w_last),
  .rsp_valid(ls_rsp_valid),.rsp_ready(ls_rsp_ready),.rsp_data(ls_rsp_data),
  .rsp_resp(ls_rsp_resp),.rsp_last(),.rsp_id(),.b_valid(ls_b_valid),
  .b_ready(ls_b_ready),.b_resp(ls_b_resp),.b_id(),.protocol_fault(ls_pf),
  .config_fault(ls_cf),.miss_event(data_cache_miss),.dc_idle(dc_idle),
  `AXI_READ_CONNECT(m,m,1),
  `AXI_WRITE_CONNECT(m,m,1)
 );
`else
 axi_data_engine data_engine(.clk(clk),.rst_n(rst_n),
  .req_valid(ls_req_valid && !protocol_fault),.req_ready(ls_engine_ready),
  .req_write(ls_req_write),.req_addr(ls_req_addr),.req_size(ls_req_size),
  .req_len(ls_req_len),.req_id(ls_req_id),.w_valid(ls_w_valid),
  .w_ready(ls_w_ready),.w_data(ls_w_data),.w_strb(ls_w_strb),.w_last(ls_w_last),
  .rsp_valid(ls_rsp_valid),.rsp_ready(ls_rsp_ready),.rsp_data(ls_rsp_data),
  .rsp_resp(ls_rsp_resp),.rsp_last(),.rsp_id(),.b_valid(ls_b_valid),
  .b_ready(ls_b_ready),.b_resp(ls_b_resp),.b_id(),
  .protocol_fault(ls_pf),.config_fault(ls_cf),
  `AXI_READ_CONNECT(m,m,1),`AXI_WRITE_CONNECT(m,m,1)
 );
 assign data_cache_miss=1'b0;
 assign dc_idle=1'b1;
`endif
 assign m_awvalid[0]=0;
 assign m_awaddr[0+:32]=0;
 assign m_awid[0+:4]=0;
 assign m_awlen[0+:8]=0;
 assign m_awsize[0+:3]=0;
 assign m_awburst[0+:2]=1;
 assign m_awlock[0]=0;
 assign m_awcache[0+:4]=0;
 assign m_awprot[0+:3]=0;
 assign m_awqos[0+:4]=0;
 assign m_wvalid[0]=0;
 assign m_wdata[0+:32]=0;
 assign m_wstrb[0+:4]=0;
 assign m_wlast[0]=0;
 assign m_bready[0]=0;
`ifdef PERF_ENABLE
 // Event taps for rtl/perips/perf_regs.v.  Both wait views are stall views that
 // overlap the cycle count and each other; they are not additive.
 assign perf_i_miss=if_cache_miss;
 assign perf_d_miss=data_cache_miss;
 assign perf_if_wait=fetch_enable && fetch_ready && !fetch_valid;
 assign perf_lsu_wait=op_valid && !done_valid;
 assign perf_pred_miss=pred_miss;
`endif
endmodule
