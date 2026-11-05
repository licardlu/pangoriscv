`timescale 1ns/1ps
`include "cpu_boot_params.vh"
module tb_cpu_ai_boot;
    reg clk=0,rst_n=0,uart_rx=1;
    always #5 clk=~clk;
    wire uart_tx;
    wire protocol_fault,trap_fire;
    wire [31:0] trap_pc,trap_cause,arch_next_pc;
    wire [31:0] acc_araddr,acc_awaddr;
    wire acc_arvalid,acc_awvalid,acc_rready,acc_wvalid,acc_wlast,acc_bready;
    wire [7:0] acc_arlen,acc_awlen;
    wire [63:0] acc_wdata;
    reg acc_rvalid=0,acc_bvalid=0;
    reg [63:0] memory_word=64'h1122334455667788,write_word;
    reg [31:0] write_address;
    wire [63:0] acc_rdata=memory_word;
    reg [1:0] acc_rresp=0,acc_bresp=0;
    wire acc_arready=!acc_rvalid,acc_awready=1,acc_wready=1;
    reg aw_have=0,w_have=0;
    pangoriscv_ai_soc #(.PROGRAM_INIT_FILE(`BOOT_HEX)) dut(
        .clk(clk),.rst_n(rst_n),.uart_rx(uart_rx),.uart_tx(uart_tx),
        .halt_req(1'b0),.trap_ready(1'b1),.trap_vector(32'd0),
        .irq_software(1'b0),.irq_timer(1'b0),.irq_external(1'b0),.debug_addr(5'd0),
        .protocol_fault(protocol_fault),.trap_fire(trap_fire),
        .trap_pc(trap_pc),.trap_cause(trap_cause),.arch_next_pc(arch_next_pc),
        .gpio_input(2'b0),.gpio_ctrl(),.gpio_data(),.spi_miso(1'b0),
        .spi_mosi(),.spi_ss(),.spi_clk(),.ext_event(2'b0),
        .acc_araddr(acc_araddr),.acc_arvalid(acc_arvalid),.acc_arready(acc_arready),
        .acc_arlen(acc_arlen),.acc_rdata(acc_rdata),.acc_rvalid(acc_rvalid),
        .acc_rready(acc_rready),.acc_rresp(acc_rresp),
        .acc_awaddr(acc_awaddr),.acc_awvalid(acc_awvalid),.acc_awready(acc_awready),
        .acc_awlen(acc_awlen),.acc_wdata(acc_wdata),.acc_wvalid(acc_wvalid),
        .acc_wlast(acc_wlast),.acc_wready(acc_wready),
        .acc_bresp(acc_bresp),.acc_bvalid(acc_bvalid),.acc_bready(acc_bready),
        .acc_dbg_st(),.acc_dbg_anom(),.acc_dbg_snap(),
        .vid_wr_en(),.vid_wr_addr(),.vid_wr_data(),.vid_rd_addr(),.vid_rd_data(32'd0));
    integer reads=0,writes=0;
    always @(posedge clk) if(rst_n) begin
        if(protocol_fault || trap_fire)
            $fatal(1,"CPU fault=%b trap=%b pc=%h cause=%h next=%h",
                   protocol_fault,trap_fire,trap_pc,trap_cause,arch_next_pc);
        if(acc_arvalid && acc_arready) begin
            if(acc_araddr!=32'h01000000) $fatal(1,"wrong CPU DDR address");
            acc_rvalid<=1;reads<=reads+1;
        end
        if(acc_rvalid && acc_rready) acc_rvalid<=0;
        if(acc_awvalid && acc_awready) begin aw_have<=1;write_address<=acc_awaddr;end
        if(acc_wvalid && acc_wready) begin
            if(!acc_wlast) $fatal(1,"CPU mailbox write must be one beat");
            w_have<=1;write_word<=acc_wdata;
        end
        if(aw_have && w_have) begin
            if(write_address!=32'h01000000)
                $fatal(1,"wrong CPU DDR write address %h",write_address);
            memory_word<=write_word;writes<=writes+1;
            acc_bvalid<=1;aw_have<=0;w_have<=0;
        end
        if(acc_bvalid && acc_bready) acc_bvalid<=0;
    end
    reg [7:0] request_bytes[0:`BOOT_REQUEST_COUNT-1];
    reg [7:0] expected_bytes[0:`BOOT_REPLY_COUNT-1],received_bytes[0:127];
    integer received=0,i,b;
    reg [7:0] byte_value;
    localparam BIT_CYCLES=234;
    initial begin
        wait(rst_n);wait(uart_tx===1'b1);
        forever begin
            @(negedge uart_tx);
            #(BIT_CYCLES*10+BIT_CYCLES*5);
            for(b=0;b<8;b=b+1) begin
                byte_value[b]=uart_tx;
                #(BIT_CYCLES*10);
            end
            if(uart_tx!==1'b1) $fatal(1,"UART stop bit");
            if(received>=128) $fatal(1,"unexpected UART output");
            received_bytes[received]=byte_value;received=received+1;
        end
    end
    task send_byte(input [7:0] value);
        integer k;
        begin
            @(negedge clk);uart_rx=0;repeat(BIT_CYCLES) @(negedge clk);
            for(k=0;k<8;k=k+1) begin
                uart_rx=value[k];repeat(BIT_CYCLES) @(negedge clk);
            end
            uart_rx=1;repeat(BIT_CYCLES) @(negedge clk);
        end
    endtask
    initial begin
        $readmemh(`REQUEST_HEX,request_bytes);
        $readmemh(`REPLY_HEX,expected_bytes);
        if(^request_bytes[0]===1'bx || ^expected_bytes[0]===1'bx)
            $fatal(1,"CPU boot vectors missing");
        repeat(20) @(negedge clk);rst_n=1;
        repeat(30000) @(negedge clk);
        for(i=0;i<24;i=i+1) send_byte(request_bytes[i]);
        wait(received==12);
        for(i=24;i<`BOOT_REQUEST_COUNT;i=i+1) send_byte(request_bytes[i]);
        wait(received==`BOOT_REPLY_COUNT);
        for(i=0;i<`BOOT_REPLY_COUNT;i=i+1)
            if(received_bytes[i]!==expected_bytes[i])
                $fatal(1,"CPU response byte %0d got %h expected %h",
                       i,received_bytes[i],expected_bytes[i]);
        if(reads!=1) $fatal(1,"DDR reads=%0d",reads);
        if(writes!=1) $fatal(1,"DDR writes=%0d",writes);
        $display("CPU_AI_BOOT_PASS real RV32IM firmware, UART CRC write/read, MMIO DDR readback");
        $finish;
    end
    initial begin repeat(600000) @(posedge clk);$fatal(1,"CPU boot timeout RX bytes=%0d",received);end
endmodule
