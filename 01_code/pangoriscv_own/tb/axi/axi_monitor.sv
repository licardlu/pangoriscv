//=============================================================================
// pangoriscv - RV32IM processor core + native AXI4 SoC (Pango PG2L100H @ 27 MHz)
// Module : axi_monitor            File : tb/axi/axi_monitor.sv
// Rev    : 1.0                    Date : 2026-10-13
// Author : pango_lpenghan
// Brief  : AXI4 protocol monitor: handshake stability, burst bookkeeping and
//          violation counting shared by the AXI testbenches
//=============================================================================

`timescale 1ns/1ps
module axi_monitor(axi_bus bus, output idle);
    reg ar_stall=0, aw_stall=0, w_stall=0, r_stall=0, b_stall=0;
    reg [63:0] ar_saved, aw_saved;
    reg [36:0] w_saved;
    reg [38:0] r_saved;
    reg [5:0] b_saved;
    wire [63:0] ar_payload={bus.arid,bus.araddr,bus.arlen,bus.arsize,
        bus.arburst,bus.arlock,bus.arcache,bus.arprot,bus.arqos,3'b0};
    wire [63:0] aw_payload={bus.awid,bus.awaddr,bus.awlen,bus.awsize,
        bus.awburst,bus.awlock,bus.awcache,bus.awprot,bus.awqos,3'b0};
    wire [36:0] w_payload={bus.wdata,bus.wstrb,bus.wlast};
    wire [38:0] r_payload={bus.rid,bus.rdata,bus.rresp,bus.rlast};
    wire [5:0] b_payload={bus.bid,bus.bresp};
    reg read_live=0, write_live=0;
    reg [3:0] read_id, write_id;
    integer read_expected=0, read_count=0, write_expected=0, write_count=0;
    reg last_seen [0:15];
    integer i, seed;
    assign idle=!read_live && !write_live && write_count==0;

    initial if (!$value$plusargs("SEED=%d",seed)) seed=1;
    always @(posedge bus.clk) begin
        if (!bus.rst_n) begin
            ar_stall=0; aw_stall=0; w_stall=0; r_stall=0; b_stall=0;
            read_live=0; write_live=0; read_count=0; write_count=0;
        end else begin
            if(ar_stall && (!bus.arvalid || ar_payload !== ar_saved))
                $fatal(1,"AXI_MONITOR AR_STABILITY seed=%0d",seed);
            if(aw_stall && (!bus.awvalid || aw_payload !== aw_saved))
                $fatal(1,"AXI_MONITOR AW_STABILITY seed=%0d",seed);
            if(w_stall && (!bus.wvalid || w_payload !== w_saved))
                $fatal(1,"AXI_MONITOR W_STABILITY seed=%0d",seed);
            if(r_stall && (!bus.rvalid || r_payload !== r_saved))
                $fatal(1,"AXI_MONITOR R_STABILITY seed=%0d",seed);
            if(b_stall && (!bus.bvalid || b_payload !== b_saved))
                $fatal(1,"AXI_MONITOR B_STABILITY seed=%0d",seed);
            ar_stall=bus.arvalid && !bus.arready; ar_saved=ar_payload;
            aw_stall=bus.awvalid && !bus.awready; aw_saved=aw_payload;
            w_stall=bus.wvalid && !bus.wready; w_saved=w_payload;
            r_stall=bus.rvalid && !bus.rready; r_saved=r_payload;
            b_stall=bus.bvalid && !bus.bready; b_saved=b_payload;

            if(bus.arvalid && bus.arready) begin
                if(read_live || write_live || write_count!=0)
                    $fatal(1,"AXI_MONITOR READ_OWNER seed=%0d",seed);
                read_live=1; read_id=bus.arid;
                read_expected=bus.arlen+1; read_count=0;
            end
            if(bus.rvalid) begin
                if(!read_live || bus.rid !== read_id ||
                   bus.rlast !== (read_count==read_expected-1))
                    $fatal(1,"AXI_MONITOR R_ID_LAST_OR_ORPHAN seed=%0d",seed);
                if(bus.rready) begin
                    read_count=read_count+1;
                    if(read_count==read_expected) read_live=0;
                end
            end
            if(bus.awvalid && bus.awready) begin
                if(write_live || read_live)
                    $fatal(1,"AXI_MONITOR WRITE_OWNER seed=%0d",seed);
                write_live=1; write_id=bus.awid; write_expected=bus.awlen+1;
            end
            if(bus.wvalid && bus.wready) begin
                if(read_live || write_count>=16)
                    $fatal(1,"AXI_MONITOR W_COUNT seed=%0d",seed);
                last_seen[write_count]=bus.wlast;
                write_count=write_count+1;
            end
            if(write_live) begin
                if(write_count>write_expected)
                    $fatal(1,"AXI_MONITOR W_EXCESS seed=%0d",seed);
                for(i=0;i<write_count;i=i+1)
                    if(last_seen[i] !== (i==write_expected-1))
                        $fatal(1,"AXI_MONITOR WLAST seed=%0d beat=%0d",seed,i);
            end
            if(bus.bvalid) begin
                if(!write_live || bus.bid !== write_id || write_count!=write_expected)
                    $fatal(1,"AXI_MONITOR B_ID_COUNT_OR_ORPHAN seed=%0d",seed);
                if(bus.bready) begin write_live=0; write_count=0; end
            end
        end
    end
endmodule
