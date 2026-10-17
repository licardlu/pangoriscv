//=============================================================================
// pangoriscv - RV32IM processor core + native AXI4 SoC (Pango PG2L100H @ 27 MHz)
// Module : lsu_axi                File : rtl/core/lsu_axi.v
// Rev    : 1.0                    Date : 2026-10-13
// Author : pango_lpenghan
// Brief  : Load/store unit: AXI4 read and write transactions, byte strobes, fault reporting
//=============================================================================

// Operation ownership and lane conversion; AXI channels belong to the engine.
//
// Latency (P8): an accepted load walks EMPTY -> READ_WAIT -> COMPLETE, and a
// store EMPTY -> WRITE_DATA -> WRITE_WAIT -> COMPLETE.  The request leaves on the
// ACCEPT edge rather than one cycle later, which is one cycle less per memory
// operation; REQUEST remains only as the "engine busy this cycle" fallback.
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
    assign idle=state==EMPTY;
    assign op_ready=rst_n && idle;
    assign done_valid=rst_n && state==COMPLETE;
    // P8 fast issue: while idle, drive the engine request straight from the
    // incoming operation so an idle engine can take it on the ACCEPT edge.  The
    // REQUEST state then only serves as the fallback for "engine not ready this
    // cycle" (a data-cache write still draining its B response, an in-flight
    // refill), and the address registers stay the source for that path.
    // Cycles per memory operation that this removes: one (measured REQUEST
    // occupancy was 1.175 cycles/op; the extra 0.175 are genuine engine waits
    // and remain).  No port changes.
    wire fast_issue=(state==EMPTY)&&op_valid&&!bad_access;
    assign eng_req_valid=rst_n && ((state==REQUEST) || fast_issue);
    assign eng_req_write=(state==REQUEST)?store_q:is_store;
    assign eng_req_addr=(state==REQUEST)?address_q:address;
    assign eng_req_size=(state==REQUEST)?size_q:access_size;
    assign eng_req_len=0;
    assign eng_req_id=1;
    assign eng_w_valid=rst_n && state==WRITE_DATA;
    assign eng_w_data=value_q << (8*address_q[1:0]);
    assign eng_w_strb=(size_q==0?4'b0001:size_q==1?4'b0011:4'b1111)
                      << address_q[1:0];
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
                if(bad_access) state<=COMPLETE;
                // Engine took the request on this very edge: skip REQUEST.
                // `is_store` (the input) is used because store_q is latched above.
                else if(eng_req_valid && eng_req_ready)
                    state<=is_store?WRITE_DATA:READ_WAIT;
                else state<=REQUEST;
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
