//=============================================================================
// pangoriscv - RV32IM processor core + native AXI4 SoC (Pango PG2L100H @ 27 MHz)
// Module : axi_ram                File : rtl/perips/axi_ram.v
// Rev    : 1.0                    Date : 2026-10-13
// Author : pango_lpenghan
// Brief  : On-chip AXI4 data RAM slave (16 KiB)
//=============================================================================

// Single-access AXI RAM. Unsupported bursts are framed errors, not memory access.
module axi_ram #(
    parameter [31:0] BASE_ADDR=32'h10000000,
    parameter integer WORDS=4096,
    parameter INIT_FILE="",
    parameter integer READ_DELAY=0,
    parameter integer WRITE_DELAY=0,
    parameter integer WRITE_ENABLE=1
) (
    input wire clk,rst_n,
    input wire s_arvalid,output wire s_arready,
    input wire [31:0] s_araddr,input wire [3:0] s_arid,
    input wire [7:0] s_arlen,input wire [2:0] s_arsize,
    input wire [1:0] s_arburst,input wire s_arlock,
    input wire [3:0] s_arcache,input wire [2:0] s_arprot,input wire [3:0] s_arqos,
    output wire s_rvalid,input wire s_rready,
    output wire [31:0] s_rdata,output wire [3:0] s_rid,
    output wire [1:0] s_rresp,output wire s_rlast,
    input wire s_awvalid,output wire s_awready,
    input wire [31:0] s_awaddr,input wire [3:0] s_awid,
    input wire [7:0] s_awlen,input wire [2:0] s_awsize,
    input wire [1:0] s_awburst,input wire s_awlock,
    input wire [3:0] s_awcache,input wire [2:0] s_awprot,input wire [3:0] s_awqos,
    input wire s_wvalid,output wire s_wready,
    input wire [31:0] s_wdata,input wire [3:0] s_wstrb,input wire s_wlast,
    output wire s_bvalid,input wire s_bready,
    output wire [3:0] s_bid,output wire [1:0] s_bresp,
    output reg protocol_fault
);
    localparam IDLE=0,READ_MEM=1,READ_WAIT=2,READ_RESP=3,
               WRITE_DRAIN=4,WRITE_WAIT=5,WRITE_RESP=6,FAULT=7;
    localparam [32:0] END_ADDR={1'b0,BASE_ADDR}+WORDS*33'd4;
    reg [2:0] state;
    reg [31:0] mem[0:WORDS-1];
    reg ar_saved,aw_saved,w_saved,prefer_write;
    reg [31:0] ar_addr,aw_addr,w_data,read_data;
    reg [3:0] ar_id,aw_id,w_strb,response_id;
    reg [7:0] ar_len,aw_len,beats_left;
    reg [2:0] ar_size,aw_size;
    reg [1:0] ar_burst,aw_burst,response_code;
    reg ar_lock,aw_lock,w_last,read_good;
    reg [31:0] read_index;
    integer delay_left;
    // Plain Verilog-2001 loop variable: the ADS/Synplify front end used by PDS
    // parses these sources as Verilog, and `for(integer lane=...)` is a
    // SystemVerilog-only declaration that failed with Verilog-4005/4039
    // unless the project's SystemVerilog option is enabled.
    integer lane;
    wire read_select=ar_saved && (!(aw_saved && w_saved) || !prefer_write);
    wire write_select=aw_saved && w_saved && !read_select;
    function address_ok;
        input [31:0] addr;
        input [2:0] size;
        reg [32:0] transfer_end;
        begin
            transfer_end={1'b0,addr}+(33'd1<<size);
            address_ok=size<=2 && {1'b0,addr}>={1'b0,BASE_ADDR} &&
                transfer_end<=END_ADDR &&
                (size!=1 || !addr[0]) && (size!=2 || addr[1:0]==0);
        end
    endfunction
    function [3:0] allowed_lanes;
        input [2:0] size;
        input [1:0] offset;
        begin
            case(size)
                0: allowed_lanes=4'b0001<<offset;
                1: allowed_lanes=4'b0011<<offset;
                2: allowed_lanes=4'b1111;
                default: allowed_lanes=0;
            endcase
        end
    endfunction
    // Burst legality for the the caches cache refill: INCR, unlocked, ARSIZE<=2, at most
    // eight beats (ARLEN=7 fills one 32 B line) and the whole burst inside the
    // window. ARLEN=0 behaves exactly as the original single-access RAM did.
    function burst_ok;
        input [31:0] addr;
        input [2:0] size;
        input [7:0] len;
        reg [32:0] transfer_end,bytes;
        begin
            bytes=({1'b0,len}+33'd1)<<size;
            transfer_end={1'b0,addr}+bytes;
            burst_ok=size<=2 && len<=8'd7 && {1'b0,addr}>={1'b0,BASE_ADDR} &&
                transfer_end<=END_ADDR &&
                (size!=1 || !addr[0]) && (size!=2 || addr[1:0]==0);
        end
    endfunction
    wire ar_good=ar_burst==1 && !ar_lock && burst_ok(ar_addr,ar_size,ar_len);
    wire write_good=WRITE_ENABLE && aw_len==0 && aw_size<=2 && aw_burst==1 && !aw_lock &&
        address_ok(aw_addr,aw_size) &&
        (w_strb & ~allowed_lanes(aw_size,aw_addr[1:0]))==0;
    wire [31:0] write_index=(aw_addr-BASE_ADDR)>>2;
    // Exposed internal event is the actual byte-enable memory mutation edge.
    wire write_event=rst_n && state==IDLE && write_select &&
                     write_good && w_last && |w_strb;
    assign s_arready=rst_n && state==IDLE && !ar_saved;
    assign s_awready=rst_n && state==IDLE && !aw_saved;
    assign s_wready=rst_n && ((state==IDLE && !w_saved) || state==WRITE_DRAIN);
    assign s_rvalid=rst_n && state==READ_RESP;
    assign s_rdata=read_data;
    assign s_rid=response_id;
    assign s_rresp=response_code;
    assign s_rlast=beats_left==0;
    assign s_bvalid=rst_n && state==WRITE_RESP;
    assign s_bid=response_id;
    assign s_bresp=response_code;
    initial begin
        if(INIT_FILE!="") $readmemh(INIT_FILE,mem);
    end
    // No reset on the memory array: this is a synchronous single-port access.
    always @(posedge clk) begin
        if(write_event)
            for(lane=0;lane<4;lane=lane+1)
                if(w_strb[lane]) mem[write_index][8*lane+:8]<=w_data[8*lane+:8];
    end
    always @(posedge clk) begin
        if(!rst_n) begin
            state<=IDLE; ar_saved<=0; aw_saved<=0; w_saved<=0; prefer_write<=0;
            ar_addr<=0; aw_addr<=0; ar_id<=0; aw_id<=0; ar_len<=0; aw_len<=0;
            ar_size<=0; aw_size<=0; ar_burst<=0; aw_burst<=0;
            ar_lock<=0; aw_lock<=0; w_data<=0; w_strb<=0; w_last<=0;
            read_data<=0; response_id<=0; response_code<=0; beats_left<=0;
            read_good<=0; read_index<=0; delay_left<=0; protocol_fault<=0;
        end else begin
            if(s_arvalid && s_arready) begin
                ar_saved<=1; ar_addr<=s_araddr; ar_id<=s_arid; ar_len<=s_arlen;
                ar_size<=s_arsize; ar_burst<=s_arburst; ar_lock<=s_arlock;
            end
            if(s_awvalid && s_awready) begin
                aw_saved<=1; aw_addr<=s_awaddr; aw_id<=s_awid; aw_len<=s_awlen;
                aw_size<=s_awsize; aw_burst<=s_awburst; aw_lock<=s_awlock;
            end
            if(state==IDLE && s_wvalid && s_wready) begin
                w_saved<=1; w_data<=s_wdata; w_strb<=s_wstrb; w_last<=s_wlast;
            end
            case(state)
                IDLE: begin
                    if(read_select) begin
                        ar_saved<=0; response_id<=ar_id; beats_left<=ar_len;
                        read_good<=ar_good;
                        response_code<=ar_good?0:2;
                        // Only a checked descriptor can reach a memory index.
                        if(ar_good) read_index<=(ar_addr-BASE_ADDR)>>2;
                        else read_index<=0;
                        prefer_write<=1; state<=READ_MEM;
                    end else if(write_select) begin
                        aw_saved<=0; w_saved<=0; response_id<=aw_id;
                        response_code<=write_good?0:2;
                        prefer_write<=0;
                        if(w_last!=(aw_len==0)) begin
                            protocol_fault<=1; state<=FAULT;
                        end else if(aw_len!=0) begin
                            beats_left<=aw_len; response_code<=2; state<=WRITE_DRAIN;
                        end else begin
                            delay_left<=WRITE_DELAY; state<=WRITE_WAIT;
                        end
                    end
                end
                READ_MEM: begin
                    if(read_good) read_data<=mem[read_index];
                    else read_data<=0;
                    delay_left<=READ_DELAY; state<=READ_WAIT;
                end
                READ_WAIT: begin
                    if(delay_left==0) state<=READ_RESP;
                    else delay_left<=delay_left-1;
                end
                READ_RESP: if(s_rvalid && s_rready) begin
                    if(beats_left==0) state<=IDLE;
                    else begin
                        beats_left<=beats_left-1;
                        // INCR with ARSIZE=2: the next beat is the next 32-bit word.
                        if(read_good) read_index<=read_index+1;
                        state<=READ_MEM;
                    end
                end
                WRITE_DRAIN: if(s_wvalid && s_wready) begin
                    if(s_wlast!=(beats_left==1)) begin
                        protocol_fault<=1; state<=FAULT;
                    end else if(beats_left==1) begin
                        delay_left<=WRITE_DELAY; state<=WRITE_WAIT;
                    end else beats_left<=beats_left-1;
                end
                WRITE_WAIT: begin
                    if(delay_left==0) state<=WRITE_RESP;
                    else delay_left<=delay_left-1;
                end
                WRITE_RESP: if(s_bvalid && s_bready) state<=IDLE;
                FAULT: state<=FAULT;
                default: begin protocol_fault<=1; state<=FAULT; end
            endcase
        end
    end
endmodule
