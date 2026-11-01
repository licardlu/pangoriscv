//=============================================================================
// pangoriscv - RV32IM processor core + native AXI4 SoC (Pango PG2L100H @ 27 MHz)
// Module : tb_native_soc_integration File : tb/integration/tb_native_soc_integration.sv
// Rev    : 1.0                    Date : 2026-10-13
// Author : pango_lpenghan
// Brief  : T01 CPU to native AXI SoC integration: fetch from program RAM,
//          load/store through the AXI fabric, committed image check
//=============================================================================

// T01 CPU <-> native AXI SoC integration: fetch from program RAM, load/store
// through the AXI fabric into data RAM, and check the committed memory image.
`timescale 1ns/1ps
module tb_native_soc_integration;
    reg clk=0; always #5 clk=~clk;
    reg rst_n=0;
    reg uart_rx=1, spi_miso=0;
    reg [1:0] gpio_input=0, ext_event=0;
    wire uart_tx,spi_mosi,spi_ss,spi_clk;
    wire [31:0] gpio_ctrl,gpio_data;
    wire halt_req=0, trap_ready=1, irq_software=0, irq_timer=0, irq_external=0;
    reg [4:0] debug_addr=0;
    wire halted;
    wire [31:0] arch_next_pc, trap_cause, trap_pc, trap_tval, csr_mtvec;
    wire trap_fire, retire_fire, rd_valid, protocol_fault;
    wire [63:0] retire_order;
    wire [31:0] retire_pc, retire_inst, wdata, debug_data;
    reg [31:0] trap_vector=32'h800;
    wire [4:0] rd;
    integer retired=0, traps=0, errors=0;
    reg [31:0] prog_mem[0:63];
    reg [31:0] data_expected[0:2];
    integer i;

    pangoriscv_axi_soc #(.PROGRAM_INIT_FILE(""),.DATA_INIT_FILE(""),
                        .READ_DELAY(0),.WRITE_DELAY(0)) soc(
        .clk(clk),.rst_n(rst_n),.uart_rx(uart_rx),.uart_tx(uart_tx),
        .gpio_input(gpio_input),.gpio_ctrl(gpio_ctrl),.gpio_data(gpio_data),
        .spi_miso(spi_miso),.spi_mosi(spi_mosi),.spi_ss(spi_ss),.spi_clk(spi_clk),
        .ext_event(ext_event),
        .halt_req(halt_req),.halted(halted),.arch_next_pc(arch_next_pc),
        .trap_ready(trap_ready),.trap_vector(trap_vector),
        .irq_software(irq_software),.irq_timer(irq_timer),.irq_external(irq_external),
        .csr_mtvec(csr_mtvec),
        .trap_fire(trap_fire),.trap_cause(trap_cause),.trap_pc(trap_pc),
        .trap_tval(trap_tval),.retire_fire(retire_fire),.retire_order(retire_order),
        .retire_pc(retire_pc),.retire_inst(retire_inst),.rd_valid(rd_valid),
        .rd(rd),.wdata(wdata),.debug_addr(debug_addr),.debug_data(debug_data),
        .protocol_fault(protocol_fault));

    // Program image is injected through hierarchical access while reset is held.
    initial begin
        prog_mem[ 0]=32'h00700093; // addi x1,x0,7
        prog_mem[ 1]=32'h00a00113; // addi x2,x0,10
        prog_mem[ 2]=32'h002081b3; // add  x3,x1,x2      -> 17
        prog_mem[ 3]=32'h40118233; // sub  x4,x3,x1      -> 10
        prog_mem[ 4]=32'h0020f2b3; // and  x5,x1,x2      -> 2
        prog_mem[ 5]=32'h0020e333; // or   x6,x1,x2      -> 15
        prog_mem[ 6]=32'h0020c3b3; // xor  x7,x1,x2      -> 13
        prog_mem[ 7]=32'h00209413; // slli x8,x1,2       -> 28
        prog_mem[ 8]=32'h10000237; // lui  x4,0x10000
        prog_mem[ 9]=32'h00322023; // sw   x3,0(x4)      -> 0x10000000
        prog_mem[10]=32'h00722223; // sw   x7,4(x4)      -> 0x10000004
        prog_mem[11]=32'h00022403; // lw   x8,0(x4)      -> 17
        prog_mem[12]=32'h00822423; // sw   x8,8(x4)      -> 0x10000008
        prog_mem[13]=32'h00025063; // bne  x4,x0,+0      (taken, loops)
        data_expected[0]=32'd17;
        data_expected[1]=32'd13;
        data_expected[2]=32'd17;
        for(i=0;i<64;i=i+1) soc.program_ram.mem[i]=prog_mem[i];
        for(i=14;i<64;i=i+1) soc.program_ram.mem[i]=32'h00000013; // nop
    end

    always @(posedge clk) if(rst_n) begin
        if(retire_fire) begin
            retired=retired+1;
            if(retired<=8)
                $display("RETIRE order=%0d pc=%08x inst=%08x rd_valid=%b rd=%0d wdata=%08x",
                         retire_order,retire_pc,retire_inst,rd_valid,rd,wdata);
        end
        if(trap_fire) begin
            traps=traps+1;
            $display("TRAP cause=%0d pc=%08x tval=%08x",trap_cause,trap_pc,trap_tval);
        end
        if(protocol_fault) errors=errors+1;
    end

    integer k; reg [31:0] got;
    initial begin
        repeat(4) @(negedge clk); rst_n=1;
        repeat(400) @(negedge clk);
        for(k=0;k<3;k=k+1) begin
            got=soc.data_ram.mem[k];
            if(got!==data_expected[k]) begin
                errors=errors+1;
                $display("DATA_MISMATCH addr=%08x expected=%08x got=%08x",
                         32'h10000000+k*4,data_expected[k],got);
            end
        end
        if(traps!==0) begin errors=errors+1; $display("UNEXPECTED_TRAP"); end
        if(retired<13) begin errors=errors+1; $display("TOO_FEW_RETIRES %0d",retired); end
        if(errors!==0) begin
            $display("TEST_FAIL T02_NATIVE_SOC_INTEGRATION errors=%0d",errors);
            $fatal(1,"integration failed");
        end
        $display("TEST_PASS T02_NATIVE_SOC_INTEGRATION retires=%0d stores=%0d traps=%0d",
                 retired,3,traps);
        $finish;
    end
    initial begin #200000; $display("TEST_FAIL TIMEOUT"); $fatal(1,"timeout"); end
endmodule
