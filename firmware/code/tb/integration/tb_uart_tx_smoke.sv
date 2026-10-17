//=============================================================================
// pangoriscv - RV32IM processor core + native AXI4 SoC (Pango PG2L100H @ 27 MHz)
// Module : tb_uart_tx_smoke       File : tb/integration/tb_uart_tx_smoke.sv
// Rev    : 1.0                    Date : 2026-10-13
// Author : pango_lpenghan
// Brief  : Minimal CPU to AXI to UART TX path check, independent of compiled
//          software
//=============================================================================

// Minimal native-CPU UART TX check: store 'A' into the UART TXDATA register
// through the full AXI fabric, then loop. Verifies the CPU->AXI->UART TX path
// independently of any compiled software.
`timescale 1ns/1ps
module tb_uart_tx_smoke;
    // This test writes TXDATA without programming UART_BAUD, so the decoder must model the
    // axi_uart reset divider: 234 for the 27 MHz board clock (was 0x1b8 = 440).
    parameter integer BAUD_DIV = 234;
    reg clk=0; always #0.5 clk=~clk;
    reg rst_n=0;
    reg uart_rx=1, spi_miso=1;
    reg [1:0] gpio_input=0, ext_event=0;
    wire uart_tx,spi_mosi,spi_ss,spi_clk;
    wire [31:0] gpio_ctrl,gpio_data;
    wire halted, trap_fire, retire_fire, rd_valid, protocol_fault;
    wire [63:0] retire_order;
    wire [31:0] arch_next_pc,trap_cause,trap_pc,trap_tval,csr_mtvec,retire_pc,retire_inst,wdata,debug_data;
    wire [4:0] rd;

    pangoriscv_axi_soc soc(
        .clk(clk),.rst_n(rst_n),.uart_rx(uart_rx),.uart_tx(uart_tx),
        .gpio_input(gpio_input),.gpio_ctrl(gpio_ctrl),.gpio_data(gpio_data),
        .spi_miso(spi_miso),.spi_mosi(spi_mosi),.spi_ss(spi_ss),.spi_clk(spi_clk),
        .ext_event(ext_event),
        .halt_req(1'b0),.halted(halted),.arch_next_pc(arch_next_pc),
        .trap_ready(1'b1),.trap_vector(32'd0),
        .irq_software(1'b0),.irq_timer(1'b0),.irq_external(1'b0),
        .csr_mtvec(csr_mtvec),
        .trap_fire(trap_fire),.trap_cause(trap_cause),.trap_pc(trap_pc),
        .trap_tval(trap_tval),.retire_fire(retire_fire),.retire_order(retire_order),
        .retire_pc(retire_pc),.retire_inst(retire_inst),.rd_valid(rd_valid),
        .rd(rd),.wdata(wdata),.debug_addr(5'd0),.debug_data(debug_data),
        .protocol_fault(protocol_fault));

    integer retired=0, traps=0, cycle=0, chars=0, txd=0;
    always @(posedge clk) begin
        cycle=cycle+1;
        if(retire_fire) begin
            retired=retired+1;
            if(retired<=8)
                $display("RETIRE pc=%08x inst=%08x rdv=%b rd=%0d wdata=%08x",retire_pc,retire_inst,rd_valid,rd,wdata);
        end
        if(trap_fire) begin traps=traps+1; $display("TRAP cause=%0d pc=%08x",trap_cause,trap_pc); end
        if(soc.uart_inst.we && soc.uart_inst.wo==12) begin
            txd=txd+1;
            $display("TXD_WRITE cycle=%0d data=%02x ctrl=%08x status=%08x",cycle,soc.uart_inst.wd[7:0],soc.uart_inst.uart_ctrl,soc.uart_inst.uart_status);
        end
        if(soc.uart_inst.we && soc.uart_inst.wo==0)
            $display("CTRL_WRITE cycle=%0d data=%08x",cycle,soc.uart_inst.wd);
        if(soc.fabric.protocol_fault)
            $display("FABRIC_PROTOCOL_FAULT cycle=%0d",cycle);
        if(soc.core.lsu.state==3'd5 && soc.core.lsu.done_valid) begin
            $display("LSU_DONE cycle=%0d fault=%b fault_addr=%08x",cycle,soc.core.lsu.fault,soc.core.lsu.fault_addr);
            if(soc.core.lsu.fault==0) $display("STORE_OK cycle=%0d",cycle);
        end
        if(soc.uart_inst.endpoint.s_awvalid && soc.uart_inst.endpoint.s_awready)
            $display("UART_AW cycle=%0d addr=%08x size=%0d burst=%0d len=%0d lock=%b",
                     cycle,soc.uart_inst.endpoint.s_awaddr,soc.uart_inst.endpoint.s_awsize,
                     soc.uart_inst.endpoint.s_awburst,soc.uart_inst.endpoint.s_awlen,soc.uart_inst.endpoint.s_awlock);
        if(soc.uart_inst.endpoint.s_wvalid && soc.uart_inst.endpoint.s_wready)
            $display("UART_W cycle=%0d data=%08x strb=%b last=%b",cycle,soc.uart_inst.endpoint.s_wdata,soc.uart_inst.endpoint.s_wstrb,soc.uart_inst.endpoint.s_wlast);
        if(soc.uart_inst.endpoint.s_bvalid && soc.uart_inst.endpoint.s_bready)
            $display("UART_B cycle=%0d resp=%b id=%0d",cycle,soc.uart_inst.endpoint.s_bresp,soc.uart_inst.endpoint.s_bid);
        if(soc.uart_inst.endpoint.consume)
            $display("UART_CONSUME cycle=%0d legal=%b framing=%b wrok=%b addrreg=%08x size=%0d burst=%0d len=%0d lock=%b wlast=%b",
                     cycle,soc.uart_inst.endpoint.write_legal,soc.uart_inst.endpoint.framing_ok,
                     soc.uart_inst.write_ok,soc.uart_inst.endpoint.awaddr,soc.uart_inst.endpoint.awsize,
                     soc.uart_inst.endpoint.awburst,soc.uart_inst.endpoint.awlen,soc.uart_inst.endpoint.awlock,
                     soc.uart_inst.endpoint.wlast);
        if(soc.uart_inst.endpoint.wr_event) begin
            txd=txd+1;
            $display("TXD_WRITE cycle=%0d data=%02x",cycle,soc.uart_inst.endpoint.wr_data);
        end
    end

    // Program: configure UART, send 'A', then 'B', then 'C'(on a different offset),
    // then 'D' with a long pause before it, to observe busy-gate behaviour.
    reg [31:0] prog[0:15];
    initial begin
        prog[0] =32'h300002b7; // lui  x5,0x30000
        prog[1] =32'h00300313; // addi x6,x0,3
        prog[2] =32'h0062a023; // sw   x6,0(x5)   CTRL=3 at 0x30000000
        prog[3] =32'h00c28293; // addi x5,x5,12  -> 0x3000000c TXDATA
        prog[4] =32'h04100313; // addi x6,x0,'A'
        prog[5] =32'h0062a023; // sw   x6,0(x5)   TXDATA='A'
        prog[6] =32'h04200313; // addi x6,x0,'B'
        prog[7] =32'h0062a023; // sw   x6,0(x5)   TXDATA='B' while possibly busy
        prog[8] =32'h04300313; // addi x6,x0,'C'
        prog[9] =32'h0062a023; // sw   x6,0(x5)   TXDATA='C' while possibly busy
        prog[10]=32'h00001313; // addi x6,x0,0
        prog[11]=32'h00000013; // nop
        prog[12]=32'h00000013; // nop
        prog[13]=32'h04400313; // addi x6,x0,'D'
        prog[14]=32'h0062a023; // sw   x6,0(x5)   TXDATA='D'
        prog[15]=32'h0000006f; // jal  x0,0
        for(integer i=0;i<64;i=i+1) soc.program_ram.mem[i] = (i<16)? prog[i] : 32'h00000013;
        for(integer j=0;j<4096;j=j+1) soc.data_ram.mem[j]=0;
    end

    // UART decoder, no reset dependency.
    reg [15:0] div_cnt=0; reg [3:0] bit_idx=0; reg [7:0] sh=0; reg busy=0; reg tx_q=1;
    always @(posedge clk) begin
        tx_q <= uart_tx;
        if(!busy) begin
            if(tx_q && !uart_tx) begin busy<=1; div_cnt<=(BAUD_DIV/2); bit_idx<=0; sh<=0; end
        end else if(div_cnt==0) begin
            if(bit_idx==0) begin bit_idx<=1; div_cnt<=BAUD_DIV-1; end
            else if(bit_idx<=8) begin
                sh[bit_idx-1]=uart_tx;
                if(bit_idx==8) begin chars=chars+1; $display("UART_BYTE '%c' (0x%02x) cycle=%0d",sh,sh,cycle); bit_idx<=9; div_cnt<=BAUD_DIV-1; end
                else begin bit_idx<=bit_idx+1; div_cnt<=BAUD_DIV-1; end
            end else begin busy<=0; bit_idx<=0; end
        end else div_cnt<=div_cnt-1;
    end

    initial begin
        repeat(10) @(negedge clk);
        rst_n=1;
        repeat(40000) @(negedge clk);
        $display("SMOKE_SUMMARY retires=%0d traps=%0d txd=%0d chars=%0d",retired,traps,txd,chars);
        if(txd==0) begin $display("TEST_FAIL NO_TXD_WRITE"); $fatal(1,"txdata never written"); end
        if(chars==0) begin $display("TEST_FAIL NO_UART_BYTE"); $fatal(1,"no uart byte"); end
        $display("TEST_PASS UART_TX_SMOKE");
        $finish;
    end
endmodule