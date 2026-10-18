//=============================================================================
// pangoriscv - RV32IM processor core + native AXI4 SoC (Pango PG2L100H @ 27 MHz)
// Module : lsu_axi                File : rtl/core/lsu_axi.v
// Rev    : 1.1 (phase-2 lsu_opt)  Date : 2026-10-18
// Author : pango_lpenghan
// Brief  : Load/store unit: AXI4 read and write transactions, byte strobes, fault reporting
//
// Phase-2 change (control-overhead merge, candidate A):
//   * The op is launched on the cycle it is accepted: eng_req_valid / eng_w_valid
//     are driven from the operation inputs while EMPTY and op_ready additionally
//     waits for the cache/engine request (and write data) ready.  This removes
//     the one-shot "accept then request" cycle (diagnosis bubble #1).
//   * The legacy REQUEST / WRITE_DATA states are kept for interface
//     compatibility, but the normal path no longer traverses them.
//   * Retirement semantics are unchanged: COMPLETE is still registered for one
//     cycle, so the AXI B response never reaches the retire path combinationally.
//=============================================================================

// Operation ownership and lane conversion; AXI channels belong to the engine.
module lsu_axi(
    input wire clk,rst_n,
    input wire op_valid,output wire op_ready,
    input wire is_store,input wire [31:0] address,store_value,op_pc,
    input wire [2:0] access_size,input wire load_unsigned,
    input wire [4:0] op_rd,
    output wire done_valid,input wire done_ready,
    output reg [31:0] load_value,fault_addr,
    output reg fault,output wire idle,
    output wire eng_req_valid,input wire eng_req_ready,
    output wire eng_req_write,output wire [31:0] eng_req_addr,
    output wire [2:0] eng_req_size,output wire [7:0] eng_req_len,
    output wire [3:0] eng_req_id,
    output wire eng_w_valid,input wire eng_w_ready,
    output wire [31:0] eng_w_data,output wire [3:0] eng_w_strb,
    output wire eng_w_last,
    input wire eng_rsp_valid,output wire eng_rsp_ready,
    input wire [31:0] eng_rsp_data,input wire [1:0] eng_rsp_resp,
    input wire eng_b_valid,output wire eng_b_ready,
    input wire [1:0] eng_b_resp
);
    localparam EMPTY=0,REQUEST=1,WRITE_DATA=2,READ_WAIT=3,
               WRITE_WAIT=4,COMPLETE=5;
    reg [2:0] state;
    reg store_q,unsigned_q;
    reg [31:0] address_q,value_q,pc_q;
    reg [2:0] size_q;
    reg [4:0] rd_q;
    wire bad_access=access_size>2 ||
        (access_size==1 && address[0]) ||
        (access_size==2 && |address[1:0]);
    // A launch happens while EMPTY: the operation inputs are still valid, so the
    // cache/engine request (and, for a store, the write data) are registered by
    // the downstream block on this very clock edge.
    wire issuing = (state==EMPTY);
    wire launch  = rst_n && issuing && op_valid && op_ready && !bad_access;

    assign idle=state==EMPTY;
    assign op_ready=rst_n && issuing &&
        (bad_access || (is_store ? (eng_req_ready && eng_w_ready) : eng_req_ready));
    assign done_valid=rst_n && state==COMPLETE;
    assign eng_req_valid=rst_n && (issuing ? launch : (state==REQUEST));
    assign eng_req_write=issuing ? is_store : store_q;
    assign eng_req_addr=issuing ? address : address_q;
    assign eng_req_size=issuing ? access_size : size_q;
    assign eng_req_len=0;
    assign eng_req_id=1;
    assign eng_w_valid=rst_n && (issuing ? (launch && is_store)
                                           : (state==WRITE_DATA && store_q));
    assign eng_w_data=issuing ? (store_value << (8*address[1:0]))
                              : (value_q << (8*address_q[1:0]));
    assign eng_w_strb=(issuing ?
                       ((access_size==0?4'b0001:access_size==1?4'b0011:4'b1111)
                        << address[1:0]) :
                       ((size_q==0?4'b0001:size_q==1?4'b0011:4'b1111)
                        << address_q[1:0]));
    assign eng_w_last=1;
    assign eng_rsp_ready=rst_n && state==READ_WAIT;
    assign eng_b_ready=rst_n && state==WRITE_WAIT;
    function [31:0] extend_load;
        input [31:0] raw;
        input [1:0] offset;
        input [2:0] size;
        input is_unsigned;
        reg [31:0] shifted;
        begin
            shifted=raw >> (8*offset);
            case(size)
                0: extend_load=is_unsigned?{24'b0,shifted[7:0]}:
                                           {{24{shifted[7]}},shifted[7:0]};
                1: extend_load=is_unsigned?{16'b0,shifted[15:0]}:
                                           {{16{shifted[15]}},shifted[15:0]};
                2: extend_load=shifted;
                default: extend_load=0;
            endcase
        end
    endfunction
    always @(posedge clk) begin
        if(!rst_n) begin
            state<=EMPTY; store_q<=0; unsigned_q<=0;
            address_q<=0; value_q<=0; pc_q<=0; rd_q<=0; size_q<=0;
            load_value<=0; fault_addr<=0; fault<=0;
        end else case(state)
            EMPTY: if(op_valid && op_ready) begin
                address_q<=address; value_q<=store_value; size_q<=access_size;
                store_q<=is_store; unsigned_q<=load_unsigned;
                pc_q<=op_pc; rd_q<=op_rd;
                fault_addr<=address; fault<=bad_access; load_value<=0;
                // the request (and W for a store) was accepted downstream on
                // this same edge, so the wait state can be entered directly
                if(bad_access) state<=COMPLETE;
                else if(is_store) state<=WRITE_WAIT;
                else state<=READ_WAIT;
            end
            REQUEST: if(eng_req_valid && eng_req_ready)
                state<=store_q?WRITE_DATA:READ_WAIT;
            WRITE_DATA: if(eng_w_valid && eng_w_ready) state<=WRITE_WAIT;
            READ_WAIT: if(eng_rsp_valid && eng_rsp_ready) begin
                fault<=eng_rsp_resp!=0;
                load_value<=eng_rsp_resp==0?
                    extend_load(eng_rsp_data,address_q[1:0],size_q,unsigned_q):0;
                state<=COMPLETE;
            end
            WRITE_WAIT: if(eng_b_valid && eng_b_ready) begin
                fault<=eng_b_resp!=0;
                state<=COMPLETE;
            end
            COMPLETE: if(done_valid && done_ready) state<=EMPTY;
            default: state<=EMPTY;
        endcase
    end
endmodule
