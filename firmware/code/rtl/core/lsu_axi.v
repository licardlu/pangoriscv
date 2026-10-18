//=============================================================================
// pangoriscv - RV32IM processor core + native AXI4 SoC (Pango PG2L100H @ 27 MHz)
// Module : lsu_axi                File : rtl/core/lsu_axi.v
// Rev    : 1.0                    Date : 2026-10-13
// Author : pango_lpenghan
// Brief  : Load/store unit: AXI4 read and write transactions, byte strobes, fault reporting
//=============================================================================

// Operation ownership and lane conversion; AXI channels belong to the engine.
//
// Latency (P8/P9): an accepted load walks EMPTY -> READ_WAIT -> (COMPLETE), and a
// store EMPTY -> WRITE_DATA -> WRITE_WAIT -> (COMPLETE).  P8 already moved the
// request onto the ACCEPT edge.  P9 moved the completion onto the RESPONSE edge:
// the result is reported combinationally in the cycle the engine answers, so the
// instruction retires there instead of one cycle later.  COMPLETE is no longer on
// the fast path -- it survives as the hold state when the consumer is not ready
// in that cycle (tb_lsu_axi deliberately back-pressures it for four cycles).
module lsu_axi(
    input wire clk,rst_n,
    input wire op_valid,output wire op_ready,
    input wire is_store,input wire [31:0] address,store_value,op_pc,
    input wire [2:0] access_size,input wire load_unsigned,
    input wire [4:0] op_rd,
    output wire done_valid,input wire done_ready,
    output wire [31:0] load_value,output reg [31:0] fault_addr,
    output wire fault,output wire idle,
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
    // Registered completion payload, held in COMPLETE when the consumer is not
    // ready on the response edge (P9).
    reg [31:0] load_value_q;
    reg fault_q;
    wire bad_access=access_size>2 ||
        (access_size==1 && address[0]) ||
        (access_size==2 && |address[1:0]);
    assign idle=state==EMPTY;
    assign op_ready=rst_n && idle;
    // P8 fast issue: while idle, drive the engine request straight from the
    // incoming operation so an idle engine can take it on the ACCEPT edge.  The
    // REQUEST state then only serves as the fallback for "engine not ready this
    // cycle" (a data-cache write still draining its B response, an in-flight
    // refill), and the address registers stay the source for that path.
    wire fast_issue=(state==EMPTY)&&op_valid&&!bad_access;
    assign eng_req_valid=rst_n && ((state==REQUEST) || fast_issue);
    assign eng_req_write=(state==REQUEST)?store_q:is_store;
    assign eng_req_addr=(state==REQUEST)?address_q:address;
    assign eng_req_size=(state==REQUEST)?size_q:access_size;
    assign eng_req_len=0;
    assign eng_req_id=1;
    // P25: present the store data on the REQUEST cycle too, so the data cache can
    // capture it on the accept edge and this unit never needs a WRITE_DATA visit.
    wire wdata_on_req = rst_n && (state==REQUEST) && store_q;
    wire wdata_on_iss = rst_n && fast_issue && is_store;
    assign eng_w_valid=rst_n && (state==WRITE_DATA || wdata_on_req || wdata_on_iss);
    assign eng_w_data =(state==REQUEST) ? (value_q << (8*address_q[1:0]))
                                       : (store_value << (8*address[1:0]));
    assign eng_w_strb =(state==REQUEST)
                       ? ((size_q==0?4'b0001:size_q==1?4'b0011:4'b1111) << address_q[1:0])
                       : ((access_size==0?4'b0001:access_size==1?4'b0011:4'b1111) << address[1:0]);
    assign eng_w_last=1;
    // P10: also be ready for a response on the ACCEPT edge.  The data cache
    // answers a hit combinationally there, so a load retires in one cycle instead
    // of two.  Gated by `fast_issue`, which is exactly "an operation is being
    // accepted this cycle and it is not a misaligned access".
    assign eng_rsp_ready=rst_n && (state==READ_WAIT || fast_issue);
    // P14: also ready for the B response on the edge the W beat is handed over --
    // the cache reports the early-release OKAY right there, so a store finishes in
    // two cycles instead of three.
    assign eng_b_ready  =rst_n && (state==WRITE_WAIT ||
                                   (state==WRITE_DATA && eng_w_valid && eng_w_ready) ||
                                   wdata_on_iss || wdata_on_req);
    // P9/P10/P14: report completion on the RESPONSE edge, not one cycle later.
    wire rsp_fire=eng_rsp_valid&&eng_rsp_ready;
    wire b_fire  =eng_b_valid&&eng_b_ready;
    assign done_valid=rst_n && (state==COMPLETE || rsp_fire || b_fire);
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
    // Completion payload: live on the response edge, held otherwise.  On the
    // accept edge (P10) the address registers are not written yet, so the
    // lane/size/sign inputs of the incoming operation are used instead.
    wire [31:0] load_now=extend_load(eng_rsp_data,
        (state==READ_WAIT)?address_q[1:0]:address[1:0],
        (state==READ_WAIT)?size_q:access_size,
        (state==READ_WAIT)?unsigned_q:load_unsigned);
    assign load_value=rsp_fire ? (eng_rsp_resp==0 ? load_now : 32'd0) : load_value_q;
    assign fault     =rsp_fire ? (eng_rsp_resp!=0) : b_fire ? (eng_b_resp!=0) : fault_q;
    always @(posedge clk) begin
        if(!rst_n) begin
            state<=EMPTY; store_q<=0; unsigned_q<=0;
            address_q<=0; value_q<=0; pc_q<=0; rd_q<=0; size_q<=0;
            load_value_q<=0; fault_addr<=0; fault_q<=0;
        end else case(state)
            EMPTY: if(op_valid && op_ready) begin
                address_q<=address; value_q<=store_value; size_q<=access_size;
                store_q<=is_store; unsigned_q<=load_unsigned;
                pc_q<=op_pc; rd_q<=op_rd;
                fault_addr<=address; fault_q<=bad_access; load_value_q<=0;
                if(bad_access) state<=COMPLETE;
                // Engine took the request on this very edge: skip REQUEST.
                // `is_store` (the input) is used because store_q is latched above.
                else if(eng_req_valid && eng_req_ready) begin
                    if(rsp_fire) begin
                        // P10: the answer came back on the same edge.
                        fault_q<=eng_rsp_resp!=0;
                        load_value_q<=(eng_rsp_resp==0)?load_now:32'd0;
                        state<=done_ready?EMPTY:COMPLETE;
                    end else if(b_fire) begin
                        fault_q<=eng_b_resp!=0;
                        state<=done_ready?EMPTY:COMPLETE;
                    end else begin
                        state<=is_store?WRITE_WAIT:READ_WAIT;
                    end
                end
                else state<=REQUEST;
            end
            REQUEST: if(eng_req_valid && eng_req_ready) begin
                if(b_fire) begin
                    fault_q<=eng_b_resp!=0;
                    state<=done_ready?EMPTY:COMPLETE;
                end else state<=store_q?WRITE_WAIT:READ_WAIT;
            end
            WRITE_DATA: if(eng_w_valid && eng_w_ready) begin
                // P14: the cache answers on this same edge for a released write.
                if(b_fire) begin
                    fault_q<=eng_b_resp!=0;
                    state<=done_ready?EMPTY:COMPLETE;
                end else begin
                    state<=WRITE_WAIT;
                end
            end
            READ_WAIT: if(eng_rsp_valid && eng_rsp_ready) begin
                fault_q<=eng_rsp_resp!=0;
                load_value_q<=eng_rsp_resp==0?
                    extend_load(eng_rsp_data,address_q[1:0],size_q,unsigned_q):0;
                // Retire on this edge when the consumer takes it; otherwise park
                // in COMPLETE and hold the payload (back-pressure contract).
                state<=done_ready?EMPTY:COMPLETE;
            end
            WRITE_WAIT: if(eng_b_valid && eng_b_ready) begin
                fault_q<=eng_b_resp!=0;
                state<=done_ready?EMPTY:COMPLETE;
            end
            COMPLETE: if(done_valid && done_ready) state<=EMPTY;
            default: state<=EMPTY;
        endcase
    end
endmodule
